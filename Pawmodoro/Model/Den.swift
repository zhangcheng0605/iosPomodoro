import CoreGraphics
import Foundation

/// A house, in species character, standing in the homestead.
///
/// One per buddy, bought once, and then simply there — nothing to maintain,
/// nothing to upgrade, nothing it produces. The penguin's is an igloo, the
/// dog's is a doghouse with its name over the door, the fox has a hollow log.
/// The whole feature is *presence*: your buddy sleeps in it after dark, and on
/// a snowy day it wears a snow cap.
///
/// ### It lives in the homestead, which was built for it
///
/// Y4's residents already established everything a den needs — hand-placed art
/// in the near band, feet-anchored, drawn in front of the wood, and a checker
/// that measures overlap, the near band, the card's rounded corners and the
/// footprint. A den goes through all of it. That is why there is no new
/// placement system here and no new checker: `check_residents.py` grew a den
/// section rather than gaining a sibling.
///
/// ### Soot's is not for sale
///
/// She arrives after a fortnight of deciding, or she does not, and hers comes
/// free with her — the epilogue of the one story in this app. Putting a price
/// on it would make that story into a transaction, which is the same reason
/// `Buddy.catalogItem` refuses to sell her.
enum Den: String, CaseIterable, Identifiable, Codable {
    case basket
    case doghouse
    case igloo
    case burrow
    case cottage
    case hollowlog
    case warmstone
    case branch
    case oakhollow
    case holt
    case leafpile
    case chimney

    var id: String { rawValue }

    /// Whose it is. One per buddy, which is what makes a den a *home* rather
    /// than furniture anybody can buy.
    var buddy: Buddy {
        switch self {
        case .basket: .cat
        case .doghouse: .dog
        case .igloo: .penguin
        case .burrow: .bunny
        case .cottage: .hamster
        case .hollowlog: .fox
        case .warmstone: .capybara
        case .branch: .redpanda
        case .oakhollow: .owl
        case .holt: .otter
        case .leafpile: .hedgehog
        case .chimney: .stray
        }
    }

    static func forBuddy(_ buddy: Buddy) -> Den? {
        allCases.first { $0.buddy == buddy }
    }

    var name: String {
        switch self {
        case .basket: "The basket by the window"
        case .doghouse: "The doghouse"
        case .igloo: "The igloo"
        case .burrow: "The burrow"
        case .cottage: "The cottage"
        case .hollowlog: "The hollow log"
        case .warmstone: "The warm stone"
        case .branch: "The high branch"
        case .oakhollow: "The oak hollow"
        case .holt: "The holt"
        case .leafpile: "The leaf pile"
        case .chimney: "The chimney corner"
        }
    }

    /// The homestead's line, once it is standing. A bare noun phrase with no
    /// comma, for the same reason `Resident.settledLine` is one: these are
    /// joined into a sentence.
    var settledLine: String {
        switch self {
        case .basket: "a basket in the sun"
        case .doghouse: "the doghouse, name over the door"
        case .igloo: "an igloo, which nobody questions"
        case .burrow: "a burrow with a round green door"
        case .cottage: "a cottage with too many entrances"
        case .hollowlog: "the hollow log"
        case .warmstone: "one flat warm stone"
        case .branch: "a platform, high up"
        case .oakhollow: "the hollow in the oak"
        case .holt: "a holt under the bank"
        case .leafpile: "a leaf pile that is clearly on purpose"
        case .chimney: "the chimney corner"
        }
    }

    /// The Sunday Post's sentence, the week it is first slept in. Never about
    /// the purchase — the trade stays silent, per the letter's rule — and
    /// never a congratulation. Somebody has gone to bed somewhere new.
    var settledInLine: String {
        switch self {
        case .basket: "The basket has been approved. It took some circling."
        case .doghouse: "The doghouse is in use. The door was the sticking point."
        case .igloo: "The igloo is warmer inside than out, which is the trick of them."
        case .burrow: "The burrow goes further back than it looks."
        case .cottage: "Every entrance to the cottage has now been tried."
        case .hollowlog: "The log is exactly the right size, which is rare."
        case .warmstone: "The stone holds the day's heat until about midnight."
        case .branch: "The branch is high enough to see the whole wood from."
        case .oakhollow: "The oak hollow was already somebody's. It is hers now."
        case .holt: "The holt is under the bank, and mostly under the water."
        case .leafpile: "The leaf pile has been rearranged. It was fine before."
        case .chimney: "She has taken the chimney corner. Nobody argued."
        }
    }

    /// Where it stands in the homestead, feet-anchored, in the near band.
    ///
    /// One den is ever on screen — the current buddy's — so they can all share
    /// the same patch of yard rather than each needing a spot of their own.
    /// The spot is the one gap the residents leave: `check_residents.py`
    /// measures it against all eight of them, the near band, the card's
    /// rounded corners and the footprint ceiling, exactly as if it were a
    /// ninth resident.
    static let position: (x: Double, y: Double) = (0.28, 0.87)

    /// Must match the aspect drawn in `tools/generate_dens.py`.
    var size: CGSize {
        switch self {
        case .basket: CGSize(width: 22, height: 14)
        case .doghouse: CGSize(width: 22, height: 18)
        case .igloo: CGSize(width: 24, height: 15)
        case .burrow: CGSize(width: 22, height: 16)
        case .cottage: CGSize(width: 20, height: 18)
        case .hollowlog: CGSize(width: 24, height: 13)
        case .warmstone: CGSize(width: 22, height: 10)
        case .branch: CGSize(width: 24, height: 14)
        case .oakhollow: CGSize(width: 18, height: 20)
        case .holt: CGSize(width: 24, height: 12)
        case .leafpile: CGSize(width: 22, height: 12)
        case .chimney: CGSize(width: 20, height: 18)
        }
    }

    /// Two frames, at the homestead's own pace. The second is the den with
    /// somebody in it — a light on, a tail showing, the door shut against the
    /// cold — which is what makes it a home rather than a shed.
    var frames: [String] { ["den_\(rawValue)_0", "den_\(rawValue)_1"] }

    /// Whether it can be traded for. Everything except Soot's, which arrives
    /// with her.
    var isForSale: Bool { buddy != .stray }

    /// When somebody is actually in it.
    ///
    /// The world's clock, so `-PawmodoroClock` moves it — and inverted for a
    /// nocturnal buddy, because Luna works nights and a dark empty hollow at
    /// midnight would be exactly backwards. Same rule `BuddyView.restingPose`
    /// already uses, asked of the buddy rather than restated.
    func isOccupied(at part: DayPart, buddy: Buddy) -> Bool {
        buddy.isNocturnal ? part != .night : part == .night
    }
}
