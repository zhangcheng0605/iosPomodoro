import SwiftUI

/// What you've seen, and what you haven't.
///
/// The unseen half is the point. A silhouette with "At dawn, in Whispering
/// Woods" under it is a reason to focus at a different hour, in a different
/// place — which is the whole retention argument for the journal, and it only
/// works if the locked entries are shown rather than hidden. Same house rule
/// as the padlocks, for a different reason.
struct JournalView: View {
    @Environment(TimerEngine.self) private var engine

    private var journal: Journal { engine.journal }

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Field journal")
                    .font(.headline)
                    .foregroundStyle(Theme.bark)
                Spacer()
                Text("\(journal.seenCount) of \(journal.total)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.bark.opacity(0.6))
                    .monospacedDigit()
            }

            Text("Hold still and things come out. Finish the session to keep the sighting.")
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.6))

            ForEach(Journal.pages) { page in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(page.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.bark.opacity(0.8))
                        Spacer()
                        Text("\(seen(in: page)) / \(page.species.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.bark.opacity(0.5))
                    }
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(page.species) { species in
                            tile(for: species)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func seen(in page: Journal.Page) -> Int {
        page.species.filter(journal.hasSeen).count
    }

    private func tile(for species: Species) -> some View {
        let record = journal.record(for: species)
        let seen = record != nil

        return VStack(spacing: 5) {
            Image(seen ? species.sketchAsset : species.ghostAsset)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(height: 42)
                .opacity(seen ? 1 : 0.28)

            Text(seen ? species.name : "?")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.bark.opacity(seen ? 0.9 : 0.5))
                .lineLimit(1)

            Text(caption(for: species, record: record))
                .font(.system(size: 9))
                .foregroundStyle(Theme.bark.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 22, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surface.opacity(seen ? 0.9 : 0.45))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: species, record: record))
    }

    private func caption(for species: Species, record: SightingRecord?) -> String {
        guard let record else { return species.hint }
        let date = record.firstSeen.formatted(.dateTime.day().month(.abbreviated))
        return record.count > 1 ? "\(date) · seen \(record.count)×" : date
    }

    private func accessibilityLabel(for species: Species, record: SightingRecord?) -> String {
        guard let record else {
            return "Not yet seen. Hint: \(species.hint)."
        }
        let date = record.firstSeen.formatted(.dateTime.day().month(.wide))
        return "\(species.name), \(species.rarity.label). "
            + "First seen \(date), seen \(record.count) time\(record.count == 1 ? "" : "s"). "
            + species.note
    }
}
