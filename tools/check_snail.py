"""Check that the old snail stays on the ground — and off the app — everywhere.

The same job `check_stray.py` does, against a harder version of the same
problem. The stray stands at three fixed x positions, so her ground line only
has to be ground in three places. The snail crosses the *whole width* over six
months, so hers has to be ground at every x, on every device aspect, at every
place she visits — and she is a third the size, so she also has to survive
being drawn at eighteen points over a night scene in a dark theme.

**And then there is the half this file could not see at all.** It passed for
months while she stood on the ambience row: her foot landed on the top edge of
the fourth chip on the idle screen and she read as climbing on the UI. Every
rule here was green, because every rule was about the *artwork* — is there
scenery under her feet? — and the app draws its own furniture on top of that
scenery afterwards. It is `CLAUDE.md`'s lesson about the residents buried in
the grove, word for word: **composite the finished surface**, not just the
sprite over the art. Section 4 below is that missing half.

What this file decided, rather than verified:

  * she is placed by a **row of the artwork** (`Snail.groundRow`) rather than a
    fraction of the screen. A fraction lands on a different part of the picture
    on every shape of screen, which is why the standable band used to be twelve
    thousandths wide — and that sliver was exactly where the chips are
  * `Place.snailVisits` excludes Cloudspire (a city on clouds: the best row in
    the whole scene is 62 % solid), Harbor Isle (an island in open sea, the
    exact hazard that caught the stray sitting on the water) and the Onsen
    (a hot spring across the middle; three of fifty-six candidate lines clear
    it and all of them are one redraw from failing)
  * a screen with no room under her feet is one she does not visit — see
    `Snail.requiredFooting(at:)`. This file checks that gate from both sides:
    she never stands on the app where she is drawn, and the gate is never wider
    than the furniture it exists to clear

### The version of this file that could not fail, and what changed

It used to read `Snail.minimumFooting` out of `Snail.swift` and then check the
gate against that same number. That is the trap `CLAUDE.md` names three times
— `check_weather`, `check_yearring`, `check_touch` — one level up: delete the
fix and the check still passes, because the check has just been handed the new
answer. It also only ever looked at the **ordinary reading size**, and every
piece of the furniture it was measuring answers Dynamic Type, so a snail
standing squarely on the third ambience chip at `.xxLarge` was green.

So nothing here is now taken from `Snail.swift` as an answer. The furniture's
geometry is parsed out of **`ContentView.swift`** — the chip scale ladder, the
gap under the ambience row, the transport's floor, the row's own spacing, the
hit-target arithmetic — and evaluated at every one of the twelve text sizes.
`Snail.swift` is *translated* rather than restated: `chromeDepth`'s expression
is read and evaluated term by term, so deleting a term from the Swift changes
the number this file computes and the comparison with `ContentView` fails.
`SnailView.swift` is parsed too, because a gate nobody calls is not a gate.

    python3 tools/check_snail.py [--preview <path>]

Exits non-zero if anything fails.
"""
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import check_contrast as contrast_check
import check_stray as stray_check
import generate_scenes as scenes
import generate_sprites as sprites

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")
SNAIL_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "Snail.swift")
SNAIL_VIEW = os.path.join(ROOT, "Pawmodoro", "Views", "SnailView.swift")
THEME_FILE = os.path.join(ROOT, "Pawmodoro", "Model", "AppTheme.swift")
SCENERY_FILE = os.path.join(ROOT, "Pawmodoro", "Views", "SceneryView.swift")
CONTENT_FILE = os.path.join(ROOT, "Pawmodoro", "Views", "ContentView.swift")
PLATFORM_FILE = os.path.join(ROOT, "Pawmodoro", "Platform", "Platform.swift")

# The same bar the stray clears, and for the same reason: 4.5:1 is for reading
# words, and an animal that shouted that loud would be a sticker rather than a
# thing you notice.
MINIMUM = stray_check.MINIMUM

# Every hundredth of the crossing. She is on screen for six months, so a
# sampling that skipped x positions would be skipping weeks.
STEPS = 100

# How much daylight there has to be between her and anything the app draws.
#
# Two points, not zero. Zero would pass a snail whose shell is touching the
# corner of a chip, which is the picture this whole check exists to stop; and
# anything much larger would fail the only band on a phone that is free at all.
# See `Snail.groundRow` for how little room there is.
#
# This is **this file's** bar, not the app's. `Snail.clearance` is the app's,
# and § 4 requires the app's to be at least this — which is a comparison
# between two files rather than a number checking itself.
MIN_CLEARANCE = 2.0

# Every text size the app can be read at, smallest first. `DynamicTypeSize`'s
# own order, which is what `textSize <= .large` means.
TEXT_SIZES = ("xSmall", "small", "medium", "large", "xLarge", "xxLarge",
              "xxxLarge", "accessibility1", "accessibility2", "accessibility3",
              "accessibility4", "accessibility5")

# The shortest label that names each measured band in the fixture below.
FIXTURE_SIZES = ("large", "xLarge", "xxLarge", "xxxLarge", "accessibility5")


# --------------------------------------------------------------------------
# 1. What the app says
# --------------------------------------------------------------------------

