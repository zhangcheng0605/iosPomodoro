# Submit Pawmodoro — the order to do it in

_Written 10 Aug 2026, from `HEAD = 2897944` plus the uncommitted Mac repair
work described in § 0. Everything in § 1 was measured on this Mac today and the
transcript is in § 1. Everything from § 3 on is yours alone: it needs App Store
Connect, an Apple Account password, or a judgement call about the product._

This is the follow-the-steps document. `docs/MAC_APP_STORE.md` is the reasoning
behind it and has the evidence for every claim; read that if a step here
surprises you.

---

## 0. Two things to settle before you archive anything

### 0.1 The working tree is not clean

`git status` right now:

```
 M Pawmodoro/PawmodoroApp.swift
 M Pawmodoro/Platform/Platform.swift
 M Pawmodoro/Views/ContentView.swift
 M Pawmodoro/Views/OnboardingView.swift
 M Pawmodoro/Views/YearKeptView.swift
 M tools/mac_probe.py
?? Pawmodoro/Views/Style/PagedDeck.swift
```

That is the Mac repair pass — the dead onboarding button, the AppKit tab chips,
the year card nobody could page through, the window that opened at its own
maximum. It is what today's green run was measured against, so it is the thing
you would be shipping.

`PagedDeck.swift` is **untracked**, and `Pawmodoro/` is a file-system
synchronized group, so it is in the build without being in git. Commit before
you archive. A clean checkout of `2897944` does not compile.

### 0.2 The build number

Live on the store: **version 1.0, build 2**. The project still says
`MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 2`.

- **macOS.** This is the first macOS build on the record, so build 2 will
  probably be accepted as-is. Bump it anyway — one sequence across both
  platforms is one fewer thing to reason about later.
- **iOS.** If you are also shipping the iOS fixes in `docs/NEXT_UPDATE.md`,
  1.0/build 2 is taken. You need a new **version** (1.0.1 or 1.1), not just a
  new build, because 1.0 is already released.

The app and the widget extension must move **together**.
`tools/check_icons.py` fails if their `CURRENT_PROJECT_VERSION` values
disagree, which is the fence around the older doc that told you to bump only
one.

---

## 1. What is green, as of today

All measured on this Mac, from the tree described in § 0.1.

**25 of 25 checkers pass.** `accessories bell catalog clocks contrast crossing
film flyway greeting grove icons music post postcard privacy residents snail
species stray swift tide touch treats weather yearring`.

**All four builds succeed.** iOS Debug (simulator), iOS Release (device,
`generic/platform=iOS`), macOS Debug, macOS Release.

**The promo-code fence holds, and the grep that says so is calibrated.**

| Binary | digest `e320…974a` | `Redeem` | `promo` | `PromoCode` | `PromoLedger` | control: `Pawmodoro` |
|---|---|---|---|---|---|---|
| iOS **Debug** `Pawmodoro.debug.dylib` (40.8 MB) | 2 | 524 | 50 | 178 | 270 | 85,983 |
| iOS **Release** `Pawmodoro` (11.1 MB) | **0** | **0** | **0** | **0** | **0** | 20,737 |
| macOS **Debug** `Pawmodoro.debug.dylib` (20.8 MB) | 1 | 262 | 25 | 89 | 135 | 43,610 |
| macOS **Release** `Pawmodoro` (22.7 MB) | **0** | **0** | **0** | **0** | **0** | 42,368 |

The last column is the point. A negative grep proves nothing on its own, and
this repo has been burned by exactly that twice — so the same grep, on the same
file, in the same invocation, was made to find something. It found "Pawmodoro"
20,737 times in the iOS Release binary and 42,368 times in the macOS one. The
zeros are absences, not a broken pipeline.

