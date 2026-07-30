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

    init() {}

    private enum CodingKeys: String, CodingKey {
        case focusMinutes, shortBreakMinutes, longBreakMinutes, sessionsPerLongBreak
        case hapticsEnabled, autoStartNextPhase, buddy, ambience
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
    }

    func duration(for phase: TimerEngine.Phase) -> TimeInterval {
        let minutes = switch phase {
        case .focus: focusMinutes
        case .shortBreak: shortBreakMinutes
        case .longBreak: longBreakMinutes
        }
        return TimeInterval(max(1, minutes) * 60)
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
    static let storageKey = "pawmodoro.settings"

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
