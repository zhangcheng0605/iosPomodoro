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
    @State private var touch = TouchTracker.shared

    private let spriteSize: CGFloat = 104

    private var buddy: Buddy { engine.settings.buddy }

    private var name: String { engine.settings.displayName(for: buddy) }

    private var dayPart: DayPart {
        LaunchOptions.forcedDayPart ?? DayPart.current()
    }

    private var isAtHome: Bool { engine.settings.place == buddy.homePlace }

    /// What this buddy has on. Per buddy, so switching to the owl and back
    /// finds the cat still in her hat.
    private var outfit: [Accessory] { engine.settings.outfit(for: buddy) }

    /// Whether the buddy is asleep *right now* — which the owl inverts after
    /// dark. Drives the zzz, the petting response and the caption.
    private var isNapping: Bool {
        restingPose == .napping
    }

    /// The resting animation, from the phase, the place and the hour.
    ///
    /// Reads as a pile of conditions because it is one: three quirks all land
    /// on the same property. The order matters — the nocturnal flip outranks
    /// everything, then the running phase, and home turf only shows when
    /// nothing else is happening.
    private var restingPose: BuddyPose {
        let focusRunning = engine.isRunning && !engine.phase.isBreak
        let breakRunning = engine.isRunning && engine.phase.isBreak
        let night = dayPart == .night
        let nocturnal = buddy.isNocturnal

        if focusRunning {
            // A nocturnal buddy is awake through a night session; everyone
            // else — and Luna in daylight — naps through focus as usual.
            return (nocturnal && night) ? .watching : .napping
        }
        if breakRunning {
            if nocturnal { return night ? .idle : .napping }
            return buddy.breakFrame != nil ? .soaking : .idle
        }
        // Idle. Home turf shows only when it doesn't contradict the buddy's own
        // clock: Luna's home pose *is* her night watch, so showing it at noon
        // would undo the one quirk that makes her different.
        if isAtHome, buddy.homeFrame != nil, !nocturnal || night {
            return .atHome
        }
        return .idle
    }

    /// How far through the dream's slice of the session we are, so the bubble
    /// can fade in and out at its own edges. A pure function of progress, like
    /// a sighting: no timer, and it is always gone before the chime.
    private var dreamPhase: Double {
        let window = TimerEngine.dreamWindow
        let span = window.upperBound - window.lowerBound
        guard span > 0 else { return 0.5 }
        return min(1, max(0, (engine.progress - window.lowerBound) / span))
    }

    /// From stage four the stray sits beside your buddy through a break — the
    /// first time the two of them are in the same frame, and the beat that
    /// makes her joining feel inevitable rather than granted.
    ///
    /// Suppressed when she *is* the buddy: Soot cannot sit next to herself.
    private var strayIsAlongside: Bool {
        engine.strayStage >= .beside
            && buddy != .stray
            && engine.isRunning
            && engine.phase.isBreak
    }

    var body: some View {
        VStack(spacing: 8) {
            // The zzz and the hearts live inside the buddy's own cell, not the
            // row: when the stray sits down the buddy shifts left to make room,
            // and effects anchored to the row would be left hanging beside it.
            HStack(spacing: 6) {
                ZStack {
                    sprite
                        .contentShape(Rectangle())
                        .gesture(petGesture)

                    if isNapping {
                        zzz
                            .offset(x: spriteSize * 0.36, y: -spriteSize * 0.30)
                            .transition(.opacity)
                    }

                    // The `isNapping` gate is the whole of the "only while
                    // asleep" rule, and it is why Luna dreams through her
                    // daytime naps rather than her night watch — no special
                    // case, just the pose she is already in.
                    if isNapping, let dream = engine.visibleDream {
                        DreamBubble(dream: dream, phase: dreamPhase)
                            .offset(x: -spriteSize * 0.42, y: -spriteSize * 0.52)
                            .transition(.opacity)
                    }

                    ForEach(hearts) { heart in
                        HeartParticle(drift: heart.drift, reduceMotion: reduceMotion)
                            .offset(y: -spriteSize * 0.22)
                    }
                }

                if strayIsAlongside {
                    // Smaller, and she keeps a little distance: she is sitting
                    // *beside* your buddy, not replacing it. No gesture on her
                    // either — she isn't yours to pet yet.
                    BuddySprite(
                        buddy: .stray,
                        assetName: Buddy.stray.frame("awake"),
                        size: spriteSize * 0.62
                    )
                    .transition(.opacity)
                    .accessibilityHidden(true)
                }
            }
            .animation(.easeInOut, value: isNapping)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: strayIsAlongside)

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
        .accessibilityAction(named: isNapping ? "Check on \(name)" : "Pet \(name)") {
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
                sleeping: isNapping,
                outfit: outfit
            )
        } else {
            TimelineView(.periodic(from: .now, by: tickInterval)) { context in
                BuddySprite(
                    buddy: buddy,
                    assetName: frameName(at: context.date),
                    size: spriteSize,
                    outfit: outfit,
                    sleeping: isNapping
                )
            }
            // A `TimelineView` keeps the schedule it was built with, so without
            // a new identity the 8fps burst would still be sampled at the 4fps
            // idle rate and drop half its frames.
            .id(tickInterval)
        }
    }

    /// The frame to draw, with one thing layered over the animator: an awake
    /// buddy watches your finger.
    ///
    /// Deliberately outranked by everything else. A one-shot — a bounce, a
    /// stir, a wake-up — is a thing the buddy is *doing*, and a glance is only
    /// where it happens to be looking.
    private func frameName(at date: Date) -> String {
        if let x = touch.x, !isNapping, !animator.isPlayingTransient(at: date) {
            return buddy.frame(x < 0.5 ? "look_l" : "look_r")
        }
        return animator.frameName(for: buddy, at: date)
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

    /// What to call her. She belongs to nobody until the naming moment, so
    /// before that she is only ever "the stray" — giving her a name early
    /// would be the app deciding something the player hasn't yet.
    private var strayName: String {
        engine.stray.hasJoined
            ? engine.settings.displayName(for: .stray)
            : "the stray"
    }

    private var caption: String {
        if animator.isPlayingTransient(at: Date()), isNapping {
            return "shhh — \(name) is dreaming"
        }
        // Ahead of everything else, because it is the rarest thing this line
        // ever says: eight of these in a lifetime of the app, against a soak
        // every other break. It lasts the one break and is then gone for good.
        if let resident = engine.residentArrived {
            return "\(name) has noticed — \(resident.arrivalLine)"
        }
        // Said once, the first time a thing is worn, and then never again —
        // an accessory that keeps being remarked on is an accessory you take
        // off. Cleared as soon as the caption has had a turn.
        if let wearing = engine.justWore {
            return "\(name) \(wearing.firstWornLine)"
        }
        // Ahead of the quirk poses on purpose: a soak happens every other
        // break, and the two of them sitting together is the payoff of a
        // fortnight. One caption for two sprites, so it reads as one moment.
        if strayIsAlongside {
            return "\(name) has company — \(strayName) sat down too"
        }
        // The quirks get their own lines: a pose nobody comments on reads like
        // a rendering mistake rather than a personality.
        switch restingPose {
        case .watching:
            return "\(name) keeps watch — owls work nights"
        case .soaking:
            return "\(name) \(buddy.breakRemark ?? "is having a soak")"
        case .atHome:
            return "\(name) is exactly where they want to be"
        default:
            break
        }
        switch engine.runState {
        case .idle:
            // A preset nobody remarks on is a settings change; one the cat
            // notices is a decision about the afternoon. Classic is the
            // default and passes without comment.
            if let expedition = Expedition.matching(engine.settings),
               expedition != .classic {
                return "\(name) is waiting — \(expedition.remark)"
            }
            return isAtHome
                ? "\(name) is home — \(engine.settings.place.name)"
                : "\(name) is waiting for you"
        case .running:
            return engine.phase.isBreak
                ? "\(name) is up and about — enjoy your break"
                : "Don't wake \(name) — stay focused!"
        case .paused:
            return "\(name) wonders where you went…"
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
