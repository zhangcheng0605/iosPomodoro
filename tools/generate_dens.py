"""Generate the dens: one house per buddy, two frames each.

The second frame is always the same idea — somebody is in. A light on, a tail
showing, the door shut against the cold. That single difference is what makes
a den a home rather than a shed, and it is why the app can say "your buddy is
asleep in there" with no extra art at all.

Same discipline as the residents: they stand in the homestead's near band,
feet-anchored, and `tools/check_residents.py` measures them against the eight
neighbours, the band, the card's rounded corners and the footprint ceiling.

    python3 tools/generate_dens.py
"""
import os
import sys

from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from generate_residents import HOME_PALETTE, shade_row
from generate_sprites import (
    ACCENT, BODY, CREAM, EYE, GLINT, NOSE, OUTLINE, PINK, SHADE, T,
    new_grid, outline_silhouette, to_png,
)

# The homestead's own palette, so a den sits in the same yard as the pond and
# the hedge rather than looking imported. One addition: snow.
DEN_PALETTE = {
    **HOME_PALETTE,
    PINK: (236, 240, 246, 255),     # snow and ice — the igloo, and cold days
}


def basket(occupied):
    """A cat basket, and the cat's back when she is in it."""
    g = new_grid(22, 14)
    d = ImageDraw.Draw(g)
    d.ellipse([1, 4, 20, 13], fill=NOSE)                  # the weave
    for x in range(3, 20, 3):
        d.line([(x, 5), (x, 12)], fill=SHADE)
    d.ellipse([3, 3, 18, 8], fill=CREAM)                  # the cushion
    if occupied:
        # NOSE, not SHADE: this palette's shade tone is the *foliage* green,
        # and a curled green cat in a basket is a different app.
        d.ellipse([6, 1, 16, 7], fill=NOSE)               # a back, curled
        d.ellipse([13, 2, 16, 5], fill=NOSE)
    return outline_silhouette(g)


def doghouse(occupied):
    """The classic, with a name over the door that says nothing legible."""
    g = new_grid(22, 18)
    d = ImageDraw.Draw(g)
    d.polygon([(0, 7), (21, 7), (11, 0)], fill=BODY)      # the roof
    d.rectangle([2, 7, 19, 17], fill=NOSE)
    for x in range(4, 19, 4):
        d.line([(x, 8), (x, 17)], fill=SHADE)
    d.rectangle([6, 3, 15, 5], fill=CREAM)                # the name plate
    for x in range(7, 15, 2):
        d.point((x, 4), fill=OUTLINE)
    d.ellipse([7, 9, 14, 17], fill=OUTLINE)               # the door
    if occupied:
        d.ellipse([8, 12, 13, 17], fill=CREAM)            # a muzzle, resting
        d.point((10, 14), fill=OUTLINE)
    return outline_silhouette(g)


def igloo(occupied):
    """The penguin's, and the example the whole feature was asked for by."""
    g = new_grid(24, 15)
    d = ImageDraw.Draw(g)
    d.ellipse([1, 1, 22, 20], fill=PINK)                  # the dome
    d.rectangle([0, 12, 23, 14], fill=PINK)
    for y in (5, 9):                                      # its blocks
        shade_row(g, y, PINK, CREAM)
    for x in range(3, 22, 5):
        d.line([(x, 6), (x, 8)], fill=CREAM)
        d.line([(x + 2, 10), (x + 2, 12)], fill=CREAM)
    d.ellipse([8, 6, 15, 14], fill=CREAM)                 # the entrance arch
    d.ellipse([9, 8, 14, 14], fill=OUTLINE)
    if occupied:
        d.ellipse([10, 10, 13, 14], fill=GLINT)           # somebody, lit
    return outline_silhouette(g)


def burrow(occupied):
    """A door in a bank, round and green, in the manner of the best burrows."""
    g = new_grid(22, 16)
    d = ImageDraw.Draw(g)
    d.ellipse([0, 3, 21, 20], fill=SHADE)                 # the bank
    shade_row(g, 4, SHADE, BODY)
    shade_row(g, 5, SHADE, BODY)
    d.ellipse([6, 5, 16, 15], fill=BODY)                  # the door
    d.ellipse([7, 6, 15, 15], fill=NOSE)
    d.point((14, 10), fill=GLINT)                         # its handle
    if occupied:
        d.ellipse([9, 11, 13, 15], fill=CREAM)            # two feet, showing
    return outline_silhouette(g)


def cottage(occupied):
    """Too many entrances, which is how a hamster builds."""
    g = new_grid(20, 18)
    d = ImageDraw.Draw(g)
    d.polygon([(0, 8), (19, 8), (10, 1)], fill=BODY)
    d.rectangle([2, 8, 17, 17], fill=NOSE)
    for cx, cy in ((5, 11), (12, 10), (8, 15)):           # the entrances
        d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=OUTLINE)
    if occupied:
        d.ellipse([11, 9, 13, 11], fill=GLINT)            # one of them, in use
    d.rectangle([14, 2, 16, 6], fill=SHADE)               # a chimney
    return outline_silhouette(g)


def hollowlog(occupied):
    """A fallen log, hollow, at exactly the right size — which is rare."""
    g = new_grid(24, 13)
    d = ImageDraw.Draw(g)
    d.rectangle([0, 3, 23, 11], fill=NOSE)
    d.ellipse([0, 2, 8, 12], fill=SHADE)                  # the cut end
    d.ellipse([2, 4, 6, 10], fill=OUTLINE)                # its hollow
    for y in (5, 8):
        d.line([(9, y), (23, y)], fill=SHADE)             # the bark
    d.ellipse([16, 1, 22, 5], fill=BODY)                  # moss on top
    if occupied:
        d.ellipse([3, 6, 6, 10], fill=BODY)               # a tail, showing
    return outline_silhouette(g)


