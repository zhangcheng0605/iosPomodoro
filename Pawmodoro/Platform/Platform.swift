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
/// ### What macOS gets that iOS does not — and where it lives
///
/// One thing, and it is not a feature: the pointer. A Mac control that does
/// not answer the cursor reads as disabled, and the walk found `.onHover`,
/// `.help()` and `.contextMenu` appearing essentially nowhere in this app.
/// That layer is `Mac/Pointer.swift` rather than this file, because it is not
/// a platform *seam* — nothing forks, nothing needs a second implementation,
/// and every one of its modifiers is literally `self` on iOS. This file is for
/// the places the two platforms cannot be written the same way; that one is
/// for the sentence a Mac adds after them.
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
    /// 860 of **content**, measured rather than guessed: the main screen wants
    /// about 848 points of it, and a Mac window with a toolbar spends roughly
    /// 52 more of its height on the title bar that a phone's status bar never
    /// charged for — so 912 of window, which is the size this app has always
    /// opened at. It was written as 740 on Linux and the phase pill sat behind
    /// the toolbar with the start button cut off by the bottom edge; it then
    /// spent a while at 480 × 900, which was never honoured by anything and
    /// never the size the window took.
    ///
    /// ### SwiftUI does not honour this. `MacWindowRules` enforces it. Measured.
    ///
    /// Read that before reaching for it. `.defaultSize(Platform.macWindow)`
    /// and the `idealWidth`/`idealHeight` in `PawmodoroApp` are **not
    /// honoured** under `.windowResizability(.contentSize)`. The window opens
    /// at whatever size the *content* reports, clamped by the content's own
    /// bounds and by nothing else.
    ///
    /// Measured on 10 Aug 2026 by deleting the saved frame (`NSWindow Frame
    /// main-AppWindow-1`, confirmed absent), launching, and reading the size
    /// back off `CGWindowListCopyWindowInfo`. Five builds:
    ///
    /// | `macWindow` | `macWindowMinimum` | Window opens at |
    /// |---|---|---|
    /// | 400 × 900 | 360 × 860 | **460 × 912** |
    /// | 480 × 900 | 400 × 860 | **460 × 912** |
    /// | 480 × 900 | 440 × 860 | **460 × 912** |
    /// | 480 × 900 | 460 × 860 | **460 × 912** |
    /// | 480 × 900 | 500 × 860 | **500 × 912** |
    ///
    /// 480 never appears in that column, and neither does 400 — the content
    /// wanted 460 × 860 and got it, clamped upward by the minimum in the last
    /// row.
    ///
    /// A sixth build, on 10 Aug, is why this constant is no longer advisory.
    /// The Mac moved to `ContentView.adaptiveColumn` so that a short window
    /// would be a *smaller* screen rather than a broken one, and that column is
    /// greedy along the vertical — a greedy content reports its **maximum**, so
    /// the window opened at 520 × 1179 with the art cropped to a band of sky.
    /// `MacWindowRules.place` now states the opening frame to AppKit directly,
    /// from this constant, and clamps it to the screen. So these numbers are
    /// live again: they are **content** points, and 52 of title bar are added
    /// on top of the height. 460 × 860 is what shipped, kept deliberately.
    /// **A toolbar that overflows is still not fixed here** — that is the
    /// minimum's width, below.
    ///
    /// ### What the width is actually for
    ///
    /// The idle screen carries five toolbar items — Stats, the Sound Studio,
    /// the camera, the gear, the bench. Below about 455 points the last of
    /// them fall into AppKit's `»` overflow, and that is worse than a chevron
    /// to click: a collapsed item **does not exist in the accessibility
    /// tree**, so a search of the running app for "Settings" finds nothing and
    /// neither VoiceOver nor keyboard navigation can reach the gear.
    ///
    /// That was reported as a first-run bug and it is not one — at every
    /// setting of these constants, including the original 400/360, the window
    /// opens at 460 with all five items drawn and no chevron (photographed).
    /// It is a **drag** bug: the old floor was 360, so the overflow was two
    /// inches of pointer travel away and permanent once there, because the
    /// frame is saved. `macWindowMinimum` is where that is fenced.
    ///
    /// Three things were tried before reaching for the width, and none of them
    /// is the fix, so that nobody spends the afternoon again. An empty
    /// `navigationTitle` changes nothing — the ~165 points between the leading
    /// and trailing groups is AppKit's own reserve, not the title. Moving the
    /// trailing pair to `.automatic` changes nothing either; on macOS it
    /// resolves to the same trailing group. Shrinking the glyphs to a uniform
    /// 30 points recovers about 46 and lands at 409, which is still over.
    static let macWindow = CGSize(width: 460, height: 860)

    /// The smallest the Mac window may be dragged to.
    ///
    /// ### The height is a screen this app has to fit on, not a taste call
    ///
    /// It was 860 of content — 912 of window — and that was measured against
    /// the layout rather than against any Mac. A **1440 × 900-point display**
    /// has 875 points under the menu bar, and the 13-inch MacBook Air is
    /// exactly that display and is well inside a `macOS 14.0` deployment
    /// target. So the window was 37 points taller than the screen it opened
    /// on, and could not be dragged smaller, and what hung off the bottom was
    /// the row with Start in it. An app you cannot start.
    ///
    /// 700 is the answer to *that* question — 752 of window, which fits a
    /// 1440 × 900 display with its Dock showing (799) and not merely with the
    /// menu bar taken off. It is deliberately not the largest number that
    /// would have done: a floor is only ever met by somebody whose screen or
    /// taste demands it, and the cost of it being low is nothing, while the
    /// cost of it being 40 points too high is an unusable app on a laptop
    /// nobody thought about.
    ///
    /// **This is only half of the fix and does not work alone.** A floor lets
    /// the window be dragged smaller; it does not make it *open* smaller.
    /// `MacWindowRules.place` clamps the opening height to the screen, and it
    /// can only clamp down to this number. The other half is that at 700 the
    /// screen still has to look like a screen: the old comment here recorded
    /// that at 780 "the phase pill disappears behind the toolbar and the start
    /// button is cut off by the bottom edge", which was true and is what
    /// `ContentView.adaptiveColumn` is for — the Mac takes that column at every
    /// text size now, so the top group gives way and the transport stays
    /// pinned. Photographed at 752, 772, 812 and 860 of window: every row
    /// whole, the treat tray and the buddy's caption going under the fade in
    /// that order as the room runs out.
    ///
    /// ### The width here is the whole of the toolbar fix
    ///
    /// 460 rather than the 360 it was, and this — not `macWindow` — is the
    /// number that does the work, for two reasons that are worth keeping
    /// apart.
    ///
    /// It is the **drag floor**: below roughly 455 the gear and the haiku
    /// bench fall into the `»` overflow and out of the accessibility tree with
    /// it, and a floor is the only thing that stops a pointer putting them
    /// there. The old 360 left that two inches of travel away and permanent
    /// once reached, because AppKit saves the frame.
    ///
    /// It used to be the **opening size** as well, which is the part nobody
    /// expects: `.defaultSize` is not honoured here (see `macWindow` above for
    /// the five-build measurement), so the window opened at the content's
    /// natural size clamped up by this. That is no longer true of the height —
    /// `MacWindowRules.place` states the opening frame now — but it is still
    /// true of the **width**, which nothing overrides. Lowering this width is
    /// therefore still a change to what every new user's first window looks
    /// like, as well as to where the toolbar overflows.
    ///
    /// 460 leaves five points over the 455 threshold rather than a comfortable
    /// margin, and that is deliberate rather than overlooked: 460 is the width
    /// the layout asks for on its own, so taking it keeps the opening window
    /// at its natural size instead of forcing it wider. The five points are
    /// backed by a photograph at exactly 460 with all five glyphs drawn and no
    /// chevron. If a sixth toolbar item is ever added, that margin is gone and
    /// this number has to be re-measured — not nudged.
    ///
    /// It leaves 460…520 of horizontal travel, which is narrow, and that is
    /// the honest shape of an app whose every scene is exported at a phone's
    /// aspect: the width was never a place this window had much to say.
    static let macWindowMinimum = CGSize(width: 460, height: 700)

    /// The biggest the Mac window may be dragged to — **the shape of the art**.
    ///
    /// Every scene is exported at 396×858 and drawn `scaledToFill`, so a window
    /// wider than that aspect crops the artwork to a horizontal band through
    /// the middle of the sky: the hills, the ground and the house all fall
    /// outside it and what is left reads as a flat wash of colour. Bounding the
    /// width at 520 is what keeps a place looking like a place. `SceneryView`
    /// anchors the remaining crop to the ground as a second line of defence.
    ///
    /// ### The height used to be free, and that was the Zoom bug
    ///
    /// `CGFloat.infinity` here is what the green traffic light reads as "you
    /// may have the whole screen": pressing Zoom on a 2160-point display gave a
    /// **520 × 2135 sliver** — the countdown at the top, the ground at the
    /// bottom and about 900 points of empty sky in between. It looked like a
    /// mistake because it was one. A window is only allowed to grow into shapes
    /// the app has art for.
    ///
    /// So the ceiling is the scene's own aspect at the maximum width:
    /// 520 × 858/396 = 1127 points of content. At exactly that size the
    /// artwork fills the window with nothing cropped and nothing stretched,
    /// which makes it the honest answer to Zoom: not "as big as the screen",
    /// but "as big as this looks right". Derived rather than chosen, so
    /// re-exporting the scenes at another aspect moves it.
    ///
    /// The floor stays 860, so the window still resizes over a real range
    /// (860…1127 of content) rather than being pinned.
    static let macWindowMaximum = CGSize(
        width: 520,
        height: (520 * (858.0 / 396.0)).rounded()
    )

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
/// no navigation bar to size a title in, and no autocapitalisation to switch
/// off on a hardware keyboard.
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

