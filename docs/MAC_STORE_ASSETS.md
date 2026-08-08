# Mac App Store — the visual assets

Companion to `docs/MAC_APP_STORE.md`, which works out *whether* and *how* the
app can ship on the Mac App Store. This file is only about the pictures: the
app icon and the screenshots. It answers three of the **VERIFY** items that doc
left open, because they were checked on the machine rather than reasoned about.

Everything produced sits in one scratch directory, outside the repo:

```
/private/tmp/claude-501/-Users-zhangcheng-Desktop-iosPomodoro/\
efd66388-5c4b-4ba5-a1b2-7351e3e69bdb/scratchpad/mas-assets/
```

Nothing in `Assets.xcassets`, `tools/` or the project file was touched. The
scratch directory is not backed up — copy anything you want to keep.

---

## Summary

| Asset | State | Where |
|---|---|---|
| macOS app icon | **Missing.** The Mac build ships with no icon at all — confirmed, not inferred | preview rendered, see § 1 |
| macOS icon preview (1024 + ten sizes) | Produced | `mas-assets/icon/` |
| Mac screenshots, store size | Six produced at 1440×900, plain and captioned | `mas-assets/screenshots-1440x900/` |
| Raw window captures (400×912) | Seven produced | `mas-assets/raw/` |
| 2560×1600 / 2880×1800 screenshots | **Not produced** — needs a Retina Mac, see § 2.3 | — |
| Menu-bar-extra screenshot | **Not produced** — see § 2.5 | — |
| Journal / Sunday Post / Cabinet screenshots | **Not produced** — see § 2.5 | — |

---

## 1. The app icon

### 1.1 It is missing, and the build says so out loud

Built for macOS into a scratch derived-data path (`BUILD SUCCEEDED`, Debug,
`-destination 'platform=macOS'`), and then looked at the product:

- `Contents/Info.plist` has **no `CFBundleIconFile` and no `CFBundleIconName`**.
- `assetutil --info Contents/Resources/Assets.car` contains the string
  `AppIcon` **zero times**.
- There is no `.icns` anywhere in the bundle.
- The build log shows `actool` being asked for exactly the right thing —
  `--app-icon AppIcon --platform macosx --target-device mac` — and producing
  nothing, silently. No warning, no error.

The cause is one line of JSON. `AppIcon.appiconset/Contents.json` declares a
single image tagged `"platform" : "ios"`, so on a macOS compile every candidate
is filtered out and the set is empty.

### 1.2 The single-size question, settled

`docs/MAC_APP_STORE.md` § 5.1 asks whether Xcode 26 has added single-size
support for the macOS idiom. It has not. Three variants of the asset catalogue
were compiled with `actool --platform macosx` directly:

| Contents.json | Result |
|---|---|
| A — as shipped: one universal 1024, `"platform": "ios"` | no icon; no `CFBundleIconName` |
| B — one universal 1024, `"platform"` key removed | no icon; two warnings: *"The app icon set AppIcon has an unassigned child"* |
| C — ten `"idiom": "mac"` entries (16/32/128/256/512 at 1× and 2×) plus the existing iOS entry | **`AppIcon.icns` emitted, `CFBundleIconFile` and `CFBundleIconName` both set, ten renditions in `Assets.car`** |

Variant C was also compiled with `--platform iphoneos`: the iOS icon still
resolves (`CFBundleIcons → CFBundlePrimaryIcon → AppIcon60x60`). **Adding the
mac ladder does not disturb the iPhone build.** That is worth knowing before
anyone edits the shared catalogue nervously.

So the ten-entry ladder is the answer, and one appiconset serves both
platforms.

### 1.3 A macOS icon is not the iOS icon resized

The shipped `AppIcon.png` is 1024×1024, mode RGB, opaque, full-bleed. iOS masks
it. macOS does not mask anything — what is in the PNG is what appears in the
Dock. Dropped in unchanged, Pawmodoro would be the one hard-edged square in a
row of rounded, shadowed neighbours, and it would read as noticeably *larger*
than every icon beside it, because Apple's own icons all sit inside a smaller
body on the same canvas.

The geometry used for the preview, on a 1024×1024 canvas:

| | |
|---|---|
| body | **824 × 824**, centred — 100 px of empty canvas on every side |
| corner | a continuous *squircle*, not a circular-arc rounded rect. Approximated as a superellipse, `|x|⁵ + |y|⁵ ≤ 1`, supersampled 4× and downsampled for the edge |
| shadow | two stacked soft shadows below the body (blur 10 / offset 6, blur 28 / offset 18), both inside the 100 px margin |
| mode | **RGBA** — the margin is transparent, not cream |

That is the Big Sur grid, which is what a macOS 14 deployment target wants.
It is *not* checked against the macOS 26 restatement of the icon template —
`docs/MAC_APP_STORE.md` flags that and it is still open. The preview is close
enough to judge the design by and should not be shipped as final artwork
without that check.

### 1.4 What was rendered

`mas-assets/preview_mac_icon.py` (a preview script; it does **not** write into
the repo and does **not** modify the generator):

- `icon/macos-appicon-1024-preview.png` — the shaped 1024 icon
- `icon/icon-comparison-light.png`, `icon-comparison-dark.png` — iOS vs macOS
  side by side at 256, then a row at 128 / 64 / 32 / 16, on both appearances.
  The small row is the one to look at: it is where the difference is loudest.
- `icon/mac-sizes/` — the ten renditions, correctly named

One thing the small row shows that the big render does not: **at 16 px the paw
disappears** and the icon becomes a pink disc on a cream square. The asset
catalogue lets each size carry different art, so if that bothers you the answer
is a simplified 16/32 pt drawing (paw only, no stem, no rim), not a sharper
downsample.

### 1.5 What `tools/generate_assets.py` would need

`make_icon` is at line 672 and, as written, cannot emit any of this. It:

- builds an **opaque RGB** full-canvas gradient (`Image.fromarray(bg, mode="RGB")`)
  and draws straight onto it — there is no alpha channel to put a margin in;
- draws everything inline in one function, so there is no way to render the
  same art at a different body size without copying the body of the function;
- writes exactly one file, `AppIcon.png`, and prints one line;
- **does not write `Contents.json`.** That file is hand-maintained. Ten new
  PNGs in the imageset with no matching entries would be dead weight, and
  `check_swift.py`'s asset rules would not see the problem because it checks
  the other direction (names used in Swift that have no imageset).

The smallest honest change is four things, in this order:

1. **Split the drawing out.** `def draw_icon_art(size) -> Image` returning
   RGBA, containing everything currently between the gradient and the final
   `resize`. Both icons then call it, and the tomato is drawn once.
2. **`make_icon()` stays as it is** — full-bleed RGB, 1024, one file. iOS is
   correct today and must not change.
3. **Add `make_mac_icon()`**: render `draw_icon_art(824 * SS)`, mask with the
   superellipse, composite the two shadows onto a transparent 1024 canvas, then
   export the ten sizes. Rendering the art *at* 824 rather than resizing the
   1024 is the point — this is pixel-adjacent artwork and the rim highlight is
   `int(big * 0.014)` wide, which does not survive an arbitrary downsample.
4. **Emit `Contents.json`** from the generator, both platforms' entries in one
   write, so the ladder can never drift from the files on disk. That is the
   same rule the rest of `tools/` already lives by.

Budget note, since the repo tracks it: the ten mac renditions add roughly
**270 KB** to the asset catalogue (measured from the preview set: 512@2x is
111 KB, 512 is 51 KB, 256@2x is 51 KB, the rest are small). Against the ~4.5 MB
of headroom under the 45 MB ceiling that is nothing, but say the number rather
than assume it.

---

## 2. Screenshots

### 2.1 The sizes App Store Connect accepts

macOS screenshots must be **exactly** one of:

- **1280 × 800**
- **1440 × 900**
- **2560 × 1600**
- **2880 × 1800**

PNG or JPEG, RGB, **no alpha channel**, 1 to 10 per localisation. (The four
sizes are two 16:10 point sizes at 1× and 2×.)

### 2.2 Why a plain screen grab can never be one

The Mac window is **400 × 912 px** — measured, not read off `Platform.swift`.
`Platform.macWindow` is 400 × 900 of *content*; the window frame adds 12 for
its chrome. And `.windowResizability(.contentSize)` really does pin it: writing
a smaller `NSWindow Frame main-AppWindow-1` into `UserDefaults` before launch
was ignored, and the window came back at 912 every time.

