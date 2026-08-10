# Shipping Pawmodoro on the Mac App Store

_First written 8 Aug 2026. Rewritten 9 Aug 2026 (evening) after the two
remaining unknowns were settled on this Mac: StoreKit under the App Sandbox,
and the distribution profiles. Host **macOS 15.7.3 (24G419)**, **Xcode 26.3
(17C529)**, **macOS 26.2 SDK**, `MACOSX_DEPLOYMENT_TARGET = 14.0`. Repo on
branch `claude/pet-interactions-retention-7caoj8`._

Everything stated flatly here was **checked against this project** — the
pbxproj, the Swift, a build I ran, or a log I read. Everything unproven is
marked **VERIFY** and says how to check it.

> ## Update, 9 Aug 2026 (evening) — both remaining unknowns are closed
>
> - **StoreKit under the App Sandbox: settled, with a primary source.** The
>   macOS App Sandbox grants StoreKit's daemon lookups to *every* sandboxed
>   app, unconditionally, in Apple's own profile. **Do not add
>   `com.apple.security.network.client`.** § 3.3 has the profile text, a
>   Release-build run, an unsandboxed control, and a negative control that
>   proves the measurement isn't vacuous.
> - **The stale distribution profiles: not a blocker, and now not stale.**
>   `xcodebuild archive -allowProvisioningUpdates` followed by
>   `-exportArchive` with `method = app-store-connect` **succeeded on both
>   platforms**, and Xcode regenerated everything that was missing: a macOS
>   store profile that never existed, a fresh iOS store profile that now
>   carries `application-groups`, and the widget-extension store profile that
>   was absent. Signed with a **cloud-managed** Apple Distribution certificate
>   — nothing to install in Keychain. § 4.2. **Nothing was uploaded.**
> - **One real sandbox denial exists** and every previous run missed it,
>   because the way this repo was measuring denials could not see them. See
>   § 3.4 — the lesson is bigger than the bug.
> - **The macOS app icon landed while this was being written.** The archive I
>   built at 20:47 has no icon — `CFBundleIconName` absent from the Mac
>   `Info.plist`, no app-icon renditions in `Assets.car`. Minutes later a
>   separate workflow added the ten-rung `"idiom": "mac"` ladder to
>   `AppIcon.appiconset` (11 images now, `mac` + `universal`) along with
>   changes to `generate_assets.py`, `check_icons.py` and `project.pbxproj`.
>   **I did not build or verify that**, and this document did not touch those
>   files. Checklist step 5 says how to confirm it in one command.

> ## Update, 10 Aug 2026 — the icon is confirmed in a build, and two more fences
>
> - **Checklist step 5 is closed.** The ladder reached the product: a built Mac
>   bundle carries `CFBundleIconName`, a 37,266-byte `AppIcon.icns` and the
>   `mac` renditions in `Assets.car`. § 5.1.
> - **Step 6 is closed** (`e83cc81`). The menu bar extra is 36 × 24 points.
> - **`INFOPLIST_KEY_*` takes an `[sdk=…]` condition — and the fix this
>   document used to prescribe was wrong.** Conditioning Live Activities on
>   `iphoneos*` alone turns them **off in the Simulator**, which is the whole
>   verification loop for this app. Measured; see the box under "Should fix".
> - **Two new static rules** in `tools/check_icons.py` guard that setting and
>   the app/widget build-number pairing, on every plain invocation, on Linux
>   included. Both were broken deliberately and caught.
> - **How to drive the Mac build without touching the owner's mouse:**
>   `tools/mac_probe.py`. See "Driving the Mac build" below.

---

## Verdict

**Pawmodoro is a native macOS app that builds, archives, exports a signed
`.pkg`, and is uploadable.** The multiplatform target is right, the sandbox is
right, the entitlements are right, the icon is in the bundle, and the signing
machinery — the part everyone expects to fight — works on the first try with
`-allowProvisioningUpdates` and needs no Keychain surgery.

**Updated 10 Aug 2026.** The two Mac UI bugs are fixed (checklist 7 and 8), a
further four came out of a repair pass and are fixed too (10c), the screenshots
are re-shot (18), and ⌘, exists (10). A full run on that tree: **25 of 25
checkers pass, all four builds succeed** — iOS Debug, iOS Release for device,
macOS Debug, macOS Release — and the promo-code fence was re-proven with a
calibrated grep.

What is left is: **an evening of listening on real hardware**, the sandbox
StoreKit purchase nobody has driven, and a pile of App Store Connect work only
the owner can do. `docs/SUBMIT_NOW.md` is that list.

---

## THE LAUNCH CHECKLIST

> **If you are uploading today, read `docs/SUBMIT_NOW.md` instead.** It is the
> short ordered version of Phases 2 and 3 below, with the exact commands, the
> agreements that have to be Active before Plus can sell, the Small Business
> Program, and an honest list of what is still unverified. This file is the
> reasoning and the evidence behind it. Statuses here were last trued up on
> 10 Aug 2026 against a full run: 25 of 25 checkers, all four builds.

In the order to do them. **DONE** = verified on this Mac. **BLOCKED** =
somebody has to write code or make art; **in progress** = somebody is, right
now, so do not start it twice. **OWNER** = only Cheng can do it,
because it needs App Store Connect, an Apple Account password, or a judgement
call about the product.

Nothing in this repo can do an **OWNER** step, and nothing should try. Every
one of them either touches Apple's servers in a way that is not reversible, or
requires typing credentials.

### Phase 1 — the app itself

