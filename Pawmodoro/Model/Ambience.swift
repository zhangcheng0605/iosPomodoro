import Foundation

/// Optional background sound that plays while a timer is running.
/// Loops live in `Pawmodoro/Resources` and are synthesized, not recorded,
/// so there is nothing to license.
enum Ambience: String, Codable, CaseIterable, Identifiable, PlusLockable {
    case off
    case rain
    case purr
    case fireplace
    case forest
    case cafe
    case ocean

    var id: String { rawValue }

    /// Rain, purr and fireplace ship with the app; the rest come with Plus.
    var isPlus: Bool {
        switch self {
        case .off, .rain, .purr, .fireplace: false
        case .forest, .cafe, .ocean: true
        }
    }

    var label: String {
        switch self {
        case .off: "Off"
        case .rain: "Rain"
        case .purr: "Purr"
        case .fireplace: "Fire"
        case .forest: "Forest"
        case .cafe: "Café"
        case .ocean: "Ocean"
        }
    }

    var systemImage: String {
        switch self {
        case .off: "speaker.slash.fill"
        case .rain: "cloud.rain.fill"
        case .purr: "pawprint.fill"
        case .fireplace: "flame.fill"
        case .forest: "leaf.fill"
        case .cafe: "cup.and.saucer.fill"
        case .ocean: "water.waves"
        }
    }

    /// Base name of the bundled loop, or nil when no sound should play.
    var fileName: String? {
        switch self {
        case .off: nil
        case .rain: "rain"
        case .purr: "purr"
        case .fireplace: "fireplace"
        case .forest: "forest"
        case .cafe: "cafe"
        case .ocean: "ocean"
        }
    }
}
