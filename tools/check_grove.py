"""Check the grove: that it is a wood, and that it is the *same* wood forever.

Two jobs, and the first one matters more than it looks.

**The layout is a compatibility contract.** Where each tree stands is a pure
function of its index, so it is decided once for everybody who will ever grow a
forest. Somebody with fifty trees has to find the same fifty trees in the same
fifty places next year and the year after — a wood that silently rearranges
itself is worse than no wood, because it says the thing was never really
theirs. The stored fixture below is the whole of that promise: it was generated
once from the shipping constants and never changes again.

Everything above the fixture parses the real numbers out of `Grove.swift`,
which makes it self-consistent by construction — tweak a coefficient and the
geometry checks happily agree with the new one. Only the fixture notices. That
is the same two-halves shape `check_weather.py` uses, and for the same reason.

**And that it reads as a wood.** A scatter that clumps, lines up, or walks off
the edge is a bad picture, and none of it is visible until a forest is big.
This grows one to a hundred and twenty trees and measures.

    python3 tools/check_grove.py

Exits non-zero if anything fails.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import check_contrast as contrast_check
import generate_sprites as sprites

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")
GROVE_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "Grove.swift")
THEME_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "AppTheme.swift")

# --- The contract ----------------------------------------------------------
#
# Generated once from the shipping implementation. If this fails, the question
# is not "how do I regenerate the fixture" — it is "did I mean to move
# somebody's trees". Almost always the answer is no.
FIXTURE = (
    (0, 0.049056, 0.075810),
    (1, 0.609174, 0.434448),
    (2, 0.242131, 0.809512),
    (3, 0.817028, 0.338557),
    (7, 0.375431, 0.884058),
    (12, 0.401258, 0.942769),
    (25, 0.481681, 0.381661),
    (49, 0.303386, 0.330256),
    (60, 0.145395, 0.863082),
    (99, 0.199969, 0.091816),
    (119, 0.564143, 0.342470),
)

# How close two trees may stand, as a fraction of the grove's diagonal. Trees
# do overlap in a real wood — that is what a wood is — but two at the *same*
# point is one tree drawn twice, which reads as a rendering fault.
MINIMUM_SPACING = 0.012

# A tree has to be visible against the card it stands on. Lower than text: a
# tree is a shape, not a word.
MINIMUM_CONTRAST = 2.0


def parse_position():
    """The layout constants, out of `Grove.position(of:)`."""
    source = open(GROVE_FILE).read()
    body = source.split("static func position(of index: Int)")[1].split("\n    }")[0]

    multipliers = re.findall(r"index\) \* ([\d.]+)\)\.truncatingRemainder", body)
    if len(multipliers) != 2:
        raise SystemExit(
            f"could not parse the two golden multipliers from "
            f"Grove.position (found {multipliers})"
        )
    x = re.search(r"let x = ([\d.]+) \+ turn \* ([\d.]+)", body)
    y = re.search(r"let y = ([\d.]+) \+ depth \* ([\d.]+)", body)
    if not x or not y:
        raise SystemExit("could not parse the x/y mapping from Grove.position")

    jitter = re.search(r"let jitter = ([\d.]+)", body)
    if not jitter:
        raise SystemExit("could not parse the jitter from Grove.position")

    turn_k, depth_k = (float(v) for v in multipliers)
    return (turn_k, depth_k,
            float(x.group(1)), float(x.group(2)),
            float(y.group(1)), float(y.group(2)),
            float(jitter.group(1)))


def parse_capacity():
    source = open(GROVE_FILE).read()
    found = re.search(r"static let capacity = (\d+)", source)
    return int(found.group(1)) if found else 120


def main():
    turn_k, depth_k, x0, xs, y0, ys, jitter = parse_position()
    capacity = parse_capacity()

    def hashed(index, salt):
        """Mirrors `Grove.hash` — splitmix32."""
        mask = 0xFFFFFFFF
        z = (index * 0x9E3779B9 + salt) & mask
        z = ((z ^ (z >> 16)) * 0x85EBCA6B) & mask
        z = ((z ^ (z >> 13)) * 0xC2B2AE35) & mask
        return ((z ^ (z >> 16)) & mask) / float(mask)

    def position(index):
        turn = (index * turn_k) % 1
        depth = (index * depth_k) % 1
        x = x0 + turn * xs + (hashed(index, 1) - 0.5) * jitter
        y = y0 + depth * ys + (hashed(index, 7) - 0.5) * jitter
        return (min(0.97, max(0.03, x)), min(0.97, max(0.03, y)))

    failures = []

    # 1. The contract.
    for index, expected_x, expected_y in FIXTURE:
        x, y = position(index)
        if abs(x - expected_x) > 1e-6 or abs(y - expected_y) > 1e-6:
            failures.append(
                f"FIXTURE: tree {index} used to stand at "
                f"({expected_x:.4f}, {expected_y:.4f}) and now stands at "
                f"({x:.4f}, {y:.4f}) — this moves trees in a forest somebody "
                f"already has. See the note above FIXTURE."
            )

    # 2. Inside the frame, all the way to capacity.
    points = [position(index) for index in range(capacity)]
    for index, (x, y) in enumerate(points):
        if not (0 <= x <= 1 and 0 <= y <= 1):
            failures.append(f"tree {index} stands outside the grove at "
                            f"({x:.3f}, {y:.3f})")

    # 3. Never two in the same spot.
    closest = (99.0, None)
    for i, (ax, ay) in enumerate(points):
        for j, (bx, by) in enumerate(points[i + 1:], start=i + 1):
            distance = ((ax - bx) ** 2 + (ay - by) ** 2) ** 0.5
            if distance < closest[0]:
                closest = (distance, (i, j))
            if distance < MINIMUM_SPACING:
                failures.append(
                    f"trees {i} and {j} stand {distance:.4f} apart — that is "
                    f"one tree drawn twice, not two trees"
                )

    # 4. A scatter, not rows. Both halves of the frame get trees, and neither
    #    axis clusters into one band — the failure mode of a badly chosen
    #    multiplier, and invisible until a forest is large.
    for name, values in (("x", [p[0] for p in points]), ("y", [p[1] for p in points])):
        spread = max(values) - min(values)
        if spread < 0.6:
            failures.append(
                f"the trees only spread {spread:.2f} across {name} — the "
                f"layout has collapsed into a band"
            )
        halves = sum(1 for v in values if v > (min(values) + max(values)) / 2)
        if not (capacity * 0.3 < halves < capacity * 0.7):
            failures.append(
                f"{halves} of {capacity} trees sit in the far half of {name} "
                f"— the scatter is lopsided"
            )

    # 5. A scatter, not a lattice.
    #
    #    Added after the fact, and that is the point of writing it down: the
    #    first layout passed every rule above and still came out in visible
    #    diagonal stripes at thirty trees, because two multiplied-and-wrapped
    #    sequences form a lattice however irrational the multipliers are. It
    #    was caught by rendering a forest and looking at it. This measures the
    #    thing the eye was measuring — which direction near neighbours lie in.
    import math
    bins = [0] * 12
    close = [p for p in points[:40]]
    for index, (ax, ay) in enumerate(close):
        for bx, by in close[index + 1:]:
            dx, dy = bx - ax, by - ay
            if math.hypot(dx, dy) > 0.22:
                continue
            bins[int((math.degrees(math.atan2(dy, dx)) % 180) // 15)] += 1
    pairs = sum(bins) or 1
    crowded = max(bins) / pairs
    if crowded > 0.32:
        failures.append(
            f"{crowded * 100:.0f}% of near-neighbour pairs point the same way "
            f"(uniform would be 8%) — the wood has come out in rows"
        )

    # 6. Every tree reads against the card it stands on.
    palettes = contrast_check.parse_palettes(open(THEME_FILE).read())
    checked = 0
    worst = (99.0, None)
    for stage in ("sapling", "young", "full"):
        asset = f"grove_{stage}"
        path = os.path.join(ASSETS, f"{asset}.imageset", f"{asset}.png")
        if not os.path.exists(path):
            failures.append(f"{asset}: missing — run tools/generate_sprites.py")
            continue
        pixels = sprites_pixels(asset)
        for theme, colours in sorted(palettes.items()):
            for appearance in ("light", "dark"):
                def c(key):
                    return colours[key][appearance]

                # The grove card: surface at 55 % over the page, which is what
                # `GroveView` draws.
                card = contrast_check.over(c("surface"), c("cream"), 0.55)
                best = max(
                    contrast_check.contrast(colour, card) for colour in pixels
                )
                checked += 1
                where = f"{asset}/{theme}/{appearance}"
                if best < worst[0]:
                    worst = (best, where)
                if best < MINIMUM_CONTRAST:
                    failures.append(f"{where}: {best:.2f}:1")

    print(f"worst direction bucket: {crowded * 100:.0f}% of near pairs")
    print(f"checked {capacity} tree positions, {len(FIXTURE)} fixture rows and "
          f"{checked} sprite/card pairs")
    print(f"closest two trees: {closest[0]:.4f} "
          f"(trees {closest[1][0]} and {closest[1][1]})")
    if worst[1]:
        print(f"faintest tree: {worst[0]:.2f}:1 at {worst[1]}")
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


def sprites_pixels(asset):
    """Every distinct colour the sprite is made of, 0..1."""
    from PIL import Image
    import numpy as np

    path = os.path.join(ASSETS, f"{asset}.imageset", f"{asset}.png")
    image = np.array(Image.open(path).convert("RGBA"))
    step = sprites.UPSCALE
    logical = image[step // 2::step, step // 2::step]
    opaque = logical[..., 3] > 0
    return [
        tuple(v / 255.0 for v in colour)
        for colour in {tuple(c) for c in logical[opaque][:, :3].tolist()}
    ]


if __name__ == "__main__":
    sys.exit(main())
