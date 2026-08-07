import Foundation

/// Every key the app persists under, in one place.
///
/// Collected here so the debug launch options below can clear or preseed the
/// app's state without duplicating string literals that would then drift.
enum StorageKeys {
    static let settings = "pawmodoro.settings"
    static let sessions = "pawmodoro.sessions"
    static let hasOnboarded = "pawmodoro.hasOnboarded"
    static let hasPlus = "pawmodoro.hasPlus"
    static let tipsGiven = "pawmodoro.tipsGiven"
    static let journal = "pawmodoro.journal"
    static let postcards = "pawmodoro.postcards"
    /// What the buddy has dreamed and you stayed to see.
    static let dreams = "pawmodoro.dreams"
    /// Things heard and never seen. Its own key rather than part of the
    /// journal's, so an older install decodes both halves independently.
    static let heard = "pawmodoro.heard"
    /// The day the stray first turned up. Every stage of her arc is counted
    /// back out of the session log from here, so this one date is the whole of
    /// her progress.
    static let strayFirstSeen = "pawmodoro.strayFirstSeen"
    /// The day she came inside. Can't be derived from her name: accepting the
    /// default name stores no override at all.
    static let strayJoined = "pawmodoro.strayJoined"
    /// The sill, the day's appetite, and which buddy has tried which snack.
    static let pantry = "pawmodoro.pantry"
    /// Lifetime high fives landed at the bell. An int, never displayed.
    static let fives = "pawmodoro.fives"
    /// The night the blanket went on, and whether its morning has been said.
    static let tuckIn = "pawmodoro.tuckIn"
    /// The last open, the last greeted day, and which rare hellos have shown.
    static let doorstep = "pawmodoro.doorstep"
    /// Everything ever carried home, with its provenance.
    static let drawer = "pawmodoro.drawer"
    /// Each buddy's trick tiers and unslept practice days.
    static let repertoire = "pawmodoro.repertoire"
    /// Which anniversaries the buddy has already brought up.
    static let anniversaries = "pawmodoro.anniversaries"
    /// Every session ever, monotonic — the log itself trims at a thousand.
    static let lifetimeSessions = "pawmodoro.lifetimeSessions"
    /// The day the very first session finished. Survives the trim too.
    static let firstSession = "pawmodoro.firstSession"
    /// Species known only by their night visits to the sill.
    static let nightKnown = "pawmodoro.nightKnown"
    /// The fortune slips drawn so far, newest last.
    static let fortunes = "pawmodoro.fortunes"
    /// Who is away on a little journey, and every letter that came home.
    static let travels = "pawmodoro.travels"
    /// The window-box: pockets, the seed on offer, the day's berry yield.
    static let garden = "pawmodoro.garden"
    /// Timetabled place events personally witnessed, with learned dates.
    static let timetable = "pawmodoro.timetable"
    /// The photographs: parameter records, and the day of the last shot.
    static let photos = "pawmodoro.photos"
    /// Tracks played by weekend request, with their stamp dates.
    static let setlist = "pawmodoro.setlist"
    /// Species once seen in the pale coat.
    static let paleCoats = "pawmodoro.paleCoats"
    /// Two features ended up sharing this key's name after the merge, and
    /// they share the key itself: the append-only event log lives here as a
    /// bare JSON array (the seeding flags decode exactly that shape), while
    /// the almanac's season letters and year card live at
    /// `chronicleAlmanac` beside it. See `Chronicle`, which holds both.
    static let chronicle = "pawmodoro.chronicle"
    /// The season letters and the year card, kept beside the event log rather
    /// than inside it. Two features share the name `Chronicle` after the
    /// merge; the event log must keep `chronicle` as a bare JSON array
    /// because the seeding flags decode that exact shape from that exact key,
    /// so the almanac half got its own sibling key.
    static let chronicleAlmanac = "pawmodoro.chronicle.almanac"
    /// The finished haiku, and which have been quoted back.
    static let anthology = "pawmodoro.anthology"


    /// The longest open hour, in seconds. A quiet almanac line and nothing
    /// else — see `SessionLog.longestDrift`.
    static let longestDrift = "pawmodoro.longestDrift"

    /// Catalogue ids traded for. The only thing the economy stores — the
    /// balance is derived from the session log, see `Acorns`.
    static let owned = "pawmodoro.owned"

    /// Things the buddy has left on the desk, in the order they arrived.
    static let keepsakes = "pawmodoro.keepsakes"

    /// The scrapbook's metadata. The photographs themselves are files in
    /// Documents/Snapshots — `Scrapbook.prune()` keeps the two in step.
    static let snapshots = "pawmodoro.snapshots"

    /// The last day the buddy said hello. One date, and the only thing the
    /// greeting stores — see `GreetingLog`.
    static let greeted = "pawmodoro.greeted"

    /// Which hours of the clock you have been sitting for when they struck.
    ///
    /// Its own key rather than being read back out of the `Chronicle`,
    /// because the chronicle is capped and drops its oldest events: a dial
    /// derived from it would quietly go dark again after a few years, and
    /// nothing in this app is allowed to decay.
    static let clockRing = "pawmodoro.clockRing"

    static let all = [
        settings, sessions, hasOnboarded, hasPlus, tipsGiven, journal, postcards,
        strayFirstSeen, strayJoined, dreams, heard, pantry, fives, tuckIn,
        doorstep, drawer, repertoire, anniversaries, lifetimeSessions, firstSession,
        nightKnown, fortunes, travels, garden, timetable, photos, setlist,
        paleCoats, chronicle, anthology, longestDrift, owned, keepsakes,
        snapshots, greeted, clockRing, chronicleAlmanac,
    ]
}

/// Command-line switches that make Pawmodoro practical to drive in a simulator.
///
/// A Pomodoro app is otherwise slow to check by hand: the first focus phase runs
/// for 25 minutes, onboarding stands in front of the timer, a notification alert
/// interrupts the first start, and the Plus content needs a purchase. These
/// flags collapse all of it, so a change can be seen in seconds.
///
///     xcrun simctl launch booted com.pawmodoro.zhangcheng -PawmodoroDemo
///
/// They are compiled out of Release builds: outside `DEBUG` every flag is a
/// `false` constant, so the branches reading them fold away and nothing about
/// this file reaches the App Store build. See `docs/SIMULATOR.md`.
enum LaunchOptions {

#if DEBUG
    private static let arguments = Set(ProcessInfo.processInfo.arguments)

