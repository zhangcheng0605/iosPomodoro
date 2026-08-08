import Foundation

/// The garnish layer: what the *light* is doing, over whatever is already
/// falling.
///
/// Three particle layers existed before this one and each owns its own matter:
/// `WeatherView` draws today's sky, `SeasonalView` draws the time of year, and
/// `AmbientSceneView` draws the sound you picked. A fourth field of falling
/// things would just be a fourth downpour on the same screen — which is the
/// mistake `ContentView.weather` already has a comment about avoiding.
///
/// So this layer draws **light and nothing else**: haloes, glints, landing
/// ripples, caustics, bokeh, sparks. Nothing here falls that wasn't already
/// falling. That is what makes it composable with all three of the layers
/// above without a single line of coordination between them, and it is also
/// what makes it *fancy* — the existing layers are flat fills at 12fps, and
/// what reads as expensive on a screen is soft falloff, bloom and a glint that
/// arrives and leaves.
///
/// # What it must never do
///
/// `Weather.at(place)` is a pure function of the day and the place, and
/// **species are gated on it**. This type is downstream of that function and
/// of nothing else: it *reads* `Weather` and `Ambience` and returns a drawing
/// instruction. It has no setter, no storage, no launch flag of its own, and
/// nothing in `rollSighting`, `Journal`, `Heard`, `Species` or `MusicGate`
/// ever asks it a question. Grep for `Flourish` outside `FlourishView.swift`
/// and this file and you should find nothing — if you ever do, that is the
/// bug. A player can be shown sparkling air; they cannot thereby arrange a
/// snow hare, because the only thing that decides a snow hare is
/// `Weather.at(place)` and this file cannot reach it.
///
/// That is also why there is deliberately **no picker**. A control that makes
/// it snow on screen while the sky says clear would make the sky a liar, and
/// the sky is information here — the almanac reads it, the journal hint quotes
/// it, half the roster is gated on it. Somebody who switched the screen to
/// snow and then met no snow hare would have learned that the world says
/// things it doesn't mean, and no later patch un-teaches that.
struct Flourish: Equatable {
    /// The six looks. Each is a way light behaves, not a weather.
    enum Look: String, CaseIterable {
        /// Bright drops with haloes, and the rings they leave where they land.
        case rainfall
        /// Big out-of-focus flakes in the foreground, and crystal glints.
        case snowfall
        /// Sparks that rise, wink and go out.
        case embers
        /// Caustics: bands of moving light low on the screen.
        case shimmer
        /// Bokeh — soft discs of out-of-focus light, drifting up.
        case motes
        /// Four-point glints that arrive and leave. The rare one.
        case sparkle

        /// How many times a second this look has to be redrawn to read.
        ///
        /// This app's vocabulary, from `CLAUDE.md`: **loops run at 2–4fps,
        /// bursts at 8fps, particles at 30fps** — and thirty is the budget for
        /// *matter in flight*, rain falling and snow driving, not for light
        /// changing its mind. Every look here was drawn at thirty to begin
        /// with, and the bill was measured: a full-screen canvas at 30fps
        /// costs about two points of CPU before it draws anything at all, and
        /// the sparkle on top of it cost ten more — roughly seven times the
        /// whole idle app, on the clear and golden skies that had previously
        /// been the cheapest states this app has. An idle app costs nothing;
        /// that is a law here, and thirty broke it.
        ///
        /// So each look is now paid for at the rate its own motion needs:
        ///
        /// * `motes` is a **loop**. A bokeh disc crosses the screen in
        ///   thirty to seventy seconds; four frames a second is more than the
        ///   drift can spend.
        /// * `sparkle`, `shimmer`, `snowfall` and `embers` are **bursts**.
        ///   Their fastest moving part is an envelope that arrives and leaves
        ///   over a second or more — the ember's flicker, at about 1Hz, is
        ///   the quickest thing in any of them, and eight frames samples it
        ///   nearly eight times a cycle.
        /// * `rainfall` is the only one with anything genuinely in flight,
        ///   and it gets twelve — the same rate `WeatherView` has always
        ///   drawn real rain at, and `WeatherView` is on screen underneath it
        ///   whenever this look is. Two layers of rain at two different rates
        ///   would be the visible bug; matching it is free.
        var frameRate: Double {
            switch self {
            case .motes, .sparkle: 4
            case .shimmer, .snowfall, .embers: 8
            case .rainfall: 12
            }
        }
    }

