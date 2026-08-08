import SwiftUI

/// The daytime half of the sky, and the movement both halves share.
///
/// ## Why there is a sun here at all
///
/// There wasn't one. `tools/generate_scenes.py` paints clouds straight into
/// each place's grid — `cloud(g, 34, 26, 9, rng)` and its dozens of siblings —
/// and exports the result four times, once per time of day. Those clouds are
/// pixels in a PNG that `SceneryView` draws with `.interpolation(.none)`, so
/// **they cannot move**, and drawing a second cloud layer over them would put
/// two weather systems on one screen travelling at different speeds. No scene
/// paints a sun, though, which leaves the sun genuinely free: it is the one
/// thing in a daytime sky that nothing else has an opinion about.
///
/// So the day answers with the sun, and the sky it sits in leans.
///
/// ## Why it costs nothing
///
/// There is no `TimelineView` in this file and no `Canvas` that redraws. The
/// sun is three filled circles laid out once; the stir arrives as an
/// animatable `Double` and is spent entirely on `scaleEffect`, `opacity` and
/// `rotationEffect`, which SwiftUI interpolates on its own display link and
/// then stops. An idle sky is three static shapes and no running clock —
/// which is a stronger claim than "the canvas unmounts when the sky settles",
/// because nothing was ever mounted to unmount.
///
/// The moon is not drawn here. It belongs to `StarfieldView`, which already
/// has it at its real phase; the night stir reaches it through the same
/// `skyStirred` lean the stars get.
struct SunView: View {
    let part: DayPart
    /// `Theme.sunshine` from the call site — the same colour the moon is
    /// drawn in, so the one bright thing in the corner belongs to whatever
    /// theme is on at either end of the day.
    let tint: Color
    /// 0 when the sky is still, 1 at the furthest point of a stir. Animated
    /// by the call site; nothing in here drives it.
    var stir: Double = 0

