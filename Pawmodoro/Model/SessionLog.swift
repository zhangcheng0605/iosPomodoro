import Foundation
import Observation

/// One completed focus session.
///
/// `place` and `buddy` arrived late (the Clockwork wave): optionals with
/// synthesized lenient decoding, so every record written before them loads
/// untouched and simply doesn't remember where it happened — which the
/// features that read them (letters, star stories, fortunes) all say out
/// loud rather than guess.
struct SessionRecord: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var endedAt: Date
    var minutes: Int
    var place: String? = nil
    var buddy: String? = nil
}

/// History of completed focus sessions, persisted on device. Nothing leaves the
/// phone — there is no account and no network call anywhere in the app.
@Observable
final class SessionLog {
    private(set) var records: [SessionRecord] = []
    /// Every session ever, monotonic, surviving the trim below.
    ///
    /// `records.count` silently stopped being a lifetime number the day the
    /// log learned to trim — after the thousandth session it would have
    /// quietly frozen the bond and shifted "your first session ever" as old
    /// records fell off. This counter and `firstSessionDate` are the fix:
    /// stored once, seeded from the records that exist, never recomputed.
    private(set) var lifetimeSessions: Int
    /// The day this whole thing started. The anniversary engine's anchor.
    private(set) var firstSessionDate: Date?

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = StorageKeys.sessions
    private static let maxRecords = 1000

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lifetimeSessions = defaults.integer(forKey: StorageKeys.lifetimeSessions)
        firstSessionDate = defaults.object(forKey: StorageKeys.firstSession) as? Date
        load()
        // Seeding for logs that predate the counter — and for the debug
        // seeders, which write records straight into defaults.
        if records.count > lifetimeSessions {
            lifetimeSessions = records.count
            defaults.set(lifetimeSessions, forKey: StorageKeys.lifetimeSessions)
        }
        if firstSessionDate == nil, let first = records.first {
            firstSessionDate = first.endedAt
            defaults.set(first.endedAt, forKey: StorageKeys.firstSession)
        }
    }

    // MARK: Writing

    func add(
        minutes: Int, place: Place? = nil, buddy: Buddy? = nil,
        endedAt: Date = Date()
    ) {
        records.append(SessionRecord(
            endedAt: endedAt, minutes: minutes,
            place: place?.rawValue, buddy: buddy?.rawValue
        ))
        if records.count > Self.maxRecords {
            records.removeFirst(records.count - Self.maxRecords)
        }
        lifetimeSessions += 1
        defaults.set(lifetimeSessions, forKey: StorageKeys.lifetimeSessions)
        if firstSessionDate == nil {
            firstSessionDate = endedAt
            defaults.set(endedAt, forKey: StorageKeys.firstSession)
        }
        save()
    }

    func clearHistory() {
        records = []
        lifetimeSessions = 0
        firstSessionDate = nil
        defaults.removeObject(forKey: StorageKeys.lifetimeSessions)
        defaults.removeObject(forKey: StorageKeys.firstSession)
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data)
        else {
            return
        }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    // MARK: Stats

    /// The lifetime number — the one the bond, the journey and every
    /// threshold reads. Survives the trim; `records` is for charts and
    /// streaks, which only ever look weeks back.
    var totalSessions: Int { max(lifetimeSessions, records.count) }

    /// The record for a given calendar night, if one survives in the log —
    /// star stories compose themselves from this.
    func record(endedOn day: Date, calendar: Calendar = .current) -> SessionRecord? {
        records.last { calendar.isDate($0.endedAt, inSameDayAs: day) }
    }

    var todaySessions: Int {
        let calendar = Calendar.current
        return records.filter { calendar.isDateInToday($0.endedAt) }.count
    }

    var todayMinutes: Int {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDateInToday($0.endedAt) }
            .reduce(0) { $0 + $1.minutes }
    }

    /// The after-dark sessions themselves, oldest first — the k-th of these
    /// IS the atlas's k-th star, which is what lets a star tell its night
    /// back. Records the trim has eaten simply aren't tellable; the count
    /// above survives, the stories are best-effort by design.
    var nightRecords: [SessionRecord] {
        let calendar = Calendar.current
        return records.filter { record in
            let part = LaunchOptions.forcedDayPart
                ?? DayPart.from(hour: calendar.component(.hour, from: record.endedAt))
            return part == .night
        }
        .sorted { $0.endedAt < $1.endedAt }
    }

    /// Sessions finished after dark — the only input the star atlas has.
    ///
    /// A pure function over the log, like the journey unlocks: the sky keeps
    /// score without anything new being written down.
    var nightSessions: Int {
        let calendar = Calendar.current
        return records.filter { record in
            // Honouring a forced clock is what lets `-PawmodoroClock 22` plus
            // one real session add a star on the spot. In a Release build
            // `forcedDayPart` is a nil constant and this is the record's own
            // hour, always.
            let part = LaunchOptions.forcedDayPart
                ?? DayPart.from(hour: calendar.component(.hour, from: record.endedAt))
            return part == .night
        }.count
    }

    /// Sessions in the last seven days, today included.
    var weekSessions: Int {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(
            byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())
        ) else {
            return todaySessions
        }
        return records.filter { $0.endedAt >= cutoff }.count
    }

    /// A streak, and the days it forgave getting there.
    struct Streak: Equatable {
        var days: Int
        /// Days with no session that the streak survived anyway, newest first.
        var forgiven: [Date] = []

        var isForgiving: Bool { !forgiven.isEmpty }
    }

    /// Days with at least one session — **allowing one missed day per calendar
    /// week**.
    ///
    /// Streak apps run on guilt, and a counter that resets to zero for one bad
    /// Tuesday teaches people to stop opening the app rather than to focus. So
    /// the boat stays anchored for a day and the count keeps breathing. Two
    /// missed days in the same week does end it: forgiving everything would
    /// make the number mean nothing, which is its own kind of dishonest.
    ///
    /// `bestStreak` deliberately keeps the strict definition — one number that
    /// is kind and one that is exact.
    var currentStreak: Int { streak.days }

    var streak: Streak {
        let calendar = Calendar.current
        let activeDays = Set(records.map { calendar.startOfDay(for: $0.endedAt) })
        guard !activeDays.isEmpty else { return Streak(days: 0) }

        var cursor = calendar.startOfDay(for: Date())
        // Today not being done yet has never broken anything, and still doesn't.
        if !activeDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor)
            else { return Streak(days: 0) }
            cursor = yesterday
        }

        var days = 0
        var forgiven: [Date] = []
        var spent: Set<Int> = []

        while true {
            if activeDays.contains(cursor) {
                days += 1
            } else {
                let week = calendar.component(.weekOfYear, from: cursor)
                let year = calendar.component(.yearForWeekOfYear, from: cursor)
                let key = year * 100 + week
                // The second miss inside one week ends it.
                if spent.contains(key) { break }
                // And a gap is only forgiven when the streak actually continues
                // behind it. Without this the walk runs backwards through all
                // of history, forgiving one day a week forever.
                guard let earlier = calendar.date(byAdding: .day, value: -1, to: cursor),
                      activeDays.contains(earlier)
                else { break }
                spent.insert(key)
                forgiven.append(cursor)
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor)
            else { break }
            cursor = previous
        }
        return Streak(days: days, forgiven: forgiven)
    }

    var bestStreak: Int {
        let calendar = Calendar.current
        let activeDays = Set(records.map { calendar.startOfDay(for: $0.endedAt) }).sorted()
        guard !activeDays.isEmpty else { return 0 }

        var best = 1
        var running = 1
        for index in 1..<max(activeDays.count, 1) {
            let previous = activeDays[index - 1]
            let current = activeDays[index]
            let gap = calendar.dateComponents([.day], from: previous, to: current).day ?? 0
            if gap == 1 {
                running += 1
                best = max(best, running)
            } else {
                running = 1
            }
        }
        return best
    }

    struct DayCount: Identifiable {
        var date: Date
        var count: Int
        var id: Date { date }
    }

    /// Oldest first, one entry per day, for the bar chart on the stats screen.
    func dailyCounts(days: Int) -> [DayCount] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var buckets: [Date: Int] = [:]
        for record in records {
            buckets[calendar.startOfDay(for: record.endedAt), default: 0] += 1
        }
        return (0..<max(days, 1)).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            return DayCount(date: date, count: buckets[date] ?? 0)
        }
    }
}
