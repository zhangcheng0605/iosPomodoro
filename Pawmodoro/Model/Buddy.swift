import Foundation

/// The companion who keeps you company through a session.
///
/// Each buddy after the first two carries one signature behaviour — a soak, a
/// waddle, a pair of raised arms, a night watch. The quirk is the point: five
/// interchangeable animals is a list, and nine animals that each do something
/// only they do is a cast.
enum Buddy: String, Codable, CaseIterable, Identifiable, PlusLockable {
    case cat
    case dog
    case penguin
    case bunny
    case hamster
    case fox
    case capybara
    case redpanda
    case owl
    /// Soot. Not bought and not chosen — she turns up on her own and has to be
    /// waited out. See `Stray`.
    case stray

    var id: String { rawValue }

    /// The buddies a player can pick right now.
    ///
    /// Soot is the one thing in the app deliberately *not* shown with a
    /// padlock. The convention exists so people can see what Plus would buy
    /// them; she isn't for sale, and a greyed-out cat captioned "Soot" from
    /// day one would spoil a two-week story to sell nothing.
    static func roster(strayJoined: Bool) -> [Buddy] {
        allCases.filter { $0 != .stray || strayJoined }
    }

    /// The buddies offered on the very first launch: what ships with the app,
    /// minus the one who has to arrive by herself.
    static var starters: [Buddy] {
        allCases.filter { !$0.isPlus && $0 != .stray }
    }

    /// Matches the sprite file names in the asset catalog.
    var species: String { rawValue }

    /// Cat, dog and penguin ship with the app; the rest come with Pawmodoro
    /// Plus. The penguin is free on purpose — a visibly generous free tier is
    /// the cheapest goodwill available. Soot is free for a different reason:
    /// charging for a cat who chose you would be the wrong story to tell.
    var isPlus: Bool {
        switch self {
        case .cat, .dog, .penguin, .stray: false
        case .bunny, .hamster, .fox, .capybara, .redpanda, .owl: true
        }
    }

    /// The name a buddy is born with. The user can rename it; read
    /// `PomodoroSettings.displayName(for:)` rather than this in the UI.
    var name: String {
        switch self {
        case .cat: "Mochi"
        case .dog: "Biscuit"
        case .penguin: "Pebble"
        case .bunny: "Momo"
        case .hamster: "Peanut"
        case .fox: "Yuzu"
        case .capybara: "Tofu"
        case .redpanda: "Maple"
        case .owl: "Luna"
        case .stray: "Soot"
        }
    }

    var kind: String {
        switch self {
        case .cat: "cat"
        case .dog: "dog"
        case .penguin: "penguin"
        case .bunny: "bunny"
        case .hamster: "hamster"
        case .fox: "fox"
        case .capybara: "capybara"
        case .redpanda: "red panda"
        case .owl: "owl"
        case .stray: "cat"
        }
    }

    /// No emoji here on purpose: the pickers show the sprite alongside this,
    /// and emoji render as missing-glyph boxes on some simulator runtimes.
    var pickerLabel: String { "\(name) the \(kind)" }

    /// Pixel-art sprites in the asset catalog, from tools/generate_sprites.py.
    var awakeAssetName: String { "buddy_\(species)_awake" }
    var asleepAssetName: String { "buddy_\(species)_asleep" }

    /// One animation frame, e.g. `frame("happy_1")` -> `buddy_cat_happy_1`.
    /// The suffixes are defined by `build_frames` in tools/generate_sprites.py.
    func frame(_ suffix: String) -> String { "buddy_\(species)_\(suffix)" }

    /// Only the buddies drawn from the cat's and dog's poses have a stretch.
    /// The others skip that beat of the wake-up rather than fall back to a
    /// wrong frame. Soot has one because she *is* the cat's drawings, in her
    /// own palette.
    var hasStretchFrame: Bool {
        switch self {
        case .cat, .dog, .stray: true
        default: false
        }
    }

    // MARK: Quirks
    //
    // Each of these is read by `BuddyFrames`; a buddy without the quirk returns
    // nil and falls through to the ordinary behaviour.

    /// Alternates with the resting pose to make an idle shuffle. Pebble does
    /// not sit down, so standing still would look like a bug.
    var idleShuffleFrame: String? {
        self == .penguin ? frame("waddle") : nil
    }

    /// Shown instead of the happy bounce when petted or celebrating.
    var celebrationFrame: String? {
        switch self {
        case .redpanda: frame("armsup")     // the startle, played as delight
        case .penguin: frame("slide")       // a belly-slide across the perch
        default: nil
        }
    }

    /// Shown while a break runs, wherever the buddy is. Tofu goes for a soak.
    var breakFrame: String? {
        self == .capybara ? frame("soak") : nil
    }

    /// Awake through focus after dark, dozing through daytime breaks — the one
    /// buddy that inverts the app's fiction, and only at night.
    var isNocturnal: Bool { self == .owl }

    /// The pose that goes with `isNocturnal`.
    var watchFrame: String? {
        self == .owl ? frame("watch") : nil
    }

    // MARK: Home turf

    /// Where this buddy would rather be. Purely cosmetic — being at home never
    /// grants anything, per the no-guilt rule.
    var homePlace: Place {
        switch self {
        case .cat: .meadow
        case .dog: .harbor
        case .hamster: .meadow
        case .bunny: .blossom
        case .fox: .woods
        case .capybara: .onsen
        case .redpanda: .blossom
        case .penguin: .peaks
        case .owl: .woods
        case .stray: .blossom      // village alleys, which is where strays live
        }
    }

    /// A resting pose used only at `homePlace`. Buddies without one still get
    /// the caption, which is most of the charm anyway.
    var homeFrame: String? {
        switch self {
        case .capybara: frame("soak")       // the onsen is the whole point
        case .redpanda: frame("curl")       // curled on Blossom's veranda
        case .penguin: frame("slide")       // belly-down on the snow
        case .owl: frame("watch")           // keeping watch over the woods
        default: nil
        }
    }

    /// Emoji are the fallback if a sprite can't be loaded for any reason.
    var idleEmoji: String {
        switch self {
        case .cat: "🐱"
        case .dog: "🐶"
        case .penguin: "🐧"
        case .bunny: "🐰"
        case .hamster: "🐹"
        case .fox: "🦊"
        case .capybara: "🦫"
        case .redpanda: "🦝"
        case .owl: "🦉"
        case .stray: "🐈‍⬛"
        }
    }

    var nappingEmoji: String { "😴" }

    var playingEmoji: String {
        switch self {
        case .cat: "😸"
        case .dog: "🐕"
        case .penguin: "🐧"
        case .bunny: "🐰"
        case .hamster: "🐹"
        case .fox: "🦊"
        case .capybara: "🦫"
        case .redpanda: "🦝"
        case .owl: "🦉"
        case .stray: "🐈‍⬛"
        }
    }
}
