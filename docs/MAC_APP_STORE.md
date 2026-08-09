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

---

## Verdict

**Pawmodoro is a native macOS app that builds, archives, exports a signed
`.pkg`, and is one icon away from being uploadable.** The multiplatform target
is right, the sandbox is right, the entitlements are right, and the signing
machinery — the part everyone expects to fight — works on the first try with
`-allowProvisioningUpdates` and needs no Keychain surgery.

What is left is: an icon, an evening of listening on real hardware, three Mac
UI bugs, and a pile of App Store Connect work only the owner can do.

---

## THE LAUNCH CHECKLIST

In the order to do them. **DONE** = verified on this Mac. **BLOCKED** =
somebody has to write code or make art. **OWNER** = only Cheng can do it,
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
| 5 | **The macOS app icon** | **BLOCKED → verify** | § 5.1. Absent from the 20:47 archive; a separate workflow landed the ten-rung `mac` ladder in the working tree minutes later, unverified in a build. **Confirm before anything else:** rebuild, then `plutil -p Pawmodoro.app/Contents/Info.plist \| grep -i icon` must print `CFBundleIconName`, and `assetutil --info …/Assets.car \| grep -i icon` must show real app-icon renditions (ignore the twenty `iconpreview_AppIcon*` ones — those belong to the alternate-icon picker). Both were empty in my build; both must not be. |
| 6 | **The menu bar extra draws the buddy at ~400 pt** | **BLOCKED** | `MAC_STORE_ASSETS.md` § 3.1. Not a rejection risk — a "this app is broken" risk, in the one feature the Mac version exists for. Fix before the first screenshot is worth taking. |
| 7 | **The Scrapbook has no import control on macOS** | **BLOCKED** | `ToolbarItem(placement: .topBarLeading)` renders nothing in a Mac sheet. `MAC_STORE_ASSETS.md` § 3.2. |
| 8 | **The old snail stands on the ambience row** | **BLOCKED** | `MAC_STORE_ASSETS.md` § 3.3. |
| 9 | **The listening pass on real Mac hardware** | **OWNER** | Headphones *and* built-in speakers; change the output device **while a track is playing**. This is build 2's scar — all fifty tracks were unplayable on every real iPhone and no simulator could show it. A Mac's output device is 48 kHz or 44.1 and changes mid-session. Nobody but the owner has ears on this machine. |
| 10 | Optional polish: `Settings` scene for ⌘,, `NSHumanReadableCopyright`, SDK-conditional `INFOPLIST_KEY_NSSupportsLiveActivities`, the two compiler warnings | not started | Cheap, none of it blocks review. § "Should fix" below. |

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
| 18 | macOS 1.0 metadata: description, keywords, screenshots, category (Productivity), support URL, review notes | **OWNER** | Screenshots are made — eight at 1440×900, `MAC_STORE_ASSETS.md` § 2 — but they predate the menu-bar fix, so re-shoot after step 6. Lead the description with the menu bar; it is the thing the phone cannot do. |
| 19 | Sign into a **Sandbox Apple Account** (System Settings → Developer) and drive the real paywall: products list, buy Plus, relaunch, Restore | **OWNER** | The only part of § 3.3 that cannot be closed from here — it needs an Apple Account password. What is already proven is that if this fails, **the sandbox is not why**, and `network.client` will not fix it. |
| 20 | Archive → Organizer → **Distribute App → App Store Connect → Upload** | **OWNER** | Or `altool --upload-app -f Pawmodoro.pkg -t macos` with the exact `.pkg` step 12 produces. **Not reversible.** |
| 21 | Attach the processed build, answer export compliance, submit | **OWNER** | Export compliance is pre-answered in the bundle (`ITSAppUsesNonExemptEncryption = NO`); App Store Connect still asks. |
| 22 | Come back and write down what actually happened | **OWNER** | Especially anything review asked for. |

### The three things that would sink the submission if forgotten

1. **The icon** (step 5). Xcode's own `builtin-validationUtility
   -validate-for-store` **passed** on a build with no icon at all, so nothing
   local will warn you.
2. **Add Platform, not a new app** (step 16). One wrong click, permanent.
3. **The listening pass** (step 9). It has failed on real hardware before, on
   this exact class of bug, and no simulator or checker can see it.

---

## SHOULD FIX — will not block review, will make the app feel wrong

| Item | Detail |
|---|---|
| **The menu bar extra is broken.** | Checklist step 6. Top of this list by a distance. |
| **The Scrapbook has no import control on macOS.** | Checklist step 7. Decide it before answering § 3.5's camera question — the answer changes. |
| **The Mac window cannot really be resized.** | `PawmodoroApp` sets `.windowResizability(.contentSize)` with min 360×860 / ideal 400×900 / max width 520. Height free, width clamped to a 160-point band. Deliberate and well argued (`Platform.swift`: the scenes are exported at 396×858 and a wide window crops the art to a band of sky) — but a Mac app that is a phone column and cannot be zoomed reads as a port. It will not fail review. It is the first thing a Mac user notices. |
| **No ⌘, (Settings) and no Help menu.** | `PawmodoroApp` adds a `CommandMenu("Session")` and a `MenuBarExtra`, but no `Settings` scene. Every Mac user reaches for ⌘, first. |
| **iOS-only keys in the Mac `Info.plist`.** | Verified again in the 9 Aug archive: `NSSupportsLiveActivities = 1`, `UILaunchScreen`, `UIApplicationSceneManifest`, `UIApplicationSupportsIndirectInputEvents`, `UISupportedInterfaceOrientations~iphone/~ipad`. macOS ignores them, but `NSSupportsLiveActivities` on a Mac is a claim that is not true, and this app's whole habit is not to claim things that are not true. Fix with `INFOPLIST_KEY_NSSupportsLiveActivities[sdk=iphoneos*]`. **VERIFY** that `INFOPLIST_KEY_*` accepts an `[sdk=…]` condition in Xcode 26 — untested; the fallback is a real `Info.plist` for the macOS SDK. |
| **`NSCameraUsageDescription` ships with no camera behind it.** | `Views/CameraPicker.swift` is entirely inside `#if canImport(UIKit)`. Cosmetic — but see § 3.5. |
| **`NSHumanReadableCopyright` is unset.** | The About box will show no copyright line. Set `INFOPLIST_KEY_NSHumanReadableCopyright`. |
| **Two compiler warnings.** | `Animation/BuddyAnimator.swift:219` — captured `var self` in concurrently-executing code, an error in Swift 6 mode. `Views/GardenView.swift:82` — unused `kind`. The first is a future build break. |
| **A bare Space bar is bound as a menu shortcut.** | `MenuBarControls` binds `.keyboardShortcut(.space, modifiers: [])` to Start/Pause, and `PawmodoroApp`'s own comment three files away says not to. Partly answered 9 Aug: read through the accessibility API the *main* menu bar carries no Space (`Session ▸ Start` has an empty `AXMenuItemCmdChar`; only `Give It a Shake` has one, ⌘K), so the binding lives in the `MenuBarExtra` menu alone, whose key equivalents are live only while that menu is open. **VERIFY** by typing a space into the rename field once. |

