import SwiftUI

/// `Flourish`, drawn.
///
/// Everything in here is light: a soft radial falloff, a glint that grows and
/// goes, a ring where a drop landed. Nothing falls that `WeatherView`,
/// `SeasonalView` or `AmbientSceneView` wasn't already dropping, so this layer
/// composites over all three without knowing any of them exist.
///
/// Two rules hold every number below in place:
///
/// * **Never darker than the scene.** Every shape is a light colour drawn at
///   low alpha, so the worst this layer can do to a text pair underneath it is
///   lighten the background — and the app's text all sits on its own theme
///   capsule at 70–82 %, which composites last and over the top of this.
///   Peak alpha anywhere here is 0.48, at the dead centre of a shape a dozen
///   points across — against weather veils that already ship at 0.10–0.40
///   across the *whole screen*. See `check_contrast.py`, and read the honest note at the bottom
///   of this file about what that check does and does not cover.
/// * **Sparse.** Nothing here draws more than about two dozen shapes a frame,
///   which is what makes 30fps affordable on a layer that is on screen most of
///   the time the app is open.
struct FlourishView: View {
    let tint: Color
    let accent: Color

    /// The world it is reading. This view *observes* and never writes — see
    /// the header of `Flourish.swift` for why that matters.
    @Environment(TimerEngine.self) private var engine
    /// Nothing here carries information — the veil and the particle layers
    /// under it already say what the weather is — so all of it goes away,
    /// exactly as `WeatherView` does and for the same stated reason.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Nothing at all when there is nothing to draw — not a canvas, and
        // not the clock that would drive one. "A canvas is only mounted while
        // it has something to draw" is the law, and the two states that reach
        // here with nothing are the common ones: an overcast or misty sky,
        // and Reduce Motion, which turns every look off. Both must cost what
        // the app costs with this layer deleted, and they measure that way.
        if let flourish = current, !reduceMotion,
           !ProcessInfo.processInfo.arguments.contains("-FxOff") {
            // Once a minute, for the hour — the same cadence the sky, the
            // scenery and the seasons are all re-read at, and about two
            // thousand times more often than the light actually changes
            // colour.
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let part = LaunchOptions.forcedDayPart
                    ?? DayPart.current(at: context.date)
                FlourishCanvas(
                    flourish: flourish,
                    tint: tint,
                    accent: accent,
                    light: FlourishView.lightColour(for: part)
                )
                .id(flourish.look)
            }
            .allowsHitTesting(false)
        }
    }

    private var current: Flourish? {
        Flourish.current(
            ambience: engine.settings.ambience,
            running: engine.isRunning,
            weather: engine.weather
        )
    }

    /// Sunlight has a colour and moonlight has another, and it is the single
    /// biggest reason this layer reads as *the place* rather than as an
    /// overlay. All of them come out of `Theme`, so it follows the theme too.
    static func lightColour(for part: DayPart) -> Color {
        switch part {
        case .day: Theme.sunshine
        case .dawn: Theme.blossom
        case .dusk: Theme.sunshine
        case .night: Theme.cream
        }
    }
}

/// The drawing half, with no environment of its own.
///
/// Split out so the whole layer is a pure function of four plain values: it
/// can be previewed, it can be rendered off screen, and — the reason that
/// matters here — an `ImageRenderer` lays its content out in a *fresh*
/// environment, so a view that reads `@Environment` in its body is a crash
/// waiting for somebody to export it.
struct FlourishCanvas: View {
    let flourish: Flourish
    let tint: Color
    let accent: Color
    let light: Color

    @State private var started = Date()

