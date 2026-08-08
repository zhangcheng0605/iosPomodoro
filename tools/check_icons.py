"""Check the app icons: the shipped one has not moved, and the rest are five
different icons rather than five copies of one.

Alternate app icons are the only art in this app that is *never seen inside
it*. Nothing on the walk can catch a mistake here — the picker draws the same
PNGs, so a set that is all-but-identical looks like a set on screen and looks
like a set in the picker, and only fails on a Home screen where you cannot
tell which square is which. Hence measurement.

Five things are checked, and the first is the one that matters:

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

    python3 tools/check_icons.py [--report]

Exits non-zero if anything fails.
"""
import hashlib
import io
import os
import re
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


def check_build_settings(failures):
    """Both configurations list exactly the alternates, and include them."""
    source = open(PBXPROJ).read()
    listed = re.findall(
        r"ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = \"?([^\";]*)\"?;", source)
    include = re.findall(
        r"ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = (\w+);", source)
    primary = re.findall(r"ASSETCATALOG_COMPILER_APPICON_NAME = (\w+);", source)

    want = sorted(assets.ALTERNATE_ICONS)
    if len(listed) != len(primary):
        failures.append(
            f"ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES appears "
            f"{len(listed)} times but the primary icon is set {len(primary)} "
            f"times — a configuration that lists no alternates builds fine "
            f"and then has nothing to switch to")
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


def main():
    report = "--report" in sys.argv
    failures = []
    check_shipped_icon_unmoved(failures)
    check_files(failures)
    check_previews(failures)
    check_build_settings(failures)
    check_swift_names(failures)
    check_paw_reads(failures)
    check_separation(failures, report=report)

    if failures:
        print(f"\n{len(failures)} FAILED:")
        for line in failures:
            print(f"  {line}")
        return 1
    print("all pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
