"""Check that the buddy on a postcard is standing on something.

A postcard crops a phone-shaped painting down to a 320x168 window and stands
the buddy in it. For six places that is one number — `Stray.groundLine`, in the
middle — and it is right. For the two the stray never visits it was wrong in
the way nothing else in the toolchain could see: Harbor Isle is open water down
the whole centre column at *every* height, so the cat stood on the sea, and
Cloudspire's rock is a wedge in clear air, so the cat stood halfway down a
cliff face. `Place.footing` moves those two onto the jetty and the grassy cap,
and this is what says so — and what will say so again if a scene is redrawn
underneath them.

The bell tower is checked too. It moved with the buddy — a tower planted in the
Harbor's open water with the cat over on the jetty would have been two bugs
instead of one — and moving it broke Cloudspire, whose footing is high enough
up the card that the roof left the picture and the corner radius ate it. That
one is invisible to everything else in `tools/`: the tower is the only thing on
a postcard the app *draws* rather than loads, so there is no asset to be
missing and no palette index to be sea.

## What this file used to prove, and why it was worth nothing

Read `Place.footing`, work out where that lands on the card, look at the pixel:
that was the shape of it, and every step after the first was a second copy of
`PostcardView`'s arithmetic written in Python. So it proved the *footings in the
model* are over ground — which nothing on a phone renders.

A verifier deleted the body of `PostcardView.standing` and put back the line it
was written to replace, `CGSize(width: 0, height: -feet)`. That is the original
bug, exactly: the cat is centred at the ground line again, which at Harbor Isle
is the open sea. This file printed `checked 16 buddy placements ... all pass`.
It was worse than no checker, because it read as coverage.

So no arithmetic is restated here any more. `cropTop`, `standing` and
`towerStanding` are read out of the Swift and **translated**, and the checker
*runs the view's own expressions*; the `.offset` each sprite actually carries is
read out of its picture block and applied the way a bottom-aligned `ZStack`
would apply it. Where the feet land is therefore computed the way the app
computes it, and the palette index under them is the app's answer, not a
restatement of the model. Delete the fix and this goes red on the pixels.

Nothing else is restated either. The footings come out of `Place.swift`, the
ground line out of `Stray.swift`, the card's geometry and the tower's
measurements out of `PostcardView.swift`, the buddies' footprints out of the
shipped sprites, and what counts as a surface out of `generate_scenes.py`'s own
grid of palette indices. Break any one of them and this fails; edit only this
file and it cannot pass.

That sentence had to be earned three times. The tower rules were written first
as `max(soles - lift, height)` in Python — the Swift's clamp copied out by hand
— and deleting the clamp from `PostcardView` altogether still passed, because
this file was computing the clamped answer from unclamped code. Then the same
mistake turned out to be underneath the whole file, not just the tower. The
answer both times was to stop keeping a copy: the translator below has no
opinion about what the view *should* say, and refuses to run rather than guess
when it meets a shape it cannot read. Every rule has been checked by
deliberately breaking the thing it guards and watching it fail; a green run on
code you have broken on purpose is the only evidence a checker checks anything.

Be honest about what is not covered. A palette index knows the sea from the
shore, so the Harbor half of the bug is caught mechanically and always will be.
It cannot tell the *top* of Cloudspire's island from the *side* of it — both
are rock, and a ground plane painted in perspective is solid for fifty rows
above where anything stands on it, so no rule about surfaces could pass Meadow
and fail a cliff face. Measured, not assumed: at the old footing Cloudspire's
centre column is STONE with twenty rows of STONE above it, while Meadow's
correct footing has *thirteen* rows of cottage wall above it — the good case
looks more buried than the bad one, and any headroom rule ranks them the wrong
way round. That half was found by compositing the card and looking at it, which
is what `--preview` is for. What this file guarantees is narrower and still
worth having: the buddy the *view draws* is on the card, out from under the
stamp, over something that is not sky and not water, under a tower that fits,
and the six places that were never wrong have not moved a pixel.

    python3 tools/check_postcard.py [--preview [stem]]

`--preview` writes one sheet per card kind — `<stem>_placePicture.png` and
`<stem>_bellTowerPicture.png` — eight places down, four times of day across,
and it runs whether the check passed or failed, because a composite is most
wanted on the run that just went red.

Exits non-zero if anything fails.
"""
import os
import re
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import check_stray as stray_check
import generate_scenes as scenes

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")
PLACE_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "Place.swift")
STRAY_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "Stray.swift")
CARD_FILE = os.path.join(ROOT, "Pawmodoro", "Views", "PostcardView.swift")

