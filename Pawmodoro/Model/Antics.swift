import CoreGraphics
import Foundation

/// What a buddy does when you touch it — the whole vocabulary, as data.
///
/// Three rules shaped this file, and all three are about keeping the moves out
/// of the view:
///
/// 1. **A move is a list of beats.** Every acrobatic in the app is a sequence
///    of (offset, mirror, rotation, drawn frame) with a duration, so `BuddyView`
///    runs exactly one loop and knows nothing about hopping. Adding a move is a
///    table entry here; it is never a branch over there.
/// 2. **A buddy's signature is a `shape` plus a frame, not a special case.**
///    `Buddy.anticShape` picks one of ten shapes and `Buddy.anticFrame` says
///    what it holds, so twelve animals share ten bodies of motion and nobody
///    writes `if buddy == .penguin` anywhere.
/// 3. **Nothing here persists.** The escalation lives in `AnticBag`, in memory,
///    reset after eight quiet seconds. A stored "acrobatics level" would look
///    exactly like a stat that decays between sessions, and this app doesn't
///    have one of those.
///
/// Note the name: `Flourish` is taken — that is the light-particle layer.
enum Antic: String, CaseIterable, Identifiable, Equatable {
    /// The everyday answer, unchanged: the existing happy bounce.
    case bounce
    /// Two hops on the spot, airborne frame held at the top.
    case hop
    /// A pleased shimmy on the delighted face, decaying to a stop.
    case wiggle
    /// A mirror flip through zero width, twice. Reads as a paper-doll turn
    /// and never breaks the pixel grid the way a held rotation would.
    case spinAround = "spin"
    /// Over the top and back on its feet, in eight steps of forty-five
    /// degrees. Rotation only while moving, never held at rest.
    case tumble
    /// The one this animal alone does.
    case signature
    /// The rare full routine: crouch, leap, spin, sit.
    case routine

    var id: String { rawValue }

    /// The one-shot pose to hand the animator alongside the beats. Only the
    /// bounce has one — it *is* the existing `happy` one-shot, kept exactly as
    /// it was so the gentle everyday answer didn't change underneath anybody.
    var pose: BuddyPose? {
        switch self {
        case .bounce: .happy
        case .hop, .wiggle, .spinAround, .tumble, .signature, .routine: nil
        }
    }

    /// What the caption says. Composed after the buddy's display name, the
    /// same shape as `Buddy.breakRemark`, and never containing a name itself —
    /// every buddy can be renamed.
    ///
    /// This is what Reduce Motion keeps: the movement goes, the sentence
    /// stays, so no information is lost. The bounce has none because the touch
    /// spot it came from already writes a line of its own.
    func remark(for buddy: Buddy) -> String? {
        switch self {
        case .bounce: nil
        case .hop: "hops on the spot, twice"
        case .wiggle: "wiggles, extremely pleased with itself"
        case .spinAround: "turns a full circle and looks back at you"
        case .tumble: "tumbles clean over and lands upright"
        case .routine: "runs the whole routine — crouch, leap, spin, sit"
        case .signature: buddy.anticRemark
        }
    }

    /// The single frame that best stands for the finished move, for Reduce
    /// Motion. The *end* of a move rather than nothing.
    func stillFrame(for buddy: Buddy) -> AnticFrame {
        switch self {
        case .bounce, .wiggle, .spinAround: .happy
        case .hop, .tumble, .routine: .air
        case .signature: .signature
        }
    }

    /// The beats, in order. A buddy is needed only for the signature, which
    /// asks its own shape.
    func beats(for buddy: Buddy) -> [AnticBeat] {
        switch self {
        case .bounce: []
        case .hop: Self.hopBeats
        case .wiggle: Self.wiggleBeats
        case .spinAround: Self.spinBeats
        case .tumble: Self.tumbleBeats
        case .routine: Self.routineBeats
        case .signature: buddy.anticShape.beats
        }
    }

    /// How long the whole move takes, for throttles and for the debug parade.
    func duration(for buddy: Buddy) -> TimeInterval {
        beats(for: buddy).reduce(0) { $0 + $1.hold }
    }

    // MARK: The tables

    private static let hopBeats: [AnticBeat] = [
        AnticBeat(dy: 4, frame: .crouch, curve: .easeIn, hold: 0.12),
        AnticBeat(dy: -22, frame: .air, curve: .easeOut, hold: 0.20),
        AnticBeat(dy: 0, frame: .crouch, curve: .easeIn, hold: 0.14),
        AnticBeat(dy: -16, frame: .air, curve: .easeOut, hold: 0.18),
        AnticBeat(dy: 0, frame: .crouch, curve: .easeIn, hold: 0.10),
        AnticBeat(curve: .spring, hold: 0.16),
    ]

