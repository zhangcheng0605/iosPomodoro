import CoreGraphics
import Foundation

/// A constellation you build by focusing after dark.
///
/// Every completed night session sets one star. Enough stars finish a figure,
/// and a finished figure is drawn into the night sky of every place you visit,
/// permanently, with its name and its lore in the atlas. The sentence this is
/// built around is *"I built that constellation."*
///
/// **Nothing new is persisted.** `SessionRecord.endedAt` already knows what
/// hour it was, so the whole system is a pure function over the session log —
/// the same trick the journey unlocks use. There is no star count to store,
/// corrupt, migrate or reset.
struct Constellation: Identifiable, Equatable {
    /// By id. The synthesized version isn't available — `links` is an array of
    /// tuples, which Swift won't derive `==` for — and identity is the only
    /// sense in which two figures are ever "the same" anyway.
    static func == (lhs: Constellation, rhs: Constellation) -> Bool {
        lhs.id == rhs.id
    }

    let id: String
    let name: String
    /// Two lines of world-lore, shown once the figure is finished.
    let lore: String
    /// Where this figure sits in the sky and how much room it takes, as
    /// fractions of the band `ConstellationAtlas.skyTop...skyBottom`.
    let frame: CGRect
    /// Stars in the figure's own 0...1 box, so a figure can be moved or
    /// resized without retyping it.
    let stars: [CGPoint]
    /// Which stars are joined once the figure is complete, as index pairs.
    /// Nothing is joined while it is still being built — a half-drawn figure
    /// with lines already on it looks broken rather than unfinished.
    let links: [(Int, Int)]

    var starCount: Int { stars.count }

    /// A star's position in sky-band space, 0...1 on both axes.
    func position(of index: Int) -> CGPoint {
        let star = stars[index]
        return CGPoint(
            x: frame.minX + star.x * frame.width,
            y: frame.minY + star.y * frame.height
        )
    }
}

/// The seven figures, in the order they are built.
///
/// Positions are layout rather than art, so they live here in Swift instead of
/// coming out of a generator like everything else that gets drawn.
enum ConstellationAtlas {

    /// The slice of the screen the sky occupies, as fractions of its height.
    /// Stops short of the countdown ring, which begins around 0.335 — and
    /// starts *below* the toolbar. The first Mac run found The Little Paw
    /// drawn under the stats pill and the clock: 0.03 was measured against
    /// the artwork's sky, which starts at the top of the screen, not against
    /// the chrome that floats over it (status bar + toolbar reach ~0.12).
    static let skyTop = 0.125
    static let skyBottom = 0.33

