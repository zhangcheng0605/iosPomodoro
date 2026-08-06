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

### As built

0b, 0c and the conventions half of 0d landed in one session on a Mac and are
verified on device. 0d's dream backfill and 0a's rasterization fix landed in a
second session on Linux, unbuilt — `check_swift.py` is green and every sprite
was looked at, but nothing here has been through a compiler. 0e is untouched
and still needs the Mac sitting.

**The dream backfill grew a sixth source and split bond off from it.** The
plan asked for 2–3 entries each for bond, regulars, heard things, seasons and
the stray's later stages. The previous session's recorded design was a single
`case companion(Buddy)`, on the reasoning that gating it on ownership would
let "bond and the stray's arc feed it for free". Half of that held and half
did not. The stray does arrive free — Soot becomes ownable only at the end of
her arc — but a dream about *another animal in the house* says nothing about
how well the two of you know each other, so bond was not fed at all. Built as
six cases instead:

| Case | Comes from | Gate | Art |
|---|---|---|---|
| `regular(Species)` | the regulars | `journal.isRegular` | `wild_<id>_regular`, already a sepia sketch with the marking |
| `companion(Buddy)` | the roster | bond ≥ acquainted, minus whoever is on duty | the asleep sprite, as a silhouette |
| `visitor(Visitor)` | the stray, stages 2–4 | her stage, and only while she is still outside | her three scene sprites, as silhouettes |
| `sound(Heard)` | the five you never see | `journal.hasHeard` | 5 new |
| `season(Season)` | the seasons | only during that season | 5 new |
| `yours(Yours)` | the bond, and nothing else | bond ≥ friendly / close / devoted | 3 new |

Four decisions inside that are worth knowing before touching it:

- **The stray gets her own String-raw `Visitor` enum** rather than reusing
  `Stray.Stage`, which is `Int`-raw. The diary is keyed on `Dream.id`, and
  `"visitor.3"` is a key nobody can read and nothing can safely renumber. It
  is the same trap that produced `chronicle.add(.bond, bond.rawValue)` — an
  `Int` raw value handed to a `String` parameter — on the day the Chronicle
  was written.
- **The five sounds are drawn as sounds, not as their sources.** A whale you
  can look at is not what the journal promised. The sprites are the swell that
  reached you, the horn going away, two calls and then nothing, one stroke
  spreading in every direction, four hanging notes. "Heard and never seen"
  survives the dream.
- **A season can only be dreamed while it *is* that season.** A dream of snow
  in July would say the seasons mean nothing, which is the opposite of what
  they are for.
- **No caption names a buddy.** They can all be renamed and a model type
  cannot reach `settings.displayName(for:)`, so a companion is described by
  what it is — "the otter", "the cat who came in".

**The diary's total went 50 → 116, and nothing anywhere shows it.** The page
prints how many have been dreamed and never what is left, which is the
no-hidden-count-shaming anti-goal already holding at four times the size.

**`-PawmodoroFillDreams` was not in the plan and had to be.** The page now
draws on five gated systems at once, and the honest route to a full one is a
hundred and fifty sessions, five sightings of forty species, all five seasons
of a year, and a cat who takes twelve days to come in. `-PawmodoroFillJournal`
does not reach it: that fills the journal, and a dream still has to be rolled
and stayed for.

**`check_swift.py` gained two rules on the way through**, both verified by
deliberately breaking the code:

1. Dream sprites are checked. It reads each `case .sound(let sound):
   "dream_heard_\(sound.rawValue)"` arm, resolves the associated type from the
   case's own declaration, and demands one imageset per member — so a missing
   sprite fails on Linux instead of drawing an empty bubble on a screen that
   takes months to reach.
2. `switch self` inside an `extension` is checked at all. It never was. Half
   the app's tables live in one, so adding a buddy broke four switches and the
   checker reported three — which reads as "you're done", the worst answer a
   checker can give.

**0a's rasterization fix is `Transferable`, as recommended**, and it is the
one thing here likely to need a signature fixed on the next Mac build:
`DataRepresentation`, `SharePreview` and `ShareLink` are precisely the
argument-label-and-inference class `check_swift.py` is blind to. The share
preview lost its image on purpose — every `SharePreview` that carries one
wants that image up front, which is the thing being fixed.

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

### As built — V-slice-1 (weather, no species)

Built on Linux, unbuilt by any compiler. `check_swift.py`, `check_contrast.py`,
`check_stray.py` and the new `check_weather.py` are all green; the three new
sprites were rendered and looked at. **V3 onward has not been started**, per
the plan's own instruction that weather spend a week on a real phone before
anything lives in it.

**`check_weather.py` found a real bug on its first run, before anything had
been compiled.** Golden was written as "if yesterday stormed, today is golden",
which is what the table above says. Over a decade of every place that produces
two failures nobody would ever have reported from inside the app: two storms
running showed **golden on both days**, and the second storm was **never shown
at all**. The rarest weather in the table, silently eaten by the second-rarest,
about thirty times a decade. The fix is one clause — golden only wins when
today is not itself a storm — and it also does all the work of keeping golden
days from chaining, which the original comment had claimed was impossible for a
reason that turned out to be wrong.

