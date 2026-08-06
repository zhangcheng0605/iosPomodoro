"""Check that the stray reads, and stands on the ground, everywhere she appears.

She is the one piece of art in the app placed by fractions of the *screen*
rather than drawn into a scene, so nothing in the existing pipeline can catch
the two ways she goes wrong:

  - **She floats.** A position that lands in open sky on one place, or on a
    phone whose aspect crops the artwork differently, puts a sitting cat in
    mid-air. `generate_scenes.py` asserts the countdown's rows are sky; this
    asserts the opposite about hers.
  - **She disappears.** A near-black cat over a night scene in a dark theme is
    a hole in the picture. Her palette carries a deliberately *pale* outline to
    survive that, and this measures whether it actually does — over the real
    exported pixels, veiled and sky-washed exactly as the app composites them.

Everything is read from the sources rather than restated: her positions and
sizes out of Stray.swift, her palette out of generate_sprites.py, the scene
composition out of generate_scenes.py, the themes out of AppTheme.swift. If any
of them moves, this moves with it.

    python3 tools/check_stray.py [--preview]

Exits non-zero if anything fails.
"""
import os
import re
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import check_contrast as contrast_check
import generate_scenes as scenes
import generate_sprites as sprites

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")
STRAY_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "Stray.swift")
THEME_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "AppTheme.swift")
PLACE_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "Place.swift")

# How strongly her silhouette has to separate from what is behind it.
#
# Not the text bar: 4.5:1 is for reading words, and an animal that shouted that
# loud would stop being a thing you notice and start being a sticker. 2.0:1 is
# "you can tell there is a cat there" — enough that she never dissolves into a
# night sky, low enough that she stays part of the picture.
MINIMUM = 2.0

# What a cat cannot stand on.
#
# Sky was the obvious half. Water was not, and the first version of this check
# passed a stray sitting placidly on the open sea at Harbor Isle for exactly
# that reason — "not sky" is not the same claim as "standing on something".
UNSTANDABLE = {
    scenes.SKY_HI, scenes.SKY_MID, scenes.SKY_LO, scenes.CLOUD, scenes.CLOUD_SH,
    scenes.SEA_HI, scenes.SEA_LO, scenes.FOAM,
}

# The screens the layout has to survive. The short one is the real test: its
# aspect is far from the artwork's, so `scaledToFill` crops the scene hard and
# every fraction lands somewhere different.
DEVICES = (
    ("iPhone 16", 393, 852),
    ("iPhone SE", 375, 667),
)


def parse_stages():
    """Pull her ground line, positions and sizes straight out of Stray.swift,
    so this check cannot quietly go on measuring where she used to be."""
    with open(STRAY_FILE) as handle:
        source = handle.read()

    ground = re.search(r"static let groundLine: Double = ([\d.]+)", source)
    if not ground:
        raise SystemExit("could not find Stray.groundLine in Stray.swift")

    # Scoped to the `x` switch: matching bare `case .name: 0.123` across the
    # whole file also picks up the dwell windows, whose `0.30...0.62` is not a
    # number at all.
    block = re.search(r"var x: Double \{\n\s*switch self \{(.*?)\n\s*\}", source,
                      re.S)
    if not block:
        raise SystemExit("could not find Stage.x in Stray.swift")
    columns = {}
    for labels, x in re.findall(r"case ((?:\.\w+,?\s*)+): ([\d.]+)",
                                block.group(1)):
        for name in re.findall(r"\.(\w+)", labels):
            columns[name] = float(x)
    sizes = dict(
        (name, (float(w), float(h)))
        for name, w, h in re.findall(
            r"case \.(\w+): CGSize\(width: ([\d.]+), height: ([\d.]+)\)", source
        )
    )
    frames = dict(
        (name, re.findall(r'"([\w]+)"', body))
        for name, body in re.findall(r'case \.(\w+): \[([^\]]+)\]', source)
    )

    # Every column, not each stage's own.
    #
    # `Stage.x(in:)` swaps the sides in the wet — she comes in tight against
    # whichever edge she is not usually on and waits it out — so a stage can
    # now stand at any column in the table. Testing each at its own would have
    # said nothing about the half of the time she is at the other one, and
    # putting her on the open sea at Harbor is exactly the bug this file was
    # written for.
    #
    # Only the columns the *scene* stages use: 0.5 belongs to `away`, `beside`
    # and `home`, which are indoors, have `.zero` size and no scene frames at
    # all. The first version of this cross-test included it and reported the
    # cat standing in the Onsen's hot spring — a true statement about a
    # position nothing ever draws her at.
    outdoors = ("eyes", "edge", "watching")
    every = sorted({columns[name] for name in outdoors if name in columns})
    stages = []
    for name in outdoors:
        if name not in columns or name not in sizes or name not in frames:
            raise SystemExit(f"could not parse stage '{name}' out of Stray.swift")
        for column in every:
            stages.append((name, column, sizes[name], frames[name]))
    return float(ground.group(1)), stages


