import Foundation
import Observation

/// Something the buddy dreamed while you were focusing.
///
/// The buddy sleeps through every focus session, and sleeping creatures dream.
/// What it dreams about is your shared journey: a species the two of you
/// actually saw, a vignette you sailed with, or — rarely — something that could
/// only happen asleep. The sentence this is built around is *"my cat just
/// dreamed about the whale we saw."*
///
/// Almost all of it is recycled. A memory dream reuses the field journal's
/// existing sepia sketch, a travel dream reuses the vignette sprite; only the
/// six surreal ones are new art. That is deliberate rather than thrifty: a rich
/// journal makes a rich dream life, which quietly makes the journal itself
/// worth more.
///
/// Six of the thirteen cases arrived together, in Phase 0d of the Deep Time plan,
/// to pay a debt: the pool had not been fed since it was written, so five whole
/// systems — the bond, the regulars, the things you can only hear, the seasons
/// and the stray's arc — could be lived through without the buddy ever dreaming
/// about any of them. Each has its own case now, gated in `TimerEngine.pool()`
/// on the thing itself, so a dream can only be had by somebody who earned what
/// it is about.
///
/// `sky`, `adrift` and `hour` came later and came the way the convention now
/// says they should: weather, the open hour and the shelf each shipped *with*
/// their dreams rather than owing them. None of the three cost new art —
/// `hour` in particular is the shelf's own candle sprites, as silhouettes.
enum Dream: Hashable, Identifiable {
    /// Something you both saw. The heart of it.
    case memory(Species)
    /// Not the species — the one you keep running into.
    case regular(Species)
    /// Something you travelled with.
    case travel(Vignette)
    /// One of the others in the household, asleep somewhere else.
    case companion(Buddy)
    /// The cat outside, while she is still outside.
    case visitor(Visitor)
    /// Something only ever heard, and never once seen.
    case sound(Heard)
    /// The time of year, dreamed while it is still that time of year.
    case season(Season)
    /// What the sky left behind today.
    case sky(Sky)
    /// Something a finger did to the night sky.
    case joined(Joined)
    /// An open hour, once you have sat one.
    case adrift(Adrift)
    /// An hour of the clock you have actually been awake in.
    case hour(Hour)
    /// The wood behind the house, once there is one.
    case wood(Wood)
    /// One of the neighbours, once they have moved in.
    case neighbour(Neighbour)
    /// Something that only passes through, remembered afterwards.
    case flight(Flight)
    /// The sea, doing the one thing it does.
    case tidal(Tidal)
    /// The bird who keeps the cart, once you have met her.
    case magpie(Magpie)
    /// Wearing something, somewhere it does not matter.
    case finery(Finery)
    /// Home, from the inside.
    case den(Home)
    /// Something it brought you, dreamed about again.
    case brought(Brought)
    /// A place *you* sat, seen from slightly above.
    case snapshot(Snapshot)
    /// You, which takes a while.
    case yours(Yours)
    /// Something that only happens asleep.
    case surreal(Surreal)

    /// The six that had to be drawn. Ids match `tools/generate_sprites.py`.
    enum Surreal: String, CaseIterable, Hashable {
        case fishballoon, yarn, tub, meadow, train, moonrabbit

        var line: String {
            switch self {
            case .fishballoon: "A fish, holding the balloon's string."
            case .yarn: "A ball of yarn the size of a house."
            case .tub: "The tub, out at sea, quite happy about it."
            case .meadow: "The meadow, going on much further than it does."
            case .train: "The night train, with one window still lit."
            // Dreamed long before it is ever seen — the moon rabbit is real,
            // and only turns up under a full moon at three places.
            case .moonrabbit: "A rabbit-shaped shadow on the moon."
            }
        }
    }

    /// The stray, at the distance she had reached when she was dreamed about.
    ///
    /// Its own String-raw enum rather than `Stray.Stage`, which is `Int`-raw:
    /// the diary is keyed on `id`, and `"visitor.3"` is a key nobody could read
    /// and nothing could safely renumber.
    enum Visitor: String, CaseIterable, Hashable {
        case hedge, grass, cushion

        /// How far she has to have come before your buddy dreams this.
        var reachedAt: Stray.Stage {
            switch self {
            case .hedge: .edge
            case .grass: .watching
            case .cushion: .beside
            }
        }

