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
    case distantthunder
    case foghorn
    case geesesouth

    var id: String { rawValue }

    struct Spec {
        let name: String
        let note: String
        let place: Place
        let dayPart: DayPart
        /// Odds per eligible session. Rarer than any sighting: a sound you
        /// can't go and look at wants to feel like luck.
        let chance: Double
        /// Which skies this can reach you through. Empty means any sky, which
        /// is the five that shipped before the weather existed.
        ///
        /// Last, because it is the only defaulted field and the memberwise
        /// init takes its arguments in declaration order — a defaulted field
        /// in the middle means every row that supplies it must also thread it
        /// through the middle.
        var weathers: [Weather] = []
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
        // The three that came with the sky. All of them are things you would
        // only ever hear, which is why they are here and not in the roster:
        // there is nothing to go and look at.
        case .distantthunder: Spec(
            name: "Distant thunder",
            note: "Somewhere behind the hills, and not coming this way.",
            place: .meadow, dayPart: .day, chance: 1.0 / 6.0,
            weathers: [.storm])
        case .foghorn: Spec(
            name: "A foghorn",
            note: "Two long notes. Nothing you could see agreed there was a boat.",
            place: .harbor, dayPart: .dawn, chance: 1.0 / 6.0,
            weathers: [.mist])
        case .geesesouth: Spec(
            name: "Geese going south",
            note: "High up, and all of them talking at once.",
            place: .woods, dayPart: .dusk, chance: 1.0 / 7.0,
            weathers: [.overcast, .breeze])
        }
    }

    var name: String { spec.name }
    var note: String { spec.note }

    /// Matches the files written by tools/generate_assets.py — base name only,
    /// because `SoundPlayer.makePlayer` appends the extension itself. Carrying
    /// the ".wav" here made it look for `heard_owlcall.wav.wav`, and every one
    /// of these five sounds silently failed to play.
    var fileName: String { "heard_\(rawValue)" }

    /// The clue shown before you've heard it. Same job as a species hint: it
    /// has to be enough to act on without being a recipe.
    var hint: String {
        var line = "\(spec.dayPart.hintPhrase.capitalizedFirst), in \(spec.place.name)"
        if let sky = spec.weathers.first?.hintPhrase { line += ", in \(sky)" }
        return line
    }

    func isEligible(place: Place, dayPart: DayPart, weather: Weather) -> Bool {
        spec.place == place && spec.dayPart == dayPart
            && (spec.weathers.isEmpty || spec.weathers.contains(weather))
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
