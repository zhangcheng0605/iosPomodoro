"""Check that body text still clears WCAG AA over every background the app can draw.

The app's promise is that every text/background pair measures at least 4.5:1, in
every theme, in both appearances. The time-of-day sky wash puts a translucent
layer between the two, which is exactly the kind of change that quietly breaks
that promise — so this recomputes it rather than trusting the eye.

Reads the palettes straight out of AppTheme.swift, so it cannot drift from the
values the app actually ships.

    python3 tools/check_contrast.py

Exits non-zero if anything fails.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THEME_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "AppTheme.swift")

MINIMUM = 4.5

# Mirrors Palette.sky(_:) — which hue each time of day borrows.
SKY_HUE = {
    "day": None,
    "dawn": "sunshine",
    "dusk": "blossom",
    "night": "night",
}

# Mirrors Palette.skyMix and Theme.skyWashOpacity.
SKY_MIX = 0.58
SKY_WASH_OPACITY = 0.45

# Mirrors Theme.background(for:): (top colour, its opacity over cream, bottom).
PHASE_BACKGROUNDS = {
    "focus": ("blush", 0.6),
    "shortBreak": ("sage", 0.5),
    "longBreak": ("sunshine", 0.45),
}


def parse_palettes(source):
    """Pull every `name: .dual(r,g,b, r,g,b)` out of each theme's Palette."""
    palettes = {}
    theme_blocks = re.split(r"case \.(\w+):\s*\n\s*Palette\(", source)[1:]
    for name, block in zip(theme_blocks[0::2], theme_blocks[1::2]):
        colours = {}
        for match in re.finditer(
            r"(\w+):\s*\.dual\(([-0-9., ]+)\)", block.split("\n            )")[0]
        ):
            values = [float(v) for v in match.group(2).split(",")]
            colours[match.group(1)] = {
                "light": tuple(values[0:3]),
                "dark": tuple(values[3:6]),
            }
        palettes[name] = colours
    return palettes


def relative_luminance(rgb):
    def channel(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = (channel(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = relative_luminance(a), relative_luminance(b)
    lighter, darker = max(la, lb), min(la, lb)
    return (lighter + 0.05) / (darker + 0.05)


def over(top, bottom, alpha):
    """Source-over composite, which is what SwiftUI's opacity does."""
    return tuple(t * alpha + b * (1 - alpha) for t, b in zip(top, bottom))


def main():
    with open(THEME_FILE) as handle:
        palettes = parse_palettes(handle.read())

    if not palettes:
        print("could not parse any palettes from AppTheme.swift", file=sys.stderr)
        return 1

    failures = []
    checked = 0

    for theme, colours in sorted(palettes.items()):
        for appearance in ("light", "dark"):
            def c(name):
                return colours[name][appearance]

            text = c("bark")

            for phase, (tint, tint_alpha) in PHASE_BACKGROUNDS.items():
                # Both ends of the gradient, which brackets everything between.
                stops = {
                    "top": over(c(tint), c("cream"), tint_alpha),
                    "bottom": c("cream"),
                }
                for part, hue in SKY_HUE.items():
                    for stop_name, stop in stops.items():
                        background = stop
                        if hue is not None:
                            # Palette.sky(): hue pulled toward cream, then laid
                            # over the phase background at the wash opacity.
                            wash = over(c("cream"), c(hue), SKY_MIX)
                            background = over(wash, stop, SKY_WASH_OPACITY)
                        ratio = contrast(text, background)
                        checked += 1
                        if ratio < MINIMUM:
                            failures.append(
                                f"{theme}/{appearance}/{phase}/{part}/{stop_name}: "
                                f"{ratio:.2f}:1"
                            )

            # onAccent on each accent fill, unchanged by the wash but cheap to
            # re-verify while we're here.
            for accent in ("blossom", "sage", "sunshine"):
                ratio = contrast(c("onAccent"), c(accent))
                checked += 1
                if ratio < MINIMUM:
                    failures.append(
                        f"{theme}/{appearance}/onAccent on {accent}: {ratio:.2f}:1"
                    )

    print(f"checked {checked} pairs against {MINIMUM}:1")
    if failures:
        print(f"\n{len(failures)} FAILED:")
        for line in failures:
            print(f"  {line}")
        return 1
    print("all pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
