# Pawmodoro — working notes for Claude

A SwiftUI Pomodoro timer for iOS 17+. No dependencies, no package manager, no
network calls, no test target. The whole app is `Pawmodoro/`.

**Current focus:** two plan documents, worked phase by phase.
`docs/DELIGHT_PLAN.md` covers feel (phases A–C are built; D needs a 30-second
Xcode step from the user first; E pending). `docs/CONTENT_PLAN.md` covers
content (journey worlds, sound studio, new buddies, themes, postcards) and
has the build order that interleaves both. Known quirk: the iOS 26.3
simulator runtime is missing the primary emoji font, so emoji in `Text`
views render as `?` boxes in the pane (the app itself no longer uses any).

## Running it

The app builds for the iOS Simulator with no signing setup — the bundle ID is
`com.zhangcheng.pawmodoro` and `DEVELOPMENT_TEAM` is empty — the team only
matters for a device, and is set in Xcode rather than here.

```sh
tools/run-sim.sh --demo --headless    # build, install, launch on the booted simulator
```

`--headless` skips opening Apple's Simulator app, which the iOS Simulator pane
doesn't need. With no `--device`, the script targets an already-booted
simulator, so it lands on whatever device the pane is showing.

The raw commands, if the script gets in the way:

```sh
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro -configuration Debug \
    -destination "id=$UDID" -derivedDataPath build/simulator \
    CODE_SIGNING_ALLOWED=NO build
xcrun simctl install "$UDID" build/simulator/Build/Products/Debug-iphonesimulator/Pawmodoro.app
xcrun simctl launch "$UDID" com.zhangcheng.pawmodoro -PawmodoroDemo
```

## Launch options — use these, the app is slow to check without them

Debug-only flags, defined in `Pawmodoro/LaunchOptions.swift` and compiled out of
Release builds. Pass them to `simctl launch` or to `tools/run-sim.sh`.

| Flag | Effect |
|---|---|
| `-PawmodoroDemo` | `-PawmodoroFastTimers` + `-PawmodoroSkipOnboarding` + `-PawmodoroSuppressNotificationPrompt` |
| `-PawmodoroFastTimers` | Minutes become seconds — a 25-minute focus phase ends in 25s |
| `-PawmodoroSkipOnboarding` | Straight to the timer |
| `-PawmodoroSuppressNotificationPrompt` | No permission alert covering the app |
| `-PawmodoroUnlockPlus` | Pretend Plus is owned, to see the locked content unlocked |
| `-PawmodoroSeedStats` | Two weeks of history, so the stats screen has data |
| `-PawmodoroResetState` | Clean-install state without deleting the app |
| `-PawmodoroCelebrate` | Fires a phase completion ~1.5s after launch, for the confetti and cycle card |
| `-PawmodoroClock <0-23>` | Pins the sky to one time of day (`-PawmodoroClock 22` for night + stars) |
| `-PawmodoroPlace <id>` | Start at a place, e.g. `-PawmodoroPlace cloudspire` |
| `-PawmodoroUnlockPlaces` | Treat every place as reached, without seeding history |

Without `-PawmodoroFastTimers`, verifying a phase transition means waiting 25
minutes. Without `-PawmodoroSeedStats`, the stats screen is empty.

Some things need a plain launch instead: the real onboarding flow, the
first-launch notification prompt, and the paywall's locked state.

## Things that behave differently in a simulator

- **Purchases don't load.** StoreKit only sees products when the app is launched
  from Xcode with `Pawmodoro.storekit` attached to the scheme. Installed with
  `simctl`, the paywall correctly shows its "store isn't available" state — that
  is not a bug to fix. Use `-PawmodoroUnlockPlus` to check the entitled UI.
- **Haptics do nothing.** `UINotificationFeedbackGenerator` is a no-op there.
- **Audio plays through the Mac.** Ambience only runs while the timer is running.
- **Notifications** fire, but the app must be backgrounded (`Cmd+Shift+H`) to see
  the banner.

## Verifying a change

There are no tests. A change is verified by building and looking at it:

1. `tools/run-sim.sh --demo --headless`
2. Drive the screen the change touched.
3. For anything visual, check it in both appearances — dark mode is
   `xcrun simctl ui "$UDID" appearance dark` — and in all four themes, which is
   what `AppTheme` in `Pawmodoro/Model/AppTheme.swift` covers.

## Conventions worth keeping

- **Colours go through `Theme`**, never literal `Color` values. That is what
  makes theme switching redraw and what keeps the measured contrast honest —
  every text/background pair in every theme clears 4.5:1, in both appearances.
  Adding a raw colour quietly breaks both.
- **Scenery is generated too.** `tools/generate_scenes.py` draws each place
  once into a grid of palette indices and exports it four times, one per time
  of day — the grade is a palette transform, and the window index is exempt
  from it so windows light up after dark. It asserts that the rows behind the
  countdown contain sky only; if a composition drifts upward it fails loudly.
  Never suppress its stderr — an art bug looks exactly like success otherwise.
- **Text over scenery sits on its own backing.** The timer face, the buddy
  caption and the paw row each carry a theme-coloured capsule, because with a
  place behind the app the background is no longer a known colour. Removing
  one will fail the contrast check.
- **Run `python3 tools/check_contrast.py` after touching a palette.** It reads
  the real values out of `AppTheme.swift` and blends the time-of-day sky wash
  over every phase background, in every theme and appearance — 216 pairs. The
  wash is safe because `Palette.sky(_:)` mixes each hue toward `cream` first,
  which pins its luminance near the background's; lowering `Palette.skyMix`
  will fail the check. It also samples the real exported scene pixels behind
  every text row — 51k measurements, a couple of seconds.
- **Animation is driven by `TimelineView`, never by a `Timer`.** A timeline
  stops when its view is off screen or the app is backgrounded, so an idle app
  costs nothing. Loops run at 2–4fps, bursts at 8fps, particles at 30fps, and
  a canvas is only mounted while it has something to draw.
- **The countdown derives from an absolute end `Date`**, never accumulated
  ticks; iOS suspends backgrounded apps. Don't convert `TimerEngine` to a
  tick-counter.
- **New user-facing state gets a key in `StorageKeys`** (`LaunchOptions.swift`),
  so `-PawmodoroResetState` keeps working.
- **Locked content is shown with a padlock, never hidden**, and tapping it opens
  the paywall.
- Every asset is generated by `tools/generate_assets.py` and
  `tools/generate_sprites.py` — edit the script, not the PNG.

## Watch out

- The code was written without a Mac, so parts of it have never been compiled.
  A build error is more likely to be a real slip than an environment problem.
- `Pawmodoro/` is a file-system synchronized group: new files are picked up
  automatically, and `project.pbxproj` doesn't need editing to add one.
- Product IDs in `Store/StoreIDs.swift` must match the bundle ID prefix and
  `Pawmodoro.storekit`. A mismatch doesn't fail the build; the store just
  returns nothing.
