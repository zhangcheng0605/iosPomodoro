"""Generate pixel-art buddy sprites for Pawmodoro.

Drawn procedurally on a small logical grid (so it is true pixel art), then
upscaled with nearest-neighbour. Output goes into the asset catalog as
single-scale imagesets. Original artwork, nothing to license.

Each buddy has one drawing function per posture, taking an `eyes` mode. Extra
animation frames are derived from those by grid transforms (`squash`, `shift`)
rather than by drawing a second time, so a tweak to a buddy's face reaches
every one of its frames. Frame names are listed in `FRAMES` at the bottom and
must stay in step with `BuddyPose` in Pawmodoro/Animation/BuddyAnimator.swift.
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw

S = 40          # logical canvas, in "pixels" of pixel art
UPSCALE = 10    # exported PNG is S * UPSCALE
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")

# Palette indices used while drawing.
T, OUTLINE, BODY, SHADE, CREAM, PINK, EYE, GLINT, NOSE, ACCENT = range(10)

CAT_PALETTE = {
    T: (0, 0, 0, 0),
    OUTLINE: (92, 58, 34, 255),
    BODY: (232, 160, 92, 255),      # ginger
    SHADE: (206, 130, 66, 255),
    CREAM: (255, 244, 224, 255),
    PINK: (240, 150, 165, 255),
    EYE: (58, 42, 34, 255),
    GLINT: (255, 255, 255, 255),
    NOSE: (216, 122, 138, 255),
    ACCENT: (58, 42, 34, 255),
}

DOG_PALETTE = {
    **CAT_PALETTE,
    BODY: (216, 168, 112, 255),     # tan
    SHADE: (184, 134, 82, 255),
}

# --- Plus buddies -----------------------------------------------------------

BUNNY_PALETTE = {
    **CAT_PALETTE,
    OUTLINE: (110, 84, 96, 255),
    BODY: (250, 240, 240, 255),     # soft white
    SHADE: (226, 208, 214, 255),
    CREAM: (255, 252, 250, 255),
    PINK: (244, 168, 184, 255),
    NOSE: (226, 130, 152, 255),
}

HAMSTER_PALETTE = {
    **CAT_PALETTE,
    OUTLINE: (120, 84, 48, 255),
    BODY: (240, 200, 130, 255),     # golden
    SHADE: (214, 168, 96, 255),
    CREAM: (255, 248, 232, 255),
}

FOX_PALETTE = {
    **CAT_PALETTE,
    OUTLINE: (104, 54, 40, 255),
    BODY: (232, 126, 66, 255),      # deeper orange
    SHADE: (204, 98, 48, 255),
    CREAM: (255, 248, 240, 255),
    ACCENT: (78, 52, 46, 255),      # dark ear tips and paws
}


def new_grid():
    return Image.new("L", (S, S), T)


def outline_silhouette(grid):
    """Add a 1px outline around everything drawn so far.

    Dilation is done on a padded copy: np.roll would wrap, so art near one edge
    would sprout stray outline pixels on the opposite edge.
    """
    arr = np.array(grid)
    solid = np.pad(arr != T, 1)
    neighbours = np.zeros_like(solid)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        shifted = np.roll(np.roll(solid, dy, axis=0), dx, axis=1)
        neighbours |= shifted
    edge = (neighbours & ~solid)[1:-1, 1:-1]
    arr[edge] = OUTLINE
    return Image.fromarray(arr, mode="L")


def to_png(grid, palette, name, template=False):
    arr = np.array(grid)
    rgba = np.zeros((S, S, 4), dtype=np.uint8)
    for index, colour in palette.items():
        rgba[arr == index] = colour
    img = Image.fromarray(rgba, mode="RGBA")
    img = img.resize((S * UPSCALE, S * UPSCALE), Image.NEAREST)

    contents = {
        "images": [{"filename": f"{name}.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }
    if template:
        # Only the alpha matters: the app tints these with the active theme.
        contents["properties"] = {"template-rendering-intent": "template"}

    folder = os.path.join(ASSETS, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, f"{name}.png"), "PNG")
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print(f"  {name}: {S * UPSCALE}x{S * UPSCALE}{' (template)' if template else ''}")


def eyes_open(d, left, right, y):
    for cx in (left, right):
        d.ellipse([cx - 2, y - 2, cx + 2, y + 2], fill=EYE)
        d.point((cx - 1, y - 1), fill=GLINT)


def eyes_closed(d, left, right, y):
    for cx in (left, right):
        d.line([(cx - 2, y), (cx + 2, y)], fill=EYE)
        d.point((cx - 3, y - 1), fill=EYE)
        d.point((cx + 3, y - 1), fill=EYE)


def eyes_happy(d, left, right, y):
    """Closed and arching upward — the ^^ that reads as a smile."""
    for cx in (left, right):
        d.point((cx - 2, y + 1), fill=EYE)
        d.point((cx - 1, y), fill=EYE)
        d.point((cx, y - 1), fill=EYE)
        d.point((cx + 1, y), fill=EYE)
        d.point((cx + 2, y + 1), fill=EYE)


EYE_MODES = {"open": eyes_open, "closed": eyes_closed, "happy": eyes_happy}


def eyes(d, left, right, y, mode="open"):
    EYE_MODES[mode](d, left, right, y)


# --- Frame transforms -------------------------------------------------------
#
# Applied after `outline_silhouette`, so the outline moves with the art.

def squash(grid, row, amount=1):
    """Delete `amount` rows at `row`; everything above slides down to close
    the gap. One row out of forty is a single pixel of pixel art — enough to
    read as a breath without the silhouette wobbling."""
    arr = np.array(grid)
    out = np.full_like(arr, T)
    out[row:] = arr[row:]
    out[amount:row] = arr[0:row - amount]
    return Image.fromarray(out, mode="L")


def shift(grid, dy):
    """Move the whole sprite `dy` rows (negative is up), clipping at the edge."""
    arr = np.array(grid)
    out = np.full_like(arr, T)
    if dy < 0:
        out[:S + dy] = arr[-dy:]
    elif dy > 0:
        out[dy:] = arr[:S - dy]
    else:
        out = arr
    return Image.fromarray(out, mode="L")


def cat_awake(eyes_mode="open"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    # Tail, curling up to the right.
    for i, (x, y) in enumerate([(31, 32), (33, 31), (35, 29), (36, 26), (36, 23)]):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=SHADE if i > 2 else BODY)
    # Sitting body.
    d.ellipse([9, 22, 31, 37], fill=BODY)
    d.ellipse([13, 26, 27, 37], fill=CREAM)          # chest
    # Front paws.
    d.ellipse([12, 32, 18, 37], fill=CREAM)
    d.ellipse([22, 32, 28, 37], fill=CREAM)
    # Ears (drawn before the head so the head overlaps their base).
    d.polygon([(9, 12), (11, 2), (18, 9)], fill=BODY)
    d.polygon([(31, 12), (29, 2), (22, 9)], fill=BODY)
    d.polygon([(12, 10), (12, 5), (16, 9)], fill=PINK)
    d.polygon([(28, 10), (28, 5), (24, 9)], fill=PINK)
    # Head.
    d.ellipse([8, 6, 32, 26], fill=BODY)
    # Stripes on the forehead.
    d.line([(16, 8), (18, 10)], fill=SHADE)
    d.line([(20, 7), (20, 10)], fill=SHADE)
    d.line([(24, 8), (22, 10)], fill=SHADE)
    # Muzzle.
    d.ellipse([13, 17, 27, 25], fill=CREAM)
    eyes(d, 15, 25, 15, eyes_mode)
    d.polygon([(19, 19), (21, 19), (20, 21)], fill=NOSE)
    d.line([(20, 21), (18, 22)], fill=OUTLINE)
    d.line([(20, 21), (22, 22)], fill=OUTLINE)
    # Whiskers.
    for y in (19, 21):
        d.line([(11, y), (14, y + 1)], fill=OUTLINE)
        d.line([(29, y), (26, y + 1)], fill=OUTLINE)
    return outline_silhouette(g)


def cat_asleep(eyes_mode="closed"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    # Curled-up body.
    d.ellipse([6, 20, 34, 36], fill=BODY)
    d.ellipse([12, 26, 30, 36], fill=CREAM)
    # Tail wrapped around the front.
    for x, y in [(30, 32), (26, 35), (21, 36), (16, 35)]:
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=SHADE)
    # Ears first, so the head overlaps their base and they read as ears.
    d.polygon([(7, 20), (8, 9), (15, 18)], fill=BODY)
    d.polygon([(24, 20), (23, 9), (17, 18)], fill=BODY)
    d.polygon([(10, 18), (10, 13), (13, 17)], fill=PINK)
    d.polygon([(21, 18), (21, 13), (18, 17)], fill=PINK)
    # Head resting low on the left.
    d.ellipse([6, 15, 25, 32], fill=BODY)
    # Muzzle sits on the lower half of the head, not on the belly.
    d.ellipse([9, 24, 21, 31], fill=CREAM)
    eyes(d, 12, 19, 22, eyes_mode)
    d.polygon([(14, 26), (16, 26), (15, 28)], fill=NOSE)
    d.line([(15, 28), (13, 29)], fill=OUTLINE)
    d.line([(15, 28), (17, 29)], fill=OUTLINE)
    for y in (26, 28):
        d.line([(6, y), (9, y + 1)], fill=OUTLINE)
    return outline_silhouette(g)


def dog_awake(eyes_mode="open"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    # Wagging tail, kept low and inside the canvas so the ears don't hide it.
    for i, (x, y) in enumerate([(30, 34), (33, 32), (35, 29)]):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=SHADE if i > 1 else BODY)
    # Sitting body.
    d.ellipse([9, 22, 31, 37], fill=BODY)
    d.ellipse([13, 26, 27, 37], fill=CREAM)
    d.ellipse([12, 32, 18, 37], fill=CREAM)
    d.ellipse([22, 32, 28, 37], fill=CREAM)
    # Floppy ears, drawn before the head.
    d.ellipse([4, 8, 13, 24], fill=SHADE)
    d.ellipse([27, 8, 36, 24], fill=SHADE)
    # Head.
    d.ellipse([8, 6, 32, 26], fill=BODY)
    # Patch over one eye.
    d.ellipse([21, 10, 30, 19], fill=SHADE)
    eyes(d, 15, 25, 15, eyes_mode)
    # Snout.
    d.ellipse([13, 18, 27, 26], fill=CREAM)
    d.ellipse([17, 18, 23, 23], fill=EYE)            # big dog nose
    d.line([(20, 23), (20, 25)], fill=OUTLINE)
    d.line([(20, 25), (17, 26)], fill=OUTLINE)
    d.line([(20, 25), (23, 26)], fill=OUTLINE)
    # Tongue.
    d.ellipse([18, 25, 22, 29], fill=PINK)
    return outline_silhouette(g)


def dog_asleep(eyes_mode="closed"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    # Curled-up body.
    d.ellipse([6, 20, 34, 36], fill=BODY)
    d.ellipse([12, 26, 30, 36], fill=CREAM)
    for x, y in [(30, 32), (26, 35), (21, 36)]:
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=SHADE)
    # Ears drape wide enough to stay visible either side of the head.
    d.ellipse([1, 19, 9, 33], fill=SHADE)
    d.ellipse([22, 19, 30, 33], fill=SHADE)
    # Head resting low on the left.
    d.ellipse([6, 15, 25, 32], fill=BODY)
    # Snout with a small button nose.
    d.ellipse([9, 24, 21, 31], fill=CREAM)
    eyes(d, 12, 19, 22, eyes_mode)
    d.ellipse([14, 27, 16, 29], fill=EYE)
    return outline_silhouette(g)


def bunny_awake(eyes_mode="open"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    # Tail puff, behind the body.
    d.ellipse([29, 28, 36, 35], fill=SHADE)
    # Tall ears first so the head overlaps their base.
    d.ellipse([12, 1, 19, 19], fill=BODY)
    d.ellipse([21, 1, 28, 19], fill=BODY)
    d.ellipse([14, 4, 17, 16], fill=PINK)
    d.ellipse([23, 4, 26, 16], fill=PINK)
    # Sitting body.
    d.ellipse([9, 23, 31, 37], fill=BODY)
    d.ellipse([13, 27, 27, 37], fill=CREAM)
    d.ellipse([12, 32, 18, 37], fill=CREAM)
    d.ellipse([22, 32, 28, 37], fill=CREAM)
    # Head and cheeks.
    d.ellipse([9, 13, 31, 31], fill=BODY)
    d.ellipse([12, 21, 28, 30], fill=CREAM)
    eyes(d, 15, 25, 20, eyes_mode)
    d.polygon([(19, 24), (21, 24), (20, 26)], fill=NOSE)
    d.line([(20, 26), (18, 27)], fill=OUTLINE)
    d.line([(20, 26), (22, 27)], fill=OUTLINE)
    return outline_silhouette(g)


def bunny_asleep(eyes_mode="closed"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    # Ears laid back over the shoulder, drawn first so the body overlaps their
    # base and they read as ears rather than a patch on the back.
    d.ellipse([17, 9, 35, 16], fill=BODY)
    d.ellipse([21, 10, 31, 14], fill=PINK)
    d.ellipse([18, 14, 36, 21], fill=SHADE)
    # Curled body.
    d.ellipse([6, 20, 34, 36], fill=BODY)
    d.ellipse([12, 26, 30, 36], fill=CREAM)
    d.ellipse([28, 30, 34, 36], fill=SHADE)      # tail puff
    # Head resting low on the left.
    d.ellipse([6, 16, 24, 32], fill=BODY)
    d.ellipse([9, 24, 21, 31], fill=CREAM)
    eyes(d, 12, 19, 22, eyes_mode)
    d.polygon([(14, 26), (16, 26), (15, 28)], fill=NOSE)
    return outline_silhouette(g)


def hamster_awake(eyes_mode="open"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    # Small round ears behind the head.
    d.ellipse([10, 11, 18, 19], fill=SHADE)
    d.ellipse([22, 11, 30, 19], fill=SHADE)
    # One round body: hamsters have no visible neck.
    d.ellipse([7, 14, 33, 37], fill=BODY)
    # Chubby cheeks and muzzle.
    d.ellipse([8, 21, 20, 33], fill=CREAM)
    d.ellipse([20, 21, 32, 33], fill=CREAM)
    d.ellipse([14, 20, 26, 32], fill=CREAM)
    eyes(d, 14, 26, 21, eyes_mode)
    d.ellipse([19, 24, 21, 26], fill=EYE)
    # Short mouth only: cream paws on cream cheeks left a stray outline artifact.
    d.line([(20, 27), (18, 28)], fill=OUTLINE)
    d.line([(20, 27), (22, 28)], fill=OUTLINE)
    return outline_silhouette(g)


def hamster_asleep(eyes_mode="closed"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.ellipse([7, 10, 17, 20], fill=SHADE)       # ear, drawn first
    d.ellipse([6, 19, 34, 37], fill=BODY)
    d.ellipse([6, 16, 24, 33], fill=BODY)
    d.ellipse([8, 23, 22, 32], fill=CREAM)       # cheek
    eyes(d, 12, 19, 22, eyes_mode)
    d.ellipse([11, 26, 13, 28], fill=EYE)        # nose at the edge of the cheek
    return outline_silhouette(g)


def fox_awake(eyes_mode="open"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    # Bushy tail sweeping up the right, white at the tip.
    for i, (x, y) in enumerate([(30, 34), (33, 31), (35, 27), (35, 23)]):
        r = 3 if i < 2 else 4
        d.ellipse([x - r, y - r, x + r, y + r], fill=CREAM if i == 3 else BODY)
    # Sitting body.
    d.ellipse([9, 22, 31, 37], fill=BODY)
    d.ellipse([13, 26, 27, 37], fill=CREAM)
    d.ellipse([12, 33, 17, 37], fill=ACCENT)     # dark socks
    d.ellipse([23, 33, 28, 37], fill=ACCENT)
    # Big pointed ears with dark tips.
    d.polygon([(9, 14), (10, 1), (19, 11)], fill=BODY)
    d.polygon([(31, 14), (30, 1), (21, 11)], fill=BODY)
    d.polygon([(10, 1), (13, 6), (10, 7)], fill=ACCENT)
    d.polygon([(30, 1), (27, 6), (30, 7)], fill=ACCENT)
    d.polygon([(12, 11), (12, 6), (16, 10)], fill=PINK)
    d.polygon([(28, 11), (28, 6), (24, 10)], fill=PINK)
    # Head with a white muzzle and cheek ruff.
    d.ellipse([8, 7, 32, 27], fill=BODY)
    d.ellipse([12, 16, 28, 26], fill=CREAM)
    eyes(d, 15, 25, 16, eyes_mode)
    d.ellipse([19, 19, 21, 21], fill=ACCENT)
    d.line([(20, 21), (18, 23)], fill=OUTLINE)
    d.line([(20, 21), (22, 23)], fill=OUTLINE)
    return outline_silhouette(g)


def fox_asleep(eyes_mode="closed"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.ellipse([6, 20, 34, 36], fill=BODY)
    d.ellipse([12, 26, 30, 36], fill=CREAM)
    # Tail curled around the front, white tip resting by the nose.
    for i, (x, y) in enumerate([(31, 31), (27, 35), (22, 36), (17, 35)]):
        r = 3
        d.ellipse([x - r, y - r, x + r, y + r], fill=CREAM if i == 3 else BODY)
    # Ears folded back.
    d.polygon([(7, 21), (7, 9), (16, 18)], fill=BODY)
    d.polygon([(24, 21), (23, 9), (17, 17)], fill=BODY)
    d.polygon([(7, 9), (11, 12), (7, 14)], fill=ACCENT)
    d.polygon([(23, 9), (20, 13), (23, 14)], fill=ACCENT)
    d.ellipse([6, 15, 25, 32], fill=BODY)
    d.ellipse([9, 23, 21, 31], fill=CREAM)
    eyes(d, 12, 19, 22, eyes_mode)
    d.ellipse([14, 26, 16, 28], fill=ACCENT)
    return outline_silhouette(g)


def cat_stretch(eyes_mode="happy"):
    """The play-bow: rump up, forelegs reaching forward, head low."""
    g = new_grid()
    d = ImageDraw.Draw(g)
    # Tail straight up off the raised rump.
    for i, (x, y) in enumerate([(32, 24), (34, 20), (35, 15), (35, 10)]):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=SHADE if i > 2 else BODY)
    # Raised hindquarters, right.
    d.ellipse([21, 17, 37, 33], fill=BODY)
    # Back sloping down toward the shoulders.
    d.polygon([(23, 20), (35, 25), (32, 34), (13, 32)], fill=BODY)
    # Shoulders low on the left, forelegs reaching out ahead.
    d.ellipse([9, 25, 25, 37], fill=BODY)
    d.ellipse([2, 32, 20, 37], fill=CREAM)
    d.ellipse([1, 33, 7, 37], fill=CREAM)
    # Head low, between the forelegs.
    d.polygon([(5, 27), (6, 16), (13, 24)], fill=BODY)      # ears
    d.polygon([(20, 27), (19, 16), (14, 24)], fill=BODY)
    d.polygon([(8, 25), (8, 20), (11, 24)], fill=PINK)
    d.polygon([(18, 25), (18, 20), (15, 24)], fill=PINK)
    d.ellipse([4, 21, 21, 34], fill=BODY)
    d.ellipse([6, 27, 18, 33], fill=CREAM)                  # muzzle
    eyes(d, 9, 16, 26, eyes_mode)
    d.polygon([(11, 29), (13, 29), (12, 31)], fill=NOSE)
    return outline_silhouette(g)


def dog_stretch(eyes_mode="happy"):
    """Same bow, with the dog's floppy ears hanging forward."""
    g = new_grid()
    d = ImageDraw.Draw(g)
    for i, (x, y) in enumerate([(32, 25), (34, 21), (35, 17)]):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=SHADE if i > 1 else BODY)
    d.ellipse([21, 17, 37, 33], fill=BODY)
    d.polygon([(23, 20), (35, 25), (32, 34), (13, 32)], fill=BODY)
    d.ellipse([9, 25, 25, 37], fill=BODY)
    d.ellipse([2, 32, 20, 37], fill=CREAM)
    d.ellipse([1, 33, 7, 37], fill=CREAM)
    # Ears hang forward, drawn before the head.
    d.ellipse([2, 21, 9, 34], fill=SHADE)
    d.ellipse([17, 21, 24, 34], fill=SHADE)
    d.ellipse([4, 21, 21, 34], fill=BODY)
    d.ellipse([6, 27, 18, 33], fill=CREAM)
    eyes(d, 9, 16, 26, eyes_mode)
    d.ellipse([10, 29, 14, 32], fill=EYE)                   # button nose
    return outline_silhouette(g)


