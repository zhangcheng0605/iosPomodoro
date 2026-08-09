"""Generate the pixel-art places Pawmodoro's journey travels through.

Same discipline as the sprite generator: draw into a small grid of palette
indices, map indices to colours, upscale with nearest-neighbour. Original
artwork, nothing to license.

Two things make this cheap. Each place is drawn **once** and exported four
times, because the time of day is a transform over the palette rather than a
redraw — and the window index is exempt from that transform, so windows light
up warm after dark for free. And the drawing primitives (ridges, hills, water,
trees, houses) are shared, so a place is about thirty lines of composition.

    python3 tools/generate_scenes.py

Places, their unlock costs and their travel vignettes are declared in
Pawmodoro/Model/Place.swift; the `id` strings here must match its
`assetPrefix`.
"""
import json
import os
import re

import numpy as np
from PIL import Image

W, H = 132, 286        # logical canvas, roughly iPhone portrait
UPSCALE = 3            # exported PNG is 396x858
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")

# Rows the countdown ring and its text sit over. Nothing but sky, cloud and
# far-distance haze may be drawn here — `assert_quiet_band` enforces it, and
# tools/check_contrast.py measures what actually lands behind the text.
QUIET_TOP, QUIET_BOTTOM = 52, 150

PARTS = ("dawn", "day", "dusk", "night")

# Palette indices.
(T, SKY_HI, SKY_MID, SKY_LO, CLOUD, CLOUD_SH, FAR, FAR_2, SEA_HI, SEA_LO,
 FOAM, LAND_HI, LAND_LO, TREE_HI, TREE_LO, TRUNK, WALL, ROOF, WINDOW,
 STONE, ACCENT, SNOW) = range(22)

BASE = {
    T:        (0, 0, 0, 0),
    SKY_HI:   (126, 197, 240, 255),
    SKY_MID:  (166, 218, 246, 255),
    SKY_LO:   (208, 236, 250, 255),
    CLOUD:    (255, 255, 255, 255),
    CLOUD_SH: (223, 235, 246, 255),
    FAR:      (156, 178, 200, 255),
    FAR_2:    (132, 156, 184, 255),
    SEA_HI:   (86, 158, 200, 255),
    SEA_LO:   (56, 116, 168, 255),
    FOAM:     (226, 244, 252, 255),
    LAND_HI:  (140, 196, 116, 255),
    LAND_LO:  (104, 164, 92, 255),
    TREE_HI:  (96, 162, 96, 255),
    TREE_LO:  (62, 122, 78, 255),
    TRUNK:    (124, 90, 62, 255),
    WALL:     (246, 238, 222, 255),
    ROOF:     (206, 106, 88, 255),
    WINDOW:   (120, 146, 168, 255),
    STONE:    (176, 176, 182, 255),
    ACCENT:   (238, 150, 176, 255),
    SNOW:     (250, 252, 255, 255),
}

# Time of day as a colour grade: blend toward a tint, then scale brightness.
# Windows are exempt — see `graded`.
GRADE = {
    "dawn":  ((255, 174, 152), 0.34, 0.94),
    "day":   ((255, 255, 255), 0.00, 1.00),
    "dusk":  ((255, 142, 108), 0.32, 0.86),
    # Night shifts hue hard but only dims moderately. Going near-black here
    # looked right on its own and wrong in the app: a light-appearance phone
    # keeps dark text, and a near-black backdrop under it fails contrast
    # everywhere. The app already says "night" through its own palette and sky
    # wash — the artwork only has to agree, not carry it alone.
    "night": ((44, 62, 120), 0.52, 0.68),
}

# What a window is doing at each time of day. Nobody's lamp is on at noon.
WINDOW_LIGHT = {
    "dawn": None,
    "day": None,
    "dusk": (255, 226, 168, 255),
    "night": (255, 212, 128, 255),
}


# --- Colour ----------------------------------------------------------------

def graded(palette, part):
    tint, amount, mul = GRADE[part]
    out = {}
    for index, rgba in palette.items():
        if index == T:
            out[index] = rgba
            continue
        if index == WINDOW and WINDOW_LIGHT[part] is not None:
            out[index] = WINDOW_LIGHT[part]
            continue
        r, g, b, a = rgba
        shaded = []
        for channel, target in zip((r, g, b), tint):
            value = channel + (target - channel) * amount
            shaded.append(max(0, min(255, int(round(value * mul)))))
        out[index] = (shaded[0], shaded[1], shaded[2], a)
    return out


# --- Deterministic noise ---------------------------------------------------
#
# A seeded generator rather than `random`, for the same reason the sprite
# frames are deterministic: the same place should look identical every run, so
# a screenshot from yesterday still means something.

class Rng:
    def __init__(self, seed):
        self.state = (seed * 2654435761) & 0x7FFFFFFF

    def _next(self):
        self.state = (self.state * 1103515245 + 12345) & 0x7FFFFFFF
        return self.state

    def unit(self):
        return self._next() / 0x7FFFFFFF

    def between(self, low, high):
        return low + self._next() % max(1, (high - low + 1))


# --- Primitives ------------------------------------------------------------

def new_scene():
    return np.full((H, W), SKY_LO, dtype=np.uint8)


def band(grid, y0, y1, index):
    grid[max(0, y0):max(0, y1), :] = index


BAYER = np.array([
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]) / 16.0


def sky_gradient(grid, horizon):
    """Three sky bands with a dithered seam between them.

    Dithering the whole band, which is the obvious way to do this, reads as
    noise rather than as a gradient — so each band stays solid and only the
    join is mixed."""
    stops = [(0.0, SKY_HI), (0.55, SKY_MID), (1.0, SKY_LO)]
    seam_from, seam_to = 0.60, 0.92
    for y in range(min(horizon, H)):
        t = y / max(1, horizon)
        for i in range(len(stops) - 1):
            t0, a = stops[i]
            t1, b = stops[i + 1]
            if t0 <= t <= t1:
                local = (t - t0) / max(1e-6, (t1 - t0))
                if local <= seam_from:
                    grid[y, :] = a
                elif local >= seam_to:
                    grid[y, :] = b
                else:
                    mix = (local - seam_from) / (seam_to - seam_from)
                    for x in range(W):
                        grid[y, x] = b if mix > BAYER[y % 4, x % 4] else a
                break


