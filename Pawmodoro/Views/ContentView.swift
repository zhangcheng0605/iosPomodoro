import SwiftUI

struct ContentView: View {
    @Environment(TimerEngine.self) private var engine
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(for: engine.phase)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: engine.phase)

                VStack(spacing: 28) {
                    phaseChip

                    TimerRingView()

                    BuddyView()

                    pawPrints

                    controls
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Theme.bark)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
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
            ForEach(0..<engine.sessionsPerLongBreak, id: \.self) { index in
                let filled = index < engine.completedFocusSessions % engine.sessionsPerLongBreak
                    || (engine.completedFocusSessions > 0
                        && engine.completedFocusSessions % engine.sessionsPerLongBreak == 0)
                Image(systemName: "pawprint.fill")
                    .font(.title3)
                    .foregroundStyle(filled ? Theme.blossom : Theme.bark.opacity(0.2))
            }
        }
        .accessibilityLabel("\(engine.completedFocusSessions) focus sessions completed")
    }

    private var controls: some View {
        HStack(spacing: 20) {
            Button(action: reset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.white.opacity(0.7)))
                    .foregroundStyle(Theme.bark)
            }

            Button(action: toggleRunning) {
                Image(systemName: engine.state == .running ? "pause.fill" : "play.fill")
                    .font(.largeTitle)
                    .frame(width: 84, height: 84)
                    .background(Circle().fill(Theme.accent(for: engine.phase)))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.accent(for: engine.phase).opacity(0.4), radius: 10, y: 4)
            }

            Button(action: engine.skipPhase) {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.white.opacity(0.7)))
                    .foregroundStyle(Theme.bark)
            }
        }
    }

    private func toggleRunning() {
        if engine.state == .running {
            engine.pause()
        } else {
            NotificationManager.shared.requestPermissionIfNeeded()
            engine.start()
        }
    }

    private func reset() {
        withAnimation { engine.reset() }
    }
}

#Preview {
    ContentView()
        .environment(TimerEngine())
        .fontDesign(.rounded)
}