Two further guards, because Debug code hides in a dylib and Xcode leaves a
39 KB stub behind: the Debug numbers above are read from
**`Pawmodoro.debug.dylib`**, not from the 72 KB / 39 KB `Pawmodoro` stub next to
it. And a raw byte grep (no `strings`) over **every file in both Release
bundles**, including `PlugIns/PawmodoroWidgetsExtension.appex`, returns nothing
for all five needles.

**Size — iOS device Release `.app`: 43.46 MB** (`du -sk`; 43.11 MB as a sum of
file bytes). Of that, **26.67 MB is the 169 `.m4a` files** and 3.42 MB is
`.wav`. `CLAUDE.md`'s last recorded figure was 42.83 MB, so the Mac icon, the
`PagedDeck` and the rest of the repair pass cost about 0.3 MB. Well under the
~200 MB point where iOS starts steering people to Wi-Fi.

The macOS Release `.app` is 53.75 MB unarchived, with a universal
`x86_64 + arm64` binary. Archiving strips it: the 9 Aug rehearsal produced a
40 MB `.app` and a 38,028,796-byte `.pkg`.

---

## 2. Money, before metadata

None of this is optional and none of it prompts you. **If these are not active,
the app can ship and Plus and the tip jar simply cannot sell** — the products
return nothing and the paywall shows its unavailable state, which looks exactly
like a bug in the app.

App Store Connect → **Business** (it was called Agreements, Tax, and Banking):

1. **Paid Applications Agreement** — accepted and showing **Active**, not
   "Pending". A free-apps-only account cannot sell an in-app purchase.
2. **Bank account** — added and verified. **The account holder name must match
   the name on the individual developer account exactly.** A middle initial on
   one and not the other is enough to hold payouts, and you find out a month
   later.
3. **Tax forms** — complete for every region you sell in. US tax forms are the
   ones that block first.

All three have to read Active. One of them Pending stops the other two from
counting.

### The Small Business Program — apply, or pay double

**15% commission instead of 30%**, for developers under 1M USD in proceeds per
calendar year. You are comfortably under it.

**You must apply. Nothing in App Store Connect prompts you, no banner appears,
and it is not retroactive.** Approved enrolment takes effect from the first day
of the following month, so applying before you submit rather than after is
worth real money on every sale in between. Confirm the current threshold and
effective date on Apple's Small Business Program page — the numbers have been
stable but they are Apple's to change.

---

## 3. App Store Connect, in order

Irreversibility is marked on each step. Read step 1 twice.

| # | Step | Reversible? |
|---|---|---|
| 1 | Apps → **Paawmodoro** → **Add Platform → macOS** | **See the box below. Do not get this wrong.** |
| 2 | Pricing and Availability → check whether **"iPhone and iPad Apps on Mac"** is on for the iOS app | Yes — a toggle |
| 3 | macOS 1.0 metadata: description, keywords, promotional text, screenshots, category **Productivity**, support URL, marketing URL, copyright, review notes | Yes, until submitted |
| 4 | Confirm the in-app purchases (Plus + three tips) are attached to the macOS version | Yes |
| 5 | Sign into a **Sandbox Apple Account** (System Settings → Developer) and drive the real paywall: do products list, does Plus buy, does the entitlement survive relaunch, does Restore work | Yes — no store record changes |
| 6 | Upload the build (§ 4) | **No. An uploaded build cannot be deleted.** |
| 7 | Attach the processed build, answer export compliance | Yes, until submitted |
| 8 | **Submit for Review** | **No** — but you can cancel the submission while it is Waiting for Review |
| 9 | Come back and write down what actually happened, especially anything review asked for | — |

> ### Step 1 is the one that cannot be undone
>
> **Add Platform → macOS on the existing Paawmodoro record. Do not create a new
> app.**
>
> A second app record permanently loses **Universal Purchase**. Every person
> who already paid for Plus on iOS would have to buy it again on the Mac, and
> there is no migration, no merge, and no support path that fixes it. The
> records cannot be joined afterwards. Bundle ID, in-app purchases, privacy
> answers and age rating all live on the record you already have, and Add
> Platform is what keeps them.
>
> The click itself is reversible in a narrow sense — you can remove a macOS
> version that has not been approved. Creating a second app record is not. If
> App Store Connect ever asks you to type the app name or the bundle ID, you
> are on the wrong screen; back out.
>
> `docs/MAC_APP_STORE.md` § 2 has the precondition work that makes this
> legitimate: one bundle ID, one target, `macosx` in `SUPPORTED_PLATFORMS`.

