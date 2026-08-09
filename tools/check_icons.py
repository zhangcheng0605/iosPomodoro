"""Check the app icons: the shipped one has not moved, and the rest are five
different icons rather than five copies of one.

Alternate app icons are the only art in this app that is *never seen inside
it*. Nothing on the walk can catch a mistake here — the picker draws the same
PNGs, so a set that is all-but-identical looks like a set on screen and looks
like a set in the picker, and only fails on a Home screen where you cannot
tell which square is which. Hence measurement.

Eight things are checked, and the first is the one that matters:

1. **The shipped icon is byte-identical to the one in the App Store.**
   `make_icon` was parameterised by palette so five icons could come out of
   one drawing; the way that goes wrong is quietly, by moving the icon already
   on everybody's Home screen. Anchored on a stored SHA-256 rather than on a
   re-render, because a re-render agrees with whatever the generator currently
   draws — this file's first draft passed with the tomato resized.

2. **The three lists agree.** An icon's name is written down in three places —
   the generator's `ICON_VARIANTS`, `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`
   in *both* build configurations, and `AppIconChoice`'s raw values. A name
   that matches in two of the three builds, installs, and does nothing at all
   when tapped: `setAlternateIconName` fails asynchronously with an error the
   picker deliberately swallows, because the alternative is an error alert on
   top of the system's alert.

3. **They are distinguishable at Home-screen size.** Rendered at 60 points
   @3x under iOS's rounded mask and compared pairwise in CIELAB. The bar is
   not a taste: it sits above every pair that was *rejected* from the set for
   being too close, so a sixth icon as close to an existing one as Cocoa is
   to Ember fails here. `--report` re-renders the rejected pairs and prints
   their numbers, so the bar can be re-derived rather than believed.

4. **Every icon has a preview imageset that is a picture of it**, because
   the picker cannot draw an `.appiconset` and a preview that resolves to
   nothing draws an empty frame rather than an error.

5. **The pads read on the tomato**, in every icon, no worse than they do on
   the one that ships — which is the rule `paw_colour` implements, checked
   against the rendered pixels rather than against the rule.

6. **The Mac has an icon at all.** This is the newest rule and it exists
   because the app shipped for months without one. `AppIcon.appiconset`
   declared a single image tagged `"platform": "ios"`, so `actool` had nothing
   to compile for the `macosx` platform, produced no `AppIcon.icns`, wrote no
   `CFBundleIconName`, **and said nothing about any of it**. The build
   succeeded. Xcode's own `-validate-for-store` step succeeded. The only way
   to find out was to open the built bundle and look — or to ship a blank tile
   to the Mac App Store.

   So: the ten `idiom: mac` entries are all present, they name files that
   exist, and those files are the right size with an alpha channel.

7. **The Mac renditions are shaped like a Mac icon**, measured off their own
   alpha rather than taken on trust. macOS rounds nothing for you: a full-bleed
   square dropped into the `mac` idiom compiles perfectly and then sits in the
   Dock as a hard-edged tile among thirty soft ones. The geometry is a stored
   fixture read off *macOS itself* (see `APPLE_GRID`), not off the generator,
   so editing the generator's constants cannot talk this check round.

8. **The Mac art is the iOS art**, compared pixel to pixel through the body of
   the largest rendition. Ten PNGs that were correct when they were written
   and were not re-run after a palette change are the failure this catches, and
   nothing else in the toolchain looks at them twice.

Rules 6-8 are static: they read the asset catalogue. `--bundle PATH` adds the
end-to-end one — that a *built* `.app` really does carry `CFBundleIconName`,
an `.icns`, and the renditions in its `Assets.car`. That is the assertion the
original bug would have failed, and it needs a Mac and a build, so it is opt-in
and says loudly when it has not run.

    python3 tools/check_icons.py [--report] [--bundle path/to/Pawmodoro.app]

Exits non-zero if anything fails.
"""
import hashlib
import io
import json
import os
import plistlib
import re
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import generate_assets as assets

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")
PBXPROJ = os.path.join(ROOT, "Pawmodoro.xcodeproj", "project.pbxproj")
PICKER = os.path.join(ROOT, "Pawmodoro", "Views", "AppIconPicker.swift")