That is the argument for the whole file: weather is a pure function of the
date, so it is one of the few things in this app that can be checked
*completely* without a Mac. Run every day of a decade at every place and count.

**The fixture is the half that matters.** Everything else in `check_weather.py`
parses the weights out of `Weather.swift` and then verifies the roll against
them — which is self-consistent by construction. Swapping `mist` and
`overcast` passed cleanly. So the file carries two dozen stored (day, place) →
weather rows, generated once from the shipping implementation, covering all
nine weathers. Those catch a changed weight, a reordered `rollable`, and a
touched seed constant — verified by doing each. This is the plan's own
"layout seeds are compatibility contracts" rule, and every date-rolled feature
after this one — tide, flyway, snail, grove — wants the same two halves.

**Divergences from the plan, and why:**

- **Weather particles are their own layer, not an extension of
  `AmbientSceneView`.** The plan says to extend it. That layer is mounted only
  while the timer runs with a sound chosen, because it is the *picture of the
  ambience* — but weather is not a choice and is not earned, and "opening the
  app in the morning is opening the curtains" only works if the curtains are
  open before you press play. `WeatherView` is modelled on `SeasonalView`
  instead, at the same 12fps and for the same reason. One piece of
  coordination: if the rain ambience is playing and it is also raining, only
  one rain field draws.
- **The suggestion glows but does not float forward.** W2 asks for the
  matching chip to "float forward in the Sound Studio". It glows, and the row
  gains three words saying why ("for the rain"), and the order does not
  change. A settings list that rearranges itself with the sky is the app
  moving your furniture; the glow already does the job, and reordering can be
  added later if a week on the phone says the glow is too quiet. The ring is
  static rather than pulsing, and the reason is on the main screen: something
  breathing there is something the eye keeps coming back to for the rest of
  the session.
- **Snow's "winter" is `Season.winter`,** which is December only, rather than a
  second set of month windows. One opinion about the time of year — and
  `-PawmodoroSeason winter` therefore makes it snow, which is what anybody
  reaching for that flag wanted.
- **The weather is named in exactly one place.** The plan's V-slice-1 is veils,
  particles and the glow, none of which give the sky a *name*. The almanac's
  today line gained `· mist` and a one-line remark under it, because a thing
  with no name is a thing nobody can tell you about. Everywhere else it stays
  a veil and some particles, which is the right weight for it.
- **Three dream entries, not nine.** The standing convention wants 2–3 per
  feature; one per weather would be nine sprites and nine near-identical
  captions, and a dream about "overcast" is not a dream about anything.
  `Dream.Sky` is `puddle` (after rain or drizzle), `thunder` (after a storm)
  and `afterglow` (after a golden day) — two of them rare enough that having
  them in the diary means you were actually there. This is the first feature to
  ship *with* its dreams rather than owing them.

**What the contrast check does and does not prove.** It grew from 103k
measurements to 922k, composites every veil, and passes everywhere. But it was
pushed to find out what it is sensitive to, and the answer is: not the veil.
The text capsules composite last at 70–82 % opacity and dominate the result;
a veil only fails at `weatherMix` 0 with an opacity of 0.8, four times anything
shipped. One reassuring number did fall out: every weather veil measures
*better* than a clear sky, because mixing toward `cream` moves the background
away from the `bark` text. The tightest pair in the whole matrix — 5.18:1 — is
a clear-sky pair that predates weather entirely.

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

### As built — V3, wave 4

Built on Linux, never compiled. The journal goes 41 → 63: nineteen animals,
three phenomena, three sounds. `tools/check_species.py` is new.

**The gate.** `Spec.weathers` — empty means any sky, which is every species
that shipped before the weather existed — checked against `Weather.at(place)`.
Never against the ambience loop: wanting to see a snow hare is not the same as
arranging one. The rainbow keeps the rule it shipped with (half a session of
*listening* to rain) because people have rainbows and a rainbow you got by
choosing the rain loop is a fair rainbow.

`needsRain` became `awardedLate` and `TimerEngine.lateAward()` generalises what
was the rainbow's special case. Three more use it: the Sun Shower, the Fogbow,
and First Thunder — one chance a year, only if you are sitting down for the
first storm of spring, gated on the journal's own record of whether it has
already happened rather than on a second flag. One award per session, rarest
first: two phenomena in one sitting would make both ordinary.

**What the checker found, on its first run.**

- **The Grey Heron has been letterboxed since wave 2.** Drawn 19×18 by the
  shared `songbird` builder, laid out inside a 34×40 frame — so every heron
  anybody has ever seen had eight points of dead space under it. Two of the
  new rows had the same bug. Nothing in the app could have shown this: the
  sprite is correct, the frame is correct, and `scaledToFit` quietly does the
  right thing with the wrong numbers.
- **`meteors` and `aurora` are phenomena that are correctly rolled normally**,
  because what gates them — where you are, what hour it is — is knowable when
  the session starts. That killed a rule written the wrong way round. The rule
  that survives is one-directional: everything `awardedLate` must be a
  phenomenon, and must name the sky it waits for.
