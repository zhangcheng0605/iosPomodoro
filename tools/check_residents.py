"""Check the homestead's neighbours: that they are there, and that you can see them.

Residents are the one part of the Homestead that is **hand-placed**. The trees
are a function of an index, so a checker can grow a hundred and twenty of them
and measure; the residents are eight positions somebody typed, and typed
positions are exactly the kind of thing that looks right in the editor and
turns out to be a pond underneath an oak.

So this asks four questions nobody can answer by eye:

1. **Do they collide?** Eight rectangles, base-anchored, on a card whose size
   the app fixes. Two overlapping is a drawing bug you would only meet at two
   hundred sessions.
2. **Do they leave a wood to look at?** This check started life the other way
   round: the residents were interleaved with the trees by depth, and it
   measured how much of each survived a full canopy. The answer was 0 % for
   the beehive and under 20 % for four others — a hundred and twenty grown
   trees cover a 350x180 card one and a third times over, so anything sharing
   that depth range is gone. A pond you lose after four months has decayed,
   whatever the storage says, so the residents moved to the near band and are
   now drawn in front of everything.

   What is left to get wrong is the opposite mistake, and it is just as
   invisible from the editor: eight neighbours walling off the hundred hours
   of wood behind them. So this now checks that they stay in the near band and
   that their combined footprint leaves the forest most of the card.
3. **Do the sprites read?** Both frames exist, the PNG's aspect matches the
   `size` the Swift lays out with (or `scaledToFit` letterboxes it), the two
   frames actually differ, and the art clears the card it stands on.
4. **Do the captions behave?** The same voice fence the Sunday Post gets: no
   congratulating, no counting, no exclaiming, and no naming a buddy — a
   resident's line is spoken *by* the buddy, whose name comes from
   `displayName(for:)` at the call site.

And, like everything else rolled off a number somebody already has, a **stored
fixture**: which residents a given session count has. Moving a threshold takes
a pond away from somebody who has one, and only the fixture notices.

    python3 tools/check_residents.py

Exits non-zero if anything fails.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import check_contrast as contrast_check
import generate_sprites as sprites

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")
RESIDENT_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "Resident.swift")
THEME_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "AppTheme.swift")

# --- The contract ----------------------------------------------------------
#
# Generated once from the shipping thresholds. A failure here is not a fixture
# that needs regenerating — it is a homestead somebody has already got, losing
# something out of it. There is no migration for that and no notification that
# would make it better.
FIXTURE = (
    (0, ()),
    (14, ()),
    (15, ("pond",)),
    (29, ("pond",)),
    (30, ("pond", "birdhouse")),
    (50, ("pond", "birdhouse", "beehive")),
    (69, ("pond", "birdhouse", "beehive")),
    (70, ("pond", "birdhouse", "beehive", "hedge")),
    (95, ("pond", "birdhouse", "beehive", "hedge", "washline")),
    (125, ("pond", "birdhouse", "beehive", "hedge", "washline", "lantern")),
    (160, ("pond", "birdhouse", "beehive", "hedge", "washline", "lantern",
           "well")),
    (200, ("pond", "birdhouse", "beehive", "hedge", "washline", "lantern",
           "well", "bench")),
    (5000, ("pond", "birdhouse", "beehive", "hedge", "washline", "lantern",
            "well", "bench")),
)

# The card `HomesteadView` draws into: full width of a padded stats page on the
# narrowest phone the app supports, and a height the view fixes outright.
CARD = (350.0, 180.0)

# The card is drawn into a rounded rectangle and clipped to it, so the last
# few points of each corner are not really there. Matches the radius in
# `HomesteadView`.
CORNER_RADIUS = 16.0

# The near band: how far down the card a resident's feet have to be. Drawn in
# front of the whole wood, anything higher than this reads as a bench hovering
# in the middle of a forest.
NEAR_BAND = 0.78

# How much of the card eight residents may cover between them. They are drawn
# over the top of the trees, so their footprint is forest nobody can see — and
# the forest is the half of this surface that took a hundred hours.
MAXIMUM_FOOTPRINT = 0.22

# A resident has to read against the card it stands on. Same bar as a tree: it
# is a shape, not a word.
MINIMUM_CONTRAST = 2.0

# How many logical pixels have to differ between a resident's two frames. Low,
# because the loop is meant to be nearly nothing — but not zero, which is what
# a copy-pasted second frame looks like.
MINIMUM_FRAME_DELTA = 3

# Words the captions may not contain. The first group congratulates, the second
# instructs, the third counts. All three are the letter's fences and they apply
# here for the same reason: this is the app talking about something you did.
FORBIDDEN = (
    "congratulations", "well done", "great", "amazing", "nice work", "keep it",
    "you should", "try to", "make sure", "remember to", "don't forget",
    "streak", "goal", "progress", "unlocked", "earned", "reward", "level",
)


def parse_residents():
    """Cases, thresholds, positions and sizes, out of `Resident.swift`."""
    source = open(RESIDENT_FILE).read()

    cases = re.findall(r"^    case (\w+)$", source, re.M)
    if not cases:
        raise SystemExit("could not parse any cases out of Resident.swift")

    def table(name, pattern):
        body = source.split(f"var {name}: ")[1].split("\n    }")[0]
        found = dict(re.findall(pattern, body))
        missing = [case for case in cases if case not in found]
        if missing:
            raise SystemExit(f"could not parse {name} for {missing}")
        return found

    arrives = table("arrivesAt", r"case \.(\w+): (\d+)")
    positions = source.split("var position: (x: Double, y: Double)")[1]
    positions = positions.split("\n    }")[0]
    found = re.findall(r"case \.(\w+): \(([\d.]+), ([\d.]+)\)", positions)
    place = {name: (float(x), float(y)) for name, x, y in found}

    sizes = source.split("var size: CGSize")[1].split("\n    }")[0]
    found = re.findall(r"case \.(\w+): CGSize\(width: ([\d.]+), height: ([\d.]+)\)",
                       sizes)
    size = {name: (float(w), float(h)) for name, w, h in found}

    for name, table_ in (("position", place), ("size", size)):
        missing = [case for case in cases if case not in table_]
        if missing:
            raise SystemExit(f"could not parse {name} for {missing}")

    return cases, {k: int(v) for k, v in arrives.items()}, place, size


def parse_lines(name):
    """One caption table, as {case: text}."""
    source = open(RESIDENT_FILE).read()
    body = source.split(f"var {name}: String")[1].split("\n    }")[0]
    return dict(re.findall(r'case \.(\w+): "([^"]*)"', body))


def rect(name, place, size):
    """Where a resident's sprite lands on the card, base-anchored: the y in
    `position` is its feet, exactly as `HomesteadView` places it."""
    x, y = place[name]
    w, h = size[name]
    cx = CARD[0] * x
    bottom = CARD[1] * y
    return (cx - w / 2, bottom - h, cx + w / 2, bottom)


def overlap(a, b):
    wide = min(a[2], b[2]) - max(a[0], b[0])
    tall = min(a[3], b[3]) - max(a[1], b[1])
    return max(0.0, wide) * max(0.0, tall)


def logical(asset):
    """The sprite as a grid of RGBA tuples at its drawn resolution."""
    from PIL import Image
    import numpy as np

    path = os.path.join(ASSETS, f"{asset}.imageset", f"{asset}.png")
    image = np.array(Image.open(path).convert("RGBA"))
    step = sprites.UPSCALE
    return image[step // 2::step, step // 2::step]


def main():
    cases, arrives, place, size = parse_residents()
    arrival_lines = parse_lines("arrivalLine")
    settled_lines = parse_lines("settledLine")
    failures = []

    # 1. The contract: who lives here at a given session count.
    for sessions, expected in FIXTURE:
        settled = tuple(c for c in cases if sessions >= arrives[c])
        if settled != expected:
            failures.append(
                f"FIXTURE: at {sessions} sessions the homestead used to have "
                f"{list(expected)} and now has {list(settled)} — this takes "
                f"something out of a garden somebody already has. See the note "
                f"above FIXTURE."
            )

    # 2. Thresholds: in the order the cases are declared, and widening. A
    #    resident on session two is a tutorial; eight of them evenly spaced is
    #    a checklist.
    ordered = [arrives[c] for c in cases]
    if ordered != sorted(ordered):
        failures.append(
            f"arrivesAt is not in declaration order ({ordered}) — "
            f"`justArrived` returns the first match and would announce them "
            f"out of sequence"
        )
    if ordered and ordered[0] < 10:
        failures.append(
            f"the first resident arrives at {ordered[0]} sessions — that is "
            f"soon enough to read as onboarding rather than as somebody "
            f"moving in"
        )
    gaps = [b - a for a, b in zip(ordered, ordered[1:])]
    if gaps != sorted(gaps):
        failures.append(
            f"the gaps between arrivals do not widen ({gaps}) — a place fills "
            f"quickly at first and then slowly, and evenly-spaced rewards are "
            f"a schedule"
        )

    # 3. On the card, and not on top of each other.
    boxes = {name: rect(name, place, size) for name in cases}
    for name, box in boxes.items():
        if box[0] < 0 or box[1] < 0 or box[2] > CARD[0] or box[3] > CARD[1]:
            failures.append(
                f"{name} hangs off the card at "
                f"({box[0]:.0f}, {box[1]:.0f})-({box[2]:.0f}, {box[3]:.0f}) "
                f"on a {CARD[0]:.0f}x{CARD[1]:.0f} homestead"
            )
    for index, first in enumerate(cases):
        for second in cases[index + 1:]:
            shared = overlap(boxes[first], boxes[second])
            if shared > 0:
                area = (boxes[first][2] - boxes[first][0]) * \
                       (boxes[first][3] - boxes[first][1])
                failures.append(
                    f"{first} and {second} overlap by {shared:.0f}pt² "
                    f"({shared / area * 100:.0f}% of {first}) — hand-placed "
                    f"furniture standing in each other"
                )

    # 4. In the near band, and leaving the wood most of the card.
    #
    #    See the note at the top of the file. This is the half of the
    #    composition nobody can judge from the editor: eight rectangles that
    #    each look small, drawn over a forest that took a hundred hours.
    for name in cases:
        if place[name][1] < NEAR_BAND:
            failures.append(
                f"{name} stands at y={place[name][1]:.2f}, above the near band "
                f"at {NEAR_BAND:.2f} — residents are drawn in front of every "
                f"tree, so one up in the wood hovers over it"
            )
    # And inside the *rounded* rectangle, not the rectangle. The card is
    #    clipped to a 16pt radius, so a well tucked into the bottom-right
    #    corner loses a slice of itself to a curve that is nowhere in the
    #    numbers — the one placement mistake a bounds check cannot see.
    for name in cases:
        clipped = corner_clipped(boxes[name])
        if clipped:
            failures.append(
                f"{name} pokes into the card's rounded corner at "
                f"({clipped[0]:.0f}, {clipped[1]:.0f}) — it will be drawn "
                f"with a bite out of it"
            )

    footprint = coverage((0, 0, CARD[0], CARD[1]), list(boxes.values()))
    share = footprint / (CARD[0] * CARD[1])
    if share > MAXIMUM_FOOTPRINT:
        failures.append(
            f"the residents cover {share * 100:.0f}% of the homestead — they "
            f"are drawn over the trees, so that is a hundred hours of wood "
            f"nobody can see"
        )

    # 5. The sprites.
    palettes = contrast_check.parse_palettes(open(THEME_FILE).read())
    pairs = 0
    faintest = (99.0, None)
    for name in cases:
        frames = []
        for index in (0, 1):
            asset = f"resident_{name}_{index}"
            path = os.path.join(ASSETS, f"{asset}.imageset", f"{asset}.png")
            if not os.path.exists(path):
                failures.append(
                    f"{asset}: missing — run tools/generate_residents.py")
                continue
            frames.append((asset, logical(asset)))
        if len(frames) != 2:
            continue

        # The aspect the app lays out with has to be the aspect that was
        # drawn, or `scaledToFit` letterboxes the sprite inside its frame and
        # everything moves a few points off where this checker thinks it is.
        grid = frames[0][1]
        drawn = (grid.shape[1], grid.shape[0])
        if drawn != tuple(int(v) for v in size[name]):
            failures.append(
                f"{name}: drawn {drawn[0]}x{drawn[1]} but `size` says "
                f"{size[name][0]:.0f}x{size[name][1]:.0f} — scaledToFit will "
                f"letterbox it"
            )

        differing = int((frames[0][1] != frames[1][1]).any(axis=2).sum())
        if differing < MINIMUM_FRAME_DELTA:
            failures.append(
                f"{name}: its two frames differ in {differing} pixels — a "
                f"loop nobody can see is a loop nobody needed"
            )

        colours = {
            tuple(v / 255.0 for v in colour)
            for asset, grid in frames
            for colour in {tuple(c) for c in grid[grid[..., 3] > 0][:, :3].tolist()}
        }
        for theme, values in sorted(palettes.items()):
            for appearance in ("light", "dark"):
                def c(key):
                    return values[key][appearance]

                # The homestead card: surface at 55 % over the page, which is
                # what `HomesteadView` draws.
                card = contrast_check.over(c("surface"), c("cream"), 0.55)
                best = max(contrast_check.contrast(colour, card)
                           for colour in colours)
                pairs += 1
                if best < faintest[0]:
                    faintest = (best, f"{name}/{theme}/{appearance}")
                if best < MINIMUM_CONTRAST:
                    failures.append(
                        f"{name}/{theme}/{appearance}: {best:.2f}:1")

    # 6. The captions.
    for label, lines in (("arrivalLine", arrival_lines),
                         ("settledLine", settled_lines)):
        for name, text in sorted(lines.items()):
            lowered = text.lower()
            for word in FORBIDDEN:
                if word in lowered:
                    failures.append(
                        f"{label}.{name} says '{word}' — a neighbour moving in "
                        f"is not an achievement and must not be worded like one")
            if "!" in text:
                failures.append(f"{label}.{name} has an exclamation mark")
            if any(ch.isdigit() for ch in text):
                failures.append(
                    f"{label}.{name} contains a number — nothing here is "
                    f"counted, least of all out loud")
            if text[:1].isupper():
                failures.append(
                    f"{label}.{name} starts with a capital — both tables are "
                    f"fragments spoken inside a longer sentence")
    for name, text in sorted(settled_lines.items()):
        if "," in text:
            failures.append(
                f"settledLine.{name} contains a comma — these are joined into "
                f"a list and an internal comma makes it unreadable")
        if text.endswith("."):
            failures.append(f"settledLine.{name} ends with a full stop")

    print(f"checked {len(cases)} residents, {len(FIXTURE)} fixture rows, "
          f"{pairs} sprite/card pairs and "
          f"{len(arrival_lines) + len(settled_lines)} captions")
    print(f"the yard covers {share * 100:.0f}% of the homestead "
          f"(ceiling {MAXIMUM_FOOTPRINT * 100:.0f}%)")
    if faintest[1]:
        print(f"faintest: {faintest[0]:.2f}:1 at {faintest[1]}")
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


def corner_clipped(box):
    """The first corner of `box` that falls outside the card's rounded edge."""
    radius = CORNER_RADIUS
    arcs = ((radius, radius), (CARD[0] - radius, radius),
            (radius, CARD[1] - radius), (CARD[0] - radius, CARD[1] - radius))
    for x in (box[0], box[2]):
        for y in (box[1], box[3]):
            for cx, cy in arcs:
                inside_x = (x < cx) if cx < CARD[0] / 2 else (x > cx)
                inside_y = (y < cy) if cy < CARD[1] / 2 else (y > cy)
                if inside_x and inside_y:
                    if (x - cx) ** 2 + (y - cy) ** 2 > radius ** 2:
                        return (x, y)
    return None


def coverage(box, others):
    """Area of `box` covered by any of `others`, counting overlap once.

    Summing the pairwise overlaps would double-count two trees standing in
    front of the same corner, which at capacity is most of them — and would
    report a pond as 140 % buried. A coarse raster is exact enough at this
    scale and cannot be got wrong.
    """
    steps = 40
    width = (box[2] - box[0]) / steps
    height = (box[3] - box[1]) / steps
    hit = 0
    for row in range(steps):
        y = box[1] + (row + 0.5) * height
        for column in range(steps):
            x = box[0] + (column + 0.5) * width
            for other in others:
                if other[0] <= x <= other[2] and other[1] <= y <= other[3]:
                    hit += 1
                    break
    return hit * width * height


if __name__ == "__main__":
    sys.exit(main())
