import SwiftUI

struct TimerRingView: View {
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.bark.opacity(0.12), lineWidth: 18)

            Circle()
                .trim(from: 0, to: engine.progress)
                .stroke(
                    Theme.accent(for: engine.phase),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: engine.progress)

            VStack(spacing: 4) {
                Text(engine.remainingText)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.bark)
                    .contentTransition(.numericText())

                Text(statusLine)
                    .font(.subheadline)
                    .foregroundStyle(Theme.bark.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 36)
        }
        .frame(width: 260, height: 260)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(engine.phase.title), \(engine.remainingText) remaining")
    }

    private var statusLine: String {
        let buddy = engine.settings.buddy.name
        switch engine.runState {
        case .idle:
            return "ready when you are"
        case .running:
            return engine.phase.isBreak ? "stretch those paws!" : "shhh… \(buddy) is napping"
        case .paused:
            return "paused"
        }
    }
}

#Preview {
    TimerRingView()
        .environment(TimerEngine())
        .padding()
        .background(Theme.cream)
}
