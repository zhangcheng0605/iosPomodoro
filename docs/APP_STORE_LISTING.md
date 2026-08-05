# App Store Connect — copy-paste contents

Everything below is ready to paste into the fields on the version page.
Character counts are against Apple's limits, checked.

---

## Promotional Text  (limit 170)

```
A focus timer with a small world behind it. Your buddy naps while you work, wildlife turns up only if you stay to the end, and every night session puts one more star in the sky.
```

*(169 characters. This is the one field you can change any time without a new
build — use it for seasonal notes later.)*

---

## Description  (limit 4,000)

```
Pawmodoro is a Pomodoro timer with somewhere to be.

Set a focus session and a pixel-art companion curls up and sleeps through it. Finish, and something happens: an animal you have never seen wanders past, a star lands in a constellation you have been building for weeks, your buddy dreams about a place you went together. Quit halfway and none of it does. That is the whole design — the app never nags you, it just quietly has more to show the people who stay.

A JOURNEY, NOT A COUNTER
Eight hand-drawn places, from a meadow at dawn to a moonlit onsen, each redrawn for four times of day. A boat, a balloon or a train crosses the scene as your session runs — its position IS the countdown. Finish enough sessions and you travel somewhere new. Places you reach stay yours.

A FIELD JOURNAL THAT FILLS ITSELF
41 species and phenomena, each appearing only in the right place, at the right hour, in the right season. See one five times and it becomes a named regular with its own markings and note. Five more things can only ever be heard, never seen — a train horn from past the hills, an owl on the dark side of the wood.

A SKY YOU BUILD
Seven constellations, 47 stars. One star per focus session finished after dark, drawn permanently into every night sky from then on. Complete a figure and it joins up, and stays joined.

TWELVE COMPANIONS
Cat, dog, penguin, bunny, hamster, fox, capybara, red panda, owl, otter, hedgehog — six with signature quirks. Bramble curls into a perfect ball while you focus. Pip floats on his back with a pebble on breaks. Luna the owl keeps watch at night instead of sleeping, so she never dreams before dawn. Rename any of them.

And one you cannot buy. A stray turns up in the hedge after you have focused on three days out of seven, comes closer over twelve more, and eventually lets you name her. She is free, and always was.

MADE TO BE KIND
- A streak that forgives one missed day a week, and says so
- Settle in with three slow breaths before the countdown starts, if you want them
- Break screens that breathe with you
- A bond that deepens over five levels
- Five seasons that arrive without being announced

ALSO INSIDE
50 gapless lo-fi tracks with a radio mode, 8 themes that all pass real contrast measurement in light and dark, postcards, an almanac, a travelogue, expedition presets, and an Action Button shortcut to start focusing without unlocking your phone.

QUIET BY DEFAULT
No account. No sign-up. No tracking, no analytics, no ads, and no network calls at all — Pawmodoro has never sent a byte anywhere and cannot. Everything stays on your device. It works in aeroplane mode, forever.

Pawmodoro Plus is one payment, no subscription: eight more companions, every ambience, every theme. Everything else — the journal, the sky, the stray, the streaks, the timer itself — is free and always will be.
```

*(~2,470 characters, well inside the limit.)*

---

## Keywords  (limit 100, comma-separated, no spaces)

```
pomodoro,focus,timer,study,deep work,cat,pixel,cozy,productivity,adhd,pet,journal,quiet
```

*(86 characters. Don't add "Pawmodoro" — Apple already indexes the app name,
so spending characters on it is waste.)*

---

## Support URL  (required — see note below)

```
https://github.com/zhangcheng0605/iosPomodoro
```

**This only works if that repo is public.** If it is private, Apple's reviewer
will hit a 404 and the submission gets rejected. Options, cheapest first:
1. Make the repo public.
2. Turn on GitHub Pages and point this at the pages URL.
3. Any page you control with a working contact address on it.

---

## Marketing URL  (optional — leave blank)

Leave empty. An empty field is fine; a broken one is a rejection.

---

## Version

```
1.0
```

---

## Copyright  (limit 200)

