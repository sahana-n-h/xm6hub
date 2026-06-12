import Foundation
import EventKit

struct UpcomingMeeting {
    let title: String
    let startDate: Date
    let endDate: Date
}

@MainActor
final class MeetingBatteryAdvisor {
    static let shared = MeetingBatteryAdvisor()

    private let eventStore = EKEventStore()
    private let store = SharedBatteryStore.shared
    private var accessGranted = false
    private var notifiedMeetingIDs: Set<String> = []

    func requestAccessIfNeeded() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized:
            accessGranted = true
        case .notDetermined:
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                Task { @MainActor in
                    self?.accessGranted = granted
                }
            }
        default:
            accessGranted = false
        }
    }

    func evaluate(currentLevel: Int, isCharging: Bool) {
        guard !isCharging, currentLevel > 0, accessGranted else { return }
        guard let meeting = nextMeeting(withinHours: 8) else { return }

        let now = Date()
        guard meeting.endDate > now else { return }

        let hoursUntilEnd = meeting.endDate.timeIntervalSince(now) / 3600
        guard let projectedAtEnd = store.projectedLevel(afterHours: hoursUntilEnd, from: currentLevel) else { return }

        let meetingKey = "\(meeting.title)-\(meeting.startDate.timeIntervalSince1970)"
        guard projectedAtEnd <= 10 else {
            notifiedMeetingIDs.remove(meetingKey)
            return
        }
        guard !notifiedMeetingIDs.contains(meetingKey) else { return }

        notifiedMeetingIDs.insert(meetingKey)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let startText = formatter.string(from: meeting.startDate)

        NotificationManager.shared.sendMeetingWarning(
            meetingTitle: meeting.title,
            startTime: startText,
            projectedLevel: projectedAtEnd
        )
    }

    private func nextMeeting(withinHours hours: Double) -> UpcomingMeeting? {
        let now = Date()
        let end = now.addingTimeInterval(hours * 3600)
        let predicate = eventStore.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        guard let event = events.first else { return nil }
        return UpcomingMeeting(title: event.title, startDate: event.startDate, endDate: event.endDate)
    }
}
