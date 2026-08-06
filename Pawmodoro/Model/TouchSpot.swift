import CoreGraphics
import Foundation

/// Where you touched, and what that means.
///
/// The whole of the era's brief is *"interact with the pet like it is their
/// own"*, and the insight this is built on is that ownership is not more
/// buttons — it is a creature that reacts to **where** you put your hand and
/// has an opinion about it. A tap that does the same thing everywhere is a
/// button with fur on it.
///
/// ### The fences, first
///
/// This is the part of a pet app that goes wrong, so the rules are written
/// before the feature:
///
/// - **Nothing decays.** The buddy is never hungry, dirty, sad or waiting.
///   There is no meter anywhere in this file and there must never be one.
/// - **No interaction is required, and none is counted.** Petting does not
///   feed the bond, which stays session-count and nothing else. A stroke you
///   can grind is a chore.
/// - **Focus stays sacred.** During a focus phase the buddy is asleep and
///   touching it does what it always did — a stir, no wake, no penalty. That
///   fiction is load-bearing and this era does not touch it.
/// - **Nothing is punitive.** The cat's tail-swish is *mild* displeasure and
///   the reaction to it is still affectionate. No buddy ever recoils.
enum TouchSpot: String, CaseIterable, Identifiable, Codable {
    case crown
    case nose
    case chin
    case tummy

    var id: String { rawValue }

    /// Where this spot is on a given frame, as a rect in the drawing grid's
    /// units — the same space `BuddyAnchors` and `Accessory.placement` use.
    ///
    /// Derived from the two anchors the wardrobe already measures rather than
    /// from a third table of hand-typed coordinates. That means a buddy
    /// redrawn tomorrow has correct touch regions from the next run of
    /// `generate_accessories.py`, exactly like its hat — and it means there is
    /// nothing here to fall out of step with the art.
    ///
    /// The regions deliberately overlap a little and are generous: a finger is
    /// far wider than a logical pixel, and a spot you have to hunt for is a
    /// spot nobody finds.
    /// The numbers each region is built from, in one table.
    ///
    /// Kept as data rather than written into the arithmetic below so that
    /// `tools/check_touch.py` can **parse** them instead of restating them.
    /// That distinction is not cosmetic: the first version of that checker
    /// carried its own copy of these coefficients, and every deliberate break
    /// — a nose pushed off the face, a chin shrunk to a sliver, two regions
    /// collapsed onto each other — passed cleanly, because the checker was
    /// only ever agreeing with itself. It is the trap CLAUDE.md records twice
    /// already, from `check_weather` and `check_yearring`.
    ///
    /// `x` and `width` are fractions of the reference width — the head for
    /// the two head spots, the collar run for the two body ones. `y` and
    /// `height` are fractions of `tall`, offset from whichever anchor the
    /// spot hangs off.
    var shape: (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        switch self {
        case .crown: (-0.50, -0.10, 1.00, 0.42)
        case .nose: (-0.32, 0.46, 0.64, 0.32)
        case .chin: (-0.50, -0.10, 1.00, 0.30)
        // The tummy's height is not a fraction of anything: it runs from just
        // under the collar to wherever the animal actually stops.
        case .tummy: (-0.45, 0.10, 0.90, 0)
        }
    }

    /// A pose whose head is shorter than this has no regions at all.
    ///
    /// The stretch, the otter's float and the penguin's slide are all
    /// *horizontal*: crown to collar is ten rows or fewer, and dividing that
    /// into a nose and a chin produces slivers three units tall that nobody
    /// could aim at. `BuddyFrames`' nil-fallback again — the buddy still
    /// answers a touch on those frames, just with the ordinary reaction
    /// rather than a claim about where your hand was, which on a lying-down
    /// animal would be a guess anyway.
    static let minimumHead: CGFloat = 14

    /// And a tummy with less room than this below the collar is nil rather
    /// than a padded lie hanging off the end of the animal.
    static let minimumTummy: CGFloat = 4

