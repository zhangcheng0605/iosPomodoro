import Foundation
import Observation

/// The bell of hours: one soft strike at the top of each real hour, in the
/// voice of wherever you are sitting.
///
/// The whole feature is two ideas that stay separate on purpose.
///
/// **The strike** is an *event*, not a reward. It happens while a phase is
/// running, it is three seconds long, it is graded by the hour so that three
/// in the morning is felt rather than heard, and one toggle in Settings stops
/// it forever. Nothing is unlocked by it and nothing is lost by turning it
/// off. It is the app's version of hearing a church two streets away while
/// you work: the only thing it tells you is that time is passing somewhere
/// outside the room, which is the one piece of information a focus timer is
/// otherwise very bad at giving you.
///
/// **The ring** is the collection, and it collects *presence*: an hour fills
/// the first time you happen to be sitting when that hour strikes. Twenty-four
/// positions, across however many weeks it takes, and most people will never
/// fill it — the small hours are unfilled because they were asleep, and being
/// asleep is not a gap in anybody's practice.
///
/// Three rules the rest of this file exists to keep:
///
/// 1. **No count, anywhere.** Not "19 of 24", not "5 to go", not a percentage,
///    not a progress bar. The dark side of the dial is visible only by looking
///    at the dial. Every caption here is checked against that.
/// 2. **Nothing notifies.** There is no `UNUserNotificationCenter` call in
///    this feature and there must never be one — "the four o'clock bell is in
///    ten minutes" is exactly the machinery the app is defined against.
/// 3. **Nothing decays.** A filled hour is filled forever, which is why the
///    ring keeps its own store rather than being derived from the `Chronicle`
///    — that log is capped and drops its oldest events, so a ring read out of
///    it would quietly empty itself after a few years of use.
enum BellVoice: String, CaseIterable, Identifiable {
    /// A parish bell, a field or two away. The green places.
    case church
    /// A bell rung by the swell, on something that is moving.
    case buoy
    /// A standing bowl, struck once, still going.
    case bowl
    /// A cased movement striking the hour. The places with architecture.
    case clock

    var id: String { rawValue }

    /// What is within earshot of each place.
    ///
    /// Four voices over eight places rather than eight voices: a bell is a
    /// thing you hear at a distance, and the distance is what makes two
    /// meadows sound the same. The Keep deliberately does **not** get the
    /// church bell — `Heard.farbell` is already "one stroke from the Keep,
    /// before anyone is up", and an hourly bell in the same voice would turn
    /// the rarest findable sound in the app into wallpaper.
    static func at(_ place: Place) -> BellVoice {
        switch place {
        case .meadow, .woods, .blossom: .church
        case .harbor, .cloudspire: .buoy
        case .onsen: .bowl
        case .keep, .peaks: .clock
        }
    }

    /// The word for it in the almanac. Never a brand, never a location — the
    /// point is what it sounds like, not which asset it is.
    var name: String {
        switch self {
        case .church: "a bell, somewhere over the fields"
        case .buoy: "a bell out on the water"
        case .bowl: "a bowl, struck once"
        case .clock: "a clock, striking"
        }
    }

    /// Matches the files written by `write_bell` in tools/generate_assets.py:
    /// the day grade keeps the bare name and the other three are suffixed,
    /// exactly as the ambience loops are.
    ///
    /// Base name only — `SoundPlayer.makePlayer` appends the extension, and
    /// carrying ".wav" here is the mistake that silently muted all five of the
    /// original "things heard".
    func fileName(for part: DayPart) -> String {
        part == .day ? "bell_\(rawValue)" : "bell_\(rawValue)_\(part.rawValue)"
    }
}

/// The twenty-four hours you have been present for a strike in.
///
/// Append-only by construction: `note(hour:at:)` refuses to overwrite an hour
/// it already has, so the earliest date always wins and no path through the
/// app can take an hour back off the dial.
@Observable
final class ClockRing {
    /// Hour of the clock (0...23) to the first time you were here for it.
    private(set) var struck: [Int: Date] = [:]

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = StorageKeys.clockRing

