import SwiftUI

/// The countdown ring — and, while the timer is idle, the dial that sets how
/// long the phase runs.
///
/// Dragging is measured as a *change* in angle rather than an absolute one.
/// Absolute mapping has to decide what happens at twelve o'clock, where the
/// shortest and longest durations meet, and every answer to that is a surprise
/// under your thumb. Accumulating deltas has no seam.
struct TimerRingView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fractional minutes held while a drag is in flight, so slow drags don't
    /// lose the part of a detent they haven't earned yet.
    @State private var pendingMinutes: Double?
    @State private var lastAngle: Angle?
    @State private var breathing = false

    private let lineWidth: CGFloat = 18
    private let diameter: CGFloat = 260
    /// One detent per 18° — twenty around the ring, which is a comfortable
    /// throw for a thumb without being twitchy.
    private let degreesPerDetent: Double = 18

    private var isAdjustable: Bool { engine.runState == .idle }

    private var phase: TimerEngine.Phase { engine.phase }

    private var minutes: Int { engine.settings.minutes(for: phase) }

    /// How long the phase is, as a share of the range it can be set to. This is
    /// what the dial shows while the timer is idle.
    private var durationTrim: Double {
        let range = PomodoroSettings.range(for: phase)
        let span = Double(range.upperBound - range.lowerBound)
        guard span > 0 else { return 0 }
        return (Double(minutes - range.lowerBound) / span).clamped01()
    }

    /// Rings are drawn from the outside in and stop at eight, which is three
    /// and a bit hours. Past that they would be closer together than the
    /// stroke is wide, and a solid disc says less than eight rings do.
    private var maxRings: Int { 8 }

    @ViewBuilder
    private var treeRings: some View {
        if engine.isDrifting {
            let rings = min(engine.driftLaps, maxRings)
            ForEach(0..<max(rings, 0), id: \.self) { index in
                Circle()
                    .stroke(
                        Theme.accent(for: phase).opacity(0.30),
                        lineWidth: 1.5
                    )
                    .padding(lineWidth + 6 + CGFloat(index) * 7)
            }
            .transition(.opacity)
        }
    }

    var body: some View {
        ZStack {
            // The timer face. Once there is scenery behind the app, the
            // countdown can no longer rely on the background being a known
            // colour — so it brings its own. It also just looks better: a
            // frosted dial floating over a landscape rather than text lying
            // on top of it.
            Circle()
                .fill(Theme.cream.opacity(0.82))
                .padding(lineWidth / 2)

            Circle()
                .stroke(Theme.bark.opacity(0.12), lineWidth: lineWidth)

            // Two arcs rather than one that changes meaning. Sharing a single
            // arc between "how long this phase is" and "how much is left" made
            // it jump the moment you pressed play — from a third of the ring
            // down to nothing. Now the dial fades out as the countdown grows
            // in, and the handoff reads as one becoming the other.
            Circle()
                .trim(from: 0, to: max(durationTrim, 0.001))
                .stroke(
                    Theme.accent(for: phase).opacity(0.55),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(isAdjustable ? 1 : 0)
                .animation(.spring(duration: 0.25), value: minutes)

            Circle()
                .trim(from: 0, to: max(engine.progress, 0.001))
                .stroke(
                    Theme.accent(for: phase),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                // Faded rather than removed when another face is carrying the
                // time: two things counting the same interval at full strength
                // compete, and the ring is still the thing you can read from
                // across the room.
                .opacity(isAdjustable ? 0 : (engine.clockFace.isDrawn ? 1 : 0.3))
                .animation(.linear(duration: 0.25), value: engine.progress)

            // The chosen face, if it is not the ring. Drawn inside the dial
            // and *under* the digits, which stay exactly where they are on
            // their own capsule — swapping the face never moves the one thing
            // on this screen anybody actually reads.
            if !engine.clockFace.isDrawn {
                ClockFaceView(face: engine.clockFace, progress: engine.progress)
                    .frame(height: diameter * 0.46)
                    .offset(y: -diameter * 0.05)
                    .opacity(isAdjustable ? 0.35 : 1)
                    .allowsHitTesting(false)
            }

            // One thin concentric ring per completed lap, laid inside the
            // track. Two hours of deep work is five rings — time made visible
            // in the same language the Homestead's trees will use, and the
            // only record an open hour keeps of how long it has been.
            treeRings

            knob
                .opacity(isAdjustable ? 1 : 0)

            VStack(spacing: 4) {
                Text(engine.remainingText)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    // A countdown is always "25:00" — five glyphs, and 56pt is
                    // sized for exactly that. A *drift* counts up and grows an
                    // hours field at sixty minutes, and "1:16:05" is seven: it
                    // wrapped onto a second line, ran to the rim of the face
                    // and pushed the status line out from under it. One line,
                    // shrunk only as far as it has to be — a string that fits
                    // is never touched, so the ordinary countdown is drawn at
                    // 56pt exactly as before. The floor is generous enough for
                    // "99:59:59", which is more drift than anybody will sit.
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Theme.bark)
                    .contentTransition(.numericText())

                Text(statusLine)
                    .font(.subheadline)
                    .foregroundStyle(Theme.bark.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 36)
        }
        .frame(width: diameter, height: diameter)
        // Crossfading the two arcs is what removes the snap; both opacities
        // and the knob ride this one animation.
        .animation(.easeInOut(duration: 0.35), value: isAdjustable)
        .scaleEffect(breathingScale)
        .animation(breathAnimation, value: breathing)
        .contentShape(Circle())
        .gesture(dialGesture)
        .onChange(of: shouldBreathe) { _, active in breathing = active }
        .onAppear { breathing = shouldBreathe }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isAdjustable ? "\(minutes) minutes" : engine.remainingText)
        .accessibilityAdjustableAction { direction in
            // The drag gesture and the knob are both gated on `isAdjustable`;
            // without the same gate here, VoiceOver could re-length a phase
            // that is already counting down.
            guard isAdjustable else {
                HapticsDirector.shared.nudge()
                return
            }
            let step = PomodoroSettings.step(for: phase)
            switch direction {
            case .increment: commit(minutes + step)
            case .decrement: commit(minutes - step)
            @unknown default: break
            }
        }
    }

    // MARK: The dial

    /// Sits at the head of the arc, so there is something obviously grabbable.
    private var knob: some View {
        Circle()
            .fill(Theme.accent(for: phase))
            .frame(width: lineWidth + 6, height: lineWidth + 6)
            .overlay(Circle().stroke(Theme.onAccent.opacity(0.35), lineWidth: 2))
            .offset(y: -diameter / 2)
            .rotationEffect(.degrees(durationTrim * 360))
            .animation(.spring(duration: 0.25), value: minutes)
            .allowsHitTesting(false)
    }

    private var dialGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard isAdjustable else { return }
                let centre = CGPoint(x: diameter / 2, y: diameter / 2)
                let current = angle(of: value.location, around: centre)

                guard let previous = lastAngle else {
                    lastAngle = current
                    pendingMinutes = Double(minutes)
                    return
                }
                lastAngle = current

                let step = Double(PomodoroSettings.step(for: phase))
                let moved = shortestDegrees(from: previous, to: current)
                let base = pendingMinutes ?? Double(minutes)
                let range = PomodoroSettings.range(for: phase)

                let updated = (base + moved / degreesPerDetent * step)
                    .clamped(to: Double(range.lowerBound)...Double(range.upperBound))
                pendingMinutes = updated

                commit(Int((updated / step).rounded() * step))
            }
            .onEnded { _ in
                lastAngle = nil
                pendingMinutes = nil
            }
    }

    /// Writes through only on a real change, so the haptic fires once per
    /// detent rather than once per touch event.
    private func commit(_ newMinutes: Int) {
        // The real gate: every caller is already conditional, but a phase that
        // is running must never have its length changed underneath it.
        guard isAdjustable else { return }
        let range = PomodoroSettings.range(for: phase)
        let clamped = min(max(newMinutes, range.lowerBound), range.upperBound)
        guard clamped != minutes else { return }

        @Bindable var engine = engine
        engine.settings.setMinutes(clamped, for: phase)
        HapticsDirector.shared.detent()
    }

    private func angle(of point: CGPoint, around centre: CGPoint) -> Angle {
        Angle(radians: atan2(point.y - centre.y, point.x - centre.x))
    }

    /// Signed degrees between two angles, taking the short way round so a drag
    /// across twelve o'clock reads as a small move, not most of a revolution.
    private func shortestDegrees(from: Angle, to: Angle) -> Double {
        var delta = to.degrees - from.degrees
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return delta
    }

    // MARK: Breathing

    /// Breaks are for breathing. The ring swells and settles on a slow count,
    /// which is something to follow rather than just something to watch.
    private var shouldBreathe: Bool {
        engine.isRunning
            && phase.isBreak
            && engine.settings.breatheOnBreaks
            && !reduceMotion
    }

    private var breathingScale: CGFloat { breathing ? 1.035 : 1.0 }

    private var breathAnimation: Animation? {
        shouldBreathe
            ? .easeInOut(duration: 4.5).repeatForever(autoreverses: true)
            : .easeInOut(duration: 0.3)
    }

    // MARK: Copy

    private var statusLine: String {
        let buddy = engine.buddyName
        switch engine.runState {
        case .idle:
            return isAdjustable
                ? "drag the ring to set \(phase.dialNoun)"
                : "ready when you are"
        case .running:
            // No count, no target, no comparison with anything. The rings say
            // how long it has been; this only says what is happening.
            if engine.isDrifting {
                return engine.driftLaps == 0
                    ? "drifting — hold to come back"
                    : "still going. hold to come back"
            }
            if phase.isBreak {
                return engine.settings.breatheOnBreaks
                    ? "breathe with \(buddy)"
                    : "stretch those paws!"
            }
            // A nocturnal buddy is awake through a night session, so the ring
            // must not insist it's asleep while the caption below says it isn't.
            if engine.settings.buddy.isNocturnal, nightOutside {
                return "\(buddy) is wide awake"
            }
            return "shhh… \(buddy) is napping"
        case .paused:
            return "paused"
        }
    }

    private var nightOutside: Bool {
        (LaunchOptions.forcedDayPart ?? DayPart.current()) == .night
    }

    private var accessibilityLabel: String {
        isAdjustable
            ? "\(phase.title) length"
            : "\(phase.title), \(engine.remainingText) remaining"
    }
}

private extension TimerEngine.Phase {
    /// Used in the hint under the countdown while the ring is a dial.
    var dialNoun: String {
        switch self {
        case .focus: "your focus"
        case .shortBreak: "your break"
        case .longBreak: "your long break"
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }

    func clamped01() -> Double { clamped(to: 0...1) }
}

#Preview {
    TimerRingView()
        .environment(TimerEngine())
        .padding()
        .background(Theme.cream)
}
