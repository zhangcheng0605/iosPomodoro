import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The whole of what this app needs from a platform.
///
/// Pawmodoro is pure SwiftUI apart from a short, listable set of UIKit
/// touchpoints, and this file is that list. Everything below is either an
/// alias, a two-line helper, or a deliberate no-op — there is no macOS
/// *variant* of anything, because a second implementation of a feature is a
/// second thing to keep in step and this app has enough of those.
///
/// ### What macOS does not get, on purpose
///
/// - **Haptics.** There is no Taptic Engine in a MacBook trackpad the way
///   there is in a phone, and `NSHapticFeedbackManager` fires on the trackpad
///   only when the pointer is over it. A buzz you feel only sometimes is worse
///   than none, so `HapticsDirector` is a no-op there.
/// - **The shake.** No accelerometer. The snow globe gets a menu item instead
///   — see `docs/HEARTH_PLAN.md`.
/// - **Live Activities.** iOS only, by construction.
///
/// ### What survives untouched, and why that is not luck
///
/// The countdown derives from an absolute end `Date`, so **App Nap cannot
/// break it** — the same property that survives iOS suspending a backgrounded
/// app. `WorldCalendar`, the themes, the scenes, the whole model layer are
/// platform-blind already. That is a law written for a different reason
/// paying off twice.
enum Platform {

    /// True on the desk, false in a pocket. Used for the handful of places a
    /// layout genuinely differs rather than for feature gating — anything
    /// gated is `#if` so it compiles out.
    static var isDesktop: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    /// The window Pawmodoro opens at on a Mac.
    ///
    /// Phone-proportioned on purpose. Every scene in this app is exported at a
    /// phone's aspect and the buddy, the stray and the snail are all placed by
    /// fractions of the screen; a wide window would letterbox the art or
    /// stretch the ground line out from under the cat. `check_stray.py` and
    /// `check_snail.py` both carry this aspect as a fixture row for exactly
    /// that reason.
    static let macWindow = CGSize(width: 400, height: 740)
}

#if canImport(UIKit)
typealias PlatformImage = UIImage
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
typealias PlatformImage = NSImage
typealias PlatformColor = NSColor
#endif

/// The impact styles `HapticsDirector` names.
///
/// The parameter survives on macOS so the call sites do not have to fork — the
/// *emitting* is what is compiled out, not the vocabulary describing it.
#if canImport(UIKit)
typealias FeedbackStyle = UIImpactFeedbackGenerator.FeedbackStyle
#else
enum FeedbackStyle { case light, medium, heavy, soft, rigid }
#endif

extension PlatformImage {

    /// An asset-catalogue image by name, on either platform.
    static func asset(_ name: String) -> PlatformImage? {
        #if canImport(UIKit)
        return UIImage(named: name)
        #else
        return NSImage(named: name)
        #endif
    }

    /// A file on disk.
    static func file(_ path: String) -> PlatformImage? {
        #if canImport(UIKit)
        return UIImage(contentsOfFile: path)
        #else
        return NSImage(contentsOfFile: path)
        #endif
    }
}

extension Image {
    /// `Image(uiImage:)` / `Image(nsImage:)`, chosen at compile time.
    init(platform image: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: image)
        #else
        self.init(nsImage: image)
        #endif
    }
}

/// A colour that answers differently in light and dark appearance.
///
/// `UIColor`'s trait-aware initialiser has no direct AppKit twin —
/// `NSColor(name:dynamicProvider:)` takes the *appearance* rather than a trait
/// collection — so the two are written out separately here rather than
/// pretended to be the same call. It is the one genuine fork in this file.
func dynamicColor(light: RGBComponents, dark: RGBComponents) -> Color {
    #if canImport(UIKit)
    return Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark.uiColor : light.uiColor
    })
    #else
    return Color(NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? dark.uiColor : light.uiColor
    })
    #endif
}

/// Draw something once, at a pixel size, and get JPEG bytes back.
///
/// The Scrapbook's import path and its debug seed both need this, and
/// `UIGraphicsImageRenderer` does not exist on macOS. Kept as one function
/// rather than two call sites of `#if`, so the *behaviour* — scale 1, opaque,
/// re-encoded — is stated once. That re-encode is the whole of the EXIF strip;
/// `tools/check_film.py` fails if it goes missing.
func renderJPEG(size: CGSize, quality: CGFloat = 0.82,
                draw: (CGContext) -> Void) -> Data? {
    #if canImport(UIKit)
    let format = UIGraphicsImageRendererFormat.default()
    // 1, not the screen's scale: `size` is already the pixel size wanted, and
    // a 3x renderer would quietly produce a nine-times-larger file.
    format.scale = 1
    format.opaque = true
    let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
        draw(context.cgContext)
    }
    return image.jpegData(compressionQuality: quality)
    #else
    guard let context = CGContext(
        data: nil,
        width: Int(size.width), height: Int(size.height),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }
    // Core Graphics is y-up and both callers draw y-down, like UIKit.
    context.translateBy(x: 0, y: size.height)
    context.scaleBy(x: 1, y: -1)
    draw(context)
    guard let cgImage = context.makeImage() else { return nil }
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    return bitmap.representation(using: .jpeg,
                                 properties: [.compressionFactor: quality])
    #endif
}