    private static func isSet(_ name: String) -> Bool { arguments.contains(name) }

    /// The token after a flag, read from the argument list itself.
    ///
    /// `UserDefaults`' automatic `-key value` parsing pairs tokens blindly, so
    /// a valueless flag followed by a valued one — `-PawmodoroFillJournal
    /// -PawmodoroDream memory` — consumes `-PawmodoroDream` as FillJournal's
    /// "value" and the dream flag silently vanishes. Every valued flag reads
    /// through this instead, which makes the whole debug surface immune to
    /// argument order. Found the hard way, mid-verification.
    private static func value(after name: String) -> String? {
        let all = ProcessInfo.processInfo.arguments
        guard let index = all.firstIndex(of: name), index + 1 < all.count else {
            return nil
        }
        let next = all[index + 1]
        return next.hasPrefix("-") ? nil : next
    }

    /// The three flags you almost always want together.
    private static let demo = isSet("-PawmodoroDemo")

    /// Durations count in seconds instead of minutes: a 25-minute focus phase
    /// finishes in 25 seconds, so a whole cycle fits inside one check.
    static let fastTimers = demo || isSet("-PawmodoroFastTimers")

    /// Land straight on the timer instead of the first-launch pages.
    static let skipOnboarding = demo || isSet("-PawmodoroSkipOnboarding")

    /// Don't ask for notification permission — the system alert covers the app.
    static let suppressNotificationPrompt = demo || isSet("-PawmodoroSuppressNotificationPrompt")

    /// Pretend Pawmodoro Plus is owned, so locked content can be checked without
    /// StoreKit. Deliberately not part of `-PawmodoroDemo`: the locked state is
    /// what most people need to look at.
    static let unlockPlus = isSet("-PawmodoroUnlockPlus")

    /// Fill the session history so the stats screen has something to draw.
    static let seedStats = isSet("-PawmodoroSeedStats")

    /// Start from a clean install without deleting the app.
    static let resetState = isSet("-PawmodoroResetState")

    /// Fire a synthetic phase completion shortly after launch, so the
    /// celebration can be iterated on without finishing a session first.
    static let celebrate = isSet("-PawmodoroCelebrate")

    /// Pin the sky to one time of day. Takes an hour, in the `-Key value` form
    /// `UserDefaults` parses for free:
    ///
    ///     xcrun simctl launch booted com.pawmodoro.zhangcheng -PawmodoroClock 22
    ///
    /// Checking all four skies otherwise means waiting for the day to go round.
    static let forcedDayPart: DayPart? = {
        guard arguments.contains("-PawmodoroClock") else { return nil }
        let hour = value(after: "-PawmodoroClock").flatMap(Int.init) ?? 12
        return DayPart.from(hour: hour)
    }()

    /// The pinned hour itself, for the things that keep minutes rather than
    /// day-parts — the timetabled place events read this.
    static let forcedClockHour: Int? = {
        guard arguments.contains("-PawmodoroClock") else { return nil }
        return value(after: "-PawmodoroClock").flatMap(Int.init) ?? 12
    }()

    /// Start at a particular place, e.g. `-PawmodoroPlace cloudspire`. Reaching
    /// the far ones honestly takes a hundred and twenty sessions.
    static let forcedPlace: Place? = {
        guard arguments.contains("-PawmodoroPlace"),
              let raw = value(after: "-PawmodoroPlace")
        else { return nil }
        return Place(rawValue: raw)
    }()

    /// Treat every place as reached, without seeding a session history.
    static let unlockPlaces = isSet("-PawmodoroUnlockPlaces")

    /// Start with a particular buddy, e.g. `-PawmodoroBuddy owl`. Nine buddies
    /// with quirks that depend on the hour and the place is a lot of states to
    /// reach by tapping.
    static let forcedBuddy: Buddy? = {
        guard arguments.contains("-PawmodoroBuddy"),
              let raw = value(after: "-PawmodoroBuddy")
        else { return nil }
        return Buddy(rawValue: raw)
    }()

    /// Guarantee a particular sighting this session, e.g.
    /// `-PawmodoroSighting whale`. Waiting for a one-in-twelve roll is not a
    /// way to check an animation.
    static let forcedSighting: Species? = {
        guard arguments.contains("-PawmodoroSighting"),
              let raw = value(after: "-PawmodoroSighting")
        else { return nil }
        return Species(rawValue: raw)
    }()

    /// Guarantee a micro-encounter this session, e.g.
    /// `-PawmodoroEncounter butterfly`. One-in-twelve odds are not a way to
    /// check a landing.
    static let forcedEncounter: MicroEncounter? = {
        guard arguments.contains("-PawmodoroEncounter"),
              let raw = value(after: "-PawmodoroEncounter")
        else { return nil }
        return MicroEncounter(rawValue: raw)
    }()

    /// Mark every species as already seen, for looking at the journal.
    static let fillJournal = isSet("-PawmodoroFillJournal")

    /// `-PawmodoroFillJournal 5` writes that many sightings per species —
    /// five is enough to make every one a named regular, which no other flag
    /// could reach.
    static let fillJournalCount: Int = {
        guard fillJournal else { return 1 }
        return value(after: "-PawmodoroFillJournal").flatMap(Int.init) ?? 1
    }()

    /// Start in a theme, e.g. `-PawmodoroTheme ink`. Eight themes times two
    /// appearances is sixteen looks to check.
    static let forcedTheme: AppTheme? = {
        guard arguments.contains("-PawmodoroTheme"),
              let raw = value(after: "-PawmodoroTheme")
        else { return nil }
        return AppTheme(rawValue: raw)
    }()

    /// Pin the moon: `-PawmodoroMoon full` or `-PawmodoroMoon new`. Waiting a
    /// fortnight for the moon rabbit is not a way to check a sprite.
    static let forcedMoon: Bool? = {
        guard arguments.contains("-PawmodoroMoon"),
              let raw = value(after: "-PawmodoroMoon")
        else { return nil }
        return raw.lowercased() == "full"
    }()

