import SwiftUI

/// The companion beside the timer. Naps through focus, sits up otherwise, and
/// answers when you touch it.
struct BuddyView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animator = BuddyAnimator()
    @State private var hearts: [Heart] = []
    @State private var heartSeed = 0
    @State private var lastPet = Date.distantPast

    private let spriteSize: CGFloat = 104

    private var buddy: Buddy { engine.settings.buddy }

    private var isNapping: Bool {
        engine.isRunning && !engine.phase.isBreak
    }

    private var restingPose: BuddyPose { isNapping ? .napping : .idle }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                sprite
                    .contentShape(Rectangle())
                    .gesture(petGesture)

                if isNapping {
                    zzz
                        .offset(x: spriteSize * 0.36, y: -spriteSize * 0.30)
                        .transition(.opacity)
                }

                ForEach(hearts) { heart in
                    HeartParticle(drift: heart.drift, reduceMotion: reduceMotion)
                        .offset(y: -spriteSize * 0.22)
                }
            }
            .animation(.easeInOut, value: isNapping)

            Text(caption)
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                // Its own backing, for the same reason the timer face has one:
                // there is scenery behind this now, and it can be any colour.
                .background(Capsule().fill(Theme.cream.opacity(0.78)))
                .animation(.easeInOut, value: caption)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: isNapping ? "Check on \(buddy.name)" : "Pet \(buddy.name)") {
            pet()
        }
        .onAppear { animator.setBase(restingPose) }
        .onChange(of: restingPose) { _, pose in animator.setBase(pose) }
        .onChange(of: engine.completion) { _, completion in
            // The payoff for *finishing* a focus session: the buddy opens its
            // eyes, stretches, and is pleased with you. Driven by the
            // completion event rather than the phase change, because skipping
            // a session also moves focus -> break and must earn nothing.
            guard let completion, completion.finished == .focus, !reduceMotion
            else { return }
            animator.play(.waking, for: buddy)
        }
    }

    // MARK: Sprite

    @ViewBuilder
    private var sprite: some View {
        if reduceMotion {
            // No timeline at all: one still frame of the resting pose.
            BuddySprite(
                buddy: buddy,
                assetName: BuddyFrames.name(for: buddy, pose: restingPose, elapsed: 0),
                size: spriteSize,
                sleeping: isNapping
            )
        } else {
            TimelineView(.periodic(from: .now, by: tickInterval)) { context in
                BuddySprite(
                    buddy: buddy,
                    assetName: animator.frameName(for: buddy, at: context.date),
                    size: spriteSize,
                    sleeping: isNapping
                )
            }
            // A `TimelineView` keeps the schedule it was built with, so without
            // a new identity the 8fps burst would still be sampled at the 4fps
            // idle rate and drop half its frames.
            .id(tickInterval)
        }
    }

    /// Follows whichever pose is on screen, so a slow breathing loop doesn't
    /// keep ticking at the rate a finished bounce needed.
    private var tickInterval: TimeInterval {
        animator.resolved(at: Date()).pose.frameInterval
    }

    private var zzz: some View {
        Image("fx_zzz")
            .renderingMode(.template)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 30, height: 30)
            .foregroundStyle(Theme.bark.opacity(0.45))
            .modifier(DriftUp(active: !reduceMotion))
    }

    // MARK: Petting

    private var petGesture: some Gesture {
        // A zero-distance drag catches both a tap and a stroke; strokes keep
        // firing on a throttle so scratching the buddy stays rewarding.
        DragGesture(minimumDistance: 0)
            .onChanged { _ in pet(throttle: 0.4) }
    }

    private func pet(throttle: TimeInterval = 0.25) {
        let now = Date()
        guard now.timeIntervalSince(lastPet) > throttle else { return }
        lastPet = now

        if isNapping {
            // Mid-focus: the buddy stirs but never wakes. No penalty, no guilt.
            animator.play(.stirring, for: buddy)
            HapticsDirector.shared.nudge()
            return
        }

        animator.play(.happy, for: buddy)
        HapticsDirector.shared.purr()
        SoundPlayer.shared.playPurr()
        addHeart()
    }

    private func addHeart() {
        heartSeed += 1
        // Spread successive hearts left and right of centre instead of stacking.
        let drift = CGFloat((heartSeed % 5) - 2) * 11
        let heart = Heart(id: heartSeed, drift: drift)
        hearts.append(heart)
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            hearts.removeAll { $0.id == heart.id }
        }
    }

    private struct Heart: Identifiable, Equatable {
        let id: Int
        let drift: CGFloat
    }

    // MARK: Caption

    private var caption: String {
        if animator.isPlayingTransient(at: Date()), isNapping {
            return "shhh — \(buddy.name) is dreaming"
        }
        switch engine.runState {
        case .idle:
            return "\(buddy.name) is waiting for you"
        case .running:
            return engine.phase.isBreak
                ? "\(buddy.name) is up and about — enjoy your break"
                : "Don't wake \(buddy.name) — stay focused!"
        case .paused:
            return "\(buddy.name) wonders where you went…"
        }
    }
}

/// One heart rising off the buddy when it's petted.
private struct HeartParticle: View {
    let drift: CGFloat
    let reduceMotion: Bool
    @State private var rising = false

    var body: some View {
        Image("fx_heart")
            .renderingMode(.template)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .foregroundStyle(Theme.blossom)
            // Under Reduce Motion the heart stays put and just fades: the
            // acknowledgement survives, the travel doesn't.
            .offset(x: reduceMotion ? 0 : (rising ? drift : 0),
                    y: reduceMotion ? -30 : (rising ? -58 : 0))
            .opacity(rising ? 0 : 0.95)
            .scaleEffect(reduceMotion ? 1 : (rising ? 1.25 : 0.7))
            .onAppear {
                withAnimation(.easeOut(duration: reduceMotion ? 0.8 : 1.1)) {
                    rising = true
                }
            }
            .allowsHitTesting(false)
    }
}

/// The slow rise-and-fade the "z z z" does above a sleeping buddy.
private struct DriftUp: ViewModifier {
    let active: Bool
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -6 : 2)
            .opacity(active ? (up ? 0.25 : 0.9) : 0.7)
            .animation(
                active ? .easeInOut(duration: 2.2).repeatForever(autoreverses: true) : nil,
                value: up
            )
            .onAppear { if active { up = true } }
    }
}

#Preview {
    BuddyView()
        .environment(TimerEngine())
        .padding()
        .background(Theme.cream)
}
