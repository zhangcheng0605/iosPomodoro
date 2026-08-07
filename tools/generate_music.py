"""Generate Pawmodoro's lo-fi catalogue.

A small deterministic composition engine, not fifty hand-made loops. A track is
a recipe — key, tempo, progression, which instruments play — and the engine
renders it from synthesised instruments with humanised timing. Same doctrine as
every other asset here: procedural, reproducible, nothing to license.

    python3 tools/generate_music.py            # everything
    python3 tools/generate_music.py chill1     # one collection

Two things make a loop actually loop. Notes that ring past the final bar are
wrapped back onto the head rather than cut, so the decay continues across the
seam; and the file length is an exact whole number of bars in samples, which is
what lets the app schedule it as a sample-accurate buffer loop. Both are
asserted below — a track that fails does not get written.

Emits AAC into Pawmodoro/Resources/Music and the catalogue Swift that the app
reads. Edit the recipe, never the .m4a and never MusicCatalog.swift.
"""
import hashlib
import os
import subprocess
import sys
import wave

import numpy as np

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC = os.path.join(ROOT, "Pawmodoro", "Resources", "Music")
CATALOG = os.path.join(ROOT, "Pawmodoro", "Model", "MusicCatalog.swift")

TARGET_RMS = 0.115          # every track lands here, so nothing jumps out
PEAK_CEILING = 0.89         # ~-1 dBFS
MIN_SECONDS, MAX_SECONDS = 20.0, 40.0
TOTAL_BUDGET_MB = 20.0


# --- Deterministic randomness ----------------------------------------------

class Rng:
    """Seeded from the track's own name, so a track sounds identical on every
    machine and every run. `random` would make the catalogue unreproducible."""

    def __init__(self, seed_text):
        digest = hashlib.sha256(seed_text.encode()).digest()
        self.state = int.from_bytes(digest[:8], "big") | 1

    def _next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) & ((1 << 64) - 1)
        return (self.state >> 11) / float(1 << 53)

    def unit(self):
        return self._next()

    def range(self, low, high):
        return low + (high - low) * self._next()

    def chance(self, p):
        return self._next() < p

    def pick(self, items):
        return items[int(self._next() * len(items)) % len(items)]


# --- Notes ------------------------------------------------------------------

SEMITONE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(name, octave=4):
    """'C' -> 60 at octave 4. Accepts 'Bb', 'F#'."""
    step = SEMITONE[name[0].upper()]
    if len(name) > 1:
        step += {"#": 1, "b": -1}.get(name[1], 0)
    return 12 * (octave + 1) + step


def hz(note):
    return 440.0 * (2.0 ** ((note - 69) / 12.0))


# Chords as semitone offsets from the key root. Seventh chords throughout —
# plain triads are what makes cheap lo-fi sound like a ringtone.
CHORDS = {
    "I": [0, 4, 7, 11],
    "ii": [2, 5, 9, 12],
    "iii": [4, 7, 11, 14],
    "IV": [5, 9, 12, 16],
    "V": [7, 11, 14, 17],
    "vi": [9, 12, 16, 19],
    "i": [0, 3, 7, 10],
    "iv": [5, 8, 12, 15],
    "v": [7, 10, 14, 17],
    "III": [3, 7, 10, 14],
    "VI": [8, 12, 15, 19],
    "VII": [10, 14, 17, 21],
}

PROGRESSIONS = {
    "I-vi-IV-V": ["I", "vi", "IV", "V"],
    "I-IV-vi-V": ["I", "IV", "vi", "V"],
    "ii-V-I-vi": ["ii", "V", "I", "vi"],
    "I-iii-IV-I": ["I", "iii", "IV", "I"],
    "i-VI-III-VII": ["i", "VI", "III", "VII"],
    "i-iv-VII-III": ["i", "iv", "VII", "III"],
    "i-VII-VI-V": ["i", "VII", "VI", "v"],
    "I-V-vi-IV": ["I", "V", "vi", "IV"],
    "i-v-VI-VII": ["i", "v", "VI", "VII"],
    "I-IV-I-V": ["I", "IV", "I", "V"],
}

MAJOR_SCALE = [0, 2, 4, 5, 7, 9, 11]
MINOR_SCALE = [0, 2, 3, 5, 7, 8, 10]


# --- Instruments ------------------------------------------------------------
#
# Each returns a mono array for one note. Additive synthesis throughout: no
# samples, so nothing to license and every timbre is a few lines.

def _env(n, attack, decay):
    t = np.arange(n) / SR
    return (1.0 - np.exp(-t * attack)) * np.exp(-t * decay)


