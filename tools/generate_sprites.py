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

# --- The second cast -------------------------------------------------------

CAPYBARA_PALETTE = {
    **CAT_PALETTE,
    OUTLINE: (86, 62, 44, 255),
    BODY: (168, 126, 88, 255),      # coarse brown
    SHADE: (140, 102, 68, 255),
    CREAM: (214, 184, 148, 255),
    PINK: (176, 206, 212, 255),     # only used as the tub's waterline
    ACCENT: (150, 108, 68, 255),    # the tub itself
    NOSE: (92, 68, 54, 255),
}

REDPANDA_PALETTE = {
    **CAT_PALETTE,
    OUTLINE: (92, 48, 34, 255),
    BODY: (200, 104, 58, 255),      # rust
    SHADE: (168, 80, 44, 255),
    CREAM: (250, 244, 238, 255),    # the white face mask
    ACCENT: (74, 48, 40, 255),      # dark legs and tail rings
    NOSE: (58, 44, 40, 255),
}

PENGUIN_PALETTE = {
    **CAT_PALETTE,
    OUTLINE: (26, 30, 42, 255),
    BODY: (58, 64, 82, 255),        # slate back
    SHADE: (40, 46, 62, 255),
    CREAM: (250, 250, 252, 255),    # belly
    ACCENT: (242, 166, 68, 255),    # beak and feet
    NOSE: (242, 166, 68, 255),
}

OWL_PALETTE = {
    **CAT_PALETTE,
    OUTLINE: (74, 58, 46, 255),
    BODY: (152, 130, 110, 255),     # mottled taupe
    SHADE: (120, 100, 84, 255),
    CREAM: (234, 220, 202, 255),
    ACCENT: (206, 158, 74, 255),    # beak
    NOSE: (206, 158, 74, 255),
}

# --- The second wave -------------------------------------------------------

OTTER_PALETTE = {
    **CAT_PALETTE,
    OUTLINE: (78, 56, 40, 255),
    BODY: (150, 110, 76, 255),      # river brown
    SHADE: (120, 86, 58, 255),
    CREAM: (234, 216, 192, 255),    # muzzle and belly
    ACCENT: (96, 72, 54, 255),      # webbed feet
    NOSE: (72, 54, 46, 255),
    PINK: (176, 206, 212, 255),     # only used as the pebble's wet highlight
}

HEDGEHOG_PALETTE = {
    **CAT_PALETTE,
    OUTLINE: (86, 66, 50, 255),
    BODY: (216, 180, 140, 255),     # the bare face and legs
    SHADE: (126, 100, 76, 255),     # the mass of spines
    CREAM: (240, 218, 190, 255),
    ACCENT: (92, 72, 56, 255),      # spine tips
    NOSE: (58, 46, 42, 255),
}


def otter_awake(eyes_mode="open"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    # Thick tail, laid along the ground rather than curled: an otter's tail is
    # a rudder, and drawing it like a cat's loses the animal.
    for x, y in ((30, 35), (34, 34), (37, 31)):
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=SHADE)
    d.ellipse([10, 20, 30, 38], fill=BODY)
    d.ellipse([14, 26, 26, 38], fill=CREAM)
    d.ellipse([12, 33, 17, 38], fill=ACCENT)         # webbed feet
    d.ellipse([23, 33, 28, 38], fill=ACCENT)
    d.ellipse([9, 9, 15, 15], fill=SHADE)            # small low ears
    d.ellipse([25, 9, 31, 15], fill=SHADE)
    # A broad flat head and a wide muzzle — the two things that stop this
    # reading as another cat.
    d.ellipse([9, 6, 31, 24], fill=BODY)
    d.ellipse([12, 15, 28, 25], fill=CREAM)
    eyes(d, 15, 25, 13, eyes_mode)
    d.ellipse([18, 17, 22, 20], fill=NOSE)
    d.line([(20, 20), (20, 22)], fill=OUTLINE)
    for y in (19, 21):
        d.line([(10, y), (13, y + 1)], fill=OUTLINE)
        d.line([(30, y), (27, y + 1)], fill=OUTLINE)
    return outline_silhouette(g)


def otter_asleep(eyes_mode="closed"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.ellipse([5, 20, 35, 36], fill=BODY)
    d.ellipse([12, 26, 30, 36], fill=CREAM)
    for x, y in ((31, 31), (27, 35), (21, 36), (16, 35)):
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=SHADE)
    d.ellipse([6, 14, 12, 20], fill=SHADE)
    d.ellipse([5, 15, 25, 32], fill=BODY)
    d.ellipse([8, 23, 22, 32], fill=CREAM)
    eyes(d, 12, 19, 22, eyes_mode)
    d.ellipse([13, 26, 17, 29], fill=NOSE)
    return outline_silhouette(g)


def otter_float():
    """The quirk, and the single most otter thing an otter does: on his back,
    both paws holding a pebble on his chest like a treasure.

    No water drawn under him. He is composited over whatever place you're in,
    and a block of blue would fight every scene that isn't the harbour."""
    g = new_grid()
    d = ImageDraw.Draw(g)
    # Lying flat, head to the left, belly up.
    d.ellipse([8, 16, 36, 30], fill=BODY)
    d.ellipse([13, 20, 32, 30], fill=CREAM)
    d.ellipse([31, 12, 37, 19], fill=ACCENT)         # hind feet, out of the water
    d.ellipse([2, 14, 17, 28], fill=BODY)            # head, tipped back
    d.ellipse([4, 18, 15, 27], fill=CREAM)
    eyes(d, 7, 12, 19, "happy")
    d.ellipse([5, 21, 8, 24], fill=NOSE)
    d.line([(2, 20), (5, 21)], fill=OUTLINE)
    # The pebble, and the two paws holding it there.
    d.ellipse([19, 15, 26, 22], fill=SHADE)
    d.point((21, 17), fill=PINK)
    d.ellipse([16, 19, 21, 24], fill=BODY)
    d.ellipse([24, 19, 29, 24], fill=BODY)
    return outline_silhouette(g)


def _spines(d, count, start, end, inner=12, outer=16, cx=20, cy=25):
    """Short strokes radiating off the dome, between two angles in radians."""
    for index in range(count):
        angle = start + (end - start) * index / max(1, count - 1)
        d.line(
            [(cx + np.cos(angle) * inner, cy + np.sin(angle) * inner),
             (cx + np.cos(angle) * outer, cy + np.sin(angle) * outer)],
            fill=ACCENT,
        )


