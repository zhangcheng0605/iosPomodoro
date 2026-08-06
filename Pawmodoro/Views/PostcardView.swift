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

    private var scale: CGFloat { width / 320 }

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
        ZStack(alignment: .bottom) {
            Image(card.resolvedPlace.assetName(for: card.resolvedDayPart))
                .interpolation(.none)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: 168 * scale)
                .clipped()

            // High enough that the buddy stands *under* the arch rather than
            // in front of it — the card is called "beneath a bell tower" and
            // at the first offset the cat was wearing one.
            BellTower(scale: scale)
                .offset(y: -46 * scale)

            BuddySprite(buddy: card.resolvedBuddy, sleeping: false, size: 44 * scale)
                .offset(y: -8 * scale)

            VStack {
                HStack {
                    Spacer()
                    stamp
                }
                Spacer()
            }
            .padding(8 * scale)
        }
        .frame(width: width, height: 168 * scale)
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
            .frame(width: width, height: 168 * scale)

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
        .frame(width: width, height: 168 * scale)
    }

    private var placePicture: some View {
        ZStack(alignment: .bottom) {
            Image(card.resolvedPlace.assetName(for: card.resolvedDayPart))
                .interpolation(.none)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: 168 * scale)
                .clipped()

            BuddySprite(buddy: card.resolvedBuddy, sleeping: false, size: 56 * scale)
                .offset(y: -10 * scale)

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
        .frame(width: width, height: 168 * scale)
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

    private var buddyName: String { card.resolvedBuddy.name }

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

    private var bodyWidth: CGFloat { 40 * scale }
    private var dialSize: CGFloat { 24 * scale }

    var body: some View {
        VStack(spacing: 0) {
            Roof()
                .fill(Theme.bark.opacity(0.9))
                .frame(width: bodyWidth + 10 * scale, height: 14 * scale)
            // Not named `body(height:)` — a method sharing a base name with
            // `View.body` is an invalid redeclaration, not an overload.
            shaft(height: 68 * scale)
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