    /// Six shimmies, decaying, on the delighted face.
    ///
    /// The first draft borrowed the pounce's haunch wiggle literally — `dx`
    /// alternating by three points — and that was a mistake, because the
    /// pounce's wiggle is *anticipation*: it plays under a crouched buddy who
    /// is visibly about to leap, and the leap is what you are watching. Alone,
    /// answering a tap, three points is nothing. Measured on screen it moved
    /// the sprite 2.3 points either way — under a millimetre on the glass — so
    /// a quarter of every escalated tap landed on a move that looked exactly
    /// like a buddy standing still.
    ///
    /// Two things fix it. The amplitude goes to nine points, which is about a
    /// tenth of the sprite and reads at arm's length; and the face changes,
    /// because a frame swap carries a move even when the travel is small. That
    /// is the whole reason `heldWiggle` works with the same three-point
    /// shimmy — the drawn frame is doing the talking. The decay is what keeps
    /// it a shimmy rather than a rattle: it arrives, it settles.
    private static let wiggleBeats: [AnticBeat] = (0..<6).map { index in
        let decay = 1 - Double(index) / 8
        return AnticBeat(
            dx: CGFloat((index.isMultiple(of: 2) ? -9 : 9) * decay),
            dy: 2,
            frame: .happy,
            curve: .linear,
            hold: 0.11
        )
    } + [AnticBeat(frame: .happy, curve: .easeOut, hold: 0.10),
         AnticBeat(curve: .spring, hold: 0.14)]

    private static let spinBeats: [AnticBeat] = [
        AnticBeat(scaleX: -1, curve: .linear, hold: 0.22),
        AnticBeat(scaleX: 1, curve: .linear, hold: 0.22),
        AnticBeat(scaleX: -1, curve: .linear, hold: 0.22),
        AnticBeat(scaleX: 1, curve: .linear, hold: 0.24),
    ]

    /// Eight steps of forty-five degrees at 8fps, over a travelling arc that
    /// comes home, snapping to exactly zero at the end. The snap matters: a
    /// pixel-art buddy left at any angle at all looks like a rendering fault,
    /// so the last beat resets with no animation attached.
    ///
    /// Both offsets are sine arcs rather than the ramp `dx` used to be, and
    /// that is the snap's fault rather than a stylistic preference. `.snap`
    /// jumps every channel at once, and a ramp left the eighth step ten points
    /// to the right of home — measured as a seven-point pop on the landing
    /// frame, arriving in the same instant the drawn frame changed back, which
    /// is precisely when the eye is already looking. Three hundred and sixty
    /// degrees is the *only* thing that can be snapped for free, because it is
    /// the same picture as zero. So the arc returns to where it started and
    /// the last beat now has nothing left to move.
    private static let tumbleBeats: [AnticBeat] = (1...8).map { step in
        let t = Double(step) / 8.0
        return AnticBeat(
            dx: CGFloat(12 * sin(Double.pi * t)),
            dy: CGFloat(-18 * sin(Double.pi * t)),
            spin: Double(step) * 45,
            frame: .air,
            curve: .linear,
            hold: 0.10
        )
    } + [AnticBeat(curve: .snap, hold: 0.05)]

    private static let routineBeats: [AnticBeat] = [
        AnticBeat(dy: 5, frame: .crouch, curve: .easeIn, hold: 0.28),
        AnticBeat(dx: 12, dy: -34, frame: .air, curve: .easeOut, hold: 0.30),
        AnticBeat(dx: 20, dy: -20, frame: .air, curve: .linear, hold: 0.16),
        AnticBeat(dx: 24, dy: 4, frame: .crouch, curve: .easeIn, hold: 0.22),
        AnticBeat(dx: 24, scaleX: -1, curve: .linear, hold: 0.20),
        AnticBeat(dx: 24, scaleX: 1, curve: .linear, hold: 0.20),
        AnticBeat(dx: 24, scaleX: -1, curve: .linear, hold: 0.20),
        AnticBeat(dx: 24, scaleX: 1, curve: .linear, hold: 0.22),
        AnticBeat(dy: 2, curve: .spring, hold: 0.30),
        AnticBeat(curve: .easeOut, hold: 0.20),
    ]
}

