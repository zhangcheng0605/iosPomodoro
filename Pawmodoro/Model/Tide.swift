import Foundation

/// The sea at Harbor Isle, which goes in and out.
///
/// The app already models the moon, and the moon already moves the sea. This
/// is that consequence, made visible — the one system here that is a *real*
/// natural rhythm rather than an invented one, and the only thing in the app
/// that changes on the scale of hours rather than days.
///
/// ### Why it is worth having at all
///
/// Every other gate in this app is a *day* gate. The weather is a day, the
/// season is a fortnight, a passage is a fortnight, the moon is three nights.
/// A tide is the first thing that makes **which hour you sat down** matter for
/// a reason that is not the colour of the sky — and it is the only one that
/// rewards coming back the same afternoon rather than the next day. Half a
/// dozen animals live in the strip of shore that only exists for a couple of
/// hours at a time.
///
/// ### The model, and how honest it is
///
/// Semidiurnal M2 — two highs and two lows in each 24h50m lunar day, which is
/// why high water is about fifty minutes later each day. The *range* between
/// them follows the moon: biggest at new and full (springs), smallest at the
/// quarters (neaps). That is genuinely how tides work and it is two lines of
/// arithmetic.
///
/// What it is not: real. There is no harmonic constituent beyond M2, no
/// shallow-water correction, no actual place on Earth. Harbor Isle has its own
/// sea for the same reason it has its own weather — no permission prompt, no
/// network call, no location. The number below is a promise about a fictional
/// coast, kept exactly.
///
/// ### And nothing here is ever announced
///
/// No notification when the tide turns, ever. The almanac says what the water
/// is doing if you open it; that is all. A push saying *the octopus pools are
/// out for the next ninety minutes* is the most effective retention message
/// this app could send and it is exactly the kind this app does not send.
enum Tide {

    /// A lunar semidiurnal period: 12h 25m 14s.
    static let period: TimeInterval = 12 * 3600 + 25 * 60 + 14

    /// The establishment of the port — the lag between the moon overhead and
    /// high water here. Every real harbour has one and it is what makes a
    /// tide *local*; three hours is unremarkable for a sheltered bay.
    ///
    /// Arbitrary, and then frozen. Changing it moves every tide this app has
    /// ever shown, which makes it exactly the sort of number
    /// `tools/check_tide.py` keeps a stored fixture for.
    static let establishment: TimeInterval = 3 * 3600

    /// The same instant `MoonPhase` counts from — a new moon, so springs line
    /// up with the reference rather than falling half a cycle out of it.
    private static let reference = Date(timeIntervalSince1970: 947_182_440)

    // MARK: The water

    /// How high the water is, 0 at the lowest astronomical tide and 1 at the
    /// highest. Never quite reaches either: those are the extremes of the
    /// *range*, and the range only opens fully at a perfect spring.
    static func level(at date: Date = WorldCalendar.now) -> Double {
        if let forced = LaunchOptions.forcedTide { return forced }

        // Springs at new *and* full — hence the absolute value. `MoonPhase.age`
        // is 0 at new and 0.5 at full, so `cos(2π·age)` is ±1 at both and 0 at
        // the quarters, which is the spring–neap cycle exactly.
        let springness = abs(cos(2 * .pi * MoonPhase.age(on: date)))
        let range = 0.25 + 0.75 * springness

        let elapsed = date.timeIntervalSince(reference) - establishment
        let swing = cos(2 * .pi * elapsed / period)
        return 0.5 + swing * range / 2
    }

    /// What that height is called. The stage is what everything else asks
    /// about — species eligibility, the shore strip, the almanac's line — so
    /// the thresholds live here once rather than as four comparisons scattered
    /// across the app.
    enum State: String, CaseIterable, Codable {
        /// The lowest water there is. A few days either side of new and full
        /// moon, and only for an hour or so around each low. Everything
        /// interesting lives here.
        case springLow
        case low
        case mid
        case high

        /// Lower bound, inclusive. Read in order by `Tide.state(at:)`.
        var floor: Double {
            switch self {
            case .springLow: 0.00
            case .low: 0.08
            case .mid: 0.28
            case .high: 0.72
            }
        }

