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


def marked(palette):
    """The pale patch that tells one individual from the rest of its kind.

    A palette swap rather than a second drawing, like the ghost and the sketch.
    Only the shade tone is lifted, so the difference is small — recognising a
    regular should feel like something you noticed, not like the app swapping
    in a different animal.
    """
    out = {}
    for index, rgba in palette.items():
        if index != SHADE:
            out[index] = rgba
            continue
        r, g, b, a = rgba
        out[index] = (
            min(255, int(r * 0.42 + 152)),
            min(255, int(g * 0.42 + 148)),
            min(255, int(b * 0.42 + 140)),
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
             wing=True, width=18, height=15, plump=0, flank=False):
    """Perched small bird. Two frames differ by a leg shift and a wing lift."""
    g = grid(width, height)
    d = ImageDraw.Draw(g)
    top = 2 + crest
    body_y = top + 3

    d.polygon([(11, body_y + 2), (11 + tail, body_y - 1), (11 + tail, body_y + 6)], fill=SHADE)
    d.ellipse([4, body_y, 12 + plump, body_y + 8], fill=MAIN)
    if breast:
        d.ellipse([5, body_y + 3, 11, body_y + 8], fill=ACCENT)
    # A patch under the wing rather than a whole coloured front. Added for the
    # redwing, whose rust is on the flank — given `breast` it came out as a
    # robin in slightly different browns, and two thrushes nobody can tell
    # apart is two journal entries doing one entry's work.
    if flank:
        d.ellipse([7, body_y + 4, 11 + plump, body_y + 7], fill=ACCENT)
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
              horns=False, belly=True, leg=5, neck=1, snout=0, tail_tip=False):
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
        # A parameter rather than a special case, per the buddies' rule: the
        # black tip is the whole difference between an ermine and a white
        # smudge, and on a white animal the shared SHADE tone is also white.
        if tail_tip:
            d.line([(back + 1, body_top - 1), (back + 3, body_top - 3)],
                   fill=ACCENT, width=2)
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


# --- Wave 4: the creatures that come with the sky --------------------------
#
# Half of these are the shared `songbird`/`quadruped` builders with different
# numbers, which is the whole argument for having built them: a snow fox is a
# fox at a different palette and a longer leg, and drawing it again would only
# create a second thing to keep in step. The bespoke ones below are the shapes
# no builder covers — the ones that crawl, hang or fill the sky.

def snail(out):
    """Shell, and as much animal as is out of it.

    The first cut drew the foot tucked under the shell and came out as a
    cinnamon roll. The animal has to lead: a long foot in front, then the
    shell sitting back on it.
    """
    g = grid(17, 14); d = ImageDraw.Draw(g)
    reach = 2 if out else 0
    d.ellipse([5, 2, 15, 11], fill=MAIN)                    # the shell, behind
    d.arc([7, 4, 13, 9], 0, 360, fill=SHADE)                # and its whorl
    d.arc([9, 5, 12, 8], 0, 360, fill=SHADE)
    d.ellipse([0, 8, 13, 12], fill=LIGHT)                   # the foot, out front
    d.ellipse([0, 6, 4 + reach, 11], fill=LIGHT)            # the head on it
    # Stalks last, or the shell is drawn over the near one and the snail comes
    # out with a single antenna.
    for dx, top in ((0, 0), (3, 2)):
        d.line([(dx + reach, 7), (dx + reach, top)], fill=LIGHT)
        d.point((dx + reach, top), fill=EYE)
    return outline(g)


def frogling(hop, *, width=13, height=11, squat=0):
    """A frog, at whatever size. `squat` widens it into something toad-shaped."""
    g = grid(width, height); d = ImageDraw.Draw(g)
    lift = 1 if hop else 0
    body = height - 2 - lift
    d.ellipse([2, body - 5 - squat, width - 3, body], fill=MAIN)
    # Wider than it is tall, or at eleven pixels across the ellipse degenerates
    # into a vertical white bar down the middle of the frog.
    d.ellipse([3, body - 3, width - 4, body], fill=LIGHT)     # the pale throat
    for x in (2, width - 4):                                 # folded legs
        d.ellipse([x - 1, body - 3, x + 2, body + 1], fill=SHADE)
    d.ellipse([3, body - 7 - squat, 6, body - 4 - squat], fill=MAIN)
    d.ellipse([width - 7, body - 7 - squat, width - 4, body - 4 - squat], fill=MAIN)
    d.point((4, body - 6 - squat), fill=EYE)
    d.point((width - 6, body - 6 - squat), fill=EYE)
    return outline(g)


