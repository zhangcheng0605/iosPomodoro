# Resume here

Last session built **the stray** (item 11) on a machine with no Xcode. Working
tree clean, everything pushed.

## The one line to paste

> read docs/RESUME_HERE.md, then continue the build order in
> docs/CONTENT_PLAN.md from item 12 (T, the star atlas)

## Do this first — it is fifteen minutes and it unblocks judgement

The stray has **never been compiled and never been seen running.** The whole
feature was written on Linux. Before building anything on top of it:

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

## Where the build order stands

Items 1–11 are done. `docs/CONTENT_PLAN.md` has the authoritative table with
the finished rows struck through; this is the summary:

| # | Scope | State |
|---|---|---|
| 1b | Phase D — Live Activity | **blocked on you** — needs a 30-second Xcode step, see below |
| 2–10 | places, cast, journal, Sound Almanac, themes, postcards, almanac | done |
| 11 | U the stray | done — **unverified on a device, see above** |
| **12** | **T star atlas** | **next** |
| 13 | S dream diary + L wave 3 (regulars, things heard) | after |
| 14 | J toys, seasons, alternate icons | after |
| 15 | P gentle streaks + Q settle-in + R expeditions/Action Button | after |
| 16 | E bond & accessories + second-wave buddies (Pip, Bramble) | after |

Specs for 12 and 13 are Phases T and S in `docs/CONTENT_PLAN.md`, each written
to implementation grade with persistence keys, debug flags and done-when
criteria. Phase U now has an **As built** section recording where the plan and
the code diverged — read it before touching her.

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
