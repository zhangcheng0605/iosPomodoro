"""Generate the Cabinet of Clocks: five alternate faces, as frame strips.

The same sacred interval, rendered five other ways. Each face is a strip of
frames indexed by `engine.progress`, which keeps `TimerEngine` completely
untouched — a clock face in this app is a *view* over a number that already
exists, and none of them can know anything the ring doesn't.

Frames rather than SwiftUI shapes, and that is the plan's instruction rather
than a preference. A clock that stalls, jumps backward or runs out early is an
art regression, and an art regression at one frame per two minutes is
invisible to anybody watching — you would have to sit through a whole phase
with a stopwatch to catch it. Frames can be *measured*, and
`tools/check_clocks.py` measures them.

**The convention every face obeys:** the pixels drawn in `ACCENT` are the part
that grows with time — the wax pool, the fallen sand, the ash, the risen
water, the swept shadow. That one rule is what makes a single monotonicity
assertion cover all five, and it is why `check_clocks.py` can tell that a
candle is burning down rather than merely changing.

    python3 tools/generate_clocks.py
"""
import os
import sys

from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from generate_sprites import (
    ACCENT, BODY, CREAM, EYE, GLINT, NOSE, OUTLINE, PINK, SHADE, T,
    new_grid, outline_silhouette, to_png,
)

# Twelve frames over a phase: one step every two minutes of a 25-minute focus.
# Enough that a candle visibly moves between glances, few enough that the
# catalog does not grow by three hundred imagesets.
FRAMES = 12

# Portrait, and sized to sit inside the timer ring's dial rather than replace
# it — the digits stay exactly where they are, on their own capsule.
W, H = 34, 46

CLOCK_PALETTE = {
    T: (0, 0, 0, 0),
    OUTLINE: (86, 68, 52, 255),
    BODY: (232, 220, 198, 255),     # wax, glass, paper
    SHADE: (198, 180, 152, 255),
    CREAM: (246, 240, 226, 255),
    ACCENT: (176, 122, 92, 255),    # ALWAYS, and ONLY, the part that grows
    # The live end — flame, coal, falling stream, the drip in the air. Its own
    # index rather than ACCENT, and that is not a nicety: these all *stop* at
    # the end of the phase, so counting them as "the part that grows" made the
    # candle and the incense measure less on their last frame than their
    # second-to-last. `check_clocks.py` reported both as clocks running
    # backwards, which is exactly what they were.
    PINK: (206, 122, 74, 255),
    NOSE: (140, 108, 78, 255),      # wood, stands, frames
    GLINT: (252, 248, 240, 255),
    EYE: (0, 0, 0, 0),              # unused; `to_png` walks the whole palette
}


def candle(t):
    """A marked candle burning down, with its wax pooling at the base."""
    g = new_grid(W, H)
    d = ImageDraw.Draw(g)
    top = 6 + int(t * 22)                       # the flame comes down
    d.rectangle([12, top + 3, 21, 40], fill=BODY)
    for mark in range(1, 5):                    # the hour rings, still there
        y = 8 + mark * 6
        if y > top + 3:
            d.line([(12, y), (21, y)], fill=SHADE)
    if t < 0.99:
        d.ellipse([15, top - 3, 18, top + 2], fill=PINK)     # the flame
        d.line([(16, top + 1), (16, top + 3)], fill=OUTLINE)
    # The pool: everything that has melted has to go somewhere.
    pool = int(t * 11)
    if pool > 0:
        d.ellipse([16 - pool, 39, 17 + pool, 43], fill=ACCENT)
    return outline_silhouette(g)


