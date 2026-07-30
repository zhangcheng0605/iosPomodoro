import Foundation

/// Optional background sound that plays while a timer is running.
/// Loops live in `Pawmodoro/Resources` and are synthesized, not recorded,
/// so there is nothing to license.
enum Ambience: String, Codable, CaseIterable, Identifiable {
    case off
    case rain
    case purr
    case fireplace

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: "Off"
        case .rain: "Rain"
        case .purr: "Purr"
        case .fireplace: "Fire"
        }
    }

    var systemImage: String {
        switch self {
        case .off: "speaker.slash.fill"
        case .rain: "cloud.rain.fill"
        case .purr: "pawprint.fill"
        case .fireplace: "flame.fill"
        }
    }

    /// Base name of the bundled loop, or nil when no sound should play.
    var fileName: String? {
        switch self {
        case .off: nil
        case .rain: "rain"
        case .purr: "purr"
        case .fireplace: "fireplace"
        }
    }
}
