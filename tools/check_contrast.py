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
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THEME_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "AppTheme.swift")
JOURNAL_FILE = os.path.join(ROOT, "Pawmodoro", "Views", "JournalView.swift")
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")

# The bar for the journal's unseen silhouettes.
#
# Deliberately not MINIMUM. A silhouette is a graphical object rather than a
# run of text, and WCAG 2.2 SC 1.4.11 asks 3:1 of "graphical objects required
# to understand the content" — which this is: working out what you have not met
# yet is the only thing the unseen half of the journal is for.
#
# It exists because the silhouettes were drawn in a flat brown baked into the
# PNG, at one opacity for both appearances, and measured 1.03-1.06:1 on a dark
# tile. Eighty-one empty rectangles, in every theme, on both platforms. Nothing
# in this file looked at them, because everything in this file was pointed at
# text over scenery.
SILHOUETTE_MINIMUM = 3.0

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

# Mirrors Palette.weather(_:) and Weather.veilOpacity — which palette hue each
# weather borrows, and how strongly it is laid over the scene.
#
# `clear` is absent because it draws nothing; every other weather is a second
# veil between the scene's own veil and the sky wash, which is a layer the
# text has to survive and therefore a layer this has to measure.
WEATHER_MIX = 0.62
WEATHER_VEILS = {
    "breeze": ("sage", 0.10),
    "snow": ("night", 0.20),
    "drizzle": ("night", 0.22),
    "golden": ("sunshine", 0.26),
    "overcast": ("bark", 0.30),
    "rain": ("night", 0.30),
    "mist": ("cream", 0.34),
    "storm": ("night", 0.40),
}

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


# Mirrors SceneryView.veil — how much theme background is laid back over the
# artwork. This is the knob that keeps eight places legible in four times of
# day without hand-tuning each combination.
SCENE_VEIL = 0.52

# Rows the UI puts text over, as a fraction of screen height, paired with the
# opacity of the theme-coloured backing that text sits on.
#
# Every one of these has a backing now. Artwork can be any colour a place needs
# it to be, and the text is never reading against it directly — the timer face
# (TimerRingView), the caption capsule (BuddyView), the paw row capsule
# (ContentView) and the now-playing chip (NowPlayingChip) each carry their own.
# What this check proves is that those backings are opaque enough to survive
# the darkest scene under them.
#
# The chip is the one row that is two rows: it is anchored to the bottom of the
# dial rather than to a fixed place on the screen, so where it lands moves with
# the phone. Measured at 0.520 on an iPhone 17; the pair below brackets it
# across the range of supported heights, because one number would leave the
# band it actually covers unmeasured on every other device.
TEXT_ROWS = (
    (0.335, 0.82),   # countdown, on the timer face
    (0.412, 0.82),   # status line, same face
    (0.500, 0.78),   # now-playing chip, top edge on a tall phone
    (0.545, 0.78),   # now-playing chip, bottom edge on a short one
    (0.690, 0.78),   # buddy caption capsule
    (0.718, 0.70),   # paw print capsule
)

PLACES = ("meadow", "woods", "harbor", "blossom",
          "keep", "cloudspire", "peaks", "onsen")


def check_scenes(palettes, minimum):
    """Measure the real exported pixels behind the real text rows.

    The palette maths above cannot see this: a place is an image, so the only
    honest check is to load it, composite what the app composites, and look."""
    try:
        from PIL import Image
    except ImportError:
        print("  (Pillow not installed — skipping the scene check)")
        return [], 0

    failures = []
    checked = 0

    for place in PLACES:
        for part in ("dawn", "day", "dusk", "night"):
            name = f"scene_{place}_{part}"
            path = os.path.join(
                ROOT, "Pawmodoro", "Assets.xcassets",
                f"{name}.imageset", f"{name}.png",
            )
            if not os.path.exists(path):
                failures.append(f"{name}: missing — run tools/generate_scenes.py")
                continue

            image = Image.open(path).convert("RGB")
            width, height = image.size
            pixels = image.load()

            for theme, colours in sorted(palettes.items()):
                for appearance in ("light", "dark"):
                    def c(key):
                        return colours[key][appearance]

                    text = c("bark")
                    wash_hue = SKY_HUE[part]

                    # Clear first, then every weather that draws a veil. Each
                    # is measured on its own so a failure names the sky that
                    # caused it rather than "somewhere in this scene".
                    skies = [("clear", None, 0.0)]
                    skies += [
                        (weather, hue, alpha)
                        for weather, (hue, alpha) in sorted(WEATHER_VEILS.items())
                    ]

                    for weather, veil_hue, veil_alpha in skies:
                        worst = (99.0, None)
                        for fraction, backing in TEXT_ROWS:
                            y = min(height - 1, int(height * fraction))
                            # Every 8th column is plenty to catch a bad region
                            # and keeps the whole sweep to a few seconds.
                            for x in range(0, width, 8):
                                r, g, b = pixels[x, y]
                                scene = (r / 255.0, g / 255.0, b / 255.0)
                                background = over(c("cream"), scene, SCENE_VEIL)
                                # The weather veil sits on the scene, inside
                                # SceneryView, so it composites before the sky.
                                if veil_hue is not None:
                                    veil = over(
                                        c("cream"), c(veil_hue), WEATHER_MIX
                                    )
                                    background = over(
                                        veil, background, veil_alpha
                                    )
                                if wash_hue is not None:
                                    wash = over(c("cream"), c(wash_hue), SKY_MIX)
                                    background = over(
                                        wash, background, SKY_WASH_OPACITY
                                    )
                                # The text's own backing, last.
                                background = over(c("cream"), background, backing)
                                ratio = contrast(text, background)
                                checked += 1
                                if ratio < worst[0]:
                                    worst = (ratio, (fraction, x))
                        if worst[0] < minimum:
                            row, col = worst[1]
                            failures.append(
                                f"{name}/{weather}/{theme}/{appearance} at row "
                                f"{row:.3f} x={col}: {worst[0]:.2f}:1"
                            )
    return failures, checked


