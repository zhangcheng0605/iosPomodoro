import SwiftUI

/// The reward for finishing a focus session: a burst of paw prints, and — when
/// a whole cycle lands — a card saying what you just did.
///
/// The confetti is one `Canvas` driven by a `TimelineView` that is only mounted
/// while a burst is in flight, so nothing is being drawn or scheduled the other
/// 99% of the time the app is open.
struct CelebrationView: View {
    let completion: PhaseCompletion
    let accent: Color
    let secondary: Color
    let streak: Int
    /// Passed in rather than read from the engine, like `streak`: this view
    /// stays free of the timer so it can be previewed with any completion.
    let buddyName: String
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()
    @State private var showCard = false

    /// How long the paw prints stay on screen.
    private let burst: TimeInterval = 1.7

    var body: some View {
        ZStack {
            if completion.deservesConfetti && !reduceMotion {
                confetti
            }
            if completion.showsCard {
                card
            }
        }
        .allowsHitTesting(completion.showsCard)
        .onTapGesture { onDismiss() }
        .task {
            // The card lingers a little after the paws settle, then leaves on
            // its own — nobody should have to dismiss a congratulation.
            if completion.showsCard {
                withAnimation(.spring(duration: 0.5)) { showCard = true }
                try? await Task.sleep(nanoseconds: 4_200_000_000)
                onDismiss()
            } else {
                try? await Task.sleep(nanoseconds: UInt64(burst * 1_000_000_000))
                onDismiss()
            }
        }
    }

    // MARK: Confetti

    private var confetti: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { canvas, size in
                let elapsed = context.date.timeIntervalSince(started)
                guard elapsed < burst else { return }
                draw(in: &canvas, size: size, elapsed: elapsed)
            } symbols: {
                // Rasterised once by the canvas and stamped for every paw.
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(accent)
                    .tag(Paw.primaryTag)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(secondary)
                    .tag(Paw.secondaryTag)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        guard let primary = canvas.resolveSymbol(id: Paw.primaryTag),
              let secondarySymbol = canvas.resolveSymbol(id: Paw.secondaryTag)
        else { return }

        // Fade the whole burst out rather than each paw separately, so they
        // disappear together instead of thinning into a straggle.
        let fade = 1 - max(0, (elapsed - burst * 0.55) / (burst * 0.45))
        canvas.opacity = max(0, min(1, fade))

        for (index, paw) in Paw.field.enumerated() {
            let symbol = index.isMultiple(of: 3) ? secondarySymbol : primary
            let t = elapsed
            let x = size.width * paw.originX + paw.driftX * t * 60
            // Up fast, then gravity takes it back down.
            let y = size.height * 0.42 - paw.lift * t * 190 + 210 * t * t
            guard y < size.height + 40 else { continue }

            canvas.drawLayer { layer in
                layer.translateBy(x: x, y: y)
                layer.rotate(by: .degrees(paw.spin * t * 220))
                layer.scaleBy(x: paw.scale, y: paw.scale)
                layer.draw(symbol, at: .zero)
            }
        }
    }

    // MARK: The cycle card

