# Mac App Store — the visual assets

Companion to `docs/MAC_APP_STORE.md`, which works out *whether* and *how* the
app can ship on the Mac App Store. This file is only about the pictures: the
app icon and the screenshots. It also records the three Mac bugs the
screenshot pass walked into, because two of them are in the shots and one of
them **is** a shot.

Everything produced sits outside the repo, in two scratch directories:

```
…/scratchpad/mas-assets/   the 8 Aug pass (icon preview, first six candidates)
…/scratchpad/mas2/         the 9 Aug pass (this file's screenshots)
```

where `…` is
`/private/tmp/claude-501/-Users-zhangcheng-Desktop-iosPomodoro/efd66388-5c4b-4ba5-a1b2-7351e3e69bdb`.
Nothing in `Assets.xcassets`, `tools/` or the project file was touched. Scratch
is not backed up — copy anything you want to keep.

---

## Summary

| Asset | State | Where |
|---|---|---|
| macOS app icon | **Still missing.** Re-checked on 9 Aug against a fresh build: `AppIcon.appiconset/Contents.json` is still one universal 1024 tagged `"platform": "ios"`, the Mac `Info.plist` still has no `CFBundleIconName`, and there is still no `.icns` in the bundle | preview only, `mas-assets/icon/` |
| macOS icon preview (1024 + ten sizes) | Produced 8 Aug, unchanged | `mas-assets/icon/` |
| Mac screenshots, store size | **Eight produced at 1440×900**, plain and captioned | `mas2/screenshots-1440x900/` |
| Raw window captures (400×912) | Twenty-eight, including the rejects | `mas2/raw/` |
| 2560×1600 / 2880×1800 | **Not produced** — needs a Retina Mac, see § 2.2 | — |
| Menu-bar-extra screenshot | **Cannot be taken: the menu bar extra is broken.** See § 3.1 | `mas2/zz-menubar-evidence.png` |

Three bugs came out of this pass. None of them is a screenshot problem and all
three are in shipping code, not in the working tree's uncommitted scenery work:

1. **The menu bar extra draws the buddy at ~400 pt** and the menu bar clips it
   to a meaningless orange band (§ 3.1). This is the one screenshot
   `MAC_APP_STORE.md` calls the Mac's whole pitch.
2. **The Scrapbook has no way to add a picture on macOS** — the `PhotosPicker`
   is a `ToolbarItem(placement: .topBarLeading)`, which renders nothing in a
   Mac sheet (§ 3.2).
3. **The old snail stands on the ambience row** rather than on the ground
   (§ 3.3). Not Mac-specific as far as anything here can tell.

---

## 1. The app icon

Nothing has changed since 8 Aug, and it was re-verified rather than assumed:

```sh
python3 -c "import json;print(json.load(open('Pawmodoro/Assets.xcassets/AppIcon.appiconset/Contents.json'))['images'])"
# → [{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}]
plutil -p <built>.app/Contents/Info.plist | grep -i icon      # → nothing
find <built>.app -name '*.icns'                               # → nothing
```

One trap worth writing down, because it nearly produced a wrong "it's fixed"
here: `assetutil --info Assets.car | grep -c AppIcon` returns **20**, and that
is not the app icon. Those twenty renditions are `iconpreview_AppIcon`,
`iconpreview_AppIconEmber`, … — the pictures the alternate-icon picker shows,
at 44 pt and 88 pt. Count the ones whose name is exactly `AppIcon`, or check
`CFBundleIconName` in the built `Info.plist`, which is the thing App Store
Connect actually reads.

Everything else about the icon — the ten-entry ladder being required, the
squircle geometry, what `tools/generate_assets.py` would need — is unchanged
from the 8 Aug write-up and is preserved in `mas-assets/` and in the previous
revision of this file's § 1.

---

## 2. Screenshots

### 2.1 The eight that are ready to upload