# What a buddy cannot stand on. The same list the stray is held to, imported
# rather than copied — a second opinion about what water is would be one more
# thing to keep in step, and the sea at Harbor is precisely the pixel both
# files exist to notice.
UNSTANDABLE = stray_check.UNSTANDABLE

# Where the buddy is in the water on purpose, and why.
#
# An allowlist with a written reason, the same shape `check_crossing.py` uses
# for the counters it lets shrink: the point of it is that adding a place here
# is a sentence somebody has to write and a reviewer can argue with, rather
# than a threshold quietly loosened until nothing fails.
SOAKING = {
    "onsen": "Moonlit Onsen is a hot spring, and the buddy stands ankle-deep "
             "in it. That is the place — its blurb is 'Steam, stone, and a "
             "warm soak', and there is a soaking pose in the sprite sheet for "
             "the capybara. A card of an onsen with the cat standing "
             "primly on the stones beside it would be the worse picture.",
}


# ---------------------------------------------------------------- the sources

def read(path):
    with open(path) as handle:
        return handle.read()


def parse_ground_line():
    found = re.search(r"static let groundLine: Double = ([\d.]+)", read(STRAY_FILE))
    if not found:
        raise SystemExit("could not find Stray.groundLine in Stray.swift")
    return float(found.group(1))


def parse_footings(ground_line):
    """`Place.footing`, per case, with the `default:` arm expanded.

    The default arm is written as `Stray.groundLine`, so it is resolved from
    Stray.swift rather than from the literal 0.79 that used to be typed here —
    which is how this stays honest if that line ever moves.
    """
    source = read(PLACE_FILE)
    cases = re.findall(r"^\s*case (\w+)$", source, re.M)
    if not cases:
        raise SystemExit("could not find Place's cases in Place.swift")

    block = re.search(r"var footing: Footing \{\n\s*switch self \{(.*?)\n\s{4}\}",
                      source, re.S)
    if not block:
        raise SystemExit("could not find Place.footing in Place.swift")
    body = block.group(1)

    footings = {}
    for labels, x, y in re.findall(
        r"case ((?:\.\w+,?\s*)+): Footing\(x: ([\d.]+), y: ([\d.]+)\)", body
    ):
        for name in re.findall(r"\.(\w+)", labels):
            footings[name] = (float(x), float(y))

    fallback = re.search(
        r"default: Footing\(x: ([\d.]+), y: Stray\.groundLine\)", body)
    if not fallback:
        raise SystemExit(
            "could not parse Place.footing's default arm — it is expected to "
            "read `Stray.groundLine`, so that one line still decides six places")
    default = (float(fallback.group(1)), ground_line)

    for name in cases:
        footings.setdefault(name, default)
    return footings, default


# ------------------------------------------------- the view's own arithmetic
#
# Three tiny Swift functions decide where a sprite lands on a card, and this
# section runs them rather than agreeing with them. Everything below is
# translation: no expression in `PostcardView` is repeated here in any form, so
# there is nothing left for the Swift and the Python to drift apart about.
#
# The translator is deliberately small and deliberately brittle. It knows the
# handful of tokens these three functions are made of, and if it meets anything
# else it stops with a message rather than guessing — because guessing is how
# the first version of this file ended up computing the *right* answer from the
# *wrong* code and reporting all pass.

