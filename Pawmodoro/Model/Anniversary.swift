import Foundation
import Observation

/// The buddy as the keeper of your shared history.
///
/// The app already writes a diary it never reads — first sightings, the
/// stray's dates, the first session ever. This engine scans those stored
/// dates for anniversaries and, at most once a day, has the buddy bring one
/// up: a small thought bubble and a dated caption.
///
/// The guilt-proofing is structural: the input is a list of things you
/// *did*. Missed days are not represented anywhere in it, so the engine
/// cannot mention what it cannot see — a sparse history means fewer
/// memories, never a remark about their absence.
struct Memory: Equatable {

    enum Subject: Equatable {
        case firstSession
        case species(Species)
        case strayFirstSeen
        case strayJoined
    }

    let subject: Subject
    let daysAgo: Int

    /// Stable per (subject, anniversary), so the same event can return at a
    /// later milestone but never repeat the same one.
    var id: String {
        switch subject {
        case .firstSession: "firstSession@\(daysAgo)"
        case .species(let species): "species.\(species.rawValue)@\(daysAgo)"
        case .strayFirstSeen: "strayFirstSeen@\(daysAgo)"
        case .strayJoined: "strayJoined@\(daysAgo)"
        }
    }

    /// "three weeks ago today", "six months ago today". Weeks up to twelve,
    /// whole months after; the debug path can produce a bare day count.
    var spanLabel: String {
        if daysAgo % 7 == 0, (1...12).contains(daysAgo / 7) {
            return "\(Self.spell(daysAgo / 7)) week\(daysAgo == 7 ? "" : "s") ago today"
        }
        if daysAgo % 30 == 0, daysAgo >= 60 {
            return "\(Self.spell(daysAgo / 30)) months ago today"
        }
        return "\(daysAgo) days ago today"
    }

    /// The caption. Dry, precise about the date, and always evidence of
    /// attention — never a score.
    func line(name: String, strayName: String) -> String {
        switch subject {
        case .firstSession:
            return "\(spanLabel): your first session together. "
                + "\(name) remembers it fondly, and inaccurately"
        case .species(let species):
            return "\(spanLabel): the \(species.name.lowercased()). "
                + "\(name) maintains it was bigger than reported"
        case .strayFirstSeen:
            return "\(spanLabel): the first pair of eyes in the hedge"
        case .strayJoined:
            return "\(spanLabel): the day \(strayName) decided you were safe"
        }
    }

    /// What sits in the thought bubble: a journal sketch for a species,
    /// nil for the rest (the bubble shows a small glyph instead).
    var sketchAsset: String? {
        if case .species(let species) = subject { return species.sketchAsset }
        return nil
    }

    private static func spell(_ n: Int) -> String {
        let words = [
            "zero", "one", "two", "three", "four", "five", "six",
            "seven", "eight", "nine", "ten", "eleven", "twelve",
        ]
        return n < words.count ? words[n] : "\(n)"
    }
}

@Observable
final class Anniversaries {

    /// Today's memory, until it is acknowledged or the day ends.
    private(set) var today: Memory?

    @ObservationIgnored private var surfaced: [String] = []
    @ObservationIgnored private var lastLookDay: Int?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        load()
    }

    /// Scan the stored past for a date-locked hit. At most one memory a
    /// day, decided once, never repeated at the same milestone.
    func lookBack(
        log: SessionLog, journal: Journal, stray: Stray, on date: Date = Date()
    ) {
        let day = Snack.dayNumber(for: date, calendar: calendar)
        guard day != lastLookDay else { return }
        lastLookDay = day
        defer { save() }

        var candidates: [(memory: Memory, rank: Int)] = []

        // The stray's dates are the rarest kind of memory there is.
        if let joined = stray.joined, let days = anniversary(from: joined, to: date) {
            candidates.append((Memory(subject: .strayJoined, daysAgo: days), 400 + days))
        }
        if let seen = stray.firstSeen, let days = anniversary(from: seen, to: date) {
            candidates.append((Memory(subject: .strayFirstSeen, daysAgo: days), 300 + days))
        }
        // Every first meeting in the journal.
        for species in Species.allCases {
            guard let record = journal.record(for: species),
                  let days = anniversary(from: record.firstSeen, to: date)
            else { continue }
            let rarity = species.rarity == .common ? 0 : 100
            candidates.append((Memory(subject: .species(species), daysAgo: days), 100 + rarity + days))
        }
        // The very first session — the stored anchor, not `records.first`,
        // which shifts once the log starts trimming.
        if let first = log.firstSessionDate,
           let days = anniversary(from: first, to: date) {
            candidates.append((Memory(subject: .firstSession, daysAgo: days), 200 + days))
        }

        let fresh = candidates.filter { !surfaced.contains($0.memory.id) }
        guard let best = fresh.max(by: { $0.rank < $1.rank }) else { return }
        surfaced.append(best.memory.id)
        today = best.memory
    }

    /// Acknowledged — the thought has been thought.
    func dismiss() {
        today = nil
    }

    /// Exact anniversaries only: whole weeks one through twelve, then whole
    /// calendar months. Nil means today is not that day.
    private func anniversary(from event: Date, to date: Date) -> Int? {
        let start = calendar.startOfDay(for: event)
        let today = calendar.startOfDay(for: date)
        guard let days = calendar.dateComponents([.day], from: start, to: today).day,
              days > 0
        else { return nil }
        if days % 7 == 0, (1...12).contains(days / 7) { return days }
        // Whole months, checked against the calendar rather than by
        // dividing days — February exists.
        if days > 84 {
            let months = calendar.dateComponents([.month], from: start, to: today).month ?? 0
            if months >= 3,
               let exact = calendar.date(byAdding: .month, value: months, to: start),
               calendar.isDate(exact, inSameDayAs: today) {
                return days
            }
        }
        return nil
    }

    // MARK: Debug

    /// `-PawmodoroRemember <daysAgo>` — surface a memory dated that far
    /// back, without arranging a real anniversary.
    func forceForDebug(daysAgo: Int, journal: Journal) {
        let subject: Memory.Subject
        if let seen = Species.allCases.first(where: { journal.hasSeen($0) }) {
            subject = .species(seen)
        } else {
            subject = .firstSession
        }
        today = Memory(subject: subject, daysAgo: max(1, daysAgo))
    }

    // MARK: Persistence

    private struct State: Codable {
        var surfaced: [String]
        var lastLookDay: Int?
    }

    private func load() {
        guard let data = defaults.data(forKey: StorageKeys.anniversaries),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return }
        surfaced = state.surfaced
        lastLookDay = state.lastLookDay
    }

    private func save() {
        let state = State(surfaced: surfaced, lastLookDay: lastLookDay)
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: StorageKeys.anniversaries)
    }
}
