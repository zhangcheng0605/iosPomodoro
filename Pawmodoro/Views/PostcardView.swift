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
        if card.occasion == .panorama { panorama } else { placePicture }
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
        }
    }

    private var message: String {
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