def sprite_pixels(asset):
    """The sprite's logical pixels and alpha, back down from the upscale."""
    path = os.path.join(ASSETS, f"{asset}.imageset", f"{asset}.png")
    if not os.path.exists(path):
        raise SystemExit(f"{asset}: missing — run tools/generate_sprites.py")
    image = np.array(Image.open(path).convert("RGBA"))
    step = sprites.UPSCALE
    return image[step // 2::step, step // 2::step]


def scaled_to_fill(screen_w, screen_h):
    """SwiftUI's `.scaledToFill()` + `.clipped()`, in logical scene units.

    Returns a function mapping a point on screen to a pixel in the artwork.
    The two differ by more than rounding on a short phone, which is exactly
    where a hand-placed sprite drifts off the ground."""
    scale = max(screen_w / scenes.W, screen_h / scenes.H)
    origin_x = (screen_w - scenes.W * scale) / 2
    origin_y = (screen_h - scenes.H * scale) / 2

    def to_scene(x, y):
        return ((x - origin_x) / scale, (y - origin_y) / scale)

    return to_scene


def skipped_places():
    """Places `Place.strayVisits` says she never reaches, read from the app so
    this can't go on testing somewhere she was deliberately taken out of — or,
    worse, stop testing somewhere she was quietly put back."""
    with open(PLACE_FILE) as handle:
        block = re.search(
            r"var strayVisits: Bool \{\n\s*switch self \{(.*?)\n\s*\}",
            handle.read(), re.S,
        )
    if not block:
        raise SystemExit("could not find Place.strayVisits in Place.swift")
    false_arm = re.search(r"case ((?:\.\w+,?\s*)+): false", block.group(1))
    return set(re.findall(r"\.(\w+)", false_arm.group(1))) if false_arm else set()


_SCENE_CACHE = {}


def scene_image(place, part):
    key = (place, part)
    if key not in _SCENE_CACHE:
        name = f"scene_{place}_{part}"
        path = os.path.join(ASSETS, f"{name}.imageset", f"{name}.png")
        _SCENE_CACHE[key] = (
            Image.open(path).convert("RGB") if os.path.exists(path) else None
        )
    return _SCENE_CACHE[key]


def sample_scene(place, part, box):
    """Nine points across the patch of artwork she covers."""
    image = scene_image(place, part)
    if image is None:
        return None
    width, height = image.size
    pixels = image.load()
    gx0, gy0, gx1, gy1 = box

    samples = []
    for fx in (0.2, 0.5, 0.8):
        for fy in (0.2, 0.5, 0.8):
            gx = gx0 + (gx1 - gx0) * fx
            gy = gy0 + (gy1 - gy0) * fy
            ix = min(width - 1, max(0, int(gx / scenes.W * width)))
            iy = min(height - 1, max(0, int(gy / scenes.H * height)))
            r, g, b = pixels[ix, iy]
            samples.append((r / 255.0, g / 255.0, b / 255.0))
    return samples


def luminance_pairs(sprite, background):
    """Every distinct colour she is made of, against one background."""
    opaque = sprite[..., 3] > 0
    colours = {tuple(c) for c in sprite[opaque][:, :3].tolist()}
    return [
        contrast_check.contrast(tuple(v / 255.0 for v in colour), background)
        for colour in colours
    ]


def preview(palettes, ground_line, stages, skipped,
            theme="sakura", path="stray_preview.png"):
    """Composite exactly what the app composites, and save it to look at.

    A number saying 2.7:1 does not tell you whether a cat looks like she is
    sitting in the grass or standing on a roof. This is the closest thing to a
    screenshot available without a Mac, and it is worth more than the numbers
    for anything about placement."""
    device, screen_w, screen_h = DEVICES[0]
    to_scene = scaled_to_fill(screen_w, screen_h)
    places = [p for p in ("meadow", "woods", "onsen", "peaks") if p not in skipped]
    parts = ("day", "night")
    rows = [(appearance, place, part)
            for appearance in ("light", "dark")
            for place in places for part in parts]

    tile_w, tile_h = screen_w, screen_h
    # One stage per tile, one stage per row. Drawing all three into the same
    # tile overlaps two of them, and a diagnostic that shows a thing the app
    # never shows is worse than no diagnostic.
    sheet = Image.new("RGB", (tile_w * len(rows), tile_h * len(stages)), (20, 20, 20))

    for column, (appearance, place, part) in enumerate(rows):
        colours = palettes[theme]

        def c(key):
            return colours[key][appearance]

        image = scene_image(place, part)
        # `.scaledToFill()` + `.clipped()`, on the artwork itself.
        factor = max(tile_w / image.width, tile_h / image.height)
        resized = image.resize(
            (round(image.width * factor), round(image.height * factor)),
            Image.NEAREST,
        )
        left = (resized.width - tile_w) // 2
        top = (resized.height - tile_h) // 2
        base = resized.crop((left, top, left + tile_w, top + tile_h)).convert("RGBA")

        veil = tuple(int(v * 255) for v in c("cream")) + (
            int(contrast_check.SCENE_VEIL * 255),
        )
        base.alpha_composite(Image.new("RGBA", base.size, veil))

        hue = contrast_check.SKY_HUE[part]
        if hue is not None:
            washed = contrast_check.over(c("cream"), c(hue), contrast_check.SKY_MIX)
            wash = tuple(int(v * 255) for v in washed) + (
                int(contrast_check.SKY_WASH_OPACITY * 255),
            )
            base.alpha_composite(Image.new("RGBA", base.size, wash))

        for row, (_, px, (sw, sh), frames) in enumerate(stages):
            tile = base.copy()
            sprite = Image.open(
                os.path.join(ASSETS, f"{frames[0]}.imageset", f"{frames[0]}.png")
            ).convert("RGBA").resize((round(sw), round(sh)), Image.NEAREST)
            if px > 0.5:
                sprite = sprite.transpose(Image.FLIP_LEFT_RIGHT)
            tile.alpha_composite(
                sprite,
                (round(px * tile_w - sprite.width / 2),
                 round(ground_line * tile_h - sprite.height)),
            )
            sheet.paste(tile.convert("RGB"), (column * tile_w, row * tile_h))

    sheet.save(path)
    print(f"preview: {path} — {device}, {theme}; "
          f"{len(rows)} columns of (light/dark x place x day/night), "
          f"one row per stage ({', '.join(s[0] for s in stages)})")


def main():
    palettes = contrast_check.parse_palettes(open(THEME_FILE).read())
    if not palettes:
        print("could not parse any palettes from AppTheme.swift", file=sys.stderr)
        return 1

    ground_line, stages = parse_stages()
    skipped = skipped_places()
    grids = {name: draw() for name, draw, _ in scenes.PLACES if name not in skipped}
    if skipped:
        print(f"not checked, she never goes there: {', '.join(sorted(skipped))}")

    failures = []
    checked = 0
    worst_overall = (99.0, None)

    for stage_name, px, (sw, sh), frames in stages:
        sprite = sprite_pixels(frames[0])

        for device, screen_w, screen_h in DEVICES:
            to_scene = scaled_to_fill(screen_w, screen_h)

            # Her box on screen, in points, then in scene pixels. Feet on the
            # ground line, which is what the app does — see `Stray.groundLine`.
            bottom = ground_line * screen_h
            left, top = px * screen_w - sw / 2, bottom - sh
            box = [to_scene(left, top), to_scene(left + sw, bottom)]
            (gx0, gy0), (gx1, gy1) = box

            # 1. Never in the countdown's rows. Same rule generate_scenes.py
            #    enforces for the artwork, applied to something drawn over it.
            if gy0 < scenes.QUIET_BOTTOM and gy1 > scenes.QUIET_TOP:
                failures.append(
                    f"{stage_name}/{device}: overlaps the countdown band "
                    f"(scene rows {gy0:.0f}-{gy1:.0f} vs "
                    f"{scenes.QUIET_TOP}-{scenes.QUIET_BOTTOM})"
                )

            foot_x = int(round((gx0 + gx1) / 2))
            foot_y = int(round(gy1)) - 1

            for place, grid in sorted(grids.items()):
                # 2. Standing on something. A cat in open sky is the failure a
                #    screenshot would show and nothing else would.
                if 0 <= foot_y < scenes.H and 0 <= foot_x < scenes.W:
                    under = int(grid[foot_y, foot_x])
                    if under in UNSTANDABLE:
                        failures.append(
                            f"{stage_name}/{device}/{place}: nothing to stand "
                            f"on at scene ({foot_x}, {foot_y}), "
                            f"palette index {under}"
                        )
                else:
                    failures.append(
                        f"{stage_name}/{device}/{place}: feet fall outside the "
                        f"artwork at ({foot_x}, {foot_y})"
                    )

                # 3. Legible, over the real exported pixels, in every theme
                #    and appearance.
                for part in scenes.PARTS:
                    samples = sample_scene(place, part, (gx0, gy0, gx1, gy1))
                    if samples is None:
                        failures.append(f"{place}/{part}: missing scene image")
                        continue

                    hue = contrast_check.SKY_HUE[part]
                    for theme, colours in sorted(palettes.items()):
                        for appearance in ("light", "dark"):
                            def c(key):
                                return colours[key][appearance]

                            for scene in samples:
                                background = contrast_check.over(
                                    c("cream"), scene, contrast_check.SCENE_VEIL
                                )
                                if hue is not None:
                                    wash = contrast_check.over(
                                        c("cream"), c(hue), contrast_check.SKY_MIX
                                    )
                                    background = contrast_check.over(
                                        wash, background,
                                        contrast_check.SKY_WASH_OPACITY,
                                    )
                                # The best any colour she is made of manages:
                                # one strong edge is all a silhouette needs,
                                # which is the whole reason for the pale rim.
                                best = max(luminance_pairs(sprite, background))
                                checked += 1
                                where = (f"{stage_name}/{place}/{part}/"
                                         f"{theme}/{appearance}")
                                if best < worst_overall[0]:
                                    worst_overall = (best, where)
                                if best < MINIMUM:
                                    failures.append(f"{where}: {best:.2f}:1")

    print(f"checked {checked} sprite/background pairs against {MINIMUM}:1")
    if worst_overall[1]:
        print(f"worst: {worst_overall[0]:.2f}:1 at {worst_overall[1]}")
    if failures:
        unique = sorted(set(failures))
        print(f"\n{len(unique)} FAILED:")
        for line in unique[:40]:
            print(f"  {line}")
        if len(unique) > 40:
            print(f"  ... and {len(unique) - 40} more")
        return 1
    print("all pass")

    if "--preview" in sys.argv:
        index = sys.argv.index("--preview")
        path = (sys.argv[index + 1] if len(sys.argv) > index + 1
                else os.path.join(ROOT, "stray_preview.png"))
        preview(palettes, ground_line, stages, skipped, path=path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
