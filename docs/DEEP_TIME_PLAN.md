# Pawmodoro Deep Time Plan — weather, the long now, and a louder world

*The fourth plan document. CONTENT_PLAN built the world, DELIGHT_PLAN made it
feel alive, SOUND_ALMANAC gave it a voice. This one is about **time itself** —
the material the app is actually made of — and it closes the alphabet:
phases V, W, X, Y, Z.*

*How this was written: twenty-odd proposals were generated across five lenses
(time, ecology, audio, ritual, contrarian), scored by independent judges on
soul-fit, differentiation, feasibility and time-depth, then a completeness
critic audited the survivors against the owner's brief and the realities of a
live App Store app. What follows is the synthesis. Scores are noted where a
decision leaned on them.*

## The owner's brief, verbatim intent

- Stay a pomodoro/time app; go **deeper on time**
- More gamification
- **MORE ANIMALS** (the only all-caps demand)
- More songs
- More ambience variation — "BGM like the rain but more variations"

### The animals ledger, stated up front

The critic's sharpest finding: plans like this tend to defer the animals.
So, counted before anything else — this era adds **35–40 species** to the
journal's 41: wave 4 weather creatures (~18), the Flyway's migrants (8–10),
the Drift's deep-water animals (4–5), Tidewater's pool (6–8), plus the
Homestead's residents (8–10, who live outside the journal as neighbors, not
sightings). Every one flows through the existing `rollSighting()` /
`generate_wildlife.py` pipeline. No new sighting system is built in this era;
the one we have is fed.

### The gamification answer, stated up front

This app will not grow meters, dailies, or anything that can be *behind*.
The era's answer is **monuments, not meters** — progression you can see and
want, none of which can decay or nag:

1. **The Homestead** grows residents and trees that never leave (Y).
2. **Found sounds** — ambiences and mixtapes earned by being somewhere, not
   by paying (W).
3. **Clock faces** earned by the counters the app already keeps (X).
4. **The Shelf of Hours, the Year Ring, the festival-stamped anniversaries**
   — collections completed by living (Y).
5. **Milestone celebrations** at 25/100/500 lifetime hours through the
   existing CelebrationView card system — the only "congratulations" surface
   this era adds, and it fires on arrival, never on absence.

## Anti-goals (binding, same force as the plans before)

- **No task manager.** Sessions stay unlabeled. The moment Pawmodoro asks
  what you're working on, it becomes homework.
- **No real-world weather.** No location permission, no network fetch. The
  meadow has *its own* weather, rolled deterministically. The world is
  somewhere you go, not a mirror.
- **Nothing decays. Ever.** Bond, candles, trees, trust, streaks-forgiven —
  the entire state model is monotonic. One decaying stat would teach users
  to open the app afraid, and no later patch could un-teach it. This goes
  into CLAUDE.md's conventions as a wall for future retention pressure to
  hit.
- **No calendar-window notification, ever.** The Flyway, festivals and
  anniversaries are one `UNUserNotificationCenter` call away from FOMO
  machinery. That call is forbidden; the code-review checklist says so.
- **No auto-switching sound.** Weather may *suggest* an ambience; it never
  changes what's playing.
- **No hidden-count shaming.** Collections with dark ends (unlit candles,
  unmet migrants) never show "x of y" anywhere. The dark end is visible only
  by looking at the shelf.
- **Focus stays sacred.** The Drift is focus. The scenery layer is deaf
  during it, exactly as during a countdown.

## Do-not-break list (carried forward, plus this era's new law)

Everything in DELIGHT_PLAN's list still binds, plus:

- Countdown derives from an absolute end `Date`; **the Drift derives from an
  absolute start `Date`**; the Old Snail derives from *today's* `Date`.
  Nothing, at any timescale, counts ticks.
- **One world calendar.** A single module owns: the local-calendar-day
  convention (DST policy decided once), the hemisphere policy (copied from
  shipped seasons, never a second one), and `seed(day:place:)` — the
  deterministic date-to-noise function. Weather, tides, the Flyway, the
  Snail, anniversaries and the Rain Ledger all consume it. `-PawmodoroDate
  <yyyy-mm-dd>` pins it everywhere; five judges independently demanded this
  flag, so it ships before any feature that needs it.