# --- Effect sprites ---------------------------------------------------------
#
# Drawn as flat silhouettes and exported opaque: the app renders them as
# template images so `Theme` tints them, which keeps them right in all four
# themes and both appearances without a second asset.

FX_PALETTE = {T: (0, 0, 0, 0), OUTLINE: (255, 255, 255, 255)}


def fx_zzz():
    """Three z's climbing to the right, for the napping buddy."""
    g = new_grid()
    d = ImageDraw.Draw(g)
    for (x, y, size) in ((11, 27, 4), (18, 18, 5), (26, 7, 6)):
        d.line([(x, y), (x + size, y)], fill=OUTLINE)
        d.line([(x + size, y), (x, y + size)], fill=OUTLINE)
        d.line([(x, y + size), (x + size, y + size)], fill=OUTLINE)
    return g


def fx_heart():
    """A 7x7 pixel heart, centred."""
    g = new_grid()
    rows = [
        ".XX.XX.",
        "XXXXXXX",
        "XXXXXXX",
        "XXXXXXX",
        ".XXXXX.",
        "..XXX..",
        "...X...",
    ]
    d = ImageDraw.Draw(g)
    for dy, row in enumerate(rows):
        for dx, cell in enumerate(row):
            if cell == "X":
                d.point((17 + dx, 17 + dy), fill=OUTLINE)
    return g


