import SwiftUI

/// What a finger does to the night sky.
///
/// **Focus stays sacred**, the same way it does for `SceneToyView`: this layer
/// stays mounted through a focus phase and answers nothing. The sky is one of
/// the two places in this app you are invited to touch, and neither of them is
/// open during the twenty-five minutes you asked it to protect.
///
/// Two things answer, and they answer differently.
///
/// **The stars.** The figure you are currently building shows its unbuilt
/// stars as pin-pricks, and a drag from one star to a neighbour draws the line
/// between them and keeps it forever. Join every link and the figure is
/// *found*: it wears its lines and says its name a night or two before the
/// last star lands. It cannot be hurried past that — a link only becomes
/// drawable once one of its two ends is lit, and lighting stars is still one
/// per focus session finished after dark and nothing else. What a finger buys
/// is recognising the shape yourself, which is the only part of a
/// constellation that was ever the point.
///
/// **The moon.** Every moon answers; they do not answer the same. See
/// `MoonAnswer` — a full moon has somebody on it and a new moon has the whole
/// rest of the sky to give away, and the ordinary moons in between say what
/// they are called.
///
/// Nothing here is scored, nothing is spent, and no line was ever worth
/// anything except that you drew it.
struct NightSkyTouchView: View {
    /// False during a focus phase. The layer stays mounted and goes deaf, so
    /// nothing appears or disappears under a finger as a break starts — it
    /// fades, which is the one thing the sky is allowed to do on its own.
    let enabled: Bool
    /// Focus sessions finished after dark. Decides which stars are lit, and
    /// therefore which links can be drawn at all.
    let nightSessions: Int
    let tint: Color
    /// `Theme.sunshine` from the call site, the same colour the starfield
    /// draws its moon in — the two layers draw one moon between them.
    let moon: Color
    var touches: SkyTouches = .shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The star a drag started on, as an index into the figure in progress.
    @State private var held: Int?
    @State private var fingertip: CGPoint?
    @State private var flashes: [Flash] = []
    @State private var seed = 0
    @State private var moonEvent: MoonEvent?
    @State private var caption: Caption?

    /// How long the moon's answer lasts. Shared by the drawing and the reaper,
    /// so the 30fps canvas unmounts exactly when the answer ends rather than
    /// ticking on over an empty sky — the mistake the firefly made once.
    private static let moonLife: TimeInterval = 4.4
    /// A drag shorter than this is a tap, not a stroke.
    private static let tapSlop = 12.0

