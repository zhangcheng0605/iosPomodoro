import SwiftUI

/// The place behind everything else.
///
/// A static image — no timeline, no per-frame cost — laid over the phase
/// gradient and under the UI. The veil is the load-bearing part: it pulls the
/// artwork toward the theme's own background colour, which is what keeps text
/// legible over eight different places in four times of day without
/// hand-tuning each combination. `tools/check_contrast.py` measures the result
/// against the real pixels.
///
/// Two images now, not one. The sky's clouds were pixels in this picture and
/// therefore could not move; they have been lifted into a transparent sheet of
/// their own — see `DriftingCloudsView` — which sits between the artwork and
/// the veil, exactly where the painted cloud used to be. Composited at rest it
/// is the same picture to the byte, and the generator's own run proves that
/// rather than claiming it.
struct SceneryView: View {
    let place: Place
    let part: DayPart
    /// What the sky is doing here today. A second veil over the first, which
    /// is why the scene pipeline stays eight places by four times of day
    /// rather than becoming eight by four by nine.
    var weather: Weather = .clear

    /// How much of the theme background is laid back over the artwork.
    /// Raising this fades the place; lowering it risks the countdown.
    static let veil: Double = 0.52

    /// Where the crop is taken from when the frame is not the art's shape.
    ///
    /// `scaledToFill` in a frame wider than the artwork throws away the top
    /// and bottom in equal measure, and a scene's whole subject — the horizon,
    /// the hills, the ground the buddy stands on — lives in its bottom half.
    /// Centred, a landscape window keeps a band of empty sky and the place
    /// reads as a flat wash of colour. Anchored to the bottom it keeps the
    /// ground and loses sky it can spare.
    ///
    /// Desktop only, and deliberately so. On a phone the frame is the art's
    /// own shape to within a pixel or two, so there is no vertical crop to
    /// place — except on a short phone, where the scene *is* centred today and
    /// `check_stray.py` holds the resulting ground line as a fixture. Moving
    /// it there would be a change to a shipped screen dressed up as a Mac fix.
    private var fillAnchor: Alignment { Platform.isDesktop ? .bottom : .center }

    var body: some View {
        GeometryReader { geometry in
            Image(place.assetName(for: part))
                .interpolation(.none)      // keep the pixel edges crisp
                .resizable()
                .scaledToFill()
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: fillAnchor
                )
                .clipped()
                // Above the artwork and *below* both veils, which is the one
                // depth that keeps the still frame identical: the painted
                // cloud was under those veils too.
                .overlay(
                    DriftingCloudsView(
                        place: place, part: part,
                        size: geometry.size, anchor: fillAnchor
                    )
                )
                .overlay(Theme.cream.opacity(Self.veil))
                .overlay(weatherVeil)
        }
        // Last, so the artwork reaches the top and bottom edges rather than
        // stopping at the safe area with the phase gradient showing above it.
        .ignoresSafeArea()
        .allowsHitTesting(false)
            .accessibilityHidden(true)
            .transition(.opacity)
    }

    /// Kept as its own view so a clear day composites nothing at all rather
    /// than a fully transparent layer — the common case stays the cheap one.
    @ViewBuilder
    private var weatherVeil: some View {
        if let tint = Theme.weatherVeil(for: weather), weather.veilOpacity > 0 {
            tint
                .opacity(weather.veilOpacity)
                .animation(.easeInOut(duration: 1.2), value: weather)
        }
    }
}

// MARK: - The clouds

