import Foundation

/// Everything the Magpie's Cart will sell, and what it costs.
///
/// **This is the only price table in the app.** `tools/check_catalog.py`
/// parses the real numbers out of it — never restates them — and holds them
/// against a stored fixture, because of the one rule that makes an economy in
/// this app trustworthy:
///
/// ### A price may fall. It may never rise.
///
/// Somebody is three afternoons from the fox. If the fox goes up tonight,
/// this app has quietly taken something off them while they were away, and
/// there is no notification, no patch note and no refund that repairs it.
/// Falling is fine — that is a gift, and everyone who already paid the old
/// price still owns the thing. The fixture in the checker exists to make the
/// direction impossible to get wrong by accident.
///
/// ### Wrapping the existing enums rather than restating them
///
/// A case per buddy would be a second roster to keep in step with `Buddy`,
/// and the day somebody added a buddy without adding its case the cart would
/// silently not sell it. `all` is computed from `allCases` of the real types
/// instead, filtered to what is actually locked, so the cart cannot fall
/// behind the app.
enum CatalogItem: Hashable, Identifiable {
    case buddy(Buddy)
    case place(Place)
    case theme(AppTheme)
    case accessory(Accessory)
    case den(Den)
    case film(FilmStock)

    /// Stable across launches: purchases are stored as these strings.
    ///
    /// Prefixed by kind, so a buddy and a place could never collide, and
    /// readable in a defaults dump — the same argument `Dream.id` makes.
    var id: String {
        switch self {
        case .buddy(let buddy): "buddy.\(buddy.rawValue)"
        case .place(let place): "place.\(place.rawValue)"
        case .theme(let theme): "theme.\(theme.rawValue)"
        case .accessory(let accessory): "wear.\(accessory.rawValue)"
        case .den(let den): "den.\(den.rawValue)"
        case .film(let film): "film.\(film.rawValue)"
        }
    }