        /// She has three sprites of her own, so this costs no art. Drawn as
        /// silhouettes, like the vignettes: they were painted for the scene.
        var asset: String {
            switch self {
            case .hedge: "stray_distant"
            case .grass: "stray_watch_0"
            case .cushion: "stray_watch_1"
            }
        }

        var subject: String {
            switch self {
            case .hedge: "the cat at the edge"
            case .grass: "the cat in the grass"
            case .cushion: "the cat who stayed"
            }
        }

        var line: String {
            switch self {
            case .hedge: "Not close, and not gone. There again."
            case .grass: "Sitting where she can see you, and not moving."
            case .cushion: "Near enough to hear breathing. Nobody moved."
            }
        }
    }

    /// What the weather leaves behind, once it has gone.
    ///
    /// Deliberately three, not one per weather: nine weathers would be nine
    /// sprites and nine near-identical captions, and a dream about "overcast"
    /// is not a dream about anything. These are the three the sky leaves you
    /// something to remember it by — and two of them are rare enough that
    /// having them in the diary means you were actually there.
    enum Sky: String, CaseIterable, Hashable {
        case puddle, thunder, afterglow

        /// Which weathers earn it. A dream about a puddle belongs to somebody
        /// who sat through the rain that made it.
        var reachedAt: [Weather] {
            switch self {
            case .puddle: [.drizzle, .rain]
            case .thunder: [.storm]
            case .afterglow: [.golden]
            }
        }

        var subject: String {
            switch self {
            case .puddle: "the puddle"
            case .thunder: "the thunder"
            case .afterglow: "the light afterwards"
            }
        }

        var line: String {
            switch self {
            case .puddle: "Deeper than it looked, and warm."
            case .thunder: "Further off each time, and then not at all."
            case .afterglow: "Everything lit from one side, and steaming."
            }
        }
    }

    /// The night sky, after somebody has been touching it.
    ///
    /// Gated on `SkyTouches` rather than on a threshold, which is the same
    /// rule the rest of this file follows: the store that knows already knows,
    /// and a second table saying when these unlock could only ever disagree
    /// with it. Note none of the three names a figure — the buddy dreams that
    /// a line was drawn, not which constellation got it, so this stays true
    /// whichever one you joined first.
    enum Joined: String, CaseIterable, Hashable {
        case firstjoin, figure, askedmoon

        var subject: String {
            switch self {
            case .firstjoin: "two stars, and a line"
            case .figure: "a whole figure, joined up"
            case .askedmoon: "the moon, asked something"
            }
        }

        var line: String {
            switch self {
            case .firstjoin: "Somebody drew it. It was still there in the morning."
            case .figure: "Finished early, and the sky did not mind."
            case .askedmoon: "It answered. Neither of them said what."
            }
        }
    }

    /// What an open hour leaves behind.
    ///
    /// Two, not three: the Drift is one idea and it does not need three
    /// captions to say it. Gated on how long you have actually drifted, in
    /// laps rather than minutes, so it is reachable under fast timers as well
    /// as in a real afternoon.
    enum Adrift: String, CaseIterable, Hashable {
        case nomap, rings, deep

        /// Laps of the longest drift so far before this can be dreamed.
        var reachedAt: Int {
            switch self {
            case .nomap: 1
            case .rings: 3
            // Deeper than anything the deep-drift roster asks for, so this
            // arrives after the animals rather than before them — a dream
            // about something enormous going under, had by somebody who has
            // not yet been shown one, would be the app spoiling its own
            // surprise.
            case .deep: 4
            }
        }

        var subject: String {
            switch self {
            case .nomap: "a boat with no oars"
            case .rings: "the rings in a cut log"
            case .deep: "something that went under"
            }
        }

        var line: String {
            switch self {
            case .nomap: "Nowhere it needed to be, and no hurry about that."
            case .rings: "More of them than either of you remembered counting."
            case .deep: "It did not come back up, and that was all right."
            }
        }
    }

    /// Two hours off the Shelf of Hours, and the only two worth a dream.
    ///
    /// No new art: these are the shelf's own candle sprites as silhouettes,
    /// which is also why they are two rather than three — there are two
    /// candles and they say different things. Both are gated on having
    /// actually lit that candle, so a dream about 3 a.m. belongs to somebody
    /// who was up at 3 a.m.
    enum Hour: String, CaseIterable, Hashable {
        case smallhours, blownout

        /// Which candle has to be lit. Read off `ShelfOfHours` rather than
        /// written out, so the two cannot drift about which hour is which.
        var reachedAt: Int {
            switch self {
            case .smallhours: ShelfOfHours.smallHours
            case .blownout: ShelfOfHours.firstLight
            }
        }

