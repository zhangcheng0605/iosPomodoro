# A promo code that unlocks Plus: is it allowed?

*Researched 8 Aug 2026 against the live App Review Guidelines and Apple's
current developer documentation. Every claim below is either quoted with a
link or flagged as unverified. Nothing here is reassurance — where I could not
confirm something, it says so.*

## Verdict

**No.** An in-app field where somebody types a code you issued yourself, and
Plus unlocks, is the exact thing guideline 3.1.1 names and the exact thing
Apple's own rejection template names — shipping it risks a rejected update
and, if a reviewer reads it as a hidden feature, a 2.3.1 finding on top.
**And you do not need it:** Apple's sanctioned replacement (offer codes) now
covers non-consumables, and for your actual problem — hearing your own audio
on your own phone — a Debug build with `-PawmodoroUnlockPlus` never reaches
App Review at all and costs one line in an Xcode scheme.

---

## 1. What guideline 3.1.1 actually says

From the [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
section 3.1.1, first bullet, quoted verbatim as of 8 Aug 2026:

> If you want to unlock features or functionality within your app, (by way of
> example: subscriptions, in-game currencies, game levels, access to premium
> content, or unlocking a full version), you must use in-app purchase. Apps
> may not use their own mechanisms to unlock content or functionality, such as
> license keys, augmented reality markers, QR codes, cryptocurrencies and
> cryptocurrency wallets, etc.

Two phrases decide this. "**Unlock features or functionality within your
app**" — Plus unlocks buddies, themes, ambience and fifty tracks, which is
squarely it. "**Their own mechanisms**" with "license keys" as the first
example — a code string you generate, ship a validator for, and honour in
`StoreManager` is a license key with different branding. The list ends in
"etc.", so the absence of the word "code" from that sentence buys nothing.

It is not a grey area in practice either. The boilerplate Apple sends on this
rejection, [quoted by a developer in the Apple Developer
Forums](https://developer.apple.com/forums/thread/109627), names promo codes
first:

> Your app unlocks or enables additional functionality with mechanisms such as
> promo codes, data transfer codes, license keys, augmented reality markers,
> or QR codes, which is not appropriate for the App Store.

I did not find, and do not believe there is, a public exception for
"self-issued codes that only give things away for free". The guideline is
about the *mechanism*, not the price. The one adjacent carve-out —
[3.1.3(b) Multiplatform Services](https://developer.apple.com/app-store/review/guidelines/)
— lets users access content **acquired** in your app on other platforms; it
does not cover minting codes, and Pawmodoro has no other platform.

## 2. Apple's sanctioned mechanisms, and which one applies

| Mechanism | What it does | Does it help here? |
|---|---|---|
| **App download promo codes** | 100 per app version, per platform; valid four weeks; free to you; redeemed in the App Store. Gives a **free download of the app**. | No. Pawmodoro is already free to download. This unlocks nothing. |
| **IAP promo codes** | Used to be 100 per IAP, 1,000 per app per six months. | **Gone.** Discontinued 26 March 2026. |
| **Offer codes** | Free or discounted price on a specific IAP, redeemed through Apple's own sheet. Now covers non-consumables. | **Yes — this is the one.** |
| `SKPaymentQueue.presentCodeRedemptionSheet()` | The old in-app sheet. iOS 14+, **deprecated in iOS 18**, and "applies to offer codes only, not promo codes". Subscriptions only on iOS 16 and earlier. | Superseded. Don't build on it. |
| `.offerCodeRedemption(isPresented:onCompletion:)` / `AppStore.presentOfferCodeRedeemSheet(in:)` | The current in-app sheet. iOS 16.0+, deprecated in favour of the `options:` variant at iOS 27. | This is the API if you want the field inside the app. |

**IAP promo codes no longer exist.** Most advice online still recommends them;
it is out of date. From Apple's news post
[*Enhancements to help you submit and market your apps and games*](https://developer.apple.com/news/?id=gf6mgrs6)
(29 Oct 2025):

> Offer codes build on the functionality of promo codes and provide improved
> configuration and customer eligibility options. As a result, starting March
> 26, 2026, you'll no longer be able to create promo codes for In-App
> Purchases in App Store Connect. Any existing promo codes for In-App
> Purchases you've created can be redeemed until they expire. You can continue
> to use promo codes in order to provide people with a free download of your
> app.

The same post says offer codes now cover:

> Consumable, non-consumable, and non-renewing subscriptions.

Apple's StoreKit article
[*Supporting offer codes in your app*](https://developer.apple.com/documentation/storekit/supporting-offer-codes-in-your-app)
confirms the platform floor: auto-renewable subscription offer codes are
iOS 14.2+, and **consumable / non-consumable / non-renewing offer codes are
iOS 16.3+**. Pawmodoro targets iOS 17+, so every user can redeem one.

**So for a one-off non-consumable "Plus", the answer is: offer codes.** They
are Apple's mechanism, not yours, so 3.1.1 is satisfied by construction. Three
ways to redeem, and only the third needs any code at all:

1. A **redemption URL** you send someone. Opens the App Store. Nothing in the app.
2. Typing the code into **Redeem Gift Card or Code** in the App Store.
3. Apple's **redemption sheet inside the app**, via
   `.offerCodeRedemption(isPresented:onCompletion:)`. Apple's doc is explicit:
   "Customers can only redeem these offers in your app through the redemption
   sheet; don't use a custom UI."

That last sentence is the whole distinction. A `TextField` you drew, validated
and honoured is a violation. Apple's sheet, presented from a button, is not —
the redemption happens on Apple's servers and comes back as a real
`Transaction`.

**And that transaction lands in code you already have.** `StoreManager` has a
`Transaction.updates` listener and derives `hasPlus` from
`Transaction.currentEntitlements`. A redeemed non-consumable is a normal
purchase: permanent, restorable, and already handled. No new `StorageKeys`
entry, no new persistence, no new way for the entitlement to be lost. That is
worth more than it sounds — see the trap in section 5.

## 3. The honest risk assessment, if you ship a self-issued code anyway

- **Likelihood of rejection: high, and I'd put it well above half** — but that
  is my judgement, not a measured rate. Nobody publishes rejection statistics.
  What pushes it high is that this is a *named* violation with a canned
  rejection letter, which means reviewers have a checkbox for it, and that a
  redeem field is a visible affordance sitting on a screen a reviewer opens.
- **What rejection costs: a rejected update, not a pulled app.** Version 1.0
  stays on sale. You get a Resolution Center message, you remove the field,
  you resubmit. Realistically a few days.
- **The tail risk is where it stops being cheap.** Hiding the field so App
  Review doesn't find it converts a 3.1.1 problem into a
  [2.3.1](https://developer.apple.com/app-store/review/guidelines/) one:
  "Don't include any hidden, dormant, or undocumented features in your app;
  your app's functionality should be clear to end users and App Review." Its
  own (b) clause says egregious or repeated behaviour is "grounds for removal
  from the Apple Developer Program". The mitigation everybody reaches for
  first — don't advertise it — is the one that makes the downside worse.
- **"Press / reviewer access" wording does not fix it.** It is still your
  mechanism unlocking your IAP. Apple's own answer to giving a reviewer
  access is guideline 2.1: in-app purchases must be "complete, up-to-date,
  visible to the reviewer and functional", and reviewers buy IAPs in sandbox
  for free. They don't need a code.
- **Debug-only genuinely does remove the risk**, because the code is not in
  the Release binary App Review runs. That is not a mitigation of the risk;
  it is the absence of the feature.

Mitigations ranked, if you insist: *(a)* use offer codes instead — this is not
a mitigation, it is the fix; *(b)* Debug-only; *(c)* keep it off the paywall
and out of any screenshot; *(d)* nothing else meaningfully helps.

## 4. What to actually do this week

Your immediate need is hearing fifty tracks and 120 ambience grades on real
hardware — the one thing the Simulator provably cannot tell you, per the
build-2 crash. Three routes, cheapest first:

1. **Debug build over the cable with `-PawmodoroUnlockPlus`.** The flag
   already exists (`LaunchOptions.swift`, and it already has its `#else`
   stand-in, so Release still builds). Edit Scheme → Run → Arguments → add
   `-PawmodoroUnlockPlus`, build to the phone. `refreshEntitlements()` honours
   it before it ever asks StoreKit. With the paid account the build lasts a
   year. **Zero App Review contact, zero new code, works today.**
2. **TestFlight.** Builds run against the sandbox, so buying Plus costs
   nothing — see
   [Testing subscriptions and In-App Purchases in TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight/).
   This gets you a *Release* build, which is the one that matters for the
   audio question, and it also lets a friend hear it.
3. **An offer code**, redeemed on your own phone against the shipping App
   Store build. Only worth setting up when you actually want to hand Plus to
   somebody outside your cable.

**The promo code is worth the risk never, in the self-issued form.** It is
worth *building* — as Apple's redemption sheet — only when you have a real
reason to hand out free Plus at a distance: a press list, a giveaway, a
thank-you to someone who helped. Route 1 solves this week. Route 3 solves that
later want, legally. There is no gap between them that a homemade code fills.

## 5. If you ever do build a redemption path, two traps in this repo

- **"Nothing decays" is not automatic here.** `refreshEntitlements()` ends in
  `updateHasPlus(unlocked)` — an *assignment*, not an OR. Anything that
  granted Plus outside StoreKit and wrote `StorageKeys.hasPlus` would be
  silently revoked on the next launch the moment StoreKit said no. A
  self-issued grant would need its own key in `StorageKeys.all` and
  `hasPlus` would have to become `storeKitSaysYes || redeemed`. Apple's offer
  codes avoid this entirely, because the entitlement *is* a StoreKit
  entitlement. That is the strongest engineering argument for the sanctioned
  path, separately from the legal one.
- **Padlocks and the price table.** Post-redemption every `isUnlocked` caller
  already reads `hasPlus`, so the padlocks go on their own. And a free grant
  of Plus touches neither `Acorns.minutesPerAcorn` nor any `CatalogItem.price`,
  so `check_catalog.py` has nothing to say about it — which is correct, and is
  not a reason to give a code holder acorns instead. The fence there is that
  the bridge between money and the catalogue is Plus, whole and once; a code
  that dropped acorns into a pouch would cross it.

## 6. What I could not verify

- **App Store Connect's own help page still reads subscriptions-only.**
  [Set up offer codes](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-subscription-offer-codes/)
  describes offer codes as auto-renewable-subscription only. The Oct 2025
  news post and the current StoreKit article both say otherwise, and the
  StoreKit article gives the iOS 16.3 floor for non-consumables, so I believe
  the expansion is real and shipped — but the ASC help text has not caught up,
  and I have not seen the ASC UI. **Confirm the non-consumable option exists in
  your account before planning around it.**
- **Sandbox testing of offer codes.** Subscription offer codes historically
  could not be tested in the sandbox. Whether that still holds for
  non-consumable offer codes, I could not confirm.
- **Whether your own Apple ID is eligible** to redeem your own offer code for
  Plus. Offer codes carry eligibility rules; for non-consumables the obvious
  rule is "doesn't already own it", but I did not verify it.
- **Exact limits.** The StoreKit article gives up to 10 active offers and
  1,000,000 codes per app per quarter. App Store Connect may state different
  numbers for non-consumables; check there rather than trusting this line.
- **Rejection likelihood.** Judgement from the guideline text and the
  existence of a canned rejection letter. There is no published rate, and
  anyone who quotes you one is guessing too.
