import Foundation

/// A year of focus, as a circle.
///
/// One thin wedge per day, tinted with the sky of the hours you actually sat:
/// dawn sessions paint a day rose, midnight sessions ink. A year of mornings
/// and a year of late nights are different colours, and you can tell which you
/// had from across the room without a single number on screen.
///
/// **It ships already old.** Every session ever completed carries a full
/// `endedAt: Date`, so this is a pure re-reading of history rather than
/// anything that had to be recorded in advance — somebody who has used the app
/// for a year sees their whole year the day it arrives. That is the entire
/// argument for building the Chronicle before the screens that read it, and
/// this is the screen that proves it was worth it.
///
/// Nothing here counts, ranks or compares. An empty day is quiet parchment, not
/// a red square: the ring is a picture of a year, not a report card, and the
/// day it starts scoring people is the day it stops being worth looking at.
enum YearRing {

    /// One day's worth of the ring.
    struct Day: Identifiable, Equatable {
        /// Day of the year, 1-based. Also the id — a ring has one wedge per
        /// day and never two.
        let ordinal: Int
        let date: Date
        /// Which times of day were focused in, and how many sessions in each.
        /// Empty means nothing was, which is most days for most people and is
        /// not a failure of any kind.
        let parts: [DayPart: Int]

        var id: Int { ordinal }
        var isEmpty: Bool { parts.isEmpty }
        var sessions: Int { parts.values.reduce(0, +) }

        /// The times of day that day held, heaviest first, so a wedge can be
        /// blended in a stable order rather than a dictionary's.
        var ordered: [(part: DayPart, count: Int)] {
            DayPart.allCases
                .compactMap { part in
                    parts[part].map { (part: part, count: $0) }
                }
                .sorted { ($0.count, $0.part.rawValue) > ($1.count, $1.part.rawValue) }
        }
    }

    /// A whole year, one entry per day, always the full length of that year —
    /// so the ring is a complete circle in January and a complete circle in
    /// December, and the empty part of it is the part you have not lived yet
    /// rather than a gap.
    struct Year: Equatable {
        let year: Int
        let days: [Day]

        var lived: Int { days.filter { !$0.isEmpty }.count }
        var isEmpty: Bool { lived == 0 }
    }

    /// Build a year out of the session log.
    ///
    /// `LaunchOptions.forcedDayPart` is honoured for the same reason
    /// `SessionLog.nightSessions` honours it: with `-PawmodoroClock 22` and a
    /// seeded history the whole ring goes to ink, which is the only way to
    /// look at the night end of the palette without waiting for midnight.
    static func build(year: Int, from records: [SessionRecord]) -> Year {
        let calendar = WorldCalendar.calendar
        var counts: [Int: [DayPart: Int]] = [:]

        for record in records {
            let components = calendar.dateComponents(
                [.year, .hour], from: record.endedAt
            )
            guard components.year == year,
                  let ordinal = calendar.ordinality(
                      of: .day, in: .year, for: record.endedAt
                  ),
                  let hour = components.hour
            else { continue }
            let part = LaunchOptions.forcedDayPart ?? DayPart.from(hour: hour)
            counts[ordinal, default: [:]][part, default: 0] += 1
        }

        let length = daysIn(year: year)
        var days: [Day] = []
        days.reserveCapacity(length)
        for ordinal in 1...length {
            let date = dateFor(ordinal: ordinal, year: year) ?? Date()
            days.append(Day(ordinal: ordinal, date: date,
                            parts: counts[ordinal] ?? [:]))
        }
        return Year(year: year, days: days)
    }

    /// Every year the log has anything in, newest first. The current year is
    /// always present even when it is empty, because a ring you cannot see
    /// until you have used it is a ring nobody discovers.
    static func years(in records: [SessionRecord],
                      now: Date = WorldCalendar.now) -> [Int] {
        let calendar = WorldCalendar.calendar
        let thisYear = calendar.component(.year, from: now)
        var found = Set(records.map { calendar.component(.year, from: $0.endedAt) })
        found.insert(thisYear)
        return found.sorted(by: >)
    }

    /// 365, or 366. Asked of the calendar rather than worked out from a rule,
    /// because the rule has exceptions and the calendar already knows them.
    static func daysIn(year: Int) -> Int {
        let calendar = WorldCalendar.calendar
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let range = calendar.range(of: .day, in: .year, for: start)
        else { return 365 }
        return range.count
    }

