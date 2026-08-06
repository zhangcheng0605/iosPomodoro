# The Sound Almanac — sixty-five tracks, zero licenses

> **Status: built.** All sixty-five tracks generate, the gapless AVAudioEngine
> player and the Sound Studio ship, and radio mode works. Outstanding from
> this spec: the pixel cassette icons for the shelf (§1) and the buddy's
> bpm-synced ear twitch (§4).
>
> The last fifteen are Deep Time's **Phase W5** and are in §6, below —
> three mixtapes behind a third kind of gate that is neither free, nor bought,
> nor travelled to.

This supersedes the five-loop version of Phase G in
[CONTENT_PLAN.md](CONTENT_PLAN.md). The ask grew: **fifty lo-fi/ambient
tracks**, tiered free/paid. Fifty hand-crafted loops would be a content
treadmill; fifty tracks from a **procedural composition engine** is a weekend
of engineering and then a catalog you can grow forever. Same doctrine as every
other asset in this app: generated, deterministic, nothing to license.

The differentiator isn't the count. It's that **music is part of the journey**:
you don't buy all of it — some of it you *travel to*. Each free-route place you
reach unlocks its own five-track mixtape. Nobody else's pomodoro hands you an
album for showing up eight days in a row.

---

## 1. The catalog: 10 mixtapes × 5 tracks

Every mixtape has a generated pixel **cassette** icon (24×16, per-collection
palette) for the Sound Studio shelf. Gating: `free` (day one), `arrival(place)`
(reach the place — works without Plus; this is the generosity engine), `plus`.

### Paws & Chill I — `free`
The classic study loop. 66–74bpm, Rhodes-ish EP, brushes, vinyl crackle.

| # | Track | bpm | key | lead | texture |
|---|---|---|---|---|---|
| 1 | First Light Loop | 70 | Cmaj7 | ep + brush | crackle |
| 2 | Homework for Two | 72 | Am | ep + sub | rain |
| 3 | Corner Desk | 68 | F | marimba + ep | crackle |
| 4 | Sleepy Metronome | 66 | G | musicbox + pad | — |
| 5 | Warm Static | 74 | Dm | ep | heavy crackle |

### Meadow Mornings — `arrival(meadow)` (i.e. session one)
Gentle, majory, birds at the edges.

| 6 | Dew on the Fence | 76 | G | marimba | birds |
| 7 | Kettle Song | 70 | C | musicbox + ep | crackle |
| 8 | Clover Rows | 72 | D | pluck + pad | birds |
| 9 | Biscuit's Nap | 64 | F | pad + sub | wind |
| 10 | Chimney Smoke | 68 | Am | ep | crackle |

### Under the Pines — `arrival(woods)`
Minor-leaning, wind and water beds.

| 11 | Needle Carpet | 66 | Em | pad + marimba | wind |
| 12 | Creekside Study | 70 | G | ep | water |
| 13 | Mushroom Lamp | 62 | Cm | musicbox | night crickets |
| 14 | Old Log Bridge | 72 | D | marimba + brush | water |
| 15 | Fern Light | 68 | A | pad | birds |

### Saltwater Tapes — `arrival(harbor)`
Slower, wave beds, one sub-pulse track.

| 16 | Slow Tide | 63 | C | pad + sub | waves |
| 17 | Rope & Plank | 74 | F | ep + shaker | waves |
| 18 | Lighthouse Pulse | 70 | Am | sub pulse + pad | waves |
| 19 | Ferry at Noon | 72 | Bb | ep + brush | crackle |
| 20 | Salt on Glass | 66 | Dm | ep | waves + crackle |

### Lantern Nights — `arrival(blossom)`
Evening-toned; music box forward.

| 21 | Paper Glow | 64 | Em | musicbox + pad | crickets |
| 22 | Petal Drift | 70 | C | ep + marimba | — |
| 23 | Waterfall Ink | 68 | G | pluck | water |
| 24 | Festival Ended | 60 | Am | pad | crackle |
| 25 | Terrace Steps | 72 | F | ep + shaker | — |

### Paws & Chill II — `plus`
| 26 | Second Wind | 74 | Em | ep + brush | crackle |
| 27 | Margin Notes | 70 | C | ep + marimba | rain |
| 28 | Half-Closed Eyes | 64 | F | pad + ep | crackle |
| 29 | Borrowed Sweater | 68 | Am | ep | rain |
| 30 | Sunday Loop | 72 | G | musicbox + brush | crackle |

