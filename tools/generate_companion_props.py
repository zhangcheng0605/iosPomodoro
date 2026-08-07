"""Generate the Companion Plan's props: snacks, blankets, keepsakes, burrs,
the moth, the summit flag, and the three bespoke paw-up frames.

A separate script from generate_sprites.py on purpose: that script's __main__
re-emits every existing imageset, and the Pillow on this container is newer
than the one that authored them — re-running it would move pixels in art this
change never touched (see RESUME_HERE.md, "Regenerating art moves pixels you
didn't touch"). This script imports the helpers and emits only new imagesets,
so `git status` after a run shows exactly the additions and nothing else.

Run it bare, never with stderr piped away:

    python3 tools/generate_companion_props.py
"""
import os
import sys

from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import generate_sprites as gs
from generate_sprites import (
    T, OUTLINE, BODY, SHADE, CREAM, PINK, EYE, GLINT, NOSE, ACCENT,
)

# --- Snacks -----------------------------------------------------------------
#
# Small enough to sit on the sill chip and still read at a glance. Each snack
# has its own palette over the standard indices, exactly like a buddy does.

SNACK_S = 14

ACORN_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (86, 60, 38, 255),
    BODY: (196, 144, 88, 255), SHADE: (122, 82, 50, 255),
    CREAM: (226, 188, 138, 255), GLINT: (255, 250, 238, 255),
}
FISH_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (58, 74, 92, 255),
    BODY: (150, 176, 198, 255), SHADE: (108, 134, 158, 255),
    CREAM: (226, 236, 244, 255), EYE: (44, 56, 70, 255),
    GLINT: (255, 255, 255, 255),
}
YUZU_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (128, 112, 40, 255),
    BODY: (240, 214, 92, 255), SHADE: (208, 178, 66, 255),
    CREAM: (250, 238, 170, 255), ACCENT: (110, 148, 72, 255),
}
CRACKER_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (140, 108, 62, 255),
    BODY: (238, 210, 158, 255), SHADE: (204, 168, 112, 255),
    CREAM: (250, 234, 198, 255), ACCENT: (94, 118, 74, 255),
}
BERRY_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (150, 96, 40, 255),
    BODY: (240, 168, 84, 255), SHADE: (214, 134, 56, 255),
    CREAM: (252, 208, 140, 255), ACCENT: (110, 148, 72, 255),
    GLINT: (255, 244, 224, 255),
}
HONEY_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (152, 104, 30, 255),
    BODY: (238, 182, 74, 255), SHADE: (206, 148, 48, 255),
    CREAM: (250, 216, 128, 255), GLINT: (255, 244, 200, 255),
}
MOCHI_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (172, 108, 128, 255),
    BODY: (246, 200, 214, 255), SHADE: (228, 168, 188, 255),
    CREAM: (252, 232, 238, 255), PINK: (216, 130, 158, 255),
}
CHESTNUT_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (74, 48, 34, 255),
    BODY: (150, 96, 60, 255), SHADE: (112, 70, 44, 255),
    CREAM: (226, 196, 158, 255), GLINT: (244, 228, 202, 255),
}
SNOWCOOKIE_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (134, 150, 172, 255),
    BODY: (236, 242, 250, 255), SHADE: (208, 220, 236, 255),
    CREAM: (252, 253, 255, 255), ACCENT: (160, 178, 204, 255),
}


def snack_acorn():
    g = gs.new_grid(SNACK_S)
    d = ImageDraw.Draw(g)
    d.ellipse([3, 5, 10, 12], fill=BODY)                  # nut
    d.point((5, 8), fill=GLINT)
    d.ellipse([2, 3, 11, 7], fill=SHADE)                  # cap
    d.line([(6, 1), (7, 3)], fill=SHADE)                  # stalk
    for x in (4, 6, 8):                                   # cap texture
        d.point((x, 5), fill=CREAM)
    return gs.outline_silhouette(g)


def snack_fish(slim=False):
    g = gs.new_grid(SNACK_S)
    d = ImageDraw.Draw(g)
    body = [1, 5, 9, 9] if slim else [1, 4, 9, 10]
    d.ellipse(body, fill=BODY)
    d.polygon([(9, 7), (12, 4), (12, 10)], fill=SHADE)    # tail
    d.ellipse([2, 6, 6, 9] if slim else [2, 6, 6, 10], fill=CREAM)  # belly
    d.point((3, 6), fill=EYE)
    d.point((5, 5), fill=GLINT)
    return gs.outline_silhouette(g)