    var body: some View {
        // Touched in `body`, not in a draw closure: a `Canvas` closure is not
        // an observation scope, so a figure joined this second would sit in
        // storage and the guides would not notice until something unrelated
        // redrew the view.
        _ = touches.joins

        return GeometryReader { geometry in
            let size = geometry.size
            let sky = skyBand(in: size)

            ZStack(alignment: .topLeading) {
                guides()

                if !isIdle {
                    if reduceMotion {
                        // Every envelope in `draw` collapses to its held value,
                        // so the answer still *arrives* — it simply doesn't
                        // travel. Reduce Motion takes the movement away and is
                        // never allowed to take the information.
                        Canvas { canvas, drawSize in
                            draw(&canvas, size: drawSize, now: Date(), still: true)
                        }
                        .allowsHitTesting(false)
                    } else {
                        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                            Canvas { canvas, drawSize in
                                draw(&canvas, size: drawSize, now: context.date, still: false)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }

                captionLabel(size: size)

                // The one thing VoiceOver can reach, and deliberately the size
                // of the sky rather than the size of the screen: a full-bleed
                // accessibility element would sit in front of everything under
                // it and make the scene one enormous unlabelled control.
                Color.clear
                    .frame(width: size.width, height: sky.height)
                    .offset(y: sky.minY)
                    // `Color.clear` is invisible and still catches fingers,
                    // which cost an afternoon: this sits in front of every
                    // star in the band and swallowed the whole gesture while
                    // looking like nothing at all. Accessibility elements are
                    // unaffected by this — VoiceOver does not hit-test.
                    .allowsHitTesting(false)
                    .accessibilityElement()
                    .accessibilityLabel(spokenLabel)
                    .accessibilityAddTraits(.isImage)
                    .accessibilityActions { voiceOverActions(size: size) }
            }
            // Only the moon and the stars catch a finger. Everything else in
            // the top third of the screen falls through to the toy layer
            // below, so the firefly still comes when called under a sky you
            // have nothing left to join.
            .contentShape(SkyReach(targets: enabled ? targets(in: size) : []))
            .gesture(enabled ? gesture(in: size) : nil)
            .onDisappear { TouchTracker.shared.x = nil }
            .onAppear { armDebugAnswer(size: size) }
        }
        .ignoresSafeArea()
    }

    // MARK: What is touchable

    /// The figure the next star belongs to, or nil once all seven are up.
    private var building: Int? {
        ConstellationAtlas.inProgress(nightSessions: nightSessions)
    }

    /// Every figure that already has a name — finished on its own, or found by
    /// hand before it finished. Tapping any of their stars says which it is.
    private var named: [Int] {
        ConstellationAtlas.all.indices.filter {
            ConstellationAtlas.isComplete($0, nightSessions: nightSessions)
                || touches.hasFound(ConstellationAtlas.all[$0])
        }
    }

    /// One touch target: where it is, how big, and what it belongs to.
    private struct Target {
        enum Kind {
            case moon
            /// A star of the figure being built — the only kind you can draw from.
            case building(Int)
            /// A star of a figure that already has a name.
            case named(figure: Int)
        }
        let at: CGPoint
        let radius: Double
        let kind: Kind
    }

    private func targets(in size: CGSize) -> [Target] {
        var targets = [Target(
            at: SkyGeometry.moonCenter(in: size),
            radius: SkyGeometry.moonTouchRadius(in: size),
            kind: .moon
        )]
        if let index = building, ConstellationAtlas.litStars(
            of: index, nightSessions: nightSessions
        ) > 0 {
            let figure = ConstellationAtlas.all[index]
            for star in 0..<figure.starCount {
                targets.append(Target(
                    at: SkyGeometry.star(figure, star, in: size),
                    radius: SkyGeometry.starTouchRadius,
                    kind: .building(star)
                ))
            }
        }
        for index in named {
            let figure = ConstellationAtlas.all[index]
            for star in 0..<figure.starCount {
                // Smaller than the building figure's: these are only ever
                // tapped, never dragged from, and seven finished figures at
                // the full radius would tile most of the sky band.
                targets.append(Target(
                    at: SkyGeometry.star(figure, star, in: size),
                    radius: 17,
                    kind: .named(figure: index)
                ))
            }
        }
        return targets
    }

    /// The hit region: a hole-punched sky. Everything outside these circles
    /// belongs to whatever is underneath.
    private struct SkyReach: Shape {
        let targets: [Target]

        func path(in rect: CGRect) -> Path {
            var path = Path()
            for target in targets {
                path.addEllipse(in: CGRect(
                    x: target.at.x - target.radius, y: target.at.y - target.radius,
                    width: target.radius * 2, height: target.radius * 2
                ))
            }
            return path
        }
    }

    private func nearest(to point: CGPoint, in size: CGSize) -> Target? {
        targets(in: size)
            .filter { hypot($0.at.x - point.x, $0.at.y - point.y) <= $0.radius }
            .min {
                hypot($0.at.x - point.x, $0.at.y - point.y)
                    < hypot($1.at.x - point.x, $1.at.y - point.y)
            }
    }

    /// The star of the figure in progress nearest a point, or nil.
    ///
    /// A separate walk from `nearest` on purpose: the end of a stroke wants
    /// the nearest *joinable* star even if a finished figure's star happens to
    /// be a pixel closer, and the two lists overlap wherever two figures do.
    private func nearestBuildingStar(to point: CGPoint, in size: CGSize) -> Int? {
        guard let index = building else { return nil }
        let figure = ConstellationAtlas.all[index]
        // Written as a plain loop rather than map/filter/min: the chained
        // version with a tuple element in it was the one expression in this
        // file the type checker gave up on.
        var best: Int?
        var bestDistance = SkyGeometry.starTouchRadius
        for star in 0..<figure.starCount {
            let at = SkyGeometry.star(figure, star, in: size)
            let distance = hypot(at.x - point.x, at.y - point.y)
            if distance <= bestDistance {
                bestDistance = distance
                best = star
            }
        }
        return best
    }

    /// The star a stroke that started on `from` would land on.
    ///
    /// Only stars `from` is actually linked to are candidates, and the reach
    /// is wider than a star's own. That is not generosity for its own sake:
    /// The Little Paw is seventy points across on a phone and its stars sit
    /// twenty-five apart, so "nearest star" would ask for a quarter-inch of
    /// precision from a finger that covers half an inch. "Nearest star this
    /// one could possibly join to" asks for none — a toe has exactly one
    /// partner, the pad, and a stroke in roughly its direction is unambiguous.
    /// Land near nothing joinable and the stroke is simply not a join.
    private func nearestPartner(of from: Int, to point: CGPoint, in size: CGSize) -> Int? {
        guard let index = building else { return nil }
        let figure = ConstellationAtlas.all[index]
        var best: Int?
        var bestDistance = 40.0
        for (a, b) in figure.links {
            let other: Int
            if a == from { other = b } else if b == from { other = a } else { continue }
            let at = SkyGeometry.star(figure, other, in: size)
            let distance = hypot(at.x - point.x, at.y - point.y)
            if distance <= bestDistance {
                bestDistance = distance
                best = other
            }
        }
        return best
    }

    // MARK: The finger

    private func gesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // The buddy watches a finger on the sky the same way it
                // watches one on the water. Same tracker, same two-pixel
                // pupil shift — to the buddy they are the same event.
                TouchTracker.shared.x = value.location.x / max(size.width, 1)
                fingertip = value.location
                if held == nil, let star = nearestBuildingStar(to: value.startLocation, in: size) {
                    held = star
                    HapticsDirector.shared.nudge()
                }
            }
            .onEnded { value in
                TouchTracker.shared.x = nil
                let travel = hypot(value.translation.width, value.translation.height)
                if travel <= Self.tapSlop {
                    tap(at: value.location, in: size)
                } else if let from = held,
                          let to = nearestPartner(of: from, to: value.location, in: size) {
                    join(from: from, to: to, in: size)
                }
                held = nil
                fingertip = nil
            }
    }