def hedgehog_awake(eyes_mode="open"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.ellipse([5, 12, 35, 38], fill=SHADE)
    _spines(d, 16, np.pi, 2 * np.pi)                 # over the top half only
    # The face pokes out from under the spines, low and central. A hedgehog is
    # mostly nose, and that is the whole read at this size.
    d.ellipse([11, 22, 29, 38], fill=BODY)
    d.ellipse([14, 28, 26, 38], fill=CREAM)
    eyes(d, 16, 24, 28, eyes_mode)
    d.polygon([(18, 32), (22, 32), (20, 36)], fill=NOSE)
    d.ellipse([13, 36, 17, 39], fill=BODY)
    d.ellipse([23, 36, 27, 39], fill=BODY)
    return outline_silhouette(g)


def hedgehog_asleep(eyes_mode="closed"):
    """The quirk, and the reason this animal is in the app: asleep, a hedgehog
    is a perfect ball. No face, no feet, no telling which end is which — the
    best silhouette in the cast.

    The `open` variant is the wake frame, where the ball cracks far enough for
    a face. That transition is worth more than any extra pose would be."""
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.ellipse([7, 12, 33, 38], fill=SHADE)
    _spines(d, 22, 0, 2 * np.pi)                     # all the way round
    if eyes_mode != "closed":
        d.ellipse([12, 24, 26, 38], fill=BODY)
        d.ellipse([15, 29, 24, 38], fill=CREAM)
        eyes(d, 16, 22, 29, eyes_mode)
        d.polygon([(18, 33), (21, 33), (19, 36)], fill=NOSE)
    return outline_silhouette(g)


# --- The stray (Soot) ------------------------------------------------------
#
# The one palette here whose outline is *lighter* than its body. Every other
# buddy is drawn on a light background and outlined dark; Soot spends her first
# two weeks standing in a scene that may be a night sky, and a near-black cat
# outlined in near-black is a hole in the picture rather than an animal. The
# pale rim is what makes her silhouette survive the darkest place in the app —
# tools/check_stray.py measures it rather than trusting this note.

STRAY_PALETTE = {
    **CAT_PALETTE,
    OUTLINE: (128, 136, 156, 255),  # a rim of moonlight, not a dark line
    BODY: (58, 62, 76, 255),        # charcoal with a blue lean
    SHADE: (42, 45, 57, 255),
    CREAM: (176, 182, 196, 255),    # the small pale chest patch
    PINK: (110, 88, 100, 255),      # ear insides, dusty
    EYE: (240, 176, 72, 255),       # amber — the only warm thing about her
    NOSE: (116, 92, 102, 255),
    ACCENT: (240, 176, 72, 255),
}


def new_grid(width=S, height=None):
    """A blank drawing grid. Buddies are square; the stray's stage sprites are
    drawn on grids matched to their own aspect, the way the wildlife generator
    does it, because `scaledToFit` would letterbox a square into a wide frame."""
    return Image.new("L", (width, height or width), T)


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
    height, width = arr.shape
    rgba = np.zeros((height, width, 4), dtype=np.uint8)
    for index, colour in palette.items():
        rgba[arr == index] = colour
    img = Image.fromarray(rgba, mode="RGBA")
    img = img.resize((width * UPSCALE, height * UPSCALE), Image.NEAREST)

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
    print(f"  {name}: {width * UPSCALE}x{height * UPSCALE}"
          f"{' (template)' if template else ''}")


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

# How far sideways the eyes are drawn, in logical pixels.
#
# Set around a call to a buddy's `awake()` to get a glance without redrawing
# the animal: every buddy routes its eyes through `eyes()`, so shifting them
# here shifts them for all twelve. Two pixels is the whole effect — more and
# they leave the face.
EYE_SHIFT = 0


def set_eye_shift(value):
    global EYE_SHIFT
    EYE_SHIFT = value


def eyes(d, left, right, y, mode="open"):
    EYE_MODES[mode](d, left + EYE_SHIFT, right + EYE_SHIFT, y)


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


# --- The stray's stages ----------------------------------------------------
#
# Three small sprites that do the first three-quarters of the trust arc. She is
# never drawn at buddy size until she is close enough to sit beside one, so the
# progression is carried by the art itself rather than by a meter: two points of
# light, then a shape, then a cat.
#
# Sizes here set the aspect the app draws them at — `Stray.Stage.size` in
# Pawmodoro/Model/Stray.swift must match, or `scaledToFit` letterboxes them.


def stray_eyes():
    """Stage one. Not a cat yet: two amber points in the dark of a hedge.

    No outline pass — a pale rim around something whose whole job is to be
    half-hidden would hand the game away on the first day."""
    g = new_grid(20, 10)
    d = ImageDraw.Draw(g)
    d.ellipse([1, 1, 18, 8], fill=SHADE)          # the shadow she is inside
    for cx in (6, 13):
        d.rectangle([cx - 1, 4, cx + 1, 5], fill=EYE)
        d.point((cx, 4), fill=BODY)               # the slit of a pupil
    return g


def stray_distant():
    """Stage two. A shape at the edge of the scene — ears and a tail are the
    whole read at this size, so the face is two amber pixels and nothing else."""
    g = new_grid(26, 23)
    d = ImageDraw.Draw(g)
    for x, y in ((20, 20), (22, 17), (23, 13)):   # tail, held up and still
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=SHADE)
    d.ellipse([6, 10, 20, 22], fill=BODY)         # sitting body
    d.polygon([(7, 8), (8, 2), (12, 7)], fill=BODY)
    d.polygon([(18, 8), (17, 2), (13, 7)], fill=BODY)
    d.ellipse([6, 3, 19, 14], fill=BODY)          # head
    d.point((10, 8), fill=EYE)
    d.point((15, 8), fill=EYE)
    return outline_silhouette(g)