def snack_yuzu():
    g = gs.new_grid(SNACK_S)
    d = ImageDraw.Draw(g)
    d.ellipse([2, 4, 11, 12], fill=BODY)
    d.ellipse([4, 6, 7, 9], fill=CREAM)                   # highlight
    d.point((7, 3), fill=SHADE)                           # stem dimple
    d.polygon([(8, 1), (11, 2), (8, 4)], fill=ACCENT)     # leaf
    return gs.outline_silhouette(g)


def snack_cracker():
    g = gs.new_grid(SNACK_S)
    d = ImageDraw.Draw(g)
    d.rounded_rectangle([2, 3, 11, 11], radius=2, fill=BODY)
    d.rectangle([5, 3, 8, 11], fill=ACCENT)               # seaweed band
    for x, y in ((3, 5), (10, 6), (4, 9), (9, 9)):        # toasted specks
        d.point((x, y), fill=SHADE)
    return gs.outline_silhouette(g)


def snack_cloudberry():
    g = gs.new_grid(SNACK_S)
    d = ImageDraw.Draw(g)
    for x, y in ((4, 6), (8, 6), (6, 4), (6, 8), (3, 9), (9, 9)):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=BODY)
    d.point((5, 5), fill=GLINT)
    d.point((8, 8), fill=SHADE)
    d.polygon([(6, 1), (9, 2), (6, 3)], fill=ACCENT)      # leaf on top
    return gs.outline_silhouette(g)


def snack_honeycomb():
    g = gs.new_grid(SNACK_S)
    d = ImageDraw.Draw(g)
    d.polygon([(3, 3), (10, 3), (12, 7), (10, 11), (3, 11), (1, 7)], fill=BODY)
    for x, y in ((4, 5), (8, 5), (6, 7), (4, 9), (8, 9)):  # cells
        d.point((x, y), fill=SHADE)
        d.point((x + 1, y), fill=SHADE)
    d.line([(10, 11), (10, 12)], fill=CREAM)               # the drip
    d.point((10, 13), fill=CREAM)
    return gs.outline_silhouette(g)


def snack_mochi():
    g = gs.new_grid(SNACK_S)
    d = ImageDraw.Draw(g)
    d.ellipse([2, 5, 11, 12], fill=BODY)                  # soft bun
    d.ellipse([4, 6, 9, 9], fill=CREAM)
    for x, y in ((6, 3), (5, 4), (7, 4)):                 # petal press
        d.point((x, y), fill=PINK)
    return gs.outline_silhouette(g)


def snack_chestnut():
    g = gs.new_grid(SNACK_S)
    d = ImageDraw.Draw(g)
    d.polygon([(6, 2), (11, 7), (9, 11), (4, 11), (2, 7)], fill=BODY)
    d.ellipse([4, 9, 9, 12], fill=CREAM)                  # pale base
    d.point((6, 4), fill=GLINT)
    d.point((5, 5), fill=SHADE)
    return gs.outline_silhouette(g)


def snack_snowcookie():
    g = gs.new_grid(SNACK_S)
    d = ImageDraw.Draw(g)
    d.ellipse([2, 3, 11, 12], fill=BODY)
    d.line([(6, 5), (6, 10)], fill=ACCENT)                # snowflake arms
    d.line([(4, 7), (9, 7)], fill=ACCENT)
    d.point((4, 5), fill=ACCENT)
    d.point((9, 5), fill=ACCENT)
    d.point((4, 10), fill=ACCENT)
    d.point((9, 10), fill=ACCENT)
    d.point((3, 4), fill=CREAM)
    return gs.outline_silhouette(g)


SNACKS = [
    ("acorn", ACORN_PALETTE, snack_acorn),
    ("sardine", FISH_PALETTE, snack_fish),
    ("yuzu", YUZU_PALETTE, snack_yuzu),
    ("cracker", CRACKER_PALETTE, snack_cracker),
    ("cloudberry", BERRY_PALETTE, snack_cloudberry),
    ("honeycomb", HONEY_PALETTE, snack_honeycomb),
    ("minnow", FISH_PALETTE, lambda: snack_fish(slim=True)),
    ("mochi", MOCHI_PALETTE, snack_mochi),
    ("chestnut", CHESTNUT_PALETTE, snack_chestnut),
    ("snowcookie", SNOWCOOKIE_PALETTE, snack_snowcookie),
]

