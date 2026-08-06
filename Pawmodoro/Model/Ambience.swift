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
    // The Second Shelf — Phase W, batch one. Appended rather than sorted in,
    // because the raw values are what a saved setting decodes from and the
    // order here is the order the picker shows.
    case drizzle
    case wind
    case creek
    case library
    case snowhush
    case temple

    var id: String { rawValue }

    /// Rain, purr and fireplace ship with the app; the rest come with Plus.
    var isPlus: Bool {
        switch self {
        case .off, .rain, .purr, .fireplace, .drizzle, .wind: false
        case .forest, .cafe, .ocean, .creek, .library, .snowhush, .temple: true
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
        case .drizzle: "Drizzle"
        case .wind: "Wind"
        case .creek: "Creek"
        case .library: "Library"
        case .snowhush: "Snow"
        case .temple: "Temple"
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
        case .drizzle: "cloud.drizzle.fill"
        case .wind: "wind"
        case .creek: "drop.fill"
        case .library: "book.closed.fill"
        case .snowhush: "snowflake"
        case .temple: "bell.fill"
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
        case .drizzle: "drizzle"
        case .wind: "wind"
        case .creek: "creek"
        case .library: "library"
        case .snowhush: "snowhush"
        case .temple: "temple"
        }
    }
}
