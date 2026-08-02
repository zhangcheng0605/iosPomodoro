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


def cloud(grid, cx, cy, scale, rng):
    """A few overlapping lozenges with a shaded underside."""
    puffs = [(0, 0, 1.0), (-scale, 1, 0.72), (scale, 1, 0.66),
             (-scale // 2, -1, 0.6), (scale // 2, -1, 0.55)]
    for dx, dy, factor in puffs:
        rx = max(2, int(scale * factor))
        ry = max(1, int(scale * factor * 0.45))
        for y in range(cy + dy - ry, cy + dy + ry + 1):
            for x in range(cx + dx - rx, cx + dx + rx + 1):
                if not (0 <= x < W and 0 <= y < H):
                    continue
                nx = (x - (cx + dx)) / rx
                ny = (y - (cy + dy)) / ry
                if nx * nx + ny * ny <= 1.0:
                    grid[y, x] = CLOUD_SH if y > cy + dy + ry - 2 else CLOUD
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


# --- The places ------------------------------------------------------------

def meadow():
    """Home. Rolling hills, one crooked cottage, a fence, wildflowers."""
    g = new_scene()
    rng = Rng(11)
    sky_gradient(g, 186)
    cloud(g, 34, 26, 9, rng)
    cloud(g, 96, 40, 7, rng)
    cloud(g, 66, 14, 5, rng)
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
    cloud(g, 24, 20, 6, rng)
    cloud(g, 104, 30, 8, rng)
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
    cloud(g, 88, 34, 12, rng)
    cloud(g, 30, 22, 8, rng)
    cloud(g, 112, 16, 6, rng)
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
    cloud(g, 40, 28, 9, rng)
    cloud(g, 100, 20, 7, rng)
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
    cloud(g, 26, 24, 7, rng)
    cloud(g, 108, 34, 9, rng)
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
    cloud(g, 30, 30, 10, rng)
    cloud(g, 104, 22, 8, rng)
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
    cloud(g, 96, 26, 7, rng)
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
    cloud(g, 34, 24, 7, rng)
    cloud(g, 100, 32, 9, rng)
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
    print("Places:")
    for name, draw, overrides in PLACES:
        grid = draw()
        assert_quiet_band(name, grid)
        palette = {**BASE, **overrides}
        for part in PARTS:
            to_png(grid, graded(palette, part), f"scene_{name}_{part}")
        print(f"  {name}: {W * UPSCALE}x{H * UPSCALE} x{len(PARTS)} parts")
    print("Vignettes:")
    for maker in (sailboat, balloon, train):
        maker()
        print(f"  {maker.__name__}")
