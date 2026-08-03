# Resume here

One long Linux session took the build order from item 11 to the end of item 16
and cleared the backlog behind it. Working tree clean, everything pushed to
`claude/continue-plan-doc-b4ct6a`. Two items remain and neither is blocked.

## ⚠️ None of it has been compiled, and none of it has been run

Fifteen commits — everything from `73158df` onward — were written on Linux with
no Xcode and no Swift toolchain, and pushed **unverified**. Not compiled once.
Not launched once, in any simulator, on any device. Nobody has *looked* at a
single one of these features.

That means the risk is not only "will it build". It is also: does the stray sit
where she should, is the dream bubble in the right place, do the constellations
read at that opacity, does a stone skip convincingly, does the settle-in feel
like twelve seconds or like forty. `tools/check_swift.py` passes on all of it
and closes the mechanical classes — brackets, `#if DEBUG` parity, missing
assets, non-exhaustive switches, constellation links that would crash — but it
is not a type checker and it has never seen a pixel.

**Build first. Fix what the compiler says. Then walk the table below before
writing anything new.** Two of its rows are rules rather than looks, and those
are the ones worth checking hardest.

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

> read docs/RESUME_HERE.md, then do the simulator pass; after that pick up the
> three deferred slices listed there

## Do this first — one build, then a walk through seven features

```sh
python3 tools/check_swift.py      # should already pass
tools/run-sim.sh --demo --headless
```

Fix whatever the compiler says. Then walk the new work, hardest-to-be-right
first. Each row is one launch.

| What | Flags | What should happen |
|---|---|---|
| The stray, stages 1–3 | `-PawmodoroStray 1` … `3` | Sitting **on the ground**, left edge then right, clear of the ambience row and the transport controls |
| Stage 4 | `-PawmodoroStray 4`, start, skip to break | Two sprites, one caption, buddy shifted left |
| Stage 5 | `-PawmodoroStray 5` | Naming sheet on launch; accepting makes her the buddy and adds her to Settings |
| Spooking her | `-PawmodoroStray 2`, tap her | Fades out for the rest of the phase; next phase she's back |
| Star atlas | `-PawmodoroClock 22 -PawmodoroNightSessions 12` | Little Paw joined and named; Sleeping Cat 7/8 bare stars, no lines |
| A star landing | same, then finish a session | Eighth star lands, card says "The Sleeping Cat is complete" |
| Dreams | `-PawmodoroFillJournal -PawmodoroDream memory` | Bubble over the sleeping buddy between 40–70% of the phase |
| **The owl rule** | `-PawmodoroBuddy owl -PawmodoroClock 22 -PawmodoroDream memory` | **No bubble at all** — Luna keeps watch at night. This one is a rule, not a look |
| Things heard | `-PawmodoroHear owlcall` | Plays once, quietly, mid-session; lands in the journal's "Heard, not seen" |
| Gentle streak | `-PawmodoroSeedGap` | "the boat stayed anchored on \<day\>" on the streak card |
| Settle-in | Settings → Behaviour → on, then play | Three breaths, ~12s, tap to skip |
| Expeditions | idle | Three chips under the ring; tapping one re-lengths all phases and the buddy remarks |
| Seasons | `-PawmodoroSeason autumn`, `sakura`, `winter` | Particles. `fireflies` and `lanterns` also need `-PawmodoroClock 22` |
| Bond | `-PawmodoroBond 150` | Heart meter on the stats screen at "Devoted"; try 10, 30, 75, 300 |
| Scene toys | idle or on a break, at `woods`/`harbor`/`onsen` | Tap water for rings; swipe to skip a stone 1–4 times |
| …and at night | `-PawmodoroClock 22` | Drag: one firefly follows your finger, then leaves |
| **Focus is sacred** | start a focus phase, then drag the scene | **Nothing happens.** The layer goes deaf during focus — a rule, not a look |
| Eyes follow | drag anywhere while the buddy is awake | Pupils glance left/right. Outranked by a bounce or a stir |
| Snow globe | shake the phone (⌃⌘Z in the simulator) | Motes go round once and settle |
| Micro-encounters | `-PawmodoroPlace meadow`, several day sessions | One in twelve: a butterfly on the nose around 60% through |

Two things nothing has verified, and a screenshot settles both in a second:

1. **Whether the stray or the constellations sit behind a button.** Her ground
   placement is measured against real scene pixels by `check_stray.py`, but the
   *chrome* geometry is a layout estimate, and the iPhone SE is the tight one.
   If she collides, move `Stage.x`, not `Stray.groundLine`.
2. **Whether the constellations are faint enough** over real scenery. They are
   drawn at 0.22–0.85 opacity of `Theme.bark` and that number is a guess.

**The riskiest single thing** is `PawmodoroShortcuts` in
`StartFocusIntent.swift`. `AppShortcutsProvider` phrases must each contain
`\(.applicationName)`; Apple rejects the whole provider otherwise and it fails
at *runtime*, not build time. Test it by asking Siri, or by looking for "Start
focus" in Shortcuts.

## Where the build order stands

| # | Scope | State |
|---|---|---|
| 1b | Phase D — Live Activity | code **done**; only the Xcode target step is left, see below |
| 2–10 | places, cast, journal, Sound Almanac, themes, postcards, almanac | done, and seen running |
| 11 | U the stray | done — **never compiled** |
| 12 | T star atlas | done — **never compiled** |
| 13 | S dream diary + L wave 3 + L5 micro-encounters | done — **never compiled** |
| 14 | J seasons, toys, buddy magic | done — **never compiled**; icons still open, below |
| 15 | P gentle streaks + Q settle-in + R expeditions & Action Button | done — **never compiled** |
| 16 | E1 bond + Pip & Bramble | done — **never compiled**; E2 accessories deferred, below |

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

- **Seven phases have never run.** See the top of this file. This is the
  biggest open risk in the repo by a distance.
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
