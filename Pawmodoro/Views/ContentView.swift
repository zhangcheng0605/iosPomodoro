import SwiftUI

struct ContentView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store
    @AppStorage(StorageKeys.hasOnboarded) private var hasOnboarded = false
    @State private var showSettings = false
    @State private var showStats = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(for: engine.phase)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: engine.phase)

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
            .fullScreenCover(isPresented: onboardingPresented) {
                OnboardingView()
            }
            .onChange(of: engine.settings) { _, _ in
                engine.settingsDidChange()
            }
            .onChange(of: store.hasPlus) { _, hasPlus in
                engine.applyEntitlement(hasPlus: hasPlus)
            }
            .task {
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
