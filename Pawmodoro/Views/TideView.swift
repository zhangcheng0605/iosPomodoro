import SwiftUI

/// The strip of shore that is only there some of the time.
///
/// Drawn rather than exported, exactly as the weather veils are, and for the
/// same reason: the scene pipeline is eight places × four times of day, and
/// making it × four tides as well would be thirty-two Harbor exports to keep
/// in step with each other. A waterline that moves is a band of colour in
/// front of the picture, and the picture does not have to know.
///
/// ### Where it is allowed to be
///
/// Between 0.79 and 0.88 of the screen's height — `Tide.waterline` — which is
/// the foreground water in the Harbor export, well below `QUIET_TOP` and
/// `QUIET_BOTTOM` in `tools/generate_scenes.py`. Nothing here may ever climb
/// into the rows behind the countdown; that is the one composition rule the
/// scene generator asserts on every export, and a SwiftUI overlay is the one
/// way to break it without the generator noticing.
///
/// ### Why it is deliberately small
///
/// A tide that visibly swallowed a third of the picture would make Harbor
/// Isle look like two different places rather than like one place at two
/// times. Nine points of screen is roughly what a real harbour wall shows
/// between springs and neaps, and it is enough that somebody who sits there
/// twice in an afternoon will notice the second time.
struct TideView: View {
    let level: Double
    let tint: Color
    /// The uncovered shore. `Theme.bark` at the call site, not a pale beach
    /// tone: what a harbour uncovers is wet mud and weed, and it has to darken
    /// the water rather than lighten it or the strip reads as a sandbar
    /// floating on the sea. There is no `Theme.sand` and adding one for this
    /// would be a raw colour with a nice name.
    let mud: Color

    /// Whether the water is coming in. Only changes which way the foam
    /// gathers, which is invisible in a screenshot and is the sort of thing
    /// somebody eventually notices at four in the afternoon.
    let rising: Bool

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let width = geometry.size.width
            let water = Tide.waterline.lowest
                + (Tide.waterline.highest - Tide.waterline.lowest) * level
            let lowest = Tide.waterline.lowest

            ZStack(alignment: .topLeading) {
                // The uncovered shore: everything between where the water is
                // now and the lowest it ever gets. At high water this is
                // nothing at all, and the whole layer costs one empty rect.
                if water < lowest {
                    mud
                        .frame(width: width,
                               height: (lowest - water) * height)
                        .offset(y: water * height)
                        .opacity(0.55)
                }
                foam(width: width, at: water * height)
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        // Announced rather than hidden, unlike the rest of the scenery.
        // The shore is the reason half a dozen animals are out, so somebody
        // who cannot see it still gets told the water is down — the same
        // argument that made the old snail speak.
        .accessibilityLabel(Tide.state(at: WorldCalendar.now).name)
    }

    /// The line where the water meets the sand.
    ///
    /// A rectangle rather than a wave: at nine points of travel a sine curve
    /// is one pixel of wobble and costs a `Canvas` and a `TimelineView` for
    /// it. Nothing here animates, which is why there is no Reduce Motion
    /// branch — the whole layer is two static rectangles that change position
    /// every five minutes, and there was never any motion to reduce.
    private func foam(width: CGFloat, at y: CGFloat) -> some View {
        VStack(spacing: 0) {
            tint.opacity(0.30).frame(height: 1.5)
            tint.opacity(0.12).frame(height: rising ? 3 : 1.5)
        }
        .frame(width: width)
        .offset(y: y - 1.5)
    }
}