def parse_switch_ladder(block, subject):
    """A Swift `switch` over `DynamicTypeSize` returning numbers, as a dict.

    Used for both `ContentView.chipScale` and `Snail.chipScale`, so the two can
    be compared as *values* rather than as two pieces of prose that look alike.
    """
    found = re.search(rf"switch {subject} \{{(.*?)\n\s*\}}", block, re.S)
    if not found:
        raise SystemExit(f"could not find a switch over {subject}")
    table, default = {}, None
    for line in found.group(1).splitlines():
        arm = re.match(r"\s*case ((?:\.\w+,?\s*)+):\s*([\d.]+)", line)
        if arm:
            for name in re.findall(r"\.(\w+)", arm.group(1)):
                table[name] = float(arm.group(2))
            continue
        fallback = re.match(r"\s*default:\s*([\d.]+)", line)
        if fallback:
            default = float(fallback.group(1))
    if default is None:
        raise SystemExit(f"the switch over {subject} has no default arm")
    return lambda size: table.get(size, default)


def parse_snail():
    """Her ground row, size, artwork shape and the places she skips."""
    source = open(SNAIL_FILE).read()

    size = re.search(r"static let size = CGSize\(width: ([\d.]+), height: ([\d.]+)\)",
                     source)
    if not size:
        raise SystemExit("could not find Snail.size in Snail.swift")

    art = re.search(
        r"static let sceneSize = CGSize\(width: ([\d.]+), height: ([\d.]+)\)", source)
    if not art:
        raise SystemExit("could not find Snail.sceneSize in Snail.swift")
    art_size = (float(art.group(1)), float(art.group(2)))
    if art_size != (float(scenes.W), float(scenes.H)):
        raise SystemExit(
            f"Snail.sceneSize {art_size} is not generate_scenes' own grid "
            f"({scenes.W}, {scenes.H}) — one of the two has moved")

    row = re.search(r"static let groundRow: Double = ([\d.]+)", source)
    if not row:
        raise SystemExit(
            "could not find Snail.groundRow in Snail.swift. If it has gone back "
            "to being a fraction of the screen, read that commit again: the "
            "sliver it has to land in is 0.779…0.791 and the chips are in it.")

    block = re.search(
        r"var snailVisits: Bool \{\n\s*switch self \{(.*?)\n\s*\}", source, re.S
    )
    if not block:
        raise SystemExit("could not find Place.snailVisits in Snail.swift")
    false_arm = re.search(r"case ((?:\.\w+,?\s*)+): false", block.group(1))
    skipped = set(re.findall(r"\.(\w+)", false_arm.group(1))) if false_arm else set()

    return (float(row.group(1)), (float(size.group(1)), float(size.group(2))),
            skipped)


def swift_block(source, signature):
    """The raw text between the braces of a `static func`/`static var`."""
    start = source.find(signature)
    if start < 0:
        raise SystemExit(f"could not find `{signature}` in Snail.swift")
    depth, i = 0, source.index("{", start)
    body_start = i + 1
    while True:
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0:
                break
        i += 1
    return source[body_start:i]


def swift_body(source, signature):
    """The statements inside such a body, one per entry.

    Continuation lines are folded back onto their statement, so a `return` split
    across two lines is one expression again. Comments go.
    """
    body = swift_block(source, signature)
    statements = []
    for line in body.splitlines():
        line = re.sub(r"//.*$", "", line).strip()
        if not line:
            continue
        if line.startswith("let ") or line.startswith("return ") or not statements:
            statements.append(line)
        else:
            statements[-1] += " " + line
    return statements


def translate(statements, namespace):
    """Evaluate a Swift arithmetic body in Python, term for term.

    This is the part that makes the comparison in § 4 mean something. It does
    **not** restate what `Snail.chromeDepth` adds up; it reads the expression
    the Swift actually contains and evaluates it. Drop `+ ambienceGap(at:)`
    from the Swift and the number this returns changes with it, which is what
    the comparison against `ContentView` then catches.
    """
    local = dict(namespace)
    out = None
    for statement in statements:
        statement = re.sub(r"(\w+)\(at: textSize\)", r"\1", statement)
        if statement.startswith("let "):
            exec(statement[4:], {"max": max, "min": min}, local)
        elif statement.startswith("return "):
            out = eval(statement[7:], {"max": max, "min": min}, local)
        else:
            out = eval(statement, {"max": max, "min": min}, local)
    if out is None:
        raise SystemExit("a Snail.swift body returned nothing this file could read")
    return out


def parse_snail_footing():
    """`Snail.requiredFooting(at:)`, translated rather than restated.

    Returns `(required, depth, clearance, chip_scale)`. Every one of them comes
    out of the Swift's own expressions; none of them is this file's opinion —
    which is exactly why they are only ever compared against numbers computed
    from `ContentView.swift` in § 4.
    """
    source = open(SNAIL_FILE).read()

    constants = {name: float(value) for name, value in
                 re.findall(r"static let (\w+): Double = ([\d.]+)", source)}
    for needed in ("clearance",):
        if needed not in constants:
            raise SystemExit(f"could not find Snail.{needed} in Snail.swift")

    chip_scale = parse_switch_ladder(
        swift_block(source, "static func chipScale(at textSize:"), "textSize")

    gap = re.search(
        r"static func ambienceGap\(at textSize: DynamicTypeSize\) -> Double \{\s*"
        r"textSize <= \.large \? ([\d.]+) : ([\d.]+)\s*\}", source)
    if not gap:
        raise SystemExit(
            "could not read Snail.ambienceGap(at:). It is the gap ContentView "
            "leaves under the ambience row and it changes with the text size; "
            "without it nothing here knows how deep the furniture is.")
    roomy, tight = float(gap.group(1)), float(gap.group(2))

    depth_body = swift_body(source, "static func chromeDepth(at textSize:")
    required_body = swift_body(source, "static func requiredFooting(at textSize:")

    def depth(text_size):
        space = dict(constants)
        space["chipScale"] = chip_scale(text_size)
        space["ambienceGap"] = roomy if TEXT_SIZES.index(text_size) <= \
            TEXT_SIZES.index("large") else tight
        return translate(depth_body, space)

    def required(text_size):
        space = dict(constants)
        space["chromeDepth"] = depth(text_size)
        return translate(required_body, space)

    return required, depth, constants["clearance"], chip_scale


