#if os(macOS)
import AppKit
import SwiftUI

/// The buddy, drawn once at a size the menu bar can actually hold.
///
/// ### Why this exists at all
///
/// A `MenuBarExtra` label sizes the status item from the **`NSImage`'s
/// intrinsic size**, and ignores the SwiftUI `.frame` around it. Every buddy
/// sprite is a 400 × 400 PNG whose `Contents.json` declares no `scale`, so
/// `NSImage(named:)` reports a size of 400 × 400 *points* — and the shipping
/// status item measured **418 × 402 points** through the accessibility API: a
/// magnified slice of the cat's face smeared across a sixth of the menu bar,
/// starting 189 points above the top of the screen.
///
/// That is not a SwiftUI layout bug to chase with more modifiers. Proven in a
/// clean-room two-scene app, same PNG, both labels:
///
/// | Label | Status item width |
/// |---|---|
/// | `Image(nsImage:).resizable().scaledToFit().frame(16, 16)` | **416 pt** |
/// | the same `NSImage` redrawn at 16 × 16 first | **32 pt** |
///
/// So the label is handed an `NSImage` that is *already* the right size, and
/// nothing else changes.
///
/// ### Not a template image, and that is the interesting part
///
/// The convention for a status item is `isTemplate = true`: a silhouette cut
/// from the alpha channel, tinted by the menu bar so it inverts correctly in
/// both appearances. It is **wrong here**, and that was settled by rendering
/// six buddies both ways at 18 points and looking at the sheet rather than by
/// preferring one: as silhouettes the cat, the fox, the owl and the bunny are
/// the same rounded blob with two ears, and the dog is a blob without. The
/// whole point of this feature is that it is *your* buddy up there; a template
/// throws away the one channel — colour — that tells them apart. In colour
/// every one of them is recognisable at that size, because the art is pixel
/// art with a dark outline and a light belly.
///
/// Which is also why it does not need the menu bar's tint to stay legible.
/// Every one of these sprites carries both a dark outline and a pale belly, so
/// whichever way the bar goes, part of the animal is the opposite of it. The
/// strongest-contrasting pixel in each, measured at 18 points against a light
/// bar and a dark one: 14.6:1 and 16.9:1 for the cat, 16.5:1 and 9.8:1 for the
/// capybara — its darkest pixel is brown rather than black — and better than
/// both for the other five. 3:1 is the bar for something that is not text.
///
/// A colour status item is allowed and common; a template one is a default,
/// not a rule. This is the case where the default costs the feature.
///
/// ### Two poses, one size
///
/// The sprites are drawn on a shared 400 × 400 grid but each pose inks a
/// different part of it — the awake cat is 330 × 380 with its tail up, the
/// asleep cat 310 × 320 curled — so fitting each pose to its own ink would
/// make the buddy visibly *grow* when it lay down. Both poses are measured
/// together and cropped to the union, which keeps one scale and one ground
/// line across the phase change. Trimming at all is worth it: untrimmed, the
/// transparent margin costs about a fifth of the height at a size where there
/// are only eighteen points to spend.
@MainActor
enum MenuBarIcon {

    /// How tall the buddy stands in the menu bar.
    ///
    /// 18 points in the 24-point bar, which is what the system items beside it
    /// use — wider than tall is capped separately, since a couple of the
    /// buddies are broader than they are high and a status item that is nearly
    /// square reads as an icon rather than as a banner.
    static let height: CGFloat = 18
    static let maximumWidth: CGFloat = 22

    /// Rendered at the sprite's own resolution — `size: 100` at `scale: 4` is
    /// 400 pixels, exactly the PNG's grid, so `BuddySprite`'s
    /// `.interpolation(.none)` resamples nothing and nothing is lost before
    /// the one downscale that matters. Rendering straight at 18 points would
    /// take nearest-neighbour from 400 pixels to 36 — four rows dropped in
    /// every five, and the nose with them.
    private static let renderSide: CGFloat = 100
    private static let renderScale: CGFloat = 4