**What carries over from iOS** (do not re-enter): in-app purchase records and
their IDs, app privacy answers ("Data Not Collected") and the privacy policy
URL, age rating, export compliance.

**What you write fresh for macOS:** screenshots, description, keywords,
promotional text, "What's New", support and marketing URLs, review notes,
copyright, pricing confirmation. `docs/MAC_LISTING.md` has drafted copy.
Lead the description with the menu bar extra — it is the thing the phone
cannot do.

One line worth pasting into review notes:

> No account, no network access. Pawmodoro Plus is a one-time non-consumable,
> shared with the iOS app via Universal Purchase.

---

## 4. The commands

The repo lives on the **iCloud-synced Desktop**, so every path below writes
outside it. This is not tidiness: the iCloud file provider stamps
`com.apple.FinderInfo` on the built bundle and `codesign` then fails with
*"resource fork, Finder information, or similar detritus not allowed"*.
`xattr -cr` fixes it only until the next build. **Xcode's own Product → Archive
menu item hits this**, which is why the archive path is stated explicitly.

The archive still lands in `~/Library/Developer/Xcode/Archives/<date>/`, so it
appears in the Organizer if you would rather finish in the GUI.

### 4.0 Setup, once

```sh
SHIP=~/PawmodoroShip
ARCH=~/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)
mkdir -p "$SHIP" "$ARCH"
cd ~/Desktop/iosPomodoro

cat > "$SHIP/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>          <string>app-store-connect</string>
    <key>destination</key>     <string>export</string>
    <key>teamID</key>          <string>6YFQ69HSD6</string>
    <key>signingStyle</key>    <string>automatic</string>
    <key>uploadSymbols</key>   <true/>
</dict>
</plist>
PLIST
```

`destination = export` is the safety catch. The other value is `upload` and it
does exactly what it says, with no confirmation. Leave it on `export` until
§ 4.3.

### 4.1 Archive

macOS:

```sh
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCH/Pawmodoro-mac.xcarchive" \
    -derivedDataPath "$SHIP/dd-mac" \
    -allowProvisioningUpdates archive
```

iOS, only if you are shipping the iOS update too:

```sh
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCH/Pawmodoro-ios.xcarchive" \
    -derivedDataPath "$SHIP/dd-ios" \
    -allowProvisioningUpdates archive
```

Expect `** ARCHIVE SUCCEEDED **`. `-allowProvisioningUpdates` is what lets
Xcode mint the profiles it needs; on 9 Aug it created a macOS store profile that
had never existed and refreshed two iOS ones, using a **cloud-managed** Apple
Distribution certificate. Nothing needs installing in Keychain, and
`security find-identity -v` listing only "Apple Development" afterwards is
correct rather than a problem.

### 4.2 Export

```sh
xcodebuild -exportArchive \
    -archivePath "$ARCH/Pawmodoro-mac.xcarchive" \
    -exportOptionsPlist "$SHIP/ExportOptions.plist" \
    -exportPath "$SHIP/mac-export" \
    -allowProvisioningUpdates
```

Produces `$SHIP/mac-export/Pawmodoro.pkg` (about 38 MB). The iOS form is the
same with `Pawmodoro-ios.xcarchive` and `-exportPath "$SHIP/ios-export"`, and
produces `Pawmodoro.ipa`.

Sanity check before you go further:

```sh
pkgutil --check-signature "$SHIP/mac-export/Pawmodoro.pkg"
```

