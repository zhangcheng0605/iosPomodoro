"""Check Tidewater — that the sea moves, and that the shore is reachable.

The tide is the first thing in this app that changes on the scale of **hours**.
Everything else — weather, seasons, passages, the moon — is a day gate, and
`check_species.py` answers "how many days a year is this reachable" by counting
days. That question is meaningless here: every day has a low water, so a
day-counting checker would report the octopus as reachable 365 days a year
while it is in fact out for ninety minutes on about a dozen afternoons a month,
and only some of those in daylight.

So this file asks the question at **hour granularity**, and it asks the one
that actually matters: *how many hours a year is each tide-gated species
eligible, in a day part it is allowed to appear in?* A creature that needs a
spring low at dawn is not rare, it is arithmetic that never lines up.

Four other things nothing else can see:

**That the sea moves at all.** A sign slip in the phase, a period in the wrong
unit, `MoonPhase.age` returning a constant — any of them produces a tide that
is simply always at half water. Every gate would still pass, every species
would still be eligible some of the time, and the harbour would just never
change. Checked by measuring the actual range over a decade.

**That springs are springs.** The whole model is that the range opens at new
and full moon and closes at the quarters. If `abs` went missing from the
springness term, springs would happen at new moon only and never at full — a
halving of the shore's availability that nothing on screen would show.

**That the shore strip stays out of the text.** `TideView` draws between 0.79
and 0.88 of the screen's height and the lowest text row in the app is the paw
capsule at 0.718. Seven points of clearance is exactly the margin a later
redesign eats without meaning to, and `check_contrast.py` samples the *scene
exports* rather than SwiftUI overlays, so it would never notice.

**That today's tide is still the tide it was.** Stored fixture, like every
other date-rolled thing here. Change `establishment` or `period` and every tide
this app has ever shown moves.

    python3 tools/check_tide.py

Exits non-zero if anything fails.
"""
import datetime
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.path.join(ROOT, "Pawmodoro", "Model")
TIDE = os.path.join(MODEL, "Tide.swift")
SPECIES = os.path.join(MODEL, "Species.swift")
MOON = os.path.join(MODEL, "MoonPhase.swift")
THEME = os.path.join(ROOT, "Pawmodoro", "Theme.swift")
TIDEVIEW = os.path.join(ROOT, "Pawmodoro", "Views", "TideView.swift")
CONTRAST = os.path.join(ROOT, "tools", "check_contrast.py")

YEARS = 10

# Hours a year a tide-gated species must be eligible, counting only hours in a
# day part it is allowed to appear in.
#
# A session is 25 minutes, so an hour of eligibility is roughly two chances.
# Two hundred hours a year is about half an hour a day on average — thin, and
# meant to be, but findable by somebody who sits at the harbour in the
# afternoons. Below that it is not an animal, it is a coincidence.
MINIMUM_HOURS = 200.0

# `DayPart.from(hour:)` — ported, and checked against the Swift below so it
# cannot drift. Night is the `default` arm rather than a written range, so it
# is the complement of the other three and is derived rather than parsed.
DAY_PARTS = {"dawn": (5, 8), "day": (8, 17), "dusk": (17, 21), "night": (21, 5)}


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


