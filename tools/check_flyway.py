"""Check the Flyway — that every passage happens, and happened when it did.

A migration window is the first gate in this app that a player cannot arrange,
wait for, or read off a clock. Everything else is reachable by deciding
something; the swans are reachable by being alive in late February. That makes
two failure modes that nothing else in the toolchain can see.

**A window that never opens.** A day-of-year arithmetic slip — an off-by-one
in `ordinality`, a drift that pushes an opening past its own closing, a
year-phase that no year satisfies — produces a species that is simply never
eligible, ever, for anybody. The journal shows it with a hint under it and it
is a tile that cannot turn over. Nothing else here counts days.

**A window that moves after the fact.** The dates are rolled from
`WorldCalendar.seed`, which makes them a *promise about the past*: somebody
sat under the geese on 12 November and the almanac will say so next year and
the year after. Change the salt, the drift, or the nominal date and that
afternoon silently becomes a day the geese were not there. So the stored
fixture at the bottom is not a convenience — it is the only thing standing
between a refactor and a rewritten memory.

Everything above the fixture **parses the real values out of `Passage.swift`**
rather than restating them, which is the lesson `check_touch.py` and
`check_yearring.py` each cost once: a checker that carries its own copy of the
numbers verifies that it agrees with itself.

    python3 tools/check_flyway.py

Exits non-zero if anything fails.
"""
import datetime
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import check_weather as weather_check

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.path.join(ROOT, "Pawmodoro", "Model")
PASSAGE = os.path.join(MODEL, "Passage.swift")
SPECIES = os.path.join(MODEL, "Species.swift")
DREAM = os.path.join(MODEL, "Dream.swift")

# `WorldCalendar.dayNumber` counts from this. Ported, not guessed — the Swift
# is `Date(timeIntervalSince1970: 1_577_836_800)`.
EPOCH = datetime.date(2020, 1, 1)

YEARS = range(2024, 2044)

# Days a year a passage must average, over twenty years.
#
# Lower than `check_species.py`'s roster floor of 8 and deliberately so: these
# are meant to be seasonal, and a fortnight is the point. What this catches is
# not "rare" but "never" — a window that comes out empty, or a cycle no year
# satisfies. Ten is one fortnight every other year and nothing real is under it.
MINIMUM_DAYS = 10.0

# Two windows may overlap — several things migrate in autumn — but if every
# one of a passage's days is shared with another, it has no fortnight of its
# own and the almanac's "on the flyway" section never names it alone.
MINIMUM_ALONE = 4


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def strip_comments(text):
    out, i = [], 0
    while i < len(text):
        two = text[i:i + 2]
        if two == "//":
            while i < len(text) and text[i] != "\n":
                i += 1
        elif two == "/*":
            i += 2
            while i < len(text) and text[i:i + 2] != "*/":
                i += 1
            i += 2
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def arms(source, member):
    """The `case .name: value` arms of one computed property, as text."""
    block = re.search(r"var %s:[^{]*\{\s*switch self \{(.*?)\n    \}" % member,
                      source, re.S)
    if not block:
        return {}
    found = {}
    for name, value in re.findall(r"case \.(\w+):\s*(.+?)(?=\n\s*case \.|\Z)",
                                  block.group(1), re.S):
        found[name] = value.strip()
    return found


def parse_passages():
    """Every passage's real window, drift and cycle, out of the Swift."""
    source = strip_comments(read(PASSAGE))
    block = re.search(r"enum Passage[^{]*\{(.*?)\n\n    var id", source, re.S)
    if not block:
        raise SystemExit("Passage.swift: could not find the case list")
    names = re.findall(r"^\s*case (\w+)\s*$", block.group(1), re.M)
    if not names:
        raise SystemExit("Passage.swift: no cases")

    nominal = arms(source, "nominal")
    drift = arms(source, "drift")

    # `everyYears` and `yearPhase` are one-liners rather than switches, so
    # they are read as expressions. Both are parsed rather than assumed: the
    # comet's cycle is the single most breakable number in the file.
    cycle = re.search(r"var everyYears: Int \{ self == \.(\w+) \? (\d+) : 1 \}",
                      source)
    phase = re.search(r"var yearPhase: Int \{ self == \.(\w+) \? (\d+) : 0 \}",
                      source)
    if not cycle or not phase:
        raise SystemExit("Passage.swift: everyYears/yearPhase changed shape — "
                         "this checker can no longer read the cycle")

    # The salt and the place the roll is taken at, read from the call rather
    # than assumed. See the note on `window`.
    call = re.search(r"WorldCalendar\.roll\(\s*day: nominal, place: \.(\w+), "
                     r'salt: "([^"]*)"', source)
    if not call:
        raise SystemExit("Passage.swift: the WorldCalendar.roll call changed "
                         "shape — this checker can no longer read the salt, "
                         "and a port with a stale salt proves nothing")

    passages = {}
    for name in names:
        window = re.search(r"\(\((\d+), (\d+)\), (\d+)\)", nominal.get(name, ""))
        if not window:
            raise SystemExit(f"Passage.{name}: could not read its nominal window")
        month, day, length = (int(v) for v in window.groups())
        passages[name] = {
            "month": month,
            "day": day,
            "length": length,
            "drift": int(re.search(r"(\d+)", drift.get(name, "0")).group(1)),
            "every": int(cycle.group(2)) if name == cycle.group(1) else 1,
            "phase": int(phase.group(2)) if name == phase.group(1) else 0,
            # Carried on the row itself so any caller — check_species.py reads
            # these too — gets a passage that knows its own salt suffix.
            "name": name,
        }
    return passages, call.group(2), call.group(1)