        var asset: String {
            switch self {
            case .smallhours: "fx_candle_lit"
            case .blownout: "fx_candle_out"
            }
        }

        var subject: String {
            switch self {
            case .smallhours: "the small hours"
            case .blownout: "a candle put out"
            }
        }

        var line: String {
            switch self {
            case .smallhours: "The hour with nobody else awake in it."
            case .blownout: "It had got light without either of you noticing."
            }
        }
    }

    /// The grove, dreamed by the one who sleeps under it.
    ///
    /// No new art again: the grove's own tree sprites as silhouettes. Gated on
    /// trees actually standing there, so the first is available after an hour
    /// and the second after a small wood.
    enum Wood: String, CaseIterable, Hashable {
        case firstone, canopy, hundred

        /// Trees that have to be standing.
        var reachedAt: Int {
            switch self {
            case .firstone: 1
            case .canopy: 25
            // The panorama's own dream, and the last thing in the diary
            // anybody reaches. Written as `Grove.panoramaHours` rather than
            // as 100 so the gate cannot disagree with the card it is about —
            // the standing rule, and here it is load-bearing, because these
            // two are four months apart and nobody would ever notice them
            // drifting.
            case .hundred: Grove.panoramaHours
            }
        }

        var asset: String {
            switch self {
            case .firstone: "grove_sapling"
            case .canopy, .hundred: "grove_full"
            }
        }

        var subject: String {
            switch self {
            case .firstone: "the first tree"
            case .canopy: "the whole wood"
            case .hundred: "the wood from above"
            }
        }

        var line: String {
            switch self {
            case .firstone: "Still mostly a stick. It does not know that."
            case .canopy: "Under all of it at once, and nowhere near an edge."
            case .hundred: "All of it, at once, from somewhere much higher up."
            }
        }
    }

    /// The homestead's other half: what moved in, dreamed about once it has.
    ///
    /// Three of the eight rather than one each — a dream per resident would be
    /// eight near-identical captions, and "I dreamed about the washing line"
    /// is not a dream about anything. These three are the ones with something
    /// in them: a pond has a fish, a birdhouse has a tenant, and a lantern
    /// nobody is ever seen lighting is the closest this app comes to a ghost
    /// story.
    ///
    /// Costs no new art. `reachedAt` is the resident itself, so the gate is
    /// the one in `Resident.arrivesAt` rather than a second table that could
    /// drift out of step with it.
    enum Neighbour: String, CaseIterable, Hashable {
        case fish, tenant, lamplight

        var reachedAt: Resident {
            switch self {
            case .fish: .pond
            case .tenant: .birdhouse
            case .lamplight: .lantern
            }
        }

        /// The second frame in each case: the one where something is
        /// happening. Drawn as silhouettes, like the vignettes — they were
        /// painted to sit in a garden, not inside a bubble.
        var asset: String {
            switch self {
            case .fish: "resident_pond_1"
            case .tenant: "resident_birdhouse_1"
            case .lamplight: "resident_lantern_1"
            }
        }

        var subject: String {
            switch self {
            case .fish: "whatever is in the pond"
            case .tenant: "whoever took the birdhouse"
            case .lamplight: "the lantern, lighting itself"
            }
        }

        var line: String {
            switch self {
            case .fish: "Up once, and then a long time nothing."
            case .tenant: "Somebody at the door of it, deciding."
            case .lamplight: "It came on. Nobody was there to do it."
            }
        }
    }

    /// The Flyway, dreamed about afterwards.
    ///
    /// Three, and the tense is the point: a passage is a fortnight and the
    /// dream is available for the whole year after it. That is deliberate and
    /// it is the only place in this app where a dream outlives its subject by
    /// eleven months. It is also the closest thing the Flyway has to a
    /// consolation — you cannot get the swans back, but the buddy remembers
    /// them until they come again, which is what remembering is for.
    ///
    /// No new art. `going` and `gone` reuse the skein sprites the passages
    /// already have; `high` is the comet's own frame. All three as
    /// silhouettes, like the vignettes.
    enum Flight: String, CaseIterable, Hashable {
        case going, gone, high

        /// The species whose sighting opens it. Written as the *passage*
        /// rather than the species, because the passage is the thing that
        /// happened and the species is only how you noticed.
        var reachedAt: Passage {
            switch self {
            case .going: .snowgeese
            case .gone: .swans
            case .high: .comet
            }
        }

