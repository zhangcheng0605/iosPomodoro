# Shipping Pawmodoro on the Mac App Store

_Written 8 Aug 2026, on the Mac, against this repo at commit `c647330` on
branch `claude/pet-interactions-retention-7caoj8`. Xcode 26.3 (17C529), macOS
26.2 SDK._

Everything in this document that is stated flatly was **checked against this
project** — the pbxproj, the Swift, or a real build I ran. Everything I could
not check is marked **VERIFY** and says how to check it. Nothing here is
copied from a generic tutorial without being confirmed against Pawmodoro.

> ## Update, 9 Aug 2026 — three VERIFYs closed, three new Mac bugs
>
> Run on this Mac against the working tree, with an ad-hoc-signed sandboxed
> build. What changed since the above was written:
>
> - **Blocker 2 is done.** `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` is wired up in
>   `project.pbxproj` (lines 459-461 / 496-498), alongside iOS entitlement
>   files for both iPhone SDKs. A sandboxed build runs, `libsystem_secinit`
>   logs `AppSandbox`, and everything lands in the container.
> - **Blocker 4 is answered: StoreKit does *not* need
>   `com.apple.security.network.client`.** See § 3.3, which now has evidence
>   rather than a question.
> - **Blocker 1 is unchanged** — still no macOS icon, re-verified. Do not trust
>   `assetutil --info | grep -c AppIcon`; it counts the twenty
>   `iconpreview_AppIcon*` renditions of the alternate-icon picker. The check
>   that means anything is `CFBundleIconName` in the built `Info.plist`.
> - **Screenshots exist** — eight at 1440×900, plain and captioned, listed in
>   `docs/MAC_STORE_ASSETS.md` § 2.1.
> - **Three Mac bugs, all in shipping code**, written up in
>   `docs/MAC_STORE_ASSETS.md` § 3. The first is a submission blocker in
>   spirit if not in the rules: **the menu bar extra draws the buddy at about
>   400 points**, so the menu bar shows a clipped band of orange cat. That is
>   the screenshot § 5.2 below calls the Mac's whole pitch, and it cannot be
>   taken. The other two: the Scrapbook has no import control on macOS
>   (`.topBarLeading` renders nothing in a Mac sheet), and the old snail
>   stands on the ambience row.

I could not edit `project.pbxproj` (two other agents are writing to it) or any
Swift file, so the two build-setting changes below are yours to make in
Xcode's GUI. The one file I did write is
`Pawmodoro/Mac/Pawmodoro.entitlements`.

---

## Verdict

**Pawmodoro is already a native macOS app and it already builds, archives and
validates. It is much closer to the Mac App Store than the docs in this repo
say it is.** `docs/HEARTH_PLAN.md` § "Phase 7 — As built" states that the macOS
target does not exist and has never been compiled. That is stale. There is one
multiplatform target, it has `SDKROOT = auto` and `macosx` in
`SUPPORTED_PLATFORMS`, and I built it:

```
xcodebuild -scheme Pawmodoro -configuration Release \
  -destination 'platform=macOS,arch=arm64' ... build      → ** BUILD SUCCEEDED **
xcodebuild -scheme Pawmodoro -configuration Release \
  -destination 'generic/platform=macOS' ... archive       → ** ARCHIVE SUCCEEDED **
```

Universal binary (`arm64` + `x86_64`), 20.05 MB executable, 48 MB `.app` on
disk, `LSMinimumSystemVersion 14.0`, and the same bundle identifier as the
shipped iPhone app. Two warnings, no errors.

There are **five things that must be fixed before you can submit**, and only
one of them is real work.

---

## Blockers, ranked

### MUST FIX — the submission cannot succeed without these

| # | Blocker | Why | Effort |
|---|---|---|---|
| 1 | **There is no macOS app icon.** | Verified: the Mac `Info.plist` I built has no `CFBundleIconName` and no `CFBundleIconFile`, and `assetutil --info` on the built `Assets.car` shows **no app-icon entries at all**. `AppIcon.appiconset/Contents.json` declares exactly one image, tagged `"platform": "ios"`. App Store Connect rejects a Mac upload with no icon. Note the trap: Xcode's own `builtin-validationUtility -validate-for-store` step **passed** on this build, so nothing local will tell you. | Half a day (see § 5) |
| 2 | ~~**The app is not sandboxed, and has no entitlements file.**~~ **DONE, 9 Aug.** | `CODE_SIGN_ENTITLEMENTS[sdk=macosx*] = Pawmodoro/Mac/Pawmodoro.entitlements` is in `project.pbxproj`, with separate iOS files for both iPhone SDKs. A sandboxed build was run and drove the timer, audio, notifications, StoreKit and the Scrapbook sheet with no denials. | — |
| 3 | **Audio has never been played on real Mac hardware.** | This is build 2's scar repeating. All fifty tracks were unplayable on every real iPhone because the player nodes were wired at the hardware's format while the files are mono 22.05 kHz; the Simulator could not show it. A Mac's default output device is 48 kHz, often 44.1 on headphones, and can change mid-session when you plug in. `HEARTH_PLAN` calls this pass non-negotiable and it still has not happened. | One evening of listening |
| 4 | ~~**StoreKit under the sandbox is unproven.**~~ **Mostly answered, 9 Aug.** | The sandbox does not block it: the mach lookup for `com.apple.storekitagent` succeeds, the product request round-trips and decodes, and there are no denials. **Do not add `network.client`.** What is left is the last step only — a signed build with a Sandbox Apple Account, to see products actually listed. § 3.3 has the log. | 15 minutes |
| 5 | **Add the macOS platform to the existing app record — do not create a new app.** | Creating a second App Store Connect record loses Universal Purchase forever and orphans your paying iOS users. See § 2. | One click, done correctly |