### Cloudspire Drift — `plus`
Airy, sparse, mostly pads; one waltz.

| 31 | Above the Weather | 58 | C | pads | wind |
| 32 | Balloon Mail | 66 | G | ep + pad | wind |
| 33 | Roots in the Sky | 62 | Dm | pad + sub | — |
| 34 | Thin Air Waltz | 84 (3/4) | F | musicbox | wind |
| 35 | Anchorless | 60 | Am | pad | wind |

### Night Train — `plus`
The rhythmic set: rail-clack percussion (band-passed noise taps at half-time).

| 36 | Sleeper Car | 52 | Am | clack + sub + ep | rumble |
| 37 | Viaduct | 56 | Em | clack + pad | rumble |
| 38 | Window Seat | 60 | C | brush + ep | rumble |
| 39 | Tunnel Counting | 54 | Dm | clack + musicbox | rumble |
| 40 | Last Stop Lullaby | 48 | F | musicbox + pad | — |

### Moonlit Onsen — `plus`
Pentatonic, mallets and plucks over water.

| 41 | Steam Rise | 62 | Am pent | pluck | water |
| 42 | Stone & Water | 66 | D pent | marimba | water |
| 43 | Capybara Club | 70 | G | ep + shaker | water |
| 44 | Warm to the Bone | 58 | C | pad + sub | water |
| 45 | Snow on Cedar | 60 | Em | musicbox | wind |

### Starfall — `plus`
The sparsest set; celesta notes with space between them.

| 46 | Meteor Ledger | 54 | C | celesta + pad | crickets |
| 47 | Counting in the Dark | 50 | Am | pad + sub | — |
| 48 | Ridge Light | 58 | F | ep sparse | wind |
| 49 | Perseid Tape | 56 | Dm | musicbox sparse | crickets |
| 50 | Hello, Moon | 46 | C | pad + celesta | crickets |

**Tallies.** Free instantly: 5. Free through play: +20 (each Home Waters
arrival hands you a mixtape — the same thresholds the journey already uses, so
this needs **no new persistence at all**; unlocks derive from
`engine.hasReached(place)`). Plus: all 50, instantly.

---

## 2. The engine — `tools/generate_music.py`

One file, numpy only, structured like the other generators.

**Determinism.** Every track's seed is a hash of its name. Same run, same
bytes. `Rng` class from generate_scenes.py, not `random`.

**Core.** A pattern sequencer over an 8- or 16-bar form: chord bank keyed by
Roman-numeral progressions (I–vi–IV–V, ii–V–I–vi, i–VI–III–VII, one pentatonic
mode for Onsen), per-bar note patterns per instrument with ±10ms humanized
timing and velocity jitter.

**Instruments** (all additive/subtractive synthesis, no samples):
`ep` (detuned sine pair + odd harmonics, tremolo, soft attack — the Rhodes),
`musicbox` (fast-decay pluck + 2 harmonics), `celesta` (musicbox, longer decay,
higher register), `marimba`, `pad` (filtered saw stack, slow LFO), `pluck`,
`sub` (sine bass), `kick` (45Hz thump), `brush` (band-passed noise burst),
`hat`, `shaker`, `clack` (the rail rhythm: paired noise taps), `crackle`
(sparse pops + hiss), and texture beds reused from generate_assets.py's
ambience DSP (rain, waves, wind, water, birds, crickets, rumble).

**Master chain.** Global tape wobble (slow pitch LFO ±6 cents), gentle low-pass
(the lo-fi warmth is also what makes 22.05kHz mono sound intentional),
soft-clip, RMS-normalize to a shared target so no track jumps out.

**The loop seam — the quality bar.** Render one extra bar, equal-power
crossfade the tail into the head (250ms), trim. The generator *asserts* per
track: seam RMS discontinuity under threshold, peak ≤ −1dBFS, RMS within
±1.5dB of target, duration 20–40s. A failed track fails the run loudly.

**Formats and size.** Master WAVs are 22.05kHz mono, then `afconvert` to AAC
`.m4a` (~64kbps) into `Pawmodoro/Resources/Music/`. Budget asserted by the
generator: **all 50 tracks ≤ 20MB total** (expect ~12–15MB). Cassette icons
emitted into the asset catalog.