# The icon that went to the App Store in 1.0, by content hash.
#
# A stored fixture in the sense `check_weather.py` means it: a promise about
# the past, generated once, never regenerated. It is the only thing in this
# file that a re-run of the generator cannot talk out of failing.
SHIPPED = "8520e1ce162b3c7a5b57b2613952bea146b632979fad720b90d876a158fc6bec"

# 60 points at @3x — an iPhone Home-screen icon, actual size.
HOME_PX = 180

# How far apart two icons have to be, as mean CIE ΔE over the masked square.
#
# Measured, not chosen. The pairs kept out of the set for being too alike
# measure 5.0 (Ember/Cocoa), 8.2 (Snowdrift/Midnight), 10.4
# (Midnight/Lavender), 14.4 (Sakura/Ink-in-daylight) and 17.2
# (Snowdrift/Lavender). The closest pair that *is* in the set measures 22.9.
# The bar goes between them, so it fails exactly the mistake it exists to
# catch — a sixth icon that is another theme's near-twin — and passes
# everything shipped with room.
#
# Two of those numbers were surprises, which is the argument for measuring at
# all: Sakura/Ink was in the first cut of this set and had to come out, and
# Snowdrift was nearly cut for being "a paler Sakura" when it is in fact
# ΔE 32.6 away and one of the most distinct icons here.
MINIMUM_SEPARATION = 20.0

# The pads on the tomato. Not a text ratio — a shape on a disc — and the bar
# is the shipped icon's own measurement, computed rather than written down.
PAW_BAR_SLACK = 0.02

# ------------------------------------------------------- the macOS icon grid
#
# **This is a stored fixture, and it deliberately does not come from
# `generate_assets`.** Importing `MAC_BODY` and then checking the PNGs against
# it would be the trap this repo has now fallen into four times: change the
# constant, re-run the generator, and the checker cheerfully agrees about a
# different icon. These numbers are external ground truth.
#
# They were measured on this Mac on 9 Aug 2026, by drawing
# `NSWorkspace.shared.icon(forFile:)` into a 1024×1024 bitmap for fifteen
# installed apps — Notes, Mail, Music, Calendar, Reminders, App Store,
# Freeform, Terminal, Slack, Telegram, Todoist, Claude, Obsidian, Postman,
# GitHub Desktop — and reading the alpha channel. Fourteen of the fifteen
# agree to the pixel; the fifteenth is Safari, whose icon is a circle, and
# Apple's grid lets a circle run wider than a rounded rectangle.
#
# To re-derive rather than believe: that is about twenty lines of Swift, and
# `docs/MAC_STORE_ASSETS.md` § 1 has the method written out.
APPLE_GRID = {
    "canvas": 1024,       # the rendition's own pixel width
    "body": 824,          # opaque body, alpha > 200
    "origin": 100,        # body's top-left, i.e. the body is centred
    "shadow_side": 12,    # how far the shadow spills left and right, alpha > 8
    "shadow_above": 2,    # above the body's top edge
    "shadow_below": 22,   # below its bottom edge
}

# Half a pixel of slack at 1024 and a pixel at the small end: these are
# rasterised shapes, not arithmetic, and a rounded corner's antialiasing moves
# the "alpha > 200" boundary around by a fraction. Wide enough that nothing
# correct fails, far too tight for a full-bleed square (which would be off by
# 200 px) or for a body inset by the wrong fraction.
GRID_SLACK = 1.0

# The ten renditions the `mac` idiom requires. There is no single-size support
# for this idiom in Xcode 26.3 — checked — so it is all ten or nothing at all,
# and nothing at all is what the app shipped with.
MAC_LADDER = [(points, scale) for points in (16, 32, 128, 256, 512)
              for scale in (1, 2)]


def masked(image):
    """The icon as a Home screen draws it: 60 pt, rounded, on nothing."""
    small = image.convert("RGB").resize((HOME_PX, HOME_PX), Image.LANCZOS)
    mask = Image.new("L", (HOME_PX * 4, HOME_PX * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, HOME_PX * 4 - 1, HOME_PX * 4 - 1],
        radius=int(HOME_PX * 4 * 0.224), fill=255)
    return np.asarray(small, dtype=float), \
        np.asarray(mask.resize((HOME_PX, HOME_PX), Image.LANCZOS), dtype=float) / 255.0


