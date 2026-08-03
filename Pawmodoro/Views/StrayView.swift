import SwiftUI

/// The stray, out in the scene, for the three stages before she is close
/// enough to sit beside your buddy.
///
/// Whether she is on screen is a pure function of `engine.progress` and her
/// stage, in the same way a sighting is: no timer, nothing to fall out of step,
/// and she is always gone before the chime. What she *isn't* is a progress bar
/// — her distance, her size and how long she stays are the only readout of the
/// arc that exists anywhere in the app, and that is deliberate.
struct StrayView: View {
    let stage: Stray.Stage
    /// Nil while nothing is running, which is how the later stages know to
    /// simply wait around instead of riding a phase.
    let progress: Double?
    /// Set when she has been spooked this phase. Not persisted anywhere:
    /// nothing about her can be lost, so this lasts until the phase does.
    @Binding var spooked: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = Date()

    /// Slow — she is holding still. The tail flick is the whole animation.
    private let framesPerSecond: Double = 1.4

    var body: some View {
        GeometryReader { geometry in
            if let frames = stage.sceneFrames, isPresent, !spooked {
                sprite(frames: frames)
                    .frame(width: stage.size.width, height: stage.size.height)
                    .opacity(fade)
                    // The touch area is padded out to the 44pt minimum around
                    // her without the sprite growing: at her shyest she is a
                    // 20x10 smudge, and a target that size isn't one.
                    .frame(minWidth: 44, minHeight: 44)
                    // Hit testing has to be settled *before* `.position`, which
                    // expands to fill the whole parent. A `contentShape` after
                    // it would make this entire layer one screen-sized tap
                    // target sitting over the controls.
                    .contentShape(Rectangle())
                    .onTapGesture { touched() }
                    .accessibilityElement()
                    .accessibilityLabel(spokenLabel)
                    .accessibilityAddTraits(.isButton)
                    // Feet on the ground line, whatever size this stage is
                    // drawn at — see `Stray.groundLine`. The sprite is centred
                    // inside the 44pt box, so placing the box's centre places
                    // hers.
                    .position(
                        x: geometry.size.width * stage.x,
                        y: geometry.size.height * Stray.groundLine
                            - stage.size.height / 2
                    )
                    // So being spooked reads as leaving rather than as a
                    // rendering glitch. Under Reduce Motion `touched()` sets
                    // the flag without an animation, so this cuts instead.
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: What she does

    @ViewBuilder
    private func sprite(frames: [String]) -> some View {
        if reduceMotion || frames.count == 1 {
            image(named: frames[0])
        } else {
            TimelineView(.periodic(from: .now, by: 1 / framesPerSecond)) { context in
                // A flick every eighth beat rather than a metronome: a cat that
                // twitches on a rhythm reads as a machine.
                let tick = Int(context.date.timeIntervalSince(appeared) * framesPerSecond)
                image(named: frames[tick.isMultiple(of: 8) ? 1 : 0])
            }
        }
    }

    private func image(named name: String) -> some View {
        Image(name)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            // Drawn with her tail to the right, so on the right of the screen
            // she is mirrored: tail toward the edge, cat facing in.
            .scaleEffect(x: stage.x < 0.5 ? 1 : -1, y: 1)
    }

    /// A hand near her. At the edge of the scene she leaves; once she is
    /// sitting and watching she stays, which is the trust made visible and the
    /// only feedback the arc ever gives.
    private func touched() {
        guard stage.spooks else {
            HapticsDirector.shared.nudge()
            return
        }
        // Reduce Motion gets the cut rather than the fade — same outcome,
        // no travel.
        if reduceMotion {
            spooked = true
        } else {
            withAnimation(.easeOut(duration: 0.55)) { spooked = true }
        }
        HapticsDirector.shared.nudge()
    }

    // MARK: Presence

    /// Early on she looks in for a moment in the middle of a session; by the
    /// time she is watching she stays for nearly all of it, and waits between
    /// them. Dwell time is the other half of the arc.
    private var isPresent: Bool {
        guard let progress else { return stage.showsWhenIdle }
        return stage.window.contains(progress)
    }

    /// Never pops. Fades across the first and last fifth of her window; under
    /// Reduce Motion she is simply there or simply not.
    private var fade: Double {
        guard !reduceMotion else { return 1 }
        guard let progress else { return 1 }
        let window = stage.window
        let span = window.upperBound - window.lowerBound
        guard span > 0 else { return 1 }
        let t = (progress - window.lowerBound) / span
        let edge = 0.18
        if t < edge { return max(0, t / edge) }
        if t > 1 - edge { return max(0, (1 - t) / edge) }
        return 1
    }

    private var spokenLabel: String {
        switch stage {
        case .eyes: "Something is watching from the hedge"
        case .edge: "A stray cat, at the edge of the scene"
        case .watching: "A stray cat, sitting and watching you"
        case .away, .beside, .home: ""
        }
    }
}

/// The moment she comes inside.
///
/// Deliberately the plainest sheet in the app: no confetti, no badge, no
/// "achievement unlocked". She waited two weeks to walk up to you, and the
/// right response to that is a name and a door, not a fanfare.
struct StrayNamingSheet: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    @State private var name = Buddy.stray.name

    var body: some View {
        VStack(spacing: 22) {
            BuddySprite(buddy: .stray, sleeping: false, size: 132)

            VStack(spacing: 8) {
                Text("She's still here.")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.bark)
                Text("She's been watching you focus for a couple of weeks. "
                     + "Today she walked up.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.bark.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)

            TextField(Buddy.stray.name, text: $name)
                .font(.title3)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Capsule().fill(Theme.surface.opacity(0.7)))
                .padding(.horizontal, 40)

            Button {
                letHerIn()
            } label: {
                Text("Let her in")
                    .font(.headline)
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.blossom))
            }
            .buttonStyle(.squishy)
            .padding(.horizontal, 40)

            Text("She's yours. No purchase, nothing to finish — you just kept "
                 + "turning up.")
                .font(.caption)
                .foregroundStyle(Theme.bark.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cream)
        // No cancel, and not dismissable by dragging: there is exactly one
        // outcome here, and it is a good one.
        .interactiveDismissDisabled()
    }

    private func letHerIn() {
        // Through `setName` like every other rename, so an empty field or the
        // default goes back to "Soot" and the name reaches the notifications
        // and the tip jar the same way any other buddy's does.
        engine.settings.setName(name, for: .stray)
        engine.stray.join()
        engine.settings.buddy = .stray
        HapticsDirector.shared.complete()
        dismiss()
    }
}

#Preview("Stages") {
    VStack(spacing: 0) {
        ForEach([Stray.Stage.eyes, .edge, .watching], id: \.rawValue) { stage in
            StrayView(stage: stage, progress: 0.5, spooked: .constant(false))
                .frame(height: 160)
                .background(Theme.sage.opacity(0.3))
        }
    }
}
