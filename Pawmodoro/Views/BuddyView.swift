import SwiftUI

/// The companion beside the timer. Naps through focus, sits up otherwise.
struct BuddyView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bobbing = false

    private var buddy: Buddy { engine.settings.buddy }

    private var isNapping: Bool {
        engine.isRunning && !engine.phase.isBreak
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                sprite
                    .offset(y: reduceMotion ? 0 : (bobbing ? -4 : 4))
                    // A single constant duration on purpose: `.animation(_:value:)`
                    // only installs a new animation when `value` changes, so making
                    // the duration depend on the phase would silently do nothing.
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: bobbing
                    )

                if isNapping {
                    Text("💤")
                        .font(.title3)
                        .offset(x: 10, y: -4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: isNapping)

            Text(caption)
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .onAppear {
            if !reduceMotion {
                bobbing = true
            }
        }
    }

    private var sprite: some View {
        BuddySprite(buddy: buddy, sleeping: isNapping, size: 104)
    }

    private var caption: String {
        switch engine.runState {
        case .idle:
            return "\(buddy.name) is waiting for you"
        case .running:
            return engine.phase.isBreak
                ? "\(buddy.name) is up and about — enjoy your break"
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
