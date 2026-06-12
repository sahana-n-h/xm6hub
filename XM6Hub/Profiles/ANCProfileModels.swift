import Foundation

enum ProfileTriggerType: String, Codable, CaseIterable, Identifiable {
    case wifi
    case location
    case calendarMeeting
    case activeApp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wifi: return "Wi‑Fi Network"
        case .location: return "Location"
        case .calendarMeeting: return "Calendar Meeting"
        case .activeApp: return "Active App"
        }
    }

    var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .location: return "location.fill"
        case .calendarMeeting: return "calendar"
        case .activeApp: return "macwindow"
        }
    }
}

struct ProfileTrigger: Codable, Equatable, Hashable {
    var type: ProfileTriggerType
    /// Wi‑Fi SSID substring, location name, or app name pattern. Unused for calendarMeeting.
    var pattern: String

    static let calendarMeeting = ProfileTrigger(type: .calendarMeeting, pattern: "")
}

struct SoundProfileSettings: Codable, Equatable, Hashable {
    var ncMode: Int
    var ambientLevel: Int
    var focusOnVoice: Bool

    var ncModeEnum: NCMode { NCMode(rawValue: ncMode) ?? .anc }

    static let ancMax = SoundProfileSettings(ncMode: NCMode.anc.rawValue, ambientLevel: 20, focusOnVoice: false)
    static let ambientHome = SoundProfileSettings(ncMode: NCMode.ambient.rawValue, ambientLevel: 20, focusOnVoice: true)
    static let coding = SoundProfileSettings(ncMode: NCMode.anc.rawValue, ambientLevel: 20, focusOnVoice: false)
    static let meeting = SoundProfileSettings(ncMode: NCMode.anc.rawValue, ambientLevel: 20, focusOnVoice: true)
}

struct ANCProfileRule: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var enabled: Bool
    var priority: Int
    var trigger: ProfileTrigger
    var profile: SoundProfileSettings

    var triggerSummary: String {
        switch trigger.type {
        case .wifi:
            return "Wi‑Fi contains \"\(trigger.pattern)\""
        case .location:
            return "Location contains \"\(trigger.pattern)\""
        case .calendarMeeting:
            return "During a calendar meeting"
        case .activeApp:
            return "App name contains \"\(trigger.pattern)\""
        }
    }
}

struct ContextSnapshot: Equatable {
    var wifiSSID: String?
    var locationLabel: String?
    var isInMeeting: Bool
    var activeMeetingTitle: String?
    var nextMeetingTitle: String?
    var nextMeetingStart: Date?
    var activeAppBundleID: String?
    var activeAppName: String?
    var updatedAt: Date

    static let empty = ContextSnapshot(
        wifiSSID: nil,
        locationLabel: nil,
        isInMeeting: false,
        activeMeetingTitle: nil,
        nextMeetingTitle: nil,
        nextMeetingStart: nil,
        activeAppBundleID: nil,
        activeAppName: nil,
        updatedAt: .distantPast
    )
}

extension ANCProfileRule {
    static let retiredBuiltInIDs: Set<UUID> = [
        UUID(uuidString: "A1000002-0000-4000-8000-000000000002")! // Coffee Shop
    ]

    static let builtInIDs: Set<UUID> = Set(defaults().map(\.id))

    var isBuiltIn: Bool {
        Self.builtInIDs.contains(id)
    }

    static func defaults() -> [ANCProfileRule] {
        [
            ANCProfileRule(
                id: UUID(uuidString: "A1000001-0000-4000-8000-000000000001")!,
                name: "Meeting",
                enabled: true,
                priority: 100,
                trigger: .calendarMeeting,
                profile: .meeting
            ),
            ANCProfileRule(
                id: UUID(uuidString: "A1000003-0000-4000-8000-000000000003")!,
                name: "Coding",
                enabled: true,
                priority: 60,
                trigger: ProfileTrigger(type: .activeApp, pattern: "Xcode"),
                profile: .coding
            ),
            ANCProfileRule(
                id: UUID(uuidString: "A1000005-0000-4000-8000-000000000005")!,
                name: "Cursor",
                enabled: true,
                priority: 55,
                trigger: ProfileTrigger(type: .activeApp, pattern: "Cursor"),
                profile: .coding
            ),
            ANCProfileRule(
                id: UUID(uuidString: "A1000004-0000-4000-8000-000000000004")!,
                name: "Home",
                enabled: true,
                priority: 40,
                trigger: ProfileTrigger(type: .wifi, pattern: "Home"),
                profile: .ambientHome
            ),
        ]
    }
}
