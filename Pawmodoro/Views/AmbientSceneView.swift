import SwiftUI

/// Makes the chosen ambience visible: pick rain and it rains on the screen.
///
/// One `Canvas` for every weather, because the differences are all in how the
/// particles move — a view per ambience would be six copies of the same
/// scaffolding. The whole thing is only mounted while the timer is running with
/// an ambience selected, which is exactly when `SoundPlayer` is playing: the
/// picture and the sound start and stop together, and an idle app draws nothing.
struct AmbientSceneView: View {
    let ambience: Ambience
    let tint: Color
    let accent: Color

    /// Nothing here is essential, so it all goes away under Reduce Motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()

    var body: some View {
        if ambience.hasScene && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                Canvas { canvas, size in
                    let t = context.date.timeIntervalSince(started)
                    draw(&canvas, size: size, t: t)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func draw(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        switch ambience {
        case .rain: drawRain(&canvas, size: size, t: t)
        case .fireplace: drawEmbers(&canvas, size: size, t: t)
        case .forest: drawLeaves(&canvas, size: size, t: t)
        case .ocean: drawWaves(&canvas, size: size, t: t)
        case .cafe: drawSteam(&canvas, size: size, t: t)
        case .purr: drawHearts(&canvas, size: size, t: t)
        // The Second Shelf. Three of the six have a weather to draw and
        // three do not: a library, a creek and a temple bell are all sounds
        // of a *place*, and inventing particles for them would put drifting
        // motes over a meadow for no reason anybody could name. Silence in
        // this switch is a decision, not an omission.
        case .drizzle: drawDrizzle(&canvas, size: size, t: t)
        case .wind: drawLeaves(&canvas, size: size, t: t)
        case .snowhush: drawSnowfall(&canvas, size: size, t: t)
        case .storm: drawRain(&canvas, size: size, t: t)
        case .raintent: drawDrizzle(&canvas, size: size, t: t)
        case .emberslate: drawEmbers(&canvas, size: size, t: t)
        // Rooms and night noises, again with nothing to draw: a carriage,
        // a summer field and a cricket meadow are all places you are already
        // standing in. The scene behind is doing that work.
        case .creek, .library, .temple, .crickets, .cicadas, .nighttrain: break
        case .off: break
        }
    }

    // MARK: Weathers

    /// Rain's field at a third the density and half the length. Same drops,
    /// so the two never look like different weather systems — drizzle is
    /// rain with less of it, which is what the loop does to the sound too.
    private func drawDrizzle(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for drop in Field.drops.enumerated().filter({ $0.offset % 3 == 0 }).map(\.element) {
            let depth = drop.depth
            let speed = 190 + depth * 260
            let y = ((drop.seedY * size.height) + t * speed)
                .truncatingRemainder(dividingBy: size.height + 90) - 45
            let x = drop.seedX * size.width + sin(t * 0.4 + drop.seedY * 6) * 6
            let length = 5 + depth * 8

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - 1, y: y + length))
            canvas.stroke(path, with: .color(tint.opacity(0.10 + depth * 0.14)),
                          lineWidth: 1)
        }
    }