def check_silhouettes(palettes, theme_source):
    """The journal's not-yet-seen tiles, measured rather than assumed.

    Every number here is read back out of the Swift — the two opacities from
    `Palette`, the tile's own fill from `JournalView`, and which palette colour
    the tint is. This file supplies the bar and nothing else, which is the only
    arrangement that survives someone changing one of them.

    Two structural rules ride along, because the maths is worthless without
    them:

    - The ghost has to be **template-rendered** at the draw site. Drop that one
      modifier and the tint silently does nothing, the sprite goes back to its
      baked brown, and the measurement below still passes while the screen is
      exactly as broken as it was.
    - The ghost sprite has to be **one flat tone**. Template rendering keeps
      alpha and throws colour away, so a ghost that ever gained a second tone
      would be flattened into a blob by this treatment, and only a person
      looking would notice.
    """
    failures = []
    checked = 0

    try:
        with open(JOURNAL_FILE) as handle:
            journal = handle.read()
    except OSError as error:
        return [f"JournalView.swift: {error}"], 0

    alphas = {}
    for appearance in ("Light", "Dark"):
        match = re.search(
            r"silhouetteOpacity%s:\s*Double\s*=\s*([0-9.]+)" % appearance,
            theme_source,
        )
        if not match:
            return [
                f"AppTheme.swift: no silhouetteOpacity{appearance} to read"
            ], 0
        alphas[appearance.lower()] = float(match.group(1))

    tile = re.search(
        r"\.fill\(Theme\.surface\.opacity\(seen \? [0-9.]+ : ([0-9.]+)\)\)",
        journal,
    )
    if not tile:
        return ["JournalView.swift: cannot read the unseen tile's fill"], 0
    tile_alpha = float(tile.group(1))

    tint = re.search(
        r"\.foregroundStyle\(Theme\.(\w+)\.opacity\(silhouetteOpacity\)\)",
        journal,
    )
    if not tint:
        return ["JournalView.swift: the silhouette is not tinted by a Theme "
                "colour any more"], 0
    tint_name = tint.group(1)

    ghost = re.search(
        r"Image\(species\.ghostAsset\)(?:\s*\n\s*\.\w+\([^\n]*\))*", journal
    )
    if not ghost or ".renderingMode(.template)" not in ghost.group(0):
        return ["JournalView.swift: the ghost is drawn without "
                ".renderingMode(.template) — the tint does nothing"], 0

    for theme, colours in sorted(palettes.items()):
        for appearance in ("light", "dark"):
            def c(name):
                return colours[name][appearance]

            background = over(c("surface"), c("cream"), tile_alpha)
            silhouette = over(c(tint_name), background, alphas[appearance])
            ratio = contrast(silhouette, background)
            checked += 1
            if ratio < SILHOUETTE_MINIMUM:
                failures.append(
                    f"{theme}/{appearance}/journal silhouette: {ratio:.2f}:1 "
                    f"(needs {SILHOUETTE_MINIMUM}:1)"
                )

    failures.extend(check_ghosts_are_flat())
    return failures, checked


def check_ghosts_are_flat():
    """Every `wild_*_ghost` sprite is one tone, so template rendering is lossless."""
    try:
        from PIL import Image
    except ImportError:
        return []

    failures = []
    pattern = os.path.join(ASSETS, "wild_*_ghost.imageset", "*.png")
    paths = sorted(glob.glob(pattern))
    if not paths:
        return ["no wild_*_ghost sprites found — run tools/generate_wildlife.py"]
    for path in paths:
        image = Image.open(path).convert("RGBA")
        tones = {
            pixel[:3] for pixel in image.getdata() if pixel[3] > 0
        }
        if len(tones) > 1:
            failures.append(
                f"{os.path.basename(path)}: {len(tones)} opaque tones — a ghost "
                "is template-tinted at the draw site, so it must be flat"
            )
    return failures


def main():
    with open(THEME_FILE) as handle:
        theme_source = handle.read()
    palettes = parse_palettes(theme_source)

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

    scene_failures, scene_checked = check_scenes(palettes, MINIMUM)
    failures.extend(scene_failures)
    checked += scene_checked

    ghost_failures, ghost_checked = check_silhouettes(palettes, theme_source)
    failures.extend(ghost_failures)
    checked += ghost_checked

    print(f"checked {checked} pairs against {MINIMUM}:1 "
          f"({scene_checked} of them sampled from real scene pixels, "
          f"{ghost_checked} journal silhouettes against "
          f"{SILHOUETTE_MINIMUM}:1)")
    if failures:
        print(f"\n{len(failures)} FAILED:")
        for line in failures:
            print(f"  {line}")
        return 1
    print("all pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