# --- Frame table ------------------------------------------------------------

BUDDIES = [
    ("cat", CAT_PALETTE, cat_awake, cat_asleep, cat_stretch),
    ("dog", DOG_PALETTE, dog_awake, dog_asleep, dog_stretch),
    ("bunny", BUNNY_PALETTE, bunny_awake, bunny_asleep, None),
    ("hamster", HAMSTER_PALETTE, hamster_awake, hamster_asleep, None),
    ("fox", FOX_PALETTE, fox_awake, fox_asleep, None),
]

# Row the breathing squash removes. Both postures are drawn with the body
# filling the lower half, so taking a row out of the mid-body reads as the
# chest falling rather than the whole sprite shrinking.
BREATHE_ROW = 26


def build_frames(species, palette, awake, asleep, stretch):
    """Emit every frame for one buddy. Base names are unchanged from the
    original two-pose set, so nothing that already references them breaks."""
    to_png(awake(), palette, f"buddy_{species}_awake")
    to_png(awake("closed"), palette, f"buddy_{species}_awake_blink")
    to_png(asleep(), palette, f"buddy_{species}_asleep")
    to_png(squash(asleep(), BREATHE_ROW), palette, f"buddy_{species}_asleep_breathe")
    # Eyes open but still curled up: the first moment of waking.
    to_png(asleep("open"), palette, f"buddy_{species}_wake")
    # Two-frame happy bounce, used for petting and for finishing a session.
    happy = awake("happy")
    to_png(happy, palette, f"buddy_{species}_happy_0")
    to_png(shift(happy, -2), palette, f"buddy_{species}_happy_1")
    if stretch is not None:
        to_png(stretch(), palette, f"buddy_{species}_stretch")


if __name__ == "__main__":
    print("Sprites:")
    for species, palette, awake, asleep, stretch in BUDDIES:
        build_frames(species, palette, awake, asleep, stretch)
    print("Effects:")
    to_png(fx_zzz(), FX_PALETTE, "fx_zzz", template=True)
    to_png(fx_heart(), FX_PALETTE, "fx_heart", template=True)
