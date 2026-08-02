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

    static let all = [settings, sessions, hasOnboarded, hasPlus, tipsGiven, journal]
}

/// Command-line switches that make Pawmodoro practical to drive in a simulator.
///
/// A Pomodoro app is otherwise slow to check by hand: the first focus phase runs
/// for 25 minutes, onboarding stands in front of the timer, a notification alert
/// interrupts the first start, and the Plus content needs a purchase. These
/// flags collapse all of it, so a change can be seen in seconds.
///
///     xcrun simctl launch booted com.zhangcheng.pawmodoro -PawmodoroDemo
///
/// They are compiled out of Release builds: outside `DEBUG` every flag is a
/// `false` constant, so the branches reading them fold away and nothing about
/// this file reaches the App Store build. See `docs/SIMULATOR.md`.
enum LaunchOptions {

#if DEBUG
    private static let arguments = Set(ProcessInfo.processInfo.arguments)

    private static func isSet(_ name: String) -> Bool { arguments.contains(name) }

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
    ///     xcrun simctl launch booted com.zhangcheng.pawmodoro -PawmodoroClock 22
    ///
    /// Checking all four skies otherwise means waiting for the day to go round.
    static let forcedDayPart: DayPart? = {
        guard arguments.contains("-PawmodoroClock") else { return nil }
        let hour = UserDefaults.standard.integer(forKey: "PawmodoroClock")
        return DayPart.from(hour: hour)
    }()

    /// Start at a particular place, e.g. `-PawmodoroPlace cloudspire`. Reaching
    /// the far ones honestly takes a hundred and twenty sessions.
    static let forcedPlace: Place? = {
        guard arguments.contains("-PawmodoroPlace"),
              let raw = UserDefaults.standard.string(forKey: "PawmodoroPlace")
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
              let raw = UserDefaults.standard.string(forKey: "PawmodoroBuddy")
        else { return nil }
        return Buddy(rawValue: raw)
    }()

    /// Guarantee a particular sighting this session, e.g.
    /// `-PawmodoroSighting whale`. Waiting for a one-in-twelve roll is not a
    /// way to check an animation.
    static let forcedSighting: Species? = {
        guard arguments.contains("-PawmodoroSighting"),
              let raw = UserDefaults.standard.string(forKey: "PawmodoroSighting")
        else { return nil }
        return Species(rawValue: raw)
    }()

    /// Mark every species as already seen, for looking at the journal.
    static let fillJournal = isSet("-PawmodoroFillJournal")

    /// Pin the moon: `-PawmodoroMoon full` or `-PawmodoroMoon new`. Waiting a
    /// fortnight for the moon rabbit is not a way to check a sprite.
    static let forcedMoon: Bool? = {
        guard arguments.contains("-PawmodoroMoon"),
              let raw = UserDefaults.standard.string(forKey: "PawmodoroMoon")
        else { return nil }
        return raw.lowercased() == "full"
    }()

    /// Every mixtape available, without Plus and without travelling.
    static let unlockMusic = isSet("-PawmodoroUnlockMusic")

    /// Start with a track selected, e.g. `-PawmodoroTrack kettle_song`.
    static let forcedTrack: String? = {
        guard arguments.contains("-PawmodoroTrack") else { return nil }
        return UserDefaults.standard.string(forKey: "PawmodoroTrack")
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
    static let fillJournal = false
    static let unlockMusic = false
    static let forcedMoon: Bool? = nil
    static let forcedTrack: String? = nil
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
