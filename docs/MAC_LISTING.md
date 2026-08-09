# App Store Connect — the macOS listing, ready to paste

Everything App Store Connect asks for when you add the **macOS** platform to
the existing **Paawmodoro** record. Companion to `docs/APP_STORE_LISTING.md`
(which is the iOS copy and mentions the Mac nowhere) and to
`docs/MAC_APP_STORE.md` (which is the engineering side — signing, sandbox,
icon, the checklist).

Every character count below was measured, not estimated. Every fact in the
description was read out of the code on 9 Aug 2026; § 8 lists what was
counted and where.

**Nothing here has been uploaded.** This file is copy.

---

## 0. Read this first — what you actually have to write

Adding a platform does **not** duplicate the whole record. Some fields are
per-platform and start empty; the rest already exist and carry over.

| Field | Scope | State |
|---|---|---|
| Name, Subtitle | per platform | **write** (§ 1, § 2) |
| Promotional text, Description, Keywords, What's New | per platform version | **write** (§ 3–6) |
| Screenshots | per platform | eight exist at 1440×900, `MAC_STORE_ASSETS.md` § 2 — **re-shoot after the menu-bar fix** |
| Support URL, Marketing URL | per platform version | **write** (§ 7) |
| Primary / Secondary category | per platform | **choose** (§ 9) |
| Copyright | per platform version | **write** (§ 11) |
| App Review notes | per submission | **write** (§ 12) |
| App Privacy | app-level, shared | already answered — confirm (§ 10) |
| Age rating | app-level, shared | already answered — confirm (§ 10) |
| In-app purchases | app-level, shared | nothing to create; same four product IDs |
| Export compliance | per build | `ITSAppUsesNonExemptEncryption = NO` is in the bundle |
| Minimum macOS | read from the build | `LSMinimumSystemVersion 14.0` — you do not type it |

---

## 1. App Name  (limit 30)

```
Paawmodoro
```

*(10 characters.)*

**Keep the two a's.** It is the same app record, and the same name across both
platforms is what makes "you already own this" legible to a customer looking
at their purchase history. Renaming the Mac platform to "Pawmodoro" would also
fail — the shorter spelling is taken on the App Store, which is why the second
a exists at all.

---

## 2. Subtitle  (limit 30)

```
A focus timer in your menu bar
```

*(30 characters, exactly at the limit.)*

Leads with the one thing the iPhone version cannot do. **This line is only
honest once the menu-bar bug is fixed** (`MAC_APP_STORE.md` checklist step 6 —
today the status item draws the buddy at ~400 pt and the menu bar clips it to
an orange band). If that fix does not land before submission, use one of these
instead — both are also exactly 30:

```
A timer with a world behind it
```
```
Focus, and a small world grows
```

---

## 3. Promotional Text  (limit 170)

```
A focus timer with a small world behind it. The buddy naps in the menu bar, wildlife turns up only if you stay, and a session after dark leaves a star in the sky.
```

*(162 characters. This is the one field you can change without shipping a
build — use it later for a season, a new place, whatever is current.)*

If the menu bar is still broken, swap the middle clause:

```
A focus timer with a small world behind it. The buddy naps through your session, wildlife turns up only if you stay, and a session after dark leaves a star in the sky.
```

*(167 characters.)*

---

## 4. Description  (limit 4,000)