- **The snow group is a December affair.** `Season.winter` runs 1–31 December
  and snow is rain-or-drizzle inside that window, so the three snow species are
  reachable about nine days a year across two places each — just over the
  floor. That is the design, and it is now measured rather than assumed.
- **`check_stray.py` had to get stronger.** She shelters in the wet by moving
  to whichever side she is not usually on, so a stage can now stand at either
  column; the checker tested each at its own. It cross-tests all of them now.
  Its own first version included the 0.5 column, which belongs to the indoor
  stages, and reported the cat standing in the Onsen's hot spring — a true
  statement about a position nothing ever draws her at.

**Divergences from the roster.**

- **No Kite Spider.** A ballooning spider is a lovely idea and cannot be drawn
  at this scale. Four drafts: eight legs at eleven pixels is a lattice, six is
  a basket, four on a bigger body is a box with a lid, three bent ones per side
  weld into two wings and the thing reads as a moth. Leg *count* is not legible
  at any size this app draws at; splay is what the eye reads, and splay is what
  makes it a moth. The subject changed rather than the drawing — the wind gets
  a **Red Kite**, which soars, only turns up in wind, and has a silhouette.
- **No Snow Hare.** It would have been the third hare, and a snow hare is a
  mountain hare in a winter coat — the app already has the mountain hare.
  **Snow Fox** instead. Big Frog and Little Frog stayed, three frogs and all,
  because two of them are a joke ("the two are never seen together") and the
  app's own Hare/Mountain Hare sets the precedent.
- **Grey Wagtail rather than Grey Heron** for overcast, for the same reason.
- **The stray's shelter is a side, not a position.** The plan asked for her
  under the eaves; there is no eave in any of these scenes, and inventing a
  third column would have needed a fresh proof that it is ground everywhere.
  Both existing columns are already proven, so she takes the other one. Her
  dwell window *widens* in the wet — she is there for the shelter rather than
  for you, and leaving means getting wet. Nothing about her ever shrinks.
- **`SightingRecord.weather` is optional and nothing backfills it.** "Seen in
  clear weather" invented for a sighting from last March would be a memory the
  app made up.

**Still owed by V3:** nothing. The three new sounds are generated and
structurally checked and, like the other five, have never been listened to —
they join the listening pass in 0e.

### V4. The Flyway (migrants on the world calendar) [8/9/6/10]

Eight to ten species that pass through only during real calendar windows —
two weeks each, seeded per year so the dates breathe a little: Whooper
Swans (early spring), Swifts (early summer), the Salmon Run (autumn,
harbor), Snow Geese (late autumn), a Comet (once every few years, the sky's
own migrant). The almanac lists **only what has already been seen**; missed
passages read kindly next year ("the swans went over early this spring").
No notification, ever — the rule above. Sightings roll through the existing
engine with the window as one more eligibility gate.

### As built — V4, the Flyway

Eight passages, eight species, one launch flag, one checker with fourteen
break-tested rules, and three dreams. `Passage.swift` owns the windows;
`Spec.passage` is the gate and `Species.isEligible` asks it **first**, because
it is the only condition in the table that can be shut on 350 days of the year.

**The plan's roster changed in two places.** *Swifts* were already a Far Isles
species (`Species.swift` has had `.swift` since wave 2), so a swift passage
would have been one animal in two rows of the journal doing different things.
The early-summer slot went to the **Painted Ladies** instead, which are the
better migrant anyway — they genuinely cross a continent — and three more were
added to fill the year: the **Cuckoo** in late April, the **Redwings** in
October and the **Waxwings** in January.

**Four of the eight are drawn as movements rather than as animals.** A single
goose is a portrait of something nobody ever sees that close; what you notice
in November is a *line* of them. So the swans and the geese are a `skein` (out
of phase across the line — birds drawn flapping in unison read as one object
with a lot of legs), the salmon are a `run`, and the painted ladies are two
butterflies at different heights going the same way. Only the cuckoo and the
waxwing are single birds, and both are drawn perched.

**The painted lady took three drafts and the first two failed the same way.**
Drawn from above with wings spread, a butterfly is a symmetric shape with a
dark body up the middle; any bright mark near the top of each wing and the eye
assembles a **face** out of it. The white wing-spots were eyes, the dark
leading corners were ears, and the contact sheet was two rows of foxes. Moving
the spots did not help — the symmetry is the problem. It changed subject the
way the Red Kite did in V3, and is a passage rather than a portrait now. (The
existing meadow butterfly has the same face-read, which is worth knowing and
not worth changing: it has shipped.)

**The comet is four-year but not thin, and that is arithmetic rather than
taste.** `check_species.py`'s reachability floor is 8 days a year and a
once-every-four-years fortnight is 3.5. Rather than write an exemption, the
comet is overhead for **forty days** when it comes — which is both what a
great comet actually does and 10 days a year averaged, clearing the floor
honestly. The floor did its job: it forced the design to be right instead of
being told to look away.

**`check_flyway.py` found one real bug on its first run.** The waxwings'
nominal opening was 8 January with ±10 days of drift, so in about a quarter of
years the window opened on day 0 or day −2 — and `Calendar.ordinality` has
nothing to say about the −2nd of January. Moved to the 18th rather than
clamped: a clamped window silently stops drifting in exactly the years it was
meant to be earliest.

