# Pawmodoro Hearth Plan — ownership, and the price of things

*The fifth plan document. CONTENT_PLAN built the world, DELIGHT_PLAN made it
feel alive, SOUND_ALMANAC gave it a voice, DEEP_TIME_PLAN gave it time. This
one is about **ownership** — making the buddy feel like *yours*, the home feel
like *yours*, the memories feel like *yours* — and, for the first time in any
of these documents, about revenue on purpose. It is written to be handed to
another builder cold: every decision is made here, and where this plan
overrides an older law, it says so out loud rather than leaving the
contradiction to be discovered mid-build.*

## The owner's brief, verbatim intent

- **A currency**, earned by using the app — "the more you use my app or
  something"
- The currency **unlocks avatars and sceneries**; or the user "just pays the
  Plus money and unlocks all" — the stated goal is that **Plus gets more
  tempting**
- **Clothes and accessories** for the buddies — "necklace or something. Even
  more things to monetize"
- **Dens** — per-species houses: "Penguin is Igloo, dog is doghouse. Another
  thing to buy with currency or monetize"
- **More animation and more interaction** than tapping — "interact with the
  pet like it is their own", with the builder asked to invent the catalogue
- **A photo memory feature** — photograph where you did the pomodoro, "a
  sentimental memory place", with "filters and stickers or something"
- **macOS** — "i wanna use it from my Macbook"

The penguin already exists (a free buddy since the second cast), so the igloo
example lands directly.

## What this era overrides, and what it will not

DEEP_TIME_PLAN's anti-goals said, in as many words: *"This app will not grow
meters, dailies, or anything that can be behind"* — the gamification answer
was monuments, not meters. **The owner has overridden half of that sentence.**
A currency is a meter, and this era builds one. That is an owner's decision
about the owner's app, and this plan does not relitigate it.

What it does instead is fix the terms. The override extends exactly as far as
the brief does and no further — because the rest of the old laws are not
obstacles to the money, they are what makes the money work. An app whose
players trust it converts better than one running dark patterns, refunds
fewer purchases, and keeps its App Store rating. The fences below are not
reluctance. They are the design.

### The eight fences (binding, same force as every earlier anti-goal)

1. **Acorns are never sold for money.** The only cash products remain Plus
   and the tips. The moment a consumable currency pack exists, this becomes
   a gambling-adjacent economy with restore-purchase problems and a
   different App Review conversation. The bridge between money and the
   catalogue is Plus, whole, once.
2. **Nothing expires, nothing is limited-time, and no price ever rises.**
   Earned acorns keep forever. An item's price is a compatibility contract
   with a stored fixture, like the grove's layout: it may fall, it may
   never climb. No sales, no countdowns, no "last chance".
3. **No randomness anywhere in the economy.** Every trade is exactly the
   thing on the label. No gacha, no loot, no mystery eggs — which also
   means no odds-disclosure obligations with App Review.
4. **Earning is passive and unmissable.** Acorns accrue from focus already
   done, automatically. There is no daily pickup, no login bonus, no streak
   multiplier, nothing lying on the ground that despawns. Absence never
   costs anything — that is the *nothing decays* law wearing its economy
   clothes, and it is not overridden.
5. **The padlock rule holds everywhere.** Everything ownable is visible
   where it will live, padlocked, with its acorn price shown plainly.
   Nothing is hidden to be revealed, and nothing pretends to be rarer than
   it is. (Soot remains the one exception, for the story reason CLAUDE.md
   records.)
6. **Memories and relationships are never for sale.** No acorn price on
   capturing a snapshot, on the bond, on a dream, on a journal page, on a
   keepsake. The Scrapbook's camera is free forever; only its optional
   dress-up (film stocks, sticker packs) joins the catalogue. The sentence
   to keep: *the memory is never the product.*
7. **No notification ever mentions the economy.** Not the pouch, not a
   price, not the cart, not an unlock. This extends the
   no-calendar-window-notification law verbatim.
8. **The timer screen carries no balance.** The pouch is visible where
   trading happens and in the stats sheet, never badged, never pulsing,
   never between the user and the countdown. Focus stays sacred.

### And the laws that hold untouched

Nothing decays — so no hunger, no dirtiness, no sad neglected pet, ever,
including in the new interaction layer (a Tamagotchi guilt loop is the single
fastest way to ruin everything this app is). One opinion about "today"
(`WorldCalendar`). Colours through `Theme`. Every asset generated. Captions
through `settings.displayName(for:)`. Audio pre-mixed and single-node. Every
feature lands with dreams. The Sunday Post stays the aggregation surface and
keeps its voice fences. Animation through `TimelineView`. Countdown from an
absolute end `Date`.

## The effort ledger, stated up front