```
Paawmodoro is a focus timer with somewhere to be.

Start a session and a small pixel-art animal curls up and sleeps through it. You can close the window; the countdown carries on in the menu bar, next to the sleeping buddy. When the session ends, something has quietly happened — an animal you have never seen wandered past, a star landed in a constellation you have been drawing for weeks, a tree grew in a wood that only grows while you work.

ON THE MAC
The buddy and the countdown sit in the menu bar, so the app can be out of the way and still be running. Command-Return starts and pauses, Command-Right skips a phase, and Command-K gives the scene a shake so the sky leans with it. The window is a narrow column, meant to be left open beside whatever you are actually doing.

A JOURNEY, NOT A COUNTER
Eight hand-drawn places, from a meadow at dawn to a moonlit onsen, each redrawn for four times of day. A boat, a balloon or a train crosses the scene while the session runs, and its position is the countdown. Keep going and somewhere new opens up. Places you reach stay yours.

A FIELD JOURNAL THAT FILLS ITSELF
Eighty-one species and phenomena, each appearing only in the right place, at the right hour, in the right season. See one a few times and it becomes a named regular with its own markings and a note. Eight more can only ever be heard — a train horn from past the hills, an owl on the dark side of the wood.

A SKY YOU BUILD
Seven constellations, forty-seven stars. One star for a session finished after dark, drawn permanently into every night sky from then on. Complete a figure and it joins up, and stays joined.

WEATHER NOBODY SETS
The day's weather is a function of the date, the same for everyone, decided before you open the app. Rain, mist, snow in the winter window, the strange gold hour that follows a storm. There is nothing to check and no way to miss it.

ELEVEN COMPANIONS, AND ONE WHO ARRIVES
Cat, dog, penguin, bunny, hamster, fox, capybara, red panda, owl, otter and hedgehog, several with their own quirks. Tofu the capybara soaks on breaks. Luna the owl keeps watch at night instead of sleeping, so she never dreams before dawn. Bramble sleeps as a perfect ball. Rename any of them.

And one you cannot buy. A stray turns up in the hedge after you have focused on a few days out of seven, comes closer over the following weeks, and eventually lets you name her. She is free, and always was.

SOUND
Sixty-five original tracks, written for this app and looping without a seam. Nineteen ambiences, each voiced four times over for morning, day, evening and night, so rain at two in the afternoon is not the same rain as rain at two in the morning. A mixer for the balance between them, and a radio mode that picks for you.

NOTHING DECAYS, EVER
A missed day is forgiven, and the app says so. Bond, trees, journal entries, trust, the sky — everything here either goes up or stays where it is. Nothing punishes you for a day off, and nothing ever will. Come back after a week away and it is all where you left it.

QUIET BY DEFAULT
No account. No sign-up. No tracking, no analytics, no ads, and no network calls at all — Paawmodoro has never sent a byte anywhere and has no code that could. It is sandboxed, everything stays on your Mac, and it works with the Wi-Fi off, forever.

ONE PURCHASE, BOTH MACHINES
If you already have Paawmodoro on your iPhone, the Mac app comes with it, and so does Plus. One purchase covers both, and it always did.

Paawmodoro Plus is a single payment with no subscription: eight more companions, four further places, the sound almanac, six more themes. Everything else — the journal, the sky, the wood, the stray, the weather, the timer itself — is free and stays free.

A NOTE ON THE NAME
The window says Pawmodoro. The App Store says Paawmodoro, with two a's, because the shorter spelling was already taken. Same app.
```

*(3,883 characters. 117 of headroom, which is enough for one added sentence
and no more.)*

### If the menu bar is not fixed before you submit

Two edits, and nothing else changes. Delete the sentence *"You can close the
window; the countdown carries on in the menu bar, next to the sleeping
buddy."* from the opening, and replace the whole **ON THE MAC** paragraph
with:

```
ON THE MAC
Command-Return starts and pauses, Command-Right skips a phase, and Command-K gives the scene a shake so the sky leans with it. The window is a narrow column, meant to be left open beside whatever you are actually doing.
```

A description that promises a menu bar buddy while the menu bar shows an
orange band is the kind of thing that produces a one-star review with a
screenshot attached, and neither the reviewer nor Apple would have caught it.

### What this description deliberately does not mention

