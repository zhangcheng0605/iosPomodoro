import SwiftUI

#if os(macOS)
import AppKit
#endif

#if os(macOS)
/// The two things about this window that SwiftUI has no modifier for.
///
/// Both are about the same sentence: **this window does not do full screen.**
/// The scenes are exported at 396×858 and drawn `scaledToFill`; a window at a
/// display's aspect crops every place to a horizontal band of sky with the
/// ground, the hills and the house outside it. That measurement is what bounds
/// the width at 520 in `Platform.swift`, and now the height with it — so full
/// screen is not a feature this app is missing, it is a shape its art does not
/// have. `NSWindowCollectionBehavior.fullScreenNone` is how you say that in
/// AppKit — it is what stops `Window ▸ Move & Resize` and a modifier-held
/// green button from putting the window into a shape the art has no picture
/// for. It does **not** take `Enter Full Screen` out of the View menu, which
/// is the second half and is `trimEmptyMenus()` below. Both are here because
/// they are the same sentence said to two different parts of AppKit.
///
/// A view rather than an `NSApplicationDelegate` because the thing being
/// configured is a *window*, and this is the only place in SwiftUI that has
/// one. `updateNSView` re-applies both because a `WindowGroup` may make a
/// second window, and because SwiftUI rebuilds the main menu whenever
/// `sessionCommands` changes — which it does on every start and pause, since
/// the first item is titled "Start" or "Pause".
private struct MacWindowRules: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        // The window is not attached yet on the first layout pass.
        DispatchQueue.main.async {
            apply(to: view.window)
            MacMenuKeeper.shared.start()
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        apply(to: view.window)
    }

    private func apply(to window: NSWindow?) {
        guard let window else { return }
        var behavior = window.collectionBehavior
        behavior.remove(.fullScreenPrimary)
        behavior.remove(.fullScreenAuxiliary)
        behavior.insert(.fullScreenNone)
        window.collectionBehavior = behavior
    }
}

/// Keeps the View menu off the menu bar, because there is nothing in it.
///
/// This took four tries and the first three are worth recording, since each
/// looked obviously right and each did nothing you could see.
///
/// 1. `CommandGroup(replacing: .sidebar) { }`. It does empty the menu;
///    SwiftUI is simply not what fills it.
/// 2. `NSWindowCollectionBehavior.fullScreenNone` on the window. The honest
///    declaration, and the item stayed exactly where it was, still greyed.
/// 3. Walking `NSApp.mainMenu` once, when the window appears, and removing
///    any item whose action is `toggleFullScreen:`. Dumping the menu from
///    inside the running app is what explained this one: at the moment
///    SwiftUI has finished building it, **the View menu holds zero items**.
///    AppKit inserts `Enter Full Screen` lazily, on the way to displaying the
///    menu, so at every moment your own code can run there is nothing there
///    to remove. The empty *menu* is the thing to take out, before AppKit has
///    anywhere to put the item.
///
/// Which leaves why this is a live observer rather than one pass. SwiftUI
/// rebuilds the whole main menu whenever `commands` re-evaluates, and this
/// app's first Session item is titled "Start" or "Pause" — so **the View menu
/// came back the first time the timer started**, measured, three seconds after
/// it had been removed. `didUpdateNotification` fires after each pass of the
/// event loop, which is the only hook that is reliably *after* a rebuild.
/// The guard makes the common case an integer comparison: the menu we last
/// trimmed, still holding the number of items we left it holding, is a menu
/// with nothing to do.
///
/// **The last menu is skipped on purpose, and it is the Help menu.** That one
/// is empty too — deliberately, see the `.help` group in `sessionCommands` —
/// but macOS puts its own search row in it, so an empty Help menu is not an
/// empty menu on screen. Skipping the last item rather than matching the title
/// "View" is what keeps this working in a language this app does not speak
/// yet; Help is the rightmost menu in every Mac app there is.
@MainActor
private final class MacMenuKeeper {
    static let shared = MacMenuKeeper()

    private var observer: (any NSObjectProtocol)?
    private var trimmedMenu: NSMenu?
    private var trimmedCount = -1

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didUpdateNotification,
            object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { MacMenuKeeper.shared.trim() }
        }
        trim()
    }

    private func trim() {
        guard let mainMenu = NSApp.mainMenu else { return }
        if mainMenu === trimmedMenu, mainMenu.numberOfItems == trimmedCount {
            return
        }
        for top in mainMenu.items.dropLast() {
            guard let submenu = top.submenu, submenu.items.isEmpty else {
                continue
            }
            mainMenu.removeItem(top)
        }
        trimmedMenu = mainMenu
        trimmedCount = mainMenu.numberOfItems
    }
}
#endif