def to_lab(rgb):
    """sRGB bytes to CIELAB (D65), vectorised over an image."""
    v = rgb / 255.0
    lin = np.where(v <= 0.04045, v / 12.92, ((v + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124, 0.3576, 0.1805],
                  [0.2126, 0.7152, 0.0722],
                  [0.0193, 0.1192, 0.9505]])
    xyz = lin @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16.0 / 116.0)
    return np.stack([116.0 * f[..., 1] - 16.0,
                     500.0 * (f[..., 0] - f[..., 1]),
                     200.0 * (f[..., 1] - f[..., 2])], axis=-1)


def separation(a, b):
    """Mean ΔE between two icons over the part of the square that is drawn."""
    (rgb_a, mask), (rgb_b, _) = a, b
    delta = np.linalg.norm(to_lab(rgb_a) - to_lab(rgb_b), axis=-1)
    return float((delta * mask).sum() / mask.sum())


def iconset_png(name):
    return os.path.join(ASSETS, f"{name}.appiconset", f"{name}.png")


def check_shipped_icon_unmoved(failures):
    """The icon on people's phones has not moved. Two halves, and it needs both.

    Comparing the PNG on disk against what `make_icon()` draws *now* proves
    only that the two agree — change the drawing, re-run the generator, and
    they agree about a different icon. That is the trap this repo has fallen
    into three times, and it was live here too: the first version of this
    function passed cleanly with the tomato's radius edited.

    So the anchor is a stored fixture. `SHIPPED` is the SHA-256 of the icon as
    submitted to the App Store in version 1.0; it was generated once and does
    not change. The rendered comparison stays as the second half, because it
    is the one that says *why* — fixture alone would fail with "the bytes
    differ" and leave you looking for the edit.
    """
    path = iconset_png("AppIcon")
    if not os.path.exists(path):
        failures.append("AppIcon.png is missing")
        return
    shipped = open(path, "rb").read()
    if hashlib.sha256(shipped).hexdigest() != SHIPPED:
        failures.append(
            f"AppIcon.png is not the icon submitted to the App Store "
            f"(sha256 {hashlib.sha256(shipped).hexdigest()[:16]}…, expected "
            f"{SHIPPED[:16]}…) — every phone with Pawmodoro on it would find "
            f"a different square on the Home screen after the next update, "
            f"and nobody asked for that")
    buffer = io.BytesIO()
    assets.make_icon(quiet=True).save(buffer, "PNG")
    if buffer.getvalue() != shipped:
        failures.append(
            "AppIcon.png does not match what make_icon() draws with its "
            "default arguments — parameterising the drawing has changed the "
            "icon it was parameterised out of")
    print(f"  shipped icon: {len(shipped) / 1024:.0f} KB, matches the 1.0 fixture")


def check_files(failures):
    """Every declared icon is on disk, square, opaque, and nothing else is."""
    on_disk = sorted(d[:-len(".appiconset")] for d in os.listdir(ASSETS)
                     if d.endswith(".appiconset"))
    declared = sorted(name for name, _, _ in assets.ICON_VARIANTS)
    if on_disk != declared:
        failures.append(
            f"the .appiconset folders {on_disk} are not the declared icons "
            f"{declared} — a leftover one still ships in the binary")
    for name in declared:
        path = iconset_png(name)
        if not os.path.exists(path):
            failures.append(f"{name}: {os.path.basename(path)} is missing")
            continue
        image = Image.open(path)
        if image.size != (1024, 1024):
            failures.append(f"{name}: {image.size}, not 1024x1024")
        if image.mode != "RGB":
            failures.append(
                f"{name}: mode {image.mode} — an app icon with an alpha "
                f"channel is rejected at upload, not at build")