```
2026 Cheng Zhang
```

*(No © symbol — Apple adds it.)*

---

## Routing App Coverage File

Not applicable. This is only for apps that give driving directions. Skip it.

---

## App Review Information

**Sign-in required:** leave UNCHECKED. The app has no accounts.

**Notes:**

```
Pawmodoro is a Pomodoro focus timer. No account, no sign-in, no network access — the app makes no network calls at all, so it can be reviewed fully in aeroplane mode.

Two things worth knowing so nothing looks broken during review:

1. TIMERS ARE REAL. A focus session is 25 minutes by default. To see a session complete quickly, open Settings (gear, top right) and set Focus to 5 minutes and Short break to 1 minute, or tap the "Sprint 15/3" preset under the ring.

2. MOST CONTENT UNLOCKS OVER TIME BY DESIGN. The field journal, constellations, the stray cat and the travel map fill in as focus sessions are completed — a fresh install is deliberately close to empty. This is the core of the app, not missing content.

IN-APP PURCHASES: one non-consumable ("Pawmodoro Plus", unlocks 8 additional companions, ambience sounds and themes) and three consumable tips that unlock nothing. There is no subscription. A "Restore purchase" button is in Settings > Pawmodoro Plus.

All artwork, music and sound in the app is originally generated for it — there is no third-party or licensed content.
```

---

## App Store Version Release

Recommended: **Manually release this version.**

The default is "Automatically release", which puts the app live the moment
review passes — possibly at 4am while you are asleep, with no chance to look
at it first. Manual costs you one button press and gives you the choice.

---

## Elsewhere in App Store Connect (not on this page)

| Where | Answer |
|---|---|
| **App Privacy** | "Data Not Collected" — answer No to every category. The app has no network code at all. |
| **Age Rating** | 4+ — no objectionable content of any kind, no web views, no user-generated content. |
| **Category** | Primary: **Productivity**. Secondary: **Health & Fitness** (or Lifestyle). |
| **Content Rights** | No third-party content. |
| **Export Compliance** | Already answered in the build: `ITSAppUsesNonExemptEncryption = NO` is set in the project, so App Store Connect should not ask again. If it does: **No**, the app uses no encryption. |
| **Price** | Free, with in-app purchases. |
| **In-App Purchases** | Must be created separately, with IDs matching `Pawmodoro/Store/StoreIDs.swift` exactly — see the table below. |

### In-App Purchase product IDs (must match exactly)

| Product | Type | ID |
|---|---|---|
| Pawmodoro Plus | Non-Consumable | `com.pawmodoro.zhangcheng.plus` |
| Tip — small | Consumable | `com.pawmodoro.zhangcheng.tip.small` |
| Tip — medium | Consumable | `com.pawmodoro.zhangcheng.tip.medium` |
| Tip — large | Consumable | `com.pawmodoro.zhangcheng.tip.large` |

A mismatch here does not fail the build — the store simply returns no products
and the paywall shows its "unavailable" state, which is a miserable bug to
chase later.

**Note:** you can submit version 1.0 without the in-app purchases and add them
in a later version. If you *do* submit them now, Apple reviews them alongside
the app, and a rejected IAP holds up the whole release.

---

## Screenshots

Six are ready in `store-screenshots/`, captured at 1320 × 2868 (iPhone 6.9"):

| File | Shows |
|---|---|
| `01-meadow-day.png` | The timer at Meadow Home, mid-morning |
| `02-night-stars.png` | Night sky with constellations built up |
| `03-onsen.png` | Moonlit Onsen at dusk, red panda |
| `04-cloudspire.png` | Cloudspire in the afternoon, capybara |
| `05-journal-stats.png` | Bond at "Devoted", streak and totals |
| `06-field-journal.png` | The field journal, including "Heard, not seen" |

Drag them into the **6.9" display** slot in Media Manager (the page you
screenshotted was showing the 6.5" slot — use "View All Sizes in Media
Manager" to find 6.9"). Apple scales down for smaller devices automatically,
so this one set covers every iPhone.
