import SwiftUI

/// A postcard, drawn from its facts.
///
/// This is the first artefact of the app anyone would voluntarily post, so it
/// carries the whole style: the place as it looked at that hour, the buddy
/// standing in it, a paw-print stamp, and a line in the buddy's voice. The
/// same view renders the thumbnail in the album and the full-size image the
/// share sheet exports.
struct PostcardView: View {
    let card: Postcard
    /// The album shows these small; export renders one large.
    var width: CGFloat = 320
    /// What to sign the card with, passed in rather than looked up.
    ///
    /// Buddies can be renamed, and the rule is that a rename reaches every
    /// caption — this one especially, since a postcard is the one artefact of
    /// this app that leaves the phone. It cannot read the environment to find
    /// out: the share sheet hands this view to `ImageRenderer`, which lays its
    /// content out in a *fresh* environment where no settings were ever
    /// installed. That is the same trap that took the whole process down on
    /// the buddy's papers card. So the name arrives as a plain value, and
    /// falls back to the factory name only when nobody supplied one.
    var name: String?

    private var scale: CGFloat { width / 320 }
    private var pictureHeight: CGFloat { 168 * scale }

    var body: some View {
        VStack(spacing: 0) {
            picture
            caption
        }
        .frame(width: width)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10 * scale, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10 * scale, style: .continuous)
                .strokeBorder(Theme.bark.opacity(0.14), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var picture: some View {
        switch card.occasion {
        case .panorama: panorama
        case .belltower: bellTowerPicture
        case .arrival, .cycle: placePicture
        }
    }

    /// The bell-of-hours card: the buddy standing under a tower, with the dial
    /// full.
    ///
    /// The tower is **drawn**, not a sprite, for the same reason the ring
    /// clock face is drawn — it is four shapes and a ring of marks, and a
    /// pixel-art bell tower would have to be redrawn for eight places and four
    /// times of day to sit in front of any of them. Drawn, it is a silhouette,
    /// which is what a tower is at that distance anyway.
    private var bellTowerPicture: some View {
        let name = card.resolvedPlace.assetName(for: card.resolvedDayPart)
        let feet: CGFloat = 8 * scale
        let stand = standing(name, feet: feet)
        let tower = towerStanding(name, feet: feet)
        return ZStack(alignment: .bottom) {
            sceneImage(name, feet: feet)

            BellTower(scale: scale)
                .offset(x: tower.width, y: tower.height)

            BuddySprite(buddy: card.resolvedBuddy, sleeping: false, size: 44 * scale)
                .offset(x: stand.width, y: stand.height)

            VStack {
                HStack {
                    Spacer()
                    stamp
                }
                Spacer()
            }
            .padding(8 * scale)
        }
        .frame(width: width, height: pictureHeight)
    }

    /// The hundred-hour card: the whole wood, wide, with the buddy standing in
    /// front of it.
    ///
    /// Drawn from `card.minutes` rather than from today's total, which is what
    /// makes it a *memory* — open it in a year and it still shows the hundred
    /// trees that stood there, not the hundred and twenty there are now.
    /// `HomesteadScene` is the same view the stats card uses, so the two can
    /// never disagree about what the wood looks like.
    private var panorama: some View {
        let minutes = card.minutes ?? Grove.panoramaHours * Grove.minutesPerTree
        return ZStack(alignment: .bottom) {
            HomesteadScene(
                trees: Grove.trees(forMinutes: minutes),
                // Everybody who has sat a hundred hours has every neighbour —
                // the last arrives at 200 sessions and a hundred hours is at
                // least 240. Passed as the full set rather than derived from a
                // session count the card does not store.
                residents: Resident.allCases,
                den: nil,
                dayPart: card.resolvedDayPart,
                buddy: card.resolvedBuddy,
                animated: false
            )
            .frame(width: width, height: pictureHeight)

            BuddySprite(buddy: card.resolvedBuddy, sleeping: false, size: 48 * scale)
                .offset(y: -6 * scale)

            VStack {
                HStack {
                    Spacer()
                    stamp
                }
                Spacer()
            }
            .padding(8 * scale)
        }
        .frame(width: width, height: pictureHeight)
    }

    private var placePicture: some View {
        let name = card.resolvedPlace.assetName(for: card.resolvedDayPart)
        let feet: CGFloat = 10 * scale
        let stand = standing(name, feet: feet)
        return ZStack(alignment: .bottom) {
            sceneImage(name, feet: feet)

            BuddySprite(buddy: card.resolvedBuddy, sleeping: false, size: 56 * scale)
                .offset(x: stand.width, y: stand.height)

            // The stamp, top-right, like a real one.
            VStack {
                HStack {
                    Spacer()
                    stamp
                }
                Spacer()
            }
            .padding(8 * scale)
        }
        .frame(width: width, height: pictureHeight)
    }

    // MARK: The place, cropped to the part of it worth posting

    /// The scene art, cropped so the card shows the *place* rather than the
    /// sky above it.
    ///
    /// A scene is painted phone-shaped — 396×858 — and a card's picture is
    /// 320×168, so most of the painting has to go. `scaledToFill` throws away
    /// the top and the bottom equally, and the middle band of every scene in
    /// this app is sky: all eight places came out as the same wash of blue
    /// with a ridge in it and the buddy hanging above nothing. At the album's
    /// two-hundred-card cap that is two hundred cards nobody can tell apart,
    /// which is how this was reported — a count with a wall of blanks under
    /// it. The count was right; the pictures were the bug.
    ///
    /// So the crop is anchored rather than centred, on the one line the app
    /// already agrees about: `Stray.groundLine`, the fraction of the artwork
    /// a creature standing in it has its feet on. Put that line under the
    /// buddy's feet and the window fills with the horizon, the ground, and
    /// whatever the place has built on it — the cottage, the pines, the
    /// harbour's island, Cloudspire hanging in the air.
    ///
    /// `feet` is how far the buddy's soles sit above the bottom edge, which
    /// differs per card because the bell tower stands the buddy slightly
    /// higher. Everything else about the crop is the same for all of them.
    private func sceneImage(_ name: String, feet: CGFloat) -> some View {
        let full = width * Self.sceneAspect(name)
        let top = cropTop(name, feet: feet)
        return Image(name)
            .interpolation(.none)      // keep the pixel edges crisp
            .resizable()
            .scaledToFill()
            .frame(width: width, height: full)
            .offset(y: -top)
            .frame(width: width, height: pictureHeight, alignment: .top)
            .clipped()
    }

    /// Where the visible window starts, down the full-height painting.
    ///
    /// Clamped, so art that is ever exported closer to square cannot slide the
    /// window off either end. The window is anchored on `Stray.groundLine` for
    /// every place, including the two whose buddy stands somewhere else: the
    /// crop is what makes the *place* recognisable, and moving it to follow a
    /// jetty would trade a floating cat for a card that no longer shows the
    /// harbour.
    private func cropTop(_ name: String, feet: CGFloat) -> CGFloat {
        let full = width * Self.sceneAspect(name)
        return min(
            max(0, CGFloat(Stray.groundLine) * full - pictureHeight + feet),
            max(0, full - pictureHeight)
        )
    }

    /// Where the buddy stands, as an offset from the bottom centre of the
    /// picture — which is where a `ZStack(alignment: .bottom)` would put it.
    ///
    /// `Place.footing` says which point of the artwork has a surface on it;
    /// this converts that into the card's own coordinates, through the same
    /// crop the picture behind it uses. For the six places whose footing is the
    /// middle at `Stray.groundLine` the answer comes back as `(0, -feet)`,
    /// which is exactly the offset those cards were drawn with before any of
    /// this existed — the two that moved are the only two that moved.
    private func standing(_ name: String, feet: CGFloat) -> CGSize {
        let footing = card.resolvedPlace.footing
        let full = width * Self.sceneAspect(name)
        // The soles, in points down from the top of the visible window.
        let soles = CGFloat(footing.y) * full - cropTop(name, feet: feet)
        return CGSize(
            width: CGFloat(footing.x - 0.5) * width,
            height: soles - pictureHeight
        )
    }

    /// How far the tower's base floats above the buddy's soles.
    ///
    /// High enough that the buddy stands *under* the arch rather than in front
    /// of it — the card is called "beneath a bell tower" and at the first
    /// offset the cat was wearing one. The tower does not reach the ground on
    /// purpose: it is a distant thing and its foot is behind the horizon.
    private static let towerLift: CGFloat = 38

    /// Where the tower stands, as an offset from the bottom centre — the same
    /// coordinates `standing` returns, and derived from it.
    ///
    /// It follows the buddy across the card rather than staying centred. The
    /// tower is a silhouette this view invents rather than art anybody painted,
    /// so it can be built wherever there is ground, and a tower planted in the
    /// Harbor's open water with the cat over on the jetty would have been two
    /// bugs instead of one.
    ///
    /// The clamp is the part that is not decorative. Cloudspire's footing is
    /// the grassy cap, which is most of the way *up* the card, and a tower hung
    /// `towerLift` above those soles puts its roof twenty-seven points above
    /// the picture — where the card's corner radius eats it. A roofless tower
    /// is not a tower. So the base rises to meet the buddy instead, which costs
    /// nothing: the arch lands on the buddy's head either way, which is the
    /// whole point of the offset. Only Cloudspire is ever clamped; every other
    /// card comes out at exactly `-towerLift` from the soles, as before.
    private func towerStanding(_ name: String, feet: CGFloat) -> CGSize {
        let stand = standing(name, feet: feet)
        // The lowest the offset may go before the roof leaves the picture.
        let ceiling = BellTower.height * scale - pictureHeight
        return CGSize(
            width: stand.width,
            height: max(stand.height - Self.towerLift * scale, ceiling)
        )
    }

    /// How tall the scene art is for its width — measured, not written down.
    ///
    /// The scenes are generated by `tools/generate_scenes.py`; re-exporting
    /// them at another size with the number hard-coded here would slide every
    /// postcard quietly off the ground, and nothing in the toolchain looks at
    /// this. The fallback is the shape that generator exports today.
    private static func sceneAspect(_ name: String) -> CGFloat {
        guard let art = PlatformImage.asset(name), art.size.width > 0 else {
            return 858.0 / 396.0
        }
        return art.size.height / art.size.width
    }

    private var stamp: some View {
        VStack(spacing: 1 * scale) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 15 * scale))
                .foregroundStyle(Theme.blossom)
            Text(card.date.formatted(.dateTime.day().month(.abbreviated)))
                .font(.system(size: 7 * scale, weight: .semibold))
                .foregroundStyle(Theme.bark.opacity(0.75))
        }
        .frame(width: 38 * scale, height: 42 * scale)
        .background(Theme.cream.opacity(0.92))
        .overlay(
            Rectangle().strokeBorder(
                style: StrokeStyle(lineWidth: 1.5 * scale, dash: [2.5 * scale, 2 * scale])
            )
            .foregroundStyle(Theme.bark.opacity(0.35))
        )
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 3 * scale) {
            Text(headline)
                .font(.system(size: 14 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.bark)
            Text(message)
                .font(.system(size: 10.5 * scale, design: .rounded))
                .foregroundStyle(Theme.bark.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12 * scale)
        .padding(.vertical, 10 * scale)
    }

    // MARK: Words

    private var buddyName: String { name ?? card.resolvedBuddy.name }

    private var headline: String {
        switch card.occasion {
        case .arrival: "Made it to \(card.resolvedPlace.name)"
        case .cycle: "A good run at \(card.resolvedPlace.name)"
        // Not "100 hours" and not a total of anything. The card is a picture
        // of a wood; the headline says what the wood is, and the number is
        // left to the line underneath where it reads as a fact rather than as
        // a score.
        case .panorama: "The whole wood"
        // Not "24 of 24", not "complete", not "unlocked". What happened is
        // that the clock went all the way round while somebody was sitting
        // under it, on and off, for months.
        case .belltower: "All the way round"
        }
    }

    private var message: String {
        if card.occasion == .belltower {
            return "Every hour on the dial, at least once — \(buddyName)"
        }
        if card.occasion == .panorama {
            let trees = Grove.trees(
                forMinutes: card.minutes ?? Grove.panoramaHours * Grove.minutesPerTree
            ).count
            return "\(trees) trees, one for each hour — \(buddyName)"
        }
        var parts: [String] = []
        parts.append(card.sessions == 1 ? "1 session today" : "\(card.sessions) sessions today")
        if let seen = card.resolvedSighting {
            parts.append("we saw a \(seen.name.lowercased())")
        }
        return parts.joined(separator: " · ") + " — \(buddyName)"
    }

    private var accessibilityLabel: String {
        "\(headline). \(message). \(card.date.formatted(.dateTime.day().month(.wide).year()))."
    }
}

