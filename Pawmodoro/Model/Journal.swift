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

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = StorageKeys.journal

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: Reading

    func record(for species: Species) -> SightingRecord? { records[species.rawValue] }

    func hasSeen(_ species: Species) -> Bool { records[species.rawValue] != nil }

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
        save()
    }

    /// Debug only — fills the journal so the seen state can be looked at
    /// without finding twelve animals by hand.
    func fillForDebug() {
        let now = Date()
        for species in Species.allCases where records[species.rawValue] == nil {
            records[species.rawValue] = SightingRecord(
                firstSeen: now,
                lastSeen: now,
                count: 1,
                place: (species.places.first ?? .meadow).rawValue,
                dayPart: (species.dayParts.first ?? .day).rawValue
            )
        }
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: SightingRecord].self, from: data)
        else { return }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
