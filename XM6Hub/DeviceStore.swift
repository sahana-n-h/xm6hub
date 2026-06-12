import Foundation
import Combine
import WidgetKit

enum NCMode: Int, CaseIterable, Identifiable {
    case off = 0
    case anc = 1
    case ambient = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .anc: return "ANC"
        case .ambient: return "Ambient"
        }
    }
}

struct MultipointDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let macAddress: String
    let connected: Bool
    let isActive: Bool
}

@MainActor
final class DeviceStore: ObservableObject {
    @Published var connectionState: MDRBridgeConnectionState = .disconnected
    @Published var statusMessage = "Starting…"
    @Published var modelName = "WH-1000XM6"
    @Published var firmwareVersion = "—"
    @Published var codecName = "—"
    @Published var batteryLevel = 0
    @Published var isCharging = false
    @Published var soundPressure = 0
    @Published var ncMode: NCMode = .off
    @Published var ambientLevel = 10
    @Published var focusOnVoice = false
    @Published var autoAmbientEnabled = false
    @Published var noiseAdaptiveSensitivity = 0
    @Published var speakToChatEnabled = false
    @Published var speakToChatSensitivity = 0
    @Published var volume = 15
    @Published var trackTitle = ""
    @Published var trackArtist = ""
    @Published var trackAlbum = ""
    @Published var isPlaying = false
    @Published var multipointDevices: [MultipointDevice] = []
    @Published var launchAtLogin = false
    @Published var pairedDevices: [String] = []

    private let bridge = MDRBridge.shared()
    private let sharedStore = SharedBatteryStore.shared
    private let notificationManager = NotificationManager.shared
    private let meetingAdvisor = MeetingBatteryAdvisor.shared
    private let profileEngine = ProfileEngine.shared
    private var reconnectTimer: Timer?
    private var wasConnected = false

    var isConnected: Bool { connectionState == .connected }
    var isConnecting: Bool { connectionState == .connecting }

    var menuBarDisplayLevel: Int {
        if isConnected { return batteryLevel }
        let cached = sharedStore.snapshot.batteryLevel
        return cached > 0 ? cached : batteryLevel
    }

    var menuBarShowsBattery: Bool {
        isConnected || sharedStore.snapshot.batteryLevel > 0
    }

    var menuBarBatterySymbol: String {
        let level = menuBarDisplayLevel
        let charging = isConnected ? isCharging : sharedStore.snapshot.isCharging
        guard menuBarShowsBattery || isConnected else { return "headphones" }
        if charging { return "battery.100percent.bolt" }
        switch level {
        case 76...100: return "battery.100"
        case 51...75: return "battery.75"
        case 26...50: return "battery.50"
        case 11...25: return "battery.25"
        default: return "battery.0"
        }
    }

    init() {
        bridge.onStateUpdate = { [weak self] state in
            Task { @MainActor in
                self?.apply(state)
            }
        }
        bridge.startPolling()
        notificationManager.requestAuthorization()
        meetingAdvisor.requestAccessIfNeeded()
        launchAtLogin = LaunchAtLoginManager.isEnabled
        profileEngine.attach(to: self)
        loadCachedSnapshot()
        connectToXM6()
        scheduleReconnect()
    }

    func connectToXM6() {
        pairedDevices = bridge.listPairedBluetoothDevices().map { "\($0.name) · \($0.macAddress)" }
        if let xm6 = bridge.findXM6Device() {
            bridge.connectToDevice(withMAC: xm6.macAddress)
            statusMessage = "Connecting to \(xm6.name)…"
        } else {
            connectionState = .disconnected
            statusMessage = "No paired WH-1000XM6 found. Pair in System Settings → Bluetooth."
        }
    }