**Single source of truth.** The generator also emits
`Pawmodoro/Model/MusicCatalog.swift` — the 50 `MusicTrack` entries (id, title,
collection, gate, bpm, energy 1–3, loop sample count) as generated Swift.
Recipes live in Python; **edit the recipe, never the Swift, never the m4a.**

---

## 3. The player — gapless is non-negotiable

AAC cannot be gap-lessly looped by `AVAudioPlayer` (encoder priming adds
silence). So the **music channel moves to `AVAudioEngine`**: decode the m4a
once into an `AVAudioPCMBuffer`, trim to the loop sample count from the
catalog, and `scheduleBuffer(_, options: .loops)` — sample-accurate, forever.
Ambience stays on `AVAudioPlayer` (its WAVs already loop cleanly). Session
category stays `.ambient`; both channels duck under the chime.

Two player nodes on the music channel, so track changes and **radio mode** can
crossfade (2s equal-power volume ramps) instead of cutting.

`SoundPlayer` grows: `setMusic(_:)`, `musicVolume`, `ambienceVolume`,
crossfade plumbing. Settings gain `music`, `musicVolume`, `ambienceVolume`,
`radioMode` — lenient decoding as always; `applyEntitlement` drops a
Plus-gated track, the mixer's second channel, and radio when Plus lapses,
falling back to track 1 or silence.

## 4. The Sound Studio UI

Long-press the ambience row (or its new ear icon) → the Studio sheet:

- **Cassette shelves**, one horizontal row per mixtape, in journey order.
  Locked mixtapes show the cassette greyed with a padlock (Plus) or "Reach
  Harbor Isle to unlock" (arrival) — locked things shown, never hidden.
- **Now playing** chip with the track name; tap advances within the mixtape.
- **The mixer** (Plus): ambience × music together with two volume sliders.
  Free plays one channel at a time — still a real upgrade over today.
- **Radio** (Plus): auto-DJ toggle. Picks from *unlocked* tracks, filtered by
  place affinity and day-part energy (dawn/day → energy 2–3, dusk/night →
  1–2), crossfading at each loop's end. "The app scores your day."
- Garnish: the buddy's idle ear-twitch syncs to the playing track's bpm
  (catalog carries bpm; the animator already ticks).

Free/Plus recap: free = 25 earnable tracks, one channel, manual picks.
Plus = 50 tracks, the mixer, radio. Update `PaywallView` copy and
[MONETIZATION.md](MONETIZATION.md) counts in the same commit.

## 5. Build order for Opus

| Slice | Scope | Verify |
|---|---|---|
| G+1 | Engine + master chain + seam/size asserts + first 2 mixtapes (10 tracks) + `MusicCatalog.swift` emission | generator run clean; listen; `afinfo` durations; size print |
| G+2 | `AVAudioEngine` music channel + buffer looping + Studio sheet + gating + settings/entitlement | loop a track 3+ minutes — no gap tick; lock states; Release build |
| G+3 | Remaining 8 mixtapes (40 tracks) + cassette art + mixer + radio + paywall copy | full catalog in Studio; radio rotates; 20MB budget holds |

Debug flags: `-PawmodoroTrack <id>` (start with a track playing),
`-PawmodoroUnlockMusic` (all mixtapes, without Plus). Add to CLAUDE.md's table.

---

## 6. Music III — fifteen found tracks (Deep Time, phase W5)

Catalog 50 → 65. The new gate is `MusicGate.found(MusicFinding)`, and the
whole point of it is in the name: these three tapes are earned by a **way of
playing**, not by paying and not by travelling. Plus does not open them.
The cart does not stock them. A Plus owner and a free one earn them on
identical terms, which is `Ambience.isFound`'s rule carried from sound to
music.

None of the three needed a new store. Two ask counters the app has kept for
years — `SessionLog.nightSessions` and `Stray.hasJoined` — and the third
keeps its tally in the Chronicle under `ChronicleEvent.Kind.tape`, capped at
five rows in a lifetime because rows stop being written the moment the tape is
found.

### Rainy Day Tapes — `found(.rainyday)`

