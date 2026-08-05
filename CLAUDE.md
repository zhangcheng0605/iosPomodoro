# Pawmodoro — working notes for Claude

A SwiftUI Pomodoro timer for iOS 17+. No dependencies, no package manager, no
network calls, no test target. The whole app is `Pawmodoro/`.

> ## ✅ The Linux backlog has now been built and walked (Aug 2026, on a Mac)
>
> The fifteen blind commits from *the stray* (`73158df`) onward have been
> compiled — Debug **and** Release — installed, and driven in the simulator.
> One compile error existed in all of it (a type-check timeout in
> `CelebrationView`), plus three logic bugs found on screen: valued debug
> flags were order-sensitive, a forced dream could be pre-empted by a rolled
> sighting, and a nocturnal buddy banked dreams it never showed. All fixed.
> Both rules hold: Luna shows no dream bubble at night (and keeps none), and
> dragging the scene during focus does nothing.
>
> A few rows could not be driven through the simulator pane and are still
> unseen — the input-latency ones (toys, firefly follow, eye-tracking), the
> snow-globe shake, micro-encounters and the regulars (no debug flag), the
> iPhone SE layout (no SE runtime installed), and everything you verify by
> ear. The feature table in `docs/RESUME_HERE.md` records the outcome of
> every row.

> ## 📮 The app is on the App Store — read `docs/NEXT_UPDATE.md` before coding
>
> Version 1.0 is submitted (bundle `com.pawmodoro.zhangcheng`, store name
> **Paawmodoro**). `docs/NEXT_UPDATE.md` is the list of what must reach users
> in the next release: fixes already in the repo, known-and-unfixed issues,
> and the surfaces nobody has ever verified. Start there, not here.
>
> The one that matters most: **all fifty music tracks were unplayable on every
> real device** until build 2 — the player nodes were wired at the hardware's
> format while the tracks are mono 22.05 kHz, and `scheduleBuffer` killed the
> process. The Simulator could never show it. Anything touching
> `AVAudioEngine` gets tried on a device before it ships.

**Resuming after a break? Read `docs/RESUME_HERE.md` first** — it says exactly
where the build order stopped, what has and hasn't been seen running, and what
is blocked on the user.

**Current focus:** `docs/DEEP_TIME_PLAN.md` — the fourth plan document,
phases V-Z (weather, sound, the open hour, the long now, widgets). **Build
Phase 0 first and alone**: the Chronicle, the world calendar, the conventions
commit, the listening pass. The two earlier plan documents are built out. `docs/DELIGHT_PLAN.md` covers feel: phases A–C built and seen
running, D (Live Activity) written but needing a one-time Xcode target step,
E1 (bond) built, E2 (accessories) still open. `docs/CONTENT_PLAN.md` covers
content and its build order is finished except alternate app icons. Each phase
carries an **As built** section recording where the code diverged from the
plan — read the relevant one before touching that code. Known quirk: the iOS
26.3 simulator runtime is missing the primary emoji font, so emoji in `Text`
views render as `?` boxes in the pane (the app itself no longer uses any).

## Running it

The app builds for the iOS Simulator with no signing setup — the bundle ID is
`com.pawmodoro.zhangcheng` and `DEVELOPMENT_TEAM` is empty — the team only
matters for a device, and is set in Xcode rather than here.

```sh
tools/run-sim.sh --demo --headless    # build, install, launch on the booted simulator
```

`--headless` skips opening Apple's Simulator app, which the iOS Simulator pane
doesn't need. With no `--device`, the script targets an already-booted
simulator, so it lands on whatever device the pane is showing.

The raw commands, if the script gets in the way:

```sh
xcodebuild -project Pawmodoro.xcodeproj -scheme Pawmodoro -configuration Debug \
    -destination "id=$UDID" -derivedDataPath build/simulator \
    CODE_SIGNING_ALLOWED=NO build
xcrun simctl install "$UDID" build/simulator/Build/Products/Debug-iphonesimulator/Pawmodoro.app
xcrun simctl launch "$UDID" com.pawmodoro.zhangcheng -PawmodoroDemo
```

