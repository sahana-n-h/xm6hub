#import "MDRBridge.h"

#import <Foundation/Foundation.h>

#include <mdr/Headphones.hpp>
#include <mdr/Generated/ProtocolV2T1Enum.hpp>
#include <mdr-c/Base.h>
#include <mdr-c/Connection.h>
#include <mdr-c/Platform/PlatformMacOS.h>

namespace t1 = mdr::v2::t1;

static bool MDRIsPlaying(const mdr::MDRHeadphones &headphones) {
    return headphones.mPlayPause == t1::PlaybackStatus::PLAY;
}

@implementation MDRPairedDeviceInfo
@end

@implementation MDRMultipointDevice
@end

@implementation MDRDeviceState
@end

@interface MDRBridge () {
    std::unique_ptr<mdr::MDRHeadphones> _headphones;
    MDRConnectionMacOS *_connectionMacOS;
}
@property(nonatomic, strong) MDRDeviceState *state;
@property(nonatomic, strong) NSThread *pollThread;
@property(nonatomic, assign) BOOL shouldPoll;
@property(nonatomic, assign) MDRConnection *connection;
@end

@implementation MDRBridge

+ (instancetype)shared {
    static MDRBridge *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MDRBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _state = [[MDRDeviceState alloc] init];
        _state.connectionState = MDRBridgeConnectionStateDisconnected;
        _state.eqBands = @[];
        _state.multipointDevices = @[];
        _connectionMacOS = mdrConnectionMacOSCreate();
        _connection = mdrConnectionMacOSGet(_connectionMacOS);
        _headphones = nullptr;
    }
    return self;
}

- (void)dealloc {
    [self stopPolling];
    [self disconnect];
    if (_connectionMacOS) {
        mdrConnectionMacOSDestroy(_connectionMacOS);
        _connectionMacOS = nullptr;
        _connection = nullptr;
    }
    _headphones.reset();
}

- (MDRDeviceState *)currentState {
    return self.state;
}

- (NSArray<MDRPairedDeviceInfo *> *)listPairedBluetoothDevices {
    MDRDeviceInfo *list = nullptr;
    int count = 0;
    if (mdrConnectionGetDevicesList(self.connection, &list, &count) != MDR_RESULT_OK) {
        return @[];
    }

    NSMutableArray<MDRPairedDeviceInfo *> *devices = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; i++) {
        MDRPairedDeviceInfo *info = [[MDRPairedDeviceInfo alloc] init];
        info.name = [NSString stringWithUTF8String:list[i].szDeviceName];
        info.macAddress = [NSString stringWithUTF8String:list[i].szDeviceMacAddress];
        [devices addObject:info];
    }
    mdrConnectionFreeDevicesList(self.connection, &list);
    return devices;
}

- (MDRPairedDeviceInfo *)findXM6Device {
    for (MDRPairedDeviceInfo *device in [self listPairedBluetoothDevices]) {
        NSString *upper = device.name.uppercaseString;
        if ([upper containsString:@"WH-1000XM6"] || [upper containsString:@"1000XM6"] || [upper containsString:@"XM6"]) {
            return device;
        }
    }
    return nil;
}

- (void)connectToDeviceWithMAC:(NSString *)macAddress {
    [self disconnect];

    self.state.connectionState = MDRBridgeConnectionStateConnecting;
    self.state.statusMessage = @"Connecting…";
    [self publishState];

    int result = mdrConnectionConnect(self.connection, macAddress.UTF8String, MDR_SERVICE_UUID_XM5);
    if (result != MDR_RESULT_OK && result != MDR_RESULT_INPROGRESS) {
        self.state.connectionState = MDRBridgeConnectionStateError;
        self.state.statusMessage = [NSString stringWithUTF8String:mdrConnectionGetLastError(self.connection)];
        [self publishState];
    }
}

- (void)disconnect {
    _headphones.reset();
    if (self.connection) {
        mdrConnectionDisconnect(self.connection);
    }
    self.state.connectionState = MDRBridgeConnectionStateDisconnected;
    self.state.statusMessage = @"Disconnected";
    [self publishState];
}