def stray_watch(tail_up=False):
    """Stage three. Close enough to be a cat: ears up, amber eyes, and the pale
    chest patch that tells you she is Soot and not a shadow.

    The two frames differ only in the tail, which is the entire animation — a
    cat that is otherwise holding perfectly still is exactly the point."""
    g = new_grid(44, 40)
    d = ImageDraw.Draw(g)
    tail = ([(34, 31), (38, 26), (40, 20), (39, 14)] if tail_up
            else [(34, 34), (37, 35), (40, 33), (41, 29)])
    for x, y in tail:
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=SHADE)
    d.ellipse([10, 16, 34, 38], fill=BODY)        # sitting body
    d.ellipse([17, 25, 27, 38], fill=CREAM)       # the chest patch
    d.polygon([(11, 12), (13, 1), (20, 9)], fill=BODY)      # ears
    d.polygon([(33, 12), (31, 1), (24, 9)], fill=BODY)
    d.polygon([(14, 10), (14, 5), (18, 9)], fill=PINK)
    d.polygon([(30, 10), (30, 5), (26, 9)], fill=PINK)
    d.ellipse([11, 4, 33, 24], fill=BODY)         # head
    for cx in (17, 27):
        d.ellipse([cx - 2, 11, cx + 2, 15], fill=EYE)
        d.point((cx, 13), fill=BODY)              # the slit
    d.polygon([(21, 17), (23, 17), (22, 19)], fill=NOSE)
    return outline_silhouette(g)


# --- Dreams -----------------------------------------------------------------
#
# The buddy sleeps through every focus session, and sleeping creatures dream.
# Almost every dream is recycled — a species out of the field journal, a
# vignette off the journey — so these six are the only art the diary needs:
# the things that could only happen in a dream.
#
# Drawn small and in sepia to sit beside `wild_*_sketch`, which is what the
# memory dreams use. A dream should look pressed rather than photographed.

DREAM_PALETTE = {
    T: (0, 0, 0, 0),
    OUTLINE: (96, 76, 58, 255),
    BODY: (176, 150, 118, 255),
    SHADE: (138, 114, 88, 255),
    CREAM: (226, 210, 188, 255),
    PINK: (198, 168, 140, 255),
    EYE: (72, 58, 46, 255),
    GLINT: (240, 230, 212, 255),
    NOSE: (120, 98, 76, 255),
    ACCENT: (206, 182, 150, 255),
}

D = 20      # the dream sprites' canvas


def dream_fishballoon():
    """A fish holding the balloon's string. Nobody asked it to."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    d.ellipse([6, 1, 14, 9], fill=BODY)              # the balloon
    d.line([(10, 9), (10, 13)], fill=OUTLINE)        # its string
    d.ellipse([4, 13, 14, 18], fill=SHADE)           # fish
    d.polygon([(14, 13), (18, 11), (17, 18)], fill=SHADE)   # tail
    d.point((7, 15), fill=GLINT)
    return outline_silhouette(g)


def dream_yarn():
    """An enormous ball of yarn. Enormous is the dream part."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    d.ellipse([2, 4, 17, 18], fill=BODY)
    for offset in (-4, 0, 4):
        d.arc([2 + offset, 4, 17 + offset, 18], 200, 340, fill=SHADE)
    d.line([(16, 8), (19, 4)], fill=SHADE)           # the loose end
    return outline_silhouette(g)


def dream_tub():
    """Tofu's tub, out at sea, which is not where a tub goes."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    d.ellipse([6, 3, 13, 9], fill=SHADE)             # a capybara in it
    d.rounded_rectangle([3, 8, 16, 15], radius=2, fill=BODY)
    for x in (7, 12):
        d.line([(x, 9), (x, 14)], fill=SHADE)        # staves
    for y, x0 in ((17, 1), (19, 4)):                 # water
        d.line([(x0, y), (x0 + 12, y)], fill=CREAM)
    return outline_silhouette(g)


def dream_meadow():
    """The meadow, going on rather further than it does awake."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    for index, top in enumerate((6, 10, 14)):
        fill = (BODY, SHADE, CREAM)[index]
        d.ellipse([-8 + index * 5, top, 16 + index * 5, top + 12], fill=fill)
    d.rectangle([0, 17, 19, 19], fill=SHADE)
    return outline_silhouette(g)


def dream_train():
    """The night train, with exactly one window still lit."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    d.rounded_rectangle([1, 7, 18, 14], radius=2, fill=SHADE)
    d.rectangle([13, 5, 17, 8], fill=SHADE)          # the cab
    for x in (3, 7, 11):
        d.rectangle([x, 9, x + 2, 11], fill=OUTLINE)
    d.rectangle([15, 9, 17, 11], fill=GLINT)         # the lit one
    for x in (4, 10, 15):
        d.ellipse([x, 14, x + 3, 17], fill=OUTLINE)
    return outline_silhouette(g)


def dream_moonrabbit():
    """A rabbit-shaped shadow on the moon — dreamed long before it is ever
    seen, which is the point of it being in here."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    d.ellipse([1, 1, 18, 18], fill=CREAM)
    # The rabbit is a hole in the moon, not a thing on top of it. The ears have
    # to stand clear of the head or the whole thing reads as a thumbprint.
    # Seen side-on, ears swept back: upright, the head, body and ears merge
    # into one blob at ten pixels tall and it reads as a thumbprint.
    d.ellipse([7, 9, 15, 16], fill=SHADE)            # haunches
    d.ellipse([4, 8, 10, 14], fill=SHADE)            # head, facing left
    d.line([(9, 8), (13, 3)], fill=SHADE, width=2)   # the long ears
    d.line([(10, 9), (16, 6)], fill=SHADE, width=2)
    return outline_silhouette(g)


# --- Dreams: the backfill ---------------------------------------------------
#
# Five sources fed the dream pool nothing at all: the bond, the regulars, the
# things you can only hear, the seasons, and the stray's later stages. Two of
# them need no art — a regular reuses `wild_*_regular`, which is already a
# sepia sketch with the marking on it, and the stray already has three sprites
# of her own. The other three are drawn here.
#
# The five sounds are drawn as *sounds*, not as their sources. A whale you can
# look at is not what the journal promised; those five are heard and never
# seen, and the rule has to survive the dream. So what is drawn is the thing
# that reached you — the swell, the horn going away, two calls and then
# nothing — never the animal that sent it.
#
# These carry no `outline_silhouette`: a 1px ring around a 2px stroke closes
# the gaps and the whole shape turns into a blot. Solid shapes below still get
# one, the way the surreal six do.


