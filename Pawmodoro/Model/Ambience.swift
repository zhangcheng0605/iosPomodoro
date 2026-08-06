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
    // Batch two.
    case storm
    case crickets
    case cicadas
    case nighttrain
    case raintent
    case emberslate

    var id: String { rawValue }

    /// Rain, purr and fireplace ship with the app; the rest come with Plus.
    var isPlus: Bool {
        switch self {
        case .off, .rain, .purr, .fireplace, .drizzle, .wind: false
        // The three found ones are not Plus. They cannot be bought at all —
        // see `isFound`. Marking them Plus would put a padlock on them and a
        // price beside it, which is the opposite of what they are for.
        case .storm, .snowhush, .crickets: false
        case .forest, .cafe, .ocean, .creek, .library, .temple,
             .cicadas, .nighttrain, .raintent, .emberslate: true
        }
    }

    /// Loops nobody can buy: the buddy records them for you, and only if you
    /// were actually out in it.
    ///
    /// Soot's rule applied to sound. Plus buys convenience everywhere else in
    /// this app; it does not buy having sat through a storm. A Plus owner and
    /// a free one earn these on exactly the same terms.
    var isFound: Bool {
        switch self {
        case .storm, .snowhush, .crickets: true
        case .off, .rain, .purr, .fireplace, .forest, .cafe, .ocean,
             .drizzle, .wind, .creek, .library, .temple,
             .cicadas, .nighttrain, .raintent, .emberslate: false
        }
    }

    /// What has to happen for the buddy to record it.
    var findingLine: String {
        switch self {
        case .storm: "Finish a session while a storm is over you."
        case .snowhush: "Finish a session in the snow."
        case .crickets: "Finish five sessions after dark."
        case .off, .rain, .purr, .fireplace, .forest, .cafe, .ocean,
             .drizzle, .wind, .creek, .library, .temple,
             .cicadas, .nighttrain, .raintent, .emberslate: ""
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
        case .storm: "Storm"
        case .crickets: "Crickets"
        case .cicadas: "Cicadas"
        case .nighttrain: "Night train"
        case .raintent: "Tent"
        case .emberslate: "Embers"
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
        case .storm: "cloud.bolt.rain.fill"
        case .crickets: "moon.stars.fill"
        case .cicadas: "sun.max.fill"
        case .nighttrain: "tram.fill"
        case .raintent: "tent.fill"
        case .emberslate: "flame"
        }
    }

    /// The bundled loop for a time of day.
    ///
    /// Four grades per loop, derived from one recipe by the generator the way
    /// `generate_scenes.py` grades a place — so the hour you *hear* and the
    /// hour you *see* come from the same clock, and `-PawmodoroClock 22` pins
    /// both. Day is the ungraded recipe, which is why the original six sound
    /// at noon exactly as they always have.
    func assetName(for part: DayPart) -> String? {
        guard let base = fileName else { return nil }
        switch part {
        case .day: return base
        case .dawn: return base + "_dawn"
        case .dusk: return base + "_dusk"
        case .night: return base + "_night"
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
        case .storm: "storm"
        case .crickets: "crickets"
        case .cicadas: "cicadas"
        case .nighttrain: "nighttrain"
        case .raintent: "raintent"
        case .emberslate: "emberslate"
        }
    }
}