def parse_snail_gate():
    """That `hasFooting` still asks the question, and `SnailView` still asks it.

    Both halves matter and they fail differently. A `hasFooting` that has been
    loosened is caught by § 4's matrix — she reappears on a screen whose
    furniture she overlaps. A `hasFooting` nobody calls is caught only here.
    """
    gate = re.search(
        r"static func hasFooting\(in size: CGSize, bottomAnchored: Bool,\s*"
        r"textSize: DynamicTypeSize\) -> Bool \{\s*"
        r"size\.height - feetY\(in: size, bottomAnchored: bottomAnchored\)\s*"
        r">= requiredFooting\(at: textSize\)\s*\}", open(SNAIL_FILE).read())
    if not gate:
        raise SystemExit(
            "Snail.hasFooting is not `room >= requiredFooting(at: textSize)` any "
            "more. That is the whole gate: without it she is drawn on screens "
            "with the ambience chips under her feet, which is what this file "
            "exists to stop. If it has genuinely changed shape, change this "
            "check with it — do not delete it.")

    view = open(SNAIL_VIEW).read()
    if not re.search(r"@Environment\(\\\.dynamicTypeSize\) private var dynamicTypeSize",
                     view):
        raise SystemExit(
            "SnailView no longer reads \\.dynamicTypeSize. The furniture under "
            "her grows by 47 points between .large and the accessibility sizes; "
            "a gate that cannot see the text size is the bug this replaced.")
    if not re.search(
            r"if Snail\.hasFooting\(in: geometry\.size,\s*"
            r"bottomAnchored: Platform\.isDesktop,\s*"
            r"textSize: dynamicTypeSize\) \{", view):
        raise SystemExit(
            "SnailView does not guard the sprite with Snail.hasFooting any more. "
            "The gate exists and nothing calls it, so she is drawn everywhere.")


def parse_fill_anchor():
    """Which way `SceneryView` crops the artwork when the frame is not its shape.

    Parsed rather than restated: `fillAnchor` is `.bottom` on the desktop and
    `.center` on a phone, and placing her against the wrong one puts her on the
    ground of a picture nobody is looking at.
    """
    source = open(SCENERY_FILE).read()
    found = re.search(
        r"private var fillAnchor: Alignment \{ Platform\.isDesktop \? "
        r"\.(\w+) : \.(\w+) \}", source)
    if not found:
        raise SystemExit("could not parse SceneryView.fillAnchor")
    return {"desktop": found.group(1), "phone": found.group(2)}


def parse_chrome_metrics():
    """The sizes ContentView lays the bottom of the screen out with.

    Every number the chrome stack is built from, read out of the real Swift —
    including, now, the two that answer Dynamic Type. They are what turns the
    one measured number per device below into a set of rectangles at *each*
    text size, and they are the independent half of every comparison in § 4:
    nothing here has been anywhere near `Snail.swift`.
    """
    source = open(CONTENT_FILE).read()

    chip_h = re.search(r"private var chipHeight: CGFloat \{ ([\d.]+) \* chipScale \}",
                       source)
    chip_w = re.search(r"private var chipWidth: CGFloat \{ ([\d.]+) \* chipScale \}",
                       source)
    target = re.search(
        r"CGSize\(width: max\(([\d.]+), chipWidth \+ ([\d.]+)\), "
        r"height: max\(([\d.]+), chipHeight \+ ([\d.]+)\)\)", source)
    gap = re.search(
        r"private var ambienceGap: CGFloat \{ dynamicTypeSize <= \.large \? "
        r"([\d.]+) : ([\d.]+) \}", source)
    if not (chip_h and chip_w and target and gap):
        raise SystemExit("could not parse ContentView's chip/gap metrics")

    scale_block = re.search(
        r"private var chipScale: CGFloat \{(.*?)\n    \}\n", source, re.S)
    if not scale_block:
        raise SystemExit("could not find ContentView.chipScale")
    chip_scale = parse_switch_ladder(scale_block.group(1), "dynamicTypeSize")

    row = re.search(r"private var ambienceRow: some View \{(.*?)\n    \}\n",
                    source, re.S)
    if not row:
        raise SystemExit("could not find ContentView.ambienceRow")
    spacing = re.search(r"VStack\(spacing: ([\d.]+)\)", row.group(1))
    if not spacing:
        raise SystemExit(
            "ContentView.ambienceRow no longer spaces its two rows explicitly. "
            "It used to be SwiftUI's implicit default, which is not written "
            "down anywhere and had to be derived from photographs; if it has "
            "gone back to that, derive it again rather than guessing.")

    column = re.search(r"private var adaptiveColumn: some View \{(.*?)\n    \}\n",
                       source, re.S)
    if not column:
        raise SystemExit("could not find ContentView.adaptiveColumn")
    if not re.search(r"ambienceRow\s*\n\s*\.padding\(\.bottom, ambienceGap\)",
                     column.group(1)):
        raise SystemExit(
            "the ambience row's bottom padding is not `ambienceGap` any more — "
            "the gap above the transport is now something this file cannot see")
    floor = re.search(r"\n            controls\n(?:.|\n)*?\.padding\(\.bottom, ([\d.]+)\)",
                      column.group(1))
    if not floor:
        raise SystemExit(
            "could not find the transport's own bottom padding in "
            "ContentView.adaptiveColumn. That is 16 points of daylight the play "
            "button buys off the bottom edge, and every rectangle below is "
            "stacked on top of it.")

    controls = re.search(r"private var controls: some View \{(.*?)\n    \}\n",
                         source, re.S)
    if not controls:
        raise SystemExit("could not find ContentView.controls")
    circles = [float(v) for v in re.findall(
        r"\.frame\(width: ([\d.]+), height: \1\)", controls.group(1))]
    spread = re.search(r"HStack\(spacing: ([\d.]+)\)", controls.group(1))
    if len(circles) != 3 or not spread:
        raise SystemExit(
            f"ContentView.controls is not three circles in an HStack any more "
            f"({circles}) — the transport's footprint below is now wrong")

    roomy, tight = float(gap.group(1)), float(gap.group(2))
    large = TEXT_SIZES.index("large")

    return {
        "chip": (float(chip_w.group(1)), float(chip_h.group(1))),
        "target": (float(target.group(1)), float(target.group(2)),
                   float(target.group(3)), float(target.group(4))),
        "chip_scale": chip_scale,
        "ambience_gap": (lambda size: roomy
                         if TEXT_SIZES.index(size) <= large else tight),
        "row_spacing": float(spacing.group(1)),
        "transport_floor": float(floor.group(1)),
        "transport": circles,
        "transport_spacing": float(spread.group(1)),
    }