    static let all: [Constellation] = [
        Constellation(
            id: "littlepaw",
            name: "The Little Paw",
            lore: "The first one anybody finds.\nThey say she was only passing through, and stayed.",
            frame: CGRect(x: 0.07, y: 0.04, width: 0.21, height: 0.26),
            stars: [
                // Four toes in an arc over a pad that sits close under them.
                // Further down and the four links read as a fan rather than a
                // paw — this is the first figure anybody finishes, so it is
                // the one that has to be recognisable.
                CGPoint(x: 0.12, y: 0.30), CGPoint(x: 0.37, y: 0.10),
                CGPoint(x: 0.65, y: 0.10), CGPoint(x: 0.90, y: 0.32),
                CGPoint(x: 0.51, y: 0.62),
            ],
            links: [(0, 4), (1, 4), (2, 4), (3, 4)]
        ),
        Constellation(
            id: "sleepingcat",
            name: "The Sleeping Cat",
            lore: "Curled since before the harbour had a name.\nNobody has ever seen her wake.",
            // Eight rather than six, so she is still going up on the twelfth
            // night — the second figure wants to be the one that teaches you
            // these take a while, and finishing two in a fortnight doesn't.
            // The outline fills first and the tail and ear land last.
            frame: CGRect(x: 0.44, y: 0.02, width: 0.27, height: 0.24),
            stars: [
                CGPoint(x: 0.08, y: 0.56), CGPoint(x: 0.20, y: 0.22),
                CGPoint(x: 0.48, y: 0.08), CGPoint(x: 0.77, y: 0.24),
                CGPoint(x: 0.92, y: 0.58), CGPoint(x: 0.50, y: 0.78),
                CGPoint(x: 0.88, y: 0.88), CGPoint(x: 0.30, y: 0.03),
            ],
            links: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 0), (5, 6), (1, 7)]
        ),
        Constellation(
            id: "ferry",
            name: "The Ferry",
            lore: "It crosses whether or not you are on it.\nThe lamp at the bow is the one that never goes out.",
            frame: CGRect(x: 0.76, y: 0.08, width: 0.20, height: 0.26),
            stars: [
                CGPoint(x: 0.08, y: 0.82), CGPoint(x: 0.50, y: 0.94),
                CGPoint(x: 0.92, y: 0.82), CGPoint(x: 0.50, y: 0.56),
                CGPoint(x: 0.50, y: 0.12), CGPoint(x: 0.84, y: 0.34),
            ],
            links: [(0, 1), (1, 2), (1, 3), (3, 4), (4, 5), (5, 3)]
        ),
        Constellation(
            id: "kettle",
            name: "The Kettle",
            lore: "Kept warm for someone still walking home.\nThe steam is the part you can't see.",
            frame: CGRect(x: 0.05, y: 0.40, width: 0.24, height: 0.28),
            stars: [
                CGPoint(x: 0.20, y: 0.74), CGPoint(x: 0.66, y: 0.74),
                CGPoint(x: 0.70, y: 0.40), CGPoint(x: 0.24, y: 0.40),
                CGPoint(x: 0.36, y: 0.10), CGPoint(x: 0.60, y: 0.10),
                CGPoint(x: 0.96, y: 0.56),
            ],
            links: [(0, 1), (1, 2), (2, 3), (3, 0), (3, 4), (4, 5), (5, 2), (2, 6)]
        ),
        Constellation(
            id: "lantern",
            name: "The Lantern",
            lore: "Hung out for travellers, not for the house.\nWhoever lit it went to bed long ago.",
            frame: CGRect(x: 0.40, y: 0.38, width: 0.17, height: 0.30),
            stars: [
                CGPoint(x: 0.22, y: 0.88), CGPoint(x: 0.78, y: 0.88),
                CGPoint(x: 0.80, y: 0.48), CGPoint(x: 0.20, y: 0.48),
                CGPoint(x: 0.50, y: 0.26), CGPoint(x: 0.50, y: 0.04),
            ],
            links: [(0, 1), (1, 2), (2, 3), (3, 0), (3, 4), (4, 2), (4, 5)]
        ),
        Constellation(
            id: "whale",
            name: "The Whale",
            lore: "The oldest thing anyone has counted.\nIt surfaces once a year and no one agrees when.",
            frame: CGRect(x: 0.66, y: 0.44, width: 0.30, height: 0.26),
            stars: [
                CGPoint(x: 0.04, y: 0.56), CGPoint(x: 0.22, y: 0.34),
                CGPoint(x: 0.48, y: 0.28), CGPoint(x: 0.72, y: 0.40),
                CGPoint(x: 0.92, y: 0.60), CGPoint(x: 0.72, y: 0.76),
                CGPoint(x: 0.38, y: 0.72), CGPoint(x: 0.30, y: 0.04),
            ],
            links: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 0), (2, 7)]
        ),
        Constellation(
            id: "longwatch",
            name: "The Long Watch",
            lore: "An owl, and the only one that never blinks.\nShe is what the night leaves on duty.",
            frame: CGRect(x: 0.20, y: 0.70, width: 0.26, height: 0.28),
            stars: [
                CGPoint(x: 0.34, y: 0.16), CGPoint(x: 0.66, y: 0.16),
                CGPoint(x: 0.16, y: 0.36), CGPoint(x: 0.84, y: 0.36),
                CGPoint(x: 0.28, y: 0.74), CGPoint(x: 0.72, y: 0.74),
                CGPoint(x: 0.50, y: 0.94),
            ],
            links: [(0, 1), (0, 2), (1, 3), (2, 4), (3, 5), (4, 6), (5, 6)]
        ),
    ]

    /// Night sessions needed before this figure's first star.
    static func firstStar(of index: Int) -> Int {
        all.prefix(index).reduce(0) { $0 + $1.starCount }
    }

    /// Every star in every figure — 45 night sessions of content.
    static var totalStars: Int { all.reduce(0) { $0 + $1.starCount } }

    /// How many of a figure's stars are lit.
    static func litStars(of index: Int, nightSessions: Int) -> Int {
        let lit = nightSessions - firstStar(of: index)
        return min(all[index].starCount, max(0, lit))
    }

    static func isComplete(_ index: Int, nightSessions: Int) -> Bool {
        litStars(of: index, nightSessions: nightSessions) == all[index].starCount
    }

    /// How many figures are finished. Also the index of the one in progress.
    static func completedCount(nightSessions: Int) -> Int {
        all.indices.filter { isComplete($0, nightSessions: nightSessions) }.count
    }

    /// The figure the next star belongs to, or nil once all seven are done.
    static func inProgress(nightSessions: Int) -> Int? {
        let index = completedCount(nightSessions: nightSessions)
        return index < all.count ? index : nil
    }

    /// Loose stars for nights beyond the seventh figure — one per five, capped,
    /// so the sky keeps acknowledging the habit long after the atlas is full
    /// without ever implying there is more to complete.
    static let wandererCap = 20

    static func wanderers(nightSessions: Int) -> Int {
        let beyond = nightSessions - totalStars
        guard beyond > 0 else { return 0 }
        return min(wandererCap, beyond / 5)
    }

    /// The figure a session just finished, if it finished one. Both counts come
    /// from the log either side of the write, so this cannot fire twice.
    static func justCompleted(before: Int, after: Int) -> Constellation? {
        let was = completedCount(nightSessions: before)
        let now = completedCount(nightSessions: after)
        guard now > was, was < all.count else { return nil }
        return all[was]
    }
}