`mas2/screenshots-1440x900/plain/` — window centred on the app's own
cream→blush gradient, no text.
`mas2/screenshots-1440x900/captioned/` — same window on the left, one line of
SF Rounded copy on the right.

All sixteen files assert 1440×900, mode RGB, no alpha channel, in
`compose.py`'s own check.

| File | State shown | Flags behind the raw capture |
|---|---|---|
| `01-meadow-focus` | running, 23:20, cat asleep | `meadow` / clock 12 / clear / ambience off |
| `02-blossom-idle` | idle, 25:00, the three presets | `blossom` / clock 12 / clear |
| `03-woods-night` | running, 22:50, stars | `woods` / clock 22 / clear |
| `04-cloudspire` | running, 22:19 | `cloudspire` / clock 10 / clear |
| `05-peaks-snow` | running, 21:50, snow falling | `peaks` / clock 11 / winter / snow |
| `06-keep-afternoon` | running, 22:50 | `keep` / clock 15 / clear |
| `07-harbor-noon` | idle, the sill and the snacks | `harbor` / clock 12 / clear |
| `08-cycle-complete` | the "Cycle complete" card | `meadow` / clock 12 / `-PawmodoroCelebrate`, captured at 3 s |

Every one also carries `-PawmodoroSkipOnboarding
-PawmodoroSuppressNotificationPrompt -PawmodoroUnlockPlus -PawmodoroUnlockPlaces
-PawmodoroBond 200 -PawmodoroSnail -1`.

Two things to know before believing these pictures:

- **They were taken from the working tree, not from `HEAD`.** Another workflow
  is mid-change on `tools/generate_scenes.py`, `Pawmodoro/Views/SceneryView.swift`
  and all thirty-two `scene_*` PNGs — it is lifting sky cloud out of the
  painted scene onto its own drifting layer. The scenery in these shots is
  that in-flight work. If it is reverted or reworked, re-shoot.
- **`-PawmodoroDemo` is still the wrong flag for store art**, for the reason
  the last pass found: it includes `-PawmodoroFastTimers` and the clock reads
  `00:25`. Use the three flags it expands to, minus `FastTimers`.

### 2.2 Why every Mac screenshot is a composite, and why 1440×900

Unchanged and re-measured: the window comes back **400 × 912 px** every time,
`.windowResizability(.contentSize)` pins it, and 912 > 900 while 1824 > 1800,
so no scale drops it into a legal canvas. `compose.py` scales the capture to
812 px tall (0.89×) and centres it, leaving 44 px of margin.

1440 × 900 is the ceiling **on this machine**, not in general: the display is
7680 × 2160 at 1×, so `screencapture` returns one pixel per point and a
2880 × 1800 set built from it would be a 2× upscale of a 1× grab sold as
Retina art. To get the 2× set, run `mas2/shoot.sh` and `mas2/compose.py`
unchanged on any MacBook and set `W, H = 2880, 1800` and `SHOT_H = 1624`.

### 2.3 Getting a *running* session into a shot, without touching the mouse

The idle screen (25:00, "drag the ring to set your focus") is the weaker
picture: the cat is awake, the ring is empty and nothing is happening. Six of
the eight are real running sessions instead, and the way in is worth keeping:

```sh
osascript -e 'tell application "System Events" to tell process "Pawmodoro" \
  to perform action "AXPress" of menu item "Start" of menu 1 \
  of menu bar item "Session" of menu bar 1'
```

`perform action "AXPress"` on the menu *item* works without opening the menu,
without fronting the app and without moving the cursor. `mas2/shootrun.sh`
wraps it: launch, press Start, wait N seconds, capture by window id, quit. The
countdown in the shot is then honestly N seconds in — `-PawmodoroFastTimers`
is never involved.

What that does **not** buy: the SwiftUI content is not enumerable through
System Events (`entire contents of window 1` returns zero elements), so
nothing inside the window can be pressed this way. The window's *toolbar*
can — `button 1..3 of toolbar 1 of window 1` are Stats, Sound Studio and the
Scrapbook, and pressing them opens their sheets. That is how § 3.2 was found.

