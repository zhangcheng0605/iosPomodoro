import Foundation
import Observation

/// Something small to give the buddy, set out by the world when a focus
/// session finishes.
///
/// Feeding here is taste discovery, not maintenance. There is no hunger and
/// no meter: an unfed buddy is identical to a daily-fed one, forever. What
/// accumulates is knowledge — which of these this particular animal loves,
/// which it politely refuses — and knowledge is the one thing in this app
/// that is allowed to pile up.
enum Snack: String, Codable, CaseIterable, Identifiable {
    case acorn
    case sardine
    case yuzu
    case cracker
    case cloudberry
    case honeycomb
    case minnow
    /// Blossom season only.
    case mochi
    /// Leaf-fall only.
    case chestnut
    /// Snow only.
    case snowcookie

    var id: String { rawValue }

    var assetName: String { "snack_\(rawValue)" }

    /// With its article, for captions: "the sardine", "a rice cracker".
    var label: String {
        switch self {
        case .acorn: "an acorn"
        case .sardine: "a sardine"
        case .yuzu: "a yuzu"
        case .cracker: "a rice cracker"
        case .cloudberry: "a cloudberry"
        case .honeycomb: "a piece of honeycomb"
        case .minnow: "a dried minnow"
        case .mochi: "a sakura mochi"
        case .chestnut: "a roasted chestnut"
        case .snowcookie: "a snow cookie"
        }
    }

    /// Bare, for the Tastes card: "sardines", "rice crackers".
    var plural: String {
        switch self {
        case .acorn: "acorns"
        case .sardine: "sardines"
        case .yuzu: "yuzu"
        case .cracker: "rice crackers"
        case .cloudberry: "cloudberries"
        case .honeycomb: "honeycomb"
        case .minnow: "dried minnows"
        case .mochi: "sakura mochi"
        case .chestnut: "roasted chestnuts"
        case .snowcookie: "snow cookies"
        }
    }

    // MARK: What the day sets out

    /// The snack the world provides today, decided by the calendar and the
    /// place — a pure function, like everything else that is rolled once.
    /// Different places set out different things, which is what quietly makes
    /// travelling worth a buddy's while.
    static func ofTheDay(
        place: Place, season: Season?, date: Date = Date(),
        calendar: Calendar = .current
    ) -> Snack {
        let day = dayNumber(for: date, calendar: calendar)
        // A season's specialty turns up every third day while it lasts —
        // often enough to taste, rare enough to stay special.
        if let season, let special = specialty(of: season), day % 3 == 0 {
            return special
        }
        let table = pantry(at: place)
        return table[day % table.count]
    }

    /// What a season bakes. Fireflies and lanterns bring no food of their
    /// own — their nights are the treat.
    static func specialty(of season: Season) -> Snack? {
        switch season {
        case .sakura: .mochi
        case .autumn: .chestnut
        case .winter: .snowcookie
        case .fireflies, .lanterns: nil
        }
    }

    /// What each place tends to set out. Every entry is year-round, so the
    /// seasonal three arrive only by being in season.
    private static func pantry(at place: Place) -> [Snack] {
        switch place {
        case .meadow: [.honeycomb, .cracker, .acorn]
        case .woods: [.acorn, .cloudberry, .honeycomb]
        case .harbor: [.sardine, .minnow, .cracker]
        case .blossom: [.cracker, .honeycomb, .yuzu]
        case .onsen: [.yuzu, .cracker, .minnow]
        case .keep: [.honeycomb, .acorn, .cracker]
        case .cloudspire: [.cloudberry, .honeycomb, .minnow]
        case .peaks: [.cloudberry, .minnow, .acorn]
        }
    }

    /// Whole days since the reference date, in local time. Good enough to be
    /// stable across a day and change at midnight, which is all a daily pick
    /// needs.
    static func dayNumber(for date: Date, calendar: Calendar = .current) -> Int {
        Int(calendar.startOfDay(for: date).timeIntervalSinceReferenceDate / 86_400)
    }
}

