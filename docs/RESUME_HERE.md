# Resume here

**Written 6 Aug 2026 from a Windows laptop, for the Mac evening that follows
it.** Phase 0 of `docs/DEEP_TIME_PLAN.md` is built except for the parts that
need a Mac, and the first slice of Phase V — weather, and the old snail — is
built on top of it. **Nothing written today has been through a compiler.**

**The next session is at the MacBook.** The section headed *"Tonight, at the
Mac"* is the one to read first — it is a running order, not a list.

---

## The one line to paste

> read docs/RESUME_HERE.md and do the Mac evening: build it, fix what the
> compiler finds, walk the dream diary and the weather, then the listening pass

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
| **V-slice-1** — weather: veils, particles, the suggestion glow | **built, never compiled** |
| **V5** — the old snail | **built, never compiled** |
| **X1** — the Drift, the open hour | **built, never compiled** |
| **Y3** — the year ring | **built, never compiled** |
| **Y1** — the shelf of hours | **built, never compiled** |
| **Y2** — the Sunday Post | **built, never compiled** |

### What today added, in one paragraph each

**The dream backfill (0d).** Five systems had shipped since the dream pool was
written — the bond, the regulars, the things you can only hear, the seasons and
the stray's arc — and none of them fed it. Six new `Dream` cases now do:
`regular`, `companion`, `visitor`, `sound`, `season`, `yours`. Each is gated in
`TimerEngine.pool()` on the thing it is about, so nothing can be dreamed by
somebody who never met it. The diary went from 50 possible dreams to 116, and weather's three took it to
119.
Thirteen new sprites, drawn on the same 20px sepia grid as the surreal six.
`docs/DEEP_TIME_PLAN.md`'s Phase 0 **As built** section has the table and the
four decisions worth knowing before touching it.

**The album fix (0a).** `ShareLink` was handed two `ImageRenderer` outputs per
card at 640pt, as ordinary function arguments inside a `ForEach` — so opening
the stats sheet rasterised every postcard twice at export size on the main
thread, before anybody tapped anything. `Postcard` now conforms to
`Transferable`; the PNG is drawn once, on demand, after a tap.

**Three new `check_swift.py` rules.** Dream sprite names are expanded from the
enum and checked against the catalog; `Dream.id` and `Dream.from(id:)` must
name the same prefixes (they drift silently and the diary just stops decoding);
and `switch self` inside an `extension` is now checked at all — it never was,
and half the app's tables live in one. All verified by deliberately breaking
the code, per the house rule.

**Weather — V-slice-1 (V1, V2, the suggestion glow).** Nine weathers, rolled
once per calendar day per place out of `WorldCalendar.seed`. Never real
weather: no location permission, no network, the meadow has its own sky.
Drawn as a theme-aware veil plus a particle layer, so the scene pipeline stays
8 places × 4 hours instead of becoming × 9. The chip that suits today's sky
gets a ring and three words; tapping is still the only thing that changes what
plays. Three dream entries came with it, because the convention now says a
feature ships with them rather than owing them.

**The old snail (V5).** Six months to cross a place, then six months
elsewhere; her position is a pure function of the date, about two points a
day. Five places — Cloudspire, Harbor and the Onsen have no continuous ground,
which was measured rather than decided.

**Two new checkers, and one of them found a real bug before any compiler saw
the code.** `check_weather.py` runs a decade of every place through a Python
port of `WorldCalendar.seed`. Golden was written exactly as the plan's table
says — "if yesterday stormed, today is golden" — and that turns out to show
**golden on both days when two storms run together**, and to **never show the
second storm at all**. The rarest weather in the app, eaten by the
second-rarest, about thirty times a decade, invisible from inside the app
forever. `check_snail.py` is `check_stray.py`'s harder sibling and is what
ruled three places out of her route.

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

0. **`Pawmodoro/Views/WeatherView.swift` and `SnailView.swift`** are new
   SwiftUI files and have never been compiled. `Canvas`, `TimelineView` and
   `GeometryReader` are all shapes the app already uses elsewhere, so these
   should be quiet, but they are the newest code here.
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
(three new flags today — `fillDreams`, `forcedWeather`, `forcedSnail` — and
all three stand-ins are in place; `check_swift.py` verifies that, and it is
one of the rules it was proved on):

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

119 tiles. What to actually check, in this order:

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

### 3. The weather, and the snail

Both are new since the last Mac session and neither has been compiled.

```sh
S="tools/run-sim.sh --demo --headless"
$S -PawmodoroWeather storm      # the darkest veil, plus the flash
$S -PawmodoroWeather mist       # the lightest, and the fog banks
$S -PawmodoroWeather golden     # only ever follows a storm, so it needs the flag
$S -PawmodoroWeather rain       # then tap the rain ambience chip — it should be ringed
$S -PawmodoroSeason winter -PawmodoroWeather rain    # should come out as snow
$S -PawmodoroSnail 50           # the old snail, halfway across
$S -PawmodoroDate 2026-12-21    # everything date-driven at once, honestly
```

