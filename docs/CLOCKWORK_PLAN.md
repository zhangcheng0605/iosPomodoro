# Pawmodoro Clockwork Plan — a world that keeps its own hours

> **Status: built end to end on Linux (Aug 2026), never compiled.** All of
> AA–AI and the second small-magic wave are written, one commit per phase,
> divergences recorded in the **As built** section at the bottom. All three
> checkers pass; the wave shares its first Mac build with the Companion
> wave. Fourth plan document. The first made the app feel alive, the second
> gave it a world, the third gave the buddy a relationship — this one gives
> the world **time**: things that happen whether or not you are watching,
> and are waiting for you when you return.

## The thesis: steal the clock, leave the whip

The Companion wave mined Tamagotchi and amputated its punishment half. This
wave does the same to a whole shelf of other mega-hits, and what they all
turn out to share is a **clock the player doesn't own**:

- **Travel Frog (旅かえる)** — the pet leaves, and *you cannot control when
  it returns*. Forty million people opened an app daily because a frog
  might be home. Variable-interval reinforcement, the strongest habit
  schedule known — and the frog was never once in danger.
- **Neko Atsume** — absence as mechanic. You put food out, you *leave*, and
  the reward is forensic: reading the yard for who came while you slept.
- **Stardew Valley** — the multi-day nurture chain. One more day, because
  the parsnips.
- **Majora's Mask** — a world on a schedule. The ferry leaves at 8:00
  whether Link is there or not, and knowing that is the gameplay.
- **Pokémon Snap × Wordle** — one shot, today only, at a living world;
  scarcity that makes timing a decision.
- **Animal Crossing** — K.K. plays on Saturdays; the Perseids fall in
  August. Appointments with a world, not with a to-do list.
- **Pokémon shiny hunting** — the 1-in-300 palette variant that
  electrifies an ordinary encounter.
- **No Man's Sky** — every star carries the name of the night you earned
  it.
- **Shrine omikuji** — the daily slip of dated luck.
- **The Sims** — the voyeur loop: a small being living autonomously.

Every one of these ships here with its dark half removed: no lateness, no
missed-it-forever, no rot, no odds displayed, no scores. The world keeps
its own hours, and every hour it keeps is one more reason the app is worth
opening — never a reason to feel late.

### The retention map (the empty slots this wave claims)

The Companion wave owns app-open, session-complete, break, bedtime,
multi-week and multi-month. What it left empty, this wave fills — each
slot claimed exactly once:

| Empty slot | Feature | The hit it descends from |
|---|---|---|
| Variable-interval returns | Little Journeys (AB) | Travel Frog |
| Session-**start** reward | The Fortune Slip (AC) | shrine omikuji |
| Multi-day nurture | The Dream Garden (AD) | Stardew Valley |
| Daily real-clock hours | Clockwork Days (AE) | Majora's Mask |
| One-per-day decision | One Shot (AF) | Pokémon Snap × Wordle |
| Overnight absence | Someone Came in the Night (AG) | Neko Atsume |
| Quiet-screen retrospection | Star Stories (AH) | No Man's Sky |
| Weekly appointment | The Saturday Set (AI) | Animal Crossing's K.K. |
| Rare calendar events | Nights of Falling Stars (magic) | ACNH meteor showers |
| Per-session lottery | Once in a Coat (magic) | Pokémon shinies |
| All-day autonomy | Played From Memory (magic) | The Sims |

### Anti-goals (the standing five, plus this wave's own)

All of COMPANION_PLAN's anti-goals stand: no guilt, no economy, no new
sensors, focus is sacred, one drawer. New ones this wave earns:

- **No denominators on discovery pages.** The Timetable and the journal's
  night tier show what you've found, never "3 of 8". An unfound thing must
  not exist as a hole. (The star atlas's counted figures are the deliberate
  exception — constellations are a map, not a checklist.)
- **No displayed odds, no displayed clocks-you-don't-own.** A journey's
  return time is never shown. The pale coat's odds appear nowhere. The
  moment a hidden clock grows a countdown it becomes an obligation.