    /// Snow: slow, and it drifts sideways rather than falling straight. The
    /// season layer already draws snow for winter; this is the same idea for
    /// somebody who chose the sound in July.
    private func drawSnowfall(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for flake in Field.drops.enumerated().filter({ $0.offset % 2 == 0 }).map(\.element) {
            let depth = flake.depth
            let speed = 26 + depth * 34
            let y = ((flake.seedY * size.height) + t * speed)
                .truncatingRemainder(dividingBy: size.height + 40) - 20
            let x = flake.seedX * size.width
                + sin(t * 0.30 + flake.seedY * 9) * (14 + depth * 20)
            let r = 1.0 + depth * 1.6
            canvas.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(tint.opacity(0.18 + depth * 0.22))
            )
        }
    }


    /// Two depths of streak, the near ones longer, faster and more opaque.
    private func drawRain(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for drop in Field.drops {
            let depth = drop.depth
            let speed = 260 + depth * 420
            let y = ((drop.seedY * size.height) + t * speed)
                .truncatingRemainder(dividingBy: size.height + 90) - 45
            let x = drop.seedX * size.width + sin(t * 0.5 + drop.seedY * 6) * 8
            let length = 10 + depth * 18

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - 2, y: y + length))
            canvas.stroke(
                path,
                with: .color(tint.opacity(0.12 + depth * 0.22)),
                lineWidth: 1 + depth
            )
        }
    }

    /// Embers rise, wander sideways and wink out near the top.
    private func drawEmbers(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for ember in Field.embers {
            let life = (t * (0.18 + ember.depth * 0.2) + ember.seedY)
                .truncatingRemainder(dividingBy: 1)
            let y = size.height * (1.02 - life * 0.85)
            let x = ember.seedX * size.width
                + sin(t * 1.1 + ember.seedY * 9) * (14 + ember.depth * 20)
            // Brightest in the middle of the climb, gone by the top.
            let glow = sin(life * .pi)
            let r = 1.4 + ember.depth * 2.2

            canvas.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(accent.opacity(glow * 0.55))
            )
        }
    }

    private func drawLeaves(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for leaf in Field.leaves {
            let fall = (t * (0.07 + leaf.depth * 0.06) + leaf.seedY)
                .truncatingRemainder(dividingBy: 1)
            let y = fall * (size.height + 60) - 30
            let x = leaf.seedX * size.width + sin(t * 0.7 + leaf.seedY * 8) * 34
            let w = 7 + leaf.depth * 7

            canvas.drawLayer { layer in
                layer.translateBy(x: x, y: y)
                layer.rotate(by: .degrees(sin(t * 0.9 + leaf.seedX * 10) * 55))
                layer.fill(
                    Path(ellipseIn: CGRect(x: -w / 2, y: -w / 4, width: w, height: w / 2)),
                    with: .color(tint.opacity(0.3 + leaf.depth * 0.2))
                )
            }
        }
    }

    /// Slow horizontal shimmer bands, drifting at different rates.
    private func drawWaves(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for band in 0..<3 {
            let n = Double(band)
            let baseY = size.height * (0.55 + n * 0.14)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: baseY))
            var x: Double = 0
            while x <= size.width {
                let y = baseY + sin(x / (90 + n * 40) + t * (0.5 + n * 0.22)) * (5 + n * 3)
                path.addLine(to: CGPoint(x: x, y: y))
                x += 6
            }
            canvas.stroke(path, with: .color(tint.opacity(0.22 - n * 0.05)), lineWidth: 2)
        }
    }

    /// Three wisps curling up out of the bottom corner.
    private func drawSteam(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for wisp in 0..<3 {
            let n = Double(wisp)
            let phase = t * 0.32 + n * 0.33
            let life = phase.truncatingRemainder(dividingBy: 1)
            let baseX = size.width * (0.18 + n * 0.1)
            let y = size.height * (1.0 - life * 0.5)
            let fade = sin(life * .pi) * 0.3

            var path = Path()
            path.move(to: CGPoint(x: baseX, y: y))
            for segment in 1...8 {
                let s = Double(segment) / 8
                path.addLine(to: CGPoint(
                    x: baseX + sin(s * 3.4 + t * 1.3 + n) * (10 + s * 22),
                    y: y - s * size.height * 0.2
                ))
            }
            canvas.stroke(path, with: .color(tint.opacity(fade)), lineWidth: 3)
        }
    }

    /// Purring gets the same hearts petting does, drifting up now and then.
    private func drawHearts(_ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        for heart in Field.hearts {
            let life = (t * 0.16 + heart.seedY).truncatingRemainder(dividingBy: 1)
            let y = size.height * (1.0 - life * 0.75)
            let x = heart.seedX * size.width + sin(t * 0.8 + heart.seedY * 7) * 20
            let scale = 0.5 + heart.depth * 0.6
            let fade = sin(life * .pi) * 0.35

            canvas.drawLayer { layer in
                layer.translateBy(x: x, y: y)
                layer.scaleBy(x: scale, y: scale)
                layer.fill(heartPath(), with: .color(accent.opacity(fade)))
            }
        }
    }

    private func heartPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 6))
        path.addCurve(
            to: CGPoint(x: -9, y: -3),
            control1: CGPoint(x: -4, y: 2),
            control2: CGPoint(x: -9, y: 1)
        )
        path.addArc(
            center: CGPoint(x: -4.5, y: -4.5),
            radius: 4.5,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: 4.5, y: -4.5),
            radius: 4.5,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addCurve(
            to: CGPoint(x: 0, y: 6),
            control1: CGPoint(x: 9, y: 1),
            control2: CGPoint(x: 4, y: 2)
        )
        path.closeSubpath()
        return path
    }

    // MARK: Particle fields
    //
    // Fixed rather than random, for the same reason the confetti is: a scene
    // that looks the same every run can be tuned by eye and compared against a
    // screenshot from yesterday. Counts are capped well under what a phone
    // notices — the whole budget here is a few dozen shapes at 30fps.

    private enum Field {
        struct Particle {
            let seedX: Double
            let seedY: Double
            let depth: Double
        }

        static func make(_ count: Int, salt: Double) -> [Particle] {
            (0..<count).map { index in
                let n = Double(index) + salt
                return Particle(
                    seedX: (n * 0.6180339887).truncatingRemainder(dividingBy: 1),
                    seedY: (n * 0.7548776662).truncatingRemainder(dividingBy: 1),
                    depth: (n * 0.4142135624).truncatingRemainder(dividingBy: 1)
                )
            }
        }

        static let drops = make(34, salt: 1)
        static let embers = make(16, salt: 7)
        static let leaves = make(9, salt: 3)
        static let hearts = make(7, salt: 11)
    }
}

extension Ambience {
    /// Whether this ambience draws something. Only `off` doesn't.
    var hasScene: Bool { self != .off }
}
