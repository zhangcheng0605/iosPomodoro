"""Check that the weather actually rolls the way `Weather.swift` says it does.

The weather is a pure function of the calendar day and the place, so it is one
of the very few things in this app that can be checked *completely* without a
Mac: run every day of a decade at every place and count what came out.

That matters more than it sounds. The roll is a weighted walk over an
accumulating ticket, which is the classic place to be off by one — and the
symptom would be that one weather never happens at all, or happens twice as
often as intended, for years, silently. Nobody would notice from inside the
app; a storm that is one day in fifteen instead of one in thirty just feels
like a stormy month.

What is checked:

  * the declared weights are parts per thousand and sum to exactly 1000
  * `rollable` names exactly the weathers with a non-zero weight
  * the observed frequency of each weather matches its weight, inside a
    four-sigma binomial bound
  * `golden` falls on exactly the days after a storm, and never any other day
  * two golden days never run together — the claim that the one-day lookback
    cannot recurse
  * `snow` only ever falls inside the snow season's own window
  * the same day and place always give the same answer

The weights and the winter window are parsed out of the Swift rather than
copied, so this cannot quietly drift from what ships. The seed function is a
port of `WorldCalendar.seed` and is marked as such — if that ever changes,
this file changes with it, and both of them are compatibility contracts.

    python3 tools/check_weather.py

Exits non-zero if anything fails.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.path.join(ROOT, "Pawmodoro", "Model")

PLACES = ("meadow", "woods", "harbor", "blossom",
          "keep", "cloudspire", "peaks", "onsen")

# Ten years of every place. Enough that a 3.3% weather still lands ~960 times,
# which is enough for the frequency bound below to mean something.
DAYS = 3650

# --- The compatibility contract --------------------------------------------
#
# Everything else here parses the weights out of `Weather.swift` and then
# checks the roll against them, which is self-consistent by construction: swap
# two weights and the whole file still passes, because it now believes the new
# weights. That was found by deliberately swapping `mist` and `overcast` and
# watching nothing happen.
#
# This table is the answer. It was generated once from the shipping
# implementation and is asserted forever after. Weather is a pure function of
# the date, which means it is also a *promise about the past*: change a weight,
# reorder `rollable`, or touch `WorldCalendar.seed`, and the storm somebody
# remembers sitting through last March silently becomes an overcast afternoon.
# Every row here is one such memory.
#
# So: if this fails, the question is not "how do I update the fixture" — it is
# "did I mean to rewrite everybody's weather". Almost always the answer is no.
# The rows cover all nine weathers, on purpose.
FIXTURE = (
    (0, "cloudspire", "breeze"),
    (0, "harbor", "clear"),
    (0, "meadow", "clear"),
    (0, "peaks", "golden"),
    (1, "harbor", "clear"),
    (1, "meadow", "mist"),
    (1, "peaks", "clear"),
    (1, "woods", "overcast"),
    (2, "cloudspire", "drizzle"),
    (2, "keep", "rain"),
    (12, "blossom", "storm"),
    (336, "onsen", "snow"),
    (365, "harbor", "clear"),
    (365, "meadow", "snow"),
    (365, "peaks", "breeze"),
    (1000, "harbor", "breeze"),
    (1000, "meadow", "overcast"),
    (1000, "peaks", "clear"),
    (2500, "harbor", "mist"),
    (2500, "meadow", "drizzle"),
    (2500, "peaks", "clear"),
    (3999, "harbor", "breeze"),
    (3999, "meadow", "mist"),
    (3999, "peaks", "golden"),
)

MASK = 0xFFFF_FFFF_FFFF_FFFF


# --- A port of WorldCalendar.seed ------------------------------------------
#
# Written out rather than imported, because there is nothing to import from:
# this is the Swift, in Python. It is a compatibility contract on both sides —
# changing either one silently rewrites everybody's weather, past and future —
# so if one moves, the other moves in the same commit.

def _mix(value):
    """splitmix64's finaliser."""
    z = (value + 0x9E37_79B9_7F4A_7C15) & MASK
    z = ((z ^ (z >> 30)) * 0xBF58_476D_1CE4_E5B9) & MASK
    z = ((z ^ (z >> 27)) * 0x94D0_49BB_1331_11EB) & MASK
    return z ^ (z >> 31)


