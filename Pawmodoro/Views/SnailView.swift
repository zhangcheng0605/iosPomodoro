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
    /// Not for anything she draws — she has no text. It is how deep the app's
    /// furniture is below her, which is the only thing standing between her
    /// and the ambience row. See `Snail.chromeDepth(at:)`.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var appeared = Date()

    var body: some View {
        if let x {
            GeometryReader { geometry in
                // Two questions of the same box, and they have to be asked in
                // this order. *Is there room* comes first — see
                // `Snail.requiredFooting(at:)`: the ground line she stands on
                // is a row of the artwork, the app's furniture is stacked up
                // from the bottom of this layer, and where the screen is short
                // or the text is large the two overlap. Then *where*, which is
                // the artwork's answer and nothing to do with the app.
                //
                // The text size belongs in the first question and not the
                // second. Her feet do not move when the reader turns the text
                // up; the chips under them grow by up to 37 points, which is
                // most of the room she had.
                if Snail.hasFooting(in: geometry.size,
                                    bottomAnchored: Platform.isDesktop,
                                    textSize: dynamicTypeSize) {
                    sprite
                        .frame(width: Snail.size.width, height: Snail.size.height)
                        .position(
                            x: geometry.size.width * x,
                            // The sprite is placed by its centre, so half its
                            // height comes back off the ground line.
                            //
                            // The line itself is a row of the *artwork*,
                            // resolved through the same `scaledToFill` the
                            // scenery uses — see `Snail.groundRow`. A fraction
                            // of this view's own height would have been simpler
                            // and was wrong twice over: it lands on a different
                            // part of the picture on every shape of screen, and
                            // this view is not the screen anyway — it is
                            // whatever box the `ZStack` came out at, which used
                            // to be 793pt on a 667pt iPhone SE while
                            // `ordinaryColumn` still overflowed. The scenery is
                            // handed the same box, which is exactly why asking
                            // the artwork is the answer: both sides use it, so
                            // she cannot come off the ground whatever it is.
                            y: Snail.feetY(
                                in: geometry.size,
                                bottomAnchored: Platform.isDesktop
                            ) - Snail.size.height / 2
                        )
                        // Not hidden from VoiceOver, unlike the rest of the
                        // scenery. She is the one thing out there that somebody
                        // might want to be told about and could not otherwise
                        // find — she is eighteen points wide and moves two
                        // points a day. On the sprite rather than on the
                        // `GeometryReader`, so that a screen with no room for
                        // her does not announce a snail nobody can see.
                        .accessibilityElement()
                        .accessibilityLabel("A snail, about "
                                            + "\(Int((x - 0.04) / 0.92 * 100)) "
                                            + "percent of the way across")
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
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
