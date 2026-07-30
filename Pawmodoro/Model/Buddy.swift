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

    var pickerLabel: String { "\(idleEmoji)  \(name) the \(kind)" }

    /// Pixel-art sprites in the asset catalog, from tools/generate_sprites.py.
    var awakeAssetName: String { "buddy_\(species)_awake" }
    var asleepAssetName: String { "buddy_\(species)_asleep" }

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
