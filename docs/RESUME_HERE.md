# Resume here

One long Linux session took the build order from item 11 to the end of item 16
and cleared the backlog behind it. A Mac session (Aug 2026) then compiled all
of it — Debug and Release — and walked the feature table in the simulator.
Two items remain and neither is blocked.

## ✅ Compiled, run, and walked (with a short unseen list)

The fifteen blind commits produced exactly **one compile error**: a
type-checker timeout in `CelebrationView`, whose real culprit was a six-way
chain of optional `.map` closures with string interpolation in the
accessibility label — flattened to `if let` statements. Release built clean
on the first try.

The walk then found **three logic bugs** no compiler could see:

1. **Valued debug flags were order-sensitive.** `UserDefaults` pairs `-key
   value` argument-by-argument, so a valueless flag before a valued one
   swallowed it. All 13 valued flags now read `ProcessInfo` directly
   (`LaunchOptions.value(after:)`) and are immune to ordering.
2. **A forced dream could be pre-empted** by a rolled sighting (exclusive
   with dreams), making `-PawmodoroDream` a coin toss. `rollSighting()` now
   stands down when a dream is forced and no sighting is.
3. **A nocturnal buddy banked dreams it never showed.** The bubble was gated
   on the napping pose but `dreams.add` was not, so Luna at night filled the
   diary invisibly. The roll itself now refuses at night for nocturnal
   buddies — roll, bubble and diary die together.

One placement fix on top: the first constellation drew under the status bar
and toolbar pill (`skyTop` was 0.03 ≈ 26pt; chrome reaches ~105pt). The sky
band now starts at 0.125.

## How this project is actually built

Weekdays are a Windows office and a Linux container: no Mac, no Xcode, no
compiler. Evenings and weekends are the MacBook, and that time is short. So the
rule is: **features get written on Linux, and Mac time is only for things that
genuinely need a Mac.** Anything a machine can check without Xcode should
already have been checked before the Mac ever sees it.

That is what `tools/check_swift.py` is for. Run it before ending any session,
along with `check_contrast.py` and `check_stray.py`. It closes the mechanical
error classes — brackets, `#if DEBUG` parity, missing assets, missing enum
cases, unknown `Theme.`/`LaunchOptions.` members, constellation links that
would crash. Every rule in it is verified by deliberately breaking the code and
watching it fail.

It is **not** a type checker. Argument labels, inference and SwiftUI misuse are
invisible to it and will surface on the Mac. Expect the first build after this
session to throw a handful of errors.

**A Swift toolchain would narrow that and isn't installable here.** The
environment's network policy allows package registries only, so
`download.swift.org` returns 403. Allowing that host would let a future session
run a real parser over everything and fully type-check the pure-Foundation
model files — worth doing, but not transformative, since Linux has no SwiftUI
or UIKit either way. It's an environment setting, changeable at
https://code.claude.com/docs/en/claude-code-on-the-web.

## The one line to paste

> read docs/RESUME_HERE.md, then pick up what's open: alternate app icons,
> Phase E2 accessories, and the Live Activity target step (that one is yours)

## The feature walk — done, row by row

Walked on an iPhone 17 Pro simulator, Aug 2026. Each row was one launch of
the Debug build containing all four fixes.