The animals ledger of the last era was species. This era's ledger is
**pose-multiplied art**: an accessory is not one sprite, it is one sprite per
buddy per pose per frame, and twelve buddies wear it. The only way this era
is buildable is that every buddy is already drawn procedurally by shared
builders with known geometry — so accessories are *derived* by the generator
from per-buddy anchor points, never hand-fitted. Where that fails for a
given buddy/pose, the accessory hides for that pose rather than shipping
misaligned (`BuddyFrames`' nil-fallback convention, extended to overlays).

Rough count, stated so nobody discovers it at commit forty: ~10 accessories
× 12 buddies × the pose set ≈ **500+ derived composites**, 12 dens, 2 new
catalogue buddies' full pose sets, a magpie, 3 treats, ~6 keepsakes, the
interaction frame strips, and the Scrapbook's LUTs. All generated; the
generators and their checkers are half this era's real work.

---

## Phase 1 — The Pouch (acorns)

The wood already drops them; now somebody picks them up.

**The currency is called acorns, and the balance is derived, not stored.**
One formula, written once:

```
earned  = lifetime completed focus minutes / 20
balance = max(0, earned − Σ price(everything owned))
```

- Derived from the session log the way the grove and the bond already are, so
  there is **no second counter to keep in step**: `-PawmodoroBond 200` seeds
  acorns automatically, drift laps bank sessions and therefore acorns
  automatically, and the whole thing backfills from history the day it ships
  — a two-year user opens the update and finds a full pouch, which is this
  app's way of saying thank you. The Year Ring shipped already old; the
  pouch does too.
- Minutes, not sessions, so the 5-minute-session farm does not exist
  (`focusMinutes` clamps 5–90; a 25-minute session ≈ 1.25 acorns; a steady
  couple-of-hours-a-day user earns ~5–6 a day). Only *completed* focus
  counts, which the log already enforces.
- **The divisor is a compatibility contract.** Moving it from 20 re-prices
  everybody's history. `check_catalog.py` (Phase 2) carries it in a stored
  fixture next to the prices.
- Only purchases are stored (a set of owned item ids in `StorageKeys`).
  "Clear history" therefore zeroes the *earned* side while owned items
  survive — the balance floors at zero and nothing bought is ever lost.
  Purchases are never destroyed by any path except deleting the app.

**Where it shows.** A quiet line on the stats sheet ("the pouch: 214
acorns"), the price rows in the cart, and one unbadged mention nowhere else.
The Sunday Post may say "The wood dropped a few acorns this week." — computed
from the week's minutes, no new Chronicle kind. The celebration card does
not count coins; fence 8.

**Dreams: none, and deliberately.** The one knowing exception to the
dream convention in five plan documents: the buddy does not dream about
money. The magpie in Phase 2 carries the era's dream pair instead. Write
this exception into the As-built so it reads as a decision, not a miss.

**Flags:** `-PawmodoroAcorns <n>` (override the derived earned total),
`-PawmodoroOwnEverything` (own the full catalogue without Plus, to drive the
owned states). Release stand-ins per the `LaunchOptions` rule.

## Phase 2 — The Magpie's Cart (the one commercial room)

The app keeps exactly one room where things are for sale, and a magpie runs
it — the one animal that famously values shiny things. She is a neighbour,
not a sighting: never in the journal, no species row, two sprites (perched
on the cart; head tilted, appraising). Everywhere else in the app stays
world: a padlocked buddy in the picker, a padlocked den in the homestead, a
padlocked film stock in the Scrapbook — each opens **the unlock sheet**, and
the cart is where you browse.

**The unlock sheet is the era's most important screen.** One design, reused
for every ownable thing:

- the thing itself, drawn large, in its place;
- its acorn price, plainly ("36 acorns");
- the distance, in the world's voice, if short ("about a week of afternoons
  away") — never as an instruction, never as a percentage bar;
- **Trade** if affordable;
- and beneath a rule line, always: *"Or everything, at once — Plus."*

That last line is the owner's thesis made into UI. Every single padlock in
the app becomes a Plus advertisement with an honest free alternative
attached, which is precisely why the free alternative must stay honest.

**What the catalogue holds, and what it never will.**

| For acorns (or all at once with Plus) | Never for sale at any price |
|---|---|
| The 8 Plus buddies, individually | The 4 free buddies, Soot, the bond |
| The 4 Plus places, individually | The 4 journey places — those are *reached*, and arriving is the fiction |
| Plus themes, individually | Dreams, journal pages, keepsakes, snapshots |
| Accessories (Phase 3) | The stray's arc, the grove, the residents |
| Dens (Phase 4) | Anything the app has already given |
| Scrapbook film stocks & sticker packs (Phase 6) | The Scrapbook camera itself |
| **Two new buddies** (below) | |

**Two new catalogue buddies.** The cart needs stock that is *new*, not just
re-routed, and the roster gains two acorn-priced buddies (Plus gets them too,
of course — Plus is everything). Suggested and sprite-arguable: a **duck**
(pond exists; the homestead's pond gains a purpose) and a **turtle-dove or
crow**… final call to the sprites, but pick animals whose dens (Phase 4)
draw well. Full pose sets each — the era's biggest single art items.

**Plus is repositioned, not changed.** Same product ID, same non-consumable,
and it now means: *everything in the cart, instantly, forever — including
whatever the cart gains later.* Existing owners are grandfathered into the
entire catalogue the moment this ships, with no action needed; anything else
is theft from the people who already paid. `docs/MONETIZATION.md` gets a
section; App Store copy gets a line.

**Pricing.** Tuned to the earn rate (~5/day steady use): an accessory
8–20, a den 30–40, a buddy 90–140, a place 120–160, a film stock 15. Full
catalogue lands somewhere north of 1,500 acorns — most of a year of steady
use, or one purchase. Single items are weeks, so patience is genuinely
viable and visibly so. **Prices live in one Swift table**; `check_catalog.py`
parses the real values (never restates them), verifies every item has art,
a padlock surface and an unlock route, and carries the stored
prices-never-rise fixture plus the earn-divisor fixture from Phase 1.

**Chronicle.** New kind `.trade`, written on every acorn purchase — and
**silent in the Sunday Post**, with the reason in `silentKinds`: the letter
is not a receipt, and the one surface addressed *to* the reader will not
double as a storefront. (`check_post.py` forces this decision to be written
down either way; this plan pre-makes it.)

**Dreams (the era's pair for Phases 1+2):** `Dream.magpie` — two entries,
e.g. *"the magpie, counting"* / "Counting, and losing count, and starting
again." and *"something shiny"* / "Exactly the right pebble. She knew it
at once." Costs the magpie's existing sprites as silhouettes.

**Flags:** `-PawmodoroCart` (open the cart on launch). The Phase 1 flags
cover the rest.

### As built — Phases 1 and 2, the Pouch and the Cart

Built on Linux, never compiled. `tools/check_catalog.py` is new and all six of
its fence rules were verified by deliberately breaking them.

**The balance is derived and there is no counter anywhere**, exactly as
planned: `Acorns.earned = totalMinutes / 20`, `balance = earned − Σ price(owned)`.
The only thing stored is a `Set<String>` of catalogue ids. Consequences that
fell out for free: `-PawmodoroBond 200` fills the pouch without knowing the
economy exists, drift laps bank acorns because they bank sessions, and the
whole thing backfills the day it ships.

**The numbers, measured rather than guessed.** At the shipping divisor and a
steady two hours a day: the dearest single item is 25 days away and the whole
catalogue is 300 days (1,800 acorns). `check_catalog.py` asserts both ends —
no single thing past a season (or the free road is decoration on the paywall)
and the whole hoard at least half a year (or Plus has no argument). Those two
constants are the era's commercial thesis expressed as arithmetic.

**Divergences from the plan:**

- **No two new catalogue buddies yet.** The plan wanted stock that is new
  rather than re-routed; a full pose set each is the era's biggest art item
  and it did not fit this commit. The cart currently stocks the eight Plus
  buddies, four Plus places and six Plus themes — eighteen items. Adding the
  new pair later needs no cart changes at all, because `CatalogItem.all` is
  computed from `Buddy.allCases` rather than listed.
- **`Pouch.take(_:)` does no arithmetic.** The plan had the pouch checking
  affordability. It cannot honestly: the balance needs the session log, which
  lives on the engine, and `-PawmodoroAcorns` overrides it. So
  `TimerEngine.trade(_:)` is the one place that decides, mirroring
  `StoreManager.isUnlocked(_:)` being the one place that decides entitlement.
- **The Sunday Post got an acorn line after all**, computed from the week's
  own minutes rather than from any `.trade` — those stay silent as planned.
  It is phrased as weather ("The wood dropped acorns all week. I have not
  counted them.") and never says a balance or what they might buy.
- **The dreams are the magpie's, and the acorns get none.** This is the one
  knowing exception to the dream convention in five plan documents and it is
  recorded here as a decision: a buddy that dreams about a balance has been
  given a job. Gated on having sat at all rather than on having traded, so
  the app never rewards the spending.

**One thing worth knowing before the Mac build:** `onLockedTap` changed shape
from `() -> Void` to `(CatalogItem?) -> Void` across all four pickers. Nil
means "Plus gates this but the cart does not sell it" — currently only
ambience — and still routes to the paywall exactly as before. That is the
seam where a compile error is most likely.

## Phase 3 — The Wardrobe (closes DELIGHT_PLAN's E2)

The accessories the owner asked for, and the oldest open phase in any plan
document, paid off at last. E2's As-built should point here.

**Three slots** — head, neck, back — one accessory each, chosen per buddy in
the buddy picker's new wardrobe row. Ten to ship (names in the app's voice,
final under the sprites-argue rule): the red bandana, a bell collar, the
knitted scarf, a flower crown, round spectacles, the sailor's kerchief, a
tiny bow, the rain cape, a sun hat, the ribbon nobody explains.

**Architecture: derived, never hand-fitted.** `generate_accessories.py`
reads each buddy's anchor geometry (head centre, neck line, back line, per
pose — derivable because every buddy is drawn by the shared builders) and
composites the accessory strip per pose per frame. Where an anchor does not
exist for a pose (the curled sleeping pose has no visible neck), the
accessory hides for that pose — `BuddyFrames`' nil-fallback, extended.
Rendering layers accessory *between* body and any held prop; sleeping
buddies keep the necklace, lose the hat (hats come off for bed; write it in
the generator comment, it will read as a bug otherwise).

**`check_accessories.py`, before believing anything:** composites every
accessory × buddy × pose × frame; asserts the overlay lands within the
anchor's tolerance box, clears 2:1 against the body it sits on in every
theme and appearance, differs between frames where the pose animates, and
hides where it must. NEXT_UPDATE.md predicted exactly this checker; the
grove/residents lessons apply — **render the contact sheet and look at it**,
because a bell collar that reads on the cat can still float on the penguin.

**Voice.** The buddy reacts once, on first wearing, through the caption —
"Mochi wears it like it was always hers" — via `displayName(for:)`, then
never mentions it again. No stats, no set bonuses, nothing an accessory
*does*. It is clothes.

**Dreams:** `Dream.finery`, two entries — the collar and the crown, drawn
from the accessory sprites as silhouettes ("Wearing it, in the dream, to
nowhere in particular.").

**Flags:** `-PawmodoroAccessory <slot>.<id>` (dress the current buddy on
launch), `-PawmodoroOwnEverything` covers ownership.

### As built — Phase 3, the Wardrobe

Built on Linux, never compiled. Ten pieces, and DELIGHT_PLAN's E2 — the oldest
open phase in any of these documents — is closed.

**The plan's architecture was wrong and the replacement is better.** It assumed
the buddies came out of shared builders with known geometry the way the
wildlife does; they do not, every one is hand-drawn with its own coordinates.
But the *pixels* know where the head is, so `generate_accessories.py` measures
each rendered frame — crown, collar line, head width — and emits
`BuddyAnchors.swift`. A buddy redrawn tomorrow gets correct anchors from the
next run, with nobody remembering to update anything.

**And it is an overlay, not a composite.** The plan's 500+ derived composites
would have been tens of megabytes of PNG and a full regeneration every time an
ear moved. There are **ten** sprites and a table of 118 attachment rows; the
app draws the piece over the buddy at runtime, scaled to that buddy's own head.

**Two slots, not three.** A back slot was planned and dropped: at forty logical
pixels anything drawn behind the buddy is four or five visible pixels poking
out at the sides, which reads as a rendering fault rather than a cape.

**What the measuring got wrong twice, and what fixed it.**

- Measuring a row's full min-to-max span reads straight **across the gap
  between two ears**. The cat's crown came out at row 1 instead of row 6 and
  every hat balanced on thin air. Contiguous runs, not extents.
- Scaling a collar to the run at the collar line scales it to the
  **shoulders**. The first contact sheet was twelve animals in striped
  blankets. `neckWidth` is capped at the head's width — a neck is never wider
  than the head above it.
- Deriving the collar row from the head's *width* overshot on the wide-eared
  buddies and put the dog's collar two rows off the bottom of the canvas. It
  comes from the figure's own height now.

**`check_accessories.py` found the one nobody would have.** Every head piece
clipped off the top of the canvas on `happy_1` — the bounce frame, which
shifts the whole buddy up two rows. Solving it by shrinking would have taken
the knitted cap to 0.43 of a head, which is a dot; instead `BuddySprite` pads
its clip upward by 30 %, and the checker mirrors the asymmetry: overhang above
is allowed, overhang below is allowed and clipped, the sides are not.

Two of its own rules were wrong first and are worth recording, because both
were the checker being stricter than the app rather than the app being wrong:
testing a *scarf's* lower edge for overlap reported 417 floating scarves (a
scarf hangs — it is the top edge that attaches), and testing contrast at the
contact row compares the piece against the buddy's own one-pixel dark outline,
which is exactly where a brim lands. 1180 placements pass now.

**`check_swift.py` grew a real fix here too.** `Accessory` came back owning
`.head` and `.neck` — the cases of the `Slot` enum nested inside it — because
the body regex stopped at the first closing brace, and four confident wrong
non-exhaustive switches were reported. Anchoring the closing brace to the
opening indent fixed that and broke the other direction: `finditer` will not
return overlapping matches, so `Species.Rarity` silently stopped being checked
at all. It walks lines now and sees both.

**Divergences:**

- **No spectacles.** They belong on the face, which is a third anchor nobody
  can measure — the eyes are drawn per buddy by a shared helper, not by a
  shape the pixels can find.
- **The first-worn remark lives in the pouch.** It has to survive a relaunch
  (a hat you put on last week is not news), so it is stored beside the
  purchases under a prefix no `CatalogItem.id` uses. `spent` ignores it
  because unknown ids contribute nothing.
- **Accessories are 15 acorns — the cheapest thing in the cart on purpose.**
  Two afternoons. The wardrobe is where somebody finds out the free road
  actually goes somewhere, and a first purchase three weeks away teaches the
  opposite lesson.

## Phase 4 — The Dens

Every buddy gets a house, in species character, and the houses live in the
**homestead** — Y4 built the stage for exactly this, whether it knew or not.

| Buddy | Den (sprites argue, this table doesn't) |
|---|---|
| cat | a basket by a sunny window |
| dog | the doghouse, name over the door |
| penguin | **the igloo** |
| bunny | a burrow with a round green door |
| hamster | a cottage with too many entrances |
| fox | a hollow log |
| capybara | a flat warm stone |
| red panda | a high branch platform |
| owl | an oak hollow |
| otter | a holt under the bank |
| hedgehog | a leaf pile that is clearly on purpose |
| Soot | a chimney corner (never for sale — she is not for sale either; hers arrives free with her, the story's epilogue) |

**Placement.** The active buddy's den is hand-placed in the homestead card,
near band, drawn with the residents — which means every hard-won lesson
transfers instead of being relearned: feet-anchored, `check_residents.py`
extended to include the den in the overlap, near-band, corner-radius and
footprint rules. One den visible at a time (the current buddy's); owned dens
show in the buddy picker beside their owners.

**What a den does** — presence, not mechanics: the buddy sleeps in it in the
homestead card during world-night (world clock, so `-PawmodoroClock` moves
it); the owl in hers by *day*, because Luna works nights; on a snow-weather
day the den wears a snow cap (palette transform, not a redraw). During
breaks, the break pose may sit beside it. Nothing to maintain, nothing to
upgrade, nothing it produces. It is a home, and it is bought once.

**Chronicle & Post.** Kind `.settledIn`, written the first night actually
slept in a new den, one Post line: *"She has slept in the new den. The
basket forgives her."* The `.trade` that bought it stays silent per Phase 2.

**Dreams:** `Dream.den`, two entries — the inside ("Bigger inside than it
is, and warm.") and the doorway ("Standing in the door of it, deciding the
weather isn't worth it.").

**Flags:** `-PawmodoroDen <id>`.

### As built — Phase 4, the Dens

Built on Linux, never compiled. Twelve houses, two frames each, standing in the
homestead. The penguin's igloo — the example the whole feature was asked for by
— lands exactly as specified.

**No new placement system and no new checker, on purpose.** Y4's residents had
already paid for everything a den needs: hand-placed art in the near band,
feet-anchored, drawn in front of the wood, and a checker that measures overlap,
the band, the card's rounded corners and the footprint ceiling. So a den goes
through `check_residents.py` as if it were a ninth resident, and every lesson
that surface cost transfers instead of being relearned. That was the argument
for putting dens in the homestead rather than giving them a screen.

**One den on screen at a time** — the current buddy's — so all twelve share a
single spot in the yard rather than each needing one. The checker holds that
spot against all eight neighbours for every den size, which is what caught the
two-point clearance from the birdhouse being real rather than lucky.

**The second frame is always the same idea: somebody is in.** A light on, a
tail showing, a muzzle resting in the door. Chosen by the world's clock rather
than animated — a house blinking between occupied and empty twice a second
would be a haunting — and inverted for a nocturnal buddy, because Luna works
nights and a dark empty hollow at midnight is exactly backwards.

**Divergences:**

- **`.settledIn` is recorded by the engine, not the view.** The first night
  actually slept in a new den is an episode, and episodes are written where
  the hour, the buddy and the pouch are all known at once. A view never writes
  to the log.
- **Soot's chimney corner arrives with her and has no price.** `Den.isForSale`
  says so and `check_catalog.py` refuses to let that change — the same fence
  that stops `Buddy.catalogItem` selling her.
- **`Dream.Home`, not `Dream.Den`.** `check_swift.py` refuses two enums with
  the same simple name outright, and it is right to: the day `Grove.Stage`
  collided with `Stray.Stage` it reported three confident wrong failures.
- **The branch was a garden table.** Drawn as a platform on three props, the
  red panda's den came out as a table with two bushes on it. It is a limb
  rising into leaves now. The basket, meanwhile, had a *green* cat curled in
  it — the homestead palette's shade tone is foliage, not fur.

## Phase 5 — A creature of one's own (the interaction era)

The brief: *"interact with the pet like it is their own."* The design
insight this phase is built on: **ownership is not more buttons — it is the
feeling that the creature knows you, and has a life when you're not
looking.** Three tiers, shippable independently, each with the same fences.

**The fences first, because this is where a pet app goes wrong:** nothing
decays — the buddy is never hungry, dirty, sad, or waiting-with-a-meter; no
interaction is ever *required*; the bond stays session-count and no petting
grinds it; no interaction counter is ever shown; focus stays sacred (during
focus, the buddy sleeps and touching does nothing — that rule is load-
bearing fiction and survives this era untouched); every gesture has a
Reduce Motion variant per the HeartParticle precedent.

### Tier 1 — a touch vocabulary (hands)

- **Stroking**: a slow drag, distinct from the existing tap. The buddy leans
  into it, eyes close by degrees, and the haptics director gets a soft purr
  pattern. Release → a contented settle frame.
- **Places that answer**: tap the nose — a scrunch; the ears — a flick; the
  tail — a swish (the cat's swish is *mild displeasure*, because she is a
  cat); the belly — the dog rolls in bliss, the cat closes a soft paw over
  your finger, playfully, never punitively. All per-buddy data via the quirk
  rule: a frame name on `Buddy`, read by `BuddyFrames`, nil falls back.
- **The favourite spot**: each buddy has one (behind the ear, under the
  chin, the base of the tail — data), unhinted anywhere. Stroking it gets
  the big reaction. Discovering it is the whole feature.

### Tier 2 — rituals (the day)

- **The greeting**: first open after world-dawn, a stretch-and-greet
  animation with its own caption. After three or more days away, the
  *gladder* greeting — "looked up before you even sat down." Return is
  always celebrated; absence is never mentioned. This is the gentle streak's
  philosophy, animated.
- **Treats**: three (a biscuit, a berry, a small fish), offered by dragging
  to the buddy during breaks or idle. Each buddy has a favourite and one it
  politely nudges back — personality without negativity. The favourite,
  once found, is remembered in a caption once. No hunger, no schedule, no
  buff. Treats are free and infinite; fence 6 — feeding your pet is a
  relationship, not a consumable.
- **Brushing**: repeated short strokes; loose fluff drifts off; the buddy
  spends the rest of the break slightly fluffed (one derived frame). Rarely,
  a tuft becomes a keepsake — and the wren takes some for the birdhouse, if
  the birdhouse resident has arrived. Cross-system delight, one line of
  gating on `Resident.settled`.
- **Tucking in**: on a long break, drag the small blanket over a napping
  buddy. Cosmetic, one caption, and it is somehow the most owner-feeling
  gesture in the list.

### Tier 3 — the other direction (it goes both ways)

- **Keepsakes**: rarely, after a completed session, the buddy has brought
  you something — a leaf, a feather, a pebble, a ribbon, a bottle cap, a
  very good stick. Kept on a small shelf in the stats sheet (or in the den,
  once there is one). Chronicle kind `.keepsake`, Post line: *"Mochi left
  you a feather this week. No explanation was offered."* Never scheduled,
  never announced by notification, waits forever to be noticed — it cannot
  be missed, only found.
- **A life of their own**: idle two minutes and the buddy gets on with
  things — washing, a tail-chase, watching a micro-encounter butterfly go
  past (the encounter system already draws one), dozing off in stages.
  TimelineView budgets per CLAUDE.md; the idle canvas stays 2–4fps.
- **Weather in the body**: per-weather idle micro-poses — a shiver-then-
  snuggle on snow days (beside the den, if owned), a full sun-sprawl in
  golden light, watching the rain from cover the way the stray does. Data
  per the quirk rule, one optional frame per weather class, nil falls back.

**Monetization note, deliberately:** none of Tier 1–3 is for sale. The
interactions are what make the buddy feel owned; the cart sells what the
owned buddy *wears and lives in*. Selling the affection itself would poison
every purchase around it.

**Dreams:** `Dream.together` — the brush ("The brush again, and no hurry
anywhere in the world."), the treat ("The good biscuit. In the dream there
were two."), the blanket ("Under it, listening to you turn pages.").

**Flags:** `-PawmodoroKeepsakes <n>` (seed the shelf), `-PawmodoroTreat`
(force the treat tray open), `-PawmodoroGreeting` (force the morning
greeting on launch).

### As built — Phase 5, tier 1 and tier 3

Built on Linux, never compiled. The touch vocabulary and the keepsakes; tier 2
(greeting, treats, brushing, tucking in) is not built.

**The touch vocabulary is the answer to the brief.** Four spots — crown, nose,
chin, tummy — each with its own reaction, and every buddy has one **favourite**
that is hinted nowhere in the app. Finding it is the feature; a tooltip
pointing at it would turn a moment of noticing into a checklist.

The regions are derived from the anchors `generate_accessories.py` already
measures, so there is no third table of coordinates and a buddy redrawn
tomorrow has correct touch regions from the next run of that tool. It needed
one new measurement — where the animal *ends* — because a tummy sized from the
head ran off the bottom of the canvas on half the roster, and the tummy is the
penguin's favourite.

**Two geometry bugs `check_touch.py` found:**

- Sizing the regions from the head's *width* was right on a round-headed buddy
  and wrong on every long-eared one. The dog's head is thirty-five units
  across, so a nose region a third of that reached down to the chin and the
  two shared 85 % of their area — a spot that can never win the tie-break is a
  spot that does not exist. They come from the head's **height** now.
- The horizontal poses — the stretch, the otter's float, the penguin's slide —
  have ten rows between crown and collar, which divides into slivers nobody
  could aim at. Those frames get **no regions at all** and the buddy answers
  with the ordinary reaction, which on a lying-down animal is the honest
  answer anyway.

**And the checker itself was the era's clearest own goal.** Its first version
carried its own copy of the region coefficients, and *all five* deliberate
breaks passed cleanly — it was only ever agreeing with itself. Moving the
numbers into `TouchSpot.shape` as data and parsing them made four fail
instantly. CLAUDE.md now records this as the third instance of that trap, with
the instruction that follows from it: break your checker before you believe it.

**Keepsakes are the other direction**, and the reason this era is not just a
bigger set of buttons. One roll per completed session at 1-in-25, from
`.close` bond onward, against the *session* rather than anything done in it —
there is nothing to optimise and no way to make a stick likelier. No
notification, no badge, no "1 new": it waits on the shelf until somebody
looks. Six of them arrive in a fixed order rather than randomly, so nobody
ends up with four ribbons and no stick.

**Divergences:**

- **Tier 2 is not built.** The greeting, treats, brushing and tucking in are
  four separate interactions with their own art and state, and shipping half
  of each would be worse than shipping none. Tier 1 and tier 3 together are
  the complete idea — a creature that reacts to your hand, and one that brings
  you things.
- **Petting is not counted anywhere.** No stroke total, no affection meter, no
  contribution to the bond. The fences at the top of `TouchSpot.swift` are
  written before the feature for that reason.
- **VoiceOver gets the spots as named actions**, since a region cannot be
  aimed at without sight — and none of those labels marks the favourite,
  because giving it away would take the feature from exactly the people the
  actions are for.

## Phase 6 — The Scrapbook (where you actually were)

The postcards remember where the *buddy* was. The Scrapbook remembers where
**you** were — the desk, the café window, the library corner, the kitchen
table at 6am. The sentimental register the owner asked for, built from
parts the app already trusts.

**Capture.** Two entry points: the celebration card gains a quiet "keep
where you were" action, and the album gains a + button. Camera, or photo
library via `PHPicker` (which needs no permission dialog at all — prefer it
as the first-run path; the camera asks only when chosen). Every snapshot is
stamped with what the world knows: the date via `WorldCalendar`, the place
the buddy was, the buddy's name via `displayName(for:)`, the session length,
the world's weather. A photo of your desk captioned *"Harbor Isle, in the
mist — 50 minutes"* is the app's two worlds shaking hands.

**Filters are the app's own light.** Not Instagram presets — the four
time-of-day grades, the sepia of the field journal, the season tints
(sakura wash, winter blue), the weather veils. Technically: Core Image
colour cubes whose LUT data is **generated by `tools/generate_luts.py` from
the same palette math the scene grades use**, with `check_luts.py` holding
the two halves rule — parse the real grade constants, and keep a stored
fixture of sampled input→output colours so a drifted LUT is caught. The
filters are literally the world's palette applied to your afternoon.

**Stickers are the app's own sprites.** The buddy in its current pose and
outfit, the species seen that session, paw prints, the postcard frame
corners, weather glyphs. Drag, pinch, rotate; flattened only on share via
`ImageRenderer` — the AlbumView lazy-render law applies verbatim, nothing
rasterizes until somebody exports.

**Storage & privacy.** The app's first real files: JPEGs (long edge capped
~2000px) plus a JSON sidecar under Documents, indexed by a `StorageKeys`
entry, wiped by `-PawmodoroResetState`. EXIF GPS is stripped on import,
always. The app still makes no network calls, so the honest sentence for
the App Store page writes itself: *your photos never leave your device.*
`docs/PRIVACY.md` gains the section; the privacy nutrition label stays
"data not collected" — camera and library are used, not collected.

**The catalogue's share (fence 6 applied):** capture, the sepia stock and
basic stickers are free forever. Extra film stocks and sticker packs go in
the cart at small prices. The memory is never the product; the dress-up is.

**Dreams:** `Dream.snapshot`, two — "A place you sat once, seen from
slightly above." / "The window table. The light was doing that thing."

**Flags:** `-PawmodoroSeedScrapbook` (bundle three sample photos so the
simulator can drive the whole feature — the pane has no camera).

## Phase 7 — The second desk (macOS)

A real Mac app, not a phone window. Native SwiftUI macOS target sharing the
`Pawmodoro/` sources — not Catalyst — because the codebase is already pure
SwiftUI with a short, listable set of UIKit touchpoints to shim behind
`#if os(macOS)`: `HapticsDirector` (no-op), `ShakeDetector` (absent — the
snow globe gets a menu item), Live Activity (absent), notification wiring
(UserNotifications works on macOS as-is).

**The Mac-shaped feature is the menu bar.** A `MenuBarExtra` with the
countdown and a tiny buddy sprite — asleep during focus, up and about on
breaks — click for pause/skip. The window can be closed entirely and the
session keeps running; that, plus keyboard control (space to start/pause),
is the whole Mac pitch: *the buddy lives in your menu bar while you work.*

**What transfers free, because the laws were kept:** the countdown derives
from an absolute end `Date`, so **App Nap cannot break it** — the
architecture survives by construction, the same way it survives iOS
suspension. The world calendar, themes, scenes, the whole model layer are
platform-blind already.

**What must be feared:** `AVAudioEngine` on new hardware is the exact crash
class that shipped all fifty tracks broken on iPhone while the Simulator
smiled — build 2's scar. The pre-mixed single-node law is the protection,
but the first Mac run gets its own listening pass on real Mac output
devices, headphones and speaker both, before any archive. Non-negotiable.

**Window and layout.** A phone-proportioned default (~400×740), resizable
within clamped aspect bounds so the scene art never letterboxes into a
postage stamp. `check_contrast.py`, `check_stray.py` and `check_snail.py`
each gain the Mac window aspect as one more fixture row — the stray has to
stand on the ground on a Mac too.

**Store.** Same bundle ID, **universal purchase** enabled in App Store
Connect — Plus bought on the phone unlocks the Mac, and the acorn ledger is
device-local until Phase 8. Mac App Store, sandboxed; camera entitlement
(the Scrapbook works from a MacBook — a photo of the desk you're actually
at); `docs/APP_STORE_LAUNCH_GUIDE.md` gains the Mac section.

**Blind-build honesty.** The shims, the menu bar view and the window code
can be written on Linux; the *target* cannot — target creation, signing,
entitlements and the first run are a Mac sitting, like Phase Z's widget
step. `check_swift.py` gains one rule the day the target exists: every
`import UIKit` must be `#if canImport(UIKit)`-guarded. Expect this phase to
be the era's least checkable from Linux, and schedule it around a real Mac
evening.

## Phase 8 — The Crossing (iCloud, last, and on purpose)

Two devices now run the same world, and the owner will feel the seam within
a day of using the Mac: the Mac's buddy doesn't know the phone's bond. The
fix is sync — and this app is accidentally *built* for it, because of a law
written for a different reason: **nothing decays, so every store is
monotonic, so merging two worlds is trivial and safe.** The merge law, one
sentence: *the merge of two worlds is the world where everything happened.*

| Store | Merge rule |
|---|---|
| Session log | Union by record identity |
| Journal | Per-species: max count, earliest firstSeen, latest lastSeen |
| Dream diary, heard list | Union |
| Chronicle | Union, re-sort, re-cap |
| Owned items (the pouch's spent side) | **Union — a purchase is never lost** |
| Acorns | Derived from the merged log minus the merged owned set — nothing to sync |
| Settings, names, outfits | Last-writer-wins, per key |
| Snapshots | Deferred — CloudKit assets, own follow-up, size-gated |

Mechanism: CloudKit private database, one record per store, merge on pull
by the table above (`NSUbiquitousKeyValueStore`'s 1MB ceiling is too tight
for the chronicle's cap; don't fight it). This is the era's one dangerous
migration — it ships behind a Settings toggle, off by default, like every
migration this app has ever survived, and it ships **last**, after
everything it would sync exists.

---

## Build order, and what waits for what

1. **Nothing here starts before the Mac evening compiles the Deep Time
   backlog** — eleven blind phases are already queued for the compiler, and
   stacking a new era on an unverified one doubles the debugging surface.
2. **Phases 1+2+3 are one release wave.** A currency without a catalogue is
   a number; a catalogue without stock is a shelf. Pouch, cart and wardrobe
   land together, with the two new buddies making the cart feel *new*, not
   re-priced.
3. **Phases 4, 5, 6 are independent** of each other and can interleave;
   each is its own release. Tier 5's interactions can trickle a tier at a
   time.
4. **Phase 7 needs its own Mac sitting**; the Linux-writable shims can be
   prepared any time after wave one.
5. **Phase 8 is last**, after there are two platforms worth crossing
   between.
6. Phase W (sounds) stays gated on 0e's listening pass exactly as before —
   this plan changes nothing about that, and the Mac adds a second
   listening pass of its own.

## New Chronicle kinds, and the Post's word on each

| Kind | In the Sunday Post? |
|---|---|
| `.trade` | **Silent**, with reason: the letter is not a receipt |
| `.settledIn` | One line — "She has slept in the new den." |
| `.keepsake` | One line — "Mochi left you a feather this week." |
| `.snapshot` | One line — "We kept a picture of Tuesday." |

`check_post.py` will hold every one of these to account the day the kind
exists; the decisions are pre-made here so the checker never blocks on a
question of taste.

## The era's flags (all Debug-only, all with Release stand-ins)

| Flag | Effect |
|---|---|
| `-PawmodoroAcorns <n>` | Override the derived earned total |
| `-PawmodoroOwnEverything` | Own the full catalogue without Plus |
| `-PawmodoroCart` | Open the Magpie's Cart on launch |
| `-PawmodoroAccessory <slot>.<id>` | Dress the current buddy on launch |
| `-PawmodoroDen <id>` | Grant and place a den |
| `-PawmodoroKeepsakes <n>` | Seed the keepsake shelf |
| `-PawmodoroTreat` | Open the treat tray |
| `-PawmodoroGreeting` | Force the morning greeting |
| `-PawmodoroSeedScrapbook` | Three bundled sample photos |

## The checkers this era must add

Every one follows the two proven disciplines: **parse the real values out
of the Swift** (a checker that restates its inputs proves nothing), and
**anything that is a promise about the past gets a stored fixture**. And
after every green run: composite the finished surface and look at it.

| Checker | Guards | Fixture |
|---|---|---|
| `check_catalog.py` | Every item has art, a padlock surface, an unlock route; prices parse from the one Swift table | Prices never rise; the earn divisor never moves |
| `check_accessories.py` | Overlay lands on its anchor, clears 2:1, hides where it must, per buddy × pose × frame | — |
| `check_residents.py` (extended) | Dens obey the near band, overlap, footprint and corner rules | Den positions |
| `check_luts.py` | LUTs match the palette math they were generated from | Sampled colour rows |
| `check_stray.py`, `check_snail.py`, `check_contrast.py` (extended) | The Mac window aspect | Existing fixtures gain a row |

## App Review notes, collected

- Acorns are never sold, so there is no consumable-currency review
  conversation and no odds disclosure (no randomness anywhere).
- Plus's description must say it unlocks the catalogue, including future
  additions; grandfathering is automatic.
- Camera and photo-library usage strings for the Scrapbook; GPS stripped;
  nutrition label stays "data not collected."
- Universal purchase requires the same bundle ID on the Mac target — set it
  before the first Mac archive, it cannot be changed after.
- The Mac target ships sandboxed with camera and user-selected-file
  entitlements only.

## For the builder this is handed to

Read CLAUDE.md first and believe it — every convention in it was paid for.
Run every `tools/check_*.py` before ending any session written without a
Mac. Render every generated surface and look at it before trusting a green
exit code. Write the As-built section for each phase as it lands, recording
where the code diverged from this plan and why — this document expects to be
wrong in the details and insists only on the fences. The eight fences are
not suggestions; they are what makes the cart worth running.
