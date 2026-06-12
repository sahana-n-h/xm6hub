#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MDRBridgeConnectionState) {
    MDRBridgeConnectionStateDisconnected = 0,
    MDRBridgeConnectionStateConnecting,
    MDRBridgeConnectionStateConnected,
    MDRBridgeConnectionStateError
};

typedef NS_ENUM(NSInteger, MDRBridgeNCMode) {
    MDRBridgeNCModeOff = 0,
    MDRBridgeNCModeANC,
    MDRBridgeNCModeAmbient
};

@interface MDRPairedDeviceInfo : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *macAddress;
@end

@interface MDRMultipointDevice : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *macAddress;
@property (nonatomic, assign) BOOL connected;
@property (nonatomic, assign) BOOL isActive;
@end

@interface MDRDeviceState : NSObject
@property (nonatomic, assign) MDRBridgeConnectionState connectionState;
@property (nonatomic, copy, nullable) NSString *statusMessage;
@property (nonatomic, copy, nullable) NSString *modelName;
@property (nonatomic, copy, nullable) NSString *firmwareVersion;
@property (nonatomic, copy, nullable) NSString *deviceMacAddress;
@property (nonatomic, copy, nullable) NSString *codecName;
@property (nonatomic, assign) NSInteger batteryLevel;
@property (nonatomic, assign) BOOL isCharging;
@property (nonatomic, assign) NSInteger soundPressure;
@property (nonatomic, assign) MDRBridgeNCMode ncMode;
@property (nonatomic, assign) NSInteger ambientLevel;
@property (nonatomic, assign) BOOL focusOnVoice;
@property (nonatomic, assign) BOOL autoAmbientEnabled;
@property (nonatomic, assign) NSInteger noiseAdaptiveSensitivity;
@property (nonatomic, assign) BOOL speakToChatEnabled;
@property (nonatomic, assign) NSInteger speakToChatSensitivity;
@property (nonatomic, assign) NSInteger eqPresetRaw;
@property (nonatomic, copy) NSArray<NSNumber *> *eqBands;
@property (nonatomic, assign) NSInteger eqClearBass;
@property (nonatomic, assign) NSInteger volume;
@property (nonatomic, copy, nullable) NSString *trackTitle;
@property (nonatomic, copy, nullable) NSString *trackArtist;
@property (nonatomic, copy, nullable) NSString *trackAlbum;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, copy) NSArray<MDRMultipointDevice *> *multipointDevices;
@end

@interface MDRBridge : NSObject

+ (instancetype)shared;

- (NSArray<MDRPairedDeviceInfo *> *)listPairedBluetoothDevices;
- (nullable MDRPairedDeviceInfo *)findXM6Device;
- (void)connectToDeviceWithMAC:(NSString *)macAddress;
- (void)disconnect;
- (void)startPolling;
- (void)stopPolling;
- (MDRDeviceState *)currentState;

- (void)setNCMode:(MDRBridgeNCMode)mode;
- (void)setAmbientLevel:(NSInteger)level;
- (void)setFocusOnVoice:(BOOL)enabled;
- (void)setAutoAmbientEnabled:(BOOL)enabled;
- (void)setNoiseAdaptiveSensitivity:(NSInteger)sensitivity;
- (void)setSpeakToChatEnabled:(BOOL)enabled;
- (void)setSpeakToChatSensitivity:(NSInteger)sensitivity;
- (void)setEQPresetRaw:(NSInteger)preset;
- (void)setEQClearBass:(NSInteger)value;
- (void)setEQBandAtIndex:(NSInteger)index value:(NSInteger)value;
- (void)setVolume:(NSInteger)volume;
- (void)setPlaying:(BOOL)playing;
- (void)skipNext;
- (void)skipPrevious;
- (void)switchMultipointToMAC:(NSString *)macAddress;
- (void)disconnectMultipointMAC:(NSString *)macAddress;
- (void)connectMultipointMAC:(NSString *)macAddress;

@property (nonatomic, copy, nullable) void (^onStateUpdate)(MDRDeviceState *state);

@end

NS_ASSUME_NONNULL_END