def _size(width, height):
    """Swift's `CGSize`, as the pair this file works in."""
    return (width, height)


def _offset(x=0.0, y=0.0):
    """SwiftUI's `.offset(x:y:)`, as a pair. Either argument may be omitted,
    exactly as the modifier allows — `.offset(y: -feet)` is the line the fix
    replaced, and it has to translate."""
    return (x, y)


# Swift on the left, this file's vocabulary on the right, applied in order.
# `stand.width` has to be rewritten before argument labels are, or `width:`
# rules would start eating property accesses.
SUBSTITUTIONS = (
    (r"//[^\n]*", ""),
    (r"\bcropTop\(name, feet: feet\)", "crop_top(feet)"),
    (r"\btowerStanding\(name, feet: feet\)", "tower_standing(feet)"),
    (r"\bstanding\(name, feet: feet\)", "standing(feet)"),
    (r"\bcard\.resolvedPlace\.footing\b", "_footing()"),
    (r"\bSelf\.sceneAspect\(name\)", "aspect"),
    (r"\bSelf\.towerLift\b", "tower_lift"),
    (r"\bStray\.groundLine\b", "ground_line"),
    (r"\bBellTower\.height\b", "tower_height"),
    (r"\bpictureHeight\b", "picture_height"),
    (r"\bstand\.width\b", "stand[0]"),
    (r"\bstand\.height\b", "stand[1]"),
    (r"\btower\.width\b", "tower[0]"),
    (r"\btower\.height\b", "tower[1]"),
    (r"\bCGFloat\(", "("),
    (r"\bCGSize\(", "_size("),
    # The space goes with it: `let full = …` has to come out at the same
    # indentation as the `return` below it or Python will not read the block.
    (r"\blet\s+", ""),
    (r"\b(width|height|x|y|feet)\s*:\s*", r"\1="),
)

# Every name the translated code is allowed to mention. Anything else means
# the Swift has grown a concept this file has never heard of, and the honest
# response is to stop.
VOCABULARY = {
    "return", "min", "max", "_size", "_offset", "_footing",
    "aspect", "ground_line", "picture_height", "width", "scale", "feet",
    "tower_height", "tower_lift", "footing", "footing.x", "footing.y",
    "full", "soles", "ceiling", "stand", "tower",
    "crop_top", "standing", "tower_standing",
}


def mentions(text):
    """Every name the translated code refers to.

    Argument labels are dropped first — `_size(width=…, height=…)` is the
    translation of `CGSize(width:height:)`, and those two words are the label,
    not something the expression reads.
    """
    text = re.sub(r"(?<=[(,])\s*[A-Za-z_]\w*\s*=", " ", text)
    return set(re.findall(
        r"[A-Za-z_][A-Za-z_0-9]*(?:\.[A-Za-z_][A-Za-z_0-9]*)*", text))


def translate(label, body, env):
    """Turn one small Swift body into a Python callable of `feet`."""
    text = body
    for pattern, replacement in SUBSTITUTIONS:
        text = re.sub(pattern, replacement, text)

    unknown = sorted(name for name in mentions(text) if name not in VOCABULARY)
    if unknown:
        raise SystemExit(
            f"{label} in PostcardView.swift now uses "
            f"{', '.join(unknown)}, which tools/check_postcard.py cannot "
            f"translate. This file runs the view's arithmetic instead of "
            f"keeping a copy of it, so a new shape means teaching the "
            f"translator — never assuming the old answer, which is how a "
            f"deleted fix once passed clean.")

    exec(f"def _translated(feet):\n{text}\n", env)
    return env.pop("_translated")


def evaluate(label, expression, env):
    """One translated Swift expression, evaluated in the same vocabulary."""
    text = expression
    for pattern, replacement in SUBSTITUTIONS:
        text = re.sub(pattern, replacement, text)
    unknown = sorted(name for name in mentions(text) if name not in VOCABULARY)
    if unknown:
        raise SystemExit(
            f"{label}: cannot translate `{expression.strip()}` — it mentions "
            f"{', '.join(unknown)}")
    return eval(text, env)