**And the checker had two holes of its own, both found by break-testing it.**
Its `enum Flight` regex matched a *renamed* enum, so deleting the Flyway's
dreams passed cleanly. And its Python port hardcoded the seed's salt, so
changing the salt in the Swift — which moves every date this feature has ever
produced — passed cleanly too. The salt and the place are parsed out of the
`WorldCalendar.roll` call now. That is the third time this repo has paid for
the same lesson and the first time the rule caught it before the commit.

**Divergences:**

- **The almanac has no future tense at all.** The plan said it lists only what
  has been seen; the built version goes further and never mentions a passage
  that is *coming*. No countdown, no "opens in nine days", no greyed-out card
  — this is the second exception to "locked content shows a padlock", after
  Soot, and for the same reason: the surprise is the content. A passage is
  happening or it has happened.
- **The afterword shows one, not a list.** Six things that already happened is
  an inventory; the point is that the world went on while you were busy.
- **The Sunday Post lifts a passage out of the sighting list** and gives it
  its own sentence, without a new `ChronicleEvent.Kind` — the sighting already
  records everything, and a second kind would be a second thing to keep in
  step.
- **Nothing stacks a second unarrangeable gate on a window.** No passage
  species has a weather requirement, a full moon, or `awardedLate`; the places
  and hours are deliberately generous. `check_flyway.py` rule 6 enforces it —
  a fortnight is already the hardest condition in the app and multiplying two
  things nobody can arrange makes a species theoretical.

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

### As built — V5, the Old Snail

Built, unbuilt by a compiler, and shipped with `check_snail.py` and
`-PawmodoroSnail` in the same commit as her sprite, as the plan required.

**She crosses five places, not eight, and that was measured rather than
decided.** `check_snail.py` walks every hundredth of the screen at her ground
line, on a tall phone and a short one, and asks what is under her feet. Three
places have no answer: **Cloudspire** is a city on clouds and its best row is
62 % solid; **Harbor Isle** is an island in open sea — the exact hazard that
once had the stray sitting on the water; and **the Onsen** has a hot spring
across its middle, with three of fifty-six candidate ground lines clearing it,
all of them one redraw from failing. `Place.snailVisits` follows
`Place.strayVisits`'s precedent and says so.

**Her ground line is 0.79 — the stray's exact value**, and that fell out of the
search rather than being chosen. It is the only band that is solid ground at
every x of all five places on both device aspects. That it is also where the
cat sits is the nice part: it is the same ground.

**Six months across, six months away, on a 364-day cycle.** The odd number is
deliberate — she comes back at *about* the same time of year rather than on an
anniversary, and nothing in this app is allowed to feel like a schedule. Each
place gets its own phase offset from `WorldCalendar.seed`, so she is not in
lockstep across the world. She moves roughly two points a day: invisible
between one session and the next, unmistakable between one month and the next.

**Divergences:**

- **`-PawmodoroSnail <0-100>`, not an alias into `-PawmodoroDate`.** The plan
  asked for the alias. Her phase offset is *per place*, so the date that puts
  her mid-crossing at the meadow puts her somewhere else entirely at the
  woods — and the place is not known in `LaunchOptions`, before the engine
  exists. This overrides the derived value the way `-PawmodoroWeather` does.
  `-PawmodoroDate` still moves her honestly, along with everything else.
- **The journal notes her in the Chronicle, not the field journal.** "Finish a
  session while she's visible and the journal quietly notes it" — the field
  journal is keyed on species and she is not one. `ChronicleEvent.Kind.snail`
  records the place. Nothing is shown, nothing is unlocked, and in a year the
  Sunday Post will be able to say the two of you were both out.
- **She is not hidden from VoiceOver**, unlike the rest of the scenery. She is
  eighteen points wide and moves two points a day; if she is not announced she
  is only discoverable by people who can see her, and the whole point of her
  is being noticed.

### V6. Tidewater (the moon pulls the Harbor) [9/7/7/9]

The Harbor gains a real tide: a pure function of date and the moon phase the
app already models. Low tide drops the waterline to reveal a shore strip and
a tide-pool wave (6–8 species: crab, starfish, anemone, curlew,
oystercatcher — and a rumored octopus at the lowest spring tides). High
tide brings seals close. The almanac gains a tide-table page drawn as the
classic sinusoid — the app gently teaching a real natural rhythm. Scene
delta is drawn as an overlay strip on the existing Harbor exports, same
veil discipline; `generate_scenes.py`'s sky-only assertion carries over.

### As built — V6, Tidewater

Six new species, one changed one, a shore strip, a tide table drawn as the
sinusoid it actually is, three dreams, and the checker that turned out to be
the point.

**The model is real M2 and nothing else.** Two highs and two lows per 24h50m
lunar day, with the *range* opening at new and full moon and closing at the
quarters. That is genuinely how tides work and it is four lines. What it is
not is a real place: no harmonic constituent beyond M2, no shallow-water
correction, no location permission. Harbor Isle has its own sea for exactly
the reason it has its own weather.