        var asset: String {
            switch self {
            case .going: "wild_snowgoose_0"
            case .gone: "wild_whooperswan_1"
            case .high: "wild_comet_0"
            }
        }

        var subject: String {
            switch self {
            case .going: "a line of something, going"
            case .gone: "the sky the morning after"
            case .high: "the light that came back"
            }
        }

        var line: String {
            switch self {
            case .going: "Still going when the dream ended."
            case .gone: "Empty, and quieter than it had been for a fortnight."
            case .high: "It had been there before. Nobody remembered when."
            }
        }
    }

    /// The sea at Harbor Isle, dreamed about by an animal who does not
    /// understand it.
    ///
    /// Three, and none of them mentions the moon. That is the joke and it is
    /// also the honest thing: a cat watching the water go out has no theory
    /// about why, and a caption explaining the spring–neap cycle would be the
    /// app teaching through the buddy's mouth. The almanac teaches; the diary
    /// only ever remembers.
    ///
    /// No new art — the shore's own animals, as silhouettes.
    enum Tidal: String, CaseIterable, Hashable {
        case out, pools, back

        /// The state of the water that earns it.
        var reachedAt: Tide.State {
            switch self {
            case .out: .low
            case .pools: .springLow
            case .back: .high
            }
        }

        var asset: String {
            switch self {
            case .out: "wild_curlew_0"
            case .pools: "wild_octopus_0"
            case .back: "wild_oystercatcher_1"
            }
        }

        var subject: String {
            switch self {
            case .out: "the ground under the sea"
            case .pools: "something in the deepest pool"
            case .back: "the water, back again"
            }
        }

        var line: String {
            switch self {
            case .out: "It had all gone somewhere, and nobody was worried."
            case .pools: "It looked back. That was the whole dream."
            case .back: "Over the same stones, as if they had never been dry."
            }
        }
    }

    /// The magpie, and the one thing in her cart the buddy actually wants.
    ///
    /// The era's dream pair, and it is deliberately *hers* rather than the
    /// pouch's. In five plan documents this is the one knowing exception to
    /// "every feature lands with two or three dreams": the acorns get none.
    /// A buddy that dreams about a balance is a buddy that has been given a
    /// job, and the whole argument for the currency being invisible outside
    /// two screens falls over the moment it turns up in the diary.
    ///
    /// So the magpie gets them instead, and neither line mentions a price.
    /// Costs no new art — her own two sprites, as silhouettes.
    enum Magpie: String, CaseIterable, Hashable {
        case counting, shiny

        var asset: String {
            switch self {
            case .counting: "magpie_1"
            case .shiny: "magpie_0"
            }
        }

        var subject: String {
            switch self {
            case .counting: "the magpie, counting"
            case .shiny: "something shiny"
            }
        }

        var line: String {
            switch self {
            case .counting: "Counting, and losing count, and starting again."
            case .shiny: "Exactly the right pebble. She knew it at once."
            }
        }
    }

    /// Dressed up, in a dream, for nobody.
    ///
    /// Gated on actually owning the thing — or, for the free pieces, on having
    /// worn it once — so a dream about a crown belongs to somebody who has
    /// one, and a dream about the leaf to somebody who put it on. Costs no
    /// new art — the accessory's own sprite, as a silhouette.
    enum Finery: String, CaseIterable, Hashable {
        case crowned, belled, leafed, bowed

        var reachedAt: Accessory {
            switch self {
            case .crowned: .crown
            case .belled: .bellcollar
            case .leafed: .leaf
            case .bowed: .bow
            }
        }

        var asset: String { reachedAt.asset }

        var subject: String {
            switch self {
            case .crowned: "the small crown"
            case .belled: "the bell"
            case .leafed: "the leaf"
            case .bowed: "the bow"
            }
        }

        var line: String {
            switch self {
            case .crowned: "Wearing it to nowhere in particular, at length."
            case .belled: "It rang, and nothing in the dream looked up."
            case .leafed: "It was the whole tree, and still weighed nothing."
            case .bowed: "Everyone was wearing one. Nobody mentioned it."
            }
        }
    }

    /// The den, dreamed from inside it.
    ///
    /// Named `Home` rather than `Den` because `check_swift.py` refuses two
    /// enums with the same simple name outright — it matches on that name, and
    /// the day `Grove.Stage` collided with `Stray.Stage` it reported three
    /// confident wrong failures before anybody worked out why.
    ///
    /// Gated on owning a den at all rather than on owning a particular one:
    /// the dream is about having somewhere to sleep, and every den is that.
    enum Home: String, CaseIterable, Hashable {
        case inside, doorway

