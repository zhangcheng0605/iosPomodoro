import SwiftUI

/// The old snail, where she has got to.
///
/// The cheapest view in the app, and deliberately: a static image at a position
/// that changes once a day. No timeline drives her *movement*, because her
/// movement is measured in months — the only animation is the eye stalks, at
/// two frames a second, and even that stops under Reduce Motion.
///
/// Positioned by her feet, like the stray, for the reason `Stray.groundLine`
/// records: a sprite anchored by its centre sits at a different height for
/// every size of art, and the bug scales with the artwork, which is the hardest
/// kind to see.
struct SnailView: View {
    let place: Place
    /// Her position across the screen, 0...1. Nil means she is elsewhere in
    /// the meadow this month and nothing is drawn at all.
    let x: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = Date()

    var body: some View {
        if let x {
            GeometryReader { geometry in
                sprite
                    .frame(width: Snail.size.width, height: Snail.size.height)
                    .position(
                        x: geometry.size.width * x,
                        // The sprite is placed by its centre, so half its
                        // height comes back off the ground line.
                        //
                        // The line itself is a row of the *artwork*, resolved
                        // through the same `scaledToFill` the scenery uses —
                        // see `Snail.groundRow`. A fraction of this view's own
                        // height would have been simpler and was wrong twice
                        // over: it lands on a different part of the picture on
                        // every shape of screen, and this view is not the
                        // screen anyway. On an iPhone SE the column overflows,
                        // the ZStack grows to about 735pt on a 667pt phone
                        // (solved back from her measured foot line, see
                        // `check_snail.py`'s KNOWN_BROKEN), and every layer in
                        // it — this one included — is handed that. The scenery
                        // is handed it too, which is exactly why asking the
                        // artwork is the answer: both sides use the same box,
                        // so she cannot come off the ground.
                        y: Snail.feetY(
                            in: geometry.size,
                            bottomAnchored: Platform.isDesktop
                        ) - Snail.size.height / 2
                    )
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            // Not hidden from VoiceOver, unlike the rest of the scenery. She
            // is the one thing out there that somebody might want to be told
            // about and could not otherwise find — she is eighteen points wide
            // and moves two points a day.
            .accessibilityElement()
            .accessibilityLabel("A snail, about "
                                + "\(Int((x - 0.04) / 0.92 * 100)) percent of "
                                + "the way across")
        }
    }

    @ViewBuilder
    private var sprite: some View {
        if reduceMotion {
            image(Snail.frames[0])
        } else {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let tick = Int(context.date.timeIntervalSince(appeared) / 0.5)
                image(Snail.frames[tick % Snail.frames.count])
            }
        }
    }

    private func image(_ name: String) -> some View {
        Image(name)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
    }
}