def seed(day_number, place, salt=""):
    """FNV-1a over "<day>|<place>|<salt>", then splitmix64."""
    hash_ = 0xCBF2_9CE4_8422_2325
    for chunk in (str(day_number).encode(), b"|", place.encode(), b"|",
                  salt.encode()):
        for byte in chunk:
            hash_ ^= byte
            hash_ = (hash_ * 0x1000_0000_01B3) & MASK
    return _mix(hash_)


def roll(day_number, place, salt=""):
    """A uniform value in 0..<1 — the top 53 bits, as the Swift does."""
    return (seed(day_number, place, salt) >> 11) / float(1 << 53)


# --- What the Swift says ---------------------------------------------------

def parse_weights():
    """`case .clear: 450` out of Weather.weight."""
    source = open(os.path.join(MODEL, "Weather.swift")).read()
    body = source.split("var weight: Int {")[1].split("\n    }")[0]
    weights = {}
    for names, value in re.findall(r"case ([^:]+): (\d+)", body):
        for name in re.findall(r"\.(\w+)", names):
            weights[name] = int(value)
    return weights


def parse_rollable():
    """The fixed order the roll walks."""
    source = open(os.path.join(MODEL, "Weather.swift")).read()
    block = source.split("static let rollable: [Weather] = [")[1].split("]")[0]
    return re.findall(r"\.(\w+)", block)


def parse_winter_window():
    """`case .winter: ((12, 1), (12, 31))` out of Season.window."""
    source = open(os.path.join(MODEL, "Season.swift")).read()
    match = re.search(
        r"case \.winter: \(\((\d+), (\d+)\), \((\d+), (\d+)\)\)", source
    )
    if not match:
        return None
    a, b, c, d = (int(g) for g in match.groups())
    return (a, b), (c, d)


# --- The roll, as Weather.at does it ---------------------------------------

def rolled(day_number, place, weights, rollable):
    total = sum(weights[name] for name in rollable)
    ticket = int(roll(day_number, place, "weather") * total)
    for name in rollable:
        ticket -= weights[name]
        if ticket < 0:
            return name
    return "clear"


def weather_at(day_number, place, weights, rollable, month_day, winter):
    today = rolled(day_number, place, weights, rollable)
    if today != "storm" and rolled(
        day_number - 1, place, weights, rollable
    ) == "storm":
        return "golden"
    if (winter and today in ("rain", "drizzle")
            and in_window(month_day(day_number), winter)):
        return "snow"
    return today


def in_window(month_and_day, window):
    (from_month, from_day), (to_month, to_day) = window
    today = month_and_day[0] * 100 + month_and_day[1]
    return from_month * 100 + from_day <= today <= to_month * 100 + to_day


