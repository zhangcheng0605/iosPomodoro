# Monetization: Pawmodoro Plus and the tip jar

Everything is built and wired up in the app. What's left is the App Store Connect
side, which only you can do.

## What's in the app

| Product | Type | Suggested price | What it does |
|---|---|---|---|
| Pawmodoro Plus | Non-consumable | $3.99 | Unlocks 3 buddies, 3 sounds, 3 themes — forever |
| Cup of tea | Consumable | $0.99 | Tip. Unlocks nothing. |
| Bag of treats | Consumable | $2.99 | Tip. Unlocks nothing. |
| Fancy cat bed | Consumable | $5.99 | Tip. Unlocks nothing. |

**Plus contains:** Momo the bunny, Peanut the hamster, Yuzu the fox; forest, café
and ocean ambience; and the Matcha, Cocoa and Midnight themes. The free app keeps
Mochi, Biscuit, rain, purr, fireplace and the Sakura theme — a complete app on its
own, which matters for App Review.

> **This section is out of date.** It describes the app as of Phase G. Since
> then the cast has grown to nine buddies, the wardrobe to eight themes and the
> music to sixty-five tracks — fifty of which Plus opens, and fifteen of which
> nothing does: the Rainy Day Tapes, Night Shift and Soot's Tape are found by
> playing, on identical terms for a Plus owner and a free one. The current
> split is the M section of
> [CONTENT_PLAN.md](CONTENT_PLAN.md), which is authoritative; rewriting this
> table is part of that phase's remaining work, not the stray's.

**Soot is free, and she is the generosity headline.** The stray who turns up in
the hedge and joins you after about a fortnight of showing up costs nothing, is
never mentioned on the paywall, and cannot be bought at any price. That is the
point of her: a buddy you can only get by turning up is worth more as a story
than as a SKU, and it is the honest answer to "what do I get for free?".

## Step 1 — Test it locally first (no account needed)

The repo ships `Pawmodoro.storekit`, a local StoreKit configuration, and the
scheme already points at it. Just run the app in the simulator: the paywall shows
real prices and "buying" works without any App Store Connect setup or money.

If prices don't appear, check **Product → Scheme → Edit Scheme → Run → Options →
StoreKit Configuration** and set it to `Pawmodoro.storekit`.

Useful while testing: **Debug → StoreKit → Manage Transactions** in Xcode lets you
refund or delete a purchase so you can test the locked state again.

## Step 2 — Fix the product identifiers

`Pawmodoro/Store/StoreIDs.swift` uses the prefix
`com.pawmodoro.zhangcheng`. Once you set your real bundle identifier, change these
to match, and change the matching `productID` values in `Pawmodoro.storekit` too.

They don't have to equal your bundle ID, but they must be identical in three
places: `StoreIDs.swift`, `Pawmodoro.storekit`, and App Store Connect. A mismatch
doesn't fail the build — the store just returns nothing and the paywall shows
"The store isn't available right now", which is a maddening bug to chase.

## Step 3 — Banking and tax (required before you can charge)

App Store Connect → **Business**. All three rows must show **Active**:

1. **Paid Applications Agreement** — accept it
2. **Bank account** — in your legal name, in a supported country
3. **Tax forms** — W-9 if you're a US taxpayer, W-8BEN if not

Then apply for the **App Store Small Business Program**: it drops Apple's cut from
30% to 15% for anyone under $1M/year. It is not automatic, and it's the highest
value five minutes in this whole document.

## Step 4 — Create the products

App Store Connect → your app → **Monetization → In-App Purchases → +**

For each product:
- **Type**: Non-Consumable for Plus, Consumable for the three tips
- **Reference Name**: internal only (e.g. "Pawmodoro Plus")
- **Product ID**: must match `StoreIDs.swift` exactly
- **Price**: pick from Apple's price points
- **Display Name** and **Description**: what the user sees. Copy the text from
  `Pawmodoro.storekit` for consistency.
- **Review screenshot**: required. A screenshot of the paywall is fine — take one
  in the simulator with ⌘S.
- For Plus, turn **Family Sharing** on if you want it shared with a family group.
  The `.storekit` file has it on already.

New in-app purchases are reviewed **with** an app version. Attach them to your
build under the version's "In-App Purchases" section, or they'll sit in
"Ready to Submit" forever while you wonder why.

## Step 5 — Sandbox testing on a real device

1. App Store Connect → **Users and Access → Sandbox → Test Accounts** → create one
   (use an email you control that is *not* your Apple ID).
2. On your iPhone: **Settings → Developer → Sandbox Apple Account** → sign in.
3. Run the app from Xcode — but **turn the StoreKit configuration off** first
   (Edit Scheme → Run → Options → StoreKit Configuration → None), otherwise you'll
   keep testing against the local file rather than the real sandbox.

Sandbox purchases are free and can be repeated.

## How the code is organised

| File | Role |
|---|---|
| `Store/StoreIDs.swift` | The product identifiers, in one place |
| `Store/StoreManager.swift` | Loading, buying, restoring, entitlements (StoreKit 2) |
| `Model/PlusLockable.swift` | The `isPlus` protocol that Buddy, Ambience and AppTheme adopt |
| `Views/PaywallView.swift` | The Plus paywall |
| `Views/TipJarView.swift` | The tip jar |
| `Views/PlusPickers.swift` | Pickers that show locked items with a padlock |

A few decisions worth knowing about:

- **Locked content is shown, not hidden.** Seeing Momo greyed out with a padlock
  is what makes the unlock worth buying. Tapping a locked item opens the paywall.
- **Entitlement is re-derived from StoreKit**, not trusted from local storage. The
  cached flag exists only so the UI doesn't flash "locked" during launch.
- **Refunds are handled.** If Plus is revoked, `applyEntitlement(hasPlus:)` moves
  the user back to a free buddy, sound and theme rather than leaving them using
  content they no longer own.
- **Tips are consumables and are finished immediately.** They unlock nothing; the
  app just counts them locally so it can say thank you.
- **Onboarding shows only the free buddies.** A padlock on first launch is a bad
  first impression, and App Review dislikes hard paywalls before any value.

## Realistic expectations

The plumbing is done; discovery is the hard part. A first app with no audience
usually earns tens of dollars, not thousands — plenty never clear the $99/year fee.
Ship free, see whether people actually use it, and let that decide whether the
paid tier is worth promoting.

## Before you submit

- [ ] Real bundle ID set, and `StoreIDs.swift` + `.storekit` updated to match
- [ ] Business section all Active; Small Business Program applied for
- [ ] All four products created in App Store Connect with matching IDs
- [ ] Products attached to the app version being submitted
- [ ] Tested a purchase and a **restore** in sandbox on a real device
- [ ] Tested that the app still works fine having bought nothing