- (void)startPolling {
    if (self.pollThread != nil) {
        return;
    }
    self.shouldPoll = YES;
    self.pollThread = [[NSThread alloc] initWithBlock:^{
        @autoreleasepool {
            [self pollLoop];
        }
    }];
    self.pollThread.name = @"MDRBridgePollThread";
    [self.pollThread start];
}

- (void)stopPolling {
    self.shouldPoll = NO;
    if (self.pollThread) {
        [self.pollThread cancel];
        self.pollThread = nil;
    }
}

- (void)pollLoop {
    while (self.shouldPoll && !NSThread.currentThread.isCancelled) {
        @autoreleasepool {
            [self tick];
        }
        [NSThread sleepForTimeInterval:0.05];
    }
}

- (void)tick {
    if (self.state.connectionState == MDRBridgeConnectionStateConnecting) {
        int pollResult = mdrConnectionPoll(self.connection, 0);
        switch (pollResult) {
        case MDR_RESULT_OK:
            _headphones = std::make_unique<mdr::MDRHeadphones>(self.connection);
            if (_headphones->Invoke(_headphones->RequestInitV2()) == MDR_RESULT_OK) {
                self.state.connectionState = MDRBridgeConnectionStateConnected;
                self.state.statusMessage = @"Connected";
            } else {
                self.state.connectionState = MDRBridgeConnectionStateError;
                self.state.statusMessage = @"Failed to initialize device";
            }
            [self publishState];
            break;
        case MDR_RESULT_INPROGRESS:
        case MDR_RESULT_ERROR_TIMEOUT:
            break;
        default:
            self.state.connectionState = MDRBridgeConnectionStateError;
            self.state.statusMessage = [NSString stringWithUTF8String:mdrConnectionGetLastError(self.connection)];
            mdrConnectionDisconnect(self.connection);
            [self publishState];
            break;
        }
        return;
    }

    if (self.state.connectionState != MDRBridgeConnectionStateConnected || !_headphones) {
        return;
    }

    int event = _headphones->PollEvents();
    switch (event) {
    case MDR_HEADPHONES_TASK_INIT_OK:
        _headphones->Invoke(_headphones->RequestSyncV2());
        break;
    case MDR_HEADPHONES_IDLE:
        if (_headphones->IsDirty()) {
            _headphones->Invoke(_headphones->RequestCommitV2());
        }
        break;
    case MDR_HEADPHONES_ERROR:
        self.state.connectionState = MDRBridgeConnectionStateError;
        self.state.statusMessage = [NSString stringWithUTF8String:_headphones->GetLastError()];
        mdrConnectionDisconnect(self.connection);
        _headphones.reset();
        break;
    default:
        break;
    }

    [self syncStateFromHeadphones];
    [self publishState];
}

