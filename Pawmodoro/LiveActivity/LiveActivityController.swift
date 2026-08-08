#if os(iOS)
import ActivityKit
#endif
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
///
/// **On macOS the type survives and the bodies empty out.** ActivityKit does
/// not exist there, and `Platform.swift` names Live Activities as one of the
/// three things the Mac deliberately does without. The class is kept whole so
/// `TimerEngine` — which is platform-blind and should stay that way — has no
/// `#if` in it: `isAvailable` simply answers false, and every method that
/// follows it is already written to return on that.
final class LiveActivityController {
    static let shared = LiveActivityController()

    #if os(iOS)
    private var activity: Activity<PawmodoroActivityAttributes>?
    #endif

    private init() {}

    /// Whether the system will let us show one at all. The user can turn Live
    /// Activities off per-app in Settings, and that is theirs to decide.
    var isAvailable: Bool {
        #if os(iOS)
        return ActivityAuthorizationInfo().areActivitiesEnabled
        #else
        return false
        #endif
    }

    /// Start the activity, or move the existing one to a new phase.
    ///
    /// Called on every `start()`, which covers both cases: the first focus of a
    /// cycle requests one, and each subsequent phase updates it in place rather
    /// than stacking a second card on the lock screen.
    func startOrUpdate(phase: TimerEngine.Phase, buddyName: String, endDate: Date) {
        guard isAvailable else { return }

        #if os(iOS)
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
        // The species is read here rather than passed in, so `TimerEngine`'s
        // call site stays the three things it already knows. `load` is the same
        // accessor the app itself uses, and it runs once per activity — at the
        // start of a phase, never on a tick.
        //
        // Known seam: this reads the *stored* settings, and `-PawmodoroBuddy`
        // assigns `settings.buddy` in memory without saving. So under that one
        // Debug flag the app shows the forced buddy while the lock screen shows
        // the stored one. Harmless in Release, where the flag compiles out and
        // the only way to change buddy is the picker, which saves. The real fix
        // is to give `startOrUpdate` a `buddyID` parameter and pass
        // `settings.buddy.rawValue` from the call site — a two-line change in
        // `TimerEngine`, left undone here only because that file was being
        // edited concurrently.
        activity = try? Activity.request(
            attributes: PawmodoroActivityAttributes(
                buddyName: buddyName,
                buddyID: PomodoroSettings.load().buddy.rawValue
            ),
            content: content,
            pushType: nil
        )
        #endif
    }

    /// Take it down. Safe to call when nothing is running, which is why every
    /// exit from a phase can call it without checking first.
    func end() {
        #if os(iOS)
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        #endif
    }
}