def parse_mac_window():
    """`Platform.macWindow` and the range the window may be dragged over."""
    source = open(PLATFORM_FILE).read()
    out = {}
    for key in ("macWindow", "macWindowMinimum"):
        found = re.search(
            rf"static let {key} = CGSize\(width: ([\d.]+), height: ([\d.]+)\)", source)
        if not found:
            raise SystemExit(f"could not parse Platform.{key}")
        out[key] = (float(found.group(1)), float(found.group(2)))
    found = re.search(
        r"static let macWindowMaximum = CGSize\(\s*width: ([\d.]+),\s*"
        r"height: \(([\d.]+) \* \(([\d.]+) / ([\d.]+)\)\)\.rounded\(\)", source)
    if not found:
        raise SystemExit("could not parse Platform.macWindowMaximum")
    out["macWindowMaximum"] = (
        float(found.group(1)),
        round(float(found.group(2)) * (float(found.group(3)) / float(found.group(4)))),
    )
    return out


# --------------------------------------------------------------------------
# 2. The box the scene is actually drawn in — the measured half
# --------------------------------------------------------------------------
#
# **The layer is not the screen, and believing it was is what hid this bug.**
# Every layer in `ContentView`'s `ZStack` is handed the stack's box, and the
# stack grows to whatever its largest child reports. While `ordinaryColumn`
# existed that child overflowed — 793 points on a 667 point iPhone SE — and
# `SnailView` was handed the overflowing box along with everybody else. It no
# longer does: there is one adaptive column now and it is not greedy, so the
# box is the screen. That is a fact about today's `ContentView`, not a law, so
# it is measured rather than assumed and § 4 fails if it stops being true.
#
# Everything else here is parsed from the Swift. This is the one thing no
# amount of parsing can reach, because it is the outcome of a SwiftUI layout.
#
# Taken 10 Aug 2026 from a Debug build of this tree on the iOS 26.3 simulator,
# place `peaks`, theme sakura, `-PawmodoroDemo -PawmodoroClock 12
# -PawmodoroSnail 50`, at each of five `simctl ui <udid> content_size` settings.
# `layer` is printed straight out of `SnailView`'s own `GeometryReader`. `chips`
# is the **painted** top edge of the ambience row, in screen points, read off
# the screenshot at that text size by finding the accent-filled chip. `foot` is
# her own foot line, found by matching the shipped sprite against the same
# screenshot, and is `None` where the gate correctly keeps her away.
#
#            screen        layer            large  xLarge xxLarge xxxLarge  AX5
PHONES = (
    ("iPhone SE (3rd gen)", (375, 667), (375.0, 667.0),
     (469.5, 458.0, 448.0, 438.5, 422.0), None),
    ("iPhone 16e",          (390, 844), (390.0, 844.0),
     (646.0, 634.3, 624.7, 615.3, 599.3), None),
    ("iPhone 16",           (393, 852), (393.0, 852.0),
     (654.0, 642.3, 632.7, 623.3, 607.3), None),
    ("iPhone 17 Pro Max",   (440, 956), (440.0, 956.0),
     (758.0, 746.3, 736.7, 727.3, 711.3), 732.0),
)

# How far the fixture and the parsed arithmetic may disagree before this is no
# longer measuring the app that is in the tree. A point, which is three device
# pixels on a 3x phone and two on the SE — the width of the antialiased edge
# the chip top is read off.
FIXTURE_TOLERANCE = 1.0

# How much slack `Snail.requiredFooting` is allowed over the furniture it has
# to clear, on top of `MIN_CLEARANCE`. Any more and it is not a measurement,
# it is a screen being hidden.
FOOTING_SLACK = 4.0