@main
struct PawmodoroApp: App {
    @State private var engine: TimerEngine
    @State private var store: StoreManager
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Before the engine and the store are built, since both read
        // UserDefaults on init and the debug launch options rewrite it.
        LaunchOptions.applyAtLaunch()
        #if os(macOS)
        // Before any window is made, which is the only time this is read.
        // See the View menu note in `sessionCommands` for why.
        NSWindow.allowsAutomaticWindowTabbing = false
        #endif
        let engine = TimerEngine()
        let store = StoreManager()
        // The two roads to the same door, introduced. `isUnlocked(_:)` stays
        // the single place that decides; it just knows about both now.
        store.pouch = engine.pouch
        _engine = State(initialValue: engine)
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(engine)
                .environment(store)
                .fontDesign(.rounded)
                .task {
                    // Before the store, so `-PawmodoroDrift` lands on the
                    // first frame rather than after a network round trip.
                    engine.applyDebugDrift()
                    await store.loadProducts()
                    engine.storeHasPlus = store.hasPlus
                    engine.applyEntitlement(hasPlus: store.hasPlus)
                }
                #if os(macOS)
                // Two things a phone never had to say out loud.
                //
                // **The size.** `.defaultSize` on its own is a suggestion the
                // window ignores under `.contentSize` resizability, because
                // the content has no size opinion to resize to: this opened at
                // 400×1134 — half again as tall as any phone — and then
                // refused to be dragged back. Stating the frame is what makes
                // the window obey, and the bounds are the rule in
                // `Platform.swift` enforced rather than hoped for. The art is
                // phone-shaped, so the window stays phone-shaped.
                //
                // `maxHeight` is stated for the same reason the width is, and
                // it is what the green traffic light reads. Left free, Zoom
                // took the window to the full height of the display — a
                // 520 × 2135 column with 900 points of empty sky in it.
                // Bounded, Zoom means "as big as the artwork looks right at",
                // which is a Mac window doing the Mac thing rather than an
                // iPhone stretched.
                //
                // **The backing.** On macOS a window is only as opaque as the
                // view inside it. The bottom layer of this app is
                // `Theme.background(for:)`, whose top stop is
                // `blush.opacity(0.6)` — four-tenths see-through — and the
                // only thing covering it is the scene image. A window whose
                // opacity depends on an image having loaded is a window that
                // shows the desktop on the day it hasn't. On iOS nobody could
                // ever have noticed: there is nothing behind a full-screen app.
                .frame(
                    minWidth: Platform.macWindowMinimum.width,
                    idealWidth: Platform.macWindow.width,
                    maxWidth: Platform.macWindowMaximum.width,
                    minHeight: Platform.macWindowMinimum.height,
                    idealHeight: Platform.macWindow.height,
                    maxHeight: Platform.macWindowMaximum.height
                )
                .background(Theme.cream)
                .background(MacWindowRules())
                #endif
        }
        #if os(macOS)
        .defaultSize(Platform.macWindow)
        .windowResizability(.contentSize)
        .commands { sessionCommands }
        #endif
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // The app may have been suspended for hours; recompute from the
                // stored end date and finish the phase if it already elapsed.
                engine.syncAfterWake()
                engine.refreshAmbience()
                MusicPlayer.shared.resumeIfNeeded()
                AmbienceLoop.shared.resumeIfNeeded()
            case .background, .inactive:
                // iOS tears the audio engine down anyway; letting it idle in
                // the background is what gets an app looked at twice.
                MusicPlayer.shared.suspend()
                AmbienceLoop.shared.suspend()
            @unknown default:
                break
            }
        }

        #if os(macOS)
        menuBar
        settingsScene
        #endif
    }

    #if os(macOS)
    /// The three things you do to a running session, on the keyboard.
    ///
    /// The same three the menu bar extra offers, calling the same methods —
    /// a Mac gets extra *ways in*, never a second implementation. Notably
    /// `SceneShake.shared.shake()`, which is the snow globe: there is no
    /// accelerometer here, and this is where the gesture lands instead.
    ///
    /// No Space bar **here**. It is the obvious shortcut and in the *main
    /// menu* it is wrong: the buddy can be renamed from Settings, and a main
    /// menu command on a bare Space swallows the space bar inside that text
    /// field.
    ///
    /// `MenuBarControls` binds one anyway, and that is not the contradiction
    /// it looks like — measured in a clean-room app with the same two pieces.
    /// A `MenuBarExtra` menu is a status item's `NSMenu`, not part of
    /// `NSApp.mainMenu`, and `performKeyEquivalent` only ever walks the main
    /// menu: with the app frontmost and a `TextField` focused, typing
    /// "a b c" put "a b c" in the field and the menu's action never fired,
    /// while the same Space *did* fire it once the status menu was open. So
    /// the rule is about which menu, not about the key.
    @CommandsBuilder
    private var sessionCommands: some Commands {
        // "New Window" is deliberately left alone. Emptying that group takes
        // the whole File menu with it, and File is where ⌘W lives — a Mac
        // window that cannot be closed from the keyboard is a worse trade
        // than a second window. A second window is harmless anyway: the
        // engine is one object held by the app, so both show the same
        // countdown rather than two.
        //
        // The Help menu's one item is *not* left alone, for the opposite
        // reason. macOS synthesises "Pawmodoro Help" (⌘?) whether or not
        // there is anything behind it, and there is not: the bundle carries no
        // `CFBundleHelpBookFolder`, so pressing it puts up an alert reading
        // "Help isn't available for Pawmodoro." — measured, not assumed; the
        // dialog was opened and read back through the accessibility API. A
        // menu item whose only behaviour is an apology is worse than no menu
        // item, and this app's habit is not to claim things that are not
        // true. Replacing the group with nothing leaves the Help *menu* in
        // place, holding only the search row macOS inserts itself, and ⌘?
        // stops resolving to anything. If a help book is ever written, delete
        // this line and the item comes back on its own.
        CommandGroup(replacing: .help) { }

        // The View menu goes by the same argument, and it was the whole menu:
        // `Enter Full Screen`, `Show Tab Bar` and `Show All Tabs`, and nothing
        // this app does.
        //
        // **Full screen is not an oversight — this window cannot have one.**
        // The scenes are exported at 396×858 and drawn `scaledToFill`; at a
        // display's aspect a full-screen window would crop every place to a
        // horizontal band of sky with the ground, the hills and the house
        // outside it. That is the same measurement that bounds the width at
        // 520, and it is why `Platform.macWindowMaximum` now bounds the height
        // too. A window that cannot fill a screen should not offer to.
        //
        // Tabs are the other half: this app has a single scene showing a
        // single engine, so two windows are two views of the same session and
        // merging them into tabs means nothing.
        //
        // Neither is removed from here, and that is worth writing down because
        // it looks like it should be. `CommandGroup(replacing: .sidebar) { }`
        // changed nothing at all — measured, in the running app: SwiftUI is
        // not what puts `Enter Full Screen` in that menu, AppKit is. The two
        // that do work are `NSWindow.allowsAutomaticWindowTabbing` in `init()`
        // for the tab items, and `MacWindowRules` for the full screen one.

        CommandMenu("Session") {
            Button(engine.isRunning ? "Pause" : "Start") { engine.toggle() }
                .keyboardShortcut(.return, modifiers: .command)

            Button("Skip This Phase") { engine.skipPhase() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(!engine.isRunning)

            Divider()

            Button("Give It a Shake") { SceneShake.shared.shake() }
                .keyboardShortcut("k", modifiers: .command)
        }
    }

    /// ⌘, — the one Mac keystroke every Mac user tries first.
    ///
    /// Until this existed, pressing it did nothing at all: the shortcut is
    /// synthesised by AppKit only when an app declares a `Settings` scene, and
    /// `Pawmodoro ▸ Settings…` was simply absent from the application menu.
    /// The gear in the toolbar was the only way in, and at the shipping
    /// default window width the gear is behind the toolbar's overflow chevron
    /// (see `docs/MAC_WALK.md` § 4) — so the app's settings were two
    /// discoveries deep on the platform where they are conventionally one
    /// keystroke away.
    ///
    /// **This is a second way in, not a second screen.** The rule in
    /// `Platform.swift` is that a Mac gets extra doors and never a Mac
    /// spelling of a view, so this is the same `SettingsView` the sheet
    /// presents, with the same environment behind it. Anything fixed in that
    /// file is fixed in both places by construction.
    ///
    /// `.sheetSize()` is what makes it a *window* rather than a column: it is
    /// already on the `Form` inside `SettingsView`, and a `Settings` scene
    /// sizes itself to its content exactly the way a sheet does — so without
    /// it this scene would open at the 547 × 2972 the Mac walk measured, which
    /// is worse than no ⌘, at all. Nothing extra is stated here on purpose:
    /// one number in one file, and the two doors cannot drift apart.
    ///
    /// **Measured, 10 Aug 2026**, both doors, Debug and Release: the window is
    /// **540 × 700** — the 540 × 620 `Form` plus the title bar and the row the
    /// Done button sits in — and the `Form` scrolls inside it. The sheet
    /// through the toolbar gear is 540 × 719, nineteen points taller because a
    /// sheet has no title bar but does have a wider action row. Say 700 rather
    /// than 620 when quoting this window: 620 is what `sheetSize` asks for,
    /// not what the user's screen has to fit.
    ///
    /// The Done button in the view's toolbar keeps working — `dismiss()`
    /// closes a `Settings` window the same way it dismisses a sheet — so there
    /// is no "which door am I behind" branch inside the view, which is the
    /// thing that would have made this a second screen. Driven rather than
    /// assumed: pressing it takes the window out of the process's
    /// accessibility window list, and ⌘, brings it straight back.
    @SceneBuilder
    private var settingsScene: some Scene {
        Settings {
            SettingsView()
                .environment(engine)
                .environment(store)
                .fontDesign(.rounded)
        }
    }

    /// The Mac's actual reason to exist: the window can be closed entirely and
    /// the session keeps running.
    ///
    /// `.menuBarExtraStyle(.menu)` rather than `.window`, because this is a
    /// glance and a keystroke — a second floating copy of the app would be a
    /// worse version of the window that is already one click away.
    @SceneBuilder
    private var menuBar: some Scene {
        MenuBarExtra {
            MenuBarControls()
                .environment(engine)
                .environment(store)
        } label: {
            MenuBarBuddy()
                .environment(engine)
        }
        .menuBarExtraStyle(.menu)
    }
    #endif
}
