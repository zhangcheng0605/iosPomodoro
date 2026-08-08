import AVFoundation
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
/// - **The audio session.** There is no `AVAudioSession` on macOS; sound just
///   plays. `activateAmbientAudioSession()` is where that stops mattering —
///   and its note carries the measurement proving the no-op is not why a Mac
///   was once reported silent.
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
    /// 900 rather than the 740 this was written as on Linux, measured rather
    /// than guessed: the main screen needs about 848 points of *content*, and
    /// a Mac window with a toolbar spends roughly 52 of its height on the
    /// title bar that a phone's status bar never charged for. At 740 the
    /// phase pill sat behind the toolbar and the start button was cut off by
    /// the bottom edge.
    static let macWindow = CGSize(width: 400, height: 900)

    /// The smallest the Mac window may be dragged to.
    ///
    /// Not a taste call, and not a guess either — this is where the screen
    /// stops fitting. The main screen is a fixed stack, not a scroll view: at
    /// 780 the phase pill disappears behind the toolbar and the start button
    /// is cut off by the bottom edge, which is a broken app rather than a
    /// small one. 860 is the first height where every row is whole, and it
    /// still leaves room under the menu bar of the shortest Mac laptop screen.
    static let macWindowMinimum = CGSize(width: 360, height: 860)

    /// The widest the Mac window may be dragged to.
    ///
    /// A ceiling on the *width* only — height is free. Every scene is exported
    /// at 396×858 and drawn `scaledToFill`, so a window wider than it is tall
    /// crops the artwork to a horizontal band through the middle of the sky:
    /// the hills, the ground and the house all fall outside it and what is
    /// left reads as a flat wash of colour. Bounding the width is what keeps a
    /// place looking like a place. `SceneryView` anchors the remaining crop to
    /// the ground as a second line of defence.
    static let macWindowMaximum = CGSize(width: 520, height: CGFloat.infinity)

    /// Put the process's audio on the ambient category, once per launch.
    ///
    /// `.ambient` mixes with whatever else is playing and honours the ringer
    /// switch, which is what keeps this app off the background-audio
    /// capability App Review scrutinises. macOS has no `AVAudioSession` at all
    /// — sound simply plays — so this is the fourth deliberate no-op, and the
    /// two audio channels call it rather than each carrying their own `#if`.
    ///
    /// ### The no-op does not cause silence, and here are the numbers
    ///
    /// "The Mac has no sound" was reported once and this method was the first
    /// suspect, being the one place the audio path forks. It is not the cause,
    /// and the measurement is written down so nobody has to suspect it twice.
    /// A tap on `mainMixerNode` inside the running Mac app, both channels
    /// going, sandboxed build and unsandboxed alike:
    ///
    /// - default output was AirPods Pro, **2 ch, 48 kHz**, while every loop and
    ///   track in this app is **1 ch, 22.05 kHz** — the exact mismatch that
    ///   killed the iPhone in build 1;
    /// - `engine.start()` returned without throwing, `isRunning == true`;
    /// - the sub-mixer converted 1 ch/22.05 kHz to 2 ch/48 kHz across the
    ///   `format: nil` hop, exactly as intended, and non-silent samples reached
    ///   the main mixer: ambience peaked around 0.05–0.07, music 0.03–0.27,
    ///   sustained over seconds.
    ///
    /// So the graph is right on macOS for the same reason it is right on iOS:
    /// the **player→mixer** connection carries the buffer's own format and the
    /// **mixer→main** connection carries `nil`, which is what makes the mixer
    /// do the conversion. Do not "fix" either hop for the Mac.
    ///
    /// What the reporter actually hit was a track chosen while the timer was
    /// resting — both channels follow the timer by design — with a Sound Studio
    /// that drew a sounding speaker beside it. That is fixed in
    /// `SoundStudioView`, not here.
    static func activateAmbientAudioSession() {
        #if canImport(UIKit)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default)
        try? session.setActive(true)
        #endif
    }
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

    /// PNG bytes, for the one thing that leaves the phone: a shared postcard.
    ///
    /// `UIImage.pngData()` has no `NSImage` counterpart — the Mac route goes
    /// through a bitmap representation — so like everything else that differs
    /// between the two, it is spelled out once here and nowhere else.
    var pngBytes: Data? {
        #if canImport(UIKit)
        return pngData()
        #else
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
        #endif
    }
}

extension PlatformColor {