        var name: String {
            switch self {
            case .springLow: "Spring low"
            case .low: "Low water"
            case .mid: "Half tide"
            case .high: "High water"
            }
        }

        /// The almanac's sentence. About the water, never about the reader,
        /// and never about what is out there — naming the animals would turn
        /// a tide table into a to-do list.
        var line: String {
            switch self {
            case .springLow:
                "The water is as far out as it goes. There is a whole other "
                    + "beach down there, and it will not be there long."
            case .low:
                "Out, and still going. The rocks are showing."
            case .mid:
                "Halfway, and moving."
            case .high:
                "Right up to the wall. The dock is a foot above it."
            }
        }

        /// A shorter phrase, for the journal's hint under an unseen species.
        var hintPhrase: String {
            switch self {
            case .springLow: "at the very lowest water"
            case .low: "at low tide"
            case .mid: "at half tide"
            case .high: "at high water"
            }
        }
    }

    /// Named `State` rather than `Stage` because `Stray.Stage` exists and
    /// `check_swift.py` matches enums on their simple name — two `Stage`s and
    /// it can no longer tell their switches apart, so its exhaustiveness rule
    /// goes quietly blind on both. It refused this file until the rename.
    static func state(at date: Date = WorldCalendar.now) -> State {
        let water = level(at: date)
        // Walked from the top so the bands read as written: the first floor
        // the water clears is the answer.
        for state in [State.high, .mid, .low, .springLow] where water >= state.floor {
            return state
        }
        return .springLow
    }

    /// The phrase the journal's hint uses for a set of states.
    ///
    /// Not simply the first of them. A species out at `[.low, .springLow]` is
    /// findable at any low water and saying "the very lowest" would send
    /// somebody to wait a fortnight for something that was there this
    /// afternoon; one at `[.mid, .high]` is best described by the high. So the
    /// rule is *name the end of the range it belongs to*, and it is written
    /// here rather than at the call site because it is a fact about tides.
    ///
    /// `nil` for a species that needs no particular water, and for one that
    /// accepts every state — a hint saying "at any tide" is a hint that has
    /// wasted the reader's time.
    static func hint(for states: [State]) -> String? {
        guard !states.isEmpty, states.count < State.allCases.count else {
            return nil
        }
        if states.contains(.high) { return State.high.hintPhrase }
        if states.contains(.low) { return State.low.hintPhrase }
        return states[0].hintPhrase
    }

    /// Whether the water is coming in. Used for one word in the almanac and
    /// nothing else — a tide that is out and rising is a different afternoon
    /// from one that is out and still falling, and that is worth a word.
    static func isRising(at date: Date = WorldCalendar.now) -> Bool {
        level(at: date.addingTimeInterval(300)) > level(at: date)
    }

    /// When the water next turns, looking forward at most one full period.
    ///
    /// Ten-minute steps rather than solving for it: the derivative of a cosine
    /// is not hard, but `LaunchOptions.forcedTide` pins `level` to a constant
    /// and a closed form would sail straight past that and report a turn that
    /// the rest of the app disagrees with. Sampling asks the same function
    /// everything else asks.
    static func nextTurn(after date: Date = WorldCalendar.now) -> Date? {
        guard LaunchOptions.forcedTide == nil else { return nil }
        let step: TimeInterval = 600
        let rising = isRising(at: date)
        var when = date
        while when.timeIntervalSince(date) < period {
            when = when.addingTimeInterval(step)
            if isRising(at: when) != rising { return when }
        }
        return nil
    }

    // MARK: Where the shore is

    /// How far up the beach the water sits, as a fraction of the scene's
    /// height. Only ever used at Harbor Isle.
    ///
    /// The band is narrow on purpose. A tide that visibly swallowed half the
    /// picture would make the scene look like two different places rather than
    /// like one place at two times, and the scene exports — which are drawn
    /// once and graded four ways — have a fixed horizon it has to live under.
    static let waterline: (lowest: Double, highest: Double) = (0.88, 0.79)

    static func waterline(at date: Date = WorldCalendar.now) -> Double {
        let water = level(at: date)
        return waterline.lowest + (waterline.highest - waterline.lowest) * water
    }
}
