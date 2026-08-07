# Mac handoff — three waves, one build

*Written 7 Aug 2026, at the end of the Linux sessions that built the
Companion, Clockwork and Keepsake waves. Everything below is on branch
`claude/pet-interactions-retention-7caoj8`, pushed. None of it has ever
met a compiler.*

## TL;DR — the first five minutes

```sh
git fetch origin claude/pet-interactions-retention-7caoj8
git checkout claude/pet-interactions-retention-7caoj8
tools/run-sim.sh --demo --headless        # Debug build + install + launch
```

Then fix whatever the type checker finds (expect a handful — see the
risk list below), build **Release** too, and walk the table in
section 4. The one-time Xcode target step (section 3) can wait until
the app itself builds and runs.

---

## 1. What is on the branch

Three plan documents, built end to end, one commit per phase, all three
Python checkers green after every phase:

| Wave | Plan doc | What it added |
|---|---|---|
| Companion | `docs/COMPANION_PLAN.md` | feeding on the sill, the high five, tuck-in, the doorstep (hellos, finds, burrs, the drawer), tricks, the anniversary engine, pounce / slow blink / summit nap |
| Clockwork | `docs/CLOCKWORK_PLAN.md` | widened session log (+ the 1000-record trim bugfix), little journeys + mailbox, the fortune slip + the shared sighting-bias seam, the dream garden, timetabled places, one-shot photos, star stories, the night caller, the saturday set, pale coats, meteor nights, idle vignettes |
| Keepsake | `docs/KEEPSAKE_PLAN.md` | share-as-image pass, the buddy book + papers, season letters, A Year Kept, the haiku bench, frost mornings, the home-screen widget (target-gated), the golden hour call |

Every phase in every plan has an **As built** section recording where
the code diverged from the plan — read it before touching that code.
`CLAUDE.md`'s flag table is current; `docs/RESUME_HERE.md`'s top note
says the same thing this file does, shorter.

**What the Linux checkers did and did not cover.** `check_swift.py`
(mechanical: brackets, `#if DEBUG` drift, asset names, StorageKeys,
enum exhaustiveness), `check_contrast.py` (102,832 pairs) and
`check_stray.py` (20,736 placements) are all green. None of them see
argument labels, type inference or SwiftUI misuse — that is what the
Mac is for. Note `check_swift.py` only scans `Pawmodoro/`; the two
files in `PawmodoroWidgets/` were written **checker-blind as well as
compiler-blind**, so read them with extra suspicion.

## 2. Build Debug, then Release

```sh
tools/run-sim.sh --demo --headless
```

Anything starting with `-Pawmodoro` passes straight through to the app:
`tools/run-sim.sh --demo --headless -PawmodoroFrost`.

For Release (catches anything hiding behind `#if DEBUG`):

```sh
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro \
    -configuration Release -destination "generic/platform=iOS Simulator" \
    -derivedDataPath build/simulator CODE_SIGNING_ALLOWED=NO build
```

### Where the compile errors are most likely hiding

Last time, fifteen blind commits produced exactly one error: a
type-check **timeout** in a wide ViewBuilder (`CelebrationView`). The
same shape exists in this batch — if the compiler hangs or times out,
hoist subexpressions into `let`s / private vars rather than fighting it:

- `Views/YearKeptView.swift` — five card builders + a computed stats
  struct in one view.
- `Views/HaikuBenchView.swift` — the 3×3 chooser with per-row styling.
- `Views/BuddyBookView.swift` — the facts array builds strings in a loop.
- `Views/JourneyViews.swift` — MailboxView gained a second ForEach +
  sheet.

API-detail risks (written from memory of the SDK, unverifiable here):

- `Views/ShareCard.swift` — `ImageRenderer` (`scale`, `uiImage`) and
  `ShareLink(item:preview:)` signatures; `Image(uiImage:)` transferable.
- `Views/FrostView.swift` — `.blendMode(.destinationOut)` on a
  `GraphicsContext` **inside `drawLayer`**; if erasing misbehaves, the
  layer boundary is the thing to check first.
- `Model/Chronicle.swift` — season-turn detection splits stored
  `"year.season"` keys; check the first-run path (no stored state) does
  nothing loudly.