    private func tap(at point: CGPoint, in size: CGSize) {
        guard let target = nearest(to: point, in: size) else { return }
        switch target.kind {
        case .moon:
            askTheMoon(in: size)
        case .named(let index):
            say(ConstellationAtlas.all[index], in: size)
        case .building:
            // Nothing to award and nothing to say — but the star acknowledges
            // the touch, because a target that answers silence is a target
            // nobody tries twice.
            add(Flash(kind: .star(at: point), born: Date(), life: 0.9))
            HapticsDirector.shared.nudge()
        }
    }

    private func join(from: Int, to: Int, in size: CGSize) {
        guard let index = building else { return }
        let figure = ConstellationAtlas.all[index]
        let link = SkyLink(figure: figure.id, from, to)
        guard SkyTouches.isReachable(
            link, figureIndex: index, nightSessions: nightSessions
        ) else { return }
        guard touches.join(link) else { return }   // already drawn: silent

        let a = SkyGeometry.star(figure, link.a, in: size)
        let b = SkyGeometry.star(figure, link.b, in: size)
        add(Flash(kind: .join(a, b), born: Date(), life: 1.4))
        HapticsDirector.shared.detent()

        if touches.hasFound(figure) {
            say(figure, in: size, found: true)
            HapticsDirector.shared.stamp()
        }
    }

    /// Names a figure, and lights every line of it for a moment.
    private func say(_ figure: Constellation, in size: CGSize, found: Bool = false) {
        add(Flash(kind: .figure(figure.id), born: Date(), life: found ? 3.2 : 2.0))
        show(
            found ? "\(figure.name) — yours, and early" : figure.name,
            in: size, life: found ? 4.0 : 2.6
        )
        if !found { HapticsDirector.shared.nudge() }
    }

    private func askTheMoon(in size: CGSize) {
        let answer = MoonAnswer.tonight()
        touches.askMoon(named: MoonPhase.name())
        moonEvent = MoonEvent(answer: answer, born: Date())
        show(answer.caption(), in: size, life: Self.moonLife)
        HapticsDirector.shared.nudge()
        reapMoon()
    }