**This is the first thing in the app that changes on the scale of hours**, and
that has a consequence nobody would have predicted from the plan:
`check_species.py` **cannot measure it**. That file answers "how many days a
year is this reachable" by counting days, and every day has a low water — so
the octopus would come out reachable 365 days a year while actually being out
for ninety minutes on a dozen afternoons a month, some of them at three in the
morning. Passing for the wrong reason is worse than not being measured, so
`check_tide.py` owns tide reachability at **hour granularity** and
`check_species.py` skips tide-gated species with a rule requiring that the
handover happened.

**And the hour granularity immediately proved it was needed.** Break-testing
the new checker, one mutation put a `dayParts: [.dawn]` on the octopus — an
edit that looks completely reasonable, "the octopus is out at dawn". Spring
low water *and* dawn coincide for **four hours a year**. Not four hours a
month. Two conditions on different clocks multiply, and the day-counting
checker would have reported that species as reachable every day of the year.

**The seal changed, which is the only shipped species this touched.** She now
comes close at half tide and high water, which is when a seal actually comes
in over the rocks. Widened to `.mid` as well as `.high` deliberately: adding a
condition to a species people have already met should not quietly halve how
often anybody meets her.

**The shore strip is nine points of screen and that is checked.** `TideView`
draws between 0.79 and 0.88 of the height; the lowest text row in the app is
the paw capsule at 0.718. Seven points of clearance is exactly the sort of
margin a later layout change eats without meaning to, and
`check_contrast.py` samples the *scene exports* — it cannot see a SwiftUI
overlay at all, so nothing else in the toolchain would ever report it.
`check_tide.py` reads both numbers out of their own files and fails on either
an overlap or a margin under 4%.

**Divergences:**

- **`Tide.State`, not `Tide.Stage`.** `check_swift.py` matches enums on their
  simple name and `Stray.Stage` already exists; two `Stage`s and its
  exhaustiveness rule goes quietly blind on *both*. It refused the file until
  the rename, which is the checker earning its keep on a collision nobody
  would have thought about.
- **No rumoured octopus at "the lowest spring tides" specifically.** It is
  gated on `.springLow` and on nothing else — no long session, no full moon.
  A spring low is already the narrowest repeating window in the app and the
  four-hours-a-year result above is what stacking looks like.
- **The almanac shows the tide whether or not anything has been seen in it**,
  unlike the Flyway, which stays silent until you have met it. A tide is not a
  surprise — it is the weather of the sea, it is there every day, and a tide
  table is a thing anybody at a harbour can read off a board. What it never
  does is name what is out there: "low water" is an observation, "the octopus
  pools are open" is an errand.
- **The curve is a `Canvas` with no `TimelineView`.** It changes by under a
  pixel a minute and the almanac is a sheet somebody has open for twenty
  seconds.
- **No `-PawmodoroTide springlow` boundary values.** Each named stage lands in
  the middle of its band rather than on its edge; pinning to a boundary is how
  you get a screenshot that disagrees with the almanac line beside it.

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

### As built — X1, the Drift

Built on Linux, never compiled. Five checkers green.

**One substitution made the whole thing cheap.** While drifting,
`TimerEngine.progress` returns the progress round the *current lap*. The
sighting's appearance window, the dream's 0.40–0.70 slice and the vignette's
position were already pure functions of `progress` — so the entire scenery
layer carried over with no changes at all, and "sightings roll per lap" became
one counter rather than a second engine.

**What it banks, and why.** One `SessionRecord` per completed lap, so the
journey moves the same distance it would have and the bond, the streak and the
stray's arc count it identically. A drift under one lap banks nothing, which is
the app's existing rule for leaving a countdown early. Past that every minute
banks: the leftover of the unfinished last lap joins the final record, so the
stats screen shows the hours actually sat. Only the *session count* rounds
down, and only ever downward.

Each record carries the time that lap really ended rather than one shared
timestamp — and that is a decision made **for Phase Y**, not for X. Y1's Shelf
of Hours lights a candle by the hour a session ended in, and Y3's Year Ring
tints a day by the hours actually focused. A four-hour drift recorded as four
identical timestamps would light one candle instead of four and paint one hour
of the ring instead of four, and by then the history would be unrecoverable.

**Divergences:**

- **The deep-drift species are not built.** A whale surfacing, a sea turtle,
  cranes crossing high, a sunfish — four new wildlife sprites, which belong
  with wave 4's art pass rather than in an engine commit. The per-lap sighting
  roll that they hang off is in and working; they are a roster addition when
  the art lands.
- **`-PawmodoroLaps` backdates the cast-off** rather than fast-forwarding a
  counter. The feature is a function of one `Date`, so moving that `Date`
  reaches exactly the state the honest two hours reach — laps, ring, banking
  and the six-hour question all agree without being told about the flag.
- **No Live Activity count-up.** The plan has one in Z; the controller is
  simply not called for a drift, so nothing has to be undone when Z arrives.
- **Both ends are a long press**, which the plan only asked for at the end.
  Casting off by accident is a smaller harm than ending by accident, but a tap
  that sometimes starts a countdown and sometimes starts an open hour is worse
  than either — one gesture, one meaning.

