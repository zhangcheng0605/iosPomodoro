import SwiftUI

/// The place behind everything else.
///
/// A static image — no timeline, no per-frame cost — laid over the phase
/// gradient and under the UI. The veil is the load-bearing part: it pulls the
/// artwork toward the theme's own background colour, which is what keeps text
/// legible over eight different places in four times of day without
/// hand-tuning each combination. `tools/check_contrast.py` measures the result
/// against the real pixels.
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
