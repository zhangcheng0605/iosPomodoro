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

## Fixed on the Mac, 8 Aug 2026 — after the two branches were merged

Six bugs found by walking the merged app, all reproduced first and all seen
fixed on screen. Every one of them is in the repo and none has shipped.

| Fix | Severity | Where |
|---|---|---|
| **Sharing the buddy's papers crashed the app.** `PapersCard` read `@Environment(TimerEngine.self)`, and the share sheet hands it to `ImageRenderer`, which lays content out in a *fresh* environment where the engine was never installed | **Fatal** | `Views/BuddyBookView.swift` |
| **Thirty-six species could roll a pale coat they had no sprite for.** `generate_pale_coats.py` ran once at 41 species and never again; the roster reached 81. The 1-in-300 sighting drew an *empty rectangle* and was written into the journal as if seen | **Invisible content, rarest event in the app** | `tools/generate_pale_coats.py`, 72 new imagesets |
| **The celebration card sat on top of the high five.** Centred full-screen, it covered the buddy, and its container `onTapGesture` + `allowsHitTesting` swallowed every tap — so a five could never be landed on any session that earned a card (every cycle, sighting and bond) | Feature unreachable | `Views/CelebrationView.swift` |
| **Every postcard was a band of sky.** `scaledToFill` cropped the vertical middle of a 396×858 scene into a 320×168 card, and the middle of every scene in this app is sky. Eight places, eight indistinguishable blue rectangles | **Every postcard, always** | `Views/PostcardView.swift` |
| **The drift countdown wrapped out of the dial.** Past one hour the string grows to seven glyphs in a 188pt column with no `lineLimit` | Layout | `Views/TimerRingView.swift` |
| **The homestead buried its own caption, then showed a blank slab.** The "next tree" line was an overlay in the corner where the well and bench stand; and a clean install drew a 180pt white rectangle that read as a loading failure | Layout | `Views/HomesteadView.swift` |
| **A renamed buddy signed every postcard with its factory name** — the one caption in the app that leaves the phone | Convention breach | `Views/PostcardView.swift`, `PostcardExport.swift`, `AlbumView.swift` |

Two new fences went in with them, both **deliberately broken first and watched
to fail**, per the rule that a green run on unbroken code proves nothing:

- `check_species.py` now requires the pale pair for every species that can roll
  one, and refuses one on a phenomenon. Nothing else could have seen this: the
  sprite name is built by interpolation, so `check_swift.py` cannot resolve it.
- `check_swift.py`'s Release-only `#if DEBUG` rule (added earlier in the merge).

Device Release measured after the new art: **37.7 MB. (The 45 MB ceiling was retired in Aug 2026 — see `CLAUDE.md`. Measure and justify rather than trip over a number nobody could explain.)**

### ~~Still open on the postcards~~ — CLOSED 9 Aug 2026

**Harbor Isle and Cloudspire no longer draw the buddy on open water and open
air.** The fix had in fact been written blind in `d880ce6` and never compiled
or looked at; this entry outlived it. Verified properly since.

The design call was *not* the `strayVisits` answer of omitting the buddy — a
postcard is of the place you reached, and a card with no buddy is a
screenshot. Instead `Place.footing` names the one surface with a top in each:
Harbor's jetty at (0.62, 0.736), Cloudspire's grassy cap west of the spire at
(0.36, 0.694). The crop stays anchored on `Stray.groundLine`, so the *place*
is still recognisable.

Verified by rendering rather than asserting: every place x 4 day-parts x both
card kinds, composited before and after. The six other places are **0 pixels**
different across all 48 cells; only Harbor and Cloudspire move. The panorama
is untouched by construction — `Place.footing` is read at exactly one line,
inside `standing`, and the panorama body calls neither `standing`, `cropTop`
nor `sceneImage`.

`check_postcard.py` was broken eight ways and caught all eight.

---

## Known and NOT yet fixed

0. ~~**On a small phone at the DEFAULT text size there is no play button.**~~
   **DECIDED, 9 Aug 2026 — the owner will not support small phones.** His
   words: "screw small phone, ignore them." Recorded as a decision rather
   than an open bug so nobody dispatches work on it again.

   The facts, kept because the decision should be re-examinable: on a
   375x667 screen at `content_size large` the transport row is off the
   bottom and the phase chip is behind the status bar. It is pre-existing —
   `ac8d928` fails identically — and it survives because the Dynamic Type
   fix hands the original view back verbatim at and below `.large`. The
   adaptive path itself is fine on that screen at larger text sizes.

   **The accepted risk:** App Review picks its own hardware, and a timer
   with no reachable start button reads as broken rather than unsupported.
   The likely fix remains one line — branch the adaptive column on
   available *height* rather than on text size alone. If a rejection ever
   cites it, that is the fix.