# --- Blankets ----------------------------------------------------------------
#
# One folded sprite for the sill chip, one draped overlay that sits over any
# buddy's existing asleep pose. The drape is shared by all twelve buddies:
# every asleep pose fills the lower half of the same 40px grid, so a single
# anchor works for the lot — the same bet the fx overlays already make.

BLANKET_ROSE = {
    T: (0, 0, 0, 0), OUTLINE: (140, 92, 100, 255),
    BODY: (226, 164, 172, 255), SHADE: (200, 136, 148, 255),
    CREAM: (250, 234, 226, 255), GLINT: (255, 248, 240, 255),
}
BLANKET_STAR = {
    T: (0, 0, 0, 0), OUTLINE: (58, 62, 104, 255),
    BODY: (104, 112, 168, 255), SHADE: (84, 90, 142, 255),
    CREAM: (216, 220, 244, 255), GLINT: (250, 240, 190, 255),
}


def blanket_folded():
    g = gs.new_grid(18, 12)
    d = ImageDraw.Draw(g)
    d.rounded_rectangle([1, 6, 16, 10], radius=2, fill=BODY)
    d.rounded_rectangle([2, 3, 15, 7], radius=2, fill=SHADE)
    d.rounded_rectangle([3, 1, 14, 4], radius=1, fill=BODY)
    d.line([(3, 8), (14, 8)], fill=CREAM)                 # the stripe
    return gs.outline_silhouette(g)


def blanket_over(starry=False):
    g = gs.new_grid(36, 18)
    d = ImageDraw.Draw(g)
    d.rounded_rectangle([1, 3, 34, 12], radius=3, fill=BODY)
    # Scalloped hem, so it reads as cloth rather than a box.
    for x in (5, 14, 23, 32):
        d.ellipse([x - 5, 9, x + 4, 15], fill=BODY)
    d.line([(3, 5), (32, 5)], fill=CREAM)                 # the stripe
    if starry:
        for x, y in ((7, 8), (16, 10), (25, 8), (30, 11), (11, 12)):
            d.point((x, y), fill=GLINT)
    else:
        for x, y in ((8, 9), (18, 10), (28, 9)):          # quilt dimples
            d.point((x, y), fill=SHADE)
    return gs.outline_silhouette(g)


# --- Keepsakes ----------------------------------------------------------------
#
# What the buddy carries home. Flat little objects, one palette each, drawn at
# the same scale as the snacks so the drawer grid can treat them alike.

KEEP_S = 14

SEAGLASS_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (58, 110, 108, 255),
    BODY: (138, 204, 196, 255), SHADE: (104, 172, 166, 255),
    GLINT: (224, 246, 240, 255),
}
MAPLE_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (146, 74, 34, 255),
    BODY: (226, 132, 62, 255), SHADE: (196, 102, 44, 255),
}
FEATHER_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (96, 110, 128, 255),
    BODY: (182, 198, 214, 255), SHADE: (146, 164, 184, 255),
    CREAM: (232, 240, 248, 255),
}
BUTTON_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (120, 84, 100, 255),
    BODY: (204, 150, 170, 255), SHADE: (176, 122, 144, 255),
    EYE: (92, 62, 76, 255),
}
RIBBON_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (150, 96, 60, 255),
    BODY: (232, 178, 110, 255), SHADE: (204, 146, 82, 255),
    CREAM: (248, 216, 168, 255),
}
BOTTLECAP_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (108, 104, 96, 255),
    BODY: (188, 184, 172, 255), SHADE: (150, 146, 136, 255),
    GLINT: (240, 238, 230, 255), ACCENT: (176, 88, 66, 255),
}
SHELL_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (170, 122, 98, 255),
    BODY: (244, 214, 190, 255), SHADE: (222, 178, 148, 255),
    PINK: (238, 186, 172, 255),
}
PINECONE_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (86, 58, 38, 255),
    BODY: (158, 112, 70, 255), SHADE: (118, 82, 50, 255),
    CREAM: (204, 164, 116, 255),
}
BELL_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (152, 112, 34, 255),
    BODY: (236, 190, 84, 255), SHADE: (204, 156, 56, 255),
    GLINT: (252, 234, 168, 255), EYE: (110, 82, 28, 255),
}
SPRIG_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (66, 104, 60, 255),
    BODY: (128, 178, 104, 255), SHADE: (96, 146, 80, 255),
}
STONE_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (104, 100, 104, 255),
    BODY: (178, 174, 178, 255), SHADE: (146, 142, 148, 255),
    GLINT: (222, 220, 224, 255),
}
SNOWDROP_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (120, 134, 120, 255),
    BODY: (246, 250, 246, 255), SHADE: (214, 226, 216, 255),
    ACCENT: (110, 148, 92, 255),
}


