"""Check the roster: that everything on it can actually be met.

Wave 4 gated half the journal on the sky, and a weather gate is the first
condition in this app that a player cannot arrange, wait for, or read off a
clock. Every other gate is reachable by deciding something — go to the woods,
sit at dawn, focus for forty minutes. A snow gate is reachable only if it
actually snows at that place, in a window that overlaps the hours the species
is out.

So the question this asks is the one no amount of reading can answer: **how
many days a year is each species reachable at all?** It runs a decade of
`WorldCalendar.seed` through the Python port in `check_weather.py` — the same
port that file's stored fixture already guards — and counts the days on which
each species is eligible somewhere. A creature that comes out for four days a
decade is not rare, it is a tile that never turns over.

It also checks the parts a compiler cannot:

- every species has its four imagesets, and the drawn aspect is roughly the
  aspect `size` lays out with (`scaledToFit` letterboxes the difference);
- nothing stacks a sky gate on top of a full moon or a forty-minute session:
  two conditions you cannot arrange multiply, and the day count above cannot
  see it because it counts days rather than sessions;
- only phenomena are `awardedLate`, and every one that is names the sky it
  waits for — otherwise `lateAward` has nothing to test and it can never be
  handed out at all;
- no note has a number, an exclamation mark, or a sentence about the reader.

    python3 tools/check_species.py

Exits non-zero if anything fails.
"""
import datetime
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import check_weather as weather_check

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")
MODEL = os.path.join(ROOT, "Pawmodoro", "Model")
SPECIES_FILE = os.path.join(MODEL, "Species.swift")

# Days a year a species must be reachable somewhere, averaged over a decade.
#
# Not a rarity floor — rarity is the roll, and a mythic is meant to be almost
# never. This is a *reachability* floor: the number of days on which sitting
# down in the right place at the right hour could possibly show it to you. A
# species below this is gated on a sky that does not happen where it lives.
MINIMUM_DAYS = 8.0

# How far the drawn aspect may differ from the laid-out `size` before
# `scaledToFit` leaves a visible letterbox on one axis.
ASPECT_TOLERANCE = 0.22

YEARS = 10

# The deepest an open hour may have to be before a species turns up.
#
# A lap is one phase length — 25 minutes by default — so four is an hour and
# forty minutes of continuous, uninterrupted sitting. Past that it stops being
# a reward for a long sit and becomes an endurance test, and the Drift's whole
# premise is that there is nothing to endure.
DEEPEST_LAPS = 4


def parse_specs():
    """Every `Spec` row out of `Species.swift`, as a dict per case."""
    source = open(SPECIES_FILE).read()
    body = source.split("var spec: Spec {")[1].split("\n    }\n\n    // MARK")[0]
    rows = {}
    # Each arm runs from `case .name: Spec(` to the next `case .` at that
    # indent, so multi-line rows survive.
    parts = re.split(r"\n        case \.(\w+): Spec\(", body)
    for name, text in zip(parts[1::2], parts[2::2]):
        text = text.split("\n        case .")[0]
        rows[name] = {
            "name": re.search(r'name: "([^"]*)"', text).group(1),
            "note": re.search(r'note: "([^"]*)"', text).group(1),
            "places": re.findall(r"\.(\w+)", _field(text, "places")),
            "dayParts": re.findall(r"\.(\w+)", _field(text, "dayParts")),
            "weathers": re.findall(r"\.(\w+)", _field(text, "weathers") or ""),
            "rarity": re.search(r"rarity: \.(\w+)", text).group(1),
            "size": tuple(float(v) for v in re.search(
                r"size: \.init\(width: ([\d.]+), height: ([\d.]+)\)",
                text).groups()),
            "awardedLate": "awardedLate: true" in text,
            "isPhenomenon": "isPhenomenon: true" in text,
            "passage": (re.search(r"passage: \.(\w+)", text)
                        or _None()).group(1),
            "tides": re.findall(r"\.(\w+)", _field(text, "tides") or ""),
            "deepLaps": int((re.search(r"deepLaps: (\d+)", text)
                             or _Zero()).group(1)),
            "needsFullMoon": "needsFullMoon: true" in text,
            "minimumMinutes": int((re.search(r"minimumMinutes: (\d+)", text)
                                   or _Zero()).group(1)),
        }
    if not rows:
        raise SystemExit("could not parse any Spec rows out of Species.swift")
    return rows


class _Zero:
    def group(self, _):
        return "0"


class _None:
    def group(self, _):
        return None


