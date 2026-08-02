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




# --- Body-plan templates ----------------------------------------------------
#
# Wave 2 roughly triples the roster, and twenty-six one-off drawings would be
# twenty-six things to maintain. Most of them are the same two animals wearing
# different hats: a perched bird and a standing quadruped. Parameterising those
# two shapes covers eighteen species, so "more sightings" stays a table edit.

def songbird(step, *, crest=0, beak=2, tail=5, legs=3, breast=False,
             wing=True, width=18, height=15, plump=0):
    """Perched small bird. Two frames differ by a leg shift and a wing lift."""
    g = grid(width, height)
    d = ImageDraw.Draw(g)
    top = 2 + crest
    body_y = top + 3

    d.polygon([(11, body_y + 2), (11 + tail, body_y - 1), (11 + tail, body_y + 6)], fill=SHADE)
    d.ellipse([4, body_y, 12 + plump, body_y + 8], fill=MAIN)
    if breast:
        d.ellipse([5, body_y + 3, 11, body_y + 8], fill=ACCENT)
    d.ellipse([2, top, 9, top + 7], fill=MAIN)
    if crest:
        d.polygon([(4, top), (6, top - crest), (8, top + 1)], fill=SHADE)
    d.point((4, top + 2), fill=EYE)
    d.polygon([(2 - beak, top + 3), (2, top + 2), (2, top + 4)], fill=ACCENT)
    if wing:
        lift = 1 if step else 0
        d.ellipse([7, body_y + 1 - lift, 12, body_y + 6 - lift], fill=SHADE)
    foot = body_y + 8
    for x in (6, 9):
        d.line([(x, foot), (x, foot + legs - (1 if step else 0))], fill=ACCENT)
    return outline(g)


def quadruped(step, *, width=22, height=18, ear="round", tail="stub",
              horns=False, belly=True, leg=5, neck=1, snout=0):
    """Standing four-legged animal, head to the left."""
    g = grid(width, height)
    d = ImageDraw.Draw(g)
    body_top = height - leg - 9
    back = width - 4

    d.ellipse([6, body_top, back, body_top + 9], fill=MAIN)
    if belly:
        d.ellipse([8, body_top + 5, back - 2, body_top + 9], fill=LIGHT)
    for index, x in enumerate((8, 11, back - 5, back - 2)):
        drop = leg - (1 if (step and index % 2 == 0) else 0)
        d.line([(x, body_top + 8), (x, body_top + 8 + drop)], fill=SHADE, width=2)

    head_y = body_top - neck
    d.ellipse([1, head_y, 9, head_y + 7], fill=MAIN)
    if snout:
        d.ellipse([0, head_y + 3, 3 + snout, head_y + 7], fill=LIGHT)
    if ear == "round":
        d.ellipse([2, head_y - 2, 5, head_y + 1], fill=SHADE)
    elif ear == "point":
        d.polygon([(2, head_y + 1), (3, head_y - 3), (6, head_y)], fill=SHADE)
    elif ear == "long":
        d.ellipse([3, head_y - 6, 6, head_y + 1], fill=SHADE)
    if horns:
        d.line([(5, head_y), (8, head_y - 5)], fill=ACCENT)
        d.line([(7, head_y - 3), (9, head_y - 4)], fill=ACCENT)
    d.point((4, head_y + 2), fill=EYE)

    if tail == "bushy":
        for i, (x, y) in enumerate(((back, body_top + 2), (back + 2, body_top - 1))):
            d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=SHADE if i else MAIN)
    elif tail == "stub":
        d.ellipse([back - 1, body_top + 1, back + 2, body_top + 4], fill=LIGHT)
    elif tail == "long":
        d.line([(back, body_top + 2), (back + 3, body_top - 3)], fill=SHADE, width=2)
    return outline(g)


# --- Wave 2 species ---------------------------------------------------------

