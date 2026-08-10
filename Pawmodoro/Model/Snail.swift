import CoreGraphics
import Foundation
// For `DynamicTypeSize` alone. The furniture she has to clear is the app's,
// and how deep it is depends entirely on how big the reader has set the text —
// see `chromeDepth(at:)`.
import SwiftUI

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
    /// comes out at 38pt.
    ///
    /// What no value of this number can fix is a screen with no room left
    /// under it — see `requiredFooting(at:)`, which is where the iPhone SE
    /// went, and where the accessibility text sizes went after it.
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

    // MARK: - The app's own floor
    //
    // `groundRow` puts her on the same painted pixel of the artwork on every
    // device, which is what keeps her on the ground. It cannot also keep her
    // off the app, because the app's furniture is not painted into the
    // artwork: the ambience chips, the photograph chip and the transport are
    // stacked up from the **bottom of the layer** she is drawn in. The
    // artwork, meanwhile, is `scaledToFill`, so how much of it falls below her
    // feet depends only on the shape of that layer. The two are unrelated, and
    // where they meet is the only place she can end up standing on a button.
    //
    // ### The version of this that was one number, and why it failed
    //
    // This used to be `minimumFooting = 198`: 196 points of furniture, plus
    // two of daylight. Both halves were real and both were measured — on four
    // phones, at the **ordinary reading size**, which is the whole of the bug.
    // Every piece of that furniture answers Dynamic Type. Measured off the
    // painted chips themselves, on the iOS 26.3 simulator, 10 Aug 2026, on
    // the `ordinaryColumn`/`adaptiveColumn` layout that then shipped:
    //
    //     text size      furniture     198 was short by
    //     .large           196.0pt        —
    //     .xLarge          197.7pt       1.7
    //     .xxLarge         207.3pt      11.3
    //     .xxxLarge        216.7pt      20.7
    //     accessibility    232.7pt      36.7
    //
    // So at `.xxLarge` and above — a plain Text Size setting on an iPhone 16,
    // no accessibility slider involved — the gate said "there is room" and
    // there was not: photographed, she stands on the top edge of the third
    // ambience chip. A constant tuned at one text size is not a measurement of
    // a layout that has a text size in it.
    //
    // What is below is that same furniture, arithmetic rather than a number.
    // Every term is `ContentView`'s own, and `check_snail.py` parses them out
    // of `ContentView.swift` and fails if this drifts from them — at *every*
    // size, not one. That check is not decoration: `ContentView` gained a
    // sixteen-point transport floor and dropped `ambienceGap` from 22 to 12
    // *while this fix was being written*, and the arithmetic below was wrong
    // for about an hour until the check said so.
    //
    // It is still a copy of another file's layout, which is a thing this repo
    // is right to distrust. The cure is `SnailView` being *told* where the
    // furniture is rather than working it out: one `PreferenceKey` written by
    // `ContentView.ambienceRow` carrying the top of its own frame, read here,
    // and every term below goes away along with the check that guards them.
    // That is a `ContentView` change and it has not been made.

    /// `ContentView.adaptiveColumn`'s transport floor: the daylight the play
    /// button buys itself off the bottom edge of the glass.
    static let transportFloor: Double = 16

    /// The transport row: the play button is the tallest thing in it. Fixed
    /// points, not scaled — `ContentView.controls` sets the three circles'
    /// frames outright.
    static let transportHeight: Double = 84

    /// The backing behind one ambience glyph at the ordinary reading size,
    /// which is `ContentView.chipHeight` before `chipScale`.
    static let chipBacking: Double = 32

    /// What `ContentView.chipTarget` adds to that backing vertically, and the
    /// floor it never goes below — a 44 point target, whatever the text size.
    static let chipPadding: Double = 12
    static let minimumTarget: Double = 44

    /// `ContentView.ambienceRow`'s own `VStack` spacing, between the chips and
    /// the photograph chip under them.
    static let rowSpacing: Double = 4

    /// The daylight she keeps between herself and anything the app draws.
    ///
    /// Two points, not zero. Zero would allow a snail whose shell is touching
    /// the corner of a chip, which is the picture this whole gate exists to
    /// stop.
    static let clearance: Double = 2

    /// `ContentView.chipScale` — how much bigger the glyph chips get as the
    /// text does. 1.0 at every ordinary reading size through `.large`, then a
    /// short ladder on a leash.
    static func chipScale(at textSize: DynamicTypeSize) -> Double {
        switch textSize {
        case .xSmall, .small, .medium, .large: 1.0
        case .xLarge: 1.15
        case .xxLarge: 1.3
        case .xxxLarge: 1.45
        default: 1.7
        }
    }

    /// `ContentView.ambienceGap` — the gap it leaves above the transport.
    /// The sky between the rows is what gives way when the text grows.
    static func ambienceGap(at textSize: DynamicTypeSize) -> Double {
        textSize <= .large ? 12 : 14
    }

    /// How deep the app's furniture is, from the bottom of the layer up to the
    /// **painted** top edge of the ambience chips.
    ///
    /// Built the way `ContentView` builds it, upwards from the bottom edge of
    /// the glass: the transport's floor, the three circles, the air above
    /// them, the photograph chip's hit target, the row's own spacing, the
    /// ambience chips' hit target — less the inset between that target and the
    /// ink inside it, because a snail may stand on an invisible 44 point hit
    /// area and may not stand on a chip.
    static func chromeDepth(at textSize: DynamicTypeSize) -> Double {
        let chip = chipBacking * chipScale(at: textSize)
        let row = max(minimumTarget, chip + chipPadding)
        let inset = (row - chip) / 2
        return transportFloor + transportHeight + ambienceGap(at: textSize)
            + row + rowSpacing + row - inset
    }

    /// How much meadow has to be left under her feet before she comes at all.
    ///
    /// Points, from her foot line down to the bottom edge of the layer she is
    /// drawn in. Below this she is somewhere else this month.
    static func requiredFooting(at textSize: DynamicTypeSize) -> Double {
        chromeDepth(at: textSize) + clearance
    }

    /// Whether the layer she would be drawn in leaves room for her.
    ///
    /// The same box `SnailView` hands `feetY`, so the two can never disagree.
    ///
    /// ### She is absent from most phones now, and that is the answer
    ///
    /// Measured on the iOS 26.3 simulator, place `peaks`, `-PawmodoroSnail 50`,
    /// 10 Aug 2026, against `ContentView`'s single adaptive column. The layer
    /// box is read out of `SnailView`'s own `GeometryReader`; room is that
    /// box's height less her foot line, and it does not move with the text
    /// size because her feet do not:
    ///
    ///                             layer box    room    here up to
    ///     iPhone SE (3rd gen)      375 x 667   118pt   nowhere
    ///     iPhone 13 mini           375 x 812   190pt   nowhere
    ///     iPhone 16e               390 x 844   197pt   nowhere
    ///     iPhone 16                393 x 852   200pt   nowhere (short by 0.4)
    ///     iPhone 17 Pro            402 x 874   205pt   .large
    ///     iPhone 17 Pro Max        440 x 956   224pt   .xxLarge
    ///     Mac, smallest window     460 x 700   234pt   .xxLarge
    ///
    /// against a furniture depth of 198pt at `.large`, 211.6 at `.xLarge`,
    /// 221.2 at `.xxLarge`, 230.8 at `.xxxLarge` and 246.8 at every
    /// accessibility size, all including the two points of `clearance`.
    ///
    /// That is a far shorter list than it used to be, and two things took it
    /// there, both of them `ContentView`'s and neither of them wrong: the
    /// transport bought itself a sixteen-point floor off the bottom edge, and
    /// the column stopped overflowing — where the `ZStack` used to grow past
    /// the glass and hand her the extra, the layer is now exactly the screen.
    /// An iPhone 16 misses by four tenths of a point.
    ///
    /// No ground row fixes the ones that say nowhere, and the ones it *could*
    /// fix are not this file's to trade. The standable band is rows 209…226
    /// (measured, every x of every scene she visits); row 218 would put her
    /// back on an iPhone 16 at `.large` with 4.6pt clear, and above 209 she is
    /// standing on sky. `groundRow` says what 219 buys and who owns that
    /// choice. Meanwhile the honest answer is the one the meadow has always
    /// allowed: **she is crossing somewhere else.** She keeps no state, so
    /// nothing is lost and nothing has to be migrated — the same sentence as
    /// any month she spends out of sight. That is why the gate is the
    /// *question* "is there room" rather than a nudge to her position: the
    /// worst it can do is take her away, and never put her on a button.
    ///
    /// ### It asks about the idle screen, always
    ///
    /// The photograph chip is gone during a focus phase, so the furniture is
    /// some fifty points shallower then, and there are screens she would fit
    /// on while the timer runs. She is not offered them. A snail who arrived
    /// when you pressed start and left when you stopped would be an animation,
    /// and this one is a thing you notice was there all along.
    ///
    /// ### The one thing this still does not fix
    ///
    /// The layer is not guaranteed to be the screen. It is the `ZStack`'s box,
    /// and the `ZStack` grows if any layer in it ever overflows again — which
    /// `ordinaryColumn` did until this week, by ten points on an iPhone 16 and
    /// a hundred and twenty-six on an SE. Nothing here would notice; the gate
    /// would simply hand her the extra room and she would still be standing on
    /// the ground of the artwork. It is `check_snail.py`'s measured `PHONES`
    /// fixture that notices, and its answer is *re-measure*.
    static func hasFooting(in size: CGSize, bottomAnchored: Bool,
                           textSize: DynamicTypeSize) -> Bool {
        size.height - feetY(in: size, bottomAnchored: bottomAnchored)
            >= requiredFooting(at: textSize)
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