    /// This colour's sRGB components, safely, on either platform.
    ///
    /// `UIColor.getRed(…)` returns `Bool` and copes with any colour you hand
    /// it. `NSColor.getRed(…)` returns `Void` and **raises
    /// `NSInvalidArgumentException` on any non-RGB colorspace** — and
    /// `dynamicColor` below returns a *catalog* `NSColor`, which is exactly
    /// that. So on the Mac every `Theme` colour threw the moment anything
    /// tried to blend it, and one click on Stats took the whole app down, in
    /// Release as well as Debug. Resolving through `usingColorSpace(.sRGB)`
    /// first is the whole difference. The fallback is reachable only by a
    /// colour with no RGB representation at all, which nothing here has.
    ///
    /// This is exactly why the platform seam is one file. The same trap waits
    /// for anyone who reaches for a bare `PlatformColor` accessor next.
    var rgbaComponents: (CGFloat, CGFloat, CGFloat, CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        guard let rgb = usingColorSpace(.sRGB) else { return (0, 0, 0, 1) }
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return (r, g, b, a)
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

// MARK: - The iOS-only spellings, absorbed

/// The handful of SwiftUI modifiers that exist on iOS and not on macOS.
///
/// Every one of them is decoration a Mac window has no place to put: there is
/// no navigation bar to size a title in, and no page dots under a `TabView`.
/// They are given macOS spellings that do nothing, rather than each call site
/// being taught a `#if`, for the reason the rest of this file exists — but
/// also for a reason particular to this app. Most of Pawmodoro is written days
/// before it meets a compiler, phone-first and by habit. A named
/// `compactNavigationTitle()` helper would have to be *remembered* by every
/// view written from here on, and forgetting it breaks only the Mac build,
/// which is the pass nobody runs. Absorbing the iOS spelling here means the
/// phone code stays the only code and the Mac drops what it cannot show.
///
/// Nothing below adds behaviour. If a modifier ever needs to *do* something
/// different on the Mac it does not belong here — it belongs above, named for
/// what it does, like `activateAmbientAudioSession()`.
#if os(macOS)

/// iOS's `NavigationBarItem.TitleDisplayMode`, in name only.
enum NavigationBarTitleDisplayMode {
    case automatic, inline, large
}

/// iOS's `PageIndexViewStyle`, in name only.
struct PageIndexViewStyleShim {
    enum BackgroundDisplayMode { case automatic, interactive, always, never }

    static func page(
        backgroundDisplayMode: BackgroundDisplayMode = .automatic
    ) -> PageIndexViewStyleShim {
        PageIndexViewStyleShim()
    }
}

extension TabViewStyle where Self == DefaultTabViewStyle {
    /// There is no swipeable page style on macOS. The default container is
    /// what the two paged screens — onboarding and the year card — fall back
    /// to; both carry their own forward button, so nothing is unreachable.
    static var page: DefaultTabViewStyle { DefaultTabViewStyle() }
}

extension View {
    func navigationBarTitleDisplayMode(_ mode: NavigationBarTitleDisplayMode) -> some View {
        self
    }

    func indexViewStyle(_ style: PageIndexViewStyleShim) -> some View { self }
}

#endif

#if os(macOS)

/// iOS's `TextInputAutocapitalization`, in name only — a hardware keyboard
/// does not autocapitalise, so there is nothing here to turn off.
struct TextInputAutocapitalizationShim {
    static let never = TextInputAutocapitalizationShim()
    static let characters = TextInputAutocapitalizationShim()
    static let words = TextInputAutocapitalizationShim()
    static let sentences = TextInputAutocapitalizationShim()
}

extension View {
    func textInputAutocapitalization(_ style: TextInputAutocapitalizationShim?) -> some View {
        self
    }
}

#endif

#if os(macOS)

extension ToolbarItemPlacement {
    /// iOS's two navigation-bar placements, mapped to the Mac's window
    /// toolbar. `.navigation` is the leading group beside the title;
    /// `.primaryAction` is the trailing one. Same reading order, so a screen
    /// laid out for a phone comes out the right way round on a Mac.
    static var topBarLeading: ToolbarItemPlacement { .navigation }
    static var topBarTrailing: ToolbarItemPlacement { .primaryAction }
}

#endif

#if os(macOS)

extension View {
    /// A Mac window has no full screen to cover. The three screens that ask
    /// for one — onboarding, the year card, the camera — are all modal and
    /// all dismiss themselves, so a sheet is the same interaction with a
    /// different frame around it.
    func fullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }
}

#endif