    /// Send a postcard on launch, to look at one without earning it.
    static let postcard = isSet("-PawmodoroPostcard")

    /// Every mixtape available, without Plus and without travelling.
    static let unlockMusic = isSet("-PawmodoroUnlockMusic")

    /// Start with a track selected, e.g. `-PawmodoroTrack kettle_song`.
    static let forcedTrack: String? = {
        guard arguments.contains("-PawmodoroTrack") else { return nil }
        return value(after: "-PawmodoroTrack")
    }()

    /// Seed the log to a given length, e.g. `-PawmodoroBond 150`. Previews
    /// every bond level — and, incidentally, every journey unlock and every
    /// homestead resident — without grinding three hundred sessions.
    ///
    /// The residents deliberately get no flag of their own: they are read off
    /// `log.totalSessions`, which this already sets, and a second way to seed
    /// the same number is a second thing to keep in step. `-PawmodoroBond 200`
    /// is a full homestead.
    static let bondSessions: Int? = {
        guard arguments.contains("-PawmodoroBond") else { return nil }
        let count = value(after: "-PawmodoroBond").flatMap(Int.init) ?? 0
        return count > 0 ? count : nil
    }()

    /// Force a time of year, e.g. `-PawmodoroSeason autumn`. Most of the year
    /// there is no season at all, and the ones there are last a fortnight.
    static let forcedSeason: Season? = {
        guard arguments.contains("-PawmodoroSeason"),
              let raw = value(after: "-PawmodoroSeason")
        else { return nil }
        return Season(rawValue: raw)
    }()

