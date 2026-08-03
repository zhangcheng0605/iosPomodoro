# Resume here

Last session built **the stray** (item 11), **the star atlas** (item 12) and
**the dream diary** (item 13's first half) on a machine with no Xcode. Working tree clean, everything pushed.

**None of the three has ever been compiled.** That is the standing risk; see
the simulator pass below.

## How this project is actually built

Weekdays are a Windows office and a Linux container: no Mac, no Xcode, no
compiler. Evenings and weekends are the MacBook, and that time is short. So
the rule is: **features get written on Linux, and Mac time is only for things
that genuinely need a Mac.** Anything a machine can check without Xcode should
already have been checked before the Mac ever sees it.

That is what `tools/check_swift.py` is for — run it before ending any session,
along with `check_contrast.py` and `check_stray.py`. It closes the mechanical
error classes (brackets, `#if DEBUG` parity, missing assets, missing enum
cases, unknown `Theme.`/`LaunchOptions.` members). It is not a type checker:
argument labels, inference and SwiftUI misuse still land on the Mac.

**A Swift toolchain would help and isn't installable here.** The environment's
network policy allows package registries only, so `download.swift.org` returns
403. Allowing that host would let a future session run `swiftc -parse` over
everything and fully type-check the pure-Foundation model files — a real but
modest improvement, since Linux has no SwiftUI or UIKit either way. It is an
environment setting, changeable at
https://code.claude.com/docs/en/claude-code-on-the-web.

## The one line to paste

> read docs/RESUME_HERE.md, then continue the build order in
> docs/CONTENT_PLAN.md from L wave 3 (regulars, things heard), then item 14

## Do this first — it is fifteen minutes and it unblocks judgement

The stray, the atlas and the dream diary have **never been compiled and never
been seen running.** All three were written on Linux. Before building anything
on top of them:

```sh
tools/run-sim.sh --demo --headless
```

Then walk her arc, which is one flag:

```sh
xcrun simctl launch "$UDID" com.zhangcheng.pawmodoro -PawmodoroDemo -PawmodoroStray 1
# ...and 2, 3, 4, 5
```

What to look at, in order of how likely it is to be wrong:

1. **Stages 1–3 in the scene.** She should be sitting *on the ground* at the
   left edge (stage 1) or the right edge (stages 2–3), clear of the ambience
   row and the transport controls. Placement is verified against the real scene
   pixels by `tools/check_stray.py`, but nothing has verified she isn't behind
   a *button* — that geometry is a layout estimate, and the iPhone SE is the
   tight one. If she collides, move `Stage.x`, not `Stray.groundLine`.
2. **Stage 4, on a break.** Two sprites, one caption, buddy shifted left to
   make room. `-PawmodoroStray 4` then start a session and skip to the break.
3. **Stage 5.** The naming sheet should come up on launch. Accepting it makes
   her the active buddy and puts her in the Settings picker for good.
4. **Spooking her.** At stage 2 only, tapping her should fade her out for the
   rest of the phase. Starting the next phase brings her back.
5. **Both appearances, and a night scene.** She is near-black by design; the
   pale rim is what carries her. `-PawmodoroClock 22 -PawmodoroStray 3`.

Then the atlas, which needs a night sky and so pairs with step 5:

```sh
xcrun simctl launch "$UDID" com.zhangcheng.pawmodoro -PawmodoroDemo \
    -PawmodoroClock 22 -PawmodoroNightSessions 12
```

Expect The Little Paw joined up and named, The Sleeping Cat at 7 of 8 bare
stars with no lines yet, and the rest unnamed dot-outlines in the atlas card
on the stats screen. Then finish one real session — with the clock still
forced to 22 it counts as a night — and the eighth star should land and the
celebration card should say *"The Sleeping Cat is complete."* Try 47 and 145
too: 47 finishes all seven, 145 is every wandering star.

Then the dreams, which need the buddy asleep and so ride any focus session:

```sh
xcrun simctl launch "$UDID" com.zhangcheng.pawmodoro -PawmodoroDemo \
    -PawmodoroFillJournal -PawmodoroDream memory
```

The bubble should rise over the sleeping buddy between 40% and 70% of the
phase and be gone before the chime. Then `-PawmodoroBuddy owl -PawmodoroClock
22 -PawmodoroDream memory`: Luna keeps watch at night rather than sleeping, so
**no bubble should appear at all** — that is the one behaviour in this phase
that is a rule rather than a look. Finish a session to see it land in the
diary at the bottom of the stats screen.

The figures and their sky layout are already checked (no overlaps, nothing
below 0.319 of screen height against a ring starting at 0.335). What has never
been checked is whether they read as *faint enough* over real scenery — they
are drawn at 0.22–0.85 opacity of `Theme.bark`, and that number is a guess.

## Where the build order stands

Items 1–13a are done. `docs/CONTENT_PLAN.md` has the authoritative table with
the finished rows struck through; this is the summary:

| # | Scope | State |
|---|---|---|
| 1b | Phase D — Live Activity | **blocked on you** — needs a 30-second Xcode step, see below |
| 2–10 | places, cast, journal, Sound Almanac, themes, postcards, almanac | done |
| 11 | U the stray | done — **unverified on a device, see above** |
| 12 | T star atlas | done — **unverified on a device, see above** |
| 13a | S dream diary | done — **unverified on a device** |
| **13b** | **L wave 3 — regulars, things heard** | **next** |
| 14 | J toys, seasons, alternate icons | after |
| 15 | P gentle streaks + Q settle-in + R expeditions/Action Button | after |
| 16 | E bond & accessories + second-wave buddies (Pip, Bramble) | after |

The remaining specs are in `docs/CONTENT_PLAN.md`, each written to
implementation grade with persistence keys, debug flags and done-when criteria.
Phases U, T and S each now carry an **As built** section recording where the
plan and the code diverged — read the relevant one before touching that code.

## The one thing only you can do

**Phase D (Live Activity)** is the single highest-visibility feature left and
it is blocked on a manual step: Xcode has to create the Widget Extension
target (File → New → Target → Widget Extension, name `PawmodoroWidgets`,
tick "Include Live Activity"). Hand-editing a second target into
`project.pbxproj` risks making the project unopenable. Do that step and the
rest is code — the recipe is already written in `docs/LIVE_ACTIVITY.md`.

## What's true about the app now

- **9 buddies**, four with signature quirks (Tofu soaks on breaks, Pebble
  waddles and belly-slides, Maple throws both arms up, Luna is nocturnal).
  Renameable.
- **Soot**, a tenth who cannot be picked, bought or unlocked — she turns up in
  the hedge after you have focused on three days out of seven, gets closer over
  twelve more, and lets you name her. Free, and the paywall never mentions her.
- **Seven constellations**, 47 stars, one star per focus session finished after
  dark. Completed figures are drawn into the night sky of every place, with
  their lore in an atlas on the stats screen. No new state: it is arithmetic
  over the hour each session ended at.
- **A dream diary.** The napping buddy sometimes dreams mid-session — of a
  species you both saw, a vignette you travelled with, or one of six things
  that only happen asleep. Stay to the end and it is kept; leave and it just
  fades. A session gets a dream *or* a sighting, never both.
- **8 places** with a boat/balloon/train whose position *is* the countdown,
  four times of day each, lit windows after dark.
- **41 journal species** including a moon rabbit gated on the real moon, plus
  rainbow / meteors / aurora as phenomena.
- **50 music tracks** from a composition engine, gapless, with radio mode;
  25 earnable free by travelling.
- **8 themes**, all passing 102,832 contrast measurements.
- Postcards, the almanac page, the travelogue route.

## Verification loop (do this every session)

```sh
python3 tools/check_swift.py             # every session, Mac or not
tools/run-sim.sh --demo --headless
python3 tools/check_contrast.py          # must print "all pass"
python3 tools/check_stray.py             # must print "all pass"
python3 tools/check_stray.py --preview /tmp/stray.png   # and look at it
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro -configuration Release \
  -destination 'platform=iOS Simulator,id=<UDID>' CODE_SIGNING_ALLOWED=NO build
```

Then screenshot the changed screen in light *and* dark, update the flag table
in `CLAUDE.md` if you added one, and commit.

## Things learned the hard way — don't relearn them

- **A checker that passes on its first run has proved nothing.** Every rule in
  `check_swift.py` was verified by deliberately breaking the code and watching
  it fail. One of the seven appeared not to work; the rule was fine and the
  test mutation hadn't applied. Test the test.
- **"Not sky" is not "standing on something".** The first stray check asserted
  she wasn't in the air and passed — while she sat on the open sea at Harbor
  Isle. An assertion that names the wrong complement is worse than none,
  because it reports success. Enumerate what a thing *may* rest on, not what it
  may not.
- **Anchor a sprite by its feet.** Positioning by the centre is what put the
  largest stray sprite in the Onsen's hot spring while the two smaller ones
  looked fine. The bug scaled with the art, which is the hardest kind to see.
- **Don't time a short animation with a screenshot loop.** Tool round-trips
  are ~9 seconds; a six-second sighting will be missed every time. Force the
  state with a debug flag and inspect the durable result instead (the journal,
  the log).
- **Never suppress a generator's stderr.** `generate_scenes.py` failed
  silently on a stray space in the sailboat art and looked like success.
- **Assertions catch what eyes don't.** The RMS/peak fight in the music master
  chain and Starfall's ridge drifting into the countdown were both found by
  checks, not by looking.
- **Measure the thing you actually mean.** The first loop-seam check compared
  whole windows from the end and the start of a track, which only proves a
  tune's end sounds different from its beginning. Always true; useless.
- **Regenerating art can move pixels you didn't touch.** A newer Pillow fills
  `rounded_rectangle` differently and closed a 1px gap in the capybara's nose.
  It was an improvement, but check a regenerated asset's pixels rather than
  assuming a clean diff — and revert the files that changed only in encoding,
  or the real change drowns in seventy of them.

## Known gaps, stated plainly

- **The stray has never run.** See the top of this file. This is the biggest
  open risk in the repo right now.
- **Nobody has heard the music.** Fifty tracks are verified structurally
  (harmonic content matches each track's key and progression, loop seam is
  0.03× a normal sample step) but never listened to. Worth doing:
  `tools/run-sim.sh --demo`, pick a track in the Sound Studio, press play.
- **Haptics are unverified.** They are no-ops in the simulator. The purr, the
  dial detents and the final-ten-seconds heartbeat need a real device — see
  `docs/RUN_ON_YOUR_IPHONE.md`.
- `docs/MONETIZATION.md`'s product table is stale (it describes the app as of
  Phase G). The M section of `CONTENT_PLAN.md` is the authoritative split.
- Sound Almanac spec leftovers: pixel cassette icons for the shelf, and the
  buddy's bpm-synced ear twitch.
- Journal spec leftover: L5 micro-encounters (the butterfly that lands on a
  sleeping buddy's nose).
- Long place names truncate in the settings place picker ("Whispering Wo…").