def worm(stretch):
    """A line that moves along itself. Two frames, two different curves."""
    g = grid(15, 7); d = ImageDraw.Draw(g)
    for x in range(1, 14):
        wave = 1 if stretch else 2
        y = 3 + int(round(wave * np.sin(x / (4.5 if stretch else 3.0))))
        d.point((x, y), fill=MAIN)
        d.point((x, y + 1), fill=SHADE)
    d.point((1, 3), fill=LIGHT)
    return outline(g)


def beetle(open_wing):
    """Domed, and split down the middle. Frame two lifts the wing cases."""
    g = grid(12, 9); d = ImageDraw.Draw(g)
    lift = 1 if open_wing else 0
    d.ellipse([2, 2 - lift, 10, 8], fill=MAIN)
    d.line([(6, 2 - lift), (6, 8)], fill=SHADE)
    d.ellipse([3, 0, 8, 3], fill=SHADE)                      # the head plate
    d.point((4, 1), fill=EYE)
    d.point((7, 1), fill=EYE)
    for y in (4, 6):
        d.point((1, y), fill=ACCENT)
        d.point((10, y), fill=ACCENT)
    if open_wing:
        d.ellipse([1, 1, 5, 4], fill=LIGHT)
        d.ellipse([7, 1, 11, 4], fill=LIGHT)
    return outline(g)


def slug(reach):
    """The snail's shape with the shell taken away, which is the joke.

    A white animal with no features is a cloud, so it gets the mantle shield
    and its keel — the two things that are actually on a slug — and stalks
    standing clear of the body rather than trailing off it diagonally.
    """
    g = grid(17, 8); d = ImageDraw.Draw(g)
    out = 2 if reach else 0
    d.ellipse([1, 3, 12 + out, 7], fill=MAIN)                # the body
    d.ellipse([2, 2, 8, 6], fill=SHADE)                      # the mantle shield
    d.line([(3, 4), (7, 4)], fill=LIGHT)                     # and its keel
    for dx, top in ((13, 0), (11, 1)):                       # the stalks
        d.line([(dx + out, 4), (dx + out, top)], fill=MAIN)
        d.point((dx + out, top), fill=EYE)
    return outline(g)


def soaring(tilt):
    """Wings out, forked tail, not flapping. A bird that rides wind.

    This slot was a ballooning spider for four drafts and never once read as
    one: eight legs at eleven pixels is a lattice, six is a basket, four on a
    bigger body is a box with a lid, and three bent ones per side weld into
    two wings. Leg count is not legible at this scale and *splay* is what the
    eye is looking for — but splay is also what makes it a moth. The subject
    changed rather than the drawing. The wind still gets something that only
    turns up in it.
    """
    g = grid(23, 15); d = ImageDraw.Draw(g)
    lift = 1 if tilt else 0
    # One wing high and one low: a soaring bird holds a shallow V and tips it
    # to turn, which is the only movement worth two frames.
    d.polygon([(11, 7), (1, 4 - lift), (3, 8 - lift), (10, 9)], fill=MAIN)
    d.polygon([(12, 7), (22, 4 + lift), (20, 8 + lift), (13, 9)], fill=SHADE)
    d.ellipse([9, 5, 14, 10], fill=MAIN)                      # the body
    # Wide and in the body tone: drawn narrow and dark, the fork read as two
    # legs dangling, which is the one thing a soaring bird never has.
    d.polygon([(11, 9), (7, 14), (11, 11), (15, 14)], fill=SHADE)    # forked tail
    d.ellipse([10, 4, 13, 7], fill=LIGHT)                     # the pale head
    d.point((11, 5), fill=EYE)
    d.polygon([(10, 4), (8, 5), (10, 6)], fill=ACCENT)        # the hooked bill
    return outline(g)


