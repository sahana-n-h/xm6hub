import Foundation

@MainActor
final class ANCProfileStore: ObservableObject {
    static let shared = ANCProfileStore()

    @Published private(set) var rules: [ANCProfileRule] = []
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.enabled) }
    }

    private enum Keys {
        static let enabled = "smartProfiles.enabled"
        static let rules = "smartProfiles.rules"
    }

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        loadRules()
    }

    func loadRules() {
        if let data = defaults.data(forKey: Keys.rules),
           let decoded = try? decoder.decode([ANCProfileRule].self, from: data),
           !decoded.isEmpty {
            let filtered = decoded.filter { !ANCProfileRule.retiredBuiltInIDs.contains($0.id) }
            rules = filtered
            if filtered.count != decoded.count {
                saveRules()
            }
            return
        }
        rules = ANCProfileRule.defaults()
        saveRules()
    }

    func saveRules() {
        guard let data = try? encoder.encode(rules) else { return }
        defaults.set(data, forKey: Keys.rules)
    }

    func updateRule(_ rule: ANCProfileRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        var updated = rules
        updated[index] = rule
        rules = updated
        saveRules()
    }

    func setRuleEnabled(_ id: UUID, enabled: Bool) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        var updated = rules
        updated[index].enabled = enabled
        rules = updated
        saveRules()
    }

    func resetToDefaults() {
        rules = ANCProfileRule.defaults()
        saveRules()
    }

    func addRule(_ rule: ANCProfileRule) {
        rules.append(rule)
        saveRules()
    }

    func deleteRule(_ id: UUID) {
        guard let rule = rules.first(where: { $0.id == id }), !rule.isBuiltIn else { return }
        rules.removeAll { $0.id == id }
        saveRules()
    }

    func canDelete(_ rule: ANCProfileRule) -> Bool {
        !rule.isBuiltIn
    }
}
