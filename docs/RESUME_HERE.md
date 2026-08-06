# Resume here

**Written 6 Aug 2026 from a Windows laptop, for the Mac evening that follows
it.** Phase 0 of `docs/DEEP_TIME_PLAN.md` is now built except for the parts
that need a Mac. Nothing written today has been through a compiler.

**The next session is at the MacBook.** The section headed *"Tonight, at the
Mac"* is the one to read first — it is a running order, not a list.

---

## The one line to paste

> read docs/RESUME_HERE.md and do the Mac evening: build it, fix what the
> compiler finds, walk the dream diary, then the listening pass

---

## Where things actually stand

**The app is on the App Store.** Version 1.0, submitted; build 2 (the music
crash fix) archived and uploaded. `docs/NEXT_UPDATE.md` is the standing list
of what the next release owes users.

**Phase 0 is code-complete except 0e, which is a Mac sitting.**

| Piece | State |
|---|---|
| 0b `Chronicle` — the append-only event log, `-PawmodoroSeedChronicle` | **done**, verified on device |
| 0c `WorldCalendar` — one opinion about "today", `-PawmodoroDate` | **done**, verified on device |
| 0d conventions in CLAUDE.md | **done** |
| 0d the dream-pool backfill | **built, never compiled** — today |
| 0a `AlbumView` rasterization | **built, never compiled** — today |
| 0a the iPad decision | **made** — `"1"`, iPhone only, see below |
| 0e the Mac-and-device sitting, four gates | **open** — tonight |

### What today added, in one paragraph each

**The dream backfill (0d).** Five systems had shipped since the dream pool was
written — the bond, the regulars, the things you can only hear, the seasons and
the stray's arc — and none of them fed it. Six new `Dream` cases now do:
`regular`, `companion`, `visitor`, `sound`, `season`, `yours`. Each is gated in
`TimerEngine.pool()` on the thing it is about, so nothing can be dreamed by
somebody who never met it. The diary went from 50 possible dreams to 116.
Thirteen new sprites, drawn on the same 20px sepia grid as the surreal six.
`docs/DEEP_TIME_PLAN.md`'s Phase 0 **As built** section has the table and the
four decisions worth knowing before touching it.

**The album fix (0a).** `ShareLink` was handed two `ImageRenderer` outputs per
card at 640pt, as ordinary function arguments inside a `ForEach` — so opening
the stats sheet rasterised every postcard twice at export size on the main
thread, before anybody tapped anything. `Postcard` now conforms to
`Transferable`; the PNG is drawn once, on demand, after a tap.

**Two new `check_swift.py` rules.** Dream sprite names are expanded from the
enum and checked against the catalog. And `switch self` inside an `extension`
is now checked at all — it never was, and half the app's tables live in one.
Both were verified by deliberately breaking the code, per the house rule.

---

## Tonight, at the Mac

### 1. Build it, and expect errors

```sh
cd ~/Desktop/…/iosPomodoro          # wherever the repo lives
git fetch origin && git checkout claude/phase-0-dream-backfill-j9sbmo && git pull
python3 tools/check_swift.py         # should print "all pass" before you start
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro -configuration Debug \
    -destination "id=$UDID" -derivedDataPath build/simulator \
    CODE_SIGNING_ALLOWED=NO build
```

`check_swift.py` is not a type checker. **A handful of errors here is the
expected outcome, not a sign something is wrong.** In likelihood order:

1. **`Pawmodoro/Views/PostcardExport.swift`.** `Transferable`,
   `DataRepresentation`, `SharePreview` and `ShareLink` are exactly the
   argument-label-and-inference class the checker is blind to. If one line has
   to go, it is `.suggestedFileName("Pawmodoro postcard.png")` — delete it and
   the representation still works. If `Postcard` is refused as non-`Sendable`,
   the fix is `struct Postcard: Codable, Equatable, Identifiable, Sendable`.
2. **`Dream.swift`'s multi-pattern arm** in `TimerEngine.daysSinceMeeting`:
   `case .memory(let species), .regular(let species):`. Both bind `Species`, so
   it should be legal; if the compiler disagrees, split it into two arms.
3. **Implicit members in switch expressions** — `Visitor.reachedAt` returns
   `Stray.Stage` as bare `.edge`, `Yours.reachedAt` returns `Bond` as bare
   `.friendly`. `Stray.Stage.scenePresence` already does this and compiles, so
   this should be fine.
4. **`bond >= .acquainted`** and **`stage >= visitor.reachedAt`** — both types
   are `Comparable` and both already use `<` elsewhere.

Then Release, which is where a missing `#if DEBUG` stand-in would show up
(there is one new flag today, `fillDreams`, and its stand-in is in place):

```sh
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro -configuration Release \
    -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO build
```

### 2. Look at the dream diary — the one screen that changed

The diary lives at the bottom of the stats sheet: tap the paw-print button,
then scroll past the almanac, bond, chart, postcards, star atlas and journal.

