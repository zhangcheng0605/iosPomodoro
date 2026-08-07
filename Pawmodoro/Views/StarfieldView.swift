import SwiftUI

/// A dozen slow stars, drawn after dark — and, over time, the figures you put
/// there yourself.
///
/// Twinkling is an opacity wobble on a half-second tick — anything faster looks
/// like static, and anything busier stops being a background. The constellation
/// layer doesn't twinkle at all: a figure you built should look fixed, and the
/// contrast between the two is what makes it read as yours rather than as more
/// scenery.
struct StarfieldView: View {
    let tint: Color
    /// The moon's colour — `Theme.sunshine` from the call site, so the disc is
    /// a bright warm yellow that still belongs to whatever theme is on.
    let moon: Color
    /// Focus sessions finished after dark, from `SessionLog.nightSessions`.
    /// Everything drawn here is a function of this one number.
    let nightSessions: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()

    private static let count = 12

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { canvas, size in draw(&canvas, size: size, t: 0) }
            } else {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
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
        drawMoon(&canvas, size: size)
        drawScatter(&canvas, size: size, t: t)
        drawConstellations(&canvas, size: size)
        drawWanderers(&canvas, size: size, t: t)
    }

    /// Tonight's moon, at its real phase.
    ///
    /// Drawn first, so the figures and the scatter always read as in front of
    /// it. It sits in the sky band's top-right, in the slot between The Ferry
    /// and The Whale — a full atlas grazes it at the edges and no more. Static
    /// on purpose: the moon does not twinkle, so Reduce Motion shows exactly
    /// the same disc. Phase comes from `MoonPhase`, which already honours
    /// `-PawmodoroMoon`.
    private func drawMoon(_ canvas: inout GraphicsContext, size: CGSize) {
        let age = MoonPhase.age()
        let illumination = MoonPhase.illumination()
        let band = ConstellationAtlas.skyBottom - ConstellationAtlas.skyTop
        let center = CGPoint(
            x: 0.86 * size.width,
            y: (ConstellationAtlas.skyTop + 0.42 * band) * size.height
        )
        let radius = min(size.width, size.height) * 0.055

        func disc(_ at: CGPoint, _ r: Double) -> Path {
            Path(ellipseIn: CGRect(x: at.x - r, y: at.y - r,
                                   width: r * 2, height: r * 2))
        }

        // A soft halo, then the whole disc as faint earthshine — so even a
        // near-new moon is unmistakably *there* rather than a missing circle.
        canvas.fill(disc(center, radius * 1.55), with: .color(moon.opacity(0.16)))
        canvas.fill(disc(center, radius), with: .color(moon.opacity(0.28)))

        guard illumination > 0.02 else { return }

        if illumination > 0.97 {
            canvas.fill(disc(center, radius), with: .color(moon.opacity(0.95)))
            return
        }

        // The lit part: the bright disc with a same-size shadow disc punched
        // out of it. The shadow sits fully over the moon at new and slides
        // clean off at full; waxing keeps the lit edge on the right, waning on
        // the left. Two circles, not an ellipse terminator — a cartoon
        // crescent, which is the honest register for this sky.
        let slide = 2 * radius * illumination
        let shadowCenter = CGPoint(
            x: center.x + (age < 0.5 ? -slide : slide),
            y: center.y
        )
        canvas.drawLayer { layer in
            layer.fill(disc(center, radius), with: .color(moon.opacity(0.95)))
            layer.blendMode = .clear
            layer.fill(disc(shadowCenter, radius), with: .color(.black))
        }
    }

    /// The background stars that were always here.
    private func drawScatter(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for index in 0..<Self.count {
            let n = Double(index)
            let x = ((n * 0.6180339887).truncatingRemainder(dividingBy: 1)) * size.width
            // Kept to the upper third: that's the part of the screen that reads
            // as sky, and the only part with no text over it.
            let y = ((n * 0.7548776662).truncatingRemainder(dividingBy: 1)) * size.height * 0.34
            let twinkle = 0.5 + 0.5 * sin(t * 0.9 + n * 1.7)
            let r = 1.3 + (n.truncatingRemainder(dividingBy: 3)) * 0.55

            // The floor used to be 0.18, which on a phone outdoors read as
            // pitch black. The owner asked for a bright night, so the dimmest
            // a star ever gets is now most of the way on.
            dot(&canvas, x: x, y: y, r: r, opacity: 0.5 + twinkle * 0.35)
        }
    }

    /// Finished figures, joined up; the one being built, as bare stars.
    ///
    /// Lines only appear on completion. A half-drawn figure with its lines
    /// already showing reads as broken rather than as unfinished, and it also
    /// gives away a shape that is more fun to recognise on the night it lands.
    private func drawConstellations(_ canvas: inout GraphicsContext, size: CGSize) {
        for (index, figure) in ConstellationAtlas.all.enumerated() {
            let lit = ConstellationAtlas.litStars(of: index, nightSessions: nightSessions)
            guard lit > 0 else { continue }
            let complete = lit == figure.starCount

            if complete {
                var path = Path()
                for (a, b) in figure.links {
                    path.move(to: point(figure.position(of: a), in: size))
                    path.addLine(to: point(figure.position(of: b), in: size))
                }
                canvas.stroke(
                    path,
                    with: .color(tint.opacity(0.22)),
                    lineWidth: 0.75
                )
            }

            for star in 0..<lit {
                let at = point(figure.position(of: star), in: size)
                // A finished figure's stars sit brighter than the scatter, so
                // the thing you made stands out from the thing that was there.
                dot(&canvas, x: at.x, y: at.y,
                    r: complete ? 1.9 : 1.5,
                    opacity: complete ? 0.85 : 0.55)
            }
        }
    }

    /// One loose star per five nights once the atlas is full. Never joined to
    /// anything: there is nothing further to complete, and pretending there is
    /// would be the first false promise in the app.
    private func drawWanderers(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let count = ConstellationAtlas.wanderers(nightSessions: nightSessions)
        guard count > 0 else { return }
        for index in 0..<count {
            let n = Double(index) + 0.5
            let x = ((n * 0.3819660113).truncatingRemainder(dividingBy: 1)) * size.width
            let band = ConstellationAtlas.skyBottom - ConstellationAtlas.skyTop
            let y = (ConstellationAtlas.skyTop
                     + ((n * 0.2360679775).truncatingRemainder(dividingBy: 1)) * band)
                * size.height
            let twinkle = 0.5 + 0.5 * sin(t * 0.6 + n * 2.3)
            dot(&canvas, x: x, y: y, r: 1.4, opacity: 0.3 + twinkle * 0.35)
        }
    }

    /// Sky-band space (0...1 on both axes) to a point on screen.
    private func point(_ position: CGPoint, in size: CGSize) -> CGPoint {
        let band = ConstellationAtlas.skyBottom - ConstellationAtlas.skyTop
        return CGPoint(
            x: position.x * size.width,
            y: (ConstellationAtlas.skyTop + position.y * band) * size.height
        )
    }

    private func dot(
        _ canvas: inout GraphicsContext,
        x: Double, y: Double, r: Double, opacity: Double
    ) {
        canvas.fill(
            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
            with: .color(tint.opacity(opacity))
        )
    }
}

#Preview("A sky part-built") {
    ZStack {
        Color.black
        StarfieldView(tint: .white, moon: .yellow, nightSessions: 12)
    }
    .ignoresSafeArea()
}

#Preview("Every figure, plus wanderers") {
    ZStack {
        Color.black
        StarfieldView(tint: .white, moon: .yellow, nightSessions: 95)
    }
    .ignoresSafeArea()
}