class Footing:
    """`Place.Footing`, so `footing.x` translates to itself."""

    def __init__(self, x, y):
        self.x = x
        self.y = y


def body_of(source, signature, label):
    block = re.search(rf"func {signature}\(.*?\) -> CG\w+ \{{(.*?)\n    \}}",
                      source, re.S)
    if not block:
        raise SystemExit(f"could not find PostcardView.{label} in "
                         f"PostcardView.swift")
    return block.group(1)


def parse_view(ground_line, aspect):
    """The card's geometry and the three functions that place a sprite in it.

    Returns the picture's size in points, the stamp's box, a per-kind record of
    what each picture draws and where it offsets it, and a `place(footing,
    kind)` that answers with the sprite's soles and centre — computed by the
    Swift, translated.

    The panorama draws `HomesteadScene` and has no place in it, so it is
    deliberately not here.
    """
    source = read(CARD_FILE)

    width = re.search(r"var width: CGFloat = ([\d.]+)", source)
    divisor = re.search(r"var scale: CGFloat \{ width / ([\d.]+) \}", source)
    height = re.search(r"var pictureHeight: CGFloat \{ ([\d.]+) \* scale \}", source)
    if not width or not divisor or not height:
        raise SystemExit("could not parse the card's size from PostcardView.swift")
    width = float(width.group(1))
    scale = width / float(divisor.group(1))
    picture_height = float(height.group(1)) * scale

    tower = {}
    for key in ("roofHeight", "shaftHeight", "width"):
        match = re.search(rf"static let {key}: CGFloat = ([\d.]+)", source)
        if not match:
            raise SystemExit(f"could not parse BellTower.{key} from PostcardView.swift")
        tower[key] = float(match.group(1))
    if not re.search(
        r"static var height: CGFloat \{ roofHeight \+ shaftHeight \}", source
    ):
        raise SystemExit("BellTower.height is no longer roof + shaft — re-read it")
    tower_height = tower["roofHeight"] + tower["shaftHeight"]
    lift = re.search(r"static let towerLift: CGFloat = ([\d.]+)", source)
    if not lift:
        raise SystemExit("could not parse PostcardView.towerLift from PostcardView.swift")

    # The environment the translated Swift runs in. `current` is the place
    # being checked; `_footing` hands it over, so `let footing =
    # card.resolvedPlace.footing` translates to a call rather than to a
    # self-assignment Python would read as an unbound local.
    current = [Footing(0.5, ground_line)]
    env = {
        "_size": _size, "_offset": _offset, "min": min, "max": max,
        "_footing": lambda: current[0],
        "aspect": aspect, "ground_line": ground_line, "width": width,
        "picture_height": picture_height, "scale": scale,
        "tower_height": tower_height, "tower_lift": float(lift.group(1)),
    }
    env["crop_top"] = translate(
        "cropTop", body_of(source, "cropTop", "cropTop"), env)
    env["standing"] = translate(
        "standing", body_of(source, "standing", "standing"), env)
    env["tower_standing"] = translate(
        "towerStanding", body_of(source, "towerStanding", "towerStanding"), env)

    kinds = {}
    for name in ("bellTowerPicture", "placePicture"):
        block = re.search(rf"var {name}: some View \{{(.*?)\n    \}}", source, re.S)
        if not block:
            raise SystemExit(f"could not find {name} in PostcardView.swift")
        block = block.group(1)

        feet = re.search(r"let feet: CGFloat = ([\d.]+) \* scale", block)
        if not feet:
            raise SystemExit(f"could not parse {name}'s feet")
        if "ZStack(alignment: .bottom)" not in block:
            raise SystemExit(
                f"{name} is no longer a bottom-aligned ZStack. Every offset in "
                f"it is measured from the bottom edge of the picture, here and "
                f"in the Swift; re-derive both before changing it.")
        if not re.search(r"\.frame\(width: width, height: pictureHeight\)", block):
            raise SystemExit(f"{name} no longer sizes itself to the picture")
        if not re.search(r"sceneImage\(name, feet: feet\)", block):
            raise SystemExit(
                f"{name} no longer draws its scene through sceneImage — the "
                f"crop under the buddy's feet is no longer the one this checks")

        # What each sprite is offset by, taken from the modifier it actually
        # carries. A sprite with no `.offset` sits at the bottom centre, which
        # is what an empty expression evaluates to — and is exactly the state
        # the Harbor bug was in.
        sprites = {}
        for key, call in (("buddy", r"BuddySprite\([^)]*?size: ([\d.]+) \* scale\)"),
                          ("tower", r"BellTower\(scale: scale\)()")):
            # No `\s*` outside the optional group: a greedy run of whitespace
            # in front of an optional match swallows the newline, the group
            # then matches empty, and every sprite reads as unoffset — which
            # is the bug this whole file exists for, silently reintroduced by
            # a regex.
            found = re.search(call + r"(?:\s*\n\s*\.offset\(([^)]*)\))?", block)
            if not found:
                if key == "tower":
                    continue
                raise SystemExit(f"could not find {name}'s {key}")
            sprites[key] = (float(found.group(1) or 0.0) * scale,
                            found.group(2) or "")
        if "buddy" not in sprites:
            raise SystemExit(f"could not find {name}'s buddy sprite")
        kinds[name] = (float(feet.group(1)) * scale, sprites)

    stamp = re.search(r"\.frame\(width: ([\d.]+) \* scale, height: ([\d.]+) \* scale\)\n"
                      r"\s*\.background\(Theme\.cream", source)
    pad = re.search(r"stamp\n(?:.*\n)*?\s*\.padding\(([\d.]+) \* scale\)", source)
    if not stamp or not pad:
        raise SystemExit("could not parse the stamp's box from PostcardView.swift")

    def place(footing, kind):
        """Where the view puts things, for one place and one card kind.

        Returns the buddy's soles and centre in card points, the crop the
        picture behind it uses, and the tower's base and centre if the card has
        one. Every number in here came out of the Swift a moment ago.
        """
        current[0] = Footing(*footing)
        feet, sprites = kinds[kind]
        env["stand"] = env["standing"](feet)
        env["tower"] = env["tower_standing"](feet)
        env["feet"] = feet

        size, expression = sprites["buddy"]
        dx, dy = evaluate(f"{kind}/buddy", f"_offset({expression})", env)
        buddy = (picture_height + dy, width / 2 + dx, size)

        tower_at = None
        if "tower" in sprites:
            _, expression = sprites["tower"]
            tx, ty = evaluate(f"{kind}/tower", f"_offset({expression})", env)
            tower_at = (picture_height + ty, width / 2 + tx)
        return buddy, env["crop_top"](feet), tower_at

    return ((width, picture_height),
            (float(stamp.group(1)) * scale, float(stamp.group(2)) * scale,
             float(pad.group(1)) * scale),
            sorted(kinds), (tower_height * scale, tower["width"] * scale),
            place)