        /// Drawn from the current buddy's own den at the call site would be
        /// nicer and is not possible — a `Dream` is a model type with no
        /// settings to ask. The basket stands for all of them, as a
        /// silhouette, which is what a dream of *somewhere warm* looks like.
        var asset: String {
            switch self {
            case .inside: "den_basket_1"
            case .doorway: "den_doghouse_0"
            }
        }

        var subject: String {
            switch self {
            case .inside: "somewhere warm"
            case .doorway: "the doorway"
            }
        }

        var line: String {
            switch self {
            case .inside: "Bigger inside than it is, and warm."
            case .doorway: "Standing in it, deciding the weather is not worth it."
            }
        }
    }

    /// The things it left on the desk, dreamed about afterwards.
    ///
    /// The one dream family that is about something the *buddy* did rather
    /// than something you did or somewhere you went — which is the whole
    /// argument for keepsakes existing, restated in the diary.
    enum Brought: String, CaseIterable, Hashable {
        case thestick, thefeather

        var reachedAt: Keepsake {
            switch self {
            case .thestick: .stick
            case .thefeather: .feather
            }
        }

        var asset: String { reachedAt.asset }

        var subject: String {
            switch self {
            case .thestick: "the stick"
            case .thefeather: "the feather"
            }
        }

        var line: String {
            switch self {
            case .thestick: "Carrying it a long way, for no reason it could give."
            case .thefeather: "Grey, and slightly bent, and worth the trip."
            }
        }
    }

    /// A place you sat once, dreamed by somebody who was there.
    ///
    /// The only dream family about the *real* world — your desk rather than
    /// the meadow — which is exactly what the Scrapbook is for. Costs no new
    /// art: the vignette sprites, as silhouettes, standing in for a room.
    enum Snapshot: String, CaseIterable, Hashable {
        case fromabove, thewindow

        var asset: String {
            switch self {
            case .fromabove: "dream_yours_desk"
            case .thewindow: "dream_yours_doorway"
            }
        }

        var subject: String {
            switch self {
            case .fromabove: "a place you sat"
            case .thewindow: "the window table"
            }
        }

        var line: String {
            switch self {
            case .fromabove: "Seen from slightly above, and further off than it was."
            case .thewindow: "The light was doing that thing again."
            }
        }
    }

    /// Three things of yours, unlocked by the bond and nothing else.
    ///
    /// The bond is the one counter in the app that measures time spent
    /// *together*, so what it buys is the buddy dreaming about you rather than
    /// about the world. Each level's own description picked the object: at
    /// `friendly` it settles the moment you sit down, at `close` it waits by
    /// the door, at `devoted` it has picked a side of the desk.
    enum Yours: String, CaseIterable, Hashable {
        case chair, doorway, desk

        var reachedAt: Bond {
            switch self {
            case .chair: .friendly
            case .doorway: .close
            case .desk: .devoted
            }
        }

        var subject: String {
            switch self {
            case .chair: "your chair"
            case .doorway: "your door"
            case .desk: "your desk"
            }
        }

        var line: String {
            switch self {
            case .chair: "With you in it, and no hurry about any of it."
            case .doorway: "Opening, at about the usual time."
            case .desk: "Both sides of it, and a mug going cold."
            }
        }
    }

    /// Stable across launches: the diary is keyed on it.
    var id: String {
        switch self {
        case .memory(let species): "memory.\(species.rawValue)"
        case .regular(let species): "regular.\(species.rawValue)"
        case .travel(let vignette): "travel.\(vignette.rawValue)"
        case .companion(let buddy): "companion.\(buddy.rawValue)"
        case .visitor(let visitor): "visitor.\(visitor.rawValue)"
        case .sound(let sound): "sound.\(sound.rawValue)"
        case .season(let season): "season.\(season.rawValue)"
        case .sky(let sky): "sky.\(sky.rawValue)"
        case .joined(let joined): "joined.\(joined.rawValue)"
        case .adrift(let adrift): "adrift.\(adrift.rawValue)"
        case .hour(let hour): "hour.\(hour.rawValue)"
        case .wood(let wood): "wood.\(wood.rawValue)"
        case .neighbour(let neighbour): "neighbour.\(neighbour.rawValue)"
        case .flight(let flight): "flight.\(flight.rawValue)"
        case .tidal(let tidal): "tidal.\(tidal.rawValue)"
        case .magpie(let magpie): "magpie.\(magpie.rawValue)"
        case .finery(let finery): "finery.\(finery.rawValue)"
        case .den(let home): "den.\(home.rawValue)"
        case .brought(let brought): "brought.\(brought.rawValue)"
        case .snapshot(let snapshot): "snapshot.\(snapshot.rawValue)"
        case .yours(let yours): "yours.\(yours.rawValue)"
        case .surreal(let surreal): "surreal.\(surreal.rawValue)"
        }
    }

