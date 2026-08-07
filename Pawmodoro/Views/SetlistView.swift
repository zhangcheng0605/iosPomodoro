import SwiftUI

/// The setlist: every track ever played by weekend request, with the date
/// it was granted. The one collection here that shows its denominator —
/// the music list is a catalog, and catalogs may count.
struct SetlistView: View {
    @Environment(TimerEngine.self) private var engine

    private static let shown = 6

    var body: some View {
        let stamps = Array(engine.setlist.stamps.prefix(Self.shown))

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "music.note.list")
                Text("The setlist")
                Spacer()
                if engine.setlist.count > 0 {
                    Text("\(engine.setlist.count) of \(MusicCatalog.tracks.count)")
                        .foregroundStyle(Theme.bark.opacity(0.6))
                        .monospacedDigit()
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.blossom)

            if stamps.isEmpty {
                Text("On weekends \(engine.buddyName) has a track in mind. "
                     + "Grant it and it's stamped here for good.")
                    .font(.caption)
                    .foregroundStyle(Theme.bark.opacity(0.65))
            } else {
                ForEach(stamps) { stamp in
                    HStack {
                        Image(systemName: "pawprint.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.blossom)
                        Text(stamp.track.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.bark.opacity(0.85))
                        Spacer()
                        Text("requested "
                             + stamp.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.caption2)
                            .foregroundStyle(Theme.bark.opacity(0.5))
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.75)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            stamps.isEmpty
                ? "The setlist, empty. Weekend requests are stamped here."
                : "The setlist: \(engine.setlist.count) tracks played by request."
        )
    }
}