### 2.4 The two things the last pass flagged — both real, one misattributed

**"A sleeping animal drawn on top of the ambience row at peaks/day."** Real,
reproduced on a fresh build, and it is not a sleeping animal: it is **the old
snail**. See § 3.3.

**"A harbor/golden capture that came out a flat beige wash."** The flatness is
real. The cause is not golden, and not harbor. Measured on the two vertical
strips of pure scenery the UI never covers (x 0–55 and 345–400, y 430–700),
per-channel standard deviation:

| Shot | sd (R, G, B) |
|---|---|
| `07-harbor-noon` — clear, **day** | 27.1, 20.3, 19.9 |
| `17-harbor-dusk` — clear, **dusk** | 9.2, 8.6, 8.7 |
| `08-harbor-golden` — golden, **dusk** | 7.5, 7.6, 8.8 |
| `01-meadow-noon` — clear, day | 15.0, 12.9, 30.8 |
| `15-meadow-golden` — golden, dusk | 5.0, 5.8, 9.7 |
| `09-keep-afternoon` — clear, day | 14.9, 12.9, 21.4 |
| `18-keep-golden` — golden, dusk | 5.0, 5.8, 8.3 |
| `16-onsen-noon` — clear, day | 16.6, 18.5, 25.1 |
| `05-onsen-dawn` — clear, **dawn** | 6.3, 8.0, 9.9 |

Clear dusk and golden dusk are the same picture to within noise. **It is the
dawn and dusk grades that flatten the scenery, not the weather veil**, and it
happens in every place. The arithmetic agrees: `Weather.golden.veilOpacity` is
0.26, and an alpha blend can only scale contrast by (1 − a) = 0.74, nowhere
near the 0.35 observed. The source art already carries most of it —

```
place        dawn   day   dusk  night      (mean per-channel sd of the exported PNG)
meadow       21.6  35.0   20.5   11.6
harbor       29.6  47.8   28.0   15.8
keep         17.1  27.6   16.3    9.5
```

— dawn and dusk are 0.58–0.62 of day before the app touches them, and then
`SceneryView.veil = 0.52` multiplies by another 0.48, and the time-of-day sky
wash goes on top of that.

This is exactly the failure `Palette.weatherMix`'s own comment predicted:
*"What a bad veil would really cost is the scenery becoming unreadable as
scenery, and that is an eye judgement no checker makes."* It is a judgement
call, not a defect, so it is recorded here rather than in § 3 — but the
practical consequence for this pass is firm: **no dawn or dusk shot is good
enough to upload**, which is why all eight are day or night, and why
`02-blossom-dusk` and `05-onsen-dawn` from the 8 Aug set were dropped.

### 2.5 Still missing

- **The menu bar extra** — blocked by the bug in § 3.1, not by tooling.
- **The Journal, the Sunday Post, the Cabinet, the stats screen.** Reachable
  now (§ 2.3 opens toolbar sheets), but a sheet is a separate `CGWindowID`
  whose capture composites oddly — `mas2/raw/sbx-photos-16766.png` shows what
  you get: the sheet card floating on a dimmed copy of the window, 470 px
  wide over a 400 px window. Usable as evidence, not as store art.
- **Dark appearance.** Everything here is light. `xcrun simctl ui` does not
  apply to a Mac app and switching appearance means System Settings, which is
  the owner's machine to change.
- **The 2× set** (§ 2.2).

### 2.6 The name in the title bar

Unchanged and still worth a decision before uploading: the window title, the
menu bar and the About box all say **Pawmodoro**; the App Store name is
**Paawmodoro**. It is in all eight screenshots.

---

## 3. The three bugs

### 3.1 The menu bar extra draws the buddy at ~400 pt

