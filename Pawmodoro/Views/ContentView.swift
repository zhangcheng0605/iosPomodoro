import SwiftUI

struct ContentView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store
    @State private var bridge = IntentBridge.shared
    @AppStorage(StorageKeys.hasOnboarded) private var hasOnboarded = false
    @State private var showSettings = false
    @State private var showStats = false
    /// `-PawmodoroCart` only. There is no button to the cart on this screen
    /// and there must not be one — fence 8 keeps the timer clear of the
    /// economy. It lives one tap deeper, in Settings.
    @State private var showCart = LaunchOptions.openCart
    @State private var showPaywall = false
    @State private var showStudio = false
    @State private var showStrayNaming = false
    @State private var showScrapbook = false
    @State private var showTipJar = false
    /// True while the three breaths are running. The engine knows nothing
    /// about this — `start()` is simply called later.
    @State private var settling = false
    /// Whether a stage-two stray has been sent off this phase. Nothing about
    /// her is ever persisted as lost, so this lives no longer than the phase.
    @State private var straySpooked = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(for: engine.phase)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: engine.phase)

                // Zero-size, no drawing: it just sits in the responder chain
                // so a shake reaches the scene.
                ShakeDetector()
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)

                scenery

                tide

                snail

                toys

                stray

                sky

                weather

                seasonal

                // Something tiny that settles on the buddy or the ring. Above
                // the scene, below the UI: it lands *on* things, so it has to
                // be in front of them.
                if let visit = engine.visibleEncounter {
                    MicroEncounterView(
                        encounter: visit.encounter, phase: visit.phase
                    )
                    .id(visit.encounter)
                }

                // Only while the timer is running with an ambience chosen —
                // the same condition that has SoundPlayer playing, so the
                // picture and the sound always agree.
                if engine.isRunning, engine.settings.ambience != .off {
                    AmbientSceneView(
                        ambience: engine.settings.ambience,
                        tint: Theme.bark,
                        accent: Theme.accent(for: engine.phase)
                    )
                }

                VStack(spacing: 0) {
                    phaseChip
                        .padding(.bottom, 20)

                    TimerRingView()

                    // Only while idle: mid-session is the wrong moment to be
                    // offered a different session.
                    if engine.runState == .idle {
                        expeditionRow
                            .padding(.top, 12)
                            .transition(.opacity)
                    }

                    BuddyView()
                        .padding(.top, 18)

                    // Only when nothing is counting down. A treat offered
                    // mid-focus would be a reason to touch the screen during
                    // the one stretch of time this app exists to leave alone.
                    if engine.runState != .running || engine.phase.isBreak {
                        TreatTray()
                            .padding(.top, 8)
                            .transition(.opacity)
                    }

                    Spacer(minLength: 12)

                    ambienceRow
                        .padding(.bottom, 22)

                    controls
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if settling {
                    SettleInView(onFinish: finishSettling)
                        .transition(.opacity)
                        .zIndex(1)
                }

                if let completion = engine.completion {
                    CelebrationView(
                        completion: completion,
                        accent: Theme.accent(for: engine.phase),
                        secondary: Theme.blossom,
                        streak: engine.log.currentStreak,
                        buddyName: engine.buddyName,
                        onDismiss: { engine.completion = nil },
                        onTip: {
                            engine.completion = nil
                            showTipJar = true
                        }
                    )
                    .id(completion.id)
                    .transition(.opacity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showStats = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(Theme.bark)
                    }
                    .accessibilityLabel("Stats")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showStudio = true
                    } label: {
                        Image(systemName: engine.settings.music == nil
                              ? "music.note" : "music.note.list")
                            .foregroundStyle(engine.settings.music == nil
                                             ? Theme.bark : Theme.blossom)
                    }
                    .accessibilityLabel("Sound Studio")
                }
                // The gentle nudge to photograph where you sit today: one
                // glyph, no new row, and gone entirely while focus runs —
                // nothing invites a touch during the stretch this app exists
                // to leave alone.
                if !(engine.isRunning && !engine.phase.isBreak) {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showScrapbook = true
                        } label: {
                            Image(systemName: "camera")
                                .foregroundStyle(Theme.bark)
                        }
                        .accessibilityLabel("Keep a picture of where you are sitting")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Theme.bark)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showStats) {
                StatsView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showStudio) {
                SoundStudioView()
            }
            .sheet(isPresented: $showStrayNaming) {
                StrayNamingSheet()
            }
            .sheet(isPresented: $showCart) {
                CartView()
            }
            .sheet(isPresented: $showScrapbook) {
                ScrapbookView()
            }
            .sheet(isPresented: $showTipJar) {
                TipJarView()
            }
            // The only question the Drift ever asks. Phrased so that neither
            // answer is the "good" one: the app genuinely does not know
            // whether you were sitting there, and pretending to would be
            // worse than asking.
            .alert("Still drifting?", isPresented: driftQuestion) {
                Button("Count it") { engine.endDrift(keep: true) }
                Button("Let it go", role: .cancel) { engine.endDrift(keep: false) }
            } message: {
                Text("This open hour has been running for "
                     + "\(engine.remainingText). Should it count?")
            }
            // She comes back next time you start. Being spooked costs the rest
            // of the phase and nothing else — there is no state anywhere that
            // remembers it.
            .onChange(of: engine.isRunning) { _, running in
                if running { straySpooked = false }
            }
            .onChange(of: strayWantsIn) { _, wants in
                if wants { showStrayNaming = true }
            }
            // The Action Button, Siri and Shortcuts all arrive here. Acted on
            // in the view rather than in the intent because on a cold launch
            // the intent fires before the engine exists.
            .onChange(of: bridge.wantsFocus) { _, wants in
                if wants { consumeIntent() }
            }
            .fullScreenCover(isPresented: onboardingPresented) {
                OnboardingView()
            }
            .onChange(of: engine.settings) { _, _ in
                engine.settingsDidChange()
            }
            .onChange(of: store.hasPlus) { _, hasPlus in
                engine.storeHasPlus = hasPlus
                engine.applyEntitlement(hasPlus: hasPlus)
                engine.refreshMusic(hasPlus: hasPlus)
            }
            .task {
                // `onChange` only fires on a transition, so a launch that is
                // already at the last stage — the ordinary case, since she is
                // reached between sessions — needs asking directly.
                if strayWantsIn { showStrayNaming = true }
                if bridge.wantsFocus { consumeIntent() }
                if LaunchOptions.postcard, engine.album.cards.isEmpty {
                    engine.album.add(Postcard(
                        id: UUID(), date: Date(),
                        place: engine.settings.place.rawValue,
                        dayPart: (LaunchOptions.forcedDayPart ?? DayPart.current()).rawValue,
                        buddy: engine.settings.buddy.rawValue,
                        occasion: .arrival, sessions: 3,
                        sighting: Species.stag.rawValue, minutes: nil
                    ))
                }
                // The other end of the album: four months of daily sitting,
                // in one flag. There is no honest way to reach this by hand.
                if LaunchOptions.panorama,
                   !engine.album.cards.contains(where: { $0.occasion == .panorama }) {
                    engine.album.add(Postcard(
                        id: UUID(), date: Date(),
                        place: engine.settings.place.rawValue,
                        dayPart: (LaunchOptions.forcedDayPart ?? DayPart.current()).rawValue,
                        buddy: engine.settings.buddy.rawValue,
                        occasion: .panorama, sessions: engine.log.todaySessions,
                        sighting: nil,
                        minutes: Grove.panoramaHours * Grove.minutesPerTree
                    ))
                }
                guard LaunchOptions.celebrate else { return }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                engine.completion = PhaseCompletion(
                    finished: .focus,
                    pawsEarned: engine.pawsPerCycle,
                    pawsPerCycle: engine.pawsPerCycle,
                    isCycleComplete: true
                )
            }
        }
    }

    /// Start, if we aren't already, and clear the flag either way so a second
    /// press of the Action Button isn't swallowed.
    private func consumeIntent() {
        bridge.wantsFocus = false
        guard engine.runState != .running, !settling else { return }
        beginOrToggle()
    }

    /// The play button. Everything about the settle-in lives here and nowhere
    /// else — the ritual is a delay in front of `start()`, not a timer state.
    private func beginOrToggle() {
        let startingFocus = engine.runState == .idle && engine.phase == .focus
        guard startingFocus, engine.settings.settleInBeforeFocus else {
            engine.toggle()
            return
        }
        NotificationManager.shared.requestPermissionIfNeeded()
        withAnimation(.easeInOut(duration: 0.35)) { settling = true }
    }

    private func finishSettling() {
        withAnimation(.easeInOut(duration: 0.35)) { settling = false }
        engine.start()
    }

    /// Onboarding shows until it has been completed once.
    private var onboardingPresented: Binding<Bool> {
        Binding(get: { !hasOnboarded }, set: { hasOnboarded = !$0 })
    }

    /// Where the journey currently is, and whatever is crossing it.
    ///
    /// Both follow the same clock the sky does, and the traveller only appears
    /// while a focus session runs — it *is* the countdown, so it has nothing to
    /// say when nothing is counting.
    private var scenery: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let part = LaunchOptions.forcedDayPart ?? DayPart.current(at: context.date)
            let place = engine.settings.place
            // Named `today` rather than `weather`: this view has a `weather`
            // layer property of its own, and a local shadowing it here reads
            // like a typo even when it isn't.
            let today = engine.weather
            ZStack {
                SceneryView(place: place, part: part, weather: today)
                    // Weather is *not* in the id: changing it should cross-fade
                    // the veil, not rebuild the scene. The place and the hour
                    // are what swap the artwork underneath.
                    .id("\(place.rawValue)-\(part.rawValue)")

                if let vignette = place.vignette,
                   engine.isRunning,
                   !engine.phase.isBreak {
                    VignetteView(
                        vignette: vignette,
                        progress: engine.progress,
                        tint: Theme.bark
                    )
                }

                // Whatever came out while you were holding still. Only
                // mounted for its own slice of the phase.
                if engine.isRunning,
                   let sighting = engine.sighting,
                   let phase = sighting.phase(at: engine.progress) {
                    WildlifeView(species: sighting.species, phase: phase)
                        .id(sighting.species)
                }
            }
            .animation(.easeInOut(duration: 0.8), value: place)
        }
        .allowsHitTesting(false)
    }

    /// The old snail, if she is crossing here this month.
    ///
    /// Above the scenery and below everything a finger can reach, which is
    /// where she belongs: she is part of the place rather than part of the
    /// app. Re-read once a minute like the sky, which is roughly two thousand
    /// times more often than she moves.
    /// The water at Harbor Isle, and nowhere else.
    ///
    /// Directly on top of the scenery and under everything else, because the
    /// shore is part of the picture rather than part of the app — the snail
    /// has to be able to stand on it and the stray has to be able to sit above
    /// it. Re-read every five minutes: the tide moves about a hundredth of its
    /// range in that time, which is under a point of screen, and a `.periodic`
    /// timeline stops dead when the app is backgrounded.
    @ViewBuilder
    private var tide: some View {
        if engine.settings.place == .harbor {
            TimelineView(.periodic(from: .now, by: 300)) { context in
                TideView(
                    level: Tide.level(at: context.date),
                    tint: Theme.surface,
                    mud: Theme.bark,
                    rising: Tide.isRising(at: context.date)
                )
            }
        }
    }

    @ViewBuilder
    private var snail: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            SnailView(place: engine.settings.place, x: engine.snailX)
        }
    }

    /// What a finger does to the place you're in.
    ///
    /// Between the scenery and the stray on purpose: a tap on her still
    /// spooks her because she is above this, and everything else falls
    /// through to here. The transport controls are above both, so they always
    /// win. Focus phases leave it mounted but deaf — see `SceneToyView`.
    @ViewBuilder
    private var toys: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let part = LaunchOptions.forcedDayPart ?? DayPart.current(at: context.date)
            SceneToyView(
                toy: engine.settings.place.toy(at: part),
                enabled: !(engine.isRunning && !engine.phase.isBreak),
                tint: Theme.bark,
                accent: Theme.blossom
            )
        }
    }

    /// Whoever is in the hedge.
    ///
    /// Its own layer rather than part of `scenery`, for one concrete reason:
    /// that layer is `allowsHitTesting(false)` so the controls stay reachable
    /// through it, and a stage-two stray has to be touchable to be spooked.
    /// `StrayView` puts the hit region on the sprite alone.
    @ViewBuilder
    private var stray: some View {
        if let stage = visibleStrayStage {
            StrayView(
                stage: stage,
                progress: engine.isRunning ? engine.progress : nil,
                weather: engine.weather,
                spooked: $straySpooked
            )
        }
    }

    /// Which stage of the arc is out in the scene right now, if any.
    private var visibleStrayStage: Stray.Stage? {
        // Some places she can't get to on four legs.
        guard engine.settings.place.strayVisits else { return nil }
        // She can't be in two places: from stage four, a break has her sitting
        // beside your buddy instead, which `BuddyView` draws.
        if engine.isRunning, engine.phase.isBreak, engine.strayStage >= .beside {
            return nil
        }
        // Once she lives here the arc is over, and all that's left is the
        // occasional glimpse of her still doing her rounds.
        if engine.stray.hasJoined {
            return engine.strayCameo ? Stray.Stage.watching : nil
        }
        return engine.strayStage.scenePresence
    }

    /// The one moment she asks for something. Only when nothing is running —
    /// she picks her time, and it is never the middle of your work.
    private var strayWantsIn: Bool {
        hasOnboarded
            && !engine.stray.hasJoined
            && engine.strayStage >= .home
            && engine.runState == .idle
    }

    /// What the sky is doing today.
    ///
    /// Above the sky wash so rain reads against the night tint, and below the
    /// UI so nothing ever falls across the countdown — the same sandwich the
    /// seasons sit in, because they are the same kind of layer.
    ///
    /// The one piece of coordination in here: if the player has chosen the
    /// rain ambience and it is also raining, only one of the two draws. Two
    /// independent rain fields on the same screen is a downpour nobody asked
    /// for, and the ambience is the one the player actually picked.
    @ViewBuilder
    private var weather: some View {
        let today = engine.weather
        let ambienceIsRaining = engine.isRunning
            && engine.settings.ambience == .rain
        if !(ambienceIsRaining && today.suggests == .rain) {
            WeatherView(
                weather: today,
                tint: Theme.bark,
                accent: Theme.accent(for: engine.phase)
            )
            .id(today)
        }
    }

    /// Whatever time of year it is, if it is any in particular.
    ///
    /// Above the sky so fireflies and lanterns read against the night wash,
    /// and below the UI so nothing ever drifts over the countdown. Most of the
    /// year this mounts nothing at all, which is what keeps it special.
    @ViewBuilder
    private var seasonal: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let part = LaunchOptions.forcedDayPart ?? DayPart.current(at: context.date)
            if let season = Season.current(),
               !season.nightOnly || part == .night {
                SeasonalView(
                    season: season,
                    tint: Theme.bark,
                    accent: Theme.accent(for: engine.phase),
                    withBats: Season.hasBats() && part == .night
                )
                .id(season)
            }
        }
        .allowsHitTesting(false)
    }

    /// The time-of-day tint, and stars after dark.
    ///
    /// Re-checked once a minute rather than per frame — a sky that changes over
    /// twenty minutes has nothing to say to a 60Hz display.
    private var sky: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let part = LaunchOptions.forcedDayPart ?? DayPart.current(at: context.date)
            ZStack {
                if let wash = Theme.skyWash(for: part) {
                    wash
                        .opacity(Theme.skyWashOpacity)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 1.2), value: part)
                }
                if part.showsStars {
                    StarfieldView(
                        tint: Theme.bark,
                        moon: Theme.sunshine,
                        nightSessions: engine.log.nightSessions
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var phaseChip: some View {
        Text(engine.phase.title)
            .font(.headline)
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.accent(for: engine.phase)))
            .animation(.easeInOut, value: engine.phase)
    }

    /// Three named crossings. One tap re-lengths all three phases; the dial on
    /// the ring still fine-tunes, and the moment it does no chip is selected.
    private var expeditionRow: some View {
        let current = Expedition.matching(engine.settings)
        return HStack(spacing: 8) {
            ForEach(Expedition.allCases) { expedition in
                let selected = current == expedition
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        expedition.apply(to: &engine.settings)
                    }
                    HapticsDirector.shared.detent()
                } label: {
                    VStack(spacing: 1) {
                        Text(expedition.name)
                            .font(.caption.weight(selected ? .bold : .medium))
                        Text(expedition.summary)
                            .font(.system(size: 9).monospacedDigit())
                            .opacity(0.75)
                    }
                    .foregroundStyle(selected ? Theme.onAccent : Theme.bark.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(
                            selected
                                ? Theme.accent(for: engine.phase)
                                : Theme.cream.opacity(0.72)
                        )
                    )
                }
                .buttonStyle(.squishy(pressedScale: 0.9))
                .accessibilityLabel(
                    "\(expedition.name): \(expedition.focusMinutes) minute focus, "
                        + "\(expedition.shortBreakMinutes) minute break"
                )
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }

    /// Every ambience chip, in a row that scrolls sideways.
    ///
    /// A plain `HStack` worked when there were six of these; at nineteen it was
    /// wider than any phone and SwiftUI just clipped both ends, leaving the
    /// later chips unreachable. The reader scrolls the current choice into
    /// view on appear so the selection is never hidden off-screen.
    private var ambienceRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Ambience.allCases) { option in
                        ambienceButton(for: option)
                            .id(option)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onAppear {
                if engine.settings.ambience != .off {
                    proxy.scrollTo(engine.settings.ambience, anchor: .center)
                }
            }
        }
    }

    private func ambienceButton(for option: Ambience) -> some View {
        let unlocked = store.isUnlocked(option)
        let selected = engine.settings.ambience == option
        // The weather suggests; it never chooses. A ring, not a switch — and
        // not on something already playing or something not owned, because a
        // glow you cannot act on is just noise.
        let suggested = unlocked && !selected && engine.weather.suggests == option

        return Button {
            if unlocked {
                engine.settings.ambience = option
            } else {
                showPaywall = true
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Label(option.label, systemImage: option.systemImage)
                    .labelStyle(.iconOnly)
                    .font(.footnote.weight(.semibold))
                    .frame(width: 38, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 11)
                            .fill(selected ? Theme.accent(for: engine.phase) : Theme.surface.opacity(0.6))
                    )
                    .foregroundStyle(
                        selected
                            ? Theme.onAccent
                            : Theme.bark.opacity(unlocked ? 0.7 : 0.35)
                    )
                    // Static, not pulsing. A ring that breathes on the main
                    // screen is a thing the eye keeps returning to for the
                    // rest of the session, and this is a hint, not an alert.
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(
                                Theme.accent(for: engine.phase)
                                    .opacity(suggested ? 0.8 : 0),
                                lineWidth: 1.5
                            )
                    )

                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(2)
                        .background(Circle().fill(Theme.blossom))
                        .offset(x: 3, y: -3)
                }
            }
            // The chip stays small, but the target around it is a full 44pt:
            // the visible size was below the minimum and these were genuinely
            // hard to hit.
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.squishy(pressedScale: 0.86))
        .accessibilityLabel(
            unlocked
                ? "Ambience: \(option.label)"
                : "Ambience: \(option.label), locked, requires Pawmodoro Plus"
        )
        // A ring is invisible to VoiceOver, so the suggestion has to be said
        // out loud too or it only exists for people who can see it.
        .accessibilityHint(
            suggested ? "Suggested \(engine.weather.suggestionNote ?? "")" : ""
        )
    }

    private var driftQuestion: Binding<Bool> {
        Binding(
            get: { engine.driftNeedsAsking },
            set: { if !$0 { engine.driftNeedsAsking = false } }
        )
    }

    private var playSymbol: String {
        if engine.isDrifting { return "water.waves" }
        return engine.isRunning ? "pause.fill" : "play.fill"
    }

    private var playLabel: String {
        if engine.isDrifting { return "Drifting" }
        return engine.isRunning ? "Pause" : "Start"
    }

    /// The long press is the only way in and the only way out, so it has to be
    /// said out loud — a gesture nobody is told about is a gesture that only
    /// exists for the people who happened to hold the button down.
    private var playHint: String {
        if engine.isDrifting { return "Press and hold to come back in" }
        if engine.runState == .idle, !engine.phase.isBreak {
            return "Press and hold to cast off an open hour with no end time"
        }
        return ""
    }

    private var controls: some View {
        HStack(spacing: 20) {
            Button {
                withAnimation { engine.reset() }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Theme.surface.opacity(0.7)))
                    .foregroundStyle(Theme.bark)
            }
            .buttonStyle(.squishy)
            .accessibilityLabel("Restart phase")

            Button {
                if engine.isDrifting { return }   // holding is the way back
                beginOrToggle()
            } label: {
                Image(systemName: playSymbol)
                    .font(.largeTitle)
                    .frame(width: 84, height: 84)
                    .background(Circle().fill(Theme.accent(for: engine.phase)))
                    .foregroundStyle(Theme.onAccent)
                    .shadow(color: Theme.accent(for: engine.phase).opacity(0.4), radius: 10, y: 4)
                    .contentTransition(.symbolEffect(.replace))
            }
            // A little deeper than the rest: it's the biggest target and the
            // one press people repeat most.
            .buttonStyle(.squishy(pressedScale: 0.88))
            // Long-press casts off, and long-press comes back. Both ends of a
            // drift are deliberate for the same reason: the failure mode that
            // matters is ending one by accident, and a session with no end
            // time is exactly the session you would hate to lose by fumbling
            // a tap.
            .onLongPressGesture(minimumDuration: 0.6) {
                withAnimation {
                    if engine.isDrifting {
                        engine.endDrift()
                    } else if engine.runState == .idle, !engine.phase.isBreak {
                        NotificationManager.shared.requestPermissionIfNeeded()
                        engine.castOff()
                    }
                }
            }
            .accessibilityLabel(playLabel)
            .accessibilityHint(playHint)

            Button {
                withAnimation { engine.skipPhase() }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Theme.surface.opacity(0.7)))
                    .foregroundStyle(Theme.bark)
            }
            .buttonStyle(.squishy)
            .accessibilityLabel("Skip to next phase")
        }
    }
}

#Preview {
    ContentView()
        .environment(TimerEngine())
        .environment(StoreManager())
        .fontDesign(.rounded)
}
