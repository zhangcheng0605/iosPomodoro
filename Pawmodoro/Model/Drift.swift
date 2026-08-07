import Foundation

/// The open hour: a session with no end time and no alarm.
///
/// A countdown is a promise you made to yourself twenty-five minutes ago. This
/// is the other way round — you cast off, and you are still going until you
/// decide not to be. Nothing is scheduled, nothing is announced, and there is
/// no moment at which the app interrupts to say you are done, because it does
/// not know.
///
/// Everything here is arithmetic, deliberately: the engine owns one `Date` —
/// the moment you cast off — and every number on screen is a function of that
/// and the wall clock. The countdown derives from an absolute end `Date` for
/// the reason iOS suspends backgrounded apps; the Drift derives from an
/// absolute *start* `Date` for exactly the same reason, and neither counts
/// ticks.
enum Drift {

    /// A lap is one focus phase's worth of drifting. The ring fills once per
    /// lap and lays a tree ring down each time it does, so two hours of deep
    /// work is five rings — time made visible in the same language the
    /// Homestead's trees will use.
    static func lapSeconds(focusMinutes: Int,
                           minute: TimeInterval = LaunchOptions.minute) -> TimeInterval {
        TimeInterval(max(1, focusMinutes)) * minute
    }

    /// Whole laps completed so far.
    static func laps(elapsed: TimeInterval, lapSeconds: TimeInterval) -> Int {
        guard lapSeconds > 0 else { return 0 }
        return max(0, Int(elapsed / lapSeconds))
    }

    /// How far round the current lap the ring is, 0...1.
    ///
    /// This is what `TimerEngine.progress` returns while drifting, which is
    /// what lets the sighting engine, the dream window and the vignette all
    /// keep working untouched: they were already pure functions of `progress`,
    /// and they do not need to know the ring changed direction.
    static func lapProgress(elapsed: TimeInterval, lapSeconds: TimeInterval) -> Double {
        guard lapSeconds > 0 else { return 0 }
        return (elapsed.truncatingRemainder(dividingBy: lapSeconds)) / lapSeconds
    }

    /// What a finished drift banks.
    ///
    /// One `SessionRecord` per completed lap, so **the journey moves the same
    /// distance it would have**: two hours of drifting reaches the same place
    /// as four countdowns did, and the bond, the streak and the stray's arc
    /// all count it the same way. A drift that never finished a lap banks
    /// nothing at all — the same rule as leaving a countdown early, and the
    /// same rule the sighting and the dream already follow. You keep what you
    /// stayed for.
    ///
    /// Past that, every minute banks: the leftover part of the last, unfinished
    /// lap is added to the final record rather than thrown away, so the hours
    /// on the stats screen are the hours you actually sat. It is only the
    /// *session count* that rounds down, and it rounds down in the one
    /// direction that can never flatter anybody.
    struct Banking: Equatable {
        /// Minutes per session record, in the order they happened.
        var minutes: [Int]

        var laps: Int { minutes.count }
        var totalMinutes: Int { minutes.reduce(0, +) }
        var isEmpty: Bool { minutes.isEmpty }
    }

    static func banking(
        elapsed: TimeInterval,
        focusMinutes: Int,
        minute: TimeInterval = LaunchOptions.minute
    ) -> Banking {
        let lap = lapSeconds(focusMinutes: focusMinutes, minute: minute)
        let whole = laps(elapsed: elapsed, lapSeconds: lap)
        guard whole > 0 else { return Banking(minutes: []) }

        var minutes = Array(repeating: max(1, focusMinutes), count: whole)
        let leftover = elapsed - Double(whole) * lap
        let extra = Int(leftover / minute)
        if extra > 0 { minutes[minutes.count - 1] += extra }
        return Banking(minutes: minutes)
    }

    /// When each banked record should say it ended.
    ///
    /// Laps end when they really ended; the last one ends when you did. Real
    /// dates matter more here than anywhere else in the app — the Year Ring
    /// tints a day by the hours actually focused, and the Shelf of Hours lights
    /// a candle by the hour a session *ended* in. A four-hour drift that
    /// recorded four identical timestamps would light one candle instead of
    /// four and paint one hour of the ring instead of four.
    static func endDates(
        from start: Date,
        elapsed: TimeInterval,
        focusMinutes: Int,
        minute: TimeInterval = LaunchOptions.minute
    ) -> [Date] {
        let lap = lapSeconds(focusMinutes: focusMinutes, minute: minute)
        let whole = laps(elapsed: elapsed, lapSeconds: lap)
        guard whole > 0 else { return [] }
        var dates = (1...whole).map { start.addingTimeInterval(Double($0) * lap) }
        dates[dates.count - 1] = start.addingTimeInterval(elapsed)
        return dates
    }

    /// Long enough away that the app should ask rather than assume.
    ///
    /// The Drift has no end time, so nothing stops it: close the app on a
    /// Friday afternoon and it is still going on Monday. Six hours is past any
    /// honest sitting and well short of anything somebody might actually have
    /// done, so it is the point at which counting it silently would be a lie
    /// and refusing it silently would be a theft. It asks. That is the only
    /// question the Drift ever puts to anybody.
    static let questionAfter: TimeInterval = 6 * 60 * 60

    static func needsAsking(elapsed: TimeInterval,
                            minute: TimeInterval = LaunchOptions.minute) -> Bool {
        // Scaled by `minute` so fast timers reach the question in six seconds
        // rather than six hours, which is the only way to ever look at it.
        elapsed >= questionAfter / 60 * minute
    }

    /// How long a drift has been going, as a clock.
    ///
    /// Counts up, and grows an hours field rather than letting the minutes run
    /// past 99 — a drift is allowed to be three hours long and "187:04" is not
    /// a thing anybody reads as time.
    static func text(elapsed: TimeInterval,
                     minute: TimeInterval = LaunchOptions.minute) -> String {
        // In fast mode a "minute" is a second, so the display is scaled the
        // same way the durations are and a lap still reads as 25:00.
        let scaled = max(0, elapsed) * (60 / minute)
        let total = Int(scaled)
        let hours = total / 3600
        if hours > 0 {
            return String(format: "%d:%02d:%02d",
                          hours, (total % 3600) / 60, total % 60)
        }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