def screens(mac):
    """Every (name, width, height, text size, state) this runs over.

    `width`/`height` are the **layer's box**, not the screen — the phones bring
    theirs from `PHONES` above. The Mac is not one shape but a range: the
    window may be dragged from `macWindowMinimum` to `macWindowMaximum` and
    there is no safe area to overflow into, so its box is the content size and
    the corners of the range are all checked.
    """
    out = []
    for name, _screen, box, _chips, _foot in PHONES:
        for text_size in TEXT_SIZES:
            for state in ("idle", "phase"):
                out.append((name, box[0], box[1], text_size, state))
    lo_w, lo_h = mac["macWindowMinimum"]
    hi_w, hi_h = mac["macWindowMaximum"]
    ideal_w, ideal_h = mac["macWindow"]
    for w, h in ((lo_w, lo_h), (ideal_w, ideal_h), (hi_w, hi_h),
                 (lo_w, hi_h), (hi_w, lo_h)):
        for text_size in TEXT_SIZES:
            for state in ("idle", "phase"):
                out.append((f"Mac {w:.0f}x{h:.0f}", w, h, text_size, state))
    return out


def chrome_depth(metrics, text_size, state="idle"):
    """How deep the app's furniture is, from the bottom of the layer up to the
    top edge of the painted ambience chips. Parsed, never typed."""
    rects = chrome_rects(1000.0, 1000.0, 1000.0, metrics, text_size, state)
    return 1000.0 - min(r[2] for r in rects if r[5])


# --------------------------------------------------------------------------
# 3. The app's own arithmetic
# --------------------------------------------------------------------------

def fill_map(width, height, desktop, anchor):
    """`scaledToFill` exactly as `SceneryView` does it, artwork <-> screen."""
    scale = max(width / scenes.W, height / scenes.H)
    drawn = scenes.H * scale
    which = anchor["desktop"] if desktop else anchor["phone"]
    if which == "bottom":
        origin_y = height - drawn
    elif which == "top":
        origin_y = 0.0
    else:
        origin_y = (height - drawn) / 2
    origin_x = (width - scenes.W * scale) / 2

    def to_scene(x, y):
        return ((x - origin_x) / scale, (y - origin_y) / scale)

    def feet(row):
        return origin_y + row * scale

    return to_scene, feet


def chrome_rects(width, height, bottom, metrics, text_size, state):
    """Every rectangle the app draws over the place, at the bottom of the screen.

    Built the way ContentView builds it — upwards from the transport's own
    floor — out of the sizes parsed from the same file, at the text size asked
    for. Returns (name, x0, y0, x1, y1, drawn), where `drawn` says whether it
    is ink or an invisible 44pt hit target.
    """
    scale = metrics["chip_scale"](text_size)
    chip_w = metrics["chip"][0] * scale
    chip_h = metrics["chip"][1] * scale
    min_w, pad_w, min_h, pad_h = metrics["target"]
    hit_w = max(min_w, chip_w + pad_w)
    hit_h = max(min_h, chip_h + pad_h)
    inset_y = (hit_h - chip_h) / 2
    gap = metrics["ambience_gap"](text_size)

    rects = []
    # The transport: three circles in a row, centred, standing on their floor.
    circles = metrics["transport"]
    span = sum(circles) + metrics["transport_spacing"] * (len(circles) - 1)
    x = width / 2 - span / 2
    tallest = max(circles)
    floor = bottom - metrics["transport_floor"]
    middle = floor - tallest / 2          # an HStack centres its children
    for d in circles:
        rects.append(("transport", x, middle - d / 2, x + d, middle + d / 2, True))
        x += d + metrics["transport_spacing"]

    row_bottom = floor - tallest - gap
    if state == "idle":
        # The photograph chip, centred, on its own row under the chips. Gone
        # while a focus phase runs, which is why the gate only ever asks about
        # the idle screen — see `Snail.hasFooting`.
        rects.append(("photo chip",
                      width / 2 - hit_w / 2, row_bottom - hit_h,
                      width / 2 + hit_w / 2, row_bottom, False))
        rects.append(("photo chip",
                      width / 2 - chip_w / 2, row_bottom - hit_h + inset_y,
                      width / 2 + chip_w / 2, row_bottom - inset_y, True))
        row_bottom -= hit_h + metrics["row_spacing"]

    # The ambience row runs edge to edge and scrolls, so every x is chip.
    rects.append(("ambience row", 0.0, row_bottom - hit_h,
                  width, row_bottom, False))
    rects.append(("ambience row", 0.0, row_bottom - hit_h + inset_y,
                  width, row_bottom - inset_y, True))
    return rects


def overlap(box, rect):
    """Signed clearance between her box and a rectangle: positive is daylight."""
    bx0, by0, bx1, by1 = box
    _, rx0, ry0, rx1, ry1, _ = rect
    if bx1 <= rx0 or bx0 >= rx1:
        return None                      # different part of the screen entirely
    if by1 <= ry0:
        return ry0 - by1
    if by0 >= ry1:
        return by0 - ry1
    return -min(by1, ry1) + max(by0, ry0)


# --------------------------------------------------------------------------
# 4. The finished surface
# --------------------------------------------------------------------------

