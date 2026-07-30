import SwiftUI

struct ContentView: View {
    @Environment(TimerEngine.self) private var engine
    @AppStorage("pawmodoro.hasOnboarded") private var hasOnboarded = false
    @State private var showSettings = false
    @State private var showStats = false

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
            .fullScreenCover(isPresented: onboardingPresented) {
                OnboardingView()
            }
            .onChange(of: engine.settings) { _, _ in
                engine.settingsDidChange()
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
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.accent(for: engine.phase)))
            .animation(.easeInOut, value: engine.phase)
    }

    private var pawPrints: some View {
        HStack(spacing: 10) {
            ForEach(0..<engine.pawsPerCycle, id: \.self) { index in
                Image(systemName: "pawprint.fill")
                    .font(.title3)
                    .foregroundStyle(
                        index < engine.filledPaws ? Theme.blossom : Theme.bark.opacity(0.18)
                    )
                    .scaleEffect(index < engine.filledPaws ? 1 : 0.85)
                    .animation(.spring(duration: 0.4), value: engine.filledPaws)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(engine.filledPaws) of \(engine.pawsPerCycle) focus sessions this cycle"
        )
    }

    private var ambienceRow: some View {
        HStack(spacing: 10) {
            ForEach(Ambience.allCases) { option in
                let selected = engine.settings.ambience == option
                Button {
                    engine.settings.ambience = option
                } label: {
                    Label(option.label, systemImage: option.systemImage)
                        .labelStyle(.iconOnly)
                        .font(.footnote.weight(.semibold))
                        .frame(width: 42, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selected ? Theme.accent(for: engine.phase) : .white.opacity(0.6))
                        )
                        .foregroundStyle(selected ? .white : Theme.bark.opacity(0.7))
                }
                .accessibilityLabel("Ambience: \(option.label)")
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 20) {
            Button {
                withAnimation { engine.reset() }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.white.opacity(0.7)))
                    .foregroundStyle(Theme.bark)
            }
            .accessibilityLabel("Restart phase")

            Button {
                engine.toggle()
            } label: {
                Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
                    .font(.largeTitle)
                    .frame(width: 84, height: 84)
                    .background(Circle().fill(Theme.accent(for: engine.phase)))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.accent(for: engine.phase).opacity(0.4), radius: 10, y: 4)
            }
            .accessibilityLabel(engine.isRunning ? "Pause" : "Start")

            Button {
                withAnimation { engine.skipPhase() }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.white.opacity(0.7)))
                    .foregroundStyle(Theme.bark)
            }
            .accessibilityLabel("Skip to next phase")
        }
    }
}

#Preview {
    ContentView()
        .environment(TimerEngine())
        .fontDesign(.rounded)
}
