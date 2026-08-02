import CoreGraphics
import Foundation

/// Something that turns up while you hold still.
///
/// The app's fiction is "be quiet, don't wake the buddy". Pointed outward,
/// that becomes the reason shy animals appear at all — and what appears
/// depends on where you are, what hour it is and how long you committed. That
/// turns the eight places and four times of day from decoration into reasons
/// to focus somewhere else, at some other hour.
///
/// Ids must match the sprites emitted by tools/generate_wildlife.py.
enum Species: String, Codable, CaseIterable, Identifiable {
    case butterfly
    case robin
    case squirrel
    case frog
    case stag
    case gull
    case otter
    case dolphin
    case whale
    case moth
    case koi
    case crane

    var id: String { rawValue }

    var name: String {
        switch self {
        case .butterfly: "Butterfly"
        case .robin: "Robin"
        case .squirrel: "Red Squirrel"
        case .frog: "Frog"
        case .stag: "Stag"
        case .gull: "Gull"
        case .otter: "Otter"
        case .dolphin: "Dolphins"
        case .whale: "Whale"
        case .moth: "Lantern Moth"
        case .koi: "Koi"
        case .crane: "Crane"
        }
    }

    /// Shown in the journal once seen — a line of field-guide flavour.
    var note: String {
        switch self {
        case .butterfly: "Landed while you weren't moving."
        case .robin: "Working the fence line at first light."
        case .squirrel: "Went up the pine without stopping."
        case .frog: "One hop, then rings on the water."
        case .stag: "Stepped out of the treeline and looked up."
        case .gull: "Broke from the others and dived."
        case .otter: "Floating on its back, holding something."
        case .dolphin: "Two arcs between the islets."
        case .whale: "Spouted once, then went down slowly."
        case .moth: "Circling a lit lantern, patiently."
        case .koi: "A ring on the surface, then orange."
        case .crane: "Standing on one leg in the shallows."
        }
    }

    // MARK: Where and when

    var places: [Place] {
        switch self {
        case .butterfly: [.meadow, .blossom]
        case .robin: [.meadow]
        case .squirrel, .frog, .stag: [.woods]
        case .gull, .otter, .dolphin, .whale: [.harbor]
        case .moth, .koi, .crane: [.blossom]
        }
    }

    /// Empty means any time of day.
    var dayParts: [DayPart] {
        switch self {
        case .butterfly, .squirrel, .gull, .otter, .dolphin, .whale, .koi: [.day]
        case .robin, .stag, .crane: [.dawn]
        case .frog: [.dusk]
        case .moth: [.night]
        }
    }

    /// A session at least this long, in minutes. The whale is the long-haul
    /// reward: it exists to make a forty-minute session worth choosing.
    var minimumMinutes: Int {
        self == .whale ? 40 : 0
    }

    var rarity: Rarity {
        switch self {
        case .butterfly, .robin, .squirrel, .frog, .gull, .moth: .common
        case .stag, .otter, .dolphin, .koi, .crane: .uncommon
        case .whale: .rare
        }
    }

    func isEligible(place: Place, dayPart: DayPart, focusMinutes: Int) -> Bool {
        places.contains(place)
            && (dayParts.isEmpty || dayParts.contains(dayPart))
            && focusMinutes >= minimumMinutes
    }

    /// The clue shown under a species you haven't seen. It has to be enough to
    /// act on — that's the whole retention mechanism — without being a recipe.
    var hint: String {
        let where_ = places.map(\.name).joined(separator: " or ")
        var when = dayParts.first.map { $0.hintPhrase } ?? "any time"
        if minimumMinutes > 0 {
            when += ", on a long session"
        }
        return "\(when.capitalizedFirst), in \(where_)"
    }

    // MARK: Drawing

    var frames: [String] { ["wild_\(rawValue)_0", "wild_\(rawValue)_1"] }
    var ghostAsset: String { "wild_\(rawValue)_ghost" }
    var sketchAsset: String { "wild_\(rawValue)_sketch" }

    var motion: Motion {
        switch self {
        case .butterfly, .moth: .flutter
        case .gull, .dolphin, .whale: .arc
        case .robin, .squirrel, .frog: .hop
        case .stag, .crane, .otter, .koi: .linger
        }
    }

    /// Where on screen it crosses, as a fraction of height. The sky band above
    /// the ring and the ground band below the paw row are the only places the
    /// UI leaves free.
    var altitude: Double {
        switch self {
        case .butterfly, .moth, .gull: 0.155
        case .robin, .squirrel, .stag, .crane, .frog: 0.775
        case .otter, .dolphin, .whale, .koi: 0.800
        }
    }

    var size: CGSize {
        switch self {
        case .butterfly: CGSize(width: 26, height: 21)
        case .robin: CGSize(width: 26, height: 23)
        case .squirrel: CGSize(width: 28, height: 32)
        case .frog: CGSize(width: 24, height: 20)
        case .stag: CGSize(width: 54, height: 50)
        case .gull: CGSize(width: 32, height: 21)
        case .otter: CGSize(width: 42, height: 26)
        case .dolphin: CGSize(width: 46, height: 30)
        case .whale: CGSize(width: 64, height: 35)
        case .moth: CGSize(width: 24, height: 20)
        case .koi: CGSize(width: 38, height: 22)
        case .crane: CGSize(width: 34, height: 46)
        }
    }

    enum Rarity: String, Codable {
        case common
        case uncommon
        case rare

        /// Odds of turning up in a session it's eligible for.
        var chance: Double {
            switch self {
            case .common: 1.0 / 3.0
            case .uncommon: 1.0 / 8.0
            case .rare: 1.0 / 12.0
            }
        }

        var label: String { rawValue.capitalized }
    }

    enum Motion {
        /// Crosses the screen with a wingbeat wobble.
        case flutter
        /// Crosses, rising and falling once — a dive or a breach.
        case arc
        /// Moves a little, bouncing.
        case hop
        /// Stays put and is simply present.
        case linger
    }
}

extension DayPart {
    var hintPhrase: String {
        switch self {
        case .dawn: "at dawn"
        case .day: "in daylight"
        case .dusk: "at dusk"
        case .night: "after dark"
        }
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