def sand(t):
    """An hourglass. The oldest one of these, and still the clearest."""
    g = new_grid(W, H)
    d = ImageDraw.Draw(g)
    d.polygon([(6, 4), (27, 4), (18, 23), (15, 23)], fill=BODY)      # top bulb
    d.polygon([(15, 23), (18, 23), (27, 42), (6, 42)], fill=BODY)    # bottom
    # What is left up top, falling from the waist down.
    left = 1 - t
    if left > 0.02:
        height = int(left * 16)
        d.polygon([(16 - height, 21 - height), (17 + height, 21 - height),
                   (17, 22), (16, 22)], fill=SHADE)
    fallen = int(t * 15)
    if fallen > 0:
        d.polygon([(16 - fallen, 41), (17 + fallen, 41),
                   (17, 41 - fallen), (16, 41 - fallen)], fill=ACCENT)
    if 0.02 < t < 0.98:
        d.line([(16, 23), (16, 34)], fill=PINK)                      # the stream
    d.rectangle([4, 2, 29, 4], fill=NOSE)
    d.rectangle([4, 42, 29, 44], fill=NOSE)
    return outline_silhouette(g)


def incense(t):
    """A coal creeping down a carved stick, and the ash it leaves.

    The Onsen's native face, and the slowest-looking of the five: nothing here
    moves except a single lit pixel and a pile that gets one taller."""
    g = new_grid(W, H)
    d = ImageDraw.Draw(g)
    d.rectangle([15, 4, 18, 38], fill=BODY)
    for notch in range(6):                      # the carved hours
        d.line([(15, 6 + notch * 5), (18, 6 + notch * 5)], fill=SHADE)
    coal = 5 + int(t * 32)
    d.rectangle([15, 4, 18, coal], fill=SHADE)  # burnt, above the coal
    if t < 0.99:
        d.rectangle([15, coal, 18, coal + 1], fill=PINK)
    ash = int(t * 9)
    if ash > 0:
        d.ellipse([16 - ash, 39, 17 + ash, 42], fill=ACCENT)
    d.rectangle([10, 41, 23, 43], fill=NOSE)    # the holder
    return outline_silhouette(g)


def water(t):
    """A vessel filling, drop by drop. Harbor Isle's own."""
    g = new_grid(W, H)
    d = ImageDraw.Draw(g)
    d.polygon([(7, 12), (26, 12), (23, 42), (10, 42)], fill=BODY)
    for mark in range(1, 5):
        y = 16 + mark * 6
        d.line([(9, y), (12, y)], fill=SHADE)
    level = int(t * 28)
    if level > 0:
        # The vessel is wider at the top, so the surface gets *wider* as it
        # rises — which is the whole reason a real water clock needs unevenly
        # spaced marks. The first version inset the surface as it rose, i.e.
        # tapered it the wrong way, and the water pulled away from the glass.
        surface = 42 - level
        spread = (42 - surface) / 30 * 3
        d.polygon([(10 - spread, surface), (23 + spread, surface),
                   (23, 42), (10, 42)], fill=ACCENT)
    if t < 0.98:
        d.line([(16, 4), (16, 8)], fill=SHADE)      # the drip, still coming
        d.point((16, 10), fill=PINK)
    return outline_silhouette(g)


def shadow(t):
    """A gnomon, and the ground its shadow has already crossed."""
    g = new_grid(W, H)
    d = ImageDraw.Draw(g)
    d.ellipse([2, 14, 31, 43], fill=BODY)           # the dial plate
    # Everything the shadow has swept, filled. West to east, 200° of arc.
    if t > 0.02:
        d.pieslice([2, 14, 31, 43], 160, 160 + t * 200, fill=ACCENT)
    for hour in range(7):                           # the hour lines
        d.pieslice([8, 20, 25, 37], 160 + hour * 33, 161 + hour * 33, fill=SHADE)
    d.polygon([(16, 6), (19, 28), (14, 28)], fill=NOSE)      # the gnomon
    return outline_silhouette(g)


FACES = {
    "candle": candle,
    "sand": sand,
    "incense": incense,
    "water": water,
    "shadow": shadow,
}


if __name__ == "__main__":
    print("Clock faces:")
    for name, draw in FACES.items():
        for frame in range(FRAMES):
            # The last frame is the phase *finishing*, so it is drawn at 1.0
            # rather than at 11/12 — a candle that stops with an inch left
            # reads as a clock that gave up.
            t = frame / (FRAMES - 1)
            to_png(draw(t), CLOCK_PALETTE, f"clock_{name}_{frame}")
        print(f"  {name}: {FRAMES} frames")
