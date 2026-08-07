import Foundation
import Observation

/// The day's slip, drawn when the first focus session *starts*.
///
/// Everything else in the app rewards finishing; the slip rewards
/// beginning, which is the hard part of focus. The mysticism is a mirror:
/// each slip carries one gentle luck grade — no curse tier exists in this
/// shrine — and one line that is secretly a pure function of the user's own
/// history. And the slip quietly comes true: the place or species it names
/// gets a small real bias in the day's rolls, threaded through the same
/// seam a blooming flower or a returned traveler presses.
///
/// Template law, enforced here and in review: no gap, count, or streak is
/// ever referenced as judgment. The slip flatters with facts or says
/// nothing.
struct Fortune: Codable, Equatable, Identifiable {
    var id: String { "fortune.\(Snack.dayNumber(for: date))" }
    let date: Date
    /// "Small luck" — the grade line. Only degrees of gentle.
    let grade: String
    /// The one true thing, phrased as an omen.
    let line: String
    /// What the slip nudges, if anything.
    let biasSpecies: String?
    let biasPlace: String?
}

@Observable
final class FortuneTeller {

    /// Today's slip, if one has been drawn. Stays up all day — the paper
    /// corner on the phase chip reads from this.
    var today: Fortune? {
        slips.last.flatMap {
            Calendar.current.isDateInToday($0.date) ? $0 : nil
        }
    }

    /// The archive, newest last. Capped — a shrine keeps a box, not a
    /// warehouse.
    private(set) var slips: [Fortune] = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    private static let keep = 60

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        load()
    }

    /// Draw, if today hasn't drawn yet. Returns the fresh slip exactly once.
    func drawIfDue(
        log: SessionLog, journal: Journal, place: Place, buddy: Buddy,
        moonIsFull: Bool, season: Season?, on date: Date = Date(),
        row: Int? = nil
    ) -> Fortune? {
        guard today == nil else { return nil }
        let slip = Self.compose(
            log: log, journal: journal, place: place, buddy: buddy,
            moonIsFull: moonIsFull, season: season, date: date, row: row
        )
        slips.append(slip)
        if slips.count > Self.keep {
            slips.removeFirst(slips.count - Self.keep)
        }
        save()
        return slip
    }

    // MARK: Composition

    /// The whole oracle: gather the true facts that exist today, and let the
    /// date pick one. Deterministic end to end.
    static func compose(
        log: SessionLog, journal: Journal, place: Place, buddy: Buddy,
        moonIsFull: Bool, season: Season?, date: Date, row: Int? = nil
    ) -> Fortune {
        let day = Snack.dayNumber(for: date)
        let seed = Doorstep.stableHash("slip.\(day)")

        var facts: [(line: String, species: Species?, place: Place?)] = []

        // The hour the log likes best. Never phrased as a count.
        if let band = bestBand(log: log) {
            let line = switch band {
            case .morning: "your best hours come before the dew dries"
            case .afternoon: "the afternoon carries you further than it lets on"
            case .evening: "the evening is yours. The lamp agrees"
            }
            facts.append((line, nil, nil))
        }
        // A species nearby that the journal hasn't met. The slip that
        // demonstrably comes true.
        let unseenHere = Species.allCases.first {
            !journal.hasSeen($0) && !$0.isPhenomenon && $0.places.contains(place)
                && $0.rarity != .mythic
        }
        if let unseen = unseenHere {
            facts.append((
                "the \(unseen.name.lowercased()) is closer than it has been",
                unseen, place
            ))
        }
        // The buddy's palate, read as weather.
        facts.append((
            "\(buddy.favoriteSnack.plural) weather, if you can find any", nil, nil
        ))
        // The sky's own plans.
        if moonIsFull {
            facts.append((
                "a full moon tonight — worth leaving something on the sill",
                nil, nil
            ))
        }
        if season == .sakura {
            facts.append(("a petal in your tea before noon. Lucky", nil, nil))
        }
        // The quiet fallback, always available.
        facts.append(("small luck, evenly spread", nil, nil))

        let pick = facts[(row ?? seed) % facts.count]
        let grades = ["Great luck", "Good luck", "Small luck", "Luck, eventually"]
        let grade = grades[(seed / 7) % grades.count]

        return Fortune(
            date: date, grade: grade, line: pick.line,
            biasSpecies: pick.species?.rawValue, biasPlace: pick.place?.rawValue
        )
    }

    private enum Band { case morning, afternoon, evening }

    /// Which third of the day holds the most finished sessions — nil until
    /// the log has enough to say anything (an empty oracle stays quiet).
    private static func bestBand(log: SessionLog) -> Band? {
        guard log.records.count >= 8 else { return nil }
        let calendar = Calendar.current
        var counts: [Band: Int] = [.morning: 0, .afternoon: 0, .evening: 0]
        for record in log.records {
            let hour = calendar.component(.hour, from: record.endedAt)
            let band: Band = hour < 12 ? .morning : (hour < 18 ? .afternoon : .evening)
            counts[band, default: 0] += 1
        }
        return counts.max { $0.value < $1.value }?.key
    }

    // MARK: Persistence

    private func load() {
        guard let data = defaults.data(forKey: StorageKeys.fortunes),
              let decoded = try? JSONDecoder().decode([Fortune].self, from: data)
        else { return }
        slips = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(slips) else { return }
        defaults.set(data, forKey: StorageKeys.fortunes)
    }
}
