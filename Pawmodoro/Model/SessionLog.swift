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

    /// Consecutive days with at least one session. Today not being done yet does
    /// not break the streak — only a fully missed day does.
    var currentStreak: Int {
        let calendar = Calendar.current
        let activeDays = Set(records.map { calendar.startOfDay(for: $0.endedAt) })
        guard !activeDays.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: Date())
        if !activeDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  activeDays.contains(yesterday)
            else {
                return 0
            }
            cursor = yesterday
        }

        var streak = 0
        while activeDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
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
