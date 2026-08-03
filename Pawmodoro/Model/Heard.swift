import Foundation

/// Something you can only ever hear.
///
/// The journal's quietest page. Five sounds that belong to one place and one
/// time of day and are never drawn, never seen, and never on screen — a whale
/// somewhere out past the harbour, a train horn from beyond Starfall, an owl
/// in the Woods, the Keep's bell at dawn, a chime in a Blossom garden.
///
/// Nearly free to build, because nothing had to be drawn, and the best thing
/// in the app if you happen to be wearing headphones.
enum Heard: String, Codable, CaseIterable, Identifiable {
    case whalesong
    case trainhorn
    case owlcall
    case farbell
    case windchime

    var id: String { rawValue }

    struct Spec {
        let name: String
        let note: String
        let place: Place
        let dayPart: DayPart
        /// Odds per eligible session. Rarer than any sighting: a sound you
        /// can't go and look at wants to feel like luck.
        let chance: Double
    }

    var spec: Spec {
        switch self {
        case .whalesong: Spec(
            name: "Whale song",
            note: "A long way out, and answering something you didn't hear.",
            place: .harbor, dayPart: .night, chance: 1.0 / 10.0)
        case .trainhorn: Spec(
            name: "A train horn",
            note: "From somewhere past Starfall, going away.",
            place: .peaks, dayPart: .night, chance: 1.0 / 9.0)
        case .owlcall: Spec(
            name: "An owl",
            note: "Twice, from the dark side of the wood. Then nothing.",
            place: .woods, dayPart: .night, chance: 1.0 / 8.0)
        case .farbell: Spec(
            name: "The far bell",
            note: "One stroke from the Keep, before anyone is up.",
            place: .keep, dayPart: .dawn, chance: 1.0 / 8.0)
        case .windchime: Spec(
            name: "A wind chime",
            note: "Someone's garden, four notes, no wind you can feel.",
            place: .blossom, dayPart: .dusk, chance: 1.0 / 8.0)
        }
    }

    var name: String { spec.name }
    var note: String { spec.note }

    /// Matches the files written by tools/generate_assets.py.
    var fileName: String { "heard_\(rawValue).wav" }

    /// The clue shown before you've heard it. Same job as a species hint: it
    /// has to be enough to act on without being a recipe.
    var hint: String {
        "\(spec.dayPart.hintPhrase.capitalizedFirst), in \(spec.place.name)"
    }

    func isEligible(place: Place, dayPart: DayPart) -> Bool {
        spec.place == place && spec.dayPart == dayPart
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
