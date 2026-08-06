"""Check that the old snail stays on the ground, everywhere she crosses.

The same job `check_stray.py` does, against a harder version of the same
problem. The stray stands at three fixed x positions, so her ground line only
has to be ground in three places. The snail crosses the *whole width* over six
months, so hers has to be ground at every x, on every device aspect, at every
place she visits — and she is a third the size, so she also has to survive
being drawn at eighteen points over a night scene in a dark theme.

Both of those are checked here, over the real exported pixels, composited
exactly as the app composites them: scene, veil, weather veil, sky wash.

What this file decided, rather than verified:

  * her ground line is 0.79 — the same value the stray stands on, which fell
    out of searching every hundredth of the screen rather than being chosen
  * `Place.snailVisits` excludes Cloudspire (a city on clouds: the best row in
    the whole scene is 62 % solid), Harbor Isle (an island in open sea, the
    exact hazard that caught the stray sitting on the water) and the Onsen
    (a hot spring across the middle; three of fifty-six candidate lines clear
    it and all of them are one redraw from failing)

    python3 tools/check_snail.py [--preview <path>]

Exits non-zero if anything fails.
"""
import os
import re
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import check_contrast as contrast_check
import check_stray as stray_check
import generate_scenes as scenes
import generate_sprites as sprites

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")
SNAIL_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "Snail.swift")
STRAY_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "Stray.swift")
THEME_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "AppTheme.swift")

# The same bar the stray clears, and for the same reason: 4.5:1 is for reading
# words, and an animal that shouted that loud would be a sticker rather than a
# thing you notice.
MINIMUM = stray_check.MINIMUM

# Every hundredth of the crossing. She is on screen for six months, so a
# sampling that skipped x positions would be skipping weeks.
STEPS = 100


def parse_snail():
    """Her ground line, size, and the places she skips, out of Snail.swift.

    `groundLine` is written as `Stray.groundLine`, so the number itself comes
    from Stray.swift — read it there rather than restating it, which is the
    whole point of it being written that way.
    """
    source = open(SNAIL_FILE).read()

    width = re.search(r"size = CGSize\(width: ([\d.]+), height: ([\d.]+)\)", source)
    if not width:
        raise SystemExit("could not find Snail.size in Snail.swift")
    size = (float(width.group(1)), float(width.group(2)))

    if "static let groundLine: Double = Stray.groundLine" in source:
        stray = open(STRAY_FILE).read()
        found = re.search(r"static let groundLine: Double = ([\d.]+)", stray)
    else:
        found = re.search(r"static let groundLine: Double = ([\d.]+)", source)
    if not found:
        raise SystemExit("could not resolve Snail.groundLine")

    block = re.search(
        r"var snailVisits: Bool \{\n\s*switch self \{(.*?)\n\s*\}", source, re.S
    )
    if not block:
        raise SystemExit("could not find Place.snailVisits in Snail.swift")
    false_arm = re.search(r"case ((?:\.\w+,?\s*)+): false", block.group(1))
    skipped = set(re.findall(r"\.(\w+)", false_arm.group(1))) if false_arm else set()

    return float(found.group(1)), size, skipped


def preview(ground_line, size, skipped, theme="sakura", path="snail_preview.png"):
    """Her whole crossing on one strip, so it can be looked at rather than
    trusted. Eleven positions across the meadow at midday."""
    palettes = contrast_check.parse_palettes(open(THEME_FILE).read())
    colours = palettes[theme]

    def c(key):
        return colours[key]["light"]

    place = next(p for p in ("meadow", "woods", "keep") if p not in skipped)
    screen_w, screen_h = 393, 852
    scene = stray_check.scene_image(place, "day").resize(
        (screen_w, screen_h), Image.NEAREST
    )
    canvas = np.array(scene).astype(float) / 255.0
    veil = np.array(c("cream"), dtype=float)
    canvas = canvas * (1 - contrast_check.SCENE_VEIL) + veil * contrast_check.SCENE_VEIL
    out = Image.fromarray((canvas * 255).astype(np.uint8), "RGB").convert("RGBA")

    asset = "snail_0"
    sprite = Image.open(
        os.path.join(ASSETS, f"{asset}.imageset", f"{asset}.png")
    ).convert("RGBA").resize((int(size[0]), int(size[1])), Image.NEAREST)

    for step in range(11):
        px = 0.04 + (step / 10) * 0.92
        out.alpha_composite(
            sprite,
            (int(px * screen_w - size[0] / 2),
             int(ground_line * screen_h - size[1])),
        )
    out.save(path)
    print(f"wrote {path}")


