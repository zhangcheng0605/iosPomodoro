"""Generate the wildlife that shows up while you hold still.

Same discipline as the other generators: index grids, nearest-neighbour
upscale, nothing to license. Each species is drawn twice — two frames are
enough for a wingbeat, a step or a tail flick — and each pair is exported four
ways:

    wild_{id}_0, wild_{id}_1   the animal itself
    wild_{id}_ghost            a flat silhouette, for species not yet seen
    wild_{id}_sketch           a sepia field-sketch, for the journal

The last two are palette transforms of frame 0, not redrawings, for the same
reason the places get four times of day from one drawing.

    python3 tools/generate_wildlife.py

Species ids must match `Species` in Pawmodoro/Model/Species.swift.
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw

UPSCALE = 6
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")

T, OUTLINE, MAIN, SHADE, LIGHT, ACCENT, EYE, GLINT = range(8)

# The journal's two derived looks.
GHOST = {T: (0, 0, 0, 0), **{i: (58, 48, 44, 255) for i in range(1, 8)}}


def sepia(palette):
    """Desaturate toward a warm paper brown — a pressed field-sketch rather
    than a colour photo, so 'seen' and 'in the wild' never look the same."""
    out = {}
    for index, rgba in palette.items():
        if index == T:
            out[index] = rgba
            continue
        r, g, b, a = rgba
        grey = 0.299 * r + 0.587 * g + 0.114 * b
        out[index] = (
            int(min(255, grey * 0.62 + 86)),
            int(min(255, grey * 0.56 + 62)),
            int(min(255, grey * 0.46 + 44)),
            a,
        )
    return out


def to_png(grid, palette, name):
    arr = np.array(grid)
    height, width = arr.shape
    rgba = np.zeros((height, width, 4), dtype=np.uint8)
    for index, colour in palette.items():
        rgba[arr == index] = colour
    image = Image.fromarray(rgba, mode="RGBA")
    image = image.resize((width * UPSCALE, height * UPSCALE), Image.NEAREST)

    folder = os.path.join(ASSETS, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    image.save(os.path.join(folder, f"{name}.png"), "PNG")
    with open(os.path.join(folder, "Contents.json"), "w") as handle:
        json.dump(
            {
                "images": [{"filename": f"{name}.png", "idiom": "universal"}],
                "info": {"author": "xcode", "version": 1},
            },
            handle,
            indent=2,
        )


def grid(width, height):
    return Image.new("L", (width, height), T)


def outline(image):
    arr = np.array(image)
    solid = np.pad(arr != T, 1)
    neighbours = np.zeros_like(solid)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        neighbours |= np.roll(np.roll(solid, dy, axis=0), dx, axis=1)
    arr[(neighbours & ~solid)[1:-1, 1:-1]] = OUTLINE
    return Image.fromarray(arr, mode="L")


# --- Palettes --------------------------------------------------------------

def palette(main, shade, light, accent, ink=(52, 40, 34)):
    return {
        T: (0, 0, 0, 0),
        OUTLINE: (*ink, 255),
        MAIN: (*main, 255),
        SHADE: (*shade, 255),
        LIGHT: (*light, 255),
        ACCENT: (*accent, 255),
        EYE: (34, 28, 26, 255),
        GLINT: (255, 255, 255, 255),
    }


P = {
    "butterfly": palette((238, 168, 96), (208, 130, 62), (255, 226, 178), (92, 62, 48)),
    "robin": palette((132, 110, 96), (98, 80, 70), (232, 220, 200), (216, 96, 62)),
    "squirrel": palette((198, 110, 62), (162, 84, 46), (244, 226, 206), (120, 68, 44)),
    "frog": palette((124, 182, 96), (92, 148, 72), (222, 240, 200), (72, 108, 60)),
    "stag": palette((166, 122, 84), (132, 94, 64), (232, 214, 190), (108, 84, 62)),
    "gull": palette((250, 250, 252), (206, 212, 222), (255, 255, 255), (240, 176, 66)),
    "otter": palette((136, 100, 74), (104, 74, 54), (214, 190, 166), (74, 54, 42)),
    "dolphin": palette((132, 156, 182), (98, 122, 150), (226, 234, 242), (64, 84, 108)),
    "whale": palette((92, 112, 140), (68, 86, 112), (206, 220, 234), (48, 62, 84)),
    "moth": palette((226, 208, 168), (194, 172, 132), (250, 240, 214), (120, 100, 76)),
    "koi": palette((246, 152, 74), (214, 110, 44), (255, 246, 234), (176, 74, 30)),
    "crane": palette((250, 250, 250), (214, 218, 226), (255, 255, 255), (214, 76, 62)),
}


# --- The species -----------------------------------------------------------
#
# Each returns two frames. The pair is the animation: a wingbeat, a step, a
# tail flick. Anything more would be invisible at this size.

def butterfly(up):
    g = grid(15, 12)
    d = ImageDraw.Draw(g)
    spread = 0 if up else 2
    # Upper and lower wings as triangles, split by a dark body — drawn as two
    # ellipses the first time, it read as a pair of orange beans.
    d.polygon([(7, 5), (1, 0 + spread), (0, 5)], fill=MAIN)
    d.polygon([(7, 5), (13, 0 + spread), (14, 5)], fill=MAIN)
    d.polygon([(7, 6), (1, 10), (4, 11)], fill=SHADE)
    d.polygon([(7, 6), (13, 10), (10, 11)], fill=SHADE)
    d.point((3, 3 + spread), fill=LIGHT)
    d.point((11, 3 + spread), fill=LIGHT)
    d.line([(7, 2), (7, 10)], fill=ACCENT)
    d.point((6, 1), fill=ACCENT)
    d.point((8, 1), fill=ACCENT)
    return outline(g)


def robin(step):
    g = grid(15, 13)
    d = ImageDraw.Draw(g)
    d.ellipse([3, 3, 12, 11], fill=MAIN)
    d.ellipse([4, 6, 10, 11], fill=ACCENT)                        # red breast
    d.ellipse([1, 1, 7, 7], fill=MAIN)                            # head
    d.point((3, 3), fill=EYE)
    d.polygon([(0, 4), (2, 3), (2, 5)], fill=ACCENT)              # beak
    d.ellipse([9, 4, 14, 8], fill=SHADE)                          # wing
    legs = 11 if step else 12
    d.line([(5, 11), (5, legs)], fill=ACCENT)
    d.line([(8, 11), (8, legs)], fill=ACCENT)
    return outline(g)


def squirrel(step):
    g = grid(16, 18)
    d = ImageDraw.Draw(g)
    curl = 0 if step else 1
    # The tail is the squirrel: a big plume behind, drawn wide then narrowed so
    # it reads as fur rather than as a row of circles.
    for x, y in ((12, 14), (14, 10), (13, 6), (10, 3 + curl)):
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=SHADE)
    for x, y in ((12, 14), (14, 10), (13, 6), (10, 3 + curl)):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=MAIN)
    d.ellipse([3, 8, 10, 16], fill=MAIN)                          # upright body
    d.ellipse([4, 11, 9, 16], fill=LIGHT)
    d.ellipse([2, 3, 9, 10], fill=MAIN)                           # head
    d.polygon([(3, 3), (4, 0), (6, 3)], fill=SHADE)               # ears
    d.polygon([(6, 3), (8, 0), (9, 3)], fill=SHADE)
    d.point((4, 6), fill=EYE)
    d.point((2, 7), fill=ACCENT)
    return outline(g)


def frog(hop):
    g = grid(13, 11)
    d = ImageDraw.Draw(g)
    lift = 1 if hop else 0
    d.ellipse([2, 4 - lift, 10, 10 - lift], fill=MAIN)            # body
    d.ellipse([3, 7 - lift, 9, 10 - lift], fill=LIGHT)
    d.ellipse([2, 1 - lift, 5, 4 - lift], fill=MAIN)              # eyes on top
    d.ellipse([7, 1 - lift, 10, 4 - lift], fill=MAIN)
    d.point((3, 2 - lift), fill=EYE)
    d.point((8, 2 - lift), fill=EYE)
    d.ellipse([0, 6 - lift, 3, 9 - lift], fill=SHADE)             # legs
    d.ellipse([9, 6 - lift, 12, 9 - lift], fill=SHADE)
    return outline(g)


def stag(head_up):
    g = grid(25, 23)
    d = ImageDraw.Draw(g)
    lift = 0 if head_up else 5
    # Antlers, only worth drawing when the head is up.
    if head_up:
        for x0, direction in ((6, -1), (11, 1)):
            d.line([(x0, 5), (x0 + direction * 2, 1)], fill=ACCENT)
            d.line([(x0 + direction, 3), (x0 + direction * 4, 2)], fill=ACCENT)
    d.ellipse([9, 9, 23, 17], fill=MAIN)                          # body
    d.ellipse([11, 13, 21, 17], fill=LIGHT)
    d.line([(11, 16), (11, 22)], fill=SHADE, width=2)             # legs
    d.line([(15, 16), (15, 22)], fill=SHADE, width=2)
    d.line([(20, 16), (20, 22)], fill=SHADE, width=2)
    d.line([(9, 11), (7, 5 + lift)], fill=MAIN, width=3)          # neck
    d.ellipse([4, 3 + lift, 12, 9 + lift], fill=MAIN)             # head
    d.polygon([(3, 5 + lift), (7, 5 + lift), (6, 9 + lift)], fill=SHADE)
    d.point((6, 5 + lift), fill=EYE)
    d.ellipse([21, 9, 24, 13], fill=LIGHT)                        # tail
    return outline(g)


def gull(down):
    g = grid(17, 11)
    d = ImageDraw.Draw(g)
    if down:
        d.polygon([(0, 8), (8, 4), (16, 8)], fill=MAIN)
        d.polygon([(2, 8), (8, 5), (14, 8)], fill=SHADE)
    else:
        d.polygon([(0, 1), (8, 5), (16, 1)], fill=MAIN)
        d.polygon([(3, 2), (8, 5), (13, 2)], fill=SHADE)
    d.ellipse([6, 3, 10, 8], fill=LIGHT)                          # body
    d.point((7, 4), fill=EYE)
    d.point((5, 5), fill=ACCENT)                                  # beak
    return outline(g)


def otter(roll):
    g = grid(21, 13)
    d = ImageDraw.Draw(g)
    d.ellipse([2, 4, 17, 11], fill=MAIN)                          # floating body
    d.ellipse([4, 6, 15, 11], fill=LIGHT)                         # pale belly
    d.ellipse([15, 2, 20, 7], fill=MAIN)                          # head
    d.point((17, 4), fill=EYE)
    d.point((19, 4), fill=ACCENT)
    paws = 3 if roll else 4
    d.ellipse([8, paws, 11, paws + 3], fill=SHADE)                # paws holding
    d.ellipse([0, 7, 4, 10], fill=SHADE)                          # tail
    d.point((9, paws + 1), fill=GLINT)                            # the shell
    return outline(g)


def dolphin(high):
    g = grid(23, 15)
    d = ImageDraw.Draw(g)
    lift = 0 if high else 2
    d.ellipse([3, 4 + lift, 19, 11 + lift], fill=MAIN)
    d.ellipse([5, 7 + lift, 17, 11 + lift], fill=LIGHT)
    d.polygon([(9, 4 + lift), (12, 0 + lift), (14, 4 + lift)], fill=SHADE)   # fin
    d.polygon([(0, 5 + lift), (4, 7 + lift), (0, 10 + lift)], fill=SHADE)    # tail
    d.polygon([(19, 7 + lift), (22, 8 + lift), (19, 9 + lift)], fill=MAIN)   # beak
    d.point((17, 7 + lift), fill=EYE)
    return outline(g)


def whale(spout):
    g = grid(31, 17)
    d = ImageDraw.Draw(g)
    if spout:
        for y in range(0, 4):
            d.point((9, y), fill=LIGHT)
            d.point((8 - y // 2, y), fill=LIGHT)
            d.point((10 + y // 2, y), fill=LIGHT)
    d.ellipse([2, 6, 24, 15], fill=MAIN)                          # back
    d.ellipse([5, 10, 22, 15], fill=LIGHT)
    for x in range(6, 20, 3):                                     # throat pleats
        d.line([(x, 12), (x, 15)], fill=SHADE)
    d.polygon([(23, 8), (30, 4), (28, 11)], fill=SHADE)           # fluke
    d.point((6, 9), fill=EYE)
    return outline(g)


def moth(up):
    g = grid(13, 11)
    d = ImageDraw.Draw(g)
    spread = 0 if up else 2
    d.polygon([(6, 3), (0, 1 + spread), (1, 8)], fill=MAIN)
    d.polygon([(6, 3), (12, 1 + spread), (11, 8)], fill=MAIN)
    d.polygon([(6, 4), (2, 3 + spread), (3, 7)], fill=LIGHT)
    d.polygon([(6, 4), (10, 3 + spread), (9, 7)], fill=LIGHT)
    d.line([(6, 2), (6, 8)], fill=ACCENT)
    d.point((5, 1), fill=ACCENT)
    d.point((7, 1), fill=ACCENT)
    return outline(g)


def koi(flick):
    g = grid(19, 11)
    d = ImageDraw.Draw(g)
    bend = 1 if flick else 0
    d.ellipse([3, 3 + bend, 15, 9 + bend], fill=MAIN)
    d.ellipse([5, 4 + bend, 11, 7 + bend], fill=LIGHT)            # patches
    d.ellipse([11, 6 + bend, 14, 8 + bend], fill=SHADE)
    d.polygon([(15, 4 + bend), (18, 1 + bend), (18, 9 + bend)], fill=SHADE)
    d.polygon([(7, 3 + bend), (9, 0 + bend), (11, 3 + bend)], fill=SHADE)
    d.point((5, 5 + bend), fill=EYE)
    return outline(g)


def crane(head_up):
    g = grid(17, 23)
    d = ImageDraw.Draw(g)
    lift = 0 if head_up else 4
    d.ellipse([4, 11, 14, 18], fill=MAIN)                         # body
    d.ellipse([5, 13, 12, 18], fill=SHADE)
    d.polygon([(12, 12), (16, 16), (12, 17)], fill=SHADE)         # tail
    d.line([(7, 12), (6, 5 + lift)], fill=MAIN, width=2)          # long neck
    d.ellipse([3, 2 + lift, 8, 6 + lift], fill=MAIN)              # head
    d.point((5, 3 + lift), fill=EYE)
    d.point((4, 3 + lift), fill=ACCENT)                           # red crown
    d.polygon([(0, 4 + lift), (3, 3 + lift), (3, 5 + lift)], fill=ACCENT)
    d.line([(9, 18), (9, 22)], fill=ACCENT)                       # one leg down
    if head_up:
        d.line([(11, 18), (12, 20)], fill=ACCENT)
    return outline(g)


SPECIES = {
    "butterfly": butterfly,
    "robin": robin,
    "squirrel": squirrel,
    "frog": frog,
    "stag": stag,
    "gull": gull,
    "otter": otter,
    "dolphin": dolphin,
    "whale": whale,
    "moth": moth,
    "koi": koi,
    "crane": crane,
}


if __name__ == "__main__":
    print("Wildlife:")
    for name, draw in SPECIES.items():
        pal = P[name]
        first, second = draw(True), draw(False)
        to_png(first, pal, f"wild_{name}_0")
        to_png(second, pal, f"wild_{name}_1")
        # The journal's two states, derived rather than drawn again.
        to_png(first, GHOST, f"wild_{name}_ghost")
        to_png(first, sepia(pal), f"wild_{name}_sketch")
        print(f"  {name}: 2 frames + ghost + sketch")