    private func loadCachedSnapshot() {
        let cached = sharedStore.snapshot
        guard cached.lastUpdated != .distantPast else { return }
        if !cached.modelName.isEmpty { modelName = cached.modelName }
        if cached.batteryLevel > 0 { batteryLevel = cached.batteryLevel }
        isCharging = cached.isCharging
        if let mode = NCMode.allCases.first(where: { $0.title == cached.ncMode }) {
            ncMode = mode
        }
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.connectionState == .disconnected || self.connectionState == .error {
                    self.connectToXM6()
                }
            }
        }
    }

    private func apply(_ state: MDRDeviceState) {
        connectionState = state.connectionState
        statusMessage = state.statusMessage ?? ""
        modelName = state.modelName ?? "WH-1000XM6"
        firmwareVersion = state.firmwareVersion ?? "—"
        codecName = state.codecName ?? "—"
        batteryLevel = state.batteryLevel
        isCharging = state.isCharging
        soundPressure = state.soundPressure
        ncMode = NCMode(rawValue: state.ncMode.rawValue) ?? .off
        ambientLevel = state.ambientLevel
        focusOnVoice = state.focusOnVoice
        autoAmbientEnabled = state.autoAmbientEnabled
        noiseAdaptiveSensitivity = state.noiseAdaptiveSensitivity
        speakToChatEnabled = state.speakToChatEnabled
        speakToChatSensitivity = state.speakToChatSensitivity
        volume = state.volume
        trackTitle = state.trackTitle ?? ""
        trackArtist = state.trackArtist ?? ""
        trackAlbum = state.trackAlbum ?? ""
        isPlaying = state.isPlaying
        multipointDevices = state.multipointDevices.map {
            MultipointDevice(
                id: $0.macAddress,
                name: $0.name,
                macAddress: $0.macAddress,
                connected: $0.connected,
                isActive: $0.isActive
            )
        }

        if isConnected {
            if !wasConnected {
                profileEngine.evaluateNow(force: true)
                sharedStore.record(level: batteryLevel, charging: isCharging, ncMode: ncMode.title, force: true)
            } else {
                sharedStore.record(level: batteryLevel, charging: isCharging, ncMode: ncMode.title)
            }
            wasConnected = true
            sharedStore.updateSnapshot(SharedDeviceSnapshot(
                batteryLevel: batteryLevel,
                isCharging: isCharging,
                isConnected: true,
                modelName: modelName,
                ncMode: ncMode.title,
                lastUpdated: Date()
            ))
            notificationManager.evaluateBattery(level: batteryLevel, charging: isCharging)
            meetingAdvisor.evaluate(currentLevel: batteryLevel, isCharging: isCharging)
            WidgetCenter.shared.reloadAllTimelines()
        } else if connectionState == .disconnected || connectionState == .error {
            wasConnected = false
            profileEngine.resetAppliedState()
            var snapshot = sharedStore.snapshot
            snapshot.isConnected = false
            snapshot.lastUpdated = Date()
            sharedStore.updateSnapshot(snapshot)
        }
    }

    func setNCMode(_ mode: NCMode) {
        bridge.setNCMode(MDRBridgeNCMode(rawValue: mode.rawValue) ?? .off)
    }

    func setAmbientLevel(_ level: Int) {
        bridge.setAmbientLevel(level)
    }

    func setFocusOnVoice(_ enabled: Bool) {
        bridge.setFocusOnVoice(enabled)
    }

    func setAutoAmbientEnabled(_ enabled: Bool) {
        bridge.setAutoAmbientEnabled(enabled)
    }

    func setNoiseAdaptiveSensitivity(_ value: Int) {
        bridge.setNoiseAdaptiveSensitivity(value)
    }

    func setSpeakToChatEnabled(_ enabled: Bool) {
        bridge.setSpeakToChatEnabled(enabled)
    }

    func setSpeakToChatSensitivity(_ value: Int) {
        bridge.setSpeakToChatSensitivity(value)
    }

    func setVolume(_ value: Int) {
        bridge.setVolume(value)
    }

    func togglePlayback() {
        bridge.setPlaying(!isPlaying)
    }

    func skipNext() { bridge.skipNext() }
    func skipPrevious() { bridge.skipPrevious() }

    func switchMultipoint(to mac: String) {
        bridge.switchMultipoint(toMAC: mac)
    }

    func disconnectMultipoint(_ mac: String) {
        bridge.disconnectMultipointMAC(mac)
    }

    func connectMultipoint(_ mac: String) {
        bridge.connectMultipointMAC(mac)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        LaunchAtLoginManager.setEnabled(enabled)
    }

    func applySoundProfile(_ profile: SoundProfileSettings) {
        setNCMode(NCMode(rawValue: profile.ncMode) ?? .anc)
        setAmbientLevel(profile.ambientLevel)
        setFocusOnVoice(profile.focusOnVoice)
    }
}