## Launch options — use these, the app is slow to check without them

Debug-only flags, defined in `Pawmodoro/LaunchOptions.swift` and compiled out of
Release builds. Pass them to `simctl launch` or to `tools/run-sim.sh`.

| Flag | Effect |
|---|---|
| `-PawmodoroDemo` | `-PawmodoroFastTimers` + `-PawmodoroSkipOnboarding` + `-PawmodoroSuppressNotificationPrompt` |
| `-PawmodoroFastTimers` | Minutes become seconds — a 25-minute focus phase ends in 25s |
| `-PawmodoroSkipOnboarding` | Straight to the timer |
| `-PawmodoroSuppressNotificationPrompt` | No permission alert covering the app |
| `-PawmodoroUnlockPlus` | Pretend Plus is owned, to see the locked content unlocked |
| `-PawmodoroSeedStats` | Two weeks of history, so the stats screen has data |
| `-PawmodoroResetState` | Clean-install state without deleting the app |
| `-PawmodoroCelebrate` | Fires a phase completion ~1.5s after launch, for the confetti and cycle card |
| `-PawmodoroClock <0-23>` | Pins the sky to one time of day (`-PawmodoroClock 22` for night + stars) |
| `-PawmodoroPlace <id>` | Start at a place, e.g. `-PawmodoroPlace cloudspire` |
| `-PawmodoroUnlockPlaces` | Treat every place as reached, without seeding history |
| `-PawmodoroBuddy <id>` | Start with one buddy, e.g. `-PawmodoroBuddy owl` |
| `-PawmodoroSighting <id>` | Guarantee a wildlife sighting this session, e.g. `stag` |
| `-PawmodoroEncounter <id>` | Guarantee a micro-encounter this session: `butterfly`, `robin`, `snowflake` |
| `-PawmodoroFillJournal [n]` | Mark every species as seen; `5` makes them all named regulars |
| `-PawmodoroMoon full\|new` | Pin the moon, for the moon rabbit |
| `-PawmodoroTheme <id>` | Start in a theme, e.g. `-PawmodoroTheme ink` |
| `-PawmodoroPostcard` | Put one postcard in the album on launch |
| `-PawmodoroUnlockMusic` | Every mixtape, without Plus and without travelling |
| `-PawmodoroTrack <id>` | Start with a track selected, e.g. `kettle_song` |
| `-PawmodoroStray <1-5>` | Put the stray at a stage of her trust arc |
| `-PawmodoroNightSessions <n>` | Seed n sessions finished after dark, for the star atlas |
| `-PawmodoroDream <id\|kind>` | Force a dream, e.g. `surreal.yarn` or just `memory` |
| `-PawmodoroHear <id>` | Guarantee a sound this session, e.g. `owlcall` |
| `-PawmodoroSeedGap` | History with a one-day hole, for the gentle streak |
| `-PawmodoroSeason <id>` | Force a time of year, e.g. `autumn`, `sakura`, `winter` |
| `-PawmodoroBond <n>` | Seed n completed sessions, to preview every bond level |

Without `-PawmodoroFastTimers`, verifying a phase transition means waiting 25
minutes. Without `-PawmodoroSeedStats`, the stats screen is empty.

Some things need a plain launch instead: the real onboarding flow, the
first-launch notification prompt, and the paywall's locked state.

## Things that behave differently in a simulator

- **Purchases don't load.** StoreKit only sees products when the app is launched
  from Xcode with `Pawmodoro.storekit` attached to the scheme. Installed with
  `simctl`, the paywall correctly shows its "store isn't available" state — that
  is not a bug to fix. Use `-PawmodoroUnlockPlus` to check the entitled UI.
- **Haptics do nothing.** `UINotificationFeedbackGenerator` is a no-op there.
- **Audio plays through the Mac.** Ambience only runs while the timer is running.
- **Notifications** fire, but the app must be backgrounded (`Cmd+Shift+H`) to see
  the banner.

## Verifying a change