/// The sky's clouds, on their own sheet, so they can move.
///
/// ## Why this exists
///
/// `SunView` says it plainly: `generate_scenes.py` painted the clouds into
/// each place's grid, so they were pixels in a PNG and **could not budge**. A
/// stir moved the cloud body by the eight parts in 255 of the glow wash while
/// the sun — three drawn shapes — moved seventy. The honest fix was never a
/// second, invented cloud layer over the painted one; it was to stop painting
/// them into the picture. The generator now exports one transparent sheet per
/// place per time of day carrying the same clouds, at the same centres, in the
/// same grade, and the scene underneath is the same scene with sky where they
/// used to be. Laid back over it at rest, every one of the thirty-two
/// composites matches the old export with a maximum per-channel difference of
/// zero — the sheet's alpha is only ever 0 or 255, so source-over is exact and
/// there is no fringe to argue about.
///
/// ## Why it is cheap
///
/// One image, drawn twice, and a `Double`. There is no `TimelineView` here and
/// no `Canvas`: the drift is a single linear `offset` animation that repeats
/// forever, which SwiftUI hands to its own display link and which costs no
/// body evaluation at all — the same argument `SunView` makes for the stir.
/// The layer is 0.3–1.1 % opaque, so the largest of the thirty-two sheets is
/// 1,842 bytes and all of them together are 55 KB — the compositor is blending
/// almost nothing, and the download barely notices.
///
/// Compare what it sits next to: `WeatherView` runs a twelve-frame-a-second
/// `Canvas` whenever it is raining, and it runs it through a focus phase,
/// because weather is what it is like outside and does not wait to be asked.
/// A cloud crossing in a minute and a half is the quietest moving thing on
/// this screen by some distance, which is why it is not gated on the phase the
/// way a *touch* answer is.
struct DriftingCloudsView: View {
    let place: Place
    let part: DayPart
    /// The scene's frame, so this sheet lands in exactly the same place the
    /// artwork does. Passed in rather than measured again: two geometry
    /// readers is two chances to disagree.
    let size: CGSize
    /// `SceneryView.fillAnchor`, for the same reason.
    let anchor: Alignment

    /// Nothing here carries information, so all of it goes under Reduce
    /// Motion — the clouds simply stay where the artist put them, which is
    /// pixel for pixel the sky this app shipped with.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The shared signal a chip sends. Watched here rather than passed in:
    /// `ContentView` already refuses to bump it during a focus phase and under
    /// Reduce Motion (`SkyStir.allowed`, `stirSky`), so subscribing to the
    /// count inherits both rules instead of restating them.
    @State private var skyStir = SkyStir.shared
    /// 0 still, 1 at the furthest point of a stir. One stored `Double`.
    @State private var lean: Double = 0
    /// How far through a lap the sky is, 0 to 1. Animated once, on appear.
    @State private var lap: Double = 0

    /// The generator's canvas, `W, H` in `tools/generate_scenes.py`.
    ///
    /// It is here because a tiled layer has to know how wide one tile is, and
    /// `scaledToFill` will not say. `generate_scenes.py` reads these two
    /// numbers back out of this file on every run and fails if they have
    /// drifted — a duplicated constant that asks the other copy is the only
    /// kind this repo allows.
    static let artSize = CGSize(width: 132, height: 286)

    /// How long one full width takes to pass, in seconds.
    ///
    /// A minute and a half, which on an iPhone 17 measures 4.46 points a
    /// second: the widest cloud in the app — Harbor Isle's, 122 points across
    /// — takes twenty-seven seconds to travel its own width. That is
    /// deliberately below the speed at which movement
    /// pulls the eye. This is a focus timer, and a sky that visibly scrolls is
    /// a thing to watch instead of working — the drift is meant to be
    /// something you notice on the second glance, not the first.
    static let lapSeconds: Double = 90

    /// Rightward, because that is the way the stir already pushes.
    ///
    /// `skyStirred` is a positive — clockwise — rotation about a pivot far
    /// below the screen, so everything above that pivot leans to the right and
    /// comes back. A drift that ran the other way would make every stir read
    /// as the wind briefly reversing.
    private var offsetX: CGFloat { CGFloat(lap) * tile }

    /// One tile is the artwork's drawn width, which is what `scaledToFill`
    /// produces in this frame: the larger of the frame's width and the height
    /// scaled by the art's aspect.
    private var tile: CGFloat {
        max(size.width, size.height * Self.artSize.width / Self.artSize.height)
    }

    private var assetName: String { "\(place.assetName(for: part))_clouds" }