## CAN SHIP AS IS — do not spend time on these

- **Haptics do nothing.** Deliberate no-op on macOS; nobody expects a buzz from a Mac.
- **No Live Activities.** iOS-only by construction; `LiveActivity/` is fenced behind `#if os(iOS)`.
- **No shake gesture.** No accelerometer. ⌘K and the "Give it a shake" menu item both call the same `SceneShake.shared.shake()`.
- **No home-screen widget.** `PawmodoroWidgetsExtension` is `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"` and carries `platformFilter = ios` on both its dependency and its embed phase. Re-verified in the 9 Aug archive: the Mac `.app` has no `Contents/PlugIns`. Just do not mention widgets in the Mac listing.
- **The app-group write is a no-op on the Mac.** `TimerEngine.settingsDidChange()` writes two keys to `UserDefaults(suiteName: "group.com.pawmodoro")` for the widget. With no widget and no app-groups entitlement it lands in the app's own container and nothing reads it. **Do not add App Groups to the Mac entitlements to "fix" this** — there is nothing to fix, and note the macOS form would have to be `6YFQ69HSD6.group.com.pawmodoro` anyway.
- **40 MB `.app` / 38 MB `.pkg`.** `CLAUDE.md` retired the 45 MB ceiling; the rule that survives is *measure it and say the number*, which is what those figures are.

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

### 5.1 The macOS app icon — the one hard blocker

Re-verified on the 9 Aug 20:47 archive: the built Mac `Info.plist` has **no**
`CFBundleIconName` and **no** `CFBundleIconFile`. A separate workflow has since
put ten `AppIcon-mac-*` PNGs and a `"idiom": "mac"` ladder into
`AppIcon.appiconset` (the catalog now declares 11 images across `mac` and
`universal`) — **built and confirmed by nobody yet.** Everything below is why
that ladder is the right shape; checklist step 5 is how to prove it shipped.

Do not trust `assetutil --info | grep -c AppIcon` — it counts the twenty
`iconpreview_AppIcon*` renditions belonging to the alternate-icon picker. The
check that means anything is `CFBundleIconName` in the built `Info.plist`.

Two separate problems:

**The sizes.** macOS needs the full ladder — 16, 32, 128, 256, 512 pt at 1× and
2×. **ANSWERED 8 Aug: a single 1024 in the macOS slot is not sufficient**; the
ten-entry `"idiom": "mac"` ladder is required, and adding it does not disturb
the iPhone icon (`MAC_STORE_ASSETS.md` § 1). App Store Connect takes the
listing icon from the bundle; there is no separate Mac icon upload.

**The shape, which matters more.** The existing PNG is 1024×1024, mode `RGB` —
opaque, full-bleed, square. Correct for iOS, where the system rounds the
corners. On macOS **nothing rounds it**, so Pawmodoro would sit in the Dock as
a hard square among thirty rounded rectangles and read as a bug. A macOS icon
is drawn *inside* a smaller rounded rect on a transparent 1024 canvas, with its
own shadow.

Given this repo's rule — *edit the script, never the PNG* — the fix is a
`make_mac_icon()` beside `make_icon()` in `tools/generate_assets.py`. **VERIFY
the inset and corner radius against the current Apple HIG** rather than
eyeballing them; the geometry was restated for the macOS 26 icon style.

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
| Should fix | Do `INFOPLIST_KEY_*` settings accept `[sdk=…]` conditions in Xcode 26? | Add one, build, `plutil -p` the result |
| 2 | Is "iPhone and iPad Apps on Mac" currently on for the iOS app? | App Store Connect → Pricing and Availability (checklist 17) |
| 5.4 | Are App Privacy answers shared across platforms? | Visible once the platform is added |

**Closed since the last revision:** does StoreKit need `network.client` (no —
§ 3.3); does `PhotosPicker` need an entitlement (no); does Xcode regenerate the
distribution profiles (yes, all three — § 4.2); is the App ID enabled for macOS
(yes); what is the `method` spelling (`app-store-connect`); does `altool` still
work (yes); does Xcode 26 accept a single-size macOS icon (no).

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
