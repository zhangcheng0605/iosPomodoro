"""Check that every clock face is actually a clock.

The Cabinet of Clocks renders the same interval seven other ways, at one frame
every two minutes. That rate is what makes this file necessary: a face that
stalls for a third of the phase, jumps backward, finishes early or never
finishes at all is an art regression nobody could catch by watching. You would
have to sit through a whole session with a stopwatch, in each of seven faces,
to see what this measures in a second.

Every face obeys one convention — **the pixels drawn in `ACCENT` are the part
that grows with time**: the wax pool, the fallen sand, the ash, the risen
water, the swept shadow, the opened petals, the risen light. So one assertion
covers all seven:

  * that quantity **never decreases** from frame to frame
  * it **actually moves** — a face that ends where it started is a picture
  * it starts near empty and ends near full, so the face agrees with the
    countdown rather than finishing at two-thirds
  * every frame reads against the dial it is drawn on, in all eight themes

    python3 tools/check_clocks.py [--preview <path>]

Exits non-zero if anything fails.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import check_contrast as contrast_check
import generate_clocks as clocks
import generate_sprites as sprites

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")
THEME_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "AppTheme.swift")

# The face sits on the timer dial, which is `Theme.cream` at 82 % over
# whatever scenery is behind it. Mirrors `TimerRingView`.
DIAL_OPACITY = 0.82

# A shape on a dial, not a word on a page.
MINIMUM_CONTRAST = 2.0

# How much of the way the growing part has to have travelled by the last
# frame. Not 100 %: a candle leaves a stub and an hourglass keeps a grain or
# two in the neck. But a face that has only moved two thirds by the chime is
# telling the wrong time.
MINIMUM_TRAVEL = 0.90


def accent_pixels(name, frame):
    """How much of the growing part is drawn, in logical pixels."""
    asset = f"clock_{name}_{frame}"
    path = os.path.join(ASSETS, f"{asset}.imageset", f"{asset}.png")
    if not os.path.exists(path):
        return None, None
    image = np.array(Image.open(path).convert("RGBA"))
    step = sprites.UPSCALE
    logical = image[step // 2::step, step // 2::step]
    target = np.array(clocks.CLOCK_PALETTE[sprites.ACCENT][:3], dtype=np.int16)
    rgb = logical[..., :3].astype(np.int16)
    grown = int((np.abs(rgb - target).sum(axis=2) == 0).sum())
    opaque = logical[logical[..., 3] > 0][:, :3]
    colours = {tuple(c) for c in opaque.tolist()}
    return grown, colours


def preview(path):
    """Every face, every frame, on a dial — so they can be looked at."""
    palettes = contrast_check.parse_palettes(open(THEME_FILE).read())
    dial = contrast_check.over(
        palettes["sakura"]["cream"]["light"],
        palettes["sakura"]["blush"]["light"], DIAL_OPACITY,
    )
    scale, pad = 3, 6
    cell_w, cell_h = clocks.W * scale + pad, clocks.H * scale + pad
    sheet = Image.new(
        "RGBA",
        (cell_w * clocks.FRAMES + pad, cell_h * len(clocks.FACES) + pad),
        tuple(int(v * 255) for v in dial) + (255,),
    )
    for row, name in enumerate(clocks.FACES):
        for frame in range(clocks.FRAMES):
            asset = f"clock_{name}_{frame}"
            img = Image.open(
                os.path.join(ASSETS, f"{asset}.imageset", f"{asset}.png")
            ).convert("RGBA").resize(
                (clocks.W * scale, clocks.H * scale), Image.NEAREST
            )
            sheet.alpha_composite(
                img, (pad + frame * cell_w, pad + row * cell_h)
            )
    sheet.save(path)
    print(f"wrote {path}")


def main():
    palettes = contrast_check.parse_palettes(open(THEME_FILE).read())
    failures = []
    checked = 0
    worst = (99.0, None)

    for name in clocks.FACES:
        series = []
        for frame in range(clocks.FRAMES):
            grown, colours = accent_pixels(name, frame)
            if grown is None:
                failures.append(
                    f"clock_{name}_{frame}: missing — run "
                    f"tools/generate_clocks.py"
                )
                break
            series.append(grown)

            # Legible on the dial, in every theme and appearance.
            for theme, palette in sorted(palettes.items()):
                for appearance in ("light", "dark"):
                    def c(key):
                        return palette[key][appearance]

                    dial = contrast_check.over(
                        c("cream"), c("blush"), DIAL_OPACITY
                    )
                    best = max(
                        contrast_check.contrast(
                            tuple(v / 255.0 for v in colour), dial
                        )
                        for colour in colours
                    )
                    checked += 1
                    where = f"{name}[{frame}]/{theme}/{appearance}"
                    if best < worst[0]:
                        worst = (best, where)
                    if best < MINIMUM_CONTRAST:
                        failures.append(f"{where}: {best:.2f}:1")
        else:
            # 1. Never backwards. A clock that un-burns is the whole reason
            #    this file exists.
            for frame in range(1, len(series)):
                if series[frame] < series[frame - 1]:
                    failures.append(
                        f"{name}: frame {frame} has less grown than frame "
                        f"{frame - 1} ({series[frame]} vs "
                        f"{series[frame - 1]}) — the clock runs backwards"
                    )
            # 2. Actually moves, and does not stall for a stretch.
            if series[-1] <= series[0]:
                failures.append(
                    f"{name}: ends where it started ({series[0]} -> "
                    f"{series[-1]}) — this is a picture, not a clock"
                )
            else:
                stalled = sum(
                    1 for f in range(1, len(series)) if series[f] == series[f - 1]
                )
                if stalled > 2:
                    failures.append(
                        f"{name}: stalls for {stalled} of "
                        f"{len(series) - 1} steps — the phase would look "
                        f"frozen for {stalled * 2} minutes"
                    )
                # 3. Finishes when the phase does.
                travel = (series[-1] - series[0]) / max(series)
                if travel < MINIMUM_TRAVEL:
                    failures.append(
                        f"{name}: only travels {travel * 100:.0f}% of its own "
                        f"range — the face finishes before or after the chime"
                    )
        print(f"  {name}: {series}")

    print(f"checked {len(clocks.FACES)} faces x {clocks.FRAMES} frames, "
          f"and {checked} sprite/dial pairs against {MINIMUM_CONTRAST}:1")
    if worst[1]:
        print(f"faintest: {worst[0]:.2f}:1 at {worst[1]}")
    if failures:
        unique = sorted(set(failures))
        print(f"\n{len(unique)} FAILED:")
        for line in unique[:20]:
            print(f"  {line}")
        if len(unique) > 20:
            print(f"  ... and {len(unique) - 20} more")
        return 1
    print("all pass")

    if "--preview" in sys.argv:
        index = sys.argv.index("--preview")
        preview(sys.argv[index + 1] if len(sys.argv) > index + 1
                else os.path.join(ROOT, "clocks.png"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
