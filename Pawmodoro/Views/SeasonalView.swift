import SwiftUI

/// The seasonal layer: petals, fireflies, leaves, snow, lanterns.
///
/// One `Canvas` for all five, because the differences are entirely in how the
/// particles move — the same shape the weather layer already takes. Deliberately
/// slower and sparser than the weather: this runs whenever the app is open,
/// where rain only runs while the timer does.
///
/// Nothing here is earned, unlocked or announced. It is simply autumn.
struct SeasonalView: View {
    let season: Season
    let tint: Color
    let accent: Color
    /// Bats, for the last week of October.
    var withBats: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()

    var body: some View {
        Group {
            if reduceMotion {
                // Still particles, laid out where they'd be at a fixed moment.
                // The season is information; the drifting is decoration.
                Canvas { canvas, size in draw(&canvas, size: size, t: 3) }
            } else {
                // 12fps, not 30: petals falling is a slow thing, and this
                // layer is on screen far more of the time than the weather is.
                TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { context in
                    Canvas { canvas, size in
                        draw(&canvas, size: size,
                             t: context.date.timeIntervalSince(started))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        switch season {
        case .sakura: drift(&canvas, size: size, t: t, colour: Theme.blossom, wobble: 26, fall: 34, radius: 2.6)
        case .autumn: drift(&canvas, size: size, t: t, colour: accent, wobble: 34, fall: 46, radius: 3.0)
        case .winter: drift(&canvas, size: size, t: t, colour: .white, wobble: 14, fall: 30, radius: 2.2)
        case .fireflies: drawFireflies(&canvas, size: size, t: t)
        case .lanterns: drawLanterns(&canvas, size: size, t: t)
        }
        if season == .autumn { drawPumpkins(&canvas, size: size) }
        if withBats { drawBats(&canvas, size: size, t: t) }
    }

    /// Three pumpkins on the ground, for the three weeks the leaves are down.
    ///
    /// `docs/CONTENT_PLAN.md` J asked for "pumpkins by the perch"; there is no
    /// perch — the buddy has always sat in a fixed slot in the column rather
    /// than in the scene — so they sit on the one line this app already agrees
    /// about instead. `Stray.groundLine` is where the stray stands, where the
    /// snail crosses and where the buddy stands on a postcard, and a pumpkin
    /// resting anywhere else would be a pumpkin resting in mid-air in one place
    /// out of eight. `StrayView` reads it exactly this way, off the layer's own
    /// height, so the two cannot disagree.
    ///
    /// Not particles: they do not move, they are not counted in
    /// `Season.particleCount`, and they take no time argument at all. Autumn
    /// already runs this canvas at 12fps for the leaves, so three still shapes
    /// inside it cost a fill each and nothing else — there is no second layer
    /// to mount and nothing new runs when the season is over.
    ///
    /// Kept out of the middle third on purpose. The transport row is centred
    /// and the ambience chips run the full width above it; a pumpkin behind the
    /// play button is a smudge rather than a pumpkin.
    private func drawPumpkins(_ canvas: inout GraphicsContext, size: CGSize) {
        let ground = size.height * Stray.groundLine
        for (fraction, scale) in [(0.12, 1.0), (0.21, 0.72), (0.86, 0.88)] {
            let width = 22.0 * scale
            let height = 17.0 * scale
            let x = size.width * fraction
            let body = CGRect(x: x - width / 2, y: ground - height,
                              width: width, height: height)

            // The stalk first, so the body's own edge cuts it off cleanly.
            canvas.fill(
                Path(roundedRect: CGRect(x: x - 1.4 * scale,
                                         y: ground - height - 4.5 * scale,
                                         width: 2.8 * scale, height: 5.5 * scale),
                     cornerSize: CGSize(width: 1.2, height: 1.2)),
                with: .color(Theme.forest.opacity(0.75))
            )
            canvas.fill(Path(ellipseIn: body),
                        with: .color(Theme.sunshine.opacity(0.88)))
            // Two ribs. A plain ellipse reads as a ball; the ribs are the
            // whole difference between a pumpkin and an orange dot.
            for offset in [-0.30, 0.30] {
                let rib = CGRect(x: x + width * offset - width * 0.11,
                                 y: body.minY + height * 0.06,
                                 width: width * 0.22, height: height * 0.88)
                canvas.fill(Path(ellipseIn: rib),
                            with: .color(tint.opacity(0.16)))
            }
        }
    }

    /// Anything that falls: petals, leaves, snow. One routine, three feels,
    /// separated only by how far sideways they wander on the way down.
    private func drift(
        _ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval,
        colour: Color, wobble: Double, fall: Double, radius: Double
    ) {
        for index in 0..<season.particleCount {
            let n = Double(index)
            let seedX = (n * 0.6180339887).truncatingRemainder(dividingBy: 1)
            let speed = fall * (0.7 + (n * 0.4142135624).truncatingRemainder(dividingBy: 1) * 0.6)
            // Wraps by the height plus a margin, so nothing pops in at the edge.
            let y = ((t * speed) + n * 90).truncatingRemainder(dividingBy: size.height + 60) - 30
            let x = seedX * size.width + sin(t * 0.6 + n * 1.9) * wobble
            let spin = 0.6 + 0.4 * sin(t * 1.1 + n)

            canvas.fill(
                Path(ellipseIn: CGRect(
                    x: x - radius, y: y - radius * spin,
                    width: radius * 2, height: radius * 2 * spin
                )),
                with: .color(colour.opacity(0.5))
            )
        }
    }

    /// On, off, and somewhere else — the same behaviour the journal's firefly
    /// has, because it is the same insect.
    private func drawFireflies(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for index in 0..<season.particleCount {
            let n = Double(index)
            let x = ((n * 0.7548776662).truncatingRemainder(dividingBy: 1)) * size.width
                + sin(t * 0.5 + n * 2.1) * 40
            let y = size.height * (0.42 + 0.36 * (n * 0.3819660113)
                .truncatingRemainder(dividingBy: 1)) + cos(t * 0.42 + n) * 24
            // A slow blink that is never in step across the field.
            let glow = max(0, sin(t * 1.4 + n * 2.7))
            guard glow > 0.15 else { continue }

            canvas.fill(
                Path(ellipseIn: CGRect(x: x - 2.4, y: y - 2.4, width: 4.8, height: 4.8)),
                with: .color(Theme.sunshine.opacity(0.25 + glow * 0.6))
            )
        }
    }

    /// Paper lanterns, hanging still and swinging very slightly. They don't
    /// fall and they don't wander — the stillness is what makes them read as
    /// hung rather than dropped.
    private func drawLanterns(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for index in 0..<season.particleCount {
            let n = Double(index)
            let x = (0.08 + 0.84 * (n / Double(max(1, season.particleCount - 1)))) * size.width
                + sin(t * 0.35 + n) * 4
            let y = size.height * (0.10 + 0.05 * (n * 0.6180339887)
                .truncatingRemainder(dividingBy: 1))

            canvas.stroke(
                Path { $0.move(to: CGPoint(x: x, y: 0)); $0.addLine(to: CGPoint(x: x, y: y - 7)) },
                with: .color(tint.opacity(0.22)), lineWidth: 1
            )
            canvas.fill(
                Path(roundedRect: CGRect(x: x - 5, y: y - 7, width: 10, height: 14),
                     cornerSize: CGSize(width: 4, height: 5)),
                with: .color(Theme.blossom.opacity(0.62))
            )
            canvas.fill(
                Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                with: .color(Theme.sunshine.opacity(0.75))
            )
        }
    }

    /// Three bats, crossing high up, for one week a year.
    private func drawBats(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for index in 0..<3 {
            let n = Double(index)
            let cycle = 9.0 + n * 2
            let progress = ((t + n * 3.1).truncatingRemainder(dividingBy: cycle)) / cycle
            let x = -20 + progress * (size.width + 40)
            let y = size.height * (0.10 + 0.06 * n) + sin(progress * .pi * 5) * 12
            // A wing-flap is two short strokes that change length. At this size
            // that is the entire animation, and it is enough.
            let flap = 3.0 + 2.5 * abs(sin(t * 7 + n))

            var path = Path()
            path.move(to: CGPoint(x: x - flap, y: y - flap * 0.5))
            path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + flap, y: y - flap * 0.5))
            canvas.stroke(path, with: .color(tint.opacity(0.5)), lineWidth: 1.4)
        }
    }
}