`Pawmodoro/Views/MenuBarBuddy.swift:23` asks for `BuddySprite(…, size: 16)`.
What appears in the menu bar is roughly **250 px of orange cat**, clipped
top and bottom by the 24 px menu bar, with the countdown beside it. Idle, you
get a slice of the cat's face — the pink nose is recognisable and nothing else
is. Running, you get a horizontal band of her body and `24:57`.

Measured through the accessibility API on the live app:

```
menu bar item 1 of menu bar 2  →  position {6640, -189}  size {418, 402}   (idle)
                                  position {6597, -189}  size {461, 402}   (running)
```

A 402-point-tall status item. Evidence, at 3×, idle above and running below:
`mas2/zz-menubar-evidence.png`. It is definitely ours — quitting the app makes
both the band and the countdown disappear (`mas2/raw/zz-mb-after-quit.png`).

`BuddySprite` is not at fault; it applies `.frame(width: size, height: size)`
and draws correctly everywhere else in the app at every size. What is
different here is the context: `PawmodoroApp.swift:141-145` hands an arbitrary
`View` to `MenuBarExtra`'s `label:` with `.menuBarExtraStyle(.menu)`, and that
label is rendered from the view's own idea of its size rather than being
constrained to the status bar's height. The fix that is known to behave is to
give `MenuBarExtra` an `Image` (or `Label`) directly — a pre-sized `NSImage`
built from the sprite, or `Image(nsImage:)` with `size` set — rather than a
`HStack`.

Two consequences beyond the picture: this is the first thing a Mac user sees,
and `docs/MAC_APP_STORE.md` § 5.2 lists the menu bar extra as the **first**
screenshot to upload because it is the one thing no iPhone shot can show. It
cannot be shipped as it stands.

### 3.2 The Scrapbook cannot import a picture on macOS

`Pawmodoro/Views/ScrapbookView.swift:50-56` puts the `PhotosPicker` in
`ToolbarItem(placement: .topBarLeading)`. In the Mac sheet that renders
**nothing**. The sheet has exactly one button:

```
UI elements of group 1 of sheet 1 of window 1
  → AXStaticText "Where you were", AXScrollArea, AXButton   (the AXButton is "Done")
```

and the capture agrees — title, the row of kept pictures, `Done`, and no `+`.
See `mas2/raw/sbx-photos-16766.png`.

So on the Mac the Scrapbook is a viewer for pictures that can only have been
put there on the phone. `docs/MAC_APP_STORE.md` § 3.4 frames the Mac Scrapbook
decision as "camera, or no camera"; it is really "no way in at all". The
smallest fix is a placement macOS honours (`.primaryAction`, or
`.navigation`), not a new feature.

`.confirmationAction` — the placement "Done" uses — clearly does work, which
is the useful half of the evidence: the toolbar is being read, and only that
one placement is being dropped.

### 3.3 The old snail stands on the ambience row

`-PawmodoroSnail 50 -PawmodoroPlace peaks` puts her foot on the top edge of
the fourth ambience chip, level with the row and reading as though she is
climbing on the UI. `mas2/raw/13-peaks-snail.png`, zoomed in `mas2/zz13.png`;
the 8 Aug pass caught the same thing at `mas-assets/raw/06-peaks-day.png`.

`Snail.groundLine` is 0.79 of the screen, deliberately the same value as
`Stray.groundLine`, and `tools/check_snail.py` asserts there is scenery under
her feet at every x of every place she visits. It has no opinion about what
the *app* draws over that scenery, and the ambience row's chips start at
about 0.774 of the content height. The two collide.