def bee(up):
    g = grid(11, 9); d = ImageDraw.Draw(g)
    spread = 0 if up else 1
    d.ellipse([1, 1 + spread, 6, 5 + spread], fill=LIGHT)      # wings
    d.ellipse([5, 1 + spread, 10, 5 + spread], fill=LIGHT)
    d.ellipse([2, 3, 9, 8], fill=MAIN)
    for x in (4, 6, 8):
        d.line([(x, 3), (x, 8)], fill=ACCENT)
    d.point((3, 4), fill=EYE)
    return outline(g)


def dragonfly(up):
    g = grid(17, 11); d = ImageDraw.Draw(g)
    spread = 0 if up else 1
    # Four wings, held clear of a long thin body — drawn as fat ovals the
    # first time, it read as a moth that had been sat on.
    for x0 in (2, 9):
        d.polygon([(8, 4), (x0, 1 + spread), (x0 + 5, 3 + spread)], fill=LIGHT)
        d.polygon([(8, 6), (x0, 9 - spread), (x0 + 5, 7 - spread)], fill=LIGHT)
    d.line([(7, 3), (16, 7)], fill=MAIN, width=2)
    for x in range(9, 16, 2):
        d.point((x, 3 + (x - 7) // 2), fill=SHADE)
    d.ellipse([4, 2, 8, 6], fill=ACCENT)
    d.point((5, 3), fill=GLINT)
    return outline(g)


def firefly(lit):
    g = grid(10, 8); d = ImageDraw.Draw(g)
    d.ellipse([1, 1, 5, 4], fill=LIGHT)
    d.ellipse([2, 2, 8, 6], fill=MAIN)
    if lit:
        d.ellipse([6, 3, 9, 6], fill=ACCENT)
        d.point((7, 2), fill=GLINT)
    else:
        d.ellipse([6, 3, 9, 6], fill=SHADE)
    return outline(g)


def hedgehog(step):
    g = grid(19, 12); d = ImageDraw.Draw(g)
    d.ellipse([3, 4, 15, 11], fill=MAIN)
    # Spines: without them this is just a small brown animal.
    for x in range(4, 15, 2):
        top = 3 - (1 if x % 4 else 0)
        d.line([(x, 6), (x - 1, top)], fill=SHADE)
    d.ellipse([13, 6, 18, 11], fill=LIGHT)
    d.point((16, 8), fill=EYE)
    d.point((18, 9), fill=ACCENT)
    drop = 0 if step else 1
    for x in (6, 11):
        d.line([(x, 11), (x, 11 + drop)], fill=SHADE)
    return outline(g)


def crab(raise_claw):
    g = grid(15, 11); d = ImageDraw.Draw(g)
    d.ellipse([3, 4, 12, 9], fill=MAIN)
    lift = 2 if raise_claw else 0
    d.ellipse([0, 3 - lift, 4, 6 - lift], fill=SHADE)
    d.ellipse([11, 3, 15, 6], fill=SHADE)
    for x in (5, 8, 11):
        d.line([(x, 9), (x - 1, 10)], fill=SHADE)
    d.point((6, 5), fill=EYE)
    d.point((9, 5), fill=EYE)
    return outline(g)


def badger(step):
    g = grid(23, 14); d = ImageDraw.Draw(g)
    d.ellipse([6, 3, 20, 11], fill=MAIN)
    d.ellipse([8, 7, 18, 11], fill=SHADE)
    for i, x in enumerate((9, 12, 16, 19)):
        drop = 3 - (1 if (step and i % 2 == 0) else 0)
        d.line([(x, 10), (x, 10 + drop)], fill=ACCENT, width=2)
    d.ellipse([1, 4, 9, 11], fill=LIGHT)
    # Two dark bands over a white face: without them it is a grey blob.
    d.line([(3, 4), (2, 11)], fill=ACCENT, width=2)
    d.line([(7, 4), (8, 11)], fill=ACCENT, width=2)
    d.ellipse([2, 3, 4, 5], fill=SHADE)
    d.point((5, 7), fill=EYE)
    d.point((0, 8), fill=ACCENT)
    return outline(g)


def turtle(step):
    g = grid(19, 11); d = ImageDraw.Draw(g)
    d.ellipse([3, 2, 15, 9], fill=MAIN)
    for x in (6, 9, 12):
        d.line([(x, 3), (x, 8)], fill=SHADE)
    d.ellipse([14, 5, 18, 9], fill=LIGHT)
    d.point((16, 6), fill=EYE)
    drop = 0 if step else 1
    for x in (5, 12):
        d.line([(x, 9), (x - 1, 10 + drop)], fill=LIGHT)
    return outline(g)


def seal(roll):
    g = grid(21, 11); d = ImageDraw.Draw(g)
    d.ellipse([2, 3, 16, 10], fill=MAIN)
    d.ellipse([4, 6, 14, 10], fill=LIGHT)
    d.ellipse([14, 1 + (0 if roll else 1), 20, 7], fill=MAIN)
    d.point((17, 3), fill=EYE)
    d.point((19, 4), fill=ACCENT)
    d.polygon([(0, 5), (3, 6), (0, 9)], fill=SHADE)
    return outline(g)


def ibex(step):
    g = grid(23, 20); d = ImageDraw.Draw(g)
    body_top = 8
    d.ellipse([6, body_top, 19, body_top + 8], fill=MAIN)
    d.ellipse([8, body_top + 4, 17, body_top + 8], fill=LIGHT)
    for i, x in enumerate((8, 11, 15, 18)):
        drop = 5 - (1 if (step and i % 2 == 0) else 0)
        d.line([(x, body_top + 7), (x, body_top + 7 + drop)], fill=SHADE, width=2)
    d.ellipse([1, 5, 9, 12], fill=MAIN)
    d.polygon([(2, 6), (3, 3), (5, 6)], fill=SHADE)
    # Long swept-back horns, ridged. The template's two short strokes vanished.
    for offset in (0, 2):
        d.line([(5 + offset, 5), (9 + offset, 0)], fill=ACCENT, width=2)
        for i in range(4):
            d.point((6 + offset + i, 4 - i), fill=SHADE)
    d.point((4, 8), fill=EYE)
    return outline(g)


def peacock(fan):
    """The showpiece. Frame two opens the tail — worth the extra pixels."""
    g = grid(25, 20); d = ImageDraw.Draw(g)
    if fan:
        for i in range(9):
            angle = -1.0 + i * 0.25
            x = int(13 + 10 * np.sin(angle))
            y = int(13 - 10 * np.cos(angle))
            d.line([(13, 13), (x, y)], fill=SHADE)
            d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=ACCENT)
    else:
        d.polygon([(13, 11), (22, 8), (23, 16)], fill=SHADE)
    d.ellipse([8, 10, 15, 18], fill=MAIN)
    d.ellipse([6, 5, 11, 11], fill=MAIN)
    d.polygon([(7, 5), (8, 2), (10, 5)], fill=ACCENT)
    d.point((8, 7), fill=EYE)
    d.polygon([(4, 8), (6, 7), (6, 9)], fill=ACCENT)
    d.line([(10, 18), (10, 19)], fill=ACCENT)
    return outline(g)


def tawnyowl(blink):
    g = grid(15, 15); d = ImageDraw.Draw(g)
    d.polygon([(3, 5), (4, 1), (7, 5)], fill=MAIN)
    d.polygon([(11, 5), (10, 1), (7, 5)], fill=MAIN)
    d.ellipse([2, 3, 13, 14], fill=MAIN)
    d.ellipse([5, 9, 11, 14], fill=LIGHT)
    for cx in (5, 10):
        d.ellipse([cx - 2, 5, cx + 2, 9], fill=LIGHT)
        if blink:
            d.line([(cx - 1, 7), (cx + 1, 7)], fill=EYE)
        else:
            d.ellipse([cx - 1, 6, cx + 1, 8], fill=EYE)
    d.polygon([(7, 8), (8, 8), (7, 10)], fill=ACCENT)
    return outline(g)


def moonrabbit(sit):
    """Only on a real full moon. Pale enough to read as a reflection."""
    g = grid(15, 17); d = ImageDraw.Draw(g)
    d.ellipse([1, 1, 5, 10], fill=LIGHT)
    d.ellipse([7, 1, 11, 10], fill=LIGHT)
    d.ellipse([2, 3, 4, 8], fill=ACCENT)
    d.ellipse([8, 3, 10, 8], fill=ACCENT)
    d.ellipse([2, 8, 12, 16], fill=LIGHT)
    d.ellipse([4, 11, 10, 16], fill=MAIN)
    d.point((5, 11), fill=EYE)
    d.point((9, 11), fill=EYE)
    if not sit:
        d.point((7, 13), fill=ACCENT)
    for x in range(0, 15, 2):                                  # its reflection
        d.point((x, 16), fill=GLINT)
    return outline(g)


# --- Phenomena --------------------------------------------------------------
#
# Not creatures, so their conditions are deterministic rather than rolled:
# earned, not lucky. They share the journal page with everything else.

def rainbow(bright):
    g = grid(21, 12); d = ImageDraw.Draw(g)
    for i, colour in enumerate((ACCENT, MAIN, LIGHT)):
        r = 9 - i * 2
        d.arc([10 - r, 10 - r, 10 + r, 10 + r], 180, 360, fill=colour)
        if bright:
            d.arc([10 - r, 9 - r, 10 + r, 9 + r], 180, 360, fill=colour)
    return outline(g)


def meteors(many):
    g = grid(19, 14); d = ImageDraw.Draw(g)
    streaks = ((2, 1, 6), (9, 3, 5), (14, 0, 4)) if many else ((4, 2, 6), (12, 4, 5))
    for x, y, length in streaks:
        for i in range(length):
            d.point((x + i, y + i), fill=LIGHT if i < 2 else MAIN)
        d.point((x, y), fill=GLINT)
    return outline(g)


def aurora(wide):
    g = grid(21, 14); d = ImageDraw.Draw(g)
    for band, colour in enumerate((MAIN, LIGHT, ACCENT)):
        for x in range(1, 20):
            y = 3 + band * 3 + int(2 * np.sin(x / 3.0 + band + (0.6 if wide else 0)))
            d.point((x, y), fill=colour)
            d.point((x, y + 1), fill=colour)
    return outline(g)


WAVE2 = {
    # Meadow
    "bee": (bee, palette((246, 200, 72), (206, 158, 44), (250, 246, 226), (58, 46, 34))),
    "hare": (lambda s: quadruped(s, ear="long", tail="stub", leg=6, width=21),
             palette((190, 156, 118), (154, 122, 90), (240, 228, 210), (110, 84, 62))),
    "swallow": (lambda s: songbird(s, tail=7, breast=True, width=20),
                palette((66, 82, 122), (44, 58, 92), (238, 232, 220), (200, 122, 84))),
    "foxcub": (lambda s: quadruped(s, ear="point", tail="bushy", leg=4, width=21, snout=2),
               palette((222, 130, 66), (186, 98, 44), (250, 244, 236), (74, 52, 44))),
    # Woods
    "woodpecker": (lambda s: songbird(s, crest=3, beak=3, tail=5, breast=True),
                   palette((44, 46, 54), (28, 30, 38), (246, 246, 248), (206, 74, 62))),
    "badger": (badger, palette((92, 92, 98), (62, 62, 68), (246, 246, 248), (32, 32, 36))),
    "fawn": (lambda s: quadruped(s, ear="point", tail="stub", leg=7, neck=3, width=21),
             palette((198, 156, 110), (162, 122, 82), (248, 240, 226), (108, 82, 58))),
    "tawnyowl": (tawnyowl, palette((150, 118, 86), (114, 88, 64), (240, 226, 206), (216, 168, 78))),
    # Harbor
    "crab": (crab, palette((214, 88, 62), (176, 62, 42), (250, 220, 206), (74, 40, 32))),
    "seal": (seal, palette((122, 128, 140), (92, 98, 112), (216, 220, 228), (40, 44, 54))),
    "heron": (lambda s: songbird(s, beak=4, legs=6, tail=4, width=19, height=18),
              palette((178, 186, 198), (138, 148, 164), (250, 250, 252), (232, 194, 82))),
    "turtle": (turtle, palette((104, 140, 96), (74, 108, 70), (196, 214, 172), (60, 82, 58))),
    # Blossom
    "dragonfly": (dragonfly, palette((92, 176, 178), (64, 140, 146), (226, 246, 246), (48, 74, 88))),
    "firefly": (firefly, palette((84, 78, 66), (58, 54, 46), (238, 232, 208), (246, 224, 120))),
    "kingfisher": (lambda s: songbird(s, beak=4, tail=3, breast=True, plump=1),
                   palette((66, 138, 198), (44, 104, 158), (248, 248, 250), (226, 146, 78))),
    "hedgehog": (hedgehog,
                 palette((146, 122, 96), (110, 90, 70), (232, 218, 198), (70, 56, 44))),
    # Sunstone Keep
    "dove": (lambda s: songbird(s, tail=5, width=19),
             palette((238, 238, 242), (200, 202, 212), (255, 255, 255), (226, 158, 92))),
    "peacock": (peacock, palette((36, 118, 132), (26, 88, 102), (226, 246, 244), (86, 176, 152))),
    # Cloudspire
    "swift": (lambda s: songbird(s, tail=8, wing=True, width=21, legs=1),
              palette((84, 78, 88), (58, 54, 64), (232, 228, 232), (52, 48, 56))),
    "sheep": (lambda s: quadruped(s, ear="round", tail="stub", leg=4, width=22, belly=False),
              palette((246, 244, 240), (212, 208, 202), (255, 255, 255), (86, 78, 74))),
    # Starfall Peaks
    "ptarmigan": (lambda s: songbird(s, tail=4, plump=2, width=18),
                  palette((248, 248, 250), (214, 218, 226), (255, 255, 255), (60, 56, 54))),
    "mountainhare": (lambda s: quadruped(s, ear="long", tail="stub", leg=6, width=21),
                     palette((242, 244, 248), (206, 212, 222), (255, 255, 255), (74, 74, 82))),
    "ibex": (ibex, palette((150, 128, 104), (116, 98, 78), (232, 222, 206), (72, 60, 48))),
    # Moonlit Onsen
    "macaque": (lambda s: quadruped(s, ear="round", tail="long", leg=4, width=21, snout=1),
                palette((176, 150, 126), (140, 118, 96), (238, 210, 200), (86, 68, 56))),
    "tanuki": (lambda s: quadruped(s, ear="point", tail="bushy", leg=3, width=22, snout=2),
               palette((138, 118, 100), (102, 86, 72), (236, 226, 212), (48, 42, 38))),
    "moonrabbit": (moonrabbit, palette((226, 226, 240), (194, 196, 214), (250, 250, 255), (188, 176, 214))),
    # Phenomena
    "rainbow": (rainbow, palette((236, 158, 92), (206, 122, 132), (128, 178, 216), (86, 70, 60))),
    "meteors": (meteors, palette((214, 216, 232), (168, 172, 196), (255, 255, 255), (70, 74, 96))),
    "aurora": (aurora, palette((110, 198, 172), (150, 190, 232), (198, 166, 220), (58, 74, 88))),
}

SPECIES.update({name: draw for name, (draw, _) in WAVE2.items()})
P.update({name: pal for name, (_, pal) in WAVE2.items()})


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