    /// Positions on the dial. Named rather than written as 24 in four places.
    static let positions = 24

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// Records presence for one strike. Returns true only the first time an
    /// hour is filled, so the caller can tell an ordinary strike from the one
    /// that put a new light on the dial.
    @discardableResult
    func note(hour: Int, at date: Date) -> Bool {
        guard (0..<Self.positions).contains(hour), struck[hour] == nil else {
            return false
        }
        struck[hour] = date
        save()
        return true
    }

    func has(_ hour: Int) -> Bool { struck[hour] != nil }

    func firstStruck(_ hour: Int) -> Date? { struck[hour] }

    /// Whether the dial is closed. Used to mint the one postcard and for
    /// nothing else — in particular, never to render "n of 24".
    var isComplete: Bool { struck.count >= Self.positions }

    /// Whether anything at all has landed yet, which is the only thing the
    /// almanac is allowed to ask.
    var hasAny: Bool { !struck.isEmpty }

    /// The oddest hour on the dial, or nil if none is filled.
    ///
    /// "Oddest" is simply furthest from one in the afternoon, going round —
    /// which makes one in the morning the strangest hour there is and noon a
    /// perfectly ordinary one. A table of interestingness would be a second
    /// opinion to keep in step with the shelf of hours; this is arithmetic.
    var oddestStruck: Int? {
        struck.keys.max { Self.strangeness($0) < Self.strangeness($1) }
    }

    static func strangeness(_ hour: Int) -> Int {
        let apart = abs(hour - 13)
        return min(apart, positions - apart)
    }

    // There is deliberately no `clear()`. Every other store has one because
    // some surface in the app calls it; nothing would call this one, and a
    // wipe with no caller is a shrinking operation that `check_crossing.py`
    // would have to be told to forgive for a reason that isn't true.
    // `-PawmodoroResetState` empties the key directly, like every other.

    // MARK: Persistence

    /// Stored keyed by string, because `[Int: Date]` encodes to JSON as a flat
    /// alternating array and would be unreadable in a defaults dump — the same
    /// reason `PomodoroSettings.buddyNames` is keyed by string.
    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return }
        var restored: [Int: Date] = [:]
        for (key, date) in decoded {
            if let hour = Int(key), (0..<Self.positions).contains(hour) {
                restored[hour] = date
            }
        }
        struck = restored
    }

    private func save() {
        var flat: [String: Date] = [:]
        for (hour, date) in struck { flat[String(hour)] = date }
        guard let data = try? JSONEncoder().encode(flat) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

/// How the app says an hour out loud.
///
/// One place, because three surfaces need it — the dial, the weekly letter and
/// the postcard — and three spellings of "four in the morning" is three chances
/// to disagree about whether 16:00 is the afternoon or the evening.
enum HourWords {
    /// As people say it: "midnight", "four in the morning", "nine at night".
    static func spoken(_ hour: Int) -> String {
        let hour = ((hour % 24) + 24) % 24
        switch hour {
        case 0: return "midnight"
        case 12: return "noon"
        case 1..<12: return "\(number(hour)) in the morning"
        case 13..<18: return "\(number(hour - 12)) in the afternoon"
        default: return "\(number(hour - 12)) at night"
        }
    }

    /// Three characters, for a dial that has room for three characters. The
    /// same form the shelf of hours uses, for the same reason.
    static func short(_ hour: Int) -> String {
        switch hour {
        case 0: return "12a"
        case 1..<12: return "\(hour)a"
        case 12: return "12p"
        default: return "\(hour - 12)p"
        }
    }

    private static func number(_ value: Int) -> String {
        let words = ["twelve", "one", "two", "three", "four", "five", "six",
                     "seven", "eight", "nine", "ten", "eleven"]
        return words[((value % 12) + 12) % 12]
    }
}