def keep_seaglass():
    g = gs.new_grid(KEEP_S)
    d = ImageDraw.Draw(g)
    d.polygon([(4, 3), (10, 4), (11, 9), (6, 12), (2, 8)], fill=BODY)
    d.point((5, 5), fill=GLINT)
    d.point((8, 9), fill=SHADE)
    return gs.outline_silhouette(g)


def keep_mapleleaf():
    g = gs.new_grid(KEEP_S)
    d = ImageDraw.Draw(g)
    d.polygon([(7, 1), (10, 5), (13, 5), (10, 8), (11, 12), (7, 9),
               (3, 12), (4, 8), (1, 5), (4, 5)], fill=BODY)
    d.line([(7, 4), (7, 10)], fill=SHADE)
    d.line([(7, 10), (7, 13)], fill=SHADE)                 # stalk
    return gs.outline_silhouette(g)


def keep_feather():
    g = gs.new_grid(KEEP_S)
    d = ImageDraw.Draw(g)
    # A slim diagonal vane, not a block — the block read as a pane of glass.
    d.polygon([(8, 1), (11, 2), (9, 6), (6, 10), (3, 12), (2, 11), (5, 6)],
              fill=BODY)
    d.line([(10, 2), (3, 11)], fill=CREAM)                 # the shaft
    d.point((7, 4), fill=SHADE)                            # barb splits
    d.point((5, 8), fill=SHADE)
    d.line([(2, 13), (3, 11)], fill=SHADE)                 # bare quill
    return gs.outline_silhouette(g)


def keep_button():
    g = gs.new_grid(KEEP_S)
    d = ImageDraw.Draw(g)
    d.ellipse([2, 2, 11, 11], fill=BODY)
    d.ellipse([4, 4, 9, 9], fill=SHADE)
    d.point((6, 6), fill=EYE)
    d.point((8, 8), fill=EYE)
    return gs.outline_silhouette(g)


def keep_ribbon():
    g = gs.new_grid(KEEP_S)
    d = ImageDraw.Draw(g)
    d.polygon([(2, 4), (6, 6), (2, 9)], fill=BODY)         # left loop
    d.polygon([(12, 4), (8, 6), (12, 9)], fill=BODY)       # right loop
    d.ellipse([5, 5, 8, 8], fill=SHADE)                    # knot
    d.line([(4, 9), (3, 12)], fill=CREAM)                  # trailing ends
    d.line([(10, 9), (11, 12)], fill=CREAM)
    return gs.outline_silhouette(g)


def keep_bottlecap():
    g = gs.new_grid(KEEP_S)
    d = ImageDraw.Draw(g)
    d.ellipse([2, 2, 11, 11], fill=BODY)
    for x, y in ((2, 5), (5, 2), (9, 2), (12, 6), (10, 11), (4, 11)):
        d.point((x, y), fill=SHADE)                        # fluted rim
    d.ellipse([4, 4, 9, 9], fill=ACCENT)
    d.point((5, 5), fill=GLINT)
    return gs.outline_silhouette(g)


def keep_shell():
    g = gs.new_grid(KEEP_S)
    d = ImageDraw.Draw(g)
    d.polygon([(7, 2), (12, 10), (2, 10)], fill=BODY)
    d.ellipse([2, 7, 12, 12], fill=BODY)
    for x in (4, 7, 10):
        d.line([(7, 3), (x, 10)], fill=SHADE)              # the fan ribs
    d.point((7, 11), fill=PINK)
    return gs.outline_silhouette(g)


def keep_pinecone():
    g = gs.new_grid(KEEP_S)
    d = ImageDraw.Draw(g)
    d.ellipse([3, 2, 10, 12], fill=BODY)
    for y in (4, 7, 10):
        for x in (4, 7):
            d.point((x + (y % 2), y), fill=CREAM)          # scales
        d.line([(3, y), (10, y)], fill=SHADE)
    return gs.outline_silhouette(g)


