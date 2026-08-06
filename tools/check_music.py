"""Check the music catalogue against the files that actually ship.

Three things can go wrong here and none of them is visible on screen.

**A hand-edited catalogue.** `MusicCatalog.swift` is generated and says so at
the top, which has never stopped anybody. A track edited into the Swift and
never rendered is a row in the Sound Studio that plays silence; a `loopFrames`
nudged by hand is a loop with a tick in it that only shows up on the second
repeat, thirty seconds in. So every field is compared back to the recipe in
`tools/generate_music.py` — the two are read from genuinely different places
(a Python object and a parsed Swift literal), which is what makes the
comparison worth making.

**The wrong audio format.** Every player node in `MusicPlayer` is connected
with the decoded buffer's own format, because connecting with the hardware's
raised an uncatchable ObjC exception and killed the app for every user on
every track until build 2. The other half of that contract is that the files
really are mono 22.05 kHz. Nothing else in the toolchain looks, and the
Simulator cannot reproduce the failure.

**A file that is not there.** A catalogue entry with no `.m4a` is a row that
does nothing when tapped, and an `.m4a` with no catalogue entry is dead weight
in a bundle four megabytes from its ceiling.

Then the gates: a collection and its tracks must agree, a found tape may never
also be for sale, and `MusicFinding`'s cases must be exactly the ones the
recipes use.

    python3 tools/check_music.py

Exits non-zero if anything fails.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

import generate_music as recipes            # noqa: E402  (after sys.path)

MUSIC = os.path.join(ROOT, "Pawmodoro", "Resources", "Music")
CATALOG = os.path.join(ROOT, "Pawmodoro", "Model", "MusicCatalog.swift")
GATE = os.path.join(ROOT, "Pawmodoro", "Model", "MusicGate.swift")

SR = 22050
# One AAC packet. The encoder's priming and padding mean a decoded file is not
# expected to land on the exact sample, but it is expected to land within a
# packet of it — a catalogue and a file that have drifted apart do so by whole
# bars, never by 1024 frames.
FRAME_SLACK = 1024


def swift_tracks():
    """The `MusicTrack(...)` rows, as dicts, straight out of the Swift."""
    source = open(CATALOG).read()
    rows = []
    for match in re.finditer(
        r'MusicTrack\(id: "([^"]+)", title: "([^"]*)", collection: "([^"]+)", '
        r'gate: (\.[\w().]+), bpm: (\d+), energy: (\d+), loopFrames: (\d+)\)',
        source,
    ):
        rows.append({
            "id": match.group(1), "title": match.group(2),
            "collection": match.group(3), "gate": match.group(4),
            "bpm": int(match.group(5)), "energy": int(match.group(6)),
            "frames": int(match.group(7)),
        })
    return rows


def swift_collections():
    source = open(CATALOG).read()
    rows = []
    for match in re.finditer(
        r'MusicCollection\(id: "([^"]+)", title: "([^"]*)", '
        r'blurb: "([^"]*)", gate: (\.[\w().]+)\)',
        source,
    ):
        rows.append({"id": match.group(1), "title": match.group(2),
                     "blurb": match.group(3), "gate": match.group(4)})
    return rows


def findings():
    """`MusicFinding`'s cases, out of MusicGate.swift."""
    source = open(GATE).read()
    block = re.search(r"enum MusicFinding[^{]*\{(.*?)\n\}", source, re.S)
    if not block:
        return None
    return set(re.findall(r"^\s*case (\w+)$", block.group(1), flags=re.M))


def audio_facts(path):
    """(channels, sample rate, frames) read off the shipped file."""
    out = subprocess.run(["afinfo", path], capture_output=True, text=True).stdout
    fmt = re.search(r"Data format:\s*(\d+) ch,\s*([\d.]+) Hz", out)
    dur = re.search(r"estimated duration: ([\d.]+) sec", out)
    if not fmt or not dur:
        return None
    return int(fmt.group(1)), float(fmt.group(2)), round(float(dur.group(1)) * SR)


