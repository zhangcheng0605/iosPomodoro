import Foundation
import Observation

// MARK: - Where it is kept

extension StorageKeys {
    /// Which grade of which loop has actually been listened to.
    ///
    /// Its own key rather than being read back out of the `Chronicle`, for the
    /// reason `clockRing` gives beside it: the chronicle is capped and drops
    /// its oldest events, so a shelf of cards derived from it would quietly
    /// empty again after a few years, and nothing in this app is allowed to
    /// decay. Seventy-two short strings is a few hundred bytes; the ceiling
    /// this store can ever reach is 18 loops × 4 grades and then it stops.
    ///
    /// This lives in an extension because `LaunchOptions.swift` was not this
    /// change's to edit. It belongs in `StorageKeys` proper, beside
    /// `clockRing`, and the one-line diff that puts it into `StorageKeys.all`
    /// is in the handoff — until that lands, `-PawmodoroResetState` leaves
    /// this key behind.
    static let fieldNotes = "pawmodoro.fieldNotes"
}

// MARK: - What a loop is called once you have heard it

extension Ambience {
    /// The loop as a sentence names it: "You have heard **the forest** at
    /// dawn."
    ///
    /// Not `label`, which is a chip in a picker and has to be short — "Tent"
    /// and "Snow" are fine on a button and are not things anybody says they
    /// heard. `.off` returns empty and is never asked; the almanac and the
    /// shelf both filter it out before they get here, the same way
    /// `findingLine` is empty for every loop that isn't found.
    var heardPhrase: String {
        switch self {
        case .off: ""
        case .rain: "the rain"
        case .purr: "the purr"
        case .fireplace: "the fire"
        case .forest: "the forest"
        case .cafe: "the café"
        case .ocean: "the sea"
        case .drizzle: "the drizzle"
        case .wind: "the wind"
        case .creek: "the creek"
        case .library: "the library"
        case .snowhush: "the snow"
        case .temple: "the temple"
        case .storm: "the storm"
        case .crickets: "the crickets"
        case .cicadas: "the cicadas"
        case .nighttrain: "the night train"
        case .raintent: "rain on the tent"
        case .emberslate: "the embers"
        }
    }

    /// The line on a finished field-recording card.
    ///
    /// Each one is a note about what the *grading* does to that loop across a
    /// day — the cafe emptying to cup-clinks, the ocean's bell buoy arriving
    /// after dark, the forest thinning out by noon. That is deliberate: the
    /// card is earned by having heard all four, so its sentence is the thing
    /// you could only have learned by hearing all four. It never says how many
    /// cards there are, and there is no card for a loop you have not finished.
    var fieldNote: String {
        switch self {
        case .off: ""
        case .rain: "Four rains. Not one of them the same."
        case .purr: "Louder at night. Nobody knows why."
        case .fireplace: "It settles as the light goes."
        case .forest: "Loud at dawn, asleep by noon."
        case .cafe: "By closing, only cups are left."
        case .ocean: "The bell buoy waits for the dark."
        case .drizzle: "Barely there, at any hour of it."
        case .wind: "It gets up at dusk and stays up."
        case .creek: "The same water all day, unbothered."
        case .library: "Someone is always turning a page."
        case .snowhush: "Snow at night is the quietest of these."
        case .temple: "The bowl carries further in the cold."
        case .storm: "The thunder keeps its own hours."
        case .crickets: "They stop before anyone is up."
        case .cicadas: "The middle of the day is theirs."
        case .nighttrain: "It runs at noon too. It sounds wrong."
        case .raintent: "The canvas answers differently each time."
        case .emberslate: "Down to almost nothing by morning."
        }
    }
}

// MARK: - The store

/// Which circadian grade of which loop you have actually sat through.
///
/// The last unbuilt piece of Phase W. Every ambience ships in four grades —
/// dawn, day, dusk, night — derived from one recipe by the generator, and
/// until now nothing anywhere recorded that you had heard any of them. Two
/// surfaces read this: one quiet almanac line naming the most recent grade,
/// and a sepia **field-recording card** for a loop whose four grades are all
/// heard.
///
/// Append-only by construction, exactly like `ClockRing`: `note(_:in:)`
/// refuses to overwrite a grade it already has, so the earliest date always
/// wins and no path through the app can take a grade back off the shelf.
/// There is deliberately no `clear()` — nothing would call it, and a wipe with
/// no caller is a shrinking operation `check_crossing.py` would have to be
/// told to forgive for a reason that isn't true. `-PawmodoroResetState` empties
/// the key directly, like every other.
///
/// A singleton because it has exactly two callers that cannot hand it to each
/// other — the engine, which writes when a session ends, and the almanac,
/// which reads. Injectable all the same, so a seeded copy is one initializer
/// away.
@Observable
final class FieldNotes {

    static let shared = FieldNotes()