Because none of it is true on the Mac, and each would be a support email:
home-screen widgets, Live Activities, the Action Button shortcut, haptics,
the shake gesture (⌘K is offered instead), the camera, and **the Scrapbook** —
which on macOS today has no way to add a picture at all
(`MAC_STORE_ASSETS.md` § 3.2). If step 7 of the launch checklist lands before
submission, the Scrapbook is worth a sentence; until then, silence is the
honest option.

### On the voice

The rules `tools/check_post.py` enforces on the Sunday Post were applied to
this copy by hand: no congratulating, no instructing, no comparison with
anything, no exclamation marks, no number used as pressure. The counts that
appear (eight places, eighty-one species, forty-seven stars) describe what is
in the box; none of them is a quota addressed to the reader. The word
*streak* is avoided for the same reason the letter avoids it — it makes the
app about a counter that can break — which is why the line reads "a missed
day is forgiven" instead.

---

## 5. Keywords  (limit 100, comma-separated, no space after commas)

```
pomodoro,focus,timer,menubar,study,deep work,cat,pixel,cozy,productivity,adhd,pet,journal,quiet
```

*(95 characters.)*

Differences from the iOS set, and why: **`menubar` added** — it is a real Mac
search term and the iOS field has no use for it. `deep work` keeps its
internal space; the "no spaces" rule is about the separators, not about
phrases. Do not spend characters on "Paawmodoro", "mac", "macos" or "app" —
Apple indexes the app name and the platform already.

If the menu-bar bug is unfixed at submission, swap `menubar` for `calm` rather
than advertising a broken surface in search:

```
pomodoro,focus,timer,calm,study,deep work,cat,pixel,cozy,productivity,adhd,pet,journal,quiet
```

*(92 characters.)*

---

## 6. What's New in This Version  (limit 4,000)

For a platform's **1.0** this field is normally not shown and not required —
the description is what a new listing displays. Fill it in anyway if App Store
Connect offers it, and keep it for the first Mac update:

```
Paawmodoro comes to the Mac.

It is the same world, built for macOS rather than wrapped: the buddy and the countdown live in the menu bar, so you can close the window and leave the session running. Command-Return starts and pauses, Command-Right skips a phase, Command-K shakes the scene.

If you already have Paawmodoro on your iPhone, this is included, and so is Plus. One purchase covers both.
```

*(396 characters.)*

---

## 7. URLs

### Support URL  (required)

```
https://github.com/zhangcheng0605/iosPomodoro
```

Same as iOS, and the same caveat applies: the README needs a visible way to
contact a human. A support URL with no route to support is a Guideline 1.5
rejection, and it is the cheapest one to avoid.

### Marketing URL  (optional)

**Leave empty.** An empty field is fine; a broken one is a rejection. There is
no marketing site, and the GitHub repo is already the support URL.

---

## 8. Where every number in the description comes from

Checked in the working tree on 9 Aug 2026, so a future edit can re-check
rather than trust this file.

| Claim | Source |
|---|---|
| eight places, four times of day each | `Model/Place.swift` — 8 cases; `assetName(for: DayPart)` |
| four free, four with Plus | `Place.swift` — "The Home Waters" (meadow, woods, harbor, blossom) vs "The Far Isles" (keep, cloudspire, peaks, onsen) |
| eighty-one species | `python3 tools/check_species.py` → *"checked 81 species over 10 years of skies"* |
| eight heard, never seen | `Model/Heard.swift` — 8 cases |
| seven constellations, forty-seven stars | `Model/Constellation.swift` — `Constellation.all` has 7 entries and 47 `CGPoint`s |
| eleven companions plus the stray | `Model/Buddy.swift` — 12 cases, `stray` excluded from `free`; cat, dog, penguin free |
| sixty-five tracks | 65 `.m4a` in `Pawmodoro/Resources/Music/` |
| nineteen ambiences, four grades each | `Model/Ambience.swift` — 19 cases; four circadian grades per loop |
| eight themes, six with Plus | `Model/AppTheme.swift` — 8 cases; Sakura and Snowdrift ship free |
| one tree per hour of focus | `Model/Grove.swift` — `minutesPerTree = 60` |
| ⌘Return / ⌘→ / ⌘K | `PawmodoroApp.swift` — `CommandMenu("Session")` |
| the window can be closed, the session keeps running | `PawmodoroApp.swift`, the `menuBar` scene's own doc comment |
| no network calls at all | `MAC_APP_STORE.md` § 3.2 — zero hits for `URLSession`, `NWConnection`, `http://`, `https://` across every `.swift`, plus the sandbox probe in § 3.3(c) |

