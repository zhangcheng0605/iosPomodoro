# Mac App Store — the visual assets

Companion to `docs/MAC_APP_STORE.md`, which works out *whether* and *how* the
app can ship on the Mac App Store. This file is only about the pictures: the
app icon and the screenshots. It also records the Mac bugs the screenshot
passes walked into, because some of them are in the shots and one of them
**is** a shot.

Everything produced sits outside the repo, in three scratch directories:

```
…/scratchpad/mas-assets/          the 8 Aug pass (icon preview, first six candidates)
…/scratchpad/mas2/                the 9 Aug afternoon pass (eight candidates)
…/scratchpad/mas-assets/final/    the 9 Aug evening pass — THE FINAL SET
```

where `…` is
`/private/tmp/claude-501/-Users-zhangcheng-Desktop-iosPomodoro/efd66388-5c4b-4ba5-a1b2-7351e3e69bdb`.

The final set was shot from a **Debug macOS build made at 20:47 on 9 Aug**,
from the working tree at that moment (`55faf15` plus the in-flight scenery
work). Other workflows edited `Antics.swift`, `Buddy.swift`,
`PomodoroSettings.swift`, `TimerEngine.swift`, `PaywallView.swift` and
`SettingsView.swift` after that build. Nothing in those files is visible in
these ten shots as far as this pass can tell, but if a buddy sprite, a preset
or the paywall changes, re-shoot rather than assume.

Nothing in `Assets.xcassets`, `tools/`, `Pawmodoro/` or the project file was
touched by any of them. **Scratch is not backed up — copy the final set
somewhere real before you rely on it.**

---

## Summary

| Asset | State | Where |
|---|---|---|
| **Mac screenshots — final set** | **Ten, at 1440 × 900, plain and captioned.** RGB, no alpha, asserted by `compose.py` | `mas-assets/final/out/plain/`, `…/out/captioned/` |
| Raw window captures | ~80, including sweeps and rejects | `mas-assets/final/raw/` |
| 2560 × 1600 / 2880 × 1800 | **Not produced, and cannot honestly be from this Mac.** § 2.4 | — |
| macOS app icon | Changed under me while this was written — § 1 | `Pawmodoro/Assets.xcassets/AppIcon.appiconset` |
| Menu-bar-extra screenshot | **Still cannot be taken: the menu bar extra is still broken.** Re-measured on tonight's build, § 3.1 | `mas2/zz-menubar-evidence.png` |

Which set to upload: **`out/plain/`** if the listing copy is doing the talking,
**`out/captioned/`** if it is not. Do not mix them — App Store Connect shows
the ten in a row and half-captioned reads as an accident. The captions are one
line each, SF Rounded, `Theme.bark`, measured at 6.9 : 1 contrast or better
against their own backdrop.

---

## 1. The app icon — read this before believing anything

**The ground moved while this pass was running.** At the time the Mac build
used for these screenshots was made (Debug, 20:47 tonight), the icon was still
missing exactly as the 8 and 9 Aug write-ups said: the built Mac `Info.plist`
had no `CFBundleIconName` and the bundle had no `.icns`.

By the end of the pass, `AppIcon.appiconset/Contents.json` had **eleven**
entries — the original universal 1024 tagged `"platform": "ios"`, plus the full
ten-entry `"idiom": "mac"` ladder (16/32/128/256/512 at 1× and 2×). That is
another workflow's work landing, and it is the right shape. **It has not been
built or verified here**, and a populated asset catalogue is not the same thing
as an icon in the bundle.

The check that means anything, on a *fresh* build:

```sh
plutil -p <built>.app/Contents/Info.plist | grep -i icon      # must not be empty
assetutil --info <built>.app/Contents/Resources/Assets.car \
  | grep -c '"Name": "AppIcon"'                               # the exact name
```

