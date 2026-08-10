import Foundation
import Observation

/// What the buddy is doing right now.
///
/// Poses come in two shapes. Loops (`napping`, `idle`) have no end and pick
/// their frame from a formula over elapsed time, so they stay in step no matter
/// when a view starts rendering them. One-shots (`waking`, `happy`, `stirring`)
/// play a fixed list of frames once and then hand back to the loop underneath.
enum BuddyPose: Equatable {
    /// Curled up asleep, chest rising and falling. Focus phase, running.
    case napping
    /// Sitting up, blinking now and then. Everything else.
    case idle
    /// Eyes open, a stretch, then a pleased bounce. Plays when focus ends.
    case waking
    /// A two-frame bounce. Plays when the buddy is petted or a session lands.
    case happy
    /// One eye cracked open and shut again — petted mid-nap. The buddy never
    /// actually wakes during focus; that would make the fiction punitive.
    case stirring
    /// Awake and alert through a focus session. Only the owl, only at night.
    case watching
    /// Off in a hot spring for the break. Only the capybara.
    case soaking
    /// The signature pose a buddy takes at the place it likes best.
    case atHome

    /// How often the frame is allowed to change.
    ///
    /// Loops stay slow on purpose: this drives a `TimelineView`, and every tick
    /// is a wake-up. Bursts get 8fps because they are short and want to read as
    /// motion rather than as two stills.
    var frameInterval: TimeInterval {
        switch self {
        case .napping: 0.5
        case .idle: 0.25
        case .waking, .happy: 1.0 / 8.0
        case .stirring: 0.25
        // The three quirk rests hold a single frame; they still need a slow
        // tick so a blink or a shuffle can land, but nothing faster.
        case .watching, .soaking, .atHome: 0.5
        }
    }

    var isLoop: Bool {
        switch self {
        case .napping, .idle, .watching, .soaking, .atHome: true
        case .waking, .happy, .stirring: false
        }
    }
}

/// Resolves a pose plus an elapsed time into one sprite asset name.
///
/// Kept separate from the animator, and pure, so the whole animation can be
/// reasoned about (and previewed) without a running clock.
enum BuddyFrames {

    static func name(for buddy: Buddy, pose: BuddyPose, elapsed: TimeInterval) -> String {
        let t = max(0, elapsed)
        switch pose {
        case .napping: return napping(buddy, t)
        case .idle: return idle(buddy, t)
        case .stirring: return buddy.frame("wake")
        case .happy: return step(in: happySteps(buddy), at: t)
        case .waking: return step(in: wakingSteps(buddy), at: t)
        // Each of these falls back to an ordinary pose if the buddy has no
        // frame for it, so a quirk is always additive and never a blank.
        case .watching: return buddy.watchFrame ?? buddy.frame("awake")
        case .soaking: return buddy.breakFrame ?? idle(buddy, t)
        case .atHome: return buddy.homeFrame ?? idle(buddy, t)
        }
    }

    /// How long a one-shot runs. Loops return nil.
    static func duration(for buddy: Buddy, pose: BuddyPose) -> TimeInterval? {
        switch pose {
        case .napping, .idle, .watching, .soaking, .atHome: return nil
        case .stirring: return 0.9
        case .happy: return total(happySteps(buddy))
        case .waking: return total(wakingSteps(buddy))
        }
    }

    // MARK: Loops

    /// A five-second breath: three seconds out, two in. The two frames differ by
    /// a single pixel of pixel art, so a hard swap still reads as breathing.
    private static func napping(_ buddy: Buddy, _ elapsed: TimeInterval) -> String {
        let phase = elapsed.truncatingRemainder(dividingBy: 5)
        return buddy.frame(phase < 3 ? "asleep" : "asleep_breathe")
    }

    /// A blink every few seconds, doubled every third one so it never settles
    /// into an obvious rhythm. Deterministic rather than random: the same
    /// elapsed time always gives the same frame, which keeps it testable.
    private static func idle(_ buddy: Buddy, _ elapsed: TimeInterval) -> String {
        // A buddy that doesn't sit down shuffles instead of blinking: standing
        // perfectly still reads as a frozen app rather than as a penguin.
        if let shuffle = buddy.idleShuffleFrame {
            let phase = elapsed.truncatingRemainder(dividingBy: 1.6)
            return phase < 0.8 ? buddy.frame("awake") : shuffle
        }

        let cycle: TimeInterval = 4.25
        let index = (elapsed / cycle).rounded(.down)
        let phase = elapsed - index * cycle
        let blinking = phase < 0.25
            || (Int(index).isMultiple(of: 3) && phase >= 0.5 && phase < 0.75)
        return buddy.frame(blinking ? "awake_blink" : "awake")
    }