def keep_bell():
    g = gs.new_grid(KEEP_S)
    d = ImageDraw.Draw(g)
    d.ellipse([5, 1, 8, 4], fill=SHADE)                    # loop
    d.polygon([(6, 3), (7, 3), (11, 10), (2, 10)], fill=BODY)
    d.line([(2, 10), (11, 10)], fill=SHADE)
    d.point((6, 12), fill=EYE)                             # clapper
    d.point((5, 5), fill=GLINT)
    return gs.outline_silhouette(g)


def keep_sprig():
    g = gs.new_grid(KEEP_S)
    d = ImageDraw.Draw(g)
    d.line([(7, 2), (7, 12)], fill=SHADE)
    d.ellipse([2, 3, 6, 7], fill=BODY)
    d.ellipse([8, 5, 12, 9], fill=BODY)
    d.ellipse([4, 8, 8, 12], fill=BODY)
    return gs.outline_silhouette(g)


def keep_stone():
    g = gs.new_grid(KEEP_S)
    d = ImageDraw.Draw(g)
    d.ellipse([2, 5, 11, 12], fill=BODY)
    d.ellipse([4, 6, 8, 9], fill=GLINT)
    d.point((9, 10), fill=SHADE)
    return gs.outline_silhouette(g)


def keep_snowdrop():
    g = gs.new_grid(KEEP_S)
    d = ImageDraw.Draw(g)
    d.line([(9, 2), (9, 12)], fill=ACCENT)                 # stem, nodding
    d.line([(6, 3), (9, 2)], fill=ACCENT)
    d.ellipse([4, 3, 8, 9], fill=BODY)                     # the drop
    d.point((6, 8), fill=SHADE)
    return gs.outline_silhouette(g)


KEEPSAKES = [
    ("seaglass", SEAGLASS_PALETTE, keep_seaglass),
    ("mapleleaf", MAPLE_PALETTE, keep_mapleleaf),
    ("feather", FEATHER_PALETTE, keep_feather),
    ("button", BUTTON_PALETTE, keep_button),
    ("ribbon", RIBBON_PALETTE, keep_ribbon),
    ("bottlecap", BOTTLECAP_PALETTE, keep_bottlecap),
    ("shell", SHELL_PALETTE, keep_shell),
    ("pinecone", PINECONE_PALETTE, keep_pinecone),
    ("bell", BELL_PALETTE, keep_bell),
    ("sprig", SPRIG_PALETTE, keep_sprig),
    ("stone", STONE_PALETTE, keep_stone),
    ("snowdrop", SNOWDROP_PALETTE, keep_snowdrop),
]

# --- Burrs --------------------------------------------------------------------
#
# Yesterday, still attached. Tiny overlays anchored to a point on the buddy —
# per-buddy anchors are Swift data; the sprites are shared by everyone.

BURR_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (96, 82, 44, 255),
    BODY: (166, 148, 84, 255), SHADE: (128, 112, 60, 255),
}
PETAL_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (196, 126, 148, 255),
    BODY: (246, 190, 206, 255), SHADE: (230, 160, 182, 255),
}
SALT_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (168, 176, 188, 255),
    BODY: (240, 244, 250, 255),
}
SNOWCAP_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (170, 188, 210, 255),
    BODY: (248, 251, 255, 255), SHADE: (222, 232, 246, 255),
}
LEAFBIT_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (150, 96, 40, 255),
    BODY: (224, 148, 74, 255), SHADE: (196, 118, 52, 255),
}
SEED_PALETTE = {
    T: (0, 0, 0, 0), OUTLINE: (120, 96, 56, 255),
    BODY: (206, 176, 116, 255), SHADE: (170, 140, 86, 255),
}

BURR_S = 8


def burr_burr():
    g = gs.new_grid(BURR_S)
    d = ImageDraw.Draw(g)
    d.ellipse([2, 2, 5, 5], fill=BODY)
    for x, y in ((1, 1), (6, 1), (1, 6), (6, 6), (3, 0), (0, 4), (7, 3), (4, 7)):
        d.point((x, y), fill=SHADE)                        # hooks
    return gs.outline_silhouette(g)