**The longest drift** is stored under its own `StorageKeys` entry, shown once
in the almanac as a fact ("The longest you have drifted: 2h 15m") and used for
nothing else. No next tier, no comparison, nothing that invites beating it: the
one part of this app with no clock on it is not getting a scoreboard.

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

### As built — X2, the Cabinet of Clocks

Built on Linux, never compiled. Five generated faces plus the ring.

**Frame strips, not shapes, and that is why this was buildable blind.** The
plan asked for "a frame-strip monotonicity assertion in the generator" and it
turns out to be the load-bearing decision of the whole phase: at one frame
every two minutes, a face that stalls, reverses or finishes early is invisible
to anybody watching. `tools/check_clocks.py` measures in a second what would
take five whole phases and a stopwatch to notice.

**One convention makes one assertion cover five faces:** the pixels drawn in
`ACCENT` are the part that *grows with time* — the wax pool, the fallen sand,
the ash, the risen water, the swept sector. The checker counts that colour per
frame and asserts it never decreases, actually moves, never stalls for more
than two steps, and travels at least 90 % of its range by the chime.

It found two problems, one each way:

- **The flame and the coal were `ACCENT`**, and both go out at the end of a
  phase — so the candle and the incense measured *less* on their last frame
  than their second-to-last, and the checker called it what it was: a clock
  running backwards. The live end has its own palette index now, which makes
  the convention exactly true rather than nearly true.
- **The water clock tapered the wrong way.** The vessel is wider at the top,
  so a rising surface should widen; the first version inset it as it rose and
  the water pulled away from the glass. The checker could not see that — it
  came out of the contact sheet. Second time in a day that a green checker
  still needed a look.

**Divergences:**

- **The chosen face lives in `PomodoroSettings`,** not its own `StorageKeys`
  entry. It is a setting; it rides in the settings blob with the theme and the
  buddy, and `-PawmodoroResetState` already clears it through
  `StorageKeys.settings`. A second key would have been a second thing to
  remember.
- **The ring fades to 30 % rather than disappearing** when another face is
  carrying the time. Two things counting the same interval at full strength
  compete, but the ring is still the thing readable from across the room.
- **Contrast is checked in `check_clocks.py`, not folded into
  `check_contrast.py`** as the plan says. The digits never move — they stay on
  their own capsule, which `check_contrast.py` already samples — so what
  actually needed measuring was the *face art* against the dial it sits on,
  and that is a sprite-against-background question of the kind `check_stray.py`
  answers. 960 pairs, faintest 7.79:1 against a bar of 2.0.

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

### As built — Y1 and Y2

Both built on Linux, never compiled, and both backfill: they are lenses on
`SessionLog` and the Chronicle rather than anything that had to be recorded in
advance.

**Y1, the shelf.** Twenty-four candles, two sprites, both templates — so the
only difference between lit and out is the silhouette (a flame, or two curls
of smoke going the other way), which reads better than colour at 26pt and
reads identically in all eight themes. Fourteen of the twenty-four hours carry
no caption at all, which is the right amount to say about 2 p.m.

Two decisions inside it:

- **The shelf does not honour `-PawmodoroClock`,** unlike `nightSessions` and
  the year ring. Those ask which *part of the day* a session belongs to and a
  debug clock may have an opinion about that. A candle is a specific hour of a
  specific day: forcing one would light a candle that is a lie, and candles
  never go out.
- **Its two dream entries cost no new art** — they are the shelf's own candles
  as silhouettes, and the hours they key on come from `ShelfOfHours` rather
  than being written out again, so the diary and the shelf cannot drift about
  which candle is which.

**Y2, the letter.** Built early and deliberately, because it is the
aggregation surface the rest of the era leans on: a system that gets a
sentence here does not need a screen.

That is also the source of its one real failure mode, and it is a silent one.
Add a `ChronicleEvent.Kind`, forget its sentence, and the letter simply never
mentions it — forever, reading perfectly well without it. Nothing else in the
toolchain can see the *absence* of a sentence. `tools/check_post.py` therefore
requires every kind to be either handled in `eventLines` or listed in
`SundayPost.silentKinds` with a reason. Only `sound` is there, waiting for
Phase W.

The other half of that file fences the letter's **voice**. This is the one
surface in the app addressed *to* the reader rather than describing them, so
it is the one most likely to drift into the register everything else avoids:
no congratulating, no instructing, no comparison with another week, no
exclamation marks. Fifteen rules, each paired with what it would actually be
doing. Verified by writing "Well done, that is better than last week!" into a
bond line and watching it fail four ways at once.

**Divergences:**

- **No stationery, stamps or album filing yet.** Y2 asks for seasonal papers,
  a stamp per place and for letters to file into the album beside the
  postcards. The letter is a plain card for now; the album's `Postcard` type is
  keyed to places and occasions and would need widening to hold a letter,
  which is a storage change and wants to be made once, with the Year Postcard
  from Y3.
- **One letter, the most recent.** Past letters are not kept. Nothing stores
  them, because everything they say is recomputable from the Chronicle — and a
  *list* of letters is a collection, which makes a missed week a hole in it.