/// How the buddy takes a snack. There are only warm answers.
enum SnackReaction {
    /// The favorite. The whole reason the Tastes card exists.
    case bliss
    /// A pleasant nibble — most pairings land here.
    case likes
    /// A polite refusal. The joke is always at the flavor, never the user,
    /// and the snack stays on the sill.
    case notMyThing
}

extension Buddy {
    /// One favorite per buddy, all reachable year-round — a favorite that
    /// only exists three weeks a year would be a lock, not a taste.
    var favoriteSnack: Snack {
        switch self {
        case .cat: .sardine
        case .dog: .cracker
        case .penguin: .minnow
        case .bunny: .cloudberry
        case .hamster: .acorn
        case .fox: .yuzu
        case .capybara: .yuzu
        case .redpanda: .honeycomb
        case .owl: .minnow
        case .otter: .sardine
        case .hedgehog: .acorn
        case .stray: .sardine
        }
    }

    /// The one thing each buddy would rather not, thanks.
    var snubbedSnack: Snack {
        switch self {
        case .cat: .yuzu
        case .dog: .cloudberry
        case .penguin: .honeycomb
        case .bunny: .sardine
        case .hamster: .minnow
        case .fox: .cracker
        case .capybara: .acorn
        case .redpanda: .sardine
        case .owl: .yuzu
        case .otter: .honeycomb
        case .hedgehog: .cracker
        case .stray: .cloudberry
        }
    }

    func reaction(to snack: Snack) -> SnackReaction {
        if snack == favoriteSnack { return .bliss }
        if snack == snubbedSnack { return .notMyThing }
        return .likes
    }

    /// The caption when the favorite lands. Follows the buddy's name in the
    /// caption, so no line starts with a capital.
    var blissRemark: String {
        switch self {
        case .cat: "a sardine! The tail went straight up"
        case .dog: "a rice cracker! The whole back half is wagging"
        case .penguin: "a minnow — swallowed whole, professionally"
        case .bunny: "cloudberries! Both ears are up"
        case .hamster: "an acorn — straight into the cheek, saved for later"
        case .fox: "yuzu! Named after it, loves it"
        case .capybara: "yuzu — smells like the onsen, tastes like home"
        case .redpanda: "honeycomb! Both paws, no manners"
        case .owl: "a minnow, gone in one blink"
        case .otter: "a sardine — eaten floating, naturally"
        case .hedgehog: "an acorn, circled twice and claimed"
        case .stray: "a sardine. Old habits, good ones now"
        }
    }

    /// The caption for the snub — dry, and never about the giver.
    var snubRemark: String {
        switch self {
        case .cat: "regards the yuzu as a practical joke"
        case .dog: "licked the cloudberry once and looked away"
        case .penguin: "has opinions about honey on feathers"
        case .bunny: "pushed the sardine somewhere further away"
        case .hamster: "tried the minnow against a cheek. It does not fit"
        case .fox: "finds the cracker too loud, apparently"
        case .capybara: "let the acorn roll away, serenely"
        case .redpanda: "sniffed the sardine and left it for the gulls"
        case .owl: "regards the yuzu as a category error"
        case .otter: "spent a while un-sticking honeycomb from whiskers. Never again"
        case .hedgehog: "bit the cracker. The cracker crunched back"
        case .stray: "gave the cloudberry a long look. No"
        }
    }
}

/// The sill: at most one snack, set out when a focus session finishes.
///
/// Deliberately not an inventory. The sill holds one snack or none — finish
/// five sessions without feeding and it still holds one. Nothing is counted,
/// nothing can be stockpiled, and a snack left out overnight is gone by
/// morning, set out for the wildlife rather than wasted.
@Observable
final class Pantry {