// `.tabViewStyle(.page)` and `.indexViewStyle(.page(…))` used to be shimmed
// here too, and that pair is the counter-example this whole section is judged
// against — the one time absorbing an iOS spelling was the wrong call.
//
// They were not no-ops. `.page` resolved to `DefaultTabViewStyle`, which on
// macOS is a **real AppKit tab bar**: the onboarding sheet — the first screen
// anybody sees — drew three unlabelled tab chips across its top edge, half of
// them clipped by the sheet's rounded corner, where a phone shows three dots
// at the bottom. Nothing failed and nothing warned; the Mac just quietly had
// a different, broken screen.
//
// The rule the miss teaches: a shim belongs here only if the Mac dropping the
// thing entirely is the *right* answer. A paged deck is not decoration, it is
// navigation, and navigation has to be built rather than dropped. It lives in
// `Views/Style/PagedDeck.swift` now, and the shims are deliberately absent so
// that writing `.tabViewStyle(.page)` fails the Mac build instead of drawing
// tab chips at somebody.

extension View {
    func navigationBarTitleDisplayMode(_ mode: NavigationBarTitleDisplayMode) -> some View {
        self
    }
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
    ///
    /// ### Only in a *window*. In a sheet, both of these render nothing.
    ///
    /// A sheet on macOS has no window toolbar to put items in. SwiftUI keeps
    /// the semantic placements — `.confirmationAction`, `.cancellationAction`,
    /// `.automatic` all appear in the sheet's bottom action row — and
    /// **silently drops `.navigation` and `.primaryAction`**. No warning, no
    /// empty space: the control simply is not there.
    ///
    /// Measured on 9 Aug 2026, in the sandboxed Mac build, by putting four
    /// probe buttons in the Scrapbook sheet's toolbar at once and reading the
    /// accessibility tree:
    ///
    /// | Placement | In a Mac sheet |
    /// |---|---|
    /// | `.navigation` (this file's `topBarLeading`) | **nothing** |
    /// | `.primaryAction` (this file's `topBarTrailing`) | **nothing** |
    /// | `.automatic` | shown, leading end of the action row |
    /// | `.cancellationAction` | shown, beside Done |
    /// | `.confirmationAction` | shown — this is the Done button |
    ///
    /// That is not a hypothesis about why something looked wrong; it is what
    /// the sheet contained. It cost the Scrapbook its only way in on macOS —
    /// a `PhotosPicker` sat in `.topBarLeading` and a fresh Mac install had a
    /// permanently empty Scrapbook with no "+" anywhere. The fix was to stop
    /// asking a sheet toolbar for a primary control at all: `ScrapbookView`
    /// puts the picker in its **content**, which is one control that lands on
    /// both platforms rather than two code paths.
    ///
    /// So: these two shims are for a screen presented in the **window**. A
    /// control a sheet cannot do without belongs in the sheet's content, or —
    /// if it really must be in the bar — at `.automatic`.
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