### SHOULD FIX — will not block review, will make the app feel wrong

| Item | Detail |
|---|---|
| **The menu bar extra is broken (9 Aug).** | Top of this list by a distance, because it is the feature the Mac version exists for. `MenuBarBuddy` asks for a 16 pt sprite and gets a ~400 pt one, so the menu bar shows a clipped band of orange cat. Measured, with evidence, in `docs/MAC_STORE_ASSETS.md` § 3.1. Not a rejection risk; it is a "this app is broken" risk with every Mac user who launches it. |
| **The Scrapbook has no import control on macOS (9 Aug).** | `ToolbarItem(placement: .topBarLeading)` renders nothing in a Mac sheet, so the Scrapbook can only show pictures added on the phone. `docs/MAC_STORE_ASSETS.md` § 3.2. Decide this before answering § 3.4's camera question — the answer changes. |
| **The Mac window cannot really be resized.** | `PawmodoroApp` sets `.windowResizability(.contentSize)` with a frame of min 360×860 / ideal 400×900 / max width 520. Height is free, width is clamped to a 160-point band. That is a deliberate, well-argued decision (`Platform.swift` explains it: the scenes are exported at 396×858 and a wide window crops the art to a band of sky) — but a Mac app that is a phone column and cannot be zoomed reads as a port. It will not fail review. It will be the first thing a Mac user notices. |
| **No ⌘, (Settings) and no Help menu.** | `PawmodoroApp` adds a `CommandMenu("Session")` and a `MenuBarExtra`, but no `Settings` scene. Settings live inside the window, reachable only by pointing. Every Mac user reaches for ⌘, first. |
| **iOS-only keys are in the Mac `Info.plist`.** | Verified in the built bundle: `NSSupportsLiveActivities = 1`, `UILaunchScreen`, `UIApplicationSceneManifest`, `UIApplicationSupportsIndirectInputEvents`, `UISupportedInterfaceOrientations~iphone/~ipad`. Harmless — macOS ignores them — but `NSSupportsLiveActivities` on a Mac is a claim that is not true, and this app's whole habit is not to claim things that are not true. Fix with SDK-conditional build settings, e.g. `INFOPLIST_KEY_NSSupportsLiveActivities[sdk=iphoneos*]`. **VERIFY** that `INFOPLIST_KEY_*` accepts an `[sdk=…]` condition in Xcode 26 — I did not test it, and if it does not, the alternative is a real `Info.plist` file for the macOS SDK. |
| **`NSCameraUsageDescription` ships in the Mac bundle with no camera behind it.** | `Pawmodoro/Views/CameraPicker.swift` is entirely inside `#if canImport(UIKit)`, so the Mac build has no camera path. The usage string is inherited from the shared build settings. It does nothing without the camera entitlement (which we are not requesting), so it is cosmetic — but see § 3.4, because `HEARTH_PLAN` promised a Mac camera and this is the moment to decide. |
| **`NSHumanReadableCopyright` is unset.** | The Mac About box will show no copyright line. Set `INFOPLIST_KEY_NSHumanReadableCopyright`. |
| **Two compiler warnings.** | `Animation/BuddyAnimator.swift:219` — "reference to captured var 'self' in concurrently-executing code; this is an error in the Swift 6 language mode". `Views/GardenView.swift:82` — unused `kind`. Neither blocks anything today; the first one is a future build break. |
| **A bare Space bar is bound as a menu shortcut — check it does not eat the rename field.** | `MenuBarControls` binds `.keyboardShortcut(.space, modifiers: [])` to Start/Pause. `PawmodoroApp`'s own comment, three files away, says the opposite: *"No Space bar. It is the obvious shortcut and it is wrong: the buddy can be renamed from Settings, and a menu command on a bare Space swallows the space bar inside that text field."* My reading is that a `MenuBarExtra` status-item menu's key equivalents are only live while that menu is open, unlike the main menu bar — which would make this safe. **VERIFY**: open Settings, rename the buddy, try to type "Mister Whiskers". If the space does not go in, that is a functional defect, not a nitpick. |

### CAN SHIP AS IS — do not spend time on these

- **Haptics do nothing.** `HapticsDirector` is a deliberate no-op on macOS and `Platform.swift` says why. Nobody expects a buzz from a Mac.
- **No Live Activities.** iOS-only by construction; `LiveActivity/` is fenced behind `#if os(iOS)`.
- **No shake gesture.** There is no accelerometer; ⌘K and the "Give it a shake" menu item are the way in, and both call the same `SceneShake.shared.shake()`.
- **No home-screen widget.** Verified: `PawmodoroWidgetsExtension` is `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`, and **both** its target dependency and its Embed Foundation Extensions build file carry `platformFilter = ios`. The Mac build correctly produces no `Contents/PlugIns` directory. Just do not mention widgets in the Mac listing.
- **The app-group write is a no-op on the Mac.** `TimerEngine.settingsDidChange()` writes two keys to `UserDefaults(suiteName: "group.com.pawmodoro")` for the widget. With no widget and no app-groups entitlement, that lands in the app's own container and nothing reads it. The comment in the code already says so. **Do not add the App Groups entitlement to fix this** — there is nothing to fix.
- **48 MB on disk.** The 45 MB ceiling in `CLAUDE.md` is an iOS concern. The Mac has no equivalent limit worth worrying about, and 20 MB of the 48 is the universal binary.