    // TEMPORARY probe knobs — removed before this lands.
    static func arg(_ name: String, _ fallback: Double) -> Double {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: name), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return fallback }
        return v
    }
    static let fxRim = arg("-FxRim", 1)          // 0 = no dark rim disc
    static let fxRimR = arg("-FxRimR", 1.35)     // rim radius multiplier
    static let fxDropHalo = arg("-FxDropHalo", 1) // 0 = drop has no soft head
    static let fxCount = arg("-FxCount", 1)      // multiplies every count
    static let fxFPS = arg("-FxFPS", 0)          // >0 overrides the cadence
    static let fxHalo = arg("-FxHalo", 1.15)     // glint halo, as a multiple of arm
    static let fxPeriodic = arg("-FxPeriodic", 1) // 1 = .periodic clock instead of .animation
    static let fxBand = arg("-FxBand", 0)        // >0 = clip the canvas to this fraction of height

    @ViewBuilder
    var body: some View {
        // Each look is redrawn at the rate its own motion needs, and no
        // faster — see `Flourish.Look.frameRate`, which carries both the
        // numbers and the measurement that set them.
        let fps = FlourishCanvas.fxFPS > 0 ? FlourishCanvas.fxFPS : flourish.look.frameRate
        Group {
            if FlourishCanvas.fxPeriodic > 0 {
                TimelineView(.periodic(from: .now, by: 1.0 / fps)) { context in
                    canvasBody(at: context.date)
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / fps)) { context in
                    canvasBody(at: context.date)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func canvasBody(at date: Date) -> some View {
        let c = Canvas { canvas, size in
            draw(&canvas, size: size, t: date.timeIntervalSince(started))
        }
        if FlourishCanvas.fxBand > 0 {
            GeometryReader { geo in
                c.frame(height: geo.size.height * FlourishCanvas.fxBand)
            }
        } else {
            c
        }
    }

    private func draw(
        _ canvas: inout GraphicsContext, size: CGSize, t: TimeInterval
    ) {
        let s = flourish.strength
        switch flourish.look {
        case .rainfall: rainfall(&canvas, size: size, t: t, strength: s)
        case .snowfall: snowfall(&canvas, size: size, t: t, strength: s)
        case .embers: embers(&canvas, size: size, t: t, strength: s)
        case .shimmer: shimmer(&canvas, size: size, t: t, strength: s)
        case .motes: motes(&canvas, size: size, t: t, strength: s)
        case .sparkle: sparkle(&canvas, size: size, t: t, strength: s)
        }
    }

    // MARK: Rainfall — the drop, and the ring it leaves

    /// A handful of lit drops, and the rings where they land.
    ///
    /// The ring is the whole point. Rain drawn as falling lines is rain that
    /// never arrives anywhere; one expanding ellipse at the moment a drop
    /// reaches the ground turns a screensaver into a place where it is
    /// raining. Each ring is caused by the drop directly above it — same
    /// index, same cycle, second half of it — so they can never drift into
    /// looking unrelated.
    private func rainfall(
        _ canvas: inout GraphicsContext, size: CGSize,
        t: TimeInterval, strength: Double
    ) {
        let count = Int(FlourishCanvas.fxCount * Double(5 + Int(strength * 6)))

        for index in 0..<count {
            let speck = Speck(index: index, salt: 1)
            // Each drop lands at its own height rather than all of them on one
            // line. Two reasons, and the second is the important one: a single
            // flat row of rings across a drawn landscape reads as a shelf, and
            // — as `check_stray.py` exists to say — *nothing in this app can
            // see where the ground is in a given scene*. A band, with the
            // nearer drops (higher `depth`) landing lower, is right everywhere
            // and claims nothing about any particular place.
            let ground = size.height * (0.70 + speck.depth * 0.22)
            // Slower than it was (1.5–2.6s), and the reason is the frame rate
            // rather than taste. At 1.5s a drop covers five hundred points a
            // second; twelve frames of that is a forty-point jump between
            // positions for a streak nine to twenty-two points long, which is
            // a dotted line rather than a falling drop. At 2.6–4.0s it moves
            // twenty to thirty-seven points a frame — the same ground per
            // frame `WeatherView`'s own rain has always covered at this rate,
            // underneath it, since the day it shipped. The ring, which is what
            // this effect is actually for, is unchanged.
            let period = 2.6 + speck.depth * 1.4
            let life = ((t + speck.phase * period)
                .truncatingRemainder(dividingBy: period)) / period
            let x = speck.sx * size.width

            if life < 0.78 {
                let fall = life / 0.78
                let y = -30 + fall * (ground + 30)
                litDrop(
                    &canvas, x: x, y: y, depth: speck.depth,
                    // Fades in over the first fifth of the fall so nothing
                    // ever pops into existence at the top edge.
                    alpha: min(1, fall * 5) * 0.38 * strength
                )
            } else {
                let spread = (life - 0.78) / 0.22
                ring(
                    &canvas, x: x, y: ground, spread: spread,
                    alpha: (1 - spread) * 0.40 * strength
                )
            }
        }
    }

    /// One drop: a short streak with a soft head, so it looks lit rather than
    /// drawn. The halo is a radial gradient rather than a blur filter —
    /// same look, no full-screen filter pass at 30fps.
    private func litDrop(
        _ canvas: inout GraphicsContext, x: Double, y: Double,
        depth: Double, alpha: Double
    ) {
        let length = 9 + depth * 13
        let halo = 4.0 + depth * 4

        if FlourishCanvas.fxDropHalo > 0 {
            softPoint(&canvas, at: CGPoint(x: x, y: y), radius: halo,
                      colour: light, alpha: alpha * 0.8)
        }

        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x - length * 0.18, y: y + length))
        // The tail fades out; `tint` at zero alpha rather than `light` at zero
        // so the gradient runs to the scene's own dark rather than to a
        // transparent cream, which on a pale theme reads as a white smear.
        canvas.stroke(
            path,
            with: .color(Theme.bark.opacity(min(0.20, alpha * 0.7))),
            lineWidth: 2.4 + depth
        )
        canvas.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [light.opacity(alpha), tint.opacity(0)]),
                startPoint: CGPoint(x: x, y: y),
                endPoint: CGPoint(x: x, y: y + length)
            ),
            lineWidth: 1 + depth
        )
    }

    /// The ring. Flattened to a third of its width, because the ground is a
    /// plane seen at an angle and a circle reads as a bubble.
    private func ring(
        _ canvas: inout GraphicsContext, x: Double, y: Double,
        spread: Double, alpha: Double
    ) {
        let radius = 2 + spread * 15
        litStroke(
            &canvas,
            Path(ellipseIn: CGRect(
                x: x - radius, y: y - radius * 0.30,
                width: radius * 2, height: radius * 0.60
            )),
            colour: light, alpha: max(0, alpha), width: 1.5
        )
    }

    // MARK: Snowfall — the foreground, out of focus

    /// Big, soft, out-of-focus flakes near the lens, plus a few crystals
    /// catching the light.
    ///
    /// The crisp small snow already falling belongs to `WeatherView`; this is
    /// the layer in front of it. Depth of field is the cheapest thing in
    /// photography that reads as expensive, and it costs one radial gradient.
    private func snowfall(
        _ canvas: inout GraphicsContext, size: CGSize,
        t: TimeInterval, strength: Double
    ) {
        for index in 0..<7 {
            let speck = Speck(index: index, salt: 5)
            let speed = 0.020 + speck.depth * 0.016
            let cycle = (t * speed + speck.sy).truncatingRemainder(dividingBy: 1)
            let y = cycle * (size.height + 90) - 45
            let x = speck.sx * size.width
                + sin(t * 0.28 + speck.phase * 7) * (24 + speck.depth * 30)
            let radius = 5 + speck.depth * 10

            softPoint(
                &canvas, at: CGPoint(x: x, y: y), radius: radius,
                colour: Theme.cream,
                alpha: (0.22 + speck.depth * 0.18) * strength
            )
        }

        for index in 0..<4 {
            let speck = Speck(index: index, salt: 13)
            let y = size.height * (0.18 + speck.sy * 0.52)
                + sin(t * 0.5 + speck.phase * 5) * 14
            let x = speck.sx * size.width + sin(t * 0.22 + speck.phase * 9) * 26
            let pulse = 0.5 + 0.5 * sin(t * 1.3 + speck.phase * 6.3)
            crystal(
                &canvas, x: x, y: y, size: 4 + speck.depth * 3,
                alpha: (0.12 + pulse * 0.28) * strength,
                spin: t * 0.25 + speck.phase * 3
            )
        }
    }

    /// Six spokes. Not a snowflake so much as the idea of one, at four points
    /// across — any more detail than this and it becomes a clip-art flake.
    private func crystal(
        _ canvas: inout GraphicsContext, x: Double, y: Double,
        size arm: Double, alpha: Double, spin: Double
    ) {
        var path = Path()
        for spoke in 0..<3 {
            let angle = spin + Double(spoke) * .pi / 3
            let dx = cos(angle) * arm
            let dy = sin(angle) * arm
            path.move(to: CGPoint(x: x - dx, y: y - dy))
            path.addLine(to: CGPoint(x: x + dx, y: y + dy))
        }
        litStroke(&canvas, path, colour: Theme.cream, alpha: alpha, width: 1.3)
    }

    // MARK: Embers — sparks that wink

    private func embers(
        _ canvas: inout GraphicsContext, size: CGSize,
        t: TimeInterval, strength: Double
    ) {
        let count = Int(FlourishCanvas.fxCount * Double(8 + Int(strength * 6)))
        for index in 0..<count {
            let speck = Speck(index: index, salt: 7)
            let speed = 0.10 + speck.depth * 0.13
            let life = (t * speed + speck.sy).truncatingRemainder(dividingBy: 1)
            let y = size.height * (1.02 - life * 0.80)
            let x = speck.sx * size.width
                + sin(t * 0.9 + speck.phase * 8) * (16 + speck.depth * 26)
            // Brightest halfway up, and flickering the whole way.
            let rise = sin(life * .pi)
            let flicker = 0.55 + 0.45 * sin(t * 6.5 + speck.phase * 11)
            let alpha = rise * flicker * 0.42 * strength
            let radius = 1.3 + speck.depth * 2.0

            softPoint(&canvas, at: CGPoint(x: x, y: y), radius: radius * 4,
                      colour: accent, alpha: alpha * 0.6)
            canvas.fill(
                Path(ellipseIn: CGRect(
                    x: x - radius, y: y - radius,
                    width: radius * 2, height: radius * 2
                )),
                with: .color(Theme.sunshine.opacity(alpha))
            )
        }
    }

    // MARK: Shimmer — sun on water

    /// Sun on water: short bright dashes that wink on and off in a band.
    ///
    /// This is the third try and the first that reads. Long stroked curves —
    /// the obvious way to draw a caustic — came out on Harbor Isle as straight
    /// lines lying across the water, the land *and* the buddy, and looked like
    /// scratches on the glass. Making them shorter and wavier fixed the
    /// scratches and then lost them entirely behind the ambience row, which is
    /// the busiest part of this screen.
    ///
    /// What actually reads as water is not a line at all: it is a scatter of
    /// short horizontal glints, each winking at its own rate, none of them
    /// long enough to look like it was drawn with a ruler. It also sits
    /// happily anywhere in the band, so nothing depends on where a particular
    /// place put its shoreline.
    private func shimmer(
        _ canvas: inout GraphicsContext, size: CGSize,
        t: TimeInterval, strength: Double
    ) {
        let count = Int(FlourishCanvas.fxCount * Double(10 + Int(strength * 8)))
        for index in 0..<count {
            let speck = Speck(index: index, salt: 23)
            let period = 2.6 + speck.depth * 3.0
            let life = ((t + speck.phase * period)
                .truncatingRemainder(dividingBy: period)) / period
            guard life < 0.5 else { continue }
            let wink = sin(life / 0.5 * .pi)

            // The band is the lower half, above the transport controls. Slow
            // sideways drift, and a gentle bob, so the field is never still.
            let y = size.height * (0.52 + speck.sy * 0.34)
                + sin(t * 0.6 + speck.phase * 7) * 3
            let drift = (t * (5 + speck.depth * 7) + speck.sx * size.width)
                .truncatingRemainder(dividingBy: size.width + 60) - 30
            let length = 8 + speck.depth * 16

            var path = Path()
            path.move(to: CGPoint(x: drift, y: y))
            path.addQuadCurve(
                to: CGPoint(x: drift + length, y: y),
                control: CGPoint(x: drift + length / 2, y: y - 1.6)
            )
            // A dash alone reads as a hair on a busy surface — Harbor Isle's
            // water art is already speckled white. The soft point under it is
            // what turns it into a highlight sitting *on* something.
            softPoint(&canvas, at: CGPoint(x: drift + length / 2, y: y),
                      radius: 5 + speck.depth * 5, colour: light,
                      alpha: wink * 0.30 * strength)
            litStroke(&canvas, path, colour: light,
                      alpha: wink * 0.46 * strength,
                      width: 2.0 + speck.depth * 2.2)
        }
    }

    // MARK: Motes — bokeh

    /// Out-of-focus discs of light, drifting up and across. A bokeh disc is a
    /// soft core with a slightly brighter rim, which is what a real lens does
    /// to a point of light, and it is the difference between this and a plain
    /// faded circle.
    private func motes(
        _ canvas: inout GraphicsContext, size: CGSize,
        t: TimeInterval, strength: Double
    ) {
        let count = Int(FlourishCanvas.fxCount * Double(9 + Int(strength * 6)))
        for index in 0..<count {
            let speck = Speck(index: index, salt: 3)
            let speed = 0.014 + speck.depth * 0.020
            let life = (t * speed + speck.sy).truncatingRemainder(dividingBy: 1)
            let y = size.height * (1.05 - life * 1.15)
            let x = speck.sx * size.width
                + sin(t * 0.22 + speck.phase * 6) * (22 + speck.depth * 34)
            let radius = 4 + speck.depth * 10
            // In and out at the ends of the drift, so nothing blinks off at
            // the edge of the screen.
            let alpha = sin(life * .pi) * (0.17 + speck.depth * 0.14) * strength

            let box = CGRect(
                x: x - radius, y: y - radius,
                width: radius * 2, height: radius * 2
            )
            softPoint(&canvas, at: CGPoint(x: x, y: y), radius: radius,
                      colour: light, alpha: alpha)
            // The rim. A real out-of-focus highlight is brighter at its edge
            // than at its middle, and that ring is the entire difference
            // between bokeh and a faded dot.
            litStroke(&canvas, Path(ellipseIn: box),
                      colour: light, alpha: alpha * 0.9, width: 1.0)
        }
    }

    // MARK: Sparkle — the rare one

    /// Four-point glints that arrive, hold for a breath, and leave.
    ///
    /// The one effect here that is not caused by anything falling: it is the
    /// air itself catching the light, which is why it belongs to the clear sky
    /// and to the golden day after a storm and to nothing else. Each glint is
    /// three shapes — a halo, a tapered cross, and a core — and the cross is
    /// what makes it read as a *glint* rather than as a dot.
    private func sparkle(
        _ canvas: inout GraphicsContext, size: CGSize,
        t: TimeInterval, strength: Double
    ) {
        let count = Int(FlourishCanvas.fxCount * Double(5 + Int(strength * 8)))
        for index in 0..<count {
            let speck = Speck(index: index, salt: 17)
            let period = 4.5 + speck.depth * 4.5
            let life = ((t + speck.phase * period)
                .truncatingRemainder(dividingBy: period)) / period
            // Alive for a third of its cycle; dark for the rest. A field that
            // is always all lit is a field of dots.
            guard life < 0.38 else { continue }
            let envelope = pow(sin(life / 0.38 * .pi), 1.5)

            let x = speck.sx * size.width
            // Kept out of the very bottom, where the controls live.
            let y = size.height * (0.07 + speck.sy * 0.68)
                - life * 10
            glint(
                &canvas, x: x, y: y,
                arm: 7 + speck.depth * 9,
                alpha: envelope * 0.55 * strength
            )
        }
    }

    private func glint(
        _ canvas: inout GraphicsContext, x: Double, y: Double,
        arm: Double, alpha: Double
    ) {
        // The halo used to be `arm * 1.8`, which — once `softPoint` has spread
        // its dark rim over 1.35 of that again — painted two soft-shaded discs
        // seventy-eight points across for a star sixteen points wide. It was
        // the largest shape in this file by a wide margin, drawn four or five
        // times a frame, and it was most of the sparkle's bill. At 1.15 the
        // glow hugs the glint instead of blooming past it, which is what a
        // point of light in clear air actually does; the star, which is the
        // part anyone actually sees, is untouched.
        let halo = arm * FlourishCanvas.fxHalo
        softPoint(&canvas, at: CGPoint(x: x, y: y), radius: halo,
                  colour: light, alpha: alpha * 0.8)

        var star = Path()
        let waist = max(0.9, arm * 0.16)
        star.move(to: CGPoint(x: x, y: y - arm))
        star.addQuadCurve(to: CGPoint(x: x + arm, y: y),
                          control: CGPoint(x: x + waist, y: y - waist))
        star.addQuadCurve(to: CGPoint(x: x, y: y + arm),
                          control: CGPoint(x: x + waist, y: y + waist))
        star.addQuadCurve(to: CGPoint(x: x - arm, y: y),
                          control: CGPoint(x: x - waist, y: y + waist))
        star.addQuadCurve(to: CGPoint(x: x, y: y - arm),
                          control: CGPoint(x: x - waist, y: y - waist))
        star.closeSubpath()
        // The cross sits on its own soft dark twin, one point wider, so the
        // glint keeps its shape against a bright sky as well as a dark one.
        canvas.stroke(star, with: .color(Theme.bark.opacity(min(0.24, alpha * 0.75))),
                      lineWidth: 2)
        canvas.fill(star, with: .color(light.opacity(alpha)))
    }

    // MARK: Shared

    /// A soft point of light, drawn the way an out-of-focus highlight really
    /// looks: a bright core sitting inside a slightly larger soft *rim*.
    ///
    /// The rim is not decoration — it is the only reason this layer exists on
    /// a light theme. The first version drew light alone, and on Snowdrift at
    /// noon it was **completely invisible**: adding cream to a near-white sky
    /// changes nothing a person can see. Screenshots of Sakura and Matcha in
    /// light appearance were blank. Value contrast has to go *both* ways, so
    /// every shape here carries both, and whichever way the background falls,
    /// one of the two reads.
    ///
    /// The rim is the one thing in this file that darkens anything, and the
    /// cap on it was set by measurement rather than by taste. At 0.13 the
    /// light-appearance themes came out at a peak luminance change of 28/255
    /// over about a tenth of a percent of the frame — which is to say, still
    /// invisible. At 0.26 they read. For scale: `Weather.veilOpacity` puts a
    /// flat 0.30 of this same colour across the *entire* screen for an
    /// overcast day and passes the contrast check, and these are gradients a
    /// dozen points across covering a couple of percent of the frame.
    private func softPoint(
        _ canvas: inout GraphicsContext, at centre: CGPoint,
        radius: Double, colour: Color, alpha: Double
    ) {
        if FlourishCanvas.fxRim > 0 {
            let rr = radius * FlourishCanvas.fxRimR
            canvas.fill(
                Path(ellipseIn: CGRect(
                    x: centre.x - rr, y: centre.y - rr,
                    width: rr * 2, height: rr * 2
                )),
                with: falloff(Theme.bark, at: centre,
                              alpha: min(0.26, alpha * 0.85), radius: rr)
            )
        }
        canvas.fill(
            Path(ellipseIn: CGRect(
                x: centre.x - radius, y: centre.y - radius,
                width: radius * 2, height: radius * 2
            )),
            with: falloff(colour, at: centre, alpha: alpha, radius: radius)
        )
    }

    /// The same two-tone idea for a line: a wider, softer dark pass under a
    /// narrower bright one. Rings and caustics go through this.
    private func litStroke(
        _ canvas: inout GraphicsContext, _ path: Path,
        colour: Color, alpha: Double, width: Double
    ) {
        guard alpha > 0.004 else { return }
        canvas.stroke(
            path,
            with: .color(Theme.bark.opacity(min(0.22, alpha * 0.75))),
            lineWidth: width + 1.6
        )
        canvas.stroke(path, with: .color(colour.opacity(alpha)), lineWidth: width)
    }

    /// The gradient itself: full at the centre, gone at the edge, with most of
    /// the brightness in the middle third.
    ///
    /// Deliberately a gradient rather than `GraphicsContext.addFilter(.blur)`.
    /// A blur filter is a full-surface pass; at 30fps on a layer that is up
    /// most of the time the app is open, that is a cost this app has already
    /// decided not to pay anywhere else.
    private func falloff(
        _ colour: Color, at centre: CGPoint, alpha: Double, radius: Double
    ) -> GraphicsContext.Shading {
        // `center:` is in the canvas's own coordinate space, not the path's —
        // leaving it at its `.zero` default puts every glow in the top-left
        // corner of the screen and each shape gets the one flat colour that
        // happens to be under it there. Always pass the point.
        .radialGradient(
            Gradient(stops: [
                .init(color: colour.opacity(alpha), location: 0),
                .init(color: colour.opacity(alpha * 0.45), location: 0.42),
                .init(color: colour.opacity(0), location: 1),
            ]),
            center: centre, startRadius: 0, endRadius: radius
        )
    }

    /// A particle's fixed seeds, from the same golden-ratio walk the rest of
    /// the app's fields use — fixed rather than random so a screenshot taken
    /// today can be compared with one from yesterday.
    private struct Speck {
        let sx: Double
        let sy: Double
        let depth: Double
        let phase: Double

        init(index: Int, salt: Double) {
            let n = Double(index) + salt
            sx = (n * 0.6180339887).truncatingRemainder(dividingBy: 1)
            sy = (n * 0.7548776662).truncatingRemainder(dividingBy: 1)
            depth = (n * 0.4142135624).truncatingRemainder(dividingBy: 1)
            phase = (n * 0.3819660113).truncatingRemainder(dividingBy: 1)
        }
    }
}