def dream_heard_whalesong():
    """A long way out, and answering something you didn't hear.

    Long wavelength drawn as long wavelength: three widely-spaced fronts
    rolling in from off the left edge, fading as they arrive."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    for radius, fill in ((6, OUTLINE), (11, SHADE), (16, BODY)):
        d.arc([-3 - radius, 12 - radius, -3 + radius, 12 + radius],
              -58, 58, fill=fill, width=2)
    return g


def dream_heard_trainhorn():
    """From somewhere past Starfall, going away.

    Centred off the top-right corner, so the fronts arrive downward and to the
    left — coming from somewhere you are not, which is the whole of it."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    for radius, fill in ((5, OUTLINE), (10, SHADE), (15, BODY)):
        d.arc([19 - radius, 1 - radius, 19 + radius, 1 + radius],
              100, 190, fill=fill, width=2)
    return g


def dream_heard_owlcall():
    """Twice, from the dark side of the wood. Then nothing.

    Two calls and a great deal of empty canvas. The emptiness is the note."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    for cx, cy in ((5, 5), (12, 12)):
        for radius, fill in ((4, OUTLINE), (7, SHADE)):
            d.arc([cx - radius, cy - radius, cx + radius, cy + radius],
                  -55, 55, fill=fill, width=2)
    return g


def dream_heard_farbell():
    """One stroke from the Keep, before anyone is up.

    The only one of the five that spreads in every direction rather than
    arriving from somewhere: closed rings, not arcs."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    d.ellipse([8, 8, 11, 11], fill=OUTLINE)
    d.ellipse([5, 5, 14, 14], outline=SHADE)
    d.ellipse([1, 1, 18, 18], outline=BODY)
    return g


def dream_heard_windchime():
    """Someone's garden, four notes, no wind you can feel.

    Four lengths, four notes. The bar they hang from is what says this is an
    object somebody hung up rather than weather."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    d.line([(3, 3), (16, 3)], fill=SHADE, width=1)
    for x, length in ((4, 9), (8, 14), (12, 7), (16, 12)):
        d.line([(x, 4), (x, 3 + length)], fill=OUTLINE)
        d.ellipse([x - 1, 3 + length, x + 1, 5 + length], fill=SHADE)
    return g


def dream_season_sakura():
    """Blossom season, which is over before you have finished noticing it."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    for dx, dy in ((0, -5), (5, -2), (3, 4), (-3, 4), (-5, -2)):
        d.ellipse([10 + dx - 3, 10 + dy - 3, 10 + dx + 3, 10 + dy + 3], fill=BODY)
    d.ellipse([8, 8, 12, 12], fill=SHADE)
    return outline_silhouette(g)


def dream_season_fireflies():
    """Firefly nights. Drawn as light rather than as insects — at this size a
    firefly is a dot, and a dot is not worth dreaming about."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    for cx, cy in ((5, 6), (13, 9), (8, 15)):
        # Four short dashes standing off the core, not a closed ring: a ring
        # at this size reads as a coin. Single points read as nothing at all,
        # which is what the first attempt did.
        d.ellipse([cx - 1, cy - 1, cx + 1, cy + 1], fill=OUTLINE)
        for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
            d.line([(cx + dx * 3, cy + dy * 3), (cx + dx * 4, cy + dy * 4)],
                   fill=SHADE)
    return g


def dream_season_autumn():
    """Leaf fall. One leaf, because a drift of them at twenty pixels is mud."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    d.polygon([(10, 2), (15, 8), (13, 14), (10, 17), (7, 14), (5, 8)], fill=BODY)
    d.line([(10, 4), (10, 16)], fill=SHADE)
    for y, reach in ((7, 3), (10, 3), (13, 2)):
        d.line([(10, y), (10 - reach, y + 1)], fill=SHADE)
        d.line([(10, y), (10 + reach, y + 1)], fill=SHADE)
    d.line([(10, 16), (10, 19)], fill=SHADE)
    return outline_silhouette(g)


def dream_season_winter():
    """Snow. Six spokes, because a snowflake with any other number is wrong and
    somebody always notices."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    for a, b in (((10, 2), (10, 18)), ((3, 6), (17, 14)), ((3, 14), (17, 6))):
        d.line([a, b], fill=OUTLINE)
    for (x, y), (dx, dy) in (
        ((10, 5), (2, 2)), ((10, 15), (2, -2)),
        ((6, 8), (0, 3)), ((14, 12), (0, -3)),
        ((6, 12), (0, -3)), ((14, 8), (0, 3)),
    ):
        d.line([(x, y), (x - dx, y + dy)], fill=SHADE)
        d.line([(x, y), (x + dx, y + dy)], fill=SHADE)
    return g


def dream_season_lanterns():
    """Lantern days. An ellipse rather than a rounded rectangle on purpose:
    Pillow fills rounded corners differently between versions, and a lantern
    that changes shape when the toolchain updates is not a lantern."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    d.line([(10, 0), (10, 3)], fill=SHADE)
    d.rectangle([8, 3, 12, 4], fill=SHADE)           # the cap it hangs from
    d.ellipse([3, 5, 17, 15], fill=BODY)             # the paper
    for x in (7, 10, 13):
        d.line([(x, 6), (x, 14)], fill=SHADE)        # its ribs
    d.rectangle([8, 15, 12, 16], fill=SHADE)
    d.line([(10, 16), (10, 19)], fill=SHADE)         # the tassel
    return outline_silhouette(g)


def dream_yours_chair():
    """The chair you sit in. The first thing a buddy dreams about that is
    yours rather than the world's — see `Bond.friendly`, whose whole
    description is that it settles the moment you sit down."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    d.rectangle([4, 2, 6, 12], fill=SHADE)           # the back
    d.rectangle([4, 12, 16, 14], fill=BODY)          # the seat
    d.rectangle([4, 14, 6, 18], fill=SHADE)          # back leg
    d.rectangle([14, 14, 16, 18], fill=SHADE)        # front leg
    return outline_silhouette(g)


def dream_yours_doorway():
    """The door, at about the usual time. `Bond.close` is the level where the
    buddy waits by it before you have decided to go anywhere."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    d.rectangle([3, 1, 16, 19], fill=SHADE)          # the frame
    d.rectangle([5, 3, 14, 19], fill=CREAM)          # the light behind it
    d.polygon([(5, 3), (11, 5), (11, 19), (5, 19)], fill=BODY)   # the door, ajar
    d.point((12, 12), fill=OUTLINE)                  # the handle
    return outline_silhouette(g)


