import CoreGraphics
import Foundation

/// Something that turns up while you hold still.
///
/// The app's fiction is "be quiet, don't wake the buddy". Pointed outward,
/// that becomes the reason shy animals appear at all — and what appears
/// depends on where you are, what hour it is, how long you committed, and in
/// two cases on the real sky. That turns eight places and four times of day
/// from decoration into reasons to focus somewhere else, at some other hour.
///
/// Everything about a species lives in one `Spec` row rather than in a dozen
/// parallel switches: at forty-one entries, parallel switches are how a table
/// quietly goes out of step with itself.
///
/// Ids must match the sprites emitted by tools/generate_wildlife.py.
enum Species: String, Codable, CaseIterable, Identifiable {
    // Home Waters — free places.
    case butterfly, robin, bee, hare, swallow, foxcub
    case squirrel, frog, stag, woodpecker, badger, fawn, tawnyowl
    case gull, otter, dolphin, whale, crab, seal, heron, turtle
    case moth, koi, crane, dragonfly, firefly, kingfisher, hedgehog
    // The Far Isles — reached through Plus places.
    case dove, peacock
    case swift, sheep
    case ptarmigan, mountainhare, ibex
    case macaque, tanuki, moonrabbit
    // Wave 4 — the creatures that come with the sky.
    case gardensnail, bigfrog, littlefrog, earthworm, rainbeetle
    case fogmoth, roedeer, ghostslug
    case stormpetrel, weathercrow
    case dragonswarm, suncat
    case redkite, dandelionmouse
    case snowfox, ermine, winterwren
    case greywagtail, mushroomvole
    // The Flyway — things that only pass through. See `Passage`.
    case whooperswan, cuckoo, paintedlady, salmonrun
    case redwing, snowgoose, waxwing
    // Phenomena.
    case rainbow, meteors, aurora
    case sunshower, fogbow, firstthunder
    case comet

    var id: String { rawValue }

    struct Spec {
        let name: String
        let note: String
        let places: [Place]
        /// Empty means any time of day.
        let dayParts: [DayPart]
        let rarity: Rarity
        let motion: Motion
        let altitude: Double
        let size: CGSize
        var minimumMinutes: Int = 0
        var needsFullMoon: Bool = false
        /// Which skies this needs. Empty means any sky, which is every species
        /// that shipped before the weather existed.
        ///
        /// Checked against `Weather.at(place)` — the world's sky, a pure
        /// function of the day and the place — and never against the ambience
        /// loop somebody happens to be playing. Wanting to see a snow hare is
        /// not the same as being able to arrange one.
        var weathers: [Weather] = []
        /// Decided at the end of a session rather than rolled at the start,
        /// because what it needs cannot be known when the session begins.
        ///
        /// A rainbow needs the rain to have *stopped*; the first thunder of a
        /// year needs to know it is the first. These are excluded from the
        /// ordinary roll and awarded by `TimerEngine.lateAward()` instead.
        var awardedLate: Bool = false
        var isPhenomenon: Bool = false
        /// The migration window this only turns up inside, if any.
        ///
        /// The one gate in this table a player cannot arrange, wait for, or
        /// read off a clock — and the only one that closes. See `Passage` for
        /// the three fences that stop that being cruel.
        var passage: Passage? = nil
    }

    // MARK: The table

