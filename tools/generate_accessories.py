"""Generate the wardrobe, and measure where it goes.

Two jobs in one tool, because they must never disagree: it draws the ten
accessories, and it measures every buddy frame to find out where each one
attaches — emitting `Pawmodoro/Model/BuddyAnchors.swift`, which is generated
and must not be hand-edited.

### Why measured rather than composited

The obvious build is to composite each accessory onto each buddy frame and
export the lot. That is ten accessories x twelve buddies x a dozen frames —
well over a thousand 400x400 PNGs, tens of megabytes in the bundle, and a
regeneration every time a buddy's ear moves. Instead there are **ten** sprites
and a table of attachment points: the app draws the accessory over the buddy
at runtime, scaled to that buddy's own head.

### Why measured rather than typed

`HEARTH_PLAN` assumed the buddies came out of shared builders with known
geometry the way the wildlife does. They do not — every buddy is hand-drawn
with its own coordinates. But the *pixels* know where the head is, so the
anchors are read off the rendered grid instead. A buddy redrawn tomorrow gets
correct anchors from the next run of this tool, with nobody remembering to
update anything, which is the property that actually mattered.

    python3 tools/generate_accessories.py

Emits the sprites, then rewrites BuddyAnchors.swift.
"""
import os
import sys

import numpy as np
from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import generate_sprites as gs
import generate_companion_props as cp
from generate_sprites import (
    ACCENT, BODY, CREAM, EYE, GLINT, NOSE, OUTLINE, PINK, SHADE, T,
    new_grid, outline_silhouette, to_png,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANCHORS_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "BuddyAnchors.swift")

# Bright and few. An accessory has to read at fourteen logical pixels against
# twelve different fur colours, so it gets saturated hues no buddy has and a
# heavy outline — subtlety here reads as dirt on the screen.
WARDROBE = {
    T: (0, 0, 0, 0),
    OUTLINE: (58, 44, 40, 255),
    BODY: (214, 84, 76, 255),       # the red things
    SHADE: (168, 58, 54, 255),
    CREAM: (248, 244, 234, 255),
    ACCENT: (86, 122, 176, 255),    # the blue things
    PINK: (232, 150, 176, 255),
    GLINT: (246, 206, 96, 255),     # gold, brass, straw
    NOSE: (128, 96, 66, 255),
    EYE: (72, 108, 84, 255),        # leaf green
}


# --- The measuring ---------------------------------------------------------

def _runs(row):
    """Contiguous filled spans in one row, as (start, end) pairs."""
    out, start = [], None
    for x, value in enumerate(row):
        if value != T and start is None:
            start = x
        elif value == T and start is not None:
            out.append((start, x - 1))
            start = None
    if start is not None:
        out.append((start, len(row) - 1))
    return out


def _run_at(row, column):
    for a, b in _runs(row):
        if a <= column <= b:
            return (a, b)
    return None


def measure(grid):
    """Where a hat and a collar go on one rendered frame.

    Runs rather than extents: measuring a row's full min-to-max span reads
    straight across the *gap between two ears*, which put the cat's crown four
    pixels above her actual skull and balanced every hat on thin air.
    """
    arr = np.array(grid)
    filled = [i for i, row in enumerate(arr) if (row != T).any()]
    if not filled:
        return None
    top, bottom = filled[0], filled[-1]
    height = bottom - top + 1

    # The head is the widest single run anywhere in the top 40%.
    widest, head_row, head_cx = 0, top, arr.shape[1] / 2
    for index in range(top, top + max(1, int(height * 0.40)) + 1):
        for a, b in _runs(arr[index]):
            if b - a + 1 > widest:
                widest, head_row, head_cx = b - a + 1, index, (a + b) / 2

    # The crown: the first row from the top whose run through the head's centre
    # line is at least half the head's width. Everything above that is ear.
    crown = head_row
    for index in range(top, head_row + 1):
        run = _run_at(arr[index], head_cx)
        if run and (run[1] - run[0] + 1) >= widest * 0.5:
            crown = index
            break

    # The collar sits at a fraction of the figure's own height below the crown,
    # not at a fraction of the head's *width*. Width overshoots badly on the
    # wide-eared buddies — it put the dog's collar two rows off the bottom of
    # the canvas — and these heads are all about the same fraction of the
    # figure however wide they are drawn.
    neck_row = min(bottom, crown + int(round((bottom - crown) * 0.68)))
    run = _run_at(arr[neck_row], head_cx)
    neck_cx = (run[0] + run[1]) / 2 if run else head_cx
    # Capped at the head's width, and this is the correction that made the
    # whole wardrobe work. The run at the collar line is the *shoulders* on
    # most of these buddies, so scaling a collar to it produced a scarf as
    # wide as the animal — the first contact sheet was twelve creatures
    # wearing striped blankets. A collar goes round a neck, and a neck is
    # never wider than the head above it.
    neck_w = min((run[1] - run[0] + 1) if run else widest, widest)

    return {
        "head": (round(head_cx, 1), crown),
        "headWidth": widest,
        "neck": (round(neck_cx, 1), neck_row),
        "neckWidth": neck_w,
        # Where the animal ends. Nothing in the wardrobe needs it — a hat and a
        # collar both hang off the head — but `TouchSpot` does: a tummy region
        # sized from the head ran off the bottom of the canvas on half the
        # roster, and there is no way to know where the body stops without
        # measuring it.
        "bottom": bottom,
    }