def dream_yours_desk():
    """The desk, and your mug going cold on it. `Bond.devoted` is where the
    buddy has picked a side of it."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    d.rectangle([1, 11, 18, 13], fill=BODY)          # the top
    d.rectangle([2, 13, 4, 18], fill=SHADE)          # legs
    d.rectangle([15, 13, 17, 18], fill=SHADE)
    # The mug is drawn a tone darker than the desk and given its own line
    # where the two meet: `outline_silhouette` only rings the outside of
    # everything drawn, so same-coloured shapes that touch merge into one
    # lump — which is exactly what the first version of this was.
    d.rectangle([7, 5, 11, 11], fill=SHADE)
    d.line([(7, 5), (11, 5)], fill=CREAM)            # the rim, so it reads open
    d.line([(12, 7), (13, 7)], fill=SHADE)           # its handle
    d.line([(13, 7), (13, 9)], fill=SHADE)
    d.line([(12, 9), (13, 9)], fill=SHADE)
    d.line([(6, 11), (12, 11)], fill=OUTLINE)
    return outline_silhouette(g)


def dream_sky_puddle():
    """What the rain leaves behind, and the best thing about rain.

    Two goes at the splash before this one: concentric ripples in the water
    read as beans (a closed shape inside a shape of the same tone has no edge
    to be seen by), and ticks flicking up out of it read as antennae. One dark
    ring on the *bright* middle has the tone contrast to be a ripple."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    d.ellipse([1, 12, 18, 18], fill=BODY)            # the puddle, seen flat
    d.ellipse([4, 13, 15, 17], fill=CREAM)           # what it is reflecting
    d.ellipse([8, 14, 12, 16], outline=SHADE)        # where one just landed
    d.line([(10, 3), (10, 9)], fill=SHADE)           # and the next one coming
    return outline_silhouette(g)


def dream_sky_thunder():
    """Further off each time, which is how a storm says goodnight.

    The bolt hangs clear of the cloud by a pixel on purpose:
    `outline_silhouette` rings the *union* of everything drawn, so a bolt
    touching the cloud gets no line between them and the pair reads as one
    lumpy bag. The gap buys it its own outline."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    for box in ([1, 3, 9, 9], [6, 1, 15, 8], [11, 4, 18, 9]):
        d.ellipse(box, fill=SHADE)                   # three lobes and
    d.rectangle([2, 6, 17, 9], fill=SHADE)           # a flat underside
    d.polygon([(11, 11), (7, 16), (10, 16), (8, 19), (14, 14), (11, 14)],
              fill=BODY)
    return outline_silhouette(g)


def dream_sky_afterglow():
    """The day after a storm: washed clean, and lit from the side.

    Drawn as the same cloud `dream_sky_thunder` has, leaving — which is what
    golden weather actually is, and makes the pair read as one story told a
    day apart. Rays were tried first and stair-stepped into a solid hatched
    mass; light drawn as light needs somewhere dark to come out from."""
    g = new_grid(D, D)
    d = ImageDraw.Draw(g)
    d.ellipse([11, 1, 19, 9], fill=CREAM)            # the sun, mostly behind
    for box in ([1, 6, 9, 13], [5, 4, 14, 12], [10, 7, 17, 13]):
        d.ellipse(box, fill=SHADE)                   # the last of the cloud
    d.rectangle([2, 9, 16, 13], fill=SHADE)
    d.rectangle([0, 17, 19, 19], fill=BODY)          # the ground, lit again
    return outline_silhouette(g)


def fx_bubble(shift=0):
    """The thought bubble the dream sits inside.

    A flat silhouette, exported as a template: the app draws it twice — once
    slightly larger in `Theme.bark` for a rim, once in `Theme.cream` for the
    fill — so one asset gives a two-tone bubble that follows every theme. The
    two frames differ only in the trailing bubbles, which is the shimmer.
    """
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.ellipse([4, 2, 36, 26], fill=OUTLINE)
    d.ellipse([9, 27 + shift, 15, 33 + shift], fill=OUTLINE)
    d.ellipse([4, 34 - shift, 8, 38 - shift], fill=OUTLINE)
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

# --- Capybara (Tofu) -------------------------------------------------------
#
# The shape note: a capybara is a brick with a blunt muzzle. Keeping the head
# nearly rectangular is what stops it reading as a very large hamster.

def capybara_awake(eyes_mode="open"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    # Small round ears, high and wide apart.
    d.ellipse([10, 6, 16, 12], fill=SHADE)
    d.ellipse([24, 6, 30, 12], fill=SHADE)
    # Loaf body.
    d.ellipse([6, 21, 34, 37], fill=BODY)
    d.ellipse([12, 27, 28, 37], fill=CREAM)
    # Blocky head.
    d.rounded_rectangle([8, 8, 32, 27], radius=6, fill=BODY)
    # Blunt muzzle across the whole lower face.
    d.rounded_rectangle([11, 18, 29, 28], radius=5, fill=CREAM)
    eyes(d, 14, 26, 15, eyes_mode)
    d.rounded_rectangle([17, 21, 23, 25], radius=2, fill=NOSE)
    d.line([(20, 25), (20, 27)], fill=OUTLINE)
    return outline_silhouette(g)


def capybara_asleep(eyes_mode="closed"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.ellipse([5, 21, 35, 36], fill=BODY)
    d.ellipse([12, 27, 30, 36], fill=CREAM)
    d.ellipse([7, 15, 13, 21], fill=SHADE)          # ear
    d.rounded_rectangle([5, 16, 24, 32], radius=6, fill=BODY)
    d.rounded_rectangle([7, 23, 22, 32], radius=5, fill=CREAM)
    eyes(d, 12, 19, 22, eyes_mode)
    d.rounded_rectangle([11, 26, 16, 29], radius=2, fill=NOSE)
    return outline_silhouette(g)


def capybara_soak():
    """The quirk: a capybara in a wooden tub, which is the whole reason this
    animal is in the app."""
    g = new_grid()
    d = ImageDraw.Draw(g)
    # Steam, in white so it reads against the sky rather than against the fur.
    for x0, y0 in ((9, 4), (20, 1), (31, 4)):
        for i in range(4):
            d.point((x0 + (i % 2), y0 + i * 2), fill=GLINT)
    # Head and shoulders, kept well clear of the rim.
    d.ellipse([11, 11, 16, 16], fill=SHADE)
    d.ellipse([24, 11, 29, 16], fill=SHADE)
    d.rounded_rectangle([10, 12, 30, 28], radius=6, fill=BODY)
    d.rounded_rectangle([13, 19, 27, 29], radius=5, fill=CREAM)
    eyes(d, 15, 25, 17, "happy")
    d.rounded_rectangle([18, 22, 23, 26], radius=2, fill=NOSE)
    # The tub: water first, then a plain rim over it. Three staves, not seven —
    # the first attempt read as a barcode.
    d.rectangle([5, 28, 35, 32], fill=PINK)
    d.rounded_rectangle([4, 31, 36, 38], radius=3, fill=ACCENT)
    for x in (13, 20, 27):
        d.line([(x, 32), (x, 37)], fill=SHADE)
    return outline_silhouette(g)


# --- Red panda (Maple) -----------------------------------------------------

def redpanda_awake(eyes_mode="open"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    # Ringed tail, curling up the right.
    for i, (x, y) in enumerate([(30, 33), (33, 30), (35, 26), (35, 21)]):
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=ACCENT if i % 2 else BODY)
    d.ellipse([9, 22, 31, 37], fill=BODY)
    d.ellipse([13, 26, 27, 37], fill=CREAM)
    d.ellipse([11, 32, 17, 37], fill=ACCENT)         # dark legs
    d.ellipse([23, 32, 29, 37], fill=ACCENT)
    # Big round ears with white insides.
    d.ellipse([6, 5, 16, 15], fill=BODY)
    d.ellipse([24, 5, 34, 15], fill=BODY)
    d.ellipse([8, 7, 14, 13], fill=CREAM)
    d.ellipse([26, 7, 32, 13], fill=CREAM)
    d.ellipse([8, 7, 32, 27], fill=BODY)
    # The mask: white cheeks and brows, which is the whole face.
    d.ellipse([10, 15, 20, 25], fill=CREAM)
    d.ellipse([20, 15, 30, 25], fill=CREAM)
    d.ellipse([14, 10, 20, 15], fill=CREAM)
    d.ellipse([20, 10, 26, 15], fill=CREAM)
    eyes(d, 15, 25, 17, eyes_mode)
    d.polygon([(19, 20), (21, 20), (20, 22)], fill=NOSE)
    return outline_silhouette(g)


def redpanda_asleep(eyes_mode="closed"):
    """Asleep hugging its own tail — the silhouette that tells you which
    buddy this is with the screen at arm's length."""
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.ellipse([6, 21, 34, 36], fill=BODY)
    # The tail comes right around the front as a pillow.
    for i, (x, y) in enumerate([(31, 28), (27, 33), (21, 35), (15, 34), (10, 30)]):
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=ACCENT if i % 2 else SHADE)
    d.ellipse([5, 13, 13, 21], fill=BODY)            # ears
    d.ellipse([19, 13, 27, 21], fill=BODY)
    d.ellipse([7, 15, 11, 19], fill=CREAM)
    d.ellipse([21, 15, 25, 19], fill=CREAM)
    d.ellipse([5, 15, 26, 32], fill=BODY)
    d.ellipse([7, 22, 16, 31], fill=CREAM)
    d.ellipse([16, 22, 25, 31], fill=CREAM)
    eyes(d, 12, 20, 23, eyes_mode)
    d.polygon([(15, 26), (17, 26), (16, 28)], fill=NOSE)
    return outline_silhouette(g)


