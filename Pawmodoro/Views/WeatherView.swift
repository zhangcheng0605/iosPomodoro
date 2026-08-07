import SwiftUI

/// What today's sky is doing, drawn.
///
/// Modelled on `SeasonalView` rather than on `AmbientSceneView`, and the
/// difference matters: the ambience layer is a *choice*, mounted only while the
/// timer runs with a sound picked. Weather is not chosen and is not earned — it
/// is simply what it is like outside today, so it has to be there the moment
/// the app opens. Opening the app in the morning is meant to be like opening
/// the curtains, and curtains do not wait for you to press play.
///
/// 12fps, the same as the seasons and for the same reason: this is on screen
/// far more of the time than the weather-as-ambience layer ever was, and rain
/// falling does not need sixty frames a second to fall.
struct WeatherView: View {
    let weather: Weather
    let tint: Color
    let accent: Color

    /// Nothing here carries information the app needs you to have, so all of
    /// it goes away under Reduce Motion — the veil in `SceneryView` stays, and
    /// the veil is what tells you it is raining. Motion is the decoration.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()

    var body: some View {
        if weather.hasParticles && !reduceMotion {
            TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { context in
                Canvas { canvas, size in
                    draw(&canvas, size: size,
                         t: context.date.timeIntervalSince(started))
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func draw(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        switch weather {
        case .drizzle:
            fall(&canvas, size: size, t: t, count: 18,
                 speed: 200, length: 7, drift: 4, opacity: 0.14, width: 1)
        case .rain:
            fall(&canvas, size: size, t: t, count: 30,
                 speed: 300, length: 14, drift: 8, opacity: 0.22, width: 1.2)
        case .storm:
            fall(&canvas, size: size, t: t, count: 38,
                 speed: 400, length: 20, drift: 14, opacity: 0.26, width: 1.4)
            flash(&canvas, size: size, t: t)
        case .snow:
            snow(&canvas, size: size, t: t)
        case .mist:
            banks(&canvas, size: size, t: t)
        case .breeze:
            gusts(&canvas, size: size, t: t)
        case .clear, .overcast, .golden:
            break
        }
    }

    // MARK: The rain family

    /// One routine for drizzle, rain and storm — they differ only in how many,
    /// how fast, how long and how hard the wind is leaning on them. Three
    /// copies of this with the numbers baked in would be three places to fix
    /// the day the angle looks wrong.
    private func fall(
        _ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval,
        count: Int, speed: Double, length: Double, drift: Double,
        opacity: Double, width: Double
    ) {
        for index in 0..<count {
            let n = Double(index)
            let seedX = (n * 0.6180339887).truncatingRemainder(dividingBy: 1)
            let seedY = (n * 0.7548776662).truncatingRemainder(dividingBy: 1)
            let depth = (n * 0.4142135624).truncatingRemainder(dividingBy: 1)

            let y = ((seedY * size.height) + t * speed * (0.7 + depth * 0.6))
                .truncatingRemainder(dividingBy: size.height + 90) - 45
            let x = seedX * size.width + sin(t * 0.5 + seedY * 6) * drift
            let len = length * (0.7 + depth * 0.6)

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            // Leaning by a fraction of its own length, so heavier rain leans
            // harder without anybody having to pick an angle per weather.
            path.addLine(to: CGPoint(x: x - len * 0.18, y: y + len))
            canvas.stroke(
                path,
                with: .color(tint.opacity(opacity * (0.5 + depth * 0.5))),
                lineWidth: width * (0.7 + depth * 0.6)
            )
        }
    }

    /// A soft full-sky lift, never a strobe.
    ///
    /// Eleven seconds apart and a third of a second long, with a sine envelope
    /// so it arrives and leaves rather than switching. The plan's floor is six
    /// seconds; this is nearly twice that, because a flash you can predict has
    /// stopped being weather and started being a metronome — and because
    /// anything faster is a photosensitivity question, not a taste one.
    private func flash(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let period = 11.0
        let phase = t.truncatingRemainder(dividingBy: period)
        guard phase < 0.34 else { return }
        let envelope = sin(phase / 0.34 * .pi)

        canvas.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(accent.opacity(envelope * 0.10))
        )
    }

    // MARK: The rest

    /// Snow does not fall so much as get in the way. Slower than rain, wider
    /// wander, and round rather than streaked.
    private func snow(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for index in 0..<22 {
            let n = Double(index)
            let seedX = (n * 0.6180339887).truncatingRemainder(dividingBy: 1)
            let depth = (n * 0.4142135624).truncatingRemainder(dividingBy: 1)
            let y = ((t * (26 + depth * 22)) + n * 90)
                .truncatingRemainder(dividingBy: size.height + 60) - 30
            let x = seedX * size.width + sin(t * 0.45 + n * 1.7) * (16 + depth * 14)
            let r = 1.6 + depth * 1.6

            canvas.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(0.35 + depth * 0.3))
            )
        }
    }

    /// Fog as horizontal banding rather than as a fill: the veil already did
    /// the fill, and what makes fog read as fog is that it sits in layers you
    /// can see the edges of.
    private func banks(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for band in 0..<4 {
            let n = Double(band)
            // Each bank drifts at its own rate and wraps, so they slide over
            // one another and the field never repeats visibly.
            let offset = (t * (5 + n * 3)).truncatingRemainder(dividingBy: size.width * 2)
            let y = size.height * (0.34 + n * 0.13)
            let height = 14 + n * 6

            var path = Path()
            path.move(to: CGPoint(x: -size.width + offset, y: y))
            var x = -size.width + offset
            while x <= size.width * 2 {
                path.addLine(to: CGPoint(
                    x: x, y: y + sin(x / (120 + n * 50) + n) * 4
                ))
                x += 10
            }
            canvas.stroke(
                path,
                with: .color(Theme.cream.opacity(0.16 + n * 0.03)),
                lineWidth: height
            )
        }
    }

    /// Wind with nothing to carry: a few fast, faint horizontal strokes that
    /// cross and are gone. Everything else in the app leans because of the
    /// veil; this is the part you can actually watch go past.
    private func gusts(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for index in 0..<6 {
            let n = Double(index)
            let cycle = 4.5 + n * 0.9
            let life = ((t + n * 1.7).truncatingRemainder(dividingBy: cycle)) / cycle
            let y = size.height * (0.24 + 0.5 * (n * 0.6180339887)
                .truncatingRemainder(dividingBy: 1))
            let len = 30 + n * 12
            let x = -len + life * (size.width + len * 2)
            // In at one end, out at the other, brightest halfway across.
            let fade = sin(life * .pi) * 0.20

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addQuadCurve(
                to: CGPoint(x: x + len, y: y),
                control: CGPoint(x: x + len / 2, y: y - 5)
            )
            canvas.stroke(path, with: .color(tint.opacity(fade)), lineWidth: 1.2)
        }
    }
}