    let look: Look
    /// How much of it, 0…1. Density and peak opacity both scale off this, so a
    /// drizzle and a storm are the same routine at two settings rather than
    /// two routines that have to be kept looking related.
    let strength: Double

    /// What the light is doing right now.
    ///
    /// **The chosen ambience gets first say, and today's sky gets the rest.**
    /// The ambience is the one thing on this screen the player actually picks,
    /// and it is the thing the owner asked to add to — so when a sound is
    /// playing that has an opinion about light, the light follows the sound.
    /// Rooms and night noises have no opinion (a library has no weather), and
    /// those fall through to the sky, which is what is true when nothing else
    /// is claiming otherwise.
    ///
    /// Note what this does *not* do: it never writes anything, and the sound
    /// never moves the sky. Choosing the rain loop makes the screen catch the
    /// light of rain; it does not make it rain, and `Weather.at(place)` returns
    /// exactly what it returned a moment ago.
    static func current(
        ambience: Ambience, running: Bool, weather: Weather
    ) -> Flourish? {
        if running, let chosen = ambience.flourish {
            return Flourish(look: chosen, strength: ambience.flourishStrength)
        }
        return weather.flourish
    }
}

extension Ambience {
    /// The light this sound implies, or nil when it has no opinion.
    ///
    /// Nil is the common answer on purpose, and it is the same decision
    /// `AmbientSceneView` already wrote down: a café, a library, a temple and
    /// a night train are sounds of a *room*, and inventing a light for them
    /// would put drifting glints over a meadow for no reason anybody could
    /// name. Silence here means "the sky is still in charge", not "nothing".
    var flourish: Flourish.Look? {
        switch self {
        case .rain: .rainfall
        case .storm: .rainfall
        case .drizzle: .rainfall
        case .raintent: .rainfall
        case .snowhush: .snowfall
        case .fireplace: .embers
        case .emberslate: .embers
        case .ocean: .shimmer
        case .creek: .shimmer
        case .forest: .motes
        case .wind: .motes
        case .off, .purr, .cafe, .library, .temple,
             .crickets, .cicadas, .nighttrain: nil
        }
    }

    /// How hard that light is laid on. Only meaningful where `flourish` is
    /// non-nil; the others return a value nobody reads rather than a second
    /// optional to unwrap at every call site.
    var flourishStrength: Double {
        switch self {
        case .storm: 1.0
        case .rain: 0.8
        case .drizzle: 0.5
        case .raintent: 0.45
        case .snowhush: 0.8
        case .fireplace: 0.9
        case .emberslate: 0.7
        case .ocean: 0.9
        case .creek: 0.8
        case .forest: 0.6
        case .wind: 0.8
        case .off, .purr, .cafe, .library, .temple,
             .crickets, .cicadas, .nighttrain: 0
        }
    }
}

extension Weather {
    /// The light today's sky is throwing, or nil when it is throwing none.
    ///
    /// Overcast and mist get nothing, and that is the whole reason this reads
    /// as weather rather than as decoration: flat grey light *is* the absence
    /// of anything catching the light, and a screen that sparkles under every
    /// sky has stopped saying anything about the sky. Golden is the strongest
    /// thing in the table and it is the one nobody can ask for — it is bought
    /// by having sat through yesterday's storm.
    var flourish: Flourish? {
        switch self {
        case .storm: Flourish(look: .rainfall, strength: 1.0)
        case .rain: Flourish(look: .rainfall, strength: 0.8)
        case .drizzle: Flourish(look: .rainfall, strength: 0.5)
        case .snow: Flourish(look: .snowfall, strength: 0.8)
        case .golden: Flourish(look: .sparkle, strength: 1.0)
        case .clear: Flourish(look: .sparkle, strength: 0.85)
        case .breeze: Flourish(look: .motes, strength: 0.7)
        case .overcast, .mist: nil
        }
    }
}