`pkgutil` describes a Mac App Store package as *"signed by a developer
certificate issued by Apple (Development)"*. That is its wording for any
non-Developer-ID Apple certificate and is what this is supposed to look like.

### 4.3 Validate, then upload

`altool` needs an **app-specific password** — make one at appleid.apple.com →
Sign-In and Security → App-Specific Passwords, and store it in the keychain so
it is not in your shell history:

```sh
xcrun notarytool store-credentials PAWMODORO_ASC \
    --apple-id zhangcheng1997@gmail.com --team-id 6YFQ69HSD6
```

Then:

```sh
ALTOOL=/Applications/Xcode.app/Contents/SharedFrameworks/ContentDelivery.framework/Resources/altool

# Validate — safe, changes nothing, and is the last cheap failure before upload
"$ALTOOL" --validate-app -f "$SHIP/mac-export/Pawmodoro.pkg" -t macos \
    -u zhangcheng1997@gmail.com -p "@keychain:PAWMODORO_ASC"

# Upload — NOT REVERSIBLE
"$ALTOOL" --upload-app -f "$SHIP/mac-export/Pawmodoro.pkg" -t macos \
    -u zhangcheng1997@gmail.com -p "@keychain:PAWMODORO_ASC"
```

For iOS: `-f "$SHIP/ios-export/Pawmodoro.ipa" -t ios`.

**Validate first, every time.** It catches the icon, the plist and the
entitlement classes of rejection in a minute instead of forty.

The GUI route does the same thing: Organizer → select the archive → **Distribute
App → App Store Connect → Upload**. Either is fine. `notarytool` is not an
upload tool and cannot do this; Transporter from the Mac App Store is the other
GUI option.

Then wait for the "processing complete" mail before the build can be attached
to a version.

---

## 5. Screenshots

`mas-assets/` in this repo. Re-shot 10 Aug 2026 from `HEAD = 2897944`, after
the menu-bar fix, so they show the app as it is now.

- **`mas-assets/plain/`** — ten files, the window on a backdrop made from its
  own artwork, no text.
- **`mas-assets/captioned/`** — the same ten with one line of copy beside each.

**Upload one folder or the other. Do not mix them** — App Store Connect shows
the ten in a row and a half-captioned row reads as an accident. Pick `plain/`
if the listing copy is doing the talking or if you may ever localise.

All twenty are **1440 × 900, PNG, RGB, no alpha**, asserted by
`mas-assets/tools/build.py` rather than eyeballed. Apple's spec was re-read on
10 Aug: 1440 × 900 is still one of the four legal Mac sizes, 1 to 10 per
platform, no alpha.

Six of the ten are real running focus phases — Start pressed through the
accessibility API and the capture taken 45 to 195 seconds later — so every
countdown in the pictures is honestly that far in.

`mas-assets/README.md` has the per-file table and the provenance.
`mas-assets/raw/` is the evidence, not the art; **do not upload anything from
it.** It was shot from a Debug build, so the Settings capture in there shows the
"Redeem a code" button that Release does not have.

There are **no new iOS screenshots**. The iOS listing keeps the ones already on
the store.

---

## 6. The listening pass — do this on real hardware before you submit

Nothing in this repo can do it and nothing has done it. Sixty-five tracks and
about 120 ambience grades have never been heard by anyone on a real device.

**What to do:**

1. On a real iPhone, and on this Mac: play a music track. Play an ambience
   loop. Let a loop go round at least twice and listen to the seam.
2. Do it on **headphones** and on the **built-in speakers**.
3. **Change the output device while a track is playing.** Unplug the
   headphones mid-track. Connect Bluetooth mid-track. On the Mac, switch output
   in Control Centre mid-track.

**Why this and not something else.** Build 1 shipped **fifty tracks that were
unplayable on every real iPhone**. The player nodes were wired at the
hardware's format — stereo, 48 kHz — while every track is mono 22.05 kHz, and
`scheduleBuffer` raised an uncatchable Objective-C exception that killed the
process the instant any track was tapped. **No simulator could show it**,
because the Simulator negotiates a compatible format and a real phone does not.
It took a build to find and a build to fix.