- **One audio architecture: pre-mixed, single-node.** Every audible variant
  is pre-rendered offline by the generators to a loop-exact file and played
  on the existing decode-once `.loops` path. No runtime layering, no second
  engine graph, no per-layer nodes — the entire multi-node crash class that
  produced the build-2 fire drill is excluded from this era by construction,
  not by care.
- **Layout seeds are compatibility contracts.** The Homestead's tree
  placement and every date-seed algorithm become permanent the day they
  ship — a user's forest must never silently rearrange. Each gets a
  regression fixture (stored seed → expected layout) before its first
  release.
- **`check_contrast.py` learns every new veil the day the veil exists.**
- **Every feature lands with two or three dream entries.** The dream pool
  has not been fed since Phase S — bond, regulars, the heard list, seasons
  and the stray's later stages are all un-wired. This becomes a standing
  convention (goes in CLAUDE.md), and the backlog gets paid in Phase 0.

---

## Phase 0 — The invisible release (ships first, shows nothing)

*The critic's forced move, and it is genuinely forced: two clocks run in
opposite directions. Every release shipped without the recording layer
permanently impoverishes what gets built on it — un-recorded weeks can never
be backfilled. And every audio feature is gated behind a debt: fifty tracks
and five one-shots have still never been heard by a human ear, on the very
surface that shipped 100%-broken on device while flawless in Simulator.*

### 0a. The ledger

`docs/NEXT_UPDATE.md` settled: build 2 live, AlbumView rasterization off the
main thread, the iPad decision made (recommendation stands:
`TARGETED_DEVICE_FAMILY = "1"` this era — an iPhone app on purpose; the
Homestead's panorama in Y is the first screen that would earn a big canvas,
revisit then).

### 0b. The Chronicle — record now, render later

An append-only, calendar-keyed event log, one new `StorageKeys` entry:
sighting kept, dream kept, thing heard, buddy arrival, bond level reached,
stray milestones, sound found, festival session. A few KB per year.

What it does **not** need to record, verified against the model: sessions
already store full `endedAt: Date` — so per-day counts, hour-of-day
histograms (the Year Ring, the Shelf of Hours) and night detection are all
derivable retroactively to the user's very first session. The Ring ships
already old. The Chronicle exists for the events that currently vanish:
the journal keeps only first/last-seen per species, so *this week's
sightings* — the Sunday Post's raw material — are otherwise lost weekly.

Ships with `-PawmodoroSeedChronicle` (a plausible six weeks of events) and a
`-PawmodoroResetState` audit covering the new key.

### 0c. The world calendar module

As specified in the do-not-break list: one file, `-PawmodoroDate`, DST and
hemisphere policy, `seed(day:place:)`. Shipped seasons are retrofitted onto
it in the same commit, so there is exactly one opinion about what "today"
means before nine features acquire opinions of their own.

### 0d. The conventions commit

CLAUDE.md gains: the no-decay wall, the dream-backfill convention, the
single-node audio law, the no-calendar-notification rule. The dream-pool
backlog is paid: 2–3 entries each for bond, regulars, heard things, seasons,
and the stray's later stages. Cheapest depth-per-byte in the app.

### 0e. The batched Mac-and-device session (one sitting, four gates)

1. **The listening pass**: all 50 tracks + 5 one-shots + 6 ambiences, on a
   device, with headphones. Notes taken per track; anything broken fixed or
   pulled before W adds a single new sound. *This gates all of Phase W.*
2. iPhone SE simulator runtime installed; the never-verified rows from
   RESUME_HERE.md walked where now possible.
3. The widget/Live-Activity extension target created (it has been waiting
   since Phase D) — but **not** shipped until Z; it just needs the one-time
   Xcode step done while the Mac is open.
4. The App Group container registered, migration code written and tested
   behind a flag, dormant until Z.

**Release 1.1 is Phase 0 + the first slice of V.** Nothing in 0 is a
screenshot; all of it is load-bearing.

---

## Phase V — Weatherfronts (the sky has moods)

*Ecology's top build [9/8/6/9]. Serves: time depth, MORE ANIMALS,
gamification.*

### V1. The weather itself

