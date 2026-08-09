import Foundation
#if os(iOS)
import WidgetKit
#endif

/// The one place the app writes to the App Group, and the one place it asks
/// WidgetKit to redraw.
///
/// Sibling to `LiveActivityController` for the same reason: it is the app's
/// side of a conversation with the widget extension, and `TimerEngine` should
/// not have to know any of it.
///
/// ## Why the write is gated on a change
///
/// `settingsDidChange()` is called from `ContentView`'s
/// `.onChange(of: engine.settings)`, which fires on *every* settings mutation
/// — a volume slider drag is dozens of them, and none of those change what is
/// on the home screen. An ungated `reloadAllTimelines()` there would be a
/// battery bug in a file that looks completely innocent.
///
/// So `sync` compares the payload it is about to write with what is already
/// in the suite and returns without touching WidgetKit when they match. That
/// makes the call **idempotent and cheap** — two string compares against an
/// already-open `UserDefaults` — which is the property that lets every caller
/// stop thinking about it. Call it from anywhere it might have changed; do
/// not call it on a tick, but if something one day does, the ticker will read
/// two strings and return rather than waking the extension sixty times a
/// minute.
///
/// ## Why *all* timelines, and not `reloadTimelines(ofKind:)`
///
/// The kind string (`"PawmodoroHomeBuddy"`) lives in the extension's target.
/// Naming it here would be a second copy of a constant across a target
/// boundary that nothing can check — and if the two ever drifted, reloads
/// would silently stop and the only symptom would be the stale sprite this
/// type exists to fix. `PawmodoroWidgetsBundle` vends exactly one timeline
/// widget, so "all" and "that one" are the same set; the Live Activity is
/// driven by ActivityKit and is not a timeline at all. Precision here would
/// buy nothing and cost a drift class.
///
/// ## macOS
///
/// The widget extension is fenced to iOS (`SUPPORTED_PLATFORMS`, and a
/// `platformFilter` on both the dependency and the embed), so the reload is
/// fenced the same way. The mirror write is not: it is two strings in a
/// `UserDefaults` suite, it is harmless where nothing reads it, and keeping
/// it unconditional means the Mac build exercises the same code path.
enum WidgetMirror {

    /// Must match `com.apple.security.application-groups` in *both*
    /// `Pawmodoro/iOS/Pawmodoro.entitlements` and
    /// `PawmodoroWidgets/PawmodoroWidgets.entitlements`. A container is only
    /// shared if both sides claim it; drop it from either and this write
    /// lands in the app's private container, the widget reads nothing, and
    /// its `?? "cat"` fallback holds for everybody.
    static let suiteName = "group.com.pawmodoro"

    /// Deliberately *not* in `StorageKeys`: these are a mirror, not state.
    /// The app never reads them back, and `-PawmodoroResetState` has nothing
    /// to clear — the next `sync` overwrites both.
    static let buddyKey = "widget.buddy"
    static let placeKey = "widget.place"

    /// Mirror what the widget draws, and redraw it if it moved.
    ///
    /// - Returns: whether anything was written. Only the tests-by-eye care;
    ///   every real caller ignores it.
    @discardableResult
    static func sync(buddy: String, place: String) -> Bool {
        guard let suite = UserDefaults(suiteName: suiteName) else { return false }
        let sameBuddy = suite.string(forKey: buddyKey) == buddy
        let samePlace = suite.string(forKey: placeKey) == place
        if sameBuddy && samePlace { return false }

        suite.set(buddy, forKey: buddyKey)
        suite.set(place, forKey: placeKey)

        // Only the buddy is drawn today; the place is mirrored ahead of a
        // widget that wants it. Reloading on a place change too costs one
        // redraw on an event that happens a handful of times a month, and
        // means the day a widget starts reading `widget.place` it is already
        // fresh rather than stale for hours in a way nobody would connect to
        // this line.
        reload()
        return true
    }

    /// Ask the system to rebuild the home widget's timeline now.
    ///
    /// Separate from `sync` so the one legitimate ungated caller — a place or
    /// buddy that changed without going through the mirror — has a door, and
    /// so the `#if` lives in exactly one body.
    static func reload() {
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