def redpanda_armsup():
    """Petted: both arms straight up. Red pandas do this when startled; here
    it is played as delight, which is the only honest reading in this app."""
    g = new_grid()
    d = ImageDraw.Draw(g)
    for i, (x, y) in enumerate([(31, 34), (34, 31), (36, 27)]):
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=ACCENT if i % 2 else BODY)
    d.ellipse([11, 25, 29, 38], fill=BODY)
    d.ellipse([14, 29, 26, 38], fill=CREAM)
    # Arms drawn as strokes from the shoulders, angled outward, with dark paws
    # on top. Drawn as blocks the first time, they read as two floating bricks.
    d.line([(13, 27), (7, 15)], fill=BODY, width=4)
    d.line([(27, 27), (33, 15)], fill=BODY, width=4)
    d.ellipse([3, 10, 10, 17], fill=ACCENT)
    d.ellipse([30, 10, 37, 17], fill=ACCENT)
    d.ellipse([8, 8, 17, 17], fill=BODY)             # ears
    d.ellipse([23, 8, 32, 17], fill=BODY)
    d.ellipse([10, 10, 15, 15], fill=CREAM)
    d.ellipse([25, 10, 30, 15], fill=CREAM)
    d.ellipse([10, 10, 30, 29], fill=BODY)
    d.ellipse([12, 18, 21, 28], fill=CREAM)
    d.ellipse([19, 18, 28, 28], fill=CREAM)
    d.ellipse([15, 13, 20, 18], fill=CREAM)
    d.ellipse([20, 13, 25, 18], fill=CREAM)
    eyes(d, 16, 24, 20, "happy")
    d.polygon([(19, 23), (21, 23), (20, 25)], fill=NOSE)
    return outline_silhouette(g)


def redpanda_curl():
    """Home turf: curled on its side, tail over the nose."""
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.ellipse([5, 22, 35, 37], fill=BODY)
    for i, (x, y) in enumerate([(32, 30), (28, 34), (22, 36), (16, 36), (11, 33)]):
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=ACCENT if i % 2 else SHADE)
    d.ellipse([6, 17, 13, 24], fill=BODY)
    d.ellipse([18, 17, 25, 24], fill=BODY)
    d.ellipse([6, 19, 27, 34], fill=BODY)
    d.ellipse([8, 25, 16, 33], fill=CREAM)
    d.ellipse([15, 25, 23, 33], fill=CREAM)
    eyes(d, 12, 19, 26, "closed")
    return outline_silhouette(g)


# --- Penguin (Pebble) ------------------------------------------------------

