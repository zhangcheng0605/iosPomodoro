import CoreGraphics
import Foundation

/// The old snail, who is crossing.
///
/// The countdown is a position: the boat leaves when you start and docks on
/// the chime. This is that idea at the other end of the telescope. She is also
/// a position that is purely a function of time — but her crossing takes six
/// months, so on any given day she has not moved in any way you could notice,
/// and by the time the leaves turn she is somewhere else entirely.
///
/// She cannot be hurried. There is nothing to tap, nothing to feed, nothing
/// that goes wrong if you never look. She is not for sale, she is never
/// announced, and no notification will ever mention her. The whole design is
/// for one person, once, to say *hold on, was that there before?* — and then
/// to start checking.
///
/// Everything about her is derived from the calendar day and the place, so
/// there is no state to keep, nothing to migrate, and reinstalling the app
/// puts her back exactly where she was.
enum Snail {

    /// Where her shell sits, as a fraction of screen height — her **feet**,
    /// not her middle, which is the lesson `Stray.groundLine` paid for.
    ///
    /// Deliberately the same value as the stray's, and not by coincidence:
    /// `tools/check_snail.py` searched every hundredth of the screen on both a
    /// tall phone and a short one, and 0.79 is inside the standable band of
    /// all five places she visits. That it is also where the cat sits is the
    /// nice part — it is the same ground.
    ///
    /// She is harder to place than the stray, and the reason is worth knowing:
    /// the stray stands at three fixed x positions, so a line only has to be
    /// ground in three places. The snail visits *every* x, so a line has to be
    /// ground across the whole width. That is what rules three places out
    /// below.
    static let groundLine: Double = Stray.groundLine

    /// Must match the aspect she is drawn at in `tools/generate_sprites.py`,
    /// or `scaledToFit` letterboxes her.
    static let size = CGSize(width: 18, height: 13)

    /// How long one crossing takes, and how long until the next.
    ///
    /// Six months across, six months away — she is crossing somewhere else,
    /// which is a bigger meadow than the one you can see. 364 rather than 365
    /// so the year drifts a day and a bit each time round: she should come
    /// back at *about* the same time of year, not on an anniversary. Nothing
    /// in this app is allowed to feel like a schedule.
    static let crossingDays = 182
    static let cycleDays = 364

    /// Fixed for all time, because her position is a promise about the past in
    /// exactly the way the weather is. It is only ever fed to
    /// `WorldCalendar.seed` to give each place a different starting offset, so
    /// she is not in lockstep across the world.
    private static let phaseEpoch = Date(timeIntervalSince1970: 1_577_836_800)

    /// How far across this place she is today, or nil if she is elsewhere.
    ///
    /// 0 at the near edge, 1 at the far one. About half a percent of the
    /// screen a day, which is roughly two points — invisible between one
    /// session and the next, and unmistakable between one month and the next.
    static func progress(at place: Place, on day: Date = WorldCalendar.today) -> Double? {
        guard place.snailVisits else { return nil }
        let offset = Int(
            WorldCalendar.seed(day: phaseEpoch, place: place, salt: "snail")
                % UInt64(cycleDays)
        )
        let elapsed = WorldCalendar.dayNumber(day) + offset
        // `%` on a negative Int is negative in Swift, and day numbers before
        // 2020 are negative. Without the second modulo she vanishes for
        // anybody whose device clock is set to the last century, which is a
        // silly case that costs one line to be right about.
        let phase = ((elapsed % cycleDays) + cycleDays) % cycleDays
        guard phase < crossingDays else { return nil }
        return Double(phase) / Double(crossingDays - 1)
    }

    /// Where she is on screen, as a fraction of width, or nil if she is not
    /// here today. Kept clear of both edges so she is never half a snail.
    static func x(at place: Place, on day: Date = WorldCalendar.today) -> Double? {
        progress(at: place, on: day).map { 0.04 + $0 * 0.92 }
    }

    /// Whether she is crossing this place today at all.
    static func isVisible(at place: Place, on day: Date = WorldCalendar.today) -> Bool {
        progress(at: place, on: day) != nil
    }

    /// The frame she is drawn as. Two of them, swapping about once a second —
    /// which is not her moving, only her deciding to.
    static let frames = ["snail_0", "snail_1"]
}

extension Place {
    /// Whether the snail crosses here.
    ///
    /// Measured, not chosen. `tools/check_snail.py` walks every x of every
    /// scene at her ground line and asks the same question `check_stray.py`
    /// asks: is there something under her feet? The three that say no say it
    /// for reasons you could have guessed from the art and nobody did:
    ///
    /// - **Cloudspire** is a city on clouds. There is no continuous ground at
    ///   any height — the best row in the whole scene is 62 % solid.
    /// - **Harbor Isle** is an island. Past the shore it is open sea, which is
    ///   the exact hazard that caught the stray sitting on the water.
    /// - **The Onsen** has a hot spring across the middle of it. Three of the
    ///   fifty-six candidate ground lines clear it, all of them awkward, and
    ///   any redraw of that scene would take them away. Better absent than
    ///   fragile.
    ///
    /// She is not diminished by this. A snail who cannot get to the floating
    /// city is a snail.
    var snailVisits: Bool {
        switch self {
        case .cloudspire, .harbor, .onsen: false
        default: true
        }
    }
}