One trap worth keeping, because it nearly produced a wrong "it's fixed" twice:
`assetutil --info Assets.car | grep -c AppIcon` returns **20**, and none of
those twenty is the app icon. They are `iconpreview_AppIcon`,
`iconpreview_AppIconEmber`, … — the pictures the alternate-icon picker shows,
at 44 pt and 88 pt. Count the ones whose name is exactly `AppIcon`, or read
`CFBundleIconName` out of the built `Info.plist`, which is what App Store
Connect reads.

Everything else about the icon — why the ladder is required, the squircle
geometry a macOS icon needs that an iOS one does not, and what
`tools/generate_assets.py` would have to grow — is unchanged from the 8 Aug
write-up and is preserved in `mas-assets/icon/` alongside a 1024 preview and
the ten rendered sizes.

---

## 2. Screenshots

### 2.1 The ten that are ready to upload

`mas-assets/final/out/plain/` — the window (or the sheet) centred, shadowed, on
a backdrop made from its own artwork. No text.
`mas-assets/final/out/captioned/` — the same art on the left, one line of SF
Rounded copy on the right.

All twenty files are **1440 × 900, mode RGB, no alpha channel**, asserted in
`compose.py`'s own check rather than eyeballed.

| # | File | What it shows | Caption |
|---|---|---|---|
| 01 | `01-meadow-day` | Meadow Home, clear, midday, sakura theme. A **running** focus phase at 24:13, Mochi asleep, the drifting cloud sheet and the new near-plane grass both visible | Twenty-five minutes somewhere quiet |
| 02 | `02-woods-night` | Whispering Woods at 22:00, midnight theme, Luna the owl awake ("owls work night shifts"), stars out, 23:43 | After dark the wood carries on without you |
| 03 | `03-homestead` | The stats sheet: 14-day streak, 200 all-time, the week chart, and **the homestead** — 83 trees, one per hour, with the pond, birdhouse, hive, well, bench and basket among them | One tree for every hour you have ever sat |
| 04 | `04-peaks-snow` | Starfall Peaks, winter, snow falling, snowdrift theme, Pebble the penguin, 23:13 | The season and the weather are the real ones |
| 05 | `05-field-journal` | The field journal — **81 of 81**, Meadow Home 14/14 and Whispering Woods 18/18, each animal with its own sketch and its own sentence | Eighty-one animals, and not one of them for sale |
| 06 | `06-blossom-sakura` | Blossom Village in blossom season, petals falling, Maple the red panda, 22:43 | Eight places, and you walk to every one |
| 07 | `07-sound-studio` | The Sound Studio: the ambience list (Off through Embers), the ambience/music mixer, Radio, and the first mixtape | Eighteen ambiences and sixty-five tracks, none of it streamed |
| 08 | `08-harbor-day` | Harbor Isle at noon, high tide, matcha theme, Pip the otter, 22:13 | The tide turns whether or not you are watching |
| 09 | `09-postcards` | The year ring, the shelf of hours, and **two postcards** — "The whole wood" and "Made it to Whispering Woods", both signed by Mochi | A postcard arrives when you get somewhere new |
| 10 | `10-cloudspire-day` | Cloudspire — the floating island — lavender theme, Yuzu the fox, 21:43 | Somewhere further, every time you go |

Six places, six buddies, six themes, four seasons, day and night, snow and
petals; four different screens.

Every one carries these flags:

```
-PawmodoroSkipOnboarding -PawmodoroSuppressNotificationPrompt
-PawmodoroUnlockPlus -PawmodoroUnlockPlaces -PawmodoroUnlockSounds
-PawmodoroUnlockMusic -PawmodoroSeedStats -PawmodoroBond 200
```

plus, per shot, `-PawmodoroClock`, `-PawmodoroWeather`, `-PawmodoroSeason`,
`-PawmodoroTide`, and a `-pawmodoro.settings` blob in the **argument** domain
that pins place, buddy, theme, ambience and a 25/5 preset for that one launch
without writing anything to disk. The sheet shots add `-PawmodoroFillJournal 5
-PawmodoroPostcard -PawmodoroPanorama -PawmodoroFillDreams -PawmodoroBloom
-PawmodoroFillDrawer -PawmodoroKeepsakes 6 -PawmodoroClockRing 23
-PawmodoroSeedChronicle -PawmodoroFillTastes -PawmodoroFindTapes
-PawmodoroPhoto -PawmodoroDevelop -PawmodoroAnthology`.

