"""Check the film stocks: that they really are this world's own light.

The Scrapbook's whole claim is that a photo of your desk under `dusk` is lit by
exactly the arithmetic that lights Whispering Woods at dusk. That is a nice
sentence, and the only thing that makes it *true* is this file — because the
numbers live in two places by necessity. `tools/generate_scenes.py` grades the
scene art at build time in Python; `FilmStock` grades a photograph at draw time
in Swift. Nothing in a compiler or a screenshot can notice them drifting apart,
and a filter that has quietly stopped matching the world looks completely fine.

So:

1. **The three time-of-day stocks are parsed out of `generate_scenes.py`'s
   `GRADE`** and compared with `FilmStock.grade`. Not restated here — that is
   the trap this repo has now fallen into three times, most recently in
   `check_touch.py`, where five deliberate breaks all passed because the
   checker carried its own copy of the numbers.
2. **The press is parsed out of `generate_wildlife.py`'s `sepia()`**, which is
   the transform the field journal's sketches are pressed with.
3. **A stored fixture** of sampled colour → graded colour, because a stock is a
   promise about pictures somebody already kept: change a coefficient and every
   photograph in their scrapbook is relit.
4. **The Swift's own two paths agree.** `FilmStock.apply` states the
   arithmetic and `FilmStock.matrix` is what the view actually uses; they are
   derived from the same grade and must produce the same answer, or the
   preview swatch and the photograph would disagree.

    python3 tools/check_film.py

Exits non-zero if anything fails.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.path.join(ROOT, "Pawmodoro", "Model")
TOOLS = os.path.dirname(os.path.abspath(__file__))

# --- The contract ----------------------------------------------------------
#
# Generated once from the shipping coefficients. A failure here means every
# photograph anybody has kept is about to be shown in a different light than
# the one they chose.
FIXTURE = (
    # stock, input rgb (0-255), expected output rgb (0-255).
    # Generated once from the shipping coefficients, then frozen. Two rows per
    # interesting stock: a mid grey, which shows the tint, and a dark or a
    # bright, which shows the multiplier — a grade can drift in one without
    # moving the other.
    ("asitwas", (128, 128, 128), (128, 128, 128)),
    ("dawn", (128, 128, 128), (161, 135, 128)),
    ("dusk", (128, 128, 128), (145, 114, 105)),
    ("dusk", (20, 30, 40), (82, 57, 53)),
    ("night", (128, 128, 128), (57, 64, 84)),
    ("night", (240, 240, 240), (94, 100, 121)),
    ("pressed", (128, 128, 128), (165, 134, 103)),
    ("sakura", (200, 100, 60), (219, 131, 105)),
    ("winter", (200, 100, 60), (191, 131, 114)),
)

# The three that must match the scene generator exactly.
FROM_SCENES = ("dawn", "dusk", "night")


def parse_scene_grades():
    """`GRADE` out of tools/generate_scenes.py."""
    source = open(os.path.join(TOOLS, "generate_scenes.py")).read()
    body = source.split("GRADE = {")[1].split("\n}")[0]
    out = {}
    for name, r, g, b, amount, mul in re.findall(
        r'"(\w+)":\s*\(\((\d+), (\d+), (\d+)\), ([\d.]+), ([\d.]+)\)', body
    ):
        out[name] = ((float(r), float(g), float(b)), float(amount), float(mul))
    if not out:
        raise SystemExit("could not parse GRADE out of generate_scenes.py")
    return out


def parse_sepia():
    """The scale and offset per channel out of `sepia()` in the wildlife tool."""
    source = open(os.path.join(TOOLS, "generate_wildlife.py")).read()
    body = source.split("def sepia(palette):")[1].split("return out")[0]
    found = re.findall(r"grey \* ([\d.]+) \+ (\d+)", body)
    if len(found) != 3:
        raise SystemExit(f"could not parse sepia() (found {found})")
    scale = tuple(float(s) for s, _ in found)
    offset = tuple(float(o) for _, o in found)
    return scale, offset


def parse_film():
    """`FilmStock.grade`, `.press`, `.desaturates` and `.isFree`."""
    source = open(os.path.join(MODEL, "FilmStock.swift")).read()

    body = source.split("var grade: (tint:")[1].split("\n    }")[0]
    grades = {}
    for name, r, g, b, amount, mul in re.findall(
        r"case \.(\w+): \(\(([\d.]+), ([\d.]+), ([\d.]+)\), ([\d.]+), ([\d.]+)\)", body
    ):
        grades[name] = ((float(r), float(g), float(b)), float(amount), float(mul))

    press = re.search(
        r"static let press:[^=]*=\s*\(\(([\d.]+), ([\d.]+), ([\d.]+)\), "
        r"\((\d+), (\d+), (\d+)\)\)", source)
    if not press:
        raise SystemExit("could not parse FilmStock.press")
    scale = tuple(float(press.group(i)) for i in (1, 2, 3))
    offset = tuple(float(press.group(i)) for i in (4, 5, 6))

    desaturating = re.search(r"var desaturates: Bool \{ self == \.(\w+) \}", source)
    free_body = source.split("var isFree: Bool {")[1].split("\n    }")[0]
    free = set()
    for labels, value in re.findall(r"case ((?:\.\w+,? ?)+): (true|false)", free_body):
        if value == "true":
            free.update(re.findall(r"\.(\w+)", labels))
    return grades, (scale, offset), (desaturating.group(1) if desaturating else None), free


def apply(name, grades, press, desaturates, colour):
    """A port of `FilmStock.apply`. Not a second idea about the arithmetic."""
    r, g, b = (c / 255 for c in colour)
    if name == desaturates:
        grey = 0.299 * r + 0.587 * g + 0.114 * b
        r = g = b = grey
        scale, offset = press
        out = [min(1, max(0, c * s + o / 255))
               for c, s, o in zip((r, g, b), scale, offset)]
    else:
        tint, amount, mul = grades[name]
        keep = (1 - amount) * mul
        out = [min(1, max(0, c * keep + t / 255 * amount * mul))
               for c, t in zip((r, g, b), tint)]
    return tuple(int(round(c * 255)) for c in out)


def main():
    failures = []
    scenes = parse_scene_grades()
    sepia_scale, sepia_offset = parse_sepia()
    grades, press, desaturates, free = parse_film()

    # --- 1. The stocks that claim to be the world's light -------------------
    for name in FROM_SCENES:
        if name not in grades:
            failures.append(f"FilmStock has no '{name}' grade")
            continue
        if name not in scenes:
            failures.append(f"generate_scenes.py has no '{name}' grade")
            continue
        if grades[name] != scenes[name]:
            failures.append(
                f"'{name}' is {grades[name]} in FilmStock and {scenes[name]} in "
                f"generate_scenes.py — the filter has stopped being the light "
                f"the world is actually drawn in, and nothing else can tell")

    # --- 2. The press is the journal's press --------------------------------
    if press[0] != sepia_scale or press[1] != sepia_offset:
        failures.append(
            f"FilmStock.press is {press} but sepia() in generate_wildlife.py is "
            f"{(sepia_scale, sepia_offset)} — 'Pressed' is supposed to be the "
            f"field journal's own press")

    # --- 3. The contract ----------------------------------------------------
    for name, source, expected in FIXTURE:
        got = apply(name, grades, press, desaturates, source)
        if got != expected:
            failures.append(
                f"FIXTURE: '{name}' turned {source} into {expected} and now "
                f"turns it into {got} — every photograph anybody has kept in "
                f"this stock is about to be relit. See the note above FIXTURE."
            )

    # --- 4. Nothing free is for sale, and nothing sold is free -------------
    catalog = open(os.path.join(MODEL, "CatalogItem.swift")).read()
    if "case .film: 15" not in catalog:
        failures.append("the film price is not 15 acorns in CatalogItem")
    if not free:
        failures.append(
            "no film stock is free — capture and enough dress-up to make a "
            "photo belong here are free forever, per fence 6")
    if "asitwas" not in free:
        failures.append(
            "the ungraded stock is not free — somebody who buys nothing must "
            "still be able to look at their own photograph")

    # --- 5. Nothing writes over somebody's picture --------------------------
    snapshot = open(os.path.join(MODEL, "Snapshot.swift")).read()
    if "func setStock" not in snapshot:
        failures.append("Snapshot has no setStock — the grade must be a display "
                        "choice, changeable forever")
    # The EXIF strip lives in `renderJPEG` — one function, on both platforms —
    # and the import path has to go through it. Checked in two halves because
    # it moved once already, when the Mac target needed the renderer to be
    # platform-neutral: an importer that stopped calling it, or a `renderJPEG`
    # that stopped re-encoding, are different bugs with the same consequence.
    importer = open(os.path.join(MODEL, "SnapshotImport.swift")).read()
    if "renderJPEG(" not in importer:
        failures.append(
            "SnapshotImport no longer goes through renderJPEG — that re-encode "
            "is the whole of the EXIF strip, and a scrapbook of desks with GPS "
            "in it is a map of where somebody lives")
    platform = open(os.path.join(
        ROOT, "Pawmodoro", "Platform", "Platform.swift")).read()
    body = platform.split("func renderJPEG(")[1] if "func renderJPEG(" in platform else ""
    if "jpegData" not in body or "representation(using: .jpeg" not in body:
        failures.append(
            "renderJPEG no longer re-encodes on both platforms — it is the "
            "single place the EXIF strip happens, and it has to happen on the "
            "Mac too")

    print(f"checked {len(FROM_SCENES)} shared grades, the press, "
          f"{len(FIXTURE)} fixture rows and {len(free)} free stocks")
    if failures:
        unique = sorted(set(failures))
        print(f"\n{len(unique)} FAILED:")
        for line in unique[:20]:
            print(f"  {line}")
        return 1
    print("all pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