    var spec: Spec {
        switch self {
        // --- Meadow Home
        case .butterfly: Spec(name: "Butterfly", note: "Landed while you weren't moving.",
            places: [.meadow, .blossom], dayParts: [.day], rarity: .common,
            motion: .flutter, altitude: 0.155, size: .init(width: 26, height: 21))
        case .robin: Spec(name: "Robin", note: "Working the fence line at first light.",
            places: [.meadow], dayParts: [.dawn], rarity: .common,
            motion: .hop, altitude: 0.775, size: .init(width: 26, height: 23))
        case .bee: Spec(name: "Bee", note: "Went through the clover and left again.",
            places: [.meadow, .blossom], dayParts: [.day], rarity: .common,
            motion: .flutter, altitude: 0.190, size: .init(width: 20, height: 16))
        case .hare: Spec(name: "Hare", note: "Sat very still, then wasn't there.",
            places: [.meadow], dayParts: [.dusk], rarity: .uncommon,
            motion: .hop, altitude: 0.780, size: .init(width: 38, height: 32))
        case .swallow: Spec(name: "Swallow", note: "Cut the whole field in one pass.",
            places: [.meadow], dayParts: [.day], rarity: .common,
            motion: .arc, altitude: 0.150, size: .init(width: 34, height: 26))
        case .foxcub: Spec(name: "Fox Cub", note: "Too young to know it should hide.",
            places: [.meadow], dayParts: [.night], rarity: .rare,
            motion: .linger, altitude: 0.780, size: .init(width: 40, height: 32))

        // --- Whispering Woods
        case .squirrel: Spec(name: "Red Squirrel", note: "Went up the pine without stopping.",
            places: [.woods], dayParts: [.day], rarity: .common,
            motion: .hop, altitude: 0.770, size: .init(width: 28, height: 32))
        case .frog: Spec(name: "Frog", note: "One hop, then rings on the water.",
            places: [.woods], dayParts: [.dusk], rarity: .common,
            motion: .hop, altitude: 0.790, size: .init(width: 24, height: 20))
        case .stag: Spec(name: "Stag", note: "Stepped out of the treeline and looked up.",
            places: [.woods], dayParts: [.dawn], rarity: .uncommon,
            motion: .linger, altitude: 0.775, size: .init(width: 54, height: 50))
        case .woodpecker: Spec(name: "Woodpecker", note: "You heard it before you saw it.",
            places: [.woods], dayParts: [.day], rarity: .common,
            motion: .hop, altitude: 0.740, size: .init(width: 30, height: 28))
        case .badger: Spec(name: "Badger", note: "Crossed the path without hurrying.",
            places: [.woods], dayParts: [.night], rarity: .uncommon,
            motion: .linger, altitude: 0.785, size: .init(width: 44, height: 27))
        case .fawn: Spec(name: "Fawn", note: "Waiting exactly where it was left.",
            places: [.woods], dayParts: [.dawn], rarity: .uncommon,
            motion: .linger, altitude: 0.770, size: .init(width: 40, height: 34))
        case .tawnyowl: Spec(name: "Tawny Owl", note: "Two calls, then nothing at all.",
            places: [.woods], dayParts: [.night], rarity: .rare,
            motion: .linger, altitude: 0.735, size: .init(width: 32, height: 32))

        // --- Harbor Isle
        case .gull: Spec(name: "Gull", note: "Broke from the others and dived.",
            places: [.harbor], dayParts: [.day], rarity: .common,
            motion: .arc, altitude: 0.155, size: .init(width: 32, height: 21))
        case .otter: Spec(name: "Otter", note: "Floating on its back, holding something.",
            places: [.harbor], dayParts: [.day], rarity: .uncommon,
            motion: .linger, altitude: 0.800, size: .init(width: 42, height: 26))
        case .dolphin: Spec(name: "Dolphins", note: "Two arcs between the islets.",
            places: [.harbor], dayParts: [.day], rarity: .uncommon,
            motion: .arc, altitude: 0.800, size: .init(width: 46, height: 30))
        case .whale: Spec(name: "Whale", note: "Spouted once, then went down slowly.",
            places: [.harbor], dayParts: [.day], rarity: .rare,
            motion: .arc, altitude: 0.805, size: .init(width: 64, height: 35),
            minimumMinutes: 40)
        case .crab: Spec(name: "Crab", note: "Sideways across the wet stones.",
            places: [.harbor], dayParts: [.dusk], rarity: .common,
            motion: .linger, altitude: 0.815, size: .init(width: 30, height: 22))
        case .seal: Spec(name: "Seal", note: "Watched you for a while, then rolled.",
            places: [.harbor], dayParts: [.day], rarity: .uncommon,
            motion: .linger, altitude: 0.805, size: .init(width: 44, height: 23))
        case .heron: Spec(name: "Heron", note: "Did not move once the whole time.",
            places: [.harbor], dayParts: [.dawn], rarity: .uncommon,
            motion: .linger, altitude: 0.760, size: .init(width: 36, height: 34))
        case .turtle: Spec(name: "Turtle", note: "Surfaced, breathed, and was gone.",
            places: [.harbor], dayParts: [.day], rarity: .rare,
            motion: .linger, altitude: 0.805, size: .init(width: 40, height: 23))

        // --- Blossom Village
        case .moth: Spec(name: "Lantern Moth", note: "Circling a lit lantern, patiently.",
            places: [.blossom], dayParts: [.night], rarity: .common,
            motion: .flutter, altitude: 0.175, size: .init(width: 24, height: 20))
        case .koi: Spec(name: "Koi", note: "A ring on the surface, then orange.",
            places: [.blossom], dayParts: [.day], rarity: .uncommon,
            motion: .linger, altitude: 0.800, size: .init(width: 38, height: 22))
        case .crane: Spec(name: "Crane", note: "Standing on one leg in the shallows.",
            places: [.blossom], dayParts: [.dawn], rarity: .uncommon,
            motion: .linger, altitude: 0.755, size: .init(width: 34, height: 46))
        case .dragonfly: Spec(name: "Dragonfly", note: "Hung in the air, then jumped sideways.",
            places: [.blossom], dayParts: [.day], rarity: .common,
            motion: .flutter, altitude: 0.185, size: .init(width: 32, height: 21))
        case .firefly: Spec(name: "Firefly", note: "On, off, and somewhere else.",
            places: [.blossom, .woods], dayParts: [.night], rarity: .common,
            motion: .flutter, altitude: 0.200, size: .init(width: 18, height: 14))
        case .kingfisher: Spec(name: "Kingfisher", note: "A blue line over the water.",
            places: [.blossom], dayParts: [.dawn], rarity: .uncommon,
            motion: .arc, altitude: 0.170, size: .init(width: 32, height: 26))
        case .hedgehog: Spec(name: "Hedgehog", note: "Rustled, stopped, rustled again.",
            places: [.blossom, .meadow], dayParts: [.dusk], rarity: .uncommon,
            motion: .linger, altitude: 0.800, size: .init(width: 36, height: 23))

        // --- Sunstone Keep
        case .dove: Spec(name: "Dove", note: "The whole flock went up at once.",
            places: [.keep], dayParts: [.dawn], rarity: .common,
            motion: .arc, altitude: 0.150, size: .init(width: 32, height: 26))
        case .peacock: Spec(name: "Peacock", note: "Opened the fan and held it.",
            places: [.keep], dayParts: [.day], rarity: .uncommon,
            motion: .linger, altitude: 0.760, size: .init(width: 50, height: 40))

        // --- Cloudspire
        case .swift: Spec(name: "Swift", note: "Never landed the entire session.",
            places: [.cloudspire], dayParts: [.day], rarity: .common,
            motion: .arc, altitude: 0.145, size: .init(width: 36, height: 26))
        case .sheep: Spec(name: "Stray Sheep", note: "On a floating island. No explanation given.",
            places: [.cloudspire], dayParts: [.day], rarity: .rare,
            motion: .linger, altitude: 0.775, size: .init(width: 42, height: 34))

        // --- Starfall Peaks
        case .ptarmigan: Spec(name: "Ptarmigan", note: "White on white until it moved.",
            places: [.peaks], dayParts: [.day], rarity: .common,
            motion: .hop, altitude: 0.780, size: .init(width: 30, height: 26))
        case .mountainhare: Spec(name: "Mountain Hare", note: "Bounded across and did not stop.",
            places: [.peaks], dayParts: [.dusk], rarity: .uncommon,
            motion: .hop, altitude: 0.780, size: .init(width: 38, height: 32))
        case .ibex: Spec(name: "Ibex", note: "A silhouette on the far ridge.",
            places: [.peaks], dayParts: [.dawn], rarity: .rare,
            motion: .linger, altitude: 0.755, size: .init(width: 44, height: 38))

        // --- Moonlit Onsen
        case .macaque: Spec(name: "Snow Macaque", note: "Sat in the water like it owned it.",
            places: [.onsen], dayParts: [.day], rarity: .common,
            motion: .linger, altitude: 0.790, size: .init(width: 40, height: 32))
        case .tanuki: Spec(name: "Tanuki", note: "Came to the edge and warmed its paws.",
            places: [.onsen], dayParts: [.night], rarity: .uncommon,
            motion: .linger, altitude: 0.790, size: .init(width: 42, height: 30))
        case .moonrabbit: Spec(name: "Moon Rabbit", note: "Sat in the reflection. Gone by morning.",
            places: [.onsen, .blossom, .harbor], dayParts: [.night], rarity: .mythic,
            motion: .linger, altitude: 0.795, size: .init(width: 32, height: 38),
            needsFullMoon: true)

        // --- Wave 4: rain and drizzle
        case .gardensnail: Spec(name: "Garden Snail", note: "Out on the wet path, in no hurry at all.",
            places: [.meadow, .woods, .blossom], dayParts: [], rarity: .common,
            motion: .linger, altitude: 0.800, size: .init(width: 20, height: 14),
            weathers: [.rain, .drizzle])
        case .bigfrog: Spec(name: "Big Frog", note: "Filled a whole flagstone and did not blink.",
            places: [.woods], dayParts: [], rarity: .common,
            motion: .hop, altitude: 0.790, size: .init(width: 26, height: 22),
            weathers: [.rain, .drizzle])
        case .littlefrog: Spec(name: "Little Frog", note: "The size of a thumbnail. The other one was elsewhere.",
            places: [.meadow], dayParts: [], rarity: .common,
            motion: .hop, altitude: 0.790, size: .init(width: 18, height: 15),
            weathers: [.rain, .drizzle])
        case .earthworm: Spec(name: "Earthworm", note: "Came up for the rain, the way they do.",
            places: [.meadow, .woods], dayParts: [], rarity: .common,
            motion: .linger, altitude: 0.815, size: .init(width: 22, height: 10),
            weathers: [.rain, .drizzle])
        case .rainbeetle: Spec(name: "Rain Beetle", note: "Waited out the shower under a leaf, then went on.",
            places: [.woods, .blossom], dayParts: [], rarity: .uncommon,
            motion: .linger, altitude: 0.805, size: .init(width: 18, height: 13),
            weathers: [.rain])

        // --- Wave 4: mist
        case .fogmoth: Spec(name: "Fog Moth", note: "Pale, and the same colour as everything else.",
            places: [.woods, .peaks], dayParts: [.dusk, .night], rarity: .uncommon,
            motion: .flutter, altitude: 0.300, size: .init(width: 24, height: 20),
            weathers: [.mist])
        case .roedeer: Spec(name: "Roe Deer", note: "There, and then only the shape of there.",
            places: [.woods, .meadow], dayParts: [.dawn], rarity: .uncommon,
            motion: .linger, altitude: 0.770, size: .init(width: 42, height: 36),
            weathers: [.mist])
        case .ghostslug: Spec(name: "Ghost Slug", note: "White, blind, and eats other slugs. Nobody discusses it.",
            places: [.woods], dayParts: [.night], rarity: .rare,
            motion: .linger, altitude: 0.810, size: .init(width: 22, height: 11),
            weathers: [.mist])

        // --- Wave 4: storm
        case .stormpetrel: Spec(name: "Storm Petrel", note: "Only ever seen when nobody sensible is out.",
            places: [.harbor], dayParts: [], rarity: .rare,
            motion: .arc, altitude: 0.200, size: .init(width: 30, height: 22),
            weathers: [.storm])
        case .weathercrow: Spec(name: "Weathervane Crow", note: "Sat through the whole thing without once shifting.",
            places: [.keep, .meadow], dayParts: [], rarity: .uncommon,
            motion: .linger, altitude: 0.740, size: .init(width: 26, height: 28),
            weathers: [.storm])

        // --- Wave 4: golden
        case .dragonswarm: Spec(name: "Dragonfly Swarm", note: "All of them, all at once, all going the same way.",
            places: [.blossom, .meadow], dayParts: [.day, .dusk], rarity: .uncommon,
            motion: .flutter, altitude: 0.250, size: .init(width: 46, height: 30),
            weathers: [.golden])
        case .suncat: Spec(name: "Sun Cat", note: "A stranger, asleep in the one warm rectangle.",
            places: [.keep, .onsen, .blossom], dayParts: [.day], rarity: .rare,
            motion: .linger, altitude: 0.790, size: .init(width: 34, height: 26),
            weathers: [.golden])

        // --- Wave 4: breeze
        case .redkite: Spec(name: "Red Kite", note: "Did not beat a wing the whole time it was up there.",
            places: [.meadow, .peaks], dayParts: [.day], rarity: .uncommon,
            motion: .arc, altitude: 0.170, size: .init(width: 36, height: 24),
            weathers: [.breeze])
        case .dandelionmouse: Spec(name: "Dandelion Mouse", note: "Bent the stem right down and did not get the seed.",
            places: [.meadow], dayParts: [.day, .dusk], rarity: .common,
            motion: .hop, altitude: 0.800, size: .init(width: 19, height: 20),
            weathers: [.breeze])

        // --- Wave 4: snow
        case .snowfox: Spec(name: "Snow Fox", note: "Listened to the ground, then went in head first.",
            places: [.peaks, .woods], dayParts: [], rarity: .uncommon,
            motion: .linger, altitude: 0.780, size: .init(width: 40, height: 30),
            weathers: [.snow])
        case .ermine: Spec(name: "Ermine", note: "White with a black tail-tip, and never still.",
            places: [.peaks, .woods], dayParts: [], rarity: .rare,
            motion: .hop, altitude: 0.790, size: .init(width: 30, height: 18),
            weathers: [.snow])
        case .winterwren: Spec(name: "Winter Wren", note: "Furious, and the size of a walnut.",
            places: [.woods, .meadow], dayParts: [.day], rarity: .common,
            motion: .hop, altitude: 0.760, size: .init(width: 18, height: 18),
            weathers: [.snow])

        // --- Wave 4: overcast
        case .greywagtail: Spec(name: "Grey Wagtail", note: "Bobbing on a wet stone, for reasons of its own.",
            places: [.harbor, .meadow], dayParts: [], rarity: .common,
            motion: .hop, altitude: 0.775, size: .init(width: 24, height: 20),
            weathers: [.overcast])
        case .mushroomvole: Spec(name: "Mushroom Vole", note: "Took one, and could barely see over it.",
            places: [.woods], dayParts: [], rarity: .common,
            motion: .linger, altitude: 0.805, size: .init(width: 16, height: 18),
            weathers: [.overcast])

        // --- Phenomena
        // --- The Flyway. Every one of these is gated on a fortnight that
        // moves from year to year, so the places and hours are kept generous
        // on purpose: the window is the whole of the difficulty and stacking a
        // second unarrangeable condition on top would make it unmeetable.
        case .whooperswan: Spec(name: "Whooper Swan", note: "Going over very high, in threes and fours.",
            places: [.meadow, .harbor, .peaks], dayParts: [.day, .dusk], rarity: .uncommon,
            motion: .flutter, altitude: 0.115, size: .init(width: 54, height: 30),
            passage: .swans)
        case .cuckoo: Spec(name: "Cuckoo", note: "Heard from three different directions and seen from none.",
            places: [.woods, .meadow, .keep], dayParts: [.dawn, .day], rarity: .rare,
            motion: .linger, altitude: 0.330, size: .init(width: 32, height: 24),
            passage: .cuckoo)
        case .paintedlady: Spec(name: "Painted Lady", note: "Came up from the south and kept going north.",
            places: [.meadow, .blossom, .keep, .onsen], dayParts: [.day], rarity: .common,
            motion: .flutter, altitude: 0.205, size: .init(width: 28, height: 22),
            passage: .paintedladies)
        case .salmonrun: Spec(name: "Salmon Run", note: "The water kept breaking over nothing at all.",
            places: [.harbor, .woods, .onsen], dayParts: [.dawn, .day, .dusk], rarity: .uncommon,
            motion: .arc, altitude: 0.720, size: .init(width: 44, height: 26),
            passage: .salmon)
        case .redwing: Spec(name: "Redwing", note: "In overnight, and none of them are staying.",
            places: [.woods, .meadow, .blossom], dayParts: [.dawn, .day], rarity: .common,
            motion: .hop, altitude: 0.610, size: .init(width: 28, height: 24),
            passage: .redwings)
        case .snowgoose: Spec(name: "Snow Goose", note: "A long ragged line, and then another one.",
            places: [.meadow, .harbor, .peaks, .cloudspire], dayParts: [.day, .dusk], rarity: .uncommon,
            motion: .flutter, altitude: 0.135, size: .init(width: 50, height: 28),
            passage: .snowgeese)
        case .waxwing: Spec(name: "Waxwing", note: "Stripped one tree bare and left together.",
            places: [.blossom, .woods, .meadow], dayParts: [.day], rarity: .rare,
            motion: .hop, altitude: 0.470, size: .init(width: 30, height: 26),
            passage: .waxwings)
        case .rainbow: Spec(name: "Rainbow", note: "The rain stopped before you did.",
            places: [.meadow, .woods, .harbor, .blossom, .keep, .cloudspire, .peaks, .onsen],
            dayParts: [.day], rarity: .uncommon,
            motion: .linger, altitude: 0.230, size: .init(width: 84, height: 48),
            weathers: [.rain, .drizzle], awardedLate: true, isPhenomenon: true)
        case .meteors: Spec(name: "Meteor Shower", note: "Three in a row, then nothing for ages.",
            places: [.peaks], dayParts: [.night], rarity: .uncommon,
            motion: .flutter, altitude: 0.140, size: .init(width: 56, height: 42),
            isPhenomenon: true)
        case .aurora: Spec(name: "Aurora", note: "The whole sky, quietly, for a while.",
            places: [.peaks], dayParts: [.night], rarity: .rare,
            motion: .linger, altitude: 0.150, size: .init(width: 92, height: 60),
            isPhenomenon: true)
        case .sunshower: Spec(name: "Sun Shower", note: "Raining, in full sun, from a sky with nothing in it.",
            places: [.meadow, .woods, .blossom, .keep], dayParts: [.day], rarity: .rare,
            motion: .linger, altitude: 0.220, size: .init(width: 80, height: 46),
            weathers: [.rain, .drizzle], awardedLate: true, isPhenomenon: true)
        case .fogbow: Spec(name: "Fogbow", note: "A rainbow with the colour taken out. White, and enormous.",
            places: [.peaks, .woods, .harbor], dayParts: [.day], rarity: .rare,
            motion: .linger, altitude: 0.240, size: .init(width: 82, height: 44),
            weathers: [.mist], awardedLate: true, isPhenomenon: true)
        // The journal's rarest page: one chance a year, and only if you happen
        // to be sitting down for the first storm of spring.
        case .firstthunder: Spec(name: "First Thunder", note: "The first of the year. Everything went quiet first.",
            places: [.meadow, .woods, .harbor, .blossom, .keep, .cloudspire, .peaks, .onsen],
            dayParts: [], rarity: .mythic,
            motion: .linger, altitude: 0.180, size: .init(width: 70, height: 50),
            weathers: [.storm], awardedLate: true, isPhenomenon: true)
        // The sky's own migrant. Four-year cycle, six weeks when it comes, and
        // no weather gate — a comet is above the weather and gating it on a
        // clear sky would make a once-in-four-years thing miss its own window.
        case .comet: Spec(name: "Comet", note: "A little further along the sky every evening.",
            places: [.meadow, .woods, .harbor, .blossom, .keep, .cloudspire, .peaks, .onsen],
            dayParts: [.dusk, .night], rarity: .uncommon,
            motion: .linger, altitude: 0.120, size: .init(width: 66, height: 38),
            isPhenomenon: true, passage: .comet)
        }
    }

