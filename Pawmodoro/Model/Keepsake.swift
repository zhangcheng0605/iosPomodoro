import Foundation

/// Something the buddy brought you.
///
/// The other direction, and the reason this era is not just a bigger set of
/// buttons: everything else in the app is you doing something to the world.
/// Rarely, after a session, there is a leaf on the desk. Nobody announced it,
/// nothing unlocked, and it will sit there until you happen to look.
///
/// ### It cannot be missed, only found
///
/// No notification, ever — the era's fence, and this is the feature most
/// tempted to break it. No badge on the stats button, no "1 new" anywhere.
/// A keepsake waits forever, which is what makes finding one feel like
/// finding something rather than collecting a delivery.
///
/// ### And it cannot be farmed
///
/// One roll per completed focus session at long odds, and the roll is against
/// the *session*, not against anything you did in it. There is no way to make
/// a keepsake more likely and nothing to optimise. That is deliberate: the
/// moment a stick is worth grinding for, it stops being a gift.
enum Keepsake: String, CaseIterable, Identifiable, Codable {
    case leaf
    case feather
    case pebble
    case ribbon
    case bottlecap
    case stick

    var id: String { rawValue }

    /// Odds per completed focus session, once the bond is deep enough that a
    /// buddy bringing you things makes sense at all.
    ///
    /// One in twenty-five: a handful a month for somebody sitting daily, and
    /// six of them is most of a year. Rare enough to be a surprise, common
    /// enough that somebody who uses the app properly meets the feature.
    static let chance = 1.0 / 25.0

    /// Nothing arrives before the buddy has decided about you. Reuses the bond
    /// rather than inventing a threshold, per the standing rule — and `.close`
    /// is where its own blurb says the buddy has started waiting by the door,
    /// which is exactly the character that brings you a stick.
    static let reachedAt: Bond = .close

    var name: String {
        switch self {
        case .leaf: "A leaf"
        case .feather: "A feather"
        case .pebble: "A pebble"
        case .ribbon: "A length of ribbon"
        case .bottlecap: "A bottle cap"
        case .stick: "A very good stick"
        }
    }

    /// The line under it on the shelf. Written as somebody describing an
    /// object on their desk, not as a reward being explained — and never
    /// naming the buddy, because buddies can be renamed and a model type
    /// cannot reach `settings.displayName(for:)`.
    var note: String {
        switch self {
        case .leaf: "Not from any tree nearby. It has been carried some way."
        case .feather: "Grey, and slightly bent. Kept anyway."
        case .pebble: "Perfectly ordinary. It was chosen over all the others."
        case .ribbon: "Faded, and knotted twice for reasons of its own."
        case .bottlecap: "Older than the app. No further explanation offered."
        case .stick: "It is a very good stick. That is the whole of it."
        }
    }

    /// The Sunday Post's sentence, the week one turns up.
    var postLine: String {
        switch self {
        case .leaf: "There was a leaf on the desk this week. No explanation."
        case .feather: "A feather turned up. It has been put somewhere safe."
        case .pebble: "Somebody brought a pebble in. It is a good pebble."
        case .ribbon: "A piece of ribbon appeared, knotted twice."
        case .bottlecap: "There is a bottle cap on the desk now. It stays."
        case .stick: "A stick was delivered this week, at some effort."
        }
    }

    var asset: String { "keepsake_\(rawValue)" }

    /// The one it brings, for a session count.
    ///
    /// Deterministic from the session index rather than random, so the six
    /// arrive in a fixed order and nobody can end up with four ribbons and no
    /// stick. It is a small collection and it should fill.
    static func next(after kept: Int) -> Keepsake {
        allCases[kept % allCases.count]
    }
}

/// What has been left on the desk, in the order it arrived.
///
/// Its own store rather than a field on the pouch: a keepsake is not a
/// purchase, it is not spendable, and folding it into the ledger the economy
/// reads would eventually invite somebody to price one.
@Observable
final class Shelf {
    private(set) var kept: [String] = []

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = StorageKeys.keepsakes

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.array(forKey: Self.storageKey) as? [String] {
            kept = stored
        }
        if let seeded = LaunchOptions.seedKeepsakes {
            kept = (0..<seeded).map { Keepsake.next(after: $0).rawValue }
        }
    }

    var items: [Keepsake] { kept.compactMap(Keepsake.init(rawValue:)) }

    var count: Int { kept.count }

    func has(_ keepsake: Keepsake) -> Bool { kept.contains(keepsake.rawValue) }

    /// Append-only, like everything else in this app. Duplicates are kept
    /// rather than collapsed — two pebbles is two pebbles, and a shelf that
    /// silently refuses the second one would be a set, not a shelf.
    func add(_ keepsake: Keepsake) {
        kept.append(keepsake.rawValue)
        defaults.set(kept, forKey: Self.storageKey)
    }
}
