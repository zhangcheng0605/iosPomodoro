import Foundation
import UserNotifications

/// Schedules the "your timer finished" local notification so phase endings reach
/// the user even when the app is backgrounded or the phone is locked.
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let phaseEndIdentifier = "pawmodoro.phaseEnd"

    func requestPermissionIfNeeded() {
        // The system alert lands on top of the timer the first time it starts,
        // which is in the way when the app is being driven in a simulator.
        guard !LaunchOptions.suppressNotificationPrompt else { return }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    func schedulePhaseEnd(for phase: TimerEngine.Phase, buddyName: String, at date: Date) {
        cancelPending()

        let content = UNMutableNotificationContent()
        // No emoji in the title. This is the one string in the app a user reads
        // with the app closed, and the banner already carries the app icon —
        // which is this app's own art. A paw glyph next to it is a second,
        // borrowed mark competing with the good one, in a typeface we don't
        // control and can't theme. Same call the Live Activity made: the buddy
        // is drawn, not spelled.
        if phase.isBreak {
            content.title = "Break's over"
            content.body = "\(buddyName) is settling in for a nap. Time to focus!"
        } else {
            content.title = "Focus complete!"
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

    // MARK: The golden hour call

    private let goldenHourIdentifier = "pawmodoro.goldenHour"

    /// BeReal's whole company was one notification: *now is the moment.*
    /// This is that, opted into and aimed at the camera — one a day at
    /// most, no sound, replaced wholesale each time it's re-armed, and
    /// never with the same wording two days running (the template index
    /// rotates with the day). Letting the minute pass costs nothing and
    /// is never mentioned anywhere.
    func scheduleGoldenHour(
        at date: Date, place: String, buddyName: String, template: Int
    ) {
        cancelGoldenHour()
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }

        let bodies = [
            "The light at \(place) is about to do something. Bring the camera.",
            "\(buddyName) is watching the sky over \(place). The camera's still loaded.",
            "Good light coming to \(place). One shot, whenever you like.",
        ]
        let content = UNMutableNotificationContent()
        content.title = "Golden hour"
        content.body = bodies[abs(template) % bodies.count]
        // Deliberately silent: a lighting tip should not chime.

        let request = UNNotificationRequest(
            identifier: goldenHourIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: interval, repeats: false
            )
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Taking the photo, turning the setting off, or the shot already
    /// being spent all land here.
    func cancelGoldenHour() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [goldenHourIdentifier])
    }
}