def parse_tide():
    """Every number in the model, out of the Swift."""
    source = strip_comments(read(TIDE))

    period = re.search(r"static let period: TimeInterval = "
                       r"(\d+) \* 3600 \+ (\d+) \* 60 \+ (\d+)", source)
    establishment = re.search(r"static let establishment: TimeInterval = "
                              r"(\d+) \* 3600", source)
    reference = re.search(r"private static let reference = "
                          r"Date\(timeIntervalSince1970: ([\d_]+)\)", source)
    swing = re.search(r"let range = ([\d.]+) \+ ([\d.]+) \* springness", source)
    if not all((period, establishment, reference, swing)):
        raise SystemExit("Tide.swift: the model changed shape — this checker "
                         "can no longer read it, and a port with stale numbers "
                         "proves nothing")

    floors = {}
    block = re.search(r"var floor: Double \{\s*switch self \{(.*?)\n        \}",
                      source, re.S)
    # `-?` matters. Without it a floor edited to a negative number simply does
    # not match, the state drops out of the table, and this checker crashes
    # somewhere else entirely with a KeyError — which is the least useful way
    # for a checker to notice something. Found by break-testing.
    for name, value in re.findall(r"case \.(\w+): (-?[\d.]+)", block.group(1)):
        floors[name] = float(value)
    states = set(re.findall(r"^        case (\w+)$",
                            source.split("enum State")[1].split("var floor")[0],
                            re.M))
    missing = states - set(floors)
    if missing:
        raise SystemExit(f"Tide.State {sorted(missing)} have no parseable "
                         f"floor — the switch changed shape and this checker "
                         f"would have gone half-blind rather than failing")

    waterline = re.search(r"static let waterline: \(lowest: Double, "
                          r"highest: Double\) = \(([\d.]+), ([\d.]+)\)", source)

    return {
        "period": (int(period.group(1)) * 3600 + int(period.group(2)) * 60
                   + int(period.group(3))),
        "establishment": int(establishment.group(1)) * 3600,
        "reference": int(reference.group(1).replace("_", "")),
        "base": float(swing.group(1)),
        "span": float(swing.group(2)),
        "floors": floors,
        "waterline": (float(waterline.group(1)), float(waterline.group(2))),
    }


def parse_moon():
    """`MoonPhase`'s reference and synodic month, out of the Swift."""
    source = strip_comments(read(MOON))
    reference = re.search(r"private static let reference = "
                          r"Date\(timeIntervalSince1970: ([\d_]+)\)", source)
    synodic = re.search(r"private static let synodic = ([\d_.]+)", source)
    if not reference or not synodic:
        raise SystemExit("MoonPhase.swift changed shape")
    return (int(reference.group(1).replace("_", "")),
            float(synodic.group(1).replace("_", "")))


def moon_age(epoch_seconds, moon):
    reference, synodic = moon
    days = (epoch_seconds - reference) / 86400
    return (days / synodic) % 1.0


def level(epoch_seconds, model, moon):
    springness = abs(math.cos(2 * math.pi * moon_age(epoch_seconds, moon)))
    span = model["base"] + model["span"] * springness
    elapsed = epoch_seconds - model["reference"] - model["establishment"]
    swing = math.cos(2 * math.pi * elapsed / model["period"])
    return 0.5 + swing * span / 2


def state(water, floors):
    for name in ("high", "mid", "low", "springLow"):
        if water >= floors[name]:
            return name
    return "springLow"


def parse_gated():
    """Every species with a `tides:` gate, with its day parts."""
    source = strip_comments(read(SPECIES))
    body = source.split("var spec: Spec {")[1].split("\n    }\n\n    // MARK")[0]
    rows = {}
    parts = re.split(r"\n        case \.(\w+): Spec\(", body)
    for name, text in zip(parts[1::2], parts[2::2]):
        text = text.split("\n        case .")[0]
        tides = re.search(r"tides: \[([^\]]*)\]", text)
        if not tides:
            continue
        rows[name] = {
            "tides": re.findall(r"\.(\w+)", tides.group(1)),
            "dayParts": re.findall(r"\.(\w+)",
                                   (re.search(r"dayParts: \[([^\]]*)\]", text)
                                    or _Empty()).group(1)),
        }
    return rows


class _Empty:
    def group(self, _):
        return ""


def in_part(hour, part):
    start, end = DAY_PARTS[part]
    if start < end:
        return start <= hour < end
    return hour >= start or hour < end


