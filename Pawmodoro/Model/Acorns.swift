import Foundation

/// The pouch: what the wood drops for sitting still.
///
/// ### The balance is derived, not stored
///
/// There is no acorn counter anywhere in this app, and there must never be
/// one. What you have earned is a pure function of the focus minutes already
/// in the session log; what you have left is that, minus the price of
/// everything you own. Two consequences, both of them the reason it is built
/// this way:
///
/// - **Nothing can fall out of step.** The grove counts the same minutes, the
///   bond counts the same sessions, and `-PawmodoroBond 200` seeds a full
///   pouch without knowing this file exists. A stored balance would be a
///   third opinion about how much you have focused, and the day it disagreed
///   with the other two there would be no way to say which was right.
/// - **It backfills.** The day this ships, somebody two years in opens the
///   app and finds a pouch with everything those two years earned in it. The
///   Year Ring shipped already old for the same reason, and it is the nearest
///   thing this app has to a thank-you.
///
/// ### And it cannot be farmed
///
/// Minutes, not sessions. `PomodoroSettings` clamps a focus phase to 5...90
/// minutes, so a five-minute session is worth a quarter of a twenty-five, and
/// the shortest-session grind that every points economy invites simply does
/// not pay. Only completed focus reaches the log at all — leaving early has
/// always earned nothing, and that rule is inherited rather than restated.
///
/// ### The divisor is a compatibility contract
///
/// Moving `minutesPerAcorn` re-prices everybody's entire history at once:
/// somebody who could afford the fox this morning cannot this afternoon.
/// `tools/check_catalog.py` holds it in a stored fixture alongside the price
/// table, and the answer to a failure there is almost always "no, I did not
/// mean to do that". Same discipline as `Grove.position` and
/// `WorldCalendar.seed`, and for the same reason.
enum Acorns {

    /// Focus minutes per acorn. **Do not change this.** See above.
    ///
    /// Twenty puts a standard twenty-five-minute session at one acorn and a
    /// bit, and a steady two-hours-a-day habit at five or six a day — which
    /// is what the price table in `CatalogItem` is tuned against. The two
    /// numbers only mean anything together.
    static let minutesPerAcorn = 20

    /// Everything the wood has ever dropped, for a lifetime of focus minutes.
    static func earned(minutes: Int) -> Int {
        max(0, minutes) / minutesPerAcorn
    }

    /// What is left after what you own.
    ///
    /// Floored at zero rather than allowed to go negative, which matters for
    /// exactly one path: clearing your history erases the *earned* side while
    /// owned items survive, because a purchase is a thing you have and this
    /// app does not take those back. The pouch reads empty and everything
    /// bought is still yours.
    static func balance(minutes: Int, spent: Int) -> Int {
        max(0, earned(minutes: minutes) - spent)
    }

    /// How many more minutes until `count` acorns are in hand. Nil once they
    /// already are.
    ///
    /// Phrased in minutes rather than sessions on purpose — the unlock sheet
    /// turns it into "about a week of afternoons", which is an observation
    /// about a distance, and "6 more sessions" is a target. Same distinction
    /// the grove's "the next is about 38 minutes away" is built on.
    static func minutesUntil(_ count: Int, minutes: Int, spent: Int) -> Int? {
        let short = count - balance(minutes: minutes, spent: spent)
        guard short > 0 else { return nil }
        return short * minutesPerAcorn
    }
}