def swarm(spread):
    """Not one dragonfly — the whole afternoon's worth, going one way."""
    g = grid(25, 16); d = ImageDraw.Draw(g)
    for index, (x, y) in enumerate(((1, 6), (7, 2), (9, 9), (14, 5),
                                    (17, 11), (20, 3), (21, 8))):
        lift = (1 if spread else 0) * (1 if index % 2 else -1)
        d.line([(x, y + lift), (x + 4, y + lift)], fill=MAIN, width=1)
        d.point((x + 4, y + lift), fill=ACCENT)
        d.line([(x + 1, y - 1 + lift), (x + 3, y - 2 + lift)], fill=LIGHT)
        d.line([(x + 1, y + 1 + lift), (x + 3, y + 2 + lift)], fill=LIGHT)
    return outline(g)


def sleepingcat(breathe):
    """A stranger, folded into a warm rectangle. Never the stray."""
    g = grid(19, 12); d = ImageDraw.Draw(g)
    rise = 1 if breathe else 0
    d.ellipse([2, 5 - rise, 16, 11], fill=MAIN)              # the loaf
    d.ellipse([4, 8, 14, 11], fill=LIGHT)
    d.ellipse([1, 5, 7, 10], fill=MAIN)                      # head, tucked
    d.polygon([(2, 6), (3, 3), (5, 6)], fill=SHADE)          # ears
    d.polygon([(5, 6), (7, 3), (8, 6)], fill=SHADE)
    d.line([(2, 8), (5, 8)], fill=EYE)                       # eyes, shut
    d.line([(14, 10), (18, 8 - rise)], fill=SHADE, width=2)  # the tail
    return outline(g)


def bigbird(open_beak, *, width=17, height=18, hunch=0):
    """A corvid shape: upright, heavy-headed, and not in a hurry."""
    g = grid(width, height); d = ImageDraw.Draw(g)
    body_top = 5 + hunch
    d.ellipse([3, body_top, width - 3, height - 3], fill=MAIN)
    d.polygon([(width - 5, body_top + 2), (width - 1, height - 6),
               (width - 6, height - 5)], fill=SHADE)          # the tail
    # The head drops a pixel and the beak opens together: a one-pixel gape on
    # its own is a frame nobody can tell from the other one.
    duck = 1 if open_beak else 0
    d.ellipse([2, 1 + hunch + duck, 9, 7 + hunch + duck], fill=MAIN)
    gape = 2 if open_beak else 0
    d.polygon([(2, 3 + hunch + duck), (2 - 4, 4 + hunch + duck + gape),
               (2, 5 + hunch + duck)], fill=ACCENT)
    d.point((5, 3 + hunch + duck), fill=EYE)
    d.ellipse([6, body_top + 1, width - 5, height - 6], fill=SHADE)   # the wing
    for x in (6, 10):
        d.line([(x, height - 3), (x, height - 1)], fill=ACCENT)
    return outline(g)


def petrel(down):
    """Small, black, and always in the trough of a wave."""
    g = grid(19, 13); d = ImageDraw.Draw(g)
    tip = 4 if down else 0
    d.polygon([(9, 6), (1, 2 + tip), (7, 7)], fill=SHADE)     # wings, one down
    d.polygon([(10, 6), (18, 10 - tip), (12, 7)], fill=MAIN)
    d.ellipse([7, 4, 13, 9], fill=MAIN)
    d.ellipse([9, 8, 13, 10], fill=LIGHT)                     # the white rump
    d.ellipse([5, 3, 9, 7], fill=MAIN)
    d.point((6, 5), fill=EYE)
    d.polygon([(5, 5), (3, 6), (5, 6)], fill=ACCENT)
    return outline(g)


