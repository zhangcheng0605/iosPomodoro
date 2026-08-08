// Live Activities are iOS-only by construction — see `Platform.swift`, which
// keeps the whole list of what the two platforms do not share. The type is
// fenced rather than stubbed because nothing on the Mac can reach it: the
// only reader is `LiveActivityController`, whose macOS bodies are empty.
#if os(iOS)
import ActivityKit
import Foundation

/// What the lock screen and the Dynamic Island are told about a running phase.
///
/// **This file is in two targets.** It lives in the app target because
/// `LiveActivityController` builds it, and in `PawmodoroWidgetsExtension`
/// because the widget reads it. Both memberships are recorded in
/// `project.pbxproj` — the app's folder is a file-system synchronized group,
/// so the second membership is a `PBXFileSystemSynchronizedBuildFileExceptionSet`
/// naming this one path rather than a build-file entry. Moving or renaming the
/// file breaks that reference silently, and the extension stops compiling.
struct PawmodoroActivityAttributes: ActivityAttributes {
    /// Values that change while the activity is live.
    ///
    /// `endDate` rather than a remaining count, for the same reason
    /// `TimerEngine` works from an absolute end date: the system draws the
    /// countdown itself from this, so the activity stays exactly right with no
    /// push notifications and no background updates at all.
    struct ContentState: Codable, Hashable {
        var phaseTitle: String
        var isBreak: Bool
        var endDate: Date
    }

    /// Fixed for the life of the activity. The buddy's *display* name, so a
    /// renamed buddy reaches the lock screen like it reaches everywhere else.
    var buddyName: String

    /// `Buddy.rawValue`, which is also the sprite's asset prefix — the widget
    /// draws `buddy_<id>_asleep` / `_awake` from its own catalog.
    ///
    /// The id travels *beside* the display name rather than instead of it: the
    /// name is the user's and can be anything, the id is the species and is the
    /// only thing that picks a picture. A `String` rather than the `Buddy` enum
    /// because the extension does not build the app's model layer, and because
    /// an id the widget has no sprite for has to degrade rather than fail to
    /// decode — a buddy added in a later version must not break the lock screen
    /// of a phone whose extension is the older build.
    var buddyID: String
}
#endif