    static func from(id: String) -> CatalogItem? {
        let parts = id.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "buddy": return Buddy(rawValue: parts[1]).map(CatalogItem.buddy)
        case "place": return Place(rawValue: parts[1]).map(CatalogItem.place)
        case "theme": return AppTheme(rawValue: parts[1]).map(CatalogItem.theme)
        case "wear": return Accessory(rawValue: parts[1]).map(CatalogItem.accessory)
        case "den": return Den(rawValue: parts[1]).map(CatalogItem.den)
        case "film": return FilmStock(rawValue: parts[1]).map(CatalogItem.film)
        default: return nil
        }
    }

    // MARK: The prices

    /// Tuned against `Acorns.minutesPerAcorn`, and only meaningful with it.
    ///
    /// At a steady couple of hours a day — five or six acorns — a theme is
    /// three days, an accessory would be two, a buddy is about three weeks
    /// and a place is a month. The whole catalogue is well over a thousand,
    /// which is most of a year of that: long enough that Plus is plainly the
    /// easier road, short enough that a single thing you actually want is a
    /// fortnight of afternoons rather than a fantasy. Both halves of that
    /// sentence have to stay true or the cart stops working — too cheap and
    /// nobody buys Plus, too dear and the free road is a lie.
    var price: Int {
        switch self {
        case .buddy: 120
        case .place: 150
        case .theme: 40
        // The cheapest thing in the cart on purpose: two afternoons. The
        // wardrobe is where somebody finds out the free road actually goes
        // somewhere, and a first purchase three weeks away teaches the
        // opposite lesson.
        case .accessory: 15
        // A week of afternoons. Dearer than a hat and far cheaper than a
        // buddy: a den is the thing you buy *for* a buddy you already have,
        // and pricing it like a second buddy would make it feel like one.
        case .den: 35
        // The same as an accessory: small, optional dress-up. Capture and
        // enough stocks to make a photo feel like it belongs here are free
        // forever — fence 6, the memory is never the product.
        case .film: 15
        }
    }

    var name: String {
        switch self {
        case .buddy(let buddy): buddy.name
        case .place(let place): place.name
        case .theme(let theme): theme.displayName
        case .accessory(let accessory): accessory.name
        case .den(let den): den.name
        case .film(let film): film.name
        }
    }

    /// What kind of thing it is, for the cart's shelves.
    var shelf: Shelf {
        switch self {
        case .buddy: .buddies
        case .place: .places
        case .theme: .themes
        case .accessory: .wardrobe
        case .den: .dens
        case .film: .film
        }
    }

    enum Shelf: String, CaseIterable, Identifiable {
        case wardrobe, dens, film, buddies, places, themes

        var id: String { rawValue }

        var title: String {
            switch self {
            case .wardrobe: "Things to wear"
            case .dens: "Somewhere to sleep"
            case .film: "Light to keep it in"
            case .buddies: "Someone to sit with"
            case .places: "Somewhere to sit"
            case .themes: "How it looks"
            }
        }

        /// The magpie's word on the shelf. Never a pitch — she is describing
        /// her own hoard, and she is not especially interested in whether you
        /// buy anything.
        var blurb: String {
            switch self {
            case .wardrobe: "Small, and none of it does anything."
            case .dens: "One each. She did not build any of them."
            case .film: "For the pictures. She does not understand them."
            case .buddies: "They came on their own. I only made room."
            case .places: "Further out than you have been. I have been."
            case .themes: "The same world, in a different light."
            }
        }
    }

    // MARK: The catalogue

    /// Everything for sale, in the order the cart shows it.
    ///
    /// Computed from the real rosters rather than listed, so adding a Plus
    /// buddy puts it on the shelf the same day. The free things are filtered
    /// out because they are not for sale — and the four journey places are
    /// filtered out with them, because those are *reached*. Selling somebody
    /// the walk to Whispering Woods would undo the only progression in this
    /// app that is a story rather than a purchase.
    static var all: [CatalogItem] {
        Accessory.allCases.filter { !$0.isFree }.map(CatalogItem.accessory)
            + Den.allCases.filter(\.isForSale).map(CatalogItem.den)
            + FilmStock.allCases.filter { !$0.isFree }.map(CatalogItem.film)
            + Buddy.allCases.filter { $0.isPlus }.map(CatalogItem.buddy)
            + Place.allCases.filter { $0.isPlus }.map(CatalogItem.place)
            + AppTheme.allCases.filter { $0.isPlus }.map(CatalogItem.theme)
    }

    /// The wardrobe splits like film does: `Accessory.isFree` marks the four
    /// pieces the app gives you outright — filtered off the shelf here because
    /// they are not for sale, exactly as the free film stocks are — and the
    /// rest are cart-or-Plus.

    /// Whether the app gives this away — the free accessories and film
    /// stocks. Free is decided on the item's own type (`Accessory.isFree`,
    /// `FilmStock.isFree`); this only gathers those answers so the store can
    /// ask one question of any catalogue id.
    var isFree: Bool {
        switch self {
        case .accessory(let accessory): accessory.isFree
        case .film(let film): film.isFree
        case .buddy, .place, .theme, .den: false
        }
    }

    static func items(on shelf: Shelf) -> [CatalogItem] {
        all.filter { $0.shelf == shelf }
    }

    /// What the whole hoard would cost. The one number that says, without
    /// saying it, that Plus is the easier road.
    static var everything: Int {
        all.reduce(0) { $0 + $1.price }
    }
}

/// Something the cart can sell.
///
/// Kept separate from `PlusLockable` so that the things Plus gates but the
/// cart will never sell — Soot, the free places, anything the app gives —
/// simply do not conform, and there is no price to accidentally read off
/// them. `StoreManager.isUnlocked(_:)` asks for this and gets nil for
/// anything that is not for sale, which is the safe answer.
protocol Ownable: PlusLockable {
    var catalogItem: CatalogItem? { get }
}

extension Buddy: Ownable {
    /// Soot is not for sale at any price. She arrives, after two weeks of
    /// deciding, or she does not — putting a number on that would make the
    /// only story in this app into a transaction.
    var catalogItem: CatalogItem? {
        guard isPlus, self != .stray else { return nil }
        return .buddy(self)
    }
}

extension Place: Ownable {
    var catalogItem: CatalogItem? { isPlus ? .place(self) : nil }
}

extension AppTheme: Ownable {
    var catalogItem: CatalogItem? { isPlus ? .theme(self) : nil }
}
