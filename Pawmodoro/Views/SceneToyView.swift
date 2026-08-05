import SwiftUI

/// What a finger does to the place you're in.
///
/// **Focus stays sacred.** These only answer while a break is running or while
/// nothing is — the one thing the app must never do is invite you to poke at
/// the scenery during the twenty-five minutes you asked it to protect.
///
/// They are toys, not games. Nothing is scored, nothing is collected, nothing
/// is unlocked, and a stone that skips four times is worth exactly as much as
/// one that skips once.
enum SceneToy {
    /// Rings on water: a tap makes one, a swipe skips a stone across.
    case water
    /// A swipe scatters blossom and it drifts back down.
    case petals
    /// After dark, one firefly follows your finger and then thinks better of it.
    case firefly
}

extension Place {
    /// What this place gives a finger to do, at this hour.
    ///
    /// Night outranks everything: a firefly is the best of the four and every
    /// place is dark eventually, which is what stops the drier places (the
    /// Keep, the Peaks) from having nothing at all.
    func toy(at dayPart: DayPart) -> SceneToy? {
        if dayPart == .night { return .firefly }
        switch self {
        case .woods, .harbor, .onsen: return .water
        case .blossom: return .petals
        case .meadow, .keep, .cloudspire, .peaks: return nil
        }
    }
}

/// Where a finger is on the scene, so the buddy can look at it.
///
/// A shared observable rather than a binding, because the two views that care
/// are siblings in the ZStack and neither owns the other. It holds a fraction
/// of the screen width, not a point: `BuddyView` is centred, so "left of
/// centre" is all it needs and that survives any screen size.
@Observable
final class TouchTracker {
    static let shared = TouchTracker()

    /// 0...1 across the width, or nil when nothing is touching.
    var x: Double?

    private init() {}
}

/// The toy layer.
///
/// Sits above the scenery and *below* the stray, so a tap on her still spooks
/// her and everything else falls through to here. Below the controls too, so
/// the transport buttons always win.
struct SceneToyView: View {
    /// Nil where a place has nothing to play with. The layer still mounts and
    /// still tracks the finger, because the buddy's eyes follow it everywhere
    /// — only the effects are place-specific.
    let toy: SceneToy?
    /// False during a focus phase. The layer stays mounted but ignores touches,
    /// so nothing pops in and out under your finger as a break starts.
    let enabled: Bool
    let tint: Color
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var effects: [Effect] = []
    @State private var seed = 0
    @State private var firefly: Firefly?
    @State private var lastRipple = Date.distantPast

