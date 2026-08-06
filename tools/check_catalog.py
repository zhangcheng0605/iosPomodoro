"""Check the economy: that it is honest, and that it stays the economy it was.

Every other checker in this repo guards a picture or a promise about the past.
This one guards a promise about *money*, which is the only kind a user can be
cheated by — and the cheats are all silent. A price that creeps up, a divisor
that quietly halves everybody's savings, an item on a shelf with no art behind
it: none of those crash, none of them look wrong in a screenshot, and every
one of them is a person who trusted the app being taken from.

So this holds the two numbers that decide what somebody's history is worth,
against a stored fixture generated once:

- **`Acorns.minutesPerAcorn`.** Moving it re-prices every hour anybody has
  ever focused. Raising it is a devaluation applied retroactively to people
  who are not in the room.
- **Every price in `CatalogItem`.** A price may fall — that is a gift, and
  everybody who already paid keeps the thing. It may never rise, because
  somebody three afternoons from the fox would lose those three afternoons
  and there is no notification, patch note or refund that repairs it.

The fixture is not a snapshot to be regenerated when it complains. If it
fails, the question is "did I mean to take something off somebody", and the
answer is almost always no.

On top of that, the parts a compiler cannot see: every catalogue item has art
to draw and a shelf to sit on, the earn rate and the prices are still in the
same universe as each other, and the two rules the fences turn into arithmetic
— the whole hoard has to cost more than any single thing is worth waiting for,
and no single thing may cost more than a season.

    python3 tools/check_catalog.py

Exits non-zero if anything fails.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")
MODEL = os.path.join(ROOT, "Pawmodoro", "Model")

# --- The contract ----------------------------------------------------------
#
# Generated once from the shipping values. See the note above before touching
# a single number here.
FIXTURE_DIVISOR = 20
FIXTURE_PRICES = {
    "buddy": 120,
    "place": 150,
    "theme": 40,
}

# What a steady user earns in a day, for the sanity sums below: two hours of
# focus at the shipping divisor. Not parsed, because it is an assumption about
# people rather than a value in the code — and it is written down here so the
# assumption is arguable instead of implicit.
DAILY_MINUTES = 120

# No single item may cost more than this many days of that. Past a season, the
# free road stops being a road and becomes a decoration on the paywall.
MAXIMUM_DAYS_FOR_ONE = 95

# The whole hoard must cost at least this many, or Plus has no argument.
MINIMUM_DAYS_FOR_ALL = 180


def parse_divisor():
    source = open(os.path.join(MODEL, "Acorns.swift")).read()
    found = re.search(r"static let minutesPerAcorn = (\d+)", source)
    if not found:
        raise SystemExit("could not parse Acorns.minutesPerAcorn")
    return int(found.group(1))


def parse_prices():
    """The real price table, out of `CatalogItem.price`."""
    source = open(os.path.join(MODEL, "CatalogItem.swift")).read()
    body = source.split("var price: Int {")[1].split("\n    }")[0]
    found = re.findall(r"case \.(\w+): (\d+)", body)
    if not found:
        raise SystemExit("could not parse CatalogItem.price")
    return {kind: int(price) for kind, price in found}


def parse_locked(enum_file, enum_name):
    """Which cases of an enum are `isPlus`, out of the real `isPlus` switch.

    Both shapes the app uses are handled: an explicit two-arm switch, and the
    `default: true` form `AppTheme` uses. Parsing rather than listing, because
    a hand-kept list of Plus buddies is exactly the thing that goes stale the
    day somebody adds a buddy.
    """
    source = open(os.path.join(MODEL, enum_file)).read()
    cases = re.findall(r"^    case (\w+)$", source, re.M)
    if not cases:
        cases = [c.strip() for line in re.findall(r"^    case ([\w, ]+)$", source, re.M)
                 for c in line.split(",")]
    body = source.split("var isPlus: Bool {")[1].split("\n    }")[0]

    free, plus = set(), set()
    for labels, value in re.findall(r"case ((?:\.\w+,?\s*)+): (true|false)", body):
        target = plus if value == "true" else free
        target.update(re.findall(r"\.(\w+)", labels))
    fallback = re.search(r"default: (true|false)", body)
    if fallback:
        rest = set(cases) - free - plus
        (plus if fallback.group(1) == "true" else free).update(rest)
    return [c for c in cases if c in plus]


def imageset_exists(name):
    return os.path.isdir(os.path.join(ASSETS, f"{name}.imageset"))


def main():
    failures = []
    divisor = parse_divisor()
    prices = parse_prices()

    # --- 1. The contract ---------------------------------------------------
    if divisor != FIXTURE_DIVISOR:
        direction = "devalues" if divisor > FIXTURE_DIVISOR else "inflates"
        failures.append(
            f"FIXTURE: Acorns.minutesPerAcorn was {FIXTURE_DIVISOR} and is now "
            f"{divisor} — that {direction} every hour anybody has ever focused, "
            f"retroactively. See the note above FIXTURE_DIVISOR."
        )
    for kind, was in sorted(FIXTURE_PRICES.items()):
        now = prices.get(kind)
        if now is None:
            failures.append(f"FIXTURE: the price for '{kind}' has vanished")
        elif now > was:
            failures.append(
                f"FIXTURE: a {kind} cost {was} acorns and now costs {now} — a "
                f"price may fall, never rise. Somebody was saving for this."
            )
    for kind in sorted(set(prices) - set(FIXTURE_PRICES)):
        failures.append(
            f"'{kind}' is a new kind of item with no fixture row — add one, "
            f"and it is frozen from then on"
        )

    # --- 2. Everything on a shelf has art to draw and a name ---------------
    buddies = parse_locked("Buddy.swift", "Buddy")
    places = parse_locked("Place.swift", "Place")
    themes = parse_locked("AppTheme.swift", "AppTheme")

    # Soot is Plus-gated but never for sale, and `Buddy.catalogItem` says so.
    # Parse that exclusion rather than restating it.
    catalog_source = open(os.path.join(MODEL, "CatalogItem.swift")).read()
    if "self != .stray" not in catalog_source:
        failures.append(
            "Buddy.catalogItem no longer excludes the stray — Soot is not for "
            "sale at any price, and putting a number on her would make the "
            "only story in this app into a transaction")
    buddies = [b for b in buddies if b != "stray"]

    # `Buddy.awakeAssetName` — the pose the unlock sheet and every picker draw.
    for buddy in buddies:
        if not imageset_exists(f"buddy_{buddy}_awake"):
            failures.append(
                f"buddy '{buddy}' is on the shelf with nothing to draw in the "
                f"unlock sheet")
    for place in places:
        if not imageset_exists(f"scene_{place}_day"):
            failures.append(
                f"place '{place}' is on the shelf but has no day scene to show "
                f"in the unlock sheet")
    for name in ("acorn", "magpie_0", "magpie_1", "cart_0", "cart_1"):
        if not imageset_exists(name):
            failures.append(f"{name}: missing — run tools/generate_magpie.py")

    # --- 3. The two fences that are arithmetic ------------------------------
    per_day = DAILY_MINUTES / divisor
    counts = {"buddy": len(buddies), "place": len(places), "theme": len(themes)}
    total = sum(prices[kind] * count for kind, count in counts.items()
                if kind in prices)

    dearest = max(prices.values()) if prices else 0
    days_for_one = dearest / per_day
    days_for_all = total / per_day

    if days_for_one > MAXIMUM_DAYS_FOR_ONE:
        failures.append(
            f"the dearest single item is {days_for_one:.0f} days of steady use "
            f"away — past a season the free road is decoration on the paywall, "
            f"not an alternative to it")
    if days_for_all < MINIMUM_DAYS_FOR_ALL:
        failures.append(
            f"the whole catalogue is only {days_for_all:.0f} days away — Plus "
            f"has no argument to make, and the cart eats the purchase it is "
            f"supposed to advertise")

    # --- 4. The fences that are code ---------------------------------------
    post = open(os.path.join(MODEL, "SundayPost.swift")).read()
    if ".trade" not in post.split("silentKinds")[1].split("\n")[0] + \
            post.split("silentKinds")[1].split("]")[0]:
        failures.append(
            "ChronicleEvent.Kind.trade is not in SundayPost.silentKinds — the "
            "letter is not a receipt")

    pouch = open(os.path.join(MODEL, "Pouch.swift")).read()
    if re.search(r"\bowned\.remove\b|\bowned = \[\]|owned\.removeAll", pouch):
        failures.append(
            "something removes an id from the pouch — nothing bought is ever "
            "lost, by any path except deleting the app")

    ids = open(os.path.join(ROOT, "Pawmodoro", "Store", "StoreIDs.swift")).read()
    if re.search(r"acorn|coin|currency|pack", ids, re.I):
        failures.append(
            "StoreIDs mentions a currency product — acorns are never sold for "
            "money. The bridge between cash and the catalogue is Plus, whole, "
            "once.")

    print(f"checked {sum(counts.values())} items across {len(prices)} kinds "
          f"at {divisor} minutes an acorn")
    print(f"the dearest single thing: {days_for_one:.0f} days of steady use; "
          f"the lot: {days_for_all:.0f} days ({total} acorns)")
    if failures:
        unique = sorted(set(failures))
        print(f"\n{len(unique)} FAILED:")
        for line in unique[:20]:
            print(f"  {line}")
        if len(unique) > 20:
            print(f"  ... and {len(unique) - 20} more")
        return 1
    print("all pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