---

## 1. What kind of Mac app is this?

**A native macOS app from a single multiplatform SwiftUI target.** Not Mac
Catalyst. Not "Designed for iPad". This is the best of the three options and it
is already done.

Read out of `Pawmodoro.xcodeproj/project.pbxproj`:

| Setting | Value | Where |
|---|---|---|
| `SDKROOT` | `auto` | Project level, Debug and Release |
| `SUPPORTED_PLATFORMS` | `iphoneos iphonesimulator macosx` | Project level, Debug and Release |
| `SUPPORTS_MACCATALYST` | **absent** → defaults to `NO` | — |
| `MACOSX_DEPLOYMENT_TARGET` | `14.0` (Sonoma) | Project level |
| `IPHONEOS_DEPLOYMENT_TARGET` | `17.0` | Project level |
| `TARGETED_DEVICE_FAMILY` | `1` (iPhone) | App target |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.pawmodoro.zhangcheng` | App target — **the same one on both platforms** |
| `DEVELOPMENT_TEAM` | `6YFQ69HSD6` | App target |
| `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` | `1.0` / `2` | App target |

`SDKROOT = auto` plus `macosx` in `SUPPORTED_PLATFORMS` is exactly the
multiplatform-single-target arrangement. `TARGETED_DEVICE_FAMILY = 1` is an
iOS-only setting and macOS ignores it — the Mac build came out fine with it
set.

Why this matters downstream, in one line each:

- **Universal Purchase is free.** One target means one bundle ID, which is the
  hard requirement (§ 2). You cannot get this wrong by accident, which you
  very much could with a second target.
- **The sandbox entitlements must be SDK-conditional**, because the same target
  produces the iOS build (§ 3.1).
- **`Info.plist` keys are shared**, which is why iOS keys leak into the Mac
  bundle.
- **`MACOSX_DEPLOYMENT_TARGET = 14.0` is your minimum macOS**, and it is a
  sensible one: `MenuBarExtra` needs 13, `PhotosPicker` needs 13, `Observable`
  needs 14. Do not lower it below 14.

`docs/HEARTH_PLAN.md` § "Phase 7 — What is not written" says step 1 is "the
macOS target itself (File → New → Target → App, name `Pawmodoro Mac`)". **Do
not do that.** A second target would need its own bundle ID or a manual match,
its own Info.plist, and its own membership list for every file. The
multiplatform target that exists is strictly better. That doc is out of date;
this one supersedes it.

---

## 2. Universal Purchase — yes, and the precondition is already met

**Yes. Someone who bought Plus on their iPhone will get the Mac app free and
keep Plus, as long as you add macOS as a *platform* on the existing app record
rather than creating a new app.**

Apple's requirement is that the macOS app share the iOS app's bundle ID, Apple
ID (the app identifier), and SKU. Because Pawmodoro has one target,
`com.pawmodoro.zhangcheng` is already the bundle ID on both platforms — nothing
to arrange, nothing to get wrong in the project. In-app purchases live on the
app record, not on a platform version, so `com.pawmodoro.zhangcheng.plus` and
the three tips serve macOS with no new records and no new prices.
([Add platforms — App Store Connect Help](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms/))

**The exact steps in App Store Connect:** Apps → Paawmodoro → in the sidebar,
**Add Platform** → **macOS** → Add. A macOS 1.0 version appears in the sidebar,
and you fill in its own metadata.

**Is it one-way?** Partly, and the boundary matters:

- A platform **can** be removed while no build has ever been uploaded for it
  and at least one existing version is editable (hover the platform, click the
  `–`).
- Once App Store Review has approved **two** platform versions, the app is a
  universal purchase permanently and no single platform can be removed.
  Apple's wording: *"Once it's a universal purchase, your app stays as
  universal purchase."*

So the point of no return is **the Mac version's approval**, not the click.
That is the right way round: you can add the platform now, upload a build,
change your mind, and pull it before it ships.

Two more things:

- **`AppStore.sync()` already handles the restore path.** `StoreManager.swift`
  calls it, and `applyEntitlement(hasPlus:)` already reasons about entitlement
  being revoked after the fact. The Mac gets Plus by signing into the same
  Apple Account; there is no code to add.
- **VERIFY: turn off "iPhone and iPad Apps on Mac" once the native Mac app
  ships.** With `TARGETED_DEVICE_FAMILY = 1` the iOS app may currently be
  offered on Apple Silicon Macs under that programme (it is opt-out, in
  Pricing and Availability). Two Pawmodoros in the Mac App Store search results
  is a bad look. I could not check what that toggle is currently set to — it is
  account state, not repo state.
- **Version numbers are per platform.** macOS starts its own train at 1.0.
  Because `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` are shared build
  settings, bumping for an iOS release also bumps the Mac's numbers. That is
  harmless — build numbers only have to be unique within a platform's train —
  but it means the Mac's build number will jump around, which is fine.

---

## 3. App Sandbox and the entitlements

### 3.1 The file, and how to wire it up

I wrote **`Pawmodoro/Mac/Pawmodoro.entitlements`**. It contains exactly one
key:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```

