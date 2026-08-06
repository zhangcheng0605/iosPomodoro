"""Generate the homestead's neighbours: eight residents, two frames each.

Two frames at 2fps, which is the slowest loop in the app and meant to be. A
homestead that twitches is a homestead you look *at*; these should be things
you look past for weeks and then notice.

The second frame is never a different object — it is the same object with one
small thing changed. A fish surfaces, a bird leans out, a bee is somewhere
else, the washing moves. That constraint is what keeps eight loops from
becoming eight distractions.
"""
import os
import sys

from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from generate_sprites import (
    ACCENT, BODY, CREAM, EYE, GLINT, NOSE, OUTLINE, PINK, SHADE, T,
    new_grid, outline_silhouette, to_png,
)

# The homestead's own palette: the grove's greens, plus wood, water and a
# little warmth for the things that are lit.
HOME_PALETTE = {
    T: (0, 0, 0, 0),
    OUTLINE: (58, 48, 38, 255),
    BODY: (108, 142, 88, 255),      # foliage
    SHADE: (78, 108, 66, 255),      # foliage shade, moss, water depth
    CREAM: (226, 216, 196, 255),    # cloth, stone
    ACCENT: (112, 148, 168, 255),   # water
    NOSE: (128, 96, 66, 255),       # wood
    PINK: (216, 152, 160, 255),     # blossom
    GLINT: (240, 208, 128, 255),    # lamplight, honey
    EYE: (92, 70, 50, 255),         # dark wood: legs, rope, the shaded side
}


def shade_row(grid, y, was, becomes):
    """Recolour one row of an already-drawn shape, without spilling past it.

    Banding a skep or coursing a wall means drawing *inside* a silhouette. A
    plain `d.line` would paint the transparent pixels either side too and the
    outliner would then dutifully wrap the overspill, so the bands have to be
    applied to pixels that are already the right colour.
    """
    pixels = grid.load()
    for x in range(grid.width):
        if pixels[x, y] == was:
            pixels[x, y] = becomes


def pond(second):
    """A pond that cleared, and something in it that comes up sometimes."""
    g = new_grid(26, 12)
    d = ImageDraw.Draw(g)
    d.ellipse([1, 2, 24, 10], fill=ACCENT)
    d.ellipse([4, 4, 12, 7], fill=CREAM)                  # the sky in it
    if second:
        d.ellipse([15, 5, 19, 7], fill=SHADE)             # a back, briefly
        d.arc([13, 4, 21, 8], 200, 340, fill=CREAM)       # and the ring it left
    else:
        d.point((17, 6), fill=SHADE)
    return outline_silhouette(g)


def birdhouse(second):
    """A box on a post, and whoever took it."""
    g = new_grid(14, 22)
    d = ImageDraw.Draw(g)
    d.rectangle([6, 12, 8, 21], fill=NOSE)                # the post
    d.rectangle([2, 5, 12, 14], fill=CREAM)               # the box
    d.polygon([(1, 5), (13, 5), (7, 0)], fill=NOSE)       # its roof
    d.ellipse([5, 8, 9, 12], fill=OUTLINE)                # the hole
    if second:
        # Pale against the dark hole, or nobody can tell the box is occupied:
        # a brown bird in a brown-outlined hole is a hole.
        d.ellipse([5, 8, 8, 11], fill=GLINT)              # somebody leaning out
        d.point((7, 9), fill=OUTLINE)                     # and looking at you
    return outline_silhouette(g)


def beehive(second):
    """A skep, and one bee that is never where it was.

    Drawn as a stack of narrowing ellipses banded with `shade_row`, because a
    hive is read from its coiled straw rings — four pale lumps read as bread.
    """
    g = new_grid(14, 16)
    d = ImageDraw.Draw(g)
    for box in ([1, 10, 12, 13], [2, 7, 11, 11], [3, 4, 10, 8], [4, 1, 9, 5]):
        d.ellipse(box, fill=GLINT)
    for y in (10, 7, 4):
        shade_row(g, y, GLINT, NOSE)                      # the coils
    d.rectangle([1, 14, 12, 14], fill=NOSE)               # the stand
    d.ellipse([6, 11, 8, 13], fill=OUTLINE)               # the way in
    # The bee has to stand off the hive with air around it: touching the straw,
    # it is swallowed by the outline and the frames look identical. Two gold
    # pixels rather than one — a lone point outlines into a dark plus, which
    # reads as a sparkle.
    x = 11 if second else 1
    d.line([(x, 2 if second else 3), (x + 1, 2 if second else 3)], fill=GLINT)
    return outline_silhouette(g)


def hedge(second):
    """A hedge that flowered all at once, the way they do."""
    g = new_grid(28, 12)
    d = ImageDraw.Draw(g)
    for x in range(1, 27, 6):
        d.ellipse([x, 3, x + 8, 11], fill=BODY)
    d.rectangle([1, 8, 26, 11], fill=SHADE)
    blooms = ((4, 5), (11, 4), (17, 6), (23, 4)) if second else ((6, 4), (13, 6),
                                                                 (19, 4), (24, 6))
    for x, y in blooms:
        d.point((x, y), fill=PINK)
    return outline_silhouette(g)