def check_day_parts():
    """The ported day-part hours still match `DayPart.from(hour:)`."""
    source = strip_comments(read(THEME))
    block = re.search(r"static func from\(hour: Int\) -> DayPart \{(.*?)\n    \}",
                      source, re.S)
    if not block:
        # A different shape — say so rather than silently trusting the port.
        return ["DayPart.from(hour:) changed shape; check_tide.py's DAY_PARTS "
                "can no longer be verified against it"]
    found = re.findall(r"case (\d+)\.\.<(\d+): \.(\w+)", block.group(1))
    problems = []
    named = set()
    for start, end, name in found:
        named.add(name)
        if DAY_PARTS.get(name) != (int(start), int(end)):
            problems.append(f"DayPart.{name} is {start}..<{end} in the Swift "
                            f"and {DAY_PARTS.get(name)} in check_tide.py")
    # The `default` arm gets whatever is left. Derived rather than trusted, so
    # widening dusk in the Swift moves night here too.
    rest = re.search(r"default: \.(\w+)", block.group(1))
    if rest:
        last_end = max(int(end) for _, end, _ in found)
        first_start = min(int(start) for start, _, _ in found)
        if DAY_PARTS.get(rest.group(1)) != (last_end, first_start):
            problems.append(
                f"DayPart.{rest.group(1)} is the default arm, which leaves "
                f"{last_end}..{first_start}, and check_tide.py has "
                f"{DAY_PARTS.get(rest.group(1))}")
    elif len(named) != len(DAY_PARTS):
        problems.append("DayPart.from(hour:) no longer has a default arm and "
                        "check_tide.py did not find every part")
    return problems