1. ~~**`Views/AlbumView.swift:35` — postcards rasterize on the main thread.**~~
   **Fixed, never compiled.** `Postcard` conforms to `Transferable` and the
   PNG is drawn once, on demand, after a tap; the share preview is a line of
   text built from the card's stored facts, because a `SharePreview` carrying
   an image wants that image up front. See `Views/PostcardExport.swift`. Needs
   a Mac build to confirm the API shapes — `check_swift.py` is blind to them.

2. ~~**iPad is declared but not designed for.**~~ **Decided:**
   `TARGETED_DEVICE_FAMILY = "1"` as of this branch — an iPhone app on
   purpose, which is the Deep Time plan's recommendation and the honest
   description of a layout with a dead band of scenery through the middle and
   the transport controls sitting on top of the house at iPad size. Revisit
   when Phase Y's Homestead panorama earns a big canvas.

   **This changes what App Review sees.** Anyone who installed 1.0 on an iPad
   cannot update to the next version. On a just-launched app that is close to
   nobody, which is exactly why now was the cheap moment to decide it. Undo is
   two characters in `project.pbxproj`, lines 273 and 303.

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
- **Everything audio, by ear.** Sixty-five music tracks and five one-shots have
  been
  verified structurally and never listened to. Given that all fifty tracks were
  silently unplayable on device until build 2, this is the single biggest
  untested surface in the app. **The four hour bells join this list** — sixteen
  WAVs whose levels `tools/check_bell.py` measures and whose *voices* nobody
  has heard. They fail soft: a bad file is a quiet hour and nothing on screen
  looks wrong. Play all four on a device, at night and at noon, before the
  release that carries them.
  **The fifteen W5 tracks are the newest entry, and one of them needs a
  particular listen:** the Rainy Day Tapes are the only music in this app
  written to be played *alongside* something, and the whole claim is that a
  42 % scoop at 1.15–3 kHz leaves room for the rain loop. That is a claim
  about two files heard together and no measurement made on either one
  separately can settle it. Turn on Rain, play Windowpane Study, and listen
  for whether either is fighting the other. The other ten want an ordinary
  ear-pass; the Soot's Tape five are the sparsest things in the catalogue and
  the failure mode to listen for is a music box that reads as a sine with a
  decay on it.
- **iPhone SE layout** — no SE runtime installed here. If the stray or the
  constellations collide with a control, move `Stage.x`, never
  `Stray.groundLine`. The homestead is the new entry here: its residents are
  hand-placed as fractions of a card `check_residents.py` assumes is 350pt
  wide, which is the padded stats sheet on the *narrowest* phone. A wider
  screen only spreads them out, so this is the safe direction — but it has
  never been drawn at any width.
- **The Scrapbook's Info.plist strings.** The photo picker needs no
  permission, so no usage string is strictly required today — but the moment
  anybody adds a camera path, `NSCameraUsageDescription` becomes mandatory and
  App Review rejects a build without it. The privacy nutrition label stays
  "data not collected": photographs are used, never collected.
- **The macOS half — written, and never compiled on any platform.** The
  target does not exist yet, so unlike everything else here this is not code
  waiting for a compiler, it is code waiting for a *target*. See section 17 of
  `docs/RESUME_HERE.md`. The one thing that must be right first time is the
  bundle identifier: universal purchase requires the Mac app to share the iOS
  app's, and it cannot be changed after the first archive.
- **The whole Deep Time build — nine phases written on Linux and never
  compiled.** Weather, the snail, the Drift, the Cabinet of Clocks, and all
  four altitudes of the Long Now (the shelf, the Sunday Post, the year ring,
  the Homestead). Ten checkers are green and every sprite has been rendered
  and looked at; no compiler has seen any of it. `docs/RESUME_HERE.md` is the
  running order for the first Mac session, in likelihood-of-error order.

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


---

## Owner verdicts, 9 Aug 2026 — settled, do not re-open

- **The re-voiced ambience is good.** He listened to the whole set,
  including the five that measured *toward* noise after re-voicing —
  `snowhush` and the three `raintent` variants. Verdict: keep. So the
  metric was right that they moved and wrong about what it meant: they
  were near-tonal before, which sounded like an artificial drone, and the
  extra texture is an improvement the number could not see. **A flatness
  figure ranks how noise-like a bed is; it does not rank how good it
  sounds.** Worth remembering the next time a measurement disagrees with
  an ear.

- **Alternate app icons work on real hardware.** He switched to the paw
  icon on his iPhone with no trouble. So the Simulator's
  "only one change succeeds per install" — where later taps never reached
  `setAlternateIconName` at all, surviving reinstall, SpringBoard restart
  and reboot — **is a Simulator defect, not an app bug.** No work needed.
  The structural gap that remains is only that the refusal line cannot
  render, since `refused` is set inside a completion UIKit sometimes never
  calls; on real hardware that path does not fire.
