# Ship these in the next update

Read this before starting any new work on Pawmodoro. Everything here is
already known, already diagnosed, and not yet in front of users.

**Status of what is live:** version 1.0, build 2, bundle `com.pawmodoro.zhangcheng`,
App Store name **Paawmodoro**.

---

## Already fixed in the repo, waiting on a release

These are **committed and archived into build 2**. If build 2 reached the
store, they are shipped and this section can be deleted. If 1.0 went out as
**build 1**, then every one of these is still broken for users and build 2 is
the fix — get it out.

| Fix | Severity | Where |
|---|---|---|
| Music crash: player nodes wired with `format: nil` (hardware stereo 48 kHz) while every track is mono 22.05 kHz — `scheduleBuffer` raised an uncatchable ObjC exception and killed the app the moment any track was tapped | **Fatal, 100% reproducible on device, all 50 tracks** | `Audio/MusicPlayer.swift` |
| Returning from background started a player node on a paused engine — same uncatchable throw | **Fatal** | `Audio/MusicPlayer.swift` |
| Decoded-buffer cache never evicted: ~2.4 MB per track × 50 ≈ 120 MB of dirty memory, and radio mode walks the catalogue unattended | Memory / jetsam risk | `Audio/MusicPlayer.swift` |
| No `AVAudioEngineConfigurationChange` observer — unplugging headphones left the cached format describing a graph that no longer existed | Crash risk on route change | `Audio/MusicPlayer.swift` |
| `MusicPlayer` never configured `AVAudioSession`; it relied on the ambience channel having run first | Silent no-audio | `Audio/MusicPlayer.swift` |
| Dream diary caption claimed a nocturnal buddy "sleeps through every session" — untrue for Luna, who keeps watch at night | Copy | `Views/DreamView.swift` |
| Long place names truncated to "Whispering Wo…" in the picker | Layout | `Views/PlacePicker.swift` |

**The lesson worth keeping:** the music crash could not be seen in the
Simulator, because the Simulator negotiates a compatible audio format and a
real iPhone does not. Anything touching `AVAudioEngine` has to be tried on a
device before it ships.

---

## Known and NOT yet fixed

1. **`Views/AlbumView.swift:35` — postcards rasterize on the main thread.**
   Opening the stats sheet renders every postcard twice at export size, on the
   main thread. A stutter today, and it gets worse the more postcards a user
   collects. Render lazily, or at thumbnail size, and move export-size
   rendering to the moment someone actually shares one.

2. **iPad is declared but not designed for.** `TARGETED_DEVICE_FAMILY = "1,2"`,
   so the app installs on iPad and Apple reviews it there. It runs, but the
   layout has a large dead band of scenery through the middle and the transport
   controls sit on top of the house. Either lay it out properly for the larger
   canvas, or set `TARGETED_DEVICE_FAMILY = "1"` and be an iPhone app on
   purpose. Right now it is neither.

3. **The app calls itself "Pawmodoro" in 16 user-visible strings** while the
   App Store listing says "Paawmodoro" (the shorter name was taken). Onboarding
   says "Welcome to Pawmodoro" right after someone downloads "Paawmodoro".
   Apple permits the mismatch; decide whether you want it.

---

## Never verified, on any device or Simulator

Carried over from `RESUME_HERE.md`. None of these has ever been seen working:

- **Scene toys** — tap water for rings, swipe to skip a stone, the firefly that
  follows a finger at night. Pane input latency defeats verification; a real
  device with real fingers is the only way.
- **Eye tracking** — pupils following a drag.
- **Snow-globe shake** — needs Simulator.app or a device.
- **Micro-encounters and journal regulars** — `-PawmodoroEncounter` and
  `-PawmodoroFillJournal <n>` were added for exactly this and have now been
  used once each; the *organic* paths (1-in-12 odds, five real sightings)
  still have not run.
- **Everything audio, by ear.** Fifty music tracks and five one-shots have been
  verified structurally and never listened to. Given that all fifty tracks were
  silently unplayable on device until build 2, this is the single biggest
  untested surface in the app.
- **iPhone SE layout** — no SE runtime installed here. If the stray or the
  constellations collide with a control, move `Stage.x`, never
  `Stray.groundLine`.

---

## Features specced but unbuilt

- **Alternate app icons** — one per buddy out of `make_icon` in
  `generate_assets.py`, plus `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS`
  and `UIApplication.setAlternateIconName`. Not a new target.
- **Phase E2 accessories** — ~200 imagesets. Verifiable from Linux by writing a
  `check_accessories.py` that composites each overlay onto each frame, the way
  `check_stray.py` measures the stray.
- **Live Activity target** — the code is all written; only the Xcode
  Widget Extension target step is missing. See `docs/LIVE_ACTIVITY.md`.

---

## Two traps that will waste an hour if forgotten

- **This repo is on the iCloud-synced Desktop.** The sync service stamps
  `com.apple.FinderInfo` on the built bundle and `codesign` refuses it
  ("resource fork, Finder information, or similar detritus not allowed").
  Always build and archive with `-derivedDataPath` pointing outside the synced
  folder. Xcode's own Product → Archive will hit this.
- **Never click into the Bundle Identifier field in Xcode.** It was left
  focused once and picked up a stray keystroke, silently becoming
  `com.pawmodoro.zhangchenso-`. A wrong bundle ID uploads fine and then fails
  to match the App Store record.
