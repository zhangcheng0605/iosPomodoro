import Foundation
import Observation

/// One species you've actually seen.
struct SightingRecord: Codable, Equatable {
    var firstSeen: Date
    var lastSeen: Date
    var count: Int
    /// Where and when it was first seen, for the journal's caption line.
    var place: String
    var dayPart: String
}

/// What you've seen, kept on device like everything else in this app.
///
/// Nothing is ever removed by ordinary use: a sighting is a memory, and taking
/// one away as a penalty is exactly the kind of mechanic this app doesn't do.
@Observable
final class Journal {
    private(set) var records: [String: SightingRecord] = [:]
    /// Things heard and never seen, by id, with the date they first reached
    /// you. Stored under their own key rather than folded into `records`: a
    /// sound has no place-and-hour to remember beyond its own, and widening
    /// `SightingRecord` would make every existing entry carry a nil.
    private(set) var heard: [String: Date] = [:]

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = StorageKeys.journal
    private static let heardKey = StorageKeys.heard

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: Things heard

    func hasHeard(_ sound: Heard) -> Bool { heard[sound.rawValue] != nil }

    func firstHeard(_ sound: Heard) -> Date? { heard[sound.rawValue] }

    var heardCount: Int { heard.count }

    /// Logged when it plays rather than on completion, unlike a sighting.
    /// You either heard it or you didn't — there is nothing to stay for.
    func addHeard(_ sound: Heard, on date: Date = Date()) {
        guard heard[sound.rawValue] == nil else { return }
        heard[sound.rawValue] = date
        saveHeard()
    }

    // MARK: Reading

    func record(for species: Species) -> SightingRecord? { records[species.rawValue] }

    func hasSeen(_ species: Species) -> Bool { records[species.rawValue] != nil }

    /// Sightings before a species stops being a species and becomes someone.
    static let regularAt = 5

    /// Whether you've seen enough of these to be seeing the *same* one.
    ///
    /// Relationship over collection, which is the whole argument for the
    /// journal: the fifth robin is not a fifth robin, it's the robin.
    func isRegular(_ species: Species) -> Bool {
        guard species.canBeRegular else { return false }
        return (records[species.rawValue]?.count ?? 0) >= Self.regularAt
    }

    var seenCount: Int { records.count }

    var total: Int { Species.allCases.count }

    /// Whether anything has ever been seen at a place — used to guarantee the
    /// first session somewhere new shows you something.
    func hasSeenAnything(at place: Place) -> Bool {
        records.values.contains { $0.place == place.rawValue }
    }

    /// The journal, split into pages. Forty-one tiles in one grid is a wall;
    /// by place it reads as somewhere you've been, which is the point.
    struct Page: Identifiable {
        let id: String
        let title: String
        let species: [Species]
    }

    static var pages: [Page] {
        var result: [Page] = Place.journey.compactMap { place in
            let here = Species.allCases
                .filter { !$0.isPhenomenon && $0.places.first == place }
                .sorted { $0.rarity.chance > $1.rarity.chance }
            guard !here.isEmpty else { return nil }
            return Page(id: place.rawValue, title: place.name, species: here)
        }
        let phenomena = Species.allCases.filter(\.isPhenomenon)
        if !phenomena.isEmpty {
            result.append(Page(id: "phenomena", title: "Phenomena", species: phenomena))
        }
        return result
    }

    /// Flat order, for counting.
    static var ordered: [Species] { pages.flatMap(\.species) }

    // MARK: Writing

    func add(_ species: Species, at place: Place, dayPart: DayPart, on date: Date = Date()) {
        if var existing = records[species.rawValue] {
            existing.count += 1
            existing.lastSeen = date
            records[species.rawValue] = existing
        } else {
            records[species.rawValue] = SightingRecord(
                firstSeen: date,
                lastSeen: date,
                count: 1,
                place: place.rawValue,
                dayPart: dayPart.rawValue
            )
        }
        save()
    }

    func clear() {
        records = [:]
        heard = [:]
        save()
        saveHeard()
    }

    /// Debug only — fills the journal so the seen state can be looked at
    /// without finding twelve animals by hand.
    func fillForDebug(count: Int = 1) {
        let now = Date()
        for sound in Heard.allCases where heard[sound.rawValue] == nil {
            heard[sound.rawValue] = now
        }
        saveHeard()
        for species in Species.allCases where records[species.rawValue] == nil {
            records[species.rawValue] = SightingRecord(
                firstSeen: now,
                lastSeen: now,
                count: max(1, count),
                place: (species.places.first ?? .meadow).rawValue,
                dayPart: (species.dayParts.first ?? .day).rawValue
            )
        }
        save()
    }

    // MARK: Persistence

    private func load() {
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: SightingRecord].self, from: data) {
            records = decoded
        }
        if let data = defaults.data(forKey: Self.heardKey),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            heard = decoded
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func saveHeard() {
        guard let data = try? JSONEncoder().encode(heard) else { return }
        defaults.set(data, forKey: Self.heardKey)
    }
}