def check_previews(failures):
    """Every icon has a preview imageset, and it is that icon.

    The picker cannot draw an `.appiconset`, so it draws `iconpreview_*`
    instead — which means a preview that is missing, stale, or of the wrong
    icon is a picker that lies about what you are choosing. It fails
    *silently*: `Image(_:)` with a name that resolves to nothing draws an
    empty frame, and five empty frames in a row look like a design.

    Checked by pixels rather than by existence: the 3x file is compared
    against a downsample of the icon it claims to preview, so swapping two of
    them fails here.
    """
    # Nothing left behind, either. A preview for an icon that no longer
    # exists still ships in the catalogue and nothing else looks — found the
    # honest way, by leaving one there.
    strays = sorted(d for d in os.listdir(ASSETS)
                    if d.startswith("iconpreview_") and d.endswith(".imageset")
                    and d[len("iconpreview_"):-len(".imageset")]
                    not in {n for n, _, _ in assets.ICON_VARIANTS})
    for stray in strays:
        failures.append(
            f"{stray} previews an icon that is not in the set — it still "
            f"ships in the catalogue and nothing else would notice")

    for name, _, _ in assets.ICON_VARIANTS:
        folder = os.path.join(ASSETS, f"iconpreview_{name}.imageset")
        if not os.path.isdir(folder):
            failures.append(
                f"iconpreview_{name}.imageset is missing — the picker's row "
                f"for {name} draws an empty frame, which looks like art")
            continue
        for scale in (1, 2, 3):
            filename = f"iconpreview_{name}@{scale}x.png" if scale > 1 \
                else f"iconpreview_{name}.png"
            path = os.path.join(folder, filename)
            if not os.path.exists(path):
                failures.append(f"iconpreview_{name}: {filename} is missing")
                continue
            preview = Image.open(path)
            if preview.size != (44 * scale, 44 * scale):
                failures.append(
                    f"iconpreview_{name}: {filename} is {preview.size}, "
                    f"not {(44 * scale, 44 * scale)}")
        big = os.path.join(folder, f"iconpreview_{name}@3x.png")
        if not os.path.exists(big):
            continue
        want = np.asarray(Image.open(iconset_png(name)).convert("RGB")
                          .resize((132, 132), Image.LANCZOS), dtype=float)
        got = np.asarray(Image.open(big).convert("RGB"), dtype=float)
        drift = float(np.abs(want - got).mean())
        if drift > 1.0:
            failures.append(
                f"iconpreview_{name} is not a picture of {name} "
                f"(mean channel difference {drift:.1f}) — the picker would "
                f"show one icon and apply another")


# The SDKs the alternates are declared for. Both iPhone ones, and macOS
# deliberately not — `check_alternates_are_ios_only` is where that is argued.
IOS_SDKS = ("iphoneos*", "iphonesimulator*")


def check_build_settings(failures):
    """Both configurations list exactly the alternates, and include them.

    The list is per-SDK now, so the count is two configurations × two iPhone
    SDKs. Counting *occurrences* rather than reading the conditions would
    accept two configurations that each cover one SDK, which builds fine for
    the device and ships a simulator build with no alternates in it.
    """
    source = open(PBXPROJ).read()
    conditioned = re.findall(
        r"\"ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES"
        r"\[sdk=([^\]]+)\]\" = \"?([^\";]*)\"?;", source)
    include = re.findall(
        r"ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = (\w+);", source)
    primary = re.findall(r"ASSETCATALOG_COMPILER_APPICON_NAME = (\w+);", source)

    want = sorted(assets.ALTERNATE_ICONS)
    listed = [value for _, value in conditioned]
    for sdk in IOS_SDKS:
        covered = sum(1 for s, _ in conditioned if s == sdk)
        if covered != len(primary):
            failures.append(
                f"ALTERNATE_APPICON_NAMES[sdk={sdk}] is set on {covered} "
                f"configurations but the primary icon is set on "
                f"{len(primary)} — a configuration that lists no alternates "
                f"builds fine and then has nothing to switch to")
    for value in listed:
        if sorted(value.split()) != want:
            failures.append(
                f"ALTERNATE_APPICON_NAMES is {value.split()}, expected {want}")
    if len(include) != len(primary) or any(v != "YES" for v in include):
        failures.append(
            f"ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS is {include} "
            f"on {len(primary)} configurations — without YES on both, the "
            f"alternate art is compiled out of the catalogue and every "
            f"switch fails at runtime")