    static func from(id: String) -> Dream? {
        let parts = id.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "memory": return Species(rawValue: parts[1]).map(Dream.memory)
        case "regular": return Species(rawValue: parts[1]).map(Dream.regular)
        case "travel": return Vignette(rawValue: parts[1]).map(Dream.travel)
        case "companion": return Buddy(rawValue: parts[1]).map(Dream.companion)
        case "visitor": return Visitor(rawValue: parts[1]).map(Dream.visitor)
        case "sound": return Heard(rawValue: parts[1]).map(Dream.sound)
        case "season": return Season(rawValue: parts[1]).map(Dream.season)
        case "sky": return Sky(rawValue: parts[1]).map(Dream.sky)
        case "joined": return Joined(rawValue: parts[1]).map(Dream.joined)
        case "adrift": return Adrift(rawValue: parts[1]).map(Dream.adrift)
        case "hour": return Hour(rawValue: parts[1]).map(Dream.hour)
        case "wood": return Wood(rawValue: parts[1]).map(Dream.wood)
        case "neighbour": return Neighbour(rawValue: parts[1]).map(Dream.neighbour)
        case "flight": return Flight(rawValue: parts[1]).map(Dream.flight)
        case "tidal": return Tidal(rawValue: parts[1]).map(Dream.tidal)
        case "magpie": return Magpie(rawValue: parts[1]).map(Dream.magpie)
        case "finery": return Finery(rawValue: parts[1]).map(Dream.finery)
        case "den": return Home(rawValue: parts[1]).map(Dream.den)
        case "brought": return Brought(rawValue: parts[1]).map(Dream.brought)
        case "snapshot": return Snapshot(rawValue: parts[1]).map(Dream.snapshot)
        case "yours": return Yours(rawValue: parts[1]).map(Dream.yours)
        case "surreal": return Surreal(rawValue: parts[1]).map(Dream.surreal)
        default: return nil
        }
    }

    var asset: String {
        switch self {
        case .memory(let species): species.sketchAsset
        // Already a sepia sketch *with the marking on it* — the same drawing
        // the journal uses to say this one is somebody. No new art.
        case .regular(let species): species.regularAsset
        case .travel(let vignette): vignette.assetName
        case .companion(let buddy): buddy.asleepAssetName
        case .visitor(let visitor): visitor.asset
        case .sound(let sound): "dream_heard_\(sound.rawValue)"
        case .season(let season): "dream_season_\(season.rawValue)"
        case .sky(let sky): "dream_sky_\(sky.rawValue)"
        case .joined(let joined): "dream_joined_\(joined.rawValue)"
        case .adrift(let adrift): "dream_adrift_\(adrift.rawValue)"
        case .hour(let hour): hour.asset
        case .wood(let wood): wood.asset
        case .neighbour(let neighbour): neighbour.asset
        case .flight(let flight): flight.asset
        case .tidal(let tidal): tidal.asset
        case .magpie(let magpie): magpie.asset
        case .finery(let finery): finery.asset
        case .den(let home): home.asset
        case .brought(let brought): brought.asset
        case .snapshot(let snapshot): snapshot.asset
        case .yours(let yours): "dream_yours_\(yours.rawValue)"
        case .surreal(let surreal): "dream_\(surreal.rawValue)"
        }
    }

    /// Art drawn in full colour for somewhere else — the vignettes for the sky,
    /// the buddies and the stray for the scene — is rendered as a silhouette
    /// here instead, so everything inside a bubble is a sketch.
    var isSilhouette: Bool {
        switch self {
        case .travel, .companion, .visitor, .hour, .wood, .neighbour,
             .magpie, .finery, .den, .brought, .snapshot, .flight,
             .tidal: true
        case .memory, .regular, .sound, .season, .sky, .joined, .adrift,
             .yours, .surreal: false
        }
    }

    /// What the thing is called, on its own.
    ///
    /// Never a buddy's name: any of them can be renamed, and a caption has to
    /// go through `PomodoroSettings.displayName(for:)` to know that. A
    /// companion is described by what it *is* instead, which stays true
    /// whatever it has been renamed to — and keeps the one name the player
    /// chose by hand out of a sentence that would have hard-coded it.
    var subject: String {
        switch self {
        case .memory(let species): species.name.lowercased()
        case .regular(let species): "the \(species.name.lowercased())"
        case .travel(let vignette): vignette.name
        case .companion(let buddy): buddy.dreamSubject
        case .visitor(let visitor): visitor.subject
        case .sound(let sound): sound.name.lowercased()
        case .season(let season): season.name.lowercased()
        case .sky(let sky): sky.subject
        case .joined(let joined): joined.subject
        case .adrift(let adrift): adrift.subject
        case .hour(let hour): hour.subject
        case .wood(let wood): wood.subject
        case .neighbour(let neighbour): neighbour.subject
        case .flight(let flight): flight.subject
        case .tidal(let tidal): tidal.subject
        case .magpie(let magpie): magpie.subject
        case .finery(let finery): finery.subject
        case .den(let home): home.subject
        case .brought(let brought): brought.subject
        case .snapshot(let snapshot): snapshot.subject
        case .yours(let yours): yours.subject
        case .surreal: "something strange"
        }
    }

    /// The line under the bubble in the diary.
    var line: String {
        switch self {
        case .memory(let species): species.note
        case .regular(let species): species.regularNote
        case .travel(let vignette): vignette.dreamLine
        case .companion(let buddy): buddy.dreamLine
        case .visitor(let visitor): visitor.line
        case .sound(let sound): sound.dreamLine
        case .season(let season): season.dreamLine
        case .sky(let sky): sky.line
        case .joined(let joined): joined.line
        case .adrift(let adrift): adrift.line
        case .hour(let hour): hour.line
        case .wood(let wood): wood.line
        case .neighbour(let neighbour): neighbour.line
        case .flight(let flight): flight.line
        case .tidal(let tidal): tidal.line
        case .magpie(let magpie): magpie.line
        case .finery(let finery): finery.line
        case .den(let home): home.line
        case .brought(let brought): brought.line
        case .snapshot(let snapshot): snapshot.line
        case .yours(let yours): yours.line
        case .surreal(let surreal): surreal.line
        }
    }

    /// Every dream there is, for counting the diary against — and the order the
    /// diary lists them in: your journey first, then the household, then the
    /// world, then the impossible.
    ///
    /// Phenomena are filtered out of the regulars because a rainbow never
    /// becomes an individual. `Species.canBeRegular` is the same test the
    /// journal uses, so there is one opinion about it rather than two.
    static var everything: [Dream] {
        Species.allCases.map(Dream.memory)
            + Species.allCases.filter(\.canBeRegular).map(Dream.regular)
            + [Vignette.sailboat, .balloon, .train].map(Dream.travel)
            + Buddy.allCases.map(Dream.companion)
            + Visitor.allCases.map(Dream.visitor)
            + Heard.allCases.map(Dream.sound)
            + Season.allCases.map(Dream.season)
            + Sky.allCases.map(Dream.sky)
            + Joined.allCases.map(Dream.joined)
            + Adrift.allCases.map(Dream.adrift)
            + Hour.allCases.map(Dream.hour)
            + Wood.allCases.map(Dream.wood)
            + Neighbour.allCases.map(Dream.neighbour)
            + Flight.allCases.map(Dream.flight)
            + Tidal.allCases.map(Dream.tidal)
            + Magpie.allCases.map(Dream.magpie)
            + Finery.allCases.map(Dream.finery)
            + Home.allCases.map(Dream.den)
            + Brought.allCases.map(Dream.brought)
            + Snapshot.allCases.map(Dream.snapshot)
            + Yours.allCases.map(Dream.yours)
            + Surreal.allCases.map(Dream.surreal)
    }
}

