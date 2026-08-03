import SwiftUI

/// One constellation drawn on its own, for the atlas and the celebration card.
///
/// Shares no code with the sky layer on purpose: there the figure is placed in
/// a band across the whole screen, here it fills a small box. Trying to serve
/// both from one routine meant passing a rect in and getting a tangle out.
struct ConstellationFigure: View {
    let figure: Constellation
    /// How many of its stars are lit. Lines appear only when all of them are.
    let lit: Int
    let tint: Color

    private var isComplete: Bool { lit == figure.starCount }

    var body: some View {
        Canvas { canvas, size in
            let inset = 5.0
            func at(_ index: Int) -> CGPoint {
                let star = figure.stars[index]
                return CGPoint(
                    x: inset + star.x * (size.width - inset * 2),
                    y: inset + star.y * (size.height - inset * 2)
                )
            }

            if isComplete {
                var path = Path()
                for (a, b) in figure.links {
                    path.move(to: at(a))
                    path.addLine(to: at(b))
                }
                canvas.stroke(path, with: .color(tint.opacity(0.45)), lineWidth: 1)
            }

            for index in 0..<figure.starCount {
                let point = at(index)
                // Unlit stars are drawn as hollow pin-pricks rather than left
                // out: the shape of what you're building is the reason to
                // build it, and hiding it would make the atlas a progress bar.
                let filled = index < lit
                let r = filled ? (isComplete ? 2.6 : 2.2) : 1.6
                let rect = CGRect(x: point.x - r, y: point.y - r,
                                  width: r * 2, height: r * 2)
                canvas.fill(
                    Path(ellipseIn: rect),
                    with: .color(tint.opacity(filled ? 0.95 : 0.16))
                )
            }
        }
        .accessibilityHidden(true)
    }
}

/// The star atlas: what the night sky owes you, and what you've already put in it.
///
/// Free forever. The price is focusing after dark, and that is the whole point
/// — this is the one thing in the app that cannot be bought, hurried, or had
/// by travelling somewhere.
struct StarAtlasView: View {
    @Environment(TimerEngine.self) private var engine

    private var nights: Int { engine.log.nightSessions }

    private var completed: Int {
        ConstellationAtlas.completedCount(nightSessions: nights)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Star atlas")
                    .font(.headline)
                    .foregroundStyle(Theme.bark)
                Spacer()
                Text("\(completed) of \(ConstellationAtlas.all.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.bark.opacity(0.6))
                    .monospacedDigit()
            }

            Text(blurb)
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.6))

            VStack(spacing: 10) {
                ForEach(Array(ConstellationAtlas.all.enumerated()), id: \.element.id) {
                    index, figure in
                    row(index: index, figure: figure)
                }
            }

            if wanderers > 0 {
                Text(wanderers == ConstellationAtlas.wandererCap
                     ? "…and every wandering star there is."
                     : "…and \(wanderers) wandering \(wanderers == 1 ? "star" : "stars"), "
                       + "loose in the sky.")
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(0.55))
                    .padding(.top, 2)
            }
        }
    }

    private var wanderers: Int { ConstellationAtlas.wanderers(nightSessions: nights) }

    private var blurb: String {
        guard completed < ConstellationAtlas.all.count else {
            return "Every figure is up. The sky is yours now; it just keeps count."
        }
        return "Finish a focus session after dark and one star goes up. "
            + "Nothing else does this."
    }

    private func row(index: Int, figure: Constellation) -> some View {
        let lit = ConstellationAtlas.litStars(of: index, nightSessions: nights)
        let complete = lit == figure.starCount
        let started = lit > 0

        return HStack(alignment: .top, spacing: 12) {
            ConstellationFigure(figure: figure, lit: lit, tint: Theme.bark)
                .frame(width: 62, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.bark.opacity(complete ? 0.10 : 0.05))
                )

            VStack(alignment: .leading, spacing: 3) {
                // An unbuilt figure is shown, not hidden — same house rule as
                // the padlocks and the journal's silhouettes. It just doesn't
                // get its name until you've earned it.
                Text(complete ? figure.name : "Unnamed")
                    .font(.subheadline.weight(complete ? .semibold : .regular))
                    .foregroundStyle(Theme.bark.opacity(complete ? 0.95 : 0.5))

                Text(complete ? figure.lore : hint(lit: lit, of: figure, started: started))
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(complete ? 0.65 : 0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            complete
                ? "\(figure.name), complete. \(figure.lore.replacingOccurrences(of: "\n", with: " "))"
                : "Unnamed constellation, \(lit) of \(figure.starCount) stars"
        )
    }

    /// The hint line doubles as the progress readout — the count of stars still
    /// to go is the only number the atlas ever shows, and it is a reason to
    /// come back at night rather than a score.
    private func hint(lit: Int, of figure: Constellation, started: Bool) -> String {
        let remaining = figure.starCount - lit
        guard started else {
            return "\(figure.starCount) stars, none of them yet"
        }
        return remaining == 1
            ? "One more night and it has a name"
            : "\(remaining) more nights"
    }
}

#Preview {
    ScrollView {
        StarAtlasView()
            .padding()
    }
    .background(Theme.cream)
    .environment(TimerEngine())
}
