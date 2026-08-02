import SwiftUI

/// A wildlife appearance scheduled inside one focus phase.
///
/// Stored as two points on the progress bar rather than as dates, so the whole
/// thing stays a pure function of `engine.progress`: no timer, no state to get
/// out of step, and the animal is guaranteed to have left before the chime.
struct Sighting: Equatable {
    let species: Species
    /// Fractions of the phase. Both well short of 1 — the last stretch belongs
    /// to the countdown, not to a distraction.
    let start: Double
    let end: Double

    init(species: Species) {
        self.species = species
        // A little scatter so two sessions in a row don't feel scripted.
        let begin = Double.random(in: 0.32...0.46)
        self.start = begin
        self.end = begin + 0.24
    }

    /// How far through the appearance we are, or nil if it isn't on screen.
    func phase(at progress: Double) -> Double? {
        guard progress >= start, progress <= end else { return nil }
        return (progress - start) / (end - start)
    }
}

/// Draws whatever is currently visiting.
///
/// Mounted only while a sighting is on screen, so there is no canvas and no
/// timeline running for the other 76% of a session.
struct WildlifeView: View {
    let species: Species
    /// 0...1 across the appearance.
    let phase: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()

    /// Two frames is the whole animation — a wingbeat, a step, a tail flick.
    private let framesPerSecond: Double = 6

    var body: some View {
        GeometryReader { geometry in
            sprite
                .frame(width: species.size.width, height: species.size.height)
                .opacity(fade)
                .position(
                    x: geometry.size.width * offset.x,
                    y: geometry.size.height * species.altitude + offset.y
                )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var sprite: some View {
        if reduceMotion {
            image(named: species.frames[0])
        } else {
            TimelineView(.periodic(from: .now, by: 1 / framesPerSecond)) { context in
                let tick = Int(context.date.timeIntervalSince(started) * framesPerSecond)
                image(named: species.frames[tick % species.frames.count])
            }
        }
    }

    private func image(named name: String) -> some View {
        Image(name)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            // Facing: everything is drawn heading right, so a leftward
            // traveller is mirrored rather than drawn twice.
            .scaleEffect(x: travelsLeft ? -1 : 1, y: 1)
    }

    /// Fades in and out at the edges so nothing ever pops.
    private var fade: Double {
        let edge = 0.16
        if phase < edge { return phase / edge }
        if phase > 1 - edge { return (1 - phase) / edge }
        return 1
    }

    private var travelsLeft: Bool {
        switch species.motion {
        case .flutter, .arc: false
        case .hop, .linger: true
        }
    }

    /// Where the animal is, as a fraction of width plus a vertical nudge.
    private var offset: (x: Double, y: Double) {
        let t = min(max(phase, 0), 1)
        switch species.motion {
        case .flutter:
            // Crosses the whole width, wobbling like something with wings.
            return (-0.12 + t * 1.24, sin(t * .pi * 6) * 9)
        case .arc:
            // Crosses, rising and falling once: a dive, or a breach.
            return (-0.15 + t * 1.30, -sin(t * .pi) * 26)
        case .hop:
            // Works across a short stretch in bounces.
            return (0.78 - t * 0.52, -abs(sin(t * .pi * 5)) * 12)
        case .linger:
            // Simply present, drifting a little. The stag doesn't perform.
            return (0.70 - t * 0.16, sin(t * .pi * 2) * 3)
        }
    }
}