    // MARK: One-shots

    private typealias Step = (frame: String, duration: TimeInterval)

    private static func happySteps(_ buddy: Buddy) -> [Step] {
        // A buddy with a signature celebration holds it, bracketed by the
        // ordinary bounce so the moment still has a beginning and an end.
        if let signature = buddy.celebrationFrame {
            return [
                (buddy.frame("happy_1"), 0.12),
                (signature, 0.46),
                (buddy.frame("happy_0"), 0.16),
            ]
        }
        return [
            (buddy.frame("happy_1"), 0.16),
            (buddy.frame("happy_0"), 0.16),
            (buddy.frame("happy_1"), 0.16),
            (buddy.frame("happy_0"), 0.22),
        ]
    }

    /// Eyes open, a stretch if this buddy has one, then a pleased bounce.
    /// Only cat and dog have a stretch drawn; the rest go straight to the
    /// bounce rather than showing a frame that doesn't exist.
    private static func wakingSteps(_ buddy: Buddy) -> [Step] {
        var steps: [Step] = [(buddy.frame("wake"), 0.45)]
        if buddy.hasStretchFrame {
            steps.append((buddy.frame("stretch"), 0.75))
        }
        steps.append(contentsOf: happySteps(buddy))
        return steps
    }

    private static func total(_ steps: [Step]) -> TimeInterval {
        steps.reduce(0) { $0 + $1.duration }
    }

    private static func step(in steps: [Step], at elapsed: TimeInterval) -> String {
        var remaining = elapsed
        for step in steps {
            if remaining < step.duration { return step.frame }
            remaining -= step.duration
        }
        return steps.last?.frame ?? ""
    }
}

/// Holds which pose the buddy is in, and lets a one-shot play over the top of
/// the resting loop without losing it.
///
/// Deliberately has no timer of its own. Views drive rendering with a
/// `TimelineView`, which stops when the view is off screen — so an idle app
/// costs nothing. The only timer here is the one that clears a finished
/// one-shot, which exists so the view's tick rate can drop back down.
@Observable
final class BuddyAnimator {

    private(set) var basePose: BuddyPose = .idle
    private(set) var baseStarted: Date = .distantPast

    private(set) var transientPose: BuddyPose?
    private(set) var transientStarted: Date = .distantPast

    @ObservationIgnored private var clearTask: Task<Void, Never>?

    /// Whichever pose should be drawn at `date`, and how far into it we are.
    func resolved(at date: Date) -> (pose: BuddyPose, elapsed: TimeInterval) {
        if let transientPose {
            let elapsed = date.timeIntervalSince(transientStarted)
            if elapsed >= 0, elapsed < transientDuration {
                return (transientPose, elapsed)
            }
        }
        return (basePose, date.timeIntervalSince(baseStarted))
    }

    func frameName(for buddy: Buddy, at date: Date) -> String {
        let resolved = resolved(at: date)
        return BuddyFrames.name(for: buddy, pose: resolved.pose, elapsed: resolved.elapsed)
    }

    /// The resting loop, from the timer's state. Restarting the same pose is
    /// ignored so the breath doesn't jump every time settings are touched.
    func setBase(_ pose: BuddyPose, now: Date = Date()) {
        guard pose != basePose else { return }
        basePose = pose
        baseStarted = now
    }

    /// Play a one-shot over the top of the resting loop.
    func play(_ pose: BuddyPose, for buddy: Buddy, now: Date = Date()) {
        guard !pose.isLoop else { return }
        transientPose = pose
        transientStarted = now
        transientDuration = BuddyFrames.duration(for: buddy, pose: pose) ?? 0

        // Clearing this is what lets the view drop back to the slow loop rate;
        // resolution above is already time-based, so a missed clear only costs
        // extra ticks, never a stuck frame.
        clearTask?.cancel()
        let seconds = transientDuration
        clearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            // Bind before the hop. `self?.` inside the MainActor closure reads
            // the *captured optional variable* from a second concurrent
            // context, which Swift 6 makes an error rather than a warning.
            guard !Task.isCancelled, let self else { return }
            await MainActor.run { self.transientPose = nil }
        }
    }

    /// True while a one-shot is on screen, so callers can avoid interrupting it.
    func isPlayingTransient(at date: Date) -> Bool {
        guard transientPose != nil else { return false }
        let elapsed = date.timeIntervalSince(transientStarted)
        return elapsed >= 0 && elapsed < transientDuration
    }

    @ObservationIgnored private var transientDuration: TimeInterval = 0

    deinit { clearTask?.cancel() }
}
