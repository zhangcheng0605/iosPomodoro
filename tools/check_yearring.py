"""Check that the year ring's four skies are actually different colours.

The ring's whole claim is that you can tell a year of mornings from a year of
late nights by looking at it. That claim is not about contrast — nothing is
written on a wedge — it is about *separation*: if dawn, day, dusk and night
resolve to four shades of the same beige in some theme, the feature is a
decoration that says nothing, and it would say nothing silently, in one theme,
forever.

Nothing else can catch that. `check_contrast.py` measures text against
background and would be perfectly happy with four identical wedges. A
screenshot would only ever show one theme at a time, and there are sixteen
combinations.

So this recomputes the tints exactly as `YearRingView.tint(for:)` does — from
the palettes in `AppTheme.swift`, through the same `Palette.sky` mixing the
scenery uses — composites them over the page, and measures the distance
between every pair in CIE Lab, where "distance" means something to an eye.

Two things are asserted:

  * every pair of times of day differs by at least `MINIMUM_DELTA`
  * every lived day differs from an empty one by at least that much, so a day
    you sat is never mistakable for a day you didn't

    python3 tools/check_yearring.py

Exits non-zero if anything fails.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import check_contrast as contrast_check

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THEME_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "AppTheme.swift")

# CIE76 ΔE. Around 2.3 is the "just noticeable difference" for two patches
# touching each other; these wedges are one pixel wide and scattered around a
# circle, so they need considerably more than that to read as different at a
# glance. 8 is a colour you would describe with a different word.
MINIMUM_DELTA = 8.0

# Mirrors the *shape* of `Palette.ringTint(_:)`; the numbers themselves are
# parsed out of it below.
#
# That distinction was learned the hard way twice in this repo. A checker that
# restates the values it is checking is self-consistent by construction: the
# first version of this file kept the ladder as a Python constant, and
# flattening all four steps in the Swift — the exact bug it exists to catch —
# passed cleanly, because the checker was still measuring its own copy.
# `check_weather.py` has the same story and the same fix.

# Mirrors the empty-day wedge: `Theme.bark.opacity(0.07)` over the page.
EMPTY_ALPHA = 0.07


def parse_ring_tint():
    """The ladder steps and the accent amount, out of `Palette.ringTint`."""
    source = open(THEME_FILE).read()
    body = source.split("func ringTint(_ part: DayPart) -> DualColor {")[1]
    body = body.split("\n    }")[0]

    ladder = dict(re.findall(r"case \.(\w+): step = ([\d.]+)", body))
    if len(ladder) != 4:
        raise SystemExit(
            f"could not parse four ladder steps from Palette.ringTint "
            f"(found {sorted(ladder)})"
        )
    accent = re.search(r"amount: ([\d.]+)\)\n", body) or re.search(
        r"\.mixed\(with: accent, amount: ([\d.]+)\)", body
    )
    if not accent:
        raise SystemExit("could not parse the accent amount from Palette.ringTint")
    return {k: float(v) for k, v in ladder.items()}, float(accent.group(1))


def to_lab(rgb):
    """sRGB 0..1 to CIE Lab, D65. Written out rather than imported — the only
    other option is a dependency, and this is twenty lines."""
    def linear(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = (linear(c) for c in rgb)
    x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
    y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.00000
    z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else (7.787 * t) + (16 / 116)

    fx, fy, fz = f(x), f(y), f(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def delta_e(a, b):
    la, lb = to_lab(a), to_lab(b)
    return sum((x - y) ** 2 for x, y in zip(la, lb)) ** 0.5


def main():
    palettes = contrast_check.parse_palettes(open(THEME_FILE).read())
    if not palettes:
        print("could not parse any palettes from AppTheme.swift", file=sys.stderr)
        return 1

    ladder, accent_amount = parse_ring_tint()

    failures = []
    checked = 0
    worst = (999.0, None)

    for theme, colours in sorted(palettes.items()):
        for appearance in ("light", "dark"):
            def c(key):
                return colours[key][appearance]

            page = c("cream")
            empty = contrast_check.over(c("bark"), page, EMPTY_ALPHA)

            for depth_name in ("as drawn",):
                wedges = {}
                for part, step in ladder.items():
                    # cream -> bark by the ladder step, then the accent on top.
                    base = contrast_check.over(c("bark"), c("cream"), step)
                    wedges[part] = contrast_check.over(
                        c("blossom"), base, accent_amount
                    )

                names = sorted(wedges)
                for index, first in enumerate(names):
                    # 1. Against every other time of day.
                    for second in names[index + 1:]:
                        distance = delta_e(wedges[first], wedges[second])
                        checked += 1
                        where = (f"{theme}/{appearance}/{depth_name}: "
                                 f"{first} vs {second}")
                        if distance < worst[0]:
                            worst = (distance, where)
                        if distance < MINIMUM_DELTA:
                            failures.append(f"{where}: ΔE {distance:.1f}")

                    # 2. Against an empty day, so a day you sat never reads as
                    #    a day you didn't.
                    distance = delta_e(wedges[first], empty)
                    checked += 1
                    where = f"{theme}/{appearance}/{depth_name}: {first} vs empty"
                    if distance < worst[0]:
                        worst = (distance, where)
                    if distance < MINIMUM_DELTA:
                        failures.append(f"{where}: ΔE {distance:.1f}")

    print(f"checked {checked} wedge pairs against ΔE {MINIMUM_DELTA} "
          f"across {len(palettes)} themes, both appearances")
    if worst[1]:
        print(f"closest: ΔE {worst[0]:.1f} at {worst[1]}")
    if failures:
        print(f"\n{len(failures)} FAILED:")
        for line in failures[:30]:
            print(f"  {line}")
        if len(failures) > 30:
            print(f"  ... and {len(failures) - 30} more")
        return 1
    print("all pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