def frames_for(species, awake, asleep, stretch, quirks):
    """Every frame `build_frames` emits, redrawn so it can be measured.

    Deliberately mirrors `build_frames` rather than importing its output: the
    exported PNG is upscaled and palette-mapped, and measuring that would mean
    undoing both. If the two ever drift apart, `check_accessories.py` notices —
    it asserts an anchor exists for every buddy imageset on disk.
    """
    out = {
        f"buddy_{species}_awake": awake(),
        f"buddy_{species}_awake_blink": awake("closed"),
        f"buddy_{species}_asleep": asleep(),
        f"buddy_{species}_asleep_breathe": gs.squash(asleep(), gs.BREATHE_ROW),
        f"buddy_{species}_wake": asleep("open"),
    }
    happy = awake("happy")
    out[f"buddy_{species}_happy_0"] = happy
    out[f"buddy_{species}_happy_1"] = gs.shift(happy, -2)
    for suffix, dx in (("look_l", -2), ("look_r", 2)):
        gs.set_eye_shift(dx)
        out[f"buddy_{species}_{suffix}"] = awake()
    gs.set_eye_shift(0)
    if stretch is not None:
        out[f"buddy_{species}_stretch"] = stretch()
    for suffix, draw in (quirks or {}).items():
        out[f"buddy_{species}_{suffix}"] = draw()
    # The high five's raised paw. Drawn in generate_companion_props.py rather
    # than here, which is why the anchor table never saw it and three poses
    # wore nothing at all: a buddy in a hat that raises a paw would have lost
    # the hat. Measured like every other pose now.
    if species in ("cat", "stray"):
        out[f"buddy_{species}_pawup"] = cp.cat_pawup()
    elif species == "dog":
        out[f"buddy_{species}_pawup"] = cp.dog_pawup()
    return out


# --- The wardrobe ----------------------------------------------------------
#
# Each returns a grid. The Swift side knows, per accessory, which of its own
# edges lands on the anchor and how wide it is relative to the buddy's head —
# see `Accessory.swift`. Nothing here knows about any particular buddy.

def sunhat():
    g = new_grid(22, 8)
    d = ImageDraw.Draw(g)
    d.ellipse([0, 4, 21, 7], fill=GLINT)                  # the brim
    d.ellipse([6, 0, 15, 6], fill=GLINT)                  # the crown
    d.rectangle([6, 3, 15, 5], fill=BODY)                 # its band
    return outline_silhouette(g)


def flowercrown():
    g = new_grid(20, 6)
    d = ImageDraw.Draw(g)
    d.arc([0, 0, 19, 9], 180, 360, fill=EYE)              # the vine
    for index, x in enumerate((1, 6, 11, 16)):
        y = 1 if index % 2 else 0
        d.ellipse([x, y, x + 3, y + 3], fill=PINK if index % 2 else CREAM)
        d.point((x + 1, y + 1), fill=GLINT)
    return outline_silhouette(g)


def knittedcap():
    g = new_grid(18, 9)
    d = ImageDraw.Draw(g)
    d.ellipse([2, 2, 15, 11], fill=ACCENT)
    d.rectangle([0, 6, 17, 8], fill=CREAM)                # the turned-up brim
    d.ellipse([7, 0, 11, 3], fill=CREAM)                  # the bobble
    for x in range(4, 15, 3):
        d.line([(x, 3), (x, 5)], fill=SHADE)              # the ribbing
    return outline_silhouette(g)


def crown():
    g = new_grid(16, 7)
    d = ImageDraw.Draw(g)
    d.polygon([(0, 6), (0, 1), (4, 4), (7, 0), (11, 4), (15, 1), (15, 6)],
              fill=GLINT)
    d.rectangle([0, 5, 15, 6], fill=SHADE)
    for x in (4, 11):
        d.point((x, 5), fill=PINK)
    return outline_silhouette(g)


def leaf():
    """One leaf, landed and stayed. The quietest thing in the cart."""
    g = new_grid(11, 8)
    d = ImageDraw.Draw(g)
    d.polygon([(0, 7), (5, 0), (10, 4), (4, 7)], fill=BODY)
    d.line([(1, 6), (7, 3)], fill=SHADE)                  # the midrib
    return outline_silhouette(g)


