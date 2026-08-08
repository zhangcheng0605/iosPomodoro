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

Nothing here is restated. The footings come out of `Place.swift`, the ground
line out of `Stray.swift`, the card's geometry and the tower's measurements out
of `PostcardView.swift`, the buddies' footprints out of the shipped sprites,
and what counts as a surface out of `generate_scenes.py`'s own grid of palette
indices. Break any one of them and this fails; edit only this file and it
cannot pass.

That sentence had to be earned twice. The tower rules were written first as
`max(soles - lift, height)` in Python — the Swift's clamp copied out by hand —
and deleting the clamp from `PostcardView` altogether still passed, because
this file was computing the clamped answer from unclamped code. `parse_tower`
now requires the clamp to *be there*, in shape, or refuses to run at all. Every
rule below has been checked by deliberately breaking the thing it guards and
watching it fail; a green run on code you have broken on purpose is the only
evidence a checker checks anything.

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
worth having: the buddy is on the card, out from under the stamp, over
something that is not sky and not water, under a tower that fits, and the six
places that were never wrong have not moved a pixel.

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


def parse_card():
    """The card's geometry, out of PostcardView.swift.

    Returns the picture's size in points and, for each of the two pictures that
    draw a *place*, how far the soles sit above the bottom edge and how tall
    the buddy is. The panorama draws `HomesteadScene` and has no place in it,
    so it is deliberately not here.
    """
    source = read(CARD_FILE)

    width = re.search(r"var width: CGFloat = ([\d.]+)", source)
    height = re.search(r"var pictureHeight: CGFloat \{ ([\d.]+) \* scale \}", source)
    if not width or not height:
        raise SystemExit("could not parse the card's size from PostcardView.swift")

    kinds = {}
    for name in ("bellTowerPicture", "placePicture"):
        block = re.search(
            rf"var {name}: some View \{{(.*?)\n    \}}", source, re.S)
        if not block:
            raise SystemExit(f"could not find {name} in PostcardView.swift")
        feet = re.search(r"let feet: CGFloat = ([\d.]+) \* scale", block.group(1))
        size = re.search(r"BuddySprite\(.*?size: ([\d.]+) \* scale\)", block.group(1))
        if not feet or not size:
            raise SystemExit(f"could not parse {name}'s feet/buddy size")
        kinds[name] = (float(feet.group(1)), float(size.group(1)))

    stamp = re.search(r"\.frame\(width: ([\d.]+) \* scale, height: ([\d.]+) \* scale\)\n"
                      r"\s*\.background\(Theme\.cream", source)
    pad = re.search(r"stamp\n(?:.*\n)*?\s*\.padding\(([\d.]+) \* scale\)", source)
    if not stamp or not pad:
        raise SystemExit("could not parse the stamp's box from PostcardView.swift")

    return (float(width.group(1)), float(height.group(1))), kinds, (
        float(stamp.group(1)), float(stamp.group(2)), float(pad.group(1)))


def parse_tower():
    """The bell tower's own measurements, and how far it floats.

    Four numbers, all read out of `BellTower` and `PostcardView` rather than
    typed here. The tower is the one thing on a postcard the app *invents*
    rather than loads, which is exactly why nothing else can see it go wrong:
    there is no asset to be missing and no palette index to be sea. It moved
    with the buddy when the footings did, and at Cloudspire — whose footing is
    most of the way up the card — an unclamped tower put its roof twenty-seven
    points above the picture, where the card's corner radius quietly ate it.

    The clamp is *parsed*, not assumed, and that distinction is the whole
    value of this function. The first draft of it read the four numbers and
    then recomputed the tower's box as `max(soles - lift, height)` — which is
    the clamp written out a second time, in Python. Deleting the clamp from
    the Swift altogether left this file computing the clamped answer from the
    unclamped code and reporting all pass, exactly as `check_touch.py` did
    with its five deliberate breaks. So the shape is required here: no
    `max(...)` in `towerStanding` against a ceiling of the tower's own height,
    no parse, no run.
    """
    source = read(CARD_FILE)
    found = {}
    for key in ("roofHeight", "shaftHeight", "width"):
        match = re.search(rf"static let {key}: CGFloat = ([\d.]+)", source)
        if not match:
            raise SystemExit(f"could not parse BellTower.{key} from PostcardView.swift")
        found[key] = float(match.group(1))
    lift = re.search(r"static let towerLift: CGFloat = ([\d.]+)", source)
    if not lift:
        raise SystemExit("could not parse PostcardView.towerLift from PostcardView.swift")

    block = re.search(
        r"func towerStanding\(.*?\) -> CGSize \{(.*?)\n    \}", source, re.S)
    if not block:
        raise SystemExit("could not find PostcardView.towerStanding in PostcardView.swift")
    body = block.group(1)
    if not re.search(
        r"let ceiling = BellTower\.height \* scale - pictureHeight", body
    ) or not re.search(
        r"height: max\(stand\.height - Self\.towerLift \* scale, ceiling\)", body
    ):
        raise SystemExit(
            "PostcardView.towerStanding is no longer clamped against the "
            "tower's own height — Cloudspire's footing is high enough in the "
            "frame that the roof leaves the picture without it, and the card's "
            "corner radius takes it silently. Restore the clamp, or teach this "
            "function the new shape and re-derive the geometry below.")

    return found["roofHeight"] + found["shaftHeight"], found["width"], float(lift.group(1))


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

