import Foundation

/// Everything the user can configure, stored as one value so it can be
/// persisted and compared in a single step.
struct PomodoroSettings: Codable, Equatable {
    var focusMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var sessionsPerLongBreak: Int = 4
    var hapticsEnabled: Bool = true
    var autoStartNextPhase: Bool = false
    var buddy: Buddy = .cat
    var ambience: Ambience = .off
    var theme: AppTheme = .sakura
    /// The ring pulses on a slow breath during breaks, to breathe along with.
    var breatheOnBreaks: Bool = true

    init() {}

    private enum CodingKeys: String, CodingKey {
        case focusMinutes, shortBreakMinutes, longBreakMinutes, sessionsPerLongBreak
        case hapticsEnabled, autoStartNextPhase, buddy, ambience, theme
        case breatheOnBreaks
    }

    /// Decode leniently: settings saved by an earlier version of the app are
    /// missing any key added later, and the synthesized initializer would throw
    /// and silently wipe the user's preferences.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = PomodoroSettings()
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes)
            ?? fallback.focusMinutes
        shortBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .shortBreakMinutes)
            ?? fallback.shortBreakMinutes
        longBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .longBreakMinutes)
            ?? fallback.longBreakMinutes
        sessionsPerLongBreak = try container.decodeIfPresent(Int.self, forKey: .sessionsPerLongBreak)
            ?? fallback.sessionsPerLongBreak
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled)
            ?? fallback.hapticsEnabled
        autoStartNextPhase = try container.decodeIfPresent(Bool.self, forKey: .autoStartNextPhase)
            ?? fallback.autoStartNextPhase
        buddy = try container.decodeIfPresent(Buddy.self, forKey: .buddy)
            ?? fallback.buddy
        ambience = try container.decodeIfPresent(Ambience.self, forKey: .ambience)
            ?? fallback.ambience
        theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme)
            ?? fallback.theme
        breatheOnBreaks = try container.decodeIfPresent(Bool.self, forKey: .breatheOnBreaks)
            ?? fallback.breatheOnBreaks
    }

    // MARK: Per-phase durations
    //
    // The timer ring doubles as a dial when it's idle, so it needs to read and
    // write whichever phase is on screen without knowing which field that is.

    func minutes(for phase: TimerEngine.Phase) -> Int {
        switch phase {
        case .focus: focusMinutes
        case .shortBreak: shortBreakMinutes
        case .longBreak: longBreakMinutes
        }
    }

    mutating func setMinutes(_ value: Int, for phase: TimerEngine.Phase) {
        let range = Self.range(for: phase)
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        switch phase {
        case .focus: focusMinutes = clamped
        case .shortBreak: shortBreakMinutes = clamped
        case .longBreak: longBreakMinutes = clamped
        }
    }

    /// Matches the bounds `clamped()` enforces, so the dial can't produce a
    /// value that would be silently corrected on the next load.
    static func range(for phase: TimerEngine.Phase) -> ClosedRange<Int> {
        switch phase {
        case .focus: 5...90
        case .shortBreak: 1...30
        case .longBreak: 5...60
        }
    }

    /// How much one detent of the dial moves this phase.
    static func step(for phase: TimerEngine.Phase) -> Int {
        switch phase {
        case .focus, .longBreak: 5
        case .shortBreak: 1
        }
    }

    func duration(for phase: TimerEngine.Phase) -> TimeInterval {
        let minutes = switch phase {
        case .focus: focusMinutes
        case .shortBreak: shortBreakMinutes
        case .longBreak: longBreakMinutes
        }
        // `LaunchOptions.minute` is 60 in every shipping build; `-PawmodoroFastTimers`
        // drops it to 1 so a full cycle can be watched in a simulator.
        return TimeInterval(max(1, minutes)) * LaunchOptions.minute
    }

    /// Keep values inside the ranges the UI offers, in case stored data is odd.
    func clamped() -> PomodoroSettings {
        var copy = self
        copy.focusMinutes = min(max(focusMinutes, 5), 90)
        copy.shortBreakMinutes = min(max(shortBreakMinutes, 1), 30)
        copy.longBreakMinutes = min(max(longBreakMinutes, 5), 60)
        copy.sessionsPerLongBreak = min(max(sessionsPerLongBreak, 2), 8)
        return copy
    }
}

extension PomodoroSettings {
    static let storageKey = StorageKeys.settings

    static func load(from defaults: UserDefaults = .standard) -> PomodoroSettings {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(PomodoroSettings.self, from: data)
        else {
            return PomodoroSettings()
        }
        return decoded.clamped()
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
