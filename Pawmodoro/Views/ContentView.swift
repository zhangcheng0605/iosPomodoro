import SwiftUI

struct ContentView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @State private var showBench = false
    @State private var showScrapbook = false
    @State private var showTipJar = false
    /// True while the three breaths are running. The engine knows nothing
    /// about this — `start()` is simply called later.
    @State private var settling = false
    /// Whether a stage-two stray has been sent off this phase. Nothing about
    /// her is ever persisted as lost, so this lives no longer than the phase.
    @State private var straySpooked = false
    /// The camera's brief blink. Under Reduce Motion the click alone
    /// carries it — the flash never mounts.
    @State private var shutter = false
    /// True for a few seconds after today's shot is taken: the line that
    /// says what just happened and where the picture went.
    @State private var keptLine = false
    /// The photo shelf, reached from the developing chip. Deliberately its
    /// own sheet: the shelf also lives in Stats, but fourteen cards down a
    /// scroll is not somewhere a one-shot can point.
    @State private var showPhotos = false
    /// The signal that the sky should answer a touch, and how far it is
    /// currently leaning. See `SkyStir`.
    @State private var skyStir = SkyStir.shared
    /// 0 when the sky is still, 1 at the furthest point of a stir. Driven by
    /// two `withAnimation` calls and nothing else — there is no timeline and
    /// no timer behind this, so a still sky costs exactly one stored `Double`.
    @State private var skyLean: Double = 0

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

                clockwork

                tide

                snail

                toys

                stray

                sky

                skyTouch

                weather

                seasonal

                // Winter's one sensation: on cold mornings the pane wakes
                // frosted, and a finger clears it. Above the scene and the
                // toys — the frost is on the glass, so the wipe wins while
                // it stands — and below the UI, whose text carries its own
                // backing anyway.
                FrostView()

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

                if shutter {
                    Theme.cream
                        .opacity(0.55)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

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
                // The bench is furniture: it only exists while nothing is
                // running, and it never asks. Off-hours only, like sitting
                // down anywhere.
                if engine.runState == .idle {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showBench = true
                        } label: {
                            Image(systemName: "scroll")
                                .foregroundStyle(Theme.bark)
                        }
                        .accessibilityLabel("The haiku bench")
                    }
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
            .sheet(isPresented: $showBench) {
                HaikuBenchView()
            }
            .sheet(isPresented: $showCart) {
                CartView()
            }
            .sheet(isPresented: $showScrapbook) {
                ScrapbookView()
            }
            .sheet(isPresented: $showPhotos) {
                PhotoShelfSheet()
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
            // The sky's answer to a touch. Two animations rather than one
            // spring: out fast, back slow, and never crossing back through
            // centre — a spring would overshoot, and an overshoot on a focus
            // timer is a bounce. Nothing is scheduled and nothing is mounted;
            // when the second animation finishes, the sky is a static layer
            // again with no clock behind it.
            //
            // **The return leg goes in the completion handler, and it has to.**
            // Written as two back-to-back `withAnimation` calls — the second
            // carrying `.delay(out)` — the sky does not move at all: both
            // mutations land in the same runloop tick, SwiftUI renders once
            // with the final value, and `skyLean` goes 0 → 0. Nothing to
            // animate, no error, no warning, and a feature that silently does
            // nothing. Chaining on completion is what makes the outward leg a
            // state change SwiftUI can actually see.
            .onChange(of: skyStir.count) { _, _ in
                withAnimation(.easeOut(duration: SkyStir.out)) {
                    skyLean = 1
                } completion: {
                    withAnimation(.easeInOut(duration: SkyStir.back)) {
                        skyLean = 0
                    }
                }
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
            // The year, kept: due from the day the anniversary rolls past,
            // standing until seen — presented, never announced, so it
            // cannot be missed.
            .fullScreenCover(isPresented: Binding(
                get: { engine.chronicle.yearDue != nil },
                set: { if !$0 { engine.chronicle.yearPresented() } }
            )) {
                YearKeptView(years: engine.chronicle.yearDue ?? 1) {
                    engine.chronicle.yearPresented()
                }
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
                if LaunchOptions.openBench { showBench = true }
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
                    WildlifeView(
                        species: sighting.species, phase: phase,
                        pale: sighting.pale
                    )
                    .id(sighting.species)
                }
            }
            .animation(.easeInOut(duration: 0.8), value: place)
        }
        .allowsHitTesting(false)
    }

    /// Whatever the timetable says is happening at this place, this minute.
    ///
    /// Above the scenery, below everything touchable. Checked twice a
    /// minute — a ferry that leaves at 8:00 sharp deserves punctuality —
    /// and each event view mounts only for its own window, then unmounts
    /// and takes its TimelineView with it.
    @ViewBuilder
    private var clockwork: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            if let event = ClockworkEvent.active(
                at: context.date, place: engine.settings.place
            ) {
                if event == .meadowHeron {
                    ClockworkHeronView(timetable: engine.timetable)
                        .id(event)
                } else {
                    ClockworkEventView(
                        event: event, timetable: engine.timetable,
                        tint: Theme.bark
                    )
                    .id(event)
                }
            }
        }
        .allowsHitTesting(false)
    }

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

    /// The old snail, if she is crossing here this month.
    ///
    /// Above the scenery and below everything a finger can reach, which is
    /// where she belongs: she is part of the place rather than part of the
    /// app. Re-read once a minute like the sky, which is roughly two thousand
    /// times more often than she moves.
    ///
    /// (Her doc comment had drifted onto `tide` when that was inserted
    /// between the two; put back with its own member during the merge.)
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
                accent: Theme.blossom,
                onTrick: { engine.cueTrick($0) }
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
                    // Leaned as one piece, and pointedly *not* including the
                    // wash above: the wash fills the screen, so sliding it
                    // eight points would show the phase gradient in the gap
                    // along one edge. These are sparse layers over
                    // transparency and have no edge to expose.
                    Group {
                        StarfieldView(
                            tint: Theme.bark,
                            moon: Theme.sunshine,
                            nightSessions: engine.log.nightSessions
                        )
                        // Three windows a year, the sky sheds. Real dates only.
                        if ShowerCalendar.isShowerNight(on: context.date) {
                            MeteorShowerView()
                        }
                    }
                    .skyStirred(skyLean)
                } else {
                    // The daytime sun, which no scene paints — see `SunView`
                    // for why the clouds are not invited. Mounted un-leaned:
                    // it leans its own disc internally and keeps its
                    // full-screen glow still, for the same edge reason.
                    SunView(part: part, tint: Theme.sunshine, stir: skyLean)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Send a breath of wind through the sky.
    ///
    /// Called by the two rows the sky answers to — the mode chips and the
    /// ambience icons. Refused mid-focus; `SkyStir.allowed` carries the
    /// argument for that.
    ///
    /// Under Reduce Motion this returns having done nothing, which is the
    /// honest reading of "settle instantly": the sky is already settled. No
    /// information lives in the movement — the chip's own selected state says
    /// everything the tap meant — so nothing is lost by holding still.
    private func stirSky() {
        guard !reduceMotion else { return }
        guard SkyStir.allowed(
            isRunning: engine.isRunning, isBreak: engine.phase.isBreak
        ) else { return }
        skyStir.stir()
    }

    /// What a finger does to the night sky.
    ///
    /// Its own layer rather than part of `sky`, for the same reason the stray
    /// is not part of `scenery`: that layer is `allowsHitTesting(false)` so
    /// the controls stay reachable through it, and a star has to be touchable
    /// to be joined. `NightSkyTouchView` puts the hit region on the stars and
    /// the moon alone, so everything between them still falls through to the
    /// toys underneath.
    ///
    /// Above `sky` so the answers draw over the moon they are about, and below
    /// `weather` so a storm still crosses in front of the whole thing. Deaf
    /// during a focus phase, like the toys — see `NightSkyTouchView`.
    @ViewBuilder
    private var skyTouch: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let part = LaunchOptions.forcedDayPart ?? DayPart.current(at: context.date)
            if part.showsStars {
                NightSkyTouchView(
                    enabled: !(engine.isRunning && !engine.phase.isBreak),
                    nightSessions: engine.log.nightSessions,
                    tint: Theme.bark,
                    moon: Theme.sunshine
                )
                // The same lean, the same value, so the hit regions travel
                // with the stars they belong to. Leaning only the drawing
                // would make a star tapped mid-stir miss by eight points for
                // two and a half seconds — see `skyStirred`.
                .skyStirred(skyLean)
            }
        }
    }

    private var phaseChip: some View {
        Text(engine.phase.title)
            .font(.headline)
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.accent(for: engine.phase)))
            // The day's slip, tucked into the chip's corner once drawn —
            // purely decorative, gone at midnight with the fortune itself.
            .overlay(alignment: .topTrailing) {
                if engine.fortunes.today != nil {
                    Image("fx_slip")
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 13, height: 20)
                        .rotationEffect(.degrees(12))
                        .offset(x: 10, y: -8)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
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
                    stirSky()
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
            photoControl
        }
    }

    /// Today's one photograph of the *world*: the shutter while the shot is
    /// unspent, and afterwards the shot itself, still in the bath. Out of
    /// reach during focus like everything else that isn't the timer.
    ///
    /// Deliberately not a camera glyph. The merge brought in a second
    /// camera — the Scrapbook's, in the toolbar — and two identical icons on
    /// one screen for two unrelated things (a picture the world gives you,
    /// and a picture you take of your desk) is a screen nobody can read.
    /// This one is a framed picture, because that is what it produces.
    ///
    /// **The control does not vanish when it is used, it changes state.** It
    /// used to disappear on the tap, which is the worst thing a *one-shot*
    /// can do: the flash is a fifth of a second, the haptic is nothing on a
    /// table, the photograph legitimately renders nothing until tomorrow,
    /// and there is no second tap to work out what happened with. So the
    /// button becomes a spent chip that stands for the rest of the day, says
    /// the shot is developing, and opens the shelf it went to — and for a
    /// few seconds after the tap the chip *widens* into a sentence saying so
    /// in words. Same idiom as the buddy's caption, and deliberately the
    /// same two values (footnote `bark` at 0.75 on a `cream` capsule at
    /// 0.78), because that is the pair `check_contrast.py` already measures
    /// over scenery. Attached to the thing that caused it rather than routed
    /// through `BuddyView`, so it can never lose the caption's precedence
    /// race against a greeting or a remark and go unsaid.
    ///
    /// It widens rather than stacking a second row: this row sits between
    /// the ambience list and the transport, with a `Spacer(minLength: 12)`
    /// above it, so an extra 34pt of height pushes the play button off the
    /// bottom of a tall phone for the seven seconds the line is up.
    @ViewBuilder
    private var photoControl: some View {
        // Read before the branch, on purpose. `developing()` touches the
        // album's observed `photos`, while `shotAvailable()` reads only the
        // `@ObservationIgnored` day stamp — so without this line a body that
        // took the shutter branch would register no dependency on the album
        // at all, and would be relying on a `@State` flag to redraw itself.
        let developing = engine.photos.developing()
        let offHours = !(engine.isRunning && !engine.phase.isBreak)
        if offHours {
            if engine.photos.shotAvailable() {
                Button {
                    guard engine.snapPhoto() else { return }
                    withAnimation(.easeOut(duration: 0.25)) { keptLine = true }
                    // The flash is motion, and the plan promised Reduce
                    // Motion keeps the click and drops it. The line carries
                    // the news either way.
                    if !reduceMotion {
                        withAnimation(.easeOut(duration: 0.2)) { shutter = true }
                        Task {
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            withAnimation(.easeIn(duration: 0.3)) { shutter = false }
                        }
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 7_000_000_000)
                        withAnimation(.easeInOut(duration: 0.4)) { keptLine = false }
                    }
                } label: {
                    photoChip(icon: "photo.on.rectangle", spent: false)
                }
                .buttonStyle(.squishy(pressedScale: 0.86))
                .accessibilityLabel("Keep today's picture of this place")
            } else {
                // The shot is spent. Usually it is still in the bath; if it
                // has already developed (a day rolled over with the screen
                // open, or `-PawmodoroDevelop`) the chip stays put and still
                // points at the shelf, because a control that vanishes is
                // the bug this whole branch exists to undo.
                Button {
                    showPhotos = true
                } label: {
                    if keptLine {
                        keptCapsule
                    } else {
                        // Not the shutter's own glyph: an identical icon
                        // that now opens a shelf instead of taking a
                        // picture is the same confusion in a smaller form.
                        photoChip(
                            icon: developing == nil
                                ? "photo.on.rectangle.angled" : "hourglass",
                            spent: true
                        )
                    }
                }
                .buttonStyle(.squishy(pressedScale: 0.92))
                .accessibilityLabel(
                    developing == nil
                        ? "Today's picture is on the shelf. Open the photo shelf"
                        : "Today's picture is developing. Open the photo shelf"
                )
            }
        }
    }

    /// The chip in its wide state: what just happened, and where it went.
    private var keptCapsule: some View {
        HStack(spacing: 7) {
            Image(systemName: "hourglass")
                .font(.footnote.weight(.semibold))
            Text("Kept. It'll be developed on the shelf by morning.")
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(Theme.bark.opacity(0.75))
        .padding(.horizontal, 14)
        .frame(height: 32)
        // Its own backing, for the same reason the buddy's caption has one:
        // there is scenery behind this.
        .background(Capsule().fill(Theme.cream.opacity(0.78)))
        .frame(height: 44)
        .contentShape(Rectangle())
    }

    private func photoChip(icon: String, spent: Bool) -> some View {
        Image(systemName: icon)
            .font(.footnote.weight(.semibold))
            .frame(width: 38, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(Theme.surface.opacity(0.6))
            )
            .foregroundStyle(Theme.bark.opacity(spent ? 0.5 : 0.7))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
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
                stirSky()
            } else {
                // No stir behind a padlock. The sky answering a tap that
                // opened a paywall would read as the sky selling something.
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
