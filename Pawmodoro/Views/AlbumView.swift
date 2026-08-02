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
                                    ShareLink(
                                        item: render(card),
                                        preview: SharePreview("Postcard", image: render(card))
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

    /// Rendered at export size on demand — nothing is stored as an image.
    @MainActor
    private func render(_ card: Postcard) -> Image {
        let renderer = ImageRenderer(content: PostcardView(card: card, width: 640))
        renderer.scale = 2
        if let ui = renderer.uiImage {
            return Image(uiImage: ui)
        }
        return Image(systemName: "photo")
    }
}
