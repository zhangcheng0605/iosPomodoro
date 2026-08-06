import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// A postcard, exportable — and rendered only once somebody actually exports it.
///
/// The album used to hand `ShareLink` two `Image`s per card, both produced by
/// `ImageRenderer` at 640pt with `scale = 2`, and both of them ordinary
/// function arguments inside a `ForEach`. Arguments are evaluated when the row
/// is built, so opening the stats sheet on a full album rasterised every
/// postcard twice at export size, on the main thread, before anyone had tapped
/// anything. At the album's 200-card limit that is 400 renders to look at a
/// scroll view.
///
/// `Transferable` moves the work behind the tap: `ShareLink` now takes the
/// `Postcard` itself — a few dozen bytes of facts — and the PNG is drawn once,
/// on demand, by whatever asked for it. The preview is a line of text built
/// from those same facts, because every `SharePreview` that carries an image
/// wants that image up front, which is the thing being fixed.
///
/// `ImageRenderer` stays on the main actor. That is not a detail to tidy away:
/// it is `@MainActor`-isolated, and the render walks a SwiftUI view tree.
extension Postcard: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            try await card.exportedPNG()
        }
        .suggestedFileName("Pawmodoro postcard.png")
    }

    /// One render, on the main actor, after a tap.
    @MainActor
    func exportedPNG() throws -> Data {
        let renderer = ImageRenderer(content: PostcardView(card: self, width: 640))
        renderer.scale = 2
        guard let data = renderer.uiImage?.pngData() else {
            throw ExportFailure.couldNotRender
        }
        return data
    }

    enum ExportFailure: Error {
        case couldNotRender
    }

    /// What the share sheet is told it is about, from the stored facts alone —
    /// no drawing, which is the whole point of not passing it an image.
    var shareTitle: String {
        let day = date.formatted(.dateTime.day().month(.abbreviated))
        return "\(resolvedPlace.name), \(day)"
    }
}
