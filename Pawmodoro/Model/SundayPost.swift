import Foundation

/// A letter from your buddy about the week you actually had.
///
/// Once a week an envelope leans against the house. Inside is a short note in
/// the world's voice: where you sat, what the two of you saw, a dream worth
/// mentioning, what the sky did. It is composed rather than written — a
/// grammar of sentences over the Chronicle's event feed — which is the whole
/// architectural point of it.
///
/// **This is the era's aggregation surface.** Every small system that would
/// otherwise want a screen of its own gets a *sentence* here instead: weather
/// that passed, a tide that revealed something, swans going over, a candle
/// lit, a resident who moved in. Adding a system to the letter is adding one
/// arm to `sentence(for:)`, and it costs no UI at all. That is why it is worth
/// building before the systems that will feed it.
///
/// Nothing in here nags. It never mentions a week you missed, never compares
/// this week to last, and never appears at all in a week with nothing in it —
/// a letter that said "you did not focus much this week" is the exact thing
/// this app is not.
enum SundayPost {

    /// A composed letter, ready to be read.
    struct Letter: Equatable, Identifiable {
        /// The Monday the week began, which is also the id — one letter per
        /// week, ever, and re-composing it produces the same one.
        let weekStart: Date
        let greeting: String
        /// The body, one sentence per line. Composed in a fixed order so a
        /// letter reads the same way twice.
        let lines: [String]
        let signoff: String

        var id: Date { weekStart }
        var isEmpty: Bool { lines.isEmpty }
    }