def window(passage, year, salt, place):
    """The Swift's `Passage.window(_:inYearOf:)`, ported.

    `salt` and `place` are passed in because they are **parsed out of the
    Swift**, not written here. Changing either moves every date this feature
    has ever produced, and a port that carried its own copy would happily
    re-derive the new dates and agree with itself — which is the exact way
    `check_touch.py` passed five break tests while proving nothing. With them
    parsed, a changed salt reaches the fixture, and the fixture is what
    notices that somebody's February has moved.
    """
    if year % passage["every"] != passage["phase"]:
        return None
    opening = datetime.date(year, passage["month"], passage["day"])
    start = opening.timetuple().tm_yday
    value = weather_check.roll((opening - EPOCH).days, place,
                               salt.replace("\\(passage.rawValue)", passage["name"]))
    span = passage["drift"] * 2 + 1
    offset = int(value * span) - passage["drift"]
    first = start + offset
    return first, first + passage["length"] - 1


def days_in(year):
    return 366 if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0 else 365


def main():
    passages, salt, place = parse_passages()
    failures = []

    # --- 1. Every window opens, and stays inside its year ------------------
    #
    # A window that runs past 31 December is not wrong arithmetic — it is a
    # window the `contains` check silently truncates, so the passage is short
    # in some years and nobody could see which.
    per_year = {name: 0 for name in passages}
    opened = {name: 0 for name in passages}
    for year in YEARS:
        limit = days_in(year)
        for name, passage in passages.items():
            span = window(passage, year, salt, place)
            if span is None:
                continue
            first, last = span
            opened[name] += 1
            per_year[name] += passage["length"]
            if first < 1:
                failures.append(
                    f"{name} opens on day {first} of {year} — before the year "
                    f"starts, so the drift has pushed it out of its own "
                    f"calendar")
            if last > limit:
                failures.append(
                    f"{name} runs to day {last} of {year}, past the {limit}th "
                    f"— the last {last - limit} days are silently lost and "
                    f"the passage is short that year")

    for name, passage in passages.items():
        if opened[name] == 0:
            failures.append(
                f"{name} never opens in {YEARS.start}–{YEARS.stop - 1}: its "
                f"cycle is every {passage['every']} years at phase "
                f"{passage['phase']}, and no year satisfies that. The species "
                f"is unreachable, forever, for everybody")
            continue
        average = per_year[name] / len(YEARS)
        if average < MINIMUM_DAYS:
            failures.append(
                f"{name} is open {average:.1f} days a year on average — under "
                f"the floor of {MINIMUM_DAYS:.0f}. That is not rare, it is a "
                f"journal entry nobody will meet")

    # --- 2. The dates actually move ----------------------------------------
    #
    # The drift is the difference between a migration and a calendar event. If
    # the roll came out constant — a salt that does not vary, an integer
    # division that always lands on the same value — every window would open
    # on precisely the same date forever and nobody would notice, because each
    # year would look correct on its own.
    for name, passage in passages.items():
        if passage["drift"] == 0:
            continue
        starts = {window(passage, year, salt, place)[0] - datetime.date(
            year, passage["month"], passage["day"]).timetuple().tm_yday
            for year in YEARS if window(passage, year, salt, place)}
        if len(starts) < 3:
            failures.append(
                f"{name} opened at only {len(starts)} distinct offsets across "
                f"{len(YEARS)} years, with a drift of ±{passage['drift']} — "
                f"the dates have stopped breathing and it is an appointment")
        if starts and (min(starts) < -passage["drift"]
                       or max(starts) > passage["drift"]):
            failures.append(
                f"{name} drifted to {min(starts)}..{max(starts)} days, outside "
                f"its own ±{passage['drift']}")

    # --- 3. Each has a fortnight of its own --------------------------------
    for name, passage in passages.items():
        alone = 0
        for year in YEARS:
            span = window(passage, year, salt, place)
            if span is None:
                continue
            others = set()
            for other, spec in passages.items():
                if other == name:
                    continue
                theirs = window(spec, year, salt, place)
                if theirs:
                    others |= set(range(theirs[0], theirs[1] + 1))
            alone += len(set(range(span[0], span[1] + 1)) - others)
        if opened[name] and alone / opened[name] < MINIMUM_ALONE:
            failures.append(
                f"{name} averages only {alone / opened[name]:.1f} days with "
                f"nothing else on the flyway — it is always sharing, and the "
                f"almanac never names it alone")

    # --- 4. Determinism -----------------------------------------------------
    for name, passage in passages.items():
        for year in list(YEARS)[:4]:
            if window(passage, year, salt, place) != window(passage, year, salt, place):
                failures.append(f"{name} in {year} is not deterministic")

    # --- 5. Every passage has exactly one species, and it is gated ----------
    species_source = strip_comments(read(SPECIES))
    gated = re.findall(r"passage: \.(\w+)\)", species_source)
    for name in passages:
        count = gated.count(name)
        if count == 0:
            failures.append(
                f"Passage.{name} has no species — `Passage.species` returns "
                f"nil, so it can never be seen and the almanac can never "
                f"mention it")
        elif count > 1:
            failures.append(
                f"Passage.{name} is claimed by {count} species; "
                f"`Passage.species` returns whichever comes first in "
                f"`allCases`, which is not a decision anybody made")
    for name in set(gated) - set(passages):
        failures.append(f"a species is gated on Passage.{name}, which does "
                        f"not exist")

    # --- 6. Nothing stacks a second unarrangeable gate on the window -------
    #
    # A fortnight is already the hardest condition in the app. A weather gate
    # or a full moon on top of it multiplies two things nobody can arrange,
    # and the day counts above cannot see it — they count *days*, and the
    # question is whether any of those days also had snow.
    for arm in re.findall(r"case \.(\w+): Spec\((.*?)(?=\n        case \.|\n        \}\n)",
                          species_source, re.S):
        name, text = arm
        if "passage: ." not in text:
            continue
        if re.search(r"weathers: \[\.", text):
            failures.append(f"{name} needs both a migration window and a "
                            f"particular sky — two unarrangeable conditions "
                            f"multiplied")
        if "needsFullMoon: true" in text:
            failures.append(f"{name} needs both a migration window and a full "
                            f"moon")
        if "awardedLate: true" in text:
            failures.append(f"{name} is both gated on a passage and awarded "
                            f"late — `isEligible` returns false for late "
                            f"awards before it ever reads the passage, so the "
                            f"window does nothing")

    # --- 7. The dreams point at passages that exist ------------------------
    dream_source = strip_comments(read(DREAM))
    block = re.search(r"enum Flight\b[^{]*\{(.*?)\n    \}\n", dream_source, re.S)
    if not block:
        failures.append("Dream.Flight is gone — the Flyway has no dreams, "
                        "which the standing convention says every feature owes")
    else:
        for target in re.findall(r"case \.\w+: \.(\w+)$", block.group(1), re.M):
            if target not in passages:
                failures.append(f"Dream.Flight reaches for Passage.{target}, "
                                f"which does not exist")

    # --- 8. The fixture: dates somebody has already stood under ------------
    for year, name, first, last in FIXTURE:
        passage = passages.get(name)
        if passage is None:
            failures.append(f"FIXTURE names Passage.{name}, which is gone — "
                            f"if it was retired, retire its rows too")
            continue
        got = window(passage, year, salt, place)
        if got != (first, last):
            failures.append(
                f"FIXTURE: {name} in {year} used to run days {first}–{last} "
                f"and now runs {got}. Somebody sat under that passage on one "
                f"of those days and the almanac has just changed its mind "
                f"about when it happened. See the note above FIXTURE.")

    total = sum(per_year.values()) / len(YEARS)
    print(f"checked {len(passages)} passages over {len(YEARS)} years — "
          f"{total:.0f} flyway days a year between them, "
          f"{len(FIXTURE)} fixture rows")
    if failures:
        print(f"\n{len(failures)} FAILED:")
        for line in failures:
            print(f"  {line}")
        return 1
    print("all pass")
    return 0