def main():
    import datetime

    failures = []
    weights = parse_weights()
    rollable = parse_rollable()
    winter = parse_winter_window()

    if not weights or not rollable:
        print("could not parse Weather.swift", file=sys.stderr)
        return 1

    # 1. Parts per thousand, and they had better be a thousand.
    total = sum(weights[name] for name in rollable)
    if total != 1000:
        failures.append(
            f"the rollable weights sum to {total}, not 1000 — the doc comment "
            f"calls them parts per thousand and the odds in the plan are read "
            f"as percentages"
        )

    # 2. Rollable is exactly the non-zero weights.
    non_zero = {name for name, value in weights.items() if value > 0}
    if non_zero != set(rollable):
        failures.append(
            f"rollable is {sorted(rollable)} but the non-zero weights are "
            f"{sorted(non_zero)} — one of them can never come out, or one "
            f"comes out with weight zero and never wins"
        )

    # `WorldCalendar.dayNumber` counts from 2020-01-01, so day 0 is that date
    # and every day number maps to a real calendar day.
    epoch = datetime.date(2020, 1, 1)

    def month_day(day_number):
        date = epoch + datetime.timedelta(days=day_number)
        return (date.month, date.day)

    # 3. The rules, checked exactly rather than statistically.
    #
    # The distribution below is measured on the raw roll and the substitutions
    # are checked as rules here. Mixing the two is what made the first version
    # of this file need an approximate expectation for every weather — golden
    # displaces some of each, snow displaces part of two of them for a month a
    # year — and an approximate expectation is one nobody can be sure of.
    counts = {}
    shown = {}
    samples = len(PLACES) * DAYS
    for place in PLACES:
        previous = None
        for day in range(DAYS):
            today = rolled(day, place, weights, rollable)
            yesterday = rolled(day - 1, place, weights, rollable)
            name = weather_at(day, place, weights, rollable, month_day, winter)
            counts[today] = counts.get(today, 0) + 1
            shown[name] = shown.get(name, 0) + 1

            wintry = winter and in_window(month_day(day), winter)
            if today != "storm" and yesterday == "storm":
                expected = "golden"
            elif today in ("rain", "drizzle") and wintry:
                expected = "snow"
            else:
                expected = today
            if name != expected:
                failures.append(
                    f"{place} day {day}: rolled {today} after {yesterday}"
                    f"{' in the snow season' if wintry else ''}, expected "
                    f"{expected}, got {name}"
                )
            if name == "golden" and previous == "golden":
                failures.append(
                    f"{place} day {day}: two golden days running — the "
                    f"one-day lookback has started to recurse"
                )
            if name == "snow" and not wintry:
                failures.append(
                    f"{place} day {day} ({month_day(day)}): snow outside the "
                    f"snow season"
                )
            previous = name

    # A storm must never be swallowed: every rolled storm has to reach the
    # screen. This is the bug this file was written and immediately caught —
    # golden used to win outright, so the second of two storms was shown as
    # sunshine and the rarest weather in the app quietly went missing.
    if shown.get("storm", 0) != counts.get("storm", 0):
        failures.append(
            f"{counts.get('storm', 0)} storms rolled but only "
            f"{shown.get('storm', 0)} were shown — something is overwriting "
            f"the rarest weather in the table"
        )

    # 4. Frequencies of the raw roll. A four-sigma binomial bound: tight
    #    enough to catch a misplaced weight, loose enough never to fail on
    #    luck.
    for name in rollable:
        expected = weights[name] / 1000.0
        sigma = (expected * (1 - expected) / samples) ** 0.5
        actual = counts.get(name, 0) / samples
        if abs(actual - expected) > 4 * sigma:
            failures.append(
                f"{name} rolled {actual * 100:.2f}% of the time, expected "
                f"{expected * 100:.2f}% (+/- {4 * sigma * 100:.2f})"
            )

    # 5. The fixture: has anybody's past weather changed?
    for day, place, expected in FIXTURE:
        actual = weather_at(day, place, weights, rollable, month_day, winter)
        if actual != expected:
            failures.append(
                f"FIXTURE: {place} on day {day} used to be {expected} and is "
                f"now {actual} — this rewrites weather that has already "
                f"happened for real users. See the note above FIXTURE."
            )

    # 6. Determinism. The whole promise of not using Swift's Hasher.
    for place in PLACES[:2]:
        for day in (0, 1, 999, 3000):
            first = weather_at(day, place, weights, rollable, month_day, winter)
            again = weather_at(day, place, weights, rollable, month_day, winter)
            if first != again:
                failures.append(f"{place} day {day} rolled twice, differently")

    print(f"checked {samples} place-days across {len(PLACES)} places "
          f"({DAYS} days each)")
    order = sorted(shown.items(), key=lambda kv: -kv[1])
    print("  as shown: "
          + ", ".join(f"{n} {c / samples * 100:.1f}%" for n, c in order))
    if failures:
        print(f"\n{len(failures)} FAILED:")
        for line in failures[:20]:
            print(f"  {line}")
        if len(failures) > 20:
            print(f"  … and {len(failures) - 20} more")
        return 1
    print("all pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