**`-PawmodoroDemo` is still the wrong flag for store art.** It expands to
include `-PawmodoroFastTimers`, and a 25-minute phase then ends in 25 seconds:
the first pass photographed a clock reading `00:25`, which looks like a broken
app. Six of these ten are real running sessions instead — see § 2.3 — so the
countdown in each picture is honestly the number of seconds the shot waited.

Two things to know before believing these pictures:

- **They come from the working tree, not from `HEAD`.** The drifting cloud
  sheet and the near plane (`SceneForegroundView`, `scene_*_fg`) are in-flight
  work by another workflow, and they are in every scenery shot — they are
  also, frankly, most of why these look better than the 8 Aug set. If that
  work is reverted or reworked, re-shoot.
- **This is a Debug build**, because every flag above is compiled out of
  Release. Nothing visual differs; `LaunchOptions` is the only difference.

### 2.2 Why every Mac screenshot is a composite

Re-measured, unchanged: the window comes back **400 × 912 px** every time and
`.windowResizability(.contentSize)` pins it. 912 > 900 and 1824 > 1800, so no
scale drops a raw grab into a legal canvas. `compose.py` scales the capture to
812 px tall (0.89 ×) and centres it, leaving 44 px of margin.

The backdrop is the one design decision worth defending. It is **not** a stock
desktop and **not** an invented gradient: it is the shot's own artwork,
enlarged, blurred to 90 px and lifted 46 % toward the app's cream, with a wide
soft corner darkening to seat the window. So the snow shot sits on a cold
field, the onsen on a warm one, and **no colour on the canvas is a colour the
app does not already use.** That is the same argument `Theme` makes about
literal `Color` values, applied to marketing art.

### 2.3 Getting a *running* session into a shot, without touching the mouse

The owner is using this machine, so nothing here moves the cursor or fronts a
window. Three techniques carry the whole pass:

```sh
# start a real focus phase — no cursor, no fronting, no FastTimers
osascript -e 'tell application "System Events" to tell process "Pawmodoro" \
  to perform action "AXPress" of menu item "Start" of menu 1 \
  of menu bar item "Session" of menu bar 1'

# open a sheet: toolbar buttons 1..3 are Stats, Sound Studio, Scrapbook
osascript -e '… perform action "AXPress" of button 1 of toolbar 1 of window 1'

# scroll a sheet to any position, in one launch, with no input events
osascript -e '… set value of scroll bar 1 of scroll area 1 of group 1 \
  of sheet 1 of window 1 to 0.23'
```

That third one is new and it is what made the sheet shots possible.
`StatsView` is a single long `ScrollView` — almanac, Sunday Post, bond,
homestead, year ring, shelf of hours, postcards, star atlas, field journal,
dream diary, garden, drawer, mailbox, photo shelf, timetable, setlist,
fortunes — so the homestead, the journal and the postcards are the *same
window* at different scroll offsets. `sweep_stats.py` opens the sheet once and
captures a ladder of them; a relaunch per frame would have cost fifteen seconds
each.

What none of this buys: the SwiftUI content of the **main window** is still not
enumerable through System Events (`entire contents of window 1` returns zero
elements), so nothing inside the timer screen can be pressed. Sheets are the
exception, and only because their scroll area surfaces as a real `AXScrollArea`.