- **The shelf shows no count anywhere**, per the anti-goal, including in the
  accessibility labels: an unlit candle reads as "unlit", never "not yet".
  There is no "yet", because there is nothing anybody is working toward.

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

### As built — Y3, the Year Ring

Built on Linux, never compiled. Six checkers green.

**It ships already old, exactly as the plan predicted** — and that is the
return on 0b. No new storage, no migration: `YearRing.build` is a pure
re-reading of `SessionLog.records`, every one of which has always carried a
full `endedAt`.

**The plan's tinting could not carry it, and only a checker could have known.**
Y3 says each day should be tinted "from the same `Palette.sky` tables the
scenes use". `tools/check_yearring.py` recomputes every wedge from the
palettes and measures each pair in CIE Lab, and the sky tables failed **61 of
320 pairs** — worst of all, in Cocoa, a night session's day measured ΔE 1.3
from a day nobody focused at all. The reason is structural and worth keeping
in mind for anything else that reuses a wash: `Palette.skyMix` pulls each hue
most of the way to `cream` *on purpose*, because a wash goes behind text and
its luminance has to stay near the background's. A wedge has nothing written
on it and needs the exact opposite.

Four separate palette hues were the second attempt and failed 18 pairs:
`sunshine` and `blossom` are both warm and sit close in several palettes, and
pulling them toward `bark` barely separates them in dark appearance, where
`bark` is also light. Ink's dark palette has no four distinguishable hues in
it at all.

What ships is a **lightness ladder** from the page colour to the text colour
(0.26 / 0.48 / 0.70 / 0.92) with the theme's accent riding on top at 20 %.
Lightness is the one axis every palette has four of; the steps are even by
construction; and it reads as the day going on, so a year of mornings is a
pale ring and a year of late nights a dark one — which was the claim all
along. Worst separation across 320 pairs: ΔE 10.4 against a bar of 8.

**Other divergences:**

