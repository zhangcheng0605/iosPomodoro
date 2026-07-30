import SwiftUI

enum Buddy: String, CaseIterable, Identifiable {
    case cat
    case dog

    var id: String { rawValue }

    var name: String {
        switch self {
        case .cat: "Mochi"
        case .dog: "Biscuit"
        }
    }

    var pickerLabel: String {
        switch self {
        case .cat: "🐱 Mochi the cat"
        case .dog: "🐶 Biscuit the dog"
        }
    }
}

/// Emoji placeholder for the buddy — swap for real sprite art in Phase 2.
/// The buddy naps while you focus and plays during breaks.
struct BuddyView: View {
    @Environment(TimerEngine.self) private var engine
    @AppStorage("buddy") private var buddyRawValue = Buddy.cat.rawValue
    @State private var bobbing = false

    private var buddy: Buddy { Buddy(rawValue: buddyRawValue) ?? .cat }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Text(buddyEmoji)
                    .font(.system(size: 72))
                    .offset(y: bobbing ? -4 : 4)
                    .animation(
                        .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                        value: bobbing
                    )

                if isNapping {
                    Text("💤")
                        .font(.title3)
                        .offset(x: 16, y: -8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: isNapping)

            Text(caption)
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.7))
        }
        .onAppear { bobbing = true }
    }

    private var isNapping: Bool {
        engine.state == .running && engine.phase == .focus
    }

    private var buddyEmoji: String {
        switch (buddy, engine.state, engine.phase) {
        case (.cat, .running, .focus): "😴"
        case (.cat, .running, _): "😸"
        case (.cat, .paused, _): "🐱"
        case (.cat, .idle, _): "🐱"
        case (.dog, .running, .focus): "😴"
        case (.dog, .running, _): "🐶"
        case (.dog, .paused, _): "🐕"
        case (.dog, .idle, _): "🐶"
        }
    }

    private var caption: String {
        switch engine.state {
        case .idle:
            "\(buddy.name) is waiting for you"
        case .running:
            engine.phase == .focus
                ? "Don't wake \(buddy.name) — stay focused!"
                : "\(buddy.name) is playing — enjoy your break"
        case .paused:
            "\(buddy.name) wonders where you went…"
        }
    }
}

#Preview {
    BuddyView()
        .environment(TimerEngine())
        .padding()
        .background(Theme.cream)
}