    /// The Monday on or before a date.
    static func weekStart(of date: Date = WorldCalendar.now) -> Date {
        let calendar = WorldCalendar.calendar
        let start = WorldCalendar.startOfDay(date)
        // `weekday` is 1 = Sunday in Gregorian, so Monday is 2 and the offset
        // wraps Sunday round to the *previous* Monday rather than the next.
        let weekday = calendar.component(.weekday, from: start)
        let back = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -back, to: start) ?? start
    }

    /// Whether there is a letter to read — i.e. whether last week happened.
    ///
    /// The letter is about the week that has *finished*, so it arrives on the
    /// Monday and describes the seven days behind it. A week with no sessions
    /// in it produces nothing at all; there is no envelope, and nothing
    /// anywhere says there could have been one.
    static func compose(
        buddy: String,
        sessions: [SessionRecord],
        events: [ChronicleEvent],
        weekOf date: Date = WorldCalendar.now
    ) -> Letter? {
        let calendar = WorldCalendar.calendar
        let thisMonday = weekStart(of: date)
        guard let lastMonday = calendar.date(
            byAdding: .day, value: -7, to: thisMonday
        ) else { return nil }

        let weekSessions = sessions.filter {
            $0.endedAt >= lastMonday && $0.endedAt < thisMonday
        }
        guard !weekSessions.isEmpty else { return nil }

        let weekEvents = events.filter {
            $0.at >= lastMonday && $0.at < thisMonday
        }

        var lines: [String] = []
        lines.append(openingLine(sessions: weekSessions))
        if let place = placeLine(weekEvents) { lines.append(place) }
        lines.append(contentsOf: eventLines(weekEvents))
        if let hour = hourLine(weekSessions) { lines.append(hour) }
        if let acorns = acornLine(weekSessions) { lines.append(acorns) }
        lines.append(moonLine(on: lastMonday))

        return Letter(
            weekStart: lastMonday,
            greeting: greeting(on: lastMonday),
            // Six is a letter; twelve is a report. A busy week is trimmed from
            // the *end*, so the opening and the arrivals always survive.
            lines: Array(lines.prefix(6)),
            signoff: "— \(buddy)"
        )
    }

    /// Chronicle kinds the letter says nothing about, on purpose.
    ///
    /// `tools/check_post.py` requires every `ChronicleEvent.Kind` to be either
    /// handled in `eventLines` or named here — because the letter is this
    /// era's *aggregation surface*, and a system that quietly never gets a
    /// sentence is a system that quietly got no surface at all. Adding a kind
    /// and forgetting it is otherwise invisible: the letter just never
    /// mentions it, forever, and reads perfectly well without it.
    ///
    /// - `sound`: reserved for Phase W and nothing writes it yet. It gets a
    ///   sentence the week the first ambience becomes findable, not before.
    /// - `trade`: silent forever, and this is the one entry here that is a
    ///   decision rather than a deferral. The letter is the single surface in
    ///   the app addressed *to* the reader, and the moment it starts
    ///   itemising what they bought it is a receipt — which is a different
    ///   relationship from the one every other line in it is building. The
    ///   thing traded for shows up in the letter anyway, in its own words, on
    ///   the week it starts being used: a new place gets "We reached the
    ///   Sunstone Keep", which is worth more than "You spent 150 acorns."
    static let silentKinds: [ChronicleEvent.Kind] = [.sound, .trade]

    // MARK: The grammar

    private static func greeting(on monday: Date) -> String {
        let formatted = monday.formatted(.dateTime.day().month(.wide))
        return "The week of \(formatted)"
    }

    /// How much, in the world's terms rather than the app's. Never a total in
    /// minutes: "you sat for 312 minutes" is a receipt, not a letter.
    private static func openingLine(sessions: [SessionRecord]) -> String {
        let days = Set(sessions.map { WorldCalendar.startOfDay($0.endedAt) }).count
        let minutes = sessions.reduce(0) { $0 + $1.minutes }
        let hours = minutes / 60

        switch (days, hours) {
        case (1, _): return "We sat down together once this week."
        case (_, 0): return "We sat down on \(days) days, and not for long."
        case (_, 1): return "We sat down on \(days) days, about an hour in all."
        default: return "We sat down on \(days) days, a good few hours between us."
        }
    }

    private static func placeLine(_ events: [ChronicleEvent]) -> String? {
        let arrivals = events
            .filter { $0.kind == .arrival }
            .compactMap { Place(rawValue: $0.subject) }
        guard let first = arrivals.first else { return nil }
        if arrivals.count > 1 {
            return "We got as far as \(arrivals[arrivals.count - 1].name)."
        }
        return "We reached \(first.name) this week."
    }

    /// One sentence per kind of thing that happened, in a fixed order so the
    /// letter reads the same way twice. Sightings come first because they are
    /// what the two of you did together; the sky comes last because it is
    /// weather.
    private static func eventLines(_ events: [ChronicleEvent]) -> [String] {
        var lines: [String] = []

        let seen = events.filter { $0.kind == .sighting }
            .compactMap { Species(rawValue: $0.subject) }
        if let line = sightingLine(seen) { lines.append(line) }

        let heard = events.filter { $0.kind == .heard }
            .compactMap { Heard(rawValue: $0.subject) }
        if let sound = heard.first {
            lines.append("One night we heard \(sound.name.lowercased()), "
                         + "and neither of us went to look.")
        }

        if let dream = events.first(where: { $0.kind == .dream }),
           let subject = Dream.from(id: dream.subject)?.subject {
            lines.append("I dreamed about \(subject).")
        }

        if let bond = events.first(where: { $0.kind == .bond }),
           let level = Int(bond.subject).flatMap(Bond.init(rawValue:)) {
            lines.append(bondLine(level))
        }

        if events.contains(where: { $0.kind == .figure }) {
            lines.append("A figure finished in the sky. It is up there now "
                         + "whether or not anybody looks.")
        }

        if events.contains(where: { $0.kind == .snail }) {
            lines.append("The old snail was still going, a little further "
                         + "along than last time.")
        }

        if events.contains(where: { $0.kind == .snapshot }) {
            lines.append("We kept a picture of one of the afternoons.")
        }

        if let left = events.last(where: { $0.kind == .keepsake }),
           let keepsake = Keepsake(rawValue: left.subject) {
            lines.append(keepsake.postLine)
        }

        if let settled = events.last(where: { $0.kind == .settledIn }),
           let den = Den(rawValue: settled.subject) {
            lines.append(den.settledInLine)
        }

        // The homestead's arrivals, in the letter's tense: they happened, and
        // now they are simply part of the place. Never how many there are —
        // eight of eight is a collection, and this is a garden.
        if let moved = events.last(where: { $0.kind == .resident }),
           let resident = Resident(rawValue: moved.subject) {
            lines.append("We have \(resident.settledLine) now.")
        }

        if let stray = events.filter({ $0.kind == .stray }).last,
           let stage = Int(stray.subject).flatMap(Stray.Stage.init(rawValue:)),
           let line = stage.postLine {
            lines.append(line)
        }
        return lines
    }

    private static func sightingLine(_ seen: [Species]) -> String? {
        let names = Array(Set(seen.map { $0.name.lowercased() })).sorted()
        switch names.count {
        case 0: return nil
        case 1: return "We saw a \(names[0])."
        case 2: return "We saw a \(names[0]) and a \(names[1])."
        default:
            let head = names.prefix(2).joined(separator: ", a ")
            return "We saw a \(head), and \(names.count - 2) other things."
        }
    }

    private static func bondLine(_ level: Bond) -> String {
        switch level {
        case .justMet: "I am still working you out."
        case .acquainted: "I know your footsteps now."
        case .friendly: "I settle the moment you sit down."
        case .close: "I have started waiting by the door."
        case .devoted: "I have picked a side of the desk. It is mine."
        case .inseparable: "I would not go anywhere without you."
        }
    }

    /// The hour the week mostly happened in — the one thing here that could
    /// have been a chart and is a sentence instead.
    private static func hourLine(_ sessions: [SessionRecord]) -> String? {
        guard sessions.count >= 3 else { return nil }
        let calendar = WorldCalendar.calendar
        var counts: [Int: Int] = [:]
        for session in sessions {
            counts[calendar.component(.hour, from: session.endedAt), default: 0] += 1
        }
        guard let (hour, count) = counts.max(by: { $0.value < $1.value }),
              count * 2 >= sessions.count
        else { return nil }

        switch DayPart.from(hour: hour) {
        case .dawn: return "Mostly early, before the day started."
        case .day: return "Mostly in the middle of the day."
        case .dusk: return "Mostly as the light went."
        case .night: return "Mostly after dark, which suits me."
        }
    }

    /// What the wood dropped, without ever saying what it is worth.
    ///
    /// Computed from the week's own minutes rather than read from a
    /// `.trade` — those stay silent, per `silentKinds`. This is the only
    /// place outside the cart and the stats sheet that the economy is
    /// mentioned at all, and it is phrased as weather: acorns fall, and
    /// nobody is being told to go and collect them. No balance, no total, no
    /// suggestion of what they might buy.
    private static func acornLine(_ sessions: [SessionRecord]) -> String? {
        let dropped = Acorns.earned(minutes: sessions.reduce(0) { $0 + $1.minutes })
        switch dropped {
        case 0: return nil
        case 1: return "One acorn came down while we were sitting."
        case 2...9: return "A few acorns came down while we were sitting."
        default: return "The wood dropped acorns all week. I have not counted them."
        }
    }

    private static func moonLine(on monday: Date) -> String {
        "The moon was \(MoonPhase.name(on: monday).lowercased()) when it began."
    }
}

extension Stray.Stage {
    /// What the letter says about the week she moved a step closer. Only the
    /// steps that are a change worth remarking on; the early ones are her
    /// deciding, and she would not want that written down.
    var postLine: String? {
        switch self {
        case .away, .eyes: nil
        case .edge: "There was a cat at the edge of things. I said nothing."
        case .watching: "The cat sat in the grass and watched us the whole time."
        case .beside: "The cat sat next to me. Neither of us moved."
        case .home: "The cat came in. She lives here now, apparently."
        }
    }
}