def preview(footings, size2d, kinds, tower, kind, path):
    """Composite the eight cards and save them, because a green checker is not
    a look. Four times of day across, one place per row.

    This is the half of the file that catches what no rule can. Cloudspire's
    original bug — the buddy halfway down a cliff face — is *rock* under the
    feet at the palette level and always will be, so it passes every mechanical
    test in here and is obvious the moment anybody renders the card. Same
    arithmetic as `main`, same crop, same sprite; only the eye is different.
    """
    width, height = size2d
    scale = 3
    parts = scenes.PARTS
    places = [name for name, _, _ in scenes.PLACES]
    feet, size = kinds[kind]
    tower_height, tower_width, lift = tower
    aspect = scene_aspect()
    full = width * aspect
    top = min(max(0.0, parse_ground_line() * full - height + feet),
              max(0.0, full - height))

    sheet = Image.new("RGBA", (int(width * scale * len(parts)),
                               int(height * scale * len(places))))
    sprite = Image.open(os.path.join(
        ASSETS, "buddy_cat_awake.imageset", "buddy_cat_awake.png")).convert("RGBA")
    sprite = sprite.resize((int(size * scale), int(size * scale)), Image.NEAREST)

    for row, place in enumerate(places):
        fx, fy = footings[place]
        for column, part in enumerate(parts):
            name = f"scene_{place}_{part}"
            art = Image.open(os.path.join(
                ASSETS, f"{name}.imageset", f"{name}.png")).convert("RGBA")
            art = art.resize((int(width * scale), int(round(full * scale))),
                             Image.NEAREST)
            tile = Image.new("RGBA", (int(width * scale), int(height * scale)))
            tile.alpha_composite(art, (0, -int(round(top * scale))))
            soles = fy * full - top
            cx = fx * width

            # The tower goes on first: the buddy stands in front of it.
            if kind == "bellTowerPicture":
                bottom = max(soles - lift, tower_height)
                block = Image.new("RGBA", (int(tower_width * scale),
                                           int(tower_height * scale)),
                                  (60, 48, 42, 210))
                tile.alpha_composite(block, (
                    int(round((cx - tower_width / 2) * scale)),
                    int(round((bottom - tower_height) * scale)),
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
    (width, height), kinds, (stamp_w, stamp_h, pad) = parse_card()
    tower_height, tower_width, lift = parse_tower()
    left_edge, right_edge, buddies = footprint()
    aspect = scene_aspect()
    grids = {name: draw() for name, draw, _ in scenes.PLACES}

    failures = []
    checked = 0
    stamp_box = (width - pad - stamp_w, pad, width - pad, pad + stamp_h)

    for kind, (feet, size) in sorted(kinds.items()):
        full = width * aspect
        top = min(max(0.0, ground_line * full - height + feet),
                  max(0.0, full - height))

        for place in sorted(grids):
            grid = grids[place]
            if place not in footings:
                failures.append(f"{place}: no footing — Place.footing lost a case")
                continue
            fx, fy = footings[place]

            # Where the buddy ends up on the card, in points.
            soles = fy * full - top          # down from the picture's top edge
            crown = soles - size
            cx = fx * width
            box = (cx - size / 2, crown, cx + size / 2, soles)
            checked += 1

            # 1. Inside the window. A footing the crop cannot see is a buddy
            #    that has walked off the card — the picture would show the
            #    place and nobody in it.
            if crown < 0 or soles > height:
                failures.append(
                    f"{kind}/{place}: the buddy does not fit the picture "
                    f"(top {crown:.1f}, soles {soles:.1f} of {height:.0f})")
            if box[0] < 0 or box[2] > width:
                failures.append(
                    f"{kind}/{place}: the buddy runs off the side "
                    f"({box[0]:.1f}..{box[2]:.1f} of {width:.0f})")

            # 2. Never under the stamp. The stamp is opaque and the buddy is
            #    the subject; a card with a franked cat on it is a bad card.
            if overlaps(box, stamp_box):
                failures.append(f"{kind}/{place}: the buddy is under the stamp")

            # 2b. The bell tower, which moves with the buddy.
            #
            #     Nothing else in this repo can see this one: the tower is
            #     drawn by `BellTower` rather than loaded, so there is no
            #     asset to be missing and no palette index to be wrong, and
            #     the card is unreachable without twenty-four lit hours.
            if kind == "bellTowerPicture":
                base = max(soles - lift, tower_height)
                tower_box = (cx - tower_width / 2, base - tower_height,
                             cx + tower_width / 2, base)
                if tower_box[1] < 0 or tower_box[3] > height:
                    failures.append(
                        f"{kind}/{place}: the tower does not fit the picture "
                        f"(roof {tower_box[1]:.1f}, base {tower_box[3]:.1f} "
                        f"of {height:.0f}) — its roof is cut off")
                if tower_box[0] < 0 or tower_box[2] > width:
                    failures.append(
                        f"{kind}/{place}: the tower runs off the side "
                        f"({tower_box[0]:.1f}..{tower_box[2]:.1f})")
                if overlaps(tower_box, stamp_box):
                    failures.append(f"{kind}/{place}: the tower is under the stamp")
                # The card is called "beneath a bell tower". The buddy has to
                # be *under* it — its head at or below the tower's base line,
                # and never poking out above the roof.
                if not (tower_box[1] <= crown <= tower_box[3]):
                    failures.append(
                        f"{kind}/{place}: the buddy is not beneath the tower "
                        f"(head {crown:.1f}, tower {tower_box[1]:.1f}"
                        f"..{tower_box[3]:.1f})")

            # 3. Standing on something, all the way across its feet. Read out
            #    of the generator's grid, which is the only place in this
            #    repo that knows the sea from the shore.
            row = int(fy * scenes.H)
            span = (
                int(round((cx - size / 2 + size * left_edge) / width * scenes.W)),
                int(round((cx - size / 2 + size * right_edge) / width * scenes.W)),
            )
            if not (0 <= row < scenes.H):
                failures.append(f"{kind}/{place}: footing row {row} is off the art")
                continue
            if place not in SOAKING:
                for column in range(max(0, span[0]), min(scenes.W, span[1])):
                    under = int(grid[row, column])
                    if under in UNSTANDABLE:
                        failures.append(
                            f"{kind}/{place}: nothing to stand on at scene "
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

    # 5. No stale exemptions. A reason written about a place that no longer
    #    exists is a hole in the check nobody would ever notice.
    for place in sorted(SOAKING):
        if place not in grids:
            failures.append(f"SOAKING names '{place}', which is not a place")

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
    for place in sorted(set(SOAKING) & set(moved)):
        failures.append(
            f"'{place}' has both a moved footing {footings[place]} and a "
            f"SOAKING exemption — pick one: either the footing is ground, or "
            f"the buddy is in the water on purpose at {default}")

    print(f"checked {checked} buddy placements across "
          f"{len(grids)} places x {len(kinds)} card kinds, "
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
        for kind in sorted(kinds):
            preview(footings, (width, height), kinds,
                    (tower_height, tower_width, lift), kind, f"{stem}_{kind}.png")

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