def scene_aspect():
    """How tall the exported art is for its width — measured off a shipped PNG,
    which is what `PostcardView.sceneAspect` does rather than trusting a
    number."""
    name = "scene_meadow_day"
    path = os.path.join(ASSETS, f"{name}.imageset", f"{name}.png")
    if not os.path.exists(path):
        raise SystemExit(f"{name}: missing — run tools/generate_scenes.py")
    art = Image.open(path)
    return art.size[1] / art.size[0]


def footprint():
    """How wide a buddy's feet are, as fractions of its box.

    The widest opaque span across the bottom eighth of every shipped awake
    sprite: it is the part that has to be over something. Taking the whole box
    would demand ground under a tail held out in mid-air, and taking the centre
    pixel alone would pass a cat with one paw on a jetty and the rest over the
    water.
    """
    left, right = 1.0, 0.0
    seen = 0
    for entry in sorted(os.listdir(ASSETS)):
        if not re.fullmatch(r"buddy_\w+_awake\.imageset", entry):
            continue
        name = entry[:-len(".imageset")]
        image = np.array(Image.open(
            os.path.join(ASSETS, entry, f"{name}.png")).convert("RGBA"))
        alpha = image[..., 3] > 0
        base = alpha[int(alpha.shape[0] * 7 / 8):]
        columns = np.where(base.any(axis=0))[0]
        if not len(columns):
            continue
        seen += 1
        left = min(left, columns.min() / alpha.shape[1])
        right = max(right, (columns.max() + 1) / alpha.shape[1])
    if seen == 0:
        raise SystemExit("no buddy sprites found — run tools/generate_sprites.py")
    return left, right, seen


