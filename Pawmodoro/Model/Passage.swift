import Foundation

/// The Flyway — the eight things that only pass through.
///
/// Everything else in this app is reachable by deciding something: go to the
/// woods, sit at dawn, focus for forty minutes, wait for it to rain. A passage
/// is the first thing here that is reachable only by **being alive on the
/// right fortnight**. The swans go over in late February whether or not
/// anybody sat still for them, and in the second week of March they are in
/// Iceland and that is that until next year.
///
/// That is a real feeling and the reason to build it. It is also, handled
/// carelessly, the single most FOMO-shaped mechanic anybody could put in this
/// app — so three fences, all of them load-bearing:
///
/// 1. **No notification, ever.** The standing rule, and this is the feature
///    most tempted to break it. A push saying *the swans are going over
///    today* would be the most effective retention message this app could
///    send and it would cost the whole premise. Missing a passage has to stay
///    free.
/// 2. **The almanac says nothing about a passage you have never seen.** No
///    countdown, no "opens in 9 days", no greyed-out card. You find out there
///    are swans by looking up in February. After that it is a thing you know
///    about and the almanac will talk about it.
/// 3. **A passage you missed is reported kindly, in the past tense, and only
///    once it has closed.** "The swans went over early this spring." Not
///    *you missed the swans*. The difference between those two sentences is
///    the difference between a world that has weather in it and an app that
///    is disappointed in you.
///
/// ### The dates breathe
///
/// A window is a nominal fortnight plus a per-year offset rolled out of
/// `WorldCalendar.seed`, so the swans come a week early one year and late the
/// next, the way they actually do. Two consequences worth stating: nobody can
/// write the dates down, and nobody has to — the almanac tells you afterwards
/// what happened, which is the only tense this feature speaks in.
///
/// ### And the comet is not a bug
///
/// One passage runs on a four-year cycle. In a comet year it is overhead for
/// nearly six weeks, which is both what a great comet actually does and what
/// keeps it above `check_species.py`'s reachability floor without an
/// exemption: forty days every fourth year is ten days a year, and a thing
/// you can meet ten days a year is rare rather than theoretical.
enum Passage: String, CaseIterable, Identifiable, Codable {
    case swans
    case cuckoo
    case paintedladies
    case salmon
    case redwings
    case snowgeese
    case waxwings
    case comet

    var id: String { rawValue }

    /// What it is called in the almanac. Definite article and plural, because
    /// a passage is a *movement* rather than an animal — you do not meet the
    /// snow geese, you are under them.
    var name: String {
        switch self {
        case .swans: "The whooper swans"
        case .cuckoo: "The first cuckoo"
        case .paintedladies: "The painted ladies"
        case .salmon: "The salmon run"
        case .redwings: "The redwings"
        case .snowgeese: "The snow geese"
        case .waxwings: "The waxwings"
        case .comet: "The comet"
        }
    }

    /// The line the almanac uses while it is happening. Present tense, no
    /// second person, and never an instruction — this is a thing that is going
    /// on, not an errand.
    var line: String {
        switch self {
        case .swans: "Going over in threes and fours, very high, calling."
        case .cuckoo: "Somewhere out past the treeline, and never twice from "
            + "the same place."
        case .paintedladies: "Coming up from the south a few at a time, all "
            + "week, all going the same way."
        case .salmon: "The whole run is in the shallows and the water keeps "
            + "breaking over nothing."
        case .redwings: "They came in overnight. The hedges are full and none "
            + "of them are staying."
        case .snowgeese: "A long ragged line of them, and then another one."
        case .waxwings: "Twenty of them stripped the berries off one tree and "
            + "left together."
        case .comet: "Low in the northwest after sunset, a little further "
            + "along every evening."
        }
    }

    /// Afterwards, once the window has closed and it is safe to mention. Two
    /// halves — the early one and the late one — because the whole charm of a
    /// migration is that it is not on a timetable, and saying *which* is what
    /// makes the world feel observed rather than scheduled.
    func afterword(early: Bool) -> String {
        let when = early ? "early" : "late"
        switch self {
        case .swans: "The swans went over \(when) this spring."
        case .cuckoo: "The cuckoo was \(when) this year."
        case .paintedladies: "The painted ladies came through \(when)."
        case .salmon: "The run was \(when) this autumn."
        case .redwings: "The redwings arrived \(when)."
        case .snowgeese: "The geese went south \(when) this year."
        case .waxwings: "The waxwings came \(when) this winter."
        case .comet: "The comet has gone."
        }
    }

    // MARK: The window

    /// Month and day the nominal window opens, and how many days it runs.
    ///
    /// Nominal: the real one slides by up to `drift` days each year. Every
    /// window is written to sit inside one calendar year — a passage crossing
    /// New Year would need the day-of-year arithmetic to wrap and nothing here
    /// is worth that, so the waxwings irrupt in January rather than December.
    var nominal: (from: (month: Int, day: Int), days: Int) {
        switch self {
        // The 18th rather than the 8th: with ±10 days of drift an opening on
        // the 8th lands on day 0 or day −2 of the year in about a quarter of
        // years, and `ordinality` has nothing to say about the −2nd of
        // January. `check_flyway.py` found it on its first run. Kept well
        // clear of both ends rather than clamped, because a clamped window is
        // one that quietly stops drifting in exactly the years it was
        // supposed to be earliest.
        case .waxwings: ((1, 18), 12)
        case .swans: ((2, 20), 17)
        case .cuckoo: ((4, 18), 18)
        case .paintedladies: ((6, 10), 17)
        case .comet: ((8, 1), 40)
        case .salmon: ((9, 25), 18)
        case .redwings: ((10, 20), 17)
        case .snowgeese: ((11, 8), 17)
        }
    }