def main():
    palettes = contrast_check.parse_palettes(open(THEME_FILE).read())
    if not palettes:
        print("could not parse any palettes from AppTheme.swift", file=sys.stderr)
        return 1

    ground_line, size, skipped = parse_snail()
    grids = {name: draw() for name, draw, _ in scenes.PLACES if name not in skipped}
    if skipped:
        print(f"not checked, she never goes there: {', '.join(sorted(skipped))}")

    sprite = stray_check.sprite_pixels("snail_0")
    failures = []
    checked = 0
    worst = (99.0, None)

    for device, screen_w, screen_h in stray_check.DEVICES:
        to_scene = stray_check.scaled_to_fill(screen_w, screen_h)

        for step in range(STEPS + 1):
            px = 0.04 + (step / STEPS) * 0.92
            bottom = ground_line * screen_h
            left, top = px * screen_w - size[0] / 2, bottom - size[1]
            (gx0, gy0), (gx1, gy1) = (to_scene(left, top),
                                      to_scene(left + size[0], bottom))

            # 1. Never in the countdown's rows. She is small and slow, not
            #    exempt.
            if gy0 < scenes.QUIET_BOTTOM and gy1 > scenes.QUIET_TOP:
                failures.append(
                    f"{device} at x={px:.2f}: overlaps the countdown band"
                )

            foot_x = int(round((gx0 + gx1) / 2))
            foot_y = int(round(gy1)) - 1

            for place, grid in sorted(grids.items()):
                # 2. Standing on something. The whole reason this file exists:
                #    over six months she visits every column of the scene, and
                #    one of them being open water is a snail on the sea.
                if 0 <= foot_y < scenes.H and 0 <= foot_x < scenes.W:
                    under = int(grid[foot_y, foot_x])
                    if under in stray_check.UNSTANDABLE:
                        failures.append(
                            f"{device}/{place} at x={px:.2f}: nothing to stand "
                            f"on at scene ({foot_x}, {foot_y}), palette index "
                            f"{under}"
                        )
                else:
                    failures.append(
                        f"{device}/{place} at x={px:.2f}: outside the artwork "
                        f"at ({foot_x}, {foot_y})"
                    )

                # 3. Legible. Only on the tall device and every fifth step —
                #    the contrast of an eighteen-point sprite does not change
                #    between neighbouring columns, and this is 8 themes x 2
                #    appearances x 4 times of day x 9 weathers per sample.
                if device != stray_check.DEVICES[0][0] or step % 5:
                    continue
                for part in scenes.PARTS:
                    samples = stray_check.sample_scene(
                        place, part, (gx0, gy0, gx1, gy1)
                    )
                    if samples is None:
                        failures.append(f"{place}/{part}: missing scene image")
                        continue
                    hue = contrast_check.SKY_HUE[part]
                    for theme, colours in sorted(palettes.items()):
                        for appearance in ("light", "dark"):
                            def c(key):
                                return colours[key][appearance]

                            for weather, (veil_hue, veil_alpha) in sorted(
                                contrast_check.WEATHER_VEILS.items()
                            ):
                                for scene in samples:
                                    background = contrast_check.over(
                                        c("cream"), scene,
                                        contrast_check.SCENE_VEIL,
                                    )
                                    veil = contrast_check.over(
                                        c("cream"), c(veil_hue),
                                        contrast_check.WEATHER_MIX,
                                    )
                                    background = contrast_check.over(
                                        veil, background, veil_alpha
                                    )
                                    if hue is not None:
                                        wash = contrast_check.over(
                                            c("cream"), c(hue),
                                            contrast_check.SKY_MIX,
                                        )
                                        background = contrast_check.over(
                                            wash, background,
                                            contrast_check.SKY_WASH_OPACITY,
                                        )
                                    best = max(stray_check.luminance_pairs(
                                        sprite, background
                                    ))
                                    checked += 1
                                    where = (f"{place}/{part}/{weather}/"
                                             f"{theme}/{appearance}")
                                    if best < worst[0]:
                                        worst = (best, where)
                                    if best < MINIMUM:
                                        failures.append(f"{where}: {best:.2f}:1")

    print(f"checked {STEPS + 1} positions across {len(grids)} places on "
          f"{len(stray_check.DEVICES)} devices, and {checked} "
          f"sprite/background pairs against {MINIMUM}:1")
    if worst[1]:
        print(f"worst: {worst[0]:.2f}:1 at {worst[1]}")
    if failures:
        unique = sorted(set(failures))
        print(f"\n{len(unique)} FAILED:")
        for line in unique[:30]:
            print(f"  {line}")
        if len(unique) > 30:
            print(f"  ... and {len(unique) - 30} more")
        return 1
    print("all pass")

    if "--preview" in sys.argv:
        index = sys.argv.index("--preview")
        path = (sys.argv[index + 1] if len(sys.argv) > index + 1
                else os.path.join(ROOT, "snail_preview.png"))
        preview(ground_line, size, skipped, path=path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
