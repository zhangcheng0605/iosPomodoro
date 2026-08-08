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
    /// What the sky was doing, if this was seen after the weather existed.
    ///
    /// Optional so that every journal written before Wave 4 decodes untouched
    /// — the same reason `heard` got its own key rather than widening this
    /// struct. Nothing backfills it and nothing should: "seen in clear
    /// weather" invented for a sighting from last March would be a memory the
    /// app made up.
    var weather: String?
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
    /// Species known only by their night visits to the sill — evidence, not
    /// sight. A tier below "seen", filled exclusively by leaving a snack out
    /// overnight, which is what makes it a gift of absence. Same own-key
    /// pattern as `heard`, for the same decoding reason.
    private(set) var nightKnown: [String: Date] = [:]
    /// Species once seen in the pale coat. One bit per species, marked with
    /// a small star on the sketch — a memory, never a set to complete.
    private(set) var paleSeen: [String: Date] = [:]

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

    // MARK: Known by night

    func hasNightKnown(_ species: Species) -> Bool {
        nightKnown[species.rawValue] != nil
    }

    var nightKnownCount: Int { nightKnown.count }

    /// One night acquaintance, for the journal page.
    struct NightEntry: Identifiable {
        let species: Species
        let since: Date
        var id: String { species.rawValue }
    }

    /// Oldest evidence first.
    var nightKnownEntries: [NightEntry] {
        nightKnown.compactMap { key, date in
            Species(rawValue: key).map { NightEntry(species: $0, since: date) }
        }
        .sorted { $0.since < $1.since }
    }

    func addNightKnown(_ species: Species, on date: Date = Date()) {
        guard nightKnown[species.rawValue] == nil else { return }
        nightKnown[species.rawValue] = date
        saveNightKnown()
    }

    // MARK: The pale coats

    func hasPaleSeen(_ species: Species) -> Bool {
        paleSeen[species.rawValue] != nil
    }

    func addPaleSeen(_ species: Species, on date: Date = Date()) {
        guard paleSeen[species.rawValue] == nil else { return }
        paleSeen[species.rawValue] = date
        savePaleSeen()
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

    /// How much likelier a regular is to turn up where it lives.
    ///
    /// The other half of what a regular means, and the half that was written
    /// down in the plan and never built: the marked sprite says you know each
    /// other, and this is the part that acts like it.
    ///
    /// The number is in the same currency the fortune slip and the garden
    /// press with — a multiplier on `Species.Rarity.chance` — and it is
    /// deliberately the smallest thumb in the app by a long way: a slip
    /// presses at 4, a blooming callflower at 5, a returned traveler at 6, a
    /// regular at 1.2. Every other thumb is temporary — a day, a session, a
    /// flowering — and this one is forever, which is the whole argument for
    /// it being the quietest.
    ///
    /// Measured on device, 200k rolls of the real queue per arm, one common
    /// species made a regular: at the Meadow it goes from 23.5% of sessions
    /// to 28.1%, at the Harbor from 15.8% to 19.2%. That is a session in
    /// twenty turning from an empty meadow into the butterfly — the whole of
    /// the feeling, and none of the arithmetic anybody could notice.
    static let regularBoost = 1.2

    /// The weight to multiply a species' own chance by in the session about
    /// to start — one for everybody except your regular, standing in the
    /// place it lives.
    ///
    /// Deliberately *not* pressed through `TimerEngine.SightingBias`, even
    /// though the arithmetic is identical, because that seam hands its
    /// species first refusal ahead of the whole queue. Measured at this very
    /// same weight, that path takes the Harbor gull from 15.8% of sessions
    /// to 49.5% and takes a third off every other creature on the water; the
    /// Meadow butterfly reaches 54%. Once two or three species in a place
    /// had become regulars, nothing else would get a look in — which is the
    /// opposite of what a journal is for.
    ///
    /// Multiplied in place instead, the queue's order is untouched, so the
    /// 3–5 points a regular gains come mostly out of the sessions where
    /// nothing turned up at all: at the Harbor, +3.4 for the gull against
    /// −1.1 from the empty sessions and no more than −0.6 from any other
    /// animal. A regular is likelier; nobody is crowded out.
    ///
    /// Monotonic like everything else here — `count` only ever rises and
    /// `regularAt` is a threshold, so a weight that has gone to 1.2 can
    /// never come back down. There is no way to stop being someone's
    /// regular.
    func regularWeight(for species: Species, at place: Place) -> Double {
        guard species.homePlace == place, isRegular(species) else { return 1 }
        return Self.regularBoost
    }

    /// What `rollSighting`'s ordinary queue should actually roll against.
    ///
    /// The one seam the engine calls, so the whole of "a regular is likelier
    /// where it lives" lives here rather than half here and half in a
    /// multiplication at the call site. Capped like the bias path is, at the
    /// same 0.85: nothing in this app is ever a certainty, and a cap that
    /// only exists on one of two paths is a cap somebody will walk around
    /// later. At today's numbers the cap is unreachable — a mythic is the
    /// dearest at 0.5, and 0.5 × 1.2 is 0.6 — which is exactly when to write
    /// it down, while it costs nothing.
    func sightingChance(for species: Species, at place: Place) -> Double {
        min(0.85, species.rarity.chance * regularWeight(for: species, at: place))
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
                .filter { !$0.isPhenomenon && $0.homePlace == place }
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

    func add(
        _ species: Species,
        at place: Place,
        dayPart: DayPart,
        weather: Weather? = nil,
        on date: Date = Date()
    ) {
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
                dayPart: dayPart.rawValue,
                weather: weather?.rawValue
            )
        }
        save()
    }

    /// Whether this has been seen in the current calendar year.
    ///
    /// Only the first thunder asks. It is the one thing in the app whose
    /// availability resets — not decays: nothing is taken away, a second
    /// chance is simply given, once a year, forever.
    func hasSeenThisYear(_ species: Species) -> Bool {
        guard let record = records[species.rawValue] else { return false }
        let calendar = WorldCalendar.calendar
        return calendar.component(.year, from: record.lastSeen)
            == calendar.component(.year, from: WorldCalendar.now)
    }

    func clear() {
        records = [:]
        heard = [:]
        nightKnown = [:]
        paleSeen = [:]
        save()
        saveHeard()
        saveNightKnown()
        savePaleSeen()
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
                place: species.homePlace.rawValue,
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
        if let data = defaults.data(forKey: StorageKeys.nightKnown),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            nightKnown = decoded
        }
        if let data = defaults.data(forKey: StorageKeys.paleCoats),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            paleSeen = decoded
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

    private func saveNightKnown() {
        guard let data = try? JSONEncoder().encode(nightKnown) else { return }
        defaults.set(data, forKey: StorageKeys.nightKnown)
    }

    private func savePaleSeen() {
        guard let data = try? JSONEncoder().encode(paleSeen) else { return }
        defaults.set(data, forKey: StorageKeys.paleCoats)
    }
}
