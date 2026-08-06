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

    /// Everything that happened, in order. Append-only, and read by nothing
    /// yet — see `Chronicle`.
    static let chronicle = "pawmodoro.chronicle"

    static let all = [
        settings, sessions, hasOnboarded, hasPlus, tipsGiven, journal, postcards,
        strayFirstSeen, strayJoined, dreams, heard, chronicle,
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
    /// every bond level — and, incidentally, every journey unlock — without
    /// grinding three hundred sessions.
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

    /// Six weeks of plausible world events, for building anything that reads
    /// the chronicle before the chronicle has had six weeks to fill up.
    static let seedChronicle = isSet("-PawmodoroSeedChronicle")

    /// Seed a history with a one-day hole in it, so both streak states can be
    /// looked at without waiting for a bad week.
    static let seedGap = isSet("-PawmodoroSeedGap")

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
#else
    static let fastTimers = false
    static let skipOnboarding = false
    static let suppressNotificationPrompt = false
    static let unlockPlus = false
    static let seedStats = false
    static let resetState = false
    static let celebrate = false
    static let forcedDayPart: DayPart? = nil
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
    static let nightSessions: Int? = nil
    static let forcedDream: String? = nil
    static let fillDreams = false
    static let forcedHeard: Heard? = nil
    static let seedGap = false
    static let pinnedDay: Date? = nil
    static let seedChronicle = false
    static let forcedSeason: Season? = nil
    static let forcedWeather: Weather? = nil
    static let bondSessions: Int? = nil
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
            records.append(SessionRecord(endedAt: evening, minutes: 25))
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

        var records: [SessionRecord] = []
        for (daysAgo, count) in sessionsPerDay.enumerated() where count > 0 {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            for index in 0..<count {
                // Spread the day's sessions out from 9am, 40 minutes apart.
                let minutesIntoDay = 9 * 60 + index * 40
                let endedAt = calendar.date(byAdding: .minute, value: minutesIntoDay, to: day) ?? day
                records.append(SessionRecord(endedAt: endedAt, minutes: 25))
            }
        }

        let ordered = records.sorted { $0.endedAt < $1.endedAt }
        guard let data = try? JSONEncoder().encode(ordered) else { return }
        defaults.set(data, forKey: StorageKeys.sessions)
    }
}
