"""Check the bell of hours — that every place has a voice, and that the
grades actually get quieter as the night comes on.

Three things, none of which anything else in the toolchain can see.

**1. Coverage.** Every `Place` is mapped to a `BellVoice` in
`BellVoice.at(_:)`. The Swift compiler already enforces exhaustiveness, so
this half is cheap — but the *files* are not compiled against anything, and a
voice whose four WAVs are missing is silent at runtime and green everywhere
else. `SoundPlayer.playBell` fails soft by design (a missing file is a quiet
hour, not a crash), which is exactly what makes it invisible.

**2. The grade.** The design says the strike is near-subliminal at three in
the morning and brighter at noon. That is a claim about the audio, and it is
checked against the shipped audio: for each voice, both peak and RMS must be
strictly increasing across night → dawn → dusk → day. Two knobs decide it —
a spectral tilt and a level — and the tilt lowers amplitude too, so the
ordering is not obvious from the table in `generate_assets.py` and cannot be
assumed. Turn one knob the wrong way and the bell gets *louder* at 3 a.m.,
which is the single worst thing this feature could do, and nothing on screen
would show it.

**3. The ceiling.** A strike is a one-shot and stays a one-shot: if any of
them grows past five seconds it has stopped being a mark and started being a
piece of music that arrives without being asked for.

    python3 tools/check_bell.py

Exits non-zero if anything fails.
"""
import os
import re
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = os.path.join(ROOT, "Pawmodoro", "Model")
RES = os.path.join(ROOT, "Pawmodoro", "Resources")
BELL = os.path.join(MODEL, "HourBell.swift")
PLACE = os.path.join(MODEL, "Place.swift")

PARTS = ["night", "dawn", "dusk", "day"]     # in order of increasing level
LONGEST = 5.0                                 # seconds


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def cases(path, name):
    """The `case foo` lines inside `enum <name>`, by brace walking."""
    source = read(path)
    opening = re.search(r"\benum %s\b[^{]*\{" % name, source)
    if not opening:
        return None
    depth = 0
    i = opening.end() - 1
    while i < len(source):
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0:
                break
        i += 1
    return re.findall(r"^\s*case (\w+)\s*$", source[opening.end():i], re.M)


def stem(voice, part):
    return voice if part == "day" else "%s_%s" % (voice, part)


def levels(path):
    """Peak and RMS of a mono 16-bit WAV, both normalised to full scale."""
    with wave.open(path) as handle:
        frames = handle.getnframes()
        raw = handle.readframes(frames)
        rate = handle.getframerate()
    samples = struct.unpack("<%dh" % (len(raw) // 2), raw)
    peak = max(abs(s) for s in samples) / 32767.0
    mean_square = sum(float(s) * s for s in samples) / len(samples)
    return peak, (mean_square ** 0.5) / 32767.0, frames / rate


def main():
    failures = []

    places = cases(PLACE, "Place")
    voices = cases(BELL, "BellVoice")
    if places is None or voices is None:
        print("could not find enum Place or enum BellVoice", file=sys.stderr)
        return 1

    # 1. Coverage — every place named in the mapping, every voice used.
    mapping = re.search(r"static func at\(_ place: Place\) -> BellVoice \{(.*?)\n    \}",
                        read(BELL), re.S)
    if not mapping:
        failures.append("HourBell.swift: BellVoice.at(_:) not found")
        named = set()
        used = set()
    else:
        arms = re.findall(r"case ([^:]+):\s*\.(\w+)", mapping.group(1))
        named = {p.strip().lstrip(".")
                 for arm, _ in arms for p in arm.split(",")}
        used = {voice for _, voice in arms}
    for place in places:
        if place not in named:
            failures.append("Place.%s has no bell voice — it would be the one "
                            "place in the world where the hour is silent" % place)
    for voice in voices:
        if voice not in used:
            failures.append("BellVoice.%s is mapped to no place, so four WAVs "
                            "ship that nothing can ever play" % voice)

    # 2 and 3. The files, and what they sound like.
    checked = 0
    for voice in voices:
        measured = []
        for part in PARTS:
            path = os.path.join(RES, "bell_%s.wav" % stem(voice, part))
            if not os.path.exists(path):
                failures.append("missing %s — BellVoice.%s.fileName(for: .%s) "
                                "points at nothing and that hour is silent"
                                % (os.path.basename(path), voice, part))
                measured = None
                break
            peak, rms, seconds = levels(path)
            if seconds > LONGEST:
                failures.append("%s is %.1fs — a strike over %.0fs has stopped "
                                "being a mark and become a piece of music"
                                % (os.path.basename(path), seconds, LONGEST))
            measured.append((part, peak, rms))
            checked += 1
        if not measured:
            continue
        for (before, peak_a, rms_a), (after, peak_b, rms_b) in zip(measured, measured[1:]):
            if peak_a >= peak_b or rms_a >= rms_b:
                failures.append(
                    "bell_%s at %s is not quieter than at %s (peak %.3f vs "
                    "%.3f, rms %.4f vs %.4f) — the grade is inverted, which "
                    "makes the bell loudest in the hours it must be softest in"
                    % (voice, before, after, peak_a, peak_b, rms_a, rms_b)
                )

    print("checked %d places, %d voices, %d bell files"
          % (len(places), len(voices), checked))
    if failures:
        print("\n%d FAILED:" % len(failures))
        for line in failures:
            print("  %s" % line)
        return 1
    print("all pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
