import CoreGraphics
import Foundation

/// The forest behind the house: one tree per completed focus hour.
///
/// A hundred hours is a small wood that exists because you sat still. Nothing
/// here is bought, nothing is chosen, and — the law this whole era is built
/// on — **nothing ever dies**. A tree does not wilt, drop, brown, or need
/// anything. It grows through three stages and then it is a tree, forever. The
/// day a plant in this app can look neglected is the day the app starts
/// teaching people to open it afraid.
///
/// ### The layout is a compatibility contract
///
/// Where each tree stands is a pure function of its index, and that function
/// becomes permanent the moment anybody's forest has trees in it. Somebody
/// who has grown fifty trees must find the same fifty trees in the same fifty
/// places next year — a forest that silently rearranges itself is worse than
/// no forest, because it says the thing was never really theirs.
///
/// So `position(of:)` is written out, deterministic, and has a stored fixture
/// in `tools/check_grove.py` that fails loudly if a single tree moves. Same
/// discipline as `WorldCalendar.seed` and for the same reason.
enum Grove {

    /// Focus minutes per tree. An hour is a real amount of sitting, which is
    /// what makes a hundred of them mean something.
    static let minutesPerTree = 60

    /// How many trees a forest can hold before it stops adding them.
    ///
    /// Not a cap on anything you earn — the hours keep counting everywhere
    /// else. It is a cap on how many sprites can be on screen at once before
    /// the wood turns into a green rectangle, which helps nobody. At a hundred
    /// and twenty trees the canopy has closed anyway.
    static let capacity = 120

    /// How grown a tree is. Three steps and then it is done: there is no
    /// fourth to chase and none that can be lost.
    ///
    /// Named `Growth` rather than `Stage` because `Stray.Stage` already
    /// exists, and `check_swift.py` matches enums by their simple name — two
    /// `Stage`s merged into one case list and it started blaming this file's
    /// switches for the cat's arc. It now refuses duplicate names outright,
    /// but the better fix was the better name.
    enum Growth: Int, CaseIterable, Comparable {
        case sapling = 0
        case young = 1
        case full = 2

        static func < (lhs: Growth, rhs: Growth) -> Bool { lhs.rawValue < rhs.rawValue }

        /// Extra hours *after* the one that planted it.
        var extraHours: Int {
            switch self {
            case .sapling: 0
            case .young: 5
            case .full: 25
            }
        }

        var asset: String {
            switch self {
            case .sapling: "grove_sapling"
            case .young: "grove_young"
            case .full: "grove_full"
            }
        }

        /// Must match the aspect drawn in `tools/generate_grove.py`, or
        /// `scaledToFit` letterboxes it.
        var size: CGSize {
            switch self {
            case .sapling: CGSize(width: 10, height: 12)
            case .young: CGSize(width: 16, height: 20)
            case .full: CGSize(width: 24, height: 30)
            }
        }
    }

    /// One tree, placed.
    struct Tree: Identifiable, Equatable {
        /// Which tree it is, 0-based, in the order they were planted.
        let index: Int
        let stage: Growth
        /// Fractions of the grove's own rectangle, x across and y down.
        let x: Double
        let y: Double

        var id: Int { index }
    }

    // MARK: The layout

    /// Where tree `index` stands, as fractions of the grove rectangle.
    ///
    /// **Do not change this function.** See the note at the top of the file:
    /// it is a promise about a forest somebody already has.
    ///
    /// The maths is a golden-angle spiral flattened onto a rectangle, which is
    /// the cheapest way to get a scatter that never clumps and never lines up.
    /// Trees are laid back-to-front — early ones far and small, later ones
    /// near — so a growing wood reads as filling in toward you rather than
    /// spreading sideways.
    static func position(of index: Int) -> (x: Double, y: Double) {
        // The golden angle in turns. Successive multiples never repeat and
        // never fall into rows, which is exactly what a natural scatter is.
        let turn = (Double(index) * 0.6180339887).truncatingRemainder(dividingBy: 1)
        // Depth uses √2−1, and the choice is load-bearing rather than
        // decorative. The first version used √5−2 here, which is φ−1 squared —
        // so both axes were golden-ratio-derived, and the two sequences came
        // back into phase at Fibonacci intervals. Trees n and n+89 landed
        // 0.0097 apart: one tree drawn twice. Nobody would have seen it until
        // they had ninety hours of focus behind them, which is months.
        // `tools/check_grove.py` found it at capacity in a second, and √2−1
        // takes the closest pair in a hundred and twenty trees from 0.0097 to
        // 0.0686.
        let depth = (Double(index) * 0.4142135624).truncatingRemainder(dividingBy: 1)

        // And a jitter, which is the difference between a scatter and a
        // lattice. Two multiplied-and-wrapped sequences always form one —
        // `i * a mod 1` against `i * b mod 1` is a line in disguise — and at
        // thirty trees the wood came out in visible diagonal stripes. That
        // was found by rendering a forest and looking at it; the checker had
        // passed. It measures near-neighbour directions now, and 0.06 takes
        // the worst 15° bucket from 53 % of all near pairs down to 24 %,
        // while leaving the closest two trees 0.0153 apart.
        let jitter = 0.06
        let x = 0.06 + turn * 0.88 + (hash(index, salt: 1) - 0.5) * jitter
        let y = 0.10 + depth * 0.86 + (hash(index, salt: 7) - 0.5) * jitter
        return (min(0.97, max(0.03, x)), min(0.97, max(0.03, y)))
    }

    /// splitmix32, written out. Deterministic across processes and platforms,
    /// which Swift's `Hasher` explicitly is not — the same reason
    /// `WorldCalendar.seed` is written out, and the same consequence if it
    /// ever changes: everybody's forest rearranges itself.
    private static func hash(_ index: Int, salt: UInt32) -> Double {
        var z = UInt32(truncatingIfNeeded: index) &* 0x9E37_79B9 &+ salt
        z = (z ^ (z >> 16)) &* 0x85EB_CA6B
        z = (z ^ (z >> 13)) &* 0xC2B2_AE35
        z = z ^ (z >> 16)
        return Double(z) / Double(UInt32.max)
    }

    /// The whole forest, for a number of completed focus minutes.
    ///
    /// Every tree is planted by one hour and then grown by the hours that came
    /// after it — so the oldest tree is the biggest, and the one planted this
    /// morning is a sapling. That ordering is what makes a wood look like it
    /// grew rather than like it was placed.
    static func trees(forMinutes minutes: Int) -> [Tree] {
        let hours = max(0, minutes) / minutesPerTree
        let count = min(hours, capacity)
        guard count > 0 else { return [] }

        return (0..<count).map { index in
            let hoursSince = hours - index - 1
            let stage = Growth.allCases.last { hoursSince >= $0.extraHours } ?? .sapling
            let place = position(of: index)
            return Tree(index: index, stage: stage, x: place.x, y: place.y)
        }
        // Far trees drawn first, so nearer ones overlap them rather than being
        // hidden behind. This is the whole of the depth illusion.
        .sorted { $0.y < $1.y }
    }

    /// Hours until the next tree, or nil once the wood is full. Shown as a
    /// quiet line, never as a bar — this is a thing to notice, not to chase.
    static func minutesToNextTree(from minutes: Int) -> Int? {
        let hours = max(0, minutes) / minutesPerTree
        guard hours < capacity else { return nil }
        return minutesPerTree - (max(0, minutes) % minutesPerTree)
    }
}
