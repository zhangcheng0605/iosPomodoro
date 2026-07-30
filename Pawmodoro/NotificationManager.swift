import Foundation
import UserNotifications

/// Schedules the "your timer finished" local notification so phase endings reach
/// the user even when the app is backgrounded or the phone is locked.
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let phaseEndIdentifier = "pawmodoro.phaseEnd"

    func requestPermissionIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    func schedulePhaseEnd(for phase: TimerEngine.Phase, buddyName: String, at date: Date) {
        cancelPending()

        let content = UNMutableNotificationContent()
        if phase.isBreak {
            content.title = "Break's over 🐾"
            content.body = "\(buddyName) is settling in for a nap. Time to focus!"
        } else {
            content.title = "Focus complete! 🐾"
            content.body = "Nice work — \(buddyName) woke up and it's break time."
        }
        content.sound = .default

        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: phaseEndIdentifier,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelPending() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [phaseEndIdentifier])
    }
}