def _field(text, key):
    """The bracketed list after `key:`, or None."""
    found = re.search(re.escape(key) + r": \[([^\]]*)\]", text)
    return found.group(1) if found else None


def logical_size(asset):
    """The drawn width and height, from the exported PNG."""
    from PIL import Image
    path = os.path.join(ASSETS, f"{asset}.imageset", f"{asset}.png")
    if not os.path.exists(path):
        return None
    width, height = Image.open(path).size
    return width, height


def main():
    specs = parse_specs()
    failures = []

    weights = weather_check.parse_weights()
    rollable = weather_check.parse_rollable()
    winter = weather_check.parse_winter_window()
    if not weights or not rollable:
        raise SystemExit("could not parse Weather.swift")

    # --- 1. Reachability, over a decade of real skies ----------------------
    epoch = datetime.date(2001, 1, 1)
    start = datetime.date(2026, 1, 1)
    days = [(start + datetime.timedelta(days=offset)) for offset in range(365 * YEARS)]

    def month_day(number):
        date = epoch + datetime.timedelta(days=number)
        return (date.month, date.day)

    # Sky per (day, place), computed once — every species then asks the same
    # table rather than re-rolling it forty times.
    skies = {}
    places = sorted({place for spec in specs.values() for place in spec["places"]})
    for date in days:
        number = (date - epoch).days
        for place in places:
            skies[(number, place)] = weather_check.weather_at(
                number, place, weights, rollable, month_day, winter
            )

    # The Flyway's windows, as a set of (year, day-of-year) pairs per passage.
    #
    # Read through `check_flyway.py` rather than re-derived, so there is one
    # port of the window arithmetic in the toolchain instead of two that can
    # disagree. Without this a fortnight would be counted as 365 days and the
    # reachability floor — the whole point of this file — would be blind to
    # the one gate in the app that is genuinely shut most of the year.
    import check_flyway
    passages, salt, place_of_roll = check_flyway.parse_passages()
    open_days = {}
    for name, passage in passages.items():
        span = set()
        for year in range(start.year, start.year + YEARS):
            found = check_flyway.window(passage, year, salt, place_of_roll)
            if found:
                span |= {(year, day) for day in range(found[0], found[1] + 1)}
        open_days[name] = span

    # Tide-gated species are measured in `check_tide.py` instead, at hour
    # granularity, and are skipped here rather than passed with a misleading
    # number. This file counts *days*, and every day has a low water — so the
    # octopus would come out reachable 365 days a year while actually being
    # out for a couple of hours on a dozen afternoons a month. Passing for the
    # wrong reason is worse than not being measured, so the handover is a rule:
    # anything with a `tides:` gate must be in check_tide's table.
    import check_tide
    tide_gated = set(check_tide.parse_gated())
    for name, spec in sorted(specs.items()):
        if spec["tides"] and name not in tide_gated:
            failures.append(
                f"{name} is gated on the tide but check_tide.py does not see "
                f"it — its reachability is measured by nothing")

    # The deep drift. A lap is one phase length, so these are the only species
    # in the app gated on *how* somebody is sitting rather than on where, when
    # or what the sky is doing — and a drift is a decision, which makes it the
    # fairest hard gate here. Right up until it is multiplied by something
    # nobody can arrange, at which point it becomes the worst.
    for name, spec in sorted(specs.items()):
        if not spec["deepLaps"]:
            continue
        stacked = []
        if spec["weathers"]:
            stacked.append("a particular sky")
        if spec["needsFullMoon"]:
            stacked.append("a full moon")
        if spec["passage"]:
            stacked.append("a migration window")
        if spec["tides"]:
            stacked.append("a state of the tide")
        if spec["minimumMinutes"]:
            stacked.append("a minimum session length")
        if stacked:
            failures.append(
                f"{name} needs {spec['deepLaps']} laps of an open hour *and* "
                f"{' and '.join(stacked)} — an hour of drifting is already the "
                f"longest ask in the app and multiplying it by something "
                f"nobody can order makes the species theoretical")
        if spec["deepLaps"] > DEEPEST_LAPS:
            failures.append(
                f"{name} needs {spec['deepLaps']} laps, over the ceiling of "
                f"{DEEPEST_LAPS}. At a default phase length that is over two "
                f"hours of unbroken sitting for one roll of the dice")
        if spec["awardedLate"]:
            failures.append(
                f"{name} is both deep-drift and awarded late — `isEligible` "
                f"returns false for late awards before it ever reads the lap "
                f"count, so the drift gate does nothing")

    thinnest = (10_000.0, None)
    for name, spec in sorted(specs.items()):
        if spec["tides"]:
            continue
        wanted = set(spec["weathers"])
        window = open_days.get(spec["passage"]) if spec["passage"] else None
        if window is not None and not window:
            failures.append(f"{name} is gated on Passage.{spec['passage']}, "
                            f"which never opens — see check_flyway.py")
        candidates = [
            date for date in days
            if window is None
            or (date.year, date.timetuple().tm_yday) in window
        ]
        if not wanted:
            reachable = len(candidates)   # any sky will do
        else:
            reachable = sum(
                1 for date in candidates
                if any(skies[((date - epoch).days, place)] in wanted
                       for place in spec["places"])
            )
        per_year = reachable / YEARS
        if per_year < thinnest[0]:
            thinnest = (per_year, name)
        if per_year < MINIMUM_DAYS:
            failures.append(
                f"{name} is reachable {per_year:.1f} days a year across "
                f"{spec['places']} — that is a tile that never turns over, "
                f"not a rare animal"
            )

    # --- 2. The art ---------------------------------------------------------
    for name, spec in sorted(specs.items()):
        for suffix in ("0", "1", "ghost", "sketch"):
            if logical_size(f"wild_{name}_{suffix}") is None:
                failures.append(f"wild_{name}_{suffix}: missing — run "
                                f"tools/generate_wildlife.py")
        if not spec["isPhenomenon"]:
            if logical_size(f"wild_{name}_regular") is None:
                failures.append(
                    f"wild_{name}_regular: missing — every species that can "
                    f"become an individual needs the marked variant")
        elif logical_size(f"wild_{name}_regular") is not None:
            failures.append(
                f"wild_{name}_regular exists, but a phenomenon is never an "
                f"individual")

        drawn = logical_size(f"wild_{name}_0")
        if drawn:
            laid_out = spec["size"][0] / spec["size"][1]
            actual = drawn[0] / drawn[1]
            drift = abs(actual - laid_out) / laid_out
            if drift > ASPECT_TOLERANCE:
                failures.append(
                    f"{name}: drawn {actual:.2f}:1 but `size` says "
                    f"{laid_out:.2f}:1 ({drift * 100:.0f}% out) — scaledToFit "
                    f"will letterbox it"
                )

    # --- 3. The gates are coherent -----------------------------------------
    for name, spec in sorted(specs.items()):
        if spec["awardedLate"] and not spec["isPhenomenon"]:
            failures.append(f"{name} is awardedLate but not a phenomenon — "
                            f"nothing else should skip the ordinary roll")
        # Deliberately not the other direction. `meteors` and `aurora` are
        # phenomena that *are* rolled normally, because what gates them is
        # where you are and what hour it is — both knowable at the start. Only
        # the ones that depend on what the session did have to wait.
        if spec["awardedLate"] and not spec["weathers"]:
            failures.append(
                f"{name} is awardedLate with no sky named — `lateAward` has "
                f"nothing to test and it can never be awarded")

        # Two unarrangeable gates multiply. The day count above is blind to
        # this: a species available on nine snowy days a year *and* only under
        # a full moon is available on roughly one, and the arithmetic that
        # says so is not in any single row.
        if spec["weathers"] and not spec["awardedLate"]:
            if spec["needsFullMoon"]:
                failures.append(
                    f"{name} needs both a sky and a full moon — neither can be "
                    f"arranged, and together they are not rare, they are off")
            if spec["minimumMinutes"] > 0:
                failures.append(
                    f"{name} needs both a sky and a {spec['minimumMinutes']}-"
                    f"minute session — one gate you cannot arrange is the "
                    f"limit")

    # --- 4. The words -------------------------------------------------------
    for name, spec in sorted(specs.items()):
        for label in ("name", "note"):
            text = spec[label]
            if "!" in text:
                failures.append(f"{name}.{label} has an exclamation mark")
            if label == "note" and any(ch.isdigit() for ch in text):
                failures.append(
                    f"{name}.note contains a number — a field note describes "
                    f"an animal, it does not score one")
            if label == "note" and re.search(r"\byou(r|'ve| have)\b", text):
                failures.append(
                    f"{name}.note is about the reader ('{text}') — the note is "
                    f"about the animal, and the two get confused the moment "
                    f"one row does it")

    print(f"checked {len(specs)} species over {YEARS} years of skies "
          f"({len(skies)} place-days)")
    print(f"thinnest window: {thinnest[1]} at {thinnest[0]:.1f} days a year "
          f"(floor {MINIMUM_DAYS:.0f})")
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