    var body: some View {
        // Guarded as well as gated at the call site. A sun after dark would
        // be the sort of thing that only shows up in one screenshot out of
        // forty, so it is impossible in two places rather than one.
        if part != .night {
            ZStack {
                glow
                disc
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// The light changing across the whole scene, which is as close as this
    /// app can honestly get to a cloud moving.
    ///
    /// The clouds are painted into the artwork and will not budge, but what a
    /// cloud actually *does* is change the light on the ground — so the stir
    /// lifts the whole scene by a few percent of sunshine and lets it fall
    /// back. It is a wash rather than a travelling band on purpose: a band
    /// sweeping across the screen is the loading-skeleton shimmer, and this
    /// app is not selling anything.
    ///
    /// Four and a half percent at its peak, over text that carries its own
    /// capsule at 70–82 %, and gone in two and a half seconds. It brightens
    /// rather than dims, so nothing it touches gets harder to read.
    private var glow: some View {
        tint.opacity(0.045 * stir)
    }

    /// Sun, moon, same corner.
    ///
    /// `SkyGeometry.moonCenter` is not a slot that happens to suit; it is
    /// *the* slot, the one place in the sky verified clear of the countdown
    /// rows and of every constellation's reach. Putting the sun anywhere else
    /// would mean re-establishing all of that for a second position, and the
    /// day has no constellations to collide with anyway. One opinion about
    /// where the sky's things are, which is what `SkyGeometry` is for.
    ///
    /// Three concentric discs rather than a gradient or a ray burst, matching
    /// `StarfieldView.drawMoon`'s halo-then-disc exactly. The scenes are pixel
    /// art and the moon is already a smooth circle over them, so a smooth
    /// circle is the register this sky is in — a rayed cartoon sun would be
    /// the only thing on screen shouting.
    private var disc: some View {
        GeometryReader { geometry in
            let center = SkyGeometry.moonCenter(in: geometry.size)
            let radius = SkyGeometry.moonRadius(in: geometry.size)

            ZStack {
                // The corona breathes widest, so the stir is legible from the
                // far side of the room even though the sun itself barely
                // moves.
                Circle()
                    .fill(tint.opacity(0.15 * strength))
                    .frame(width: radius * 4.2, height: radius * 4.2)
                    .scaleEffect(1 + 0.17 * stir)
                Circle()
                    .fill(tint.opacity(0.26 * strength))
                    .frame(width: radius * 2.7, height: radius * 2.7)
                    .scaleEffect(1 + 0.09 * stir)
                // Nearly opaque, matching the moon's 0.95 core, and it has to
                // be. At 0.60 the sun read as a warm yellow disc in `sakura`,
                // `matcha` and `ember` and as a faint smudge in every cool or
                // pale theme — `snowdrift`'s sunshine is a warm sand and
                // `ink`'s is a warm grey, and either of those at 60 % over a
                // bright daytime sky is a stain rather than an object. A
                // night sky is dark, so the moon can be subtle and still
                // read; a day sky is nearly as light as the sun is, which is
                // the whole reason this number cannot simply be copied from
                // `drawMoon` and left there.
                Circle()
                    .fill(tint.opacity(0.92 * strength))
                    .frame(width: radius * 2, height: radius * 2)
            }
            .position(center)
        }
        // Less than the stars' full lean, so the sun trails them. See
        // `SkyStir.heavyLean`.
        .skyStirred(stir * SkyStir.heavyLean)
    }

    /// Dawn and dusk get the same sun, dimmer.
    ///
    /// Not lower: dropping it toward the horizon walks it into the countdown
    /// rows, and `SkyGeometry`'s slot is the one that has been checked. A
    /// low winter sun that is hard to read a timer through is a worse trade
    /// than a sun that stays put and fades.
    private var strength: Double {
        part == .day ? 1.0 : 0.62
    }
}

// MARK: - The lean

extension View {
    /// Lean this layer by `amount` (0 still, 1 fully stirred).
    ///
    /// A rotation about a pivot two and a half screens below the view, which
    /// at `SkyStir.leanDegrees` is a slide of seven or eight points at the top
    /// of the sky band and a little less lower down. See `SkyStir.leanDegrees`
    /// for why it is a rotation and not an offset.
    ///
    /// **Put this on the things in the sky, never on the sky wash.** The wash
    /// is a flat colour filling the screen; slide it eight points and the
    /// phase gradient shows in the gap along one edge. The stars, the moon,
    /// the meteors and the sun are all sparse layers over transparency, so
    /// there is no edge of theirs to expose — a star that slides off the side
    /// and back is just a star near the side.
    ///
    /// **And put it on the touch layer too, with the same value.**
    /// `NightSkyTouchView` hit-tests the moon and the stars out of
    /// `SkyGeometry` at the positions `StarfieldView` draws them. If only the
    /// drawing leans, the two disagree for the two and a half seconds it
    /// takes to settle, and a star tapped mid-stir misses — which is the
    /// precise failure `SkyGeometry`'s own doc comment says it exists to
    /// prevent ("a moon drawn at 0.86 of the width but hit-tested at 0.84 is
    /// a bug nobody can see — it just feels like the app ignoring you").
    /// Leaning both keeps them in lockstep by construction rather than by
    /// arithmetic.
    /// **The trailing `ignoresSafeArea` is load-bearing, and it is the whole
    /// reason this is a modifier rather than two lines at the call site.**
    /// A `rotationEffect` is a geometry transform, and a child's own
    /// `.ignoresSafeArea()` no longer reaches the screen edges from inside
    /// one — the layer silently re-lays-out into the safe area instead. Every
    /// star in `StarfieldView` is positioned as a *fraction of its canvas
    /// height*, so that shrink walked the entire night sky 38 points down the
    /// screen the instant a stir began and snapped it back when the stir
    /// ended. Measured, not guessed: the moon's centroid moved +114 device
    /// pixels vertically against the +8 points of horizontal lean it was
    /// supposed to make. Re-declaring it outside the rotation restores the
    /// full-bleed frame, and putting it *here* means the drawing layer and
    /// the touch layer cannot be given different treatment by accident.
    func skyStirred(_ amount: Double) -> some View {
        rotationEffect(
            .degrees(SkyStir.leanDegrees * amount),
            anchor: UnitPoint(x: 0.5, y: 2.4)
        )
        .ignoresSafeArea()
    }
}

#Preview("Noon, still") {
    ZStack {
        Theme.cream
        SunView(part: .day, tint: Theme.sunshine, stir: 0)
    }
    .ignoresSafeArea()
}

#Preview("Noon, stirred") {
    ZStack {
        Theme.cream
        SunView(part: .day, tint: Theme.sunshine, stir: 1)
    }
    .ignoresSafeArea()
}

#Preview("Dusk") {
    ZStack {
        Theme.cream
        SunView(part: .dusk, tint: Theme.sunshine, stir: 0)
    }
    .ignoresSafeArea()
}
