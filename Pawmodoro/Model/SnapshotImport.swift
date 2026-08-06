import CoreGraphics
import Foundation
import SwiftUI

/// Turning somebody's photograph into something this app will keep.
///
/// Three jobs, in one place so none of them can be skipped by a second call
/// site later:
///
/// 1. **Strip the location.** Always, not as a setting. A scrapbook of the
///    desks somebody works at is a map of where they live, and the app has no
///    business holding that. Re-encoding through `UIImage` drops every EXIF
///    tag on the floor, which is the simplest possible guarantee — there is no
///    list of tags to keep in step with.
/// 2. **Bound the size.** A modern phone photograph is several megabytes and
///    twelve megapixels; two hundred of those is a gigabyte of somebody's
///    device spent on a Pomodoro timer.
/// 3. **Normalise the orientation.** `UIImage` drawing bakes the EXIF rotation
///    in, so what is written is what is seen — otherwise every portrait
///    photograph from a camera comes back sideways.
enum SnapshotImport {

    /// JPEG data ready to write, or nil if it was not an image at all.
    static func prepare(_ data: Data, longEdge: CGFloat = Scrapbook.longEdge)
        -> Data? {
        guard let image = PlatformImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(1, longEdge / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(),
                            height: (size.height * scale).rounded())

        guard let source = cgImage(of: image) else { return nil }
        return renderJPEG(size: target) { context in
            context.draw(source, in: CGRect(origin: .zero, size: target))
        }
    }

    /// The bitmap inside a platform image. `UIImage` hands one over directly;
    /// `NSImage` is a container of representations and has to be asked.
    private static func cgImage(of image: PlatformImage) -> CGImage? {
        #if canImport(UIKit)
        return image.cgImage
        #else
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #endif
    }
}