    /// The month the journal's hint names, and the only thing it says.
    ///
    /// Deliberately vaguer than the data: the window is a fortnight and this
    /// says a month, because a hint precise enough to plan around would turn a
    /// migration into an appointment. "Some years, around late February" is
    /// somewhere to stand; "opens 24 February" is a calendar entry.
    var hintMonth: String {
        let names = ["", "January", "February", "March", "April", "May",
                     "June", "July", "August", "September", "October",
                     "November", "December"]
        let month = names[nominal.from.month]
        return nominal.from.day <= 10 ? "early \(month)"
            : nominal.from.day <= 20 ? "mid \(month)" : "late \(month)"
    }

    /// How far the window may slide, in days, either side of nominal.
    ///
    /// Bigger for the things that are genuinely unpredictable. The salmon run
    /// answers to the first autumn rain and the comet answers to nothing, so
    /// they wander; the swans are on the same weather system every year and
    /// barely do.
    var drift: Int {
        switch self {
        case .swans: 6
        case .cuckoo: 5
        case .paintedladies: 8
        case .salmon: 9
        case .redwings: 5
        case .snowgeese: 6
        case .waxwings: 10
        case .comet: 30
        }
    }

    /// How many years between passages. One for everything except the comet.
    var everyYears: Int { self == .comet ? 4 : 1 }

    /// Which species turns up during it.
    ///
    /// Derived rather than stored: the `Spec` row is where a species says what
    /// gates it, and a second table saying the same thing backwards is a table
    /// that goes out of step. `tools/check_flyway.py` asserts the lookup finds
    /// exactly one for every passage.
    var species: Species? {
        Species.allCases.first { $0.spec.passage == self }
    }

    // MARK: When

    /// The window in this date's year, as days-of-year, inclusive.
    ///
    /// `nil` in a year this passage does not run — only ever the comet.
    ///
    /// The offset is rolled from the **first of January of that year**, not
    /// from the day being asked about, so every day in a year agrees about
    /// when the swans came. Rolling per-day would give a window that moved
    /// while you were standing in it.
    static func window(_ passage: Passage, inYearOf date: Date)
        -> ClosedRange<Int>? {
        let year = WorldCalendar.calendar.component(.year, from: date)
        guard year % passage.everyYears == passage.yearPhase else { return nil }

        var opening = DateComponents()
        opening.year = year
        opening.month = passage.nominal.from.month
        opening.day = passage.nominal.from.day
        guard let nominal = WorldCalendar.calendar.date(from: opening),
              let start = WorldCalendar.calendar.ordinality(
                  of: .day, in: .year, for: nominal
              )
        else { return nil }

        // A whole-year salt: the same roll for every place, because a
        // migration is not a local event and swans over the meadow are the
        // same swans over the woods an hour later.
        let roll = WorldCalendar.roll(
            day: nominal, place: .meadow, salt: "flyway.\(passage.rawValue)"
        )
        let offset = Int((roll * Double(passage.drift * 2 + 1)).rounded(.down))
            - passage.drift
        let from = start + offset
        return from...(from + passage.nominal.days - 1)
    }

    /// Which year of the cycle this one runs in. Fixed rather than rolled: a
    /// comet whose *year* moved would make the four-year rhythm unfindable,
    /// and the whole pleasure of a long cycle is that somebody eventually
    /// works it out.
    var yearPhase: Int { self == .comet ? 2 : 0 }

    /// Everything happening on a given day.
    static func open(on date: Date = WorldCalendar.today) -> [Passage] {
        allCases.filter { isOpen($0, on: date) }
    }

    static func isOpen(_ passage: Passage, on date: Date = WorldCalendar.today)
        -> Bool {
        if let forced = LaunchOptions.forcedPassage {
            return forced == passage
        }
        guard let window = window(passage, inYearOf: date),
              let today = WorldCalendar.calendar.ordinality(
                  of: .day, in: .year, for: date
              )
        else { return false }
        return window.contains(today)
    }

    /// Passages that have already finished in this date's year, with whether
    /// each ran early. The almanac's past tense, and the only tense it has for
    /// something nobody saw.
    static func closed(by date: Date = WorldCalendar.today) -> [(Passage, Bool)] {
        guard let today = WorldCalendar.calendar.ordinality(
            of: .day, in: .year, for: date
        ) else { return [] }
        return allCases.compactMap { passage in
            guard let window = window(passage, inYearOf: date),
                  window.upperBound < today
            else { return nil }
            // Early or late against its own nominal opening, which is the only
            // thing there is to be early *for*.
            guard let nominal = nominalStart(passage, inYearOf: date)
            else { return nil }
            return (passage, window.lowerBound < nominal)
        }
    }

    private static func nominalStart(_ passage: Passage, inYearOf date: Date)
        -> Int? {
        var opening = DateComponents()
        opening.year = WorldCalendar.calendar.component(.year, from: date)
        opening.month = passage.nominal.from.month
        opening.day = passage.nominal.from.day
        guard let start = WorldCalendar.calendar.date(from: opening)
        else { return nil }
        return WorldCalendar.calendar.ordinality(of: .day, in: .year, for: start)
    }
}
