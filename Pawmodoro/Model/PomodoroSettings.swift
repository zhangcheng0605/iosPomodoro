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
    /// Where the journey is currently sitting.
    var place: Place = .meadow
    /// Names the user has given their buddies, keyed by species. Empty means
    /// "use the name it came with".
    var buddyNames: [String: String] = [:]
    /// What each buddy is wearing, as `"<buddy>.<slot>" -> accessory id`.
    ///
    /// Per buddy rather than one global outfit: the hat belongs to the cat,
    /// and switching to the owl and back should find her still wearing it.
    /// Keyed by strings for the same reason `buddyNames` is — retiring a
    /// buddy or an accessory can never make somebody's settings undecodable.
    var worn: [String: String] = [:]
    /// The music track id, or nil for silence. Ambience and music are separate
    /// channels; free plays one at a time, Plus layers them.
    var music: String?
    var musicVolume: Double = 0.7
    var ambienceVolume: Double = 0.8
    /// Let the app choose the track, matched to the place and the hour.
    var radioMode: Bool = false
    /// Three slow breaths before a focus session actually starts. Off by
    /// default: it is a lovely thing to opt into and an irritating thing to
    /// have imposed on you when you only wanted the timer.
    var settleInBeforeFocus: Bool = false
    /// Show the countdown on the lock screen and in the Dynamic Island. On by
    /// default — it costs nothing (the system draws it from an end date) and
    /// it is the whole point of having built it.
    var liveActivityEnabled: Bool = true

    /// Which face the timer wears. The plan asked for its own `StorageKeys`
    /// entry; it is a setting, it rides in the settings blob with every other
    /// one, and `-PawmodoroResetState` clears it through `StorageKeys.settings`
    /// exactly as it clears the theme and the buddy. A second key would have
    /// been a second thing to remember.
    var clockFace: ClockFace = .ring

    init() {}

    private enum CodingKeys: String, CodingKey {
        case focusMinutes, shortBreakMinutes, longBreakMinutes, sessionsPerLongBreak
        case hapticsEnabled, autoStartNextPhase, buddy, ambience, theme
        case breatheOnBreaks, place, buddyNames, worn
        case music, musicVolume, ambienceVolume, radioMode, settleInBeforeFocus
        case liveActivityEnabled, clockFace
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
        place = try container.decodeIfPresent(Place.self, forKey: .place)
            ?? fallback.place
        buddyNames = try container.decodeIfPresent([String: String].self, forKey: .buddyNames)
            ?? fallback.buddyNames
        worn = try container.decodeIfPresent([String: String].self, forKey: .worn)
            ?? fallback.worn
        music = try container.decodeIfPresent(String.self, forKey: .music)
        musicVolume = try container.decodeIfPresent(Double.self, forKey: .musicVolume)
            ?? fallback.musicVolume
        ambienceVolume = try container.decodeIfPresent(Double.self, forKey: .ambienceVolume)
            ?? fallback.ambienceVolume
        radioMode = try container.decodeIfPresent(Bool.self, forKey: .radioMode)
            ?? fallback.radioMode
        settleInBeforeFocus = try container.decodeIfPresent(
            Bool.self, forKey: .settleInBeforeFocus
        ) ?? fallback.settleInBeforeFocus
        liveActivityEnabled = try container.decodeIfPresent(
            Bool.self, forKey: .liveActivityEnabled
        ) ?? fallback.liveActivityEnabled
        clockFace = try container.decodeIfPresent(
            ClockFace.self, forKey: .clockFace
        ) ?? fallback.clockFace
    }

    // MARK: Naming
    //
    // Every caption in the app routes through this rather than `Buddy.name`,
    // so renaming one reaches the notifications and the tip jar too.

    /// What to call this buddy: the user's name for it, or the one it came with.
    func displayName(for buddy: Buddy) -> String {
        let custom = buddyNames[buddy.rawValue]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return custom.isEmpty ? buddy.name : custom
    }

    // MARK: The wardrobe

    private func wornKey(_ buddy: Buddy, _ slot: Accessory.Slot) -> String {
        "\(buddy.rawValue).\(slot.rawValue)"
    }

    func worn(_ slot: Accessory.Slot, on buddy: Buddy) -> Accessory? {
        worn[wornKey(buddy, slot)].flatMap(Accessory.init(rawValue:))
    }

    /// Everything this buddy has on, in slot order.
    func outfit(for buddy: Buddy) -> [Accessory] {
        Accessory.Slot.allCases.compactMap { worn($0, on: buddy) }
    }

    /// Passing nil takes the slot's piece off. Wearing a second thing in the
    /// same slot replaces the first — there is no inventory to manage and no
    /// way to end up wearing two hats.
    mutating func wear(_ accessory: Accessory?, on buddy: Buddy, in slot: Accessory.Slot) {
        let key = wornKey(buddy, slot)
        if let accessory, accessory.slot == slot {
            worn[key] = accessory.rawValue
        } else {
            worn.removeValue(forKey: key)
        }
    }

    /// Storing an empty (or unchanged) name clears the override, so the field
    /// can always be emptied to get the original name back.
    mutating func setName(_ name: String, for buddy: Buddy) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == buddy.name {
            buddyNames.removeValue(forKey: buddy.rawValue)
        } else {
            buddyNames[buddy.rawValue] = String(trimmed.prefix(20))
        }
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
        copy.musicVolume = min(max(musicVolume, 0), 1)
        copy.ambienceVolume = min(max(ambienceVolume, 0), 1)
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
