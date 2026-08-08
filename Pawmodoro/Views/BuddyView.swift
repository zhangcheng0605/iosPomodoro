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
    /// The acrobatics: a second, independent set of the same three channels
    /// the tricks use, plus a rotation. Kept separate from `trickOffset` on
    /// purpose — the break's closing pounce drives that one off the countdown,
    /// and a tap landing in the last ten seconds of a break must not be able
    /// to fight it for the same property. The two compose instead.
    @State private var anticOffset: CGSize = .zero
    @State private var anticScaleX: CGFloat = 1
    @State private var anticSpin: Double = 0
    /// The drawn frame the move is holding, or nil for "ask the animator".
    @State private var anticFrame: AnticFrame?
    /// True for exactly as long as a move is on screen: raises the timeline
    /// to 8fps and drops it straight back afterwards.
    @State private var anticRunning = false
    /// The escalation. A value, in view state, written down nowhere.
    @State private var anticBag = AnticBag()
    @State private var anticTask: Task<Void, Never>?
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
                // The window-box's showpiece: whatever is furthest along,
                // just visible at the edge of the scene. Not a control —
                // the garden itself lives on the stats screen.
                if let showpiece = gardenShowpiece {
                    Image(showpiece)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 32)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

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
                        // Rotation first, so a tumble turns about the sprite's
                        // own centre before any travel moves it. The clip in
                        // `BuddySprite` runs in its own coordinate space, so
                        // it happens before this and nothing shears — and the
                        // whole stack, hat and collar included, turns as one
                        // piece. That is why an upside-down buddy needs no
                        // anchor: no frame changed.
                        .rotationEffect(.degrees(anticSpin))
                        .scaleEffect(x: trickScaleX * anticScaleX, y: 1)
                        .offset(trickOffset)
                        .offset(anticOffset)
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

                    // The blanket, over the sleeping buddy — and the way back
                    // out from under it. All twelve asleep poses fill the
                    // lower half of the same grid, so one shared overlay
                    // drapes everyone.
                    if isTuckedAsleep {
                        BlanketOverlay(
                            starry: Season.current() == .winter,
                            spriteSize: spriteSize,
                            onTouched: { pet() },
                            onLifted: { liftBlanket() }
                        )
                        .transition(.opacity)
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
                // Where the sprite is, for the treat tray below. The tray
                // cannot see this view's geometry — they are siblings — so
                // the frame travels the same channel the finger's position
                // already does. Offsets (hearts, the dream bubble) do not
                // move layout, so this is the sprite's own square.
                .background(GeometryReader { proxy in
                    Color.clear
                        .onAppear { touch.buddyFrame = proxy.frame(in: .global) }
                        .onChange(of: proxy.frame(in: .global)) { _, frame in
                            touch.buddyFrame = frame
                        }
                })

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

                // The weekend request: a note in mind, waiting to be
                // granted. Off-hours only, like every chip.
                if let request = weekendRequest {
                    Button {
                        engine.acceptSaturdayRequest()
                        HapticsDirector.shared.detent()
                        say("\(request.title), then — stamped into the setlist", for: 5)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.cream.opacity(0.85))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Theme.bark.opacity(0.14), lineWidth: 1)
                                )
                            Image(systemName: "music.note")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.blossom)
                        }
                        .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                    .accessibilityLabel(
                        "Grant \(name)'s request: \(request.title)"
                    )
                }
            }
            .animation(.easeInOut, value: isNapping)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: strayIsAlongside)
            .animation(.easeInOut(duration: 0.35), value: sillSnack)

            Text(caption)
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.75))
                .multilineTextAlignment(.center)
                // Every caption that shipped before happened to fit on one
                // line, so nothing here ever had to say it could wrap — and
                // `multilineTextAlignment` alone does not grant it. Inside a
                // laid-out stack the text stayed one line and truncated.
                //
                // The night visitor is what found it: its whole feature is a
                // sentence of evidence about who came to the sill, 70-95
                // characters long, and all nine of them lost their tail
                // mid-word — "the tanuki has a sardine now,…". The homecoming
                // line is longer still. VoiceOver was always fine, because
                // `accessibilityLabel` below is handed the whole string; this
                // was only ever true of the drawing.
                .fixedSize(horizontal: false, vertical: true)
                // Kept off the screen edges, since it may now be two lines.
                .frame(maxWidth: 300)
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
        .accessibilityAction(named: isResting ? "Check on \(name)" : "Pet \(name)") {
            pet()
        }
        // Everything the sighted hand can reach, offered by name. One block
        // rather than two stacked modifiers: a second `.accessibilityActions`
        // is not documented to accumulate, and the whole point of this list is
        // that nothing quietly falls off it.
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
            // The drag has an opposite; so must the spoken list. A blanket
            // that can only be put on is a trap either way you reach it.
            if isTuckedAsleep {
                Button("Take \(name)'s blanket off") { liftBlanket() }
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
            // A touch region cannot be aimed at without sight, so each spot
            // gets its own action. The favourite is not marked in any of these
            // labels: finding it is the feature, and a list that gave it away
            // would take the feature from exactly the people this is for.
            if !isResting {
                ForEach(TouchSpot.allCases) { spot in
                    Button("Touch \(spot.name)") { touchNamed(spot) }
                }
            }
        }
        .onAppear {
            animator.setBase(restingPose)
            engine.greetIfOwed()
            playGreetingIfOwed()
        }
        .onChange(of: engine.greeting) { _, hello in
            guard hello != nil else { return }
            playGreetingIfOwed()
        }
        // The bounce only for the favourite. A bounce for everything would
        // make the favourite unfindable, which is the whole feature.
        .onChange(of: engine.offered?.reception) { _, reception in
            guard reception?.isDelighted == true, !isNapping else { return }
            animator.play(.happy, for: buddy)
        }
        .onChange(of: restingPose) { _, pose in animator.setBase(pose) }
        // A treat has come within reach: the buddy sits up and takes notice.
        // Reuses the `stirring` one-shot — for an awake buddy that is the
        // alert, eyes-open frame, which reads as perking up — rather than
        // `happy`, so the delighted bounce stays the favourite's alone.
        .onChange(of: touch.treatNear) { _, near in
            guard near, !isNapping else { return }
            animator.play(.stirring, for: buddy)
        }
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
            // `-PawmodoroAntics` walks the whole vocabulary; `-PawmodoroAntic
            // tumble` plays one and then pins every tap to it.
            if LaunchOptions.anticParade {
                await paradeAntics()
            } else if let id = LaunchOptions.forcedAntic,
                      let antic = Antic(rawValue: id) {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                playAntic(.move(antic))
            }
        }
        .task(id: engine.runState == .idle) {
            await runIdleLife()
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
        } else if engine.chronicle.claimFreshLetter() != nil {
            say("a letter from the season — it's in the mailbox", for: 6)
        } else {
            playHello()
        }
        revealMorningIfDue()
    }

    // MARK: Sprite

    @ViewBuilder
    private var sprite: some View {
        if reduceMotion {
            // No timeline at all: one still frame — the move's last pose while
            // one is being held, the resting pose otherwise.
            BuddySprite(
                buddy: buddy,
                assetName: stillAsset,
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
                    sleeping: isNapping,
                    outfit: outfit
                )
            }
            // A `TimelineView` keeps the schedule it was built with, so without
            // a new identity the 8fps burst would still be sampled at the 4fps
            // idle rate and drop half its frames.
            .id(tickInterval)
        }
    }

    /// The one frame Reduce Motion draws.
    ///
    /// This exists because the obvious version of the branch above didn't have
    /// it, and the omission was invisible from the code: `runMove` sets
    /// `anticFrame` to the move's last pose and returns, the caption says what
    /// happened, and the sprite — asked only for `restingPose` — never changed
    /// by a single pixel. Measured on screen, seven moves in a row moved the
    /// buddy's pixels 0.00. Reduce Motion means *less motion*, not less
    /// information, so the end of the move has to actually be drawn.
    ///
    /// `currentAsset` reads this too. The touch regions are measured per frame,
    /// and a held signature is exactly when the frame is not the resting one.
    private var stillAsset: String {
        if let anticFrame, let asset = anticFrame.asset(for: buddy) {
            return asset
        }
        return BuddyFrames.name(for: buddy, pose: restingPose, elapsed: 0)
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
        // A move outranks the glance and the raised paw for the same reason a
        // one-shot does: it is a thing the buddy is *doing*. The `??` is what
        // keeps this agent unblocked by the art — a signature whose sprite
        // hasn't been drawn yet falls through to the animator rather than
        // blanking, and the transform still carries the move.
        if let anticFrame, let asset = anticFrame.asset(for: buddy) {
            return asset
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
    private var visibleFind: Trinket? {
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

    // MARK: A life of its own

    /// The Sims' voyeur loop, stateless and with a real past: every so
    /// often while idle, the buddy does a small thing on its own. The slot
    /// schedule and the choice are pure functions of (buddy, time) — no
    /// vignette log exists, deliberately, so absence subtracts nothing —
    /// and the rare entries replay the buddy's own records: the drawer,
    /// the half-learned trick, the favorite snack.
    private func runIdleLife() async {
        guard engine.runState == .idle else { return }
        if let forced = LaunchOptions.forcedVignette {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            playVignette(seed: forced)
        }
        let slotLength: TimeInterval = 420
        while !Task.isCancelled, engine.runState == .idle {
            // Find the next slot this buddy does something — about one
            // slot in three, so roughly every twenty minutes of idle.
            var slot = Int(Date().timeIntervalSinceReferenceDate / slotLength) + 1
            while Doorstep.stableHash("life.\(buddy.rawValue).\(slot)") % 3 != 0 {
                slot += 1
            }
            let fireAt = Double(slot) * slotLength
            let wait = max(1, fireAt - Date().timeIntervalSinceReferenceDate)
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard !Task.isCancelled, engine.runState == .idle, remark == nil,
                  !isTuckedAsleep
            else { continue }
            playVignette(seed: Doorstep.stableHash("life.pick.\(buddy.rawValue).\(slot)"))
        }
    }

    private func playVignette(seed: Int) {
        say(vignetteLine(seed: seed), for: 7)
        if !reduceMotion, seed % 2 == 0 {
            animator.play(.happy, for: buddy)
        }
    }

    private func vignetteLine(seed: Int) -> String {
        // The rare entries prove the buddy remembers the same things you
        // do — material no generic pet has, because no generic pet kept
        // your drawer.
        if seed % 5 == 0 {
            // Rarest of all: a middle line from a haiku you finished weeks
            // ago, quoted back. Each poem gets this once, ever.
            if seed % 3 == 0, let line = engine.anthology.quoteBack() {
                return "\(name) says, mostly to itself: “\(line)”"
            }
            if seed % 2 == 0, let last = engine.drawer.items.last,
               let trinket = Trinket(rawValue: last.keepsake) {
                return "\(name) sniffs the spot where the "
                    + "\(trinket.name.lowercased()) lay"
            }
            if let trick = Trick.allCases.first(where: {
                engine.repertoire.tier(buddy, $0) > 0
                    && !engine.repertoire.hasMastered(buddy, $0)
            }) {
                return "\(name) practices \(trick.name), quietly, badly, "
                    + "believing itself unobserved"
            }
            if engine.pantry.hasTried(buddy, buddy.favoriteSnack) {
                return "\(name) checks the sill. Optimistically"
            }
        }
        let generic = [
            "\(name) washes a face that was already clean",
            "\(name) chases the tail. The tail wins",
            "\(name) watches a bird only \(name) can see",
            "\(name) digs, briefly, for reasons",
            "\(name) stretches one leg. Just the one",
            "\(name) sits facing the wall — correctly, somehow",
            "\(name) nudges the pebble toward the edge of the shelf. "
                + "Slowly. While watching you",
        ]
        return generic[abs(seed) % generic.count]
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

    // MARK: Acrobatics

    /// Whether a tap gets a performance at all.
    ///
    /// `isNapping` alone was the wrong gate, and it was wrong on the shipped
    /// build: `restingPose` returns `.watching` for a nocturnal buddy during a
    /// night focus phase, so `isNapping` is false and Luna got the full bounce,
    /// a purr and a heart in the middle of a focus session. With acrobatics
    /// behind it she would have performed. The phase is the fence, not the pose.
    private var isResting: Bool {
        isNapping || (engine.isRunning && !engine.phase.isBreak)
    }

    /// What this tap is answered with: the pinned move under the debug flag,
    /// otherwise the bag's next draw.
    private func nextAntic() -> AnticChoice {
        if let id = LaunchOptions.forcedAntic, let antic = Antic(rawValue: id) {
            return .move(antic)
        }
        let mastered = Trick.allCases.filter {
            engine.repertoire.hasMastered(buddy, $0)
        }
        // The established deterministic-roll idiom, over something that
        // changes every tap. Only the one-in-twenty-five routine reads it.
        let seed = Doorstep.stableHash(
            "antic.\(buddy.rawValue).\(Int(Date().timeIntervalSinceReferenceDate * 1000))"
        )
        return anticBag.draw(seed: seed, mastered: mastered)
    }

    /// Perform one drawn answer.
    private func playAntic(_ choice: AnticChoice) {
        switch choice {
        case .trick(let trick):
            // A trick taught all the way to mastery joins the everyday
            // vocabulary. `showOff` does no practice bookkeeping — a tap must
            // never look like a carefully drawn circle — and the existing
            // `onChange(of: repertoire.attempt)` runs it and writes its caption.
            engine.repertoire.showOff(trick, tier: Repertoire.masteredTier)
        case .move(let antic):
            // The favourite touch spot outranks the move's line: finding it is
            // a discovery that happens once, and a somersault says so every
            // third tap. Everything else the move describes itself, which is
            // what Reduce Motion and VoiceOver both live on.
            if let line = antic.remark(for: buddy), !engine.foundFavourite {
                say(line, for: 3.5)
            }
            runMove(antic)
        }
    }

    private func runMove(_ antic: Antic) {
        if let pose = antic.pose {
            animator.play(pose, for: buddy)
        }
        anticTask?.cancel()

        guard !reduceMotion else {
            // The *end* of the move rather than nothing: the frame it would
            // have finished on, held still, with its sentence above. Motion
            // removed, information kept — which is already better than the
            // shipped build, where Reduce Motion dropped the bounce silently.
            anticFrame = antic.stillFrame(for: buddy)
            anticTask = Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard !Task.isCancelled else { return }
                anticFrame = nil
            }
            return
        }

        let beats = antic.beats(for: buddy)
        guard !beats.isEmpty else { return }
        anticTask = Task { await run(beats: beats) }
    }

    /// The whole acrobatics engine: one loop over a table. Every move in the
    /// app comes through here, which is why there is no `if buddy == …`
    /// anywhere in this file — a signature is a different list, not a
    /// different code path.
    private func run(beats: [AnticBeat]) async {
        anticRunning = true
        defer {
            // Belt and braces for a cancelled move. Every table already ends
            // at rest; this makes sure an interrupted one does too, so a
            // rotation can never be left held — pixel art at thirty degrees
            // reads as a broken app, not as a buddy.
            anticRunning = false
            anticFrame = nil
            anticSpin = 0
            anticScaleX = 1
            anticOffset = .zero
        }
        for beat in beats {
            guard !Task.isCancelled else { return }
            anticFrame = beat.frame
            let land = {
                anticOffset = CGSize(width: beat.dx, height: beat.dy)
                anticScaleX = beat.scaleX
                anticSpin = beat.spin
            }
            if let curve = beat.curve.animation(over: beat.hold) {
                withAnimation(curve, land)
            } else {
                land()
            }
            try? await Task.sleep(nanoseconds: UInt64(beat.hold * 1_000_000_000))
        }
    }

    /// `-PawmodoroAntics`: every move for this buddy, back to back. Tapping
    /// for them is not a way to check twelve buddies — the bag deliberately
    /// won't let you choose.
    private func paradeAntics() async {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        for antic in Antic.allCases {
            guard !Task.isCancelled else { return }
            playAntic(.move(antic))
            let gap = max(1.0, antic.duration(for: buddy)) + 1.5
            try? await Task.sleep(nanoseconds: UInt64(gap * 1_000_000_000))
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

    /// This week's request, when it's grantable: weekends, off-hours, and
    /// not while the buddy is under the blanket.
    private var weekendRequest: MusicTrack? {
        guard !(engine.isRunning && !engine.phase.isBreak) else { return nil }
        guard !isTuckedAsleep else { return nil }
        return engine.saturdayRequest
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

    /// The blanket comes off by hand, before its own morning.
    ///
    /// Nothing is handed back. The night's guaranteed dream was earned the
    /// moment the blanket went on, and `TuckIn.lift(on:)` leaves it alone —
    /// so this is a way out of the ritual, never a way to undo having done
    /// it. The folded chip returns on its own, because `showsTuckChip` only
    /// ever asked whether the buddy is under a blanket right now.
    private func liftBlanket() {
        withAnimation(.easeInOut(duration: 0.4)) {
            // The `_ =` is load-bearing: `lift()` is `@discardableResult`, so
            // without it the closure infers `() -> Bool` and the compiler
            // warns that `withAnimation`'s result is unused.
            _ = engine.tuckIn.lift()
        }
        HapticsDirector.shared.detent()
        say("blanket off — \(name) is up again", for: 4)
    }

    /// The blanket's thank-you, once, on the first look of the morning.
    private func revealMorningIfDue() {
        guard engine.tuckIn.claimMorningReveal() else { return }
        say("the blanket did its work — \(name) is full of dreams today", for: 6)
    }

    // MARK: The day's greeting

    /// Stretch, look up, bounce — and that is the existing `waking` one-shot,
    /// unchanged.
    ///
    /// No new pose and no new art. `waking` is already eyes-open, then a
    /// stretch for the buddies that have one, then the pleased bounce, which
    /// is exactly what the plan asked a greeting to be. Inventing a second
    /// animation that looked the same would be two things to keep in step for
    /// no gain — the standing quirk rule, applied to a whole feature.
    ///
    /// The caption is what carries the *warmth*: it holds for
    /// `Warmth.seconds`, which is longer than the animation, so a gladder
    /// greeting lingers after the bounce has finished rather than needing its
    /// own longer bounce.
    private func playGreetingIfOwed() {
        guard let hello = engine.greeting, !isNapping else { return }
        animator.play(.waking, for: buddy)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(hello.seconds * 1_000_000_000))
            engine.endGreeting()
        }
    }

    /// Follows whichever pose is on screen, so a slow breathing loop doesn't
    /// keep ticking at the rate a finished bounce needed.
    ///
    /// A move takes the burst rate for exactly its own length and gives it
    /// straight back — `anticRunning` is cleared in the runner's `defer`, so
    /// even a cancelled move cannot leave the timeline running hot.
    private var tickInterval: TimeInterval {
        anticRunning ? 1.0 / 8.0 : animator.resolved(at: Date()).pose.frameInterval
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

    /// The furthest-along pocket's sprite, for the pot at the scene's edge.
    private var gardenShowpiece: String? {
        let pockets = engine.garden.pockets.compactMap { $0 }
        guard let best = pockets.max(by: {
            engine.garden.stage(of: $0, log: engine.log)
                < engine.garden.stage(of: $1, log: engine.log)
        }), let kind = PlantKind(rawValue: best.kind) else { return nil }
        return kind.stageAsset(engine.garden.stage(of: best, log: engine.log))
    }

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
        // firing on a throttle so scratching the buddy stays rewarding. The
        // location is what turned this from a button into a creature: the
        // buddy now knows *where* your hand is.
        //
        // A touch that begins and then holds truly still is something else:
        // eye contact. Hold it most of a second and the buddy answers with
        // the slow blink — the animal signal for "I trust you, and I can't
        // be bothered to prove it harder than this." The two read the same
        // gesture: the travel test that decides a hold is also what tells a
        // stroke from a still finger, and the location goes to the touch
        // regions either way.
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
                pet(at: value.location, throttle: 0.4)
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

    /// Where a touch landed, in the drawing grid's own units.
    ///
    /// The sprite is drawn `scaledToFit` into a `spriteSize` square, and the
    /// grid is square too, so the conversion is one division — and it is the
    /// same space `BuddyAnchors` and `Accessory.placement` already work in,
    /// which is why the touch regions could be derived from the anchors the
    /// wardrobe measures instead of needing a third table of their own.
    private func gridPoint(_ location: CGPoint) -> CGPoint {
        let unit = spriteSize / BuddyAnchors.canvas
        return CGPoint(x: location.x / unit, y: location.y / unit)
    }

    private func pet(at location: CGPoint? = nil, throttle: TimeInterval = 0.25) {
        let now = Date()
        // While the paw is up, a touch is a high five — the pet can wait.
        if let fiveWindow, fiveWindow.contains(now) {
            landFive()
            return
        }
        guard now.timeIntervalSince(lastPet) > throttle else { return }
        lastPet = now

        if isResting {
            // Mid-focus: the buddy stirs but never wakes. No penalty, no guilt,
            // and no touch vocabulary either — a sleeping animal does not have
            // opinions about where you put your hand, and the fiction that
            // focus is sacred outranks the new feature. A buddy who is awake
            // through focus because it is nocturnal gets the same answer: an
            // acknowledged glance, and back to the watch. Nothing performs
            // during a focus phase, ever.
            animator.play(.stirring, for: buddy)
            HapticsDirector.shared.nudge()
            return
        }

        let spot = location.flatMap {
            TouchSpot.at(gridPoint($0), on: currentAsset)
        }
        engine.touched(spot)

        playAntic(nextAntic())
        // The favourite gets the softer, longer haptic — the one difference
        // between finding it and not that is felt rather than read.
        if engine.foundFavourite {
            HapticsDirector.shared.purr()
            HapticsDirector.shared.purr()
        } else {
            HapticsDirector.shared.purr()
        }
        SoundPlayer.shared.playPurr()
        addHeart()
    }

    /// The frame currently on screen, which is what the touch regions are
    /// measured against. Anchors are per *frame*, so asking the resting pose
    /// while a bounce is playing would put the chin in the wrong place.
    private var currentAsset: String {
        reduceMotion ? stillAsset : frameName(at: Date())
    }

    /// The accessibility path: a named spot rather than a location.
    ///
    /// Named `touchNamed` because `touch` is already the finger tracker this
    /// view holds — the two would compile side by side and read as a bug.
    private func touchNamed(_ spot: TouchSpot) {
        guard !isResting else {
            animator.play(.stirring, for: buddy)
            HapticsDirector.shared.nudge()
            return
        }
        lastPet = .distantPast
        engine.touched(spot)
        // The same bag as the finger's path. Escalation reached only by
        // aiming at a sprite would be a feature sighted hands have and
        // nobody else does — and the caption is what carries it either way.
        playAntic(nextAntic())
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

    /// One line, and a strict order of who gets it.
    ///
    /// Two rules decide the whole chain. A sleeping buddy outranks everything,
    /// because the fiction that focus is sacred is older than any of the
    /// features below it. Then the one-shots — things that happened a second
    /// ago and expire on their own — above the ambient lines that describe a
    /// state and will still be true in a minute.
    ///
    /// Inside the one-shots the order is by *how long each holds the screen*,
    /// shortest first, so that two arriving together are both seen instead of
    /// the longer one swallowing the shorter. That is why the day's greeting
    /// (3–4.5s) sits above `remark` (3.5–8s): on most mornings the doorstep
    /// deals a hello *and* a greeting is owed, and with `remark` first the
    /// greeting would expire unseen every single time. Ordered this way the
    /// greeting plays, ends, and the remark is still there underneath it.
    private var caption: String {
        if animator.isPlayingTransient(at: Date()), isNapping {
            return "shhh — \(name) is dreaming"
        }
        // The hello, ahead of everything except a sleeping buddy. It is the
        // first thing on screen on a new day and it is over in a few seconds;
        // anything that outranked it would mean somebody who opens the app,
        // gets a resident and a greeting on the same morning never sees the
        // greeting at all.
        if let hello = engine.greeting {
            return "\(name) \(hello.line)"
        }
        // A fresh reaction outranks everything below: it *is* the moment.
        if let remark {
            return remark
        }
        if let fiveWindow, fiveWindow.contains(Date()) {
            return "\(name)'s paw is up — don't leave it hanging"
        }
        if preemptRaised {
            return "\(name)'s paw is already up. It knew"
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
        // What you just handed over. Above the touch spots because a treat is
        // a bigger thing to have done than a stroke, and both are replies to
        // something that happened a second ago.
        if let given = engine.offered {
            return "\(name) \(given.treat.line(for: given.reception, isFirstFavourite: given.isFirstFavourite))"
        }
        // What your hand just found. Above the quirk poses because it is a
        // reply to something you did a second ago, and below the sleeping
        // remark because focus outranks everything.
        if let spot = engine.touchedSpot {
            return engine.foundFavourite
                ? "\(name) \(buddy.favouriteLine)"
                : "\(name) \(spot.line)"
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
            // The weekend request, when nothing else is asking.
            if let request = weekendRequest {
                return "\(name) has a request — \(request.title)"
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

/// The model's curve names, resolved into SwiftUI.
///
/// The only translation between `Antics.swift` and the view layer. It lives
/// here rather than there so the move tables stay importable, summable and
/// printable without SwiftUI — a beat list is data about a performance, not a
/// performance.
private extension AnticCurve {
    /// nil means no animation at all: land there. Used once, to put the
    /// tumble's rotation on exactly zero degrees.
    func animation(over duration: TimeInterval) -> Animation? {
        switch self {
        case .linear: .linear(duration: duration)
        case .easeIn: .easeIn(duration: duration)
        case .easeOut: .easeOut(duration: duration)
        case .easeInOut: .easeInOut(duration: duration)
        case .spring: .spring(duration: duration, bounce: 0.35)
        case .snap: nil
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