# ---------------------------------------------------------------- the picture

def preview(footings, size2d, tower, place, kind, path):
    """Composite the eight cards and save them, because a green checker is not
    a look. Four times of day across, one place per row.

    This is the half of the file that catches what no rule can. Cloudspire's
    original bug — the buddy halfway down a cliff face — is *rock* under the
    feet at the palette level and always will be, so it passes every mechanical
    test in here and is obvious the moment anybody renders the card. Same
    arithmetic as `main` — which is to say the view's — same crop, same sprite;
    only the eye is different.
    """
    width, height = size2d
    scale = 3
    parts = scenes.PARTS
    places = [name for name, _, _ in scenes.PLACES]
    tower_height, tower_width = tower
    aspect = scene_aspect()
    full = width * aspect

    sheet = Image.new("RGBA", (int(width * scale * len(parts)),
                               int(height * scale * len(places))))
    art_sprite = Image.open(os.path.join(
        ASSETS, "buddy_cat_awake.imageset", "buddy_cat_awake.png")).convert("RGBA")

    for row, name in enumerate(places):
        (soles, cx, size), top, tower_at = place(footings[name], kind)
        sprite = art_sprite.resize((int(size * scale), int(size * scale)),
                                   Image.NEAREST)
        for column, part in enumerate(parts):
            asset = f"scene_{name}_{part}"
            art = Image.open(os.path.join(
                ASSETS, f"{asset}.imageset", f"{asset}.png")).convert("RGBA")
            art = art.resize((int(width * scale), int(round(full * scale))),
                             Image.NEAREST)
            tile = Image.new("RGBA", (int(width * scale), int(height * scale)))
            tile.alpha_composite(art, (0, -int(round(top * scale))))

            # The tower goes on first: the buddy stands in front of it.
            if tower_at is not None:
                base, tcx = tower_at
                block = Image.new("RGBA", (int(tower_width * scale),
                                           int(tower_height * scale)),
                                  (60, 48, 42, 210))
                tile.alpha_composite(block, (
                    int(round((tcx - tower_width / 2) * scale)),
                    int(round((base - tower_height) * scale)),
                ))

            tile.alpha_composite(sprite, (
                int(round((cx - size / 2) * scale)),
                int(round((soles - size) * scale)),
            ))
            sheet.alpha_composite(tile, (int(column * width * scale),
                                         int(row * height * scale)))
    sheet.save(path)
    print(f"preview: {path} — {kind}, one row per place ("
          f"{', '.join(places)}), {', '.join(parts)} across")


# ------------------------------------------------------------------ the rules

def overlaps(a, b):
    """Two (left, top, right, bottom) boxes, in points."""
    return a[0] < b[2] and a[2] > b[0] and a[1] < b[3] and a[3] > b[1]