    /// How long she takes to dim out after being let go. Shared by the fade
    /// maths and the reaper, so the canvas unmounts exactly when she vanishes.
    private static let fireflyFade: TimeInterval = 2.2

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // A canvas is only mounted while it has something to draw —
                // the same rule the confetti and the wildlife follow.
                if !effects.isEmpty || firefly != nil {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                        Canvas { canvas, size in
                            draw(&canvas, size: size, now: context.date)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(enabled ? gesture(in: geometry.size) : nil)
            .onDisappear { TouchTracker.shared.x = nil }
            // The snow globe. Works in any place and at any hour, including
            // during focus — a shake is not a fiddle, it is something you do
            // once and then go back to work.
            .onReceive(NotificationCenter.default.publisher(for: .pawmodoroShake)) { _ in
                // Reduce Motion turns the whole toy layer off rather than
                // slowing it: every effect here *is* motion, so there is no
                // still version of it worth drawing.
                guard !reduceMotion else { return }
                swirl(in: geometry.size)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // MARK: The finger

    /// The toy, unless the reader has asked for less movement — in which case
    /// there isn't one. The finger is still *tracked* either way, because the
    /// buddy's glance is a two-pixel pupil shift rather than an animation.
    private var activeToy: SceneToy? { reduceMotion ? nil : toy }

    private func gesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Tracked first and unconditionally: the eyes follow a finger
                // even in a place with nothing to stir.
                TouchTracker.shared.x = value.location.x / max(size.width, 1)
                switch activeToy {
                case .firefly:
                    follow(value.location)
                case .water:
                    // Rings under a moving finger, throttled — a ring per frame
                    // is a smear rather than water.
                    ripple(at: value.location, throttle: 0.22)
                case .petals:
                    scatter(from: value.location, drag: value.translation)
                case nil:
                    break
                }
            }
            .onEnded { value in
                TouchTracker.shared.x = nil
                let travel = hypot(value.translation.width, value.translation.height)
                switch activeToy {
                case .water where travel > 40:
                    skipStone(from: value.startLocation, to: value.location, in: size)
                case .water:
                    ripple(at: value.location, throttle: 0)
                case .petals where travel > 30:
                    scatter(from: value.location, drag: value.translation)
                case .petals, nil:
                    break
                case .firefly:
                    // Let go and she wanders off, which is the whole joke.
                    firefly?.releasedAt = Date()
                    reapFirefly()
                }
            }
    }

    private func ripple(at point: CGPoint, throttle: TimeInterval) {
        let now = Date()
        guard now.timeIntervalSince(lastRipple) > throttle else { return }
        lastRipple = now
        add(Effect(kind: .ring, at: point, born: now, life: 1.4))
        HapticsDirector.shared.nudge()
    }

    /// One to four skips, decided by how hard the swipe was — and never
    /// reported. A number on screen would turn this into a game.
    private func skipStone(from start: CGPoint, to end: CGPoint, in size: CGSize) {
        let now = Date()
        let travel = hypot(end.x - start.x, end.y - start.y)
        let skips = min(4, max(1, Int(travel / max(size.width * 0.22, 1))))
        var point = start
        let step = CGPoint(
            x: (end.x - start.x) / CGFloat(skips + 1),
            y: (end.y - start.y) / CGFloat(skips + 1)
        )
        for index in 0...skips {
            point = CGPoint(x: point.x + step.x, y: point.y + step.y)
            // Each skip's ring is born a beat after the last, so the stone
            // reads as travelling rather than as five rings appearing at once.
            add(Effect(
                kind: .ring, at: point,
                born: now.addingTimeInterval(Double(index) * 0.16),
                life: 1.2
            ))
        }
        HapticsDirector.shared.detent()
    }

    private func scatter(from point: CGPoint, drag: CGSize) {
        let now = Date()
        guard now.timeIntervalSince(lastRipple) > 0.12 else { return }
        lastRipple = now
        for index in 0..<4 {
            let spread = Double(index) - 1.5
            add(Effect(
                kind: .petal(driftX: drag.width * 0.012 + spread * 0.5,
                             spin: spread),
                at: point, born: now, life: 2.4
            ))
        }
    }

    /// Everything loose in the scene goes round once and resettles.
    private func swirl(in size: CGSize) {
        guard effects.count < 40 else { return }   // no stacking a shake storm
        let now = Date()
        for index in 0..<18 {
            let n = Double(index)
            add(Effect(
                kind: .mote(
                    angle: n / 18 * .pi * 2,
                    radius: size.width * (0.18 + 0.26 * (n * 0.6180339887)
                        .truncatingRemainder(dividingBy: 1))
                ),
                at: .zero, born: now, life: 2.0
            ))
        }
        HapticsDirector.shared.detent()
    }

    private func follow(_ point: CGPoint) {
        if firefly == nil {
            firefly = Firefly(at: point, born: Date())
        }
        firefly?.target = point
        firefly?.releasedAt = nil
    }

    /// Clears her once she has faded, so the 30fps canvas can unmount.
    ///
    /// Without this the mount condition (`firefly != nil`) latched on the
    /// first touch and the timeline ticked for the rest of the app's life,
    /// drawing nothing — the effects array has always been reaped this way,
    /// and she was the one thing that wasn't.
    private func reapFirefly() {
        guard let released = firefly?.releasedAt else { return }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(Self.fireflyFade * 1_000_000_000))
            // Only if she hasn't been picked up again in the meantime.
            if firefly?.releasedAt == released { firefly = nil }
        }
    }

    private func add(_ effect: Effect) {
        seed += 1
        var effect = effect
        effect.id = seed
        effects.append(effect)
        // Reaped rather than left to accumulate: an hour of idle poking would
        // otherwise be an hour of dead structs in an array.
        let deadline = effect.born.addingTimeInterval(effect.life)
        Task {
            let wait = max(0, deadline.timeIntervalSinceNow)
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            effects.removeAll { $0.id == effect.id }
        }
    }

    // MARK: Drawing

    private func draw(_ canvas: inout GraphicsContext, size: CGSize, now: Date) {
        for effect in effects {
            let age = now.timeIntervalSince(effect.born)
            guard age >= 0, age < effect.life else { continue }
            let t = age / effect.life

            switch effect.kind {
            case .ring:
                // Expanding and thinning: the two things that make a ring read
                // as water rather than as a circle.
                let radius = 6 + t * 46
                let fade = (1 - t) * 0.55
                canvas.stroke(
                    Path(ellipseIn: CGRect(
                        x: effect.at.x - radius, y: effect.at.y - radius * 0.42,
                        width: radius * 2, height: radius * 0.84
                    )),
                    with: .color(tint.opacity(fade)),
                    lineWidth: max(0.6, 2.2 * (1 - t))
                )
            case .mote(let angle, let radius):
                // Round once and settle: the swirl decays as it goes, so the
                // mote spirals inward and drops rather than orbiting forever.
                let sweep = angle + t * .pi * 2
                let out = radius * (1 - t * 0.45)
                let x = size.width / 2 + cos(sweep) * out
                let y = size.height * 0.42 + sin(sweep) * out * 0.5 + t * t * 90
                canvas.fill(
                    Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                    with: .color(tint.opacity((1 - t) * 0.5))
                )
            case .petal(let driftX, let spin):
                let x = effect.at.x + driftX * t * 90 + sin(t * .pi * 3 + spin) * 10
                let y = effect.at.y + t * t * 120 - 12
                let squash = 0.5 + 0.5 * abs(sin(t * .pi * 4 + spin))
                canvas.fill(
                    Path(ellipseIn: CGRect(
                        x: x - 3, y: y - 3 * squash, width: 6, height: 6 * squash
                    )),
                    with: .color(accent.opacity((1 - t) * 0.75))
                )
            }
        }

        if let firefly {
            draw(firefly, in: &canvas, now: now)
        }
    }

    private func draw(_ firefly: Firefly, in canvas: inout GraphicsContext, now: Date) {
        let age = now.timeIntervalSince(firefly.born)
        var point = firefly.target

        // Once let go she drifts off on her own and dims out.
        var glow = 0.55 + 0.45 * sin(age * 3.1)
        if let released = firefly.releasedAt {
            let gone = now.timeIntervalSince(released)
            point.x += sin(gone * 1.4) * 34 + gone * 12
            point.y -= gone * 26
            glow *= max(0, 1 - gone / Self.fireflyFade)
        }
        guard glow > 0.02 else { return }

        // A soft halo under a hard dot: at four pixels that is the whole
        // difference between a firefly and a full stop.
        canvas.fill(
            Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)),
            with: .color(Theme.sunshine.opacity(glow * 0.18))
        )
        canvas.fill(
            Path(ellipseIn: CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)),
            with: .color(Theme.sunshine.opacity(min(1, glow)))
        )
    }

    // MARK: Model

    private struct Effect: Identifiable {
        enum Kind {
            case ring
            case petal(driftX: Double, spin: Double)
            /// One mote of the snow-globe swirl. `angle` is where it starts on
            /// the circle and `radius` how far out it sits.
            case mote(angle: Double, radius: Double)
        }

        var id: Int = 0
        let kind: Kind
        let at: CGPoint
        let born: Date
        let life: TimeInterval
    }

    private struct Firefly {
        var target: CGPoint
        let born: Date
        /// Set when the finger lifts. From then on she leaves.
        var releasedAt: Date?

        init(at point: CGPoint, born: Date) {
            self.target = point
            self.born = born
        }
    }
}
