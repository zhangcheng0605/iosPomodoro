import Foundation
import Observation

/// The places keep hours.
///
/// The ferry casts off at 8:00 and 18:00 whether anyone is watching; the
/// Keep's tower catches first light in the dawn hour; the Onsen's steam
/// doubles after nine. Every event is a pure function of the clock — no
/// state, no timers, rendered by the same TimelineView machinery as the
/// skies — and the Timetable page fills in an entry only after you have
/// personally been there in the window. There is no last ferry, nothing
/// depends on being seen, and unwitnessed rows do not render: no
/// denominators, ever.
enum ClockworkEvent: String, CaseIterable, Identifiable {
    case ferryMorning
    case ferryEvening
    case keepFirstLight
    case onsenNightSteam
    case meadowHeron
    case cloudspireBeacon

    var id: String { rawValue }

    var place: Place {
        switch self {
        case .ferryMorning, .ferryEvening: .harbor
        case .keepFirstLight: .keep
        case .onsenNightSteam: .onsen
        case .meadowHeron: .meadow
        case .cloudspireBeacon: .cloudspire
        }
    }

    var name: String {
        switch self {
        case .ferryMorning: "The ferry, out"
        case .ferryEvening: "The ferry, home"
        case .keepFirstLight: "First light on the tower"
        case .onsenNightSteam: "The late steam"
        case .meadowHeron: "The heron's shift"
        case .cloudspireBeacon: "The beacon"
        }
    }

    /// The Timetable line, shown only once the event has been witnessed —
    /// learned knowledge, not a listing.
    var schedule: String {
        switch self {
        case .ferryMorning: "8:00, sharp"
        case .ferryEvening: "18:00, sharp"
        case .keepFirstLight: "the dawn hour"
        case .onsenNightSteam: "after 21:00"
        case .meadowHeron: "first thing, at the stream"
        case .cloudspireBeacon: "from full dark"
        }
    }

    /// Whether this event is happening at `date`. `-PawmodoroClock <h>`
    /// pins the hour and widens each window to the whole of it — the pane
    /// can pin an hour, not a minute.
    func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        let pinned = LaunchOptions.forcedClockHour
        let hour = pinned ?? calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let wholeHour = pinned != nil
        switch self {
        case .ferryMorning:
            return hour == 8 && (wholeHour || minute < 12)
        case .ferryEvening:
            return hour == 18 && (wholeHour || minute < 12)
        case .keepFirstLight:
            return hour == 6
        case .onsenNightSteam:
            return hour >= 21
        case .meadowHeron:
            return hour == 6 || hour == 7
        case .cloudspireBeacon:
            return hour >= 21 || hour < 5
        }
    }

    /// The event running at this place right now, if one is.
    static func active(
        at date: Date, place: Place, calendar: Calendar = .current
    ) -> ClockworkEvent? {
        allCases.first { $0.place == place && $0.isActive(at: date, calendar: calendar) }
    }
}

/// What you've personally caught happening, with the date you learned it.
@Observable
final class Timetable {

    private(set) var witnessed: [String: Date] = [:]

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func hasWitnessed(_ event: ClockworkEvent) -> Bool {
        witnessed[event.rawValue] != nil
    }

    /// One learned row, for the almanac card.
    struct Entry: Identifiable {
        let event: ClockworkEvent
        let learned: Date
        var id: String { event.rawValue }
    }

    var entries: [Entry] {
        witnessed.compactMap { key, date in
            ClockworkEvent(rawValue: key).map { Entry(event: $0, learned: date) }
        }
        .sorted { $0.learned < $1.learned }
    }

    func witness(_ event: ClockworkEvent, on date: Date = Date()) {
        guard witnessed[event.rawValue] == nil else { return }
        witnessed[event.rawValue] = date
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let data = defaults.data(forKey: StorageKeys.timetable),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return }
        witnessed = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(witnessed) else { return }
        defaults.set(data, forKey: StorageKeys.timetable)
    }
}
