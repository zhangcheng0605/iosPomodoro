import Foundation
import Observation

/// Something the buddy dreamed while you were focusing.
///
/// The buddy sleeps through every focus session, and sleeping creatures dream.
/// What it dreams about is your shared journey: a species the two of you
/// actually saw, a vignette you sailed with, or — rarely — something that could
/// only happen asleep. The sentence this is built around is *"my cat just
/// dreamed about the whale we saw."*
///
/// Almost all of it is recycled. A memory dream reuses the field journal's
/// existing sepia sketch, a travel dream reuses the vignette sprite; only the
/// six surreal ones are new art. That is deliberate rather than thrifty: a rich
/// journal makes a rich dream life, which quietly makes the journal itself
/// worth more.
enum Dream: Hashable, Identifiable {
    /// Something you both saw. The heart of it.
    case memory(Species)
    /// Something you travelled with.
    case travel(Vignette)
    /// Something that only happens asleep.
    case surreal(Surreal)

    /// The six that had to be drawn. Ids match `tools/generate_sprites.py`.
    enum Surreal: String, CaseIterable, Hashable {
        case fishballoon, yarn, tub, meadow, train, moonrabbit

        var line: String {
            switch self {
            case .fishballoon: "A fish, holding the balloon's string."
            case .yarn: "A ball of yarn the size of a house."
            case .tub: "The tub, out at sea, quite happy about it."
            case .meadow: "The meadow, going on much further than it does."
            case .train: "The night train, with one window still lit."
            // Dreamed long before it is ever seen — the moon rabbit is real,
            // and only turns up under a full moon at three places.
            case .moonrabbit: "A rabbit-shaped shadow on the moon."
            }
        }
    }

    /// Stable across launches: the diary is keyed on it.
    var id: String {
        switch self {
        case .memory(let species): "memory.\(species.rawValue)"
        case .travel(let vignette): "travel.\(vignette.rawValue)"
        case .surreal(let surreal): "surreal.\(surreal.rawValue)"
        }
    }

    static func from(id: String) -> Dream? {
        let parts = id.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "memory": return Species(rawValue: parts[1]).map(Dream.memory)
        case "travel": return Vignette(rawValue: parts[1]).map(Dream.travel)
        case "surreal": return Surreal(rawValue: parts[1]).map(Dream.surreal)
        default: return nil
        }
    }

    var asset: String {
        switch self {
        case .memory(let species): species.sketchAsset
        case .travel(let vignette): vignette.assetName
        case .surreal(let surreal): "dream_\(surreal.rawValue)"
        }
    }

    /// Vignettes are drawn in full colour for the sky, so in a dream they are
    /// rendered as silhouettes instead — a sketch, like everything else here.
    var isSilhouette: Bool {
        if case .travel = self { return true }
        return false
    }

    /// What the thing is called, on its own.
    var subject: String {
        switch self {
        case .memory(let species): species.name.lowercased()
        case .travel(let vignette): vignette.name
        case .surreal: "something strange"
        }
    }

    /// The line under the bubble in the diary.
    var line: String {
        switch self {
        case .memory(let species): species.note
        case .travel(let vignette): vignette.dreamLine
        case .surreal(let surreal): surreal.line
        }
    }

    /// Every dream there is, for counting the diary against.
    static var everything: [Dream] {
        Species.allCases.map(Dream.memory)
            + [Vignette.sailboat, .balloon, .train].map(Dream.travel)
            + Surreal.allCases.map(Dream.surreal)
    }
}

extension Vignette {
    var name: String {
        switch self {
        case .sailboat: "the sailboat"
        case .balloon: "the balloon"
        case .train: "the night train"
        }
    }

    var dreamLine: String {
        switch self {
        case .sailboat: "Still crossing, in no hurry at all."
        case .balloon: "Higher than it ever goes awake."
        case .train: "Somewhere past Starfall, still going."
        }
    }
}

/// One dream, kept.
struct DreamRecord: Codable, Equatable {
    var firstDreamed: Date
    var lastDreamed: Date
    var count: Int
    /// Days between meeting the thing and dreaming about it, where that is
    /// knowable. It's what lets the diary write the relationship rather than
    /// just the fact — "three days after you met it".
    var daysAfter: Int?
}

/// Everything the buddy has dreamed and you stayed to see.
///
/// Leave a session early and the dream simply fades, unrecorded. Dreams are
/// like that, and it is the same no-guilt rule as the field journal: nothing is
/// taken away, some things are just not kept.
@Observable
final class DreamDiary {
    private(set) var records: [String: DreamRecord] = [:]

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = StorageKeys.dreams

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func record(for dream: Dream) -> DreamRecord? { records[dream.id] }

    func hasDreamed(_ dream: Dream) -> Bool { records[dream.id] != nil }

    var dreamedCount: Int { records.count }

    var total: Int { Dream.everything.count }

    func add(_ dream: Dream, daysAfter: Int? = nil, on date: Date = Date()) {
        if var existing = records[dream.id] {
            existing.count += 1
            existing.lastDreamed = date
            records[dream.id] = existing
        } else {
            records[dream.id] = DreamRecord(
                firstDreamed: date, lastDreamed: date, count: 1, daysAfter: daysAfter
            )
        }
        save()
    }

    func clear() {
        records = [:]
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: DreamRecord].self, from: data)
        else { return }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
