import SwiftUI

/// Three slow breaths before the boat leaves.
///
/// Every other timer starts with a click. This one, if you ask it to, takes a
/// breath first — the cheapest "this app is different" moment in the whole
/// plan, and the only one that costs nothing to build and nothing to run.
///
/// Entirely a UI layer: it defers the call to `engine.start()` and touches
/// nothing else, so the absolute-end-date countdown underneath stays exactly
/// as it was. Tap anywhere to skip.
struct SettleInView: View {
    /// Called when the breaths are done, or the moment it's tapped.
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breath = 0
    @State private var expanded = false
    @State private var finished = false

    /// Three breaths of four seconds. Twelve seconds is long enough to
    /// actually settle and short enough that nobody reaches for the skip.
    private static let breaths = 3
    private static let perBreath: TimeInterval = 4

    var body: some View {
        ZStack {
            Theme.cream.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                if reduceMotion {
                    // A plain count instead of a swelling ring: the ritual
                    // survives, the movement doesn't.
                    Text("\(Self.breaths - breath)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.blossom)
                        .contentTransition(.numericText())
                } else {
                    ring
                }

                Text(prompt)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Theme.bark.opacity(0.8))
                    .animation(.easeInOut, value: prompt)

                Text("\(Pointing.Tap) to skip")
                    .font(.footnote)
                    .foregroundStyle(Theme.bark.opacity(0.45))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task { await run() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Settling in. Three slow breaths before the session starts.")
        .accessibilityAction(named: "Skip") { finish() }
    }

    private var ring: some View {
        Circle()
            .strokeBorder(Theme.blossom.opacity(0.55), lineWidth: 10)
            .background(Circle().fill(Theme.blossom.opacity(0.12)))
            .frame(width: 168, height: 168)
            .scaleEffect(expanded ? 1 : 0.62)
            .animation(
                .easeInOut(duration: Self.perBreath / 2), value: expanded
            )
    }

    private var prompt: String {
        if reduceMotion { return "Settling in" }
        return expanded ? "Breathe out…" : "Breathe in…"
    }

    /// One task rather than a timer: it is cancelled automatically when the
    /// view goes away, which is what stops a skipped ritual from finishing
    /// twice.
    private func run() async {
        for index in 0..<Self.breaths {
            breath = index
            expanded = true
            try? await Task.sleep(nanoseconds: UInt64(Self.perBreath / 2 * 1_000_000_000))
            if Task.isCancelled { return }
            expanded = false
            try? await Task.sleep(nanoseconds: UInt64(Self.perBreath / 2 * 1_000_000_000))
            if Task.isCancelled { return }
        }
        finish()
    }

    /// Guarded, because a tap during the last breath would otherwise start the
    /// session twice.
    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

#Preview {
    SettleInView(onFinish: {})
}
