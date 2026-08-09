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

    /// The shape every scene is drawn at, in `tools/generate_scenes.py`'s own
    /// grid units. Every place is exported at this aspect and drawn
    /// `scaledToFill`, so this is the only thing needed to turn a row of the
    /// artwork into a row of the screen. `check_snail.py` asserts it against
    /// `generate_scenes.W/H` rather than trusting it.
    static let sceneSize = CGSize(width: 132, height: 286)

    /// The row of the **artwork** her feet stand on — not a fraction of the
    /// screen, and that difference is the whole of a bug.
    ///
    /// She used to be placed at 0.79 of the screen, the same line the stray
    /// stands on. It read as one number doing one job and it was two:
    ///
    /// * **The ground moved under her.** A screen fraction lands on a
    ///   different row of the artwork on every shape, because the scene is
    ///   `scaledToFill`. Measured: 0.79 was scene row 226 on an iPhone 17 Pro,
    ///   row 236 on an iPhone SE and somewhere else again on a Mac window the
    ///   owner had dragged taller. Keeping her on the ground therefore meant
    ///   finding a fraction that was standable on *three* aspects at once, and
    ///   the intersection of those three was a band twelve thousandths of the
    ///   screen wide — 0.779…0.791, with nothing whatever above it.
    /// * **She stood on the app.** That sliver is exactly where the ambience
    ///   chips sit on the idle screen, and their backing is translucent, so
    ///   she showed *through* the fourth chip and read as climbing on the UI.
    ///   Seen on macOS (`MAC_STORE_ASSETS.md` § 3.3) and then on both an
    ///   iPhone 17 Pro and an iPhone SE. During a focus phase the row sits
    ///   lower and she cleared it, which is why it hid for so long.
    ///
    /// Pinning her to a row of the artwork unties the two. She now stands on
    /// the same painted pixel on every device and at every window size — which
    /// is what "she is standing on the ground" was always supposed to mean —
    /// and the standable band widens from that sliver to rows 208…225, wide
    /// enough that a line clearing the chrome exists at all.
    ///
    /// 219 is measured, not chosen, and it is a *trade* rather than a maximum.
    /// The row with the largest clearance from chrome is 215 (about 19pt clear
    /// on both phones); 219 keeps 7pt, which is still over half her own
    /// height below the ambience chips, and buys the thing 215 could not: on a
    /// tall phone she passes *below* the treat tray rather than behind it.
    /// Being hidden is its own failure — a hundred and twenty trees buried
    /// eight residents once already — and the treats are three opaque sprites
    /// covering a third of the crossing, which is nine weeks of a six-month
    /// walk spent invisible. On an iPhone SE the two cannot both be had: the
    /// two phones' layouts are three and a half scene rows apart, so there she
    /// still grazes the underside of the tray. That is written down rather
    /// than smoothed over, and `check_snail.py` reports it every run.
    ///
    /// Photographed rather than believed. On an iPhone 17 Pro her foot line
    /// lands on screen row 2007 of 2622 against the 2008 this predicts, and
    /// the chips' painted edge is 21 device pixels below it — the 7pt above,
    /// measured off the glass, at x = 0.13, 0.50 and 0.92 and in both a
    /// running phase and an idle screen. On a Mac window the same arithmetic
    /// comes out at 38pt. **On an iPhone SE it is still wrong**, and not by
    /// any fault of this number: the main column overflows that screen by
    /// about 68pt, every layer in the stack is handed the overflowing box,
    /// and she is drawn inside the fourth chip. `check_snail.py`'s
    /// `KNOWN_BROKEN` has the evidence; the fix is in `ContentView`.
    ///
    /// She is harder to place than the stray, and the reason is worth knowing:
    /// the stray stands at three fixed x positions, so a line only has to be
    /// ground in three places. The snail visits *every* x, so a line has to be
    /// ground across the whole width. That is what rules three places out
    /// below.
    static let groundRow: Double = 219

    /// Where her feet land, in the coordinates of the layer she is drawn in.
    ///
    /// The same arithmetic `SceneryView` hands to `scaledToFill` — including
    /// its `fillAnchor`, which is `.bottom` on the desktop and `.center` on a
    /// phone. Getting that wrong would put her on the ground of an artwork
    /// nobody is looking at.
    static func feetY(in size: CGSize, bottomAnchored: Bool) -> Double {
        let scale = max(size.width / sceneSize.width,
                        size.height / sceneSize.height)
        let drawn = sceneSize.height * scale
        let originY = bottomAnchored
            ? size.height - drawn
            : (size.height - drawn) / 2
        return originY + groundRow * scale
    }

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