**Two hazards, both of which cost time tonight.** First, `screencapture -l`
against a window whose sheet is open returns the **sheet's** window, at
470 × 924, with the parent's dimmed title bar as the top 52 rows — which is why
`compose.py` crops sheets at `(0, 52, 470, 924)`. Second, and worse: two other
workflows had their own Pawmodoro builds running, and
`tell process "Pawmodoro"` binds to *a* process of that name, not yours. The
symptom is `Can't get window 1 of process "Pawmodoro". Invalid index. (-1719)`
while your own capture-by-`CGWindowID` succeeds — proof that the window exists
and System Events is looking at somebody else's process. Check `pgrep -fl
Pawmodoro` before blaming your script, and **never `pkill -f Pawmodoro`**;
match on your own derived-data path.

### 2.4 The 2× set, and why there isn't one

`system_profiler SPDisplaysDataType` on this Mac:

```
Odyssey G95NC:  Resolution: 7680 x 2160    UI Looks like: 7680 x 2160
```

One point per pixel. `screencapture` therefore returns 1× art, and a
2880 × 1800 set built from it would be a 2× upscale sold as Retina. It was not
made, and it should not be faked.

To get one: run `mas-assets/final/shot.py`, `scenery.py` and `sweep_stats.py`
unchanged on any Retina Mac, then set `W, H = 2880, 1800` and `SHOT_H = 1624`
in `compose.py`. Everything else scales.

1280 × 800 is also legal and is a *downscale* of what exists, so it is honest
today: set `W, H = 1280, 800` and `SHOT_H = 722`.

### 2.5 The two things the previous pass flagged — both re-measured

**"A sleeping animal drawn on top of the ambience row at peaks/day."**
**Reproduced.** It is the old snail, and § 3.3 has it. One refinement the
previous pass did not have: it happens on the **idle** screen and not while a
phase runs. On idle the transport is one Play button and there is a second chip
row, which lifts the ambience row about 64 px; at `-PawmodoroSnail 50` her foot
lands exactly on the top edge of the fourth chip. In a running phase the row
sits lower and she clears it — in `04-peaks-snow` she is standing on a fence
rail in the near plane, which reads as charming rather than broken. **The bug
is real; it is just not in any of the ten.**

**"A harbor/golden capture that came out a flat beige wash."** The previous
pass concluded it was the dusk *grade* rather than the golden weather. That is
right, and here is the control it did not run — the same place and weather at
two times of day. Per-channel standard deviation over the two vertical strips
of pure scenery the UI never covers (x 0–55 and 345–400, y 430–700):

| Shot | sd (R, G, B) | mean | vs clear/day |
|---|---|---|---|
| harbor, **clear, day** | 27.2, 20.3, 19.3 | 22.3 | — |
| harbor, **golden, day** | 20.2, 15.3, 14.8 | 16.8 | **0.75 ×** |
| harbor, **clear, dusk** | 10.3, 10.2, 9.4 | 10.0 | **0.45 ×** |
| harbor, **golden, dusk** | 8.6, 8.9, 9.2 | 8.9 | 0.40 × |

`Weather.golden.veilOpacity` is 0.26, and an alpha blend can only scale
contrast by (1 − a) = 0.74. Golden-at-day measures 0.75 ×, which is the veil
and *nothing but* the veil — the weather is exactly as expensive as the
arithmetic says and no more. Dusk costs 0.45 × on its own, and that is where
the beige wash came from. **Golden weather is fine for store art; dusk and dawn
are not.** All ten are day or night.

### 2.6 Things in these shots you may want changed before uploading

None of these is a defect that blocks a submission. All are visible in the art.

- ~~**The window title says "Pawmodoro"; the App Store name is
  "Paawmodoro".**~~ **Decided 10 Aug 2026 — keep both, upload as shot. No
  change to the screenshots is needed.** The shipped iOS archive (1.0 build 2)
  has `CFBundleName = Pawmodoro` and no `CFBundleDisplayName`, so *Pawmodoro*
  is already the name on every existing user's Home screen; and "Pawmodoro" was
  never available on the App Store, which is why the record is "Paawmodoro" in
  the first place. Both store descriptions already close by explaining the two
  a's, and the App Review notes say it outright. Full reasoning in
  `docs/NEXT_UPDATE.md` § "Decide before the next submission", item 3.
- **The toolbar overflows on the idle screen.** Five toolbar items (Stats,
  Sound Studio, Scrapbook / Settings, Bench) do not fit 400 pt, so macOS
  collapses the trailing ones behind a `»` chevron and the gear disappears.
  During a focus phase the camera button hides itself and everything fits,
  which is why no shot here shows the chevron — but the first thing a user
  sees does.
- **A macOS sheet comes up 470 pt wide over a 400 pt window** — wider than its
  own parent, overhanging 35 pt on each side. That is why every sheet shot here
  is cropped to the card rather than shown attached. Cosmetic, and odd.
- **Harbor Isle's water has white specks painted into it.** They are in
  `scene_harbor_day.png` itself — sea sparkle, not weather and not the near
  plane; `scene_harbor_day_fg.png` is opaque only in rows 720–858. At full size
  they read as sparkle. At thumbnail size they read as snow, in August.
- **The star atlas reads "0 of 7 — none of them yet"** in any shot that
  includes it, and cannot be made to read otherwise with these flags. See
  § 4.1: that is two debug-flag bugs rather than an app bug, but it is why
  `09-postcards` stops where it does.

---

## 3. The bugs

### 3.1 The menu bar extra draws the buddy at ~400 pt — STILL BROKEN

Re-measured tonight through the accessibility API, on a build made from the
current working tree:

```
menu bar item 1 of menu bar 2  →  position {6191, -189}   size {418, 402}
```

A 402-point-tall status item, unchanged from the 9 Aug measurement of
{418, 402}. `MenuBarBuddy.swift:23` asks for `BuddySprite(…, size: 16)`; what
the menu bar shows is a clipped horizontal band of orange cat. `git log` on
that file has no commit since. Evidence at 3×, idle above and running below:
`mas2/zz-menubar-evidence.png`.

`BuddySprite` is not at fault — it applies `.frame(width:height:)` and draws
correctly everywhere else at every size. The context is:
`PawmodoroApp.swift` hands an arbitrary `View` to `MenuBarExtra`'s `label:`
with `.menuBarExtraStyle(.menu)`, and that label is rendered from the view's
own idea of its size rather than being constrained to the status bar's height.
The fix known to behave is to give `MenuBarExtra` an `Image` or `Label`
directly — a pre-sized `NSImage`, or `Image(nsImage:)` with `size` set —
rather than an `HStack`.

**This is why there is no menu-bar screenshot.** `MAC_APP_STORE.md` § 5.2 calls
the menu bar extra the one thing no iPhone shot can show and wants it first in
the listing. It cannot be photographed, and it is the first thing a Mac user
will see.

### 3.2 The Scrapbook's missing import control — FIXED, and verified on screen

The 9 Aug entry said the Scrapbook had no way to add a picture on macOS,
because its `PhotosPicker` sat in `ToolbarItem(placement: .topBarLeading)` and
a Mac sheet silently drops that placement.

**That is fixed in the current tree and it was checked, not assumed.** The
picker now lives in the sheet's *content* as the first cell of the grid, and a
capture of the Mac Scrapbook sheet shows a dashed **＋ Keep one** tile ahead of
the kept photographs: `mas-assets/final/raw/V6-scrapbook.png`. The placement
table that explains the original bug is now written into `Platform.swift`'s
toolbar shim, which is the right place for it.

What is still not verified on macOS: an actual import all the way through
`SnapshotImport.prepare` to a file in the container. `MAC_APP_STORE.md` § 3.3
says the sandbox permits it; nobody has yet picked a picture on this platform
and seen it land.

### 3.3 The old snail stands on the ambience row — CONFIRMED, and narrowed

`-PawmodoroSnail 50 -PawmodoroPlace peaks -PawmodoroClock 12`, idle: her foot
sits on the top edge of the fourth ambience chip and she reads as climbing on
the UI. `mas-assets/final/raw/V1-peaks-snail-50.png`, zoomed in
`…/raw/zz-V1-snail.png`; the 8 and 9 Aug passes caught the same thing.

New tonight: **it is the idle screen only.** During a focus phase the ambience
row sits about 64 px lower (one Pause button instead of the preset row and the
photo chip) and she clears it — `raw/03-peaks-snow.png` has her on a fence rail
instead, which looks deliberate.

`Snail.groundLine` is 0.79 of the screen, the same value as `Stray.groundLine`,
and `tools/check_snail.py` asserts there is scenery under her feet at every x
of every place she visits. It has no opinion about what the *app* draws over
that scenery. This is the lesson in `CLAUDE.md` about the residents buried in
the grove, again: **composite the finished surface**, not just the sprite over
the art.

Still not confirmed on iOS. The Mac window is 400 × 900 of which ~52 goes to
the title bar, so the content is ~400 × 848 against the iPhone's 396 × 858 —
the same aspect to within 1 %, and everything involved is placed by a fraction
of it. One `-PawmodoroSnail 50 -PawmodoroPlace peaks` launch on an iPhone
simulator settles it.

---

## 4. How to redo any of it

```sh
cd …/scratchpad/mas-assets/final

