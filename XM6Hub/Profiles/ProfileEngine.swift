import Foundation
import Combine

@MainActor
final class ProfileEngine: ObservableObject {
    static let shared = ProfileEngine()

    @Published private(set) var activeRule: ANCProfileRule?
    @Published private(set) var lastAppliedAt: Date?
    private init() {}
    private let store = ANCProfileStore.shared
    private let monitor = ContextMonitor.shared
    private weak var deviceStore: DeviceStore?
    private var lastAppliedRuleID: UUID?
    private var lastAppliedProfile: SoundProfileSettings?
    private var cancellables = Set<AnyCancellable>()

    func attach(to deviceStore: DeviceStore) {
        self.deviceStore = deviceStore
        monitor.onUpdate = { [weak self] context in
            Task { @MainActor in
                self?.evaluate(context: context)
            }
        }

        store.$isEnabled
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.evaluateNow()
            }
            .store(in: &cancellables)

        store.$rules
            .sink { [weak self] _ in
                self?.evaluateNow()
            }
            .store(in: &cancellables)

        monitor.requestPermissionsIfNeeded()
        evaluate(context: monitor.snapshot)
    }

    func resetAppliedState() {
        lastAppliedRuleID = nil
        lastAppliedProfile = nil
    }

    func evaluateNow(force: Bool = false) {
        monitor.refresh()
        evaluate(context: monitor.snapshot, force: force)
    }

    private func evaluate(context: ContextSnapshot, force: Bool = false) {
        guard store.isEnabled, deviceStore?.isConnected == true else {
            if activeRule != nil {
                activeRule = nil
            }
            resetAppliedState()
            return
        }

        let matching = store.rules
            .filter(\.enabled)
            .filter { ruleMatches($0, context: context) }
            .sorted { $0.priority > $1.priority }

        guard let winner = matching.first else {
            if activeRule != nil {
                activeRule = nil
                lastAppliedRuleID = nil
                lastAppliedProfile = nil
            }
            return
        }

        activeRule = winner
        let profileChanged = winner.profile != lastAppliedProfile
        guard force || winner.id != lastAppliedRuleID || profileChanged else { return }

        apply(winner)
        lastAppliedRuleID = winner.id
        lastAppliedProfile = winner.profile
        lastAppliedAt = Date()

        NotificationManager.shared.sendProfileSwitch(ruleName: winner.name)
    }

    private func ruleMatches(_ rule: ANCProfileRule, context: ContextSnapshot) -> Bool {
        let pattern = rule.trigger.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        switch rule.trigger.type {
        case .wifi:
            guard !pattern.isEmpty, let ssid = context.wifiSSID else { return false }
            return ssid.localizedCaseInsensitiveContains(pattern)
        case .location:
            guard !pattern.isEmpty, let label = context.locationLabel else { return false }
            return label.localizedCaseInsensitiveContains(pattern)
        case .calendarMeeting:
            return context.isInMeeting
        case .activeApp:
            guard !pattern.isEmpty, let name = context.activeAppName else { return false }
            return name.localizedCaseInsensitiveContains(pattern)
        }
    }

    private func apply(_ rule: ANCProfileRule) {
        deviceStore?.applySoundProfile(rule.profile)
    }
}