def check_fixture(row, size, metrics, footing, failures, notes):
    """Does the arithmetic still describe the app somebody photographed?

    Everything in § 4 is parsed or translated. These twenty rows are the only
    measurements, and this is where they earn their keep. Three things are
    compared, and each catches something the others cannot:

    * the **painted chip top** against the depth computed from `ContentView` —
      one row per text size, so a metric that only moves at `.xxLarge` cannot
      hide behind a default-size photograph
    * the **layer box** against her foot line, where she is drawn — which is
      what would notice a column that started overflowing again and quietly
      handed her room the arithmetic here does not know about
    * whether she is **there at all**, against what `Snail.hasFooting` says —
      the screenshots agreeing with the gate is the only evidence that the
      Swift in this tree is the Swift that was photographed
    """
    anchor = parse_fill_anchor()
    for name, screen, box, chips, foot in PHONES:
        _, feet_at = fill_map(box[0], box[1], False, anchor)
        predicted_foot = feet_at(row)
        room = box[1] - predicted_foot

        for text_size, measured_chip in zip(FIXTURE_SIZES, chips):
            predicted_chip = box[1] - chrome_depth(metrics, text_size)
            if abs(predicted_chip - measured_chip) > FIXTURE_TOLERANCE:
                failures.append(
                    f"{name} at {text_size}: the model puts the painted chips "
                    f"{predicted_chip:.1f}pt down the layer; the screenshot "
                    f"shows {measured_chip:.1f}. Something under this file has "
                    f"moved — re-measure PHONES on a simulator before trusting "
                    f"any of it")
            here = room >= footing(text_size)
            drawn = foot is not None and text_size in ("large", "xLarge", "xxLarge")
            if name == "iPhone 17 Pro Max" and here != drawn:
                failures.append(
                    f"{name} at {text_size}: the gate says "
                    f"{'here' if here else 'away'} and the photograph says "
                    f"{'here' if drawn else 'away'}")

        if foot is not None and abs(predicted_foot - foot) > FIXTURE_TOLERANCE:
            failures.append(
                f"{name}: her foot line is computed at {predicted_foot:.1f} and "
                f"matched at {foot:.1f} in the screenshot — the layer box in "
                f"PHONES is no longer the box SnailView is handed")
        notes.append(
            f"{name}: screen {screen[0]}x{screen[1]}, layer "
            f"{box[0]:.0f}x{box[1]:.0f}, {room:.1f}pt under her feet, here up "
            f"to " + (max((t for t in TEXT_SIZES if room >= footing(t)),
                          key=TEXT_SIZES.index, default="nowhere")))


def check_footing(footing, clearance, chip_scale, metrics, failures, notes):
    """Is the gate the width of the problem, at every size, or wider?

    `Snail.requiredFooting` decides which screens she is absent from, which
    makes it the one number in this system that could hide a bug instead of
    fixing one: raise it far enough and every screen goes quiet. So it is
    pinned to the furniture it exists to clear — computed from `ContentView`,
    not read back out of `Snail.swift` — with four points of slack and no more,
    at every text size rather than at the one somebody photographed.
    """
    if clearance < MIN_CLEARANCE:
        failures.append(
            f"Snail.clearance is {clearance:.1f}pt against this file's "
            f"{MIN_CLEARANCE:.1f}. Zero daylight passes a snail whose shell is "
            f"touching the corner of a chip.")

    for text_size in TEXT_SIZES:
        mine = chip_scale(text_size)
        theirs = metrics["chip_scale"](text_size)
        if abs(mine - theirs) > 1e-9:
            failures.append(
                f"Snail.chipScale({text_size}) is {mine} and "
                f"ContentView.chipScale is {theirs} — the chips are not the "
                f"size this file thinks they are")

        depth = chrome_depth(metrics, text_size)
        low, high = depth + MIN_CLEARANCE, depth + MIN_CLEARANCE + FOOTING_SLACK
        asked = footing(text_size)
        # A tenth of a point of tolerance, both ways. These are two independent
        # floating-point walks over the same layout, and 219.2 + 2.0 is
        # 221.20000000000002 in one of them.
        if asked < low - 0.1:
            failures.append(
                f"at {text_size} Snail.requiredFooting is {asked:.1f}, which "
                f"lets her onto a screen with only {asked - depth:.1f}pt "
                f"between her feet and the painted chips — ContentView's "
                f"furniture is {depth:.1f}pt deep there and MIN_CLEARANCE asks "
                f"for {MIN_CLEARANCE:.0f}")
        if asked > high + 0.1:
            failures.append(
                f"at {text_size} Snail.requiredFooting is {asked:.1f} against "
                f"furniture {depth:.1f}pt deep — {asked - depth - MIN_CLEARANCE:.1f}pt "
                f"more than the clearance needs. That is not a measurement, it "
                f"is screens being hidden; bring it back to {low:.0f}…{high:.0f} "
                f"or say in Snail.swift what the extra is for")
        notes.append(f"furniture at {text_size}: {depth:.1f}pt deep, gate asks "
                     f"{asked:.1f}pt")


