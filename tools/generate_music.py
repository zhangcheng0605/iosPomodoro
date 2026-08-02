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


def master(sig, rng):
    sig = wobble(sig, rng)
    sig = lowpass(sig, 7200)
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
                 progression, lead, texture, energy, meter=4):
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
            if rng.chance(0.6):
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
                if not rng.chance(0.42 if track.energy < 3 else 0.55):
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
    return master(signal, rng), bar_samples


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
    projected = megabytes / max(1, len(tracks)) * 50
    print(f"\n  {megabytes:.2f} MB for {len(tracks)} tracks "
          f"(all 50 would be ~{projected:.1f} MB, budget {TOTAL_BUDGET_MB:.0f} MB)")
    if projected > TOTAL_BUDGET_MB:
        raise AssertionError(f"projected catalogue {projected:.1f} MB exceeds budget")

    if only is None:
        with open(CATALOG, "w") as handle:
            handle.write(swift_catalog(rendered))
        print(f"  wrote {os.path.relpath(CATALOG, ROOT)}")


if __name__ == "__main__":
    main()