def cloud(grid, cx, cy, scale, rng=None):
    """A few overlapping lozenges with a shaded underside.

    Painted straight into `grid`, which makes it part of the picture and
    therefore immovable. That is right for cloud that is *scenery* — the bank
    Cloudspire's island floats on is the ground of that place, not its sky —
    and wrong for cloud in the sky, which lives in `SKY_CLOUDS` instead and is
    exported to its own layer. See `cloud_layer`.

    Columns wrap. Nothing in the shipped compositions comes near an edge (the
    nearest is ten columns clear), so this changes no pixel today; it exists
    so that the same primitive can paint the drifting layer, where a cloud cut
    off at the right edge would reappear sliced in half at the left.
    """
    puffs = [(0, 0, 1.0), (-scale, 1, 0.72), (scale, 1, 0.66),
             (-scale // 2, -1, 0.6), (scale // 2, -1, 0.55)]
    for dx, dy, factor in puffs:
        rx = max(2, int(scale * factor))
        ry = max(1, int(scale * factor * 0.45))
        for y in range(cy + dy - ry, cy + dy + ry + 1):
            for x in range(cx + dx - rx, cx + dx + rx + 1):
                if not 0 <= y < H:
                    continue
                nx = (x - (cx + dx)) / rx
                ny = (y - (cy + dy)) / ry
                if nx * nx + ny * ny <= 1.0:
                    grid[y, x % W] = (
                        CLOUD_SH if y > cy + dy + ry - 2 else CLOUD
                    )
    del rng


def ridge(grid, y_base, height, index, seed, roughness=0.55, start=0, end=W):
    """A mountain silhouette by midpoint displacement — cheap, and it never
    repeats the way a sum of sines does."""
    rng = Rng(seed)
    points = {start: y_base, end - 1: y_base}
    step = end - start - 1
    amplitude = height
    while step > 1:
        half = step // 2
        for x in range(start, end - 1, step):
            left = points[x]
            right = points[min(x + step, end - 1)]
            mid = (left + right) / 2 + (rng.unit() - 0.5) * amplitude
            points[x + half] = mid
        step = half
        amplitude *= roughness
    for x in range(start, end):
        top = int(points.get(x, y_base))
        grid[max(0, top):H, x] = np.where(
            grid[max(0, top):H, x] == index, index, index
        )
    return points


def hills(grid, y_base, amplitude, wavelength, index, phase=0.0, top_index=None):
    """Rolling ground: one sine, filled to the bottom of the canvas."""
    for x in range(W):
        y = int(y_base - amplitude * np.sin(2 * np.pi * (x / wavelength) + phase))
        grid[max(0, y):H, x] = index
        if top_index is not None and 0 <= y < H:
            grid[max(0, y):min(H, y + 2), x] = top_index


def water(grid, y0, rng, sparkle=0.014):
    """Depth bands plus glitter.

    Sparkle is concentrated near the horizon and thins toward the viewer —
    scattered evenly it stops reading as light on water and starts reading as
    television static, which is what the first attempt looked like."""
    for y in range(max(0, y0), H):
        depth = (y - y0) / max(1, H - y0)
        grid[y, :] = SEA_HI if depth < 0.34 else SEA_LO
    span = max(1, H - y0)
    for y in range(max(0, y0), H):
        nearness = (y - y0) / span
        density = sparkle * (1.0 - nearness) ** 1.6
        for x in range(W):
            if rng.unit() < density:
                grid[y, x] = FOAM
    # A few long glints in the near water, where waves would catch the light.
    for _ in range(14):
        y = rng.between(y0 + span // 2, H - 2)
        x = rng.between(2, W - 8)
        for dx in range(rng.between(2, 5)):
            speck(grid, x + dx, y, FOAM)


def pine(grid, x, y_base, height, hi=TREE_HI, lo=TREE_LO):
    width = max(2, height // 3)
    for i in range(height):
        y = y_base - i
        if not (0 <= y < H):
            continue
        half = int(width * (1 - i / height))
        for dx in range(-half, half + 1):
            px = x + dx
            if 0 <= px < W:
                grid[y, px] = lo if dx > half - 1 else hi
    for i in range(2):
        y = y_base + i
        if 0 <= y < H and 0 <= x < W:
            grid[y, x] = TRUNK


def round_tree(grid, x, y_base, radius, hi=TREE_HI, lo=TREE_LO):
    for y in range(y_base - 2 * radius, y_base + 1):
        for px in range(x - radius, x + radius + 1):
            if not (0 <= px < W and 0 <= y < H):
                continue
            nx = (px - x) / radius
            ny = (y - (y_base - radius)) / radius
            if nx * nx + ny * ny <= 1.0:
                grid[y, px] = lo if nx > 0.35 else hi
    for i in range(3):
        y = y_base + i - 1
        if 0 <= y < H and 0 <= x < W:
            grid[y, x] = TRUNK


def house(grid, x, y_base, width, height, wall=WALL, roof=ROOF, windows=True):
    """A wall block, a pitched roof, and one lit-able window."""
    for y in range(y_base - height, y_base):
        for px in range(x, x + width):
            if 0 <= px < W and 0 <= y < H:
                grid[y, px] = wall
    peak = max(2, width // 2)
    for i in range(peak):
        y = y_base - height - i
        if not (0 <= y < H):
            continue
        for px in range(x + i, x + width - i):
            if 0 <= px < W:
                grid[y, px] = roof
    if windows and height >= 5 and width >= 5:
        wy = y_base - height + 2
        for y in range(wy, min(wy + 2, y_base)):
            for px in range(x + 1, x + 3):
                if 0 <= px < W and 0 <= y < H:
                    grid[y, px] = WINDOW


def tower(grid, x, y_base, width, height, wall=WALL, roof=ROOF):
    for y in range(y_base - height, y_base):
        for px in range(x, x + width):
            if 0 <= px < W and 0 <= y < H:
                grid[y, px] = wall
    for i in range(width):
        y = y_base - height - i
        if not (0 <= y < H):
            continue
        for px in range(x + i, x + width - i):
            if 0 <= px < W:
                grid[y, px] = roof
    wy = y_base - height + 3
    if 0 <= wy < H and 0 <= x + width // 2 < W:
        grid[wy, x + width // 2] = WINDOW


def speck(grid, x, y, index):
    if 0 <= x < W and 0 <= y < H:
        grid[y, x] = index


def flowers(grid, y_from, y_to, rng, density=0.03):
    for y in range(max(0, y_from), min(H, y_to)):
        for x in range(W):
            if grid[y, x] in (LAND_HI, LAND_LO) and rng.unit() < density:
                grid[y, x] = ACCENT


def birds(grid, rng, count, y_from, y_to):
    for _ in range(count):
        x = rng.between(6, W - 8)
        y = rng.between(y_from, y_to)
        speck(grid, x, y, FAR_2)
        speck(grid, x + 1, y - 1, FAR_2)
        speck(grid, x + 2, y, FAR_2)


# --- The sky's own layer ---------------------------------------------------
#
# Every cloud that is *sky* used to be painted straight into the place, which
# is why it could not move: it was pixels in the picture, and a stir moved it
# by the 8/255 of the glow wash while the sun — three drawn shapes — moved 70.
#
# So the sky clouds come out into a layer of their own, exported once per place
# per time of day as a transparent PNG that `SceneryView` draws over the scene
# and under the veil. Composited at rest it is the same picture, pixel for
# pixel; given an offset it drifts, and given a stir it leans with the sun.
#
# These are the same centres, heights and scales that were in the composition
# functions, moved verbatim. Nothing was added and nothing was invented:
#
#   * **Cloudspire keeps its bank.** The three clouds *below* the island are
#     still `cloud(g, …)` calls inside `cloudspire()`, because they are not
#     sky — they are the ground of that place, the thing the rock floats over,
#     and they sit at the bottom of the screen where the buddy stands. Only the
#     two overhead ones drift.
#   * **The Onsen is not enclosed.** Its recipe draws open sky down to row 150
#     with two clouds in it, so it gets a layer like everywhere else.
#
# Anything added here has to keep two promises, both asserted below: it stays
# clear of the countdown's rows, and the rows it occupies are nothing but sky
# all the way across — because a drifting cloud visits every column, and a
# cloud that slides in front of a mountain is a cloud in the wrong place.
SKY_CLOUDS = {
    "meadow":     ((34, 26, 9), (96, 40, 7), (66, 14, 5)),
    "woods":      ((24, 20, 6), (104, 30, 8)),
    "harbor":     ((88, 34, 12), (30, 22, 8), (112, 16, 6)),
    "blossom":    ((40, 28, 9), (100, 20, 7)),
    "keep":       ((26, 24, 7), (108, 34, 9)),
    "cloudspire": ((30, 30, 10), (104, 22, 8)),
    "peaks":      ((96, 26, 7),),
    "onsen":      ((34, 24, 7), (100, 32, 9)),
}


def cloud_layer(name):
    """The transparent sheet of drifting cloud for one place."""
    layer = np.full((H, W), T, dtype=np.uint8)
    for cx, cy, scale in SKY_CLOUDS.get(name, ()):
        cloud(layer, cx, cy, scale)
    return layer


# --- The near plane --------------------------------------------------------
#
# `docs/CONTENT_PLAN.md` F1 asked for a second layer per scene — "a dock post,
# grass fringe, branch" — drawn in front, so the place has something *near* in
# it and not only a backdrop. It was never built. This is it.
#
# It is the cloud sheet's mirror image and deliberately so: same canvas, same
# palette, same four grades, same transparent export, same `scaledToFill`
# framing in the app. The only differences are which side of the world it is on
# and how much of the theme is laid back over it — see `SceneForegroundView`,
# which veils this at half the scene's 0.52. That halved veil is the depth cue
# that does the actual work: the far world is hazed toward the theme's cream,
# the near world is not, which is atmospheric perspective and is free.
#
# **Where it may be drawn is decided by the app, not by taste.** Everything that
# stands in a place stands on one line — `Stray.groundLine`, which the stray,
# the snail and the postcard's buddy all share — and a near plane that reached
# above it would put creatures behind grass that `check_stray.py` and
# `check_snail.py` do not composite, so their contrast measurements would
# quietly stop describing the screen. So the ceiling is that line plus a small
# margin, read out of `Stray.swift` rather than written down again here.
#
# The second rule is the app's own layout. Measured on an iPhone 17 at the
# default text size, the lowest thing the UI draws is the transport row's rim
# at 0.76 of the screen; the ceiling below works out at 0.811, which clears it.
# That margin is not relied on, though — the layer is composited *behind* the
# main column, for the reason written up in `ContentView.nearPlane`.

# How far below the ground line the near plane has to start, in grid rows.
FG_MARGIN = 6


def ground_line():
    """`Stray.groundLine`, asked for rather than copied.

    The rule this repo keeps paying to relearn: if a tool has a value another
    file also has, it is already wrong. The near plane's ceiling is derived
    from this, so moving the ground in the Swift moves the ceiling here on the
    next run instead of silently overlapping the stray.
    """
    path = os.path.join(ROOT, "Pawmodoro", "Model", "Stray.swift")
    found = re.search(r"static let groundLine: Double = ([\d.]+)", open(path).read())
    if not found:
        raise AssertionError("Stray.swift: could not find Stray.groundLine")
    return float(found.group(1))


FG_TOP = int(round(ground_line() * H)) + FG_MARGIN


def fg_new():
    return np.full((H, W), T, dtype=np.uint8)


def fg_speck(layer, x, y, index):
    """A pixel in the near plane. Columns wrap, rows are clipped.

    Wrapping matters here for the same reason it does in `cloud`: this sheet is
    framed with `scaledToFill` and bleeds past the frame, so a shape running off
    the right edge should continue at the left rather than end in mid-air on a
    Mac window wider than the art."""
    if FG_TOP <= y < H:
        layer[y, x % W] = index


def fg_blade(layer, x, base, height, index, lean=0.0, tip=None):
    """One tapering blade of grass, standing on `base` and leaning as it rises."""
    for i in range(height):
        y = base - i
        t = i / max(1, height - 1)
        px = x + int(round(lean * t * t * height))
        fg_speck(layer, px, y, index)
        # Thick at the root, one pixel at the tip — a blade rather than a wire.
        if t < 0.45:
            fg_speck(layer, px + 1, y, index)
    if tip is not None:
        top = base - height
        fg_speck(layer, x + int(round(lean * height)), top, tip)
        fg_speck(layer, x + int(round(lean * height)) + 1, top, tip)


def fg_turf(layer, top, index, jitter, rng, shade=None):
    """A solid mass of near ground with a ragged top edge, filled to the bottom."""
    for x in range(W):
        y = top + rng.between(0, jitter)
        for yy in range(y, H):
            fg_speck(layer, x, yy, index)
        if shade is not None:
            fg_speck(layer, x, y, shade)


def fg_boulder(layer, cx, base, rx, ry, index, cap=None):
    """A rounded near-mass: rocks, tussocks, bushes."""
    for y in range(base - 2 * ry, base + 1):
        for x in range(cx - rx, cx + rx + 1):
            nx = (x - cx) / max(1, rx)
            ny = (y - (base - ry)) / max(1, ry)
            if nx * nx + ny * ny <= 1.0:
                fg_speck(layer, x, y, index)
                if cap is not None and ny < -0.45:
                    fg_speck(layer, x, y, cap)


def fg_masonry(layer, top, base, light, dark, mortar, rng, course=5, block=11):
    """Coursed stone: staggered rectangular blocks with mortar between them.

    **Not `(x + y) % n`.** That is what the first draft of the keep's parapet
    and the onsen's rim used, and at this size, over an area this large, two
    multiplied-and-wrapped sequences form a lattice: both came out as visible
    diagonal hatching. It is the same failure `check_grove.py` was green
    through, and it was found the same way — by compositing the finished
    surface and looking at it, not by reading the code.
    """
    for row, y in enumerate(range(top, base)):
        if (y - top) % course == 0:
            for x in range(W):
                fg_speck(layer, x, y, mortar)
            continue
        offset = (row // course) * (block // 2)
        for x in range(W):
            joint = (x + offset) % block == 0
            if joint:
                fg_speck(layer, x, y, mortar)
            else:
                fg_speck(layer, x, y, light if rng.unit() < 0.72 else dark)


def fg_post(layer, x, top, width, index, cap=None):
    """A mooring post, a fence post, a bamboo culm."""
    for y in range(top, H):
        for dx in range(width):
            fg_speck(layer, x + dx, y, index)
    if cap is not None:
        for dx in range(-1, width + 1):
            fg_speck(layer, x + dx, top, cap)


def fg_meadow():
    """Home: a fringe of long grass and wildflower heads."""
    layer = fg_new()
    rng = Rng(211)
    # A solid mass first, so the blades rise out of something. Blades alone
    # composited as wires standing on nothing — grass reads as a mass with an
    # edge, and the edge is the only part that needs to be blades.
    fg_turf(layer, 266, LAND_LO, 6, rng, shade=LAND_HI)
    for x in range(0, W, 3):
        fg_boulder(layer, x + rng.between(0, 2), 276, rng.between(4, 8),
                   rng.between(4, 8), TREE_LO if rng.unit() < 0.5 else TREE_HI)
    for x in range(0, W, 2):
        if rng.unit() < 0.72:
            height = rng.between(8, H - 6 - FG_TOP)
            lean = (rng.unit() - 0.5) * 0.30
            head = ACCENT if rng.unit() < 0.13 else None
            fg_blade(layer, x, 274, height, TREE_LO if x % 4 else TREE_HI,
                     lean=lean, tip=head)
    return layer


def fg_frond(layer, x, base, height, spine, leaflet, lean=0.0):
    """A fern: a curving spine with paired leaflets, longest at the root.

    Drawn as leaflets rather than as speckle. The first version scattered
    single pixels either side of a stem and composited as noise — a fern reads
    because its leaflets are *paired* and shorten toward the tip, and one pixel
    cannot be a pair.
    """
    for i in range(height):
        y = base - i
        t = i / max(1, height - 1)
        px = x + int(round(lean * t * t * height))
        fg_speck(layer, px, y, spine)
        if i % 3:
            continue
        arm = int(round(6 * (1 - t) ** 0.8))
        for dx in range(1, arm + 1):
            drop = dx // 3
            fg_speck(layer, px - dx, y + drop, leaflet)
            fg_speck(layer, px + dx, y + drop, leaflet)


def fg_woods():
    """A fallen log across the near bank, with ferns growing over it."""
    layer = fg_new()
    rng = Rng(223)
    fg_turf(layer, 276, TREE_LO, 4, rng)
    for x in range(W):                       # the log, sagging to the right
        y = 258 + int(4 * np.sin(x / 40.0 + 0.4))
        for dy in range(9):
            fg_speck(layer, x, y + dy, TRUNK if dy else FAR_2)
        if rng.unit() < 0.18:                # moss along its upper edge
            fg_speck(layer, x, y, TREE_HI)
            fg_speck(layer, x, y + 1, TREE_HI)
    for cx in (26, 96):                      # two mushroom caps, the wood's motif
        for dy in range(5):
            fg_speck(layer, cx, 272 + dy, WALL)
            fg_speck(layer, cx + 1, 272 + dy, WALL)
        fg_boulder(layer, cx, 273, 5, 3, ACCENT)
    # Standing *in front of* the log and taller than it, which is the point —
    # the first version topped out below the log's own rows and read as green
    # stipple round its feet rather than as anything growing.
    for x in range(4, W, 13):
        fg_frond(layer, x, H - 2, rng.between(30, 44),
                 TREE_LO, TREE_HI, lean=(rng.unit() - 0.5) * 0.4)
    return layer


def fg_harbor():
    """Two mooring posts and the rope slung between them."""
    layer = fg_new()
    rng = Rng(233)
    for x in range(W):                       # the near planking
        fg_speck(layer, x, 276, TRUNK)
        for dy in range(1, 10):
            fg_speck(layer, x, 276 + dy, FAR_2 if x % 9 else TRUNK)
    left, right = 16, 104
    fg_post(layer, left, 240, 5, TRUNK, cap=FAR_2)
    fg_post(layer, right, 244, 5, TRUNK, cap=FAR_2)
    span = right - left
    for i in range(span + 1):                # the rope, a shallow catenary
        t = i / span
        y = 244 + int(26 * np.sin(np.pi * t)) + int(2 * t)
        fg_speck(layer, left + 2 + i, y, FAR_2)
        if i % 6 < 3:
            fg_speck(layer, left + 2 + i, y + 1, TRUNK)
    for _ in range(12):                      # barnacles on the planks
        fg_speck(layer, rng.between(0, W - 1), rng.between(278, H - 1), STONE)
    return layer


def fg_blossom():
    """The lip of the nearest terrace, and the flowers spilling over it."""
    layer = fg_new()
    rng = Rng(241)
    fg_turf(layer, 272, LAND_LO, 4, rng, shade=LAND_HI)
    for x in range(W):                       # the retaining wall's coping
        fg_speck(layer, x, 276, WALL)
        fg_speck(layer, x, 277, STONE)
    # Distinct bushes with sky between them, not a hedge. Spaced at 11 with a
    # radius of 6 they merged into one green band across the screen, which is
    # the same shape as the terraces behind and read as another stripe.
    for cx in range(8, W + 8, 21):
        fg_boulder(layer, cx, 274, 8, 9, TREE_HI, cap=TREE_LO)
        for _ in range(9):
            fg_speck(layer, cx + rng.between(-6, 6),
                     260 + rng.between(0, 12), ACCENT)
    for cx in (2, 124):                      # a taller one at each edge
        fg_boulder(layer, cx, 268, 11, 15, TREE_LO)
        for _ in range(18):
            fg_speck(layer, cx + rng.between(-9, 9),
                     FG_TOP + 6 + rng.between(0, 20), ACCENT)
    return layer


def fg_keep():
    """A stone parapet at the top of the stair, with ivy over it."""
    layer = fg_new()
    rng = Rng(251)
    fg_masonry(layer, 258, H, WALL, STONE, FAR, rng, course=6, block=13)
    for x in range(W):                       # the capping course, run flat
        fg_speck(layer, x, 258, WALL)
        fg_speck(layer, x, 259, WALL)
        fg_speck(layer, x, 260, STONE)
    for x in range(1, W, 17):                # merlons
        for dx in range(10):
            for y in range(244, 258):
                shade = WALL if rng.unit() < 0.78 else STONE
                fg_speck(layer, x + dx, y, shade)
            fg_speck(layer, x + dx, 244, STONE)
            fg_speck(layer, x + dx, 245, WALL)
    for x in range(0, W, 7):                 # ivy in clusters, not scratches
        if rng.unit() > 0.7:
            continue
        drop = rng.between(8, 22)
        for i in range(0, drop, 3):
            cx = x + (i // 5)
            fg_boulder(layer, cx, 262 + i, 3, 2, TREE_LO)
            fg_speck(layer, cx - 1, 261 + i, TREE_HI)
            fg_speck(layer, cx + 1, 261 + i, TREE_HI)
    return layer


def fg_cloudspire():
    """You are above the weather here, so some of it passes in front."""
    layer = fg_new()
    for cx, cy, scale in ((18, 272, 16), (74, 280, 20), (120, 268, 13)):
        cloud(layer, cx, cy, scale)
    # `cloud` paints its own rows and does not know about the ceiling, so trim
    # rather than trust it — this is the one recipe that borrows a primitive
    # written for the sky.
    layer[:FG_TOP, :] = T
    return layer


def fg_peaks():
    """Near boulders under snow, and the tops of three pines."""
    layer = fg_new()
    rng = Rng(263)
    fg_turf(layer, 274, FAR_2, 5, rng)
    for cx, rx, ry in ((14, 18, 9), (52, 14, 7), (92, 20, 11), (126, 15, 8)):
        fg_boulder(layer, cx, 284, rx, ry, STONE, cap=SNOW)
    for x, height in ((30, 22), (72, 18), (110, 24)):
        for i in range(height):
            y = H - 1 - i
            half = int(max(0, 7 * (1 - i / height)))
            for dx in range(-half, half + 1):
                fg_speck(layer, x + dx, y, TREE_LO)
            if i % 5 == 0 and half > 1:
                fg_speck(layer, x - half, y, SNOW)
                fg_speck(layer, x + half, y, SNOW)
    return layer


def fg_onsen():
    """The near rim of the bath, cobbled, and three stalks of bamboo."""
    layer = fg_new()
    rng = Rng(277)
    lip = [262 + int(6 * np.cos(x / 42.0)) for x in range(W)]
    for x in range(W):                       # the rim, curving toward you
        for y in range(lip[x], H):
            fg_speck(layer, x, y, STONE)
        fg_speck(layer, x, lip[x], WALL)
    # Cobbles set into it: rounded, overlapping, laid down the rim rather than
    # scattered — a wet stone edge is stones, and modular speckle is hatching.
    for band in range(4):
        y = 270 + band * 5
        x = 2 + band * 3
        while x < W + 6:
            radius = rng.between(3, 6)
            fg_boulder(layer, x, y + rng.between(0, 2), radius,
                       max(2, radius - 2), FAR, cap=WALL)
            x += radius + rng.between(2, 4)
    for x, top in ((5, FG_TOP + 2), (13, FG_TOP + 9), (23, FG_TOP + 5)):
        fg_post(layer, x, top, 4, TREE_HI)   # bamboo at the left edge
        for y in range(top, H, 10):          # the nodes
            for dx in range(-1, 5):
                fg_speck(layer, x + dx, y, TREE_LO)
    for i in range(11):                      # leaves off the nearest culm
        fg_speck(layer, 28 + i, FG_TOP + 6 + i // 2, TREE_HI)
        fg_speck(layer, 28 + i, FG_TOP + 7 + i // 2, TREE_HI)
        fg_speck(layer, 30 + i, FG_TOP + 22 - i // 3, TREE_LO)
    return layer


FOREGROUNDS = {
    "meadow": fg_meadow,
    "woods": fg_woods,
    "harbor": fg_harbor,
    "blossom": fg_blossom,
    "keep": fg_keep,
    "cloudspire": fg_cloudspire,
    "peaks": fg_peaks,
    "onsen": fg_onsen,
}


# --- The places ------------------------------------------------------------

def meadow():
    """Home. Rolling hills, one crooked cottage, a fence, wildflowers."""
    g = new_scene()
    rng = Rng(11)
    sky_gradient(g, 186)
    birds(g, rng, 3, 56, 88)
    hills(g, 168, 6, 190, FAR, phase=0.6)
    hills(g, 186, 9, 150, LAND_LO, phase=1.8)
    hills(g, 202, 7, 118, LAND_HI, phase=0.2)
    for x, r in ((16, 7), (112, 6), (92, 5)):
        round_tree(g, x, 212, r)
    house(g, 46, 226, 22, 15)
    for i in range(3):                       # chimney
        speck(g, 62, 226 - 15 - 4 - i, WALL)
    for x in range(8, W - 8, 6):             # fence
        for dy in range(4):
            speck(g, x, 244 + dy, TRUNK)
    for x in range(8, W - 8):
        speck(g, x, 245, TRUNK)
    flowers(g, 206, H, rng, 0.035)
    return g


def woods():
    """Pines and birches with a stream cutting the foreground."""
    g = new_scene()
    rng = Rng(23)
    sky_gradient(g, 176)
    hills(g, 166, 5, 210, FAR, phase=2.2)
    hills(g, 188, 7, 160, LAND_LO, phase=0.9)
    band(g, 198, H, LAND_HI)
    # A far treeline of silhouettes standing on the hill, rather than the flat
    # dark band a filled hill gives.
    for x in range(2, W, 6):
        pine(g, x, 196, 13, hi=TREE_LO, lo=TREE_LO)
    for x, h in ((14, 26), (36, 22), (60, 28), (86, 24), (114, 27)):
        pine(g, x, 218, h)
    for y in range(226, 250):                # the stream
        width = 16 + int(6 * np.sin(y / 7.0))
        centre = 66 + int(10 * np.sin(y / 11.0))
        for x in range(centre - width // 2, centre + width // 2):
            speck(g, x, y, SEA_HI if (x + y) % 5 else FOAM)
    for x in range(52, 82):                  # a log bridge
        speck(g, x, 234, TRUNK)
        speck(g, x, 235, TRUNK)
    for cx in (24, 100, 44):                 # mushroom caps
        speck(g, cx, 258, ACCENT)
        speck(g, cx + 1, 258, ACCENT)
        speck(g, cx, 259, WALL)
    flowers(g, 250, H, rng, 0.02)
    return g


def harbor():
    """Open sea, two islets, a stub tower. The sailboat crosses here."""
    g = new_scene()
    rng = Rng(37)
    sky_gradient(g, 172)
    birds(g, rng, 4, 60, 96)
    water(g, 174, rng, 0.04)
    for x in range(0, W):                    # far shore
        speck(g, x, 172, FAR)
        speck(g, x, 173, FAR_2)
    # Small islet, left.
    for x in range(14, 40):
        h = int(6 * np.sin((x - 14) / 26 * np.pi))
        for y in range(186 - h, 190):
            speck(g, x, y, LAND_LO)
    round_tree(g, 22, 185, 4)
    round_tree(g, 33, 186, 3)
    # The main isle, right, with a stub tower on top.
    for x in range(74, 124):
        h = int(16 * np.sin((x - 74) / 50 * np.pi))
        for y in range(196 - h, 202):
            speck(g, x, y, LAND_LO if x % 7 else LAND_HI)
    tower(g, 96, 188, 7, 14)
    house(g, 82, 198, 12, 8)
    house(g, 108, 199, 10, 7)
    for x in range(70, 128):                 # dock
        speck(g, x, 210, TRUNK)
    for x in range(72, 128, 8):
        speck(g, x, 211, TRUNK)
        speck(g, x, 212, TRUNK)
    return g


def blossom():
    """Terraced flower beds under a pastel hillside, and a waterfall thread."""
    g = new_scene()
    rng = Rng(53)
    sky_gradient(g, 180)
    # Two shallow pastel ranges rather than one heavy mass — layered depth
    # instead of a magenta blob across the middle of the screen.
    for x in range(W):
        far_y = 158 + int(8 * np.sin(x / 34.0 + 0.4)) + int(4 * np.sin(x / 13.0))
        for yy in range(max(0, far_y), 200):
            speck(g, x, yy, FAR)
    for x in range(W):
        near_y = 176 + int(9 * np.sin(x / 21.0 + 2.4))
        for yy in range(max(0, near_y), 202):
            speck(g, x, yy, FAR_2)
    for y in range(154, 200):                # waterfall
        for x in range(100, 105):
            speck(g, x, y, FOAM if (x + y) % 3 else SEA_HI)
    hills(g, 200, 6, 140, LAND_LO, phase=1.1)
    band(g, 212, H, LAND_HI)
    for x in range(96, 118):                 # the pool it falls into
        for y in range(200, 208):
            speck(g, x, y, SEA_HI if (x + y) % 4 else FOAM)
    house(g, 20, 224, 24, 14)
    house(g, 56, 220, 16, 10)
    for i in range(3):
        speck(g, 38, 224 - 14 - 3 - i, WALL)
    for row, y in enumerate(range(236, 264, 7)):   # terraced beds
        for x in range(8 + row * 3, W - 8 - row * 2):
            speck(g, x, y, ACCENT if (x + row) % 3 else LAND_LO)
            speck(g, x, y + 1, LAND_LO)
    for x in (88, 104, 120):                 # paper lanterns
        speck(g, x, 226, WINDOW)
        speck(g, x, 227, WINDOW)
    for x, r in ((78, 6), (122, 5)):
        round_tree(g, x, 232, r, hi=ACCENT, lo=ACCENT)
    return g


def keep():
    """White stone, teal domes, banners. The stairs climb out of frame."""
    g = new_scene()
    rng = Rng(71)
    sky_gradient(g, 174)
    birds(g, rng, 3, 62, 92)
    hills(g, 178, 4, 200, FAR, phase=0.4)
    band(g, 184, H, LAND_LO)
    band(g, 196, H, STONE)
    for step, y in enumerate(range(236, H, 8)):    # the stair flight
        inset = 10 + step * 5
        for x in range(inset, W - inset):
            speck(g, x, y, WALL)
            speck(g, x, y + 1, STONE)
    tower(g, 24, 200, 9, 22, roof=SEA_LO)
    tower(g, 100, 202, 9, 20, roof=SEA_LO)
    for y in range(186, 214):                # the keep itself
        for x in range(48, 86):
            # Shade the right third rather than speckling the whole face, so
            # it reads as a lit wall with a shadow side.
            speck(g, x, y, STONE if x > 76 else WALL)
    for i in range(11):                      # dome, rounded not stepped
        y = 186 - i
        half = int(19 * np.sqrt(max(0.0, 1 - (i / 11.0) ** 2)))
        for x in range(67 - half, 67 + half + 1):
            speck(g, x, y, SEA_LO)
    for wy in (194, 202):                    # arched windows
        for x in range(54, 82, 7):
            speck(g, x, wy, WINDOW)
            speck(g, x, wy + 1, WINDOW)
    for bx in (44, 88):                      # banners
        for y in range(200, 214):
            speck(g, bx, y, ACCENT)
    return g


def cloudspire():
    """A floating rock with a spire on it, and clouds passing underneath."""
    g = new_scene()
    rng = Rng(89)
    sky_gradient(g, H)
    birds(g, rng, 4, 66, 104)
    top = 196
    for x in range(26, 108):                 # the island's grassy cap
        edge = abs(x - 67) / 41.0
        y = top + int(6 * edge * edge)
        for yy in range(y, y + 5):
            speck(g, x, yy, LAND_HI if yy < y + 2 else LAND_LO)
    for depth in range(0, 46):               # the rock tapering to a point
        y = top + 5 + depth
        half = int(40 * (1 - depth / 46.0) ** 1.35)
        for x in range(67 - half, 67 + half + 1):
            speck(g, x, y, STONE if (x + y) % 9 else FAR_2)
    tower(g, 60, 196, 9, 26, roof=ROOF)
    house(g, 44, 198, 12, 9)
    house(g, 78, 199, 11, 8)
    for x, r in ((36, 5), (94, 4)):
        round_tree(g, x, 198, r)
    cloud(g, 22, 250, 9, rng)                # clouds *below* the island
    cloud(g, 108, 262, 11, rng)
    cloud(g, 64, 272, 8, rng)
    return g


def peaks():
    """A dark ridge line and a viaduct — where the night train runs."""
    g = new_scene()
    rng = Rng(101)
    sky_gradient(g, 182)
    for x in range(W):                       # two ridge layers
        # Base chosen so the tallest peak still clears the countdown band.
        y = 172 + int(14 * np.sin(x / 26.0 + 1.2)) + int(6 * np.sin(x / 9.0))
        for yy in range(max(0, y), H):
            speck(g, x, yy, FAR)
        if y < 178:
            for yy in range(max(0, y), min(H, y + 3)):
                speck(g, x, yy, SNOW)
    for x in range(W):
        y = 190 + int(14 * np.sin(x / 19.0 + 3.1))
        for yy in range(max(0, y), H):
            speck(g, x, yy, FAR_2)
    band(g, 232, H, TREE_LO)
    for x in range(0, W, 7):
        pine(g, x, 244, 14, hi=TREE_LO, lo=TREE_LO)
    for x in range(W):                       # the viaduct deck
        speck(g, x, 224, STONE)
        speck(g, x, 225, STONE)
    for x in range(6, W, 18):                # its arches
        for y in range(226, 240):
            speck(g, x, y, STONE)
            speck(g, x + 1, y, STONE)
    return g


def onsen():
    """A stone hot spring under the mountains, with capybaras in the far pool."""
    g = new_scene()
    rng = Rng(127)
    sky_gradient(g, 178)
    for x in range(W):
        y = 150 + int(16 * np.sin(x / 24.0 + 0.7))
        for yy in range(max(0, y), 196):
            speck(g, x, yy, FAR)
    band(g, 190, H, LAND_LO)
    for x in range(0, W, 9):
        pine(g, x, 200, 12, hi=TREE_LO, lo=TREE_LO)
    # An oval pool with a stone rim that follows it, instead of a rectangle.
    cx, cy, rx, ry = 66, 234, 56, 19
    for y in range(cy - ry - 2, cy + ry + 3):
        for x in range(cx - rx - 2, cx + rx + 3):
            if not (0 <= x < W and 0 <= y < H):
                continue
            nx, ny = (x - cx) / rx, (y - cy) / ry
            d = nx * nx + ny * ny
            if d <= 1.0:
                speck(g, x, y, SEA_HI if (x + y) % 7 else FOAM)
            elif d <= 1.24:
                speck(g, x, y, STONE)
    for x in range(30, 60):                  # a smaller far pool
        for y in range(200, 210):
            speck(g, x, y, SEA_LO if (x + y) % 5 else SEA_HI)
    for cx in (38, 48):                      # capybaras, two pixels of charm
        speck(g, cx, 202, TRUNK)
        speck(g, cx + 1, 202, TRUNK)
        speck(g, cx, 201, TRUNK)
    for x in (20, 66, 110):                  # stone lanterns
        speck(g, x, 210, STONE)
        speck(g, x, 209, WINDOW)
    return g


PLACES = [
    ("meadow", meadow, {}),
    ("woods", woods, {
        LAND_HI: (128, 178, 104, 255), LAND_LO: (92, 146, 84, 255),
        TREE_HI: (86, 150, 92, 255), TREE_LO: (52, 104, 70, 255),
    }),
    ("harbor", harbor, {
        SEA_HI: (78, 158, 206, 255), SEA_LO: (44, 104, 158, 255),
    }),
    ("blossom", blossom, {
        FAR: (196, 178, 206, 255), FAR_2: (170, 152, 186, 255),
        ACCENT: (246, 168, 190, 255), LAND_HI: (154, 200, 152, 255),
        LAND_LO: (118, 172, 132, 255),
    }),
    ("keep", keep, {
        WALL: (250, 246, 236, 255), STONE: (206, 202, 196, 255),
        SEA_LO: (86, 176, 176, 255), ACCENT: (226, 132, 92, 255),
        LAND_LO: (120, 158, 116, 255),
    }),
    ("cloudspire", cloudspire, {
        STONE: (152, 140, 132, 255), FAR_2: (122, 110, 106, 255),
        SKY_HI: (104, 178, 232, 255), SKY_MID: (150, 206, 242, 255),
    }),
    ("peaks", peaks, {
        SKY_HI: (78, 118, 176, 255), SKY_MID: (120, 158, 202, 255),
        SKY_LO: (168, 196, 224, 255), FAR: (96, 106, 138, 255),
        FAR_2: (70, 78, 108, 255), TREE_LO: (44, 62, 72, 255),
        STONE: (128, 124, 132, 255),
    }),
    ("onsen", onsen, {
        FAR: (128, 128, 150, 255), SEA_HI: (150, 200, 208, 255),
        SEA_LO: (108, 170, 186, 255), FOAM: (232, 248, 250, 255),
        LAND_LO: (98, 122, 104, 255), STONE: (150, 148, 148, 255),
    }),
]

# What crosses the sky or the water while a session runs, drawn once each.
QUIET_ALLOWED = {SKY_HI, SKY_MID, SKY_LO, CLOUD, CLOUD_SH, FAR, FAR_2}


def assert_quiet_band(name, grid):
    """The countdown has to stay readable, so the rows it occupies may only
    contain sky. This catches a composition that drifts upward long before a
    contrast measurement would."""
    strip = grid[QUIET_TOP:QUIET_BOTTOM, :]
    found = set(np.unique(strip).tolist()) - QUIET_ALLOWED
    if found:
        raise AssertionError(
            f"{name}: rows {QUIET_TOP}-{QUIET_BOTTOM} are behind the countdown "
            f"and must be sky only; found palette indices {sorted(found)}"
        )


def assert_drifting_layer(name, grid, layer):
    """The two rules a cloud has to keep once it is allowed to move.

    Both are invisible in a single screenshot, which is why they are assertions
    rather than something to check by eye:

    1. **It stays out of the countdown's rows.** `assert_quiet_band` lets cloud
       into that band because painted cloud is a fixed, known backdrop that
       `check_contrast.py` has measured. A *drifting* cloud is not: it visits
       every column of those rows over a lap, so nothing that moves may enter
       them at all. Today the lowest cloud pixel in the app is row 43, nine
       rows clear.
    2. **Every row it occupies is sky the whole way across.** A cloud drawn at
       one x with a mountain 40 columns away looks fine standing still and
       becomes a cloud in front of the mountain thirty seconds later.
    """
    rows = np.where((layer != T).any(axis=1))[0]
    if rows.size == 0:
        return
    top, bottom = int(rows.min()), int(rows.max())
    if bottom >= QUIET_TOP:
        raise AssertionError(
            f"{name}: a drifting cloud reaches row {bottom}, and rows "
            f"{QUIET_TOP}-{QUIET_BOTTOM} are behind the countdown. Nothing "
            f"that moves may enter them."
        )
    sky = {SKY_HI, SKY_MID, SKY_LO}
    behind = set(np.unique(grid[top:bottom + 1, :]).tolist()) - sky
    if behind:
        raise AssertionError(
            f"{name}: rows {top}-{bottom} carry drifting cloud, so they must "
            f"be sky all the way across — a cloud visits every column. Found "
            f"palette indices {sorted(behind)}"
        )


def assert_near_plane(name, layer):
    """The near plane's one hard rule, and why it is a rule.

    It is drawn in front of the world, so anything it reaches is *hidden* —
    not dimmed, not tinted, gone. Everything that stands in a place stands on
    `Stray.groundLine`: the stray, the snail, and the buddy on a postcard.
    `check_stray.py` and `check_snail.py` composite the scene, the veil and the
    sky wash behind those sprites and measure the silhouette against them; they
    know nothing about this layer, and they never will, because a checker that
    has to be told about every future layer is a checker that will one day be
    out of date without failing. So the near plane simply may not reach the
    ground line, and this is the assertion that says so.

    Six rows of margin below it, which at this canvas is about eighteen device
    pixels — enough that a sprite drawn a little tall, or a phone that crops the
    art a little differently, still has its feet in the clear.
    """
    rows = np.where((layer != T).any(axis=1))[0]
    if rows.size == 0:
        raise AssertionError(
            f"{name}: no near plane. Every place gets one — an empty sheet is "
            f"32 KB of nothing and a scene with no depth."
        )
    top = int(rows.min())
    if top < FG_TOP:
        raise AssertionError(
            f"{name}: the near plane reaches row {top}, and it may not go above "
            f"row {FG_TOP} — {FG_MARGIN} rows below Stray.groundLine at "
            f"{int(round(ground_line() * H))}. Anything standing in this place "
            f"stands on that line and would be drawn behind this layer."
        )


def assert_view_agrees():
    """The drifting layer is tiled, so the view has to know one tile's width.

    `scaledToFill` will not tell it, so `DriftingCloudsView` carries the
    canvas's aspect as `artSize` — the only copy of a number this file owns
    that lives anywhere else. It asks rather than assumes, which is the rule
    the sprite and species checkers already live by: if a tool has a value
    another file also has, it is already wrong.

    The asset-name suffix is checked the same way. `check_swift.py` cannot see
    it — the name is assembled by interpolation, not written as a literal — so
    renaming the export here and nowhere else would leave the sky cloudless
    with nothing in the toolchain to notice.
    """
    path = os.path.join(ROOT, "Pawmodoro", "Views", "SceneryView.swift")
    source = open(path).read()

    found = re.search(
        r"static let artSize = CGSize\(width: ([\d.]+), height: ([\d.]+)\)",
        source,
    )
    if not found:
        raise AssertionError(
            "SceneryView.swift: could not find DriftingCloudsView.artSize"
        )
    if (int(float(found.group(1))), int(float(found.group(2)))) != (W, H):
        raise AssertionError(
            f"SceneryView.swift: artSize is {found.group(1)}x{found.group(2)} "
            f"but this canvas is {W}x{H} — the cloud layer would tile at the "
            f"wrong width"
        )

    if 'assetName(for: part))_clouds"' not in source:
        raise AssertionError(
            "SceneryView.swift: DriftingCloudsView no longer builds its asset "
            "name as scene_<place>_<part>_clouds, which is what this exports"
        )

    if 'assetName(for: part))_fg"' not in source:
        raise AssertionError(
            "SceneryView.swift: SceneForegroundView no longer builds its asset "
            "name as scene_<place>_<part>_fg, which is what this exports"
        )

    # The near plane's veil is half the scene's, and that halving *is* the
    # depth: the far world hazes toward the theme's cream and the near world
    # barely does. Equalise the two and the layer stops reading as nearer and
    # starts reading as a band of scenery at the bottom of the screen, which
    # no screenshot would obviously flag.
    found = re.findall(r"static let veil: Double = ([\d.]+)", source)
    if len(found) != 2:
        raise AssertionError(
            "SceneryView.swift: expected two `static let veil` values — the "
            f"scene's and the near plane's — found {len(found)}"
        )
    scene_veil, near_veil = float(found[0]), float(found[1])
    if abs(near_veil * 2 - scene_veil) > 1e-9:
        raise AssertionError(
            f"SceneForegroundView.veil is {near_veil} against the scene's "
            f"{scene_veil}. It has to be half: that difference is the only "
            f"depth cue this layer has."
        )


def to_png(grid, palette, name, scale=UPSCALE):
    height, width = grid.shape
    rgba = np.zeros((height, width, 4), dtype=np.uint8)
    for index, colour in palette.items():
        rgba[grid == index] = colour
    image = Image.fromarray(rgba, mode="RGBA")
    image = image.resize((width * scale, height * scale), Image.NEAREST)

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


# --- Travel vignettes ------------------------------------------------------
#
# The little vehicle whose position across the scene *is* the countdown.
# Drawn on their own small grids and exported untinted: they are tinted at
# runtime so they read against whatever time of day they cross.

def vignette(name, rows, palette):
    height = len(rows)
    width = max(len(r) for r in rows)
    ink = {"#": WALL, "o": ROOF, "=": TRUNK, "w": WINDOW, "s": STONE}
    grid = np.full((height, width), T, dtype=np.uint8)
    for y, row in enumerate(rows):
        for x, cell in enumerate(row):
            if cell in (".", " "):
                continue
            if cell not in ink:
                raise ValueError(f"vignette {name}: unknown cell {cell!r}")
            grid[y, x] = ink[cell]
    to_png(grid, palette, f"vignette_{name}", scale=4)


VIGNETTE_PALETTE = {
    T: (0, 0, 0, 0),
    WALL: (252, 248, 240, 255),
    ROOF: (206, 106, 88, 255),
    TRUNK: (124, 90, 62, 255),
    WINDOW: (255, 214, 128, 255),
    STONE: (94, 96, 112, 255),
}


def sailboat():
    vignette("sailboat", [
        "...#..",
        "..##..",
        ".###..",
        "####..",
        "...#..",
        "======",
        ".====.",
    ], VIGNETTE_PALETTE)


def balloon():
    vignette("balloon", [
        ".ooo.",
        "ooooo",
        "ooooo",
        "ooooo",
        ".ooo.",
        "..=..",
        ".===.",
    ], VIGNETTE_PALETTE)


def train():
    vignette("train", [
        "..s.......",
        ".sss......",
        "ssswsswsss",
        "ssswsswsss",
        "s.s....s.s",
    ], VIGNETTE_PALETTE)


if __name__ == "__main__":
    assert_view_agrees()
    print("Places:")
    for name, draw, overrides in PLACES:
        grid = draw()
        layer = cloud_layer(name)
        near = FOREGROUNDS[name]()
        assert_quiet_band(name, grid)
        assert_drifting_layer(name, grid, layer)
        assert_near_plane(name, near)
        palette = {**BASE, **overrides}
        for part in PARTS:
            to_png(grid, graded(palette, part), f"scene_{name}_{part}")
            to_png(layer, graded(palette, part), f"scene_{name}_{part}_clouds")
            to_png(near, graded(palette, part), f"scene_{name}_{part}_fg")
        clouds = len(SKY_CLOUDS.get(name, ()))
        top = int(np.where((near != T).any(axis=1))[0].min())
        print(f"  {name}: {W * UPSCALE}x{H * UPSCALE} x{len(PARTS)} parts"
              f" (+{clouds} drifting cloud{'' if clouds == 1 else 's'},"
              f" near plane from row {top})")
    print("Vignettes:")
    for maker in (sailboat, balloon, train):
        maker()
        print(f"  {maker.__name__}")
