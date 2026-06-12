import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private var notifiedThresholds: Set<Int> = []

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluateBattery(level: Int, charging: Bool) {
        if charging {
            notifiedThresholds.removeAll()
            return
        }

        let thresholds = [20, 10, 5]
        for threshold in thresholds where level <= threshold {
            guard !notifiedThresholds.contains(threshold) else { continue }
            notifiedThresholds.insert(threshold)
            send(title: "XM6 Battery Low", body: "Battery at \(level)%. Charge soon to avoid interruption.")
        }

        if level > 25 {
            notifiedThresholds.removeAll()
        }
    }

    func sendMeetingWarning(meetingTitle: String, startTime: String, projectedLevel: Int) {
        send(
            title: "XM6 battery will die during your next meeting",
            body: "\(meetingTitle) at \(startTime) — projected \(projectedLevel)% by end."
        )
    }

    func sendProfileSwitch(ruleName: String) {
        send(
            title: "Smart Profile Applied",
            body: "Switched to \(ruleName) based on your current context."
        )
    }

    private func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
