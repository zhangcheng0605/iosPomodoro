import CoreGraphics
import Foundation

/// The neighbours: things that move in behind the house and then are simply
/// there.
///
/// The grove counts hours; this counts *coming back*. At quiet milestones of
/// the same session count the bond already reads, a small thing appears in the
/// homestead — a pond clears, somebody takes the birdhouse, the hedge flowers
/// — and from then on it is part of the place. Nothing is chosen, nothing is
/// bought, nothing can be lost, and none of them is ever announced by a
/// notification. The buddy notices, once, and after that it is furniture.
///
/// **They are neighbours, not sightings.** Nothing here touches the field
/// journal: a resident is not a species you met, it is something that lives
/// where you live. Putting them in the journal would turn the homestead into
/// another collection to complete, and there are enough of those.
enum Resident: String, CaseIterable, Identifiable, Codable {
    case pond
    case birdhouse
    case beehive
    case hedge
    case washline
    case lantern
    case well
    case bench

    var id: String { rawValue }

    /// Completed focus sessions before it turns up.
    ///
    /// The same counter the bond reads, deliberately: this app already knows
    /// how often you come back, and inventing a second progression to measure
    /// the same thing would be two things to keep in step. The gaps widen —
    /// 15, 30, 50, 70 — so the homestead fills quickly at first and then
    /// slowly, which is how a place you live actually fills.
    var arrivesAt: Int {
        switch self {
        case .pond: 15
        case .birdhouse: 30
        case .beehive: 50
        case .hedge: 70
        case .washline: 95
        case .lantern: 125
        case .well: 160
        case .bench: 200
        }
    }

    /// What the buddy says the once, on the session it turns up. Never a
    /// congratulation and never a total — it is somebody noticing something,
    /// which is a different sentence from somebody awarding you something.
    ///
    /// A lowercase fragment, because it is spoken as the tail of the buddy's
    /// caption ("Mochi has noticed — the hedge flowered overnight") and the
    /// name has to come from `settings.displayName(for:)` at the call site: a
    /// model type cannot reach it, and buddies can be renamed.
    var arrivalLine: String {
        switch self {
        case .pond: "the puddle out back has cleared, and something lives in it"
        case .birdhouse: "somebody has moved into the birdhouse"
        case .beehive: "there are bees now, and they were not consulted"
        case .hedge: "the hedge flowered overnight, all at once"
        case .washline: "a line went up, which means somebody stays here"
        case .lantern: "there is a lantern on the post, and it lights itself"
        case .well: "an old well, with the bucket still on the rope"
        case .bench: "a bench, facing the wood, which is correct"
        }
    }

    /// The homestead's line, once it is simply there.
    ///
    /// A bare noun phrase with no comma in it, because these are joined into a
    /// list ("There is the pond, the hive and the old well") and an internal
    /// comma turns that sentence to soup. It also has to sit inside the Sunday
    /// Post's "We have … now", so no verb either.
    var settledLine: String {
        switch self {
        case .pond: "the pond"
        case .birdhouse: "the occupied birdhouse"
        case .beehive: "the hive"
        case .hedge: "the flowering hedge"
        case .washline: "the washing line"
        case .lantern: "the lantern on its post"
        case .well: "the old well"
        case .bench: "the bench facing the wood"
        }
    }

    /// Where it stands, as fractions of the homestead rectangle. Like the
    /// trees, the stray and the snail, the fraction is the thing's **feet**.
    ///
    /// Hand-placed rather than scattered, unlike the grove: eight things is
    /// few enough to arrange on purpose, and a pond that lands somewhere
    /// different for everybody is not a pond anybody could describe to a
    /// friend. `tools/check_residents.py` asserts they never overlap each
    /// other, never leave the frame, never poke into the card's rounded
    /// corners, and never cover so much of it that the wood behind them stops
    /// being worth growing.
    ///
    /// They sit in the **near band** and are drawn in front of the whole wood,
    /// which was not the first arrangement and is not a stylistic preference.
    /// Interleaving them with the trees by depth makes a prettier picture at
    /// twenty trees and an empty one at a hundred and twenty: `check_residents`
    /// measured every resident 80–100 % buried once the canopy closed. A pond
    /// that disappears behind an oak after four months has decayed, whatever
    /// the storage says, and this app does not do that.
    ///
    /// Two rows within the band, so it is a yard rather than a shelf: the tall
    /// things — the birdhouse, the lantern — stand a little further back than
    /// the pond and the hedge. The rows are **offset by half a slot** across
    /// x, which is not decoration either: lined up, the lantern sat directly
    /// over the well and the beehive over the bench, and each pair read as one
    /// tall object rather than two neighbours. That is only visible in a
    /// composite of the finished card, which is why one gets rendered.
    var position: (x: Double, y: Double) {
        switch self {
        case .pond: (0.22, 0.97)
        case .birdhouse: (0.34, 0.86)
        case .beehive: (0.58, 0.86)
        case .hedge: (0.46, 0.97)
        case .washline: (0.09, 0.86)
        case .lantern: (0.82, 0.86)
        case .well: (0.91, 0.97)
        case .bench: (0.70, 0.97)
        }
    }

    /// Must match the aspect drawn in `tools/generate_residents.py`.
    var size: CGSize {
        switch self {
        case .pond: CGSize(width: 26, height: 12)
        case .birdhouse: CGSize(width: 14, height: 22)
        case .beehive: CGSize(width: 14, height: 16)
        case .hedge: CGSize(width: 28, height: 12)
        case .washline: CGSize(width: 24, height: 16)
        case .lantern: CGSize(width: 10, height: 20)
        case .well: CGSize(width: 18, height: 16)
        case .bench: CGSize(width: 20, height: 12)
        }
    }

    /// Two frames, swapped at 2fps. Deliberately the slowest loop in the app:
    /// a homestead that twitches is a homestead you look at instead of past.
    var frames: [String] { ["resident_\(rawValue)_0", "resident_\(rawValue)_1"] }

    /// Seconds a frame is held. Eight loops at once, so this is also the
    /// budget: a `TimelineView` at 2fps redraws the whole wood twice a second
    /// and no more, and it is only mounted while somebody actually lives here.
    static let frameSeconds: TimeInterval = 0.5

    // MARK: Who is here

    static func settled(sessions: Int) -> [Resident] {
        allCases.filter { sessions >= $0.arrivesAt }
    }

    /// The one that turned up on the session just finished, if any.
    ///
    /// Both counts come from the log either side of the write, exactly like
    /// `Bond.justReached` — so this can only ever fire on the session that
    /// actually crossed the line, and never twice.
    static func justArrived(before: Int, after: Int) -> Resident? {
        allCases.first { before < $0.arrivesAt && after >= $0.arrivesAt }
    }
}
