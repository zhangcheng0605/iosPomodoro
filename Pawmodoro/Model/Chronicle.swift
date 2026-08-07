import Foundation
import Observation

/// The letters the seasons write, and the year, kept.
///
/// Stardew's Grandpa is remembered with love only because of the love —
/// the candles were judgment, and they die here. Spotify Wrapped is the
/// same loop annualized. So: when a real season ends, a letter arrives
/// recounting it — counts as memory, never as comparison, and a
/// near-empty season gets a shorter, warmer letter. And once a year, on
/// the anniversary of the first session ever, a small sequence of cards:
/// the year, kept. Presented whenever the year rolls past, so it cannot
/// be missed — nothing here knows how to be late.
struct SeasonLetter: Codable, Equatable, Identifiable {
    var id: String { "\(year).\(season)" }
    let season: String
    let year: Int
    let date: Date
    let text: String

    var title: String {
        Season(rawValue: season).map(\.name) ?? "A season"
    }
}

@Observable
final class Chronicle {

    private(set) var letters: [SeasonLetter] = []
    /// The just-composed letter, for the caption to announce once.
    private(set) var freshLetter: SeasonLetter?
    /// The anniversary sequence waiting to be shown: years together.
    private(set) var yearDue: Int?

    @ObservationIgnored private var lastSeenKey: String?
    @ObservationIgnored private var yearShown: Int?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    private static let keepLetters = 12

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        load()
    }

    // MARK: The check, on launch and foregrounding

    func check(
        log: SessionLog, journal: Journal, travels: Travels,
        photos: PhotoAlbum, now: Date = Date()
    ) {
        let year = calendar.component(.year, from: now)
        let currentKey = Season.current().map { "\(year).\($0.rawValue)" } ?? "none"

        // A season we were inside last look, and aren't anymore: it turned.
        if let last = lastSeenKey, last != currentKey, last != "none" {
            let parts = last.split(separator: ".").map(String.init)
            if parts.count == 2, let lastYear = Int(parts[0]),
               let season = Season(rawValue: parts[1]),
               !letters.contains(where: { $0.id == last }) {
                let letter = SeasonLetter(
                    season: season.rawValue, year: lastYear, date: now,
                    text: Self.compose(
                        season: season, year: lastYear, log: log,
                        journal: journal, travels: travels, photos: photos,
                        calendar: calendar
                    )
                )
                letters.append(letter)
                if letters.count > Self.keepLetters {
                    letters.removeFirst(letters.count - Self.keepLetters)
                }
                freshLetter = letter
            }
        }
        lastSeenKey = currentKey

        // The anniversary: due from the day the year completes, standing
        // until seen. Never missable, never mentioned twice.
        if let first = log.firstSessionDate {
            let years = (calendar.dateComponents(
                [.day], from: first, to: now
            ).day ?? 0) / 365
            if years >= 1, yearShown ?? 0 < years {
                yearDue = years
            }
        }
        save()
    }

    func claimFreshLetter() -> SeasonLetter? {
        defer { freshLetter = nil }
        return freshLetter
    }

    func yearPresented() {
        yearShown = yearDue ?? yearShown
        yearDue = nil
        save()
    }

    // MARK: Composition

    /// The recounting. Counts appear as memory ("forty-one quiet hours"),
    /// never as comparison — no season is ever measured against another,
    /// and absence is structurally invisible.
    static func compose(
        season: Season, year: Int, log: SessionLog, journal: Journal,
        travels: Travels, photos: PhotoAlbum, calendar: Calendar
    ) -> String {
        guard let interval = Self.interval(of: season, year: year, calendar: calendar)
        else { return "A season came and went, the way they do." }

        let sessions = log.records.filter { interval.contains($0.endedAt) }
        let minutes = sessions.reduce(0) { $0 + $1.minutes }
        let hours = minutes / 60

        var lines: [String] = []
        if sessions.isEmpty {
            lines.append("A quiet \(season.name.lowercased()). "
                + "The garden waited with you, and the sill kept its view.")
            return lines.joined(separator: " ")
        }
        if hours >= 1 {
            lines.append("This \(season.name.lowercased()): "
                + "\(spell(hours)) quiet hour\(hours == 1 ? "" : "s"), kept.")
        } else {
            lines.append("This \(season.name.lowercased()): "
                + "a handful of quiet minutes, kept anyway.")
        }

        let met = journal.records.compactMap { key, record -> String? in
            guard interval.contains(record.firstSeen) else { return nil }
            return Species(rawValue: key)?.name.lowercased()
        }
        if let firstMet = met.first {
            lines.append(met.count == 1
                ? "You met the \(firstMet)."
                : "You met the \(firstMet), and \(met.count - 1) other"
                    + "\(met.count == 2 ? "" : "s") besides.")
        }

        let nights = log.nightRecords.filter { interval.contains($0.endedAt) }.count
        if nights > 0 {
            lines.append("\(spell(nights).capitalized) star"
                + "\(nights == 1 ? "" : "s") went up after dark.")
        }

        let arrived = travels.mailbox.filter { interval.contains($0.date) }.count
        if arrived > 0 {
            lines.append("\(spell(arrived).capitalized) letter"
                + "\(arrived == 1 ? "" : "s") came home.")
        }

        let shots = photos.photos.filter { interval.contains($0.date) }.count
        if shots > 0 {
            lines.append("The camera kept \(spell(shots)) morning"
                + "\(shots == 1 ? "" : "s")' worth of light.")
        }

        lines.append("Noted, all of it. — the almanac")
        return lines.joined(separator: " ")
    }

    /// The season's real dates in a given year.
    static func interval(
        of season: Season, year: Int, calendar: Calendar
    ) -> ClosedRange<Date>? {
        let window = season.window
        var fromParts = DateComponents()
        fromParts.year = year
        fromParts.month = window.from.month
        fromParts.day = window.from.day
        var toParts = DateComponents()
        toParts.year = year
        toParts.month = window.to.month
        toParts.day = window.to.day
        toParts.hour = 23
        toParts.minute = 59
        guard let from = calendar.date(from: fromParts),
              let to = calendar.date(from: toParts), from <= to
        else { return nil }
        return from...to
    }

    private static func spell(_ n: Int) -> String {
        let words = [
            "zero", "one", "two", "three", "four", "five", "six", "seven",
            "eight", "nine", "ten", "eleven", "twelve",
        ]
        return n < words.count ? words[n] : "\(n)"
    }

    // MARK: Debug

    /// `-PawmodoroSeasonLetter <season>` — compose it now.
    func composeForDebug(
        season: Season, log: SessionLog, journal: Journal,
        travels: Travels, photos: PhotoAlbum, now: Date = Date()
    ) {
        let year = calendar.component(.year, from: now)
        let letter = SeasonLetter(
            season: season.rawValue, year: year, date: now,
            text: Self.compose(
                season: season, year: year, log: log, journal: journal,
                travels: travels, photos: photos, calendar: calendar
            )
        )
        letters.removeAll { $0.id == letter.id }
        letters.append(letter)
        freshLetter = letter
        save()
    }

    /// `-PawmodoroYearCard` — the sequence, now.
    func forceYearForDebug() {
        yearDue = max(1, (yearShown ?? 0) + 1)
    }

    // MARK: Persistence

    private struct State: Codable {
        var letters: [SeasonLetter]
        var lastSeenKey: String?
        var yearShown: Int?
    }

    private func load() {
        guard let data = defaults.data(forKey: StorageKeys.chronicle),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return }
        letters = state.letters
        lastSeenKey = state.lastSeenKey
        yearShown = state.yearShown
    }

    private func save() {
        let state = State(
            letters: letters, lastSeenKey: lastSeenKey, yearShown: yearShown
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: StorageKeys.chronicle)
    }
}