- (void)syncStateFromHeadphones {
    if (!_headphones) {
        return;
    }

    auto &hp = *_headphones;

    self.state.modelName = [NSString stringWithUTF8String:hp.mModelName.c_str()];
    self.state.firmwareVersion = [NSString stringWithUTF8String:hp.mFWVersion.c_str()];
    self.state.deviceMacAddress = [NSString stringWithUTF8String:hp.mUniqueId.c_str()];
    self.state.codecName = [NSString stringWithUTF8String:t1::format_as(hp.mAudioCodec)];

    self.state.batteryLevel = hp.mBatteryL.level;
    self.state.isCharging = hp.mBatteryL.charging == t1::BatteryChargingStatus::CHARGING ||
                            hp.mBatteryL.charging == t1::BatteryChargingStatus::CHARGED;
    self.state.soundPressure = hp.mSafeListeningSoundPressure;

    if (!hp.mNcAsmEnabled.current) {
        self.state.ncMode = MDRBridgeNCModeOff;
    } else if (hp.mNcAsmMode.current == t1::NcAsmMode::ASM) {
        self.state.ncMode = MDRBridgeNCModeAmbient;
    } else {
        self.state.ncMode = MDRBridgeNCModeANC;
    }

    self.state.ambientLevel = hp.mNcAsmAmbientLevel.current;
    self.state.focusOnVoice = hp.mNcAsmFocusOnVoice.current;
    self.state.autoAmbientEnabled = hp.mNcAsmAutoAsmEnabled.current;
    self.state.noiseAdaptiveSensitivity = static_cast<NSInteger>(hp.mNcAsmNoiseAdaptiveSensitivity.current);

    self.state.speakToChatEnabled = hp.mSpeakToChatEnabled.current;
    self.state.speakToChatSensitivity = static_cast<NSInteger>(hp.mSpeakToChatDetectSensitivity.current);

    self.state.eqPresetRaw = static_cast<NSInteger>(hp.mEqPresetId.current);
    self.state.eqClearBass = hp.mEqClearBass.current;

    NSMutableArray<NSNumber *> *bands = [NSMutableArray array];
    for (const auto value : hp.mEqConfig.current) {
        [bands addObject:@(value)];
    }
    self.state.eqBands = bands;

    self.state.volume = hp.mPlayVolume.current;
    self.state.trackTitle = [NSString stringWithUTF8String:hp.mPlayTrackTitle.c_str()];
    self.state.trackArtist = [NSString stringWithUTF8String:hp.mPlayTrackArtist.c_str()];
    self.state.trackAlbum = [NSString stringWithUTF8String:hp.mPlayTrackAlbum.c_str()];
    self.state.isPlaying = MDRIsPlaying(hp);

    NSMutableArray<MDRMultipointDevice *> *devices = [NSMutableArray array];
    for (const auto &device : hp.mPairedDevices) {
        MDRMultipointDevice *entry = [[MDRMultipointDevice alloc] init];
        entry.name = [NSString stringWithUTF8String:device.name.c_str()];
        entry.macAddress = [NSString stringWithUTF8String:device.macAddress.c_str()];
        entry.connected = device.connected;
        entry.isActive = device.macAddress == hp.mMultipointDeviceMac.current;
        [devices addObject:entry];
    }
    self.state.multipointDevices = devices;
}

- (MDRDeviceState *)snapshotState {
    MDRDeviceState *snapshot = [[MDRDeviceState alloc] init];
    snapshot.connectionState = self.state.connectionState;
    snapshot.statusMessage = self.state.statusMessage;
    snapshot.modelName = self.state.modelName;
    snapshot.firmwareVersion = self.state.firmwareVersion;
    snapshot.deviceMacAddress = self.state.deviceMacAddress;
    snapshot.codecName = self.state.codecName;
    snapshot.batteryLevel = self.state.batteryLevel;
    snapshot.isCharging = self.state.isCharging;
    snapshot.soundPressure = self.state.soundPressure;
    snapshot.ncMode = self.state.ncMode;
    snapshot.ambientLevel = self.state.ambientLevel;
    snapshot.focusOnVoice = self.state.focusOnVoice;
    snapshot.autoAmbientEnabled = self.state.autoAmbientEnabled;
    snapshot.noiseAdaptiveSensitivity = self.state.noiseAdaptiveSensitivity;
    snapshot.speakToChatEnabled = self.state.speakToChatEnabled;
    snapshot.speakToChatSensitivity = self.state.speakToChatSensitivity;
    snapshot.eqPresetRaw = self.state.eqPresetRaw;
    snapshot.eqBands = self.state.eqBands;
    snapshot.eqClearBass = self.state.eqClearBass;
    snapshot.volume = self.state.volume;
    snapshot.trackTitle = self.state.trackTitle;
    snapshot.trackArtist = self.state.trackArtist;
    snapshot.trackAlbum = self.state.trackAlbum;
    snapshot.isPlaying = self.state.isPlaying;
    snapshot.multipointDevices = self.state.multipointDevices;
    return snapshot;
}

- (void)publishState {
    MDRDeviceState *snapshot = [self snapshotState];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.onStateUpdate) {
            self.onStateUpdate(snapshot);
        }
    });
}