| What | Flags | Outcome |
|---|---|---|
| The stray, stages 1–3 | `-PawmodoroStray 1` … `3` | ✅ On the ground, correct sides, clear of chrome. Stages 1–2 show only in-session inside their dwell windows — that's the design, not a bug |
| Stage 4 | `-PawmodoroStray 4`, start, skip to break | ✅ Two sprites, one caption, buddy shifted left |
| Stage 5 | `-PawmodoroStray 5` | ✅ Naming sheet; "Let her in" → "Soot is waiting for you", and she's in Settings |
| Spooking her | `-PawmodoroStray 2`, tap her | ✅ Fades for the phase. Mind the tap: the locked ambience chip's 44pt target is nearby |
| Star atlas | `-PawmodoroClock 22 -PawmodoroNightSessions 12` | ✅ After the `skyTop` fix: Little Paw joined and named, Sleeping Cat 7/8 bare, no lines |
| A star landing | same, then finish a session | ✅ Durable result verified: atlas "2 of 7", Sleeping Cat named with lore. (The 4.2s card outruns ~9s tool round-trips) |
| Dreams | `-PawmodoroFillJournal -PawmodoroDream memory` | ✅ Diary entry lands on natural completion (after the pre-emption fix). Bubble-on-buddy placement itself: seen via the diary tile, not mid-phase |
| **The owl rule** | `-PawmodoroBuddy owl -PawmodoroUnlockPlus -PawmodoroClock 22 -PawmodoroDream memory` | ✅ **Holds.** No bubble, and the diary stays at 0 after a completed night session (that second half was the leak that got fixed). Note: owl is Plus — without `-PawmodoroUnlockPlus`, entitlement reverts her to Mochi |
| Things heard | `-PawmodoroHear owlcall` | ✅ "Heard, not seen" journal section lists all five. By ear: unverified |
| Gentle streak | `-PawmodoroSeedGap` | ✅ "Streak 11 — the boat stayed anchored on Friday"; best-streak stays strict at 7 |
| Settle-in | Settings → Behaviour → on, then play | ✅ Misted overlay, breathing ring, full 12s, tap-to-skip starts the countdown at once |
| Expeditions | idle | ✅ Chips re-length (Deep Dive → 00:50) and the caption remarks ("Bramble is waiting — a long crossing, then") |
| Seasons | `-PawmodoroSeason winter` etc. | ✅ Winter snow seen falling. Other four seasons: unwalked, same code path |
| Bond | `-PawmodoroBond 150` | ✅ "Devoted", 4/5 hearts. Side-effect worth knowing: bond seeding marks every place reached |
| Scene toys | idle or on a break, at `woods`/`harbor`/`onsen` | ⬜ Unverified — pane input latency defeats tap/swipe-timing verification |
| …and at night | `-PawmodoroClock 22` | ⬜ Unverified — same reason |
| **Focus is sacred** | start a focus phase, then drag the scene | ✅ **Holds.** Dragging during focus does nothing; the countdown is untouched |
| Eyes follow | drag anywhere while the buddy is awake | ⬜ Unverified — input latency |
| Snow globe | shake (⌃⌘Z) | ⬜ Unverified — no shake channel from the pane; needs Simulator.app |
| Micro-encounters | several day sessions | ⬜ Unverified — no debug flag; one-in-twelve odds. Regulars (five sightings) same story |
| Pip on a break | `-PawmodoroBuddy otter`, reach a break | ✅ On his back, "Pip is floating with a pebble". Fast-mode breaks are 5s — use Deep Dive's 10s and screenshot immediately |
| Bramble in focus | `-PawmodoroBuddy hedgehog`, start | ✅ Perfect spiky ball with a "z", "Don't wake Bramble — stay focused!" |

Dark appearance: the night atlas and a day scene were both re-shot in dark —
capsules and text stay legible, the constellation stays clear of the pill.
The iPhone SE layout is still unseen (no SE runtime installed here).

Constellation opacity over real scenery: reads right at night — lines at 0.22
are faint but findable, stars at 0.85 clearly brighter than the scatter.

`PawmodoroShortcuts` phrases: all three contain `\(.applicationName)`, and
the Release build's AppIntents trainer processed them without complaint.
Asking Siri out loud: still untested.

## Where the build order stands

