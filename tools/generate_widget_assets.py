"""Build PawmodoroWidgets/Assets.xcassets: the widget extension's catalog.

A widget runs in its own process and bundle, so it cannot read the app's
asset catalog — the sprites it draws must ship in the extension target.
This script fills the catalog two ways:

* The buddy sprites are **copied byte-for-byte** from the app catalog —
  never re-rendered. The Pillow on this container is newer than the one
  that authored the art, and re-rendering would move pixels in sprites
  this change never touched (see RESUME_HERE.md). A copy cannot drift.
* The one genuinely new sprite (the December night-cap) is drawn here,
  which is safe for the same reason generate_companion_props.py is: new
  art has no old pixels to move.

Idempotent; run it bare, never with stderr piped away:

    python3 tools/generate_widget_assets.py
"""
import json
import os
import shutil

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")
OUT = os.path.join(ROOT, "PawmodoroWidgets", "Assets.xcassets")

BUDDIES = [
    "cat", "dog", "penguin", "bunny", "hamster", "fox",
    "capybara", "redpanda", "owl", "otter", "hedgehog", "stray",
]

UPSCALE = 10

# Index constants, matching generate_sprites.py's convention.
T, OUTLINE, BODY, SHADE, CREAM = 0, 1, 2, 3, 4

NIGHTCAP_PALETTE = {
    T: (0, 0, 0, 0),
    OUTLINE: (40, 50, 86, 255),
    BODY: (86, 106, 168, 255),
    SHADE: (62, 80, 136, 255),
    CREAM: (250, 244, 228, 255),
}


def copy_imageset(name):
    src = os.path.join(APP_ASSETS, f"{name}.imageset")
    dst = os.path.join(OUT, f"{name}.imageset")
    if not os.path.isdir(src):
        raise SystemExit(f"missing source imageset: {name}")
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    print(f"  copied {name}")


def emit(grid, palette, name):
    arr = np.array(grid, dtype=np.uint8)
    height, width = arr.shape
    rgba = np.zeros((height, width, 4), dtype=np.uint8)
    for index, colour in palette.items():
        rgba[arr == index] = colour
    img = Image.fromarray(rgba, mode="RGBA")
    img = img.resize((width * UPSCALE, height * UPSCALE), Image.NEAREST)

    folder = os.path.join(OUT, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, f"{name}.png"), "PNG")
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({
            "images": [{"filename": f"{name}.png", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
        }, f, indent=2)
    print(f"  {name}: {width * UPSCALE}x{height * UPSCALE}")


def outline(arr):
    """Ring every solid pixel with OUTLINE, the generate_sprites way."""
    solid = np.pad(arr != T, 1)
    neighbours = np.zeros_like(solid)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        shifted = np.roll(np.roll(solid, dy, axis=0), dx, axis=1)
        neighbours |= shifted
    edge = (neighbours & ~solid)[1:-1, 1:-1]
    arr[edge] = OUTLINE
    return arr


def nightcap():
    """A slouching night-cap, brim left, pompom drooping right."""
    img = Image.new("L", (18, 14), T)
    d = ImageDraw.Draw(img)
    # The cone, leaning right the way a well-used cap does.
    d.polygon([(3, 10), (6, 2), (14, 8)], fill=BODY)
    # A fold of shade along the underside of the lean.
    d.line([(7, 6), (12, 8)], fill=SHADE, width=1)
    d.line([(6, 8), (11, 9)], fill=SHADE, width=1)
    # The brim, rolled cream.
    d.rectangle([2, 9, 9, 11], fill=CREAM)
    # The pompom, hanging off the tip.
    d.ellipse([13, 7, 16, 10], fill=CREAM)
    arr = outline(np.array(img, dtype=np.uint8))
    return arr


def main():
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)

    print("copying buddy sprites into the widget catalog:")
    for buddy in BUDDIES:
        copy_imageset(f"buddy_{buddy}_awake")
        copy_imageset(f"buddy_{buddy}_asleep")
    copy_imageset("buddy_owl_watch")

    print("drawing the new sprite:")
    emit(nightcap(), NIGHTCAP_PALETTE, "widget_nightcap")


if __name__ == "__main__":
    main()