/// One beat of a move: where the sprite is by the end of it, what it is doing
/// with itself, and which drawn frame it wears while it gets there.
///
/// Offsets are in points, applied on top of whatever the trick and pounce
/// machinery is already doing, so the two can never fight over one property.
struct AnticBeat: Equatable {
    var dx: CGFloat = 0
    var dy: CGFloat = 0
    /// A horizontal mirror. -1 is the far side of the paper-doll turn.
    var scaleX: CGFloat = 1
    /// Degrees. Only ever non-zero *while moving*.
    var spin: Double = 0
    /// The frame to hold. nil hands the frame back to the animator.
    var frame: AnticFrame?
    var curve: AnticCurve = .easeInOut
    /// How long this beat holds the screen before the next one starts. The
    /// movement into it takes the same time, which is what makes the whole
    /// list read as one continuous motion.
    var hold: TimeInterval
}

/// The animation curves a beat may ask for. An enum rather than a SwiftUI
/// `Animation` so the tables stay in the model and can be reasoned about (and
/// summed, and printed) without importing a view framework.
enum AnticCurve: Equatable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case spring
    /// No animation at all — jump there. Used once, to land the tumble's
    /// rotation on exactly zero.
    case snap
}

/// Which drawn frame a beat wants, named by role rather than by asset, so a
/// buddy that hasn't had one drawn yet falls back rather than blanking.
enum AnticFrame: Equatable {
    /// The wind-up every move opens on. Also the `pounceFrame` COMPANION_PLAN
    /// asked for.
    case crouch
    /// Legs tucked, ears and tail streaming. Held through anything airborne.
    case air
    /// The existing bounce frame, for a move whose end is simply delight.
    case happy
    /// The one this animal alone does.
    case signature
    /// The second half of a two-part signature — the hedgehog's ball
    /// cracking open. Falls back to the signature itself.
    case signatureTail

    /// nil means "leave the frame to the animator".
    func asset(for buddy: Buddy) -> String? {
        switch self {
        case .crouch: buddy.crouchFrame
        case .air: buddy.airFrame
        case .happy: buddy.frame("happy_1")
        case .signature: buddy.anticFrame
        case .signatureTail: buddy.anticTailFrame ?? buddy.anticFrame
        }
    }
}

/// The ten bodies of motion a signature can have. Twelve buddies share them:
/// what makes a signature the animal's own is the drawn frame it holds and the
/// sentence underneath, not a bespoke tumble nobody could name the difference
/// between.
enum AnticShape: Equatable {
    /// Raise it, hold it, put it down. A paw wave.
    case held
    /// The same, a beat slower — for someone still deciding about you.
    case heldSlow
    /// A play-bow that turns into chasing the tail.
    case bowThenSpin
    /// Out and back on the belly.
    case slide
    /// Held up, and wobbled.
    case heldWiggle
    /// Curl, bounce, uncurl.
    case ballHop
    /// All four feet off the ground, twisting.
    case airborne
    /// Nose down, rear up, forward and down onto it.
    case pounceForward
    /// Wings out, off the perch, hovering.
    case flap
    /// The joke: it does not move.
    case still

