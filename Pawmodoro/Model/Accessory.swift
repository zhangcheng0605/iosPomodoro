import CoreGraphics
import Foundation

/// Something a buddy wears.
///
/// Fifteen pieces, three slots, and nothing any of them *does*. There are no
/// stats, no set bonuses and no accessory that earns anything — it is clothes,
/// and the moment a hat is worth acorns per hour the buddy has been given a
/// job.
///
/// ### How they are positioned
///
/// Not by hand. `tools/generate_accessories.py` measures every buddy frame's
/// rendered pixels and emits `BuddyAnchors` — where the crown is, where the
/// collar line is, and how wide the head is at each. This file says only how
/// big a piece is *relative to that head* and which of its own edges lands on
/// the anchor, so nothing here knows about any particular buddy and a buddy
/// redrawn tomorrow is dressed correctly by the next run of the tool.
///
/// A frame with no anchor row simply wears nothing, which is `BuddyFrames`'
/// nil-fallback rule extended to overlays: a pose whose head the measurer
/// could not find should go bare-headed, not crash and not guess.
enum Accessory: String, CaseIterable, Identifiable, Codable {
    // Head
    case sunhat
    case flowercrown
    case knittedcap
    case crown
    case leaf
    case beret
    // Face
    case spectacles
    case shades
    case monocle
    case starglasses
    // Neck
    case bandana
    case bellcollar
    case scarf
    case kerchief
    case bow

    var id: String { rawValue }

    /// Three slots — and still not the three `HEARTH_PLAN` asked for.
    ///
    /// A *back* slot was planned and dropped: at forty logical pixels, anything
    /// drawn behind the buddy is four or five visible pixels of colour poking
    /// out at the sides, which reads as a rendering fault rather than a cape.
    ///
    /// The face came back instead. It was written off in the plan's as-built
    /// as "a third anchor nobody can measure", on the grounds that the eyes are
    /// drawn per buddy by a shared helper rather than by a shape the pixels can
    /// find. That was the wrong way round: the helper paints both eyes in one
    /// palette index, so the eyes are the *easiest* thing on a buddy to find —
    /// they are the only pair. `generate_accessories.py` measures them now, and
    /// a frame whose eyes are not visible simply goes without.
    ///
    /// Listed top to bottom, because that is the order the wardrobe row draws
    /// them in and the order somebody dresses an animal in.
    enum Slot: String, CaseIterable, Identifiable, Codable {
        case head, face, neck

        var id: String { rawValue }

        var title: String {
            switch self {
            case .head: "On the head"
            case .face: "Over the eyes"
            case .neck: "Round the neck"
            }
        }
    }

    var slot: Slot {
        switch self {
        case .sunhat, .flowercrown, .knittedcap, .crown, .leaf, .beret: .head
        case .spectacles, .shades, .monocle, .starglasses: .face
        case .bandana, .bellcollar, .scarf, .kerchief, .bow: .neck
        }
    }

    var name: String {
        switch self {
        case .sunhat: "The sun hat"
        case .flowercrown: "A crown of flowers"
        case .knittedcap: "The knitted cap"
        case .crown: "A small crown"
        case .leaf: "One leaf"
        case .beret: "The beret"
        case .spectacles: "Round spectacles"
        case .shades: "The dark glasses"
        case .monocle: "A monocle"
        case .starglasses: "Star glasses"
        case .bandana: "The red bandana"
        case .bellcollar: "A bell collar"
        case .scarf: "The long scarf"
        case .kerchief: "A sailor's kerchief"
        case .bow: "The bow"
        }
    }

    /// What the buddy's caption says the once, the first time it is worn.
    ///
    /// A lowercase fragment, spoken after the name — the name has to come
    /// from `settings.displayName(for:)` at the call site, because a model
    /// type cannot reach it and every buddy can be renamed. Never a
    /// congratulation: somebody put a hat on a cat, and the cat has an
    /// opinion about that, which is a different sentence from being thanked
    /// for a purchase.
    var firstWornLine: String {
        switch self {
        case .sunhat: "wears it like the weather was the plan all along"
        case .flowercrown: "has not moved since it went on"
        case .knittedcap: "was not cold, and is now delighted anyway"
        case .crown: "has taken this entirely the wrong way"
        case .leaf: "does not know it is there"
        case .beret: "has opinions now, about painting"
        case .spectacles: "looks about to explain something, and does not"
        case .shades: "cannot see a thing and has decided this is fine"
        case .monocle: "has never explained the monocle"
        case .starglasses: "is at a party. You are not invited to it"
        case .bandana: "looks ready for something. Nothing is happening"
        case .bellcollar: "has discovered the bell, and then discovered it again"
        case .scarf: "is wearing most of it and sitting on the rest"
        case .kerchief: "has never been on a boat"
        case .bow: "is pretending not to like it"
        }
    }

    var asset: String { "wear_\(rawValue)" }

    /// The six the app simply gives you — two per slot, owned from the first
    /// launch with no acorns and no Plus.
    ///
    /// They exist so the wardrobe can be *tried* before it is saved for:
    /// somebody puts the leaf on the owl in their first minute, discovers
    /// that hats are a thing here, and the paid pieces mean something. The
    /// humble ones are the gifts — a leaf that fell, a cap somebody knitted,
    /// a bandana, a bow, two ordinary pairs of glasses — and the finery stays
    /// in the Magpie's Cart. Two per slot is a promise `check_catalog.py`
    /// holds: a gift once given is never taken back, and a slot with nothing
    /// free in it is a shelf of padlocks rather than a wardrobe.
    var isFree: Bool {
        switch self {
        case .knittedcap, .leaf, .spectacles, .shades, .bandana, .bow: true
        case .sunhat, .flowercrown, .crown, .beret, .monocle, .starglasses,
             .bellcollar, .scarf, .kerchief: false
        }
    }