    /// Pixels per point in the icon that is kept.
    ///
    /// The 400-pixel render is for measuring and cropping; holding onto it
    /// would be 640 KB per cached pose in an app whose whole pitch is that it
    /// sits in the menu bar all day. 4× covers a Retina display twice over and
    /// costs about 20 KB, and the resample down to it is the same high-quality
    /// one AppKit would have done at draw time — done once, here, instead of
    /// on every redraw.
    private static let iconScale: CGFloat = 4

    private static var cache: [String: NSImage] = [:]

    /// The menu bar's buddy, cached — `body` re-evaluates every second while
    /// the countdown ticks, and this walks 160 000 pixels twice.
    static func buddy(_ buddy: Buddy, sleeping: Bool,
                      outfit: [Accessory]) -> NSImage? {
        let key = "\(buddy.rawValue)|\(sleeping)|\(outfit.map(\.id).joined(separator: "+"))"
        if let hit = cache[key] { return hit }
        guard let image = draw(buddy, sleeping: sleeping, outfit: outfit)
        else { return nil }
        cache[key] = image
        return image
    }

    private static func draw(_ buddy: Buddy, sleeping: Bool,
                             outfit: [Accessory]) -> NSImage? {
        guard let awake = pixels(buddy, assetName: buddy.awakeAssetName,
                                 sleeping: false, outfit: outfit),
              let asleep = pixels(buddy, assetName: buddy.asleepAssetName,
                                  sleeping: true, outfit: outfit),
              let awakeInk = inkedBounds(awake),
              let asleepInk = inkedBounds(asleep)
        else { return nil }

        let union = awakeInk.union(asleepInk)
        guard let cropped = (sleeping ? asleep : awake).cropping(to: union)
        else { return nil }

        let scale = min(height / union.height, maximumWidth / union.width)
        let size = NSSize(width: union.width * scale, height: union.height * scale)
        guard let small = resampled(cropped, to: size) else { return nil }
        let image = NSImage(cgImage: small, size: size)
        image.isTemplate = false
        return image
    }

    /// The crop, resampled to `iconScale` pixels per point.
    private static func resampled(_ image: CGImage, to size: NSSize) -> CGImage? {
        let width = Int((size.width * iconScale).rounded(.up))
        let height = Int((size.height * iconScale).rounded(.up))
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func pixels(_ buddy: Buddy, assetName: String,
                               sleeping: Bool, outfit: [Accessory]) -> CGImage? {
        let renderer = ImageRenderer(content: BuddySprite(
            buddy: buddy, assetName: assetName, size: renderSide,
            sleeping: sleeping, outfit: outfit
        ))
        renderer.scale = renderScale
        return renderer.cgImage
    }

    /// The bounding box of everything that is not transparent, in the image's
    /// own top-left-origin pixel coordinates — which is the space
    /// `CGImage.cropping(to:)` reads, so the two agree without a flip. A
    /// bitmap context's first row in memory is the image's *top* row, and this
    /// counts rows, not context points.
    private static func inkedBounds(_ image: CGImage) -> CGRect? {
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return nil }
        let bytesPerRow = width * 4
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: bytesPerRow * height, alignment: 4)
        defer { buffer.deallocate() }
        buffer.initializeMemory(as: UInt8.self, repeating: 0,
                                count: bytesPerRow * height)
        guard let context = CGContext(
            data: buffer, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let bytes = buffer.assumingMemoryBound(to: UInt8.self)
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = y * bytesPerRow
            for x in 0..<width where bytes[row + x * 4 + 3] > 8 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY,
                      width: maxX - minX + 1, height: maxY - minY + 1)
    }
}