    // MARK: Convenience

    var name: String { spec.name }
    var note: String { spec.note }
    var places: [Place] { spec.places }
    var dayParts: [DayPart] { spec.dayParts }
    var rarity: Rarity { spec.rarity }
    var motion: Motion { spec.motion }
    var altitude: Double { spec.altitude }
    var size: CGSize { spec.size }
    var isPhenomenon: Bool { spec.isPhenomenon }

    var frames: [String] { ["wild_\(rawValue)_0", "wild_\(rawValue)_1"] }
    var ghostAsset: String { "wild_\(rawValue)_ghost" }
    var sketchAsset: String { "wild_\(rawValue)_sketch" }
    /// The marked variant, once this species has become an individual.
    var regularAsset: String { "wild_\(rawValue)_regular" }

    // MARK: Regulars

    /// What tells this individual apart, once you have seen enough of them to
    /// start noticing.
    ///
    /// Grouped by body plan rather than written one species at a time. Forty
    /// bespoke lines would be better, but "the whale with the notched ear" is
    /// much worse than a plain one — a shared phrase that is always *true*
    /// beats a unique one that is sometimes absurd.
    var marking: String {
        switch self {
        case .robin, .swallow, .gull, .heron, .woodpecker, .tawnyowl, .crane,
             .kingfisher, .dove, .peacock, .swift, .ptarmigan,
             .stormpetrel, .weathercrow, .winterwren, .greywagtail, .redkite,
             .whooperswan, .cuckoo, .redwing, .snowgoose, .waxwing:
            "a pale feather"
        case .butterfly, .bee, .moth, .dragonfly, .firefly,
             .fogmoth, .dragonswarm, .rainbeetle, .paintedlady:
            "a torn wing"
        case .dolphin, .whale, .seal, .otter, .turtle, .koi, .crab, .frog,
             .bigfrog, .littlefrog, .earthworm, .ghostslug, .salmonrun:
            "a pale scar"
        // Its own arm rather than folded into the scars: a snail is told apart
        // by its shell, and "the garden snail with a pale scar" is a sentence
        // about an animal nobody has ever looked at.
        case .gardensnail:
            "a chip out of the shell"
        case .hare, .foxcub, .squirrel, .stag, .badger, .fawn, .hedgehog,
             .sheep, .mountainhare, .ibex, .macaque, .tanuki, .moonrabbit,
             .roedeer, .suncat, .dandelionmouse, .snowfox, .ermine,
             .mushroomvole:
            "a notched ear"
        case .rainbow, .meteors, .aurora, .sunshower, .fogbow, .firstthunder,
             .comet:
            // A rainbow is never an individual, and never becomes a regular.
            ""
        }
    }