def penguin_awake(eyes_mode="open"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.ellipse([16, 36, 24, 39], fill=ACCENT)         # feet, drawn first
    d.ellipse([10, 34, 18, 39], fill=ACCENT)
    d.ellipse([22, 34, 30, 39], fill=ACCENT)
    # One upright body — a penguin has no visible neck either.
    d.ellipse([9, 6, 31, 37], fill=BODY)
    d.ellipse([13, 16, 27, 36], fill=CREAM)          # belly
    d.ellipse([12, 9, 28, 22], fill=CREAM)           # face patch
    d.ellipse([5, 17, 11, 32], fill=SHADE)           # flippers
    d.ellipse([29, 17, 35, 32], fill=SHADE)
    eyes(d, 16, 24, 15, eyes_mode)
    d.polygon([(18, 18), (22, 18), (20, 22)], fill=ACCENT)
    return outline_silhouette(g)


def penguin_asleep(eyes_mode="closed"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.ellipse([6, 20, 34, 37], fill=BODY)
    d.ellipse([12, 26, 30, 37], fill=CREAM)
    d.ellipse([26, 24, 34, 33], fill=SHADE)          # flipper over the back
    d.ellipse([5, 15, 25, 32], fill=BODY)
    d.ellipse([7, 19, 22, 31], fill=CREAM)
    eyes(d, 12, 19, 22, eyes_mode)
    d.polygon([(12, 25), (16, 25), (14, 29)], fill=ACCENT)
    return outline_silhouette(g)


def penguin_waddle():
    """The idle quirk: weight shifted, one flipper out. Alternated with the
    plain standing pose it reads as a shuffle on the spot."""
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.ellipse([13, 35, 21, 39], fill=ACCENT)
    d.ellipse([23, 36, 31, 39], fill=ACCENT)
    d.ellipse([11, 7, 33, 37], fill=BODY)
    d.ellipse([15, 17, 29, 36], fill=CREAM)
    d.ellipse([14, 10, 30, 23], fill=CREAM)
    d.ellipse([4, 14, 12, 28], fill=SHADE)           # the raised flipper
    d.ellipse([31, 19, 37, 33], fill=SHADE)
    eyes(d, 18, 26, 16, "open")
    d.polygon([(20, 19), (24, 19), (22, 23)], fill=ACCENT)
    return outline_silhouette(g)


def penguin_slide():
    """Happy, and the home-turf pose: belly down, flippers back."""
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.ellipse([4, 22, 36, 34], fill=BODY)
    d.ellipse([10, 26, 32, 34], fill=CREAM)
    d.ellipse([28, 18, 38, 26], fill=SHADE)          # flippers swept back
    d.ellipse([26, 28, 36, 35], fill=SHADE)
    d.ellipse([4, 18, 20, 32], fill=BODY)            # head out front
    d.ellipse([6, 21, 18, 31], fill=CREAM)
    eyes(d, 10, 16, 22, "happy")
    d.polygon([(4, 25), (9, 25), (6, 29)], fill=ACCENT)
    return outline_silhouette(g)


# --- Owl (Luna) ------------------------------------------------------------

def owl_eyes(d, left, right, y, mode):
    """Owls are mostly eyes, so they get their own routine: a pale facial disc
    under a much larger pupil than the `eyes` helper draws."""
    left, right = left + EYE_SHIFT, right + EYE_SHIFT
    for cx in (left, right):
        d.ellipse([cx - 5, y - 5, cx + 5, y + 5], fill=CREAM)
    if mode == "open":
        for cx in (left, right):
            d.ellipse([cx - 3, y - 3, cx + 3, y + 3], fill=EYE)
            d.ellipse([cx - 2, y - 2, cx, y], fill=GLINT)
    elif mode == "closed":
        for cx in (left, right):
            d.line([(cx - 3, y), (cx + 3, y)], fill=EYE)
    else:                                            # happy
        for cx in (left, right):
            for dx in range(-3, 4):
                d.point((cx + dx, y + abs(dx) // 2 - 1), fill=EYE)


def owl_awake(eyes_mode="open"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.polygon([(8, 12), (11, 2), (17, 11)], fill=BODY)     # ear tufts
    d.polygon([(32, 12), (29, 2), (23, 11)], fill=BODY)
    d.ellipse([7, 8, 33, 37], fill=BODY)                   # one round body
    d.ellipse([13, 24, 27, 37], fill=CREAM)                # speckled chest
    for x, y in ((16, 27), (23, 29), (19, 32), (14, 31), (25, 33)):
        d.point((x, y), fill=SHADE)
    d.ellipse([5, 20, 11, 33], fill=SHADE)                 # wings
    d.ellipse([29, 20, 35, 33], fill=SHADE)
    owl_eyes(d, 14, 26, 17, eyes_mode)
    d.polygon([(19, 21), (21, 21), (20, 25)], fill=ACCENT)
    d.ellipse([14, 36, 19, 39], fill=ACCENT)               # talons
    d.ellipse([21, 36, 26, 39], fill=ACCENT)
    return outline_silhouette(g)


def owl_asleep(eyes_mode="closed"):
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.polygon([(7, 18), (9, 9), (14, 17)], fill=BODY)
    d.polygon([(26, 18), (24, 9), (19, 17)], fill=BODY)
    d.ellipse([6, 20, 34, 37], fill=BODY)
    d.ellipse([13, 26, 29, 37], fill=CREAM)
    d.ellipse([5, 14, 27, 34], fill=BODY)
    d.ellipse([26, 22, 34, 32], fill=SHADE)                # wing tucked over
    owl_eyes(d, 12, 21, 24, eyes_mode)
    d.polygon([(15, 27), (17, 27), (16, 30)], fill=ACCENT)
    return outline_silhouette(g)


def owl_watch():
    """The nocturnal quirk: after dark Luna is awake through your focus, eyes
    wide, tufts up. The one buddy that inverts the app's fiction."""
    g = new_grid()
    d = ImageDraw.Draw(g)
    d.polygon([(7, 13), (10, 1), (17, 12)], fill=BODY)
    d.polygon([(33, 13), (30, 1), (23, 12)], fill=BODY)
    d.ellipse([6, 9, 34, 37], fill=BODY)
    d.ellipse([13, 25, 27, 37], fill=CREAM)
    for x, y in ((16, 28), (23, 30), (19, 33), (14, 32)):
        d.point((x, y), fill=SHADE)
    d.ellipse([4, 20, 10, 34], fill=SHADE)
    d.ellipse([30, 20, 36, 34], fill=SHADE)
    # Wider discs and bigger pupils than the resting pose: alert, not just awake.
    for cx in (14, 26):
        d.ellipse([cx - 6, 11, cx + 6, 23], fill=CREAM)
        d.ellipse([cx - 4, 13, cx + 4, 21], fill=EYE)
        d.ellipse([cx - 3, 14, cx - 1, 16], fill=GLINT)
    d.polygon([(19, 22), (21, 22), (20, 26)], fill=ACCENT)
    d.ellipse([14, 36, 19, 39], fill=ACCENT)
    d.ellipse([21, 36, 26, 39], fill=ACCENT)
    return outline_silhouette(g)


# Each entry: species, palette, awake, asleep, stretch (or None), and any
# extra hand-drawn quirk poses keyed by the suffix they're emitted under.
BUDDIES = [
    ("cat", CAT_PALETTE, cat_awake, cat_asleep, cat_stretch, {}),
    ("dog", DOG_PALETTE, dog_awake, dog_asleep, dog_stretch, {}),
    ("bunny", BUNNY_PALETTE, bunny_awake, bunny_asleep, None, {}),
    ("hamster", HAMSTER_PALETTE, hamster_awake, hamster_asleep, None, {}),
    ("fox", FOX_PALETTE, fox_awake, fox_asleep, None, {}),
    ("capybara", CAPYBARA_PALETTE, capybara_awake, capybara_asleep, None,
     {"soak": capybara_soak}),
    ("redpanda", REDPANDA_PALETTE, redpanda_awake, redpanda_asleep, None,
     {"armsup": redpanda_armsup, "curl": redpanda_curl}),
    ("penguin", PENGUIN_PALETTE, penguin_awake, penguin_asleep, None,
     {"waddle": penguin_waddle, "slide": penguin_slide}),
    ("owl", OWL_PALETTE, owl_awake, owl_asleep, None,
     {"watch": owl_watch}),
    ("otter", OTTER_PALETTE, otter_awake, otter_asleep, None,
     {"float": otter_float}),
    # Bramble gets no extra pose on purpose: his asleep frame *is* the quirk.
    ("hedgehog", HEDGEHOG_PALETTE, hedgehog_awake, hedgehog_asleep, None, {}),
    # Soot is a cat, so she is the cat's drawings in her own palette rather
    # than a tenth animal — which is also why she inherits the stretch.
    ("stray", STRAY_PALETTE, cat_awake, cat_asleep, cat_stretch, {}),
]

# Row the breathing squash removes. Both postures are drawn with the body
# filling the lower half, so taking a row out of the mid-body reads as the
# chest falling rather than the whole sprite shrinking.
BREATHE_ROW = 26


def build_frames(species, palette, awake, asleep, stretch, quirks=None):
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
    # Two glances, for the eyes that follow a finger. A grid transform can't
    # do this — the pupils are drawn, not overlaid — but shifting the shared
    # `eyes()` helper reaches every buddy for free.
    # `dx`, not `shift` — that name is a module-level function two lines above,
    # and rebinding it here makes it local for the whole body, which breaks the
    # happy frame with an UnboundLocalError.
    for suffix, dx in (("look_l", -2), ("look_r", 2)):
        set_eye_shift(dx)
        to_png(awake(), palette, f"buddy_{species}_{suffix}")
    set_eye_shift(0)
    if stretch is not None:
        to_png(stretch(), palette, f"buddy_{species}_stretch")
    # Signature poses: the soak, the raised arms, the waddle, the watch.
    for suffix, draw in (quirks or {}).items():
        to_png(draw(), palette, f"buddy_{species}_{suffix}")


if __name__ == "__main__":
    print("Sprites:")
    for species, palette, awake, asleep, stretch, quirks in BUDDIES:
        build_frames(species, palette, awake, asleep, stretch, quirks)
    print("The stray:")
    to_png(stray_eyes(), STRAY_PALETTE, "stray_eyes")
    to_png(stray_distant(), STRAY_PALETTE, "stray_distant")
    to_png(stray_watch(), STRAY_PALETTE, "stray_watch_0")
    to_png(stray_watch(tail_up=True), STRAY_PALETTE, "stray_watch_1")
    print("Dreams:")
    for name, draw in (
        ("fishballoon", dream_fishballoon), ("yarn", dream_yarn),
        ("tub", dream_tub), ("meadow", dream_meadow),
        ("train", dream_train), ("moonrabbit", dream_moonrabbit),
        # The backfill. Names are `dream_<group>_<case>` and the group matches
        # the enum the case comes from, which is what lets check_swift.py
        # expand `"dream_heard_\(sound.rawValue)"` and tell you a sprite is
        # missing rather than leaving a blank bubble to find in the simulator.
        ("heard_whalesong", dream_heard_whalesong),
        ("heard_trainhorn", dream_heard_trainhorn),
        ("heard_owlcall", dream_heard_owlcall),
        ("heard_farbell", dream_heard_farbell),
        ("heard_windchime", dream_heard_windchime),
        ("season_sakura", dream_season_sakura),
        ("season_fireflies", dream_season_fireflies),
        ("season_autumn", dream_season_autumn),
        ("season_winter", dream_season_winter),
        ("season_lanterns", dream_season_lanterns),
        ("yours_chair", dream_yours_chair),
        ("yours_doorway", dream_yours_doorway),
        ("yours_desk", dream_yours_desk),
        ("sky_puddle", dream_sky_puddle),
        ("sky_thunder", dream_sky_thunder),
        ("sky_afterglow", dream_sky_afterglow),
    ):
        to_png(draw(), DREAM_PALETTE, f"dream_{name}")
    print("Effects:")
    to_png(fx_zzz(), FX_PALETTE, "fx_zzz", template=True)
    to_png(fx_heart(), FX_PALETTE, "fx_heart", template=True)
    to_png(fx_bubble(), FX_PALETTE, "fx_bubble_0", template=True)
    to_png(fx_bubble(shift=1), FX_PALETTE, "fx_bubble_1", template=True)