- `PawmodoroWidgets/PawmodoroHomeWidget.swift` — `TimelineProvider`,
  `containerBackground(for: .widget)`; **compiles only inside the
  widget target** (section 3). Do not add it to the app target.
- `TimerEngine.armGoldenHour()` — calls
  `FortuneTeller.bestBand(log:)`, which this wave widened from private
  to internal; if that collides with anything, the change is in
  `Model/Fortune.swift`.

## 3. The one-time Xcode step (unlocks two features)

`docs/LIVE_ACTIVITY.md` has the full walkthrough. Short version:
**File → New → Target → Widget Extension**, name it `PawmodoroWidgets`,
check "Include Live Activity", delete Xcode's generated files, then drag
in **all three** of:

- `PawmodoroWidgets/PawmodoroLiveActivity.swift`
- `PawmodoroWidgets/PawmodoroHomeWidget.swift`
- `PawmodoroWidgets/Assets.xcassets` (25 buddy sprites copied
  byte-for-byte by `tools/generate_widget_assets.py`, plus the new
  `widget_nightcap`)

…and tick `Pawmodoro/LiveActivity/PawmodoroActivityAttributes.swift`
for both targets. The **App Group is optional in v1**: without it the
home-screen widget always shows the cat (its designed fallback). To get
the chosen buddy on the widget, add App Group `group.com.pawmodoro` to
both targets, then change any setting once so the app mirrors the buddy
into the suite.

## 4. The walk

`--demo` is assumed in every row (`fast timers + skip onboarding + no
notification prompt`). One feature per launch keeps the captions from
fighting each other.

### Companion wave

| # | Launch with | You should see |
|---|---|---|
| 1 | `-PawmodoroSnack sardine` | Sill chip stocked; finish a focus → the pairing reaction; repeat with `-PawmodoroFillTastes` for the Tastes card |
| 2 | *(nothing extra)* | Finish a focus → the high-five paw at the bell; tap it |
| 3 | `-PawmodoroFives 5` | The paw rises *before* the chime (the pre-empt) |
| 4 | `-PawmodoroClock 22` | Idle at night → the blanket offer; tuck the buddy in |
| 5 | `-PawmodoroTucked` | The blessed-morning thank-you over the caption |
| 6 | `-PawmodoroHello mothLands` | The doorstep vignette on first look |
| 7 | `-PawmodoroFind seaglass` | Carried home → tap → it lands in the drawer |
| 8 | `-PawmodoroBurr salt` | The burr on the buddy; pick it off |
| 9 | `-PawmodoroFillDrawer` | The keepsake drawer, full grid |
| 10 | `-PawmodoroTrick spin.2` | The pinned trick plays ~2.5 s after launch |
| 11 | `-PawmodoroRemember 21` | The memory bubble, dated three weeks back |
| 12 | `-PawmodoroPounce` | Break's final 10 s → crouch, wiggle, pounce — and the miss |

### Clockwork wave

| # | Launch with | You should see |
|---|---|---|
| 13 | `-PawmodoroNightCaller tanuki` | Morning evidence caption; the night page in the journal |
| 14 | `-PawmodoroFortune 1` | The slip read out; the paper corner on the phase chip all day |
| 15 | `-PawmodoroJourney owl.peaks -PawmodoroReturnNow` | The knock; letter in the mailbox; keepsake in the drawer |
| 16 | `-PawmodoroSeed callflower` | The seed on offer; plant it |
| 17 | `-PawmodoroBloom` | One of each plant in bloom; pick them |
| 18 | `-PawmodoroPhoto -PawmodoroDevelop` | Take the shot; the developed card on the shelf |
| 19 | `-PawmodoroNightSessions 12 -PawmodoroClock 22` | The star atlas with figures to open |
| 20 | `-PawmodoroSet kettle_song` | The weekend request chip, any day |
| 21 | `-PawmodoroPale -PawmodoroSighting stag` | The moon-white stag mid-focus; the journal notes the coat |
| 22 | `-PawmodoroShower -PawmodoroClock 22` | Slow meteors on break/idle |
| 23 | `-PawmodoroVignette 3` | An idle vignette a few seconds in |

### Keepsake wave