- **Derived, not stored, wherever possible.** Photos are parameter records
  re-rendered on demand. Star Stories is a join, not a table. Friendship
  (backlog) is a pure function of the log. The Stray set this pattern;
  this wave leans on it everywhere.
- **No free placement over scenery.** Clockwork events live in the lower
  scene rows at fixed anchors; the sky-rows-behind-the-countdown assertion
  in `generate_scenes.py` keeps holding. Anything that wanted to wander
  (the busker sprite, the flower trail) was cut or anchored in review.

---

## Phase AA — The wider log (prerequisite, small, urgent)

**The one real bug this planning pass found.** `SessionRecord` stores only
`{endedAt, minutes}`, and `SessionLog` trims to 1,000 records. Two
consequences, one live today, one waiting:

1. `totalSessions` is `records.count` — after the 1,000th session it stops
   being a lifetime number. Bond, place unlocks and the anniversary
   engine's "first session ever" (`records.first`) all quietly shift as the
   log trims.
2. Nothing records **where** a session happened or **who** kept you
   company — the exact two facts Little Journeys' letters, Star Stories,
   the Fortune Slip and future waves need. Every day this ships later is a
   day of history those features can never narrate.

The fix, in one sitting:

- Add optional `place: String?` and `buddy: String?` to `SessionRecord` —
  `decodeIfPresent`, default nil, fully backward compatible. `add()` gains
  the two parameters; `completePhase()` passes them.
- Add a persisted monotonic `lifetimeSessions` counter (`StorageKeys`
  entry), seeded from `records.count` on first read, incremented in
  `add()`. `totalSessions` returns it. The anniversary engine keeps a
  stored `firstSessionDate` the same way.
- Trimming behavior is otherwise unchanged — charts and streaks only ever
  look weeks back.

**Done when:** an old log decodes losslessly; new sessions carry place and
buddy; `-PawmodoroSeedStats` seeds both fields; bond and unlocks read the
lifetime counter.

---

## Phase AB — Little Journeys (the flagship — Travel Frog)

**Goal:** off-duty buddies get a life, and the app gets the strongest
comeback loop in the cozy canon: *someone might be home*.