    /// Clears the answer once it has finished, so the timeline can unmount.
    private func reapMoon() {
        let born = moonEvent?.born
        Task {
            try? await Task.sleep(nanoseconds: UInt64(Self.moonLife * 1_000_000_000))
            if moonEvent?.born == born { moonEvent = nil }
        }
    }

    /// `-PawmodoroAskMoon`: the answer, without a tap, a beat after launch.
    private func armDebugAnswer(size: CGSize) {
        guard LaunchOptions.askMoon, enabled else { return }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            askTheMoon(in: size)
        }
    }

    // MARK: Bookkeeping

    private var isIdle: Bool {
        flashes.isEmpty && moonEvent == nil && held == nil
    }

    private func add(_ flash: Flash) {
        seed += 1
        var flash = flash
        flash.id = seed
        flashes.append(flash)
        // Reaped rather than left to pile up: an evening of poking would
        // otherwise be an evening of dead structs keeping a canvas alive.
        let deadline = flash.born.addingTimeInterval(flash.life)
        Task {
            let wait = max(0, deadline.timeIntervalSinceNow)
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            flashes.removeAll { $0.id == flash.id }
        }
    }

    /// Puts a line up over the sky.
    ///
    /// One slot, in the top-right corner, rather than under whatever it is
    /// about. Under-the-thing was tried and it is not available on this
    /// screen: **this layer sits behind the countdown**, so a caption that
    /// strays over the ring or the phase chip is not merely crowded, it is
    /// invisible. Measured, the free sky is the strip right of the chip and
    /// above the ring's top — which is also where the moon is, and where most
    /// of what the sky has to say comes from.
    private func show(_ text: String, in size: CGSize, life: TimeInterval) {
        let born = Date()
        caption = Caption(text: text, born: born, life: life)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(life * 1_000_000_000))
            if caption?.born == born { caption = nil }
        }
    }

    // MARK: Layers

    /// The stars of the figure you are building that have not been reached
    /// yet, as pin-pricks — the same idiom the atlas already uses, arriving in
    /// the sky so a finger knows where to go.
    ///
    /// No line is ever hinted at, only points. The atlas has always shown the
    /// *shape* of an unbuilt figure; putting the shape in the sky as well
    /// would leave nothing to recognise.
    @ViewBuilder
    private func guides() -> some View {
        Canvas { canvas, drawSize in
            guard let index = building else { return }
            let figure = ConstellationAtlas.all[index]
            let lit = ConstellationAtlas.litStars(of: index, nightSessions: nightSessions)
            guard lit > 0 else { return }
            // Moonlight washes stars out, and a new moon hands them back. The
            // hit targets do not move — only how easy they are to see, which
            // is the honest half of the effect.
            let alpha = 0.21 - 0.08 * MoonPhase.illumination()
            for star in lit..<figure.starCount {
                let at = SkyGeometry.star(figure, star, in: drawSize)
                canvas.stroke(
                    Path(ellipseIn: CGRect(x: at.x - 2.6, y: at.y - 2.6, width: 5.2, height: 5.2)),
                    with: .color(tint.opacity(alpha)),
                    lineWidth: 0.8
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .opacity(enabled ? 1 : 0)
        .animation(.easeInOut(duration: 1.1), value: enabled)
    }

    @ViewBuilder
    private func captionLabel(size: CGSize) -> some View {
        if let caption {
            // Text over scenery sits on its own backing — with a place behind
            // the app the sky is not a known colour, and this is the one row
            // of type the sky ever puts up.
            Text(caption.text)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.bark)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                // A rounded rectangle rather than the app's usual capsule: this
                // wraps to two and three lines, and a capsule around a block
                // that tall is a lozenge with half its width in end-caps.
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Theme.surface.opacity(0.9))
                )
                .frame(width: size.width * 0.32, alignment: .trailing)
                // Measured, not chosen: 0.10 tucked the first line under the
                // toolbar's right-hand pill. This clears the pill above, the
                // phase chip to the left, and the moon's halo below.
                .offset(x: size.width * 0.68 - 12, y: size.height * 0.115)
                .transition(.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .id(caption.born)
        }
    }

    // MARK: Drawing

    private func draw(
        _ canvas: inout GraphicsContext, size: CGSize, now: Date, still: Bool
    ) {
        drawStroke(&canvas, size: size)
        for flash in flashes {
            let age = now.timeIntervalSince(flash.born)
            guard age >= 0, age < flash.life else { continue }
            let t = still ? 0.25 : age / flash.life
            draw(flash, t: t, in: &canvas, size: size, still: still)
        }
        if let moonEvent {
            let age = now.timeIntervalSince(moonEvent.born)
            if age >= 0, age < Self.moonLife {
                draw(moonEvent, age: age, in: &canvas, size: size, still: still)
            }
        }
    }

    /// The star being held, and the line following the finger.
    ///
    /// Drawn under Reduce Motion too: this is direct manipulation, not
    /// animation — a line that does not follow your finger is a broken
    /// control rather than a calmer one.
    private func drawStroke(_ canvas: inout GraphicsContext, size: CGSize) {
        guard let index = building, let held, let fingertip else { return }
        let figure = ConstellationAtlas.all[index]
        let from = SkyGeometry.star(figure, held, in: size)

        var line = Path()
        line.move(to: from)
        line.addLine(to: fingertip)
        canvas.stroke(line, with: .color(tint.opacity(0.52)), lineWidth: 1.3)

        // The held star wears a ring, so "this one is caught" is visible
        // without moving the star itself.
        canvas.stroke(
            Path(ellipseIn: CGRect(x: from.x - 7, y: from.y - 7, width: 14, height: 14)),
            with: .color(tint.opacity(0.55)),
            lineWidth: 1.2
        )
        canvas.fill(
            Path(ellipseIn: CGRect(x: from.x - 2.4, y: from.y - 2.4, width: 4.8, height: 4.8)),
            with: .color(tint.opacity(0.9))
        )

        // And the star it would land on, so a stroke can be aimed.
        if let over = nearestPartner(of: held, to: fingertip, in: size) {
            let at = SkyGeometry.star(figure, over, in: size)
            canvas.stroke(
                Path(ellipseIn: CGRect(x: at.x - 7, y: at.y - 7, width: 14, height: 14)),
                with: .color(tint.opacity(0.4)),
                lineWidth: 1.0
            )
        }
    }

    private func draw(
        _ flash: Flash, t: Double, in canvas: inout GraphicsContext,
        size: CGSize, still: Bool
    ) {
        switch flash.kind {
        case .join(let a, let b):
            // The line settles onto the sky: it arrives bright and cools to
            // the weight it will keep. The kept line is drawn by the
            // starfield underneath, so this only has the cooling to do.
            var line = Path()
            line.move(to: a)
            line.addLine(to: b)
            canvas.stroke(
                line, with: .color(tint.opacity(still ? 0.5 : 0.7 * (1 - t))),
                lineWidth: still ? 1.4 : 1.0 + 1.2 * (1 - t)
            )
        case .star(let at):
            let r = still ? 6.0 : 4 + t * 7
            canvas.stroke(
                Path(ellipseIn: CGRect(x: at.x - r, y: at.y - r, width: r * 2, height: r * 2)),
                with: .color(tint.opacity(still ? 0.45 : 0.5 * (1 - t))),
                lineWidth: 1.0
            )
        case .figure(let id):
            guard let figure = ConstellationAtlas.all.first(where: { $0.id == id })
            else { return }
            // A hump rather than a fade: the whole figure comes up, holds, and
            // goes back to being sky.
            let glow = still ? 0.5 : sin(t * .pi)
            var path = Path()
            for (a, b) in figure.links {
                path.move(to: SkyGeometry.star(figure, a, in: size))
                path.addLine(to: SkyGeometry.star(figure, b, in: size))
            }
            canvas.stroke(path, with: .color(tint.opacity(0.55 * glow)), lineWidth: 1.3)
            for star in 0..<figure.starCount {
                let at = SkyGeometry.star(figure, star, in: size)
                canvas.fill(
                    Path(ellipseIn: CGRect(x: at.x - 2.6, y: at.y - 2.6,
                                           width: 5.2, height: 5.2)),
                    with: .color(tint.opacity(0.8 * glow))
                )
            }
        }
    }

    // MARK: The moon's answer

    private func draw(
        _ event: MoonEvent, age: TimeInterval, in canvas: inout GraphicsContext,
        size: CGSize, still: Bool
    ) {
        let center = SkyGeometry.moonCenter(in: size)
        let radius = SkyGeometry.moonRadius(in: size)

        // The ring every moon gives: the answer leaving. Pure movement, so
        // Reduce Motion simply doesn't get one — the answer itself is still
        // drawn below, and the caption says what it was.
        if !still {
            for index in 0..<2 {
                let t = (age - Double(index) * 0.28) / 1.5
                guard t > 0, t < 1 else { continue }
                let r = radius * (1.1 + 2.4 * t)
                canvas.stroke(
                    Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r,
                                           width: r * 2, height: r * 2)),
                    with: .color(moon.opacity(0.30 * (1 - t))),
                    lineWidth: 1.0
                )
            }
        }

        switch event.answer {
        case .rabbit:
            drawRabbit(&canvas, center: center, radius: radius, age: age, still: still)
        case .starsGiven:
            drawGivenStars(&canvas, size: size, age: age, still: still)
        case .limb:
            drawLimb(&canvas, center: center, radius: radius, age: age, still: still)
        }
    }

    /// The full moon leans in, and the shadow on it turns out to be somebody.
    ///
    /// The disc is redrawn here at the larger size rather than the starfield
    /// being asked to grow: at a real moon's twenty-odd points a hare is four
    /// pixels of ear, and the whole answer is that you can suddenly see who it
    /// is. Under Reduce Motion it is simply already leaning in.
    private func drawRabbit(
        _ canvas: inout GraphicsContext, center: CGPoint, radius: Double,
        age: TimeInterval, still: Bool
    ) {
        let bump = still ? 1.0 : envelope(age, rise: 0.55, fall: 0.9, life: Self.moonLife)
        let r = radius * (1 + 0.5 * bump)

        func disc(_ scale: Double) -> Path {
            Path(ellipseIn: CGRect(x: center.x - r * scale, y: center.y - r * scale,
                                   width: r * scale * 2, height: r * scale * 2))
        }
        canvas.fill(disc(1.55), with: .color(moon.opacity(0.16)))
        // Opaque enough to cover the starfield's own disc underneath — at full
        // moon that disc is a complete circle, so this replaces it exactly.
        canvas.fill(disc(1.0), with: .color(moon.opacity(0.97)))

        let box = CGRect(x: center.x - r * 0.82, y: center.y - r * 0.82,
                         width: r * 1.64, height: r * 1.64)
        canvas.fill(hare(in: box), with: .color(tint.opacity(0.55 * (still ? 1 : bump))))
    }

    /// The hare in the moon, pounding.
    ///
    /// Drawn as a path rather than a sprite because it is only ever seen
    /// inside one circle, at one size, in one colour — a generated imageset
    /// would be a file to keep in step for nothing.
    ///
    /// Laid out with the mortar in the bottom-right and the hare filling the
    /// left, because that is the only arrangement that survived being looked
    /// at: the first draft put the head between the ears and the pestle and
    /// all three fused into one bar with a bucket beside it. Everything here
    /// is separated by a gap or by a limb that explains the gap.
    private func hare(in rect: CGRect) -> Path {
        var path = Path()
        func at(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        func ellipse(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
            path.addEllipse(in: CGRect(
                x: rect.minX + (x - w / 2) * rect.width,
                y: rect.minY + (y - h / 2) * rect.height,
                width: w * rect.width, height: h * rect.height
            ))
        }

        ellipse(0.29, 0.66, 0.46, 0.38)     // the haunch, sitting
        ellipse(0.48, 0.52, 0.26, 0.26)     // the shoulder
        ellipse(0.44, 0.31, 0.29, 0.26)     // the head
        ellipse(0.60, 0.55, 0.16, 0.14)     // the paws, on the pestle

        // Two ears, up and leaning away from the mortar — the first draft's
        // were needles, because a quad curve from a narrow base straight to a
        // point has nothing to be wide *at*. The control points now sit out to
        // the side of the ear rather than along it.
        for (base, tip, controls) in [
            ((0.34, 0.33), (0.19, 0.02), ((0.19, 0.18), (0.38, 0.13))),
            ((0.47, 0.29), (0.37, -0.01), ((0.35, 0.13), (0.54, 0.14))),
        ] as [((Double, Double), (Double, Double), ((Double, Double), (Double, Double)))] {
            path.move(to: at(base.0, base.1))
            path.addQuadCurve(to: at(tip.0, tip.1), control: at(controls.0.0, controls.0.1))
            path.addQuadCurve(
                to: at(base.0 + 0.11, base.1 - 0.01),
                control: at(controls.1.0, controls.1.1)
            )
            path.closeSubpath()
        }

        // The pestle, held across to the mortar's mouth.
        path.move(to: at(0.58, 0.44))
        path.addLine(to: at(0.84, 0.68))
        path.addLine(to: at(0.77, 0.76))
        path.addLine(to: at(0.51, 0.52))
        path.closeSubpath()

        // The mortar, with a gap of moon between it and the hare.
        path.move(to: at(0.68, 0.74))
        path.addLine(to: at(0.96, 0.74))
        path.addLine(to: at(0.90, 0.96))
        path.addLine(to: at(0.74, 0.96))
        path.closeSubpath()
        return path
    }

    /// The new moon has nothing to show you, so it gives you everything else.
    ///
    /// Every background star and every wandering star comes up to full and
    /// settles back. Positions come from `SkyGeometry`, which is also where
    /// the starfield gets them, so the swell lands *on* the stars rather than
    /// beside them.
    private func drawGivenStars(
        _ canvas: inout GraphicsContext, size: CGSize, age: TimeInterval, still: Bool
    ) {
        let swell = still ? 1.0 : envelope(age, rise: 0.7, fall: 1.6, life: Self.moonLife)
        guard swell > 0.02 else { return }
        var points = SkyGeometry.scatter(in: size)
        points += SkyGeometry.wanderers(
            count: ConstellationAtlas.wanderers(nightSessions: nightSessions), in: size
        )
        for (index, at) in points.enumerated() {
            let r = 2.0 + Double(index % 3) * 0.5
            canvas.fill(
                Path(ellipseIn: CGRect(x: at.x - r * 2.8, y: at.y - r * 2.8,
                                       width: r * 5.6, height: r * 5.6)),
                with: .color(tint.opacity(0.20 * swell))
            )
            canvas.fill(
                Path(ellipseIn: CGRect(x: at.x - r, y: at.y - r, width: r * 2, height: r * 2)),
                with: .color(tint.opacity(0.85 * swell))
            )
        }
    }

    /// Every other moon: light runs along the edge that has any.
    private func drawLimb(
        _ canvas: inout GraphicsContext, center: CGPoint, radius: Double,
        age: TimeInterval, still: Bool
    ) {
        // Which side is lit is the same question `StarfieldView` answers when
        // it decides which way to slide the shadow: waxing keeps the light on
        // the right, waning on the left.
        let waxing = MoonPhase.age() < 0.5
        let facing = waxing ? 0.0 : Double.pi

        func arc(from start: Double, to end: Double) -> Path {
            var path = Path()
            path.addArc(
                center: center, radius: radius * 1.06,
                startAngle: .radians(start), endAngle: .radians(end),
                clockwise: false
            )
            return path
        }

        if still {
            // The whole lit edge, held. The information is "this side has the
            // light on it", and that survives having no travel at all.
            canvas.stroke(
                arc(from: facing - .pi / 2, to: facing + .pi / 2),
                with: .color(moon.opacity(0.85)), lineWidth: 2.0
            )
            return
        }
        let t = min(1, age / 1.4)
        let head = facing - .pi / 2 + .pi * t
        canvas.stroke(
            arc(from: facing - .pi / 2, to: facing + .pi / 2),
            with: .color(moon.opacity(0.35 * (1 - t * 0.6))), lineWidth: 1.2
        )
        canvas.stroke(
            arc(from: max(facing - .pi / 2, head - 0.5), to: head),
            with: .color(moon.opacity(0.95 * (1 - t * t))), lineWidth: 2.8
        )
    }

    /// Up, hold, down — one shape for every answer's life, so nothing has to
    /// invent its own timing and they all feel like the same moon.
    private func envelope(
        _ age: TimeInterval, rise: TimeInterval, fall: TimeInterval, life: TimeInterval
    ) -> Double {
        if age < rise { return max(0, age / rise) }
        if age > life - fall { return max(0, (life - age) / fall) }
        return 1
    }

    // MARK: Accessibility

    /// A trace cannot be made with VoiceOver on, so it is not the only way in.
    ///
    /// The two actions below do exactly what a finger does and nothing a
    /// finger cannot: "Join the next stars" draws **one** link — the next one
    /// that is drawable — so finding a figure by hand still takes as many
    /// deliberate moves as it takes anybody, and every one of them is
    /// announced. Nothing here is a shortcut; it is the same walk with a
    /// different door.
    private var spokenLabel: String {
        var parts = ["The night sky. The moon is \(MoonPhase.name().lowercased())."]
        let done = ConstellationAtlas.completedCount(nightSessions: nightSessions)
        parts.append("\(done) of \(ConstellationAtlas.all.count) figures are up.")
        if let index = building {
            let figure = ConstellationAtlas.all[index]
            let lit = ConstellationAtlas.litStars(of: index, nightSessions: nightSessions)
            if touches.hasFound(figure) {
                parts.append("You joined \(figure.name) by hand.")
            } else if lit > 0 {
                let left = pendingLinks.count
                parts.append(
                    left > 0
                        ? "\(lit) stars are lit in the one you are building, "
                          + "and \(left) \(left == 1 ? "join is" : "joins are") "
                          + "there to be drawn."
                        : "\(lit) stars are lit in the one you are building, "
                          + "with nothing left to join until the next one."
                )
            }
        }
        if !enabled {
            parts.append("It answers on a break, not during focus.")
        }
        return parts.joined(separator: " ")
    }

    /// The links that could be drawn right now and have not been.
    private var pendingLinks: [SkyLink] {
        guard let index = building else { return [] }
        return SkyTouches
            .reachableLinks(of: index, nightSessions: nightSessions)
            .filter { !touches.hasJoined($0) }
    }

    @ViewBuilder
    private func voiceOverActions(size: CGSize) -> some View {
        if enabled {
            Button("Ask the moon") {
                askTheMoon(in: size)
                AccessibilityNotification.Announcement(MoonAnswer.tonight().spoken()).post()
            }
            if let index = building, let next = pendingLinks.first {
                Button("Join the next stars") {
                    join(from: next.a, to: next.b, in: size)
                    AccessibilityNotification.Announcement(
                        joinAnnouncement(figureIndex: index)
                    ).post()
                }
            }
        }
    }

    private func joinAnnouncement(figureIndex: Int) -> String {
        let figure = ConstellationAtlas.all[figureIndex]
        if touches.hasFound(figure) {
            return "Joined. The figure is finished, and it is called "
                + "\(figure.name). \(figure.lore.replacingOccurrences(of: "\n", with: " "))"
        }
        let left = pendingLinks.count
        guard left > 0 else {
            return "Joined. Nothing more can be drawn until another star goes up."
        }
        return "Joined. \(left) more \(left == 1 ? "join" : "joins") can be drawn tonight."
    }

    // MARK: Geometry helpers

    private func skyBand(in size: CGSize) -> CGRect {
        CGRect(
            x: 0, y: ConstellationAtlas.skyTop * size.height,
            width: size.width,
            height: (ConstellationAtlas.skyBottom - ConstellationAtlas.skyTop) * size.height
        )
    }

    // MARK: Model

    private struct Flash: Identifiable {
        enum Kind {
            case join(CGPoint, CGPoint)
            case star(at: CGPoint)
            /// A whole figure lighting up, by id — the positions are worked
            /// out at draw time so a rotation cannot leave a flash behind at
            /// last frame's coordinates.
            case figure(String)
        }
        var id: Int = 0
        let kind: Kind
        let born: Date
        let life: TimeInterval
    }

    private struct MoonEvent: Equatable {
        let answer: MoonAnswer
        let born: Date
    }

    private struct Caption: Equatable {
        let text: String
        let born: Date
        let life: TimeInterval
    }
}

#Preview("A sky with something to join") {
    ZStack {
        Color.black
        StarfieldView(tint: .white, moon: .yellow, nightSessions: 4)
        NightSkyTouchView(
            enabled: true, nightSessions: 4, tint: .white, moon: .yellow
        )
    }
    .ignoresSafeArea()
}