**Run `python3 tools/check_swift.py` before ending any session written without
a Mac.** Most of this app is written on Linux and compiled days later, so a
typo costs Mac time — which is the scarce resource here, not Linux time. It
closes the mechanical error classes a compiler would catch instantly:
unbalanced brackets, `#if DEBUG`/`#else` drift in `LaunchOptions` (a flag
missing its Release stand-in builds fine in Debug and only fails the Release
build), asset names with no imageset, `StorageKeys` missing from `.all`,
`Theme.` and `LaunchOptions.` members that don't exist, and non-exhaustive
switches over the app's own enums. Each of those seven is verified to actually
fail the checker, not just assumed to. It is **not** a type checker and cannot
become one: argument labels, inference and SwiftUI misuse still need Xcode.

There are no tests. A change is verified by building and looking at it:

1. `tools/run-sim.sh --demo --headless`
2. Drive the screen the change touched.
3. For anything visual, check it in both appearances — dark mode is
   `xcrun simctl ui "$UDID" appearance dark` — and in all four themes, which is
   what `AppTheme` in `Pawmodoro/Model/AppTheme.swift` covers.

## Conventions worth keeping

- **Nothing decays. Ever.** Bond, trees, trust, candles, the forgiving
  streak — every counter in this app only goes up or stays put. One decaying
  stat would teach people to open the app afraid, and no later patch could
  un-teach that. When retention pressure eventually argues for a wilting
  plant or an expiring streak, this line is the answer.
- **One opinion about "today".** `WorldCalendar` owns the calendar, the
  hemisphere policy, and `seed(day:place:)`. Anything date-driven goes
  through it — never `Date()` and `Calendar.current` directly — so that
  `-PawmodoroDate` moves the whole world at once and the sky can never
  disagree with the tide. Its seed is a written-out FNV-1a, deliberately not
  Swift's `Hasher` (whose output is randomised per process); changing that
  function silently rewrites everybody's past, so don't.
- **No calendar-window notification, ever.** Migrations, festivals and
  anniversaries are one `UNUserNotificationCenter` call away from being FOMO
  machinery. Missing them has to stay free.
- **Audio is pre-mixed and single-node.** Every audible variant is rendered
  offline by the generators to a loop-exact file and played on the existing
  decode-once `.loops` path. No runtime layering, no second engine graph:
  that is the crash class that made all fifty tracks unplayable on device.
- **Every feature lands with two or three dream entries.** The dream pool is
  the cheapest depth in the app — captions and palette transforms over art
  that already exists. A feature that adds nothing to it has left money on
  the table.

- **Colours go through `Theme`**, never literal `Color` values. That is what
  makes theme switching redraw and what keeps the measured contrast honest —
  every text/background pair in every theme clears 4.5:1, in both appearances.
  Adding a raw colour quietly breaks both.
- **Scenery is generated too.** `tools/generate_scenes.py` draws each place
  once into a grid of palette indices and exports it four times, one per time
  of day — the grade is a palette transform, and the window index is exempt
  from it so windows light up after dark. It asserts that the rows behind the
  countdown contain sky only; if a composition drifts upward it fails loudly.
  Never suppress its stderr — an art bug looks exactly like success otherwise.
- **Music is generated too, and it must loop exactly.**
  `tools/generate_music.py` is a small composition engine; a track is a recipe.
  Two invariants make a loop loop: notes ringing past the last bar are wrapped
  onto the head (not cut), and the file is a whole number of bars in samples.
  Both are asserted. The app then decodes the AAC once and schedules the buffer
  with `.loops` — `AVAudioPlayer` cannot loop AAC without a tick. Never edit an
  `.m4a` or `MusicCatalog.swift`; both are generated.
- **A sighting is decided once, then it's pure maths.** `rollSighting()` runs
  at the start of a focus phase and stores two points on the progress bar;
  everything after is a function of `engine.progress`, so there is no timer,
  nothing to fall out of step, and the animal always leaves before the chime.
  Timing a 6-second appearance from a screenshot loop is hopeless — use
  `-PawmodoroSighting` and read the journal afterwards instead.
