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
            centre = (found[0] + found[1]) / 2 if found else anchored[0]
            source = ("the eyes, found by diffing this frame against the one "
                      "that differs from it only in the eyes,"
                      if found else "the face anchor")
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
    print(f"crown furthest from its own face: {drifted[0]:.1f}px"
          f"{f' at {drifted[1]}' if drifted[1] else ''}")
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