def check_chrome(row, size, footing, metrics, mac, failures, notes):
    """Does she ever touch what the app draws?

    The half this file was missing. Everything above asks the artwork; this
    asks the app. Every screen is checked at every text size, including the
    ones she is absent from — being absent is the answer this expects there,
    and a screen that is neither absent nor clear is a failure.
    """
    anchor = parse_fill_anchor()

    checked = 0
    absent = set()
    tightest = {}
    for name, width, height, text_size, state in screens(mac):
        desktop = name.startswith("Mac")
        _, feet_at = fill_map(width, height, desktop, anchor)
        feet = feet_at(row)
        # `Snail.hasFooting`, translated. Same box, same arithmetic.
        room = height - feet
        if room < footing(text_size):
            absent.add((name, text_size))
            continue

        rects = chrome_rects(width, height, height, metrics, text_size, state)
        worst = (float("inf"), None)
        for step in range(STEPS + 1):
            px = 0.04 + (step / STEPS) * 0.92
            box = (px * width - size[0] / 2, feet - size[1],
                   px * width + size[0] / 2, feet)
            for rect in rects:
                clear = overlap(box, rect)
                if clear is None:
                    continue
                checked += 1
                label = (f"{name}/{text_size}/{state}/{rect[0]}"
                         f"{'' if rect[5] else ' (hit area)'}")
                if clear < worst[0]:
                    worst = (clear, f"{label} at x={px:.2f}")
                if not rect[5]:
                    continue          # invisible hit areas are reported, not failed
                if clear < MIN_CLEARANCE:
                    failures.append(
                        f"{label} at x={px:.2f}: {clear:.1f}pt — she is "
                        f"standing on the app")
        if worst[1] is not None and state == "idle":
            if worst[0] < tightest.get(name, (float("inf"), None))[0]:
                tightest[name] = worst
    for name, (clear, where) in sorted(tightest.items()):
        notes.append(f"closest on {name}: {clear:.1f}pt ({where})")
    for name in sorted({n for n, _ in absent}):
        sizes = sorted({t for n, t in absent if n == name}, key=TEXT_SIZES.index)
        if len(sizes) == len(TEXT_SIZES):
            notes.append(f"{name}: she does not visit at any text size")
        else:
            notes.append(f"{name}: she does not visit at {', '.join(sizes)}")
    return checked


def preview_surface(row, size, skipped, footing, metrics, mac, theme="sakura",
                    path="snail_surface.png"):
    """Composite what the *app* composites, and save it to be looked at.

    A number saying 7.4pt does not tell you whether a snail looks like she is
    crossing a road or climbing on a button. This draws the scene, the veil,
    her, and then the app's own furniture on top of it, at every screen and
    both states — which is the picture that would have caught this in the
    first place.
    """
    palettes = contrast_check.parse_palettes(open(THEME_FILE).read())
    colours = palettes[theme]
    anchor = parse_fill_anchor()
    place = next(p for p in ("peaks", "meadow", "woods", "keep") if p not in skipped)
    sprite = Image.open(
        os.path.join(ASSETS, "snail_0.imageset", "snail_0.png")
    ).convert("RGBA").resize((int(size[0]), int(size[1])), Image.NEAREST)

    tiles = []
    for name, width, height, text_size, state in screens(mac):
        if text_size not in FIXTURE_SIZES:
            continue
        bottom = height
        width, height = int(width), int(height)
        desktop = name.startswith("Mac")
        art = stray_check.scene_image(place, "day")
        factor = max(width / art.width, height / art.height)
        resized = art.resize((round(art.width * factor), round(art.height * factor)),
                             Image.NEAREST)
        left = (resized.width - width) // 2
        which = anchor["desktop"] if desktop else anchor["phone"]
        top = (resized.height - height) if which == "bottom" \
            else (resized.height - height) // 2
        tile = resized.crop((left, top, left + width, top + height)).convert("RGBA")
        veil = tuple(int(v * 255) for v in colours["cream"]["light"]) + (
            int(contrast_check.SCENE_VEIL * 255),)
        tile.alpha_composite(Image.new("RGBA", tile.size, veil))

        _, feet_at = fill_map(width, height, desktop, anchor)
        feet = feet_at(row)
        # Only where the app would draw her. A preview that put her on every
        # screen would be showing a picture the app never renders, which is the
        # same sin as a checker that restates its own values.
        here = height - feet >= footing(text_size)
        if here:
            for step in range(11):
                px = 0.04 + (step / 10) * 0.92
                tile.alpha_composite(sprite, (int(px * width - size[0] / 2),
                                              int(feet - size[1])))

        draw = ImageDraw.Draw(tile, "RGBA")
        for label, x0, y0, x1, y1, drawn in chrome_rects(
                width, height, bottom, metrics, text_size, state):
            fill = (40, 40, 40, 150) if drawn else None
            draw.rectangle([x0, y0, x1 - 1, y1 - 1], fill=fill,
                           outline=(255, 60, 60, 220) if drawn else (255, 200, 0, 160))
        draw.text((6, 6), f"{name} {text_size} {state}"
                  + ("" if here else "  — she does not visit"),
                  fill=(20, 20, 20, 255))
        tiles.append(tile.convert("RGB"))

    w = max(t.width for t in tiles)
    h = max(t.height for t in tiles)
    sheet = Image.new("RGB", (w * len(tiles), h), (18, 18, 18))
    for i, t in enumerate(tiles):
        sheet.paste(t, (i * w, 0))
    sheet.save(path)
    print(f"surface preview: {path} — {len(tiles)} screens, place {place}, "
          f"grey blocks are what the app draws")


# --------------------------------------------------------------------------

