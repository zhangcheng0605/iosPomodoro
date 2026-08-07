"""The pale coats: one palette transform over every animal in the catalog.

Pokemon's shiny, at Pawmodoro odds and with the counter amputated. Roughly
one sighting in three hundred crosses the scene in a moon-washed coat; the
journal sketch gains a small star, forever, and no number anywhere says how
lucky that was.

A separate script for the same reason generate_companion_props.py is: the
wildlife generator's __main__ re-emits all 41 species' base art, and the
container's Pillow is newer than the one that authored it. This emits only
the new pale imagesets.

Run bare, never with stderr piped away:

    python3 tools/generate_pale_coats.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import generate_wildlife as gw

# A rainbow has no coat to pale.
PHENOMENA = ("rainbow", "meteors", "aurora")


def pale(palette):
    """Lift every coat tone toward moon-white; ink and outline keep their
    job in a cool slate so the silhouette still reads at night."""
    out = {}
    for index, rgba in palette.items():
        if index == gw.T:
            out[index] = rgba
            continue
        r, g, b, a = rgba
        luminance = 0.299 * r + 0.587 * g + 0.114 * b
        if luminance < 90:
            out[index] = (98, 96, 118, a)
        else:
            out[index] = (
                min(255, int(r * 0.30 + 168)),
                min(255, int(g * 0.30 + 170)),
                min(255, int(b * 0.30 + 182)),
                a,
            )
    return out


if __name__ == "__main__":
    print("Pale coats:")
    for name, draw in gw.SPECIES.items():
        if name in PHENOMENA:
            continue
        coat = pale(gw.P[name])
        gw.to_png(draw(True), coat, f"wild_{name}_pale_0")
        gw.to_png(draw(False), coat, f"wild_{name}_pale_1")
    print(f"  {len(gw.SPECIES) - len(PHENOMENA)} species, two frames each")
