import SwiftUI

/// The letter, on paper.
///
/// A card the shape and colour of a note left on a table, with the week's
/// sentences on it and the buddy's name at the bottom. Nothing here is
/// interactive except sharing it, and nothing anywhere counts letters — if
/// there were a collection of these, a missed week would become a hole in it.
struct SundayPostView: View {
    @Environment(TimerEngine.self) private var engine

    private var letter: SundayPost.Letter? {
        SundayPost.compose(
            buddy: engine.buddyName,
            sessions: engine.log.records,
            events: engine.chronicle.events
        )
    }

    var body: some View {
        if let letter {
            VStack(alignment: .leading, spacing: 10) {
                Text("A letter came")
                    .font(.headline)
                    .foregroundStyle(Theme.bark)
                paper(letter)
            }
        }
    }

    private func paper(_ letter: SundayPost.Letter) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(letter.greeting)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.bark.opacity(0.5))

            ForEach(Array(letter.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.callout)
                    .foregroundStyle(Theme.bark.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(letter.signoff)
                .font(.callout.italic())
                .foregroundStyle(Theme.bark.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.surface)
                // A paper edge rather than a card shadow: this is meant to be
                // a thing on a table, not another panel in a settings screen.
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.bark.opacity(0.12), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(letter.greeting). "
                + letter.lines.joined(separator: " ")
                + " \(letter.signoff)"
        )
    }
}