**Every tile at once**, which is the only way to see the new art:

```sh
tools/run-sim.sh --demo --headless -PawmodoroFillDreams
```

(`run-sim.sh` passes anything starting `-Pawmodoro` straight to the app, so the
flag lists below can be appended to that same line verbatim.)

116 tiles. What to actually check, in this order:

- **The thirteen new sprites read at 62pt.** They were looked at on Linux at
  8× on a cream card and they read there; 62pt on a phone is the real test.
  The five sounds are the risk — they are drawn as *sounds*, not as whales and
  owls, so they are abstract by design and either land or don't.
- **Silhouettes.** `companion` and `visitor` tiles reuse full-colour sprites
  rendered as silhouettes. If any of them shows up in colour, `isSilhouette`
  missed a case.
- **Both appearances and all four themes.** `xcrun simctl ui "$UDID"
  appearance dark`.

**Then that the gates actually gate**, which `-PawmodoroFillDreams` cannot
tell you because it bypasses them. Each of these should end a focus phase with
the named kind in the diary:

```sh
S="tools/run-sim.sh --demo --headless"
$S -PawmodoroBond 150 -PawmodoroDream yours                     # your chair/door/desk
$S -PawmodoroFillJournal 5 -PawmodoroDream regular              # the one you keep meeting
$S -PawmodoroFillJournal -PawmodoroDream sound                  # only ever heard
$S -PawmodoroStray 3 -PawmodoroDream visitor                    # the cat, still outside
$S -PawmodoroBond 150 -PawmodoroUnlockPlus -PawmodoroDream companion
$S -PawmodoroSeason autumn -PawmodoroDream season               # the time of year
```

The bubble itself appears over the sleeping buddy between 40 % and 70 % of a
focus phase — about 10–21 s in under `--demo` — but do not try to catch it with
a screenshot loop; tool round-trips are ~9 s. Let the phase finish and read the
diary tile instead, which is the durable result.

Two rules to confirm hold, because both are load-bearing and neither is
obvious from the code:

- **A season is only dreamable during that season.** Without
  `-PawmodoroSeason`, `-PawmodoroDream season` should find nothing at all for
  most of the year. That is correct behaviour, not a broken flag.
- **The stray's `visitor` dreams stop when she comes in.** At
  `-PawmodoroStray 5` they should be gone, and `companion` should have gained
  "the cat who came in" instead.

### 3. Share a postcard

`-PawmodoroPostcard` puts one in the album. Long-press it in the stats sheet →
Share. The share sheet should show a text title like "Whispering Woods, 12 Aug"
rather than a picture — **that is the change**, not a regression: an image
preview is an eager render, which is the thing being removed. What lands in
Messages or Files must still be the full 640pt PNG.

### 4. The four gates of 0e — the actual reason for a Mac evening

These gate all of Phase W and have been waiting since the plan was written.

1. **The listening pass.** All 50 tracks, 5 one-shots and 6 ambiences, **on a
   device, with headphones**. Notes per track. Anything broken gets fixed or
   pulled. *Nobody has ever heard any of it* — and this is the surface that
   shipped 100 %-broken on device while flawless in Simulator. This is the
   single biggest untested thing in the repo.
2. **Install the iPhone SE runtime** and walk the rows in the old feature
   table that need a short phone.
3. **Create the Widget Extension target** — File → New → Target → Widget
   Extension, name `PawmodoroWidgets`, tick "Include Live Activity". Then
   delete Xcode's generated files, drag in
   `PawmodoroWidgets/PawmodoroLiveActivity.swift`, and tick
   `Pawmodoro/LiveActivity/PawmodoroActivityAttributes.swift` for **both**
   targets. Five minutes. `docs/LIVE_ACTIVITY.md` has the detail. It ships in
   Phase Z, not now — this is just getting the one-time step done while the
   Mac is open.
4. **Register the App Group container**, write the migration behind a flag,
   leave it dormant until Z.

---

## The iPad decision, made

**`TARGETED_DEVICE_FAMILY` is now `"1"`** — iPhone only, on purpose. Two
occurrences in `Pawmodoro.xcodeproj/project.pbxproj`, lines 273 and 303. It is
the Deep Time plan's recommendation and the honest description of what the app
is: at iPad size the layout has a dead band of scenery through the middle and
the transport controls sit on top of the house.

**One thing to know before you archive.** The app is already live declaring
iPad support, so anyone who installed 1.0 on an iPad cannot update to the next
version. On a just-launched app that is close to nobody — which is why now was
the cheap moment. Undo is two characters on those two lines.

Revisit when Phase Y's Homestead panorama earns a big canvas.

---

## Verification loop (every session)

```sh
python3 tools/check_swift.py             # every session, Mac or not
python3 tools/check_contrast.py          # must print "all pass"
python3 tools/check_stray.py             # must print "all pass"
tools/run-sim.sh --demo --headless
xcodebuild … -configuration Release …    # the Release build catches what Debug won't
```

