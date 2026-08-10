import SwiftUI

struct ContentView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    /// How tall the column above the ambience row wants to be. See
    /// `columnMeasure`; it decides whether that region scrolls.
    @State private var columnHeight: CGFloat = 0
    /// Where the floating toolbar's lower edge is, in global points, and where
    /// the column's own container begins. Both measured rather than assumed —
    /// see `topInset`, which is the whole reason they exist.
    @State private var toolbarBottom: CGFloat = 0
    @State private var containerTop: CGFloat = 0
    /// Whether the screen can pay for the spacing it was drawn with. See
    /// `reflow`, which is the only writer.
    @State private var roomy = true

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

                nearPlane

                sky

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

                mainColumn

                // Where this screen's own container starts, in the same
                // coordinate space the toolbar is measured in. Zero-drawing
                // and flexible, so it reports the container and changes
                // nothing about it. See `topInset`.
                GeometryReader { g in
                    Color.clear
                        .onAppear { containerTop = g.frame(in: .global).minY }
                        .onChange(of: g.frame(in: .global).minY) { _, top in
                            containerTop = top
                        }
                }
                .allowsHitTesting(false)

                // Above the countdown, and it has to be. See `skyTouch`.
                skyTouch

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
            // Five items at idle, and on a Mac they need a **455-point
            // window** for all five to be drawn — below that the last of them
            // fall into AppKit's `»` overflow and out of the accessibility
            // tree with it, where VoiceOver and the keyboard cannot reach
            // them. The lever is not here and not `Platform.macWindow` either,
            // which was measured to have no effect on the opening size at all:
            // it is **`Platform.macWindowMinimum.width`**, which is both the
            // drag floor and — because `.defaultSize` is not honoured under
            // `.windowResizability(.contentSize)` — the opening width. That
            // file carries the five-build measurement and the three fixes that
            // were tried first and didn't work.
            //
            // The margin at 460 is five points. **A sixth item added to this
            // toolbar spends it**, so re-measure there before adding one.
            //
            // The tooltips are macOS-only for a reason worth knowing: `.help`
            // sets the *accessibility hint* on iOS, so an unguarded one here
            // would put "The weeks so far" in VoiceOver's mouth on a phone.
            // `tooltip` in `Mac/Pointer.swift` is `self` there.
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showStats = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(Theme.bark)
                            .pointerBacking()
                            // The toolbar, measuring itself. This is the one
                            // item that is on the bar in every state, so it is
                            // the one that can answer "where does the bar
                            // end?" whatever else is up there. See `topInset`.
                            .background(toolbarProbe)
                    }
                    .accessibilityLabel("Stats")
                    .tooltip("The weeks so far")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showStudio = true
                    } label: {
                        Image(systemName: engine.settings.music == nil
                              ? "music.note" : "music.note.list")
                            .foregroundStyle(engine.settings.music == nil
                                             ? Theme.bark : Theme.blossom)
                            .pointerBacking()
                    }
                    .accessibilityLabel("Sound Studio")
                    .tooltip("Sounds and music")
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
                                .pointerBacking()
                        }
                        .accessibilityLabel("Keep a picture of where you are sitting")
                        .tooltip("A picture of where you are sitting")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Theme.bark)
                            .pointerBacking()
                    }
                    .accessibilityLabel("Settings")
                    .tooltip("Settings")
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
                                .pointerBacking()
                        }
                        .accessibilityLabel("The haiku bench")
                        .tooltip("The haiku bench")
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

    /// The nearest thing in the place — see `SceneForegroundView`.
    ///
    /// **In front of everything that stands in the scene, and behind the
    /// column.** The plan (CONTENT_PLAN F1) put the controls between the two
    /// scenery layers, and that was written when the column was shorter than
    /// the screen. It is not, now: `adaptiveColumn` pins the ambience row and
    /// the transport to the bottom of the glass at every text size above
    /// `.large`, so a near plane drawn over the column would put grass across
    /// the play button of a Pomodoro timer — for the same reason `topInset`
    /// and `chipScale` exist. Measured on an iPhone 17 at the default size the
    /// transport's rim sits at 0.76 of the screen and this layer starts at
    /// 0.811, so today they do not even meet; being under the column means
    /// they can never meet on a phone nobody here has held.
    ///
    /// What it *is* in front of is everything that lives in the place: the
    /// scene, the snail, the toys and the stray. That is where the depth comes
    /// from, and none of it is UI.
    private var nearPlane: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let part = LaunchOptions.forcedDayPart ?? DayPart.current(at: context.date)
            let place = engine.settings.place
            SceneForegroundView(place: place, part: part, weather: engine.weather)
                // Same rule as `scenery`: the place and the hour swap the
                // artwork, the weather only recolours the veil over it.
                .id("\(place.rawValue)-\(part.rawValue)")
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
    /// **Last in this stack, above the countdown.** It was originally below,
    /// on the reasoning that the sky is behind the dial and its answers should
    /// stay there. Measured on a phone, that reasoning cost the feature: the
    /// sky band is 0.125–0.33 of the height and the 260pt dial covers y
    /// 140–400, so the dial sits on 20 of the 47 stars and the phase chip on
    /// two more. Sixteen of the forty-eight links had *both* ends under
    /// them — The Lantern's seven, The Long Watch's seven, two of The
    /// Whale's — which is three figures nobody could ever trace, because the
    /// dial took the touch first. (`skyBottom` reads "stops short of the countdown ring,
    /// which begins around 0.335"; the ring begins at 0.16, and the stars are
    /// not the thing to move — the atlas is built on where they are.)
    ///
    /// Being on top costs almost nothing, because `NightSkyTouchView`'s hit
    /// region is `SkyReach` — the star and moon discs and nothing else. Every
    /// point of the dial that is not within a couple of dozen points of a star
    /// still falls straight through to it, and by day, or mid-focus, there are
    /// no targets at all and the layer is a hole. What it does buy is that the
    /// line following your finger is drawn *over* the dial rather than under
    /// it: a stroke you cannot see is not direct manipulation, and half of
    /// these strokes cross the face.
    ///
    /// The two things it now draws in front of that it used to draw behind:
    /// `weather` (a flash lands over the rain rather than under it — the
    /// answer belongs to the finger, and the rain is scenery) and the dial
    /// itself. Deaf during a focus phase, like the toys — see
    /// `NightSkyTouchView`.
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
        // Declared last so it is drawn and hit-tested last; read *first*, so
        // moving it up the stack didn't quietly move the sky to the bottom of
        // VoiceOver's list. It is the top of the screen and it should be said
        // where it looks.
        .accessibilitySortPriority(1)
    }

    // MARK: The column

    /// Everything the app puts *on top of* the place you're in, in one column.
    ///
    /// **There is one column now, and it is the one that fits.** There used to
    /// be two: the layout that shipped, kept verbatim for `.large` and below,
    /// and an adaptive one for everything above it. The split was written on
    /// the belief that the shipped layout *worked* at the default text size and
    /// only broke as the type grew. Photographed on four phones at `.large`, it
    /// does not work on any of them:
    ///
    /// | phone | what the default screen did |
    /// |---|---|
    /// | iPhone SE (3rd gen), 375×667 | the phase chip's top sits at **−18pt** — above the screen — and the transport row is **100pt below the bottom edge**. The start button of a Pomodoro timer could not be reached at all. |
    /// | iPhone 16e, 390×844 | "Focus" read as "ocus": 14 of the chip's 87 points were behind the leading toolbar capsule. Play button's rim on the final pixel row. |
    /// | iPhone 17, 402×874 | chip 4pt into the toolbar's band and 26pt behind its capsule; play button's rim on the final pixel row. |
    /// | iPhone 17 Pro Max, 440×956 | clear. |
    ///
    /// The column wants about 818pt with a one-line caption and 20 more with
    /// two. Only the Pro Max has that. So the old layout was not "the screen as
    /// designed" on anything else — it was a column overflowing its container
    /// and being centred, hanging off the top into the toolbar and off the
    /// bottom over the home indicator, by half the shortfall each. On the SE
    /// the shortfall was 200 points.
    ///
    /// The adaptive column already solved exactly that, for exactly that
    /// reason, above `.large`: the two rows a person reaches for are pinned to
    /// the bottom and the region above them takes what is left, scrolling only
    /// when the room genuinely runs out. Nothing about that argument was ever
    /// specific to large type. It is now the only column, at every text size,
    /// on both platforms — which also means the phone and the Mac can no
    /// longer drift apart, and the Mac's window-resize argument (below) is
    /// simply the phone argument with a smaller screen.
    ///
    /// ### The Mac was always taking this one, and for the same reason
    ///
    /// A phone's screen is a constant. A window is not, and this one is
    /// resizable down to `Platform.macWindowMinimum` — which had to come down
    /// to 700 points of content, because at 860 the window was 912 tall and a
    /// 1440×900 display has 875 points under the menu bar. The window did not
    /// fit on a 13-inch MacBook Air and could not be shrunk, and the row it
    /// pushed off the bottom was Start. That is the SE's bug with a mouse
    /// attached.
    private var mainColumn: some View {
        adaptiveColumn
    }

    /// The rows, laid out so that they fit.
    ///
    /// **The transport is pinned and the timer face gives way.** Wrapping the
    /// whole screen in a `ScrollView` is the obvious move and the wrong one: a
    /// timer you have to go looking for before you can start it is a worse
    /// timer, and the two rows a person reaches for — which ambience is
    /// playing, and start — are the two that must never move. So they are
    /// pinned to the bottom, and the region above them takes whatever is left.
    ///
    /// The cut is made where the `Spacer` already was, and that is the trick. A
    /// `GeometryReader` is greedy along the vertical exactly as the `Spacer`
    /// was, so the top group sits at its natural height against the top of that
    /// region with the leftover falling below it — which is what a `Spacer`
    /// does — and the two pinned rows land where they always did. Measured
    /// against the shipped build, the ambience row and the transport are
    /// pixel-identical at every text size.
    ///
    /// There is **no scroll view at all** unless the top group genuinely does
    /// not fit. That is not belt-and-braces: a `ScrollView` on this screen costs
    /// 34 points of top content inset — it insets for the floating toolbar it
    /// is allowed to scroll under — which pushes the column down and clips the
    /// treat tray, and its pan gesture would be competing with the ring, which
    /// is a drag target of its own. Neither happens when the plain column is
    /// what is on screen.
    ///
    /// Two things that looked like the tool for this and were not, both ruled
    /// out on screen rather than on paper. `ViewThatFits` chose the
    /// non-scrolling candidate at *every* text size, including ones where a
    /// third of the column was off the screen — inside a stack it is offered as
    /// much height as it likes, so everything "fits". And `.frame(minHeight:)`
    /// on scrolling content does not stretch it: a scroll view proposes an
    /// unspecified height, the flexible frame passes that straight through, and
    /// the child comes back at its ideal size with its `Spacer` collapsed — the
    /// frame then grows and *centres* it, which moved the whole column down by
    /// 34 points.
    private var adaptiveColumn: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let column = topGroup(width: proxy.size.width)
                    // A `GeometryReader` places its child at the child's own
                    // width, leading-aligned. Without this the column would
                    // shrink to its widest row and slide left.
                    .frame(width: proxy.size.width)
                    .background(columnMeasure)

                Group {
                    if columnHeight <= proxy.size.height {
                        column
                    } else {
                        ScrollView(.vertical) { column }
                            .scrollBounceBehavior(.basedOnSize)
                            // The system's own way of saying "there is more
                            // here", and the reason the fade is not carrying
                            // that alone: a fade says the picture continues,
                            // an indicator says you may move it. Costs nothing
                            // and touches nothing.
                            .scrollIndicatorsFlash(onAppear: true)
                            .mask(alignment: .top) { scrollFade }
                    }
                }
                .onAppear { reflow(region: proxy.size.height) }
                .onChange(of: columnHeight) { _, _ in
                    reflow(region: proxy.size.height)
                }
                .onChange(of: proxy.size.height) { _, region in
                    reflow(region: region)
                }
            }
            // A scroll view's clip region is not its frame: it is allowed to
            // draw into the safe area it scrolls under, so scrolled content
            // painted over the toolbar at the top and, worse, straight across
            // the ambience chips and the transport at the bottom — the two
            // rows pinned there precisely so they would always be readable.
            // Cut the region to its own bounds and that cannot happen.
            .clipped()

            ambienceRow
                .padding(.bottom, ambienceGap)

            controls
                // The transport's own clearance from the bottom edge, and the
                // reason the column below still ignores the safe area.
                //
                // Measured on an iPhone 17 and a 16e, the play button's accent
                // ran to the **final pixel row of the display** — 45px of pink
                // still lit at y=2621 of 2621 — which is both a home-indicator
                // collision and the reason its lower rim looked shaved. The
                // obvious fix is to stop ignoring the bottom safe area, and it
                // is the wrong one: that hands 34 points back to the system on
                // every notched phone, and those 34 points come straight out of
                // the region the buddy and the treat tray live in, on the
                // phones that are already 60 short. So the column keeps the
                // full height and the transport buys its own daylight — the
                // cheapest 16 points on the screen, since it is the row with
                // slack under it rather than above.
                .padding(.bottom, 16)
        }
        // Nothing left in this stack is greedy the way the `Spacer` was, so
        // without this it would size to its content and be centred.
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal)
        .padding(.top, topInset)
        // The column runs to the bottom edge of the glass rather than stopping
        // at the home indicator; `transportFloor` above is what keeps the play
        // button off it. Measured, without this the whole transport row moved
        // up by exactly the indicator's height — 34 points this screen cannot
        // pay on a 390pt phone.
        .ignoresSafeArea(.container, edges: .bottom)
    }

    /// What the bottom edge of the scrolling region looks like.
    ///
    /// **A hard cut through a sprite reads as a bug; a fade reads as a page.**
    /// The region only scrolls when the group genuinely does not fit, and the
    /// ordinary sizes now all fit — see `air` and `TimerRingView.diameter`.
    /// The accessibility ones cannot: measured on a 402×874pt phone the top
    /// group wants 855pt at AX5 where 507 exist, and the buddy's caption alone
    /// accounts for close to three hundred of them. No arrangement of a phase
    /// chip, a dial and a cat fits beside that on a phone, so something has to
    /// be below the fold. What can be chosen is what the fold looks like.
    /// Clipped, the last row stops mid-stroke with the ambience chips
    /// beginning immediately underneath and nothing on screen saying there is
    /// more — which is exactly how the regression this replaces looked, and
    /// why it read as a rendering fault rather than as a scroll nobody had
    /// scrolled.
    ///
    /// Twenty-six points of alpha ramp, so whatever meets the fold dissolves
    /// into the row below instead of being guillotined by it. Not a colour and
    /// not themed — a mask is read for its alpha channel and never drawn, so
    /// there is nothing here for `check_contrast.py` to measure and nothing
    /// for a theme to change.
    ///
    /// **What goes under it is chosen, and the order is the point.** The group
    /// gives way from the bottom, and the bottom is the treat tray, then the
    /// caption, then the sprite. So the tray goes first at
    /// accessibility-medium and -large; only past that does the caption start
    /// to run under the fade; and the cat itself is whole at every size this
    /// app has been driven at. The one thing that must never happen — a sprite
    /// sliced in half with chips drawn across the cut — is the thing that is
    /// furthest down the list.
    private var scrollFade: some View {
        VStack(spacing: 0) {
            Rectangle()
            LinearGradient(
                colors: [.black, .black.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 26)
        }
    }

    /// The rows above the old `Spacer`: the part of the screen that gives way.
    ///
    /// The width is only for the expeditions — three capsules that stop fitting
    /// side by side long before the accessibility sizes.
    @ViewBuilder
    private func timerRows(width: CGFloat) -> some View {
        phaseChip
            .padding(.bottom, air.chip)

        TimerRingView()

        // Only while idle: mid-session is the wrong moment to be
        // offered a different session.
        if engine.runState == .idle {
            expeditions(width: width)
                .padding(.top, air.expeditions)
                .transition(.opacity)
        }

        BuddyView(spriteSize: buddySprite)
            .padding(.top, air.buddy)

        // Only when nothing is counting down. A treat offered
        // mid-focus would be a reason to touch the screen during
        // the one stretch of time this app exists to leave alone.
        if engine.runState != .running || engine.phase.isBreak {
            TreatTray()
                .padding(.top, air.treats)
                .transition(.opacity)
        }
    }

    /// The gaps between the rows of the top group, and the two below it.
    ///
    /// **The sky between the rows gives way before the buddy does, and it now
    /// gives way when it has to rather than when the type is large.** On a
    /// screen with room, the air *is* the composition — the rows sit in a
    /// landscape and the spacing is what makes it look like one. On a screen
    /// without room the rows are already touching the edges of what they have,
    /// and the choice is between keeping the spacing and keeping the buddy.
    ///
    /// The trigger used to be the text size, which was a proxy for "is this
    /// screen full?" and a bad one. Photographed at the *default* size: an
    /// iPhone 17 Pro Max has 628 points for a group that wants 597 and should
    /// keep every point of the shipped spacing; an iPhone 16e has 497 for the
    /// same 597 and cannot keep any of it. Same text size, opposite answers. So
    /// the trigger is the measurement — see `reflow`, which is what sets
    /// `roomy`.
    ///
    /// The tight row goes tighter again at the accessibility sizes, where the
    /// rows are two and three times the height they were and the spacing
    /// between them is the only thing on the screen that has not grown with
    /// them. `airSlack` is derived from these two tuples rather than written
    /// down beside them — the rule this repo already keeps for checkers, and
    /// the same reason: a constant that restates a table is a constant that
    /// goes quietly out of date.
    private var air: (chip: CGFloat, expeditions: CGFloat, buddy: CGFloat,
                      treats: CGFloat, floor: CGFloat) {
        roomy ? Self.roomyAir : tightAir
    }

    private static let roomyAir = (chip: CGFloat(20), expeditions: CGFloat(12),
                                   buddy: CGFloat(18), treats: CGFloat(8),
                                   floor: CGFloat(12))

    private var tightAir: (chip: CGFloat, expeditions: CGFloat, buddy: CGFloat,
                           treats: CGFloat, floor: CGFloat) {
        dynamicTypeSize.isAccessibilitySize
            ? (chip: 4, expeditions: 2, buddy: 4, treats: 2, floor: 4)
            : (chip: 8, expeditions: 6, buddy: 8, treats: 4, floor: 6)
    }

    /// The buddy is the last thing on this screen to give ground, and it gives
    /// twelve points of it. Not because twelve looks better — 104 does — but
    /// because on a 390×844 phone those twelve points are the difference
    /// between the caption capsule being whole and being sheared off at the
    /// descenders, which is the exact fault the walk found at AX5 and which has
    /// no business appearing at the default size as the price of fixing it.
    private var buddySprite: CGFloat { roomy ? 104 : 92 }

    /// The gap under the ambience row. Deliberately **not** part of `air`: it
    /// sits outside the measured region, so letting it move with `roomy` would
    /// change the region that decides `roomy`, and that is a layout loop.
    private var ambienceGap: CGFloat { dynamicTypeSize <= .large ? 12 : 14 }

    /// How much taller the roomy arrangement is than the tight one: the
    /// difference between the two spacing tables, plus the buddy's twelve.
    /// Used to decide whether roomy would fit *from a measurement taken while
    /// tight*, which is the only way this switch can be free of hysteresis.
    /// Derived, never written down — see `air`. `reflow` is the reader.
    private var airSlack: CGFloat {
        func total(_ a: (chip: CGFloat, expeditions: CGFloat, buddy: CGFloat,
                         treats: CGFloat, floor: CGFloat)) -> CGFloat {
            a.chip + a.expeditions + a.buddy + a.treats + a.floor
        }
        return total(Self.roomyAir) - total(tightAir) + (104 - 92)
    }

    /// Which arrangement the room can pay for.
    ///
    /// **The two tests are asymmetric on purpose, and that is what stops it
    /// oscillating.** Coming down is "the group I measured does not fit".
    /// Going back up is "the group I measured, *plus the points roomy would
    /// add back*, still fits" — so the arrangement it would switch to is
    /// checked, never the one it is already in. Switch down and the next
    /// measurement is `slack` smaller, which fails the way back by exactly the
    /// margin that failed on the way down; switch up and the next measurement
    /// is `slack` larger, which is the number that was just tested. Neither
    /// direction can immediately undo itself.
    ///
    /// `columnHeight` is measured with whatever arrangement is currently on
    /// screen, so this is the one place that has to know both are the same
    /// height apart every time — hence `airSlack` being derived from the two
    /// tables rather than written beside them.
    ///
    /// **The 24-point deadband is the seatbelt on that assumption.** The two
    /// arrangements differ by exactly `airSlack` today, because nothing either
    /// of them changes can reflow anything else — the caption's width is fixed
    /// and the chips beside the buddy are shorter than the sprite at both
    /// sizes. If that ever stops being true and roomy turns out to cost *more*
    /// than `airSlack`, the way back up would be a lie and the two states
    /// would trade places on every layout pass, forever, on a screen somebody
    /// is looking at. Twenty-four points of margin means the arithmetic has to
    /// be wrong by more than a treat tray's half before that can happen; the
    /// cost is a window that could just barely afford the roomy spacing
    /// keeping the tight one, which nobody can see.
    private func reflow(region: CGFloat) {
        guard columnHeight > 0, region > 0 else { return }
        if roomy {
            if columnHeight > region { roomy = false }
        } else if columnHeight + airSlack + 24 <= region {
            roomy = true
        }
    }

    private func topGroup(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            timerRows(width: width)
        }
        // What is left of the old `Spacer(minLength: 12)`: the region above
        // absorbs the slack now, so all that is wanted here is the floor the
        // Spacer kept between the treats and the ambience row. A padding
        // rather than a Spacer on purpose — a flexible child would make this
        // group report whatever height it was handed, and the measurement has
        // to be the height it actually wants.
        .padding(.bottom, air.floor)
    }

    /// The top group's natural height, as last measured.
    ///
    /// Reported by the group itself rather than assumed from the text size: a
    /// phase chip, a dial, three expedition capsules, a buddy with a caption of
    /// unknown length and a treat tray is not something anybody can add up in
    /// their head, and the answer also depends on the phone, the run state and
    /// whether there is a treat to offer today.
    private var columnMeasure: some View {
        GeometryReader { inner in
            Color.clear
                .onAppear { columnHeight = inner.size.height }
                .onChange(of: inner.size.height) { _, height in
                    columnHeight = height
                }
        }
    }

    /// How far below the container's top the column starts.
    ///
    /// **The toolbar is asked where it ends, rather than guessed at.** The
    /// toolbar floats *over* this screen rather than reserving a bar above it,
    /// and the phase chip is centred in a row the toolbar's own capsules reach
    /// into from both sides. Every previous version of this was a number
    /// somebody chose — eight points, then a ramp to forty-eight, then eight
    /// again — and each of them was measured on one phone at one text size and
    /// silently wrong on the next. The bug it shipped with: on a 390pt phone at
    /// the *default* text size, "Focus" read as "ocus", with fourteen of the
    /// chip's eighty-seven points behind the leading capsule. That capsule had
    /// grown by one glyph — the camera — and nothing in a fixed inset could
    /// know.
    ///
    /// So the clearance is not a constant and not a ramp: the always-present
    /// stats button reports the toolbar's own lower edge in global points
    /// (`toolbarProbe`), the container reports where this column begins, and
    /// the chip starts six points below whichever is lower. Add a sixth
    /// toolbar item, grow the type to AX5, run it on a phone nobody here has
    /// held, and the chip still clears — because the number came from the
    /// toolbar that is actually on screen.
    ///
    /// The measurement cannot feed back on itself: moving the column moves
    /// neither the toolbar nor the container.
    ///
    /// The floor stays at the eight points the screen has always had, for the
    /// case where the probe has not reported yet (first frame) or reports
    /// nothing useful.
    ///
    /// **A Mac is opted out by name, and that is not tidiness.** There the
    /// toolbar is a real bar that reserves its own space *above* the content
    /// rather than glass floating over it, so there is nothing to be clear of
    /// and the honest answer is the floor. Opting out by platform rather than
    /// trusting the arithmetic to come out negative is the cheap insurance:
    /// AppKit's own coordinate space is y-up, and a probe that came back
    /// flipped would push this whole screen down by the height of a window
    /// with nothing on Linux able to see it. The ceiling is the second belt —
    /// the largest clearance any phone has needed is 62 points, on an
    /// iPhone SE, so anything past 72 is a measurement that has gone wrong
    /// rather than a toolbar that is genuinely that tall.
    private var topInset: CGFloat {
        let base: CGFloat = 8
        guard !Platform.isDesktop, toolbarBottom > 0, containerTop > 0 else {
            return base
        }
        // Two points, not ten. A `ToolbarItem`'s own frame already runs about
        // sixteen points below the glass capsule it is drawn in — measured on a
        // 390pt phone, capsule bottom 86.7, item bottom 103 — so this is
        // measuring to the outside of the bar's padding and every point added
        // here is a point taken from a screen that is already short.
        return min(72, max(base, toolbarBottom + 2 - containerTop))
    }

    /// The toolbar, measuring its own lower edge. Draws nothing and changes no
    /// layout — see `topInset`, which is the only reader.
    private var toolbarProbe: some View {
        GeometryReader { g in
            Color.clear
                .onAppear { toolbarBottom = g.frame(in: .global).maxY }
                .onChange(of: g.frame(in: .global).maxY) { _, bottom in
                    toolbarBottom = bottom
                }
        }
    }

    /// How much bigger the glyph chips — ambience, and today's photograph —
    /// get as the text size does.
    ///
    /// These are icon-only buttons: a fixed 38×32 backing inside a 44×44
    /// target, with the glyph set in `.footnote`. The glyph scaled and the
    /// backing did not, and nothing clipped it, so at the accessibility sizes
    /// it grew to about three times the shape it is supposed to sit inside —
    /// chips overlapping each other, glyphs running off the right edge and
    /// landing directly on scenery at 1.00:1 against it, and the accent pill
    /// that says *which* ambience is playing completely hidden behind its own
    /// icon. There was no visible selected state left at all.
    ///
    /// So the backing scales *with* the glyph, by the same factor, and the
    /// factor is on a leash. Keeping the ratio is the whole point: the glyph
    /// can never outgrow the shape that carries the selection, whatever the
    /// text size. The leash exists because this row is nineteen chips sharing a
    /// screen with a countdown — it grows to a size worth having and then
    /// stops, and legibility past that is the ambience list in the Sound
    /// Studio, which is a real list with real labels.
    ///
    /// 1.0 at every ordinary reading size through `.large`, so the default
    /// screen is untouched.
    private var chipScale: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium, .large: 1.0
        case .xLarge: 1.15
        case .xxLarge: 1.3
        case .xxxLarge: 1.45
        default: 1.7
        }
    }

    /// The glyph inside a chip.
    ///
    /// Above `.large` it is sized in points so that it and its backing can
    /// only ever change together — the whole reason the backing stopped being
    /// outgrown. But `.system(size:)` is a *fixed* size and does not answer
    /// Dynamic Type at all, while `.footnote` does: 13pt at `.large` and
    /// about 12 at `.medium`. Sizing every ordinary reading size at a flat 13
    /// therefore made the glyphs visibly **larger** than shipped for anyone
    /// reading below the default, inside backings that had not grown — a
    /// regression at `.medium` measured at 3,739 pixels and a channel delta
    /// of 176, found by an adversarial verifier diffing against the shipped
    /// binary rather than against the default size alone.
    ///
    /// So the ordinary sizes keep the exact font they always had, and the
    /// point-sized branch starts where the adaptive layout does.
    private var chipFont: Font {
        dynamicTypeSize <= .large
            ? .footnote.weight(.semibold)
            : .system(size: 13 * chipScale, weight: .semibold)
    }

    /// The padlock badge on a locked chip, on the same terms and for the same
    /// reason as `chipFont`.
    private var chipBadgeFont: Font {
        dynamicTypeSize <= .large
            ? .footnote
            : .system(size: 13 * chipScale)
    }

    private var chipWidth: CGFloat { 38 * chipScale }
    private var chipHeight: CGFloat { 32 * chipScale }

    /// The hit target around a chip: never smaller than 44pt on either side,
    /// and never smaller than the chip it has to contain.
    private var chipTarget: CGSize {
        CGSize(width: max(44, chipWidth + 6), height: max(44, chipHeight + 12))
    }

    /// The chip is capped at `accessibility1`, and the reason is what sits
    /// under it.
    ///
    /// Uncapped, one word — "Focus" — takes 72 points of vertical screen at
    /// AX5, which is more than the buddy's caption, more than the expedition
    /// row, and about a seventh of everything the top group has to spend. It is
    /// spent on a label whose whole job is to say which of three phases is
    /// running, and the thing it pushes under the fold is the sentence the
    /// buddy is saying. At AX1 the chip is still half again the size of body
    /// text at the default setting.
    ///
    /// The transport row takes the same medicine one size lower
    /// (`.xxxLarge`) — this is the same argument, and it was already the
    /// house answer for a row that must not be allowed to grow without limit.
    private var phaseChip: some View {
        Text(engine.phase.title)
            .font(.headline)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
    ///
    /// Same shape of fix as the column above, one axis over: three capsules of
    /// growing text on a 402pt phone stop fitting side by side well before the
    /// accessibility sizes — "Deep Dive" was already "Deep Di…" at
    /// accessibility-large and all three were two letters and an ellipsis at
    /// the top size, which is three chips nobody can tell apart. Given the
    /// row's own width as a minimum, the three capsules sit centred in it
    /// exactly as they always have while they fit, and take their full names
    /// into a sideways scroll when they don't.
    ///
    /// This is the fix the walk found had worked and must not be undone: at
    /// AX5 the three pills were "Sprin/t" and "Clas/sic" broken across two
    /// lines inside clipped circles. They read correctly now, at every size,
    /// and the sideways scroll is what pays for it.
    private func expeditions(width: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            expeditionChips
                .frame(minWidth: width)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var expeditionChips: some View {
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
                    .pointerRing(Capsule())
                }
                .buttonStyle(.squishy(pressedScale: 0.9))
                .accessibilityLabel(
                    "\(expedition.name): \(expedition.focusMinutes) minute focus, "
                        + "\(expedition.shortBreakMinutes) minute break"
                )
                .tooltip("\(expedition.focusMinutes) minutes of focus, "
                         + "\(expedition.shortBreakMinutes) minute break")
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
            // Spaced explicitly. Left implicit these two rows sat eleven points
            // apart, and on a 390×844 phone eleven points is a fifth of the
            // treat tray — see `air`, where the same argument is made about
            // ninety-two points of it.
            VStack(spacing: 4) {
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
    /// bottom of a tall phone for the seven seconds the line is up. (Above
    /// `.large` the transport is pinned and can no longer be pushed anywhere —
    /// but the 34pt would come out of the timer face's room instead, which is
    /// the same argument with a different victim, so it still widens.)
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
                .tooltip("Today's picture of this place")
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
                .tooltip(developing == nil
                         ? "Today's picture, on the shelf"
                         : "Today's picture, still developing")
            }
        }
    }

    /// The chip in its wide state: what just happened, and where it went.
    private var keptCapsule: some View {
        HStack(spacing: 7 * chipScale) {
            Image(systemName: "hourglass")
                .font(chipFont)
            Text("Kept. It'll be developed on the shelf by morning.")
                // On the same leash as the glyph beside it, and for the same
                // reason: this capsule is one row tall on purpose (see above),
                // so text that grows without its backing growing too just
                // leaves the shape it is meant to sit on.
                .font(chipBadgeFont)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundStyle(Theme.bark.opacity(0.75))
        .padding(.horizontal, 14 * chipScale)
        .frame(height: chipHeight)
        // Its own backing, for the same reason the buddy's caption has one:
        // there is scenery behind this.
        .background(Capsule().fill(Theme.cream.opacity(0.78)))
        .pointerRing(Capsule())
        .frame(height: chipTarget.height)
        .contentShape(Rectangle())
    }

    private func photoChip(icon: String, spent: Bool) -> some View {
        Image(systemName: icon)
            .font(chipFont)
            .frame(width: chipWidth, height: chipHeight)
            .background(
                RoundedRectangle(cornerRadius: 11 * chipScale)
                    .fill(Theme.surface.opacity(0.6))
            )
            .foregroundStyle(Theme.bark.opacity(spent ? 0.5 : 0.7))
            .pointerRing(RoundedRectangle(cornerRadius: 11 * chipScale))
            .frame(width: chipTarget.width, height: chipTarget.height)
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
                    .font(chipFont)
                    .frame(width: chipWidth, height: chipHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 11 * chipScale)
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
                        RoundedRectangle(cornerRadius: 11 * chipScale)
                            .strokeBorder(
                                Theme.accent(for: engine.phase)
                                    .opacity(suggested ? 0.8 : 0),
                                lineWidth: 1.5
                            )
                    )
                    // On the chip rather than on the 44pt target around it, so
                    // the ring is the shape the eye can see. Under the pointer
                    // only; a weather suggestion is still the accent ring
                    // above, and the two are different colours on purpose.
                    .pointerRing(RoundedRectangle(cornerRadius: 11 * chipScale))

                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8 * chipScale, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(2 * chipScale)
                        .background(Circle().fill(Theme.blossom))
                        .offset(x: 3 * chipScale, y: -3 * chipScale)
                }
            }
            // The chip stays small, but the target around it is a full 44pt:
            // the visible size was below the minimum and these were genuinely
            // hard to hit. It grows with the chip from there, so a bigger
            // glyph never means a target that has stopped containing it.
            .frame(width: chipTarget.width, height: chipTarget.height)
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
        // Nineteen chips of icon and nothing else is exactly the row a Mac
        // reads with the pointer. The padlock says the rest.
        .tooltip(unlocked ? option.label : "\(option.label) — Pawmodoro Plus")
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

    /// The same thing the hint says, in the length a tooltip has room for.
    ///
    /// The hold is the only way into and out of a drift, and on a Mac there is
    /// no VoiceOver rotor and no long-press habit to discover it with — so the
    /// one surface that can mention it is the one the pointer rests on. Said
    /// as what the button *is*, not as an instruction.
    private var playTooltip: String {
        if engine.isDrifting { return "Drifting — hold to come back in" }
        if engine.isRunning { return "Pause" }
        if engine.phase.isBreak { return "Start" }
        return "Start — or hold, for an open hour with no end time"
    }

    /// Undo, play and skip.
    ///
    /// **The glyphs are held at `.xxxLarge` because the circles behind them
    /// cannot grow.** Same failure as the ambience chips — a glyph that
    /// answers Dynamic Type inside a backing that does not — and it was left
    /// on the one row the Dynamic Type work exists to protect, where nobody
    /// could see it before, because until that work the transport was off the
    /// bottom of the screen at these sizes. `.title2` is 22pt at `.large` and
    /// 58 at AX5, inside a fixed 56pt circle.
    ///
    /// Measured off the screen on a 402×874pt phone, as the furthest any of
    /// the glyph's own ink gets from the centre of the disc it sits on, in
    /// units of that disc's 28pt radius — 1.0 is the rim:
    ///
    ///                       undo   skip
    ///     large             0.42   0.45
    ///     xxxLarge          0.52   0.57
    ///     accessibility-L   0.73   0.78
    ///     AX5               1.06   1.12   ← ink outside the circle
    ///
    /// At the top sizes they are not glyphs on buttons any more; they are two
    /// brown shapes lying on the grass, and skip is close enough to the play
    /// button to read as part of it.
    ///
    /// The chips answered this by growing their backing, and that was right
    /// for them: a 38×32 chip carrying the accent pill that says which
    /// ambience is playing is small enough that growing it is worth having.
    /// It is the wrong answer here, for two reasons. These circles are 56 and
    /// 84 points against a 44pt minimum — already the most generous targets on
    /// the screen, and growing them buys nothing a finger can feel. And this
    /// row is *pinned*: every point it grows is a point taken off the region
    /// above it, which is the region where the buddy's caption and the treat
    /// tray were being cut off in the first place. A fix for one regression
    /// that pays for itself out of the other is not a fix.
    ///
    /// So the backing keeps the size it shipped at and the glyph is capped at
    /// the largest size that fits inside it. Held at `.xxxLarge` that is 28pt
    /// of `.title2` in a 56pt circle and 40pt of `.largeTitle` in an 84 — half
    /// the diameter in both cases, against 0.39 at the default size, so the
    /// glyphs do still visibly answer the text size right up to the cap: 0.57
    /// of the radius in the table above, with 43% of it still spare. Nothing
    /// below `.xxxLarge` is touched at all, which is every ordinary reading
    /// size. The same trade, and the same wording, as the status line inside
    /// `TimerRingView`: an icon-only control whose target is already twice the
    /// minimum is not the part of this screen that is hard to use, and
    /// VoiceOver reads the labels either way.
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
                    .pointerRing(Circle())
            }
            .buttonStyle(.squishy)
            .accessibilityLabel("Restart phase")
            .tooltip("Restart this phase")

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
                    .pointerRing(Circle())
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
            .tooltip(playTooltip)

            Button {
                withAnimation { engine.skipPhase() }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Theme.surface.opacity(0.7)))
                    .foregroundStyle(Theme.bark)
                    .pointerRing(Circle())
            }
            .buttonStyle(.squishy)
            .accessibilityLabel("Skip to next phase")
            .tooltip("Skip to the next phase")
        }
        // The cap. It belongs on the row rather than on the three glyphs so a
        // fourth control added here cannot be the one that forgets it.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

#Preview {
    ContentView()
        .environment(TimerEngine())
        .environment(StoreManager())
        .fontDesign(.rounded)
}
