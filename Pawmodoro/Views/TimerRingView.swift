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

    /// While idle the ring shows how long the phase is, as a share of the range
    /// it can be set to. While running it shows how much of it is left.
    private var trim: Double {
        guard isAdjustable else { return engine.progress }
        let range = PomodoroSettings.range(for: phase)
        let span = Double(range.upperBound - range.lowerBound)
        guard span > 0 else { return 0 }
        return (Double(minutes - range.lowerBound) / span).clamped01()
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.bark.opacity(0.12), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(trim, 0.001))
                .stroke(
                    Theme.accent(for: phase),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: engine.progress)
                .animation(.spring(duration: 0.25), value: minutes)

            if isAdjustable {
                knob
            }

            VStack(spacing: 4) {
                Text(engine.remainingText)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
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
            .rotationEffect(.degrees(trim * 360))
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
        let buddy = engine.settings.buddy.name
        switch engine.runState {
        case .idle:
            return isAdjustable ? "drag the ring to set \(phase.dialNoun)" : "ready when you are"
        case .running:
            if phase.isBreak {
                return engine.settings.breatheOnBreaks
                    ? "breathe with \(buddy)"
                    : "stretch those paws!"
            }
            return "shhh… \(buddy) is napping"
        case .paused:
            return "paused"
        }
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
