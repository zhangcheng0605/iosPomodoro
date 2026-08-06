import Foundation

/// What the sky is doing at a place today.
///
/// Rolled once per calendar day per place from `WorldCalendar.seed(day:place:)`
/// — deterministic, offline, and identical on reinstall. Opening the app in the
/// morning becomes opening the curtains: today the meadow is misted, and it
/// will still be misted when you come back at lunchtime.
///
/// **Not real weather, and never will be.** There is no location permission
/// here and no network call; the meadow has *its own* sky. The world is
/// somewhere you go, not a mirror of the room you are sitting in — which is
/// also the only version that works offline, on a plane, and in ten years.
///
/// Weather **decorates, never blocks**. It changes what you see, hear and meet.
/// It never changes what you can do, and it never moves a countdown.
enum Weather: String, CaseIterable, Identifiable, Hashable {
    /// Exactly what the app looked like before any of this existed.
    case clear
    case overcast
    case breeze
    case drizzle
    case rain
    case mist
    /// An event. Roughly one day in thirty.
    case storm
    /// The day after a storm, and the only weather that is never rolled.
    case golden
    /// Replaces the rain family while it is the snow season.
    case snow

    var id: String { rawValue }

    // MARK: The roll

    /// Parts per thousand. `golden` and `snow` are absent on purpose: neither
    /// is ever rolled — one is earned by yesterday and the other substitutes
    /// for the rain family in December.
    ///
    /// These are a **compatibility contract** in the same way
    /// `WorldCalendar.seed` is. Changing a weight does not shift one day; it
    /// silently rewrites what the sky did on every day anybody has ever
    /// opened the app, and every day it will ever do. Add a case at the end
    /// and take its share from `clear` if it must change at all.
    var weight: Int {
        switch self {
        case .clear: 450
        case .overcast: 150
        case .breeze: 120
        case .drizzle: 100
        case .rain: 80
        case .mist: 67
        case .storm: 33
        case .golden, .snow: 0
        }
    }

    /// The ones that can come out of the hat, in a fixed order. The order is
    /// part of the contract too — the roll walks this list accumulating
    /// weights, so reordering it re-rolls history.
    static let rollable: [Weather] = [
        .clear, .overcast, .breeze, .drizzle, .rain, .mist, .storm,
    ]

    /// What the sky is doing at a place on a day.
    static func at(_ place: Place, on day: Date = WorldCalendar.today) -> Weather {
        if let forced = LaunchOptions.forcedWeather { return forced }

        let today = rolled(place, on: day)

        // Yesterday's storm buys today's clarity — the reward for having sat
        // through it. Unless today is a storm of its own, in which case the
        // storm wins and the golden day waits: two storms running is the
        // rarest thing this table can produce (one time in nine hundred), and
        // an earlier version quietly overwrote the second one with sunshine.
        //
        // That condition also does all the work of keeping golden days from
        // chaining. Golden requires today *not* to be a storm, so the next day
        // looks back at a non-storm and rolls normally. Without it, two storms
        // in a row produced two golden days in a row — found by
        // `tools/check_weather.py` over a decade of every place, and by
        // nothing else that could have found it.
        if today != .storm,
           let yesterday = WorldCalendar.calendar.date(
               byAdding: .day, value: -1, to: day
           ), rolled(place, on: yesterday) == .storm {
            return .golden
        }
        return seasonal(today, on: day)
    }

    /// The plain weighted draw, before yesterday and the season get a say.
    private static func rolled(_ place: Place, on day: Date) -> Weather {
        let total = rollable.reduce(0) { $0 + $1.weight }
        // The salt keeps this from agreeing with anything else that asks
        // `WorldCalendar` about the same day and place.
        var ticket = Int(WorldCalendar.roll(day: day, place: place, salt: "weather")
                         * Double(total))
        for weather in rollable {
            ticket -= weather.weight
            if ticket < 0 { return weather }
        }
        return .clear
    }

    /// Rain is snow while it is the snow season, and so is drizzle.
    ///
    /// Which season it is comes from `Season`, so there is one opinion about
    /// the time of year rather than a second set of month windows here — and
    /// `-PawmodoroSeason winter` makes it snow, which is the behaviour anybody
    /// reaching for that flag wanted.
    private static func seasonal(_ weather: Weather, on day: Date) -> Weather {
        guard Season.current(on: day) == .winter else { return weather }
        switch weather {
        case .rain, .drizzle: return .snow
        default: return weather
        }
    }

    // MARK: What it is called

    var name: String {
        switch self {
        case .clear: "Clear"
        case .overcast: "Overcast"
        case .breeze: "Breezy"
        case .drizzle: "Drizzle"
        case .rain: "Rain"
        case .mist: "Mist"
        case .storm: "Storm"
        case .golden: "Golden"
        case .snow: "Snow"
        }
    }

    /// One line in the world's voice, for the almanac and the buddy's caption.
    /// Nothing here congratulates or instructs; it is a remark about the sky.
    var line: String {
        switch self {
        case .clear: "Nothing much in the sky today."
        case .overcast: "Grey all the way over, and staying that way."
        case .breeze: "Everything leaning the same direction."
        case .drizzle: "Not really rain. Not really not."
        case .rain: "Proper rain, settled in for a while."
        case .mist: "You can hear further than you can see."
        case .storm: "It has been building since this morning."
        case .golden: "Washed clean, and lit from the side."
        case .snow: "Coming down, and none of it in a hurry."
        }
    }

    // MARK: How it is drawn

    /// Whether the particle layer has anything to draw. Overcast and golden
    /// are light, not weather you can count.
    var hasParticles: Bool {
        switch self {
        case .clear, .overcast, .golden: false
        case .breeze, .drizzle, .rain, .mist, .storm, .snow: true
        }
    }

    /// How strongly the veil is laid over the scene.
    ///
    /// `tools/check_contrast.py` measures every one of these over the real
    /// scene pixels and they pass with room — but read `Palette.weatherMix`
    /// before trusting that too far. The check is dominated by the text
    /// capsules, not by this, so it says these numbers are safe rather than
    /// standing guard over them. What raising one too far actually costs is
    /// the place disappearing behind its own weather, which only an eye can
    /// see. Keep them where the sky reads as a mood and the scenery still
    /// reads as somewhere.
    var veilOpacity: Double {
        switch self {
        case .clear: 0
        case .breeze: 0.10
        case .snow: 0.20
        case .drizzle: 0.22
        case .golden: 0.26
        case .overcast: 0.30
        case .rain: 0.30
        case .mist: 0.34
        case .storm: 0.40
        }
    }

    // MARK: The suggestion

    /// The ambience this weather would go with, if the player wants it.
    ///
    /// A suggestion and nothing more: the chip glows, and tapping it stays the
    /// only thing that changes what is playing. Sound that switches itself is
    /// sound you stop trusting, and this app never takes the controls.
    var suggests: Ambience? {
        switch self {
        case .drizzle, .rain, .storm: .rain
        case .breeze: .forest
        case .clear, .overcast, .mist, .golden, .snow: nil
        }
    }

    /// Why that chip is glowing, in three words. Nil exactly when `suggests`
    /// is nil, so the glow and its explanation cannot drift apart — a chip
    /// that lights up for no stated reason is a chip people learn to ignore.
    var suggestionNote: String? {
        switch self {
        case .rain: "for the rain"
        case .drizzle: "for the drizzle"
        case .storm: "for the storm"
        case .breeze: "for the wind"
        case .clear, .overcast, .mist, .golden, .snow: nil
        }
    }
}