def arc_phenomenon(bright, *, width=27, height=15, bands=None, thin=False):
    """A bow across the sky: the rainbow's shape, at other saturations."""
    g = grid(width, height); d = ImageDraw.Draw(g)
    colours = bands or (MAIN, SHADE, LIGHT)
    for index, colour in enumerate(colours):
        box = [1 + index, 2 + index, width - 2 - index, height * 2 - index]
        d.arc(box, 180, 360, fill=colour)
        if not thin:
            d.arc([box[0], box[1] + 1, box[2], box[3] + 1], 180, 360, fill=colour)
    if bright:
        for x in range(3, width - 3, 5):
            d.point((x, 1), fill=GLINT)
    return outline(g)


def sunshower(bright):
    """Rain, in full sun. Drawn as both at once, because that is the whole of
    what makes anybody look up."""
    g = grid(27, 16); d = ImageDraw.Draw(g)
    d.ellipse([1, 1, 9, 9], fill=ACCENT)                      # the sun
    for angle in range(0, 360, 45):
        dx = int(round(6 * np.cos(np.radians(angle))))
        dy = int(round(6 * np.sin(np.radians(angle))))
        d.point((5 + dx, 5 + dy), fill=GLINT if bright else ACCENT)
    for index, x in enumerate(range(11, 26, 3)):              # and the rain
        top = 2 + (index % 3) * 3 + (1 if bright else 0)
        d.line([(x, top), (x - 1, top + 4)], fill=MAIN)
    return outline(g)


def thunderhead(flash):
    """The first storm of a year: cloud, and one fork under it."""
    g = grid(23, 17); d = ImageDraw.Draw(g)
    for x0, y0, x1, y1 in ((1, 3, 11, 10), (7, 1, 18, 9), (13, 4, 22, 10)):
        d.ellipse([x0, y0, x1, y1], fill=MAIN)
    d.rectangle([2, 7, 21, 10], fill=SHADE)
    if flash:
        d.polygon([(12, 10), (8, 15), (11, 15), (9, 17)], fill=ACCENT)
        d.polygon([(15, 10), (13, 14), (16, 14)], fill=GLINT)
    else:
        # The same bolt, unlit. A frame that simply loses it reads as a bug
        # rather than as the gap between one strike and the next.
        d.polygon([(12, 10), (8, 15), (11, 15), (9, 17)], fill=SHADE)
    return outline(g)


# --- The Flyway: things that only pass through ------------------------------
#
# Four of these are *movements* rather than animals, and that is the drawing
# problem. A single goose is a goose; the thing you actually notice in November
# is a line of them, and one bird drawn large would be a portrait of something
# nobody ever sees that close. So the skein, the run and the swarm are drawn as
# several small shapes going the same way, and the two that genuinely are one
# creature — the cuckoo and the waxwing — are drawn perched.


def skein(step, *, count=5, neck=3, width=25, height=14, tipped=False, span=2):
    """Birds in a ragged line, seen from underneath.

    The wingbeat is deliberately **out of phase across the line**: birds in a
    skein do not flap together, and drawing them synchronised read as one
    object with a lot of legs. Each bird's phase comes from its index, which
    also means the two frames differ everywhere rather than in one place.
    """
    g = grid(width, height)
    d = ImageDraw.Draw(g)
    # A ragged line, not a tidy V: the spacing is uneven on purpose, because a
    # regular V at this scale reads as a decoration rather than as birds.
    slots = ((1, 7), (6, 4), (10, 8), (15, 3), (19, 6), (22, 9), (3, 11))
    for index, (x, y) in enumerate(slots[:count]):
        up = (index + (1 if step else 0)) % 2 == 0
        rise = 1 if up else -1
        body = x + neck
        # The neck is the whole of what tells a swan from a goose at this size,
        # so it is a parameter and it is drawn first, under the wings.
        d.line([(x, y + 1), (body, y + 1)], fill=LIGHT)
        d.ellipse([body - 1, y, body + 2, y + 3], fill=MAIN)
        left = (body - span, y + 1 - rise)
        right = (body + 1 + span, y + 1 + rise)
        d.line([(body, y + 1), left], fill=MAIN)
        d.line([(body + 1, y + 1), right], fill=SHADE)
        if tipped:
            # Black wingtips: the one marking that says snow goose rather than
            # "a white bird". Two pixels, not one — at this scale a single
            # dark pixel at the end of a two-pixel wing reads as the outline
            # the whole sprite already has, and the first render showed
            # nothing at all.
            d.point(left, fill=ACCENT)
            d.point((left[0] + 1, left[1]), fill=ACCENT)
            d.point(right, fill=ACCENT)
            d.point((right[0] - 1, right[1]), fill=ACCENT)
    return outline(g)