    /// Pin the world's calendar day: `-PawmodoroDate 2026-12-21`.
    ///
    /// Everything date-driven reads `WorldCalendar`, so this one flag moves
    /// the season, the moon, and — as they arrive — the weather, the tide,
    /// the migrations and the snail, all at once and in agreement. The clock
    /// keeps running inside the pinned day; `-PawmodoroClock` still owns the
    /// hour.
    static let pinnedDay: Date? = {
        guard arguments.contains("-PawmodoroDate"),
              let raw = value(after: "-PawmodoroDate")
        else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw).map { Calendar.current.startOfDay(for: $0) }
    }()

    /// Pin today's weather at every place, e.g. `-PawmodoroWeather storm`.
    ///
    /// A storm is one day in thirty at one place, and golden only ever follows
    /// one, so waiting for either is not a way to check a veil.
    /// `-PawmodoroDate` reaches the same states honestly when you want to see
    /// the roll itself working rather than one sky.
    static let forcedWeather: Weather? = {
        guard arguments.contains("-PawmodoroWeather"),
              let raw = value(after: "-PawmodoroWeather")
        else { return nil }
        return Weather(rawValue: raw)
    }()

    /// Put the old snail at a point of her crossing, `-PawmodoroSnail 0` to
    /// `100`, as a percentage. `-PawmodoroSnail -1` sends her away.
    ///
    /// The plan asked for this to be an alias into `-PawmodoroDate`, and it
    /// isn't, for a concrete reason: her phase offset is *per place*, derived
    /// from `WorldCalendar.seed`, so the date that puts her mid-crossing at
    /// the meadow puts her somewhere else entirely at the woods — and the
    /// place isn't known here, before the engine exists. This overrides the
    /// derived value instead, exactly as `-PawmodoroWeather` does.
    /// `-PawmodoroDate` still moves her honestly, along with everything else.
    ///
    /// Without it, checking the far end of her crossing means waiting about
    /// six months.
    static let forcedSnail: Double? = {
        guard arguments.contains("-PawmodoroSnail"),
              let raw = value(after: "-PawmodoroSnail"),
              let percent = Double(raw)
        else { return nil }
        return percent < 0 ? -1 : min(100, percent) / 100
    }()

    /// Force the day's greeting, at a chosen warmth:
    /// `-PawmodoroGreet gladder`. Without a value, whatever the real gap
    /// earns.
    ///
    /// The warmest greeting needs a week away, and the app cannot be left
    /// alone for a week during a verification pass. Forcing it also bypasses
    /// `GreetingLog`, so it can be watched twice in a row.
    static let forcedGreeting: Greeting.Warmth? = {
        guard arguments.contains("-PawmodoroGreet") else { return nil }
        guard let raw = value(after: "-PawmodoroGreet") else { return .daily }
        return Greeting.Warmth(rawValue: raw) ?? .daily
    }()

    static let forceGreeting = isSet("-PawmodoroGreet")

    /// Put the hundred-hour panoramic postcard in the album on launch.
    ///
    /// Its own flag rather than a side effect of `-PawmodoroBond 200`, because
    /// the card is minted on a session *crossing* a hundred hours and seeding
    /// history retroactively never crosses anything. Four months of daily
    /// sitting is the only other way to see it.
    static let panorama = isSet("-PawmodoroPanorama")

    /// Pin the water at Harbor Isle: `-PawmodoroTide low`, `high`,
    /// `springlow`, `mid`, or a bare number from 0 to 1.
    ///
    /// The tide turns every six hours and a spring low is a couple of hours
    /// twice a day for a few days a fortnight, so waiting for one is not a way
    /// to check the shore strip. Each named stage lands in the middle of its
    /// own band rather than on its edge — pinning to a boundary is how you get
    /// a screenshot that disagrees with the almanac line beside it.
    static let forcedTide: Double? = {
        guard arguments.contains("-PawmodoroTide"),
              let raw = value(after: "-PawmodoroTide")
        else { return nil }
        switch raw.lowercased() {
        case "springlow": return 0.04
        case "low": return 0.18
        case "mid": return 0.50
        case "high": return 0.86
        default: return Double(raw).map { min(1, max(0, $0)) }
        }
    }()

    /// Hold one migration window open, e.g. `-PawmodoroPassage swans`.
    ///
    /// The only practical way to see the Flyway. A window is a fortnight
    /// whose dates move every year, so `-PawmodoroDate` can reach one but
    /// only after computing where it landed — and the comet's is four years
    /// wide. This forces the named passage open and, deliberately, **holds
    /// every other one shut**: seeing that the swans and the snow geese
    /// cannot both be over the meadow in February is half of what there is to
    /// check.
    static let forcedPassage: Passage? = {
        guard arguments.contains("-PawmodoroPassage"),
              let raw = value(after: "-PawmodoroPassage")
        else { return nil }
        return Passage(rawValue: raw)
    }()

    /// Cast off an open hour on launch, instead of an idle countdown.
    static let drift = isSet("-PawmodoroDrift")

    /// Start a drift already n laps deep, e.g. `-PawmodoroLaps 5`.
    ///
    /// Backdates the cast-off rather than fast-forwarding anything, because
    /// the whole feature is a function of one `Date` — so this reaches the
    /// same state the honest route reaches, and every derived number agrees.
    /// The honest route to five laps is two hours.
    static let driftLaps: Int? = {
        guard arguments.contains("-PawmodoroLaps") else { return nil }
        let laps = value(after: "-PawmodoroLaps").flatMap(Int.init) ?? 0
        return laps > 0 ? laps : nil
    }()

    /// Start on a clock face, e.g. `-PawmodoroClockFace incense`. Two of the
    /// eight are earned by reaching places that take a hundred sessions.
    static let forcedClockFace: ClockFace? = {
        guard arguments.contains("-PawmodoroClockFace"),
              let raw = value(after: "-PawmodoroClockFace")
        else { return nil }
        return ClockFace(rawValue: raw)
    }()

    /// Override the derived acorn total, e.g. `-PawmodoroAcorns 800`.
    ///
    /// The pouch is normally a pure function of the session log, so the honest
    /// way to fill it is `-PawmodoroBond 200`. This exists for the other
    /// direction: driving the *cannot afford it* half of the unlock sheet,
    /// which a seeded history makes hard to reach.
    static let forcedAcorns: Int? = {
        guard arguments.contains("-PawmodoroAcorns") else { return nil }
        return value(after: "-PawmodoroAcorns").flatMap(Int.init)
    }()

    /// Own the entire catalogue without Plus and without earning it, for
    /// driving every owned state at once.
    static let ownEverything = arguments.contains("-PawmodoroOwnEverything")

    /// Open the Magpie's Cart on launch.
    static let openCart = arguments.contains("-PawmodoroCart")

    /// Dress the current buddy on launch, e.g. `-PawmodoroWear sunhat,bow`.
    ///
    /// A list rather than one, because the interesting question is always how
    /// two pieces sit together — a hat and a collar at once is the composite
    /// that catches an anchor being wrong.
    /// Grant and show a den on launch, e.g. `-PawmodoroDen igloo`.
    ///
    /// Grants the *buddy's own* den rather than an arbitrary one — a den
    /// belongs to a species — so this also switches the buddy to its owner.
    /// Seed the keepsake shelf, e.g. `-PawmodoroKeepsakes 4`.
    ///
    /// The honest way to get one is a one-in-twenty-five roll after a session,
    /// which is not a thing anybody can drive a simulator through.
    /// Put three sample photographs in the scrapbook on launch.
    ///
    /// The simulator has no camera and its photo library is three stock
    /// wallpapers, so without this the whole feature is unreachable in a pane.
    /// The samples are generated at launch rather than bundled: three
    /// flat-coloured rectangles are enough to judge a filter by, and shipping
    /// real photographs inside the app would be shipping somebody's data.
    static let seedScrapbook = arguments.contains("-PawmodoroSeedScrapbook")

    static let seedKeepsakes: Int? = {
        guard arguments.contains("-PawmodoroKeepsakes") else { return nil }
        return value(after: "-PawmodoroKeepsakes").flatMap(Int.init)
    }()

    static let forcedDen: Den? = {
        guard arguments.contains("-PawmodoroDen"),
              let raw = value(after: "-PawmodoroDen")
        else { return nil }
        return Den(rawValue: raw)
    }()

    static let forcedWear: [Accessory] = {
        guard arguments.contains("-PawmodoroWear"),
              let raw = value(after: "-PawmodoroWear")
        else { return [] }
        return raw.split(separator: ",").compactMap {
            Accessory(rawValue: String($0).trimmingCharacters(in: .whitespaces))
        }
    }()

    /// Six weeks of plausible world events, for building anything that reads
    /// the chronicle before the chronicle has had six weeks to fill up.
    static let seedChronicle = isSet("-PawmodoroSeedChronicle")

    /// Treat every found loop as already recorded, so the Second Shelf can be
    /// heard without waiting for a storm.
    static let unlockSounds = isSet("-PawmodoroUnlockSounds")

    /// Earn all three found mixtapes, rather than unlocking them.
    ///
    /// Deliberately different from `-PawmodoroUnlockMusic`, which lies to
    /// `isUnlocked` and leaves the world untouched. This writes the world the
    /// honest way — five rainy sessions in the chronicle, ten after-dark
    /// sessions in the log, a joined stray — so everything downstream of a
    /// find is exercised too: the arrival rows, the Sunday Post's sentence,
    /// the year ring's rim, and radio actually reaching for the new tracks.
    /// The unlock flag reaches none of that.
    static let findTapes = isSet("-PawmodoroFindTapes")

    /// Pin which of the rain family's three renderings plays.
    static let forcedVariant: Int? = {
        guard arguments.contains("-PawmodoroVariant") else { return nil }
        return value(after: "-PawmodoroVariant").flatMap(Int.init).map { max(0, min(2, $0)) }
    }()

    /// Seed a history with a one-day hole in it, so both streak states can be
    /// looked at without waiting for a bad week.
    static let seedGap = isSet("-PawmodoroSeedGap")

    /// Ring the hour bell five seconds after launch, once a phase is running.
    ///
    /// The honest way to hear one is to be mid-session at the top of an hour,
    /// which is up to fifty-nine minutes of waiting for a three-second sound.
    /// Deliberately ignores the Settings toggle, so the flag always makes a
    /// noise and a silent run means the audio is wrong rather than the switch.
    static let bell = isSet("-PawmodoroBell")

    /// Which hour to pretend it is when `-PawmodoroBell` fires, e.g.
    /// `-PawmodoroBell 3` for the night grade and the small-hours position on
    /// the dial. Without a number it uses the hour it actually is.
    static let bellHour: Int? = {
        guard arguments.contains("-PawmodoroBell") else { return nil }
        return value(after: "-PawmodoroBell").flatMap(Int.init).map { max(0, min(23, $0)) }
    }()

    /// Fill the clock ring, so the completed dial and the bell-tower card can
    /// be looked at without living through twenty-four different hours.
    ///
    /// Takes an optional count — `-PawmodoroClockRing 23` leaves exactly one
    /// position dark, which is the state worth checking: a dial one short of
    /// closed must still say nothing about how many are missing.
    static let clockRingHours: Int? = {
        guard arguments.contains("-PawmodoroClockRing") else { return nil }
        let count = value(after: "-PawmodoroClockRing").flatMap(Int.init) ?? 24
        return max(0, min(24, count))
    }()

    /// Guarantee a sound this session, e.g. `-PawmodoroHear owlcall`. These
    /// are the rarest things in the app and depend on both a place and an
    /// hour; waiting for one is not a way to check a synth.
    static let forcedHeard: Heard? = {
        guard arguments.contains("-PawmodoroHear"),
              let raw = value(after: "-PawmodoroHear")
        else { return nil }
        return Heard(rawValue: raw)
    }()

    /// Force a dream: `-PawmodoroDream surreal.yarn` for one in particular, or
    /// a kind on its own for any of that kind — `memory`, `regular`, `travel`,
    /// `companion`, `visitor`, `sound`, `season`, `yours`, `surreal`. Waiting
    /// for a one-in-four roll to land on the kind you wanted to look at is not
    /// a way to check a bubble.
    ///
    /// A kind still has to be *reachable*: the pool is gated on having met the
    /// thing, so `-PawmodoroDream sound` finds nothing until something has
    /// been heard. Pair it with `-PawmodoroFillJournal 5`, `-PawmodoroBond`,
    /// `-PawmodoroStray` or `-PawmodoroSeason` accordingly.
    static let forcedDream: String? = {
        guard arguments.contains("-PawmodoroDream") else { return nil }
        return value(after: "-PawmodoroDream")
    }()

    /// Mark every dream as already dreamed, for looking at the diary.
    ///
    /// The page draws on five gated systems now, and the honest route to a
    /// full one is a hundred and fifty sessions, five sightings of forty
    /// species, all five seasons of a year and a cat who takes twelve days to
    /// come in. `-PawmodoroFillJournal` does not reach it — that fills the
    /// journal, and a dream still has to be rolled and stayed for.
    static let fillDreams = isSet("-PawmodoroFillDreams")

    /// Seed the log with n sessions finished after dark, e.g.
    /// `-PawmodoroNightSessions 12`. The atlas is 45 nights of content and the
    /// wandering stars run to 145; neither is reachable by hand.
    static let nightSessions: Int? = {
        guard arguments.contains("-PawmodoroNightSessions") else { return nil }
        let count = value(after: "-PawmodoroNightSessions").flatMap(Int.init) ?? 0
        return count > 0 ? count : nil
    }()

    /// Put the stray at a stage of her trust arc, `-PawmodoroStray 1` to `5`.
    /// The honest way to reach stage 5 is to focus on twelve separate days,
    /// which is not a way to check a sprite.
    static let forcedStrayStage: Int? = {
        guard arguments.contains("-PawmodoroStray") else { return nil }
        let stage = value(after: "-PawmodoroStray").flatMap(Int.init) ?? 0
        return (1...5).contains(stage) ? stage : nil
    }()

    /// Stock the sill without finishing a session, e.g. `-PawmodoroSnack
    /// sardine`. Each reaction tier is a different pairing away.
    static let forcedSnack: String? = {
        guard arguments.contains("-PawmodoroSnack") else { return nil }
        return value(after: "-PawmodoroSnack")
    }()

    /// Mark every snack as tried by every buddy, for looking at a full
    /// Tastes card.
    static let fillTastes = isSet("-PawmodoroFillTastes")

    /// Seed the lifetime high-five count, e.g. `-PawmodoroFives 5` to see the
    /// pre-empted paw without landing five real ones.
    static let fiveCount: Int? = {
        guard arguments.contains("-PawmodoroFives") else { return nil }
        let count = value(after: "-PawmodoroFives").flatMap(Int.init) ?? 0
        return count > 0 ? count : nil
    }()

    /// Pretend the blanket went on last night: today carries the blessing
    /// and the morning line, without waiting out a real night.
    static let tuckedYesterday = isSet("-PawmodoroTucked")

    /// Force a greeting vignette, e.g. `-PawmodoroHello mothLands`. The rare
    /// two are one-in-sixteen mornings otherwise.
    static let forcedHello: String? = {
        guard arguments.contains("-PawmodoroHello") else { return nil }
        return value(after: "-PawmodoroHello")
    }()

    /// Put a find at the buddy's feet, e.g. `-PawmodoroFind seaglass` —
    /// the honest trigger is six hours away, which is not a way to check art.
    static let forcedFind: String? = {
        guard arguments.contains("-PawmodoroFind") else { return nil }
        return value(after: "-PawmodoroFind")
    }()

    /// Stick a burr on the buddy, e.g. `-PawmodoroBurr salt`.
    static let forcedBurr: String? = {
        guard arguments.contains("-PawmodoroBurr") else { return nil }
        return value(after: "-PawmodoroBurr")
    }()

    /// One of every trinket in the drawer, for looking at the grid.
    static let fillDrawer = isSet("-PawmodoroFillDrawer")

    /// Pin a trick at a tier and play it shortly after launch, e.g.
    /// `-PawmodoroTrick spin.2`. Drawing a clean circle through the
    /// simulator pane's input latency is not a way to check an animation.
    static let forcedTrick: String? = {
        guard arguments.contains("-PawmodoroTrick") else { return nil }
        return value(after: "-PawmodoroTrick")
    }()

    /// Surface a memory dated n days back, e.g. `-PawmodoroRemember 21` —
    /// arranging a real three-week anniversary takes three weeks.
    static let rememberDaysAgo: Int? = {
        guard arguments.contains("-PawmodoroRemember") else { return nil }
        let days = value(after: "-PawmodoroRemember").flatMap(Int.init) ?? 0
        return days > 0 ? days : nil
    }()

    /// Every break's closing pounce misses — the one-in-seven escape,
    /// on demand.
    static let pounceEscapes = isSet("-PawmodoroPounce")

    /// Force last night's sill visitor, e.g. `-PawmodoroNightCaller tanuki`.
    /// The honest trigger is a snack left out overnight.
    static let nightCaller: String? = {
        guard arguments.contains("-PawmodoroNightCaller") else { return nil }
        return value(after: "-PawmodoroNightCaller") ?? "tanuki"
    }()

    /// Draw the day's fortune at launch, pinned to template row n —
    /// `-PawmodoroFortune 1`. The honest draw is the day's first start.
    static let forcedFortune: Int? = {
        guard arguments.contains("-PawmodoroFortune") else { return nil }
        return value(after: "-PawmodoroFortune").flatMap(Int.init) ?? 0
    }()

    /// Seed a journey already due home, e.g. `-PawmodoroJourney owl.peaks`.
    /// The honest wait is six to thirty-six hidden hours.
    static let forcedJourney: String? = {
        guard arguments.contains("-PawmodoroJourney") else { return nil }
        return value(after: "-PawmodoroJourney")
    }()

    /// Everyone still out on a journey knocks at launch.
    static let returnNow = isSet("-PawmodoroReturnNow")

    /// A dream seed on offer right now, e.g. `-PawmodoroSeed callflower` —
    /// the honest source is a kept dream.
    static let forcedSeed: String? = {
        guard arguments.contains("-PawmodoroSeed") else { return nil }
        return value(after: "-PawmodoroSeed") ?? "callflower"
    }()

    /// One of each plant, already in bloom (against any seeded history).
    static let forceBloom = isSet("-PawmodoroBloom")

    /// Regrant today's photograph, however many were already taken.
    static let regrantPhoto = isSet("-PawmodoroPhoto")

    /// Today's photograph renders immediately instead of overnight.
    static let developNow = isSet("-PawmodoroDevelop")

    /// The weekend request, on any day, for a given track:
    /// `-PawmodoroSet kettle_song`.
    static let forcedSet: String? = {
        guard arguments.contains("-PawmodoroSet") else { return nil }
        return value(after: "-PawmodoroSet")
    }()

    /// Every decided sighting wears the pale coat. Pair with
    /// `-PawmodoroSighting stag` to see the moon-white stag on demand.
    static let paleCoat = isSet("-PawmodoroPale")

    /// Tonight is a falling-star night, whatever the calendar says.
    static let forceShower = isSet("-PawmodoroShower")

    /// Fire an idle vignette a few seconds after launch, e.g.
    /// `-PawmodoroVignette 3` to pin the table row.
    static let forcedVignette: Int? = {
        guard arguments.contains("-PawmodoroVignette") else { return nil }
        return value(after: "-PawmodoroVignette").flatMap(Int.init) ?? 1
    }()

    /// Compose a season's letter right now, e.g.
    /// `-PawmodoroSeasonLetter autumn` — the honest wait is a season.
    static let forcedSeasonLetter: String? = {
        guard arguments.contains("-PawmodoroSeasonLetter") else { return nil }
        return value(after: "-PawmodoroSeasonLetter") ?? "autumn"
    }()

    /// Present the anniversary sequence at launch — the honest wait
    /// is a year.
    static let forcedYearCard = isSet("-PawmodoroYearCard")

    /// Open the haiku bench at launch.
    static let openBench = isSet("-PawmodoroBench")

    /// Seed three finished poems, dated weeks back, so the anthology has
    /// pages and the quote-back is within reach.
    static let seedAnthology = isSet("-PawmodoroAnthology")

    /// Frost the pane now, any season, any hour — and skip the
    /// mid-morning melt, so there's time to wipe it.
    static let frostNow = isSet("-PawmodoroFrost")

    /// Arm the golden hour call ~10 seconds out, ignoring the window and
    /// the shot — background the app (Cmd+Shift+H) to see the banner.
    static let goldenHourSoon = isSet("-PawmodoroGoldenHour")