def main():
    palettes = contrast_check.parse_palettes(open(THEME_FILE).read())
    if not palettes:
        print("could not parse any palettes from AppTheme.swift", file=sys.stderr)
        return 1

    row, size, skipped = parse_snail()
    parse_snail_gate()
    footing, _depth, clearance, chip_scale = parse_snail_footing()
    metrics = parse_chrome_metrics()
    mac = parse_mac_window()
    anchor = parse_fill_anchor()
    grids = {name: draw() for name, draw, _ in scenes.PLACES if name not in skipped}
    if skipped:
        print(f"not checked, she never goes there: {', '.join(sorted(skipped))}")

    sprite = stray_check.sprite_pixels("snail_0")
    failures, notes = [], []
    checked = 0
    worst = (99.0, None)

    for device, screen_w, screen_h in stray_check.DEVICES:
        desktop = device.startswith("Mac")
        to_scene, feet_at = fill_map(screen_w, screen_h, desktop, anchor)
        bottom = feet_at(row)

        for step in range(STEPS + 1):
            px = 0.04 + (step / STEPS) * 0.92
            left, top = px * screen_w - size[0] / 2, bottom - size[1]
            (gx0, gy0), (gx1, gy1) = (to_scene(left, top),
                                      to_scene(left + size[0], bottom))

            # 1. Never in the countdown's rows. She is small and slow, not
            #    exempt.
            if gy0 < scenes.QUIET_BOTTOM and gy1 > scenes.QUIET_TOP:
                failures.append(
                    f"{device} at x={px:.2f}: overlaps the countdown band"
                )

            foot_x = int(round((gx0 + gx1) / 2))
            foot_y = int(round(gy1)) - 1

            for place, grid in sorted(grids.items()):
                # 2. Standing on something. The whole reason this file exists:
                #    over six months she visits every column of the scene, and
                #    one of them being open water is a snail on the sea.
                if 0 <= foot_y < scenes.H and 0 <= foot_x < scenes.W:
                    under = int(grid[foot_y, foot_x])
                    if under in stray_check.UNSTANDABLE:
                        failures.append(
                            f"{device}/{place} at x={px:.2f}: nothing to stand "
                            f"on at scene ({foot_x}, {foot_y}), palette index "
                            f"{under}"
                        )
                else:
                    failures.append(
                        f"{device}/{place} at x={px:.2f}: outside the artwork "
                        f"at ({foot_x}, {foot_y})"
                    )

                # 3. Legible. Only on the tall device and every fifth step —
                #    the contrast of an eighteen-point sprite does not change
                #    between neighbouring columns, and this is 8 themes x 2
                #    appearances x 4 times of day x 9 weathers per sample.
                if device != stray_check.DEVICES[0][0] or step % 5:
                    continue
                for part in scenes.PARTS:
                    samples = stray_check.sample_scene(
                        place, part, (gx0, gy0, gx1, gy1)
                    )
                    if samples is None:
                        failures.append(f"{place}/{part}: missing scene image")
                        continue
                    hue = contrast_check.SKY_HUE[part]
                    for theme, colours in sorted(palettes.items()):
                        for appearance in ("light", "dark"):
                            def c(key):
                                return colours[key][appearance]

                            for weather, (veil_hue, veil_alpha) in sorted(
                                contrast_check.WEATHER_VEILS.items()
                            ):
                                for scene in samples:
                                    background = contrast_check.over(
                                        c("cream"), scene,
                                        contrast_check.SCENE_VEIL,
                                    )
                                    veil = contrast_check.over(
                                        c("cream"), c(veil_hue),
                                        contrast_check.WEATHER_MIX,
                                    )
                                    background = contrast_check.over(
                                        veil, background, veil_alpha
                                    )
                                    if hue is not None:
                                        wash = contrast_check.over(
                                            c("cream"), c(hue),
                                            contrast_check.SKY_MIX,
                                        )
                                        background = contrast_check.over(
                                            wash, background,
                                            contrast_check.SKY_WASH_OPACITY,
                                        )
                                    best = max(stray_check.luminance_pairs(
                                        sprite, background
                                    ))
                                    checked += 1
                                    where = (f"{place}/{part}/{weather}/"
                                             f"{theme}/{appearance}")
                                    if best < worst[0]:
                                        worst = (best, where)
                                    if best < MINIMUM:
                                        failures.append(f"{where}: {best:.2f}:1")

    # 4. Off the app's own furniture, on the finished surface.
    check_fixture(row, size, metrics, footing, failures, notes)
    check_footing(footing, clearance, chip_scale, metrics, failures, notes)
    surfaces = check_chrome(row, size, footing, metrics, mac, failures, notes)

    print(f"checked {STEPS + 1} positions across {len(grids)} places on "
          f"{len(stray_check.DEVICES)} devices, {checked} "
          f"sprite/background pairs against {MINIMUM}:1, and {surfaces} "
          f"sprite/chrome pairs over {len(TEXT_SIZES)} text sizes against "
          f"{MIN_CLEARANCE}pt")
    if worst[1]:
        print(f"worst contrast: {worst[0]:.2f}:1 at {worst[1]}")
    for line in notes:
        print(f"  note: {line}")
    if failures:
        unique = sorted(set(failures))
        print(f"\n{len(unique)} FAILED:")
        # Which screens, before the list — because she fails at all 101 x
        # positions when she fails at all, and thirty lines of one phone will
        # hide another phone entirely under the "and N more". Proved by
        # breaking it: with the footing gate loosened, every printed line was
        # an iPhone 13 mini and the iPhone SE — the worse of the two — was
        # below the cut.
        screens_hit = sorted({line.split("/")[0] for line in unique
                              if " at x=" in line})
        if screens_hit:
            print(f"  she is on the app on: {', '.join(screens_hit)}")
        for line in unique[:30]:
            print(f"  {line}")
        if len(unique) > 30:
            print(f"  ... and {len(unique) - 30} more")
        return 1
    print("all pass")

    if "--preview" in sys.argv:
        index = sys.argv.index("--preview")
        path = (sys.argv[index + 1] if len(sys.argv) > index + 1
                else os.path.join(ROOT, "snail_surface.png"))
        preview_surface(row, size, skipped, footing, metrics, mac, path=path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