/// A bell tower in silhouette, with its dial full.
///
/// Four shapes: a roof, a body, a dial with twenty-four marks round it, and an
/// arch where the bell hangs. Every colour goes through `Theme`, so the tower
/// changes with the theme like everything else on the card.
private struct BellTower: View {
    let scale: CGFloat

    /// The silhouette's own measurements, at scale 1, named once.
    ///
    /// `PostcardView` has to know how tall this is to keep it inside the
    /// picture, and `tools/check_postcard.py` has to read the same numbers to
    /// prove that it does. A second copy of "82" in either of them would be a
    /// checker restating what it checks, which this repo has been burned by
    /// three times.
    static let roofHeight: CGFloat = 14
    static let shaftHeight: CGFloat = 68
    static let width: CGFloat = 50
    static var height: CGFloat { roofHeight + shaftHeight }

    private var bodyWidth: CGFloat { 40 * scale }
    private var dialSize: CGFloat { 24 * scale }

    var body: some View {
        VStack(spacing: 0) {
            Roof()
                .fill(Theme.bark.opacity(0.9))
                .frame(width: Self.width * scale, height: Self.roofHeight * scale)
            // Not named `body(height:)` — a method sharing a base name with
            // `View.body` is an invalid redeclaration, not an overload.
            shaft(height: Self.shaftHeight * scale)
        }
    }

