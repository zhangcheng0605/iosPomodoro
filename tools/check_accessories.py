"""Check the wardrobe: that every piece lands on the animal wearing it.

The accessories are the first art in this app that is positioned by *another
file's* numbers. A sprite that is wrong on its own is obvious in a contact
sheet; a hat that is correct on eleven buddies and floating above the twelfth
is not, and neither is one that is fine awake and hovering over a curled-up
sleeping pose. Ten pieces x twelve buddies x a dozen frames is more than
anybody is going to page through.

So this asks, for every combination the app can actually draw:

1. **Is there an anchor at all?** Every buddy imageset on disk must have a row
   in `BuddyAnchors`, or that pose silently wears nothing forever.
2. **Does the piece touch the animal?** A hat's bottom edge has to overlap
   real pixels. Floating is the failure mode this whole file exists for — the
   stray taught the same lesson about ground, and the residents taught it
   about being buried.
3. **Is it still on the canvas?** A tall hat on a buddy whose crown is six
   rows down gets clipped clean off the top, and a clipped hat is a rectangle.
4. **Does it read?** Every piece has to clear 2:1 against the fur immediately
   under it, in every buddy's palette. A red bandana on the fox is the case
   this catches.
5. **Do the two files agree?** `Accessory.aspect` is typed in Swift and the
   grids are drawn in Python. They must match, because a wrong aspect
   *squashes* the art rather than moving it, and a squashed hat still looks
   like a hat.
6. **Are the head and the face the same head?** Every rule above asks whether a
   piece landed on the anchor it was hung from, so a head anchor pointing at
   the wrong end of the animal passes all of them — the hat sits convincingly
   on the rump, which is solid fur and contrasts fine. Six frames shipped that
   way. The crown and the eyes share a centre line or they are not one head.
7. **Does a neck piece leave the face alone?** The same blind spot one anchor
   further down. A collar measured onto the muzzle passes every rule above —
   it is on the animal, it is on the canvas, and a red bandana reads perfectly
   well against a cream snout — so the whole hedgehog set shipped with all
   five neck pieces drawn across his face and his nose hidden underneath. A
   collar hangs *downward* from the collar line, so that line has to be below
   the eyes or the piece is a blindfold.

The placement arithmetic is deliberately a port of `Accessory.placement(on:)`
rather than a second idea about where things go — if the two disagree, this
file is wrong and should be fixed to match the app.

    python3 tools/check_accessories.py

Exits non-zero if anything fails.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np

import check_contrast as contrast_check
import generate_accessories as ga
import generate_sprites as gs

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")
MODEL = os.path.join(ROOT, "Pawmodoro", "Model")

# A piece has to read against the fur under it. Same bar as a tree or a
# resident: it is a shape, not a word.
MINIMUM_CONTRAST = 2.0

# How much of a piece's lower edge must overlap the buddy. Less than this and
# it is perched on an ear tip or hanging in the air beside a chin.
MINIMUM_OVERLAP = 0.35

# How far the crown may sit from the face's own centre line, in grid pixels.
#
# A head is symmetric about the face on it, so these two anchors share a centre
# line and the honest tolerance is "a pixel or two", not a tuned number: every
# frame in the shipping table scores exactly 0.0, and the six frames this rule
# was written against scored 7.0 to 17.5. Nothing lands in between, which is
# what makes 2.0 a threshold rather than a fudge.
MAXIMUM_HEAD_FACE_DRIFT = 2.0

# How far below the lowest eye pixel the collar line must sit, in grid rows.
#
# Zero would be the literal rule — a piece that starts on an eye covers it —
# and zero is too weak by exactly the amount that matters. The hedgehog's two
# happy frames drew their bandana across the muzzle with the collar one row
# under a `^^` eye, passing a strictly-below test while hiding the whole face
# beneath it. So this asks for daylight rather than a tie.
#
# Two, because nothing in the roster is near it from either side: every frame
# in the shipping table clears by 3 to 14 rows, and the nine hedgehog frames
# this rule was written against cleared by -1 to 1. Nothing lands on 2, which
# is what makes it a threshold rather than a fudge — the same standard
# MAXIMUM_HEAD_FACE_DRIFT above is held to.
MINIMUM_COLLAR_CLEARANCE = 2.0


def parse_anchors():
    """The generated table, read back as the app will read it."""
    source = open(os.path.join(MODEL, "BuddyAnchors.swift")).read()
    rows = {}
    for match in re.finditer(
        r'"(\w+)": Anchors\(\s*head: CGPoint\(x: ([-\d.]+), y: ([-\d.]+)\),\s*'
        r'headWidth: ([-\d.]+),\s*neck: CGPoint\(x: ([-\d.]+), y: ([-\d.]+)\),\s*'
        r'neckWidth: ([-\d.]+),\s*'
        r'face: (?:nil|CGPoint\(x: ([-\d.]+), y: ([-\d.]+)\)),\s*'
        r'faceWidth: ([-\d.]+),\s*bottom: ([-\d.]+)\)', source
    ):
        face = None
        if match.group(8) is not None:
            face = (float(match.group(8)), float(match.group(9)))
        rows[match.group(1)] = {
            "head": (float(match.group(2)), float(match.group(3))),
            "headWidth": float(match.group(4)),
            "neck": (float(match.group(5)), float(match.group(6))),
            "neckWidth": float(match.group(7)),
            "face": face,
            "faceWidth": float(match.group(10)),
            "bottom": float(match.group(11)),
        }
    if not rows:
        raise SystemExit("could not parse BuddyAnchors.swift")
    return rows


def parse_table(name, pattern):
    source = open(os.path.join(MODEL, "Accessory.swift")).read()
    body = source.split(name)[1].split("\n    }")[0]
    return dict(re.findall(pattern, body))


def parse_accessories():
    """Slot, scale, sink and aspect, out of the real Swift."""
    source = open(os.path.join(MODEL, "Accessory.swift")).read()

    slots = {}
    body = source.split("var slot: Slot {")[1].split("\n    }")[0]
    for labels, slot in re.findall(r"case ((?:\.\w+,? ?)+): \.(\w+)", body):
        for name in re.findall(r"\.(\w+)", labels):
            slots[name] = slot

    scales = {k: float(v) for k, v in
              parse_table("var scale: CGFloat {", r"case \.(\w+): ([\d.]+)").items()}
    sinks = {}
    body = source.split("var sink: CGFloat {")[1].split("\n    }")[0]
    for labels, value in re.findall(r"case ((?:\.\w+,? ?)+): ([\d.]+)", body):
        for name in re.findall(r"\.(\w+)", labels):
            sinks[name] = float(value)

    aspects = {}
    body = source.split("private static func aspect")[1].split("\n    }")[0]
    for name, w, h in re.findall(r"case \.(\w+): ([\d.]+) / ([\d.]+)", body):
        aspects[name] = (float(w), float(h))
    return slots, scales, sinks, aspects


def parse_headroom():
    """`BuddySprite.headroom`, out of the real Swift rather than restated."""
    source = open(os.path.join(ROOT, "Pawmodoro", "Views", "BuddySprite.swift")).read()
    found = re.search(r"static let headroom: CGFloat = ([\d.]+)", source)
    if not found:
        raise SystemExit("could not parse BuddySprite.headroom")
    return float(found.group(1))


def logical(asset):
    """A sprite as its drawing grid, undoing the export's upscale."""
    from PIL import Image
    path = os.path.join(ASSETS, f"{asset}.imageset", f"{asset}.png")
    if not os.path.exists(path):
        return None
    image = np.array(Image.open(path).convert("RGBA"))
    step = gs.UPSCALE
    return image[step // 2::step, step // 2::step]


# Pairs of frames that differ *only* in their eyes. Each is the same drawing
# called with a different eye mode — `awake("closed")` for the blink,
# `asleep("open")` for the waking frame, the same `awake()` with the pupils
# nudged for the two glances — so whatever changed between them is the eyes and
# nothing else. That is the independent measurement in this file: everywhere
# else it asks "given where the generator says the face is, does the piece land
# on it", which is exactly the trap `check_touch.py` fell into, where five
# deliberate breaks all passed because the checker carried the numbers it was
# checking. A difference between two shipped PNGs is not something
# `BuddyAnchors` has any say in.
EYE_PAIRS = (("awake", "awake_blink"), ("asleep", "wake"), ("look_l", "look_r"))

# Above this many changed pixels the two frames are not an eyes-only pair —
# Bramble's asleep pose is a different drawing rather than the same one with
# its eyes shut — and there is nothing to conclude from the difference.
MAXIMUM_EYE_DIFFERENCE = 90


def eye_colour(species):
    """The RGB this species' eyes are painted, out of its own palette."""
    for name, palette, *_ in gs.BUDDIES:
        if name == species:
            return tuple(palette[gs.EYE])[:3]
    return None


def eye_blobs(asset, species):
    """Where the eyes are on one shipped PNG, found without the anchor table.

    A second opinion for the frames `EYE_PAIRS` cannot reach. Half the roster's
    poses — every stretch, the otter's float, the penguin's slide and waddle,
    the quirks — have no eyes-only partner to diff against, and for those the
    rule below was comparing the face anchor against itself and scoring a
    guaranteed zero. That is the `check_touch.py` trap exactly, and it hid the
    original bug: five of the six frames rule 3c was written for are unpaired.

    Deliberately a *different* algorithm from the generator's `_eye_band`, which
    walks rows looking for two runs. This flood-fills connected components of
    eye-coloured pixels and takes the two largest in the upper half. A copy of
    the generator's method would agree with the generator's mistakes; two
    methods that disagree are the point.

    Returns `(centre column, first row, last row)` across the two blobs, or
    None when this frame does not show a clean pair — a closed eye, a rolled-up
    hedgehog, or a nose painted in the same index. The rows are what rule 7
    needs: a collar has to hang below the *bottom* of the eyes, and the centre
    of a face anchor says nothing about where its lowest pixel is.
    """
    colour = eye_colour(species)
    image = logical(asset)
    if image is None or colour is None:
        return None
    hit = np.all(image[..., :3] == np.array(colour), axis=-1) & (image[..., 3] > 0)
    if not hit.any():
        return None

    seen = np.zeros_like(hit, dtype=bool)
    blobs = []
    for sy, sx in zip(*np.nonzero(hit)):
        if seen[sy, sx]:
            continue
        stack, cells = [(sy, sx)], []
        seen[sy, sx] = True
        while stack:
            y, x = stack.pop()
            cells.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if (0 <= ny < hit.shape[0] and 0 <= nx < hit.shape[1]
                        and hit[ny, nx] and not seen[ny, nx]):
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        blobs.append(cells)

    # The two biggest, and they have to be side by side rather than one above
    # the other — that is what separates a pair of eyes from an eye and a nose.
    blobs.sort(key=len, reverse=True)
    if len(blobs) < 2:
        return None
    (ay, ax), (by, bx) = (
        (sum(c[0] for c in b) / len(b), sum(c[1] for c in b) / len(b))
        for b in blobs[:2]
    )
    if abs(ax - bx) < 2 or abs(ay - by) > 2:
        return None

    # How deep the eyes are, which is a different question from where they are
    # and cannot be answered by the two blobs above.
    #
    # A happy eye is the five pixels of a `^`, and those touch only at their
    # corners: orthogonally it is five blobs of one pixel each, so "the two
    # largest" are whichever two the sort put first and the pair measures one
    # row tall. Flood-filling diagonally instead fixes the `^` and breaks
    # something worse — a pair of *closed* eyes is drawn five columns apart and
    # seven wide, so diagonal fill merges them into one blob and twenty frames
    # stop finding a pair at all.
    #
    # So the pair says where to look, and the depth is then grown from there
    # through rows that actually continue the shape. Contiguously, not "every
    # eye-coloured pixel between the two blobs" — that reaches past the eyes
    # into anything else drawn in the same index further down the face and
    # reported the sleeping hamster's eyes as six rows deeper than they are.
    left = min(cell[1] for blob in blobs[:2] for cell in blob)
    right = max(cell[1] for blob in blobs[:2] for cell in blob)
    filled = hit[:, left:right + 1].any(axis=1)
    first = min(cell[0] for blob in blobs[:2] for cell in blob)
    last = max(cell[0] for blob in blobs[:2] for cell in blob)
    while first > 0 and filled[first - 1]:
        first -= 1
    while last + 1 < len(filled) and filled[last + 1]:
        last += 1
    return round((ax + bx) / 2, 1), int(first), int(last)


def eye_box(first, second):
    """Where two eyes-only frames differ: (x0, x1, y0, y1), or None."""
    a, b = logical(first), logical(second)
    if a is None or b is None or a.shape != b.shape:
        return None
    changed = np.any(a != b, axis=-1)
    count = int(changed.sum())
    if count < 4 or count > MAXIMUM_EYE_DIFFERENCE:
        return None
    ys, xs = np.nonzero(changed)
    return (int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max()))


