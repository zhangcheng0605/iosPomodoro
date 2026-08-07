import SwiftUI

/// What the current buddy has tried from the sill, and what it made of it.
///
/// Reactions are pure data, so the card stores nothing of its own — a snack
/// once given is a fact, and the fact already says how it went. The unseen
/// half shows as dimmed squares, the same convention the journal uses:
/// the point is that there is more animal left to learn.
struct TastesCard: View {
    @Environment(TimerEngine.self) private var engine

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 10)]

    var body: some View {
        let buddy = engine.settings.buddy
        let name = engine.buddyName
        let tried = engine.pantry.triedCount(for: buddy)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "fork.knife")
                Text("\(name)'s tastes")
                Spacer()
                Text("\(tried) of \(Snack.allCases.count)")
                    .foregroundStyle(Theme.bark.opacity(0.6))
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.blossom)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Snack.allCases) { snack in
                    cell(for: snack, buddy: buddy)
                }
            }

            Text(footline(for: buddy, name: name, tried: tried))
                .font(.caption)
                .foregroundStyle(Theme.bark.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.75)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(name)'s tastes: \(tried) of \(Snack.allCases.count) snacks tried. "
                + footline(for: buddy, name: name, tried: tried)
        )
    }

    @ViewBuilder
    private func cell(for snack: Snack, buddy: Buddy) -> some View {
        let known = engine.pantry.hasTried(buddy, snack)
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.cream.opacity(known ? 0.9 : 0.35))
                .frame(width: 44, height: 44)
            if known {
                Image(snack.assetName)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .frame(width: 44, height: 44)
            } else {
                Image(systemName: "questionmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.bark.opacity(0.25))
                    .frame(width: 44, height: 44)
            }
            // The favorite gets its heart once it has actually been given —
            // the card records discoveries, it never spoils them.
            if known, snack == buddy.favoriteSnack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.blossom)
                    .offset(x: 3, y: -3)
            }
        }
    }

    /// One dry line summing up what's known so far.
    private func footline(for buddy: Buddy, name: String, tried: Int) -> String {
        let lovesKnown = engine.pantry.hasTried(buddy, buddy.favoriteSnack)
        let snubKnown = engine.pantry.hasTried(buddy, buddy.snubbedSnack)
        if lovesKnown && snubKnown {
            return "Loves \(buddy.favoriteSnack.plural). "
                + "\(buddy.snubbedSnack.plural.capitalized): not \(name)'s thing."
        }
        if lovesKnown {
            return "Loves \(buddy.favoriteSnack.plural). The rest is still research."
        }
        if snubKnown {
            return "\(buddy.snubbedSnack.plural.capitalized): not \(name)'s thing. "
                + "The favorite is still out there."
        }
        if tried > 0 {
            return "No strong opinions yet — keep offering."
        }
        return "Finish a session and something small lands on the sill."
    }
}