def warmstone(occupied):
    """One flat stone that holds the day's heat until about midnight."""
    g = new_grid(22, 10)
    d = ImageDraw.Draw(g)
    d.ellipse([0, 3, 21, 9], fill=CREAM)
    shade_row(g, 7, CREAM, SHADE)
    shade_row(g, 8, CREAM, SHADE)
    for x in (5, 12, 17):
        d.point((x, 5), fill=SHADE)                       # its grain
    if occupied:
        d.ellipse([5, 0, 16, 5], fill=NOSE)               # a large calm shape
        d.point((7, 2), fill=OUTLINE)
    else:
        d.ellipse([1, 1, 4, 3], fill=BODY)                # a weed beside it
    return outline_silhouette(g)


def branch(occupied):
    """A platform high in a tree, which is where a red panda actually sleeps."""
    g = new_grid(24, 14)
    d = ImageDraw.Draw(g)
    # Drawn as a branch *going up into leaves*, not a platform on legs. The
    # first version put three props under a slab and came out as a garden
    # table with two bushes on it.
    d.line([(2, 13), (9, 5)], fill=NOSE, width=3)         # the limb, rising
    d.line([(9, 5), (21, 4)], fill=NOSE, width=2)         # and levelling off
    d.line([(13, 5), (17, 1)], fill=NOSE)                 # a fork off it
    d.ellipse([14, 0, 23, 6], fill=BODY)                  # leaves at the end
    d.ellipse([0, 8, 6, 13], fill=BODY)                   # and at the base
    d.rectangle([9, 3, 18, 5], fill=SHADE)                # the flat part
    if occupied:
        d.ellipse([10, 0, 17, 4], fill=NOSE)              # somebody draped
        d.line([(16, 3), (20, 7)], fill=NOSE, width=2)    # a tail, hanging
    return outline_silhouette(g)


def oakhollow(occupied):
    """A hollow in a standing oak. It was already somebody's."""
    g = new_grid(18, 20)
    d = ImageDraw.Draw(g)
    d.rectangle([2, 0, 15, 19], fill=NOSE)                # the trunk
    for x in (4, 8, 12):
        d.line([(x, 0), (x, 19)], fill=SHADE)             # its bark
    d.ellipse([4, 5, 13, 15], fill=OUTLINE)               # the hollow
    if occupied:
        d.ellipse([6, 8, 11, 14], fill=CREAM)             # a face in it
        d.point((7, 10), fill=OUTLINE)
        d.point((10, 10), fill=OUTLINE)
    return outline_silhouette(g)


def holt(occupied):
    """Under the bank, and mostly under the water."""
    g = new_grid(24, 12)
    d = ImageDraw.Draw(g)
    d.rectangle([0, 0, 23, 6], fill=SHADE)                # the bank
    shade_row(g, 0, SHADE, BODY)
    shade_row(g, 1, SHADE, BODY)
    d.rectangle([0, 7, 23, 11], fill=ACCENT)              # the water
    d.ellipse([7, 3, 16, 9], fill=OUTLINE)                # the way in
    for x in (2, 19):
        d.line([(x, 8), (x + 3, 8)], fill=CREAM)          # ripples
    if occupied:
        d.ellipse([10, 5, 14, 8], fill=NOSE)              # a head, just above
    return outline_silhouette(g)


def leafpile(occupied):
    """Clearly on purpose, whatever it looks like."""
    g = new_grid(22, 12)
    d = ImageDraw.Draw(g)
    for x0, y0, x1, y1 in ((0, 5, 10, 11), (6, 2, 17, 11), (13, 5, 21, 11)):
        d.ellipse([x0, y0, x1, y1], fill=BODY)
    for x, y in ((3, 7), (9, 4), (15, 6), (19, 8)):
        d.point((x, y), fill=NOSE)                        # a few gone brown
    if occupied:
        d.ellipse([9, 6, 14, 10], fill=OUTLINE)           # a gap, with spines
        for x in range(10, 14):
            d.line([(x, 8), (x, 6)], fill=SHADE)
    return outline_silhouette(g)


def chimney(occupied):
    """Soot's, and never for sale. It arrives with her."""
    g = new_grid(20, 18)
    d = ImageDraw.Draw(g)
    d.rectangle([0, 6, 19, 17], fill=CREAM)               # the hearth wall
    shade_row(g, 11, CREAM, SHADE)
    for x in (4, 11, 16):
        d.line([(x, 6), (x, 10)], fill=SHADE)
    d.rectangle([3, 3, 16, 6], fill=NOSE)                 # the mantel
    d.ellipse([5, 9, 14, 17], fill=OUTLINE)               # the opening
    if occupied:
        d.ellipse([7, 12, 12, 16], fill=GLINT)            # embers, and a shape
        d.ellipse([8, 11, 11, 14], fill=SHADE)
    return outline_silhouette(g)


DENS = {
    "basket": basket,
    "doghouse": doghouse,
    "igloo": igloo,
    "burrow": burrow,
    "cottage": cottage,
    "hollowlog": hollowlog,
    "warmstone": warmstone,
    "branch": branch,
    "oakhollow": oakhollow,
    "holt": holt,
    "leafpile": leafpile,
    "chimney": chimney,
}


if __name__ == "__main__":
    print("Dens:")
    for name, draw in DENS.items():
        for frame in (0, 1):
            to_png(draw(bool(frame)), DEN_PALETTE, f"den_{name}_{frame}")
        print(f"  {name}: 2 frames")