| # | Step | Status | Notes |
|---|---|---|---|
| 1 | Multiplatform target, `SDKROOT = auto`, `macosx` in `SUPPORTED_PLATFORMS`, one bundle ID | **DONE** | § 1. Do **not** add a second "Pawmodoro Mac" target; `HEARTH_PLAN.md` Phase 7 says to and is wrong. |
| 2 | `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` → `Pawmodoro/Mac/Pawmodoro.entitlements`, App Sandbox and nothing else | **DONE** | Verified in the archived Release build: signed entitlements are exactly `app-sandbox`, `application-identifier`, `team-identifier`. § 3.1. |
| 3 | Prove the sandbox does not break StoreKit | **DONE** | § 3.3. Answer: no entitlement needed, and the reason is in Apple's own sandbox profile. |
| 4 | Prove the sandbox does not break `PhotosPicker` | **DONE** (8–9 Aug) | § 3.2. The picker is permitted; the *control* to reach it does not render on macOS — that is step 6. |
| 5 | **The macOS app icon** | **DONE** (9 Aug, `b50a7c3`) | Proven in a built Mac bundle, not inferred: `CFBundleIconName = AppIcon` and `CFBundleIconFile = AppIcon` in the built `Info.plist`, a 37,266-byte `Contents/Resources/AppIcon.icns`, and the ten-rung `mac` ladder in `Assets.car`. § 5.1 has the geometry and the two traps. Do not use `assetutil --info \| grep -c AppIcon` to check it — it counts the twenty `iconpreview_AppIcon*` renditions belonging to the alternate-icon picker. |
| 6 | **The menu bar extra draws the buddy at ~400 pt** | **DONE** (9 Aug, `e83cc81`) | 418 × 402 points → 36 × 24. `BuddySprite` is rendered once through `ImageRenderer` at the PNG's native size and cropped to the **union** of the awake and asleep poses, so the buddy does not visibly grow when it lies down. The screenshots **have** been re-shot since — step 18 — and shot 01 in `mas-assets/` is the real 72 × 24 capture at 1:1 plus the same pixels at 6×. |
| 7 | **The Scrapbook has no import control on macOS** | **DONE** (10 Aug) | Fixed in the *content*, not the toolbar: `ScrapbookView.keepPicker` is a `PhotosPicker` worn twice, as the grid's first "+ Keep one" tile and as the empty state's button. A Mac sheet has no window toolbar, and SwiftUI silently drops `.navigation` / `.primaryAction` there while keeping `.confirmationAction` — so the phone's "+" rendered nothing and the Scrapbook had no way in at all. One control drawn by the same code on both platforms, not a Mac variant. |
| 8 | **The old snail stands on the ambience row** | **DONE** (10 Aug) | `SoundStudioView` no longer references the snail; she is drawn from `ContentView` with the rest of the scenery. |
| 9 | **The listening pass on real Mac hardware** | **OWNER** | Headphones *and* built-in speakers; change the output device **while a track is playing**. This is build 2's scar — all fifty tracks were unplayable on every real iPhone and no simulator could show it. A Mac's output device is 48 kHz or 44.1 and changes mid-session. Nobody but the owner has ears on this machine. |
| 10 | Optional polish: `NSHumanReadableCopyright`, SDK-conditional `INFOPLIST_KEY_NSSupportsLiveActivities`, a `Settings` scene for ⌘,, the two compiler warnings | **three of four done** | The two `Info.plist` ones are **done, seen in a build, and guarded**: the macOS Debug bundle reads `NSHumanReadableCopyright = "Copyright © 2026 Cheng Zhang. All rights reserved."` and `NSSupportsLiveActivities = 0`, while the same setting gives the Simulator build `1` (the box under "Should fix" says why naming one SDK is not enough). `tools/check_icons.py` now fails if either regresses. **The ⌘, scene is done** — `PawmodoroApp.settingsScene` is a `Settings` scene wrapping the same `SettingsView` the sheet uses, driven rather than assumed (pressing it removes the window from the process's accessibility window list, and ⌘, brings it back). **The two compiler warnings are still open** — re-measured on 10 Aug in fresh Release builds of both platforms, see "Should fix". |
| 10b | **The promo-code field is fenced out of Release** | **DONE and proven** (9–10 Aug) | `Store/PromoCode.swift` and `Views/RedeemCodeView.swift` are each wrapped whole in `#if DEBUG`, first line to last, and the "Redeem a code" row in `SettingsView` with them. That is a fence you cannot verify by reading, because a `#if` that is correct in the source and wrong in the build settings looks identical — so it was checked in the **product**: the symbols are **absent from both Release binaries**, iOS and macOS, and **present in both Debug** ones. It matters more than its size suggests: a shipped app that can redeem its own codes gives Plus away outside StoreKit, which is a rejection and a revenue hole at once. Written down nowhere until now. |
| 10c | **The Mac UI repair pass** — onboarding button, paged deck, year card, window geometry | **DONE** (10 Aug), driven not eyeballed | Four bugs, each measured after the fix. (a) The onboarding primary button hung its frame/padding/`.background` *outside* the `Button`, so only the text label was a control and the pink capsule was dead pixels on **both** platforms — and on macOS AppKit drew its own 46 × 20 white push button inside our pill. Styling moved into the `Button`'s label plus `.contentShape(Capsule())`; AX now reports 406 × 48 where it reported 46 × 20, and a tap at x = 70 on bare capsule advanced the page on iOS. (b) `.tabViewStyle(.page)` was shimmed to `DefaultTabViewStyle` on macOS, which is a **real AppKit tab bar** — three unlabelled chips clipped by the sheet's corner. New `Views/Style/PagedDeck.swift`: iOS keeps the exact `TabView` paging that shipped, macOS gets the selected page plus a named control row. AX now reports 0 tab groups and 0 radio buttons. **Both macOS shims are deleted from `Platform.swift`**, so `.tabViewStyle(.page)` now fails the Mac build instead of silently drawing chips. (c) `YearKeptView` had the identical broken `TabView` and no forward control, stranding a Mac reader on card 1 of 5; moved to `PagedDeck`, and a dot click was driven to card 5. (d) `Platform.macWindow` is now 460 × 860 — the size that actually ships — instead of the never-honoured 480 × 900, `macWindowMinimum` height dropped 860 → 700 of content so the window fits a 1440 × 900 display, `ContentView.mainColumn` always takes `adaptiveColumn` on macOS so a short window is a smaller screen rather than a broken one, and `MacWindowRules.place()` states the opening frame to AppKit and clamps it to `screen.visibleFrame`. Two things measured from inside the running app while doing that: `window.frameAutosaveName` is **empty** under a SwiftUI `WindowGroup`, and SwiftUI writes `NSWindow Frame main-AppWindow-1` and then ignores it under `.windowResizability(.contentSize)` — so this app had **never** remembered its Mac window size. `place()` reads that key, so it does now. |

### Phase 2 — signing and packaging (all rehearsed, nothing uploaded)

| # | Step | Status | Notes |
|---|---|---|---|
| 11 | `xcodebuild archive` for `generic/platform=macOS` | **DONE** | `** ARCHIVE SUCCEEDED **`. Universal `arm64` + `x86_64`, 40 MB `.app`, `LSMinimumSystemVersion 14.0`, no `Contents/PlugIns` (the widget is correctly iOS-only). |
| 12 | `xcodebuild -exportArchive -exportOptionsPlist … method=app-store-connect` | **DONE** | `** EXPORT SUCCEEDED **` → `Pawmodoro.pkg`, 38,028,796 bytes, app signed `Apple Distribution: Cheng Zhang (6YFQ69HSD6)`, installer signed `3rd Party Mac Developer Installer: Cheng Zhang (6YFQ69HSD6)`, `embedded.provisionprofile` present. § 4.2. |
| 13 | Same rehearsal for iOS, so the shipped app is not broken by the entitlement change | **DONE** | `Pawmodoro.ipa`, 34,717,389 bytes, app + `PawmodoroWidgetsExtension.appex` both signed and both carrying `application-groups`. § 4.2. |
| 14 | Certificates and profiles | **DONE — nothing to do** | Xcode created every missing profile on demand and used a **cloud-managed** Apple Distribution certificate. The Keychain still holds only "Apple Development"; that is correct and expected. § 4.2. |
| 15 | **Validate the package against App Store Connect** (`altool --validate-app`, or the Organizer's Validate button) | **OWNER** | `altool` still exists (v26.10.1) and still has `--validate-app`. It needs an app-specific password or an API key — entering credentials is the owner's alone. This is the last cheap failure before upload. |

### Phase 3 — App Store Connect (every step is OWNER)

| # | Step | Status | Notes |
|---|---|---|---|
| 16 | Apps → **Paawmodoro** → **Add Platform → macOS**. **Not a new app.** | **OWNER** | A second app record loses Universal Purchase permanently and orphans the paying iOS users. § 2. Reversible until the Mac version is *approved*, not until the click. |
| 17 | Check "iPhone and iPad Apps on Mac" in Pricing and Availability | **OWNER** | With `TARGETED_DEVICE_FAMILY = 1` the iOS build may already be offered on Apple Silicon Macs. Two Pawmodoros in one search result is a bad look. Account state; not visible from the repo. |
| 18 | macOS 1.0 metadata: description, keywords, screenshots, category (Productivity), support URL, review notes | **OWNER** — screenshots are done | **Re-shot 10 Aug**, after the menu-bar fix, from `HEAD = 2897944`: ten at 1440 × 900 in `mas-assets/plain/` and the same ten captioned in `mas-assets/captioned/`. Upload one folder or the other, never a mix. RGB, no alpha, asserted by `mas-assets/tools/build.py`. Six of the ten are real running focus phases. Do **not** upload anything from `mas-assets/raw/` — it is evidence, shot from a Debug build, and its Settings capture shows the "Redeem a code" button Release does not have. Lead the description with the menu bar; it is the thing the phone cannot do. |
| 19 | Sign into a **Sandbox Apple Account** (System Settings → Developer) and drive the real paywall: products list, buy Plus, relaunch, Restore | **OWNER** | The only part of § 3.3 that cannot be closed from here — it needs an Apple Account password. What is already proven is that if this fails, **the sandbox is not why**, and `network.client` will not fix it. |
| 20 | Archive → Organizer → **Distribute App → App Store Connect → Upload** | **OWNER** | Or `altool --upload-app -f Pawmodoro.pkg -t macos` with the exact `.pkg` step 12 produces. **Not reversible.** |
| 21 | Attach the processed build, answer export compliance, submit | **OWNER** | Export compliance is pre-answered in the bundle (`ITSAppUsesNonExemptEncryption = NO`); App Store Connect still asks. |
| 22 | Come back and write down what actually happened | **OWNER** | Especially anything review asked for. |

### The three things that would sink the submission if forgotten

1. **The icon** (step 5) — *done*, and left at the top of this list because of
   how it hid. Xcode's own `builtin-validationUtility -validate-for-store`
   **passed** on a build with no icon at all, so nothing local warned. It is
   guarded now by `tools/check_icons.py --bundle`, which is opt-in: if you
   change the asset catalogue, run it against a real build.
2. **Add Platform, not a new app** (step 16). One wrong click, permanent.
3. **The listening pass** (step 9). It has failed on real hardware before, on
   this exact class of bug, and no simulator or checker can see it.
4. **A build number that goes past 2** (step 20). Build 2 is live. The app and
   the widget extension must move **together** — `tools/check_icons.py` fails
   if they disagree, and `docs/SHARE_WITH_TESTERS.md` used to tell you to bump
   only one.

---

## SHOULD FIX — will not block review, will make the app feel wrong

| Item | Detail |
|---|---|
| ~~**The menu bar extra is broken.**~~ | **Fixed 9 Aug, `e83cc81`** — 418 × 402 points down to 36 × 24, the buddy rendered once through `ImageRenderer` and cropped to the union of both poses. Checklist step 6. |
| ~~**The Scrapbook has no import control on macOS.**~~ | **Fixed 10 Aug** — checklist step 7. The picker moved into the sheet's *content*, so one control serves both platforms. Still decide § 3.5's camera question; the answer no longer depends on this. |
| **The Mac window is a phone column.** | Partly addressed 10 Aug — checklist step 10c. The width clamp stays and is still deliberate (`Platform.swift`: the scenes are exported at 396×858 and a wide window crops the art to a band of sky). What changed is that the *height* is now honest: `macWindow` is 460×860, the size that actually ships, and `macWindowMinimum` is 460×700 of content so the window fits a 1440×900 display. It will not fail review. A Mac app that cannot be zoomed still reads as a port, and that is the first thing a Mac user notices. |
| ~~**No ⌘, (Settings) and no Help menu.**~~ | **⌘, fixed** — checklist step 10. `PawmodoroApp.settingsScene` is a real `Settings` scene wrapping the same `SettingsView` as the sheet, so there is no "which door am I behind" branch inside the view. `CommandGroup(replacing: .help) { }` still empties the Help menu deliberately. |
| **iOS-only keys in the Mac `Info.plist`.** | `UILaunchScreen`, `UIApplicationSceneManifest`, `UIApplicationSupportsIndirectInputEvents`, `UISupportedInterfaceOrientations~iphone/~ipad` are all still there; macOS ignores them and they are cosmetic. `NSSupportsLiveActivities` was the one that was a *claim*, and it is **fixed** — see the box below for the setting that does it and the one that looks right and is not. |
| **`NSCameraUsageDescription` ships with no camera behind it.** | `Views/CameraPicker.swift` is entirely inside `#if canImport(UIKit)`. Cosmetic — but see § 3.5. |
| ~~**`NSHumanReadableCopyright` is unset.**~~ | **Fixed.** `INFOPLIST_KEY_NSHumanReadableCopyright` is now set on all four configurations — the app's two and the widget extension's two, because an extension has an About-less bundle that App Store Connect still reads. |
| **Two compiler warnings — still open, re-measured 10 Aug.** | Fresh Release builds of both platforms emit exactly these two. `Animation/BuddyAnimator.swift:219:35` — *reference to captured var 'self' in concurrently-executing code; this is an error in the Swift 6 language mode*. `Views/GardenView.swift:82:31` — *immutable value 'kind' was never used*. Neither affects review. The first will stop a Swift 6 migration cold, and adding `[weak self]` did not silence it — the capture is of the `var`, not the value. |
| **A bare Space bar is bound as a menu shortcut.** | `MenuBarControls` binds `.keyboardShortcut(.space, modifiers: [])` to Start/Pause, and `PawmodoroApp`'s own comment three files away says not to. Partly answered 9 Aug: read through the accessibility API the *main* menu bar carries no Space (`Session ▸ Start` has an empty `AXMenuItemCmdChar`; only `Give It a Shake` has one, ⌘K), so the binding lives in the `MenuBarExtra` menu alone, whose key equivalents are live only while that menu is open. **VERIFY** by typing a space into the rename field once. |

### `INFOPLIST_KEY_*` and `[sdk=…]` — measured, and the obvious fix is wrong

This used to be a **VERIFY**, and the fix it prescribed —
`INFOPLIST_KEY_NSSupportsLiveActivities[sdk=iphoneos*]`, on its own — was
**measured on Xcode 26.3 and is a bug**. Do not write it that way.

`INFOPLIST_KEY_*` does accept an `[sdk=…]` condition. What it does not do is
drop the key when the condition misses. Three states, each built and each read
back out of the product with `plutil -p`:

| Build setting | `NSSupportsLiveActivities` in the built `Info.plist` |
|---|---|
| absent entirely | key absent |
| `[sdk=…]` condition **does not** match this SDK | key present, **`0`** |
| `[sdk=…]` condition **does** match | key present, `1` |

Re-confirmed in two products built from the current tree on 10 Aug, rather than
taken from the earlier write-up: the macOS Debug `.app` reads
`"NSSupportsLiveActivities" => 0` and the `Debug-iphonesimulator` `.app` reads
`=> 1`. Same setting, same build, opposite answers — which is the whole point.

`GENERATE_INFOPLIST_FILE` writes one entry for every `INFOPLIST_KEY_` name
that appears anywhere in the settings table; an unmatched condition evaluates
to the empty string, and the empty string lands as boolean false. So
conditioning on `iphoneos*` alone silently ships **`NSSupportsLiveActivities =
0` on `iphonesimulator`** — and the Simulator is this repo's entire
verification loop. You would find out by wondering why the Live Activity
stopped appearing.

What is in the project, on both configurations of the app target:

```
"INFOPLIST_KEY_NSSupportsLiveActivities[sdk=iphoneos*]" = YES;
"INFOPLIST_KEY_NSSupportsLiveActivities[sdk=iphonesimulator*]" = YES;
```

`false` is the honest answer on a Mac, so that is where this stops. Making the
key vanish on macOS would take a hand-written macOS `Info.plist` — a second
source of truth for everything else in it, to remove a key macOS ignores.

`tools/check_icons.py` holds both halves: a **static** rule over
`project.pbxproj` that runs on every plain invocation, including on Linux, and
a `--bundle` rule that reads a built Mac bundle's `Info.plist`. The static one
was broken three ways deliberately — reverted to unconditional, conditioned on
`iphoneos*` alone, and deleted outright — and caught all three.

## CAN SHIP AS IS — do not spend time on these

- **Haptics do nothing.** Deliberate no-op on macOS; nobody expects a buzz from a Mac.
- **No Live Activities.** iOS-only by construction; `LiveActivity/` is fenced behind `#if os(iOS)`.
- **No shake gesture.** No accelerometer. ⌘K and the "Give it a shake" menu item both call the same `SceneShake.shared.shake()`.
- **No home-screen widget.** `PawmodoroWidgetsExtension` is `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"` and carries `platformFilter = ios` on both its dependency and its embed phase. Re-verified in the 9 Aug archive: the Mac `.app` has no `Contents/PlugIns`. Just do not mention widgets in the Mac listing.
- **The app-group write is a no-op on the Mac.** `TimerEngine.settingsDidChange()` writes two keys to `UserDefaults(suiteName: "group.com.pawmodoro")` for the widget. With no widget and no app-groups entitlement it lands in the app's own container and nothing reads it. **Do not add App Groups to the Mac entitlements to "fix" this** — there is nothing to fix, and note the macOS form would have to be `6YFQ69HSD6.group.com.pawmodoro` anyway.
- **40 MB `.app` / 38 MB `.pkg`.** `CLAUDE.md` retired the 45 MB ceiling; the rule that survives is *measure it and say the number*, which is what those figures are.

---

## Driving the Mac build — `tools/mac_probe.py`

The owner works at this machine while the Mac build is being checked, so
anything that moves the cursor, clicks, or pulls a window in front of what he
is typing into is off the table — which rules out every desktop-automation
tool there is. `tools/mac_probe.py` is what is left, and it is enough for
nearly everything: it launches the built `.app` detached so it never becomes
frontmost, lists its windows with their real sizes off `CGWindowList`,
photographs a window **by id** with `screencapture -l` even when that window
is behind another app or shoved half off the screen, presses controls through
the accessibility API with no pointer involved, and quits what it started.
Read its docstring before using it; every claim in there was measured on this
Mac rather than hoped for.

Two things to take from it before you start. `windows()` is often *better*
evidence than a screenshot — the menu bar extra bug was "416 × 24 where it
should be 36 × 24", which is one line of output and nothing to squint at. And
**wrap anything that seeds state in `preserve()`**: redirecting `HOME` does not
isolate the app (CFPreferences resolves the home directory out of the passwd
database), so a run with `-PawmodoroBond 200` rewrites the owner's real
preferences unless something puts them back.

The one thing it cannot do is hover: a posted mouse-moved event does not drive
SwiftUI's `.onHover`, because the window server synthesizes enter and exit from
the real cursor. Verify a hover *appearance* by rendering the hovered state
directly, and the *wiring* by reading the code. Never claim you saw one.

---

## 1. What kind of Mac app is this?

**A native macOS app from a single multiplatform SwiftUI target.** Not Catalyst,
not "Designed for iPad". Read out of `project.pbxproj`:

| Setting | Value |
|---|---|
| `SDKROOT` | `auto` |
| `SUPPORTED_PLATFORMS` | `iphoneos iphonesimulator macosx` |
| `SUPPORTS_MACCATALYST` | absent → `NO` |
| `MACOSX_DEPLOYMENT_TARGET` | `14.0` (Sonoma) |
| `IPHONEOS_DEPLOYMENT_TARGET` | `17.0` |
| `TARGETED_DEVICE_FAMILY` | `1` (iPhone) — macOS ignores it |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.pawmodoro.zhangcheng` — **the same on both platforms** |
| `DEVELOPMENT_TEAM` | `6YFQ69HSD6` |
| `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` | `1.0` / `2` |

Why it matters, one line each:

- **Universal Purchase is free.** One target, one bundle ID — the hard
  requirement (§ 2) — and you cannot get it wrong by accident.
- **Entitlements must be SDK-conditional**, because the same target produces
  the iOS build (§ 3.1).
- **`Info.plist` keys are shared**, which is why iOS keys leak into the Mac
  bundle.
- **macOS 14 is the floor**: `MenuBarExtra` needs 13, `PhotosPicker` needs 13,
  `Observable` needs 14. Do not lower it.

`HEARTH_PLAN.md` § "Phase 7 — What is not written" says to create a second
target. **Do not.** That doc is out of date; this one supersedes it.

---

## 2. Universal Purchase — yes, and the precondition is already met

Someone who bought Plus on their iPhone gets the Mac app free and keeps Plus,
**as long as macOS is added as a platform on the existing app record**.

Apple requires the macOS app to share the iOS app's bundle ID, Apple ID and
SKU. With one target, `com.pawmodoro.zhangcheng` is already the bundle ID on
both platforms. In-app purchases live on the app record, not on a platform
version, so `com.pawmodoro.zhangcheng.plus` and the three tips serve macOS with
no new records and no new prices.
([Add platforms — App Store Connect Help](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms/))

**Steps:** Apps → Paawmodoro → sidebar **Add Platform** → **macOS** → Add.

**Is it one-way?** A platform can be removed while no build has ever been
uploaded for it and at least one version is editable. Once Review has approved
**two** platform versions the app is universal-purchase permanently. So the
point of no return is the Mac version's *approval*, not the click.

- **`AppStore.sync()` already handles restore.** `StoreManager.restore()` calls
  it and `refreshEntitlements()` re-derives `hasPlus` from
  `Transaction.currentEntitlements`; `applyEntitlement(hasPlus:)` already
  reasons about revocation. Signing into the same Apple Account is the whole
  Mac story. No code to add.
- **Version numbers are per platform.** macOS starts its own train at 1.0.
  `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` are shared build settings, so
  an iOS bump moves the Mac's numbers too. Harmless — build numbers only have
  to be unique within a platform's train.

---

## 3. App Sandbox and the entitlements

### 3.1 The file, and how it is wired

`Pawmodoro/Mac/Pawmodoro.entitlements` contains exactly one key:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```

It is wired per-SDK in `project.pbxproj`:

```
CODE_SIGN_ENTITLEMENTS[sdk=macosx*]          = Pawmodoro/Mac/Pawmodoro.entitlements
CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]        = Pawmodoro/iOS/Pawmodoro.entitlements
CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*] = Pawmodoro/iOS/Pawmodoro.entitlements
```

with the unconditional value empty, so neither platform inherits the other's
claims. **Never use the Signing & Capabilities tab's "App Sandbox" button** —
it writes an unconditional value and the iOS build starts signing with an App
Sandbox entitlement it has no business carrying.

What the shipping `.pkg` actually carries, read back out of the exported
payload on 9 Aug:

```
com.apple.application-identifier   6YFQ69HSD6.com.pawmodoro.zhangcheng
com.apple.developer.team-identifier 6YFQ69HSD6
com.apple.security.app-sandbox      1
```

Three points still worth knowing:

- `plutil -lint` passes on the file.
- **It is not copied into the bundle.** `Pawmodoro/` is a file-system
  synchronized group, so this was a real worry; `Contents/Resources` contains
  no `.entitlements`. (Check with `ls Pawmodoro.app/Contents/Resources | grep
  entitle` if a future Xcode changes it.)
- **Never add `com.apple.security.get-task-allow`.** Xcode injects it for
  debugging and strips it when archiving; a copy in the file would survive into
  the archive and the upload is rejected.

**Hardened Runtime is not required for the Mac App Store** — it is a
notarization / Developer ID concern. Leave `ENABLE_HARDENED_RUNTIME` off.

### 3.2 What each subsystem actually needs

| Subsystem | Where | Entitlement | Why |
|---|---|---|---|
| **Network** | Nowhere — zero hits for `URLSession`, `NWConnection`, `http://`, `https://` across every `.swift` | **None** | `docs/PRIVACY.md` says the app makes no network requests and that sentence has to stay true. Proven from the outside too: § 3.3's probe shows a sandboxed process with these exact entitlements **cannot** open a socket, and the app runs with zero network denials — it never tries. |
| **Scrapbook import** | `ScrapbookView` → `PhotosPicker` → `loadTransferable(type: Data.self)` | **None** | Verified 9 Aug: the picker extension launched, a photo was chosen, `SnapshotImport.prepare` ran, a 116,530-byte JPEG landed in the container, zero denials. The EXIF strip holds on the macOS `renderJPEG` path — the only surviving metadata is a pixel-dimension pointer and an empty Photoshop block. |
| **Scrapbook storage** | `Model/Snapshot.swift`, `.documentDirectory` | **None** | Inside the container already. |
| **Settings, history** | `UserDefaults` | **None** | Container-local. |
| **Audio** | `AVAudioEngine` on bundled `.m4a`/`.wav` | **None** | Playback of bundled files. `device.audio-input` is the microphone; there is none. |
| **Local notifications** | `NotificationManager`, `UNUserNotificationCenter` | **None** | `(usernotifications)` is granted to every sandboxed app in Apple's profile, same as `(storekit)`. |
| **Sharing a postcard** | `ShareLink` + `Transferable` | **None** | `NSSharingService` runs out of process. |
| **StoreKit** | `Store/StoreManager.swift` | **None — proven** | § 3.3. |
| **Camera** | `Views/CameraPicker.swift`, inside `#if canImport(UIKit)` | **None** | There is no camera code in the Mac build. § 3.5. |
| **App Groups** | `TimerEngine.swift:1302` | **None, on purpose** | The only reader is the iOS-only widget. |

### 3.3 StoreKit under the App Sandbox — ANSWERED

**StoreKit needs no entitlement. Do not add `com.apple.security.network.client`.**

Three independent pieces of evidence, in increasing order of how much they
prove.

**(a) Apple's own sandbox profile says so — this is the primary source.**
`/System/Library/Sandbox/Profiles/appsandbox-common.sb`, lines 689-696:

```scheme
(define (storekit)
  (allow mach-lookup
         (global-name
           "com.apple.storeagent.storekit"
           "com.apple.storeagent.storekit.receiptrenewal"
           "com.apple.storekit.configuration.xpc"
           "com.apple.storekitagent"
           "com.apple.storekitservice")))
```

and `/System/Library/Sandbox/Profiles/application.sb` line 691 invokes
`(storekit)` unconditionally, in the same breath as `(usernotifications)` and
`(coreaudio-services)`. **Every App Sandbox app on macOS gets these five mach
services with no entitlement, no capability, and no review question.** That is
the whole mechanism: the purchase UI, the network and the transaction work
happen in Apple's daemon, and all the app is allowed to do is talk to it.

Note `com.apple.storekit.configuration.xpc` in that list — that is the *local
`.storekit` configuration* service, so Xcode's StoreKit testing also works
against a sandboxed build.

**(b) A sandboxed Release build behaves identically to an unsandboxed one.**
Both runs are the same archived Release binary; the second was re-signed ad-hoc
with no entitlements as a control. `StoreManager.loadProducts()` is called at
launch from `PawmodoroApp.swift:32`, so this needs no navigation.

Sandboxed (`Apple Development`-signed, `com.apple.security.app-sandbox` only):

```
Pawmodoro[86294] (libsystem_secinit.dylib) AppSandbox
Pawmodoro[86294] [com.apple.xpc:connection] activating connection: mach=true … name=com.apple.storekitagent
Pawmodoro[86294] [com.apple.storekit:Default] [06ab5cd2_SK2] Starting product request
Pawmodoro[86294] [com.apple.storekit:Default] [06ab5cd2_SK2] Decoded product response
Pawmodoro[86294] [com.apple.storekit:Default] [06ab5cd2_SK2] Finished product request
Pawmodoro[86294] [com.apple.storekit:Default] [06ab5cd2_SK2] Parsing 0 products in response
Pawmodoro[86294] [com.apple.storekit:Default] Error … Domain=ASDErrorDomain Code=509
```

Unsandboxed control (`Pawmodoro[86195]`): **no `AppSandbox` line**, and then
the same four StoreKit lines and the same `ASDErrorDomain Code=509`. The mach
lookup succeeds in both, the request round-trips in both, the response decodes
in both. The sandbox is not a variable in this experiment.

**The "0 products" is not the sandbox either.** `ASDErrorDomain Code=509` is
"no store account", and it appears in the unsandboxed run too. A local build
with no signed-in Apple Account and no App Store receipt gets an empty
catalogue, which is the correct answer for both builds and is exactly the
"store isn't available" state `CLAUDE.md` says is not a bug.

**(c) A negative control, because "no denials" is worthless if denials were
never visible.** A separate ad-hoc app bundle
(`com.pawmodoro.sandboxprobe`) signed with *this app's exact entitlements
file* tried two things:

| | Unsandboxed | Sandboxed with `Pawmodoro/Mac/Pawmodoro.entitlements` |
|---|---|---|
| `URLSession` GET `https://www.apple.com/` | `OK 254160 bytes` | `FAILED — A server with the specified hostname could not be found.` |
| List `/Users/zhangcheng/Desktop` | `OK 22 entries` | `FAILED — you don't have permission to view it` |

So the sandbox in this file is genuinely on and genuinely restrictive: it
blocks the process's own network completely. **StoreKit works anyway**, which
is the point — the network is not happening in this process.

#### What this means for App Review

The reviewer tests with a real Sandbox Apple Account against App Store Connect,
not with a local `.storekit` file. The thing that could have broken that —
"the app requests no network entitlement, and StoreKit obviously needs the
network" — is now answered: **StoreKit's network is not the app's network.**
The app is allowed to reach `storekitagent` by Apple's default profile, and the
daemon does everything else in its own address space, under its own
entitlements. Adding `network.client` would grant this app a capability with no
code behind it and would not change any StoreKit outcome.

**What is still not proven, and cannot be from here:** that products *list*,
that a sandbox purchase completes, that the entitlement survives a relaunch,
and that Restore finds it. All four need an Apple Account password typed into
System Settings, which is the owner's step (checklist 19). If any of them fails,
**the sandbox is not the reason** and `network.client` is not the fix — look at
the App Store Connect product records, the agreements, and whether the products
are in "Ready to Submit".

### 3.4 How to look for a sandbox denial — the old method could not see one

This matters more than the finding it produced.

Every earlier pass in this repo checked for sandbox denials with a predicate on
the app's own process, e.g.

```sh
/usr/bin/log show --last 5m --info --debug \
  --predicate 'processImagePath CONTAINS "Pawmodoro"' | grep -i deny   # WRONG
```

and reported "zero denials". **That predicate can never return a denial.**
Sandbox violations are emitted by **`sandboxd`**, under the
`com.apple.sandbox.reporting:violation` subsystem, with the offending process
named *inside* the message. Filtering on the app's process filters them out.

Proved by breaking it: the probe from § 3.3(c) was denied two mach lookups, and
`--predicate 'process == "SandboxProbe"'` returned **nothing**, while

```sh
/usr/bin/log show --last 5m --info --debug --predicate 'process == "sandboxd"' \
  | grep -oE 'Sandbox: [A-Za-z]+\([0-9]+\) deny\([0-9]\) [a-z-]+ ?[^ ]*' | sort | uniq -c
```

returned them immediately. Use that. (`log` is a zsh builtin — the absolute
path matters.)

**And with the right predicate, Pawmodoro does have one denial**, on every
sandboxed launch, missed by every previous pass:

```
Sandbox: Pawmodoro(86294) deny(1) hid-control
```

No target, no `errno` beyond 1, fired ~0.4 s after launch, in both sandboxed
runs and never in the probe (which has no AppKit). Nothing visible failed
because of it, and a bare `hid-control` denial at launch is common in sandboxed
AppKit apps — but it is a real refusal in the shipping configuration and
nothing else in this repo would ever have found it. **VERIFY** what asks for
it: the suspects are the `MenuBarExtra`'s key equivalents, `NSEvent` modifier
polling, and anything that touches `IOHIDManager`. If it turns out to be the
bare-Space shortcut, two open questions collapse into one.

### 3.5 A decision you have to make: the Mac camera

`HEARTH_PLAN.md` § Phase 7 promised *"camera entitlement (the Scrapbook works
from a MacBook — a photo of the desk you're actually at)"*.

**As the code stands there is no camera on the Mac at all.** `CameraPicker` is
a `UIViewControllerRepresentable` around `UIImagePickerController` inside
`#if canImport(UIKit)`, and `ScrapbookView` guards its camera button with the
same fence.

- **Ship without it.** The Scrapbook still works — you pick an existing
  picture. Zero new entitlements, zero new review questions. This is what the
  entitlements file assumes. **Recommended for macOS 1.0.**
- **Build it later** as an `AVCaptureSession` (there is no
  `UIImagePickerController` on macOS, so this is real work, not a shim) and add
  `com.apple.security.device.camera`. `NSCameraUsageDescription` is already in
  the shared build settings.

Either way, correct `HEARTH_PLAN.md` so nobody adds a camera entitlement for
code that is not there. An entitlement with nothing behind it is a question in
review you answer with "sorry, ignore that".

If a Scrapbook import ever *does* fail, the two candidate fixes in order of how
little they claim: an `NSOpenPanel` / `.fileImporter` path plus
`com.apple.security.files.user-selected.read-only` ("the user handed me this
one file"), or `com.apple.security.personal-information.photos-library` (a much
larger claim your privacy label has to answer for). Prefer the first.

---

## 4. Signing and packaging

### 4.1 Notarization does not apply

**Mac App Store builds are not notarized by you.** Notarization is for software
you distribute yourself — Developer ID, downloaded from a website, checked by
Gatekeeper.
([Distributing software on macOS](https://developer.apple.com/macos/distribution/))
You will never run `notarytool` for this. If you find yourself reading
notarization instructions you have wandered into the wrong half of the docs.

### 4.2 Certificates and profiles — rehearsed end to end on 9 Aug

This is the section that used to be a list of worries. It is now a transcript.

**Starting state.** The Keychain held exactly one identity, `Apple Development:
Cheng Zhang (HN4SH472L4)` — **no** Apple Distribution, **no** Mac Installer
Distribution. The profile folder held four `.mobileprovision` files, all
`Platform = iOS`: a 5 Aug store profile `14421f73-…` **without**
`application-groups`, and three 8 Aug development profiles with it. **No macOS
profile of any kind existed, and no store profile for the widget extension.**
That was the worry: the store profile predated the app-groups entitlement, so
it could not sign the app any more.

**What actually happened.**

```sh
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro -configuration Release \
  -destination 'generic/platform=macOS' -archivePath …/Pawmodoro-mac.xcarchive \
  -derivedDataPath …/dd -allowProvisioningUpdates archive        # ** ARCHIVE SUCCEEDED **

xcodebuild -exportArchive -archivePath …/Pawmodoro-mac.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath …/mac-export \
  -allowProvisioningUpdates                                      # ** EXPORT SUCCEEDED **
```

with

```xml
<key>method</key>            <string>app-store-connect</string>
<key>destination</key>       <string>export</string>
<key>teamID</key>            <string>6YFQ69HSD6</string>
<key>signingStyle</key>      <string>automatic</string>
<key>uploadSymbols</key>     <true/>
```

`destination = export` is the safety catch: `upload` is the other value and it
does exactly what it says. Keep it `export` until step 20.

**Xcode created, on demand, every profile that was missing:**

| New profile | Platform | Created | Entitlements it carries |
|---|---|---|---|
| `be35c101-…` **Mac Team Store Provisioning Profile: com.pawmodoro.zhangcheng** (a `.provisionprofile`, not `.mobileprovision`) | `OSX` | 9 Aug | app-identifier, team-identifier, `application-groups` (superset — the app does not claim it), keychain-access-groups |
| `fbc3e468-…` iOS Team Store Provisioning Profile: com.pawmodoro.zhangcheng | iOS | 9 Aug | **now includes `application-groups = group.com.pawmodoro`** |
| `7454b217-…` iOS Team Store Provisioning Profile: com.pawmodoro.zhangcheng.PawmodoroWidgets | iOS | 9 Aug | app-identifier + `application-groups` |

The stale `14421f73-…` was **replaced and removed** from the folder in the
process. So: **the stale-profile blocker was never going to bite, because
`-allowProvisioningUpdates` regenerates the lot.** The rule to remember is that
a profile is a *superset* permission — the Mac store profile listing
`application-groups` while the Mac app does not claim it is fine; the reverse
would fail.

**Certificates: nothing to install.** Both exports signed with a **Cloud
Managed Apple Distribution** certificate (`Apple Distribution: Cheng Zhang
(6YFQ69HSD6)`, SHA-1 `38F8AFCD…`, expires 6 Aug 2027). Apple holds the key and
signs remotely — `Packaging.log` shows the `codeSignatures` round trip to
`developerservices3.apple.com`. `security find-identity -v` still lists only
"Apple Development" afterwards, and that is **correct, not a problem**. The
`.pkg` is signed `3rd Party Mac Developer Installer: Cheng Zhang (6YFQ69HSD6)`,
also cloud-managed. `pkgutil --check-signature` describes it as "signed by a
developer certificate issued by Apple (Development)" — that is pkgutil's
wording for any non-Developer-ID Apple certificate, and is what a Mac App Store
package is supposed to look like.

**What came out:**

| | Size | Signed app | Embedded profile |
|---|---|---|---|
| `Pawmodoro.pkg` (macOS) | 38,028,796 B | Apple Distribution, entitlements = app-identifier + team-identifier + **app-sandbox** | `Contents/embedded.provisionprofile` present |
| `Pawmodoro.ipa` (iOS, run as a regression check) | 34,717,389 B | app + `PawmodoroWidgetsExtension.appex`, both with `application-groups`, `get-task-allow = 0`, `beta-reports-active = 1` | per-target store profiles |

The iOS rehearsal matters: the per-SDK entitlements change (checklist 2) did
not break the shipping app's ability to be archived and exported for the store.

**The App ID is enabled for macOS.** It has to be — the portal minted a
`Platform = OSX` profile for `6YFQ69HSD6.com.pawmodoro.zhangcheng` without
being asked twice. That VERIFY is closed.

**Side effects of this rehearsal, so nobody is surprised:** three new
provisioning profiles are now in
`~/Library/Developer/Xcode/UserData/Provisioning Profiles/`, one old one is
gone, and the corresponding records exist on the developer portal. Nothing was
uploaded to App Store Connect and no app record was touched.

### 4.3 The upload route

**Use Xcode's GUI.** Destination **My Mac** → **Product → Archive** → Organizer
→ **Distribute App → App Store Connect → Upload**. Xcode signs the `.app`,
wraps it in the `.pkg` and uploads it. Then wait for the "processing complete"
mail and attach the build to macOS 1.0.

The command-line route is now known-good up to the last step — §4.2's two
commands produce exactly the `.pkg` the Organizer would. Two facts that used to
be VERIFY:

- **`method` spelling: `app-store-connect`.** Confirmed from `xcodebuild -help`
  in Xcode 26.3: *"Available options: app-store-connect, release-testing,
  enterprise, debugging, developer-id, mac-application, and validation …
  Additional options include app-store (deprecated: use app-store-connect)"*.
  There is also a `validation` method, which is worth knowing about.
- **`altool` still exists and still works.** `/Applications/Xcode.app/Contents/
  SharedFrameworks/ContentDelivery.framework/Resources/altool`, version
  26.10.1, still advertising `--upload-app`, `--validate-app` and
  `--upload-package`. Both need authentication (app-specific password or API
  key), which is why they are OWNER steps. **Transporter** from the Mac App
  Store is the GUI alternative. `notarytool` is not an upload tool and cannot
  do this.

---

## 5. What App Store Connect will demand that does not exist yet

### 5.1 The macOS app icon — was the one hard blocker, now closed

The 9 Aug 20:47 archive had **no** `CFBundleIconName` and **no**
`CFBundleIconFile`. `b50a7c3` put ten `AppIcon-mac-*` PNGs and a
`"idiom": "mac"` ladder into `AppIcon.appiconset` (11 images now, across `mac`
and `universal`), and a build made afterwards carries all of it:
`CFBundleIconName = AppIcon`, `CFBundleIconFile = AppIcon`, a 37,266-byte
`Contents/Resources/AppIcon.icns`, and the renditions in `Assets.car`.

Do not trust `assetutil --info | grep -c AppIcon` — it counts the twenty
`iconpreview_AppIcon*` renditions belonging to the alternate-icon picker. The
check that means anything is `CFBundleIconName` in the built `Info.plist`.

**One number that was overstated, corrected here because this repo's rule is to
say the measured one.** The icon write-up called the round trip through the
build "BYTE-IDENTICAL … mean absolute difference 0.0/255". It is not
byte-identical, and 0.0 was a `%.1f` of something that is not zero. Two
measurements, both of the same thing — *does the art survive being compiled
into the product* — and neither changes the conclusion by a hair:

| Comparison | mean | max channel | pixels differing |
|---|---|---|---|
| `NSWorkspace` render of the built bundle vs. the source PNG, 1024 × 1024 | **0.002/255** | **11** | **1,836 of 1,048,576** |
| `AppIcon.icns` unpacked with `iconutil` vs. the source PNGs — 128@2x | 0.012/255 | 34 | 398 of 65,536 |
| the same, 128@1x | 0.046/255 | 51 | 182 of 16,384 |
| the same, 16@2x | 0.096/255 | 51 | 31 of 1,024 |
| the same, 16@1x | **2.53/255** | **137** | 33 of 256 |

Provenance, since the whole point of the correction is provenance: the
`NSWorkspace` row was measured by the verification pass that caught the
overstatement; the four `.icns` rows were measured here on 10 Aug, headlessly,
by unpacking the `AppIcon.icns` out of a Debug Mac build made 9 Aug 22:44 with
`iconutil --convert iconset` and differencing it against
`Pawmodoro/Assets.xcassets/AppIcon.appiconset/`. That `.icns` holds only four
sizes — 16, 16@2x, 128, 128@2x — because it is the legacy fallback; the full
ladder lives in `Assets.car`.

The pattern is what you would expect from a resampling and re-encoding round
trip and not from a wrong picture: a handful of edge pixels, worst where there
are fewest of them. At 16 × 1 the body is 13 px, so a third of a pixel of
difference on the rounded corner is 2.5/255 averaged over the tile. The
conclusion — *the art in the bundle is our art* — is untouched. The claim that
it was byte-identical was not measured, it was read off a rounded print.

`tools/check_icons.py` says the live version of that number every run
(`macOS art: 512@2x matches the shipped drawing to 0.1/255`), with the failure
bar at 4.0 — comfortably above resampling noise and far below a stale icon.

Two separate problems, both now solved — kept here because the next person to
add a platform meets them again:

**The sizes.** macOS needs the full ladder — 16, 32, 128, 256, 512 pt at 1× and
2×. **ANSWERED 8 Aug: a single 1024 in the macOS slot is not sufficient**; the
ten-entry `"idiom": "mac"` ladder is required, and adding it does not disturb
the iPhone icon (`MAC_STORE_ASSETS.md` § 1). App Store Connect takes the
listing icon from the bundle; there is no separate Mac icon upload.

**The shape, which matters more.** The old PNG was 1024×1024, mode `RGB` —
opaque, full-bleed, square. Correct for iOS, where the system rounds the
corners. On macOS **nothing rounds it**, so Pawmodoro would have sat in the
Dock as a hard square among thirty rounded rectangles and read as a bug. A
macOS icon is drawn *inside* a smaller rounded rect on a transparent 1024
canvas, with its own shadow.

The geometry is settled and it was **measured rather than read off the HIG**,
which is the better answer to the VERIFY that used to sit here:
`NSWorkspace.icon(forFile:)` drawn at 1024 for fifteen installed apps, alpha
channels differenced. Fourteen of the fifteen agree to the pixel — an 824 × 824
body at (100, 100) with a corner radius of 185.5 px and a shadow of about
sigma 10, offset 10 down, peak alpha 0.30. (The fifteenth is Safari, whose icon
is a circle; Apple's grid lets a circle run wider.) Those numbers live in
`check_icons.py` as `APPLE_GRID`, deliberately **not** imported from the
generator, so editing the generator cannot talk the checker round.

And the folklore is wrong: it is **not** a squircle. A circular-arc rounded
rectangle fits the measured edge at 0.83 px mean error; a continuous
superellipse fits at 1.7 px — worse. They differ by about 2 px at 45° on a 1024
canvas. PIL draws the arc exactly, so `tools/generate_assets.py` draws the arc.

Xcode 26 also ships **Icon Composer** (`.icon` files). Not required at a macOS
14 deployment target, and a `.icon` would be a second source of truth for
artwork this repo generates — skip it.

### 5.2 Screenshots

Required: 1–10, **exactly** one of 1280×800, 1440×900, 2560×1600, 2880×1800,
16:10, `.png`/`.jpg`, **no alpha**.
([Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/))

Pawmodoro's window is a **400 × 900 point column** — 5:11, nothing like 16:10 —
so every screenshot is a composite: the window shot, scaled, on a legal canvas,
on the app's own cream→blush gradient rather than a stock desktop.

**Eight exist** at 1440×900, plain and captioned, from real running sessions —
`MAC_STORE_ASSETS.md` § 2. Two constraints on them: **the menu bar extra cannot
be the hero shot** until checklist step 6 is fixed, and **no dawn or dusk
grade** — those flatten the scenery to about a third of the day grade's
contrast, measured, which is what produced the earlier "flat beige wash".

### 5.3 Category and minimum version

- **Category is already correct.** `LSApplicationCategoryType =
  public.app-category.productivity` is in the built Mac `Info.plist`; that key
  *is* the macOS category. Pick **Productivity** in App Store Connect to match.
- **Minimum macOS: 14.0.** `LSMinimumSystemVersion = 14.0` in the bundle. App
  Store Connect reads it from the build; you do not type it anywhere.

### 5.4 What carries over, and what does not

**Carries over** (these live on the app record):

- In-app purchase records — Plus and all three tips, same product IDs.
- App privacy answers ("Data Not Collected") and the privacy policy URL.
  **VERIFY** that the privacy section is presented once per app rather than per
  platform — confident, unconfirmed.
- Age rating.
- Export compliance: `ITSAppUsesNonExemptEncryption = NO`, confirmed in the
  built Mac `Info.plist`.

**Written fresh for macOS:** screenshots; description, keywords, promotional
text and "What's New" (lead with the menu bar — it is what the phone cannot
do; `docs/APP_STORE_LISTING.md` has the iOS copy); support and marketing URLs;
review notes; copyright; pricing/availability confirmation.

One line worth putting in the review notes: *"No account, no network access.
Pawmodoro Plus is a one-time non-consumable, shared with the iOS app via
Universal Purchase."*

---

## 6. Everything still marked VERIFY

| § | Question | How to answer it |
|---|---|---|
| 3.3 | Do products list, does a purchase complete, does the entitlement survive relaunch, does Restore work? | Checklist 19 — needs a Sandbox Apple Account password. **If it fails, the sandbox is not why.** |
| 3.4 | What asks for `hid-control` at launch? | Instrument the `MenuBarExtra` shortcuts / `NSEvent` polling; it is the app's only sandbox denial |
| Should fix | Does the bare-Space menu shortcut swallow spaces in the rename field? | Open Settings, rename the buddy, type "Mister Whiskers" |
| 5.1 | Current HIG inset and corner radius for a macOS icon | Apple HIG → App icons → macOS |
| 2 | Is "iPhone and iPad Apps on Mac" currently on for the iOS app? | App Store Connect → Pricing and Availability (checklist 17) |
| 5.4 | Are App Privacy answers shared across platforms? | Visible once the platform is added |

**Closed since the last revision:** does StoreKit need `network.client` (no —
§ 3.3); does `PhotosPicker` need an entitlement (no); does Xcode regenerate the
distribution profiles (yes, all three — § 4.2); is the App ID enabled for macOS
(yes); what is the `method` spelling (`app-store-connect`); does `altool` still
work (yes); does Xcode 26 accept a single-size macOS icon (no); does the ten-rung
`mac` ladder actually reach the built bundle (yes — checklist step 5).

**Closed 10 Aug:** do `INFOPLIST_KEY_*` settings accept `[sdk=…]` conditions in
Xcode 26 — **yes, and the naive form is a trap.** The answer, the measurement
and the two SDKs it has to name are in the box under "Should fix", and
`tools/check_icons.py` now fails if either condition goes missing.

---

## Sources

- [Screenshot specifications — App Store Connect Help](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)
- [Add platforms — App Store Connect Help](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms/)
- [Distributing software on macOS — Apple Developer](https://developer.apple.com/macos/distribution/)
- [App Sandbox Entitlement — Apple Developer Documentation](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.security.app-sandbox)
- `/System/Library/Sandbox/Profiles/appsandbox-common.sb` and `application.sb` — the sandbox profile Apple actually enforces, and the source for § 3.3
- `xcodebuild -help` (Xcode 26.3) — the `method` list
- [Xcode app icon asset catalog guide (third party, corroborating the macOS icon ladder)](https://bravecl.com/articles/xcode-app-icon-asset-catalog-guide)

Everything else came from this repository or from builds and runs I made
against it on this Mac.

---

## 7. The privacy manifest (added 9 Aug 2026) — DONE

**Why:** the app uses `UserDefaults`, a required-reason API, and had no
`PrivacyInfo.xcprivacy` anywhere. An upload can return an **ITMS-91053**
notice. Better settled before a submission than during one.

*(This section was lost once to a destructive `git checkout -- .` run by an
agent and rebuilt from its report. The manifests, the checker and the builds
were never affected — only this prose.)*

### What the app actually uses — audited, not assumed

Grepped both targets for all five required-reason categories, with comments
and string literals stripped first. That mattered: `Model/Antics.swift` says
*"a stat that decays"* in prose, which a naive word match hits.

| Category | Present | Evidence |
|---|---|---|
| File timestamp | **No** | `FileManager` appears only in `Model/Snapshot.swift:107-177`, and the listing is `contentsOfDirectory(atPath:)` — names only. No `includingPropertiesForKeys`, no `resourceValues`, no `attributesOfItem`. |
| System boot time | **No** | All six `ProcessInfo` sites are `.arguments`. No `systemUptime`, no `mach_absolute_time`. |
| Disk space | **No** | No `statfs`, no `volumeAvailableCapacity*`. |
| Active keyboards | **No** | No `activeInputModes`. |
| **User defaults** | **Yes, two kinds** | `UserDefaults.standard` across ~30 model types; and the App Group suite in `LiveActivity/WidgetMirror.swift:70`, read by `PawmodoroWidgets/PawmodoroHomeWidget.swift:61`. |

Also confirmed: zero `URLSession` / `NWConnection` / `WKWebView` / `http(s)://`
in any Swift file, no SPM or CocoaPods, and only `SwiftUI` and `WidgetKit`
linked.

### The codes, and the one that is easy to get wrong

- **App** — `CA92.1` **and** `1C8F.1`.
- **Widget** — `1C8F.1` only. It never touches `UserDefaults.standard`.

`CA92.1` alone would have been an **under-declaration**, which is the failure
mode that looks like the careful answer: Apple's text for it explicitly
excludes *"writing information that can be accessed by other apps"*, and the
App Group write is exactly that. `C56D.1` is third-party-SDK only and there
are none; `AC6B.1` is MDM. All three "collect nothing" keys are false or empty
in both manifests.

**Scope note:** Apple lists the requirement for iOS, iPadOS, tvOS, visionOS
and watchOS — **macOS is not on that list**. One multiplatform target means
the Mac carries it anyway, which is harmless and equally true.

### Proven in the product, not the source tree

That distinction is the whole point — it is how the Mac shipped with no icon
at all while Xcode's own validation passed.

- iOS Release: `Pawmodoro.app/PrivacyInfo.xcprivacy` (3747 B) **and**
  `.../PlugIns/PawmodoroWidgetsExtension.appex/PrivacyInfo.xcprivacy` (1898 B)
- macOS Release: `Pawmodoro.app/Contents/Resources/PrivacyInfo.xcprivacy`
- `cmp` byte-identical to source in all three; `plutil -lint` clean.

No pbxproj edit was needed — both folders are synchronized groups, so the
files joined their targets on their own.

### `tools/check_privacy.py` — new, and broken seven ways first

It never reads a manifest and agrees with it. It reads the **Swift**, derives
the required categories per target (parsing `membershipExceptions` out of the
pbxproj, so the one app file the widget also compiles counts on the widget's
side), and demands an exact match in both directions.

Seven deliberate breaks, all seven caught: a dropped `1C8F.1`; an unbacked
`FileTimestamp`; `NSPrivacyTracking` set true; a fabricated code `CA92.2`; a
new file calling `systemUptime`; the widget manifest deleted; and
`UserDefaults.standard` added to the one shared file — which failed the
**widget's** manifest, proving the pbxproj exception parsing is genuinely read
rather than decorative.

### Still the owner's, in App Store Connect

- Confirm App Privacy still says **Data Not Collected**.
- Confirm the privacy policy URL is hosted and reachable.
- Confirm the answers cover macOS once the platform is added.
- Only a real upload can prove ITMS-91053 is gone.