    var beats: [AnticBeat] {
        switch self {
        // Three pumps, not one hold.
        //
        // The first draft raised the sprite two points, held the raised-paw
        // frame for four tenths of a second and put it down, under the caption
        // "waves a paw. Just the one". Measured on screen that is a 6px lift
        // on a 104pt sprite and then nothing: the frame swap does all the
        // work, and what you watch is a cat standing still in a different
        // drawing. It was indistinguishable from the capybara's `still`, which
        // is the move whose entire joke is that nothing happens.
        //
        // A wave is repetition — that is the whole of what makes it a wave
        // rather than a raised paw — so the lift goes to six points and
        // happens three times. It is the beckoning-cat pump, and it is the
        // sprite that moves rather than the paw, which is honest: there is one
        // drawing, and a pumped whole-body beckon is what that drawing can say.
        case .held:
            [
                AnticBeat(dy: -6, frame: .signature, curve: .easeOut, hold: 0.14),
                AnticBeat(dy: -1, frame: .signature, curve: .easeIn, hold: 0.12),
                AnticBeat(dy: -6, frame: .signature, curve: .easeOut, hold: 0.14),
                AnticBeat(dy: -1, frame: .signature, curve: .easeIn, hold: 0.12),
                AnticBeat(dy: -6, frame: .signature, curve: .easeOut, hold: 0.16),
                AnticBeat(curve: .easeIn, hold: 0.16),
            ]
        // Two pumps and a longer look, for someone still deciding about you.
        case .heldSlow:
            [
                AnticBeat(dy: -5, frame: .signature, curve: .easeOut, hold: 0.22),
                AnticBeat(dy: -1, frame: .signature, curve: .easeIn, hold: 0.18),
                AnticBeat(dy: -5, frame: .signature, curve: .easeOut, hold: 0.22),
                AnticBeat(dy: -5, frame: .signature, curve: .linear, hold: 0.32),
                AnticBeat(curve: .easeIn, hold: 0.22),
            ]
        case .bowThenSpin:
            [
                AnticBeat(dy: 3, frame: .signature, curve: .easeOut, hold: 0.35),
                AnticBeat(scaleX: -1, curve: .linear, hold: 0.20),
                AnticBeat(scaleX: 1, curve: .linear, hold: 0.20),
                AnticBeat(scaleX: -1, curve: .linear, hold: 0.20),
                AnticBeat(scaleX: 1, curve: .linear, hold: 0.20),
                AnticBeat(curve: .easeOut, hold: 0.15),
            ]
        case .slide:
            [
                AnticBeat(dx: -26, dy: 4, frame: .signature, curve: .easeOut, hold: 0.30),
                AnticBeat(dx: 26, dy: 4, frame: .signature, curve: .easeInOut, hold: 0.42),
                AnticBeat(curve: .spring, hold: 0.30),
            ]
        case .heldWiggle:
            [
                AnticBeat(frame: .signature, curve: .easeOut, hold: 0.18),
                AnticBeat(dx: -3, frame: .signature, curve: .linear, hold: 0.12),
                AnticBeat(dx: 3, frame: .signature, curve: .linear, hold: 0.12),
                AnticBeat(dx: -3, frame: .signature, curve: .linear, hold: 0.12),
                AnticBeat(dx: 3, frame: .signature, curve: .linear, hold: 0.12),
                AnticBeat(curve: .easeOut, hold: 0.16),
            ]
        case .ballHop:
            [
                AnticBeat(frame: .signature, curve: .easeOut, hold: 0.30),
                AnticBeat(dy: -20, frame: .signature, curve: .easeOut, hold: 0.20),
                AnticBeat(frame: .signature, curve: .easeIn, hold: 0.16),
                AnticBeat(frame: .signatureTail, curve: .linear, hold: 0.34),
                AnticBeat(curve: .easeOut, hold: 0.16),
            ]
        case .airborne:
            [
                AnticBeat(dy: 4, frame: .crouch, curve: .easeIn, hold: 0.16),
                AnticBeat(dx: 6, dy: -30, frame: .signature, curve: .easeOut, hold: 0.24),
                AnticBeat(dx: -6, dy: -22, frame: .signature, curve: .linear, hold: 0.16),
                AnticBeat(dy: 3, frame: .crouch, curve: .easeIn, hold: 0.18),
                AnticBeat(curve: .spring, hold: 0.20),
            ]
        case .pounceForward:
            [
                AnticBeat(dy: 4, frame: .crouch, curve: .easeIn, hold: 0.24),
                AnticBeat(dx: 14, dy: -14, frame: .signature, curve: .easeOut, hold: 0.18),
                AnticBeat(dx: 22, dy: 6, frame: .signature, curve: .easeIn, hold: 0.16),
                AnticBeat(dx: 22, dy: 2, frame: .signature, curve: .linear, hold: 0.22),
                AnticBeat(curve: .spring, hold: 0.26),
            ]
        // Wings *down* between the wings-up frames, or it is a hover.
        //
        // Held on one drawing this was an owl with its wings permanently
        // spread, bobbing four points up and down — which reads as a bird
        // being lifted rather than one flying. There is no second flap sprite
        // and there does not need to be: the ordinary perched drawing has its
        // wings folded, so alternating the two *is* the wingbeat, and
        // `signatureTail` already exists for exactly this (the hedgehog's ball
        // cracking open). Every up in the bob is a wings-out frame and every
        // dip is a wings-in one, so the two channels say the same thing.
        case .flap:
            [
                AnticBeat(dy: -4, frame: .signature, curve: .easeOut, hold: 0.16),
                AnticBeat(dy: -16, frame: .signature, curve: .easeOut, hold: 0.18),
                AnticBeat(dy: -12, frame: .signatureTail, curve: .linear, hold: 0.12),
                AnticBeat(dy: -20, frame: .signature, curve: .linear, hold: 0.16),
                AnticBeat(dy: -14, frame: .signatureTail, curve: .linear, hold: 0.12),
                AnticBeat(dy: -20, frame: .signature, curve: .linear, hold: 0.16),
                AnticBeat(curve: .spring, hold: 0.26),
            ]
        case .still:
            // One frame, one second, and the caption does the rest. Everyone
            // else somersaults; this one declines, and the joke only lands
            // because the machinery around it was perfectly willing.
            //
            // The second beat looks pointless and is not: every table in this
            // file hands the frame back to the animator itself rather than
            // leaning on the runner's `defer` to do it. A move that only ends
            // tidily when it runs to completion ends untidily when it doesn't.
            [
                AnticBeat(frame: .signature, curve: .linear, hold: 0.9),
                AnticBeat(curve: .linear, hold: 0.1),
            ]
        }
    }
}

