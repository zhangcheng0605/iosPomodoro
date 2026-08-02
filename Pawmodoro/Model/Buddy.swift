import Foundation

/// The companion who keeps you company through a session.
enum Buddy: String, Codable, CaseIterable, Identifiable, PlusLockable {
    case cat
    case dog
    case bunny
    case hamster
    case fox

    var id: String { rawValue }

    /// Matches the sprite file names in the asset catalog.
    var species: String { rawValue }

    /// Cat and dog ship with the app; the rest come with Pawmodoro Plus.
    var isPlus: Bool {
        switch self {
        case .cat, .dog: false
        case .bunny, .hamster, .fox: true
        }
    }

    var name: String {
        switch self {
        case .cat: "Mochi"
        case .dog: "Biscuit"
        case .bunny: "Momo"
        case .hamster: "Peanut"
        case .fox: "Yuzu"
        }
    }

    var kind: String {
        switch self {
        case .cat: "cat"
        case .dog: "dog"
        case .bunny: "bunny"
        case .hamster: "hamster"
        case .fox: "fox"
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

    /// Only the two free buddies have a stretch pose drawn. The others skip
    /// that beat of the wake-up rather than fall back to a wrong frame.
    var hasStretchFrame: Bool {
        switch self {
        case .cat, .dog: true
        case .bunny, .hamster, .fox: false
        }
    }

    /// Emoji are the fallback if a sprite can't be loaded for any reason.
    var idleEmoji: String {
        switch self {
        case .cat: "🐱"
        case .dog: "🐶"
        case .bunny: "🐰"
        case .hamster: "🐹"
        case .fox: "🦊"
        }
    }

    var nappingEmoji: String { "😴" }

    var playingEmoji: String {
        switch self {
        case .cat: "😸"
        case .dog: "🐕"
        case .bunny: "🐰"
        case .hamster: "🐹"
        case .fox: "🦊"
        }
    }
}