Every other entitlement is deliberately absent, and the file's comment says why
for each one, so nobody re-adds them later "just in case".

**Wire it up in Xcode — Build Settings, not the Signing & Capabilities tab.**
Select the `Pawmodoro` target → Build Settings → search "entitlements" → find
**Code Signing Entitlements**, then click the `+` on the value row and add a
**condition for `Any macOS SDK`**, so you end up with:

```
CODE_SIGN_ENTITLEMENTS[sdk=macosx*] = Pawmodoro/Mac/Pawmodoro.entitlements
```

and the unconditional value left **empty**. If you use the Signing &
Capabilities tab's "App Sandbox" button instead, Xcode writes an unconditional
`CODE_SIGN_ENTITLEMENTS` and your iOS build starts signing with an App Sandbox
entitlement it has no business carrying. Do it in Build Settings.

Three things I verified about this file so you do not have to:

- `plutil -lint` passes.
- **It does not get copied into the app bundle.** `Pawmodoro/` is a
  file-system synchronized group, so I was worried the new file would be picked
  up into Copy Bundle Resources. I rebuilt after creating it and checked:
  `Contents/Resources` contains no `.entitlements`. (Xcode 26.3. If a future
  Xcode changes this, `ls Pawmodoro.app/Contents/Resources | grep entitle` is
  the check.)
- Ad-hoc signing the built app with it embeds exactly one entitlement and
  `codesign -vvv` reports "satisfies its Designated Requirement":

```sh
codesign --force --deep --sign - --entitlements Pawmodoro/Mac/Pawmodoro.entitlements Pawmodoro.app
codesign -d --entitlements - --xml Pawmodoro.app | plutil -p -
# → { "com.apple.security.app-sandbox" => 1 }
```

### 3.2 What each subsystem actually needs — worked out from the code

| Subsystem | Where | Entitlement needed | Why |
|---|---|---|---|
| **Network** | Nowhere. I grepped every `.swift` in the repo for `URLSession`, `NWConnection`, `http://`, `https://` — **zero hits.** | **None.** No `network.client`, no `network.server`. | `docs/PRIVACY.md` says the app makes no network requests and `CLAUDE.md` says that sentence has to stay true. Requesting the entitlement would not break the sentence (an entitlement is a permission, not a call) but it would be a capability with no code behind it. |
| **Scrapbook photo import** | `Views/ScrapbookView.swift` uses SwiftUI `PhotosPicker` and `item.loadTransferable(type: Data.self)`. Nothing in the app opens a file by path. | **None** — probably. See § 3.3. | The picker runs out of process and hands back `Data`; it needs no permission dialog on iOS, which is exactly why it was chosen. |
| **Scrapbook photo storage** | `Model/Snapshot.swift` writes to `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)`. | **None.** | Inside the sandbox container already. |
| **Settings, history, everything else** | `UserDefaults`. | **None.** | Container-local. |
| **Audio** | `AVAudioEngine` playing bundled `.m4a`/`.wav`. | **None.** | Playback of bundled files. `com.apple.security.device.audio-input` is for the microphone and this app has none. |
| **Local notifications** | `NotificationManager.swift`, `UNUserNotificationCenter`. | **None.** | Works in the sandbox; the app must be signed, which it will be. |
| **Sharing a postcard** | `ShareLink` with a `Transferable` (`Views/PostcardExport.swift`, `ShareCard.swift`, `AlbumView.swift`). | **None.** | `NSSharingService` runs out of process. |
| **StoreKit** | `Store/StoreManager.swift` — `Product.products(for:)`, `AppStore.sync()`. | **Probably none.** See § 3.3. | — |
| **Camera** | `Views/CameraPicker.swift`, entirely inside `#if canImport(UIKit)`. | **None** — there is no camera code in the Mac build. | See § 3.4. |
| **App Groups** | `TimerEngine.swift:1302`, `UserDefaults(suiteName: "group.com.pawmodoro")`. | **None, on purpose.** | The only reader is the widget, which is iOS-only. Also note that on macOS an app-group identifier must be prefixed with the team ID (`6YFQ69HSD6.group.com.pawmodoro`), so the iOS string would not even work here. Leave it out. |

**Never add `com.apple.security.get-task-allow` to this file.** Xcode injects it
for debugging and strips it when archiving; a copy in the file would survive
into the archive and the upload is rejected.

**Hardened Runtime is not required for the Mac App Store** — it is a
notarization/Developer ID requirement. Leave `ENABLE_HARDENED_RUNTIME` off
unless something later needs it.

### 3.3 The entitlement question, now answered

**Does StoreKit work in the sandbox without `com.apple.security.network.client`?**

**No entitlement is needed. Do not add `network.client`.** Settled on this Mac
on 9 Aug 2026, by running the same Debug build twice — once ad-hoc signed with
`Pawmodoro/Mac/Pawmodoro.entitlements` (so `com.apple.security.app-sandbox` and
nothing else), once unsigned and unsandboxed as a control — and reading the
unified log for both processes.

`StoreManager.loadProducts()` is called at launch from `PawmodoroApp.swift:32`,
so this needs no navigation: the product request happens whether or not
anything opens the paywall. The sandboxed run:

```
Pawmodoro[4074] (libsystem_secinit.dylib) AppSandbox
Pawmodoro[4074] [com.apple.xpc:connection] activating connection: mach=true … name=com.apple.storekitagent
Pawmodoro[4074] [com.apple.storekit:Default] [347c471e_SK2] Starting product request
Pawmodoro[4074] [com.apple.storekit:Default] [347c471e_SK2] Decoded product response
Pawmodoro[4074] [com.apple.storekit:Default] [347c471e_SK2] Finished product request
Pawmodoro[4074] [com.apple.storekit:Default] [347c471e_SK2] Parsing 0 products in response
```

Three things matter in that. The **mach lookup for `com.apple.storekitagent`
succeeds** — that is the call the sandbox would have refused, and it is the
whole question. The request then **round-trips and the response decodes**, so
the daemon did the network on the app's behalf exactly as the theory says.
And there are **zero sandbox denials** anywhere in the process's log
(`grep -ci deny` over five minutes of `--info --debug` for this process: 0).

The "0 products" is not the sandbox. The unsandboxed control run gets `Parsing
0 products in response` too, and the accompanying error is
`ASDErrorDomain Code=509` — no store account on this Mac. An ad-hoc-signed
local build has no team, no receipt and no signed-in sandbox Apple Account, so
an empty catalogue is the correct answer for *both* builds.

**What this proves and what it does not.** It proves the App Sandbox does not
block StoreKit's path, which is the thing that would have cost an evening to
rediscover. It does not prove products *appear* — that still wants the last
step below, on a properly signed build with a Sandbox Apple Account signed in.
But if that test fails, `network.client` is not the reason and adding it will
not help.

The reasoning, kept because it is why the answer is believable:

- StoreKit's purchase UI and transaction work happen in Apple's own daemon
  process, not yours — which is the usual reason an entitlement is not needed.
- Apple's [App Sandbox entitlement
  documentation](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.security.app-sandbox)
  lists no in-app-purchase entitlement.
- But the folk advice around sandboxed Mac apps leans heavily on
  "just add `network.client`, everything needs it", and I could not find a
  primary source ruling it out for StoreKit specifically.

**The test, in order — do not skip to the last step:**

1. Wire up the entitlements file as § 3.1 says, with **no** network entitlement.
2. Run the Mac app **from Xcode with `Pawmodoro.storekit` attached to the
   scheme**. This proves the code path but *not* the entitlement question, since
   a local StoreKit configuration does not talk to Apple's servers. It is still
   worth doing first because it separates "my code is broken" from "the sandbox
   is blocking me".
3. Detach the StoreKit configuration, sign into a **Sandbox Apple Account** on
   the Mac (Settings → Developer → Sandbox Apple Account), and run the
   sandboxed build. Open the paywall.
   - **Products appear** → you need no network entitlement. Stop. Do not add it.
   - **Products do not appear** → add
     `com.apple.security.network.client` to the entitlements file and try again.
     If that fixes it, keep it, and note in `docs/PRIVACY.md` that the
     entitlement exists solely so the App Store can talk to itself — the app
     still makes no network calls of its own, which is the sentence that has to
     stay true.
4. Whichever answer you get, **write it into this document.** It is the kind of
   fact that costs an evening to rediscover.

The same shape of doubt applied, more weakly, to **`PhotosPicker` under the
sandbox on macOS**, and it is now half answered — for a reason nobody expected.

Opening the Scrapbook in the sandboxed build (through the window toolbar's
third button, pressed with `perform action "AXPress"`) works, connects out to
`com.apple.photos.service`, initialises `PHPhotoLibrary`, and produces **no
sandbox denial**. So the sandbox is not standing in the way.

**But the picker cannot be reached at all on macOS**, sandboxed or not:
`ScrapbookView.swift:50` puts the `PhotosPicker` in
`ToolbarItem(placement: .topBarLeading)`, which renders nothing in a Mac
sheet. The sheet has exactly one button and it is `Done`. See
`docs/MAC_STORE_ASSETS.md` § 3.2 — fix the placement first, then finish this
test by actually importing a picture.

If an import ever does fail, the two candidate fixes remain, in order of how
little they claim: replace the Mac path with an `NSOpenPanel` /
`.fileImporter` and add `com.apple.security.files.user-selected.read-only`
(the narrowest possible claim: "the user handed me this one file"), or add
`com.apple.security.personal-information.photos-library` (a much larger claim,
and one your privacy label would have to answer for). Prefer the first.

### 3.4 A decision you have to make: the Mac camera

`docs/HEARTH_PLAN.md` § Phase 7 promised *"camera entitlement (the Scrapbook
works from a MacBook — a photo of the desk you're actually at)"* and lists "the
camera/user-selected-file entitlements the Scrapbook needs" as work to do.

**As the code actually stands there is no camera on the Mac at all.**
`CameraPicker` is `UIViewControllerRepresentable` around
`UIImagePickerController`, inside `#if canImport(UIKit)`, and `ScrapbookView`
guards its camera toolbar button with the same `#if`. On the Mac you get the
photo picker and nothing else.

Two honest options:

- **Ship without it.** The Scrapbook still works — you pick an existing
  picture. Zero new entitlements, zero new review questions. This is what my
  entitlements file assumes. Recommended for version 1 on the Mac.
- **Build it later**, as an `AVCaptureSession` (there is no
  `UIImagePickerController` on macOS, so this is real work, not a shim), and
  add `com.apple.security.device.camera`. `NSCameraUsageDescription` is already
  in the shared build settings, so that half is done.