def check_swift_names(failures):
    """`AppIconChoice`'s raw values are the iconset names, all of them."""
    source = open(PICKER).read()
    cases = re.findall(r"^\s*case \w+ = \"([^\"]+)\"", source, re.M)
    declared = sorted(name for name, _, _ in assets.ICON_VARIANTS)
    if sorted(cases) != declared:
        failures.append(
            f"AppIconChoice names {sorted(cases)}, the generator writes "
            f"{declared} — a case whose raw value is not an iconset name "
            f"fails silently inside setAlternateIconName's completion")


def check_separation(failures, report=False):
    """No two icons are the same icon at the size they are actually seen."""
    names = [name for name, _, _ in assets.ICON_VARIANTS]
    rendered = {n: masked(Image.open(iconset_png(n))) for n in names}
    worst = (1e9, None)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            value = separation(rendered[a], rendered[b])
            if report:
                print(f"    {a} / {b}: ΔE {value:.1f}")
            if value < worst[0]:
                worst = (value, f"{a}/{b}")
            if value < MINIMUM_SEPARATION:
                failures.append(
                    f"{a} and {b} differ by ΔE {value:.1f} at 60 points, "
                    f"under the {MINIMUM_SEPARATION} bar — two icons nobody "
                    f"can tell apart on a Home screen are one icon")
    print(f"  separation: {len(names)} icons, closest pair {worst[1]} at "
          f"ΔE {worst[0]:.1f} (bar {MINIMUM_SEPARATION})")

    if report:
        # The rejected pairs, which is where the bar comes from. Rendered on
        # the spot rather than stored, so the numbers in the docstring can be
        # re-derived by anyone who doubts them.
        for (a, appearance_a), (b, appearance_b) in (
                (("ember", "light"), ("cocoa", "light")),
                (("snowdrift", "light"), ("midnight", "light")),
                (("midnight", "light"), ("lavender", "light")),
                (("sakura", "light"), ("ink", "light")),
                (("snowdrift", "light"), ("lavender", "light")),
                (("sakura", "light"), ("snowdrift", "light"))):
            pair = [masked(assets.make_icon(theme=t, appearance=a, quiet=True))
                    for t, a in ((a, appearance_a), (b, appearance_b))]
            print(f"    not in the set — {a} / {b}: ΔE {separation(*pair):.1f}")