def run(step):
    """Fish breaking the surface, all going upstream.

    Three drafts. The first drew a continuous waterline under four fish, and
    a solid bar across the bottom of a frame is a *shelf* — the fish came out
    standing on a plank, four brown blobs on a board. What makes water read as
    water at thirteen pixels is that it is **broken**: short dashes at two
    heights, with gaps. And what makes a fish read as leaping is the tail
    still in the water while the head is out, so each one is drawn as a body
    tilted nose-up with its tail crossing the surface rather than as an
    ellipse hovering above it.
    """
    g = grid(22, 13)
    d = ImageDraw.Draw(g)
    surface = 8
    # The water first, so every fish is drawn over it and genuinely crosses it.
    for x, drop in ((0, 0), (5, 1), (9, 0), (13, 1), (18, 0)):
        d.line([(x, surface + drop), (x + 3, surface + drop)], fill=SHADE)
    for x in (2, 8, 15, 20):
        d.point((x, surface + 2), fill=LIGHT)

    for index, (x, top) in enumerate(((2, 3), (9, 1), (16, 4))):
        lift = 1 if (index % 2 == 0) == step else 0
        y = top - lift
        # Nose up and to the right: the body is a slanted lozenge rather than
        # a level ellipse, which is the whole difference between leaping and
        # floating.
        d.polygon([(x + 4, y), (x + 5, y + 3), (x + 1, y + 6), (x, y + 3)],
                  fill=MAIN)
        d.polygon([(x + 1, y + 4), (x + 4, y + 2), (x + 4, y + 4)], fill=LIGHT)
        d.point((x + 4, y + 1), fill=EYE)
        # The tail, still down in the broken water.
        d.polygon([(x + 1, y + 5), (x - 2, surface + 2), (x + 2, surface + 1)],
                  fill=SHADE)
    return outline(g)


def migrant_butterfly(up):
    """Not one butterfly — three, all going the same way.

    Two drafts died before this one, and both died the same death. Drawn from
    above with wings spread, a butterfly is a **symmetric shape with a dark
    body up the middle**; put any bright mark on each wing near the top and
    the eye assembles a face out of it instantly. The first draft's white
    wing-spots were eyes and the dark leading corners were ears, and the
    contact sheet was two rows of foxes. Moving the spots did not fix it —
    the symmetry is the problem, not the spots.

    So this changed subject the way the Red Kite did. What anybody actually
    sees of a painted lady passage is not one butterfly: it is a few of them
    an hour, all week, all crossing the same way. Three side-on, at different
    heights, going right. No symmetry, no face, and truer to the note than the
    portrait was.
    """
    g = grid(14, 11)
    d = ImageDraw.Draw(g)
    # Three at five pixels each read as orange crumbs; two at seven read as
    # butterflies. "A few at a time" is satisfied by two, and legibility wins
    # the tie — at the size this is drawn on screen, a shape nobody can name
    # is decoration rather than a sighting.
    for index, (x, y) in enumerate(((0, 4), (7, 0))):
        high = (index + (0 if up else 1)) % 2 == 0
        base = y + 3
        d.line([(x + 3, base - 1), (x + 3, base + 2)], fill=ACCENT)   # body
        # The near wing is a tall triangle from the body, the far wing a short
        # one behind it — the three-quarter view a butterfly crossing a field
        # actually presents, rather than the flat-from-above portrait that
        # kept turning into a face.
        tip = y if high else base + 3
        far = y + 1 if high else base + 2
        d.polygon([(x + 3, base + 1), (x, tip), (x + 3, base - 1)], fill=MAIN)
        d.polygon([(x + 4, base + 1), (x + 6, far), (x + 4, base - 1)],
                  fill=SHADE)
        d.point((x + 1, tip + (1 if high else -1)), fill=LIGHT)
    return outline(g)