    /// What's on the sill right now.
    private(set) var sill: Snack?
    /// Which snacks each buddy has actually been given, keyed by species.
    /// This is the Tastes card's whole substance: reactions are pure data,
    /// so knowing a snack was tried is knowing how it went.
    private(set) var tried: [String: Set<String>] = [:]

    @ObservationIgnored private var sillDate: Date?
    @ObservationIgnored private var fedOn: Date?
    @ObservationIgnored private var fedCount = 0
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar

    /// Snacks a buddy will take in one day before contentedly waving the
    /// rest off. Fullness is drawn as satisfaction, never as rationing.
    static let dailyAppetite = 3

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        load()
        sweep()
    }

    // MARK: The sill

    /// Called when a focus session completes. The sill holds one snack;
    /// an uneaten one is kept, not replaced — nothing accumulates.
    func setOut(for place: Place, season: Season?, on date: Date = Date()) {
        guard sill == nil else { return }
        sill = Snack.ofTheDay(place: place, season: season, date: date, calendar: calendar)
        sillDate = date
        save()
    }

    /// A snack left out overnight has been found by something small and
    /// grateful by morning. Called on launch and on foregrounding.
    func sweep(on date: Date = Date()) {
        guard let sillDate, !calendar.isDate(sillDate, inSameDayAs: date) else { return }
        sill = nil
        self.sillDate = nil
        save()
    }

    /// Whether the buddy has room today.
    func hasAppetite(on date: Date = Date()) -> Bool {
        guard let fedOn, calendar.isDate(fedOn, inSameDayAs: date) else { return true }
        return fedCount < Self.dailyAppetite
    }

    /// Give the sill snack to the buddy. Returns how it went, or nil when
    /// there is nothing to give or no room left today.
    ///
    /// A snub leaves the snack on the sill — it was offered, not wasted —
    /// but still counts as tried: a refusal is knowledge too.
    @discardableResult
    func feed(_ buddy: Buddy, on date: Date = Date()) -> SnackReaction? {
        guard let snack = sill, hasAppetite(on: date) else { return nil }
        let reaction = buddy.reaction(to: snack)
        if reaction != .notMyThing {
            sill = nil
            sillDate = nil
            if let fedOn, calendar.isDate(fedOn, inSameDayAs: date) {
                fedCount += 1
            } else {
                fedCount = 1
            }
            fedOn = date
        }
        tried[buddy.rawValue, default: []].insert(snack.rawValue)
        save()
        return reaction
    }

    // MARK: Reading, for the Tastes card

    func hasTried(_ buddy: Buddy, _ snack: Snack) -> Bool {
        tried[buddy.rawValue]?.contains(snack.rawValue) ?? false
    }

    func triedCount(for buddy: Buddy) -> Int {
        tried[buddy.rawValue]?.count ?? 0
    }

    // MARK: Debug

    /// `-PawmodoroSnack <id>` — stock the sill without finishing a session.
    func forceSill(_ snack: Snack) {
        sill = snack
        sillDate = Date()
        save()
    }

    /// `-PawmodoroFillTastes` — every buddy has tried everything.
    func fillForDebug() {
        for buddy in Buddy.allCases {
            tried[buddy.rawValue] = Set(Snack.allCases.map(\.rawValue))
        }
        save()
    }

    // MARK: Persistence

    private struct State: Codable {
        var sill: String?
        var sillDate: Date?
        var fedOn: Date?
        var fedCount: Int
        var tried: [String: [String]]
    }

    private func load() {
        guard let data = defaults.data(forKey: StorageKeys.pantry),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return }
        sill = state.sill.flatMap(Snack.init(rawValue:))
        sillDate = state.sillDate
        fedOn = state.fedOn
        fedCount = state.fedCount
        tried = state.tried.mapValues(Set.init)
    }

    private func save() {
        let state = State(
            sill: sill?.rawValue,
            sillDate: sillDate,
            fedOn: fedOn,
            fedCount: fedCount,
            tried: tried.mapValues(Array.init)
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: StorageKeys.pantry)
    }
}
