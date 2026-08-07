import CoreGraphics
import Foundation
import Observation

/// The first five seconds of the day: what the buddy is doing when you catch
/// it mid-life, what it carried home, and what yesterday left stuck to it.
///
/// Everything is decided once, at the first open of a calendar day, from a
/// seed of the date and the buddy — then it is pure display. The second open
/// of a day is plain idle: the greeting can't be re-pulled, which is exactly
/// what makes tomorrow's first open worth something.
///
/// Guilt-proofing is structural. Every hello in the table is warm or funny —
/// there is no "I missed you" draw. A gap of six hours or six months yields
/// the same single gift. Nothing here can read as a remark about absence,
/// because absence is not an input the tables can see.

// MARK: - Hellos

/// One greeting vignette, played over the ordinary idle.
enum Hello: String, CaseIterable, Identifiable {
    // The commons.
    case bigStretch
    case mothChase
    case peek
    case newSpot
    case shake
    case slowMorning
    // The rares. Recorded when seen; never teased in a caption.
    case leafGift
    case mothLands
    /// The arrival after time away — always carrying something. Takes the
    /// greeting slot so the gift *is* the hello, not a second event.
    case carriedHome

    var id: String { rawValue }

    var isRare: Bool {
        switch self {
        case .leafGift, .mothLands: true
        default: false
        }
    }

    /// The line under the buddy while the vignette plays.
    func caption(_ name: String) -> String {
        switch self {
        case .bigStretch: "\(name), caught mid-stretch. The big one, tip to tail"
        case .mothChase: "\(name) has noticed a moth. Nothing else matters now"
        case .peek: "\(name) was waiting behind the timer. Found you first"
        case .newSpot: "\(name), asleep in a brand-new spot — the old spot, moved slightly"
        case .shake: "one all-over shake, and now \(name)'s day can start"
        case .slowMorning: "\(name) offers one slow blink. It's that kind of morning"
        case .leafGift: "\(name) brought you a leaf. It is, verifiably, a good leaf"
        case .mothLands: "the moth landed on \(name). Nobody move"
        case .carriedHome: "\(name) came back carrying something — set down, for you"
        }
    }

    /// A weighted deterministic pick: commons five tickets each, rares one.
    /// The weights are gentle on purpose, and no caption ever hints at the
    /// tier — a hello is a hello, not a pull.
    static func pick(seed: Int) -> Hello {
        let commons: [Hello] = [.bigStretch, .mothChase, .peek, .newSpot, .shake, .slowMorning]
        let rares: [Hello] = [.leafGift, .mothLands]
        let total = commons.count * 5 + rares.count
        var ticket = abs(seed) % total
        if ticket < commons.count * 5 { return commons[ticket / 5] }
        ticket -= commons.count * 5
        return rares[ticket]
    }
}

// MARK: - Trinkets

/// A small found thing, carried home and kept.
enum Trinket: String, Codable, CaseIterable, Identifiable {
    case seaglass, mapleleaf, feather, button, ribbon, bottlecap
    case shell, pinecone, bell, sprig, stone, snowdrop

    var id: String { rawValue }

    var assetName: String { "keep_\(rawValue)" }

    var name: String {
        switch self {
        case .seaglass: "Sea glass"
        case .mapleleaf: "A maple leaf"
        case .feather: "A feather"
        case .button: "A button"
        case .ribbon: "A ribbon"
        case .bottlecap: "A bottle cap"
        case .shell: "A shell"
        case .pinecone: "A pinecone"
        case .bell: "A small bell"
        case .sprig: "A green sprig"
        case .stone: "A smooth stone"
        case .snowdrop: "A snowdrop"
        }
    }

    /// The drawer's one dry line per object.
    var note: String {
        switch self {
        case .seaglass: "the sea made it soft"
        case .mapleleaf: "the exact best one of the year"
        case .feather: "somebody's spare"
        case .button: "lost by someone long ago, found by somebody good"
        case .ribbon: "already tangled. Worth it"
        case .bottlecap: "treasure is a matter of opinion"
        case .shell: "still sounds like the harbor"
        case .pinecone: "heavier than it looks. Carried anyway"
        case .bell: "rings once per good idea"
        case .sprig: "picked with care and some difficulty"
        case .stone: "the smoothest one there was"
        case .snowdrop: "first one up this year"
        }
    }