**This is very unlikely to be Mac-specific and was not confirmed on iOS.**
The Mac window is 400 × 900 of which roughly 52 points go to the title bar
(`Platform.macWindow`'s own comment), so the content is ~400 × 848 against
the iPhone's 396 × 858 — the same aspect to within 1 %, and everything
involved is placed by a fraction of it. The check worth running is one
`-PawmodoroSnail 50 -PawmodoroPlace peaks` launch on an iPhone simulator.

Whichever way that comes out, a checker cannot see it today: `check_snail.py`
composites the scene and the sprite, and the collision is with a control that
is not in the composite. This is the same shape as the lesson in `CLAUDE.md`
about the residents buried in the grove — *composite the finished surface*.

---

## 4. How to redo any of it

```sh
cd …/scratchpad/mas2

./shoot.sh    <name> [--wait N] <flags...>   # idle capture
./shootrun.sh <name> <run-seconds> <flags...> # presses Session ▸ Start first
python3 compose.py                            # raw/ -> screenshots-1440x900/
```

Five things about this machinery cost time and are worth keeping:

- **`open -n` does not work for this app.** LaunchServices resolves
  `com.pawmodoro.zhangcheng` to an App Store *placeholder* bundle, so `open`
  returns 0 and nothing starts. `launch.py` double-forks and `setsid`s the
  executable directly.
- **Capture by `CGWindowID`, never by screen rectangle.** `screencapture -R`
  grabs whatever is on top of that rectangle. `wins.swift` lists window ids
  for one pid and `screencapture -x -o -l <id>` captures that window even when
  it is covered, without fronting it.
- **Never name a shell variable `LINES` in zsh.** It is a special integer
  variable; assigning window-list text to it fails with the wonderfully
  unhelpful `bad math expression: lvalue required`, pointing at the assignment
  line. Half an hour.
- **`log` is a zsh builtin.** `log show …` inside a `zsh -c` silently becomes
  "too many arguments" and you get an empty log file rather than an error you
  can read. Use `/usr/bin/log`.
- **Set the app's settings through the argument domain, not by writing
  defaults.** `NSUserDefaults` reads `-<key> <value>` off the command line
  into a volatile domain that outranks the stored one, so

  ```sh
  ./shoot.sh hero … -pawmodoro.settings "<7b22666f...>"     # JSON, as a hex data literal
  ```

  pins the preset, ambience, theme and clock face for one launch and writes
  nothing to disk. This is how every shot here reads 25:00 rather than the 50
  minutes the owner's Mac is actually set to.

### 4.1 A warning about `defaults` and this bundle id — and a state apology

`defaults read com.pawmodoro.zhangcheng` **does not read the file the
unsandboxed Mac app writes.** A sandbox container exists for this bundle id
(`~/Library/Containers/com.pawmodoro.zhangcheng/…`), and `defaults` redirects
the whole domain into it:

```
The domain/default pair of (/Users/zhangcheng/Library/Containers/com.pawmodoro.
zhangcheng/Data/Library/Preferences/com.pawmodoro.zhangcheng, pawmodoro.settings)
does not exist
```

The unsandboxed build writes `~/Library/Preferences/com.pawmodoro.zhangcheng.plist`
instead. So the 8 Aug pass's `defaults export` / `defaults import` backed up
and restored the *container*, and never protected the file it meant to.

The consequence, stated plainly rather than buried: **the Mac's copy of
`~/Library/Preferences/com.pawmodoro.zhangcheng.plist` now carries seeded
state** — `pawmodoro.lifetimeSessions` is 200, from `-PawmodoroBond 200`. This
pass's own backup was taken after two probe launches had already written it,
so the pre-seed value could not be restored; the container's copy, which is
the closest thing to a witness, said 45. Nothing on the iPhone is affected —
that is a different device with its own store. If you want the Mac back to
nothing, delete that plist and the container; if you would rather not lose it,
200 sessions on a Mac that has never run one is harmless and only ever appears
in the Mac app's own stats screen.

The right procedure from here is `cp` of the file itself, before the first
launch:

```sh
cp ~/Library/Preferences/com.pawmodoro.zhangcheng.plist  /somewhere/safe.plist
… run everything …
cp /somewhere/safe.plist ~/Library/Preferences/com.pawmodoro.zhangcheng.plist
killall -u "$USER" cfprefsd          # or cfprefsd flushes its cache over you
```
