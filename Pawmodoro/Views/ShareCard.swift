import SwiftUI

/// The share pass: any kept card, rendered once and handed to the system
/// share sheet.
///
/// Wordle's real invention was the artifact — a clean image worth putting
/// somewhere. The app never posts and never phones home; `ShareLink` opens
/// the user's own sheet and that is the whole of it. Cards export exactly
/// as they display, with one quiet provenance line and never a number that
/// could read as a score.
@MainActor
enum CardExporter {

    /// A card view, rendered at 3x on the app's cream ground.
    ///
    /// **The content must not read `@Environment` objects.** `ImageRenderer`
    /// lays out what it is given in a fresh environment, so an
    /// `@Environment(TimerEngine.self)` inside a card is a trap in the
    /// environment getter and takes the process with it — not a blank image,
    /// a crash. `PapersCard` did exactly this and killed the app on every
    /// tap of "Share the papers". Pass values in as plain properties.
    static func image<Content: View>(
        of content: Content, width: CGFloat = 360
    ) -> PlatformImage? {
        let framed = content
            .frame(width: width)
            .padding(20)
            .background(Theme.cream)
        let renderer = ImageRenderer(content: framed)
        renderer.scale = 3
        // `uiImage` on iOS, `nsImage` on the Mac target — the one place
        // this file has to know there are two platforms, and the reason it
        // uses `PlatformImage` everywhere else instead of naming UIKit.
        #if canImport(UIKit)
        return renderer.uiImage
        #else
        return renderer.nsImage
        #endif
    }
}

/// A sheet that shows one card large, renders it once, and offers the
/// share link when the render is ready. Rendering happens here, lazily —
/// never in a grid's body.
struct ShareableCardSheet<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    @Environment(\.dismiss) private var dismiss
    @State private var rendered: PlatformImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    content()
                        .padding(.top, 8)

                    if let rendered {
                        ShareLink(
                            item: Image(uiImage: rendered),
                            preview: SharePreview(title, image: Image(uiImage: rendered))
                        ) {
                            Label("Share as image", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.onAccent)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Theme.blossom))
                        }
                    }

                    // The Wrapped signature, minus any bait: where and when,
                    // and nothing that counts anything.
                    Text("Pawmodoro — kept, not scored.")
                        .font(.caption2)
                        .foregroundStyle(Theme.bark.opacity(0.4))
                }
                .padding()
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                rendered = CardExporter.image(of: content())
            }
        }
    }
}
