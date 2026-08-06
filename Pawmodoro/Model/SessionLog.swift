import Foundation
import Observation

/// One completed focus session.
struct SessionRecord: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var endedAt: Date
    var minutes: Int
}

/// History of completed focus sessions, persisted on device. Nothing leaves the
/// phone — there is no account and no network call anywhere in the app.
@Observable
final class SessionLog {
    private(set) var records: [SessionRecord] = []

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = StorageKeys.sessions
    private static let maxRecords = 1000

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: Writing

    func add(minutes: Int, endedAt: Date = Date()) {
        records.append(SessionRecord(endedAt: endedAt, minutes: minutes))
        if records.count > Self.maxRecords {
            records.removeFirst(records.count - Self.maxRecords)
        }
        save()
    }

    func clearHistory() {
        records = []
        longestDrift = 0
        save()
        defaults.removeObject(forKey: StorageKeys.longestDrift)
    }

    // MARK: The longest drift

    /// The longest open hour anybody has sat, in seconds.
    ///
    /// Recorded, shown once in the almanac, and never used for anything else.
    /// It is not a target, there is no next tier, and nothing anywhere invites
    /// you to beat it — a personal best that the app kept asking about would
    /// turn the one part of this with no clock on it into a race. It only ever
    /// goes up, like everything else here.
    private(set) var longestDrift: TimeInterval = 0

    func recordLongestDrift(seconds: TimeInterval) {
        guard seconds > longestDrift else { return }
        longestDrift = seconds
        defaults.set(seconds, forKey: StorageKeys.longestDrift)
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data)
        else {
            return
        }
        records = decoded
        longestDrift = defaults.double(forKey: StorageKeys.longestDrift)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    // MARK: Stats

    var totalSessions: Int { records.count }

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