    var body: some View {
        ZStack {
            // Two copies, a tile apart, so a cloud that leaves on the right
            // arrives on the left. The generator paints the sheet with
            // wrapping columns, so the seam is continuous by construction —
            // and today it is also empty, since the nearest cloud stops ten
            // columns short of an edge. That is what makes `tile` a
            // forgiving number rather than a load-bearing one.
            sheet.offset(x: offsetX)
            sheet.offset(x: offsetX - tile)
        }
        // The same lean the sun takes, from the same signal. The heavy things
        // in the sky move together and trail the stars; see `SkyStir.heavyLean`.
        .skyStirred(lean * SkyStir.heavyLean)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear(perform: setSailing)
        // **Re-armed whenever the tile changes, and that is load-bearing.**
        // See `setSailing` for what goes wrong without it.
        .onChange(of: tile) { _, _ in setSailing() }
        .onChange(of: skyStir.count) { _, _ in
            // The two legs, out fast and back slow, and the return leg in the
            // completion handler — written as two calls in one tick it would
            // animate nothing at all. `ContentView` explains why at length;
            // this is the same movement on a different layer, which is why the
            // durations come from `SkyStir` rather than from here.
            withAnimation(.easeOut(duration: SkyStir.out)) {
                lean = 1
            } completion: {
                withAnimation(.easeInOut(duration: SkyStir.back)) {
                    lean = 0
                }
            }
        }
    }

    /// One sheet, framed exactly as `SceneryView` frames the scene — same
    /// `scaledToFill`, same frame, same anchor — so copy zero registers with
    /// the artwork to the pixel.
    ///
    /// Deliberately *not* clipped. The scene is, because a scene that bled
    /// would show artwork outside its frame; this bleeds nothing but
    /// transparency, and clipping it would put a hard edge across a cloud
    /// mid-lap and give the stir's rotation a corner to cut.
    private var sheet: some View {
        Image(assetName)
            .interpolation(.none)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height, alignment: anchor)
    }

    /// Start the lap.
    ///
    /// A single `repeatForever` linear animation from 0 to 1. At the end of a
    /// lap the layer is in exactly the state it started in — copy zero has
    /// taken copy one's place — so the restart is invisible and there is
    /// nothing to schedule, nothing to tick and nothing to unmount.
    ///
    /// ## Why it re-arms, and why arming once was wrong
    ///
    /// `.offset` animates *points*, so the distance a lap covers is fixed at
    /// the moment the animation is armed — and `onAppear` fires while the
    /// enclosing `GeometryReader` is still being sized. Measured on an iPhone
    /// 17, this view is offered `292 x 1304.7` and `402 x 900.2` before it
    /// settles on `402 x 874`, which is a tile of **602 pt** and then **403**.
    /// Armed once, the sheets ended up 403 pt apart while the animation swept
    /// 602 — so the sky ran half as fast again as it was asked to (a lap in
    /// 60 s rather than 90) and dropped 199 pt backwards once per lap, which
    /// on screen is a cloud visibly flinching. It was not the eye that caught
    /// it; it took logging the geometry.
    ///
    /// Re-arming on every change of `tile` fixes it at the root: the last arm
    /// is the one made with the size the view actually has. During launch that
    /// is three or four arms inside a tenth of a second, before anything is on
    /// screen. Afterwards `tile` only moves when the window does — a rotation
    /// or a resized Mac window — and restarting the lap there is the right
    /// answer anyway, since the distance it has to cover has changed.
    ///
    /// The reset has to land in its **own** runloop turn. Written as
    /// `lap = 0` and `lap = 1` back to back, SwiftUI coalesces the two, sees
    /// 1 → 1, and animates nothing at all — the same trap `ContentView`
    /// documents for the sky's two-legged stir.
    private func setSailing() {
        guard !reduceMotion else { return }
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { lap = 0 }
        Task { @MainActor in
            withAnimation(
                .linear(duration: Self.lapSeconds).repeatForever(autoreverses: false)
            ) {
                lap = 1
            }
        }
    }
}

// MARK: - The near plane