def bandana():
    g = new_grid(18, 9)
    d = ImageDraw.Draw(g)
    d.rectangle([0, 1, 17, 4], fill=BODY)                 # round the neck
    d.polygon([(6, 3), (12, 3), (9, 8)], fill=SHADE)      # the knot's tail
    for x in range(1, 17, 3):
        d.point((x, 2), fill=CREAM)                       # the spots
    return outline_silhouette(g)


def bellcollar():
    g = new_grid(18, 8)
    d = ImageDraw.Draw(g)
    d.rectangle([0, 0, 17, 3], fill=BODY)
    d.ellipse([6, 2, 11, 7], fill=GLINT)                  # the bell
    d.line([(7, 5), (10, 5)], fill=SHADE)
    d.point((8, 3), fill=CREAM)
    return outline_silhouette(g)


def scarf():
    g = new_grid(20, 11)
    d = ImageDraw.Draw(g)
    d.rectangle([0, 0, 19, 3], fill=ACCENT)
    d.rectangle([13, 2, 17, 10], fill=ACCENT)             # the hanging end
    for y in (1, 3):
        d.line([(0, y), (19, y)], fill=CREAM)
    for y in (5, 8):
        d.line([(13, y), (17, y)], fill=CREAM)
    return outline_silhouette(g)


def kerchief():
    g = new_grid(18, 9)
    d = ImageDraw.Draw(g)
    d.rectangle([0, 0, 17, 2], fill=CREAM)
    d.polygon([(4, 1), (14, 1), (9, 8)], fill=ACCENT)     # the sailor's fall
    d.line([(6, 4), (12, 4)], fill=CREAM)
    return outline_silhouette(g)


def bow():
    g = new_grid(14, 8)
    d = ImageDraw.Draw(g)
    d.polygon([(0, 0), (5, 3), (0, 7)], fill=PINK)
    d.polygon([(13, 0), (8, 3), (13, 7)], fill=PINK)
    d.ellipse([5, 2, 8, 5], fill=SHADE)
    return outline_silhouette(g)


ACCESSORIES = {
    # head
    "sunhat": sunhat,
    "flowercrown": flowercrown,
    "knittedcap": knittedcap,
    "crown": crown,
    "leaf": leaf,
    # neck
    "bandana": bandana,
    "bellcollar": bellcollar,
    "scarf": scarf,
    "kerchief": kerchief,
    "bow": bow,
}


# --- Emitting the anchors --------------------------------------------------

HEADER = '''import CoreGraphics

// Generated by tools/generate_accessories.py. Do not edit by hand.
//
// Where an accessory attaches, per buddy frame, measured off the rendered
// sprite rather than typed. Coordinates are in the drawing grid's own units
// (%d x %d), which `Accessory` converts to fractions of whatever size the
// sprite is finally drawn at.
//
// A frame with no row here simply wears nothing — `BuddyFrames`' nil-fallback
// rule, extended to overlays. That is the correct behaviour for a pose whose
// head the measurer could not find, and it is why a missing entry is a
// shrug rather than a crash.
enum BuddyAnchors {

    struct Anchors {
        /// The crown: where the bottom edge of a hat sits.
        let head: CGPoint
        /// How wide the head is, so a hat can be scaled to it.
        let headWidth: CGFloat
        /// The collar line: where the centre of a neck piece sits.
        let neck: CGPoint
        let neckWidth: CGFloat
        /// The last row the animal occupies, for anything that needs to know
        /// where the body stops rather than where the head is.
        let bottom: CGFloat
    }

    /// The grid every coordinate above is measured on.
    static let canvas: CGFloat = %d

    static func anchors(for asset: String) -> Anchors? { table[asset] }

    static let table: [String: Anchors] = [
'''


def emit_anchors(rows):
    lines = [HEADER % (gs.S, gs.S, gs.S)]
    for name in sorted(rows):
        a = rows[name]
        lines.append(
            f'        "{name}": Anchors(\n'
            f'            head: CGPoint(x: {a["head"][0]}, y: {a["head"][1]}),\n'
            f'            headWidth: {a["headWidth"]},\n'
            f'            neck: CGPoint(x: {a["neck"][0]}, y: {a["neck"][1]}),\n'
            f'            neckWidth: {a["neckWidth"]},\n'
            f'            bottom: {a["bottom"]}),\n'
        )
    lines.append("    ]\n}\n")
    with open(ANCHORS_FILE, "w") as handle:
        handle.write("".join(lines))


if __name__ == "__main__":
    print("Wardrobe:")
    for name, draw in ACCESSORIES.items():
        to_png(draw(), WARDROBE, f"wear_{name}")

    print("Anchors:")
    rows = {}
    for species, palette, awake, asleep, stretch, quirks in gs.BUDDIES:
        frames = frames_for(species, awake, asleep, stretch, quirks)
        for asset, grid in frames.items():
            found = measure(grid)
            if found:
                rows[asset] = found
        print(f"  {species}: {len(frames)} frames")
    emit_anchors(rows)
    print(f"  wrote {len(rows)} rows to {os.path.relpath(ANCHORS_FILE, ROOT)}")