| # | Scope | State |
|---|---|---|
| 1b | Phase D — Live Activity | code **done**; only the Xcode target step is left, see below |
| 2–10 | places, cast, journal, Sound Almanac, themes, postcards, almanac | done, and seen running |
| 11 | U the stray | done, **seen running** — all five stages plus the spook |
| 12 | T star atlas | done, **seen running** — after the `skyTop` chrome fix |
| 13 | S dream diary + L wave 3 + L5 micro-encounters | done, **seen running** — except micro-encounters (no flag, 1-in-12 odds) |
| 14 | J seasons, toys, buddy magic | done, **compiled + winter seen**; toys/eyes/shake unseen (pane limits); icons still open, below |
| 15 | P gentle streaks + Q settle-in + R expeditions & Action Button | done, **seen running** — Action Button intent untested by voice |
| 16 | E1 bond + Pip & Bramble | done, **seen running**; E2 accessories deferred, below |

Every phase above carries an **As built** section in its plan document
recording where the code and the plan diverged. Read the relevant one before
touching that code — several record a decision that looks arbitrary until you
know why.

## What is still open

Two things, and neither is blocked — they are simply what was left when the
session ended. Both can be done from Linux.

1. **Alternate app icons.** The generator half is easy: one icon per buddy out
   of `make_icon` in `generate_assets.py`, as `.appiconset` folders. The
   project half needs `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES`
   and one `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` entry — additions to
   an existing build-settings dict, the same shape as the
   `NSSupportsLiveActivities` line already added safely, *not* a new target.
   Then `UIApplication.setAlternateIconName` and a picker in Settings.
2. **Phase E2's accessories.** Five items per posture family per buddy is
   roughly two hundred imagesets. Verifiable from here despite the earlier
   note to the contrary: write a `check_accessories.py` that composites each
   overlay onto each frame and asserts it lands on the head, exactly the way
   `check_stray.py` measures the stray. Volume is the cost, not uncertainty.

**Everything else in both plans is built.**

**Pip and Bramble** are built — the eleventh and twelfth buddies. Check them
with `-PawmodoroBuddy otter` (start a session, then skip to the break: he
should be on his back with a pebble, captioned "floating with a pebble") and
`-PawmodoroBuddy hedgehog` (during focus he is a perfect ball; finishing the
session cracks it open for a face).

## The one thing only you can do

**Phase D (Live Activity) — the code is written; only the target isn't.**

Everything except the target now exists: the shared attributes type, the
controller wired into every entry and exit of a running phase, the widget UI,
the `NSSupportsLiveActivities` build setting, and a Settings toggle. The app
builds and runs as it is — with no extension present `Activity.request` just
returns nil and the whole thing is a no-op.

What needs Xcode, and genuinely cannot be done from Linux, is creating the
Widget Extension *target*: File → New → Target → Widget Extension, name
`PawmodoroWidgets`, tick "Include Live Activity". Adding a second target by
hand means writing a PBXNativeTarget, its build phases, a product reference, a
configuration list and an embed phase across eight sections of
`project.pbxproj` with fresh UUIDs, unverifiable, where a mistake makes the
project unopenable. Not worth it.

Then: delete the files Xcode generates for the target, drag in
`PawmodoroWidgets/PawmodoroLiveActivity.swift`, and tick
`Pawmodoro/LiveActivity/PawmodoroActivityAttributes.swift` for **both**
targets. Five minutes. `docs/LIVE_ACTIVITY.md` has the detail.

## What's true about the app now

- **11 buddies**, six with signature quirks. Renameable.
- **Soot**, a tenth who cannot be picked, bought or unlocked — she turns up in
  the hedge after you've focused on three days out of seven, comes closer over
  twelve more, and lets you name her. Free, and the paywall never mentions her.
- **8 places**, four times of day each, with a boat/balloon/train whose
  position *is* the countdown.
- **41 journal species** plus phenomena; the fifth sighting of one turns it
  into a named regular with its own marking and note.
- **5 things you can only hear**, never see.
- **7 constellations, 47 stars**, one per focus session finished after dark,
  drawn permanently into every night sky.
- **A dream diary** — the sleeping buddy dreams of where you've been together.
- **50 music tracks**, gapless, with radio mode; 25 earnable free.
- **8 themes**, all passing 102,832 contrast measurements.
- **A bond** over five levels, and a streak that forgives one day a week.
- **Five seasons** that arrive without being announced.
- Postcards, the almanac, the travelogue, expeditions, a settle-in ritual, and
  an Action Button intent.

