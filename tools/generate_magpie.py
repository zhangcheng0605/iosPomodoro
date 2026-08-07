"""Generate the magpie and her cart — the app's one commercial room.

Two sprites and one piece of furniture. She is a neighbour, not a species:
nothing here goes near the field journal, there is no `Spec` row, and
`check_species.py` must never learn about her. A shopkeeper you can *collect*
would turn the one honest storefront in the app into another tile to fill.

    python3 tools/generate_magpie.py
"""
import os
import sys

from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from generate_sprites import (
    ACCENT, BODY, CREAM, EYE, GLINT, NOSE, OUTLINE, PINK, SHADE, T,
    new_grid, outline_silhouette, to_png,
)

# Black, white, and the oil-slick blue-green a magpie's wing actually is —
# which is the one thing that stops her reading as a crow, and the reason she
# gets her own palette rather than borrowing the weathervane crow's.
MAGPIE_PALETTE = {
    T: (0, 0, 0, 0),
    OUTLINE: (34, 32, 38, 255),
    BODY: (44, 42, 50, 255),        # the black, which is never quite black
    SHADE: (28, 26, 34, 255),
    CREAM: (242, 242, 246, 255),    # the white
    ACCENT: (58, 108, 106, 255),    # the oil-slick wing
    NOSE: (128, 96, 66, 255),       # the cart's wood
    PINK: (176, 150, 120, 255),     # its worn edges
    GLINT: (240, 208, 128, 255),    # an acorn, and anything else she likes
    EYE: (240, 240, 244, 255),      # pale: a dark eye in a black head is a hole
}


def magpie(appraising):
    """Perched, and deciding what you are worth.

    Two frames: head level, then tilted. A magpie tilting its head at a thing
    is the single most recognisable move the bird has, and it is worth more
    than any amount of wing detail at this size.
    """
    g = new_grid(20, 22)
    d = ImageDraw.Draw(g)
    tilt = 1 if appraising else 0

    d.polygon([(12, 12), (19, 20), (15, 20), (13, 17)], fill=BODY)   # long tail
    d.ellipse([5, 9, 15, 19], fill=BODY)                             # the body
    d.ellipse([6, 13, 12, 19], fill=CREAM)                           # white belly
    d.ellipse([10, 10, 16, 16], fill=ACCENT)                         # the wing
    d.line([(12, 11), (14, 15)], fill=SHADE)

    # The head, tilted in frame two. Drawn after the body so the tilt reads as
    # the head moving rather than the whole bird leaning.
    d.ellipse([3, 3 + tilt, 11, 11 + tilt], fill=BODY)
    d.point((6, 6 + tilt), fill=EYE)
    # Dark and solid. Drawn pale, and as a one-pixel-tall wedge, it degenerated
    # into two white strokes either side of the head — the bird grew whiskers.
    d.polygon([(4, 5 + tilt), (0, 7 + tilt), (4, 9 + tilt)], fill=SHADE)
    for x in (7, 9):                                                 # the feet
        d.line([(x, 19), (x, 21)], fill=GLINT)
    return outline_silhouette(g)


def cart(loaded):
    """A handcart with more in it than anybody needs.

    Deliberately shabby rather than shiny: a gleaming shop counter would make
    this a storefront, and it is a bird with a pile of things she likes.
    """
    g = new_grid(28, 18)
    d = ImageDraw.Draw(g)
    d.rectangle([2, 8, 25, 14], fill=NOSE)                  # the box
    for x in range(4, 25, 5):
        d.line([(x, 8), (x, 14)], fill=PINK)                # its planks
    d.rectangle([1, 6, 26, 8], fill=PINK)                   # the rim
    d.polygon([(26, 9), (27, 4), (25, 4)], fill=NOSE)       # the handle
    for cx in (7, 19):                                      # two wheels
        d.ellipse([cx - 3, 13, cx + 3, 17], fill=SHADE)
        d.point((cx, 15), fill=PINK)
    # The hoard. One more acorn in the loaded frame, which is the whole of the
    # animation: nothing moves in a cart, things are added to it.
    hoard = ((6, 4), (10, 3), (14, 4), (18, 3), (22, 5))
    for index, (x, y) in enumerate(hoard):
        if index == 4 and not loaded:
            continue
        d.ellipse([x, y, x + 3, y + 3], fill=GLINT)
        d.point((x + 1, y + 3), fill=NOSE)                  # each one's cup
    return outline_silhouette(g)


def acorn(_=None):
    """The currency, at the size a price row wants it."""
    g = new_grid(10, 12)
    d = ImageDraw.Draw(g)
    # The nut is most of an acorn and the cup is a beret on top of it. Drawn
    # the other way round — a deep cup over a small nut — it reads as a
    # mushroom, which is a different thing entirely and lives in the woods.
    d.ellipse([1, 3, 8, 11], fill=GLINT)                    # the nut
    d.ellipse([0, 1, 9, 4], fill=NOSE)                      # its cup
    for x in range(1, 9, 2):
        d.point((x, 2), fill=PINK)                          # and the cup's weave
    d.line([(4, 0), (5, 1)], fill=NOSE)                     # the stalk
    return outline_silhouette(g)


SPRITES = {
    "magpie_0": lambda: magpie(False),
    "magpie_1": lambda: magpie(True),
    "cart_0": lambda: cart(False),
    "cart_1": lambda: cart(True),
    "acorn": acorn,
}


if __name__ == "__main__":
    print("The cart:")
    for name, draw in SPRITES.items():
        to_png(draw(), MAGPIE_PALETTE, name)