def burr_petal():
    g = gs.new_grid(BURR_S)
    d = ImageDraw.Draw(g)
    d.polygon([(1, 5), (4, 1), (6, 3), (4, 6)], fill=BODY)
    d.point((4, 3), fill=SHADE)
    return gs.outline_silhouette(g)


def burr_salt():
    g = gs.new_grid(BURR_S)
    d = ImageDraw.Draw(g)
    for x, y in ((1, 3), (4, 1), (6, 4), (3, 6)):
        d.point((x, y), fill=BODY)
    return gs.outline_silhouette(g)


def burr_snow():
    g = gs.new_grid(BURR_S)
    d = ImageDraw.Draw(g)
    d.ellipse([1, 2, 6, 6], fill=BODY)
    d.point((2, 3), fill=SHADE)
    return gs.outline_silhouette(g)


def burr_leaf():
    g = gs.new_grid(BURR_S)
    d = ImageDraw.Draw(g)
    d.polygon([(1, 6), (3, 1), (6, 2), (5, 6)], fill=BODY)
    d.line([(3, 2), (4, 6)], fill=SHADE)
    return gs.outline_silhouette(g)


def burr_seed():
    g = gs.new_grid(BURR_S)
    d = ImageDraw.Draw(g)
    d.ellipse([2, 1, 5, 6], fill=BODY)
    d.point((3, 2), fill=SHADE)
    return gs.outline_silhouette(g)


BURRS = [
    ("burr", BURR_PALETTE, burr_burr),
    ("petal", PETAL_PALETTE, burr_petal),
    ("salt", SALT_PALETTE, burr_salt),
    ("snow", SNOWCAP_PALETTE, burr_snow),
    ("leaf", LEAFBIT_PALETTE, burr_leaf),
    ("seed", SEED_PALETTE, burr_seed),
]

# --- Effects ------------------------------------------------------------------


def fx_moth(frame):
    """Two frames of a small moth for the hello vignette. Template, like the
    other fx sprites, so it tints with the theme."""
    g = gs.new_grid(12, 10)
    d = ImageDraw.Draw(g)
    d.line([(5, 3), (5, 7)], fill=OUTLINE)                 # body
    if frame == 0:                                         # wings up
        d.polygon([(4, 4), (1, 1), (2, 5)], fill=OUTLINE)
        d.polygon([(6, 4), (9, 1), (8, 5)], fill=OUTLINE)
    else:                                                  # wings out
        d.polygon([(4, 4), (0, 3), (2, 6)], fill=OUTLINE)
        d.polygon([(6, 4), (10, 3), (8, 6)], fill=OUTLINE)
    d.point((4, 2), fill=OUTLINE)                          # antennae
    d.point((6, 2), fill=OUTLINE)
    return g


def fx_flag():
    """The summit flag, planted on a personal-best week. Template, so the app
    can tint it with the phase accent and the contrast stays checkable."""
    g = gs.new_grid(10, 12)
    d = ImageDraw.Draw(g)
    d.line([(3, 1), (3, 10)], fill=OUTLINE)                # pole
    d.polygon([(4, 1), (9, 3), (4, 5)], fill=OUTLINE)      # pennant
    return g


# --- The three bespoke paw-up frames -------------------------------------------
#
# High-five frames for the two free buddies (and Soot, who is the cat's
# drawings in her own palette). Everyone else raises the moment through the
# happy bounce via the BuddyFrames fallback until their frame is drawn.
# Bodies copied from cat_awake/dog_awake in generate_sprites.py with one
# front paw raised; a change to the base drawing there should be mirrored here.