extension Vignette {
    var name: String {
        switch self {
        case .sailboat: "the sailboat"
        case .balloon: "the balloon"
        case .train: "the night train"
        }
    }

    var dreamLine: String {
        switch self {
        case .sailboat: "Still crossing, in no hurry at all."
        case .balloon: "Higher than it ever goes awake."
        case .train: "Somewhere past Starfall, still going."
        }
    }
}

extension Buddy {
    /// What the one on duty calls the one it is dreaming about. Deliberately
    /// not a name — see `Dream.subject`.
    var dreamSubject: String {
        // Soot is the second cat in the cast, so "the cat" would be ambiguous
        // the moment Mochi is the one asleep.
        self == .stray ? "the cat who came in" : "the \(kind)"
    }

    /// Where this one sleeps, told by somebody else. Each is the buddy's own
    /// signature behaviour carried into the dream, so a quirk stays data.
    var dreamLine: String {
        switch self {
        case .cat: "Asleep in the good spot, as usual."
        case .dog: "Asleep, with all four feet still going."
        case .penguin: "Asleep standing up, somehow."
        case .bunny: "Asleep with both ears down, which is rare."
        case .hamster: "Asleep under the bedding, mostly buried."
        case .fox: "Asleep in a curl, nose under tail."
        case .capybara: "Asleep in the tub. Not one ripple."
        case .redpanda: "Asleep along a branch, hanging over both sides."
        case .owl: "Asleep in the daylight, which is her night."
        case .otter: "Asleep on his back, still holding the pebble."
        case .hedgehog: "Asleep as a closed ball. No way in."
        case .stray: "Asleep indoors, in the warm bit by the window."
        }
    }
}

