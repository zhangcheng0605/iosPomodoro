import CoreGraphics
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
/// 3. **Normalise the orientation.** The image is drawn through its **own**
///    draw method, never via its raw `cgImage`. That distinction shipped a
///    bug: `cgImage` is the sensor's pixels with the EXIF rotation *not*
///    applied, and `CGContext.draw` inside `UIGraphicsImageRenderer` uses
///    Core Graphics' y-up coordinates under UIKit's y-down flip — every
///    photograph came out upside-down, and camera portraits sideways too.
///    `UIImage.draw(in:)` bakes the rotation in and respects the renderer's
///    coordinate space, so what is written is exactly what was seen.
enum SnapshotImport {

    /// JPEG data ready to write, or nil if it was not an image at all.
    static func prepare(_ data: Data, longEdge: CGFloat = Scrapbook.longEdge)
        -> Data? {
        guard let image = PlatformImage(data: data) else { return nil }
        return prepare(image, longEdge: longEdge)
    }

    /// The same, from an image already in hand — the camera hands over a
    /// `UIImage`, not bytes, and round-tripping it through JPEG just to decode
    /// it again would cost a generation of compression for nothing.
    static func prepare(_ image: PlatformImage,
                        longEdge: CGFloat = Scrapbook.longEdge) -> Data? {
        // `UIImage.size` is the *oriented* size — a portrait photo reports
        // tall, whatever way the sensor stored it — which is exactly the shape
        // the upright rendering below needs.
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(1, longEdge / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(),
                            height: (size.height * scale).rounded())

        return renderJPEG(size: target) { context in
            #if canImport(UIKit)
            // Inside `UIGraphicsImageRenderer`'s closure this draws into the
            // current UIKit context: orientation applied, y-down, upright.
            image.draw(in: CGRect(origin: .zero, size: target))
            #else
            // Never compiled today (the app is iOS-only) but kept honest:
            // NSImage.draw needs a current NSGraphicsContext, and renderJPEG's
            // AppKit branch pre-flips the CTM to y-down.
            let graphics = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphics
            image.draw(in: CGRect(origin: .zero, size: target),
                       from: .zero, operation: .copy, fraction: 1,
                       respectFlipped: true, hints: nil)
            NSGraphicsContext.restoreGraphicsState()
            #endif
        }
    }
}
