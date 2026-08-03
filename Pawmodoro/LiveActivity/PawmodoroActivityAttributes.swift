import ActivityKit
import Foundation

/// What the lock screen and the Dynamic Island are told about a running phase.
///
/// **This file needs two target memberships.** It lives in the app target
/// because `LiveActivityController` builds it, and in `PawmodoroWidgets`
/// because the widget reads it. Select it in the Project navigator and tick
/// both under Target Membership — everything else about the Live Activity is
/// already wired, and this is the one file that has to be in two places.
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
}