extension Heard {
    /// The dream is not the journal note: the note is about the night you heard
    /// it, and this is about hearing it again with nothing else in the way.
    /// Still nothing to look at — that rule survives the dream.
    var dreamLine: String {
        switch self {
        case .whalesong: "The answer this time. Still nothing to see."
        case .trainhorn: "Going away, the way it always is."
        case .owlcall: "Twice again, and the wood no closer."
        case .farbell: "One stroke, and the whole morning after it."
        case .windchime: "Four notes, in an order they have never used."
        case .distantthunder: "Behind the hills again, and staying there."
        case .foghorn: "Answered, this time, by something further out."
        case .geesesouth: "All of them, still going, still arguing."
        }
    }
}

extension Season {
    var dreamLine: String {
        switch self {
        case .sakura: "All of it at once, and none of it falling."
        case .fireflies: "The whole field lit, and nobody counting."
        case .autumn: "Coming down slowly enough to watch."
        case .winter: "Everything quiet, and none of it cold."
        case .lanterns: "Strung the length of a street with no end."
        }
    }
}

/// One dream, kept.
struct DreamRecord: Codable, Equatable {
    var firstDreamed: Date
    var lastDreamed: Date
    var count: Int
    /// Days between meeting the thing and dreaming about it, where that is
    /// knowable. It's what lets the diary write the relationship rather than
    /// just the fact — "three days after you met it".
    var daysAfter: Int?
}

/// Everything the buddy has dreamed and you stayed to see.
///
/// Leave a session early and the dream simply fades, unrecorded. Dreams are
/// like that, and it is the same no-guilt rule as the field journal: nothing is
/// taken away, some things are just not kept.
@Observable
final class DreamDiary {
    private(set) var records: [String: DreamRecord] = [:]

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = StorageKeys.dreams

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func record(for dream: Dream) -> DreamRecord? { records[dream.id] }

    func hasDreamed(_ dream: Dream) -> Bool { records[dream.id] != nil }

    var dreamedCount: Int { records.count }

    var total: Int { Dream.everything.count }

    func add(_ dream: Dream, daysAfter: Int? = nil, on date: Date = Date()) {
        if var existing = records[dream.id] {
            existing.count += 1
            existing.lastDreamed = date
            records[dream.id] = existing
        } else {
            records[dream.id] = DreamRecord(
                firstDreamed: date, lastDreamed: date, count: 1, daysAfter: daysAfter
            )
        }
        save()
    }

    func clear() {
        records = [:]
        save()
    }

    /// Debug only — every dream marked as dreamed, so the diary's whole spread
    /// can be looked at in one launch.
    ///
    /// Nothing else could reach it: the page draws on five gated systems now,
    /// and the honest route to a full one is a hundred and fifty sessions, five
    /// sightings of forty species, all five seasons of a year, and a cat who
    /// takes twelve days to come in.
    func fillForDebug(on date: Date = Date()) {
        for dream in Dream.everything where records[dream.id] == nil {
            records[dream.id] = DreamRecord(
                firstDreamed: date, lastDreamed: date, count: 1, daysAfter: nil
            )
        }
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: DreamRecord].self, from: data)
        else { return }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