---

## 9. Categories

| Field | Answer |
|---|---|
| **Primary** | **Productivity** |
| **Secondary** | **Health & Fitness** |

Primary must be Productivity for a reason beyond taste: the built Mac
`Info.plist` already carries `LSApplicationCategoryType =
public.app-category.productivity`, and that key is what the Finder and the
Mac App Store use for the app itself. A mismatch between the bundle and the
listing is confusing rather than fatal, but there is no reason to have one.

Secondary is a judgement call and worth one line each way. **Health & Fitness**
matches what the app is actually for — attention and rest, and a design whose
central promise is that nothing punishes you. **Lifestyle** is the softer
alternative and is where a lot of cozy apps sit. Health & Fitness is the same
answer as iOS, and keeping the two platforms consistent is worth more than the
difference between them.

---

## 10. Age rating and App Privacy

Both are **app-level** and already answered for iOS. Adding a platform should
not re-ask. Confirm rather than re-enter — and if the new platform does
present the questionnaire again, the answers are unchanged.

### Age rating → **4+**

| Question group | Answer |
|---|---|
| Cartoon or Fantasy Violence | **None** |
| Realistic Violence / Prolonged Graphic or Sadistic Violence | **None** |
| Sexual Content or Nudity | **None** |
| Profanity or Crude Humor | **None** |
| Alcohol, Tobacco, or Drug Use or References | **None** |
| Mature/Suggestive Themes | **None** |
| Horror/Fear Themes | **None** |
| Medical/Treatment Information | **None** |
| Simulated Gambling / Contests / Gambling | **None / No** |
| Unrestricted Web Access | **No** — there is no web view and no network code |
| Built-in advertising | **No** |
| User-generated content, messaging, or chat | **No** |
| Shares user location with other users | **No** |
| In-app purchases | **Yes** — one non-consumable and three tips. Disclosing this does not raise the rating |
| Made for Kids | **No** — leave the Kids Category unset |

Nothing in the app is age-sensitive: no web views, no user-generated content
that leaves the device, no communication of any kind. It rates 4+ on every
answer being the mildest available.

### App Privacy → **Data Not Collected**

The whole section collapses to one answer, and this app earns it more
literally than most:

| Prompt | Answer |
|---|---|
| "Do you or your third-party partners collect any data from this app?" | **No** |
| Every data type (Contact Info, Health, Financial, Location, Sensitive Info, Contacts, User Content, Browsing/Search History, Identifiers, Usage Data, Diagnostics, Purchases, Other) | **not selected** — the "No" above means none of these screens appear |
| Tracking / ATT | **not asked.** The tracking question is downstream of collecting data; with nothing collected it never appears, and the app shows no ATT prompt because there is nothing to ask permission for |
| Third-party SDKs | **none.** No dependencies, no package manager |
| Privacy Policy URL (required even with nothing collected) | `https://github.com/zhangcheng0605/iosPomodoro/blob/claude/pawmodoro-ios-simulator-sf815f/PRIVACY.md` — **pin this to a stable branch or a GitHub Pages URL before submitting;** a link into a working branch will rot |
| Privacy Choices URL | leave empty — not applicable |