- **Watch a generator's stderr, and mean it.** `python3 tools/generate_sprites.py
  | grep something` sends only stdout to the pipe: a traceback goes to stderr,
  vanishes, and the grep reports zero matches as if the run had simply produced
  nothing. That is how a shadowed variable (`for suffix, shift in …`, over the
  module-level `shift()`) looked like a silent no-op rather than a crash. Use
  `2>&1` or run it bare.
- **A buddy's quirk is data, not a special case.** `Buddy` exposes
  `idleShuffleFrame`, `celebrationFrame`, `breakFrame`, `watchFrame` and
  `homeFrame`; `BuddyFrames` reads them and falls back to the ordinary pose
  when one is nil. Adding a quirk to a new buddy is a switch arm and a sprite,
  never a branch in `BuddyView`.
- **Every caption goes through `settings.displayName(for:)`**, never
  `Buddy.name` — buddies can be renamed, and the name has to reach the
  notifications and the tip jar too.
- **Text over scenery sits on its own backing.** The timer face, the buddy
  caption and the paw row each carry a theme-coloured capsule, because with a
  place behind the app the background is no longer a known colour. Removing
  one will fail the contrast check.
- **The stray stands on the ground, and that is checked, not eyeballed.** She
  is the only art placed by fractions of the *screen* rather than drawn into a
  scene, so nothing else in the pipeline can catch her floating.
  `tools/check_stray.py` composites what the app composites — scene, veil, sky
  wash — behind each stage sprite at its shipping position and asserts two
  things: she is standing on something, and her silhouette clears 2:1 against
  whatever is behind it, in every place, time of day, theme and appearance, on
  a tall phone and a short one. It found her sitting on the open sea at Harbor
  and hanging in mid-air over Cloudspire, which is why `Place.strayVisits`
  exists. Note the sprite is positioned by its **feet** (`Stray.groundLine`),
  never its centre — anchoring the centre put the biggest stage in the Onsen's
  hot spring while the two smaller ones looked fine. Run it after moving her,
  resizing a stage sprite, or redrawing any scene.
- **Run `python3 tools/check_contrast.py` after touching a palette.** It reads
  the real values out of `AppTheme.swift` and blends the time-of-day sky wash
  over every phase background, in every theme and appearance — 216 pairs. The
  wash is safe because `Palette.sky(_:)` mixes each hue toward `cream` first,
  which pins its luminance near the background's; lowering `Palette.skyMix`
  will fail the check. It also samples the real exported scene pixels behind
  every text row — 51k measurements, a couple of seconds.
- **Animation is driven by `TimelineView`, never by a `Timer`.** A timeline
  stops when its view is off screen or the app is backgrounded, so an idle app
  costs nothing. Loops run at 2–4fps, bursts at 8fps, particles at 30fps, and
  a canvas is only mounted while it has something to draw.
- **The countdown derives from an absolute end `Date`**, never accumulated
  ticks; iOS suspends backgrounded apps. Don't convert `TimerEngine` to a
  tick-counter.
- **New user-facing state gets a key in `StorageKeys`** (`LaunchOptions.swift`),
  so `-PawmodoroResetState` keeps working.
- **Locked content is shown with a padlock, never hidden**, and tapping it opens
  the paywall. The single exception is Soot, who is hidden until she arrives —
  she isn't for sale, and a greyed-out cat from day one would spoil a two-week
  story to sell nothing. Everything else still follows the rule.
- Every asset is generated: `tools/generate_assets.py` (icon, audio),
  `generate_sprites.py` (buddies), `generate_scenes.py` (places, vignettes)
  and `generate_wildlife.py` (species, plus their journal silhouettes and
  sepia sketches, both derived from frame 0 by palette transform). Edit the
  script, never the PNG.

## Watch out

- The code was written without a Mac, so much of it has never been compiled —
  see the warning at the top of this file for exactly how much. A build error
  is far more likely to be a real slip than an environment problem.
- `Pawmodoro/` is a file-system synchronized group: new files are picked up
  automatically, and `project.pbxproj` doesn't need editing to add one.
- Product IDs in `Store/StoreIDs.swift` must match the bundle ID prefix and
  `Pawmodoro.storekit`. A mismatch doesn't fail the build; the store just
  returns nothing.