def cat_pawup():
    g = gs.new_grid()
    d = ImageDraw.Draw(g)
    for i, (x, y) in enumerate([(31, 32), (33, 31), (35, 29), (36, 26), (36, 23)]):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=SHADE if i > 2 else BODY)
    d.ellipse([9, 22, 31, 37], fill=BODY)
    d.ellipse([13, 26, 27, 37], fill=CREAM)
    d.ellipse([12, 32, 18, 37], fill=CREAM)                # left paw stays down
    d.polygon([(9, 12), (11, 2), (18, 9)], fill=BODY)
    d.polygon([(31, 12), (29, 2), (22, 9)], fill=BODY)
    d.polygon([(12, 10), (12, 5), (16, 9)], fill=PINK)
    d.polygon([(28, 10), (28, 5), (24, 9)], fill=PINK)
    d.ellipse([8, 6, 32, 26], fill=BODY)
    d.line([(16, 8), (18, 10)], fill=SHADE)
    d.line([(20, 7), (20, 10)], fill=SHADE)
    d.line([(24, 8), (22, 10)], fill=SHADE)
    d.ellipse([13, 17, 27, 25], fill=CREAM)
    gs.eyes(d, 15, 25, 15, "happy")
    d.polygon([(19, 19), (21, 19), (20, 21)], fill=NOSE)
    d.line([(20, 21), (18, 22)], fill=OUTLINE)
    d.line([(20, 21), (22, 22)], fill=OUTLINE)
    for y in (19, 21):
        d.line([(11, y), (14, y + 1)], fill=OUTLINE)
        d.line([(29, y), (26, y + 1)], fill=OUTLINE)
    # The raised arm, drawn after the head so it sits in front: shoulder to
    # paw in three beads, then the pad held up and open.
    for x, y in ((28, 29), (30, 26), (32, 23)):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=BODY)
    d.ellipse([30, 17, 36, 23], fill=CREAM)
    d.point((32, 19), fill=PINK)
    d.point((34, 19), fill=PINK)
    d.point((33, 21), fill=PINK)
    return gs.outline_silhouette(g)


def dog_pawup():
    g = gs.new_grid()
    d = ImageDraw.Draw(g)
    for i, (x, y) in enumerate([(30, 34), (33, 32), (35, 29)]):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=SHADE if i > 1 else BODY)
    d.ellipse([9, 22, 31, 37], fill=BODY)
    d.ellipse([13, 26, 27, 37], fill=CREAM)
    d.ellipse([12, 32, 18, 37], fill=CREAM)                # left paw stays down
    d.ellipse([4, 8, 13, 24], fill=SHADE)
    d.ellipse([27, 8, 36, 24], fill=SHADE)
    d.ellipse([8, 6, 32, 26], fill=BODY)
    d.ellipse([21, 10, 30, 19], fill=SHADE)
    gs.eyes(d, 15, 25, 15, "happy")
    d.ellipse([13, 18, 27, 26], fill=CREAM)
    d.ellipse([17, 18, 23, 23], fill=EYE)
    d.line([(20, 23), (20, 25)], fill=OUTLINE)
    d.line([(20, 25), (17, 26)], fill=OUTLINE)
    d.line([(20, 25), (23, 26)], fill=OUTLINE)
    d.ellipse([18, 25, 22, 29], fill=PINK)
    for x, y in ((28, 30), (30, 27), (32, 24)):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=BODY)
    d.ellipse([30, 18, 36, 24], fill=CREAM)
    d.point((32, 20), fill=EYE)
    d.point((34, 20), fill=EYE)
    return gs.outline_silhouette(g)


if __name__ == "__main__":
    print("Snacks:")
    for name, palette, draw in SNACKS:
        gs.to_png(draw(), palette, f"snack_{name}")
    print("Blankets:")
    gs.to_png(blanket_folded(), BLANKET_ROSE, "fx_blanket_folded")
    gs.to_png(blanket_folded(), BLANKET_STAR, "fx_blanket_folded_winter")
    gs.to_png(blanket_over(), BLANKET_ROSE, "fx_blanket_over")
    gs.to_png(blanket_over(starry=True), BLANKET_STAR, "fx_blanket_over_winter")
    print("Keepsakes:")
    for name, palette, draw in KEEPSAKES:
        gs.to_png(draw(), palette, f"keep_{name}")
    print("Burrs:")
    for name, palette, draw in BURRS:
        gs.to_png(draw(), palette, f"burr_{name}")
    print("Effects:")
    gs.to_png(fx_moth(0), gs.FX_PALETTE, "fx_moth_0", template=True)
    gs.to_png(fx_moth(1), gs.FX_PALETTE, "fx_moth_1", template=True)
    gs.to_png(fx_flag(), gs.FX_PALETTE, "fx_flag", template=True)
    print("Paw-up frames:")
    gs.to_png(cat_pawup(), gs.CAT_PALETTE, "buddy_cat_pawup")
    gs.to_png(dog_pawup(), gs.DOG_PALETTE, "buddy_dog_pawup")
    gs.to_png(cat_pawup(), gs.STRAY_PALETTE, "buddy_stray_pawup")