def placement(anchors, slot, scale, sink, aspect):
    """A port of `Accessory.placement(on:)`. Must not become a second idea."""
    if slot == "head":
        width = anchors["headWidth"] * scale
        height = width / aspect
        return (anchors["head"][0] - width / 2,
                anchors["head"][1] - height * (1 - sink), width, height)
    if slot == "face":
        if anchors.get("face") is None or not anchors.get("faceWidth"):
            return None
        width = anchors["faceWidth"] * scale
        height = width / aspect
        return (anchors["face"][0] - width / 2,
                anchors["face"][1] - height / 2, width, height)
    width = anchors["neckWidth"] * scale
    height = width / aspect
    return (anchors["neck"][0] - width / 2, anchors["neck"][1], width, height)


def main():
    failures = []
    anchors = parse_anchors()
    slots, scales, sinks, aspects = parse_accessories()

    names = sorted(slots)
    if len(names) != 15:
        failures.append(f"parsed {len(names)} accessories out of Accessory.swift, "
                        f"expected 15 — the parser has drifted from the file")

    # --- 1. The two files agree on how big each piece is drawn -------------
    for name in names:
        drawn = logical(f"wear_{name}")
        if drawn is None:
            failures.append(f"wear_{name}: missing — run "
                            f"tools/generate_accessories.py")
            continue
        actual = drawn.shape[1] / drawn.shape[0]
        typed = aspects.get(name)
        if typed is None:
            failures.append(f"{name} has no aspect in Accessory.swift")
            continue
        if abs(actual - typed[0] / typed[1]) > 0.02:
            failures.append(
                f"{name}: drawn {drawn.shape[1]}x{drawn.shape[0]} but "
                f"Accessory.aspect says {typed[0]:.0f}/{typed[1]:.0f} — a wrong "
                f"aspect squashes the art instead of moving it, which is the "
                f"kind of wrong nobody notices")

    # --- 2. Every buddy frame on disk has an anchor -------------------------
    on_disk = sorted(
        d[:-len(".imageset")] for d in os.listdir(ASSETS)
        if d.startswith("buddy_") and d.endswith(".imageset")
    )
    for asset in on_disk:
        if asset not in anchors:
            failures.append(
                f"{asset} has no row in BuddyAnchors — that pose wears nothing, "
                f"forever, and nothing anywhere says so")

    # --- 3. Every piece, on every frame -------------------------------------
    palettes = contrast_check.parse_palettes(
        open(os.path.join(MODEL, "AppTheme.swift")).read())
    canvas = gs.S
    # Mirrors `BuddySprite.headroom`: the sprite is clipped to a box padded
    # above by this much, so a hat may rise past the buddy's own square and a
    # scarf may hang below it, but neither may leave the sides.
    headroom = parse_headroom() * canvas
    checked = 0
    worst = (99.0, None)
    tightest = (2.0, None)
    drifted = (0.0, None)
    clearance = (None, None)
    independent, selfsame = 0, 0

    wardrobe = {name: logical(f"wear_{name}") for name in names}

    # --- 3a. The face anchors, against eyes nobody told this file about -----
    #
    # `EYE_PAIRS` gives a second opinion on where the eyes are for the frames
    # that have a partner: the difference between two eyes-only drawings. It
    # covers the two very different postures (sitting up, curled asleep) and
    # both glances, which is most of what any face piece is ever drawn on.
    species_of = {}
    verified = {}
    for asset in on_disk:
        parts = asset.split("_")
        if len(parts) >= 3:
            species_of[asset] = parts[1]
    for species in sorted(set(species_of.values())):
        for first, second in EYE_PAIRS:
            one, two = f"buddy_{species}_{first}", f"buddy_{species}_{second}"
            box = eye_box(one, two)
            if box:
                verified[one] = box
                verified[two] = box

    faces_seen, faces_bare = 0, 0
    for asset, box in sorted(verified.items()):
        if asset not in anchors:
            continue
        anchored = anchors[asset].get("face")
        x0, x1, y0, y1 = box
        if not anchored:
            failures.append(
                f"{asset}: the eyes are plainly there — rows {y0}-{y1}, columns "
                f"{x0}-{x1}, found by diffing this frame against the one that "
                f"differs from it only in the eyes — and BuddyAnchors has no "
                f"face row, so a pair of spectacles blinks out on this frame "
                f"and back on the next")
            continue
        faces_seen += 1
        if not (y0 - 1.5 <= anchored[1] <= y1 + 1.5):
            failures.append(
                f"{asset}: the face anchor is on row {anchored[1]:.1f} and the "
                f"eyes are on rows {y0}-{y1} — a piece centred there is on the "
                f"muzzle, not the eyes")
        if not (x0 - 1.5 <= anchored[0] <= x1 + 1.5):
            failures.append(
                f"{asset}: the face anchor is at x={anchored[0]:.1f} and the "
                f"eyes run from {x0} to {x1} — the piece is off the side of "
                f"the face")
        width = anchors[asset]["faceWidth"]
        if not ((x1 - x0 + 1) * 0.5 <= width <= (x1 - x0 + 1) * 1.5):
            failures.append(
                f"{asset}: faceWidth is {width:.0f} but the eyes measure "
                f"{x1 - x0 + 1} across — every face piece is scaled to that "
                f"number, so all four come out the wrong size")

    for asset in on_disk:
        if asset not in anchors:
            continue
        buddy = logical(asset)
        if buddy is None:
            continue
        solid = buddy[..., 3] > 0
        found = verified.get(asset)

        # --- 3b. And on the frames with no partner to diff against ----------
        #
        # Weaker, but not nothing: a face is between the crown and the collar,
        # and roughly over the head. This is what catches a measurer that has
        # locked on to something that is not a face at all on a pose only that
        # buddy has.
        anchored = anchors[asset].get("face")
        if anchored is None:
            faces_bare += 1
        elif not found:
            crown, collar = anchors[asset]["head"][1], anchors[asset]["neck"][1]
            if not (crown <= anchored[1] <= collar + 1):
                failures.append(
                    f"{asset}: the face anchor is on row {anchored[1]:.1f}, "
                    f"outside the crown ({crown:.0f}) to collar ({collar:.0f}) "
                    f"band — that is not a face")

        # --- 3c. The crown and the eyes belong to the same head -------------
        #
        # The two anchors were measured separately and nothing above makes them
        # agree with each other: 3a asks whether the *face* is on the eyes, and
        # every other rule asks whether a piece lands on the anchor it was hung
        # from. A head anchor can therefore be pointing at an entirely different
        # part of the animal and every one of those rules still passes, because
        # the hat does sit convincingly on *something*.
        #
        # That is not hypothetical. It is what shipped: the head anchor is
        # measured as the widest run near the top of the figure, and on the
        # three play-bow stretch frames the top of the figure is the raised
        # hindquarters, so every hat was drawn on the cat's rear — 17.5 pixels
        # from her face, at the other end of the sprite — while the overlap and
        # contrast rules passed it happily, the rump being warm solid fur.
        #
        # A head is symmetric about its own face, so the crown and the eyes
        # share a centre line. Checked against the eyes found by frame
        # difference where that frame has a partner to diff against, which is
        # the measurement `BuddyAnchors` has no say in; the stretch frames have
        # no partner, so they fall back to the face anchor, corroborated by 3b
        # above. The chain is: 3a/3b say the face anchor is really a face, and
        # this says the head is the head that face is on.
        if anchored is not None:
            # A glance is the one frame where the eye pixels genuinely move and
            # the head deliberately does not — `frames_for` measures both
            # glances off the resting drawing, on the grounds that a pupil that
            # glances is not a head that moved. So read the eyes off that same
            # resting drawing, or this rule reports the owl's 2px glance as a
            # 2px error. `EYE_PAIRS` already knows these two are a pair; this is
            # the same fact, used for the head instead of the face.
            source_asset = asset
            for glance in ("_look_l", "_look_r"):
                if asset.endswith(glance):
                    source_asset = asset[:-len(glance)] + "_awake"
            blobs = eye_blobs(source_asset, species_of.get(asset, ""))
            if found:
                centre = (found[0] + found[1]) / 2
                source = ("the eyes, found by diffing this frame against the "
                          "one that differs from it only in the eyes,")
                independent += 1
            elif blobs is not None:
                centre = blobs[0]
                source = ("the eyes, found as the two largest blobs of eye "
                          "colour on the shipped sprite,")
                independent += 1
            else:
                centre = anchored[0]
                source = "the face anchor"
                selfsame += 1
            drift = abs(anchors[asset]["head"][0] - centre)
            if drift > drifted[0]:
                drifted = (drift, asset)
            if drift > MAXIMUM_HEAD_FACE_DRIFT:
                failures.append(
                    f"{asset}: the crown is at x={anchors[asset]['head'][0]:.1f} "
                    f"but {source} is centred on x={centre:.1f} — {drift:.1f} "
                    f"pixels apart, so the head anchor and the face anchor are "
                    f"not on the same head, and every hat is worn by whichever "
                    f"part of the animal the head anchor found instead")

        # --- 3d. And the collar line is below the face ----------------------
        #
        # A neck piece hangs *downward* from the collar line by its top edge,
        # so everything from that line to the bottom of the piece is drawn over
        # whatever is there. Every other rule in this file is satisfied by a
        # collar measured onto a muzzle — it is on the animal, it is on the
        # canvas, and a red bandana reads beautifully against a cream snout —
        # which is exactly how the hedgehog shipped wearing all five neck
        # pieces across his face, nose hidden, the bow tied to his snout.
        #
        # Checked against the lowest eye pixel rather than the face anchor's
        # own row wherever a second opinion exists, for the `check_touch.py`
        # reason: an anchor that has landed on the muzzle will cheerfully agree
        # that the collar is below itself. `eye_box` diffs this frame against
        # the one that differs from it only in the eyes; `eye_blobs` reads the
        # eye-coloured pixels straight off the shipped sprite. The anchor is
        # the last resort, and a frame where nothing can find a pair of eyes —
        # the hedgehog curled into a ball — has no face to cover and so no rule
        # to break.
        own = eye_blobs(asset, species_of.get(asset, ""))
        if found:
            floor, source = found[3], ("the eyes, found by diffing this frame "
                                       "against the one that differs from it "
                                       "only in the eyes,")
        elif own is not None:
            floor, source = own[2], ("the eyes, found as blobs of eye colour "
                                     "on the shipped sprite,")
        elif anchored is not None:
            floor, source = anchored[1], "the face anchor"
        else:
            floor, source = None, None
        if floor is not None:
            collar = anchors[asset]["neck"][1]
            if clearance[0] is None or collar - floor < clearance[0]:
                clearance = (collar - floor, asset)
            if collar - floor < MINIMUM_COLLAR_CLEARANCE:
                failures.append(
                    f"{asset}: the collar line is on row {collar:.0f} and "
                    f"{source} reaches row {floor:.0f} — a neck piece hangs "
                    f"downward from the collar line, so all five of them are "
                    f"drawn across this face rather than under it")

        for name in names:
            art = wardrobe.get(name)
            if art is None:
                continue
            box = placement(anchors[asset], slots[name], scales[name],
                            sinks.get(name, 0.0), art.shape[1] / art.shape[0])
            if box is None:
                # No face on this frame, so nothing is drawn. Rule 3a above has
                # already decided whether that absence is honest.
                continue
            x, y, w, h = box
            checked += 1

            # A face piece has to be *on* the eyes, and wide enough to be a
            # thing worn over them rather than a smudge between them.
            if slots[name] == "face" and found:
                x0, x1, y0, y1 = found
                centre_x, centre_y = (x0 + x1) / 2, (y0 + y1) / 2
                if not (x - 0.5 <= centre_x <= x + w + 0.5
                        and y - 0.5 <= centre_y <= y + h + 0.5):
                    failures.append(
                        f"{name} on {asset} does not cover the eyes: the piece "
                        f"is at ({x:.1f}, {y:.1f}) {w:.1f}x{h:.1f} and the eyes "
                        f"are centred on ({centre_x:.1f}, {centre_y:.1f})")
                    continue
                if w < (x1 - x0 + 1) * 0.6:
                    failures.append(
                        f"{name} on {asset} is {w:.1f} wide across eyes that "
                        f"measure {x1 - x0 + 1} — too small to read as worn")
                    continue

            # On the canvas — in the three directions that matter. A hat
            # clipped by the *top* edge is a rectangle, and a piece running off
            # either side is obviously wrong. Running off the bottom is not a
            # fault: a scarf is supposed to hang past the animal, the sprite
            # view clips to its own square, and forbidding it here reported
            # three hundred correct scarves as broken.
            if x < -0.5 or y < -headroom - 0.5 or x + w > canvas + 0.5:
                failures.append(
                    f"{name} on {asset} runs off the canvas at "
                    f"({x:.1f}, {y:.1f}) {w:.1f}x{h:.1f}")
                continue
            # But the edge it attaches by has to be *on* the canvas, or the
            # piece is entirely below the animal and only its clipping saves it.
            if slots[name] == "neck" and y > canvas - 2:
                failures.append(
                    f"{name} on {asset} attaches at y={y:.1f}, off the bottom of "
                    f"the canvas — it would be clipped away to nothing")
                continue

            # Touching the animal — at the edge that actually attaches, which
            # is not the same edge for both slots. A hat *rests* on the skull,
            # so its lower edge must be over pixels. A scarf *hangs* from the
            # collar, so its lower edge is supposed to be in mid-air and its
            # top edge is the one that has to be on the animal. Testing the
            # bottom of both reported 417 floating scarves against a contact
            # sheet where every one of them sat correctly.
            # A face piece is centred rather than hung, so its middle is the
            # row that matters: the top edge of a pair of spectacles is up in
            # the brow fur, and what an eye compares them against is the face.
            if slots[name] == "head":
                attach = y + h - 1
            elif slots[name] == "face":
                attach = y + h / 2
            else:
                attach = y
            row = int(min(canvas - 1, max(0, round(attach))))
            columns = [int(round(x + w * f)) for f in (0.2, 0.35, 0.5, 0.65, 0.8)]
            columns = [c for c in columns if 0 <= c < canvas]
            hits = sum(1 for c in columns if solid[row, c])
            share = hits / max(1, len(columns))
            if share < tightest[0]:
                tightest = (share, f"{name}/{asset}")
            if share < MINIMUM_OVERLAP:
                failures.append(
                    f"{name} floats on {asset} — only {share * 100:.0f}% of its "
                    f"lower edge is over the animal")
                continue

            # Reading against the fur — the *mass* of it, not the rim.
            #
            # Sampled across three rows inward from the attaching edge and
            # reduced to the commonest colour there. Testing the contact row
            # alone compares the piece against the buddy's own one-pixel dark
            # outline, which is precisely where a brim lands on every buddy in
            # the roster: it reported the red leaf as 1.97:1 on the white
            # bunny, when what it had actually found was dark-red-on-dark-brown
            # at the single pixel of silhouette between the two. What an eye
            # compares an accessory against is the animal.
            samples = []
            for offset in (0, 1, 2):
                probe = row + offset
                if 0 <= probe < canvas:
                    samples += [tuple(buddy[probe, c][:3])
                                for c in columns if solid[probe, c]]
            if not samples:
                continue
            fur = max(set(samples), key=samples.count)
            fur = tuple(v / 255.0 for v in fur)
            colours = {
                tuple(v / 255.0 for v in colour)
                for colour in {tuple(c) for c in art[art[..., 3] > 0][:, :3].tolist()}
            }
            best = max(contrast_check.contrast(colour, fur) for colour in colours)
            if best < worst[0]:
                worst = (best, f"{name}/{asset}")
            if best < MINIMUM_CONTRAST:
                failures.append(
                    f"{name} on {asset}: {best:.2f}:1 against the fur under it")

    print(f"checked {checked} piece/frame placements across {len(on_disk)} frames")
    print(f"face anchors: {faces_seen} checked against eyes found by frame "
          f"difference, {faces_bare} frames correctly bare-faced")
    if tightest[1]:
        print(f"least overlap: {tightest[0] * 100:.0f}% at {tightest[1]}")
    if clearance[1]:
        print(f"tightest collar: {clearance[0]:.0f} row(s) below the last eye "
              f"pixel at {clearance[1]}")
    print(f"crown furthest from its own face: {drifted[0]:.1f}px"
          f"{f' at {drifted[1]}' if drifted[1] else ''}"
          f" — {independent} measured independently of the anchor table, "
          f"{selfsame} against the face anchor itself")
    if worst[1]:
        print(f"faintest: {worst[0]:.2f}:1 at {worst[1]}")
    if failures:
        unique = sorted(set(failures))
        print(f"\n{len(unique)} FAILED:")
        for line in unique[:20]:
            print(f"  {line}")
        if len(unique) > 20:
            print(f"  ... and {len(unique) - 20} more")
        return 1
    print("all pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