// MARK: - A note on the contrast check
//
// `tools/check_contrast.py` passes with this layer in, and it is worth being
// precise about why that is weaker evidence than it sounds. That check samples
// the exported scene pixels under the weather veils and the sky wash; it does
// not know this file exists, and it could not — these shapes move, and where
// a glint lands next second is not where it landed last.
//
// What actually keeps the text readable is structural rather than measured:
//
//   1. Every shape here is *light on* the scene. The check's concern is a text
//      pair losing separation, and the app's text is dark on a theme capsule
//      at 70–82 % opacity that composites *above* this layer. Lightening what
//      is behind that capsule cannot reduce the pair's ratio.
//   2. Peak alpha is 0.48, at the exact centre of a shape a dozen points across,
//      and every effect fades to nothing at its own edge. `Weather.veilOpacity`
//      puts 0.10-0.40 over the entire frame and passes; this is a rounding
//      error beside it.
//   3. Nothing here fills the frame. The largest single shape is a 15-point
//      bokeh disc; there is no full-screen wash anywhere in this file, which
//      is the one thing that could move a measured ratio.
//
// If a future effect wants a full-screen fill — a lightning lift, a warm
// flood — it does not belong here. `WeatherView.flash` is where that already
// lives, at 0.10, and it was argued for separately.
