import Foundation

/// The first time you open the app on a new day.
///
/// The buddy stretches, looks up, and says something. That is the whole
/// feature, and it is the one place in this app where the gentle streak's
/// philosophy is *animated* rather than merely obeyed:
///
/// **Return is always celebrated. Absence is never mentioned.**
///
/// Come back after four months and the buddy is *gladder*, not colder. There
/// is no line anywhere in here about where you were, no "it's been a while",
/// no counter that reset while you were gone. The longer the gap the warmer
/// the greeting, which is the exact opposite of what every retention system
/// ever built does, and it is the point.
///
/// ### What it is not
///
/// - **Not a daily reward.** Nothing is granted, no streak advances, no acorn
///   falls. It is a hello.
/// - **Not a notification.** Nothing tells you to come and be greeted. You
///   find it because you opened the app, which you were doing anyway.
/// - **Not missable.** It waits. Open the app at eleven at night and the day's
///   greeting is still there, because it is keyed to the day rather than to
///   the hour — see `Warmth.dawn`, which is about the *first* opening rather
///   than about being up early.
enum Greeting {

    /// How pleased the buddy is, which depends only on how long it has been.
    ///
    /// The thresholds go up. That is the whole table and it is the whole
    /// argument: there is no arm here that gets less warm.
    enum Warmth: String, CaseIterable, Codable {
        /// You were here yesterday.
        case daily
        /// A couple of days.
        case away
        /// A week or more. The gladdest one there is.
        case gladder
        /// The first opening ever, or the first since a reset. Its own arm
        /// because "welcome back" to somebody who has never been here is the
        /// kind of small wrongness that makes an app feel like a form.
        case first

        /// Whole days since the last session, and the smallest gap that earns
        /// this greeting.
        var reachedAt: Int {
            switch self {
            case .daily: 0
            case .away: 2
            case .gladder: 7
            // Never matched by a gap — `for(daysAway:hasSat:)` picks it from
            // the absence of any history at all.
            case .first: Int.max
            }
        }

        /// The caption, which never names the buddy — that has to come from
        /// `settings.displayName(for:)` at the call site, and a model type
        /// cannot reach it. Each is written to be true whether it has been a
        /// day or a decade.
        var line: String {
            switch self {
            case .first: "is deciding what to make of you."
            case .daily: "stretched, and looked up."
            case .away: "got up when the door went."
            // The gladdest line in the app, and it is careful. It says what
            // the buddy did, not what you failed to do — "looked up before you
            // even sat down" is a fact about an animal being pleased. Any
            // sentence here that referred to the gap would turn four months
            // away into something to apologise for.
            case .gladder: "looked up before you even sat down."
            }
        }

        /// How long the greeting holds the screen before the ordinary caption
        /// comes back. Longer for the warmer ones, because they are rarer and
        /// because a stretch that ends in two seconds reads as a glitch.
        var seconds: TimeInterval {
            switch self {
            case .daily: 3.0
            case .away: 3.5
            case .gladder: 4.5
            case .first: 4.0
            }
        }
    }

    /// Which greeting is owed, from the gap and whether there is any history.
    ///
    /// Written as a pure function of two numbers so `tools/check_greeting.py`
    /// can walk every gap from zero to a thousand days and assert the one
    /// property that matters: **warmth never goes down.**
    static func `for`(daysAway: Int, hasSat: Bool) -> Warmth {
        guard hasSat else { return .first }
        // Walked warmest-first, so the table reads in the direction it is
        // written in and adding an arm cannot silently be shadowed by an
        // earlier one.
        for warmth in [Warmth.gladder, .away, .daily]
        where daysAway >= warmth.reachedAt {
            return warmth
        }
        return .daily
    }

    /// The pose. The stretch every buddy already has, and the ordinary resting
    /// frame for the two that do not — `BuddyFrames`' standing rule, applied
    /// here rather than branching in the view.
    static let poseSuffix = "stretch"
}

/// Whether today's greeting has been shown.
///
/// One stored date and nothing else. Not a counter, not a streak, not a
/// history — the app already has the session log if it ever wants to know how
/// often somebody comes back, and a second record of the same thing is a
/// second thing to keep in step.
///
/// Deliberately *not* merged across devices: greeting somebody twice on two
/// machines is a nicer failure than greeting them on neither, and a `Date`
/// that only ever moves forward is the one kind of state this app has decided
/// is not worth syncing. See `Crossing.swift`.
struct GreetingLog {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The last day a greeting was shown, at the world's midnight.
    var lastGreeted: Date? {
        defaults.object(forKey: StorageKeys.greeted) as? Date
    }

    func isOwed(on day: Date = WorldCalendar.today) -> Bool {
        guard let last = lastGreeted else { return true }
        return WorldCalendar.startOfDay(last) < WorldCalendar.startOfDay(day)
    }

    func noteGreeted(on day: Date = WorldCalendar.today) {
        defaults.set(WorldCalendar.startOfDay(day), forKey: StorageKeys.greeted)
    }
}