Either way, update `HEARTH_PLAN.md` so the next person does not add a camera
entitlement for code that is not there. An entitlement with nothing behind it
is a question in review that you answer with "sorry, ignore that".

---

## 4. Signing and upload

### 4.1 Notarization does not apply

**Mac App Store builds are not notarized by you.** Notarization is for software
you distribute yourself — Developer ID, downloaded from a website, checked by
Gatekeeper. Apple's own distribution page frames it that way: the Mac App Store
is one route, and *"you may choose to distribute your Mac apps in other
ways… sign your apps, plug-ins, or installer packages to let Gatekeeper know
they're safe to install. You can also give users even more confidence in your
apps by submitting them to Apple to be notarized."*
([Distributing software on macOS](https://developer.apple.com/macos/distribution/))

So: **you will never run `notarytool` for this.** If you find yourself reading
notarization instructions, you have wandered into the wrong half of the docs.

### 4.2 Certificates and profiles

With **automatic signing** (`CODE_SIGN_STYLE = Automatic` is already set on the
target), Xcode creates and manages all of this for you the first time you
archive and distribute. You should not have to touch Keychain Access.

What it creates, so you recognise the names when you see them:

| Thing | What it signs | You need it if… |
|---|---|---|
| **Apple Distribution** | The `.app` | Always. This is the modern certificate that covers iOS and macOS both — it replaces the older, macOS-specific "3rd Party Mac Developer Application" / "Mac App Distribution". |
| **Mac Installer Distribution** (a.k.a. "3rd Party Mac Developer Installer") | The `.pkg` that actually gets uploaded | Always — a Mac App Store submission is a signed installer package, not a `.app`. Xcode makes and uses this for you. |
| **Mac App Store provisioning profile** | Ties the App ID to the certificate | Always; automatic signing generates it. |
| **Developer ID Application / Installer** | — | **Never, for this.** That is the outside-the-store route. |

**VERIFY in the Developer portal** that the App ID `com.pawmodoro.zhangcheng`
is enabled for macOS. App IDs have been platform-agnostic since 2020 and
automatic signing normally handles it, but if the first archive fails with a
profile error, Certificates, IDs & Profiles → Identifiers → your App ID is the
place to look.

### 4.3 The upload route

**Use Xcode's GUI. All of it.** For this app there is no reason to touch the
command line, and the command-line upload path is the part of this whole
document I trust least.

**The GUI route, end to end:**

1. Xcode → the scheme's run destination → **My Mac**.
2. **Product → Archive.** (With "My Mac" selected, Archive builds the macOS
   archive; the iOS archive is a separate operation with a different
   destination.)
3. The Organizer opens. Select the archive → **Distribute App** → **App Store
   Connect** → **Upload**.
4. Xcode signs the `.app` with Apple Distribution, wraps it in a `.pkg` signed
   with Mac Installer Distribution, and uploads it.
5. Wait for the "processing complete" email, then attach the build to the macOS
   1.0 version in App Store Connect.

**The command-line route, if you ever need it** — for example from CI:

```sh
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath build/Pawmodoro-mac.xcarchive archive

xcodebuild -exportArchive -archivePath build/Pawmodoro-mac.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/mac-export
```

with an `ExportOptions.plist` whose `method` is the App Store method. That
produces a signed `.pkg`. **VERIFY the two moving parts before relying on
this:** (a) the exact spelling of the `method` value — Xcode has been migrating
from `app-store` to `app-store-connect` and the wrong one fails with an
unhelpful error; (b) how you upload the `.pkg`. `xcrun altool --upload-app -f
Pawmodoro.pkg -t macos` has historically been the answer and Apple has been
deprecating `altool`; the **Transporter** app from the Mac App Store is the
supported GUI alternative. `notarytool` is **not** an upload tool and cannot do
this. I could not confirm `altool`'s current status from here — if you go this
way, run `xcrun altool --help` first and believe what it says over what I say.

I archived the Mac target with `CODE_SIGNING_ALLOWED=NO` and it succeeded, so
the archive itself has no surprises in it. Everything past that point is
account state I cannot see.

---

## 5. What App Store Connect will demand that does not exist yet

### 5.1 The macOS app icon — the real work item

Two separate problems, and the second is the one people miss.

**Problem one: the sizes.** `AppIcon.appiconset/Contents.json` declares a single
universal 1024×1024 tagged `"platform": "ios"`. macOS needs the full ladder —
16, 32, 128, 256, 512 pt, each at 1× and 2× (so the largest file is 1024×1024,
which is also what the store listing uses; there is no separate icon upload for
Mac, App Store Connect takes it from the bundle). In Xcode: select `AppIcon` in
the asset catalog, open the Attributes inspector, tick **macOS**, and ten new
wells appear. A single 1024 in the macOS slot is **not** sufficient — a Mac
build with an incomplete icon set is rejected at submission.
([Xcode app icon guide](https://bravecl.com/articles/xcode-app-icon-asset-catalog-guide))
**VERIFY** whether Xcode 26 has since added single-size support for the macOS
idiom — if it has, that is much less work; the ladder is the safe answer.

**Problem two: the shape, which matters more.** I checked the existing PNG:
1024×1024, mode `RGB` — opaque, full-bleed, square. That is correct for iOS,
where the system rounds the corners for you. On macOS **nothing rounds it**.
Dropped in as-is, Pawmodoro would sit in the Dock as a hard square between
thirty rounded-rectangle-with-shadow icons and look like a bug. A macOS icon is
drawn *inside* a smaller rounded rectangle on a transparent 1024 canvas, with
its own shadow.

The right fix given this repo's rules — *edit the script, never the PNG* — is a
`make_mac_icon()` beside `make_icon()` in `tools/generate_assets.py`. It has all
the pieces already: the tomato, the paw, the gradient, `BLUSH`/`CREAM`/`BLOSSOM`.
What changes is the frame: an RGBA canvas, the art composited into a rounded
rect inset from the edges, a soft shadow beneath it, then exported at the ten
sizes. **VERIFY the exact inset and corner radius against the current Apple
HIG** ("App icons" → macOS) rather than eyeballing it; the geometry has been
restated for the macOS 26 icon style and I did not check the current numbers.

Xcode 26 also ships **Icon Composer** (`.icon` files) for the newer layered
macOS icon look. Not required at a macOS 14 deployment target, and a `.icon`
would be a second source of truth for artwork this repo generates — I would
skip it.

### 5.2 Screenshots

**Required.** At least 1, at most 10, in **exactly** one of these sizes, 16:10,
`.png`/`.jpg`, **no alpha channel**:

- 1280 × 800
- 1440 × 900
- 2560 × 1600
- 2880 × 1800

([Screenshot specifications — App Store Connect Help](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/))

The awkward part is Pawmodoro-specific: your window is a **400 × 900 point
column**, which is 5:11 — nothing like 16:10. A raw window capture will never be
a valid screenshot. Every one is a composite: the window shot, scaled, on a
canvas of a legal size, on the app's own cream→blush gradient rather than a
stock desktop — Pawmodoro's whole visual argument is its palette.

**Eight are made and ready**, at 1440 × 900, plain and captioned, from real
running sessions rather than the idle 25:00 screen. `docs/MAC_STORE_ASSETS.md`
§ 2 has the list, the flags behind each one, how to re-shoot, and why
1440 × 900 rather than 2880 × 1800 on this particular machine.

Two corrections to what this section used to advise. **The menu bar extra
cannot be the first screenshot**, because it is broken — see
`MAC_STORE_ASSETS.md` § 3.1. And **no dawn or dusk shot is worth uploading**:
those two grades flatten the scenery to about a third of the day grade's
contrast, measured, which is what made the earlier "flat beige wash" capture.
The eight that exist are all day or night.

### 5.3 Category and minimum version

- **Category is already correct.** `LSApplicationCategoryType =
  public.app-category.productivity` is in the built Mac `Info.plist` — that key
  *is* the macOS category. You still pick the category in App Store Connect for
  the macOS version, and the two should agree: **Productivity**.
- **Minimum macOS: 14.0 (Sonoma)**, from `MACOSX_DEPLOYMENT_TARGET`. Verified in
  the built bundle as `LSMinimumSystemVersion = 14.0`. App Store Connect reads
  this from the build; you do not type it anywhere.

### 5.4 What carries over, and what does not

**Carries over automatically** (these live on the app record, not on a platform
version):

- In-app purchase records — Plus and all three tips, same product IDs. Nothing
  to recreate.
- App privacy answers (the nutrition label) and the privacy policy URL. The
  answer stays "Data Not Collected"; nothing about the Mac build changes it.
  **VERIFY** in App Store Connect that the privacy section is presented once
  for the app rather than per platform — I am confident but did not confirm it
  against Apple's help.
- Age rating.
- Export compliance: `ITSAppUsesNonExemptEncryption = NO` is in the shared
  build settings and I confirmed it is in the built Mac `Info.plist`.

**Does not carry over — you write these fresh for macOS:**

- Screenshots (§ 5.2).
- Description, keywords, promotional text, "What's New". Rewrite the
  description for the Mac. `docs/APP_STORE_LISTING.md` has the iOS copy; the Mac
  version should lead with the menu bar, because that is the thing the phone
  cannot do.
- Support URL and marketing URL (can be the same values, but they are entered
  again).
- App Review notes. Worth writing one line: *"No account, no network access.
  Pawmodoro Plus is a one-time non-consumable, shared with the iOS app via
  Universal Purchase."*
- Copyright, pricing/availability confirmation for the macOS version.

---

## 6. The step-by-step

Ordered so that the things that can fail cheaply fail first.

**Before you open App Store Connect at all**

1. `git status` — make sure the other agents' work has landed and the tree is
   clean.
2. Build and run the Mac app, unsandboxed, as it is today. Confirm the scenery
   and window work (another agent was fixing those).
3. **The listening pass.** Run a full focus phase on the Mac. Headphones and
   built-in speakers, both. Change the output device *while a track is
   playing*. Every ambience family, a handful of the sixty-five tracks, the
   hour bell at more than one grade. This is blocker #3 and it is the one that
   burned you before.
4. Run every checker: `for f in tools/check_*.py; do python3 "$f" || echo "FAIL $f"; done`.
   `check_music.py` only tells the truth on a Mac, and this is the Mac.

**Make the app submittable**

5. ~~Wire up `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` (§ 3.1).~~ **Done.** It is in
   `project.pbxproj`, per-SDK, with iOS entitlement files of its own. Rebuild
   for iOS once and confirm the iOS build is unchanged.
6. Rebuild for Mac and confirm the sandbox is on:
   `codesign -d --entitlements - --xml <path>/Pawmodoro.app | plutil -p -`
   should print exactly `com.apple.security.app-sandbox => 1`.
7. **Drive the sandboxed build.** Timer, notifications (background the app),
   audio, Scrapbook import (§ 3.3), postcard share, StoreKit (§ 3.3). A sandbox
   failure is silent — a thing simply does not happen — so you have to touch
   each one. Partly done on 9 Aug: launch, window restoration, notifications,
   CoreAudio, StoreKit and opening the Scrapbook all ran sandboxed with **zero
   denials**. The way to check for a silent sandbox failure without a UI to
   look at is the log — `/usr/bin/log show --last 5m --info --debug
   --predicate 'processImagePath CONTAINS "Pawmodoro"'`, then `grep -i deny`.
   Note `log` is a zsh builtin, so the absolute path matters.
8. The macOS icon (§ 5.1). Add `make_mac_icon()` to
   `tools/generate_assets.py`, run it **bare or with `2>&1`** — never piped
   into `grep`, per this repo's standing trap — populate the macOS wells,
   rebuild, and confirm with:
   `assetutil --info Pawmodoro.app/Contents/Resources/Assets.car | grep -i icon`
   and `plutil -p Pawmodoro.app/Contents/Info.plist | grep -i icon`.
   Both are empty today; both must not be.
9. Optional but cheap: the SDK-conditional Info.plist keys, the copyright
   string, the two warnings, a `Settings` scene for ⌘,.

**App Store Connect**

10. App Store Connect → Paawmodoro → **Add Platform → macOS**. Not a new app.
11. Fill in the macOS 1.0 metadata: description, keywords, screenshots,
    category (Productivity), support URL, review notes.
12. Xcode → destination **My Mac** → **Product → Archive** → Organizer →
    **Distribute App → App Store Connect → Upload**.
13. Attach the processed build to macOS 1.0, answer export compliance, submit.
14. **Come back and edit this document** with what actually happened —
    especially the StoreKit entitlement answer (§ 3.3), the icon geometry
    (§ 5.1), and anything review asked for.

---

## 7. Everything marked VERIFY, in one list

So you can check them off rather than hunt for them.

| § | Question | How to answer it |
|---|---|---|
| 3.3 | ~~Does StoreKit need `com.apple.security.network.client` in the sandbox?~~ | **ANSWERED 9 Aug: no.** Mach lookup to `storekitagent` succeeds, request round-trips, zero denials. Still open, separately: do products *list* on a signed build with a Sandbox Apple Account |
| 3.3 | ~~Does `PhotosPicker` work in the sandbox on macOS with no entitlement?~~ | **Half answered 9 Aug:** the sandbox permits it (`com.apple.photos.service` connects, `PHPhotoLibrary` initialises, no denials) — but the picker has no control on macOS at all (`MAC_STORE_ASSETS.md` § 3.2). Fix the toolbar placement, then import a picture |
| Blockers | Does the bare-Space menu shortcut swallow spaces in the rename field? | **Partly answered 9 Aug:** the *main* menu bar carries no Space — read through the accessibility API, `Session ▸ Start` has an empty `AXMenuItemCmdChar` and only `Give It a Shake` has one (⌘K). So the binding lives in the `MenuBarExtra` menu alone, which is the reading that made it look safe. Still worth typing a space into the rename field once |
| 2 | Is "iPhone and iPad Apps on Mac" currently on for the iOS app? | App Store Connect → Pricing and Availability |
| 4.2 | Is the App ID enabled for macOS? | Certificates, IDs & Profiles → Identifiers — or just let the first archive tell you |
| 4.3 | `ExportOptions.plist` method spelling, and whether `altool --upload-app` still works | `xcrun altool --help`; or avoid entirely and use the Organizer |
| 5.1 | ~~Does Xcode 26 accept a single-size macOS app icon?~~ | **ANSWERED 8 Aug: no.** The ten-entry `"idiom": "mac"` ladder is required, and adding it does not disturb the iPhone icon. `MAC_STORE_ASSETS.md` § 1 |
| Blockers | Do the iOS-only `Info.plist` keys still ship in the Mac bundle? | **Still yes, 9 Aug.** `NSSupportsLiveActivities = 1`, `UILaunchScreen` and `UIApplicationSceneManifest` are all in the built Mac `Info.plist` |
| 5.1 | Current HIG inset and corner radius for a macOS icon | Apple HIG → App icons → macOS |
| 5.4 | Are App Privacy answers shared across platforms? | Visible in App Store Connect once the platform is added |
| Blockers | Do `INFOPLIST_KEY_*` settings accept `[sdk=…]` conditions? | Add one, build, `plutil -p` the result |

---

## Sources

- [Screenshot specifications — App Store Connect Help](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)
- [Add platforms — App Store Connect Help](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms/)
- [Distributing software on macOS — Apple Developer](https://developer.apple.com/macos/distribution/)
- [App Sandbox Entitlement — Apple Developer Documentation](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.security.app-sandbox)
- [Xcode app icon asset catalog guide (third party, corroborating the macOS icon ladder)](https://bravecl.com/articles/xcode-app-icon-asset-catalog-guide)

Everything else in this document came from this repository or from builds I ran
against it.