    /// Whether this can become someone rather than something.
    var canBeRegular: Bool { !isPhenomenon }

    /// The journal's line once it is a regular. Relationship over collection:
    /// the note stops describing the species and starts describing the one you
    /// keep running into.
    var regularNote: String {
        "The \(name.lowercased()) with \(marking). The same one, every time."
    }

    /// Whether this could turn up in the session about to start.
    ///
    /// The late-awarded ones are deliberately excluded: a rainbow depends on
    /// what the session *did*, which nobody knows when it begins. They are
    /// handed out on completion instead.
    func isEligible(
        place: Place,
        dayPart: DayPart,
        focusMinutes: Int,
        moonIsFull: Bool,
        weather: Weather
    ) -> Bool {
        guard !spec.awardedLate else { return false }
        // The passage gate goes first: it is the only one that can be shut on
        // 350 days of the year, so asking it first is both cheaper and the
        // honest reading — the swans are not "eligible but unlucky" in July,
        // they are in Iceland.
        if let passage = spec.passage, !Passage.isOpen(passage) { return false }
        return spec.places.contains(place)
            && (spec.dayParts.isEmpty || spec.dayParts.contains(dayPart))
            && focusMinutes >= spec.minimumMinutes
            && (!spec.needsFullMoon || moonIsFull)
            && (spec.weathers.isEmpty || spec.weathers.contains(weather))
    }

