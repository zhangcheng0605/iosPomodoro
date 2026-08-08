"""Generate the wardrobe, and measure where it goes.

Two jobs in one tool, because they must never disagree: it draws the fifteen
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

def _runs(row, of=None):
    """Contiguous spans in one row, as (start, end) pairs.

    Filled pixels by default; one specific palette index when `of` is given,
    which is how the eyes are found — they are the only thing on a buddy drawn
    in `EYE`, apart from a couple of noses, and a nose is one blob rather than
    a pair.
    """
    out, start = [], None
    for x, value in enumerate(row):
        hit = (value != T) if of is None else (value == of)
        if hit and start is None:
            start = x
        elif not hit and start is not None:
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


def _eye_band(arr, top, floor):
    """Where the eyes are, read off the pixels that draw them.

    `HEARTH_PLAN`'s as-built said spectacles were impossible because the face
    "is a third anchor nobody can measure". That was wrong, and pleasantly so:
    every buddy routes its eyes through `generate_sprites.eyes()`, which paints
    them in one palette index — `EYE` — that nothing else on the head uses in
    a *pair*. So the eyes announce themselves.

    A pair, specifically: two spans in the same row with a real gap between
    them. Three buddies draw their nose in `EYE` as well, and a nose is one
    span — which is also why this takes runs rather than a bounding box, since
    a box round every `EYE` pixel on the dog reaches from his eyes down over
    his muzzle and would sit the spectacles on his nose.

    The gap has to be at least two columns wide, because a single open eye is
    itself two spans on the row where its highlight sits: `eyes_open` paints a
    `GLINT` pixel inside the pupil, splitting that row in half with a
    one-column gap. Two halves of one eye are not a pair of eyes.

    Nothing about the *head* is used here — no centre line, no width. That was
    the first version and it was wrong: the sleeping bunny's widest run is her
    ear, which puts the measured head centre well right of her face, and both
    of her closed eyes then counted as "left" and she went bare-faced. The eyes
    know where they are without being told where the head is.

    The topmost band wins. Below the eyes there is only muzzle.
    """
    band = None
    for index in range(top, floor + 1):
        spans = _runs(arr[index], of=EYE)
        outer = None
        if len(spans) >= 2 and spans[-1][0] - spans[0][1] - 1 >= 2:
            outer = (spans[0][0], spans[-1][1])
        if outer:
            if band is None:
                band = [index, index, outer]
            else:
                band[1] = index
                band[2] = (min(band[2][0], outer[0]), max(band[2][1], outer[1]))
        elif band is not None:
            break
    return band


def measure(grid, face_grid=None, eyes_grid=None):
    """Where a hat, a collar and a pair of spectacles go on one rendered frame.

    Runs rather than extents: measuring a row's full min-to-max span reads
    straight across the *gap between two ears*, which put the cat's crown four
    pixels above her actual skull and balanced every hat on thin air.

    `face_grid` is the drawing the *face* is measured on, when that is not the
    frame itself. The two glance frames are the whole reason it exists: they
    are the same animal with its pupils moved two pixels sideways, and
    spectacles measured off them slide about the face every time the buddy
    looks at something. A pupil that glances is not a head that moved.

    `eyes_grid` is the same idea for the *head*, and it exists because the two
    cannot always be the same drawing. A sleeping buddy's eyes are shut, and on
    the hedgehog they are not drawn at all — he must get no face anchor, or he
    wears spectacles over closed eyes. But his head has not gone anywhere, and
    without somewhere to read it from he fell back to the old widest-run rule
    and centred it a pixel off, so a hat slid sideways the instant he woke.
    Passing the waking drawing here locates the head without granting a face.
    """
    arr = np.array(grid)
    filled = [i for i, row in enumerate(arr) if (row != T).any()]
    if not filled:
        return None
    top, bottom = filled[0], filled[-1]
    height = bottom - top + 1

    # The face is measured *first*, because the head is measured from it.
    #
    # It used to be measured last, off a floor derived from the head, which is
    # the wrong way round: the eyes are the one landmark that announces itself
    # in a palette index of its own, and the head is the thing that has to be
    # searched for. Nothing here uses the head, exactly as `_eye_band`'s
    # docstring insists — the floor is the whole figure.
    band = _eye_band(np.array(face_grid) if face_grid is not None else arr,
                     top, bottom)
    face, face_w = None, 0
    if band:
        first, last, (left, right) = band
        face = (round((left + right) / 2, 1), round((first + last) / 2, 1))
        face_w = right - left + 1

    # Where the head is, which is not always where the face anchor is allowed to
    # be. Falls back to this frame's own eyes whenever no reference is given.
    head_band = band
    if eyes_grid is not None:
        head_band = _eye_band(np.array(eyes_grid), top, bottom) or band
    head_eyes = None
    if head_band:
        first, last, (left, right) = head_band
        head_eyes = round((left + right) / 2, 1)

    # The head is the widest run *through the eyes*, made symmetric about them.
    #
    # Both halves of that sentence are load-bearing, and each fixes a different
    # frame. "The widest single run anywhere in the top 40%" — what this used
    # to be — assumes the animal is standing up. The three stretch frames are a
    # play-bow: rump up and to the right, head low on the left. In the top 40%
    # of *that* there is no head at all, only tail and hindquarters, so every
    # hat was drawn on the cat's rear.
    #
    # Searching through the eyes fixes the position but not the size, because
    # a row or two below the crown the head touches the raised rump and the two
    # merge into one run thirty-five pixels wide — the dog's stretch measured a
    # head of 37 on a 40-pixel canvas, and wore a sun hat the width of the whole
    # animal. So the run is clipped to the widest span *symmetric about the
    # face*: a head is symmetric about its own face, and whatever sticks out on
    # one side only is some other part of the animal. A run already centred on
    # the face keeps its exact width, so this half costs the upright buddies
    # nothing.
    #
    # The rows searched reach down to the eyes when the eyes are lower than the
    # top 40%, and no further: below the eyes there is only muzzle and body.
    # This *does* move the upright buddies, and deliberately — 62 of the 121
    # rows changed. The old floor stopped near the top of the skull and measured
    # a head narrower than the head: the bunny came out 19 wide and wore a sun
    # hat that perched on her like a party cone, where the width at her own eye
    # line is 25. Every such change was checked against a contact sheet before
    # it was kept, and the three worst were not the stretch at all — the otter
    # floating on her back and the sliding penguin were both measured at 37,
    # the whole animal, and the sleeping bunny's head anchor sat out on the tip
    # of her ear, which is the same mistake `_eye_band` below already had to
    # learn for the face.
    widest, head_row, head_cx = 0, top, arr.shape[1] / 2
    floor = top + max(1, int(height * 0.40))
    if head_band:
        floor = max(floor, head_band[1])
    floor = min(floor, bottom)

    if head_eyes is not None:
        for index in range(top, floor + 1):
            run = _run_at(arr[index], head_eyes)
            if run is None:
                continue
            # Symmetric about the face, and inclusive of the centre column, so
            # a run already centred there keeps its exact width rather than
            # losing a pixel to the rounding.
            span = int(2 * min(head_eyes - run[0], run[1] - head_eyes) + 1)
            if span > widest:
                widest, head_row, head_cx = span, index, head_eyes

    # No eyes on this frame and no drawing of it with them open — so there is
    # nothing to measure the head from and the old rule is the best available.
    # It is also still correct for every pose it was correct for before, which
    # is most of them.
    if not widest:
        for index in range(top, floor + 1):
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

    # The face was measured at the top of this function. Nothing is guessed
    # there: a frame whose eyes are not visible — the hedgehog rolled into a
    # ball, the bunny asleep with her head tucked under — gets no face anchor
    # and so wears nothing on it. That is `BuddyFrames`' nil-fallback rule
    # again, and it is the honest answer: a pair of spectacles on a face you
    # cannot see would be floating in fur.

    return {
        "head": (round(head_cx, 1), crown),
        "headWidth": widest,
        "neck": (round(neck_cx, 1), neck_row),
        "neckWidth": neck_w,
        "face": face,
        "faceWidth": face_w,
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

    Returns the frames and, alongside them, the drawing each frame's *face* is
    measured on where that is not the frame itself, and the drawing its *head*
    is measured from where those two differ. See `measure`.
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
    faces = {}

    # A pupil that closes is not a head that moved, either.
    #
    # This started as the two glance frames below, for the face alone. It has
    # to cover every eyes-only variant now, because the *head* is measured from
    # the eyes as well, and the rows it searches reach down to them: a blink
    # draws a shorter eye band than an open eye, which moved the search floor,
    # which measured a different head on a drawing that is pixel-for-pixel
    # identical. The owl and the hamster came out 29 awake and 27 blinking, and
    # `BuddyAnimator.idle` alternates those two — so a hat resized itself every
    # time the buddy blinked, four seconds apart, for as long as the app was
    # open. `awake_blink` and the two happy frames are the same drawing as
    # `awake` with different eyes, so they measure both anchors on it; `happy_1`
    # is that drawing shifted, and its reference is shifted with it.
    reference = out[f"buddy_{species}_awake"]
    faces[f"buddy_{species}_awake_blink"] = reference
    faces[f"buddy_{species}_happy_0"] = reference
    faces[f"buddy_{species}_happy_1"] = gs.shift(reference, -2)

    # The sleeping pair, for the head only. These two must *not* get a face
    # reference: a buddy with his eyes shut wears no spectacles, and that is
    # `BuddyFrames`' nil-fallback rule. But the head is still there, and the
    # hedgehog is drawn asleep with no eyes at all, so without this he fell back
    # to the old rule and measured his head a pixel off the one his waking frame
    # measured — a hat that jumped sideways the moment he opened his eyes.
    eyes = {
        f"buddy_{species}_asleep": out[f"buddy_{species}_wake"],
        f"buddy_{species}_asleep_breathe":
            gs.squash(asleep("open"), gs.BREATHE_ROW),
    }

    for suffix, dx in (("look_l", -2), ("look_r", 2)):
        gs.set_eye_shift(dx)
        out[f"buddy_{species}_{suffix}"] = awake()
        faces[f"buddy_{species}_{suffix}"] = out[f"buddy_{species}_awake"]
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
    return out, faces, eyes


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


def beret():
    """Soft, tilted, and nobody asked why."""
    g = new_grid(16, 7)
    d = ImageDraw.Draw(g)
    d.ellipse([0, 2, 15, 6], fill=ACCENT)                 # the wide soft brim
    d.ellipse([1, 0, 11, 5], fill=ACCENT)                 # the crown, worn over
    d.line([(3, 1), (7, 0)], fill=CREAM)                  # where the light sits
    d.ellipse([4, 0, 6, 1], fill=CREAM)                   # the stalk
    return outline_silhouette(g)


# The face pieces. Two rules of their own:
#
# They are centred on the anchor rather than hung from an edge — a face sits in
# the middle of a face — and the see-through ones skip `outline_silhouette`.
# That pass paints every transparent pixel *adjacent to* a solid one, which
# includes the inside of a five-pixel lens: silhouetting a pair of round
# spectacles fills both lenses solid and blindfolds the animal.

def spectacles():
    """Round, brass, and see-through — the eyes still show through them.

    Two rings each, dark outside the gold. That is not decoration: a gold hoop
    on its own measured 1.4:1 against the bunny's fur, and a rim you cannot see
    against the animal is not a pair of spectacles, it is a smudge. Every other
    piece gets the same dark edge from `outline_silhouette`; these have to draw
    it by hand, because that pass would fill the lenses in.
    """
    g = new_grid(20, 9)
    d = ImageDraw.Draw(g)
    for x in (0, 11):
        d.ellipse([x, 0, x + 8, 8], outline=OUTLINE)
        d.ellipse([x + 1, 1, x + 7, 7], outline=GLINT)
        d.point((x + 3, 2), fill=CREAM)                   # the catch of light
    d.line([(9, 3), (10, 3)], fill=OUTLINE)
    d.line([(9, 4), (10, 4)], fill=GLINT)                 # the bridge
    d.line([(9, 5), (10, 5)], fill=OUTLINE)
    return g


def shades():
    """Two dark lenses and nothing behind them."""
    g = new_grid(16, 6)
    d = ImageDraw.Draw(g)
    d.rectangle([0, 1, 6, 5], fill=OUTLINE)
    d.rectangle([9, 1, 15, 5], fill=OUTLINE)
    d.rectangle([0, 0, 15, 0], fill=GLINT)                # the brow bar
    d.line([(7, 1), (8, 1)], fill=GLINT)                  # the bridge
    d.line([(1, 2), (3, 4)], fill=CREAM)                  # the shine
    d.line([(10, 2), (12, 4)], fill=CREAM)
    return outline_silhouette(g)


def monocle():
    """One lens, one chain, no explanation.

    Drawn hard against the right edge on purpose. The piece is centred on the
    face like every other one, so where the ring sits *within the grid* is the
    only thing deciding which eye it lands on — drawn nearer the middle it came
    out perched on the bridge of the nose on half the roster.
    """
    g = new_grid(18, 10)
    d = ImageDraw.Draw(g)
    d.ellipse([9, 0, 17, 8], outline=OUTLINE)
    d.ellipse([10, 1, 16, 7], outline=GLINT)
    d.point((12, 2), fill=CREAM)
    for point in ((9, 8), (8, 9), (7, 9)):                # the chain, falling
        d.point(point, fill=OUTLINE)
    d.point((8, 8), fill=GLINT)
    return g


def starglasses():
    """At a party nobody else has been told about."""
    g = new_grid(18, 8)
    d = ImageDraw.Draw(g)
    for cx in (4, 13):
        d.polygon([(cx, 0), (cx + 2, 3), (cx + 4, 3), (cx + 2, 5),
                   (cx + 3, 7), (cx, 6), (cx - 3, 7), (cx - 2, 5),
                   (cx - 4, 3), (cx - 2, 3)], fill=PINK)
        d.point((cx, 3), fill=GLINT)
    d.line([(8, 3), (9, 3)], fill=PINK)                   # the bridge
    return outline_silhouette(g)


ACCESSORIES = {
    # head
    "sunhat": sunhat,
    "flowercrown": flowercrown,
    "knittedcap": knittedcap,
    "crown": crown,
    "leaf": leaf,
    "beret": beret,
    # face
    "spectacles": spectacles,
    "shades": shades,
    "monocle": monocle,
    "starglasses": starglasses,
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
        /// The eyes: where the *centre* of a face piece sits, and how far
        /// apart the eyes are so it can be scaled to them. Nil on a frame
        /// whose eyes are not visible — a face down in a stretch, a hedgehog
        /// rolled up — and that frame wears nothing on its face, which is the
        /// honest answer rather than a guess.
        let face: CGPoint?
        let faceWidth: CGFloat
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
        face = ("nil" if a["face"] is None
                else f'CGPoint(x: {a["face"][0]}, y: {a["face"][1]})')
        lines.append(
            f'        "{name}": Anchors(\n'
            f'            head: CGPoint(x: {a["head"][0]}, y: {a["head"][1]}),\n'
            f'            headWidth: {a["headWidth"]},\n'
            f'            neck: CGPoint(x: {a["neck"][0]}, y: {a["neck"][1]}),\n'
            f'            neckWidth: {a["neckWidth"]},\n'
            f'            face: {face},\n'
            f'            faceWidth: {a["faceWidth"]},\n'
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
        frames, faces, eyes = frames_for(species, awake, asleep, stretch, quirks)
        bare = 0
        for asset, grid in frames.items():
            found = measure(grid, faces.get(asset), eyes.get(asset))
            if found:
                rows[asset] = found
                bare += found["face"] is None
        print(f"  {species}: {len(frames)} frames"
              f"{f', {bare} with no visible face' if bare else ''}")
    emit_anchors(rows)
    print(f"  wrote {len(rows)} rows to {os.path.relpath(ANCHORS_FILE, ROOT)}")