- (void)setNCMode:(MDRBridgeNCMode)mode {
    if (!_headphones) {
        return;
    }
    switch (mode) {
    case MDRBridgeNCModeOff:
        _headphones->mNcAsmEnabled.desired = false;
        break;
    case MDRBridgeNCModeANC:
        _headphones->mNcAsmEnabled.desired = true;
        _headphones->mNcAsmMode.desired = t1::NcAsmMode::NC;
        break;
    case MDRBridgeNCModeAmbient:
        _headphones->mNcAsmEnabled.desired = true;
        _headphones->mNcAsmMode.desired = t1::NcAsmMode::ASM;
        if (_headphones->mNcAsmAmbientLevel.desired == 0) {
            _headphones->mNcAsmAmbientLevel.desired = 20;
        }
        break;
    }
}

- (void)setAmbientLevel:(NSInteger)level {
    if (!_headphones) {
        return;
    }
    _headphones->mNcAsmAmbientLevel.desired = static_cast<int>(MAX(1, MIN(20, level)));
}

- (void)setFocusOnVoice:(BOOL)enabled {
    if (!_headphones) {
        return;
    }
    _headphones->mNcAsmFocusOnVoice.desired = enabled;
}

- (void)setAutoAmbientEnabled:(BOOL)enabled {
    if (!_headphones) {
        return;
    }
    _headphones->mNcAsmAutoAsmEnabled.desired = enabled;
}

- (void)setNoiseAdaptiveSensitivity:(NSInteger)sensitivity {
    if (!_headphones) {
        return;
    }
    _headphones->mNcAsmNoiseAdaptiveSensitivity.desired = static_cast<t1::NoiseAdaptiveSensitivity>(sensitivity);
}

- (void)setSpeakToChatEnabled:(BOOL)enabled {
    if (!_headphones) {
        return;
    }
    _headphones->mSpeakToChatEnabled.desired = enabled;
}

- (void)setSpeakToChatSensitivity:(NSInteger)sensitivity {
    if (!_headphones) {
        return;
    }
    _headphones->mSpeakToChatDetectSensitivity.desired = static_cast<t1::DetectSensitivity>(sensitivity);
}

- (void)setEQPresetRaw:(NSInteger)preset {
    if (!_headphones) {
        return;
    }
    _headphones->mEqPresetId.desired = static_cast<t1::EqPresetId>(preset);
}

- (void)setEQClearBass:(NSInteger)value {
    if (!_headphones) {
        return;
    }
    _headphones->mEqClearBass.desired = static_cast<int>(MAX(-10, MIN(10, value)));
}

- (void)setEQBandAtIndex:(NSInteger)index value:(NSInteger)value {
    if (!_headphones) {
        return;
    }
    auto &bands = _headphones->mEqConfig.desired;
    if (index < 0 || index >= static_cast<NSInteger>(bands.size())) {
        return;
    }
    bands[static_cast<size_t>(index)] = static_cast<int>(MAX(-10, MIN(10, value)));
}

- (void)setVolume:(NSInteger)volume {
    if (!_headphones) {
        return;
    }
    _headphones->mPlayVolume.desired = static_cast<int>(MAX(0, MIN(30, volume)));
}

- (void)setPlaying:(BOOL)playing {
    if (!_headphones) {
        return;
    }
    _headphones->mPlayControl.desired = playing ? t1::PlaybackControl::PLAY : t1::PlaybackControl::PAUSE;
}

- (void)skipNext {
    if (!_headphones) {
        return;
    }
    _headphones->mPlayControl.desired = t1::PlaybackControl::TRACK_UP;
}

- (void)skipPrevious {
    if (!_headphones) {
        return;
    }
    _headphones->mPlayControl.desired = t1::PlaybackControl::TRACK_DOWN;
}

- (void)switchMultipointToMAC:(NSString *)macAddress {
    if (!_headphones) {
        return;
    }
    _headphones->mMultipointDeviceMac.desired = macAddress.UTF8String;
}

- (void)disconnectMultipointMAC:(NSString *)macAddress {
    if (!_headphones) {
        return;
    }
    _headphones->mPairedDeviceDisconnectMac.desired = macAddress.UTF8String;
}

- (void)connectMultipointMAC:(NSString *)macAddress {
    if (!_headphones) {
        return;
    }
    _headphones->mPairedDeviceConnectMac.desired = macAddress.UTF8String;
}

@end