def washline(second):
    """A line of washing, which is the thing that says somebody lives here.

    The first cut of this was a table: garments of equal length hung one pixel
    apart merge under the outliner into a single slab, and two full-height
    posts under a straight rail finish the illusion. So the line sags, the
    garments are three different lengths, and the gaps are wide enough to
    survive being outlined.
    """
    g = new_grid(24, 16)
    d = ImageDraw.Draw(g)
    d.line([(1, 2), (1, 14)], fill=EYE)                   # thin posts
    d.line([(22, 2), (22, 14)], fill=EYE)
    d.line([(1, 3), (8, 4)], fill=EYE)                    # and the sag in it
    d.line([(8, 4), (15, 4)], fill=EYE)
    d.line([(15, 4), (22, 3)], fill=EYE)
    # Hems are staggered by two clear rows as well as spaced by two clear
    # columns: the middle garment throws far enough that a shared row would
    # let the outliner weld it to its neighbour.
    for index, (x, hem, colour, throw) in enumerate(((4, 13, CREAM, 1),
                                                     (10, 9, PINK, 2),
                                                     (16, 12, CREAM, 1))):
        d.rectangle([x, 5, x + 3, hem - 2], fill=colour)
        # The hem, in the wind. One garment throws twice as far as the others,
        # so the loop has something a glance can catch; the rest is a shiver.
        kick = throw if (second != (index % 2 == 0)) else -throw
        d.rectangle([x + kick, hem - 1, x + 3 + kick, hem], fill=colour)
    return outline_silhouette(g)


def lantern(second):
    """A lantern on a post. Nobody has ever been seen lighting it."""
    g = new_grid(10, 20)
    d = ImageDraw.Draw(g)
    d.rectangle([4, 9, 6, 19], fill=NOSE)
    d.rectangle([2, 8, 8, 9], fill=NOSE)
    d.rectangle([2, 2, 8, 8], fill=CREAM)
    d.rectangle([3, 3, 7, 7], fill=GLINT if second else NOSE)
    d.polygon([(1, 2), (9, 2), (5, 0)], fill=NOSE)
    return outline_silhouette(g)


def well(second):
    """An old well, and the bucket still on the rope.

    A flat beam on two posts over a block is a table, so the roof is pitched
    and the stone is coursed horizontally — vertical mortar lines read as
    planks, which is the one thing a well must not be made of. The roof is
    also *narrower* than the stone: a wide roof over a small base is a hut,
    which is what the second attempt drew.
    """
    g = new_grid(18, 16)
    d = ImageDraw.Draw(g)
    d.polygon([(3, 3), (14, 3), (8, 0)], fill=NOSE)       # the roof
    d.line([(4, 4), (4, 7)], fill=EYE)                    # the posts
    d.line([(13, 4), (13, 7)], fill=EYE)
    d.rectangle([1, 8, 16, 8], fill=NOSE)                 # the coping
    d.rectangle([1, 9, 16, 14], fill=CREAM)               # the stone drum
    for corner in ((1, 14), (16, 14)):
        d.point(corner, fill=T)                           # worn round at the foot
    shade_row(g, 11, CREAM, SHADE)                        # a course, gone mossy
    for x in (5, 9, 13):
        d.line([(x, 9), (x, 10)], fill=SHADE)
    for x in (3, 7, 11, 15):
        d.line([(x, 12), (x, 14)], fill=SHADE)
    centre = 10 if second else 6                          # the bucket, swinging
    d.line([(centre, 4), (centre, 5)], fill=EYE)          # on its rope
    d.rectangle([centre, 6, centre + 1, 7], fill=NOSE)
    return outline_silhouette(g)


def bench(second):
    """A bench, facing the wood, which is the correct direction."""
    g = new_grid(20, 12)
    d = ImageDraw.Draw(g)
    d.rectangle([2, 6, 17, 8], fill=NOSE)                 # the seat
    d.rectangle([2, 2, 17, 3], fill=NOSE)                 # the back
    d.rectangle([3, 3, 4, 6], fill=NOSE)
    d.rectangle([15, 3, 16, 6], fill=NOSE)
    d.rectangle([3, 8, 4, 11], fill=EYE)                  # legs
    d.rectangle([15, 8, 16, 11], fill=EYE)
    if second:
        d.point((12, 5), fill=BODY)                       # a leaf, landed
    else:
        d.point((18, 0), fill=BODY)                       # a leaf, still coming
    return outline_silhouette(g)


RESIDENTS = {
    "pond": pond,
    "birdhouse": birdhouse,
    "beehive": beehive,
    "hedge": hedge,
    "washline": washline,
    "lantern": lantern,
    "well": well,
    "bench": bench,
}


if __name__ == "__main__":
    print("Residents:")
    for name, draw in RESIDENTS.items():
        for frame in (0, 1):
            to_png(draw(bool(frame)), HOME_PALETTE, f"resident_{name}_{frame}")
        print(f"  {name}: 2 frames")