#else
    static let fastTimers = false
    static let skipOnboarding = false
    static let suppressNotificationPrompt = false
    static let unlockPlus = false
    static let seedStats = false
    static let resetState = false
    static let celebrate = false
    static let forcedDayPart: DayPart? = nil
    static let forcedClockHour: Int? = nil
    static let forcedPlace: Place? = nil
    static let unlockPlaces = false
    static let forcedBuddy: Buddy? = nil
    static let forcedSighting: Species? = nil
    static let forcedEncounter: MicroEncounter? = nil
    static let fillJournal = false
    static let fillJournalCount = 1
    static let postcard = false
    static let unlockMusic = false
    static let forcedMoon: Bool? = nil
    static let forcedTheme: AppTheme? = nil
    static let forcedTrack: String? = nil
    static let forcedStrayStage: Int? = nil
    static let forcedSnack: String? = nil
    static let fillTastes = false
    static let fiveCount: Int? = nil
    static let tuckedYesterday = false
    static let forcedHello: String? = nil
    static let forcedFind: String? = nil
    static let forcedBurr: String? = nil
    static let fillDrawer = false
    static let forcedTrick: String? = nil
    static let rememberDaysAgo: Int? = nil
    static let pounceEscapes = false
    static let nightCaller: String? = nil
    static let forcedFortune: Int? = nil
    static let forcedJourney: String? = nil
    static let returnNow = false
    static let forcedSeed: String? = nil
    static let forceBloom = false
    static let regrantPhoto = false
    static let developNow = false
    static let forcedSet: String? = nil
    static let paleCoat = false
    static let forceShower = false
    static let forcedVignette: Int? = nil
    static let forcedSeasonLetter: String? = nil
    static let forcedYearCard = false
    static let openBench = false
    static let seedAnthology = false
    static let frostNow = false
    static let goldenHourSoon = false
    static let nightSessions: Int? = nil
    static let forcedDream: String? = nil
    static let fillDreams = false
    static let forcedHeard: Heard? = nil
    static let seedGap = false
    static let pinnedDay: Date? = nil
    static let seedChronicle = false
    static let unlockSounds = false
    static let findTapes = false
    static let forcedVariant: Int? = nil
    static let forcedSeason: Season? = nil
    static let forcedWeather: Weather? = nil
    static let forcedSnail: Double? = nil
    static let forcedPassage: Passage? = nil
    static let forcedTide: Double? = nil
    static let panorama = false
    static let forcedGreeting: Greeting.Warmth? = nil
    static let forceGreeting = false
    static let drift = false
    static let driftLaps: Int? = nil
    static let forcedClockFace: ClockFace? = nil
    static let bondSessions: Int? = nil
    static let forcedAcorns: Int? = nil
    static let ownEverything = false
    static let openCart = false
    static let forcedWear: [Accessory] = []
    static let forcedDen: Den? = nil
    static let seedKeepsakes: Int? = nil
    static let seedScrapbook = false
    static let bell = false
    static let bellHour: Int? = nil
    static let clockRingHours: Int? = nil
