import Foundation
import Observation

/// What you have traded for, and nothing else.
///
/// The only thing stored by the whole economy is this set of ids. The balance
/// is not in here and never will be — see `Acorns` for why — so there is
/// exactly one number to persist and it is a *list of things you own*, which
/// is the number that must survive.
///
/// ### Nothing here can be lost
///
/// There is no path in the app that removes an id from this set. Clearing
/// history does not (it erases the earned side and leaves what you bought).
/// Refunding Plus does not, because Plus and the pouch are separate roads to
/// the same door and walking one never closed the other. Every store in this
/// app is monotonic and this is no exception; the day it stops being one is
/// the day `HEARTH_PLAN`'s merge law stops working too.
@Observable
final class Pouch {

    /// Catalogue ids, as `CatalogItem.id` writes them.
    ///
    /// Stored as raw strings rather than decoded items, so that retiring a
    /// buddy can never make somebody's purchases undecodable — the same
    /// argument `ChronicleEvent.subject` makes. An unknown id costs nothing:
    /// it is skipped when spending is totted up and quietly kept in case it
    /// comes back.
    private(set) var owned: Set<String> = []

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = StorageKeys.owned

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        if LaunchOptions.ownEverything {
            owned.formUnion(CatalogItem.all.map(\.id))
        }
        if let den = LaunchOptions.forcedDen {
            owned.insert(CatalogItem.den(den).id)
        }
    }

    // MARK: Reading

    func owns(_ item: CatalogItem) -> Bool {
        owned.contains(item.id)
    }

    /// What every owned thing cost, at today's prices.
    ///
    /// Today's, not the price paid, and that is safe *because* prices may
    /// only ever fall: a price drop refunds the difference into everybody's
    /// pouch automatically, which is the pleasant direction for the surprise
    /// to run in. Storing the price paid would be the only way to make a
    /// rise safe, and rises are forbidden — so there is nothing to store.
    ///
    /// Ids that no longer resolve contribute nothing rather than crashing.
    var spent: Int {
        owned.compactMap(CatalogItem.from(id:)).reduce(0) { $0 + $1.price }
    }

    var count: Int { owned.count }

    /// Whether the hoard is complete. Used for one line in the cart and for
    /// nothing else — there is no "12 of 20" anywhere, per the era's
    /// no-hidden-count rule.
    var hasEverything: Bool {
        CatalogItem.all.allSatisfy(owns)
    }

    // MARK: Trading

    /// Keep the thing, forever.
    ///
    /// Deliberately does no affordability arithmetic. It cannot: the balance
    /// needs the session log, which lives on the engine, and the debug
    /// override lives on `LaunchOptions` — so a check here would either be a
    /// second opinion about the balance or a lie. `TimerEngine.trade(_:)` is
    /// the one place that decides, exactly as `isUnlocked(_:)` is the one
    /// place that decides entitlement.
    func take(_ item: CatalogItem) {
        guard !owns(item) else { return }
        owned.insert(item.id)
        save()
    }

    // MARK: What has been worn

    /// Accessories that have been on at least once, ever.
    ///
    /// Stored alongside the purchases because it has the same lifetime and the
    /// same law: it only grows. Its whole job is to make the buddy's remark
    /// about a new hat happen exactly once, which means it has to survive a
    /// relaunch — a hat you put on last week is not news, and being told it is
    /// would make the remark worthless the second time.
    func hasWorn(_ accessory: Accessory) -> Bool {
        owned.contains(Self.wornMark(accessory))
    }

    func noteWorn(_ accessory: Accessory) {
        owned.insert(Self.wornMark(accessory))
        save()
    }

    /// Whether this den has ever been slept in.
    ///
    /// Same storage and the same law as `hasWorn`: it only grows, and it has
    /// to survive a relaunch or the Sunday Post would report the same first
    /// night every week.
    func hasSettled(in den: Den) -> Bool {
        owned.contains(Self.settledMark(den))
    }

    func noteSettled(in den: Den) {
        owned.insert(Self.settledMark(den))
        save()
    }

    private static func settledMark(_ den: Den) -> String { "slept!\(den.rawValue)" }

    /// Deliberately in the same set, under a prefix no `CatalogItem.id` uses,
    /// so it needs no second storage key and `-PawmodoroResetState` clears it
    /// with everything else. `spent` ignores it: `CatalogItem.from(id:)`
    /// returns nil for a mark, and unknown ids contribute nothing.
    private static func wornMark(_ accessory: Accessory) -> String {
        "worn!\(accessory.rawValue)"
    }

    // MARK: Persistence

    private func load() {
        guard let stored = defaults.array(forKey: Self.storageKey) as? [String]
        else { return }
        owned = Set(stored)
    }

    private func save() {
        defaults.set(Array(owned).sorted(), forKey: Self.storageKey)
    }
}