    private var card: some View {
        // Each branch lives in its own small view: as one six-way if/else
        // expression, the type checker timed out on the very first Mac build
        // this file ever saw.
        VStack(spacing: 10) {
            cardContent
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surface)
                .shadow(color: Theme.bark.opacity(0.16), radius: 18, y: 8)
        )
        .scaleEffect(showCard ? 1 : 0.85)
        .opacity(showCard ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardAccessibilityLabel)
    }

    @ViewBuilder
    private var cardContent: some View {
        if let seen = completion.saw {
            sightingCard(seen)
        } else if let bond = completion.bondReached {
            bondCard(bond)
        } else if let dream = completion.dreamed {
            dreamCard(dream)
        } else if let figure = completion.completedFigure {
            figureCard(figure)
        } else if let place = completion.arrivedAt {
            arrivalCard(place)
        } else if let laps = completion.driftLaps {
            driftCard(laps)
        } else {
            cycleCard
        }
    }

    /// What an open hour gets instead of a cycle card.
    ///
    /// It says how long, and then it stops. No best, no comparison, no "that's
    /// your longest yet" — the one part of this app with no clock on it is not
    /// going to be handed a scoreboard on the way out.
    @ViewBuilder
    private func driftCard(_ laps: Int) -> some View {
        Image(systemName: "water.waves")
            .font(.system(size: 42))
            .foregroundStyle(accent)
        title(laps == 1 ? "You drifted for a while" : "You drifted a long way")
        footnote(laps == 1
                 ? "One lap of the ring, and back in."
                 : "\(laps) rings, laid down one at a time.")
    }

    /// A sighting outranks the cycle card: it is the rarer thing, and the
    /// whole reason the journal exists.
    @ViewBuilder
    private func sightingCard(_ seen: Species) -> some View {
        Image(seen.sketchAsset)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(height: 46)
        title("You saw a \(seen.name.lowercased())")
        footnote(seen.note)
    }

    /// The rarest card of all — five of these in three hundred sessions.
    @ViewBuilder
    private func bondCard(_ bond: Bond) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<Bond.allCases.count - 1, id: \.self) { index in
                Image(systemName: index < bond.hearts ? "heart.fill" : "heart")
                    .font(.subheadline)
                    .foregroundStyle(index < bond.hearts
                                     ? Theme.blossom : Theme.bark.opacity(0.25))
            }
        }
        title(bond.name)
        footnote(bond.blurb(buddy: buddyName))
    }

    /// Quieter than a sighting and rarer than a cycle.
    @ViewBuilder
    private func dreamCard(_ dream: Dream) -> some View {
        DreamBubble(dream: dream, phase: 0.5)
            .frame(width: 62, height: 62)
        title("\(buddyName) dreamed of \(dream.subject)")
        footnote(dream.line)
    }

    /// Seven of these exist, ever. The figure draws itself — it is layout,
    /// and this is the first time anyone sees it joined up.
    @ViewBuilder
    private func figureCard(_ figure: Constellation) -> some View {
        ConstellationFigure(figure: figure, lit: figure.starCount, tint: accent)
            .frame(width: 92, height: 66)
        title("\(figure.name) is complete")
        footnote("Look up tonight.")
    }

    @ViewBuilder
    private func arrivalCard(_ place: Place) -> some View {
        Image(systemName: place.isPlus ? "lock.fill" : "map.fill")
            .font(.title2)
            .foregroundStyle(accent)
        title("You've reached \(place.name)")
        footnote(place.isPlus
                 ? "\(place.blurb) — unlock it with Pawmodoro Plus"
                 : place.blurb)
    }

    @ViewBuilder
    private var cycleCard: some View {
        HStack(spacing: 8) {
            ForEach(0..<completion.pawsPerCycle, id: \.self) { _ in
                Image(systemName: "pawprint.fill")
                    .font(.headline)
                    .foregroundStyle(accent)
            }
        }
        title("Cycle complete")
        footnote(subtitle)
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.title3.bold())
            .foregroundStyle(Theme.bark)
            .multilineTextAlignment(.center)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Theme.bark.opacity(0.7))
            .multilineTextAlignment(.center)
    }

    /// Plain statements on purpose. As a six-way chain of optional maps and
    /// nil-coalescing, this one expression was what actually timed out the
    /// type checker — the view code around it was fine.
    private var cardAccessibilityLabel: String {
        if let seen = completion.saw {
            return "You saw a \(seen.name). \(seen.note)"
        }
        if let bond = completion.bondReached {
            return "\(bond.name). \(bond.blurb(buddy: buddyName))"
        }
        if let dream = completion.dreamed {
            return "\(buddyName) dreamed of \(dream.subject). \(dream.line)"
        }
        if let figure = completion.completedFigure {
            return "\(figure.name) is complete. Look up tonight."
        }
        if let place = completion.arrivedAt {
            return "You've reached \(place.name). \(place.blurb)"
        }
        if let laps = completion.driftLaps {
            return laps == 1
                ? "You drifted for one lap of the ring."
                : "You drifted for \(laps) laps of the ring."
        }
        return "Cycle complete. \(subtitle)"
    }

    private var subtitle: String {
        let paws = "\(completion.pawsEarned) of \(completion.pawsPerCycle) paws"
        guard streak > 1 else { return "\(paws) · time for a long break" }
        return "\(paws) · \(streak)-day streak"
    }

    // MARK: Particle field

    /// Fixed, not random: the same burst every time is easier to tune, and a
    /// screenshot of it can be compared against an earlier one. `Math.random`
    /// would also make this untestable for no visible gain at 40 particles.
    private struct Paw {
        static let primaryTag = "paw-primary"
        static let secondaryTag = "paw-secondary"

        let originX: Double
        let driftX: Double
        let lift: Double
        let spin: Double
        let scale: Double

        static let field: [Paw] = (0..<38).map { index in
            let n = Double(index)
            // Cheap deterministic spread — irrational multipliers keep the
            // values from lining up into visible rows.
            let a = (n * 0.6180339887).truncatingRemainder(dividingBy: 1)
            let b = (n * 0.7548776662).truncatingRemainder(dividingBy: 1)
            let c = (n * 0.4142135624).truncatingRemainder(dividingBy: 1)
            return Paw(
                originX: 0.12 + a * 0.76,
                driftX: (b - 0.5) * 2.4,
                lift: 1.5 + c * 1.7,
                spin: (a - 0.5) * 2,
                scale: 0.55 + b * 0.5
            )
        }
    }
}