    // MARK: Where it sits

    /// How wide the piece is drawn, as a fraction of the anchor's reference
    /// width — the head for a hat, the (head-capped) collar run for a neck
    /// piece, the distance between the eyes for a face piece. Tuned against a
    /// contact sheet of all twelve buddies in all sixteen pieces; the numbers
    /// only mean anything together with that picture.
    var scale: CGFloat {
        switch self {
        case .sunhat: 1.00
        case .flowercrown: 0.95
        case .knittedcap: 0.85
        case .crown: 0.70
        case .leaf: 0.42
        case .beret: 0.90
        // Just past the eyes rather than well past them: the owl's eyes are
        // two thirds of her face and the bunny's are a third, so anything
        // scaled to the *head* is a windscreen on one and a dot on the other.
        case .spectacles: 1.20
        case .shades: 1.10
        case .monocle: 1.15
        case .starglasses: 1.20
        case .bandana: 0.90
        case .bellcollar: 0.85
        case .scarf: 0.95
        case .kerchief: 0.90
        case .bow: 0.50
        }
    }

    /// How far a head piece settles *into* the head, as a fraction of its own
    /// height. Hats sit on skulls rather than hovering over them, and without
    /// this every one of them floated — and the tall ones were clipped clean
    /// off the top of the canvas, because the crown is only six rows down.
    ///
    /// Neck and face pieces ignore this: a neck piece hangs from the collar
    /// line by its top edge — centring it there instead drew the bandana
    /// straight across the muzzle of every long-faced buddy in the roster —
    /// and a face piece is centred on the eyes, which is the one anchor that
    /// is a point in the middle of the thing rather than an edge to hang from.
    var sink: CGFloat {
        switch self {
        case .sunhat: 0.35
        case .flowercrown: 0.40
        case .knittedcap: 0.40
        case .crown: 0.30
        case .leaf: 0.25
        case .beret: 0.40
        case .spectacles, .shades, .monocle, .starglasses: 0
        case .bandana, .bellcollar, .scarf, .kerchief, .bow: 0
        }
    }

    /// Where this piece lands on a buddy frame, in the same units
    /// `BuddyAnchors` uses, or nil if that frame has no anchors.
    ///
    /// Returns the rect rather than a point so the view has nothing left to
    /// work out — and so `tools/check_accessories.py` can ask the same
    /// question the app asks and get the same answer.
    func placement(on asset: String) -> CGRect? {
        guard let anchors = BuddyAnchors.anchors(for: asset) else { return nil }
        let aspect = Self.aspect(of: self)
        switch slot {
        case .head:
            let width = anchors.headWidth * scale
            let height = width / aspect
            return CGRect(
                x: anchors.head.x - width / 2,
                y: anchors.head.y - height * (1 - sink),
                width: width, height: height
            )
        case .face:
            // Nil rather than a guess: a frame whose eyes the measurer could
            // not find is a face you cannot see — mid-stretch, or a hedgehog
            // rolled into a ball — and spectacles on it would hang in fur.
            guard let face = anchors.face, anchors.faceWidth > 0 else { return nil }
            let width = anchors.faceWidth * scale
            let height = width / aspect
            return CGRect(
                x: face.x - width / 2,
                y: face.y - height / 2,
                width: width, height: height
            )
        case .neck:
            let width = anchors.neckWidth * scale
            let height = width / aspect
            return CGRect(
                x: anchors.neck.x - width / 2,
                y: anchors.neck.y,
                width: width, height: height
            )
        }
    }

    /// The drawn aspect of each sprite, which must match the grids in
    /// `tools/generate_accessories.py` — `check_accessories.py` reads both and
    /// fails if they drift, because a wrong aspect here silently squashes the
    /// art rather than moving it, and a squashed hat still looks like a hat.
    private static func aspect(of accessory: Accessory) -> CGFloat {
        switch accessory {
        case .sunhat: 22.0 / 8.0
        case .flowercrown: 20.0 / 6.0
        case .knittedcap: 18.0 / 9.0
        case .crown: 16.0 / 7.0
        case .leaf: 11.0 / 8.0
        case .beret: 16.0 / 7.0
        case .spectacles: 20.0 / 9.0
        case .shades: 16.0 / 6.0
        case .monocle: 18.0 / 10.0
        case .starglasses: 18.0 / 8.0
        case .bandana: 18.0 / 9.0
        case .bellcollar: 18.0 / 8.0
        case .scarf: 20.0 / 11.0
        case .kerchief: 18.0 / 9.0
        case .bow: 14.0 / 8.0
        }
    }

    /// The picker's order: the free pieces first, then the cart's, each in
    /// declaration order. First thing anybody sees in a row is something they
    /// can actually put on.
    static func items(in slot: Slot) -> [Accessory] {
        let inSlot = allCases.filter { $0.slot == slot }
        return inSlot.filter(\.isFree) + inSlot.filter { !$0.isFree }
    }
}
