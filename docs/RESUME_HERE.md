# Resume here

Last session ended mid-build-order with everything committed and pushed. The
working tree was clean at `c000769`.

## The one line to paste

> read docs/RESUME_HERE.md, then continue the build order in
> docs/CONTENT_PLAN.md from item 11 (the stray)

## Where the build order stands

Items 1–10 are done. `docs/CONTENT_PLAN.md` has the authoritative table with
the finished rows struck through; this is the summary:

| # | Scope | State |
|---|---|---|
| 1b | Phase D — Live Activity | **blocked on you** — needs a 30-second Xcode step, see below |
| 2–6 | places, cast, journal wave 1, Sound Almanac | done |
| 7 | four new themes (eight total) | done |
| 8 | postcards + album | done |
| 9 | journal wave 2 | done — grew to **41 species**, moon, phenomena |
| 10 | almanac page + travelogue | done |
| **11** | **U the stray** | **next** |
| 12 | T star atlas | after |
| 13 | S dream diary + L wave 3 (regulars, things heard) | after |
| 14 | J toys, seasons, alternate icons | after |
| 15 | P gentle streaks + Q settle-in + R expeditions/Action Button | after |
| 16 | E bond & accessories + second-wave buddies (Pip, Bramble) | after |

Specs for 11, 12 and 13 are Phases U, T and S in `docs/CONTENT_PLAN.md` — each
written to implementation grade, with persistence keys, debug flags and
done-when criteria.

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
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro -configuration Release \
  -destination 'platform=iOS Simulator,id=<UDID>' CODE_SIGNING_ALLOWED=NO build
```

Then screenshot the changed screen in light *and* dark, update the flag table
in `CLAUDE.md` if you added one, and commit.

## Things learned the hard way — don't relearn them

- **Don't time a short animation with a screenshot loop.** Tool round-trips
  are ~9 seconds; a six-second sighting will be missed every time. Force the
  state with a debug flag and inspect the durable result instead (the journal,
  the log). This cost half an hour before it was written down.
- **Never suppress a generator's stderr.** `generate_scenes.py` failed
  silently on a stray space in the sailboat art and looked like success.
- **Assertions catch what eyes don't.** The RMS/peak fight in the music master
  chain and Starfall's ridge drifting into the countdown were both found by
  checks, not by looking.
- **Measure the thing you actually mean.** The first loop-seam check compared
  whole windows from the end and the start of a track, which only proves a
  tune's end sounds different from its beginning. Always true; useless.

## Known gaps, stated plainly

- **Nobody has heard the music.** Fifty tracks are verified structurally
  (harmonic content matches each track's key and progression, loop seam is
  0.03× a normal sample step) but never listened to. Worth doing before
  building more on top: `tools/run-sim.sh --demo`, pick a track in the Sound
  Studio, press play.
- **Haptics are unverified.** They are no-ops in the simulator. The purr, the
  dial detents and the final-ten-seconds heartbeat need a real device — see
  `docs/RUN_ON_YOUR_IPHONE.md`.
- Sound Almanac spec leftovers: pixel cassette icons for the shelf, and the
  buddy's bpm-synced ear twitch.
- Journal spec leftover: L5 micro-encounters (the butterfly that lands on a
  sleeping buddy's nose).
- Long place names truncate in the settings place picker ("Whispering Wo…").