def main():
    ground_line = parse_ground_line()
    footings, default = parse_footings(ground_line)
    aspect = scene_aspect()
    ((width, height), (stamp_w, stamp_h, pad), kind_names,
     (tower_height, tower_width), place) = parse_view(ground_line, aspect)
    left_edge, right_edge, buddies = footprint()
    grids = {name: draw() for name, draw, _ in scenes.PLACES}
    full = width * aspect

    failures = []
    checked = 0
    stamp_box = (width - pad - stamp_w, pad, width - pad, pad + stamp_h)

    for kind in kind_names:
        for name in sorted(grids):
            grid = grids[name]
            if name not in footings:
                failures.append(f"{name}: no footing — Place.footing lost a case")
                continue

            # Where the buddy ends up on the card, in points — asked of the
            # view's own `standing` and its own `.offset`, not worked out here.
            (soles, cx, size), top, tower_at = place(footings[name], kind)
            crown = soles - size
            box = (cx - size / 2, crown, cx + size / 2, soles)
            checked += 1

            # 1. Inside the window. A footing the crop cannot see is a buddy
            #    that has walked off the card — the picture would show the
            #    place and nobody in it.
            if crown < 0 or soles > height:
                failures.append(
                    f"{kind}/{name}: the buddy does not fit the picture "
                    f"(top {crown:.1f}, soles {soles:.1f} of {height:.0f})")
            if box[0] < 0 or box[2] > width:
                failures.append(
                    f"{kind}/{name}: the buddy runs off the side "
                    f"({box[0]:.1f}..{box[2]:.1f} of {width:.0f})")

            # 2. Never under the stamp. The stamp is opaque and the buddy is
            #    the subject; a card with a franked cat on it is a bad card.
            if overlaps(box, stamp_box):
                failures.append(f"{kind}/{name}: the buddy is under the stamp")

            # 2b. The bell tower, which moves with the buddy.
            #
            #     Nothing else in this repo can see this one: the tower is
            #     drawn by `BellTower` rather than loaded, so there is no
            #     asset to be missing and no palette index to be wrong, and
            #     the card is unreachable without twenty-four lit hours.
            if tower_at is not None:
                base, tcx = tower_at
                tower_box = (tcx - tower_width / 2, base - tower_height,
                             tcx + tower_width / 2, base)
                if tower_box[1] < 0 or tower_box[3] > height:
                    failures.append(
                        f"{kind}/{name}: the tower does not fit the picture "
                        f"(roof {tower_box[1]:.1f}, base {tower_box[3]:.1f} "
                        f"of {height:.0f}) — its roof is cut off")
                if tower_box[0] < 0 or tower_box[2] > width:
                    failures.append(
                        f"{kind}/{name}: the tower runs off the side "
                        f"({tower_box[0]:.1f}..{tower_box[2]:.1f})")
                if overlaps(tower_box, stamp_box):
                    failures.append(f"{kind}/{name}: the tower is under the stamp")
                # The card is called "beneath a bell tower". The buddy has to
                # be *under* it — its head at or below the tower's base line,
                # and never poking out above the roof.
                if not (tower_box[1] <= crown <= tower_box[3]):
                    failures.append(
                        f"{kind}/{name}: the buddy is not beneath the tower "
                        f"(head {crown:.1f}, tower {tower_box[1]:.1f}"
                        f"..{tower_box[3]:.1f})")

            # 3. Standing on something, all the way across its feet.
            #
            #    The row is the soles *as drawn* — the point the sprite's
            #    bottom edge lands on, put back into the painting through the
            #    crop the picture behind it is using. That is the whole repair:
            #    it is a fact about the rendered card, so deleting the fix from
            #    `standing` moves this row back onto the sea and fails here,
            #    where the old version read the model and never noticed.
            row = int((soles + top) / full * scenes.H)
            span = (
                int(round((cx - size / 2 + size * left_edge) / width * scenes.W)),
                int(round((cx - size / 2 + size * right_edge) / width * scenes.W)),
            )
            if not (0 <= row < scenes.H):
                failures.append(f"{kind}/{name}: the soles land on scene row "
                                f"{row}, which is off the art")
                continue
            if name not in SOAKING:
                for column in range(max(0, span[0]), min(scenes.W, span[1])):
                    under = int(grid[row, column])
                    if under in UNSTANDABLE:
                        failures.append(
                            f"{kind}/{name}: nothing to stand on at scene "
                            f"({column}, {row}) — palette index {under}")
                        break

    # 4. The six that were never wrong must still be exactly where they were.
    #    `PostcardView.standing` collapses to the old `(0, -feet)` offset when
    #    and only when the footing is the middle at the ground line, so this is
    #    what stands between a refactor and eight cards quietly moving.
    moved = sorted(name for name, value in footings.items() if value != default)
    if moved != ["cloudspire", "harbor"]:
        failures.append(
            f"footings other than Harbor and Cloudspire have moved: {moved} — "
            f"every other card is drawn at {default} and must stay there")

    # 4b. And the two that were wrong must have actually reached the card. A
    #     footing the view does not read is a footing that changes nothing:
    #     the whole of the old bug was `standing` ignoring `Place.footing`, and
    #     rule 3 only catches that where the ignored ground happens to be sea.
    #     Cloudspire's is not, so it is checked directly — the buddy must land
    #     somewhere different from where the default footing would put it.
    for kind in kind_names:
        for name in moved:
            (soles, cx, _), _, _ = place(footings[name], kind)
            (was, was_cx, _), _, _ = place(default, kind)
            if abs(soles - was) < 0.5 and abs(cx - was_cx) < 0.5:
                failures.append(
                    f"{kind}/{name} has a moved footing {footings[name]} that "
                    f"the card draws in the same place as the default "
                    f"{default} — PostcardView is not reading Place.footing")

    # 5. No stale exemptions. A reason written about a place that no longer
    #    exists is a hole in the check nobody would ever notice.
    for name in sorted(SOAKING):
        if name not in grids:
            failures.append(f"SOAKING names '{name}', which is not a place")

    # 5b. A place may have a moved footing or a soaking exemption, never both.
    #
    #     Without this, the one-line way to silence the bug this whole file
    #     exists for is to add `"harbor"` to `SOAKING` — and it reads like the
    #     others, because the Harbor genuinely is water. But the two are
    #     answers to the *same* question and only one can be right: an
    #     exemption says the buddy stands at the ordinary ground line and the
    #     water there is the point, which is true of the Onsen's hot spring
    #     and of nowhere else. A moved footing says somebody has already
    #     found the ground and put the buddy on it. Needing both means the
    #     footing was not ground after all.
    for name in sorted(set(SOAKING) & set(moved)):
        failures.append(
            f"'{name}' has both a moved footing {footings[name]} and a "
            f"SOAKING exemption — pick one: either the footing is ground, or "
            f"the buddy is in the water on purpose at {default}")

    print(f"checked {checked} buddy placements across "
          f"{len(grids)} places x {len(kind_names)} card kinds, "
          f"through PostcardView's own cropTop/standing/towerStanding, "
          f"feet {left_edge:.2f}-{right_edge:.2f} of the box "
          f"(widest of {buddies} buddies)")
    print(f"moved off the middle: {', '.join(moved) if moved else 'nothing'}")
    print(f"in the water on purpose: {', '.join(sorted(SOAKING)) or 'nowhere'}")

    # Before the verdict, not after it. A composite is most wanted on the run
    # that just failed, and a `--preview` that only fires on success is a
    # darkroom with the light on.
    if "--preview" in sys.argv:
        index = sys.argv.index("--preview")
        stem = (sys.argv[index + 1] if len(sys.argv) > index + 1
                and not sys.argv[index + 1].startswith("-")
                else os.path.join(ROOT, "postcard_preview"))
        stem = stem[:-4] if stem.endswith(".png") else stem
        for kind in kind_names:
            preview(footings, (width, height), (tower_height, tower_width),
                    place, kind, f"{stem}_{kind}.png")

    if failures:
        unique = sorted(set(failures))
        print(f"\n{len(unique)} FAILED:")
        for line in unique[:40]:
            print(f"  {line}")
        if len(unique) > 40:
            print(f"  ... and {len(unique) - 40} more")
        return 1
    print("all pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