    /// What turns up where. Keyed by the place you were last, so the gift is
    /// a receipt from your own history — and by the season, so autumn leaves
    /// exist only in autumn. Never by how much you focused: this house does
    /// not price affection by output.
    static func find(
        at place: Place, season: Season?, day: Int
    ) -> Trinket {
        // A season's find takes every other seasonal day it is eligible.
        if let season {
            let seasonal: Trinket? = switch season {
            case .autumn: .mapleleaf
            case .winter: .snowdrop
            case .sakura, .fireflies, .lanterns: nil
            }
            if let seasonal, day % 2 == 0 { return seasonal }
        }
        let table: [Trinket] = switch place {
        case .meadow: [.button, .feather, .sprig]
        case .woods: [.pinecone, .feather, .sprig]
        case .harbor: [.seaglass, .shell, .bottlecap]
        case .blossom: [.ribbon, .button, .bell]
        case .onsen: [.stone, .bell, .button]
        case .keep: [.bell, .button, .bottlecap]
        case .cloudspire: [.feather, .ribbon, .stone]
        case .peaks: [.stone, .pinecone, .feather]
        }
        return table[abs(day) % table.count]
    }
}

/// One kept thing, with its provenance — the date, the place it came from,
/// and who carried it home. The provenance is the point: each object is a
/// dated proof the two of you were living alongside each other.
struct KeepsakeRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let keepsake: String
    let date: Date
    let place: String
    let finder: String
}

/// Every trinket ever carried home. The plan's one collection surface —
/// anything else that banks an object banks it here, never into a second
/// drawer.
@Observable
final class KeepsakeDrawer {
    private(set) var items: [KeepsakeRecord] = []

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ trinket: Trinket, place: Place, finder: Buddy, on date: Date = Date()) {
        items.append(KeepsakeRecord(
            id: UUID(), keepsake: trinket.rawValue, date: date,
            place: place.rawValue, finder: finder.rawValue
        ))
        save()
    }

    /// `-PawmodoroFillDrawer` — one of everything, for looking at the grid.
    func fillForDebug() {
        let calendar = Calendar.current
        for (index, trinket) in Trinket.allCases.enumerated() {
            let date = calendar.date(byAdding: .day, value: -index, to: Date()) ?? Date()
            items.append(KeepsakeRecord(
                id: UUID(), keepsake: trinket.rawValue, date: date,
                place: Place.allCases[index % Place.allCases.count].rawValue,
                finder: Buddy.cat.rawValue
            ))
        }
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: StorageKeys.drawer),
              let decoded = try? JSONDecoder().decode([KeepsakeRecord].self, from: data)
        else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: StorageKeys.drawer)
    }
}

// MARK: - Burrs

/// Yesterday, still attached: a burr from the meadow, one petal glued on in
/// blossom season, salt after Harbor. Tap it and it pops off with a shake.
/// Ignore it and the buddy shakes it off itself — the anti-dirty-state, and
/// it curates itself.
enum Burr: String, CaseIterable, Identifiable {
    case burr, petal, salt, snow, leaf, seed

    var id: String { rawValue }

    var assetName: String { "burr_\(rawValue)" }

    /// "a burr", for the caption.
    var label: String {
        switch self {
        case .burr: "a burr"
        case .petal: "a petal"
        case .salt: "a crust of sea salt"
        case .snow: "a cap of snow"
        case .leaf: "a scrap of leaf"
        case .seed: "a grass seed"
        }
    }

    /// What sticks where. Season first — a petal in blossom season beats the
    /// local flora — then the place you were last.
    static func of(place: Place, season: Season?, day: Int) -> Burr {
        if let season {
            let seasonal: Burr? = switch season {
            case .sakura: .petal
            case .autumn: .leaf
            case .winter: .snow
            case .fireflies, .lanterns: nil
            }
            if let seasonal, day % 2 == 1 { return seasonal }
        }
        switch place {
        case .meadow: return .seed
        case .woods: return .burr
        case .harbor: return .salt
        case .blossom: return .petal
        case .onsen: return day % 2 == 0 ? .leaf : .seed
        case .keep: return .seed
        case .cloudspire: return .snow
        case .peaks: return .snow
        }
    }
}