    /// Where this spot is on a given frame, as a rect in the drawing grid's
    /// units — the same space `BuddyAnchors` and `Accessory.placement` use.
    ///
    /// Derived from the anchors the wardrobe already measures rather than
    /// from a table of hand-typed coordinates. A buddy redrawn tomorrow has
    /// correct touch regions from the next run of `generate_accessories.py`,
    /// exactly like its hat.
    func region(on asset: String) -> CGRect? {
        guard let anchors = BuddyAnchors.anchors(for: asset) else { return nil }
        // The head's own *height*, crown to collar — not its width. Sized
        // from the width, the regions were right on a round-headed buddy and
        // wrong on every long-eared one: the dog's head is thirty-five units
        // across, so a nose a third of that reached down to the chin and the
        // two shared 85 % of their area. A spot that can never win the
        // tie-break is a spot that does not exist.
        let tall = anchors.neck.y - anchors.head.y
        guard tall >= Self.minimumHead else { return nil }

        let box = shape
        let onHead = self == .crown || self == .nose
        let anchor = onHead ? anchors.head : anchors.neck
        let reference = onHead ? anchors.headWidth : anchors.neckWidth

        let x = anchor.x + reference * box.x
        let y = anchor.y + tall * box.y
        let width = reference * box.width

        if self == .tummy {
            let height = anchors.bottom - y - 1
            guard height >= Self.minimumTummy else { return nil }
            return CGRect(x: x, y: y, width: width, height: height)
        }
        return CGRect(x: x, y: y, width: width, height: tall * box.height)
    }

    /// Which spot a point in grid units falls in, or nil for a miss.
    ///
    /// Nearest-centre rather than first-hit, so the overlaps resolve to
    /// whichever spot you were most obviously aiming at instead of to
    /// whichever happens to be declared first.
    static func at(_ point: CGPoint, on asset: String) -> TouchSpot? {
        var best: (TouchSpot, CGFloat)?
        for spot in allCases {
            guard let region = spot.region(on: asset), region.contains(point) else {
                continue
            }
            let dx = point.x - region.midX
            let dy = point.y - region.midY
            let distance = dx * dx + dy * dy
            if best == nil || distance < best!.1 { best = (spot, distance) }
        }
        return best?.0
    }
}

extension Buddy {

    /// The one place this buddy would rather be touched than anywhere else.
    ///
    /// Never hinted anywhere in the app — not in Settings, not in the almanac,
    /// not in a tooltip. Finding it is the whole feature, and a feature that
    /// tells you where to look has been turned into a checklist. It is data
    /// per the quirk rule, so adding a buddy is one arm and no branching.
    var favouriteSpot: TouchSpot {
        switch self {
        case .cat: .chin              // under the chin, obviously
        case .dog: .tummy
        case .bunny: .nose
        case .hamster: .chin
        case .fox: .crown
        case .capybara: .tummy        // a capybara has never objected to anything
        case .redpanda: .crown
        case .penguin: .tummy
        case .owl: .crown             // the top of the head, between the tufts
        case .otter: .tummy
        case .hedgehog: .nose         // the one place that is not spines
        case .stray: .crown           // she came in on her own terms and it shows
        }
    }

    /// What this buddy does when you find its favourite.
    ///
    /// Said through the caption once and then not repeated for a while — see
    /// `TimerEngine.touched(_:)`. Never a congratulation and never a
    /// discovery announcement ("You found it!"), which would turn a moment of
    /// noticing into an achievement.
    var favouriteLine: String {
        switch self {
        case .cat: "has closed both eyes and is not opening them"
        case .dog: "has rolled over entirely. This was the plan"
        case .bunny: "went very still, which is a rabbit's way of purring"
        case .hamster: "has gone limp and is making a small sound"
        case .fox: "leaned into it, hard, and nearly fell over"
        case .capybara: "was already relaxed and has found somewhere lower to go"
        case .redpanda: "has shut its eyes and is holding onto your finger"
        case .penguin: "is leaning back like this was arranged in advance"
        case .owl: "has fluffed up to twice the size and gone silent"
        case .otter: "has grabbed your hand and kept it"
        case .hedgehog: "has flattened its spines completely, which is trust"
        case .stray: "let you, and did not move away afterwards"
        }
    }
}

extension TouchSpot {

    /// The ordinary reaction, when it is not the favourite.
    ///
    /// Warm without being ecstatic — the favourite has to be a step up from
    /// something, and if every spot were delightful none of them would be.
    /// None of these is a rejection: the cat's tail is mild displeasure and
    /// she is still sitting there.
    var line: String {
        switch self {
        case .crown: "leans into your hand"
        case .nose: "has scrunched up its whole face"
        case .chin: "has tipped its head back for you"
        case .tummy: "is entirely unbothered by this"
        }
    }

    /// What VoiceOver calls it, and the label on the accessibility action.
    var name: String {
        switch self {
        case .crown: "the top of the head"
        case .nose: "the nose"
        case .chin: "under the chin"
        case .tummy: "the tummy"
        }
    }
}
