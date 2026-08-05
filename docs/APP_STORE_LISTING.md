# App Store Connect — copy-paste contents

Everything below is ready to paste into the fields on the version page.
Character counts are against Apple's limits, checked.

---

## ⚠️ First: sign Xcode in, or none of this can be uploaded

This Mac has **no Apple ID in Xcode and no signing certificate** — checked
with `security find-identity -v -p codesigning`, which returns "0 valid
identities found", and the provisioning-profile folder is empty.

That is why the target looked empty: with no account signed in, the Team
dropdown has nothing to offer and Xcode gives up on the signing panel.

Fix it in this order:

1. **Xcode → Settings (⌘,) → Accounts → "+" → Apple ID.** Sign in with the
   Apple ID that owns the App Store Connect account — the one that created
   the Paawmodoro record. If it says you have no membership, that Apple ID
   is not the one enrolled in the Developer Program.
2. Open `Pawmodoro.xcodeproj`. In the left sidebar click the **blue project
   icon** at the very top (named "Pawmodoro"). The editor then shows a
   PROJECT and a TARGETS list — click **"Pawmodoro" under TARGETS**, not
   under PROJECT. That is the target; it does exist.
3. **Signing & Capabilities** tab → tick "Automatically manage signing" →
   pick your team in the **Team** dropdown.
4. Xcode writes your Team ID into the project. Send me the resulting diff,
   or just the ID (10 characters, like `A1B2C3D4E5`), and I'll commit it.

Until step 3 is done, **Product → Archive is greyed out or fails**, so there
is nothing to upload no matter how complete this page is.

---

## Promotional Text  (limit 170)

```
A focus timer with a small world behind it. Your buddy naps while you work, wildlife turns up only if you stay, and every night session puts one more star in the sky.
```

*(164 characters. This is the one field you can change any time without a new
build — use it for seasonal notes later.)*

---

## Description  (limit 4,000)

```
Paawmodoro is a Pomodoro timer with somewhere to be.

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
No account. No sign-up. No tracking, no analytics, no ads, and no network calls at all — Paawmodoro has never sent a byte anywhere and cannot. Everything stays on your device. It works in aeroplane mode, forever.

Paawmodoro Plus is one payment, no subscription: eight more companions, every ambience, every theme. Everything else — the journal, the sky, the stray, the streaks, the timer itself — is free and always will be.
```

*(~2,470 characters, well inside the limit.)*

---

## Keywords  (limit 100, comma-separated, no spaces)

```
pomodoro,focus,timer,study,deep work,cat,pixel,cozy,productivity,adhd,pet,journal,quiet
```

*(86 characters. Don't add "Paawmodoro" — Apple already indexes the app name,
so spending characters on it is waste.)*

---

## Support URL  (required)

```
https://github.com/zhangcheng0605/iosPomodoro
```

Confirmed public, so a reviewer can reach it. One thing worth doing before
you submit: make sure the README has a visible way to contact you (an email
address is enough). "Support URL" means support — a reviewer who finds no
way to ask for help can reject on Guideline 1.5.

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
Paawmodoro is a Pomodoro focus timer. No account, no sign-in, no network access — the app makes no network calls at all, so it can be reviewed fully in aeroplane mode.

Two things worth knowing so nothing looks broken during review:

1. TIMERS ARE REAL. A focus session is 25 minutes by default. To see a session complete quickly, open Settings (gear, top right) and set Focus to 5 minutes and Short break to 1 minute, or tap the "Sprint 15/3" preset under the ring.

2. MOST CONTENT UNLOCKS OVER TIME BY DESIGN. The field journal, constellations, the stray cat and the travel map fill in as focus sessions are completed — a fresh install is deliberately close to empty. This is the core of the app, not missing content.

IN-APP PURCHASES: one non-consumable ("Paawmodoro Plus", unlocks 8 additional companions, ambience sounds and themes) and three consumable tips that unlock nothing. There is no subscription. A "Restore purchase" button is in Settings > Pawmodoro Plus.

NOTE ON THE NAME: the App Store listing is "Paawmodoro"; the app's own interface calls itself "Pawmodoro". This is deliberate — the shorter spelling was unavailable on the App Store.

All artwork, music and sound in the app is originally generated for it — there is no third-party or licensed content.
```

---

## App Store Version Release

**Automatic is fine — with one condition.**

The generic "always release manually" advice is weak, and for a first app
with no launch plan, getting it live sooner is worth more than controlling
the minute. Automatic release is a reasonable default.

The condition is your in-app purchases. If the app goes live *before* the
four IAPs are approved, the paywall shows its "store isn't available" state
to every real user who taps Plus — the app looks broken, and early reviews
are the ones that stick. So:

- **Submitting the IAPs with this build?** Automatic is fine. Apple reviews
  them together, and they go live together.
- **Submitting the app alone and adding IAPs later?** Choose manual, or
  accept that Plus is dead until the next review round.

The other, smaller argument for manual: you cannot see the live product page
before customers do. If you want to check how the screenshots and
description actually look before anyone finds them, manual buys you that.

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
