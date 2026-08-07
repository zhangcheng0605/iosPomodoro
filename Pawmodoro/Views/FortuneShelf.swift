import SwiftUI

/// The box the drawn slips keep in — the last handful, newest first, each
/// one a dated line of gentle luck that was secretly true.
struct FortuneShelf: View {
    @Environment(TimerEngine.self) private var engine

    private static let shown = 5

    var body: some View {
        let slips = Array(engine.fortunes.slips.suffix(Self.shown).reversed())

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image("fx_slip")
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 15)
                Text("Fortunes")
                Spacer()
                if engine.fortunes.slips.count > Self.shown {
                    Text("the last \(Self.shown)")
                        .foregroundStyle(Theme.bark.opacity(0.5))
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.blossom)

            if slips.isEmpty {
                Text("Start the day's first session and a slip is drawn. "
                     + "Only degrees of luck in this box — no other kind.")
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(0.65))
            } else {
                ForEach(slips) { slip in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text(slip.grade)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.bark.opacity(0.85))
                            Spacer()
                            Text(slip.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Theme.bark.opacity(0.45))
                        }
                        Text(slip.line)
                            .font(.caption)
                            .foregroundStyle(Theme.bark.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.75)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            slips.isEmpty
                ? "Fortunes: none drawn yet. The day's first session draws one."
                : "Fortunes: latest, \(slips[0].grade) — \(slips[0].line)"
        )
    }
}