/// The Mac's whole pitch: the buddy lives in your menu bar while you work.
///
/// A phone app you can also run on a laptop is not worth shipping. What makes
/// this worth a second platform is that the window can be closed entirely and
/// the session keeps going — the countdown is in the menu bar, the buddy is
/// asleep beside it, and you get on with whatever you opened the Mac to do.
///
/// This costs nothing to keep accurate, because of a law written for a
/// completely different reason: the countdown derives from an absolute end
/// `Date`, so **App Nap cannot break it**. A tick-counting timer would drift
/// or stall the moment macOS throttled the app, exactly as it would when iOS
/// suspends a backgrounded one.
struct MenuBarBuddy: View {
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        HStack(spacing: 4) {
            // Asleep while you focus, up and about on a break — the same
            // fiction as the phone, at eighteen points.
            //
            // No `.resizable()`, no `.frame()`: the whole fix is that the
            // `NSImage` arrives already the right size, and a status item
            // takes its width from that and from nothing else. Adding a frame
            // back would change the picture and not the status item, which is
            // exactly the trap this used to be in — see `MenuBarIcon`.
            if let icon = MenuBarIcon.buddy(
                engine.settings.buddy,
                sleeping: engine.isRunning && !engine.phase.isBreak,
                outfit: engine.settings.outfit(for: engine.settings.buddy)
            ) {
                Image(nsImage: icon)
            } else {
                // Only reachable if an asset lookup fails outright. A symbol
                // rather than the buddy's emoji, because this has to be a
                // thing of known size in a bar where an unknown one is what
                // went wrong in the first place.
                Image(systemName: "timer")
            }
            if engine.isRunning {
                Text(engine.remainingText)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
            }
        }
        .accessibilityLabel(label)
    }

    private var label: String {
        let name = engine.settings.displayName(for: engine.settings.buddy)
        guard engine.isRunning else { return "Pawmodoro. \(name) is waiting." }
        return engine.phase.isBreak
            ? "Break, \(engine.remainingText) left."
            : "Focus, \(engine.remainingText) left. \(name) is asleep."
    }
}

/// What the menu opens to: the controls, and nothing else.
///
/// Deliberately four items. A menu bar extra is a glance and a keystroke, not
/// a second copy of the app — everything else stays in the window, which is
/// one click away and where it belongs.
struct MenuBarControls: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(engine.isRunning ? "Pause" : "Start") {
            engine.toggle()
        }
        .keyboardShortcut(.space, modifiers: [])

        Button("Skip this phase") { engine.skipPhase() }
            .disabled(!engine.isRunning)

        Divider()

        // The snow globe's replacement. There is no accelerometer in a Mac, so
        // the shake gesture has nowhere to live; it becomes a menu item rather
        // than being dropped, because the thing it does is worth keeping and
        // only the *gesture* was ever iPhone-shaped.
        Button("Give it a shake") { SceneShake.shared.shake() }

        Divider()

        // Raise the window you already have; only make one when there is none.
        //
        // `openWindow(id:)` on a `WindowGroup` is *new window*, not *show
        // window* — measured, not assumed: pressing this with the window
        // already open left two 400×912 windows on screen, and pressing it
        // again would have left three. Somebody whose window is behind Xcode
        // reaches for this item precisely because they cannot see it, which is
        // the one case where the wrong behaviour is guaranteed to fire.
        //
        // `canBecomeMain` is what separates the app's own windows from the
        // status item's — `MenuBarExtra` keeps an `NSStatusBarWindow` in
        // `NSApp.windows` for the life of the process, so a bare `first` here
        // would find that and raise nothing. `isVisible` is the second half:
        // a closed `WindowGroup` window lingers in the list until it is
        // released, and ordering a closed window front shows an empty frame.
        Button("Open Pawmodoro") {
            let existing = NSApp.windows.first { $0.canBecomeMain && $0.isVisible }
            if let existing {
                NSApp.activate(ignoringOtherApps: true)
                existing.makeKeyAndOrderFront(nil)
            } else {
                openWindow(id: "main")
            }
        }
        .keyboardShortcut("0", modifiers: .command)

        Divider()

        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}
#endif