# Windows that have already happened, as far as anybody using the app is
# concerned.
#
# Generated once from the implementation and frozen — the shape every
# date-rolled feature in this app now carries, and the only half of this file
# that can notice the *right* kind of breakage. Everything above parses the
# real numbers out of `Passage.swift`, which makes it self-consistent: change
# the drift and every rule above happily re-derives itself against the new
# drift and passes. Only these rows notice, and what they notice is that a
# morning somebody remembers has moved.
#
# If a row here fails, the question is never "how do I update the fixture". It
# is "am I willing to rewrite somebody's February". Regenerate only when the
# answer is yes and say so in the commit message.
FIXTURE = (
    (2026, "comet", 197, 236),
    (2026, "cuckoo", 113, 130),
    (2026, "paintedladies", 159, 175),
    (2026, "redwings", 292, 308),
    (2026, "salmon", 265, 282),
    (2026, "snowgeese", 311, 327),
    (2026, "swans", 57, 73),
    (2026, "waxwings", 23, 34),
    (2027, "snowgeese", 315, 331),
    (2027, "swans", 52, 68),
    (2027, "waxwings", 24, 35),
    (2029, "snowgeese", 306, 322),
    (2029, "swans", 53, 69),
    (2029, "waxwings", 27, 38),
    (2030, "comet", 226, 265),
    (2030, "snowgeese", 318, 334),
    (2030, "swans", 51, 67),
    (2030, "waxwings", 26, 37),
    (2034, "comet", 225, 264),
    (2034, "snowgeese", 313, 329),
    (2034, "swans", 50, 66),
    (2034, "waxwings", 17, 28),
)


if __name__ == "__main__":
    sys.exit(main())