/// What is nearest to you in a place — a dock post, a grass fringe, a branch.
///
/// ## Why it exists
///
/// `docs/CONTENT_PLAN.md` F1 asked for it in the same breath as the pipeline
/// itself — "**Two layers per scene:** `scene_{id}_{part}` (background) and an
/// optional `scene_{id}_fg` foreground strip (a dock post, grass fringe,
/// branch) drawn at the bottom edge" — and only the first half was ever built.
/// Eight places shipped as a single flat plane. This is the second half.
///
/// It is the drifting cloud sheet's mirror image, on purpose: the same canvas,
/// the same palette, the same four grades, the same transparent export and the
/// same `scaledToFill` framing, so the near plane registers with the artwork to
/// the pixel exactly as the sky does. One image and no clock.
///
/// ## The veil is the depth
///
/// Half the scene's, and that halving is the whole trick. `SceneryView.veil`
/// lays 52 % of the theme's cream back over the artwork, which is what keeps
/// eight places legible in four times of day; laying **26 %** over the near
/// plane says the same thing an oil painter says by mixing more sky into the
/// far hills. The near world is the one you are standing in, so it keeps its
/// colour; the far world is seen through half a mile of air, so it does not.
/// `generate_scenes.py` reads both numbers back out of this file and fails if
/// the ratio drifts — equalise them and the layer quietly stops reading as
/// nearer, which is not something a screenshot would flag.
///
/// ## What it is not allowed to touch
///
/// Everything that stands in a place stands on `Stray.groundLine`. The
/// generator derives this layer's ceiling from that line plus six rows and
/// asserts it, because `check_stray.py` and `check_snail.py` measure a
/// silhouette against what is *behind* it and know nothing about a layer in
/// front. Nothing here may hide a creature.
///
/// And it takes no touches. The buddy, the toys, the stray and the treat tray
/// all live under this, and a transparent sheet that swallowed a tap on the
/// scene would be the worst kind of bug — one where the app simply feels
/// broken and nothing on screen says why.
struct SceneForegroundView: View {
    let place: Place
    let part: DayPart
    var weather: Weather = .clear

    /// Half `SceneryView.veil`. See the note above; the generator enforces it.
    static let veil: Double = 0.26

    /// `SceneryView.fillAnchor`, for the reason given there — the near plane
    /// has to be cropped the same way the scene is or it would sit at a
    /// different height than the ground it belongs to.
    private var fillAnchor: Alignment { Platform.isDesktop ? .bottom : .center }

    private var assetName: String { "\(place.assetName(for: part))_fg" }

    var body: some View {
        GeometryReader { geometry in
            sheet(geometry.size)
                // Masked by the sheet itself rather than laid over the frame:
                // this layer is mostly transparent, and an unmasked veil would
                // be a full-screen wash of cream over the whole app.
                .overlay(veils.mask(sheet(geometry.size)))
        }
        .ignoresSafeArea()
        // Deliberately not clipped, for the same reason the cloud sheet is
        // not: it bleeds nothing but transparency.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .transition(.opacity)
    }

    /// Framed exactly as `SceneryView` frames the scene, so the two register.
    private func sheet(_ size: CGSize) -> some View {
        Image(assetName)
            .interpolation(.none)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height, alignment: fillAnchor)
    }

    /// The theme's cream at half strength, and whatever the sky is doing at
    /// half of that too — one rule rather than two numbers to keep in step.
    @ViewBuilder
    private var veils: some View {
        ZStack {
            Theme.cream.opacity(Self.veil)
            if let tint = Theme.weatherVeil(for: weather), weather.veilOpacity > 0 {
                tint
                    .opacity(weather.veilOpacity * 0.5)
                    .animation(.easeInOut(duration: 1.2), value: weather)
            }
        }
    }
}

/// The sailboat, balloon or night train crossing the current place.
///
/// Its position is `engine.progress`, so the countdown is legible from across
/// the room: the boat leaves when you start and docks on the chime. It rides
/// the engine's existing tick — there is no timeline here.
struct VignetteView: View {
    let vignette: Vignette
    let progress: Double
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bobbing = false

    var body: some View {
        GeometryReader { geometry in
            let travel = geometry.size.width + vignette.size.width
            let x = -vignette.size.width / 2 + travel * eased
            Image(vignette.assetName)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: vignette.size.width, height: vignette.size.height)
                .opacity(0.9)
                // A gentle bob for the things that float; the train has rails.
                .offset(y: bobbing ? -3 : 3)
                .animation(
                    ridesRails || reduceMotion
                        ? nil
                        : .easeInOut(duration: 2.6).repeatForever(autoreverses: true),
                    value: bobbing
                )
                .position(x: x, y: geometry.size.height * vignette.altitude)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .transition(.opacity)
        .onAppear {
            if !ridesRails && !reduceMotion { bobbing = true }
        }
    }

    /// Under Reduce Motion the traveller jumps between quarter waypoints
    /// instead of gliding — the information survives, the movement doesn't.
    private var eased: Double {
        let clamped = min(max(progress, 0), 1)
        guard reduceMotion else { return clamped }
        return (clamped * 4).rounded(.down) / 4
    }

    private var ridesRails: Bool { vignette == .train }
}