- **No opacity ramp by session count.** One was written ("more sessions, more
  colour") and removed: it washed a one-session day out by 40 % and undid the
  separation the ladder guarantees. It was also answering the wrong question —
  the ring is about *when* you sat, and a day with one session is not a
  fainter kind of day.
- **The rim marks only firsts, and only some kinds.** Places reached, bond
  levels, the first session, and the two stray days worth remembering.
  Sightings, dreams, sounds and the snail are excluded: a rim with every heron
  you ever met on it is a smear, and those are the Sunday Post's material.
- **Not built:** the Year Postcard on 31 December, the anniversary scene props
  and the solstice sky dressing. All three want a surface that notices a date
  *while the timer is running*, which is a different piece of plumbing from
  the ring and belongs with Y2's letter grammar.

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

### As built — Y4's grove (the trees half)

Built on Linux, never compiled. The **residents** — the pond, the beehive, the
birdhouse, the hedge that flowers — are not built; nor are the four
time-of-day grades or the hundred-hour panoramic postcard. The trees are the
half that carries the idea, and they are the half with a compatibility
contract in it, which is why they went first.

**Two bugs, found two different ways, and the second is the more useful
story.**

`check_grove.py` found the first before anything was rendered. The layout used
φ−1 for x and √5−2 for y — and √5−2 *is* φ−1 squared, so both axes were
golden-ratio-derived and the sequences came back into phase at Fibonacci
intervals. Trees *n* and *n+89* landed 0.0097 apart: one tree drawn twice.
Invisible until ninety hours of focus, which is months. √2−1 takes the closest
pair to 0.0686.

The checker **missed** the second. Rendering a thirty-tree wood and looking at
it showed obvious diagonal stripes — two multiplied-and-wrapped sequences form
a lattice however irrational the multipliers are, and no rule about bounds,
spacing or spread can see that. A deterministic splitmix32 jitter of 0.06
breaks it: the worst 15° direction bucket falls from 53 % of near pairs to
24 %. The checker now measures near-neighbour directions, which is the thing
the eye was measuring. **A generator's output needs looking at even when its
checker is green** — the checker only knows the questions somebody thought to
ask it.

**The layout is frozen.** `Grove.position(of:)` and `Grove.hash` are both
written out, and `check_grove.py` carries a stored fixture. Everything above
that fixture parses the real constants out of the Swift, which is
self-consistent by construction; only the fixture notices a coefficient
moving. Same two halves as `check_weather.py`.

**`check_swift.py` grew a rule here too.** `Grove.Stage` and `Stray.Stage`
shared a simple name, which is what the checker matches on, so it merged their
case lists and reported three confident wrong failures — this file's switches
blamed for the cat's trust arc. Duplicate enum names are now a single failure
asking for a rename, and the ambiguous name is dropped rather than checked
against a merged list. The better fix was still the better name: `Growth`.

**Other decisions:**

- **A cap of 120 trees**, which is not a cap on anything earned — the hours
  keep counting everywhere else. Past that the canopy has closed and more
  sprites make a green rectangle.
- **Trees are positioned by their base**, like the stray and the snail, for
  the reason `Stray.groundLine` records: anchoring a centre puts a tall tree's
  roots lower than a short one's, and the error grows with the art.
- **The only number near it** is "the next is about 38 minutes away", phrased
  as an observation rather than a countdown. No percentage, no next milestone,
  no trees-to-go.

### As built — Y4's residents (the other half)

Built on Linux, never compiled. Eight of them — pond, birdhouse, beehive,
hedge, washline, lantern, well, bench — at 15/30/50/70/95/125/160/200 sessions,
two frames each at 2fps, `tools/generate_residents.py`. `GroveView` became
`HomesteadView` and now draws both halves.

**The interesting failure is one nobody could have seen for four months.**

The first arrangement interleaved residents with the trees by depth, sorted
into one list — which is the prettier picture, and is what the code comment
argued for at the time. `check_residents.py` was written to assert that each
resident kept most of itself visible with the wood in front of it, and on its
first run reported the beehive at **0 % visible**, the washline at 2 %, the
bench at 4 %, the pond at 12 %. A hundred and twenty full trees at 24×30
cover a 350×180 card *one and a third times over*: the canopy closing is
already in `Grove`'s own docstring, and anything sharing that depth range
simply stops existing. Nobody would have met it before a hundred and twenty
hours of focus.

That is a decay bug wearing a layout bug's clothes. A pond you lose after four
months has decayed whatever the storage says, and this era's one law is that
nothing does. So the residents moved into a near band (y ≥ 0.78) and are drawn
**in front of the whole wood** — the trees behind the house, the neighbours in
the yard, which is what both names said all along.

The checker then had to change jobs, because "is a resident buried" had become
true-by-construction — a checker that restates the code. It now measures the
opposite mistake, which is just as invisible from an editor: that eight
neighbours drawn over the top of the trees don't wall off the hundred hours
behind them. The yard covers 3 % of the card against a 22 % ceiling.

**And the render caught two more the checker could not.** With the two rows at
matching x, the lantern sat directly above the well and the beehive above the
bench; each pair read as one tall object. The rows are offset by half a slot
now. And the well, tucked into the bottom-right, lost a bite to the card's
16pt corner radius — which is nowhere in any bounds check, so
`corner_clipped()` exists and the sprite generator's contact sheet is not the
only picture worth looking at. Same lesson as the grove's diagonal stripes,
found the same way.

**Other decisions:**

- **No card, no confetti, no notification.** A resident is announced by the
  buddy's caption for the length of one break, and `residentArrived` is
  cleared when the next focus starts. It is deliberately not persisted: miss
  it and you find the pond yourself, which is a better way to find a pond.
- **No flag of its own.** `-PawmodoroBond 200` already seeds two hundred
  sessions, which is what a resident reads. A second seeding flag is a second
  thing to keep in step.
- **They are not in the journal.** A resident is not a species you met, and
  putting them there would make the homestead another set to complete.
- **Three dreams, no new art** — `Dream.Neighbour`: the fish, the tenant, the
  lamplight, drawn from the residents' own second frames as silhouettes.
  Gated on `Resident.settled` rather than on thresholds copied into `Dream`,
  so the gate cannot disagree with the thing it gates.
### As built — Y4's four time-of-day grades

**No new art, and that was the whole finding.** The plan asked for the
homestead to be exported four times, once per time of day, the way every place
is: seventy-six more imagesets, each of which would have to be kept in step
with the sprite it is graded from. But a grade in this app is three numbers —
a tint, how far to pull toward it, and a brightness multiplier — and
`FilmStock` has held all four sets of them since the Scrapbook, *because the
film stocks were built out of the scene generator's grades in the first place*.
So `FilmStock.of(_ part: DayPart)` names the stock carrying each hour's grade
and `HomesteadView` applies it with the `.filmStock()` modifier the Scrapbook
already uses. The wood is lit by exactly the arithmetic that lights Whispering
Woods, for the cost of one switch.

`day` maps to `asitwas` and that is not a shortcut: the generator's `day` grade
is `((255,255,255), 0.00, 1.00)`, the identity, because the art is drawn in
daylight.

**`check_film.py` gained a sixth rule for it**, and its first two break tests
both passed — which meant the rule was looping zero times. `DayPart` declares
its cases on one line (`case dawn, day, dusk, night`) and the parser was
written for one case per line, so it found no hours at all and reported
success. Four break tests bite now: a swapped arm, a lost identity, a deleted
arm, and the function vanishing.

**One refactor came with it.** The `.filmStock()` `View` extension lived at the
bottom of `ScrapbookView.swift`; a modifier that two unrelated screens depend
on has no business hiding under a third one's implementation, so it is
`Pawmodoro/Views/FilmStockGrade.swift` now.

**Divergences:**

- **The grade is applied inside the clip and under the caption.** Grading a
  text row would put its contrast somewhere `check_contrast.py` never looks —
  it samples the scene exports, not SwiftUI overlays. The wood is graded; the
  card it sits on and the line in its corner are not.
- **Still unbuilt in Y4:** the hundred-hour panoramic postcard.

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
| `-PawmodoroFillDreams` | Every dream marked as dreamed, for looking at the diary |
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
