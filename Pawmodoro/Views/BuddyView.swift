import SwiftUI

/// The companion beside the timer. Naps through focus, plays through breaks.
/// Emoji are placeholders for illustrated sprites.
struct BuddyView: View {
    @Environment(TimerEngine.self) private var engine
    @State private var bobbing = false

    private var buddy: Buddy { engine.settings.buddy }

    private var isNapping: Bool {
        engine.isRunning && !engine.phase.isBreak
    }

    private var isPlaying: Bool {
        engine.isRunning && engine.phase.isBreak
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Text(emoji)
                    .font(.system(size: 76))
                    .offset(y: bobbing ? -4 : 4)
                    .animation(
                        .easeInOut(duration: isPlaying ? 0.7 : 1.8)
                            .repeatForever(autoreverses: true),
                        value: bobbing
                    )

                if isNapping {
                    Text("💤")
                        .font(.title3)
                        .offset(x: 18, y: -6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: isNapping)

            Text(caption)
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .onAppear { bobbing = true }
    }

    private var emoji: String {
        if isNapping { return buddy.nappingEmoji }
        if isPlaying { return buddy.playingEmoji }
        return buddy.idleEmoji
    }

    private var caption: String {
        switch engine.runState {
        case .idle:
            return "\(buddy.name) is waiting for you"
        case .running:
            return engine.phase.isBreak
                ? "\(buddy.name) is playing — enjoy your break"
                : "Don't wake \(buddy.name) — stay focused!"
        case .paused:
            return "\(buddy.name) wonders where you went…"
        }
    }
}

#Preview {
    BuddyView()
        .environment(TimerEngine())
        .padding()
        .background(Theme.cream)
}