The route change is the same bug wearing a different hat: a real output device
is 44.1 or 48 kHz and changes underneath you. `AVAudioEngineConfigurationChange`
handling went in with the fix and has never been exercised by a human pulling a
cable.

`tools/check_music.py` reads every shipped `.m4a` with `afinfo` and fails if any
is not 1 ch / 22.05 kHz. It passes. That proves the files are right. It cannot
prove the engine plays them.

---

## 7. Still unverified — read this before you press submit

Honest list. None of it is known-broken; all of it is unwitnessed.

**Will be seen by a reviewer, and nobody has checked it:**

- **The real StoreKit paywall has never completed a purchase.** Products
  listing, buying Plus, the entitlement surviving relaunch, and Restore are all
  unproven end to end. This is § 3 step 5 and it needs a Sandbox Apple Account
  password. What *is* proven is that if it fails, the App Sandbox is not why,
  and adding `com.apple.security.network.client` will not fix it
  (`MAC_APP_STORE.md` § 3.3).
- **The listening pass** — § 6.
- **The Mac repair work has been driven through the accessibility API, not by a
  human.** The onboarding button, the paged deck, the year card and the window
  geometry were each measured after the fix (the button reports 406 × 48 where
  it reported 46 × 20; the onboarding sheet reports zero tab groups; a dot click
  lands on card 5). Nobody has sat down and *used* it with a mouse. Hover states
  in particular cannot be synthesised on this machine and are unwitnessed by
  construction.

**Known and deliberately not fixed:**

- **Two compiler warnings survive, in both Release builds, measured today.**
  `Animation/BuddyAnimator.swift:219` — reference to captured `var self` in
  concurrently-executing code, *which is an error in Swift 6 language mode*, so
  it is a future build break rather than noise.
  `Views/GardenView.swift:82` — `kind` bound and never used. Neither affects
  review. The first one will stop a Swift 6 migration cold.
- **A bare Space bar is bound as a Start/Pause shortcut** in the `MenuBarExtra`
  menu. Read through the accessibility API the main menu bar carries no Space,
  so it should only be live while that menu is open — **type a space into the
  buddy rename field once** and confirm it does not start the timer.
- **`NSCameraUsageDescription` ships on macOS with no camera behind it**, and
  the iOS-only `Info.plist` keys (`UILaunchScreen`,
  `UIApplicationSceneManifest`, the orientation keys) are still in the Mac
  bundle. macOS ignores all of them. Cosmetic.
- **The Mac window is a phone column.** Width is clamped to a 160-point band on
  purpose — the scenes are exported at 396 × 858 and a wide window crops the art
  to a band of sky. It will not fail review. It is the first thing a Mac user
  notices.

**Assumed, not confirmed:**

- **That app privacy answers are presented once per app record rather than once
  per platform.** Confident, unconfirmed. If App Store Connect asks again for
  macOS, the answer is the same: Data Not Collected.
- **Whether "iPhone and iPad Apps on Mac" is currently on** for the iOS app.
  That is account state and is not visible from this repo. If it is on, two
  Pawmodoros appear in one Mac search result. § 3 step 2.

**Not in the app at all, and fine:** no Live Activities, no home-screen widget
and no shake gesture on macOS — all iOS-only by construction. Just do not
mention widgets in the Mac listing.

---

## 8. If you only remember four things

1. **Add Platform, not a new app.** § 3 step 1. One wrong click, permanent, and
   it costs every paying iOS user their purchase.
2. **The three agreements have to read Active**, or Plus and the tip jar cannot
   sell. § 2.
3. **Apply for the Small Business Program.** Nothing prompts you and it is half
   the commission. § 2.
4. **Listen to it on real hardware first.** § 6. This exact class of bug has
   shipped from this repo once already.