extension Buddy {
    /// Where a burr sits, in units of the sprite's size from its centre.
    /// Placement is data, like every quirk: the ear region for most, lower
    /// for the hedgehog (whose top half is spines), the round flank for the
    /// capybara, the tuft for the owl.
    var burrAnchor: CGSize {
        switch self {
        case .hedgehog: CGSize(width: 0.04, height: -0.16)
        case .penguin: CGSize(width: 0.15, height: -0.30)
        case .capybara: CGSize(width: 0.21, height: -0.20)
        case .owl: CGSize(width: 0.20, height: -0.33)
        default: CGSize(width: 0.18, height: -0.28)
        }
    }
}

// MARK: - The doorstep itself

@Observable
final class Doorstep {

    /// Today's greeting, if it hasn't been played yet this launch.
    private(set) var hello: Hello?
    /// What was carried home, until it is picked up.
    private(set) var find: Trinket?
    /// What yesterday left attached, until it is popped.
    private(set) var burr: Burr?

    @ObservationIgnored private var lastOpen: Date?
    @ObservationIgnored private var lastGreetedDay: Int?
    @ObservationIgnored private var raresSeen: [String] = []
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar

    /// Hours away before the hello becomes an arrival with a gift.
    static let awayThreshold: TimeInterval = 6 * 3600

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        load()
    }

    /// Called on launch and on every foregrounding. Decides the whole
    /// doorstep once per calendar day; every later call only refreshes the
    /// away-clock.
    func arrive(place: Place, buddy: Buddy, season: Season?, now: Date = Date()) {
        let previous = lastOpen
        lastOpen = now
        defer { save() }

        let day = Snack.dayNumber(for: now, calendar: calendar)
        guard day != lastGreetedDay else { return }
        lastGreetedDay = day

        let away = previous.map { now.timeIntervalSince($0) } ?? 0
        let seed = day &+ Self.stableHash(buddy.rawValue)

        if away >= Self.awayThreshold {
            // The gift takes the greeting slot: the arrival IS the hello.
            // One per day, however long the gap — absence is never graded.
            find = Trinket.find(at: place, season: season, day: day)
            hello = .carriedHome
        } else {
            hello = Hello.pick(seed: seed)
            // Some mornings, yesterday is still attached. Never alongside a
            // rare hello — one small event at a time.
            if hello?.isRare != true, seed % 3 == 0 {
                burr = Burr.of(place: place, season: season, day: day)
            }
        }
        if let hello, hello.isRare, !raresSeen.contains(hello.rawValue) {
            raresSeen.append(hello.rawValue)
        }
    }

    /// The vignette plays once per day: taking it clears it.
    func claimHello() -> Hello? {
        defer { hello = nil }
        return hello
    }

    /// Pick the find up off the ground and into the drawer.
    func bankFind(into drawer: KeepsakeDrawer, place: Place, finder: Buddy) -> Trinket? {
        guard let find else { return nil }
        drawer.add(find, place: place, finder: finder)
        self.find = nil
        return find
    }

    /// Off with a shake, tapped or not.
    func popBurr() {
        burr = nil
    }

    // MARK: Debug

    func forceHello(_ forced: Hello) { hello = forced }
    func forceFind(_ forced: Trinket) { find = forced }
    func forceBurr(_ forced: Burr) { burr = forced }

    /// Deterministic across launches, unlike `String.hashValue`, which is
    /// salted per process and would reroll the doorstep on every cold start.
    static func stableHash(_ text: String) -> Int {
        var hash = 5381
        for byte in text.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return abs(hash)
    }

    // MARK: Persistence

    private struct State: Codable {
        var lastOpen: Date?
        var lastGreetedDay: Int?
        var raresSeen: [String]
    }

    private func load() {
        guard let data = defaults.data(forKey: StorageKeys.doorstep),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return }
        lastOpen = state.lastOpen
        lastGreetedDay = state.lastGreetedDay
        raresSeen = state.raresSeen
    }

    private func save() {
        let state = State(
            lastOpen: lastOpen, lastGreetedDay: lastGreetedDay, raresSeen: raresSeen
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: StorageKeys.doorstep)
    }
}