def main():
    failures = []

    tracks = swift_tracks()
    collections = swift_collections()
    if not tracks or not collections:
        print("could not parse MusicCatalog.swift", file=sys.stderr)
        return 1

    # 1. The Swift is what the recipes say. Every field, both directions.
    by_id = {t["id"]: t for t in tracks}
    for recipe in recipes.TRACKS:
        row = by_id.get(recipe.id)
        if row is None:
            failures.append(f"{recipe.id} is a recipe with no catalogue entry — "
                            f"generate_music.py was not re-run")
            continue
        want = {
            "title": recipe.title, "collection": recipe.collection,
            "bpm": recipe.bpm, "energy": recipe.energy,
            "gate": recipes.swift_gate(recipe.gate),
        }
        for field, expected in want.items():
            if row[field] != expected:
                failures.append(
                    f"{recipe.id}.{field} is {row[field]!r} in the catalogue "
                    f"and {expected!r} in the recipe"
                )
    for extra in sorted(set(by_id) - {t.id for t in recipes.TRACKS}):
        failures.append(f"{extra} is in the catalogue with no recipe behind it")

    recipe_collections = {c[0]: c for c in recipes.COLLECTIONS}
    for row in collections:
        entry = recipe_collections.get(row["id"])
        if entry is None:
            failures.append(f"collection {row['id']} has no recipe")
            continue
        _, title, blurb, gate = entry
        if (row["title"], row["blurb"], row["gate"]) != (
            title, blurb, recipes.swift_gate(gate)
        ):
            failures.append(f"collection {row['id']} differs from its recipe")

    # 2. A file for every track, a track for every file — and the right format.
    #
    # The format assertion is the build-2 crash, written down: mono 22.05 kHz
    # is what `MusicPlayer` wires its nodes at, and a stereo or 44.1 kHz file
    # slipping into the folder is fatal on device and fine in the Simulator.
    on_disk = {name[:-4] for name in os.listdir(MUSIC) if name.endswith(".m4a")}
    for row in tracks:
        path = os.path.join(MUSIC, row["id"] + ".m4a")
        if row["id"] not in on_disk:
            failures.append(f"{row['id']} has a catalogue entry and no .m4a — "
                            f"it would be a silent row in the Sound Studio")
            continue
        facts = audio_facts(path)
        if facts is None:
            failures.append(f"{row['id']}.m4a: afinfo could not read it")
            continue
        channels, rate, frames = facts
        if (channels, rate) != (1, float(SR)):
            failures.append(
                f"{row['id']}.m4a is {channels} ch, {rate:.0f} Hz — every "
                f"track must be 1 ch, {SR} Hz, which is the format the player "
                f"nodes are connected with"
            )
        if abs(frames - row["frames"]) > FRAME_SLACK:
            failures.append(
                f"{row['id']}.m4a is {frames} frames and the catalogue says "
                f"{row['frames']} — the buffer is trimmed to the catalogue's "
                f"number, so the loop would tick or truncate"
            )
    for orphan in sorted(on_disk - set(by_id)):
        failures.append(f"{orphan}.m4a ships with no catalogue entry")

    # 3. Gates.
    gate_of = {c["id"]: c["gate"] for c in collections}
    for row in tracks:
        expected = gate_of.get(row["collection"])
        if expected is None:
            failures.append(f"{row['id']} is in collection "
                            f"{row['collection']!r}, which does not exist")
        elif row["gate"] != expected:
            failures.append(
                f"{row['id']} is gated {row['gate']} but its collection "
                f"{row['collection']} is {expected} — one of the two is a lie"
            )
    for row in collections:
        count = sum(1 for t in tracks if t["collection"] == row["id"])
        if count != 5:
            failures.append(f"collection {row['id']} has {count} tracks, not 5")

    # 4. A found tape is never for sale. This is the whole point of the gate,
    #    and it is one careless edit away from being untrue.
    declared = findings()
    if declared is None:
        failures.append("could not find enum MusicFinding in MusicGate.swift")
    else:
        used = set()
        for row in tracks + collections:
            match = re.fullmatch(r"\.found\(\.(\w+)\)", row["gate"])
            if match:
                used.add(match.group(1))
        for name in sorted(used - declared):
            failures.append(f"the catalogue gates on .found(.{name}), which is "
                            f"not a case of MusicFinding")
        for name in sorted(declared - used):
            failures.append(f"MusicFinding.{name} gates nothing — either a "
                            f"mixtape was dropped or the case is stale")

    # 5. The budget, measured on what ships rather than on what was just
    #    written. The generator's own assertion only sees its own run.
    megabytes = sum(
        os.path.getsize(os.path.join(MUSIC, n)) for n in os.listdir(MUSIC)
        if n.endswith(".m4a")
    ) / (1024 * 1024)
    if megabytes > recipes.TOTAL_BUDGET_MB:
        failures.append(f"the music folder is {megabytes:.1f} MB, over the "
                        f"{recipes.TOTAL_BUDGET_MB:.0f} MB budget")

    print(f"checked {len(tracks)} tracks in {len(collections)} collections, "
          f"{megabytes:.2f} MB of AAC")
    if failures:
        print(f"\n{len(failures)} FAILED:")
        for line in failures:
            print(f"  {line}")
        return 1
    print("all pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