Each place rolls one weather per calendar day from `seed(day:place:)` —
deterministic, offline, identical on reinstall. Opening the app in the
morning becomes opening the curtains.

| id | Feels like | Odds | Notes |
|---|---|---|---|
| `clear` | today's default | ~45% | exactly what exists now |
| `overcast` | soft grey light | ~15% | flattened wash |
| `breeze` | everything leans | ~12% | existing particles, wind bias |
| `drizzle` | thin quiet rain | ~10% | sparse streaks |
| `rain` | proper rain | ~8% | C2's layer, now place-driven |
| `mist` | fog banding | ~6% | horizontal veils, muffled palette |
| `storm` | dark and rumbling | ~1 in 30 | an *event* |
| `golden` | post-storm clarity | the day after storm | warm rim light; the reward |
| `snow` | winter only | replaces rain ids | reuses season particles |

Weather **decorates, never blocks**. It changes what you see, hear and meet
— never what you can do.

### V2. Drawn as veils, not exports

The scene pipeline stays untouched — still 8 places × 4 times, not × 9
weathers. Weather is runtime composition, the sky-wash trick again: a
theme-aware translucent veil per weather, mixed toward `cream` the way
`Palette.sky(_:)` pins luminance so contrast holds by construction, plus
`AmbientSceneView` particles extended with `drizzle`, `mist`, `storm` (soft
full-sky flash ≥6s apart, never strobing) and `breeze`. Reduce Motion keeps
veils (static), drops particles and flashes. `check_contrast.py` samples
every text row under every veil — the pair count roughly doubles; let it.