    static func dateFor(ordinal: Int, year: Int) -> Date? {
        let calendar = WorldCalendar.calendar
        guard let start = calendar.date(
            from: DateComponents(year: year, month: 1, day: 1)
        ) else { return nil }
        return calendar.date(byAdding: .day, value: ordinal - 1, to: start)
    }

    // MARK: The rim

    /// A date the world itself remembers, sitting on the rim of the ring.
    struct Mark: Identifiable, Equatable {
        let ordinal: Int
        let label: String
        let kind: ChronicleEvent.Kind?

        var id: String { "\(ordinal).\(label)" }
    }

    /// What the Chronicle can tell us about a year, as rim marks.
    ///
    /// Only the firsts: the first time a species was seen, the first time a
    /// place was reached, each bond level, the stray's stages. A rim crowded
    /// with every heron you ever met would be a smear — these are the days
    /// that were different from the day before them.
    ///
    /// Deliberately no notification and no "on this day" prompt, now or ever.
    /// A rim mark is something you find by looking at the ring, and finding it
    /// has to stay free — see the anti-goals.
    static func marks(
        for year: Int, from events: [ChronicleEvent], firstSession: Date?
    ) -> [Mark] {
        let calendar = WorldCalendar.calendar
        var marks: [Mark] = []

        func ordinal(_ date: Date) -> Int? {
            guard calendar.component(.year, from: date) == year else { return nil }
            return calendar.ordinality(of: .day, in: .year, for: date)
        }

        if let firstSession, let day = ordinal(firstSession) {
            marks.append(Mark(ordinal: day, label: "the first one", kind: nil))
        }

        // One mark per (kind, subject) pair, on the day it first happened.
        var seen: Set<String> = []
        for event in events.sorted(by: { $0.at < $1.at }) {
            let key = "\(event.kind.rawValue).\(event.subject)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            guard let day = ordinal(event.at), let label = event.rimLabel else { continue }
            marks.append(Mark(ordinal: day, label: label, kind: event.kind))
        }
        return marks.sorted { $0.ordinal < $1.ordinal }
    }
}

extension ChronicleEvent {
    /// What this event is called on the rim, or nil for the kinds that are too
    /// common to mark. A rim is a handful of days, not a transcript.
    var rimLabel: String? {
        switch kind {
        case .arrival: Place(rawValue: subject).map { "reached \($0.name)" }
        case .bond: Int(subject).flatMap(Bond.init(rawValue:)).map { $0.name.lowercased() }
        case .figure: "a constellation finished"
        case .stray: Int(subject).flatMap(Stray.Stage.init(rawValue:))?.rimLabel
        case .resident: Resident(rawValue: subject).map { "the \($0.rawValue) arrived" }
        // The night in it, not the buying of it — the same distinction the
        // two kinds were split for.
        case .settledIn: Den(rawValue: subject).map { "first night in \($0.name.lowercased())" }
        case .panorama: Int(subject).map { "\($0) hours, and a wood to show for it" }
        // The day the dial closed, and only that day. Each of the
        // twenty-four hours also writes a `.bell` row the first time it
        // fills, and twenty-four marks would ring the whole circle — an
        // hour you happened to be awake for is not a day you would
        // remember, but the one that finished the round is.
        case .bell: subject == "ring" ? "the clock came all the way round" : nil
        // The day a tape turned up, and only that day. The rainy tally's rows
        // share this kind and get no mark: four of them are steps toward
        // something and the fifth is the thing itself.
        case .tape: MusicFinding(foundSubject: subject)?.rimLabel
        // Sightings, dreams, sounds and the snail happen often enough that
        // marking every first would ring the whole circle. They are the
        // Sunday Post's material, not the rim's. Trades, keepsakes and
        // snapshots are the same: things you do often, by choice.
        case .sighting, .dream, .heard, .sound, .snail,
             .trade, .keepsake, .snapshot: nil
        }
    }
}

extension Stray.Stage {
    /// Only the two stages that are actually a day you would remember.
    var rimLabel: String? {
        switch self {
        case .away, .eyes, .edge, .watching: nil
        case .beside: "she sat with you"
        case .home: "she came in"
        }
    }
}