**Why this is stronger on the Mac than on iPhone, and worth saying in the
review notes.** On iOS "no network" is a claim about the code. On macOS the
App Sandbox makes it a claim the operating system enforces:
`Pawmodoro/Mac/Pawmodoro.entitlements` contains exactly one key,
`com.apple.security.app-sandbox`, and **not**
`com.apple.security.network.client`. A sandboxed process without that
entitlement cannot open a socket at all — measured, not assumed
(`MAC_APP_STORE.md` § 3.3(c): the same entitlements file applied to a probe
turned a successful `URLSession` GET into "a server with the specified
hostname could not be found"). The signed `.pkg` carries three entitlements
in total: `application-identifier`, `team-identifier`, `app-sandbox`.

Purchases still work, and it is worth knowing why before a reviewer asks:
StoreKit's network happens in Apple's own daemon, and every sandboxed app is
allowed to reach it unconditionally by Apple's default profile. The app talks
to `storekitagent`; it does not talk to the internet.

**One flag, not a listing field.** There is no `PrivacyInfo.xcprivacy` in this
project, and the app uses at least one required-reason API (`UserDefaults`).
That does not affect any answer above and does not block review, but the
upload may return an ITMS-91053 notice about missing API declarations. Worth
deciding on before the upload rather than in the middle of one.

---

## 11. Copyright  (limit 200)

```
2026 Cheng Zhang
```

*(16 characters. No © symbol — Apple adds it.)*

Separately, and not a listing field:
`INFOPLIST_KEY_NSHumanReadableCopyright` is unset for the main target, so the
Mac About box shows no copyright line at all. Cosmetic, will not block
review, and is already on the "should fix" list in `MAC_APP_STORE.md`.

---

## 12. App Review Information (macOS)

**Sign-in required:** leave UNCHECKED. There are no accounts.

**Notes:**

```
Paawmodoro for macOS is the same app as the iOS version, from a single multiplatform SwiftUI target sharing the bundle identifier com.pawmodoro.zhangcheng. Universal Purchase applies: Paawmodoro Plus is a one-time non-consumable already on this app record, and an existing iOS purchase entitles the Mac app.

No account, no sign-in, and no network access. The app is sandboxed with only com.apple.security.app-sandbox — it does not request com.apple.security.network.client, and it makes no network requests of any kind. It can be reviewed entirely with networking disabled. StoreKit works regardless, because the purchase flow runs in the system's StoreKit daemon rather than in the app.

Three things worth knowing so nothing looks broken:

1. TIMERS ARE REAL. A focus session is 25 minutes by default. To see a session complete quickly, open Settings and set Focus to 5 minutes and Short break to 1 minute, or choose the "Sprint 15/3" preset under the ring.

2. MOST CONTENT UNLOCKS OVER TIME BY DESIGN. The field journal, the constellations, the wood, the stray cat and the travel map fill in as focus sessions are completed, so a fresh install is deliberately close to empty. That is the core of the app, not missing content.

3. THE APP CAN RUN WITH ITS WINDOW CLOSED. The countdown continues in the menu bar extra; reopening the window is one item in that menu.

IN-APP PURCHASES: one non-consumable ("Paawmodoro Plus" — 8 additional companions, 4 additional places, the sound library and 6 additional themes) and three consumable tips that unlock nothing. There is no subscription. "Restore purchase" is in Settings under Pawmodoro Plus.

NOTE ON THE NAME: the App Store listing is "Paawmodoro"; the app's own window title, menu bar and About box say "Pawmodoro". This is deliberate — the shorter spelling was unavailable on the App Store — and is the same on both platforms.

All artwork, music and sound in the app is generated for it by scripts in the repository. There is no third-party or licensed content.
```

If the menu-bar bug is still unfixed, delete point 3.

---

## 13. The two awkward facts, and how to phrase them

### The app calls itself Pawmodoro

**Scale, measured:** 21 user-visible string literals in the Swift contain
"Pawmodoro" (Onboarding's "Welcome to Pawmodoro", "Pawmodoro Plus" throughout
the paywall and settings, the postcard filename, the share card's
"Pawmodoro — kept, not scored.", the menu bar's "Open Pawmodoro"). On the Mac
there is a twenty-second, and it is the loudest: `PRODUCT_NAME =
$(TARGET_NAME)` and no `CFBundleDisplayName`, so **the app menu, the window
title and the About box all read "Pawmodoro"** — and unlike iOS, the menu bar
is on screen the entire time the app is running. It is in all eight
screenshots (`MAC_STORE_ASSETS.md` § 2.6).

**Do not fix it by renaming the app.** "Pawmodoro" is the name in the
world — in the postcards people have shared, in the notifications, and in a
year of the owner's own writing. Changing it to match a store constraint
would be the store winning an argument it should not be in.

**Phrase it as a small piece of the app's honesty, not as an apology.** The
description ends with:

> The window says Pawmodoro. The App Store says Paawmodoro, with two a's,
> because the shorter spelling was already taken. Same app.

Four things that does: it is the last thing read, so it never competes with
the pitch; it explains rather than excuses; it matches the voice of an app
whose habit is not to claim things that are not true; and it pre-empts the
one review that would otherwise say "is this the right app?". A reviewer who
notices the mismatch finds it addressed both in the listing and in the notes.

**The alternative, if you would rather it not be in the copy at all:** set
`INFOPLIST_KEY_CFBundleDisplayName = Paawmodoro` for the Mac SDK, so the menu
bar and About box match the Store while the in-app strings stay as they are.
That is a project-file change this document does not make and another
workflow is currently in `project.pbxproj`, so it is a decision, not an edit.

### Universal Purchase — generous, not confusing

The trap is explaining the mechanism. Nobody buying a timer wants to know
what a bundle identifier is; they want to know whether they are about to pay
twice. So **lead with the outcome, and never use the phrase "Universal
Purchase" in customer-facing copy** — it is App Store Connect's word, not a
sentence anyone says.

What the description says, in full:

> **ONE PURCHASE, BOTH MACHINES**
> If you already have Paawmodoro on your iPhone, the Mac app comes with it,
> and so does Plus. One purchase covers both, and it always did.

Why each part earns its place: *"comes with it"* answers the free-download
question before it is asked. *"and so does Plus"* answers the one people
actually worry about. *"and it always did"* is the generous clause — it says
this was the arrangement all along rather than a promotion that could end,
which is the same promise the app makes about everything else it gives you.

What **not** to write: "requires an existing purchase" (it does not — the Mac
app is free to download and the free tier is the whole timer), "sync" (there
is none, and claiming it would be a lie about an app with no network), or
"restores automatically" (it needs the same Apple Account, and `Restore` in
Settings is the button if it does not).

**The one irreversible step this depends on** is in `MAC_APP_STORE.md`
checklist 16, and it is worth repeating here because this copy is void
without it: **Apps → Paawmodoro → Add Platform → macOS.** Not a new app
record. A second record loses Universal Purchase permanently, orphans every
paying iOS customer, and makes the paragraph above false.

---

## 14. Before any of this can be pasted

Not listing work, but this copy is written against an app that has these
fixed. From `MAC_APP_STORE.md`:

| # | Blocker | Effect on this file |
|---|---|---|
| 5 | The macOS app icon | Hard blocker for the submission itself; no copy consequence |
| 6 | The menu bar extra draws the buddy at ~400 pt | Changes the subtitle, the promotional text, the opening paragraph, ON THE MAC, one keyword, and one review note — every swap is written out above |
| 7 | The Scrapbook has no import control on macOS | Why the Scrapbook is absent from the description |
| 9 | The listening pass on real hardware | Sixty-five tracks and nineteen ambiences are advertised above; on iOS, every one of them was unplayable on real devices until build 2 and no simulator could show it |
| — | Screenshots | Eight exist at 1440×900 and none of them can be the menu bar. Re-shoot after 6 |