    private func shaft(height: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(Theme.surface.opacity(0.94))
                .overlay(
                    Rectangle().strokeBorder(Theme.bark.opacity(0.55), lineWidth: 1.5 * scale)
                )
            VStack(spacing: 5 * scale) {
                dial
                arch
            }
            .padding(.vertical, 7 * scale)
        }
        .frame(width: bodyWidth, height: height)
    }

    /// Twenty-four marks, all of them lit. The card only exists once they all
    /// are, so there is no unlit state to draw and no number to write in the
    /// middle of it.
    private var dial: some View {
        ZStack {
            Circle()
                .strokeBorder(Theme.bark.opacity(0.45), lineWidth: 1 * scale)
            ForEach(0..<24, id: \.self) { hour in
                Circle()
                    .fill(Theme.sunshine)
                    .frame(width: 1.8 * scale, height: 1.8 * scale)
                    .offset(mark(hour))
            }
        }
        .frame(width: dialSize, height: dialSize)
    }

    private func mark(_ hour: Int) -> CGSize {
        let angle = Double(hour) / 24.0 * 2 * .pi - .pi / 2
        let radius = Double(dialSize / 2 - 3 * scale)
        return CGSize(width: radius * cos(angle), height: radius * sin(angle))
    }

    /// The opening the bell hangs in, and the bell.
    private var arch: some View {
        ZStack {
            Capsule()
                .fill(Theme.bark.opacity(0.75))
                .frame(width: 16 * scale, height: 22 * scale)
            Circle()
                .fill(Theme.sunshine.opacity(0.9))
                .frame(width: 8 * scale, height: 8 * scale)
                .offset(y: 2 * scale)
        }
    }
}

/// A tapered cap. The one thing on the card that needs a path rather than a
/// built-in shape.
private struct Roof: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
