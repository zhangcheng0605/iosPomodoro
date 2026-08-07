import Foundation
import Observation

/// The haiku bench (Ghost of Tsushima).
///
/// The most-loved five minutes in a fifty-hour samurai epic was sitting
/// still and picking three lines. That is nearly a Pomodoro already. While
/// idle, the bench offers three choices for each of three lines; the pools
/// are seeded by (place, season, time of day), so the Harbor at dusk
/// offers different first lines than the Peaks at dawn — places read
/// differently on the page, which is the Tsushima trick. No prompts, no
/// streaks, no poem-a-day: the bench is furniture, not homework. Every
/// combination parses; nothing rhyme-shames.
struct Haiku: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let place: String
    let lines: [String]

    var placeName: String {
        Place(rawValue: place)?.name ?? "Somewhere"
    }
}

enum HaikuBench {

    /// Three choices for each of the three lines, stable for the calendar
    /// day. Deterministic end to end: the same bench on the same day at
    /// the same place offers the same page.
    static func choices(
        place: Place, season: Season?, part: DayPart, day: Int
    ) -> [[String]] {
        let pools = [
            firstLines(place: place, part: part),
            secondLines(part: part, season: season),
            thirdLines(season: season),
        ]
        return pools.enumerated().map { index, pool in
            pick(3, from: pool, seed: "bench.\(day).\(index).\(place.rawValue)")
        }
    }

    /// N distinct lines from a pool, by hash, without replacement.
    private static func pick(_ n: Int, from pool: [String], seed: String) -> [String] {
        var remaining = pool
        var out: [String] = []
        var salt = 0
        while out.count < n, !remaining.isEmpty {
            let index = Doorstep.stableHash("\(seed).\(salt)") % remaining.count
            out.append(remaining.remove(at: index))
            salt += 1
        }
        return out
    }

    // MARK: The pools
    //
    // Fragments, all of them — lowercase, unpunctuated at the ends — so
    // any first line can sit above any second above any third. First
    // lines set the scene, second lines move, third lines turn.

    private static func firstLines(place: Place, part: DayPart) -> [String] {
        var pool: [String]
        switch place {
        case .meadow: pool = ["long grass, holding still", "the meadow leans one way"]
        case .woods: pool = ["pines above the path", "the stream talks to itself"]
        case .harbor: pool = ["salt wind off the water", "one boat, going nowhere"]
        case .blossom: pool = ["petals on the terrace", "the waterfall's white thread"]
        case .keep: pool = ["warm stone underfoot", "teal domes against the sky"]
        case .cloudspire: pool = ["an island, mid-thought", "nothing below but sky"]
        case .peaks: pool = ["cold air on the viaduct", "the summit keeps its snow"]
        case .onsen: pool = ["steam climbs off the water", "stone worn smooth by soaking"]
        }
        switch part {
        case .dawn: pool += ["the sky rehearsing pink", "first light, unhurried"]
        case .day: pool += ["a wide and even light", "noon holds everything still"]
        case .dusk: pool += ["the lamps come on early", "dusk pulls in its chair"]
        case .night: pool += ["stars in cold order", "the moon minds its business"]
        }
        pool += ["a bench with room for two", "the kettle already on"]
        return pool
    }

    private static func secondLines(part: DayPart, season: Season?) -> [String] {
        var pool = [
            "a small paw settles in the grass",
            "something moves, and then does not",
            "one leaf takes the long way down",
            "the timer keeps its silence",
            "a tail curls like a question",
            "work waits without complaint",
            "the bench remembers everyone",
            "a bird revises its one song",
        ]
        if part == .night {
            pool.append("the dark walks its slow rounds")
        }
        switch season {
        case .sakura: pool.append("petals interrupt, politely")
        case .fireflies: pool.append("small lanterns test their wicks")
        case .autumn: pool.append("the red leaf outranks the rest")
        case .winter: pool.append("snow revises everything")
        case .lanterns: pool.append("paper light on paper wind")
        case nil: break
        }
        return pool
    }

    private static func thirdLines(season: Season?) -> [String] {
        var pool = [
            "the tea goes cold, forgiven",
            "nobody keeps score here",
            "I stay a while longer",
            "the bell can wait its turn",
            "this was the whole errand",
            "home is where the bowl is",
            "enough, and then a little more",
            "the day files itself away",
        ]
        switch season {
        case .sakura: pool.append("spring signs its name in pink")
        case .fireflies: pool.append("the dark blinks back, friendly")
        case .autumn: pool.append("autumn takes only what fell")
        case .winter: pool.append("the snow keeps the receipt")
        case .lanterns: pool.append("light carried, not spent")
        case nil: break
        }
        return pool
    }
}

/// The finished poems, kept with their date and place. Weeks later, a
/// poem's middle line can surface once — exactly once, ever — as an idle
/// caption: the buddy, quoting you back to yourself.
@Observable
final class Anthology {

    private(set) var poems: [Haiku] = []

    @ObservationIgnored private var quoted: Set<UUID> = []
    @ObservationIgnored private let defaults: UserDefaults
    private static let kept = 40

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func keep(_ haiku: Haiku) {
        poems.append(haiku)
        if poems.count > Self.kept {
            poems.removeFirst(poems.count - Self.kept)
        }
        save()
    }

    /// A middle line old enough to have been half-forgotten. Returns nil
    /// most of the time, by design — the quote is a rare event, and each
    /// poem is quoted at most once in its life.
    func quoteBack(now: Date = Date()) -> String? {
        guard let poem = poems.first(where: {
            now.timeIntervalSince($0.date) > 14 * 86_400
                && !quoted.contains($0.id)
                && $0.lines.count == 3
        }) else { return nil }
        quoted.insert(poem.id)
        save()
        return poem.lines[1]
    }

    /// `-PawmodoroAnthology` — three poems, dated weeks back, so the
    /// anthology has pages and the quote-back is within reach.
    func seedForDebug(now: Date = Date()) {
        let benches: [(Place, DayPart, Int)] = [
            (.meadow, .day, 21), (.woods, .dusk, 28), (.harbor, .dawn, 35),
        ]
        poems = benches.map { place, part, daysAgo in
            let lines = HaikuBench.choices(
                place: place, season: Season.current(), part: part, day: daysAgo
            ).compactMap(\.first)
            return Haiku(
                id: UUID(),
                date: now.addingTimeInterval(-Double(daysAgo) * 86_400),
                place: place.rawValue,
                lines: lines
            )
        }
        quoted = []
        save()
    }

    // MARK: Persistence

    private struct State: Codable {
        var poems: [Haiku]
        var quoted: Set<UUID>
    }

    private func load() {
        guard let data = defaults.data(forKey: StorageKeys.anthology),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return }
        poems = state.poems
        quoted = state.quoted
    }

    private func save() {
        let state = State(poems: poems, quoted: quoted)
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: StorageKeys.anthology)
    }
}