/// What a tap resolved to: one of the app's own moves, or a trick this buddy
/// has actually mastered.
///
/// The second case is the whole bridge to Phase Y. A tap is never a `Trick`
/// *cue* — cueing gates on bond, performs a deliberate pratfall at tier zero,
/// and writes `practicedOn`, so fifty taps would be indistinguishable from one
/// carefully drawn circle. But a trick that has been taught all the way to
/// mastery joins the everyday vocabulary permanently, played through
/// `Repertoire.showOff`, which does no bookkeeping at all.
enum AnticChoice: Equatable {
    case move(Antic)
    case trick(Trick)
}

/// The escalation: a bag, not a cycle, and nothing is written down.
///
/// A strict cycle is learnable in four taps and becomes a slideshow. Drawing
/// without replacement from a shuffled bag guarantees no immediate repeat —
/// which is the actual complaint — without ever being predictable.
///
/// Deliberately a value type held in view state. There is no `StorageKeys`
/// entry for it and there must never be one: a stored tap count would read as
/// a stat that decays between sessions, and this app doesn't have one of
/// those.
struct AnticBag: Equatable {

    /// Quiet for this long and the buddy is back to its gentle self.
    static let restWindow: TimeInterval = 8
    /// Taps before the bag opens at all.
    static let gentleTaps = 2
    /// The tap the signature joins from.
    static let signatureTap = 6
    /// One tap in this many, past the gentle ones, is the full routine.
    static let routineOdds = 25

    private var bag: [AnticChoice] = []
    private var lastDrawn: AnticChoice?
    private var lastTap: Date = .distantPast
    private(set) var taps = 0

    /// The moves that make up an escalated tap. `signature` is added from the
    /// sixth tap; mastered tricks are added whenever there are any.
    static let core: [Antic] = [.hop, .wiggle, .spinAround, .tumble]

    /// Draw the answer to one tap.
    ///
    /// `seed` is the caller's deterministic roll — `Doorstep.stableHash` of
    /// something that changes per tap — used only for the rare routine, so the
    /// one-in-twenty-five can be reasoned about rather than watched for.
    mutating func draw(
        at now: Date = Date(), seed: Int, mastered: [Trick]
    ) -> AnticChoice {
        if now.timeIntervalSince(lastTap) > Self.restWindow {
            taps = 0
            bag = []
            lastDrawn = nil
        }
        lastTap = now
        taps += 1

        guard taps > Self.gentleTaps else { return .move(.bounce) }

        if seed % Self.routineOdds == 0 {
            lastDrawn = .move(.routine)
            return .move(.routine)
        }

        if bag.isEmpty { refill(mastered: mastered) }
        let drawn = bag.popLast() ?? .move(.bounce)
        lastDrawn = drawn
        return drawn
    }

    /// Refill and shuffle, then make sure the first thing out isn't the last
    /// thing in. That single swap is what turns "shuffled" into "never repeats
    /// immediately", which is the only property anybody actually notices.
    private mutating func refill(mastered: [Trick]) {
        var pool: [AnticChoice] = Self.core.map { .move($0) }
        if taps >= Self.signatureTap { pool.append(.move(.signature)) }
        pool.append(contentsOf: mastered.map { .trick($0) })
        pool.shuffle()
        if pool.count > 1, pool.last == lastDrawn {
            pool.swapAt(pool.count - 1, 0)
        }
        bag = pool
    }
}
