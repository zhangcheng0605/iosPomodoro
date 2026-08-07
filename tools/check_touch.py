"""Check the touch vocabulary: that every spot is on the animal and findable.

`TouchSpot` derives its regions from the same anchors the wardrobe measures,
which means it inherits the wardrobe's failure mode: a region that is correct
on eleven buddies and hanging in the air beside the twelfth. Four spots x
twelve buddies x a dozen frames is past what anybody will check by hand, and
unlike a hat a bad region is *invisible* — the buddy simply never reacts to
that part of itself and nobody can tell whether that was the design.

So, for every frame the app can draw:

1. **Is the spot on the animal?** Its centre has to be over real pixels. A
   region floating beside the chin is a spot that silently does nothing.
2. **Is it big enough to hit?** A finger is about 44pt; the buddy is drawn at
   104pt across forty grid units, so a region under about four units square is
   a target nobody can aim at.
3. **Do they overlap so much they are one spot?** `TouchSpot.at` resolves ties
   by nearest centre, but two regions sharing most of their area means one of
   them can never win, which is the same bug as not existing.
4. **Can every buddy's favourite actually be found?** The one rule that is
   about the *feature* rather than the geometry: a favourite whose region is
   broken on the resting pose is a buddy with no discoverable secret, and the
   discovery is the whole point.

The region arithmetic is a port of `TouchSpot.region(on:)` and must stay one —
if the two disagree, this file is wrong.

    python3 tools/check_touch.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np

import check_accessories as wardrobe
import generate_sprites as gs

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")
MODEL = os.path.join(ROOT, "Pawmodoro", "Model")

# Grid units. The buddy is drawn at 104pt over a 40-unit canvas, so one unit is
# about 2.6pt and a four-unit region is a ~10pt target — small, but it is a
# region on a creature rather than a button, and the surrounding spots catch
# the misses.
MINIMUM_SIDE = 4.0

# How much of a region may be shared with another before one of them can never
# win the nearest-centre tie-break.
MAXIMUM_OVERLAP = 0.55


def parse_shapes():
    """The real coefficients, out of `TouchSpot.shape`.

    **Parsed, not restated.** The first version of this file carried its own
    copy of these numbers, and every deliberate break passed cleanly — the
    checker was agreeing with itself. CLAUDE.md records the same trap twice
    from `check_weather` and `check_yearring`; this is the third.
    """
    source = open(os.path.join(MODEL, "TouchSpot.swift")).read()
    body = source.split("var shape: (x: CGFloat")[1].split("\n    }")[0]
    found = re.findall(
        r"case \.(\w+): \(([-\d.]+), ([-\d.]+), ([-\d.]+), ([-\d.]+)\)", body)
    shapes = {name: tuple(float(v) for v in rest) for name, *rest in
              [(m[0], m[1], m[2], m[3], m[4]) for m in found]}
    limits = {}
    for name in ("minimumHead", "minimumTummy"):
        match = re.search(rf"static let {name}: CGFloat = ([\d.]+)", source)
        if not match:
            raise SystemExit(f"could not parse TouchSpot.{name}")
        limits[name] = float(match.group(1))
    if len(shapes) != 4:
        raise SystemExit(f"could not parse TouchSpot.shape (found {shapes})")
    return shapes, limits


def regions(anchors, shapes, limits):
    """A port of `TouchSpot.region(on:)`, driven by the parsed numbers."""
    tall = anchors["neck"][1] - anchors["head"][1]
    if tall < limits["minimumHead"]:
        return {}
    boxes = {}
    for name, (bx, by, bw, bh) in shapes.items():
        on_head = name in ("crown", "nose")
        anchor = anchors["head"] if on_head else anchors["neck"]
        reference = anchors["headWidth"] if on_head else anchors["neckWidth"]
        x = anchor[0] + reference * bx
        y = anchor[1] + tall * by
        width = reference * bw
        if name == "tummy":
            height = anchors["bottom"] - y - 1
            if height < limits["minimumTummy"]:
                continue
            boxes[name] = (x, y, width, height)
        else:
            boxes[name] = (x, y, width, tall * bh)
    return boxes


def parse_favourites():
    source = open(os.path.join(MODEL, "TouchSpot.swift")).read()
    body = source.split("var favouriteSpot: TouchSpot {")[1].split("\n    }")[0]
    return dict(re.findall(r"case \.(\w+): \.(\w+)", body))


def overlap(a, b):
    wide = min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])
    tall = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
    return max(0.0, wide) * max(0.0, tall)


def main():
    failures = []
    anchors = wardrobe.parse_anchors()
    shapes, limits = parse_shapes()
    favourites = parse_favourites()
    canvas = gs.S

    on_disk = sorted(
        d[:-len(".imageset")] for d in os.listdir(ASSETS)
        if d.startswith("buddy_") and d.endswith(".imageset")
    )

    checked = 0
    skipped = 0
    smallest = (999.0, None)
    for asset in on_disk:
        if asset not in anchors:
            continue
        sprite = wardrobe.logical(asset)
        if sprite is None:
            continue
        solid = sprite[..., 3] > 0
        boxes = regions(anchors[asset], shapes, limits)
        if not boxes:
            skipped += 1
            continue

        for name, box in sorted(boxes.items()):
            checked += 1
            side = min(box[2], box[3])
            if side < smallest[0]:
                smallest = (side, f"{name}/{asset}")
            # Enforced on the poses the buddy actually holds. The regions
            # tile, so a near-miss on a transient frame lands on a neighbour
            # and still gets a reaction — but a resting pose is where somebody
            # spends minutes hunting for the favourite, and a sliver there is
            # a spot that cannot be found.
            if side < MINIMUM_SIDE and asset.endswith(("_awake", "_asleep")):
                failures.append(
                    f"{name} on {asset} is {box[2]:.1f}x{box[3]:.1f} units — "
                    f"too small to aim at on a pose the buddy holds")
                continue

            cx = int(round(min(canvas - 1, max(0, box[0] + box[2] / 2))))
            cy = int(round(min(canvas - 1, max(0, box[1] + box[3] / 2))))
            if not solid[cy, cx]:
                failures.append(
                    f"{name} on {asset} centres at ({cx}, {cy}), which is not on "
                    f"the animal — that spot silently never reacts")

        for first in sorted(boxes):
            for second in sorted(boxes):
                if first >= second:
                    continue
                shared = overlap(boxes[first], boxes[second])
                area = min(boxes[first][2] * boxes[first][3],
                           boxes[second][2] * boxes[second][3])
                if area > 0 and shared / area > MAXIMUM_OVERLAP:
                    failures.append(
                        f"{first} and {second} on {asset} share "
                        f"{shared / area * 100:.0f}% of the smaller region — one "
                        f"of them can never win the tie-break")

    # The favourite has to work on the pose the buddy actually holds.
    for buddy, spot in sorted(favourites.items()):
        asset = f"buddy_{buddy}_awake"
        if asset not in anchors:
            failures.append(f"{buddy} has no anchors for its resting pose")
            continue
        sprite = wardrobe.logical(asset)
        found = regions(anchors[asset], shapes, limits)
        if spot not in found:
            failures.append(
                f"{buddy}'s favourite spot ({spot}) has no region on its "
                f"resting pose — that buddy has a secret nobody can find")
            continue
        box = found[spot]
        cx = int(round(box[0] + box[2] / 2))
        cy = int(round(box[1] + box[3] / 2))
        if not (0 <= cx < canvas and 0 <= cy < canvas) \
                or not (sprite[..., 3] > 0)[cy, cx]:
            failures.append(
                f"{buddy}'s favourite spot ({spot}) is not on it when awake — "
                f"that buddy has a secret nobody can find")

    print(f"checked {checked} touch regions across {len(on_disk)} frames "
          f"and {len(favourites)} favourites")
    print(f"{skipped} frames have no regions at all — the lying-down poses, "
          f"where a chin is a guess")
    if smallest[1]:
        print(f"smallest region: {smallest[0]:.1f} units at {smallest[1]}")
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