Five sessions finished with a rain-family loop playing (`Ambience.isRain`:
rain, drizzle, storm, tent). Written to be heard **with** something else, which
is the only set in the catalogue that is, and three rules follow:

- **no texture bed** — the rain loop *is* the bed, and a second one is mud;
- **brush kit, never a hat or a shaker** — both live exactly where rain does
  and both lose;
- **the `rain` room** — the master chain scoops 42 % out of 1.15–3 kHz and
  rolls off at 5.2 kHz, so the loop sits in the gap and the treble is given
  away rather than fought over.

| # | Track | bpm | key | lead | space |
|---|---|---|---|---|---|
| 51 | Windowpane Study | 66 | C | ep + brush | 0.78 |
| 52 | Gutter Song | 62 | Am | pad + sub | 0.72 |
| 53 | Second Umbrella | 70 | F | marimba + brush | 0.80 |
| 54 | Wet Pavement | 64 | Dm | ep + pad | 0.70 |
| 55 | Nothing Urgent | 68 | G | musicbox + pad + brush | 0.74 |

### Night Shift — `found(.nightshift)`

Ten sessions finished after dark — twice the crickets' five, deliberately, so
the two finds are separate evenings instead of arriving together and one of
them going unnoticed. Sub, pad and music box; the `night` room rolls off at
4.3 kHz, darker than anything else here.

| 56 | Third Coffee | 64 | C | ep + pad + sub | 0.76 |
|---|---|---|---|---|---|
| 57 | The Building Is Empty | 60 | Em | pad + musicbox | 0.68 |
| 58 | Corridor Light | 66 | Am | musicbox + sub + pad | 0.72 |
| 59 | Small Hours | 62 | F | pad + ep | 0.70 |
| 60 | Nobody Is Awake | 68 | Dm | pad + sub + marimba | 0.66 |

### Soot's Tape — `found(.soot)`

The stray's trust arc, completed. Music box over a pad throughout — the box is
nearly all fundamental, so the `lullaby` room barely grades it at all.

**Hidden until found**, which makes it the second exception to "locked content
is shown with a padlock, never hidden" and the same exception for the same
reason: a greyed-out row called *Soot's Tape* on day one tells somebody there
is a cat coming, and that is a two-week story spoiled in order to advertise
nothing.

| 61 | The Hedge | 56 | Am | musicbox + pad | 0.62 |
|---|---|---|---|---|---|
| 62 | Fence Post | 60 | C | musicbox + pad | 0.66 |
| 63 | Six Feet Away | 54 | Em | musicbox + pad | 0.58 |
| 64 | She Stayed | 58 | F | musicbox + pad | 0.64 |
| 65 | Indoor Cat | 52 | C | musicbox + pad + sub | 0.60 |

### Two knobs added to the engine

`Track` gained `space` and `room`, and neither is a rewrite of anything.

**`space`** is a density multiplier on the melody and chord-repeat rolls.
`energy` already said how busy a track is *rhythmically*; this says how often a
note is played at all, and the two are genuinely different — all fifteen of
these are energy 1 or 2 and would still have been far too full at the density
the first fifty were written at. Sparse is not the same as slow. Default 1.0
multiplies the existing constants by exactly one, so the original fifty render
bit-identically; that was checked rather than assumed.

**`room`** picks a row of the `ROOMS` table — one lowpass and an optional
`scoop(low, high, depth)` applied in the master chain. `None` is the old
behaviour (lowpass 7200), which is why nothing that shipped moved.

### Radio

`radioPick` gained a third input. Place affinity alone would have hidden all
fifteen forever: `here` is non-empty at seven of the eight places and the pool
is `here` whenever it is. Found tapes now join the pool when their *occasion*
is on — rain in the sky or in the speaker, night or dusk, and Soot's always,
because hers has no occasion but her. That makes radio the surface where a
find is most audible: the app starts playing it back to you unprompted.

### Size

65 tracks ≈ 12.4 MB of AAC (was 9.5 MB for 50). Release `.app` went
**37.9 MB → 40.5 MB** against a 45 MB ceiling. That leaves ~4.5 MB, which is
not much: the next thing to add audio should measure before it writes recipes,
and the generator's `TOTAL_BUDGET_MB` assertion now projects over
`len(TRACKS)` rather than a hard-coded 50.