Ships in two slices, per the judges: **V-slice-1 = veils + particles + the
suggestion glow (W2's hook, sound-less), zero species.** Weather must feel
right for a week on the owner's own phone before anything lives in it.

### V3. Wave 4 — the creatures that come with the sky (~18 species)

Journal 41 → ~59. Weather-gated exactly as existing species are hour-gated —
this wave is roster data and sprites, no new engine. The roster (names final
unless the sprites argue): **rain/drizzle** Garden Snail, Big Frog, Little
Frog (regular note: "the two are never seen together"), Earthworm, Rain
Beetle; **mist** Fog Moth, Roe Deer, Ghost Slug; **storm** Storm Petrel
(harbor), Weathervane Crow (sits through the whole storm); **golden**
Dragonfly Swarm, Sun Cat (a stranger, not the stray); **breeze** Kite Spider,
Dandelion Mouse; **snow** Snow Hare, Ermine, Winter Wren; **overcast** Grey
Heron, Mushroom Vole.

**Phenomena**: Sun Shower (very rare), Fogbow (mist's rainbow), First
Thunder (spring's first storm — one chance a year, the journal's rarest
page). **New heard**: Distant Thunder, Foghorn (harbor, mist), Geese Going
South (autumn). `SightingRecord` gains an optional `weather` field (optional
= old journals decode untouched): "seen in the rain at Harbor Isle, after
dark." The stray shelters under the eaves in rain — a `Stage.x` lookup that
`check_stray.py` already knows how to judge.

### V4. The Flyway (migrants on the world calendar) [8/9/6/10]

Eight to ten species that pass through only during real calendar windows —
two weeks each, seeded per year so the dates breathe a little: Whooper
Swans (early spring), Swifts (early summer), the Salmon Run (autumn,
harbor), Snow Geese (late autumn), a Comet (once every few years, the sky's
own migrant). The almanac lists **only what has already been seen**; missed
passages read kindly next year ("the swans went over early this spring").
No notification, ever — the rule above. Sightings roll through the existing
engine with the window as one more eligibility gate.

### V5. The Old Snail (ships quietly alongside V) [10/6/7/10]

A snail crosses each scene at a pace measured in **months** — her position a
pure function of today's date, the countdown philosophy scaled up
ten-million-fold. She cannot be hurried, needs nothing, and is simply
*there* on the days she's crossing your part of the meadow. Finish a session
while she's visible and the journal quietly notes it. She is never for
sale, never announced, and designed to be discovered by the kind of person
who notices snails. `check_snail.py` (the check_stray.py mold — she is
screen-positioned art, the proven floating-hazard class) and
`-PawmodoroSnailDay` (an alias into `-PawmodoroDate`) land **in the same
commit as her first sprite**.

### V6. Tidewater (the moon pulls the Harbor) [9/7/7/9]

The Harbor gains a real tide: a pure function of date and the moon phase the
app already models. Low tide drops the waterline to reveal a shore strip and
a tide-pool wave (6–8 species: crab, starfish, anemone, curlew,
oystercatcher — and a rumored octopus at the lowest spring tides). High
tide brings seals close. The almanac gains a tide-table page drawn as the
classic sinusoid — the app gently teaching a real natural rhythm. Scene
delta is drawn as an overlay strip on the existing Harbor exports, same
veil discipline; `generate_scenes.py`'s sky-only assertion carries over.

### V7. Flags

`-PawmodoroWeather <id>`, `-PawmodoroDate <yyyy-mm-dd>` (from 0c),
`-PawmodoroTide low|high|springlow`. Existing `-PawmodoroSighting` /
`-PawmodoroFillJournal [n]` cover every new species by construction.

---

## Phase W — The Weather Radio (a louder world, behind the listening gate)

*Nothing in W starts until 0e's listening pass is done. That is a hard gate,
not a caveat — this surface shipped 100%-broken once.*

### W1. The Second Shelf — twelve new ambience loops, two batches of six

All `make_*` recipes in `generate_assets.py`, mono 22.05 kHz, seamless via
the existing fades. Batch one (simplest synthesis first, judges' order):
`drizzle` (rain body high-passed, transients at a third the density),
`wind` (band-swept noise, two beating LFOs), `creek` (ocean at quarter
scale, bubbly band-pass), `library` (deep room tone, rare page turns),
`snowhush` (dark noise at −18 dB with 8-second breathing — the sound of
sound being absorbed), `temple` (the far bell over pine wind). Batch two:
`storm` (rain + brown-noise swells + baked distant thunder), `crickets`
(pulse trains ~4.5 Hz, five detuned voices), `cicadas` (saw-shimmer tamed
by `distant()`), `night train` (rail clack at half speed under interior
rumble — the Night Train mixtape's room), `rain on the tent` (rain through
a resonant membrane), `embers late` (fireplace's last hour). Each batch
gets its own device ear-pass before shipping.

**Found, not bought** — the gamification of sound, and Soot's rule applied
to audio: `storm` unlocks by finishing a session during storm weather
("recorded it for you"), `snowhush` in snow, `crickets` after five night
sessions. Plus owners still have to be there. The rest split free/Plus as
the first six did.

### W2. The suggestion, and the circadian grades [10/6/6/10]

When a place's weather matches a loop, that chip glows softly and floats
forward in the Sound Studio. Tapping remains the only way anything changes.
Radio mode learns weather as its third input (place, hour, now sky).

Then the era's quiet masterstroke, judged the deepest audio idea: **do to
ambience what `generate_scenes.py` does to scenery.** Each loop exports in
four time-of-day grades derived from one recipe by deterministic transform —
filter tilt darker at night, event density thinning after dusk, the cafe
emptying to cup-clinks, the ocean gaining a slow bell buoy after dark.
Pre-rendered offline (the single-node law), picked by the same clock the
sky uses, so `-PawmodoroClock 22` pins what you hear and see in one flag.
The almanac notes, star-atlas-quietly: "You have heard the forest at dawn."
All four grades of a loop earn its sepia field-recording card.

### W3. No two rains (the variation the owner asked for by name)

Per-session variation without runtime layering: the generators pre-render
**three deterministic variants per loop per grade** (different garnish
seeds — this thunder placement, that owl, a different bell-buoy timing),
and the session picks one by `seed(day:place:)` + session count. Decided
once at phase start, pure playback after — the sighting engine's law
applied to the ears. Rare baked garnishes (a fox bark in the night forest,
the first thunderclap of a storm) register in the **heard** journal, which
grows from a short list into a real collection. File cost is honest: ~16
loops × 4 grades × 3 variants of mono AAC ≈ 15–20 MB on a 22 MB app —
the size budget gets its own assertion in the generator, and grades/variants
are trimmed to fit a 45 MB ceiling before anything ships.

### W4. The Bell of Hours [7/9/7/10]

While a session runs, the top of each real hour lands one soft, place-voiced
strike: a far church bell in the meadow, a buoy at the harbor, a temple bowl
at the onsen — three seconds, graded to the hour (near-subliminal at 3am),
off with one toggle. The almanac gains the clock-ring: twenty-four
positions that fill as you're *present* for each hour striking, across
however many weeks that takes. No count is shown anywhere; the dark hours
are visible only by looking. Completing the ring mints one postcard: the
buddy beneath a bell tower.

### W5. Music III — fifteen tracks, three gates that are ways of playing

- **Rainy Day Tapes** — five sparse pieces voiced to duet with the
  rain-family loops (midrange left open where rain lives). Found: five
  sessions with rain running.
- **Night Shift** — five low-energy pieces, 60–68 bpm, sister to the star
  atlas. Found: the after-dark counter.
- **Soot's Tape** — five music-box lullabies that arrive only when the
  stray's trust arc completes. The one reward for the app's one hidden
  story: an ending you can *hear*. Never for sale, like her.

Radio folds unlocked tracks into its filters, so every find audibly widens
the world. Catalog 50 → 65; recipes in SOUND_ALMANAC style appended there.

### W6. Flags

`-PawmodoroUnlockSounds` (found ambiences), `-PawmodoroUnlockMusic` learns
the found gates, `-PawmodoroVariant <n>` pins a rain-ledger variant,
`-PawmodoroBell` fires an hour strike 5 s after launch.

---

## Phase X — The Open Hour (the sit, and new faces for it)

### X1. The Drift — count-up mode [8/7/5/8, the era's one engine change]

A long-press on play casts off with no end time and no alarm: the ring
inverts from countdown to accumulation, filling over 25 minutes and laying a
thin concentric **tree ring** at each lap — two hours of deep work is five
rings, time made visible in the same language the Homestead's trees will
use. Ending is tap-and-hold (accidental ends are the failure mode that
matters); every minute banks; the journey moves the same distance it would
have.

Rules: the Drift **is** focus — scenery deaf, dreams and encounters roll
once at cast-off. Sightings roll *per lap*, so a long drift can meet two
animals — and past the 30- and 50-minute marks live the **deep-drift
species** reachable no other way: a whale surfacing, a sea turtle, migrating
cranes crossing high, a sunfish. (MORE ANIMALS, vehicle three.) No
notification is scheduled — nothing to announce. Elapsed derives from the
absolute start `Date`; returning after six hours away asks gently whether
the time should count — the only question the Drift ever asks. Longest
drift is a quiet almanac line, recorded, never challenged.

`-PawmodoroDrift` starts one; fast timers compress laps to 25 s and the
deep thresholds proportionally. `-PawmodoroLaps <n>` seeds a deep drift.

### X2. The Cabinet of Clocks [9/8/8/9]

Six to eight alternate renderings of the same sacred interval, each a pure
view over `engine.progress`, TimerEngine untouched: the **incense clock**
(a coal creeping down a carved stick, ash accumulating — the Onsen's
native face), the **water clock** (Harbor), the **candle clock** (marked
rings melting), the **sand glass**, the **shadow clock** (a gnomon whose
shadow arcs with the phase), and the classic ring. Faces are earned by
counters the app already keeps — the night counter, arrivals, a completed
constellation — padlocked-never-hidden, one new `StorageKeys` entry,
`-PawmodoroClockFace <id>`. Two disciplines from the judges are
non-negotiable: a frame-strip monotonicity assertion in the generator (a
1fps art regression is invisible to the eye), and every face folded into
`check_contrast.py`'s scene-pixel sampling with the digits kept on their
capsule.

---

## Phase Y — The Long Now (four altitudes of looking back)

*The era's centerpiece and its screenshot. Everything here is a pure
function of data that already exists (sessions carry full Dates) plus the
Chronicle from 0b — which is why 0b ships first.*

### Y1. The day — the Shelf of Hours [7/7/9/8]

Twenty-four candle vignettes, one per hour of the clock; a candle lights
the first time a session ever *ends* in that hour (credited by the absolute
end Date). 3 a.m. carries a caption that is strange, not virtuous — every
night-hour caption passes the "strange, not proud" test in copy review, or
ships with no caption at all. No count, no list of unlit candles, nothing
anywhere but the shelf itself. Backfills from history the day it ships.

### Y2. The week — the Sunday Post [9/9/8/9, ritual's top build]

Once a week an envelope leans against the house: a short letter from your
buddy about the week you actually had — where you sat, what the two of you
saw, a dream worth mentioning, the moon — over a small painted week-strip.
Template grammar in the world's voice, composed from the Chronicle; files
into the album beside the postcards; shareable like one. Collectible
stationery: seasonal papers, and a stamp per place you've actually been.

Designed explicitly as the era's **aggregation surface**: the letter's
grammar takes an event feed, so weather that passed, a tide that revealed
something, swans that went over, a candle lit and a resident who moved in
each plug in a *sentence*, not a screen. Small systems get their weekly
paragraph instead of their own UI.

### Y3. The year — the Year Ring, with Quiet Anniversaries pinned

A circular calendar in the almanac: 365 thin wedges, each day tinted with
the real sky gradient of the hours actually focused — dawn sessions paint
the day rose, midnight ink — from the same `Palette.sky` tables the scenes
use. Empty days are quiet parchment, never red. Drawn entirely in Canvas
from palette data; `check_contrast.py` samples computed wedge tints; zero
new PNGs. Because sessions store full Dates, **the ring ships already
old** — a year-one user sees their whole history on day one.

On the rim sit the world's own dates, recorded by the Chronicle from 0b
onward and inferred from history where possible: first session, each
buddy's arrival, the stray's naming day, First Thunder. The almanac's Today
line notes them ("a year since Luna arrived — she gets the good cushion
tonight"), the scene wears one small prop that day, and finishing any
session on an anniversary stamps the year on its postcard. Solstice and
equinox dress the sky slightly. Nothing notifies; the day is simply better
if you happen to be there — and next year's ring holds what this year
recorded.

December 31 mints the Year Postcard through the existing pipeline. Past
years stack behind the current one like tree rings; the stack is Plus, the
current year always free and complete.

### Y4. The lifetime — the Homestead (Grove ∪ Understory, merged)

The two highest-soul proposals of the panel are one instinct — accumulation
made visible at home — so they ship as one system. The home scene slowly,
permanently grows, on two clocks:

- **Residents** (the Understory, soul-fit 10): at quiet milestones of the
  bond counter that already exists, small ambient neighbors move in and
  then are simply *there* — a pond that clears and gains fish, a beehive, a
  birdhouse that gets its tenant, a hedge that flowers. 8–10 residents at
  2–4fps idle loops, announced only by the buddy's caption noticing
  ("someone new in the birdhouse"). The almanac gains the Homestead page.
- **The grove** (time's top build): behind the house, one sapling per
  completed focus **hour**, thickening through growth stages at 5/10/25
  hours per tree. A hundred hours is a small forest that exists because you
  sat still. Journal species come to **roost** — the owl in your oak, the
  fox at the treeline — so filling the journal and growing the grove feed
  each other, and the era's animals get a second home.

Layout is deterministic from a stored seed — the compatibility contract,
with its regression fixture, per the law above. Trees and residents never
die, never wilt, never leave; growth-only is asserted in review, not hoped.
`tools/generate_grove.py` (the scenes mold: palette indices, four grades)
plus `check_grove.py` (densest grove per theme/appearance; trunks
feet-anchored on the ground line — the stray taught us; caption capsules
clear 4.5:1). At 100 hours: a panoramic postcard. Entirely free, buddies to
residents — Plus adds tree varieties native to the Plus places, padlocked
never hidden. `-PawmodoroGroveHours <n>` jumps to any density.

---

## Phase Z — The Window Sill (presence, and the one dangerous migration)

Deliberately last: the only phase that cannot ship from the command line,
and the only one with a real migration. The extension target and App Group
were prepared in 0e; Z turns them on.

- **Small widget — the window**: the buddy right now (asleep in focus,
  waving at idle, night pose after dark) + today's count. The home screen
  gets a pet.
- **Medium — the homestead strip**: the last 14 days as garden growth (the
  reason Y ships before Z).
- **Lock screen**: circular = today's count in a paw ring; rectangular =
  the streak boat, anchored or sailing.
- **Live Activity**: the Phase D code, finally alive — countdown during
  focus, count-up during a Drift.
- **Intents**: `StartFlowIntent` and `StartBreakIntent` join
  `StartFocusIntent`, every phrase carrying `\(.applicationName)` (the rule
  that fails at runtime, now documented three times). The Action Button can
  cast off a Drift.

The migration: `UserDefaults.standard` → the App Group suite for the keys
widgets read. One-time, idempotent, old keys kept one version as backup,
`StorageKeys` remains the single source of truth, `-PawmodoroResetState`
clears both stores from day one, and `check_swift.py` grows a rule tying
every key to its store. Widgets render from shared sprites and pure
timeline entries — no live engine in the extension.

---

## The release train — small updates, one headline each

| Version | Ships | The headline |
|---|---|---|
| 1.1 | Phase 0 + V-slice-1 (weather, no species) | "The meadow has weather now" |
| 1.2 | V3 wave 4 + V5 snail | "Creatures come with the rain" |
| 1.3 | V4 Flyway + V6 Tidewater | "The moon pulls the harbor" |
| 1.4 | W1 batch 1 + W2 circadian | "The world got a voice for every hour" |
| 1.5 | W1 batch 2 + W3 + W4 + W5 | "No two rains, and Soot's Tape" |
| 1.6 | X (Drift + Clocks) | "The open hour" |
| 1.7 | Y (all four altitudes) | "See what 100 hours looks like" |
| 1.8 | Z | "A window on your home screen" |

Two constraints are load-bearing: 0 before everything (the Chronicle cannot
backfill), and the listening pass before any of W. X can trade places with
W if a release needs to ship light; Y's altitudes can split across two
updates if the Homestead runs long — ship Y1+Y2 first, the Ring and
Homestead as the follow-up.

## New debug flags (CLAUDE.md table additions; Release stand-ins required)

| Flag | Effect |
|---|---|
| `-PawmodoroDate <yyyy-mm-dd>` | Pin the world calendar everywhere (weather, tide, flyway, snail, anniversaries) |
| `-PawmodoroWeather <id>` | Pin today's weather at every place |
| `-PawmodoroTide <low\|high\|springlow>` | Pin the Harbor's tide |
| `-PawmodoroSeedChronicle` | Six plausible weeks of world events |
| `-PawmodoroUnlockSounds` | Treat every found ambience as found |
| `-PawmodoroVariant <n>` | Pin the rain-ledger variant |
| `-PawmodoroBell` | An hour strike 5 s after launch |
| `-PawmodoroDrift` | Cast off an open hour on launch |
| `-PawmodoroLaps <n>` | Seed a drift n laps deep |
| `-PawmodoroClockFace <id>` | Start on a cabinet face |
| `-PawmodoroGroveHours <n>` | Jump the grove to any density |

## Considered, and kept for the era after

- **While You Slept** (evening tuck-in, morning curios) [8/8/8/7] — lovely,
  but it's a new daily ritual surface and this era already adds the Sunday
  rhythm; its curio shelf also wants the Homestead to exist first. Next era,
  where it inherits residents to leave the curios.
- **Red-Letter Days' festival dressings and festival tracks** — the
  anniversaries shipped in Y3; the full costume-and-track festivals are a
  content wave for an era with the listening debt long paid.
- **Named doorways / ritual intents beyond the two shipped** [8/5/7/7] —
  wait for evidence people use the first two.
- **The Ambience Loom & Weatherworks** — superseded structurally: the
  single-node pre-mix law delivers their goals without their graphs.
- **Real-weather anything** — refused permanently, see anti-goals.

## What Opus should do first

Read this file top to bottom, then build **Phase 0 only** — the Chronicle,
the world calendar, the conventions commit, and schedule the Mac/device
sitting for the four gates in 0e. Do not touch a veil, a species or a loop
until 1.1's invisible half is committed and the listening pass has notes.
Then V-slice-1, `check_contrast.py` green, on the owner's phone for a week
before wave 4 lands. Add an **As built** section under each phase as it
lands, in the tradition the other plans established: where the code
disagreed with this document, the code's reasons get written down.