All three were green when this was written: 102,832 contrast pairs, 20,736
stray pairs, 68 Swift files and 382 imagesets.

---

## Building without a Mac — the normal condition

Most of this app was written this way. The rules that make it work:

### What `check_swift.py` catches

Unbalanced brackets; `#if DEBUG`/`#else` drift in `LaunchOptions` (a flag
missing its Release stand-in builds fine in Debug and only fails Release);
asset names with no imageset; **dream sprite names expanded from their enum**;
`StorageKeys` missing from `.all`; `Theme.`/`LaunchOptions.` members that don't
exist; constellation links to stars that don't exist; and non-exhaustive
switches over the app's own enums, **including the ones inside an
`extension`**. Every rule was verified by deliberately breaking the code.

### What it cannot catch

Argument labels, type inference, SwiftUI misuse. A worked example from the
Chronicle session: `chronicle.add(.bond, bond.rawValue)` passed the checker and
was still wrong — `Bond` is `Int`-raw and the parameter wanted a `String`. Only
the compiler found it. **When you add an enum case or touch a raw value, write
out the type in your head.**

### Safe to build blind

Model code and pure logic; captions, copy, roster data, new enum cases; the
Python generators in `tools/`, whose checkers verify the output *pixels*; plan
and documentation work.

### Not safe

Anything touching `AVAudioEngine` — the Simulator lies about audio formats, and
that is how fifty tracks shipped unplayable. New layout: it compiles and looks
wrong. Anything you would want to *see* before believing.

### Art, specifically

New sprites are safe to draw blind **if you render them and look at the PNG**
— that is real verification, not a guess. Two traps, both hit today:

- **Regenerating art moves pixels you didn't touch.** Running
  `generate_sprites.py` rewrote 69 existing PNGs on a newer Pillow. All 69 were
  byte-different and **pixel-identical**; they were checked and reverted, so
  the commit contains only the thirteen new ones. Always compare pixels rather
  than trusting `git status`.
- **Never `git checkout --` a file you haven't committed.** A test script used
  it to undo a deliberate one-line break and threw away an hour of uncommitted
  work in `Dream.swift`. Commit before you break things on purpose.

---

## Two traps that cost an hour each when forgotten

- **This repo lives on the iCloud-synced Desktop.** The sync service stamps
  `com.apple.FinderInfo` on the built bundle and `codesign` refuses it
  ("resource fork, Finder information, or similar detritus not allowed").
  Always build and archive with `-derivedDataPath` pointing **outside** the
  synced folder. Xcode's own Product → Archive menu item hits this.
- **Never click into the Bundle Identifier field in Xcode.** It was left
  focused once, picked up a stray keystroke and silently became
  `com.pawmodoro.zhangchenso-`. A wrong bundle ID uploads fine and then fails
  to match the App Store record.

---

## Reference: the plan documents

| Doc | What it covers | State |
|---|---|---|
| `docs/DEEP_TIME_PLAN.md` | Phases V–Z: weather, sound, the open hour, the long now, widgets | **current work**; Phase 0 built except 0e |
| `docs/NEXT_UPDATE.md` | What the next App Store release owes users | standing list |
| `docs/CONTENT_PLAN.md` | The world: places, cast, journal, themes, postcards | built out |
| `docs/DELIGHT_PLAN.md` | The feel: living buddy, tactile timer, living scene | A–C built, D needs the Xcode target, E2 open |
| `docs/SOUND_ALMANAC.md` | The fifty tracks and the mixer | built, **never listened to** |

Every phase carries an **As built** section recording where the code and the
plan diverged. Read the relevant one before touching that code — several
record a decision that looks arbitrary until you know why.

**Do not start Phase V.** Weather touches scenery, veils and the contrast
matrix, and the first slice explicitly wants a week on a real phone before
anything lives in it. **Do not start Phase W** until the listening pass has
notes: that is a hard gate, not a caveat.

---

## Known gaps, stated plainly

- **Nobody has heard the music.** Fifty tracks and five one-shots, verified
  structurally, never listened to — on the surface that shipped 100 %-broken on
  device. Gate 1 of 0e above.
- **Today's two commits have never been compiled.** Everything else in this
  file has.
- **Never verified on any device**: scene toys, the night firefly,
  eye-tracking, the snow-globe shake, organic micro-encounters, the iPhone SE
  layout.
- **iPad support is now dropped** — decided, not overlooked. Read the section
  above before the next archive.
- The app's own screens say "Pawmodoro" while the App Store listing says
  "Paawmodoro" (the shorter name was taken). Apple permits it; it is explained
  in the App Review notes; decide whether you want it.
- `docs/MONETIZATION.md`'s product table is stale. `CONTENT_PLAN.md`'s M
  section is authoritative.