That number does not fit anywhere:

| Canvas | Tallest window it can hold | Window at that scale |
|---|---|---|
| 1280 × 800 | 800 | 912 — **12 % too tall** |
| 1440 × 900 | 900 | 912 — **1.3 % too tall** |
| 2560 × 1600 | 1600 | 1824 at 2× — too tall |
| 2880 × 1800 | 1800 | 1824 at 2× — **24 px too tall** |

So there is no scale, integer or otherwise, at which the window drops into a
legal canvas untouched. **Every Mac screenshot for this app is a composite**,
and the only question is how much it is scaled. The 2880 × 1800 case misses by
24 px, which is maddening and worth knowing before someone spends an afternoon
trying to make it land: if `Platform.macWindow.height` were 888 rather than 900
the 2× shot would fit exactly, with the window filling the canvas edge to edge.
That is a real design option, not a hack — but it is a change to a shipping
screen and belongs to whoever owns the Mac layout, not to the screenshot pass.

### 2.3 What was produced, and at which size

**1440 × 900**, six candidates, in two variants:

```
mas-assets/screenshots-1440x900/plain/       window centred, no text
mas-assets/screenshots-1440x900/captioned/   window left, one line of copy right
```

| File | Flags behind it |
|---|---|
| `01-meadow-day` | `-PawmodoroPlace meadow -PawmodoroClock 12` |
| `02-blossom-dusk` | `-PawmodoroPlace blossom -PawmodoroClock 18 -PawmodoroSeason sakura` |
| `07-cloudspire-day` | `-PawmodoroPlace cloudspire -PawmodoroClock 10` |
| `06-peaks-day` | `-PawmodoroPlace peaks -PawmodoroClock 11 -PawmodoroSeason winter` |
| `05-onsen-dawn` | `-PawmodoroPlace onsen -PawmodoroClock 6` |
| `03-woods-night` | `-PawmodoroPlace woods -PawmodoroClock 22` |

All six also carry `-PawmodoroSkipOnboarding -PawmodoroSuppressNotificationPrompt
-PawmodoroUnlockPlus -PawmodoroUnlockPlaces -PawmodoroBond 200`.

**`-PawmodoroDemo` is the wrong flag for store art** and this is the one trap in
the process. It includes `-PawmodoroFastTimers`, which turns minutes into
seconds — the first capture read **`00:25`** on the clock face, which is both
wrong and, on a Pomodoro app's store page, actively confusing. Use the three
flags `Demo` expands to, minus `FastTimers`.

The background is the app's own `CREAM → BLUSH` gradient rather than a stock
desktop, per `docs/MAC_APP_STORE.md` § 5.2. Captions are in SF Rounded, which
is what `.fontDesign(.rounded)` gives the app itself.

**1440 × 900 was chosen because it is the largest canvas this machine can fill
with honest pixels.** The display here is 7680 × 2160 at **1×** — `UI Looks like
7680 × 2160` — so `screencapture` returns one pixel per point. A 2880 × 1800
screenshot made from those pixels would be a 2× upscale of a 1× grab, and on
pixel art that is either blurry (Lanczos) or chunky (nearest). Presenting that
as Retina art would be a lie about the app's crispness.

**To get the 2× set**, run the same two scripts on a Retina Mac — any MacBook —
with no other change. `shoot.sh` captures by `CGWindowID`, so occlusion does not
matter and nothing has to be brought to the front; `compose.py` needs `W, H`
set to `2880, 1800` and `SHOT_H` doubled. The window will come back as
800 × 1824 and the composite scales it by 0.97 instead of 0.89.

### 2.4 Honesty about how the app looks right now

Another agent is mid-fix on the Mac scenery and a translucent window. Both look
**already fixed in the current source** — but say what was checked rather than
that:

- **The window is opaque.** Captured by window id, which returns the window's
  own surface with its alpha; the alpha channel is 255 everywhere except the
  corner radii. There is no desktop showing through.