#endif

    /// How many seconds one "minute" of a phase lasts.
    static var minute: TimeInterval { fastTimers ? 1 : 60 }

    /// Applies the options that change stored state.
    ///
    /// Must run before anything reads `UserDefaults`, which is why
    /// `PawmodoroApp.init()` calls it before building the engine and the store.
    /// In a Release build every option is `false` and this does nothing.
    static func applyAtLaunch(defaults: UserDefaults = .standard) {
        if resetState {
            for key in StorageKeys.all {
                defaults.removeObject(forKey: key)
            }
        }
        if skipOnboarding {
            defaults.set(true, forKey: StorageKeys.hasOnboarded)
        }
        if unlockPlus {
            defaults.set(true, forKey: StorageKeys.hasPlus)
        }
        // Any flag that replaces the session records also clears the
        // lifetime counter and first-session anchor, so `SessionLog` reseeds
        // both from the records being written — otherwise an earlier run's
        // larger seed would keep the bond pinned high.
        if seedStats || seedGap || bondSessions != nil {
            defaults.removeObject(forKey: StorageKeys.lifetimeSessions)
            defaults.removeObject(forKey: StorageKeys.firstSession)
        }
        if seedStats {
            seedSampleSessions(into: defaults)
        }
        if let nightSessions {
            seedNightSessions(nightSessions, into: defaults)
        }
        if seedGap {
            seedGappedHistory(into: defaults)
        }
        if let bondSessions {
            seedSessionCount(bondSessions, into: defaults)
        }
        if seedChronicle {
            seedChronicleEvents(into: defaults)
        }
        if let clockRingHours {
            seedClockRing(clockRingHours, into: defaults)
        }
        // Last, and after `seedChronicle` on purpose: that one *replaces* the
        // event array, so anything appended before it would vanish.
        if findTapes {
            seedFoundTapes(into: defaults)
        }
    }

    /// Earn all three found mixtapes the way the app would.
    ///
    /// Three separate writes, because the three gates ask three different
    /// parts of the world — which is the design, and a flag that faked one
    /// number would prove nothing about the other two.
    private static func seedFoundTapes(into defaults: UserDefaults) {
        let calendar = Calendar.current

        // The rainy tally: five `.tape` rows, appended to whatever is there.
        var events: [ChronicleEvent] = []
        if let data = defaults.data(forKey: StorageKeys.chronicle),
           let decoded = try? JSONDecoder().decode([ChronicleEvent].self, from: data) {
            events = decoded
        }
        for index in 0..<MusicFinding.rainSessions {
            let daysAgo = (MusicFinding.rainSessions - index) * 3
            guard let at = calendar.date(byAdding: .day, value: -daysAgo, to: Date())
            else { continue }
            events.append(ChronicleEvent(
                at: at, kind: .tape, subject: MusicFinding.rainyday.rawValue
            ))
        }
        if let data = try? JSONEncoder().encode(events.sorted(by: { $0.at < $1.at })) {
            defaults.set(data, forKey: StorageKeys.chronicle)
        }

        // The after-dark counter. Skipped when `-PawmodoroNightSessions` is
        // also on, which has already written its own and would otherwise get
        // ten more than it asked for.
        if nightSessions == nil {
            seedNightSessions(MusicFinding.nightSessions, into: defaults)
        }

        // And the cat, in the door. `strayFirstSeen` too: her stage is counted
        // back from it, and a cat who has joined but never arrived is a state
        // the app cannot otherwise be in.
        if defaults.object(forKey: StorageKeys.strayFirstSeen) == nil,
           let start = calendar.date(byAdding: .day, value: -14, to: Date()) {
            defaults.set(start, forKey: StorageKeys.strayFirstSeen)
        }
        defaults.set(Date(), forKey: StorageKeys.strayJoined)
    }

    /// Fill the first `count` hours of the dial, working outward from the
    /// ordinary working day so that a partial ring looks like somebody's
    /// actual life rather than the numbers 0 to n.
    ///
    /// Compiled out of Release with the rest of this block, and it writes the
    /// same `[String: Date]` shape `ClockRing` reads — see its `save()`.
    private static func seedClockRing(_ count: Int, into defaults: UserDefaults) {
        // Furthest from one in the afternoon last, which is `ClockRing`'s own
        // idea of strange: the small hours are the ones you fill by accident,
        // years in.
        let order = (0..<24).sorted {
            ClockRing.strangeness($0) < ClockRing.strangeness($1)
        }
        let calendar = Calendar.current
        var flat: [String: Date] = [:]
        for (index, hour) in order.prefix(count).enumerated() {
            let daysAgo = 3 + index * 4
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: Date()),
                  let at = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
            else { continue }
            flat[String(hour)] = at
        }
        guard let data = try? JSONEncoder().encode(flat) else { return }
        defaults.set(data, forKey: StorageKeys.clockRing)
    }

    /// Six weeks of world events, thinning out toward the past the way a real
    /// one would — most species are met early, then the pace slows because
    /// there is less left to meet.
    private static func seedChronicleEvents(into defaults: UserDefaults) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var events: [ChronicleEvent] = []

        func add(_ kind: ChronicleEvent.Kind, _ subject: String, daysAgo: Int, hour: Int) {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today),
                  let at = calendar.date(byAdding: .hour, value: hour, to: day)
            else { return }
            events.append(ChronicleEvent(at: at, kind: kind, subject: subject))
        }

        let species = Species.allCases.map(\.rawValue)
        for index in 0..<26 {
            // Sightings thin out: day 41 down to day 1, front-loaded.
            let daysAgo = 42 - Int(pow(Double(index), 1.35))
            guard daysAgo > 0 else { break }
            add(.sighting, species[index % species.count], daysAgo: daysAgo, hour: 9 + index % 10)
        }
        for (index, sound) in Heard.allCases.enumerated() {
            add(.heard, sound.rawValue, daysAgo: 38 - index * 7, hour: 21)
        }
        for (index, place) in Place.journey.prefix(4).enumerated() {
            add(.arrival, place.rawValue, daysAgo: 40 - index * 12, hour: 11)
        }
        for (index, level) in Bond.allCases.prefix(3).enumerated() {
            add(.bond, String(level.rawValue), daysAgo: 39 - index * 14, hour: 18)
        }
        add(.figure, ConstellationAtlas.all[0].id, daysAgo: 20, hour: 22)
        add(.stray, String(Stray.Stage.watching.rawValue), daysAgo: 16, hour: 17)
        add(.stray, String(Stray.Stage.beside.rawValue), daysAgo: 4, hour: 17)
        for (index, dream) in Dream.Surreal.allCases.prefix(4).enumerated() {
            add(.dream, "surreal.\(dream.rawValue)", daysAgo: 30 - index * 8, hour: 14)
        }

        let ordered = events.sorted { $0.at < $1.at }
        guard let data = try? JSONEncoder().encode(ordered) else { return }
        defaults.set(data, forKey: StorageKeys.chronicle)
    }

    /// Exactly `count` completed sessions, spread back over the past fortnight
    /// so the streak and the charts stay plausible. Replaces whatever was
    /// there: this flag is about a total, and appending would make it a lie.
    private static func seedSessionCount(_ count: Int, into defaults: UserDefaults) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var records: [SessionRecord] = []
        for index in 0..<count {
            let daysAgo = index % 14
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)
            else { continue }
            let minutesIn = 9 * 60 + (index / 14) * 35
            let endedAt = calendar.date(byAdding: .minute, value: minutesIn, to: day) ?? day
            records.append(SessionRecord(endedAt: endedAt, minutes: 25))
        }
        let ordered = records.sorted { $0.endedAt < $1.endedAt }
        guard let data = try? JSONEncoder().encode(ordered) else { return }
        defaults.set(data, forKey: StorageKeys.sessions)
    }

    /// Twelve days of history with exactly one day missing, four days back.
    /// The gentle streak should forgive it and say so; a second hole in the
    /// same week should end it, which is what makes this worth eyeballing.
    private static func seedGappedHistory(into defaults: UserDefaults) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var records: [SessionRecord] = []
        for daysAgo in 0..<12 where daysAgo != 4 {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)
            else { continue }
            for index in 0..<3 {
                let minutesIn = 9 * 60 + index * 50
                let endedAt = calendar.date(byAdding: .minute, value: minutesIn, to: day) ?? day
                records.append(SessionRecord(endedAt: endedAt, minutes: 25))
            }
        }
        let ordered = records.sorted { $0.endedAt < $1.endedAt }
        guard let data = try? JSONEncoder().encode(ordered) else { return }
        defaults.set(data, forKey: StorageKeys.sessions)
    }

    /// Adds `count` sessions that all finished at 10pm, on consecutive
    /// evenings going back from tonight.
    ///
    /// Appends rather than replaces, so this composes with `-PawmodoroSeedStats`
    /// instead of one of them silently winning. Note it does move the journey
    /// along — forty-five night sessions is enough to reach Sunstone Keep —
    /// which is honest: those are real completed sessions as far as the rest of
    /// the app is concerned.
    private static func seedNightSessions(_ count: Int, into defaults: UserDefaults) {
        let calendar = Calendar.current
        let tonight = calendar.startOfDay(for: Date())

        var records: [SessionRecord] = []
        if let data = defaults.data(forKey: StorageKeys.sessions),
           let existing = try? JSONDecoder().decode([SessionRecord].self, from: data) {
            records = existing
        }
        for index in 0..<count {
            guard let evening = calendar.date(
                byAdding: .hour, value: 22 - index * 24, to: tonight
            ) else { continue }
            records.append(SessionRecord(
                endedAt: evening, minutes: 25, place: "meadow", buddy: "cat"
            ))
        }

        let ordered = records.sorted { $0.endedAt < $1.endedAt }
        guard let data = try? JSONEncoder().encode(ordered) else { return }
        defaults.set(data, forKey: StorageKeys.sessions)
    }

    /// A fortnight of plausible history. The same shape every run, so a
    /// screenshot of the stats screen can be compared against an earlier one.
    private static func seedSampleSessions(into defaults: UserDefaults) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Sessions per day, index 0 being today. The gap eight days back is
        // there on purpose: it gives the streak counters something to find.
        let sessionsPerDay = [3, 5, 2, 4, 2, 6, 3, 1, 0, 4, 5, 2, 3, 4]

        // The free places, rotated by day, so the widened fields have
        // something for star stories and letters to narrate in a demo.
        let places = ["meadow", "woods", "harbor"]
        var records: [SessionRecord] = []
        for (daysAgo, count) in sessionsPerDay.enumerated() where count > 0 {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            for index in 0..<count {
                // Spread the day's sessions out from 9am, 40 minutes apart.
                let minutesIntoDay = 9 * 60 + index * 40
                let endedAt = calendar.date(byAdding: .minute, value: minutesIntoDay, to: day) ?? day
                records.append(SessionRecord(
                    endedAt: endedAt, minutes: 25,
                    place: places[daysAgo % places.count], buddy: "cat"
                ))
            }
        }

        let ordered = records.sorted { $0.endedAt < $1.endedAt }
        guard let data = try? JSONEncoder().encode(ordered) else { return }
        defaults.set(data, forKey: StorageKeys.sessions)
    }
}