def comet(bright):
    """A head and a tail, low in the sky, and nothing else in the frame.

    The two frames differ only in the brightness of the coma — a comet does
    not move visibly in an evening, and animating it would be the one thing
    about this that isn't true.
    """
    g = grid(33, 19)
    d = ImageDraw.Draw(g)
    # The tail is three tapering strokes rather than one wedge: a solid
    # triangle read as a paper aeroplane in the first draft.
    for index, (drop, length, tone) in enumerate(
        ((0, 26, MAIN), (-2, 20, SHADE), (2, 22, SHADE))
    ):
        d.line([(26, 7 + drop), (26 - length, 7 + drop - length // 5)], fill=tone)
    d.ellipse([25, 4, 31, 10], fill=LIGHT if bright else MAIN)
    d.ellipse([26, 5, 30, 9], fill=GLINT if bright else LIGHT)
    # A few grains along the tail, so it has texture rather than being three
    # clean lines.
    for x, y in ((20, 6), (14, 5), (9, 4), (17, 9), (11, 8)):
        d.point((x, y), fill=LIGHT)
    return outline(g)


FLYWAY = {
    # Late February. Three or four, very high, and the necks are the whole
    # silhouette — hence neck=5 against the goose's 3.
    "whooperswan": (lambda s: skein(s, count=3, neck=5, width=27, height=15),
                    palette((252, 252, 254), (214, 220, 230), (255, 255, 255),
                            (242, 196, 74))),
    # Late April. Never seen well, which is the joke: it perches high, stays
    # put (`.linger`), and the long tail is all anybody gets.
    "cuckoo": (lambda s: songbird(s, tail=9, width=20, height=15, legs=2),
               palette((146, 150, 158), (110, 114, 124), (240, 240, 244),
                       (216, 190, 96))),
    # Mid June. A butterfly, but the migrating kind — orange going to brick,
    # with the white spots at the wingtip that name it.
    "paintedlady": (migrant_butterfly,
                    palette((226, 138, 74), (186, 102, 52), (252, 246, 238),
                            (74, 52, 44))),
    # Late September, in the shallows.
    "salmonrun": (run, palette((186, 118, 96), (146, 88, 72), (238, 214, 198),
                               (108, 132, 148))),
    # Late October, in overnight. The rusty flank under the wing is the only
    # thing that separates it from every other thrush.
    "redwing": (lambda s: songbird(s, tail=5, width=14, height=12, flank=True,
                                   legs=2),
                palette((122, 106, 84), (92, 78, 62), (240, 232, 214),
                        (192, 88, 54))),
    # Early November. Five of them, ragged, with the black wingtips.
    "snowgoose": (lambda s: skein(s, count=5, neck=3, width=25, height=14,
                                  tipped=True, span=3),
                  palette((250, 250, 252), (208, 214, 224), (255, 255, 255),
                          (58, 56, 62))),
    # January, and not every year in the real world — here it is annual and
    # short, because a species nobody can meet is not a species. The crest is
    # the whole bird.
    "waxwing": (lambda s: songbird(s, crest=3, tail=4, width=15, height=13,
                                   breast=True, legs=2, plump=1),
                palette((196, 160, 130), (158, 126, 100), (244, 232, 216),
                        (206, 78, 58))),
    # August, every fourth year, for six weeks.
    "comet": (comet, palette((228, 232, 246), (150, 162, 200), (250, 252, 255),
                             (108, 124, 172))),
}


WAVE4 = {
    # Rain and drizzle
    "gardensnail": (snail, palette((188, 150, 96), (150, 116, 68), (226, 208, 186), (94, 74, 52))),
    "bigfrog": (lambda s: frogling(s, width=17, height=14, squat=1),
                palette((112, 148, 84), (82, 116, 62), (226, 236, 200), (64, 92, 54))),
    "littlefrog": (lambda s: frogling(s, width=13, height=11),
                   palette((146, 190, 104), (110, 156, 78), (236, 246, 212), (72, 108, 58))),
    "earthworm": (worm, palette((196, 134, 128), (158, 100, 98), (232, 190, 184), (110, 70, 68))),
    "rainbeetle": (beetle, palette((72, 84, 96), (48, 58, 70), (196, 206, 216), (150, 128, 72))),
    # Mist
    "fogmoth": (moth, palette((214, 212, 206), (176, 176, 172), (240, 240, 238), (128, 128, 128))),
    "roedeer": (lambda s: quadruped(s, ear="point", tail="stub", leg=7, neck=3, width=23),
                palette((174, 146, 118), (138, 114, 90), (238, 230, 218), (96, 80, 64))),
    "ghostslug": (slug, palette((238, 238, 236), (204, 206, 208), (250, 250, 250), (150, 152, 156))),
    # Storm
    "stormpetrel": (petrel, palette((70, 68, 74), (46, 44, 50), (242, 242, 244), (34, 32, 36))),
    "weathercrow": (lambda s: bigbird(s, width=17, height=18),
                    palette((52, 52, 60), (34, 34, 42), (206, 206, 214), (30, 30, 36))),
    # Golden
    "dragonswarm": (swarm, palette((238, 176, 82), (198, 138, 54), (250, 226, 178), (110, 78, 46))),
    "suncat": (sleepingcat, palette((236, 190, 118), (200, 150, 82), (252, 236, 208), (108, 76, 50))),
    # Breeze
    "redkite": (soaring, palette((188, 108, 62), (152, 84, 48), (238, 232, 224), (74, 58, 48))),
    "dandelionmouse": (lambda s: quadruped(s, ear="round", tail="long", leg=2, width=17, snout=1),
                       palette((178, 152, 124), (140, 118, 94), (240, 232, 220), (86, 70, 58))),
    # Snow
    "snowfox": (lambda s: quadruped(s, ear="point", tail="bushy", leg=5, width=23, snout=2),
                palette((246, 248, 252), (212, 218, 228), (255, 255, 255), (92, 100, 116))),
    "ermine": (lambda s: quadruped(s, ear="round", tail="long", leg=3, width=25,
                                   belly=False, snout=1, tail_tip=True),
               palette((250, 250, 250), (216, 218, 224), (255, 255, 255), (40, 38, 36))),
    "winterwren": (lambda s: songbird(s, tail=3, plump=2, width=16, height=14, breast=True),
                   palette((150, 112, 78), (116, 84, 56), (238, 224, 204), (86, 62, 42))),
    # Overcast
    "greywagtail": (lambda s: songbird(s, tail=8, breast=True, width=21, legs=2),
                    palette((150, 154, 162), (114, 118, 128), (244, 236, 196), (232, 206, 96))),
    "mushroomvole": (lambda s: quadruped(s, ear="round", tail="stub", leg=2, width=16, snout=1),
                     palette((160, 132, 106), (124, 100, 80), (232, 220, 204), (78, 62, 50))),
    # Phenomena
    "sunshower": (sunshower, palette((132, 168, 212), (98, 132, 178), (226, 238, 250), (246, 208, 108))),
    # A fogbow is a rainbow with the colour taken out — which is exactly what
    # this is: the same arc, three greys and one thin band.
    "fogbow": (lambda s: arc_phenomenon(s, width=27, height=14, thin=True),
               palette((238, 238, 240), (206, 208, 214), (250, 250, 252), (168, 172, 180))),
    "firstthunder": (thunderhead,
                     palette((104, 108, 126), (72, 76, 94), (198, 202, 216), (248, 226, 138))),
}

for wave in (WAVE2, WAVE4, FLYWAY):
    SPECIES.update({name: draw for name, (draw, _) in wave.items()})
    P.update({name: pal for name, (_, pal) in wave.items()})


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
        # The fifth sighting turns a species into an individual; this is what
        # the journal shows once it has. A rainbow is never an individual, so
        # the phenomena don't get one.
        regular = name not in ("rainbow", "meteors", "aurora",
                               "sunshower", "fogbow", "firstthunder", "comet")
        if regular:
            to_png(first, marked(sepia(pal)), f"wild_{name}_regular")
        print(f"  {name}: 2 frames + ghost + sketch{' + regular' if regular else ''}")
