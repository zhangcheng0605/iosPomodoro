# Resume here

**Stopped on 6 Aug 2026 because the session hit its token limit**, mid-way
through Phase 0 of `docs/DEEP_TIME_PLAN.md`. Everything below is current as of
the last push to `claude/continue-plan-doc-b4ct6a`.

**Next session is on a Windows laptop: no Xcode, no Swift compiler, no
simulator, no iPhone.** The section headed *"Tomorrow: building without a
Mac"* is written for exactly that and is the one to read first.

---

## Where things actually stand

**The app is on the App Store.** Version 1.0, submitted. Build 2 (the music
crash fix) is archived and uploaded. `docs/NEXT_UPDATE.md` is the standing
list of what the next release owes users.

**Phase 0 of the Deep Time plan is half done.** What landed and is verified
on device:

| Piece | State |
|---|---|
| `WorldCalendar` — one opinion about "today", hemisphere policy, `seed(day:place:)` | **done**, Season/MoonPhase/DayPart retrofitted onto it |
| `-PawmodoroDate <yyyy-mm-dd>` | **done** — moves season, moon and (later) weather together |
| `Chronicle` — the append-only event log | **done**, wired into the completion path, verified live |
| `-PawmodoroSeedChronicle` | **done** — 35 events over six weeks, all seven kinds |
| `StorageKeys.chronicle` in `.all` | **done**, so `-PawmodoroResetState` clears it |
| CLAUDE.md conventions (no-decay, one-calendar, no-calendar-notification, single-node audio, dream-backfill) | **done** |

Verified by running it: the seeder decodes clean and sorts ascending, and a
real completed focus session with `-PawmodoroSighting stag` recorded exactly
one event with no seeding involved.

### What is left in Phase 0

Three items, and **all three are doable without a Mac** — see the next
section for how each is verified.

1. **0d — the dream-pool backfill.** The plan asks for 2–3 dream entries
   each for bond, regulars, things heard, seasons and the stray's later
   stages. Nothing has been added yet. The design decided during this
   session, ready to build: add a `case companion(Buddy)` to `Dream`, which
   reuses the existing `buddy_<id>_asleep` sprite rendered as a silhouette
   (`Dream.isSilhouette` already does exactly this for vignettes — see
   `DreamView.sketch`). **Zero new art.** The pool in
   `TimerEngine.pool()` gates it naturally: only buddies actually owned, so
   bond and the stray's arc feed it for free. Add captions in `Dream.line`
   and `Dream.subject`, and remember `Dream.everything` needs the new cases
   or the diary's total goes wrong.
2. **0a — the AlbumView rasterization fix.** `Pawmodoro/Views/AlbumView.swift`
   calls `render(card)` **twice** per card (once for `item:`, once for
   `preview:`), and both are eager function arguments inside a `ForEach`, so
   opening the stats sheet rasterizes every postcard twice at 640pt on the
   main thread. The right fix is to make `Postcard` conform to `Transferable`
   with a `DataRepresentation` that renders lazily at share time, so nothing
   rasterizes until somebody actually shares. `ImageRenderer` must stay on
   `@MainActor`.
3. **0a — the iPad decision.** `TARGETED_DEVICE_FAMILY = "1,2"` in
   `Pawmodoro.xcodeproj/project.pbxproj` (two occurrences). The plan's
   recommendation is `"1"` — be an iPhone app on purpose. It is a two-line
   edit but it changes what App Review sees, so it wants a deliberate
   decision, not a drive-by.

**0e is a Mac-and-device sitting and cannot be done from Windows at all** —
the listening pass over all 50 tracks with headphones, the iPhone SE runtime,
the widget/Live-Activity target step, the App Group registration. It gates
all of Phase W. Save it for the next Mac evening.

---

## Tomorrow: building without a Mac

This is the normal condition for this project, not an emergency — most of the
app was written this way. The rules that make it work:

### The verification you *do* have

```sh
python3 tools/check_swift.py       # run before ending ANY session
python3 tools/check_contrast.py    # after touching a palette or a veil
python3 tools/check_stray.py       # after moving art or resizing a sprite
```

`check_swift.py` is not a type checker and cannot become one. It **does**
catch: unbalanced brackets, `#if DEBUG`/`#else` drift in `LaunchOptions` (a
flag missing its Release stand-in builds fine in Debug and only fails the
Release build), asset names with no imageset, `StorageKeys` missing from
`.all`, `Theme.`/`LaunchOptions.` members that don't exist, and
non-exhaustive switches over the app's own enums. Every one of those rules
was verified by deliberately breaking the code.

