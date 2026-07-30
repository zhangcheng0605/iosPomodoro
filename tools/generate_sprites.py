"""Generate pixel-art buddy sprites for Pawmodoro.

Drawn procedurally on a small logical grid (so it is true pixel art), then
upscaled with nearest-neighbour. Output goes into the asset catalog as
single-scale imagesets. Original artwork, nothing to license.
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw

S = 40          # logical canvas, in "pixels" of pixel art
UPSCALE = 10    # exported PNG is S * UPSCALE
ASSETS = "/home/user/iosPomodoro/Pawmodoro/Assets.xcassets"

# Palette indices used while drawing.
T, OUTLINE, BODY, SHADE, CREAM, PINK, EYE, GLINT, NOSE = range(9)

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
}

DOG_PALETTE = {
    **CAT_PALETTE,
    BODY: (216, 168, 112, 255),     # tan
    SHADE: (184, 134, 82, 255),
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


def to_png(grid, palette, name):
    arr = np.array(grid)
    rgba = np.zeros((S, S, 4), dtype=np.uint8)
    for index, colour in palette.items():
        rgba[arr == index] = colour
    img = Image.fromarray(rgba, mode="RGBA")
    img = img.resize((S * UPSCALE, S * UPSCALE), Image.NEAREST)

    folder = os.path.join(ASSETS, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, f"{name}.png"), "PNG")
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump(
            {
                "images": [{"filename": f"{name}.png", "idiom": "universal"}],
                "info": {"author": "xcode", "version": 1},
            },
            f,
            indent=2,
        )
    print(f"  {name}: {S * UPSCALE}x{S * UPSCALE}")


def eyes_open(d, left, right, y):
    for cx in (left, right):
        d.ellipse([cx - 2, y - 2, cx + 2, y + 2], fill=EYE)
        d.point((cx - 1, y - 1), fill=GLINT)


def eyes_closed(d, left, right, y):
    for cx in (left, right):
        d.line([(cx - 2, y), (cx + 2, y)], fill=EYE)
        d.point((cx - 3, y - 1), fill=EYE)
        d.point((cx + 3, y - 1), fill=EYE)


def cat_awake():
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
    eyes_open(d, 15, 25, 15)
    d.polygon([(19, 19), (21, 19), (20, 21)], fill=NOSE)
    d.line([(20, 21), (18, 22)], fill=OUTLINE)
    d.line([(20, 21), (22, 22)], fill=OUTLINE)
    # Whiskers.
    for y in (19, 21):
        d.line([(11, y), (14, y + 1)], fill=OUTLINE)
        d.line([(29, y), (26, y + 1)], fill=OUTLINE)
    return outline_silhouette(g)


def cat_asleep():
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
    eyes_closed(d, 12, 19, 22)
    d.polygon([(14, 26), (16, 26), (15, 28)], fill=NOSE)
    d.line([(15, 28), (13, 29)], fill=OUTLINE)
    d.line([(15, 28), (17, 29)], fill=OUTLINE)
    for y in (26, 28):
        d.line([(6, y), (9, y + 1)], fill=OUTLINE)
    return outline_silhouette(g)


def dog_awake():
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
    eyes_open(d, 15, 25, 15)
    # Snout.
    d.ellipse([13, 18, 27, 26], fill=CREAM)
    d.ellipse([17, 18, 23, 23], fill=EYE)            # big dog nose
    d.line([(20, 23), (20, 25)], fill=OUTLINE)
    d.line([(20, 25), (17, 26)], fill=OUTLINE)
    d.line([(20, 25), (23, 26)], fill=OUTLINE)
    # Tongue.
    d.ellipse([18, 25, 22, 29], fill=PINK)
    return outline_silhouette(g)


def dog_asleep():
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
    eyes_closed(d, 12, 19, 22)
    d.ellipse([14, 27, 16, 29], fill=EYE)
    return outline_silhouette(g)


if __name__ == "__main__":
    print("Sprites:")
    to_png(cat_awake(), CAT_PALETTE, "buddy_cat_awake")
    to_png(cat_asleep(), CAT_PALETTE, "buddy_cat_asleep")
    to_png(dog_awake(), DOG_PALETTE, "buddy_dog_awake")
    to_png(dog_asleep(), DOG_PALETTE, "buddy_dog_asleep")