def ep(freq, dur, vel, rng):
    """The Rhodes-ish electric piano that carries most of the catalogue."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    detune = 1.0 + rng.range(0.0015, 0.004)
    sig = (np.sin(2 * np.pi * freq * t)
           + 0.55 * np.sin(2 * np.pi * freq * detune * t)
           + 0.22 * np.sin(2 * np.pi * freq * 3 * t) * np.exp(-t * 7)
           + 0.10 * np.sin(2 * np.pi * freq * 5 * t) * np.exp(-t * 11))
    tremolo = 1.0 + 0.07 * np.sin(2 * np.pi * rng.range(4.5, 6.5) * t)
    return sig * _env(n, 110, 2.1) * tremolo * vel


def musicbox(freq, dur, vel, rng):
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = (np.sin(2 * np.pi * freq * t)
           + 0.48 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t * 11)
           + 0.26 * np.sin(2 * np.pi * freq * 3.01 * t) * np.exp(-t * 15))
    return sig * _env(n, 400, 6.5) * vel


def celesta(freq, dur, vel, rng):
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = (np.sin(2 * np.pi * freq * t)
           + 0.35 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t * 6)
           + 0.15 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t * 10))
    return sig * _env(n, 300, 3.4) * vel


def marimba(freq, dur, vel, rng):
    """A marimba's defining overtone is the fourth harmonic, not the second."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = (np.sin(2 * np.pi * freq * t) * np.exp(-t * 5.0)
           + 0.40 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t * 12)
           + 0.12 * np.sin(2 * np.pi * freq * 9.2 * t) * np.exp(-t * 18))
    return sig * _env(n, 500, 4.6) * vel


def pluck(freq, dur, vel, rng):
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for harmonic in range(1, 7):
        sig += (1.0 / harmonic) * np.sin(2 * np.pi * freq * harmonic * t) * np.exp(-t * (3 + harmonic * 1.6))
    return sig * _env(n, 700, 4.0) * vel * 0.7