What to look at:

- **The veil in all eight themes and both appearances.** The contrast numbers
  say it is safe (922k measurements) but the numbers are dominated by the text
  capsules — what a bad veil actually costs is the *place* disappearing behind
  its own weather, and only an eye sees that. `storm` and `mist` are the two
  to judge.
- **The storm flash.** Eleven seconds apart, a third of a second long, soft.
  If it reads as a strobe at all, lower the opacity in `WeatherView.flash` —
  do not shorten the period.
- **The snail.** `tools/check_snail.py --preview /tmp/snail.png` draws her
  whole crossing on one strip from Linux, and it looked right; the thing to
  confirm on a phone is that eighteen points is big enough to notice and small
  enough not to be a mascot.
- **The almanac's today line**, which is the one place the weather is named in
  words.

### 4. The open hour

```sh
S="tools/run-sim.sh --demo --headless"
$S -PawmodoroDrift              # cast off on launch
$S -PawmodoroLaps 5             # five rings deep already
$S -PawmodoroLaps 40            # far past the six-hour question, which should fire
```

**Hold** the play button for 0.6 s to cast off, and hold it again to come back.
Under `--demo` a lap is 25 seconds, so rings appear fast enough to watch.

What to check:

- **The tree rings.** One per lap, inside the track, stopping at eight. If they
  crowd the countdown text, raise the padding step in `TimerRingView.treeRings`.
- **What it banks.** End a five-lap drift and the stats screen should gain five
  sessions and 125 minutes; the paw row should gain five prints. Under one lap
  should bank nothing at all — that is the rule, not a bug.
- **The six-hour question.** `-PawmodoroLaps 40` puts it past the threshold;
  background and foreground the app to fire `syncAfterWake`. Both answers are
  meant to feel equally reasonable.
- **A sighting at the top of a lap.** `-PawmodoroSighting stag -PawmodoroDrift`
  and wait through two laps: the stag should come round twice.

### 5. The year ring

It sits in the stats sheet, above the postcards.

```sh
tools/run-sim.sh --demo --headless -PawmodoroSeedStats -PawmodoroSeedChronicle
tools/run-sim.sh --demo --headless -PawmodoroSeedStats -PawmodoroClock 22
```

The second one forces every seeded session to read as a night session, which
paints the whole ring at the dark end of the ladder — the fastest way to see
that the ladder is doing what it claims.

`check_yearring.py` says the four steps are separable in all sixteen
theme/appearance combinations (worst ΔE 10.4 against a bar of 8), so what is
left for an eye is whether 365 one-pixel wedges look like a year or like
noise. If they look like noise, widen the wedge gap (`+ 0.35` in
`YearRingView.wheel`) before touching any colour — the colours are measured
and the gap is not.

### 6. The shelf, and the letter

Both are in the stats sheet — the letter at the very top, the shelf under the
year ring.

```sh
tools/run-sim.sh --demo --headless -PawmodoroSeedStats -PawmodoroSeedChronicle
```

`-PawmodoroSeedStats` seeds a fortnight, so there *is* a finished week behind
today and the letter has something to say. Without it the letter correctly
does not appear at all — that is the design, not a missing view.

- **The letter** should be five or six sentences and read like an animal wrote
  it. If any line reads as a status report, the fix is the sentence, not the
  layout. `check_post.py` guards the register mechanically but it cannot tell
  you whether a sentence is any good.
- **The shelf** should show a cluster of lit candles around whatever hours the
  seeded history used, and a dark rim elsewhere. Check there is no count
  anywhere on it — that is the anti-goal, and it is the kind of thing that
  gets helpfully added back later.

### 7. Share a postcard

`-PawmodoroPostcard` puts one in the album. Long-press it in the stats sheet →
Share. The share sheet should show a text title like "Whispering Woods, 12 Aug"
rather than a picture — **that is the change**, not a regression: an image
preview is an eager render, which is the thing being removed. What lands in
Messages or Files must still be the full 640pt PNG.

### 8. The four gates of 0e — the actual reason for a Mac evening

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
python3 tools/check_weather.py           # any date-rolled feature
python3 tools/check_yearring.py          # after touching a palette or the ring
python3 tools/check_post.py              # after any Chronicle kind or letter copy
python3 tools/check_contrast.py          # must print "all pass"
python3 tools/check_stray.py             # must print "all pass"
python3 tools/check_snail.py             # after moving her or redrawing a scene
tools/run-sim.sh --demo --headless
xcodebuild … -configuration Release …    # the Release build catches what Debug won't
```

All five were green when this was written: 922,032 contrast pairs, 20,736
stray pairs, 483,840 snail pairs, 29,200 place-days of weather, 72 Swift files
and 387 imagesets. `check_snail.py` takes about 18 seconds; the rest are quick.

Two of these are new, and the reason to keep running them is that one of them
paid for itself immediately: `check_weather.py` found a logic bug in the
golden-day rule on its very first run, before any of this had been compiled.

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