## Verification loop (every session)

```sh
python3 tools/check_swift.py             # every session, Mac or not
python3 tools/check_contrast.py          # must print "all pass"
python3 tools/check_stray.py             # must print "all pass"
python3 tools/check_stray.py --preview /tmp/stray.png   # and look at it
tools/run-sim.sh --demo --headless
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro -configuration Release \
  -destination 'platform=iOS Simulator,id=<UDID>' CODE_SIGNING_ALLOWED=NO build
```

Then screenshot the changed screen in light *and* dark, update the flag table
in `CLAUDE.md` if you added one, and commit.

## Things learned the hard way — don't relearn them

- **A checker that passes on its first run has proved nothing.** Every rule in
  `check_swift.py` was verified by deliberately breaking the code. Two of them
  were wrong when written: one blamed a nested enum for its parent's switches,
  and one required a `case`'s labels and its colon on the same line, silently
  skipping every arm long enough to wrap. Both looked strict and were blind.
- **"Not sky" is not "standing on something".** The first stray check asserted
  she wasn't in the air and passed — while she sat on the open sea at Harbor
  Isle. Enumerate what a thing *may* rest on, not what it may not.
- **Anchor a sprite by its feet.** Positioning by the centre put the largest
  stray sprite in the Onsen's hot spring while the two smaller ones looked
  fine. The bug scaled with the art, which is the hardest kind to see.
- **Don't time a short animation with a screenshot loop.** Tool round-trips are
  ~9 seconds; a six-second sighting will be missed every time. Force the state
  with a debug flag and inspect the durable result instead.
- **Never suppress a generator's stderr.** `generate_scenes.py` failed silently
  on a stray space in the sailboat art and looked like success.
- **Measure the thing you actually mean.** The first loop-seam check compared
  windows from the end and the start of a track, which only proves a tune's end
  sounds different from its beginning. Always true; useless.
- **Regenerating art moves pixels you didn't touch.** A newer Pillow fills
  `rounded_rectangle` differently. Check a regenerated asset's pixels rather
  than assuming, and revert the files that changed only in encoding — otherwise
  the real change drowns in seventy of them.
- **Ten pixels is not enough for an upright rabbit.** Head, ears and body merge
  into a thumbprint. Side profile, ears swept back.

## Known gaps, stated plainly

- **A handful of rows are still unseen** — the ⬜ entries in the walk table
  above: scene toys, the night firefly, eye-tracking, the snow-globe shake,
  micro-encounters and regulars, and the iPhone SE layout. All need either
  real-time input, Simulator.app, or a debug flag that doesn't exist yet.
- **Two copy nits, noticed and left**: the dream diary caption claims Luna
  "sleeps through every session", untrue at night now that she keeps watch;
  and `-PawmodoroBond` seeding unlocks every place, which makes the almanac
  say "Every place reached" under a 10-session bond.
- **Nobody has heard the music.** Fifty tracks verified structurally, never
  listened to. `tools/run-sim.sh --demo`, Sound Studio, press play.
- **Nobody has heard the five new one-shots either.** They are synthesised to
  peak under 0.35 so they sit under the ambience, but that is a number, not an
  ear.
- **Haptics are unverified.** No-ops in the simulator — see
  `docs/RUN_ON_YOUR_IPHONE.md`.
- **Regulars are hard to check by hand** — a species needs five sightings.
  There is no debug flag for it; `-PawmodoroFillJournal` only marks things
  seen once. Worth adding a count to that flag next time.
- `docs/MONETIZATION.md`'s product table is stale (it describes the app as of
  Phase G). The M section of `CONTENT_PLAN.md` is authoritative.
- Sound Almanac leftovers: pixel cassette icons, and the bpm-synced ear twitch.
- Journal leftover: L5 micro-encounters (the butterfly that lands on a sleeping
  buddy's nose).
- Long place names truncate in the settings place picker ("Whispering Wo…").