def main():
    model = parse_tide()
    moon = parse_moon()
    gated = parse_gated()
    failures = list(check_day_parts())

    # Hour by hour for a decade. 87,600 samples, which costs about a second.
    start = datetime.datetime(2026, 1, 1, tzinfo=datetime.timezone.utc)
    hours = []
    for step in range(YEARS * 365 * 24):
        when = start + datetime.timedelta(hours=step)
        seconds = when.timestamp()
        water = level(seconds, model, moon)
        hours.append((when.hour, water, state(water, model["floors"])))

    levels = [water for _, water, _ in hours]

    # --- 1. The sea actually moves -----------------------------------------
    if max(levels) - min(levels) < 0.5:
        failures.append(
            f"the water only ever ranges {min(levels):.3f}..{max(levels):.3f} "
            f"— the tide has stopped moving, and every gate below would still "
            f"pass while the harbour never changed")

    # --- 2. Springs happen at new *and* full -------------------------------
    #
    # If `abs` went missing from the springness term, the range would open at
    # new moon only and never at full: half the spring tides gone, and nothing
    # on screen to show it.
    at_new, at_full = [], []
    for step in range(0, YEARS * 365 * 24, 3):
        when = start + datetime.timedelta(hours=step)
        age = moon_age(when.timestamp(), moon)
        if age < 0.02 or age > 0.98:
            at_new.append(level(when.timestamp(), model, moon))
        elif abs(age - 0.5) < 0.02:
            at_full.append(level(when.timestamp(), model, moon))
    new_range = max(at_new) - min(at_new) if at_new else 0
    full_range = max(at_full) - min(at_full) if at_full else 0
    for label, found in (("new", new_range), ("full", full_range)):
        if found < 0.85:
            failures.append(
                f"the range at {label} moon is only {found:.2f} — springs are "
                f"supposed to be the biggest tides of the month, and this one "
                f"is not")
    if abs(new_range - full_range) > 0.1:
        failures.append(
            f"springs at new moon range {new_range:.2f} and at full "
            f"{full_range:.2f} — they should be the same size, and are not. "
            f"The `abs` is missing from the springness term")

    # --- 3. Neaps are genuinely smaller ------------------------------------
    at_quarter = []
    for step in range(0, YEARS * 365 * 24, 3):
        when = start + datetime.timedelta(hours=step)
        if abs(moon_age(when.timestamp(), moon) - 0.25) < 0.02:
            at_quarter.append(level(when.timestamp(), model, moon))
    neap = max(at_quarter) - min(at_quarter) if at_quarter else 1
    if neap > new_range * 0.6:
        failures.append(
            f"neaps range {neap:.2f} against springs' {new_range:.2f} — the "
            f"spring–neap cycle has flattened out and the moon no longer "
            f"moves the sea")

    # --- 4. Every band is actually visited ---------------------------------
    seen = {name: 0 for name in model["floors"]}
    for _, _, name in hours:
        seen[name] += 1
    for name, count in sorted(seen.items()):
        if count == 0:
            failures.append(
                f"the water is never in the {name} band — its floor is "
                f"unreachable, so everything gated on it is unreachable too")

    # --- 5. Reachability, at hour granularity ------------------------------
    thinnest = (1e9, None)
    for name, spec in sorted(gated.items()):
        wanted = set(spec["tides"])
        parts = spec["dayParts"] or list(DAY_PARTS)
        count = sum(1 for hour, _, band in hours
                    if band in wanted
                    and any(in_part(hour, part) for part in parts))
        per_year = count / YEARS
        if per_year < thinnest[0]:
            thinnest = (per_year, name)
        if per_year < MINIMUM_HOURS:
            failures.append(
                f"{name} needs {sorted(wanted)} water during "
                f"{parts} and that lines up only {per_year:.0f} hours a year "
                f"— under the floor of {MINIMUM_HOURS:.0f}. Two conditions on "
                f"different clocks multiply, and this is what that looks like")

    # --- 6. The shore strip stays out of the text --------------------------
    view = read(TIDEVIEW)
    if "Tide.waterline" not in view:
        failures.append("TideView no longer reads Tide.waterline — it is "
                        "drawing the shore at a height nothing checks")
    highest = min(model["waterline"])          # smaller fraction = higher up
    rows = [float(match) for match in
            re.findall(r"\(([\d.]+), [\d.]+\),\s*#", read(CONTRAST))]
    lowest_text = max(rows) if rows else 0.718
    if highest <= lowest_text:
        failures.append(
            f"the shore strip reaches {highest:.3f} of the screen and the "
            f"lowest text row in the app is at {lowest_text:.3f} — the water "
            f"is now behind a caption. check_contrast.py samples the scene "
            f"exports and cannot see a SwiftUI overlay, so nothing else would "
            f"ever report this")
    elif highest - lowest_text < 0.04:
        failures.append(
            f"the shore strip clears the lowest text row by only "
            f"{(highest - lowest_text) * 100:.1f}% of the screen — too close "
            f"to survive a layout change")

    # --- 7. The fixture ----------------------------------------------------
    for stamp, expected_level, expected_state in FIXTURE:
        when = datetime.datetime.fromisoformat(stamp).replace(
            tzinfo=datetime.timezone.utc)
        water = level(when.timestamp(), model, moon)
        band = state(water, model["floors"])
        if abs(water - expected_level) > 0.002 or band != expected_state:
            failures.append(
                f"FIXTURE: {stamp} used to be {expected_level:.3f} "
                f"({expected_state}) and is now {water:.3f} ({band}). Every "
                f"tide this app has ever shown has just moved. See the note "
                f"above FIXTURE.")

    print(f"checked {len(hours)} hours of water over {YEARS} years, "
          f"{len(gated)} tide-gated species, {len(FIXTURE)} fixture rows")
    print(f"range {min(levels):.2f}..{max(levels):.2f}; springs {new_range:.2f}, "
          f"neaps {neap:.2f}; thinnest: {thinnest[1]} at {thinnest[0]:.0f} "
          f"hours a year (floor {MINIMUM_HOURS:.0f})")
    if failures:
        print(f"\n{len(failures)} FAILED:")
        for line in failures:
            print(f"  {line}")
        return 1
    print("all pass")
    return 0


# The water at a handful of instants, generated once from the implementation
# and frozen.
#
# `establishment` and `period` are the two numbers that move *every* tide this
# app has ever shown, in both directions in time. Somebody sat at the harbour
# on a Tuesday afternoon with the shore out and half a dozen animals on it; if
# these rows change, that afternoon has become high water and the app has
# rewritten a thing somebody remembers.
#
# If a row fails the question is never "how do I update the fixture". It is
# "am I willing to move the sea".
FIXTURE = (
    ("2026-01-01T00:00:00", 0.067, "springLow"),
    ("2026-01-01T06:00:00", 0.942, "high"),
    ("2026-03-15T09:00:00", 0.423, "mid"),
    ("2026-06-30T18:00:00", 0.527, "mid"),
    ("2026-11-11T03:00:00", 0.018, "springLow"),
    ("2030-02-02T12:00:00", 0.183, "low"),
    ("2027-07-04T21:00:00", 0.994, "high"),
    ("2028-09-19T15:00:00", 0.011, "springLow"),
)


if __name__ == "__main__":
    sys.exit(main())
