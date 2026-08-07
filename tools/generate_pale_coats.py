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

import check_species
import generate_wildlife as gw


def phenomena():
    """Which species have no coat to pale, read out of `Species.swift`.

    This was a hard-coded `("rainbow", "meteors", "aurora")` and it went stale
    twice over. The roster grew from 41 species to 81 and this script was
    never re-run, so 36 animals could roll the one-in-three-hundred pale coat
    with no sprite to draw — an invisible animal on the rarest event in the
    app. Four more phenomena shipped after the tuple was written, so a re-run
    would have handed a moon-washed coat to a fogbow.

    Asking the Swift is the fix for both: there is one list of what a
    phenomenon is, and it is the one the app itself uses.
    """
    return {name for name, spec in check_species.parse_specs().items()
            if spec["isPhenomenon"]}


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
    skip = phenomena()
    print("Pale coats:")
    drawn = 0
    for name, draw in gw.SPECIES.items():
        if name in skip:
            continue
        coat = pale(gw.P[name])
        gw.to_png(draw(True), coat, f"wild_{name}_pale_0")
        gw.to_png(draw(False), coat, f"wild_{name}_pale_1")
        drawn += 1
    print(f"  {drawn} species, two frames each ({len(skip)} phenomena skipped)")
