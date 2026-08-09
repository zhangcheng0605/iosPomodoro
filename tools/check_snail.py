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
  * the **iPhone SE is reported and not failed** — see `KNOWN_BROKEN`

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
MIN_CLEARANCE = 2.0


# --------------------------------------------------------------------------
# 1. What the app says
# --------------------------------------------------------------------------

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

    return float(row.group(1)), (float(size.group(1)), float(size.group(2))), skipped


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

    Every number the chrome stack is built from, read out of the real Swift.
    They are what turns the one measured number per device below — where the
    column's bottom edge lands — into a set of rectangles. If any of them moves
    the arithmetic moves with it, and `CHROME_SPACING`'s own assertion (§ 4)
    is what notices that the fixture then needs re-measuring.
    """
    source = open(CONTENT_FILE).read()

    chip_h = re.search(r"private var chipHeight: CGFloat \{ ([\d.]+) \* chipScale \}",
                       source)
    chip_w = re.search(r"private var chipWidth: CGFloat \{ ([\d.]+) \* chipScale \}",
                       source)
    target = re.search(
        r"CGSize\(width: max\(([\d.]+), chipWidth \+ ([\d.]+)\), "
        r"height: max\(([\d.]+), chipHeight \+ ([\d.]+)\)\)", source)
    # The default reading size's row of the `air` table, and only that one —
    # matching `ambience:` anywhere would just as happily read the squeezed
    # values the accessibility sizes use.
    air = re.search(
        r"dynamicTypeSize <= \.large\n\s*\? \(chip: [\d.]+, expeditions: [\d.]+, "
        r"buddy: [\d.]+, treats: [\d.]+, floor: [\d.]+, ambience: ([\d.]+)\)",
        source)
    if not (chip_h and chip_w and target and air):
        raise SystemExit("could not parse ContentView's chip/air metrics")

    chip_height = float(chip_h.group(1))
    chip_width = float(chip_w.group(1))
    hit = (max(float(target.group(1)), chip_width + float(target.group(2))),
           max(float(target.group(3)), chip_height + float(target.group(4))))

    controls = re.search(r"private var controls: some View \{(.*?)\n    \}\n",
                         source, re.S)
    if not controls:
        raise SystemExit("could not find ContentView.controls")
    circles = [float(v) for v in re.findall(
        r"\.frame\(width: ([\d.]+), height: \1\)", controls.group(1))]
    spacing = re.search(r"HStack\(spacing: ([\d.]+)\)", controls.group(1))
    if len(circles) != 3 or not spacing:
        raise SystemExit(
            f"ContentView.controls is not three circles in an HStack any more "
            f"({circles}) — the transport's footprint below is now wrong")

    return {
        "chip": (chip_width, chip_height),
        "hit": hit,
        "ambience_gap": float(air.group(1)),
        "transport": circles,
        "transport_spacing": float(spacing.group(1)),
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
# 2. Where the app's own furniture is — the one measured number per screen
# --------------------------------------------------------------------------
#
# Everything else about the chrome is derived from the Swift above. This is the
# single thing no amount of parsing can reach, because it is the outcome of a
# SwiftUI layout: **where the bottom edge of the column lands**, in points from
# the top of the screen. It is a measurement, and each one names the screenshot
# it came from so the next person can re-take it.
#
# All four were taken on 10 Aug 2026 from a Debug build of the current tree,
# place `peaks`, theme sakura, `-PawmodoroSnail 50 -PawmodoroClock 12`. The
# number is the bottom of the play button, found by its accent pixels.
#
#   iPhone 17 Pro idle    ios-after-idle.png     872.3
#   iPhone 17 Pro phase   ios-after-phase.png    839.7
#   Mac 460x860 content   mac-after-idle.png     859.0   (== content height)
#   iPhone SE idle        se-after-idle.png      off the bottom of the screen
#
# The Mac's is the useful one: the column's bottom edge *is* the bottom of the
# content area, so on that platform this stops being a fixture at all and
# becomes `height`, which is what lets the whole resize range be checked.
COLUMN_BOTTOM = {
    ("iPhone 17 Pro", "idle"): 872.3,
    ("iPhone 17 Pro", "phase"): 839.7,
}

# The gap `ScrollViewReader` leaves between the ambience chips and the photo
# chip below them — SwiftUI's own default spacing, which is not written down
# anywhere in the app and cannot be parsed out of it.
#
# Derived, not guessed: on an iPhone 17 Pro at idle the chips' hit band was
# measured at 670.7 and the column's bottom at 872.3, and everything between
# them except this is known. § 4 re-derives it from the *running phase* layout,
# where the photo chip is absent and the arithmetic closes exactly — so if any
# of ContentView's metrics move, that assertion fails rather than this quietly
# absorbing the change.
CHROME_SPACING = 8.0

# Screens where the main column does not fit and the whole scene layer is
# displaced with it. Reported every run, never failed.
#
# This is not a taste call, and "not checked" here does not mean "probably
# fine" — it means *known wrong, by a cause this file cannot reach*. Say the
# state out loud so nobody reads the note as an all-clear: on an iPhone SE she
# is drawn INSIDE the fourth ambience chip, half over the flame icon, which is
# a worse version of the picture this whole file exists to stop.
#
# What is actually broken is a screen above her. On an iPhone SE at the
# ordinary text size the main column is taller than the glass, so the ZStack
# every layer lives in — the scenery included — grows past the screen and the
# transport row is drawn **entirely below the bottom edge**. Measured on
# 10 Aug 2026 on an iPhone SE (3rd generation) simulator, se-idle.png: no
# 84pt accent circle appears anywhere on the screen, so the start button of a
# Pomodoro timer is unreachable. That is a much larger bug than this file's,
# and it lives in ContentView.
#
# Her own foot line is the measurement of it. It lands at 585pt on that
# screen, where a 667pt layer would put it at 549pt; solving the
# `scaledToFill` arithmetic backwards, the box every layer is handed is about
# 735pt — a 68pt overflow. So she is still standing on the artwork exactly as
# she should be, and the artwork is somewhere the chrome is not. No value of
# `groundRow` can fix that from here: the two are laid out in different
# spaces. When the column is made to fit, delete this entry — a green run with
# the SE back in is the acceptance test for that fix.
KNOWN_BROKEN = {
    "iPhone SE": "the column overflows the glass by about 68pt; the transport "
                 "row is drawn off the bottom edge, the scene layer is "
                 "displaced with it, and she lands inside the fourth ambience "
                 "chip (se-idle.png, 10 Aug 2026)",
}


def screens(mac):
    """Every (name, width, height, state) this runs over.

    The phones are the two `check_stray.py` already knows about. The Mac is not
    one shape but a range — the window may be dragged from
    `macWindowMinimum` to `macWindowMaximum` — and a fraction-placed sprite
    drifts across the artwork over that range, so the corners are all checked.
    """
    out = [("iPhone 17 Pro", 402, 874, "idle"),
           ("iPhone 17 Pro", 402, 874, "phase"),
           ("iPhone SE", 375, 667, "idle")]
    lo_w, lo_h = mac["macWindowMinimum"]
    hi_w, hi_h = mac["macWindowMaximum"]
    ideal_w, ideal_h = mac["macWindow"]
    for w, h in ((lo_w, lo_h), (ideal_w, ideal_h), (hi_w, hi_h),
                 (lo_w, hi_h), (hi_w, lo_h)):
        for state in ("idle", "phase"):
            out.append((f"Mac {w:.0f}x{h:.0f}", w, h, state))
    return out


def column_bottom(name, width, height, state):
    """Where the bottom edge of the column lands on this screen."""
    if name.startswith("Mac"):
        return height
    measured = COLUMN_BOTTOM.get((name, state))
    return measured


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


def chrome_rects(width, height, bottom, metrics, state):
    """Every rectangle the app draws over the place, at the bottom of the screen.

    Built the way ContentView builds it — upwards from the transport — out of
    the sizes parsed from the same file. Returns (name, x0, y0, x1, y1, drawn),
    where `drawn` says whether it is ink or an invisible 44pt hit target.
    """
    chip_w, chip_h = metrics["chip"]
    hit_w, hit_h = metrics["hit"]
    inset_y = (hit_h - chip_h) / 2
    inset_x = (hit_w - chip_w) / 2
    gap = metrics["ambience_gap"]

    rects = []
    # The transport: three circles in a row, centred.
    circles = metrics["transport"]
    span = sum(circles) + metrics["transport_spacing"] * (len(circles) - 1)
    x = width / 2 - span / 2
    tallest = max(circles)
    middle = bottom - tallest / 2          # an HStack centres its children
    for d in circles:
        rects.append(("transport", x, middle - d / 2, x + d, middle + d / 2, True))
        x += d + metrics["transport_spacing"]

    row_bottom = bottom - tallest - gap
    if state == "idle":
        # The photograph chip, centred, on its own row under the chips.
        rects.append(("photo chip",
                      width / 2 - hit_w / 2, row_bottom - hit_h,
                      width / 2 + hit_w / 2, row_bottom, False))
        rects.append(("photo chip",
                      width / 2 - chip_w / 2, row_bottom - hit_h + inset_y,
                      width / 2 + chip_w / 2, row_bottom - inset_y, True))
        row_bottom -= hit_h + CHROME_SPACING

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

def check_chrome(row, size, metrics, mac, failures, notes):
    """Does she ever touch what the app draws?

    The half this file was missing. Everything above asks the artwork; this
    asks the app.
    """
    anchor = parse_fill_anchor()

    # The cross-check that keeps CHROME_SPACING honest. In a running phase the
    # photo chip is gone, so the whole stack between the chips and the bottom
    # of the column is parsed metric and nothing else — and it has to come out
    # at the measured 690.0 on an iPhone 17 Pro. If a metric in ContentView
    # moves, this fails and the measurements in COLUMN_BOTTOM want re-taking.
    predicted = (COLUMN_BOTTOM[("iPhone 17 Pro", "phase")]
                 - max(metrics["transport"]) - metrics["ambience_gap"]
                 - metrics["hit"][1])
    if abs(predicted - 690.0) > 1.0:
        failures.append(
            f"ContentView's own metrics now put the ambience row's hit band at "
            f"{predicted:.1f} in a running phase, where it was measured at "
            f"690.0 — re-measure COLUMN_BOTTOM and CHROME_SPACING")

    checked = 0
    said = set()
    for name, width, height, state in screens(mac):
        bottom = column_bottom(name, width, height, state)
        broken = next((why for k, why in KNOWN_BROKEN.items()
                       if name.startswith(k)), None)
        if broken and name not in said:
            said.add(name)
            notes.append(f"{name}: NOT CHECKED and NOT FAILED — {broken}")
        if bottom is None:
            if not broken:
                failures.append(
                    f"{name}/{state}: no measurement in COLUMN_BOTTOM, so the "
                    f"app's own furniture cannot be placed — take a screenshot")
            continue
        desktop = name.startswith("Mac")
        _, feet_at = fill_map(width, height, desktop, anchor)
        feet = feet_at(row)
        rects = chrome_rects(width, height, bottom, metrics, state)

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
                label = f"{name}/{state}/{rect[0]}{'' if rect[5] else ' (hit area)'}"
                if clear < worst[0]:
                    worst = (clear, f"{label} at x={px:.2f}")
                if not rect[5]:
                    continue          # invisible hit areas are reported, not failed
                if clear < MIN_CLEARANCE:
                    line = (f"{label} at x={px:.2f}: {clear:.1f}pt — she is "
                            f"standing on the app")
                    (notes if broken else failures).append(
                        (f"[known-broken screen] {line}" if broken else line))
        if worst[1] is not None:
            notes.append(f"closest on {name}/{state}: {worst[0]:.1f}pt "
                         f"({worst[1]})")
    return checked


def preview_surface(row, size, skipped, metrics, mac, theme="sakura",
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
    for name, width, height, state in screens(mac):
        bottom = column_bottom(name, width, height, state)
        if bottom is None:
            continue
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
        for step in range(11):
            px = 0.04 + (step / 10) * 0.92
            tile.alpha_composite(sprite, (int(px * width - size[0] / 2),
                                          int(feet - size[1])))

        draw = ImageDraw.Draw(tile, "RGBA")
        for label, x0, y0, x1, y1, drawn in chrome_rects(
                width, height, bottom, metrics, state):
            fill = (40, 40, 40, 150) if drawn else None
            draw.rectangle([x0, y0, x1 - 1, y1 - 1], fill=fill,
                           outline=(255, 60, 60, 220) if drawn else (255, 200, 0, 160))
        draw.text((6, 6), f"{name} {state}", fill=(20, 20, 20, 255))
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
    surfaces = check_chrome(row, size, metrics, mac, failures, notes)

    print(f"checked {STEPS + 1} positions across {len(grids)} places on "
          f"{len(stray_check.DEVICES)} devices, {checked} "
          f"sprite/background pairs against {MINIMUM}:1, and {surfaces} "
          f"sprite/chrome pairs against {MIN_CLEARANCE}pt")
    if worst[1]:
        print(f"worst contrast: {worst[0]:.2f}:1 at {worst[1]}")
    for line in notes:
        print(f"  note: {line}")
    if failures:
        unique = sorted(set(failures))
        print(f"\n{len(unique)} FAILED:")
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
        preview_surface(row, size, skipped, metrics, mac, path=path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
