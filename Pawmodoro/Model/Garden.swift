import Foundation
import Observation

/// The window-box: three pockets of soil, seeded by dreams, watered by
/// showing up.
///
/// The Stardew loop with its dark half amputated. Seeds fall out of the
/// dream diary — the night the buddy dreams of the stag, the flower stags
/// eat is on the sill by morning. A pocket's growth is derived, never
/// stored: its stage is the count of days with at least one finished focus
/// session since planting, read straight from the log. Unwatered days pause
/// growth at the same pixel frame indefinitely. Nothing browns, nothing
/// wilts, and an empty pocket is soil, not absence.
enum PlantKind: String, Codable, CaseIterable, Identifiable {
    /// From a memory dream. Its bloom calls the dreamed species closer —
    /// the garden growing what the dreams dreamed, literally.
    case callflower
    /// From a travel dream. Its bloom keeps the sill in berries.
    case berrybush
    /// From a surreal dream. Its bloom rings for the lantern moth.
    case moonbell

    var id: String { rawValue }

    var name: String {
        switch self {
        case .callflower: "a callflower"
        case .berrybush: "a berrybush"
        case .moonbell: "a moonbell"
        }
    }

    func stageAsset(_ stage: Int) -> String {
        "plant_\(rawValue)_\(min(max(stage, 0), 3))"
    }

    /// The line under a bloom, once it opens.
    func bloomRemark(species: Species?) -> String {
        switch self {
        case .callflower:
            "the callflower is open — "
                + (species.map { "\($0.name.lowercased())s can smell it" }
                    ?? "something can smell it")
        case .berrybush: "the berrybush is carrying — the sill won't go bare"
        case .moonbell: "the moonbell rings at a pitch only moths respect"
        }
    }
}

/// A seed a dream dropped, waiting to be planted.
struct DreamSeed: Codable, Equatable {
    let kind: String
    /// The dreamed species, when the kind is a callflower.
    let species: String?
    let offeredOn: Date
}

/// One planted pocket. The stage lives nowhere — it is asked of the log.
struct GardenPocket: Codable, Equatable {
    let kind: String
    let species: String?
    let plantedOn: Date
}

@Observable
final class Garden {

    static let pocketCount = 3
    /// Watered days to a bloom.
    static let bloomStage = 3

    private(set) var pockets: [GardenPocket?] = Array(repeating: nil, count: pocketCount)
    private(set) var seedOnOffer: DreamSeed?

    @ObservationIgnored private var lastYieldDay: Int?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        load()
    }

    // MARK: Seeds

    static func seed(from dream: Dream, on date: Date) -> DreamSeed {
        switch dream {
        case .memory(let species):
            DreamSeed(kind: PlantKind.callflower.rawValue,
                      species: species.rawValue, offeredOn: date)
        case .travel:
            DreamSeed(kind: PlantKind.berrybush.rawValue,
                      species: nil, offeredOn: date)
        case .surreal:
            DreamSeed(kind: PlantKind.moonbell.rawValue,
                      species: nil, offeredOn: date)
        }
    }

    /// A dream just landed in the diary; by morning its seed is here. A new
    /// seed replaces an unplanted one — the wind took the old one somewhere
    /// nice.
    func offerSeed(from dream: Dream, on date: Date = Date()) {
        seedOnOffer = Self.seed(from: dream, on: date)
        save()
    }

    func plantOffered(in slot: Int, on date: Date = Date()) {
        guard pockets.indices.contains(slot), pockets[slot] == nil,
              let seed = seedOnOffer
        else { return }
        pockets[slot] = GardenPocket(
            kind: seed.kind, species: seed.species, plantedOn: date
        )
        seedOnOffer = nil
        save()
    }

    // MARK: Growth (derived, never stored)

    /// Days with at least one finished session since planting, the planting
    /// day included, capped at the bloom.
    func stage(of pocket: GardenPocket, log: SessionLog) -> Int {
        let start = calendar.startOfDay(for: pocket.plantedOn)
        let watered = Set(
            log.records
                .map { calendar.startOfDay(for: $0.endedAt) }
                .filter { $0 >= start }
        )
        return min(Self.bloomStage, watered.count)
    }

    func isBloomed(_ pocket: GardenPocket, log: SessionLog) -> Bool {
        stage(of: pocket, log: log) >= Self.bloomStage
    }

    /// Every open bloom, with its pocket index for bias bookkeeping.
    func blooms(log: SessionLog) -> [(slot: Int, pocket: GardenPocket)] {
        pockets.enumerated().compactMap { index, pocket in
            guard let pocket, isBloomed(pocket, log: log) else { return nil }
            return (index, pocket)
        }
    }

    /// A blooming berrybush restocks a bare sill once a day.
    func claimDailyYield(log: SessionLog, on date: Date = Date()) -> Bool {
        let day = Snack.dayNumber(for: date, calendar: calendar)
        guard day != lastYieldDay else { return false }
        guard blooms(log: log).contains(where: {
            $0.pocket.kind == PlantKind.berrybush.rawValue
        }) else { return false }
        lastYieldDay = day
        save()
        return true
    }

    /// Pick a bloom: the pocket returns to soil, and the caller hands out
    /// what the plant was holding.
    func pick(slot: Int, log: SessionLog) -> GardenPocket? {
        guard pockets.indices.contains(slot), let pocket = pockets[slot],
              isBloomed(pocket, log: log)
        else { return nil }
        pockets[slot] = nil
        save()
        return pocket
    }

    // MARK: Debug

    /// `-PawmodoroSeed callflower` — a seed on offer right now.
    func offerForDebug(kind: PlantKind) {
        seedOnOffer = DreamSeed(
            kind: kind.rawValue,
            species: kind == .callflower ? Species.stag.rawValue : nil,
            offeredOn: Date()
        )
        save()
    }

    /// `-PawmodoroBloom` — one of each, planted long enough ago to bloom
    /// against any seeded history.
    func bloomForDebug(on date: Date = Date()) {
        let past = date.addingTimeInterval(-9 * 86_400)
        pockets = [
            GardenPocket(kind: PlantKind.callflower.rawValue,
                         species: Species.stag.rawValue, plantedOn: past),
            GardenPocket(kind: PlantKind.berrybush.rawValue,
                         species: nil, plantedOn: past),
            GardenPocket(kind: PlantKind.moonbell.rawValue,
                         species: nil, plantedOn: past),
        ]
        save()
    }

    // MARK: Persistence

    private struct State: Codable {
        var pockets: [GardenPocket?]
        var seedOnOffer: DreamSeed?
        var lastYieldDay: Int?
    }

    private func load() {
        guard let data = defaults.data(forKey: StorageKeys.garden),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return }
        pockets = state.pockets
        seedOnOffer = state.seedOnOffer
        lastYieldDay = state.lastYieldDay
        if pockets.count != Self.pocketCount {
            pockets = Array(repeating: nil, count: Self.pocketCount)
        }
    }

    private func save() {
        let state = State(
            pockets: pockets, seedOnOffer: seedOnOffer, lastYieldDay: lastYieldDay
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: StorageKeys.garden)
    }
}