| # | Launch with | You should see |
|---|---|---|
| 24 | `-PawmodoroPhoto -PawmodoroDevelop` | Tap the developed photo → the share sheet renders a clean card (the AK pass — check the rendered PNG, not just the sheet) |
| 25 | *(nothing extra)* | Settings → **The buddy book** → facts + papers; share the papers |
| 26 | `-PawmodoroBuddy stray` | Soot's papers say what only hers can |
| 27 | `-PawmodoroSeasonLetter autumn` | Morning caption points at the mailbox; the letter under FROM THE SEASONS; share it |
| 28 | `-PawmodoroSeedStats -PawmodoroYearCard` | The five-card A Year, Kept pager; per-card share; "Kept" dismisses and it stays dismissed |
| 29 | `-PawmodoroBench` | The bench opens; choose 3 lines; Keep; the poem in the anthology |
| 30 | `-PawmodoroAnthology -PawmodoroVignette 15` | The buddy quotes a seeded poem's middle line back (seed 15 hits the rare quote branch; the anthology seeds are dated 3+ weeks old on purpose) |
| 31 | `-PawmodoroFrost` | Wipe the frost; the buddy's eyes follow the finger; past ~60 % the rest lets go. Start a focus mid-frost → it melts for good |
| 32 | *(Accessibility → Reduce Motion, then `-PawmodoroFrost`)* | Frost pre-cleared as an edge vignette, no gesture |
| 33 | `-PawmodoroGoldenHour` (+ toggle **Golden hour call** on in Settings) | `Cmd+Shift+H` within 10 s → the silent banner; take the photo and relaunch → no call that day |
| 34 | *(after section 3)* | Add the small widget from the gallery: buddy by wall clock, asleep at night, Luna on watch; no numbers anywhere |

### The appearance pass

New text-bearing views this wave: **LetterCard, YearKeptView's cards,
HaikuCard + the bench chooser, PapersCard + the buddy book, the mailbox
season section, the frost veil**. Check each in dark mode
(`xcrun simctl ui booted appearance dark`) and across themes — the frost
veil is `Theme.cream` on purpose, so each theme tints its own frost.

## 5. Simulator caveats that will look like bugs (they aren't)

- **Notifications** need the app backgrounded (`Cmd+Shift+H`) to show a
  banner. The golden hour call is *deliberately silent* — no sound is
  correct, not a bug.
- **Haptics are no-ops** in the simulator: the frost wipe's per-stroke
  tick and the photo click are inaudible/unfeelable there.
- **The paywall shows "store isn't available"** under `simctl` — correct.
  Use `-PawmodoroUnlockPlus`.
- **The widget** ignores all `-Pawmodoro` flags (separate process). To
  see the December night-cap without waiting for December, change the
  simulator's date, or trust the gallery preview.
- **Emoji render as `?` boxes** in the iOS 26.3 simulator runtime (a
  missing font). The app uses none; the Live Activity's two glyphs will
  box in the pane but are fine on device.

## 6. Rules for fixing what you find

- One fix per commit where practical, in the house voice, on this same
  branch (`git push -u origin claude/pet-interactions-retention-7caoj8`).
- Run `python3 tools/check_swift.py` after edits;
  `check_contrast.py` only if a palette or text backing moved;
  `check_stray.py` only if she, a stage sprite or a scene moved.
- **Never** re-run `generate_sprites.py` / `generate_scenes.py` /
  `generate_wildlife.py` / `generate_music.py` on a machine with a
  different Pillow than authored them unless you *want* every asset
  re-rendered. `generate_widget_assets.py` is safe: it copies bytes and
  only draws the one nightcap.
- When the walk is done, record outcomes the way the last Mac session
  did: update the top note + feature table in `docs/RESUME_HERE.md`
  (compiled? walked? what broke and how it was fixed), so the next
  Linux session knows exactly where reality stands.

## 7. Known-unverifiable rows (don't burn time on these in the pane)

Same class as last time — input-latency and by-ear rows: the frost
wipe *feel*, trick circles drawn by hand (that's what `-PawmodoroTrick`
is for), anything haptic, ambience by ear. Drive them on the device
when one is handy; the pane proves logic, not feel.
