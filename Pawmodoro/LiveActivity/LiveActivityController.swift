import ActivityKit
import Foundation

/// Wraps ActivityKit so `TimerEngine` doesn't have to know any of it.
///
/// Everything here compiles and runs whether or not the widget extension
/// exists yet: `Activity.request` simply fails and returns nil without one, and
/// a nil activity makes every other method a no-op. So the app side of the Live
/// Activity is finished and safe to ship ahead of the target being created —
/// see `docs/LIVE_ACTIVITY.md`.
///
/// No `@available` guard: the project's deployment target is iOS 17, and
/// ActivityKit has been there since 16.1.
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<PawmodoroActivityAttributes>?

    private init() {}

    /// Whether the system will let us show one at all. The user can turn Live
    /// Activities off per-app in Settings, and that is theirs to decide.
    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Start the activity, or move the existing one to a new phase.
    ///
    /// Called on every `start()`, which covers both cases: the first focus of a
    /// cycle requests one, and each subsequent phase updates it in place rather
    /// than stacking a second card on the lock screen.
    func startOrUpdate(phase: TimerEngine.Phase, buddyName: String, endDate: Date) {
        guard isAvailable else { return }

        let state = PawmodoroActivityAttributes.ContentState(
            phaseTitle: phase.title,
            isBreak: phase.isBreak,
            endDate: endDate
        )
        // Stale at the chime: after that the system dims it rather than
        // showing a countdown that has quietly finished.
        let content = ActivityContent(state: state, staleDate: endDate)

        if let activity {
            Task { await activity.update(content) }
            return
        }
        activity = try? Activity.request(
            attributes: PawmodoroActivityAttributes(buddyName: buddyName),
            content: content,
            pushType: nil
        )
    }

    /// Take it down. Safe to call when nothing is running, which is why every
    /// exit from a phase can call it without checking first.
    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
