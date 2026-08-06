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

> ## ⏳ Phase 0 is code-complete and two commits of it have never compiled
>
> `WorldCalendar` and the `Chronicle` were built on a Mac and verified on
> device. The **dream-pool backfill** and the **`AlbumView` rasterization
> fix** were written on a Windows laptop with no Xcode and no simulator: both
> pass `check_swift.py`, every new sprite was rendered and looked at, and
> neither has been through a compiler. Expect a handful of errors on the next
> Mac build and don't be alarmed — `docs/RESUME_HERE.md` lists the likely ones
> in order, with the fix for each.
>
> One thing is still open: **0e's Mac-and-device sitting** — above all the
> listening pass, which gates every one of Phase W's sounds. The iPad question
> was decided rather than deferred: `TARGETED_DEVICE_FAMILY` is now `"1"`, an
> iPhone app on purpose. Read `docs/NEXT_UPDATE.md` before the next archive —
> that change is visible to App Review.

**At a Mac, picking this up after the Linux run? Read `docs/TONIGHT.md`** —
the short running order: build, the ten new files ranked by how likely each is
to break, then the four surfaces no checker could judge.
**`docs/RESUME_HERE.md`** is the long version — where the build order stopped,
what has and hasn't been seen running, and what is blocked on the user.

**The next era is planned:** `docs/HEARTH_PLAN.md` — the fifth plan document
— covers the owner's monetization brief: the acorn currency, the Magpie's
Cart, accessories (closing DELIGHT's E2), dens, the interaction era, the
Scrapbook, and macOS. It deliberately overrides one old anti-goal (monuments,
not meters) and records the terms — eight binding fences. **It does not start
until the Mac evening has compiled the Deep Time backlog.** Hand it to the
builder whole; every decision is pre-made in it.

**Current focus:** `docs/DEEP_TIME_PLAN.md` — the fourth plan document,
phases V-Z (weather, sound, the open hour, the long now, widgets). **Phase 0
is built except 0e**: the Chronicle, the world calendar, the conventions and
the dream backfill are in; the listening pass and the widget-target step are
the Mac sitting that is left, and Phase W does not start until the listening
pass has notes. **Phases V, X and Y are complete** — weather, the snail, the
Flyway, Tidewater, the Drift with its deep-drift species, the Cabinet, and all
four altitudes of the Long Now including the Homestead's time-of-day grades
and its hundred-hour panorama. None of it has been compiled;
`docs/TONIGHT.md` is the running order. What is left in Deep Time is W (gated
on the listening pass) and Z (needs an Xcode target). The two earlier plan
documents are built out. `docs/DELIGHT_PLAN.md` covers feel: phases A–C built and seen
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
| `-PawmodoroWeather <id>` + `-PawmodoroSighting` | The only way to see a wave-4 species on demand — half the roster is gated on the sky |
| `-PawmodoroPassage <id>` | Hold one migration window open, e.g. `swans` — and hold every other one shut. The only practical way to see the Flyway |
| `-PawmodoroTide <id\|0-1>` | Pin the water at Harbor Isle: `springlow`, `low`, `mid`, `high`, or a number. The tide turns every six hours, so waiting for one is not a way to check the shore |
| `-PawmodoroEncounter <id>` | Guarantee a micro-encounter this session: `butterfly`, `robin`, `snowflake` |
| `-PawmodoroFillJournal [n]` | Mark every species as seen; `5` makes them all named regulars |
| `-PawmodoroMoon full\|new` | Pin the moon, for the moon rabbit |
| `-PawmodoroTheme <id>` | Start in a theme, e.g. `-PawmodoroTheme ink` |
| `-PawmodoroPostcard` | Put one postcard in the album on launch |
| `-PawmodoroPanorama` | Put the hundred-hour panoramic postcard in the album — four months of sitting, otherwise |
| `-PawmodoroGreet [warmth]` | Force the day's greeting: `daily`, `away`, `gladder`, `first`. The warmest needs a week away |
| `-PawmodoroUnlockMusic` | Every mixtape, without Plus and without travelling |
| `-PawmodoroTrack <id>` | Start with a track selected, e.g. `kettle_song` |
| `-PawmodoroStray <1-5>` | Put the stray at a stage of her trust arc |
| `-PawmodoroNightSessions <n>` | Seed n sessions finished after dark, for the star atlas |
| `-PawmodoroDream <id\|kind>` | Force a dream: `surreal.yarn`, or a kind — `memory`, `regular`, `travel`, `companion`, `visitor`, `sound`, `season`, `sky`, `adrift`, `hour`, `wood`, `neighbour`, `magpie`, `finery`, `den`, `brought`, `snapshot`, `yours`, `surreal` |
| `-PawmodoroFillDreams` | Mark every dream as dreamed, for looking at the diary |
| `-PawmodoroHear <id>` | Guarantee a sound this session, e.g. `owlcall` |
| `-PawmodoroSeedGap` | History with a one-day hole, for the gentle streak |
| `-PawmodoroSeason <id>` | Force a time of year, e.g. `autumn`, `sakura`, `winter` |
| `-PawmodoroBond <n>` | Seed n completed sessions — every bond level, every homestead resident (`200` for all eight), and a full pouch |
| `-PawmodoroAcorns <n>` | Override the derived acorn total, for the cannot-afford-it half of the unlock sheet |
| `-PawmodoroOwnEverything` | Own the whole cart without Plus and without earning it |
| `-PawmodoroCart` | Open the Magpie's Cart on launch |
| `-PawmodoroWear <ids>` | Dress the buddy on launch, e.g. `sunhat,bow` — two at once is what catches a bad anchor |
| `-PawmodoroDen <id>` | Grant a den and switch to its owner, e.g. `igloo` |
| `-PawmodoroKeepsakes <n>` | Seed the shelf of things the buddy brought you |
| `-PawmodoroSeedScrapbook` | Three generated sample photographs — the pane has no camera |
| `-PawmodoroDate <yyyy-mm-dd>` | Pin the world's calendar day — season, moon, and everything date-driven after them |
| `-PawmodoroSeedChronicle` | Six plausible weeks of world events in the chronicle |
| `-PawmodoroWeather <id>` | Pin today's weather everywhere, e.g. `storm`, `mist`, `golden` |
| `-PawmodoroSnail <0-100>` | Put the old snail that far across her crossing; `-1` sends her away |
| `-PawmodoroDrift` | Cast off an open hour on launch |
| `-PawmodoroLaps <n>` | Start a drift already n laps deep (backdates the cast-off) |
| `-PawmodoroClockFace <id>` | Start on a cabinet face, e.g. `incense`, `sand`, `shadow` |

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

**Run every `python3 tools/check_*.py` before ending any session written
without a Mac** — there are twenty now (`swift`, `contrast`, `grove`,
`residents`, `species`, `catalog`, `accessories`, `touch`, `film`, `post`,
`weather`, `yearring`, `clocks`, `stray`, `snail`, `crossing`, `flyway`,
`tide`, `greeting`, `treats`), they take about twenty-five seconds
between them, and each one exists because
something got through. `check_swift.py` is the one that stands in for the
compiler; the rest each guard one system.
Most of this app is written on Linux and compiled days later, so a
typo costs Mac time — which is the scarce resource here, not Linux time. It
closes the mechanical error classes a compiler would catch instantly:
unbalanced brackets, `#if DEBUG`/`#else` drift in `LaunchOptions` (a flag
missing its Release stand-in builds fine in Debug and only fails the Release
build), asset names with no imageset, `StorageKeys` missing from `.all`,
`Theme.` and `LaunchOptions.` members that don't exist, dream sprites whose
imageset was never generated, and non-exhaustive switches over the app's own
enums — **including the ones inside an `extension`**, which is where half the
app's tables actually live. Every one of those rules is verified by
deliberately breaking the code and watching it fail, never by assuming. It is
**not** a type checker and cannot become one: argument labels, inference and
SwiftUI misuse still need Xcode.

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
  plant or an expiring streak, this line is the answer. It has since bought
  something nobody was aiming at: because every store is monotonic, merging
  two devices' worlds is `union` and `max` and never has to decide which of
  two disagreeing values was later. `tools/check_crossing.py` now guards the
  law itself — it walks all nine store classes and fails on any shrinking
  operation not on an allowlist with a written reason, because a decaying
  counter added in two years would make the merge silently wrong and nothing
  else in the toolchain could see it.
- **A merge is idempotent or it is a bug.** The one place this app's
  arithmetic can be wrong *silently*, on a device nobody is holding, with no
  undo. `Crossing.swift`'s first draft added journal counts across devices —
  obviously right, well argued in its own doc comment, and wrong, because a
  sync that retries after a dropped connection then doubles every count.
  Three properties, all cheap to test and all worth testing: `merge(a,b) ==
  merge(b,a)`, `merge(a,a) == a`, and nothing smaller than either input. Any
  tie broken by argument order fails the first; any counter that accumulates
  fails the second. Prefer a bounded undercount to an unbounded overcount
  every time.
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
  the table. The shape is settled now: a case on `Dream`, its own String-raw
  nested enum if the thing it comes from is `Int`-raw (the diary is keyed on
  `id`, and `"visitor.3"` is a key nobody can read), a `reachedAt` saying what
  earns it, and one arm in each of the six tables in `Dream.swift`. Gate it in
  `TimerEngine.pool()` on the system it belongs to rather than on a second
  unlock table — the journal, the bond, the stray's arc and the calendar
  already know. And no caption may name a buddy: they can all be renamed, and
  a model type cannot reach `settings.displayName(for:)`.

- **The economy has one earn rate and one price table, and neither may rise.**
  `Acorns.minutesPerAcorn` and `CatalogItem.price` decide what everybody's
  focus history is worth, retroactively, and they are the only numbers in this
  app a user can be *cheated* by. A price may fall — that is a gift and
  everyone who already paid keeps the thing. Raising either takes something
  from somebody who is not in the room, silently, with no notification or
  patch note that repairs it. `tools/check_catalog.py` holds both in a stored
  fixture and refuses the direction. Its other rules are the fences written
  out as code: acorns are never sold for money (the bridge between cash and
  the catalogue is Plus, whole, once), nothing is ever removed from the pouch,
  Soot is never for sale, and the Sunday Post never itemises what you bought.
  `docs/HEARTH_PLAN.md` has the reasoning for all eight.
- **The app builds for two platforms, and UIKit is fenced.**
  `Pawmodoro/Platform/Platform.swift` is the entire list of what this app needs
  from a platform — aliases, three helpers, and two deliberate no-ops — and it
  is the only file allowed to `import UIKit` plainly. Everything else uses
  `PlatformImage`, `PlatformColor`, `dynamicColor` or `renderJPEG`.
  `check_swift.py` fails on an unguarded import or a bare `UIImage`/`UIScreen`,
  because that class of mistake compiles perfectly on iOS and breaks the Mac
  target where nothing on the Linux side can see it. There is no macOS
  *variant* of any feature — only a macOS way in: the shake becomes a menu
  item and both paths call the same `SceneShake`.
- **A photograph is never modified, and never leaves the device.** The
  Scrapbook writes exactly what was imported and applies a film stock at *draw*
  time, so changing the light is free and reversible forever. Import goes
  through `SnapshotImport.prepare` and nothing else: re-encoding through a
  renderer is the whole of the EXIF strip, and a scrapbook of the desks
  somebody works at is a map of where they live. The app still makes no
  network calls — `docs/PRIVACY.md` says so, and that sentence has to stay
  true.
- **A film stock is the world's own light, and that is checkable.** The three
  time-of-day stocks are the same three numbers `tools/generate_scenes.py`
  grades the scene art with, and "Pressed" is the same transform
  `generate_wildlife.py` presses the journal's sketches with.
  `tools/check_film.py` parses both generators and fails if the Swift drifts —
  which nothing else could notice, because a filter that has quietly stopped
  matching the world looks completely fine.
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
- **An accessory is positioned by measurement, never by hand.**
  `tools/generate_accessories.py` reads each buddy frame's rendered pixels to
  find the crown and the collar line and emits `BuddyAnchors.swift`, which is
  generated — never edit it. `Accessory` then says only how big a piece is
  *relative to that head* and which of its own edges attaches, so nothing in
  the wardrobe knows about any particular buddy and a buddy redrawn tomorrow
  is dressed correctly by the next run of the tool. Two traps it is worth
  knowing about before touching it: measuring a row's full min-to-max span
  reads straight across the gap between two ears (the cat's crown came out
  four pixels above her skull), and scaling a collar to the run at the collar
  line scales it to the *shoulders* (every buddy wore a striped blanket).
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
  `tools/check_snail.py` is the same file's harder sibling: the stray stands
  at three fixed x positions, so her line only has to be ground three times,
  while the **snail crosses the whole width** over six months and hers has to
  be ground everywhere. That is what ruled Cloudspire, Harbor and the Onsen
  out of `Place.snailVisits` — measured, not chosen.
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
- **Run `python3 tools/check_contrast.py` after touching a palette or a veil.**
  It reads the real values out of `AppTheme.swift` and blends the time-of-day
  sky wash over every phase background, in every theme and appearance. It also
  samples the real exported scene pixels behind every text row, under every
  weather veil — 922k measurements, about six seconds. Be honest about what
  that proves: the text capsules composite last at 70–82 %, so they dominate
  the result and the check confirms the veils are safe rather than standing
  guard over them. See `Palette.weatherMix`, which says so with the numbers.
- **The Sunday Post is the aggregation surface, and forgetting it is silent.**
  Small systems are meant to get a weekly *sentence* rather than a screen of
  their own. A system that never gets one has quietly got no surface at all,
  and the letter reads perfectly well without it — nothing would ever show
  the absence. `tools/check_post.py` therefore requires every
  `ChronicleEvent.Kind` to be either handled in `SundayPost.eventLines` or
  named in `SundayPost.silentKinds` with a reason. It also fences the letter's
  voice: no congratulating, no instructing, no comparison with another week,
  no exclamation marks. That is the one surface in the app addressed *to* the
  reader, which makes it the one most likely to drift.
- **A frame strip is a clock you can measure.** The Cabinet's five faces are
  generated frame strips rather than SwiftUI shapes, and every one obeys the
  same rule: the pixels drawn in `ACCENT` are the part that grows with time.
  That is what lets `check_clocks.py` assert with one measurement that a face
  never runs backwards, never stalls, and finishes when the phase does — none
  of which anybody could see at one frame per two minutes. Any new face keeps
  the convention or the checker goes blind.
- **A green checker is not a look.** `check_grove.py` passed every rule it had
  — bounds, spacing, spread, the stored fixture — while the wood came out in
  visible diagonal stripes, because two multiplied-and-wrapped sequences form
  a lattice and no rule anybody had thought to write could see it. It was
  found by rendering a thirty-tree forest and looking at the picture. Every
  generator in `tools/` can composite its output; do that before believing
  the exit code. It happened again with the homestead: `check_residents.py`
  was green while the lantern sat directly on top of the well and the well
  had a bite taken out of it by the card's corner radius. **Composite the
  finished surface**, not just the sprite sheet — a sprite that reads alone
  can still be wrong where it stands.
- **Anything hand-placed on a surface something else also draws into needs a
  checker, and the checker's first answer is often "move it".** Eight
  residents were laid out among the trees by hand, one at a time, each looking
  fine. At the grove's capacity of a hundred and twenty they were 80–100 %
  buried — a hundred and twenty full trees cover that card one and a third
  times over — and nobody would have met it before four months of daily use.
  The residents are drawn in front of the whole wood now. A thing this app
  promises can never be lost has to still be *visible*, or it decayed
  whatever the storage says.
- **A checker that restates the values it checks has proved nothing.** Three
  times now: `check_weather.py` parsed the weights and then verified the roll
  against them, so swapping two weights passed cleanly; `check_yearring.py`
  kept the ring's ladder as its own constant, so flattening all four steps in
  the Swift — the exact bug it exists to catch — passed cleanly too. The fix
  is the same every time: **parse the real values out of the Swift**, and for
  anything that is a promise about the past, add a stored fixture on top. The
  third was `check_touch.py`, and it is the clearest demonstration of the trap
  in the repo: five deliberate breaks — a nose pushed off the face, a chin
  shrunk to a sliver, two regions collapsed onto each other, a tummy floated
  into the air — and *every one passed*, because the checker carried its own
  copy of the coefficients. Moving them into `TouchSpot.shape` as data, and
  parsing that, made four of the five fail immediately. **Break your checker
  before you believe it**; a green run on code you have deliberately broken is
  the only proof that a checker checks anything.
- **Anything rolled from a date is a promise about the past, and gets a stored
  fixture.** `tools/check_weather.py` runs a decade of every place through a
  Python port of `WorldCalendar.seed` — the distribution, the golden-after-
  storm rule, the snow window, determinism — and then checks two dozen stored
  (day, place) → weather rows that were generated once and never change.
  Everything above the fixture parses the weights out of the Swift, which
  makes it self-consistent: swap two weights and it all still passes, because
  it now believes the new weights. Only the fixture notices, and what it
  notices is that a storm somebody sat through last March has just become an
  overcast afternoon. Every future date-rolled feature — the tide, the flyway,
  the snail, the grove's layout — wants the same two halves.
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
