import SwiftUI

/// The companion beside the timer. Naps through focus, sits up otherwise, and
/// answers when you touch it.
struct BuddyView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var animator = BuddyAnimator()
    @State private var hearts: [Heart] = []
    @State private var heartSeed = 0
    @State private var lastPet = Date.distantPast
    @State private var touch = TouchTracker.shared
    /// A caption that outranks the computed one for a few seconds — the
    /// buddy's answer to a snack, a snub, a full belly.
    @State private var remark: String?
    /// While this contains now, the paw is up and a tap on the buddy is a
    /// high five rather than a pet.
    @State private var fiveWindow: ClosedRange<Date>?
    /// The moth vignette on screen, if one is.
    @State private var helloMoth: Hello?
    /// True through the first beats of the new-spot hello: the buddy is
    /// drawn asleep somewhere it usually isn't, then wakes.
    @State private var helloAsleep = false
    /// The peek hello slides the whole sprite in through this.
    @State private var helloOffset: CGSize = .zero
    /// The rare leaf hello: shown at the feet, never banked — the gesture
    /// is the gift.
    @State private var helloLeaf = false
    /// The trick machinery: a horizontal mirror scale (a flip through zero
    /// width reads as a paper-doll turn, and never breaks the pixel grid the
    /// way rotation would) and a travel offset for the leap.
    @State private var trickScaleX: CGFloat = 1
    @State private var trickOffset: CGSize = .zero
    /// The break's closing hunt: crouch from T-10, wiggle from T-3, pounce
    /// at zero. Pure function of the countdown; nothing persists.
    @State private var pounceStage: PounceStage = .none
    /// The batted second, mid-tumble.
    @State private var digitVisible = false
    @State private var digitOffset = CGSize(width: 0, height: -64)
    @State private var digitSpin: Double = 0
    @State private var digitFade: Double = 1
    /// Held eye contact, being answered.
    @State private var slowBlinking = false
    /// The pet gesture's hold-tracking, for telling a slow blink from a
    /// stroke: where the touch began, and whether it has wandered.
    @State private var petHoldBegan: Date?
    @State private var petHoldMoved = false

    private enum PounceStage { case none, crouch, wiggle, pounce }

    private let spriteSize: CGFloat = 104

    private var buddy: Buddy { engine.settings.buddy }

    private var name: String { engine.settings.displayName(for: buddy) }

    private var dayPart: DayPart {
        LaunchOptions.forcedDayPart ?? DayPart.current()
    }

    private var isAtHome: Bool { engine.settings.place == buddy.homePlace }

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

        // Tucked in outranks everything, including a break: a buddy under
        // the blanket sleeps through your rest as well as your work. It
        // releases a nocturnal buddy at night — Luna's bedtime is daybreak,
        // and the blanket never touches her watch.
        if isTuckedAsleep {
            return .napping
        }
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
            HStack(spacing: 10) {
                // The sill: one snack, waiting to be slid over. Out of reach
                // during focus, exactly like the toys.
                if let snack = sillSnack {
                    SnackSillChip(
                        snack: snack,
                        verdictForDrop: { snackVerdict() },
                        onLanded: { snackLanded($0) }
                    )
                    .transition(.opacity)
                }

                ZStack {
                    sprite
                        .scaleEffect(x: trickScaleX, y: 1)
                        .offset(trickOffset)
                        .offset(helloOffset)
                        .contentShape(Rectangle())
                        .gesture(petGesture)

                    if let helloMoth {
                        HelloMothView(
                            lands: helloMoth == .mothLands, spriteSize: spriteSize
                        )
                    }

                    // Yesterday, still attached. Tappable except during
                    // focus — a burr can wait twenty-five minutes.
                    if let burr = engine.doorstep.burr {
                        Button {
                            popBurr(burr)
                        } label: {
                            Image(burr.assetName)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                        .offset(
                            x: buddy.burrAnchor.width * spriteSize,
                            y: buddy.burrAnchor.height * spriteSize
                        )
                        .allowsHitTesting(!(engine.isRunning && !engine.phase.isBreak))
                        .transition(.opacity)
                        .task {
                            // Ignored long enough, the buddy shakes it off
                            // itself — nothing is ever left to nag.
                            try? await Task.sleep(nanoseconds: 90_000_000_000)
                            engine.doorstep.popBurr()
                        }
                    }

                    // What was carried home, set down at the feet. Tap to
                    // keep it.
                    if let find = visibleFind {
                        Button {
                            bankFind()
                        } label: {
                            Image(find.assetName)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                                .padding(6)
                                .background(Circle().fill(Theme.cream.opacity(0.85)))
                        }
                        .buttonStyle(.plain)
                        .offset(x: spriteSize * 0.46, y: spriteSize * 0.40)
                        .transition(.opacity)
                    } else if helloLeaf {
                        Image("keep_sprig")
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .offset(x: spriteSize * 0.46, y: spriteSize * 0.42)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }

                    // The blanket, over the sleeping buddy. All twelve
                    // asleep poses fill the lower half of the same grid, so
                    // one shared overlay drapes everyone.
                    if isTuckedAsleep {
                        Image(Season.current() == .winter
                              ? "fx_blanket_over_winter" : "fx_blanket_over")
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: spriteSize * 0.98)
                            .offset(y: spriteSize * 0.16)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }

                    if isNapping {
                        zzz
                            .offset(x: spriteSize * 0.36, y: -spriteSize * 0.30)
                            .transition(.opacity)
                    }

                    // The last second, batted off the clock — or getting
                    // away, one break in seven.
                    if digitVisible {
                        Text("0")
                            .font(.system(size: 20, weight: .bold, design: .rounded)
                                .monospacedDigit())
                            .foregroundStyle(Theme.bark)
                            .padding(6)
                            .background(Circle().fill(Theme.cream.opacity(0.9)))
                            .rotationEffect(.degrees(digitSpin))
                            .offset(digitOffset)
                            .opacity(digitFade)
                            .allowsHitTesting(false)
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

                    // An anniversary, held up in the dream bubble's spot —
                    // awake and idle, so the two can never collide. Tap to
                    // acknowledge; starting a session leaves it for later.
                    if engine.runState == .idle, let memory = engine.memories.today {
                        MemoryBubble(memory: memory)
                            .offset(x: -spriteSize * 0.42, y: -spriteSize * 0.52)
                            .transition(.opacity)
                            .onTapGesture { acknowledgeMemory() }
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

                // The blanket, folded and waiting, once the sun is down.
                if showsTuckChip {
                    TuckChip(starry: Season.current() == .winter) {
                        tuckNow()
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: isNapping)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: strayIsAlongside)
            .animation(.easeInOut(duration: 0.35), value: sillSnack)

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
        .accessibilityActions {
            // The drop without the drag: same verdict, same answer.
            if let snack = sillSnack {
                Button("Give \(name) \(snack.label)") {
                    snackLanded(snackVerdict())
                }
            }
            if showsTuckChip {
                Button("Tuck \(name) in") { tuckNow() }
            }
            if let fiveWindow, fiveWindow.contains(Date()) {
                Button("High five \(name)") { landFive() }
            }
            if let find = visibleFind {
                Button("Keep the \(find.name.lowercased())") { bankFind() }
            }
            if let burr = engine.doorstep.burr {
                Button("Brush off \(burr.label)") { popBurr(burr) }
            }
        }
        .onAppear { animator.setBase(restingPose) }
        .onChange(of: restingPose) { _, pose in animator.setBase(pose) }
        .onChange(of: engine.completion) { _, completion in
            // The payoff for *finishing* a focus session: the buddy opens its
            // eyes, stretches, and is pleased with you. Driven by the
            // completion event rather than the phase change, because skipping
            // a session also moves focus -> break and must earn nothing.
            guard let completion, completion.finished == .focus else { return }
            if !reduceMotion {
                animator.play(.waking, for: buddy)
            }
            openFiveWindow()
            // A mastered trick joins the celebration — once the stretch and
            // the paw have had their moment.
            if let trick = engine.repertoire.celebrationTrick(
                for: buddy, day: Snack.dayNumber(for: Date())
            ) {
                Task {
                    try? await Task.sleep(nanoseconds: 6_200_000_000)
                    if engine.runState == .idle {
                        engine.repertoire.showOff(trick, tier: Repertoire.masteredTier)
                    }
                }
            }
        }
        .onChange(of: engine.repertoire.attempt) { _, attempt in
            guard let attempt else { return }
            performTrick(attempt)
        }
        .onChange(of: engine.remaining) { _, remaining in
            advancePounce(remaining: remaining)
        }
        .onChange(of: engine.drawnSlip) { _, slip in
            // The slip reads itself out as the session settles in. The
            // remark outranks the focus caption for a few breaths, then the
            // paper corner on the phase chip carries it for the day.
            guard let slip else { return }
            say("the slip says: \(slip.grade). And that \(slip.line)", for: 8)
        }
        .task {
            greetTheMorning()
            // `-PawmodoroTrick spin.2`: play the pinned trick soon after
            // launch, because the pane can't draw a clean circle.
            if let preview = engine.forcedTrickPreview {
                engine.forcedTrickPreview = nil
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                engine.repertoire.showOff(preview.trick, tier: preview.tier)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // The morning's small events can only arrive on the first look
            // of the day, and an app left in memory overnight re-enters here
            // rather than through launch. The short wait lets the engine's
            // own foreground pass decide the new day first.
            guard phase == .active else { return }
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                greetTheMorning()
            }
        }
    }

    /// One small event per look, in a strict order: a homecoming outranks
    /// everything (someone is at the door), evidence of the night outranks
    /// a live hello (which keeps for the day's next look), and the
    /// blanket's thank-you rides over the caption either way.
    private func greetTheMorning() {
        if let letter = engine.claimArrivedLetter() {
            let traveler = Buddy(rawValue: letter.buddy)
                .map { engine.settings.displayName(for: $0) } ?? "someone"
            let from = Place(rawValue: letter.place)?.name ?? "somewhere"
            say("\(traveler) is back from \(from) — a letter and something "
                + "for the drawer", for: 7)
        } else if let visit = engine.claimNightVisit() {
            var line = NightCaller.evidence(for: visit.species, snack: visit.snack)
            if visit.memento != nil {
                line += ". It left something — it's in the drawer"
            }
            say(line, for: 7)
        } else {
            playHello()
        }
        revealMorningIfDue()
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
                    assetName: frameName(at: context.date),
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

    /// The frame to draw, with two things layered over the animator: a
    /// raised paw when a five is on offer, and an awake buddy watching your
    /// finger.
    ///
    /// The glance is deliberately outranked by everything else. A one-shot —
    /// a bounce, a stir, a wake-up — is a thing the buddy is *doing*, and a
    /// glance is only where it happens to be looking.
    private func frameName(at date: Date) -> String {
        // The new-spot hello opens on a buddy asleep somewhere new; the
        // wake-up that follows is the vignette's whole plot.
        if helloAsleep {
            return buddy.frame("asleep")
        }
        // The slow blink holds the half-lidded frame — the existing blink
        // art, just given time to mean something.
        if slowBlinking {
            return buddy.frame("awake_blink")
        }
        if !animator.isPlayingTransient(at: date), pawRaised(at: date) {
            // The raised bounce frame stands in for buddies whose paw-up
            // hasn't been drawn yet — up on the toes, expectant.
            return buddy.pawUpFrame ?? buddy.frame("happy_1")
        }
        if let x = touch.x, !isNapping, !animator.isPlayingTransient(at: date) {
            return buddy.frame(x < 0.5 ? "look_l" : "look_r")
        }
        return animator.frameName(for: buddy, at: date)
    }

    // MARK: The doorstep

    /// The find at the feet, out of reach during focus like everything else.
    private var visibleFind: Keepsake? {
        guard !(engine.isRunning && !engine.phase.isBreak) else { return nil }
        return engine.doorstep.find
    }

    /// Play today's greeting, if it hasn't played. Once per day: claiming
    /// clears it, and the doorstep won't deal a second one until tomorrow.
    private func playHello() {
        guard let hello = engine.doorstep.claimHello() else { return }
        say(hello.caption(name), for: 6)
        guard !reduceMotion else { return }
        switch hello {
        case .bigStretch:
            animator.play(.waking, for: buddy)
        case .shake:
            animator.play(.happy, for: buddy)
        case .mothChase, .mothLands:
            helloMoth = hello
            Task {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                helloMoth = nil
            }
        case .peek:
            helloOffset = CGSize(width: -46, height: 0)
            withAnimation(.spring(duration: 0.8, bounce: 0.3)) {
                helloOffset = .zero
            }
        case .newSpot:
            helloAsleep = true
            Task {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                helloAsleep = false
                animator.play(.waking, for: buddy)
            }
        case .leafGift:
            withAnimation(.easeInOut(duration: 0.4)) { helloLeaf = true }
            Task {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                withAnimation(.easeInOut(duration: 0.8)) { helloLeaf = false }
            }
        case .slowMorning, .carriedHome:
            // The caption carries the first; the find at the feet is the
            // whole show for the second.
            break
        }
        // Past bond level three, the buddy says it first: one unprompted
        // slow blink, only at the day's first meeting, never replayable.
        if engine.bond >= .close {
            Task {
                try? await Task.sleep(nanoseconds: 7_500_000_000)
                performSlowBlink(initiated: true)
            }
        }
    }

    /// Pick the find up: it moves to the drawer, with its provenance.
    private func bankFind() {
        guard let banked = engine.doorstep.bankFind(
            into: engine.drawer, place: engine.settings.place, finder: buddy
        ) else { return }
        HapticsDirector.shared.stamp()
        if !reduceMotion {
            animator.play(.happy, for: buddy)
        }
        say("\(banked.name.lowercased()) — \(banked.note). Kept", for: 5)
    }

    private func popBurr(_ burr: Burr) {
        withAnimation(.easeInOut(duration: 0.3)) {
            engine.doorstep.popBurr()
        }
        HapticsDirector.shared.detent()
        if !reduceMotion {
            animator.play(.happy, for: buddy)
        }
        say("\(burr.label) from yesterday, off with a shake — "
            + "\(name) hadn't noticed and does not care", for: 5)
    }

    /// The memory has been looked at, which is all it asked.
    private func acknowledgeMemory() {
        withAnimation(.easeInOut(duration: 0.4)) {
            engine.memories.dismiss()
        }
        HapticsDirector.shared.nudge()
        addHeart()
    }

    // MARK: The last-second pounce

    /// The countdown digits become prey in a break's final ten seconds:
    /// flatten, wiggle, pounce on the zero as it lands. Driven entirely off
    /// `engine.remaining`, which the ticker already publishes — the same
    /// no-new-timers rule as everything else. It must never delay the
    /// incoming focus face, and it can't: it only ever touches the buddy.
    private func advancePounce(remaining: TimeInterval) {
        guard !reduceMotion else { return }
        guard engine.isRunning, engine.phase.isBreak else {
            if pounceStage != .none, pounceStage != .pounce { resetPounce() }
            return
        }
        if remaining > 10 {
            if pounceStage != .none { resetPounce() }
            return
        }
        switch pounceStage {
        case .none where remaining > 3:
            pounceStage = .crouch
            withAnimation(.easeInOut(duration: 0.4)) {
                trickOffset = CGSize(width: 0, height: 3)
            }
        case .none, .crouch:
            if remaining <= 3, remaining > 0.5 {
                pounceStage = .wiggle
                Task { await wiggleHaunches() }
            } else if remaining <= 0.5 {
                pounceStage = .pounce
                Task { await performPounce(escapes: engine.pounceEscape) }
            }
        case .wiggle:
            if remaining <= 0.5 {
                pounceStage = .pounce
                Task { await performPounce(escapes: engine.pounceEscape) }
            }
        case .pounce:
            break
        }
    }

    private func resetPounce() {
        pounceStage = .none
        withAnimation(.easeOut(duration: 0.3)) { trickOffset = .zero }
    }

    private func wiggleHaunches() async {
        for index in 0..<6 {
            guard pounceStage == .wiggle else { return }
            withAnimation(.linear(duration: 0.12)) {
                trickOffset = CGSize(width: index.isMultiple(of: 2) ? -2 : 2, height: 3)
            }
            try? await Task.sleep(nanoseconds: 130_000_000)
        }
    }

    private func performPounce(escapes: Bool) async {
        // The zero drops off the clock…
        digitOffset = CGSize(width: 6, height: -64)
        digitSpin = 0
        digitFade = 1
        digitVisible = true
        withAnimation(.easeOut(duration: 0.24)) {
            trickOffset = CGSize(width: 0, height: -30)
        }
        try? await Task.sleep(nanoseconds: 240_000_000)
        if escapes {
            // …and gets away, straight up. One break in seven.
            withAnimation(.easeIn(duration: 0.6)) {
                digitOffset = CGSize(width: 22, height: -180)
                digitSpin = 200
                digitFade = 0
            }
            withAnimation(.easeIn(duration: 0.22)) { trickOffset = .zero }
            say("the last second got away. \(name) is still thinking about it", for: 4)
        } else {
            // …and is batted clean off the screen.
            withAnimation(.easeIn(duration: 0.5)) {
                digitOffset = CGSize(width: 96, height: 40)
                digitSpin = 300
                digitFade = 0
            }
            withAnimation(.easeIn(duration: 0.22)) { trickOffset = .zero }
            animator.play(.happy, for: buddy)
            HapticsDirector.shared.stamp()
        }
        try? await Task.sleep(nanoseconds: 650_000_000)
        digitVisible = false
        pounceStage = .none
    }

    // MARK: Tricks

    /// Perform whatever the repertoire put on stage: the caption tells the
    /// truth about the tier, the body does its best.
    private func performTrick(_ attempt: Repertoire.Attempt) {
        let line = attempt.trick.remark(tier: attempt.tier, name: name)
        say(attempt.announcedGrowth
            ? "practiced in dreams overnight — \(line)" : line, for: 5)
        guard !reduceMotion else {
            // The travel goes, the story stays.
            engine.repertoire.clearAttempt()
            return
        }
        Task {
            switch attempt.trick {
            case .spin: await performSpin(tier: attempt.tier)
            case .leap: await performLeap(tier: attempt.tier)
            }
            engine.repertoire.clearAttempt()
        }
    }

    /// The spin: mirror-flips through zero width, which reads as a
    /// paper-doll turn and keeps every pixel on the grid. Tier zero is one
    /// slow half-hearted turn that resolves into a dignified sit.
    private func performSpin(tier: Int) async {
        let step = min(max(tier, 0), Repertoire.masteredTier)
        let flips = [1, 2, 3, 4][step]
        let beat = [0.42, 0.3, 0.24, 0.18][step]
        for _ in 0..<flips {
            withAnimation(.linear(duration: beat)) { trickScaleX = -1 }
            try? await Task.sleep(nanoseconds: UInt64(beat * 1_000_000_000))
            withAnimation(.linear(duration: beat)) { trickScaleX = 1 }
            try? await Task.sleep(nanoseconds: UInt64(beat * 1_000_000_000))
        }
        if step == 0 {
            withAnimation(.easeOut(duration: 0.18)) {
                trickOffset = CGSize(width: 0, height: 4)
            }
            try? await Task.sleep(nanoseconds: 420_000_000)
            withAnimation(.spring(duration: 0.4, bounce: 0.4)) {
                trickOffset = .zero
            }
        }
        if step >= Repertoire.masteredTier {
            animator.play(.happy, for: buddy)
            burstHearts(2)
        }
    }

    /// The leap: crouch, arc, land, trot back. Higher tiers go higher and
    /// farther; the mastered one turns over at the apex.
    private func performLeap(tier: Int) async {
        let step = min(max(tier, 0), Repertoire.masteredTier)
        let height: [CGFloat] = [8, 20, 32, 42]
        let span: [CGFloat] = [2, 14, 26, 38]
        withAnimation(.easeIn(duration: 0.18)) {
            trickOffset = CGSize(width: 0, height: 3)
        }
        try? await Task.sleep(nanoseconds: 220_000_000)
        withAnimation(.easeOut(duration: 0.26)) {
            trickOffset = CGSize(width: span[step] * 0.6, height: -height[step])
        }
        if step >= Repertoire.masteredTier {
            withAnimation(.linear(duration: 0.26)) { trickScaleX = -1 }
        }
        try? await Task.sleep(nanoseconds: 280_000_000)
        withAnimation(.easeIn(duration: 0.22)) {
            // Tier zero comes down a pixel too hard. The ground disagrees.
            trickOffset = CGSize(width: span[step], height: step == 0 ? 4 : 0)
        }
        if step >= Repertoire.masteredTier {
            withAnimation(.linear(duration: 0.22)) { trickScaleX = 1 }
        }
        try? await Task.sleep(nanoseconds: 340_000_000)
        withAnimation(.spring(duration: 0.5, bounce: 0.35)) {
            trickOffset = .zero
        }
        try? await Task.sleep(nanoseconds: 420_000_000)
        if step >= Repertoire.masteredTier {
            animator.play(.happy, for: buddy)
            burstHearts(2)
        }
    }

    // MARK: The high five

    /// Whether the paw is up at `date` — the post-bell window, or the earned
    /// pre-empt just before the chime.
    private func pawRaised(at date: Date) -> Bool {
        if let fiveWindow, fiveWindow.contains(date) { return true }
        return preemptRaised
    }

    /// After enough landed fives the paw rises a beat *before* the chime:
    /// the buddy has learned you'll be there. Earned once, kept forever.
    private var preemptRaised: Bool {
        engine.fives.preempts
            && engine.isRunning && !engine.phase.isBreak
            && engine.remaining > 0 && engine.remaining <= 1.6
    }

    /// Three seconds of offered paw, opening once the wake-up stretch has
    /// played. A missed window closes silently — nothing records it.
    private func openFiveWindow() {
        let wake = reduceMotion
            ? 0 : (BuddyFrames.duration(for: buddy, pose: .waking) ?? 0)
        let start = Date().addingTimeInterval(wake)
        let window = start...start.addingTimeInterval(3.0)
        fiveWindow = window
        Task {
            try? await Task.sleep(nanoseconds: UInt64((wake + 3.0) * 1_000_000_000))
            if fiveWindow == window { fiveWindow = nil }
        }
    }

    private func landFive() {
        guard fiveWindow != nil else { return }
        fiveWindow = nil
        engine.fives.land()
        lastPet = Date()   // the same touch shouldn't immediately pet too
        animator.play(.happy, for: buddy)
        HapticsDirector.shared.stamp()
        SoundPlayer.shared.playPurr()
        burstHearts(2)
        say(engine.fives.lifetime == 1
            ? "a high five! \(name) will remember this"
            : "high five — \(name) was ready", for: 3.5)
    }

    // MARK: Tucking in

    /// Under the blanket right now. Releases a nocturnal buddy at night —
    /// the blanket never touches Luna's watch.
    private var isTuckedAsleep: Bool {
        engine.tuckIn.isTuckedNow()
            && !(buddy.isNocturnal && dayPart == .night)
    }

    /// The blanket is offered while idle, in the buddy's own bedtime window,
    /// once per day.
    private var showsTuckChip: Bool {
        engine.runState == .idle
            && !engine.tuckIn.isTuckedNow()
            && TuckIn.windowIsOpen(for: buddy, at: dayPart)
    }

    private func tuckNow() {
        withAnimation(.easeInOut(duration: 0.5)) {
            engine.tuckIn.tuck()
        }
        HapticsDirector.shared.purr(duration: 0.9)
    }

    /// The blanket's thank-you, once, on the first look of the morning.
    private func revealMorningIfDue() {
        guard engine.tuckIn.claimMorningReveal() else { return }
        say("the blanket did its work — \(name) is full of dreams today", for: 6)
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

    // MARK: The sill

    /// What's on the sill, when it's reachable. During a running focus phase
    /// the sill is simply out of reach, behind the same rule as the toys —
    /// and nobody offers snacks to a buddy already under the blanket.
    private var sillSnack: Snack? {
        guard !(engine.isRunning && !engine.phase.isBreak) else { return nil }
        guard !isTuckedAsleep else { return nil }
        return engine.pantry.sill
    }

    /// Pure functions only — the chip animates to match the outcome before
    /// anything is actually eaten.
    private func snackVerdict() -> SnackDropVerdict {
        guard let snack = engine.pantry.sill else { return .full }
        guard engine.pantry.hasAppetite() else { return .full }
        return buddy.reaction(to: snack) == .notMyThing ? .snubbed : .taken
    }

    private func snackLanded(_ verdict: SnackDropVerdict) {
        switch verdict {
        case .taken:
            guard let reaction = engine.pantry.feed(buddy) else { return }
            animator.play(.happy, for: buddy)
            if reaction == .bliss {
                HapticsDirector.shared.purr()
                SoundPlayer.shared.playPurr()
                burstHearts(3)
                say("\(name) — \(buddy.blissRemark)", for: 5)
            } else {
                HapticsDirector.shared.stamp()
                addHeart()
                say("\(name) nibbles — approved", for: 3.5)
            }
        case .snubbed:
            // Records the datum; the snack stays on the sill. A refusal is
            // knowledge too, which is why the Tastes card still fills in.
            engine.pantry.feed(buddy)
            HapticsDirector.shared.nudge()
            say("\(name) \(buddy.snubRemark)", for: 4.5)
        case .full:
            HapticsDirector.shared.nudge()
            say("\(name) pats a full belly — tomorrow, maybe", for: 3.5)
        }
    }

    /// Hearts in a small stagger, so three read as delight, not a stack.
    private func burstHearts(_ count: Int) {
        for index in 0..<count {
            Task {
                try? await Task.sleep(nanoseconds: UInt64(index) * 180_000_000)
                addHeart()
            }
        }
    }

    /// Put a line under the buddy for a few seconds, then hand the caption
    /// back to the computed one.
    private func say(_ text: String, for seconds: TimeInterval) {
        remark = text
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if remark == text { remark = nil }
        }
    }

    // MARK: Petting

    private var petGesture: some Gesture {
        // A zero-distance drag catches both a tap and a stroke; strokes keep
        // firing on a throttle so scratching the buddy stays rewarding.
        // A touch that begins and then holds truly still is something else:
        // eye contact. Hold it most of a second and the buddy answers with
        // the slow blink — the animal signal for "I trust you, and I can't
        // be bothered to prove it harder than this."
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if petHoldBegan == nil {
                    petHoldBegan = Date()
                    petHoldMoved = false
                    Task {
                        try? await Task.sleep(nanoseconds: 900_000_000)
                        guard let began = petHoldBegan,
                              Date().timeIntervalSince(began) >= 0.85,
                              !petHoldMoved
                        else { return }
                        performSlowBlink()
                    }
                }
                let travel = hypot(
                    value.location.x - value.startLocation.x,
                    value.location.y - value.startLocation.y
                )
                if travel > 14 { petHoldMoved = true }
                pet(throttle: 0.4)
            }
            .onEnded { _ in
                petHoldBegan = nil
                petHoldMoved = false
            }
    }

    /// The blink, returned — or, past bond level three, offered first on
    /// the day's first open.
    private func performSlowBlink(initiated: Bool = false) {
        guard !isNapping, !slowBlinking else { return }
        slowBlinking = true
        HapticsDirector.shared.purr(duration: 0.8)
        say(initiated
            ? "\(name) blinked first. Make of that what you will"
            : "\(name) returns the slow blink. That settles that", for: 4)
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            slowBlinking = false
        }
    }

    private func pet(throttle: TimeInterval = 0.25) {
        let now = Date()
        // While the paw is up, a touch is a high five — the pet can wait.
        if let fiveWindow, fiveWindow.contains(now) {
            landFive()
            return
        }
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
        // A fresh reaction outranks everything: it *is* the moment.
        if let remark {
            return remark
        }
        if let fiveWindow, fiveWindow.contains(Date()) {
            return "\(name)'s paw is up — don't leave it hanging"
        }
        if preemptRaised {
            return "\(name)'s paw is already up. It knew"
        }
        if animator.isPlayingTransient(at: Date()), isNapping {
            return "shhh — \(name) is dreaming"
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
            // A memory outranks the day's errands: it exists only today.
            if let memory = engine.memories.today {
                return memory.line(name: name, strayName: strayName)
            }
            // The tucked line is the ritual's receipt, and it holds the
            // caption for the rest of the evening.
            if isTuckedAsleep, let clock = engine.tuckIn.tuckClock {
                return "tucked in at \(clock). \(name) has no notes"
            }
            // The sill outranks the expedition remark: a snack is something
            // to *do*, and it teaches the drag without a tutorial.
            if let snack = sillSnack {
                return "there's \(snack.label) on the sill — slide it over"
            }
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
            if engine.phase.isBreak {
                return isTuckedAsleep
                    ? "\(name) sleeps through your break — well earned"
                    : "\(name) is up and about — enjoy your break"
            }
            return "Don't wake \(name) — stay focused!"
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