- **The scenery draws, and it draws correctly.** Sampled against the source
  art: the meadow's day sky is `(126, 197, 240)` in
  `scene_meadow_day.imageset` and `(196, 221, 232)` on screen, which is exactly
  `SceneryView.veil = 0.52` of cream over it. The scenes look pale because the
  app deliberately washes them 52 %, on both platforms — not because the Mac is
  dropping the image.
- **The horizontal dotted bands** across the sky in every shot are in the
  source PNGs. They are the palette's ordered dither between two blues, not a
  rendering artefact.

Two things in the captures are worth a look before uploading, and neither is a
Mac bug:

- `06-peaks-day` has a small sleeping animal drawn **on top of** the ambience
  button row, overlapping it.
- `05-onsen-dawn` and `04-harbor-golden` (raw only, not composed) come out very
  flat and beige under their veils. `04` in particular reads as a wash rather
  than a place; it is in `raw/` and was deliberately **not** promoted to a
  candidate.

The window title bar reads **"Pawmodoro"**. The App Store name is
**"Paawmodoro"**. On iOS nobody ever sees the bundle name; on a Mac it is in
the title bar, the menu bar and the About box, and it is in all six
screenshots. Decide which one is the name before uploading, not after.

### 2.5 What is missing

- **The menu bar extra.** `docs/MAC_APP_STORE.md` calls this the Mac's pitch,
  and it is the one screenshot no iPhone shot can stand in for. Not captured:
  the menu is a transient window that needs a real click on the status item,
  and driving that needs Accessibility permission this session did not have —
  `System Events` could not see the app's windows at all (`-1719`), so neither
  clicking nor resizing was possible.
- **Any screen behind a tap.** The journal, the Sunday Post, the Cabinet of
  Clocks, the stats screen and the Magpie's Cart all need navigation. Some have
  a launch flag that opens them (`-PawmodoroCart`, `-PawmodoroBench`,
  `-PawmodoroYearCard`) — `-PawmodoroCart` was tried and the sheet came up as a
  **separate window** that `screencapture -l` refused (*"could not create image
  from window"*). Capturing sheets needs either the child window's own id or a
  full-screen grab with the app in front.
- **`-PawmodoroCelebrate`** fires ~1.5 s after launch and the capture happens at
  ~9 s, so the confetti was always over. It needs a shorter wait or a screen
  recording.
- **Dark appearance.** Everything here is light. `xcrun simctl ui` does not
  apply to a Mac app; switching appearance means System Settings.
- **The 2× set**, per § 2.3.

---

## 3. How to redo any of it

Everything is in `mas-assets/` and each piece is one command.

```sh
cd .../scratchpad/mas-assets

# a candidate: launch with flags, capture the window, quit that instance
./shoot.sh 08-woods-dawn -PawmodoroSkipOnboarding \
    -PawmodoroSuppressNotificationPrompt -PawmodoroUnlockPlus \
    -PawmodoroUnlockPlaces -PawmodoroBond 200 \
    -PawmodoroPlace woods -PawmodoroClock 6

python3 compose.py            # raw/ -> screenshots-1440x900/
python3 preview_mac_icon.py   # -> icon/
```

Three things about that machinery are worth keeping, because each cost time:

- **`open -n` does not work for this app.** LaunchServices resolves
  `com.pawmodoro.zhangcheng` to an App Store *placeholder* bundle under
  `~/Library/Daemon Containers/…/Placeholders-v2.noindex/` — the shipped app,
  not your build — so `open` returns 0 and nothing starts. `launch.py`
  double-forks and `setsid`s the executable directly, which is also what keeps
  it alive after the shell that started it exits.
- **Capture by window id, never by screen rectangle.** `screencapture -R` grabs
  whatever is on top of that rectangle; on a busy desktop that is somebody
  else's window, and the mistake is invisible until you look at the PNG.
  `wins.swift` lists `CGWindowID`s for one pid, and `screencapture -o -l <id>`
  captures that window even when it is fully covered.
- **Seeding flags write to real `UserDefaults`.** `-PawmodoroBond 200` and
  friends persist into `com.pawmodoro.zhangcheng`, which other people's Mac
  sessions share. `defaults export` before and `defaults import` after;
  `mas-assets/defaults-backup.plist` is the snapshot taken here, and it was
  restored.