python3 scenery.py                      # the six window shots, each a real run
python3 sweep_stats.py T 0.1,0.15,0.2 1 # sheet frames: prefix, scroll values, toolbar button
python3 verify.py                       # the § 2.5 and § 3 measurements
python3 compose.py                      # raw/ -> out/plain/ and out/captioned/
```

`shot.py` is the engine — launch with flags, press what needs pressing through
the accessibility API, capture every layer-0 window the process owns by
`CGWindowID`, kill only the instance it started.

Six things about this machinery cost time and are worth keeping:

- **`open -n` does not work for this app.** LaunchServices resolves
  `com.pawmodoro.zhangcheng` to an App Store *placeholder* bundle, so `open`
  returns 0 and nothing starts. `launch.py` double-forks, `setsid`s and
  `execv`s the executable directly.
- **Capture by `CGWindowID`, never by screen rectangle.** `screencapture -R`
  grabs whatever is on top of that rectangle. `wins.swift` lists window ids for
  one pid and `screencapture -x -o -l <id>` captures that window even when it
  is covered, without fronting it and without moving the cursor.
- **`tell process "Pawmodoro"` is ambiguous when another workflow is also
  running a build.** § 2.3 has the symptom and the fix.
- **Never name a shell variable `LINES` in zsh.** It is a special integer
  variable; assigning window-list text to it fails with `bad math expression:
  lvalue required`, pointing at the assignment line. Half an hour.
- **`log` is a zsh builtin.** `log show …` inside a `zsh -c` silently becomes
  "too many arguments" and you get an empty log file rather than an error you
  can read. Use `/usr/bin/log`.
- **Set the app's settings through the argument domain, not by writing
  defaults.** `NSUserDefaults` reads `-<key> <value>` off the command line into
  a volatile domain that outranks the stored one, so
  `-pawmodoro.settings "<7b22666f…>"` (the settings JSON as a hex data literal)
  pins preset, ambience, theme, place, buddy and clock face for one launch and
  writes nothing to disk. This is how every shot reads 25:00 rather than the 50
  minutes the owner's Mac is actually set to.

### 4.1 Three debug-flag traps that shaped these screenshots

All three are in `LaunchOptions.swift`, all three are Debug-only, and none of
them touches a shipping user. They are written down because each one silently
produced a *plausible* screenshot that was not the state asked for.

**`-PawmodoroSnail -1` can never work.** `LaunchOptions.value(after:)` returns
`nil` for any value beginning with `-`, so the documented "sends her away" form
parses as no value at all and `forcedSnail` comes out `nil` — the derived
position, which is the opposite of what was asked. Both `CLAUDE.md`'s flag
table and the property's own doc comment promise it. Every valued flag that
could take a negative number has the same hole.

**`-PawmodoroBond n` discards `-PawmodoroSeedStats` and
`-PawmodoroNightSessions`.** `seedSessionCount` *replaces* `StorageKeys.sessions`
outright, while `seedNightSessions` reads the existing records and appends —
and `applyAtLaunch` runs the appending one first. So `-PawmodoroSeedStats
-PawmodoroNightSessions 40 -PawmodoroBond 200` yields exactly the 200 records
Bond wrote, all of them at 9 a.m. onwards.

**`log.nightSessions` is judged against the pinned `-PawmodoroClock` hour.**
So even seeding night sessions alone does not light the star atlas while the
clock is pinned to noon. Between the two, the atlas card reads "0 of 7 — none
of them yet" in every sheet shot here. To photograph a lit atlas: drop
`-PawmodoroBond`, and use `-PawmodoroClock 22 -PawmodoroNightSessions 45
-PawmodoroTraced`.

### 4.2 The owner's Mac state — backed up and restored this time

The 8 Aug pass backed up the wrong thing: `defaults export
com.pawmodoro.zhangcheng` redirects into the sandbox **container**
(`~/Library/Containers/…`), while the unsandboxed Mac build writes
`~/Library/Preferences/com.pawmodoro.zhangcheng.plist`. So that pass left
`pawmodoro.lifetimeSessions = 200` on the owner's Mac and could not undo it.

This pass copied the file itself before the first launch and copied it back at
the end, and checked with `cmp` that the restored file is byte-identical to the
backup:

```sh
cp ~/Library/Preferences/com.pawmodoro.zhangcheng.plist /somewhere/safe.plist
… run everything …
cp /somewhere/safe.plist ~/Library/Preferences/com.pawmodoro.zhangcheng.plist
killall -u "$USER" cfprefsd      # or cfprefsd flushes its cache over you
cmp -s /somewhere/safe.plist ~/Library/Preferences/com.pawmodoro.zhangcheng.plist
```

The backup and the dirty copy are kept at
`mas-assets/final/PREFS-BACKUP-BEFORE-LNCH.plist` and
`…/PREFS-AFTER-LNCH-dirty.plist`. Note this restores the Mac to the state the
8 Aug pass left it in — the 200 lifetime sessions are still there, because no
witness to the value before *that* exists.

---

## 5. What App Store Connect will and will not object to

Checked against Apple's [screenshot
specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/).

**Will pass:**

| Requirement | These files |
|---|---|
| One of 1280 × 800, 1440 × 900, 2560 × 1600, 2880 × 1800 | **1440 × 900**, all twenty, asserted |
| PNG or JPEG | PNG |
| **No alpha channel** | mode `RGB`, no `transparency` chunk, asserted |
| 1 to 10 per platform | **10** |
| 16:10 | 1440 : 900 = 16 : 10 |

**Will not be objected to, but is worth a decision:**

- **The name in the title bar** (§ 2.6). Review does not compare a title bar to
  a store name, but a customer does.
- **No menu bar extra in the set** (§ 3.1). The Mac listing's whole argument is
  a feature that cannot currently be photographed. `docs/MAC_LISTING.md` is
  another workflow's file — make sure the copy there does not promise a menu
  bar picture that is not in the upload.
- **The captioned set contains English text.** If the listing is ever
  localised, captions have to be re-rendered per language; the plain set does
  not. That is a real argument for uploading `out/plain/`.

**Nothing here claims a feature the Mac build does not have.** No widget, no
Live Activity, no camera, no haptics; all four are absent from both the art and
the captions.

---

## 6. Still not photographed

- **The menu bar extra** — blocked by § 3.1, not by tooling.
- **Dark appearance.** Everything here is light. `xcrun simctl ui` does not
  apply to a Mac app, and switching appearance means System Settings, which is
  the owner's machine to change. Worth one shot if he is willing.
- **The Magpie's Cart, the haiku bench, the Sunday Post, the Cabinet's clock
  faces, the celebration card.** All reachable now that sheets can be opened
  and scrolled (§ 2.3); they were left out because ten is the ceiling and the
  ten chosen cover more ground.
- **The 2× set** (§ 2.4).
