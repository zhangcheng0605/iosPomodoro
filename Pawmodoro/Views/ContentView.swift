import SwiftUI

struct ContentView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store
    @AppStorage(StorageKeys.hasOnboarded) private var hasOnboarded = false
    @State private var showSettings = false
    @State private var showStats = false
    @State private var showPaywall = false
    @State private var showStudio = false
    @State private var showStrayNaming = false
    /// Whether a stage-two stray has been sent off this phase. Nothing about
    /// her is ever persisted as lost, so this lives no longer than the phase.
    @State private var straySpooked = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(for: engine.phase)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: engine.phase)

                scenery

                stray

                sky

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

                    BuddyView()
                        .padding(.top, 18)

                    pawPrints
                        .padding(.top, 14)

                    Spacer(minLength: 12)

                    ambienceRow
                        .padding(.bottom, 22)

                    controls
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if let completion = engine.completion {
                    CelebrationView(
                        completion: completion,
                        accent: Theme.accent(for: engine.phase),
                        secondary: Theme.blossom,
                        streak: engine.log.currentStreak,
                        onDismiss: { engine.completion = nil }
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
            // She comes back next time you start. Being spooked costs the rest
            // of the phase and nothing else — there is no state anywhere that
            // remembers it.
            .onChange(of: engine.isRunning) { _, running in
                if running { straySpooked = false }
            }
            .onChange(of: strayWantsIn) { _, wants in
                if wants { showStrayNaming = true }
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
                if LaunchOptions.postcard, engine.album.cards.isEmpty {
                    engine.album.add(Postcard(
                        id: UUID(), date: Date(),
                        place: engine.settings.place.rawValue,
                        dayPart: (LaunchOptions.forcedDayPart ?? DayPart.current()).rawValue,
                        buddy: engine.settings.buddy.rawValue,
                        occasion: .arrival, sessions: 3, sighting: Species.stag.rawValue
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
            ZStack {
                SceneryView(place: place, part: part)
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

    private var pawPrints: some View {
        HStack(spacing: 10) {
            ForEach(0..<engine.pawsPerCycle, id: \.self) { index in
                let earned = index < engine.filledPaws
                Image(systemName: "pawprint.fill")
                    .font(.title3)
                    .foregroundStyle(earned ? Theme.blossom : Theme.bark.opacity(0.18))
                    .scaleEffect(earned ? 1 : 0.85)
                    .rotationEffect(.degrees(earned ? 0 : -8))
                    // The newest paw lands last and hardest — it's the one that
                    // was just earned.
                    .animation(
                        .spring(duration: 0.45, bounce: 0.55)
                            .delay(earned ? Double(index) * 0.04 : 0),
                        value: engine.filledPaws
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.cream.opacity(0.7)))
        .onChange(of: engine.filledPaws) { previous, current in
            if current > previous { HapticsDirector.shared.stamp() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(engine.filledPaws) of \(engine.pawsPerCycle) focus sessions this cycle"
        )
    }

    private var ambienceRow: some View {
        HStack(spacing: 8) {
            ForEach(Ambience.allCases) { option in
                ambienceButton(for: option)
            }
        }
    }

    private func ambienceButton(for option: Ambience) -> some View {
        let unlocked = store.isUnlocked(option)
        let selected = engine.settings.ambience == option

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
                engine.toggle()
            } label: {
                Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
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
            .accessibilityLabel(engine.isRunning ? "Pause" : "Start")

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
