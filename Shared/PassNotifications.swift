import Foundation
import UserNotifications

/// "1 minute left on your pass" and "Pass over. Welcome back." Plus the Sunday weekly summary.
enum PassNotifications {
    private static let oneMinuteID = "uk.tawfeeq.pass.oneMinute"
    private static let endID = "uk.tawfeeq.pass.end"
    private static let weeklyID = "uk.tawfeeq.weekly"

    static func schedule(expiresAt: Date, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [oneMinuteID, endID])

        let oneMinute = expiresAt.addingTimeInterval(-60).timeIntervalSince(now)
        if oneMinute > 1 {
            let content = UNMutableNotificationContent()
            content.title = "1 minute left on your pass"
            content.body = "Finish up. Your apps rest again soon."
            content.interruptionLevel = .timeSensitive
            center.add(UNNotificationRequest(identifier: oneMinuteID, content: content,
                                             trigger: UNTimeIntervalNotificationTrigger(timeInterval: oneMinute, repeats: false)))
        }

        let end = expiresAt.timeIntervalSince(now)
        if end > 1 {
            let content = UNMutableNotificationContent()
            content.title = "Pass over"
            content.body = "Welcome back to your focus."
            center.add(UNNotificationRequest(identifier: endID, content: content,
                                             trigger: UNTimeIntervalNotificationTrigger(timeInterval: end, repeats: false)))
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [oneMinuteID, endID])
    }

    /// Sunday 19:00: "Your week with Tawfeeq".
    static func scheduleWeeklySummary() {
        let content = UNMutableNotificationContent()
        content.title = "Your week with Tawfeeq"
        content.body = "See your focus time, streak and mornings."
        var when = DateComponents()
        when.weekday = 1
        when.hour = 19
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: weeklyID, content: content,
                                  trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))
        )
    }
}