- **Seeing off.** In the buddy picker, any owned, unselected buddy can be
  seen off on a little journey to a place you've unlocked. The ritual is
  the packing: a small furoshiki bundle appears; optionally drag the sill's
  snack onto it and it gets knotted in. (No snack packed = "traveled
  light", never a lack.) The buddy's picker row shows a tiny bindle and
  "Pip is away — the Peaks".
- **The hidden clock.** Return time = departure + 6–36 real hours, drawn
  deterministically from `hash(buddy, departure day)` and **displayed
  nowhere**. Stored: destination, departure date, packed snack. Everything
  else — including "are they back?" — is a pure function of now, resolved
  at foreground like the timers themselves.
- **The homecoming.** On the first idle open after return: a knock line in
  the caption, then the letter — a short note in the house voice, built
  from a template corpus keyed to place × season × packed snack × **your
  journal's gaps**. The alchemy: the letter reports a species your journal
  is missing at that place — *"Something with antlers watched me all
  evening. You'd know its name."* — and the return quietly arms a
  guaranteed sighting of that species in your **next focus session at that
  place**. Your idle buddies become scouts for your own incomplete journal,
  and one letter sells two more sessions.
- **The souvenirs.** One keepsake into the existing drawer with travel
  provenance ("brought back from the Onsen by Pip"), occasionally a burr
  from that place's burr table, and the packed snack decides one letter
  line via the taste tables ("ate the sardine on the ferry, no regrets").
- **Letters keep.** A Mailbox card joins the stats screen, letters archived
  forever, unread ones marked with nothing more urgent than a closed
  envelope.
- Soot travels only after she has joined. The selected buddy never
  travels — someone keeps you company; that rule is the fiction's floor.

**Guilt-proof:** a traveler is never lost, hungry, or waiting; the trip
proceeds identically whether the app opens or not; letters wait unread
forever; being "late" to a return is not a representable state.

**What this quietly does for the business:** owning more buddies finally
*does* something, without a coin ever existing.

**State:** journeys (buddy, destination, departedAt, snack), mailbox.
**New flags:** `-PawmodoroJourney <buddy.place>` (departed hours ago),
`-PawmodoroReturnNow` (all travelers knock at launch).

**Done when:** see-off, letter, drawer row, sighting bias and picker state
all forceable; a journey survives relaunch; the selected buddy can't be
sent; Soot gated on joining.

---

## Phase AC — The Fortune Slip (omikuji, at the one moment nothing rewards)

**Goal:** the day's first **started** session draws the slip. Everything in
the app rewards finishing; nothing yet rewards *beginning* — and beginning
is the hard part of focus. This is the only concept from the workshop that
claims the start moment, so it gets it.

- Starting the first focus session of a day (after the settle-in, never
  interrupting it) slides a small paper slip from the timer face: two
  lines, then it tucks itself into the capsule's corner for the rest of
  the day. No interaction needed or possible — during focus it is
  scenery.
- **The mysticism is a mirror.** Each slip contains one gentle luck grade
  (no curse tier exists in this shrine) and **one true fact derived from
  your own history**: "you do your best work before the dew dries" (your
  log's longest sessions are pre-noon); "a good day for the Harbor"
  (statistically your deepest place); "salt things, today — someone here
  agrees" (the buddy's taste table). Template ban, enforced in review: no
  gap, count, or streak is ever referenced as judgment.
- **The slip comes true.** The named place, species or hour gets a small
  real bias in that day's sighting/encounter/heard rolls — the same
  parameter shape `-PawmodoroSighting` already threads. Horoscopes retain
  people while being false; this one is occasionally, demonstrably true,
  which is a daily-open magnet with the con amputated.
- Slips file into the almanac, dated.

**Guilt-proof:** no bad-luck tier is generatable; a missed day draws
nothing and says nothing; a slip after long absence reads warmest of all
("the kettle kept your seat").

**State:** last-draw date + slip seed. **New flags:**
`-PawmodoroFortune <n>` (pin the template row).

**Done when:** first start draws, second start doesn't; the derived fact
matches seeded stats; the bias verifiably lands via the journal; light and
dark shots of the tucked slip in all themes.

---

## Phase AD — The Dream Garden (the second flagship — Stardew × the dream diary)

**Goal:** the multi-day nurture chain Stardew runs on, seeded by the one
system nothing yet feeds on: dreams. The garden grows what the dreams
dreamed.

- **Seeds fall out of dreams.** The night a dream lands in the diary, its
  seed is on the sill by morning: the yarn dream drops a yarn-flower seed,
  the stag dream drops the flower stags eat, the fish-balloon something
  stranger. A fixed `dreamID → seedID` table; ~8 plants at launch.
- **One pocket at a time.** A small planter with three pockets lives on
  the stats screen (garden card); on the main screen it appears only as a
  small pot chip beside the sill while something is growing — tap for a
  status caption. No pocket pressure: empty pockets are soil, not absence.
- **Focus is the watering can.** A pocket's growth stage = the count of
  days with at least one completed session since planting, read straight
  from the log — derived, never stored. Three to five watered days to
  bloom, stages visible. Unwatered days pause growth at the same pixel
  frame indefinitely. Nothing browns. Ever.
- **Blooms do something.** By type: stock the sill with a garden snack
  (which enters the existing taste tables — new rows for the Tastes card),
  or quietly bias one species' sighting roll while blooming ("the robin
  likes the red one"). Then the plant keeps flowering for days; harvest is
  a gift, not a chore.
- **The chain is the point:** tuck-in → guaranteed dream → seed by morning
  → one session a day waters → bloom feeds the sill or the journal. The
  bedtime ritual becomes load-bearing instead of decorative.

**Guilt-proof:** growth pauses, never reverses; a replaced unplanted seed
is "the wind took it somewhere nice"; no wilting exists in the data model.

**Art:** ~8 plants × 4 stages = 32 small prop sprites (scene-palette work,
cheap); pot chip; seed packet sprites.
**State:** three (seedID, plantedDate) pairs + seeds-on-sill.
**New flags:** `-PawmodoroSeed <id>`, `-PawmodoroBloom <id>`.

**Done when:** dream → seed → plant → stage-per-watered-day → bloom → sill
snack all forceable end to end; growth math verified against seeded logs;
the Tastes card shows garden rows.

---

## Phase AE — Clockwork Days (Majora's Mask)

**Goal:** the places keep hours, and knowing the timetable becomes
gameplay made of decisions the user already takes daily (which place, what
time).

- Six to eight events at launch, each a deterministic scene-overlay
  animation keyed to (place, real clock window), pure `f(now)` rendered by
  the same TimelineView machinery as the skies — no state, no timers:
  - the Harbor ferry casts off at 8:00 and 18:00 sharp;
  - the Keep's bell tower catches first light in the dawn hour;
  - the Onsen steam doubles after 21:00;
  - a heron fishes the Meadow stream at dawn;
  - Cloudspire's beacon blinks its pattern from full dark;
  - blossom drifts double in the Village at dusk (sakura season).
- **The Timetable** joins the almanac: an entry appears only after you've
  personally been there in the window ("the ferry — 8:00 & 18:00, learned
  Aug 12"). Witnessing writes one `{eventID: date}`. Unwitnessed rows do
  not render — no denominators.
- Events live in the lower scene rows at fixed anchors; the scenery
  assertion keeps holding. All forceable today with the existing
  `-PawmodoroClock` + `-PawmodoroPlace`.

**Guilt-proof:** everything fires eternally on schedule; there is no last
ferry; nothing depends on being seen.

**Art:** small overlay sequences (ferry slide frames, steam particles in
the house style, bell glint, heron, beacon) — props, not poses.
**State:** witnessed set. **New flags:** none needed beyond the existing
clock and place flags.

**Done when:** every event walkable via `-PawmodoroClock`; Timetable fills
per event; scene assertions and contrast still pass.

---

## Phase AF — One Shot (Pokémon Snap × Wordle)

**Goal:** one photograph per day of whatever is true right now — and the
develop-overnight beat guarantees tomorrow's first open has a parcel.

- A small bellows camera sits at the scene's edge while idle or on a break
  (never during focus). Tap: shutter, click, done — one per day.
- **Photos are parameter records** (~200 bytes): {date, place, dayPart,
  season, buddy + frame, sighting?, moon, theme}. The image re-renders
  from those params through the same composable views — derived, not
  stored, exactly the postcard pipeline's philosophy. The capture
  quantizes to the nearest keyframe so a mid-animation frame can't be
  stored.
- **It develops overnight.** The album row for day D renders only after
  midnight — tomorrow's first open has the photo waiting, captioned in the
  house voice ("dusk at the Harbor. The ferry was leaving. Pip pretended
  not to pose").
- A Photos shelf beside the postcards album. Not shareable by design —
  Wordle's scarcity kept, its performance anxiety amputated.
- The skill curve is the interlock: the timetable, sighting windows and
  moon knowledge you've built are what make a *good* shot possible.

**Guilt-proof:** an unspent shot vanishes without record; the shelf shows
photos taken, never blanks for days skipped; no film count, no grades.

**Art:** one camera prop. **State:** parameter records.
**New flags:** `-PawmodoroPhoto` (grant today's shot regardless),
`-PawmodoroDevelop` (render today's instantly).

**Done when:** shot → overnight gate → render-from-params proven across
theme changes (the photo keeps its original theme); one-per-day enforced;
Reduce Motion drops the flash and keeps the click.

---

## Phase AG — Someone Came in the Night (Neko Atsume)

**Goal:** the sill's one soft edge — an uneaten snack — becomes its best
feature. Absence as mechanic, the Atsume way.

- A snack still on the sill at the day's last close is an invitation, not
  a waste. The morning sweep already removes it; now it leaves **evidence**:
  paw prints in the dew, a stray feather, the sardine nibbled at one
  corner, and a journal line — *"someone came in the night. You were
  asleep, which was the point."*
- The visitor is a deterministic roll from (date, snack, season, place,
  moon) against the taste tables — sardines tempt the harbor cat, seeds
  tempt the robin. A handful of the 41 species become **knowable by
  night**: an evidence tier in the journal below "seen", filled only this
  way. On rare seeds the visitor leaves a memento straight into the drawer
  ("a smooth pebble, left where the sardine was").
- This inverts the feeding loop's economics: *not* feeding the buddy now
  has a positive meaning too. Blanket on the buddy, sardine on the sill,
  goodnight — the bedtime tableau completes itself.

**Guilt-proof:** an uneaten snack can never read as neglect because the
system makes it generous; the roll keys to the close date, never your
bedtime; evidence species are a gift of absence.

**Art:** paw-print/feather overlays + nibbled variants of existing snack
sprites (palette transforms in the generator).
**State:** last-close sill snack + date. **New flags:**
`-PawmodoroNightCaller <species>`.

**Done when:** leave-snack → morning evidence → journal tier all
forceable; the drawer memento lands; the sweep and the visit can't both
claim the same snack.

---

## Phase AH — Star Stories (No Man's Sky)

**Goal:** every star in the atlas already *is* a night session — let each
one tell its night back. A memory palace the user built without knowing.

- Tap a star: a small card composes the night live — a pure join across
  the (newly widened) log, the dream diary, the heard log, the journal and
  the computed moon: *"A Tuesday in March. The Onsen, past eleven. Luna
  was with you; she dreamed of yarn after. You heard the owl."*
- Zero new state — the card is a query. Stars from before Phase AA render
  a sparser, still-warm card ("a night session, before the notes got
  good"). Stars older than a year get the warmer verb tense.
- The anniversary engine gains a new subject: star deep-links ("one year
  ago tonight: this one").

**Guilt-proof:** pure retrospection; gaps between stars are un-remarked
dark sky, which real skies have.

**Art:** none. **State:** none. **New flags:** the existing
`-PawmodoroNightSessions` seeds everything this needs.

**Done when:** cards compose correctly for seeded rich and sparse nights;
tap targets work inside the existing atlas layout.

---

## Phase AI — The Saturday Set (Animal Crossing's K.K., the gramophone version)

**Goal:** a weekly appointment with the 50-track catalog, no new performer
art (review killed the badger: twelve drawings and a placement problem for
one cameo).

- On the first break or idle moment each weekend, a tiny gramophone
  appears beside the buddy with a request: that week's track, deterministic
  from the ISO week number, biased toward tracks you've never played — the
  setlist quietly walks the whole catalog in about a year.
- Play it and the buddy sways (existing break frames + note particles);
  the track gets a paw-stamp in the music list forever: *"requested by
  Mochi, first Saturday of spring."* A Setlist page collects the stamps.
- Skip the weekend and the gramophone waits for your next break. The
  Saturday-only gate is the amputated punishment; the cadence survives.

**Guilt-proof:** no missed show is possible; requests never expire; the
setlist has gaps only in the sense that a concert hasn't happened yet.

**Art:** gramophone prop + note particles. **State:** stamped track ids.
**New flags:** `-PawmodoroSet <trackID>`.

---

## Small magic II (anytime, between phases)

- **Once in a Coat** (Pokémon shinies). Inside `rollSighting()`, a second
  deterministic roll — roughly 1-in-300, displayed nowhere — flags the
  sighting pale: a moon-white fox, a charcoal robin, rendered from a
  palette-transform sprite set the wildlife generator emits in one extra
  pass over all 41 species. The journal sketch gains a tiny star, forever.
  A **named regular** in the pale coat gets its own line. No counter, no
  set, no odds — the only way to hunt is to keep doing sessions.
  `-PawmodoroPale` forces it.
- **Nights of Falling Stars** (ACNH meteor showers). Two or three real
  windows a year (Perseids, Geminids — a `ShowerCalendar` in the
  `Season.swift` pattern). During a window, night skies shed slow pixel
  meteors on breaks and idle; any night session finished under a shower
  mints a **comet-tailed star** in the atlas, permanently different. The
  fortune slip foreshadows it a day ahead ("the sky has plans tomorrow").
  Missing a shower marks nothing; the next window simply arrives.
  `-PawmodoroShower` forces one.
- **Played From Memory** (The Sims, with a real past). Idle micro-vignettes
  all day from a deterministic scheduler — mostly generic (washes face,
  chases tail, from existing frames + flips), but the weighted-rare entries
  are generated **from the buddy's own history**: it bats at the spot
  yesterday's sea glass lay, practices its wobbliest trick when it thinks
  you aren't looking, watches the window on the anniversary of its first
  sighting. No vignette log exists, deliberately — absence subtracts
  nothing. `-PawmodoroVignette <id>` forces one.

---

## Backlog (held with intent, each with its review verdict)

- **The Season's Letter** (Stardew's Grandpa, judged with love only) — the
  five-times-a-year recounting letter + season postcard. The capstone that
  makes every other system pay twice. Ships whenever writing time exists;
  it is prose, not code.
- **Fast Friends** (Tamagotchi Connection) — buddies who've shared your
  weeks become friends, derived entirely from the widened log; nap piles,
  shared journeys, "Miso pushed the sardine toward Mochi; a first." Ships
  as Little Journeys' duet layer once AA has accrued data.
- **Something in the Egg** (Chao Gardens) — the second flagship-in-waiting:
  an egg warmed by finished sessions, hatching a wisp whose palette, sleep
  schedule and loyalties are a pure function of the sessions that incubated
  it. Held because it competes with the Dream Garden for the nurture slot;
  its incubation month deserves its own wave.
- **The Ema Branch** (shrine plaques) — the app's only free text besides
  names: write a line on a new-moon plaque, hang it facing away, and the
  app never asks how it went. Ships with the shrine corner when fortunes
  earn a physical home.
- **The Little Tree** (bonsai) — a years-long tree that grows by lifetime
  sessions and cannot be hurried. Needs AA's lifetime counter; a v2
  candidate alongside the drawer's growth.
- **Curiosities** (BOTW Koroks) — hidden micro-secrets with the
  no-denominator rule. Still charming, still last: texture, not retention.
- **Your Song** — buddy-composed melodies died in review (verification is
  by ear, which the repo's own walk table calls unverifiable).

## Rejected on principle (recorded so nobody rebuilds them)

- **The badger busker** — twelve sprite drawings and a free-placement
  problem for one cameo; the gramophone delivers the appointment at a
  fiftieth of the cost.
- **Petal trails and scattered blooms** (Pikmin Bloom) — free art placement
  over scenery, the exact trap `check_stray.py` exists for.
- **Window-box pockets with harvest counts** — superseded by the Dream
  Garden; growth is cumulative and pause-only, never pockets-as-chores.
- **Fortunes at the first-open or bell slots** — both slots are owned;
  slot-squatting was scored and lost. Session-start was empty; it wins.
- **Any displayed return-clock, odds, or completion denominator** — a
  hidden clock with a countdown is just an obligation with better art.

---

## Cross-cutting engineering notes

Everything from COMPANION_PLAN's notes stands (determinism, StorageKeys,
Reduce Motion as the default path, flags with Release stand-ins, checkers
every session). New to this wave:

**The bias parameter.** The Fortune Slip, Dream Garden blooms and journey
returns all nudge `rollSighting()`/`rollEncounter()`. Implement one shared
`SightingBias` input (species + weight + place scope) threaded like the
existing forced-flag path — three features, one seam, no special cases.

**Re-render fidelity.** One Shot's photos and Star Stories' cards are
derived from stored parameters; both must render stably as the app
evolves. Rule: parameter records carry raw values (ids, dates), renderers
fall back gracefully when an id no longer resolves — same lenient-decode
philosophy as settings.

**The real calendar.** Clockwork windows, shower dates and Saturday all
come from pure date functions in the `Season.swift` pattern — nothing
polls, nothing schedules; TimelineView and foreground passes read the
clock they already read.

## Suggested build order

| Session | Scope | Riskiest bit |
|---|---|---|
| 1 | AA (log widening) + AG (night caller) | lenient decode of old logs |
| 2 | AB Little Journeys (model + letters) | return resolution across relaunches |
| 3 | AB (picker UI, mailbox, drawer rows) | see-off gesture in the picker |
| 4 | AC Fortune Slip + the shared bias seam | template bans holding in review |
| 5 | AD Dream Garden (model + sprites) | 32 plant sprites reading at 14px |
| 6 | AD (planter UI + chain wiring) | growth math against seeded logs |
| 7 | AE Clockwork Days | scene-row anchors across 8 places |
| 8 | AF One Shot + AH Star Stories | render-from-params stability |
| 9 | AI Saturday Set + small magic II | meteor pass inside the star budget |

Each session ends the standard way: checkers green, flag table updated,
As built notes, commit.

---

## As built (one Linux session, Aug 2026 — not yet compiled)

Where the code diverged from the plan above. Everything else shipped as
written, in nine commits (AA, AG, AC, AB, AD, AE, AF+AH, AI, magic).

**AA.** As specced, plus a subtlety: any debug flag that replaces the
session records also clears the lifetime counter and first-session anchor,
so seeding reseeds both — otherwise an earlier run's larger seed kept the
bond pinned high. The anniversary engine now reads the stored anchor.
Bundled cleanup: `DreamBubble` and `MemoryBubble` carried identical bubble
shells; both now ride one `ThoughtBubbleShell`.

**AG.** The sill evidence is carried by the caption, the journal tier and
the drawer memento — the planned paw-print/nibbled-sprite overlays were
cut as a second art pass the moment didn't need. A memento's drawer row
says "with a visitor", which fell out of the finder-fallback for free.

**AB.** The packing gesture became policy: the first traveler of the day
packs the sill snack automatically (the letter notes it); a drag-onto-
furoshiki ritual can upgrade it later. The tiny map dot was cut. The
Travel Frog photo variant stays future work — letters, souvenirs and the
armed sighting carry the homecoming.

**AC.** The slip's disposal ritual (tuck vs. tie) was cut with the shrine
corner; the slip self-tucks into the phase chip and files into the shelf.
Drawn facts are limited to five sources at launch; the template ban held.

**AD.** Three plants, not eight: the callflower carries any dreamed
species as payload, which is most of the variety the eight would have
bought. Blooms persist until picked; picking pays out (berries to the
sill, a keepsake otherwise). The pot-chip on the main screen is display
only.

**AE.** Six events. The heron borrows the wildlife art outright. The
`-PawmodoroClock` flag now also exposes its pinned hour
(`forcedClockHour`), widening each window to the whole hour for the walk.

**AF.** Photos render in the *current* theme — the scenes are exported
art and theme-independent, so only the card chrome shifts; the plan's
stored-theme fidelity wasn't worth a parallel palette path. The develop
flag re-dates the shot to yesterday, which is what developed *means* here.

**AH.** Stars open per constellation row (a sheet of that figure's
nights) rather than per-star canvas hit-testing — same memory palace,
honest tap targets, VoiceOver included. Comet-tailed atlas stars became a
line in the star's story instead of per-star tail rendering; the meteors
themselves are the visible spectacle.

**AI.** The gramophone is an SF-symbol chip, not a sprite; the stamp
happens at granting (the track is cued for the next run, and stamping on
actual playback would have meant a playback callback for one sentence).

**Magic.** The pale transform keeps ink and outline in slate so
silhouettes survive night scenes — verified on a contact sheet against a
dark backdrop. Idle vignettes are driven by a slot-hashed task loop
(content pure, timing by sleep), roughly every twenty minutes of idle.

**Unwalked, stated plainly.** Nothing here has met a compiler. The rows
that most want real eyes: the see-off menu inside the Settings form, the
clockwork anchors over all eight scenes, the photo card's scaledToFill
crop, the meteor pass sharing the night sky with the starfield, and the
stroke recognizer's thresholds are unchanged from the companion wave's
still-unverified numbers.