    /// `"forest.dawn"` to the first time you heard it.
    ///
    /// Keyed by string rather than by a pair, because that is what encodes to
    /// readable JSON in a defaults dump and what `Crossing.merge(heard:)`
    /// already knows how to fold — an id to the first date it happened is the
    /// clock ring's shape, and this is the fifth store to turn out to have it.
    private(set) var heard: [String: Date] = [:]

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = StorageKeys.fieldNotes

    /// Every loop that has a recording to make. `.off` is not a sound.
    static var loops: [Ambience] { Ambience.allCases.filter { $0 != .off } }

    /// Grades per loop, in the order a day happens in.
    static var grades: [DayPart] { [.dawn, .day, .dusk, .night] }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        #if DEBUG
        applyDebugSeed()
        #endif
    }

    static func key(_ ambience: Ambience, _ part: DayPart) -> String {
        "\(ambience.rawValue).\(part.rawValue)"
    }

    // MARK: Writing

    /// Records one grade listened through. Returns true only the first time a
    /// grade lands, so the caller can tell an ordinary session from the one
    /// that put something new on the shelf.
    @discardableResult
    func note(
        _ ambience: Ambience, in part: DayPart, at date: Date = WorldCalendar.now
    ) -> Bool {
        guard ambience != .off else { return false }
        let key = Self.key(ambience, part)
        guard heard[key] == nil else { return false }
        heard[key] = date
        save()
        return true
    }

    // MARK: Reading

    func has(_ ambience: Ambience, _ part: DayPart) -> Bool {
        heard[Self.key(ambience, part)] != nil
    }

    /// Whether all four grades of one loop are in. This is the whole gate on
    /// the card, and nothing is allowed to render it as a fraction — a shelf
    /// shows what is on it, never what is missing from it.
    func hasCard(_ ambience: Ambience) -> Bool {
        ambience != .off && Self.grades.allSatisfy { has(ambience, $0) }
    }

    /// The day a card was finished — the latest of its four grades.
    func cardFinished(_ ambience: Ambience) -> Date? {
        guard hasCard(ambience) else { return nil }
        return Self.grades.compactMap { heard[Self.key(ambience, $0)] }.max()
    }

    /// The finished cards, oldest first, so the newest one is on the end of
    /// the shelf where a new one appears.
    var cards: [Ambience] {
        Self.loops
            .compactMap { loop in cardFinished(loop).map { (loop, $0) } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    /// Whether anything at all has landed, which is the only thing the almanac
    /// is allowed to ask before it decides to say nothing.
    var hasAny: Bool { !heard.isEmpty }

    /// The most recent grade heard, as the almanac says it out loud.
    ///
    /// One sentence, in the past tense, about a thing that already happened.
    /// It never names a grade you have *not* heard, because "you have not
    /// heard the forest at night" is an errand, and the errand would be to sit
    /// still in a wood at three in the morning.
    var latestLine: String? {
        let newest = heard.max { $0.value < $1.value }
        guard let key = newest?.key else { return nil }
        let parts = key.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let ambience = Ambience(rawValue: parts[0]),
              let grade = DayPart(rawValue: parts[1]),
              ambience != .off
        else { return nil }
        return "You have heard \(ambience.heardPhrase) \(grade.hintPhrase)."
    }

    // MARK: Persistence

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return }
        heard = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(heard) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    // MARK: Debug

    #if DEBUG
    /// `-PawmodoroFieldNotes [n]` — n finished cards, plus one loose grade on
    /// the loop after them so the almanac line has something recent to say
    /// that is not already on the shelf. Default four.
    ///
    /// This belongs in `LaunchOptions` with every other flag, and the diff
    /// that moves it there is in the handoff; that file was not this change's
    /// to edit. Reading `ProcessInfo` here rather than naming a flag that does
    /// not exist yet keeps `check_swift.py`'s member check honest.
    ///
    /// Written through `note(_:in:)` so the seeded shelf goes in by the same
    /// door a real one does — a seeder with its own opinion about the storage
    /// shape is the thing that goes stale silently.
    private func applyDebugSeed() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-PawmodoroFieldNotes") else { return }
        let next = arguments.index(after: flag)
        let asked = arguments.indices.contains(next) ? Int(arguments[next]) : nil
        let count = max(0, min(asked ?? 4, Self.loops.count))

        // Backdated so the dates ascend in the order they are written: the
        // loose grade at the end is the newest, which is what the almanac
        // line reads.
        var stamp = WorldCalendar.now.addingTimeInterval(-Double(count + 1) * 86_400)
        for loop in Self.loops.prefix(count) {
            for grade in Self.grades {
                note(loop, in: grade, at: stamp)
                stamp = stamp.addingTimeInterval(3_600)
            }
            stamp = stamp.addingTimeInterval(86_400 - 4 * 3_600)
        }
        if count < Self.loops.count {
            note(Self.loops[count], in: .dusk, at: stamp)
        }
    }
    #endif
}