It **cannot** see: argument labels, type inference, SwiftUI misuse. Those
surface on the next Mac build. Expect a handful and don't be alarmed.

A worked example from this very session: `chronicle.add(.bond, bond.rawValue)`
passed the checker and was still wrong — `Bond` is `Int`-raw and the
parameter wanted a `String`. Only the compiler found it. **When you add an
enum case or touch a raw value, write out the type in your head.**

### What is safe to build blind

- Model code, pure logic, anything in `Pawmodoro/Model/`
- Captions, copy, roster data, new enum cases
- The python generators in `tools/` — these run anywhere python does, and
  their checkers verify the *output pixels*, which is real verification
- Plan and documentation work

### What is not

- Anything touching `AVAudioEngine`. The Simulator lies about audio formats;
  that is how all fifty tracks shipped unplayable. Device or nothing.
- New layout. It compiles and looks wrong.
- Anything you would want to *see* before believing.

### The three items above, ranked for a Windows day

**Best first job: the dream backfill (0d).** Pure model work, no art, no
layout, and `check_swift.py` guards the exhaustive switches over `Dream` and
`Buddy` that adding a case will break. Highest value per risk.

**Second: the AlbumView `Transferable` fix (0a).** Real code, no visual
change to design, but it uses `Transferable`/`DataRepresentation` — API
shapes the checker can't verify. Write it carefully and expect to fix a
signature on the next Mac build.

**Leave the iPad flag** until you can look at it, or decide it deliberately
and write the reason down.

**Do not start Phase V.** Weather touches scenery, veils and the contrast
matrix; the first slice explicitly wants a week on a real phone before
anything lives in it.

### Working from the branch

```sh
git fetch origin && git checkout claude/continue-plan-doc-b4ct6a && git pull
```

Everything is on `claude/continue-plan-doc-b4ct6a`. The repo's default branch
is `claude/pawmodoro-ios-simulator-sf815f`; `PRIVACY.md` was pushed to both,
because App Review needs it at a stable URL.

---

## Two traps that cost an hour each when forgotten

- **This repo lives on the iCloud-synced Desktop.** The sync service stamps
  `com.apple.FinderInfo` on the built bundle and `codesign` refuses it
  ("resource fork, Finder information, or similar detritus not allowed").
  Always build and archive with `-derivedDataPath` pointing **outside** the
  synced folder. Xcode's own Product → Archive menu item hits this. Irrelevant
  on Windows, essential on the next Mac evening.
- **Never click into the Bundle Identifier field in Xcode.** It was left
  focused once and picked up a stray keystroke, silently becoming
  `com.pawmodoro.zhangchenso-`. A wrong bundle ID uploads fine and then fails
  to match the App Store record.

## The one line to paste next session

> read docs/RESUME_HERE.md, then finish Phase 0 of docs/DEEP_TIME_PLAN.md —
> the dream backfill first

---

## Reference: the four plan documents

| Doc | What it covers | State |
|---|---|---|
| `docs/DEEP_TIME_PLAN.md` | Phases V–Z: weather, sound, the open hour, the long now, widgets | **current work**, Phase 0 half done |
| `docs/NEXT_UPDATE.md` | What the next App Store release owes users | standing list |
| `docs/CONTENT_PLAN.md` | The world: places, cast, journal, themes, postcards | built out |
| `docs/DELIGHT_PLAN.md` | The feel: living buddy, tactile timer, living scene | A–C built, D needs the Xcode target, E2 open |
| `docs/SOUND_ALMANAC.md` | The fifty tracks and the mixer | built, **never listened to** |

Every phase in the older plans carries an **As built** section recording
where the code and the plan diverged. Read the relevant one before touching
that code, and keep the habit: Phase 0's As-built note is the next thing to
write once its last three items land.

## Known gaps, stated plainly

- **Nobody has heard the music.** Fifty tracks and five one-shots, verified
  structurally, never listened to — on the surface that shipped
  100%-broken on device. This is the biggest untested thing in the repo and
  it gates all of Phase W.
- **Never verified on any device**: scene toys, the night firefly,
  eye-tracking, the snow-globe shake, organic micro-encounters, the iPhone SE
  layout.
- **`AlbumView` rasterizes on the main thread** — item 2 above.
- **iPad is declared but not designed for** — item 3 above.
- The app's own screens say "Pawmodoro" while the App Store listing says
  "Paawmodoro" (the shorter name was taken). Apple permits it; it is
  explained in the App Review notes; decide whether you want it.