def check_paw_reads(failures):
    """The pads are legible on the tomato in every icon.

    Measured off the rendered pixels — the colour at the centre of the main
    pad against the colour just outside the toes — rather than off the rule
    that chose them, because a rule that checks itself checks nothing.
    """
    bar = None
    for name, theme, appearance in assets.ICON_VARIANTS:
        image = np.asarray(Image.open(iconset_png(name)).convert("RGB"), dtype=float)
        # The drawing puts the pad centre at 0.5 + 0.335*0.20 down the square,
        # and clear tomato sits a third of the radius left of the middle.
        side = image.shape[0]
        pad = image[int(side * (0.5 + 0.335 * 0.20)), side // 2]
        flesh = image[side // 2, int(side * (0.5 - 0.335 * 0.62))]
        ratio = assets.contrast(tuple(pad), tuple(flesh))
        if name == "AppIcon":
            bar = ratio
        elif ratio < bar - PAW_BAR_SLACK:
            failures.append(
                f"{name}: pads read at {ratio:.2f}:1 on the tomato, worse "
                f"than the shipped icon's {bar:.2f}:1")
        print(f"  {name}: pads {ratio:.2f}:1 on the tomato")


def contents(name):
    path = os.path.join(ASSETS, f"{name}.appiconset", "Contents.json")
    with open(path) as f:
        return json.load(f)


def alpha_box(image, threshold):
    """(left, top, right, bottom) of the pixels above `threshold` alpha."""
    channel = np.asarray(image.convert("RGBA"), dtype=float)[..., 3]
    rows, cols = np.where(channel > threshold)
    if rows.size == 0:
        return None
    return float(cols.min()), float(rows.min()), float(cols.max()), float(rows.max())


def check_mac_ladder(failures):
    """The Mac has an icon — the whole ladder, on disk, with an alpha channel.

    The bug this replaces was silent in every direction: `actool` compiled a
    catalogue whose only app-icon image said `"platform": "ios"`, emitted no
    macOS rendition, no `.icns` and no `CFBundleIconName`, and reported no
    warning; `-validate-for-store` then passed. Nothing anywhere said the Mac
    app had no icon.
    """
    want = {(f"{p}x{p}", f"{s}x") for p, s in MAC_LADDER}
    folder = os.path.join(ASSETS, f"{assets.MAC_ICON}.appiconset")
    images = contents(assets.MAC_ICON)["images"]
    mac = {(e.get("size"), e.get("scale")): e
           for e in images if e.get("idiom") == "mac"}

    missing = sorted(want - set(mac))
    if missing:
        failures.append(
            f"{assets.MAC_ICON}/Contents.json is missing the mac renditions "
            f"{missing} — the macOS idiom has no single-size form, so a "
            f"partial ladder is the same as none: actool emits nothing, says "
            f"nothing, and the Mac app has a blank tile in the Dock")
    extra = sorted(set(mac) - want)
    if extra:
        failures.append(f"{assets.MAC_ICON}: unexpected mac renditions {extra}")

    # Every file named exists, is the right pixel size, and *has* an alpha
    # channel — the reverse of the iOS rule, and the reason it is worth
    # stating: an opaque square passes `check_files`' idea of a good icon and
    # is a hard-edged tile on a Mac.
    for (size, scale), entry in sorted(mac.items()):
        px = int(size.split("x")[0]) * int(scale.rstrip("x"))
        path = os.path.join(folder, entry.get("filename", ""))
        if not entry.get("filename") or not os.path.exists(path):
            failures.append(
                f"{assets.MAC_ICON} {size}@{scale}: {entry.get('filename')} "
                f"is named in Contents.json and is not on disk")
            continue
        image = Image.open(path)
        if image.size != (px, px):
            failures.append(
                f"{os.path.basename(path)} is {image.size}, not {(px, px)}")
        if image.mode != "RGBA":
            failures.append(
                f"{os.path.basename(path)} is mode {image.mode} — a macOS "
                f"icon without an alpha channel is a square: nothing on macOS "
                f"rounds it for you")

    # Nothing orphaned in the folder either. A rendition left behind by a
    # rename still ships in git and in the catalogue, and nothing else looks.
    named = {e["filename"] for e in images if "filename" in e} | {"Contents.json"}
    stray = sorted(set(os.listdir(folder)) - named)
    if stray:
        failures.append(
            f"{assets.MAC_ICON}.appiconset contains {stray}, which "
            f"Contents.json does not name")
    print(f"  macOS ladder: {len(mac)} of {len(want)} renditions declared")


def check_alternates_are_ios_only(failures):
    """The four alternates carry no mac idiom, and the build says so too.

    A decision, not an omission, and it is written down in `generate_assets`
    beside `MAC_ICON`: macOS has no equivalent of `setAlternateIconName`, so
    forty more renditions would be art that nothing on any platform can
    select, and — worse — would read to the next person as support that is
    there.

    Checked in both directions so that this file is where you come to change
    your mind. If macOS ever gains alternate app icons, deleting this function
    and giving every variant the ladder is the whole change.
    """
    for name in assets.ALTERNATE_ICONS:
        mac = [e for e in contents(name)["images"] if e.get("idiom") == "mac"]
        if mac:
            failures.append(
                f"{name} declares {len(mac)} mac renditions — nothing on "
                f"macOS can select an alternate app icon, so they would ship "
                f"unreachable. If that has changed, this is the check to "
                f"delete, and `MAC_ICON` is the comment to rewrite")

    source = open(PBXPROJ).read()
    plain = re.findall(
        r"^\s*ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = ", source, re.M)
    if plain:
        failures.append(
            f"ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES is set "
            f"unconditionally in {len(plain)} configurations — on the macOS "
            f"SDK that asks actool for four icons that have no mac renditions, "
            f"which is four build warnings per build and the kind of noise a "
            f"real warning then hides in. Condition it on the two iPhone SDKs")
    primary = re.findall(r"ASSETCATALOG_COMPILER_APPICON_NAME = (\w+);", source)
    if not primary:
        failures.append(
            "ASSETCATALOG_COMPILER_APPICON_NAME is not set unconditionally — "
            "the Mac would build with no primary icon at all")


def check_mac_geometry(failures):
    """Every mac rendition sits on Apple's icon grid, measured off its alpha.

    Against `APPLE_GRID`, which was read off fifteen shipping macOS apps and
    is deliberately not the generator's own constants — see the comment there.
    Change `MAC_BODY` in `generate_assets` and this fails, which is the whole
    point of not importing it.
    """
    folder = os.path.join(ASSETS, f"{assets.MAC_ICON}.appiconset")
    grid = APPLE_GRID
    for entry in sorted(contents(assets.MAC_ICON)["images"],
                        key=lambda e: e.get("size", "")):
        if entry.get("idiom") != "mac":
            continue
        path = os.path.join(folder, entry["filename"])
        if not os.path.exists(path):
            continue
        image = Image.open(path)
        px = image.size[0]
        k = px / grid["canvas"]
        solid = alpha_box(image, 200)
        if solid is None:
            failures.append(f"{entry['filename']} is entirely transparent")
            continue
        left, top, right, bottom = solid
        want_origin, want_body = grid["origin"] * k, grid["body"] * k
        for label, got, expected in (
                ("left", left, want_origin),
                ("top", top, want_origin),
                ("width", right - left + 1, want_body),
                ("height", bottom - top + 1, want_body)):
            if abs(got - expected) > GRID_SLACK:
                failures.append(
                    f"{entry['filename']}: body {label} is {got:.1f} px, "
                    f"Apple's grid puts it at {expected:.1f} — a macOS icon "
                    f"is {grid['body']}/{grid['canvas']} of its canvas, "
                    f"centred, and everything else in the Dock is")

        # The shadow, only where it is big enough to measure. Below about
        # 128 px it is a fraction of a pixel and correctly invisible.
        if px < 128:
            continue
        soft = alpha_box(image, 8)
        side = ((left - soft[0]) + (soft[2] - right)) / 2.0
        above, below = top - soft[1], soft[3] - bottom
        # Proportional, with a floor. A flat two-pixel tolerance was wide
        # enough to accept *no shadow at all* at 128 px, where the expected
        # spill is only 1.5 px — found by deleting the shadow and watching
        # this rule pass while only the one below it failed.
        want_side = grid["shadow_side"] * k
        if abs(side - want_side) > max(1.0, 0.35 * want_side):
            failures.append(
                f"{entry['filename']}: the shadow spills {side:.1f} px "
                f"sideways, Apple's icons spill {grid['shadow_side'] * k:.1f} "
                f"— no shadow at all is the usual reason, and it is what makes "
                f"an icon look pasted on rather than sitting there")
        if below <= above:
            failures.append(
                f"{entry['filename']}: the shadow reaches {above:.1f} px above "
                f"the body and {below:.1f} px below it — light in the Dock "
                f"comes from above")
    print(f"  macOS grid: body {grid['body']}/{grid['canvas']} centred, "
          f"shadow {grid['shadow_side']} px sideways — as measured off macOS")


def check_mac_art_is_the_icon(failures):
    """The largest mac rendition is a picture of the icon that ships.

    Ten PNGs written once and not re-run after a palette edit look completely
    fine — they are a perfectly good picture of last month's icon. Nothing else
    in this toolchain opens them twice.
    """
    folder = os.path.join(ASSETS, f"{assets.MAC_ICON}.appiconset")
    biggest = os.path.join(folder, f"{assets.MAC_ICON}-mac-512@2x.png")
    if not os.path.exists(biggest):
        return
    mac = Image.open(biggest).convert("RGBA")
    px = mac.size[0]
    k = px / APPLE_GRID["canvas"]
    origin = int(round(APPLE_GRID["origin"] * k))
    body = int(round(APPLE_GRID["body"] * k))
    got = np.asarray(mac.crop((origin, origin, origin + body, origin + body))
                     .convert("RGB"), dtype=float)
    want = np.asarray(Image.open(iconset_png(assets.MAC_ICON)).convert("RGB")
                      .resize((body, body), Image.LANCZOS), dtype=float)
    # Only where the rounded corner is not cutting: the mask's edge is a
    # different picture in the two by construction.
    inside = np.asarray(mac.crop((origin, origin, origin + body, origin + body))
                        .getchannel("A"), dtype=float) > 250
    drift = float(np.abs(want - got)[inside].mean())
    if drift > 4.0:
        failures.append(
            f"{os.path.basename(biggest)} is not a picture of "
            f"{assets.MAC_ICON}.png (mean channel difference {drift:.1f}) — "
            f"the macOS ladder is stale, and a stale icon is a good picture "
            f"of the wrong thing")
    print(f"  macOS art: 512@2x matches the shipped drawing to {drift:.1f}/255")


def check_built_bundle(failures, app):
    """The end-to-end one: a built `.app` really does carry the icon.

    Everything above reads the source. This reads the product, and it is the
    assertion the original bug would have failed — `CFBundleIconName` absent,
    no `.icns`, no renditions, and a green build either way.
    """
    plist = os.path.join(app, "Contents", "Info.plist")
    if not os.path.exists(plist):
        failures.append(f"{app} has no Contents/Info.plist — not a Mac .app?")
        return
    with open(plist, "rb") as f:
        info = plistlib.load(f)
    for key in ("CFBundleIconName", "CFBundleIconFile"):
        if not info.get(key):
            failures.append(
                f"the built app's Info.plist has no {key} — this is exactly "
                f"the state the app shipped in: actool emitted nothing, "
                f"warned about nothing, and Xcode's -validate-for-store passed")
    icns = os.path.join(app, "Contents", "Resources",
                        f"{info.get('CFBundleIconFile', 'AppIcon')}.icns")
    if not os.path.exists(icns):
        failures.append(f"the built app has no {os.path.basename(icns)} "
                        f"in Contents/Resources")

    car = os.path.join(app, "Contents", "Resources", "Assets.car")
    if not os.path.exists(car):
        failures.append("the built app has no Assets.car")
        return
    try:
        raw = subprocess.run(["assetutil", "--info", car],
                             capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"  built bundle: assetutil unavailable ({error})")
        return
    # Count the ones whose name is *exactly* the app icon. The trap here has
    # caught a previous pass: `grep -c AppIcon` returns twenty, and all twenty
    # are `iconpreview_AppIcon*` — the pictures the alternate-icon picker
    # draws. Those are imagesets and have nothing to do with the app's icon.
    entries = [e for e in json.loads(raw)
               if isinstance(e, dict) and e.get("Name") == assets.MAC_ICON]
    sized = [e for e in entries if e.get("PixelWidth")]
    if len(sized) < len(MAC_LADDER):
        failures.append(
            f"the built app's Assets.car has {len(sized)} {assets.MAC_ICON} "
            f"renditions, expected at least {len(MAC_LADDER)}")
    print(f"  built bundle: CFBundleIconName={info.get('CFBundleIconName')}, "
          f"{os.path.basename(icns)} present, {len(sized)} renditions")


def main():
    report = "--report" in sys.argv
    bundle = None
    if "--bundle" in sys.argv:
        bundle = sys.argv[sys.argv.index("--bundle") + 1]
    failures = []
    check_shipped_icon_unmoved(failures)
    check_files(failures)
    check_previews(failures)
    check_build_settings(failures)
    check_swift_names(failures)
    check_paw_reads(failures)
    check_separation(failures, report=report)
    check_mac_ladder(failures)
    check_alternates_are_ios_only(failures)
    check_mac_geometry(failures)
    check_mac_art_is_the_icon(failures)
    if bundle:
        check_built_bundle(failures, bundle)
    else:
        print("  built bundle: NOT CHECKED — pass --bundle path/to/Pawmodoro.app "
              "on a Mac to assert the icon is really in the product")

    if failures:
        print(f"\n{len(failures)} FAILED:")
        for line in failures:
            print(f"  {line}")
        return 1
    print("all pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
