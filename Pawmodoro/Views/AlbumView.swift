import SwiftUI

/// The postcards, newest first, with a share sheet on each.
///
/// Sharing is the point: this is the first artefact of the app anyone would
/// voluntarily post, and every one of them carries the art style out with it.
struct AlbumView: View {
    @Environment(TimerEngine.self) private var engine

    private var album: Album { engine.album }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Postcards")
                    .font(.headline)
                    .foregroundStyle(Theme.bark)
                Spacer()
                Text("\(album.cards.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.bark.opacity(0.6))
            }

            if album.cards.isEmpty {
                Text("Your buddy sends one when you arrive somewhere new, and when a cycle lands.")
                    .font(.footnote)
                    .foregroundStyle(Theme.bark.opacity(0.6))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(album.newestFirst) { card in
                            PostcardView(card: card, width: 210)
                                .contextMenu {
                                    // The card itself, not an image of it: see
                                    // `PostcardExport`. Passing `Image`s here
                                    // rasterised every postcard in the album,
                                    // twice, at export size, just to draw the
                                    // row — arguments are evaluated when the
                                    // row is built, tap or no tap.
                                    ShareLink(
                                        item: card,
                                        preview: SharePreview(card.shareTitle)
                                    ) {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