def pad(freq, dur, vel, rng):
    """A slow stack with a drifting filter — the bed most tracks float on."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for harmonic, gain in ((1, 1.0), (2, 0.42), (3, 0.24), (4, 0.14), (5, 0.08)):
        drift = 1.0 + 0.0012 * np.sin(2 * np.pi * rng.range(0.08, 0.2) * t + harmonic)
        sig += gain * np.sin(2 * np.pi * freq * harmonic * drift * t)
    swell = 1.0 + 0.18 * np.sin(2 * np.pi * rng.range(0.06, 0.14) * t)
    env = (1.0 - np.exp(-t * 2.2)) * np.exp(-t * 0.30)
    return sig * env * swell * vel * 0.5


def sub(freq, dur, vel, rng):
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * freq * t) + 0.15 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t * 5)
    return sig * _env(n, 60, 2.6) * vel


def kick(dur, vel, rng):
    n = int(SR * dur)
    t = np.arange(n) / SR
    sweep = 92.0 * np.exp(-t * 26) + 44.0
    sig = np.sin(2 * np.pi * np.cumsum(sweep) / SR)
    return sig * np.exp(-t * 11) * vel


def _noise(n, rng, tilt=0.0, cutoff=None, highpass=None, order=2):
    half = n // 2 + 1
    seeds = np.array([rng.unit() for _ in range(8)])
    phase = np.exp(2j * np.pi * ((np.arange(half) * seeds.sum() * 97.13) % 1.0))
    mag = np.ones(half)
    freq = np.fft.rfftfreq(n, 1.0 / SR)
    if tilt:
        mag[1:] = freq[1:] ** (-tilt)
    if cutoff:
        mag *= 1.0 / (1.0 + (freq / cutoff) ** (2 * order)) ** 0.5
    if highpass:
        mag *= 1.0 / (1.0 + (highpass / np.maximum(freq, 1e-6)) ** (2 * order)) ** 0.5
    sig = np.fft.irfft(mag * phase, n)
    return sig / (np.max(np.abs(sig)) + 1e-12)


def brush(dur, vel, rng):
    n = int(SR * dur)
    t = np.arange(n) / SR
    return _noise(n, rng, cutoff=4200, highpass=700) * np.exp(-t * 22) * vel


def hat(dur, vel, rng):
    n = int(SR * dur)
    t = np.arange(n) / SR
    return _noise(n, rng, highpass=6000) * np.exp(-t * 60) * vel


def shaker(dur, vel, rng):
    n = int(SR * dur)
    t = np.arange(n) / SR
    return _noise(n, rng, highpass=4200, cutoff=9000) * np.exp(-t * 34) * vel


def clack(dur, vel, rng):
    """Rail joints: two taps a breath apart. The Night Train set runs on this."""
    n = int(SR * dur)
    out = np.zeros(n)
    for offset, gain in ((0.0, 1.0), (0.085, 0.72)):
        start = int(offset * SR)
        length = min(n - start, int(SR * 0.09))
        if length <= 0:
            continue
        t = np.arange(length) / SR
        out[start:start + length] += (
            _noise(length, rng, cutoff=2600, highpass=240) * np.exp(-t * 42) * gain
        )
    return out * vel


INSTRUMENTS = {
    "ep": ep, "musicbox": musicbox, "celesta": celesta, "marimba": marimba,
    "pluck": pluck, "pad": pad, "sub": sub,
}


# --- Texture beds -----------------------------------------------------------

def bed(kind, n, rng):
    """A continuous layer under the music, crossfaded to loop cleanly."""
    if kind is None:
        return np.zeros(n)

    fade = int(SR * 0.6)
    long_n = n + fade

    if kind in ("crackle", "crackle_heavy"):
        density = 26 if kind == "crackle" else 70
        out = _noise(long_n, rng, tilt=0.5, cutoff=5200) * 0.055
        for _ in range(int(density * long_n / SR)):
            at = int(rng.unit() * (long_n - 400))
            length = int(rng.range(30, 190))
            t = np.arange(length) / SR
            out[at:at + length] += _noise(length, rng, highpass=1800) * np.exp(-t * 320) * rng.range(0.10, 0.34)
        level = 0.30 if kind == "crackle" else 0.48
    elif kind == "rain":
        out = _noise(long_n, rng, tilt=0.35, cutoff=6500)
        level = 0.26
    elif kind == "wind":
        out = _noise(long_n, rng, tilt=1.1, cutoff=1300)
        swell = 1.0 + 0.5 * np.sin(2 * np.pi * 0.055 * np.arange(long_n) / SR)
        out = out * swell
        level = 0.30
    elif kind == "water":
        out = _noise(long_n, rng, tilt=0.5, cutoff=3800, highpass=280)
        level = 0.24
    elif kind == "waves":
        out = _noise(long_n, rng, tilt=0.9, cutoff=1700)
        swell = 0.45 + 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.09 * np.arange(long_n) / SR))
        out = out * swell
        level = 0.34
    elif kind == "rumble":
        out = _noise(long_n, rng, tilt=1.5, cutoff=320)
        level = 0.38
    elif kind in ("birds", "crickets"):
        out = _noise(long_n, rng, tilt=0.6, cutoff=4000) * 0.05
        calls = 9 if kind == "birds" else 26
        for _ in range(calls):
            at = int(rng.unit() * (long_n - SR))
            if kind == "birds":
                length = int(SR * rng.range(0.05, 0.11))
                t = np.arange(length) / SR
                f0 = rng.range(2100, 3600)
                chirp = np.sin(2 * np.pi * (f0 + 900 * np.sin(2 * np.pi * 22 * t)) * t)
                out[at:at + length] += chirp * np.exp(-t * 26) * rng.range(0.16, 0.30)
            else:
                for rep in range(4):
                    start = at + rep * int(SR * 0.055)
                    length = int(SR * 0.022)
                    if start + length >= long_n:
                        break
                    t = np.arange(length) / SR
                    out[start:start + length] += (
                        np.sin(2 * np.pi * 4600 * t) * np.exp(-t * 130) * 0.14
                    )
        level = 0.34
    else:
        raise ValueError(f"unknown texture {kind!r}")

    out = out / (np.max(np.abs(out)) + 1e-12)
    # Crossfade the tail over the head: noise isn't periodic, so the seam has
    # to be made rather than found.
    head = out[:n].copy()
    ramp = np.linspace(0.0, 1.0, fade)
    head[:fade] = head[:fade] * ramp + out[n:n + fade] * (1.0 - ramp)
    return head * level


# --- Master chain -----------------------------------------------------------

def lowpass(sig, cutoff, order=2):
    spec = np.fft.rfft(sig)
    freq = np.fft.rfftfreq(len(sig), 1.0 / SR)
    return np.fft.irfft(spec * (1.0 / (1.0 + (freq / cutoff) ** (2 * order)) ** 0.5), len(sig))


def scoop(sig, low, high, depth):
    """Take `depth` (0-1) out of a band and leave the rest alone.

    This is how a track is made to *duet* with something rather than to be
    mixed against it: the Rainy Day tapes cut the band the rain loop already
    fills, so the two can play together at full level without either having to
    be turned down. A raised-cosine skirt rather than a brick wall — a sharp
    notch is audible as a hole, and the point is that nobody notices."""
    spec = np.fft.rfft(sig)
    freq = np.fft.rfftfreq(len(sig), 1.0 / SR)
    band = np.clip((freq - low) / max(high - low, 1e-6), 0.0, 1.0)
    shape = 0.5 - 0.5 * np.cos(2 * np.pi * band)   # 0 at the edges, 1 mid-band
    return np.fft.irfft(spec * (1.0 - depth * shape), len(sig))


# How a collection sits in the spectrum. Each is one deliberate sentence about
# where that set of tracks is *meant* to be heard, expressed as filters rather
# than as mixing advice nobody would follow.
#
#   rain     — the midrange left open for the rain family's loops, and the top
#              given away entirely: rain owns the treble, so a tape that fights
#              it there loses. What is left is body and sparkle either side.
#   night    — darker than anything else in the catalogue. A 3 a.m. shift is a
#              lamp and a sub, not a top end.
#   lullaby  — barely graded at all. A music box is nearly all fundamental,
#              and taking anything out of it makes it a sine.
ROOMS = {
    None:      {"lowpass": 7200},
    "rain":    {"lowpass": 5200, "scoop": (1150, 3000, 0.42)},
    "night":   {"lowpass": 4300},
    "lullaby": {"lowpass": 6000},
}


def wobble(sig, rng, cents=6.0):
    """Tape flutter. The resampled index is renormalised to span exactly the
    original length — a loop whose length drifted by even a few samples would
    stop being a whole number of bars."""
    n = len(sig)
    t = np.arange(n) / SR
    lfo = (np.sin(2 * np.pi * rng.range(0.5, 0.9) * t + rng.range(0, 6))
           + 0.45 * np.sin(2 * np.pi * rng.range(1.7, 2.6) * t))
    ratio = 2.0 ** ((cents / 1200.0) * lfo / 1.45)
    index = np.cumsum(ratio)
    index = index / index[-1] * (n - 1)
    return np.interp(index, np.arange(n), sig)


def master(sig, rng, room=None):
    shape = ROOMS[room]
    sig = wobble(sig, rng)
    sig = lowpass(sig, shape["lowpass"])
    if "scoop" in shape:
        low, high, depth = shape["scoop"]
        sig = scoop(sig, low, high, depth)
    sig = np.tanh(sig * 1.35) / np.tanh(1.35)

    # Loudness and headroom fight each other: scaling down to fix a peak undoes
    # the level match, which is how the first version drifted 1.6 dB under
    # target. Soft-limit the transients instead and re-level, twice if needed —
    # tanh barely touches the body of the signal, so RMS survives.
    for _ in range(8):
        rms = float(np.sqrt(np.mean(sig ** 2))) + 1e-12
        sig = sig * (TARGET_RMS / rms)
        if float(np.max(np.abs(sig))) <= PEAK_CEILING:
            break
        sig = np.tanh(sig / PEAK_CEILING) * PEAK_CEILING

    peak = float(np.max(np.abs(sig)))
    if peak > PEAK_CEILING:
        sig = sig * (PEAK_CEILING / peak)
    return sig


# --- Arrangement ------------------------------------------------------------

class Track:
    def __init__(self, number, ident, title, collection, gate, bpm, key,
                 progression, lead, texture, energy, meter=4,
                 space=1.0, room=None):
        self.number = number
        self.id = ident
        self.title = title
        self.collection = collection
        self.gate = gate
        self.bpm = bpm
        self.key = key
        self.progression = progression
        self.lead = lead
        self.texture = texture
        self.energy = energy
        self.meter = meter
        # How much of the bar is left empty. `energy` already says how busy a
        # track is *rhythmically*; this says how often a note is played at all,
        # and the two are genuinely different — Phase W's three collections are
        # all energy 1 or 2 and would still be far too full at the density the
        # first fifty were written at. Sparse is not the same as slow.
        self.space = space
        # Which shelf of ROOMS this track is filtered for.
        self.room = room

    @property
    def is_minor(self):
        return self.progression.startswith("i-")

    @property
    def root(self):
        return midi(self.key, 4)

    @property
    def bars(self):
        """Chosen so every track lands inside the 20-40s window."""
        seconds = self.meter * 60.0 / self.bpm
        count = 8
        while seconds * count > MAX_SECONDS:
            count //= 2
        while seconds * count < MIN_SECONDS:
            count *= 2
        return count


def render(track):
    rng = Rng(track.id)
    beat = SR * 60.0 / track.bpm
    bar_samples = int(round(beat * track.meter))
    total = bar_samples * track.bars
    tail = int(SR * 3.0)
    buf = np.zeros(total + tail)

    def place(sig, at, gain=1.0):
        start = max(0, int(at))
        end = min(len(buf), start + len(sig))
        if end > start:
            buf[start:end] += sig[:end - start] * gain

    chords = [CHORDS[name] for name in PROGRESSIONS[track.progression]]
    scale = MINOR_SCALE if track.is_minor else MAJOR_SCALE
    lead = set(track.lead)

    for bar in range(track.bars):
        chord = chords[bar % len(chords)]
        bar_at = bar * bar_samples
        # Humanise: a few milliseconds of drag, different every bar.
        def when(beats):
            return bar_at + beats * beat + rng.range(-0.010, 0.010) * SR

        # Bass.
        if "sub" in lead or "ep" in lead or "pad" in lead:
            place(sub(hz(track.root + chord[0] - 24), 1.9, rng.range(0.5, 0.62), rng), when(0))
            if track.energy >= 2 and rng.chance(0.45):
                place(sub(hz(track.root + chord[0] - 24), 1.1, 0.36, rng), when(2.5))

        # Chords.
        if "ep" in lead:
            for index, step in enumerate(chord):
                place(ep(hz(track.root + step), 2.6, rng.range(0.24, 0.33), rng),
                      when(0) + index * rng.range(0.004, 0.016) * SR)
            if rng.chance(0.6 * track.space):
                for step in chord[1:]:
                    place(ep(hz(track.root + step), 1.6, 0.18, rng), when(2))
        if "pad" in lead:
            for step in chord:
                place(pad(hz(track.root + step - 12), track.meter * 60.0 / track.bpm + 1.4,
                          rng.range(0.16, 0.22), rng), when(0))

        # Melody: chord tones with the odd passing note, never on every beat.
        melody_voice = next((v for v in ("musicbox", "celesta", "marimba", "pluck") if v in lead), None)
        if melody_voice:
            voice = INSTRUMENTS[melody_voice]
            slots = [0.0, 1.0, 1.5, 2.0, 3.0, 3.5]
            for slot in slots:
                if not rng.chance((0.42 if track.energy < 3 else 0.55) * track.space):
                    continue
                if rng.chance(0.72):
                    step = rng.pick(chord)
                else:
                    step = rng.pick(scale) + rng.pick([0, 12])
                place(voice(hz(track.root + step + 12), 1.8, rng.range(0.20, 0.30), rng), when(slot))

        # Percussion — half-time, which is most of what makes it lo-fi.
        if track.energy >= 2:
            place(kick(0.5, rng.range(0.42, 0.52), rng), when(0))
            if rng.chance(0.8):
                place(kick(0.45, 0.34, rng), when(2.5 if rng.chance(0.5) else 3.0))
        if "brush" in lead:
            place(brush(0.35, rng.range(0.26, 0.34), rng), when(2))
        if "shaker" in lead:
            for slot in (0.5, 1.5, 2.5, 3.5):
                place(shaker(0.14, rng.range(0.10, 0.17), rng), when(slot))
        if "hat" in lead:
            for slot in np.arange(0, track.meter, 0.5):
                place(hat(0.09, 0.07 if slot % 1 else 0.11, rng), when(float(slot)))
        if "clack" in lead:
            place(clack(0.4, rng.range(0.30, 0.40), rng), when(0))
            place(clack(0.4, rng.range(0.24, 0.32), rng), when(2))

    # Wrap the ring-out onto the head so decays continue across the seam. This,
    # not a crossfade, is what makes a musical loop seamless.
    buf[:tail] += buf[total:total + tail]
    signal = buf[:total]
    signal = signal + bed(track.texture, total, rng)
    return master(signal, rng, track.room), bar_samples


# --- Checks -----------------------------------------------------------------

def verify(track, signal, bar_samples):
    seconds = len(signal) / SR
    problems = []
    if not (MIN_SECONDS <= seconds <= MAX_SECONDS):
        problems.append(f"duration {seconds:.1f}s outside {MIN_SECONDS}-{MAX_SECONDS}s")
    if len(signal) % bar_samples != 0:
        problems.append("length is not a whole number of bars")
    peak = float(np.max(np.abs(signal)))
    if peak > PEAK_CEILING + 1e-6:
        problems.append(f"peak {peak:.3f} over ceiling")
    rms = float(np.sqrt(np.mean(signal ** 2)))
    if abs(20 * np.log10(rms / TARGET_RMS)) > 1.5:
        problems.append(f"rms {rms:.4f} more than 1.5 dB from target")
    # The seam: what matters is the single step from the last sample to the
    # first, since that is what the loop actually plays. Comparing whole
    # windows instead — the first version's mistake — just measures that the
    # end of a tune sounds different from its beginning, which it always does.
    steps = np.abs(np.diff(signal))
    seam = abs(float(signal[0] - signal[-1]))
    worst_ordinary = float(np.percentile(steps, 99.9))
    if seam > worst_ordinary * 4:
        problems.append(
            f"seam step {seam:.5f} vs ordinary {worst_ordinary:.5f}"
        )
    if problems:
        raise AssertionError(f"{track.id}: " + "; ".join(problems))
    return seconds


def write_wav(path, signal):
    pcm = (np.clip(signal, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(pcm.tobytes())


def encode(wav_path, m4a_path):
    subprocess.run(
        ["afconvert", "-f", "m4af", "-d", "aac", "-b", "64000",
         "-q", "127", wav_path, m4a_path],
        check=True, capture_output=True,
    )


# --- The catalogue ----------------------------------------------------------

COLLECTIONS = [
    # id, title, blurb, gate
    ("chill1", "Paws & Chill I", "The classic study loop.", "free"),
    ("meadow", "Meadow Mornings", "Gentle, and a little birdsong.", "arrival:meadow"),
    ("woods", "Under the Pines", "Minor keys, wind and water.", "arrival:woods"),
    ("harbor", "Saltwater Tapes", "Slower, with the tide underneath.", "arrival:harbor"),
    ("blossom", "Lantern Nights", "Evening music, music box forward.", "arrival:blossom"),
    ("chill2", "Paws & Chill II", "Five more of the same warmth.", "plus"),
    ("cloudspire", "Cloudspire Drift", "Airy and sparse, mostly pads.", "plus"),
    ("nighttrain", "Night Train", "Rail rhythm at half speed.", "plus"),
    ("onsen", "Moonlit Onsen", "Mallets and plucks over water.", "plus"),
    ("starfall", "Starfall", "The sparsest set. Space between notes.", "plus"),
    # Phase W's three. Not free, not bought, not travelled to — found, by
    # playing a certain way. See MusicGate.found and MusicFinding.
    ("rainyday", "Rainy Day Tapes", "Written to leave room for the rain.",
     "found:rainyday"),
    ("nightshift", "Night Shift", "For the hours nobody else is up for.",
     "found:nightshift"),
    ("soot", "Soot's Tape", "Five lullabies. Nobody knows where she got them.",
     "found:soot"),
]

TRACKS = [
    Track(1, "first_light", "First Light Loop", "chill1", "free", 70, "C", "I-vi-IV-V", ["ep", "brush"], "crackle", 2),
    Track(2, "homework_for_two", "Homework for Two", "chill1", "free", 72, "A", "i-VI-III-VII", ["ep", "sub"], "rain", 2),
    Track(3, "corner_desk", "Corner Desk", "chill1", "free", 68, "F", "I-IV-vi-V", ["marimba", "ep"], "crackle", 2),
    Track(4, "sleepy_metronome", "Sleepy Metronome", "chill1", "free", 66, "G", "I-iii-IV-I", ["musicbox", "pad"], None, 1),
    Track(5, "warm_static", "Warm Static", "chill1", "free", 74, "D", "i-iv-VII-III", ["ep"], "crackle_heavy", 2),

    Track(6, "dew_on_the_fence", "Dew on the Fence", "meadow", "arrival:meadow", 76, "G", "I-IV-vi-V", ["marimba", "shaker"], "birds", 3),
    Track(7, "kettle_song", "Kettle Song", "meadow", "arrival:meadow", 70, "C", "ii-V-I-vi", ["musicbox", "ep"], "crackle", 2),
    Track(8, "clover_rows", "Clover Rows", "meadow", "arrival:meadow", 72, "D", "I-vi-IV-V", ["pluck", "pad"], "birds", 2),
    Track(9, "biscuits_nap", "Biscuit's Nap", "meadow", "arrival:meadow", 64, "F", "I-iii-IV-I", ["pad", "sub"], "wind", 1),
    Track(10, "chimney_smoke", "Chimney Smoke", "meadow", "arrival:meadow", 68, "A", "i-VII-VI-V", ["ep"], "crackle", 1),

    Track(11, "needle_carpet", "Needle Carpet", "woods", "arrival:woods", 66, "E", "i-VI-III-VII", ["pad", "marimba"], "wind", 1),
    Track(12, "creekside_study", "Creekside Study", "woods", "arrival:woods", 70, "G", "I-V-vi-IV", ["ep"], "water", 2),
    Track(13, "mushroom_lamp", "Mushroom Lamp", "woods", "arrival:woods", 62, "C", "i-iv-VII-III", ["musicbox"], "crickets", 1),
    Track(14, "old_log_bridge", "Old Log Bridge", "woods", "arrival:woods", 72, "D", "I-IV-vi-V", ["marimba", "brush"], "water", 2),
    Track(15, "fern_light", "Fern Light", "woods", "arrival:woods", 68, "A", "I-iii-IV-I", ["pad"], "birds", 1),

    Track(16, "slow_tide", "Slow Tide", "harbor", "arrival:harbor", 63, "C", "I-vi-IV-V", ["pad", "sub"], "waves", 1),
    Track(17, "rope_and_plank", "Rope & Plank", "harbor", "arrival:harbor", 74, "F", "I-IV-vi-V", ["ep", "shaker"], "waves", 2),
    Track(18, "lighthouse_pulse", "Lighthouse Pulse", "harbor", "arrival:harbor", 70, "A", "i-VI-III-VII", ["sub", "pad"], "waves", 2),
    Track(19, "ferry_at_noon", "Ferry at Noon", "harbor", "arrival:harbor", 72, "Bb", "ii-V-I-vi", ["ep", "brush"], "crackle", 2),
    Track(20, "salt_on_glass", "Salt on Glass", "harbor", "arrival:harbor", 66, "D", "i-VII-VI-V", ["ep"], "waves", 1),

    Track(21, "paper_glow", "Paper Glow", "blossom", "arrival:blossom", 64, "E", "i-VI-III-VII", ["musicbox", "pad"], "crickets", 1),
    Track(22, "petal_drift", "Petal Drift", "blossom", "arrival:blossom", 70, "C", "I-vi-IV-V", ["ep", "marimba"], None, 2),
    Track(23, "waterfall_ink", "Waterfall Ink", "blossom", "arrival:blossom", 68, "G", "I-V-vi-IV", ["pluck"], "water", 2),
    Track(24, "festival_ended", "Festival Ended", "blossom", "arrival:blossom", 60, "A", "i-iv-VII-III", ["pad"], "crackle", 1),
    Track(25, "terrace_steps", "Terrace Steps", "blossom", "arrival:blossom", 72, "F", "I-IV-vi-V", ["ep", "shaker"], None, 2),

    Track(26, "second_wind", "Second Wind", "chill2", "plus", 74, "E", "i-VI-III-VII", ["ep", "brush"], "crackle", 2),
    Track(27, "margin_notes", "Margin Notes", "chill2", "plus", 70, "C", "ii-V-I-vi", ["ep", "marimba"], "rain", 2),
    Track(28, "half_closed_eyes", "Half-Closed Eyes", "chill2", "plus", 64, "F", "I-iii-IV-I", ["pad", "ep"], "crackle", 1),
    Track(29, "borrowed_sweater", "Borrowed Sweater", "chill2", "plus", 68, "A", "i-VII-VI-V", ["ep"], "rain", 1),
    Track(30, "sunday_loop", "Sunday Loop", "chill2", "plus", 72, "G", "I-vi-IV-V", ["musicbox", "brush"], "crackle", 2),

    Track(31, "above_the_weather", "Above the Weather", "cloudspire", "plus", 58, "C", "I-V-vi-IV", ["pad"], "wind", 1),
    Track(32, "balloon_mail", "Balloon Mail", "cloudspire", "plus", 66, "G", "I-IV-I-V", ["ep", "pad"], "wind", 1),
    Track(33, "roots_in_the_sky", "Roots in the Sky", "cloudspire", "plus", 62, "D", "i-VI-III-VII", ["pad", "sub"], None, 1),
    Track(34, "thin_air_waltz", "Thin Air Waltz", "cloudspire", "plus", 84, "F", "I-vi-IV-V", ["musicbox"], "wind", 2, 3),
    Track(35, "anchorless", "Anchorless", "cloudspire", "plus", 60, "A", "i-v-VI-VII", ["pad"], "wind", 1),

    Track(36, "sleeper_car", "Sleeper Car", "nighttrain", "plus", 52, "A", "i-VI-III-VII", ["clack", "sub", "ep"], "rumble", 2),
    Track(37, "viaduct", "Viaduct", "nighttrain", "plus", 56, "E", "i-iv-VII-III", ["clack", "pad"], "rumble", 2),
    Track(38, "window_seat", "Window Seat", "nighttrain", "plus", 60, "C", "I-vi-IV-V", ["ep", "brush"], "rumble", 2),
    Track(39, "tunnel_counting", "Tunnel Counting", "nighttrain", "plus", 54, "D", "i-VII-VI-V", ["clack", "musicbox"], "rumble", 2),
    Track(40, "last_stop_lullaby", "Last Stop Lullaby", "nighttrain", "plus", 48, "F", "I-iii-IV-I", ["musicbox", "pad"], None, 1),

    Track(41, "steam_rise", "Steam Rise", "onsen", "plus", 62, "A", "i-v-VI-VII", ["pluck"], "water", 1),
    Track(42, "stone_and_water", "Stone & Water", "onsen", "plus", 66, "D", "I-V-vi-IV", ["marimba"], "water", 2),
    Track(43, "capybara_club", "Capybara Club", "onsen", "plus", 70, "G", "I-IV-vi-V", ["ep", "shaker"], "water", 2),
    Track(44, "warm_to_the_bone", "Warm to the Bone", "onsen", "plus", 58, "C", "I-IV-I-V", ["pad", "sub"], "water", 1),
    Track(45, "snow_on_cedar", "Snow on Cedar", "onsen", "plus", 60, "E", "i-VI-III-VII", ["musicbox"], "wind", 1),

    Track(46, "meteor_ledger", "Meteor Ledger", "starfall", "plus", 54, "C", "I-V-vi-IV", ["celesta", "pad"], "crickets", 1),
    Track(47, "counting_in_the_dark", "Counting in the Dark", "starfall", "plus", 50, "A", "i-VI-III-VII", ["pad", "sub"], None, 1),
    Track(48, "ridge_light", "Ridge Light", "starfall", "plus", 58, "F", "I-iii-IV-I", ["ep"], "wind", 1),
    Track(49, "perseid_tape", "Perseid Tape", "starfall", "plus", 56, "D", "i-iv-VII-III", ["musicbox"], "crickets", 1),
    Track(50, "hello_moon", "Hello, Moon", "starfall", "plus", 46, "C", "I-V-vi-IV", ["pad", "celesta"], "crickets", 1),

    # --- Rainy Day Tapes ----------------------------------------------------
    #
    # These are the only tracks in the catalogue written to be heard *with*
    # something else. Three rules follow from that and all three are in the
    # recipes rather than in a mixing note: no texture bed (the rain loop is
    # the bed, and a second one is mud), a brush kit and never a hat or a
    # shaker (both live exactly where rain does and both lose), and the "rain"
    # room, which takes 4 dB out of 1.2-3 kHz so the loop can sit in the gap.
    Track(51, "windowpane_study", "Windowpane Study", "rainyday", "found:rainyday", 66, "C", "I-vi-IV-V", ["ep", "brush"], None, 1, space=0.78, room="rain"),
    Track(52, "gutter_song", "Gutter Song", "rainyday", "found:rainyday", 62, "A", "i-VI-III-VII", ["pad", "sub"], None, 1, space=0.72, room="rain"),
    Track(53, "second_umbrella", "Second Umbrella", "rainyday", "found:rainyday", 70, "F", "I-IV-vi-V", ["marimba", "brush"], None, 2, space=0.80, room="rain"),
    Track(54, "wet_pavement", "Wet Pavement", "rainyday", "found:rainyday", 64, "D", "i-VII-VI-V", ["ep", "pad"], None, 1, space=0.70, room="rain"),
    Track(55, "nothing_urgent", "Nothing Urgent", "rainyday", "found:rainyday", 68, "G", "I-iii-IV-I", ["musicbox", "pad", "brush"], None, 2, space=0.74, room="rain"),

    # --- Night Shift --------------------------------------------------------
    #
    # Sub, pad and music box, and nothing above 4.3 kHz. Sister set to the star
    # atlas: found on the same after-dark counter the crickets are.
    Track(56, "third_coffee", "Third Coffee", "nightshift", "found:nightshift", 64, "C", "I-vi-IV-V", ["ep", "pad", "sub"], None, 1, space=0.76, room="night"),
    Track(57, "the_building_is_empty", "The Building Is Empty", "nightshift", "found:nightshift", 60, "E", "i-VI-III-VII", ["pad", "musicbox"], None, 1, space=0.68, room="night"),
    Track(58, "corridor_light", "Corridor Light", "nightshift", "found:nightshift", 66, "A", "i-VII-VI-V", ["musicbox", "sub", "pad"], "crackle", 1, space=0.72, room="night"),
    Track(59, "small_hours", "Small Hours", "nightshift", "found:nightshift", 62, "F", "I-iii-IV-I", ["pad", "ep"], None, 1, space=0.70, room="night"),
    Track(60, "nobody_is_awake", "Nobody Is Awake", "nightshift", "found:nightshift", 68, "D", "i-iv-VII-III", ["pad", "sub", "marimba"], "wind", 1, space=0.66, room="night"),

    # --- Soot's Tape --------------------------------------------------------
    #
    # Music box throughout, over a pad so the box has something to ring into.
    # Never for sale and never Plus: the one reward for the app's one hidden
    # story, on exactly the terms the stray herself is on.
    Track(61, "the_hedge", "The Hedge", "soot", "found:soot", 56, "A", "i-VI-III-VII", ["musicbox", "pad"], None, 1, space=0.62, room="lullaby"),
    Track(62, "fence_post", "Fence Post", "soot", "found:soot", 60, "C", "I-iii-IV-I", ["musicbox", "pad"], None, 1, space=0.66, room="lullaby"),
    Track(63, "six_feet_away", "Six Feet Away", "soot", "found:soot", 54, "E", "i-iv-VII-III", ["musicbox", "pad"], None, 1, space=0.58, room="lullaby"),
    Track(64, "she_stayed", "She Stayed", "soot", "found:soot", 58, "F", "I-vi-IV-V", ["musicbox", "pad"], "crackle", 1, space=0.64, room="lullaby"),
    Track(65, "indoor_cat", "Indoor Cat", "soot", "found:soot", 52, "C", "I-V-vi-IV", ["musicbox", "pad", "sub"], None, 1, space=0.60, room="lullaby"),
]


def swift_catalog(rendered):
    lines = [
        "// Generated by tools/generate_music.py — do not edit by hand.",
        "//",
        "// Loop frames are exact: the app trims the decoded AAC buffer to this",
        "// length before scheduling it as a looping buffer, which is what makes",
        "// playback gapless (the encoder adds priming samples that would",
        "// otherwise tick at every repeat).",
        "",
        "import Foundation",
        "",
        "/// One track in the Sound Almanac.",
        "struct MusicTrack: Identifiable, Equatable, Hashable {",
        "    let id: String",
        "    let title: String",
        "    let collection: String",
        "    let gate: MusicGate",
        "    let bpm: Int",
        "    /// 1 quiet, 2 steady, 3 brighter — used by radio mode to match the hour.",
        "    let energy: Int",
        "    /// Exact loop length in frames at 22.05 kHz.",
        "    let loopFrames: Int",
        "",
        "    var assetName: String { id }",
        "}",
        "",
        "enum MusicCatalog {",
        "    static let collections: [MusicCollection] = [",
    ]
    for ident, title, blurb, gate in COLLECTIONS:
        gate_expr = swift_gate(gate)
        lines.append(f'        MusicCollection(id: "{ident}", title: "{title}", '
                     f'blurb: "{blurb}", gate: {gate_expr}),')
    lines += ["    ]", "", "    static let tracks: [MusicTrack] = ["]
    for track, frames in rendered:
        lines.append(
            f'        MusicTrack(id: "{track.id}", title: "{track.title}", '
            f'collection: "{track.collection}", gate: {swift_gate(track.gate)}, '
            f'bpm: {track.bpm}, energy: {track.energy}, loopFrames: {frames}),'
        )
    lines += [
        "    ]",
        "",
        "    static func tracks(in collection: String) -> [MusicTrack] {",
        "        tracks.filter { $0.collection == collection }",
        "    }",
        "",
        "    static func track(id: String) -> MusicTrack? {",
        "        tracks.first { $0.id == id }",
        "    }",
        "",
        "    /// The one everybody starts with.",
        "    static var opener: MusicTrack { tracks[0] }",
        "}",
        "",
    ]
    return "\n".join(lines)


def swift_gate(gate):
    if gate == "free":
        return ".free"
    if gate == "plus":
        return ".plus"
    if gate.startswith("arrival:"):
        return f".arrival(.{gate.split(':')[1]})"
    if gate.startswith("found:"):
        return f".found(.{gate.split(':')[1]})"
    raise ValueError(gate)


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    os.makedirs(MUSIC, exist_ok=True)

    tracks = [t for t in TRACKS if only is None or t.collection == only]
    rendered = []
    total_bytes = 0

    print(f"Music ({len(tracks)} tracks):")
    for track in tracks:
        signal, bar_samples = render(track)
        seconds = verify(track, signal, bar_samples)

        wav_path = os.path.join(MUSIC, f"{track.id}.wav")
        m4a_path = os.path.join(MUSIC, f"{track.id}.m4a")
        write_wav(wav_path, signal)
        encode(wav_path, m4a_path)
        os.remove(wav_path)

        size = os.path.getsize(m4a_path)
        total_bytes += size
        rendered.append((track, len(signal)))
        print(f"  {track.number:2d}. {track.title:<22} {track.bpm:>3}bpm "
              f"{track.bars:>2} bars  {seconds:5.1f}s  {size / 1024:5.0f} KB")

    megabytes = total_bytes / (1024 * 1024)
    projected = megabytes / max(1, len(tracks)) * len(TRACKS)
    print(f"\n  {megabytes:.2f} MB for {len(tracks)} tracks "
          f"(all {len(TRACKS)} would be ~{projected:.1f} MB, "
          f"budget {TOTAL_BUDGET_MB:.0f} MB)")
    if projected > TOTAL_BUDGET_MB:
        raise AssertionError(f"projected catalogue {projected:.1f} MB exceeds budget")

    if only is None:
        with open(CATALOG, "w") as handle:
            handle.write(swift_catalog(rendered))
        print(f"  wrote {os.path.relpath(CATALOG, ROOT)}")


if __name__ == "__main__":
    main()