    /// The clue shown under a species you haven't seen. Enough to act on —
    /// that is the whole retention mechanism — without being a recipe.
    var hint: String {
        if spec.awardedLate {
            let sky = spec.weathers.first?.hintPhrase ?? "the weather"
            return "After focusing through \(sky)"
        }
        // A passage names its month and nothing else. It is the one hint in
        // the journal that cannot be acted on today, so it says the least of
        // any of them: no dates, no countdown, no "in 9 days" — only the time
        // of year, which is what somebody standing in a field would know.
        if let passage = spec.passage {
            return "Some years, around \(passage.hintMonth)"
        }
        let where_ = spec.places.count > 3
            ? "anywhere"
            : spec.places.map(\.name).joined(separator: " or ")
        var when = spec.dayParts.first.map(\.hintPhrase) ?? "any time"
        if spec.needsFullMoon { when = "under a full moon" }
        if spec.minimumMinutes > 0 { when += ", on a long session" }
        var line = "\(when.capitalizedFirst), in \(where_)"
        // The sky goes last and is never plural: "in the rain or the drizzle"
        // reads as a recipe, and the point of a hint is somewhere to stand
        // rather than a list of conditions to satisfy.
        if let sky = spec.weathers.first?.hintPhrase { line += ", in \(sky)" }
        return line
    }

    enum Rarity: String, Codable, CaseIterable {
        case common, uncommon, rare, mythic

        /// Odds of turning up in a session it's eligible for. Mythic is not
        /// rolled at all — its conditions are the gate.
        var chance: Double {
            switch self {
            case .common: 1.0 / 3.0
            case .uncommon: 1.0 / 8.0
            case .rare: 1.0 / 12.0
            case .mythic: 1.0 / 2.0
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
