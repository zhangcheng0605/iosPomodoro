"""Generate the six keepsakes — the things the buddy leaves on the desk.

Small, plain, and deliberately not precious: a bottle cap and a good stick sit
next to a feather because that is what an animal thinks is worth carrying. Each
is drawn as an object on a surface rather than an icon, which is the whole
difference between a shelf and an inventory.

    python3 tools/generate_keepsakes.py
"""
import os
import sys

from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from generate_sprites import (
    ACCENT, BODY, CREAM, EYE, GLINT, NOSE, OUTLINE, PINK, SHADE, T,
    new_grid, outline_silhouette, to_png,
)

# Muted and found-looking. Nothing here glitters: a keepsake that sparkled
# would read as loot, and the point is that these are worthless.
KEEPSAKE_PALETTE = {
    T: (0, 0, 0, 0),
    OUTLINE: (62, 52, 44, 255),
    BODY: (172, 108, 66, 255),      # autumn leaf, stick
    SHADE: (132, 78, 48, 255),
    CREAM: (222, 214, 198, 255),    # feather, stone
    ACCENT: (150, 154, 162, 255),   # metal, grey
    PINK: (206, 146, 158, 255),     # the ribbon
    GLINT: (238, 230, 212, 255),
    NOSE: (112, 92, 70, 255),
    EYE: (92, 116, 78, 255),        # a little green left in the leaf
}


def leaf():
    g = new_grid(14, 12); d = ImageDraw.Draw(g)
    d.polygon([(1, 10), (7, 0), (12, 6), (5, 11)], fill=BODY)
    d.line([(2, 9), (9, 4)], fill=SHADE)                  # the midrib
    for a, b in (((4, 7), (6, 5)), ((6, 8), (8, 7))):
        d.line([a, b], fill=SHADE)                        # and its veins
    d.polygon([(1, 10), (4, 8), (2, 11)], fill=EYE)       # still a bit green
    return outline_silhouette(g)


def feather():
    """A plume, tapered, with the shaft showing all the way down.

    The first version varied the spread by one pixel over ten rows and came
    out as an oval on a stick — a lollipop. A feather is read from its taper
    and its centre line, so the taper has to be the whole width of the thing
    and the shaft has to be drawn *last*, over the barbs.
    """
    g = new_grid(11, 16); d = ImageDraw.Draw(g)
    # Barbs first: none at the tip, widest a third of the way down, gone by
    # the quill.
    for index, y in enumerate(range(1, 12)):
        spread = (0, 1, 2, 3, 4, 4, 4, 3, 3, 2, 1)[index]
        if spread:
            # Two genuinely different tones, not two shades of the same
            # off-white: drawn in CREAM and GLINT the barbs were invisible
            # against each other *and* against the card, and the whole plume
            # read as an outline with nothing in it.
            d.line([(5 - spread, y), (4, y)], fill=ACCENT)
            d.line([(6, y), (5 + spread, y)], fill=GLINT)
    d.line([(5, 0), (5, 14)], fill=NOSE)                  # the shaft, on top
    d.line([(5, 11), (5, 15)], fill=SHADE)                # and the bare quill
    d.line([(2, 7), (4, 7)], fill=ACCENT)                 # one barb, bent
    return outline_silhouette(g)


def pebble():
    g = new_grid(13, 10); d = ImageDraw.Draw(g)
    d.ellipse([0, 2, 12, 9], fill=CREAM)
    d.ellipse([2, 3, 8, 6], fill=GLINT)                   # where the light is
    for x, y in ((9, 6), (4, 8), (10, 4)):
        d.point((x, y), fill=ACCENT)                      # its speckle
    return outline_silhouette(g)


def ribbon():
    """A length of it, curled, knotted twice for reasons of its own.

    Drawn as a wide band rather than a line: at two pixels a ribbon is a
    scribble, and what makes it read is that it has a *face* which turns as it
    curls — so the far side of each curl is the shade tone.
    """
    g = new_grid(16, 12); d = ImageDraw.Draw(g)
    d.polygon([(0, 2), (5, 4), (5, 7), (0, 5)], fill=PINK)      # one flat run
    d.polygon([(5, 4), (10, 1), (10, 4), (5, 7)], fill=SHADE)   # turning over
    d.polygon([(10, 1), (15, 4), (15, 7), (10, 4)], fill=PINK)  # and back
    d.polygon([(6, 6), (9, 6), (8, 11), (5, 11)], fill=PINK)    # a loose end
    d.ellipse([5, 3, 9, 8], fill=SHADE)                         # the knot
    d.point((7, 5), fill=GLINT)
    return outline_silhouette(g)


def bottlecap():
    g = new_grid(12, 9); d = ImageDraw.Draw(g)
    d.ellipse([0, 1, 11, 8], fill=ACCENT)
    d.ellipse([2, 2, 9, 6], fill=CREAM)
    for x in range(1, 11, 2):
        d.point((x, 8), fill=OUTLINE)                     # its crimped edge
    d.line([(4, 4), (7, 4)], fill=SHADE)                  # a scratch
    return outline_silhouette(g)


def stick():
    g = new_grid(16, 9); d = ImageDraw.Draw(g)
    d.line([(0, 6), (15, 3)], fill=BODY, width=2)
    d.line([(6, 5), (10, 1)], fill=BODY)                  # one fork
    d.line([(3, 6), (5, 8)], fill=SHADE)                  # and one stub
    d.point((15, 3), fill=NOSE)
    return outline_silhouette(g)


KEEPSAKES = {
    "leaf": leaf, "feather": feather, "pebble": pebble,
    "ribbon": ribbon, "bottlecap": bottlecap, "stick": stick,
}


if __name__ == "__main__":
    print("Keepsakes:")
    for name, draw in KEEPSAKES.items():
        to_png(draw(), KEEPSAKE_PALETTE, f"keepsake_{name}")
