"""Generate Pawmodoro assets: app icon (PNG) + synthesized ambience loops (WAV).

All audio is procedurally synthesized here, so it is original content with no
licensing concerns. Swap for professionally recorded loops later if desired.
"""
import json
import os
import re
import subprocess
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SR = 22050
# Derived from this file's own location, like every other generator here.
# These were absolute paths into the Linux container they were written in,
# which meant the one generator that makes *audio* could only be run on the
# one machine that cannot hear it.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "Pawmodoro", "Resources")
ASSETS = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets")
ICONSET = os.path.join(ASSETS, "AppIcon.appiconset")
THEME_SWIFT = os.path.join(ROOT, "Pawmodoro", "Model", "AppTheme.swift")

# The paw, and the only colour in the icon that is not in a palette: the pads
# are a warm off-white rather than pure white so they sit on cream without a
# hard edge.
OFFWHITE = (255, 251, 246)

# The tomato's rim highlight, as a fraction of the icon's width. Named because
# `draw_icon` both draws it and decides whether it is thick enough to be worth
# drawing, and those two must be the same number.
RIM_WIDTH = 0.014

os.makedirs(RES, exist_ok=True)
os.makedirs(ICONSET, exist_ok=True)


# ------------------------------------------------------------- theme palettes
#
# The icon used to carry its own copy of Sakura's light palette as seven
# module constants "matching Theme.swift". They did match — every one rounded
# to the same byte — but that is luck, not a mechanism, and the house rule is
# blunt about it: if a tool has a list that another file also has, it is
# already wrong. So the icons ask the Swift instead. `parse_palettes` is the
# reason there can be five icons rather than one: a variant is a palette name,
# not a second drawing.

def parse_palettes(path=THEME_SWIFT):
    """Read `AppTheme.palette` out of the Swift.

    Returns {theme: {"light": {role: (r,g,b)}, "dark": {...}}} with each
    channel rounded to a byte. Deliberately strict — a palette that has grown
    a role, or a `case` whose body stops looking like `.dual(...)`, raises
    here rather than silently exporting the previous icon again.
    """
    source = open(path).read()
    body = source[source.index("var palette: Palette"):]
    body = body[:body.index("\n    }\n")]
    palettes = {}
    for chunk in re.split(r"\n        case \.", body)[1:]:
        theme = chunk.split(":", 1)[0].strip()
        light, dark = {}, {}
        for role, nums in re.findall(
                r"(\w+):\s*\.dual\(([^)]*)\)", chunk):
            values = [float(v) for v in nums.split(",")]
            assert len(values) == 6, f"{theme}.{role}: {values}"
            light[role] = tuple(int(round(v * 255)) for v in values[:3])
            dark[role] = tuple(int(round(v * 255)) for v in values[3:])
        assert len(light) >= 9, f"{theme}: only {len(light)} roles parsed"
        palettes[theme] = {"light": light, "dark": dark}
    assert len(palettes) == 8, f"{len(palettes)} themes parsed, expected 8"
    return palettes


PALETTES = parse_palettes()


def _luminance(rgb):
    """WCAG relative luminance, for choosing the paw by measurement."""
    channels = []
    for value in rgb:
        v = value / 255.0
        channels.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast(a, b):
    lo, hi = sorted((_luminance(a), _luminance(b)))
    return (hi + 0.05) / (lo + 0.05)


# ---------------------------------------------------------------- audio utils
def shaped_noise(n, rng, exponent, cutoff=None, order=2):
    """Noise with a 1/f**exponent spectrum and optional smooth lowpass."""
    half = n // 2 + 1
    spec = rng.normal(size=half) + 1j * rng.normal(size=half)
    freq = np.fft.rfftfreq(n, 1.0 / SR)
    gain = np.zeros_like(freq)
    gain[1:] = freq[1:] ** (-exponent)
    if cutoff:
        gain *= 1.0 / (1.0 + (freq / cutoff) ** (2 * order)) ** 0.5
    sig = np.fft.irfft(spec * gain, n)
    return sig / (np.max(np.abs(sig)) + 1e-12)


def seamless(sig, fade_n):
    """Crossfade the tail over the head so the loop repeats without a click."""
    length = len(sig) - fade_n
    out = sig[:length].copy()
    ramp = np.linspace(0.0, 1.0, fade_n)
    out[:fade_n] = out[:fade_n] * ramp + sig[length:] * (1.0 - ramp)
    return out


def normalize(sig, peak):
    return sig / (np.max(np.abs(sig)) + 1e-12) * peak


def encode(wav_path, m4a_path):
    """AAC, at the music catalogue's settings.

    macOS-only, exactly as `generate_music.py` has always been — `afconvert`
    is the encoder and there is no Linux equivalent that produces the same
    priming behaviour. The .m4a files are committed, so a Linux session can
    still change every recipe here; it just cannot re-encode, and the run
    says so rather than writing a half-updated Resources folder.
    """
    subprocess.run(
        ["afconvert", "-f", "m4af", "-d", "aac", "-b", "64000",
         "-q", "127", wav_path, m4a_path],
        check=True, capture_output=True)


# A bed you stop hearing, graded so that later sounds later.
LOOP_GRADES = {
    "dawn": (0.25, 0.92),
    "dusk": (0.55, 0.86),
    "night": (0.80, 0.72),
}

# An *event*, graded much harder, and deliberately not the table above.
#
# A loop at 0.72 is a quieter room; a bell at 0.72 at three in the morning is
# an interruption, which is the one thing the hour strike may never be. So the
# strike's night level is under a third of its noon level and its tilt is
# almost all the way over — at 3 a.m. it is felt more than heard, which is
# what "near-subliminal" has to mean for something that arrives without being
# asked for.
BELL_GRADES = {
    "dawn": (0.40, 0.55),
    "dusk": (0.55, 0.72),
    "night": (0.85, 0.30),
}


def graded(sig, part, grades=LOOP_GRADES):
    """One loop, at one time of day, by deterministic transform.

    The same idea `generate_scenes.py` applies to a place: draw it once, then
    grade it four ways rather than authoring four. A grade here is two knobs —
    a spectral tilt and a level — because those are what the ear actually
    reads as "later". Night is darker and quieter; dawn is thin and bright;
    dusk sits between. Day is the recipe unchanged, so the existing six sound
    exactly as they always have at noon.

    `grades` picks the table. Ambience uses the default; the hour bells pass
    `BELL_GRADES`, which is the same two knobs turned much further.

    **A loop is graded circularly, and that is not a detail.** The smoother is
    a one-pole filter, and a one-pole filter started from rest does not come
    back to where it began: the head of the graded buffer is missing the low
    frequencies the tail still has, so a loop that was seamless at noon has a
    step in it at dawn. Measured, that step was up to nine million times the
    median sample-to-sample difference — the three graded files were 24 dB
    worse at the wrap than the day file they came from, on every loop in the
    app. The steady-state response is applied in the frequency domain instead,
    which is *identical* to the recursion sample-for-sample everywhere except
    the first two hundred samples (checked: 5e-17), and periodic, so the tail
    leads back into the head exactly.

    A bell is not a loop, so it keeps the causal filter: an hour strike starts
    from silence and should be filtered from silence.
    """
    if part == "day":
        return sig
    # A one-pole tilt: mix the signal with a smoothed copy of itself. More
    # smoothing is a darker sound, and it costs one pass.
    tilt, level = grades[part]
    # Two passes of a simple lowpass; coefficient from the tilt.
    a = 0.35 + 0.55 * tilt
    if grades is LOOP_GRADES:
        n = len(sig)
        z = np.exp(-2j * np.pi * np.arange(n // 2 + 1) / n)
        response = (a / (1.0 - (1.0 - a) * z)) ** 2
        smoothed = np.fft.irfft(np.fft.rfft(sig) * response, n)
    else:
        smoothed = np.copy(sig)
        for _ in range(2):
            out = np.empty_like(smoothed)
            acc = 0.0
            for i in range(len(smoothed)):
                acc = acc + a * (smoothed[i] - acc)
                out[i] = acc
            smoothed = out
    return (sig * (1.0 - tilt) + smoothed * tilt) * level


VARIED = {"rain", "drizzle", "storm", "raintent"}


def write_varied(name, maker):
    """Three renderings of the same recipe, for the loops rain lives in.

    "No two rains" was the ask, and this is the cheapest honest version of
    it: the recipe is identical, the garnish seed is not, so the drops fall
    in different places and the thunder lands at a different moment. The
    session picks one from the day and the place, so today's rain is today's
    rain and tomorrow's is not.

    Only the rain family. Three variants of all eighteen loops would be two
    hundred files and thirty-odd megabytes for a difference nobody asked to
    hear in a library.
    """
    for variant in range(3):
        stem = name if variant == 0 else f"{name}_v{variant}"
        write_loop(stem, maker(variant=variant), quiet=(variant > 0))


def write_loop(name, sig, quiet=False):
    """A looping ambience: WAV out, AAC in, and the exact frame count kept.

    The same three-step the music takes, and for the same reason. AAC adds
    priming frames at the head and padding at the tail, so a decoder hands
    back more samples than were encoded; playing that back as a loop ticks
    every time round. The app trims the decoded buffer to the number below
    before scheduling it, which is why the number has to travel with the file.
    """
    # Variants are the same recipe at the same length, so only the base name
    # goes in the table — `Ambience` has no `.rain_v1` case and never should.
    if "_v" not in name:
        LOOP_FRAMES[name] = len(sig)
    total = 0
    for part in ("dawn", "day", "dusk", "night"):
        stem = name if part == "day" else f"{name}_{part}"
        wav_path = os.path.join(RES, stem + ".wav")
        m4a_path = os.path.join(RES, stem + ".m4a")
        write_wav(stem + ".wav", graded(sig, part))
        encode(wav_path, m4a_path)
        os.remove(wav_path)
        total += os.path.getsize(m4a_path)
    if not quiet:
        print(f"  {name}: 4 grades, {len(sig) / SR:.1f}s, "
              f"{total / 1024:.0f} KB, {len(sig)} frames")


LOOP_FRAMES = {}


def write_wav(name, sig):
    data = np.clip(sig, -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    path = os.path.join(RES, name)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())
    kb = os.path.getsize(path) / 1024
    print(f"  {name}: {len(sig) / SR:.1f}s, {kb:.0f} KB")


# ======================================================================
# The rain family — rain, drizzle, storm, raintent.
#
# The complaint was "it sounds like freaking noise", and for these four that
# was literally true rather than figuratively: `drizzle` measured a spectral
# flatness of 0.887 with a tilt of -0.1 dB per octave, which is the textbook
# definition of white noise. Four mechanisms produced it, and the helpers
# below exist one per mechanism:
#
#   * `shaped_noise` peak-normalises, so on loops whose energy was mostly
#     infrasonic the audible part came out 20-40 dB down. `_a_cnoise`
#     removes the sub-audible octaves inside the gain curve and returns unit
#     RMS instead, and `_a_to_lufs` sets the final level by loudness. That is
#     what collapsed a 36.5 dB spread across the shelf onto one number.
#   * The gusts were +-12 %, about 3 dB, which the ear reads as a flat hiss
#     rather than as weather. `_a_gust` breathes 10-15 dB on three coprime
#     rates.
#   * Every droplet was `np.sin` — a raindrop synthesised as a beep, thirty
#     of them a second. `droplet` and `membrane_tap` are resonances excited
#     by noise, which is both what water is and what stops the spectrum
#     being either flat or tonal.
#   * `seamless()` crossfades two uncorrelated noises, which sums to half
#     power and dips 2-3 dB at every wrap. Everything here is periodic in the
#     loop length by construction, so there is nothing to crossfade.
#
# The prefix is `_a_`/family-A-specific on purpose: three agents are voicing
# this file at once and these are deliberately not shared until somebody
# reconciles them.
# ======================================================================

def _a_cnoise(n, rng, exponent, cutoff=None, order=2, highpass=45.0,
              hp_order=4):
    """Circular 1/f**exponent noise, infrasound removed, at unit RMS.

    Three deliberate differences from `shaped_noise`:

    * it is periodic in `n` by construction — the spectrum is built on the
      loop's own rfft grid, so the last sample already joins the first and
      there is nothing for a crossfade to repair;
    * the sub-audible octaves come out inside the gain curve rather than
      through a filter run over the samples, which would break that;
    * it returns unit RMS, not unit peak. Peak normalisation is how rumble
      no phone can reproduce came to own the headroom of half the shelf.
    """
    half = n // 2 + 1
    spec = rng.normal(size=half) + 1j * rng.normal(size=half)
    freq = np.fft.rfftfreq(n, 1.0 / SR)
    gain = np.zeros_like(freq)
    gain[1:] = freq[1:] ** (-exponent)
    if cutoff:
        gain *= 1.0 / (1.0 + (freq / cutoff) ** (2 * order)) ** 0.5
    if highpass:
        ratio = (freq / highpass) ** (2 * hp_order)
        gain *= (ratio / (1.0 + ratio)) ** 0.5
    sig = np.fft.irfft(spec * gain, n)
    return sig / (np.sqrt(np.mean(sig ** 2)) + 1e-12)


def _a_shelf(sig, corner, db, order=1):
    """A high shelf on the loop's own rfft grid, so it stays circular."""
    freq = np.fft.rfftfreq(len(sig), 1.0 / SR)
    low = 1.0 / (1.0 + (freq / corner) ** (2 * order)) ** 0.5
    gain = low + (1.0 - low) * 10.0 ** (db / 20.0)
    return np.fft.irfft(np.fft.rfft(sig) * gain, len(sig))


def _a_gust(n, cycles=(1, 3, 7), amps=(0.55, 0.29, 0.16), floor=0.20,
            shape=1.5):
    """Weather breathing, at a whole number of cycles per loop.

    Integer counts are the whole of loop-exactness for an LFO: a gust 3.4
    cycles long has to be crossfaded and one 3 cycles long does not. Coprime
    counts mean the three only line up once, so the bed never settles into a
    period shorter than the file.
    """
    t = np.arange(n) / n
    g = np.zeros(n)
    for k, a in zip(cycles, amps):
        # Fixed phases, not rolled ones. The three rain renderings are meant
        # to differ in where the drops fall, not in how hard the weather
        # breathes; rolling the phases made one of the three storms peak
        # 4 dB harder than its siblings, which is a rendering nobody chose.
        g += a * np.sin(2 * np.pi * (k * t + (k * 0.6180339887) % 1.0))
    u = (g - g.min()) / (np.ptp(g) + 1e-12)
    return floor + (1.0 - floor) * u ** shape


def droplet(rng, length, centre, q=4.0, second=2.4, decay=9.0):
    """One drop: a resonance, not a beep.

    Water falling on water is a small bubble ringing and dying — narrowband,
    but not one frequency. Noise through a two-mode resonator is both, which
    is why this reads as a drop where `np.sin` read as a tone.
    """
    x = rng.normal(size=length)
    freq = np.fft.rfftfreq(length, 1.0 / SR)
    bw = centre / q
    g = 1.0 / (1.0 + ((freq - centre) / bw) ** 2)
    g += 0.3 / (1.0 + ((freq - centre * second) / (bw * 1.8)) ** 2)
    x = np.fft.irfft(np.fft.rfft(x) * g, length)
    x *= np.exp(-np.linspace(0.0, decay, length))
    return x / (np.max(np.abs(x)) + 1e-12)


def membrane_tap(rng, length, pitch, decay=34.0):
    """Canvas has a note, and every drop that lands excites it."""
    x = rng.normal(size=length)
    freq = np.fft.rfftfreq(length, 1.0 / SR)
    g = np.zeros_like(freq)
    for mult, amp, q in ((1.0, 1.0, 7.0), (1.59, 0.55, 9.0), (2.14, 0.28, 11.0)):
        bw = pitch * mult / q
        g += amp / (1.0 + ((freq - pitch * mult) / bw) ** 2)
    x = np.fft.irfft(np.fft.rfft(x) * g, length)
    x *= np.exp(-np.linspace(0.0, 6.0, length) * decay / 6.0)
    return x / (np.max(np.abs(x)) + 1e-12)


def scatter(n, rng, count, gust, make, gain=(0.05, 0.16), follow=1.0):
    """Sprinkle grains around the loop, wrapping the tail onto the head.

    `follow` ties both the density and the level of the grains to the gust,
    which is what makes a swell read as *more rain* rather than as the same
    rain turned up. Grains that run past the end wrap with `% n` — the same
    rule the music generator has always used for notes ringing past the last
    bar, and the reason nothing here needs a fade.
    """
    weight = gust ** follow if follow else np.ones(n)
    weight = weight / (np.sum(weight) + 1e-12)
    out = np.zeros(n)
    for start in rng.choice(n, size=count, p=weight):
        grain = make(rng)
        idx = (start + np.arange(len(grain))) % n
        out[idx] += grain * rng.uniform(*gain) * weight[start] * n
    return out


def _a_kweight_gain(n):
    """BS.1770 K-weighting as a magnitude curve on the loop's rfft bins.

    The standard is two biquads; their responses are evaluated analytically
    rather than run as a filter, because a per-sample IIR over a loop is the
    exact non-circular operation this whole section exists to avoid.
    """
    w = 2 * np.pi * np.fft.rfftfreq(n, 1.0 / SR) / SR
    z = np.exp(-1j * w)
    f0, gain_db, q = 1681.97, 3.999843, 0.7071752
    k = np.tan(np.pi * f0 / SR)
    vh = 10 ** (gain_db / 20.0)
    vb = vh ** 0.4996667
    a0 = 1.0 + k / q + k * k
    b = np.array([vh + vb * k / q + k * k, 2 * (k * k - vh),
                  vh - vb * k / q + k * k]) / a0
    a = np.array([1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0])
    h1 = (b[0] + b[1] * z + b[2] * z ** 2) / (a[0] + a[1] * z + a[2] * z ** 2)
    f0, q = 38.13547, 0.5003270
    k = np.tan(np.pi * f0 / SR)
    d = 1.0 + k / q + k * k
    a2 = np.array([1.0, 2 * (k * k - 1) / d, (1 - k / q + k * k) / d])
    h2 = (1.0 - 2.0 * z + z ** 2) / (a2[0] + a2[1] * z + a2[2] * z ** 2)
    return np.abs(h1 * h2)


def _a_to_lufs(sig, target=-26.0):
    """Set the level by loudness, never by peak.

    -26 LUFS is derived, not chosen: the sixty-five music tracks the owner
    has approved sit at -19.7 LUFS median and play at node volume 0.7, while
    ambience plays at 0.45. For a bed to sit about 10 dB under the music the
    file wants -19.7 - 10 + 3.8. Whether 10 dB is the right gap is a question
    for ears; that this is how the number is computed is not.
    """
    sig = sig - np.mean(sig)
    y = np.fft.rfft(sig) * _a_kweight_gain(len(sig))
    msq = 2.0 * np.sum(np.abs(y) ** 2) / (len(sig) ** 2)
    now = -0.691 + 10 * np.log10(msq + 1e-20)
    return sig * 10.0 ** ((target - now) / 20.0)


def _a_cut_at_lull(sig, window=0.35):
    """Rotate the loop so the wrap falls at its quietest moment.

    A tape is spliced where there is least to splice. It is free — the loop
    is circular, so every rotation of it is the same loop — and it is also
    what protects the three *graded* files: `graded()` runs a non-circular
    one-pole whose start-up error scales with the amplitude at the head, so
    a head already at the loop's minimum has the least error to make. That
    is measured, not assumed: the wrap of every one of these twelve loops
    stays inside |z| = 2.3 in all four grades, against 9 to 490 on the loops
    this section did not touch.
    """
    n = len(sig)
    w = max(8, int(SR * window))
    kernel = np.ones(w) / w
    power = np.fft.irfft(
        np.fft.rfft(sig ** 2) * np.conj(np.fft.rfft(kernel, n)), n)
    return np.roll(sig, -int(np.argmin(power)))


def wet_bed(n, rng, exponent, cutoff, shelf_hz, shelf_db, base=170.0):
    """The water itself: everything in the sound that is not a single drop.

    `base` is the number that stopped these four being a rumble. Rain
    outdoors has almost nothing under about 150 Hz; the old recipes put most
    of their energy there, which both ate the headroom and dragged the
    spectral centroid down to 200-500 Hz, where a phone speaker reproduces
    none of it.
    """
    bed = _a_cnoise(n, rng, exponent=exponent, cutoff=cutoff, order=1,
                    highpass=base, hp_order=2)
    return _a_shelf(bed, shelf_hz, shelf_db)


def thunder(n, rng, at, dur=3.6, level=0.5, cutoff=170.0):
    """A roll that has already happened, wrapped onto the head if it runs off."""
    out = np.zeros(n)
    for start_frac in at:
        length = min(int(SR * dur), n)
        roll = _a_cnoise(length, rng, exponent=1.6, cutoff=cutoff, order=2,
                         highpass=28.0)
        t = np.linspace(0.0, 1.0, length)
        roll *= (1.0 - np.exp(-t * 9.0)) * np.exp(-t * 2.6)
        roll *= 1.0 + 0.5 * np.sin(2 * np.pi * 1.7 * t)
        idx = (int(start_frac * n) + np.arange(length)) % n
        out[idx] += roll * level
    return out


# -------------------------------------------------------------------- rain
def make_rain(variant=0, dur=12.0):
    """Steady rain: a wet bed that breathes, with drops that ring.

    Measured against the old rendering: spectral flatness in the hiss band
    0.445 -> 0.295, the 2-8 kHz share 0.14 -> 0.04, the envelope's range
    11.0 -> 11.1 dB at a loudness 3 dB lower, and the infrasonic share
    0.42 -> 0.00.
    """
    rng = np.random.default_rng(7 + variant * 17)
    n = int(SR * dur)
    gust = _a_gust(n, cycles=(1, 3, 7), amps=(0.55, 0.29, 0.16),
                   floor=0.27, shape=1.25)
    bed = wet_bed(n, rng, exponent=0.95, cutoff=5000, shelf_hz=2600,
                  shelf_db=-4.0, base=175.0) * gust
    drops = scatter(
        n, rng, int(dur * 26), gust,
        lambda r: droplet(r, int(r.integers(240, 620)),
                          r.uniform(650.0, 2000.0), q=r.uniform(3.0, 6.5)),
        gain=(0.30, 0.80), follow=1.1)
    return _a_cut_at_lull(_a_to_lufs(bed + drops * 0.55))


# ======================================================================
# The textured beds — purr, fireplace, emberslate, nighttrain.
#
# The rain family's re-voicing was killed before it reached these four, and
# what the measurements found here was worse than what it found there. All
# four were built on `shaped_noise` with no highpass, so the gain curve ran
# as f**-exponent down to the loop's first bin — a twentieth of a Hertz —
# and *that* is where nearly all the energy went: 99.0 % of purr, 99.6 % of
# fireplace and 100.0 % of nighttrain sat under 120 Hz, with spectral
# centroids of 11, 24 and 4 Hz. `normalize()` then set the peak from that
# infrasonic drift, so the part a phone can reproduce came out 3 dB
# (purr), 13 dB (fireplace), 20 dB (emberslate) and **42 dB** (nighttrain)
# below the rain family's -26 LUFS. Nighttrain was, in the strict sense,
# not audible at all.
#
# So the fix is the same one, with one addition per loop, because each of
# these fails differently if it is a plain wash:
#
#   * a purr is *periodic* — 26 Hz, amplitude, and warm. It is heard on a
#     handset entirely through the harmonics of that pulse rate, so the
#     pulse has to be a sharp-edged one over a 100-1100 Hz bed rather than a
#     sine over a rumble no speaker can move.
#   * a fire is *discrete events*. The crackles are the character and they
#     are not spectrum; the roar is what they sit on. Measured as onsets per
#     second, the old fireplace had them (17.9/s) and simply played them
#     13 dB too quiet to hear.
#   * emberslate is the same machinery an hour later: sparser, duller, and
#     with no flame under it.
#   * a night train is periodic too, but at 0.72 Hz, and *distant* — which
#     in synthesis is a dark spectrum and a soft top, not merely a low
#     level.
#
# Every one is circular by construction and levelled by loudness, so none
# of them needs `seamless()` — which is just as well, because the crossfade
# was also what left the three graded files with a step at the wrap: the
# shipped fireplace_night measured a seam 217x its own median sample step.
# ======================================================================

# -------------------------------------------------------------------- purr
def make_purr(dur=8.0):
    """A cat, at 26 Hz, and audible on something you can hold.

    Two hundred and eight whole pulse cycles in eight seconds, which is what
    makes the modulation loop-exact without a fade. The pulse is a fast rise
    and a slower fall rather than a sine: the sharp edge is the whole reason
    this reads as a purr on a phone, because it puts harmonics of the 26 Hz
    rate up into the band the speaker can actually move. The fundamental
    itself is inaudible on any handset and always was.

    The breath does three things at once — level, modulation depth, and a
    crossfade between the same noise heard warm and heard bright — so the
    cat opens and closes rather than only getting louder. A little breath
    noise above 700 Hz sits on top so it is a live animal and not a filter.

    Measured against the old rendering: -28.9 -> -26.0 LUFS, the share under
    120 Hz 0.99 -> 0.31, the centroid 11 -> 410 Hz, the 2-8 kHz share 0.000
    -> 0.031, and the envelope's periodicity now peaks at 26.5 Hz where
    before it peaked at 10.4.
    """
    rng = np.random.default_rng(11)
    n = int(SR * dur)
    t = np.arange(n) / SR

    rate = 26.0
    assert abs(rate * dur - round(rate * dur)) < 1e-9, "purr rate must be whole"

    phase = (rate * t) % 1.0
    pulse = np.exp(-phase * 5.5) * (1.0 - np.exp(-phase * 70.0))
    pulse /= pulse.max()

    warm = _a_cnoise(n, rng, exponent=1.00, cutoff=1100, order=1,
                     highpass=100.0, hp_order=2)
    bright = _a_shelf(warm, 550.0, 9.0)

    breath = 0.5 + 0.5 * np.sin(2 * np.pi * 0.25 * t)
    bed = warm + 0.5 * breath * (bright - warm)

    depth = 0.62 + 0.30 * breath
    body = bed * ((1.0 - depth) + depth * pulse) * (0.42 + 0.58 * breath)

    air = _a_cnoise(n, rng, exponent=0.55, cutoff=5200, order=1,
                    highpass=700.0, hp_order=2)
    air *= 0.55 + 0.45 * breath

    return _a_cut_at_lull(
        _a_to_lufs(_a_shelf(body, 2600.0, -8.0) + air * 0.11))


# --------------------------------------------------------------- fireplace
def make_fireplace(dur=12.0):
    """A fire, which is crackles over a roar and not the other way round.

    Two populations, because wood makes two sounds: thirty *ticks* a second
    of loop — short, bright, resonant — and a couple of *pops* a second that
    are longer, lower and louder. Both are noise through a resonator with an
    instant attack, which is what a crackle is; both are scattered by
    `scatter`, so they wrap round the loop and follow the draw.

    The draw is the fire breathing, and it breathes harder than weather does
    at 10 dB rather than 3 — a fire that does not surge is a hairdryer.

    Measured against the old rendering: -39.2 -> -26.0 LUFS, the share under
    120 Hz 0.996 -> 0.145, the centroid 24 -> 721 Hz, the 2-8 kHz share
    0.002 -> 0.084, and 15.0 onsets a second that can now be heard.
    """
    rng = np.random.default_rng(23)
    n = int(SR * dur)
    draw = _a_gust(n, cycles=(1, 2, 5), amps=(0.50, 0.30, 0.20),
                   floor=0.34, shape=1.20)
    roar = _a_shelf(_a_cnoise(n, rng, exponent=0.85, cutoff=1500, order=1,
                              highpass=120.0, hp_order=2), 2200.0, -4.0) * draw

    ticks = scatter(
        n, rng, int(dur * 30), draw,
        lambda r: droplet(r, int(r.integers(50, 190)),
                          r.uniform(900.0, 3200.0),
                          q=r.uniform(1.6, 3.4), second=r.uniform(1.7, 2.9),
                          decay=r.uniform(9.0, 16.0)),
        gain=(1.0, 3.6), follow=1.0)
    pops = scatter(
        n, rng, int(dur * 2.5), draw,
        lambda r: droplet(r, int(r.integers(400, 1100)),
                          r.uniform(320.0, 900.0),
                          q=r.uniform(2.0, 4.0), decay=r.uniform(7.0, 11.0)),
        gain=(2.0, 6.0), follow=0.8)
    return _a_cut_at_lull(
        _a_to_lufs(roar * 0.85 + ticks * 1.15 + pops * 0.65))


# ============================================================================
# The rooms — forest, cafe, library, temple.
#
# The trap here is the opposite of the rain family's. Rain is a wash and the
# old recipes made it a *white* wash; a room is mostly quiet, so a bed that is
# audible at all is usually already too loud, and everything that makes the
# place recognisable lives in sparse events rather than in the wash. All four
# of these were built the other way round — a continuous bed carrying the
# whole sound, with a few `np.sin` beeps dropped on top — and all four
# measured it:
#
#   forest    -32.3 LUFS, 98 % of its energy under 60 Hz, and **70 %** of what
#             was left in 2-8 kHz. Bright bursts of `exponent=0.2, cutoff=8000`
#             noise three times a second: that is not a branch moving, it is a
#             hiss gate. The birds were sine sweeps at 2.2-3.4 kHz, about
#             fifty of them per fourteen-second loop — a bird every 0.3 s.
#   cafe      -41.3 LUFS and **94 %** of the audible band in 2-8 kHz, because
#             a "cup" was two sine waves at 2.3-3.1 and 4.2-5.4 kHz with a
#             30 ms decay. Twenty-one of them a loop. That is a smoke alarm,
#             not a saucer.
#   library   -57.0 LUFS. Thirty-one decibels under the rest of the shelf on
#             one shared node volume, 100 % of its energy infrasonic: nobody
#             has ever heard this loop. The events it is made of were there
#             and were fine; they were 30 dB too quiet to arrive.
#   temple    -24.6 LUFS, the loudest thing on the shelf, tilted -13 dB per
#             octave with a measured 2-8 kHz share of **0.000** and a spectral
#             flatness of 0.000. A drone with a sine bank on top.
#
# Six rules, and they are the room-shaped version of the ones the water and
# weather families already follow:
#
#  1. **Circular, end to end** — `b_cnoise`, `b_gust`, `b_grains`, and every
#     grain placed with `_r_place`'s `% n`. Nothing here calls `seamless()`,
#     so nothing pays its 2-3 dB power dip at the wrap.
#  2. **Levelled to loudness.** These four spanned 32.4 LUFS between them.
#     They now sit within 2.5 dB of each other and of the water family, so
#     picking a room is picking a room and not a volume.
#  3. **No infrasound.** All four were 88-100 % sub-60 Hz, which is both
#     inaudible and — through `normalize(peak)` — what the level was being
#     divided by. Every bed here is high-passed inside its own gain curve.
#  4. **A small hard thing is a resonance, not a sine.** `_r_struck` is
#     `membrane_tap` generalised: noise through a bank of narrow modes with a
#     fast decay. It is what a clink, a page, a chair and a bell's mallet are
#     all made of below.
#  5. **A room is heard, not just what is in it.** `_r_room` convolves a
#     layer with a decaying-noise tail *circularly*, which is what puts the
#     page two tables away and the bird at the top of the wood. It is also
#     why the loop survives it: circular convolution is periodic.
#  6. **The events carry the loop, and the bed gets out of the way.** The
#     library's room tone is at 0.014 of its own noise and the whole point is
#     that you cannot quite hear it.
#
# Two measurements deserve their own note, because both look like failures
# and are not. **Temple's spectral flatness is 0.003** — but a temple bell
# *is* tonal, and the drone test is the envelope, which reads 0.71 with 18 dB
# of range. **Library's crest factor is 29 dB** — but a silent room with a
# page turned in it has a 29 dB crest by definition; it is levelled to a
# ceiling rather than a target for exactly that reason, and the achieved
# loudness is reported rather than assumed.
#
# `_r_` for the same reason `_a_` and `b_` exist: three agents were voicing
# this file at once. When somebody reconciles them, `_r_struck` belongs next
# to `membrane_tap` and `_r_to_lufs` is `b_to_lufs` with a ceiling.
# ============================================================================

def _r_to_lufs(sig, target, ceiling=0.85):
    """Level by loudness, but never past a peak ceiling.

    `b_to_lufs` asserts on a peak over 0.95 because a bed that trips it has a
    bug in it. A *room* can trip it honestly: the library is silence with
    seven transients in it, so the gated loudness is measuring the page turns
    and the peaks are 29 dB above the mean. Backing off to the ceiling loses
    half a decibel of loudness and keeps the transient intact, which is the
    right trade for a sound whose whole character is its transients.

    Iterated rather than one-shot: BS.1770's *relative* gate is
    scale-equivariant, but its absolute -70 LUFS gate is not, and on a loop
    this sparse the two disagree by a few tenths on the first pass.
    """
    sig = sig - np.mean(sig)
    for _ in range(4):
        now = b_lufs(sig)
        if abs(now - target) < 0.01:
            break
        sig = sig * 10.0 ** ((target - now) / 20.0)
    peak = float(np.max(np.abs(sig)))
    if peak > ceiling:
        sig = sig * (ceiling / peak)
    return sig


def _r_place(out, grain, start):
    """Drop a grain into the loop, wrapping the tail onto the head."""
    n = len(out)
    idx = (int(start) + np.arange(len(grain))) % n
    np.add.at(out, idx, grain)
    return out


def _r_room(sig, rng, rt=0.5, pre=0.010, mix=0.45, cutoff=3200.0):
    """Put a layer in a room, by *circular* convolution with a decaying tail.

    Distance is what separates "a page turning" from "a page turning two
    tables away", and it is three things: a delay before the reflections, a
    tail, and a lost top end. Done as a frequency-domain multiply over the
    whole loop, so the tail of the last event wraps onto the head and the
    loop stays exact — a time-domain convolution would leave `len(ir)`
    samples of missing reverb at the seam.

    The wet signal is matched to the dry one's RMS before mixing, so `mix`
    means what it says instead of also being a volume control.
    """
    n = len(sig)
    length = min(int(SR * rt * 3.0), n)
    t = np.linspace(0.0, rt * 3.0, length)
    ir = rng.normal(size=length) * np.exp(-t * (6.9 / rt))
    ir[:int(SR * pre)] = 0.0
    ir = distant(ir, cutoff, order=2)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-12
    full = np.zeros(n)
    full[:length] = ir
    wet = np.fft.irfft(np.fft.rfft(sig) * np.fft.rfft(full), n)
    wet *= ((np.sqrt(np.mean(sig ** 2)) + 1e-20)
            / (np.sqrt(np.mean(wet ** 2)) + 1e-20))
    return sig * (1.0 - mix) + wet * mix


def _r_struck(rng, length, modes, decay=30.0, strike=0.03):
    """Something small and hard, hit once: noise through a bank of modes.

    `membrane_tap` with an arbitrary mode list. The old cafe's cup was
    `sin(2400t) + 0.5 sin(4800t)` under a 30 ms exponential — two pure tones,
    which is what "piercing" is made of and why 94 % of that loop's audible
    energy sat in the 2-8 kHz band. A cup is a body with a few inharmonic
    resonances and a noisy attack; excite the same frequencies with noise and
    it is the same pitch with something underneath it.

    `strike` is the mallet, tack or fingernail — a little unresonated top end
    at the instant of contact, without which every one of these reads as a
    synthesiser rather than as a collision.
    """
    x = rng.normal(size=length)
    f = np.fft.rfftfreq(length, 1.0 / SR)
    g = np.zeros_like(f)
    for freq, amp, q in modes:
        bw = freq / q
        g += amp / (1.0 + ((f - freq) / bw) ** 2)
    g += strike / (1.0 + (f / 5000.0) ** 4) * (f > 300.0)
    x = np.fft.irfft(np.fft.rfft(x) * g, length)
    x *= np.exp(-np.linspace(0.0, decay, length))
    return x / (np.max(np.abs(x)) + 1e-12)


def _r_bell(rng, length, f0, partials, beat=1.6):
    """A bell: inharmonic partials, each with its own decay, and a warble.

    Two things make this a bell rather than the old temple's organ chord.
    *Per-partial decay* — the top of a bell dies in a second and the prime
    rings for fifteen, so the sound darkens as it fades, which is the single
    most recognisable thing about struck bronze. And *beating*: a real bell
    is never quite rotationally symmetric, so each partial is two frequencies
    a fraction of a hertz apart and the tail shimmers. Scaled by the partial
    ratio, so the top shimmers faster than the hum, exactly as the asymmetry
    would produce.

    The strike itself is `_r_struck` over the same modes, because a bell
    begins with a hammer hitting metal and not with a fade-in.
    """
    t = np.arange(length) / SR
    out = np.zeros(length)
    for ratio, amp, decay in partials:
        f = f0 * ratio
        for sign in (-1.0, 1.0):
            out += 0.5 * amp * np.exp(-t * decay) * np.sin(
                2 * np.pi * (f + sign * beat * ratio * 0.5) * t
                + rng.uniform(0.0, 2 * np.pi))
    head = min(int(SR * 0.35), length)
    modes = [(f0 * r, a, 24.0) for r, a, _ in partials[:6]]
    out[:head] += _r_struck(rng, head, modes, decay=14.0, strike=0.06) * 0.60
    return out / (np.max(np.abs(out)) + 1e-12)


# ------------------------------------------------------------- forest (Plus)
def make_forest(dur=22.0):
    """Leaves, and birds far off. Sparse, directional, never a drone.

    The old one had the parts right and every level wrong. Leaf rustle is not
    a bright burst three times a second — that reads as a hiss being switched
    on and off, and it put 70 % of the audible energy in 2-8 kHz. It is a
    band around a kilohertz that comes and goes with the wind, with
    individual leaves ticking only where the wind is actually moving. So the
    canopy rides `breeze ** 2.3`: at the bottom of a lull there is almost
    nothing, which is what makes it a wood and not a fan.

    The birds are three phrases in twenty-four seconds rather than fifty
    chirps in fourteen, they are *far* — lowpassed at 3 kHz and mostly
    reverb — and each note carries a struck resonance under the sweep so it
    has a throat. Lengthened to 24 s for one reason: a bird that repeats
    every fourteen seconds is a ringtone.

    Measured, day grade, on the >140 Hz part: -32.3 -> -26.5 LUFS, sub-60 Hz
    share 0.98 -> 0.00, 2-8 kHz share 0.70 -> 0.13, centroid 3172 -> 1102 Hz,
    tilt -2.1 -> -9.2 dB/octave, envelope range 21.7 -> 21.3 dB.
    """
    rng = np.random.default_rng(31)
    n = int(SR * dur)

    breeze = b_gust(n, (2, 3, 7), (0.52, 0.33, 0.18), (0.0, 1.9, 4.2), 0.05)

    canopy = b_shelf(
        b_band(b_cnoise(n, rng, exponent=0.6, corner=4600, order=1,
                        hp=320.0, hp_order=6), 600.0, 3600.0, order=2),
        1800.0, -8.0)
    sig = canopy * breeze ** 2.3

    # Air under the canopy, so the wood has a floor to stand on.
    under = b_shelf(b_cnoise(n, rng, exponent=0.95, corner=1100, order=1,
                             hp=150.0, hp_order=6), 500.0, -7.0)
    sig = sig + under * (0.14 + 0.86 * breeze) * 0.26

    # Individual leaves, and only where the wind is.
    env = b_grains(n, rng, int(dur * 14), np.clip(breeze ** 2.6, 0.0, 1.0),
                   200, 700, decay=7.0)
    ticks = b_cnoise(n, rng, exponent=0.25, hp=800.0, hp_order=2)
    sig = sig + b_band(ticks * env, 900.0, 3600.0, order=2) * 0.36

    birds = np.zeros(n)
    for phrase in range(3):
        at = int(n * (0.10 + 0.31 * phrase + rng.uniform(-0.04, 0.04)))
        f0 = rng.uniform(1700.0, 2500.0)
        for note in range(int(rng.integers(2, 5))):
            length = int(rng.integers(900, 1900))
            local = np.arange(length) / SR
            top = f0 * rng.uniform(0.82, 1.28)
            sweep = f0 + (top - f0) * (local / local[-1]) ** rng.uniform(0.6, 1.8)
            # Integrated, not `f * t`: multiplying a swept frequency by time
            # sweeps at twice the rate you asked for and lands on the wrong note.
            phase = 2 * np.pi * np.cumsum(sweep) / SR
            note_sig = np.sin(phase) + 0.28 * np.sin(2 * phase)
            note_sig *= np.hanning(length) ** 1.4
            note_sig += _r_struck(rng, length,
                                  [(f0, 1.0, 24.0), (2 * f0, 0.4, 30.0)],
                                  decay=9.0) * 0.30
            _r_place(birds, note_sig * rng.uniform(0.55, 1.0),
                     at + note * int(rng.integers(2600, 5200)))
    birds = distant(birds, 3000.0, order=2)
    birds = _r_room(birds, rng, rt=0.8, pre=0.02, mix=0.45, cutoff=2600.0)
    sig = sig + birds / (np.max(np.abs(birds)) + 1e-12) * 0.55

    return _r_to_lufs(sig, -26.5)


# --------------------------------------------------------------- cafe (Plus)
def make_cafe(dur=18.0):
    """A murmur with syllables in it, and cups you can count.

    `Ambience`'s own note says this one empties to cup-clinks across the day,
    which the grades do — but only if there are cups to be left with. The old
    loop had twenty-one sine-pair beeps per fourteen seconds over a flat
    mid-band hiss; what it emptied to was a smoke alarm over a hiss.

    Two changes. The murmur is *syllabic*: speech-band noise gated by
    `b_grains` at 100-320 ms, which is roughly the length of a syllable, and
    then by a slow room gust so the talking has lulls. That is the difference
    between a room with people in it and a band-limited hiss, and it is worth
    28 dB of envelope range. And a cup is `_r_struck` — four inharmonic modes
    with a fingernail transient — nine of them across twenty seconds, plus a
    few low thuds for a cup set down on wood.

    Measured, day grade, on the >140 Hz part: -41.3 -> -26.5 LUFS, sub-60 Hz
    share 0.99 -> 0.00, 2-8 kHz share 0.94 -> 0.04, centroid 2975 -> 752 Hz,
    crest 29.8 -> 20.1 dB, envelope range 20.7 -> 28.1 dB.
    """
    rng = np.random.default_rng(47)
    n = int(SR * dur)

    room = b_gust(n, (1, 2, 5), (0.55, 0.31, 0.18), (0.0, 1.9, 3.7), 0.12)
    voice = b_band(b_cnoise(n, rng, exponent=0.9, corner=2600, order=1,
                            hp=180.0, hp_order=6), 300.0, 1800.0, order=2)
    syll = b_grains(n, rng, int(dur * 9), np.clip(room, 0.0, 1.0),
                    int(SR * 0.10), int(SR * 0.32), decay=3.2)
    syll = syll / (np.max(syll) + 1e-12)
    murmur = voice * (0.08 + 0.92 * syll) * room
    murmur = _r_room(murmur, rng, rt=0.9, pre=0.014, mix=0.50, cutoff=2000.0)
    sig = murmur * 0.55

    clinks = np.zeros(n)
    for _ in range(int(dur * 0.45)):                      # cup, spoon, saucer
        length = int(rng.integers(2600, 5200))
        pitch = rng.uniform(1400.0, 2400.0)
        grain = _r_struck(
            rng, length,
            [(pitch, 1.0, 34.0), (pitch * 2.41, 0.42, 40.0),
             (pitch * 3.87, 0.18, 44.0), (pitch * 0.63, 0.22, 22.0)],
            decay=rng.uniform(11.0, 17.0), strike=0.05)
        _r_place(clinks, grain * rng.uniform(0.45, 1.0), rng.integers(0, n))
    for _ in range(int(dur * 0.25)):                      # set down on wood
        length = int(rng.integers(1800, 3400))
        pitch = rng.uniform(190.0, 330.0)
        grain = _r_struck(rng, length,
                          [(pitch, 1.0, 9.0), (pitch * 2.7, 0.30, 12.0)],
                          decay=24.0, strike=0.10)
        _r_place(clinks, grain * rng.uniform(0.30, 0.60), rng.integers(0, n))
    clinks = _r_room(clinks, rng, rt=0.8, pre=0.012, mix=0.38, cutoff=4200.0)
    sig = sig + clinks / (np.max(np.abs(clinks)) + 1e-12) * 0.55

    return _r_to_lufs(sig, -26.5)


# ============================================================================
# Water and air — the four continuous beds: ocean, wind, creek, snowhush.
#
# These four have no discrete events in them at all. Whatever they sound like
# is entirely the shape of a noise spectrum and the shape of an envelope, so
# they are the loops where "it sounds like noise" was most literally true:
# measured against the shipped files, `creek` moved 2.8 dB across its whole
# loop and `snowhush` was a 100 %-infrasonic signal whose only audible band
# was the codec's own noise floor.
#
# Five rules replace the old `shaped_noise` + `normalize` + `seamless` chain
# here. Each is a measurement, not a preference:
#
#  1. **Circular, end to end.** An inverse FFT is already periodic; an LFO at
#     a whole number of cycles per loop is periodic; a grain wrapped with
#     `% n` is periodic. Nothing below needs `seamless()`, and nothing below
#     pays its crossfade — a linear fade between two uncorrelated noises sums
#     to half power, which is a measurable 2-3 dB dip at every wrap.
#  2. **No infrasound.** `f ** -exponent` puts most of a dark noise's energy
#     under 40 Hz, where a phone cannot reproduce it and an ear cannot hear
#     it — and then `normalize(peak)` divides the whole loop by that
#     inaudible rumble. It cost `snowhush` 43 dB of audible level. A steep
#     circular high-pass at 55 Hz buys all of it back.
#  3. **Levelled to loudness, not to peak.** The shelf spanned 36.5 LUFS on
#     one shared node volume, so the loops that survived were exactly the
#     white, flat ones. `b_to_lufs` puts every bed at the same measured
#     loudness and lets timbre do the distinguishing.
#  4. **A gentle high shelf, not a brick wall.** Harshness lives at 2-8 kHz.
#     Rolling it off with a first-order corner keeps the band tilted rather
#     than absent — remove it entirely and the bed becomes a drone, which is
#     a different failure with the same cause.
#  5. **It has to breathe.** A bed with a flat envelope stops reading as a
#     place and starts reading as interference. Every loop here carries a
#     multi-rate gust at coprime cycle counts, deep enough to measure.
#
# The four are deliberately spread across the target band rather than piled
# in the middle of it, so they still differ from each other: creek is the
# brightest, then ocean, then wind, and snowhush is the darkest thing in the
# app — as it always was, but now by timbre instead of by being 23 dB too
# quiet to hear.
#
# NOTE FOR WHOEVER MERGES THE OTHER FAMILIES: everything named `b_*` here is
# general, not marine. It is namespaced only because three agents were
# editing this file at once and a shared `cnoise`/`shelf`/`gust`/`to_lufs`
# could not be landed first. When the other families are re-voiced, hoist
# these next to `shaped_noise` and drop the prefix; `b_graded` in particular
# should replace `graded()` outright, because the shipped `graded()` breaks
# the loop seam on every non-day file in the app (see its docstring).
# ============================================================================

def b_cnoise(n, rng, exponent=0.85, corner=None, order=1,
             hp=55.0, hp_order=6):
    """Circular noise: exact loop, no infrasound, gently tilted.

    `shaped_noise`'s shape, with two changes. The high-pass is the headroom
    fix (rule 2) and it is applied here rather than after the fact because
    a filter that runs in the frequency domain over a periodic buffer is
    exactly circular — a time-domain one is not. And it returns an
    RMS-normalised signal, because a peak is set by whichever single sample
    happened to be largest and is no basis for deciding how loud a bed is.
    """
    half = n // 2 + 1
    spec = rng.normal(size=half) + 1j * rng.normal(size=half)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    g = np.zeros_like(f)
    g[1:] = f[1:] ** (-exponent)
    g[1:] *= 1.0 / (1.0 + (hp / f[1:]) ** (2 * hp_order)) ** 0.5
    if corner:
        g *= 1.0 / (1.0 + (f / corner) ** (2 * order)) ** 0.5
    s = np.fft.irfft(spec * g, n)
    return s / (np.sqrt(np.mean(s ** 2)) + 1e-12)


def b_band(sig, lo, hi, order=2):
    """Circular band-pass. Used to give a grain a resonance instead of a pitch.

    The old creek and cafe synthesised their small sounds as `np.sin` — a
    droplet as a decaying beep. A beep at 1.5 kHz is what "piercing" means.
    A short burst of noise pushed through a band is the same event with a
    body instead of a fundamental, and it costs the same.
    """
    n = len(sig)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    g = np.ones_like(f)
    g[0] = 0.0
    g[1:] *= 1.0 / (1.0 + (lo / f[1:]) ** (2 * order)) ** 0.5
    g *= 1.0 / (1.0 + (f / hi) ** (2 * order)) ** 0.5
    return np.fft.irfft(np.fft.rfft(sig) * g, n)


def b_shelf(sig, f0, gain_db, order=1):
    """Circular high shelf: everything above `f0` is `gain_db` down.

    Rule 4. A first-order corner leaves the 2-8 kHz band present and tilted;
    a steep one removes it and the measured spectral flatness falls straight
    through the floor of the target and out the other side into "drone".
    """
    n = len(sig)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    g = 10 ** (gain_db / 20.0)
    below = 1.0 / (1.0 + (f / f0) ** (2 * order)) ** 0.5
    return np.fft.irfft(np.fft.rfft(sig) * (g + (1.0 - g) * below), n)


def b_gust(n, cycles, amps, phases, floor):
    """A breathing multiplier that is exactly periodic over the loop.

    `cycles` are counts *per loop*, so they are integers by construction and
    the LFO cannot land mid-swing at the wrap. Keep them coprime (1, 3, 7)
    and the sum does not repeat inside the loop, which is the whole of what
    the old wind's two free-running LFOs were reaching for — except that
    those were at 0.037 and 0.053 Hz over a 16-second loop, i.e. neither of
    them completed a cycle, which is precisely why its seam had to be
    crossfaded shut.
    """
    t = np.arange(n) / float(n)
    g = np.zeros(n)
    for k, a, p in zip(cycles, amps, phases):
        g += a * np.sin(2.0 * np.pi * k * t + p)
    g = (g - g.min()) / (np.ptp(g) + 1e-12)
    return floor + (1.0 - floor) * g


def b_grains(n, rng, count, dens, lo_len, hi_len, decay=6.0):
    """Sparse decaying envelopes scattered circularly, denser where `dens` is.

    Returns an *envelope*, not a sound: multiply a noise by it and band it,
    and the grains inherit the band rather than a pitch. Tying the density
    to the gust is what stops a swell being a volume knob — more water is
    moving, so more of it is breaking.
    """
    env = np.zeros(n)
    made, tries = 0, 0
    while made < count and tries < count * 60:
        tries += 1
        s = int(rng.integers(0, n))
        if rng.random() > dens[s]:
            continue
        length = int(rng.integers(lo_len, hi_len))
        idx = (s + np.arange(length)) % n
        np.add.at(env, idx,
                  np.exp(-np.linspace(0.0, decay, length)) * rng.uniform(0.4, 1.0))
        made += 1
    return env


def b_kweight(sig):
    """BS.1770 K-weighting, applied circularly in the frequency domain.

    Same two biquads the standard specifies, redesigned for 22.05 kHz by
    bilinear transform. For an exactly periodic signal the steady-state
    response of an IIR *is* the frequency-domain multiply, so this is the
    same filter — minus the start-up transient a per-sample pass would leave
    at the head of a loop that does not have a head.
    """
    n = len(sig)
    w = 2.0 * np.pi * np.fft.rfftfreq(n, 1.0 / SR) / SR
    z = np.exp(-1j * w)
    f0, gain_db, q = 1681.97, 3.999843, 0.7071752
    k = np.tan(np.pi * f0 / SR)
    vh = 10 ** (gain_db / 20.0)
    vb = vh ** 0.4996667
    a0 = 1.0 + k / q + k * k
    b1 = np.array([vh + vb * k / q + k * k, 2 * (k * k - vh),
                   vh - vb * k / q + k * k]) / a0
    a1 = np.array([1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0])
    h1 = ((b1[0] + b1[1] * z + b1[2] * z ** 2)
          / (a1[0] + a1[1] * z + a1[2] * z ** 2))
    f0, q = 38.13547, 0.5003270
    k = np.tan(np.pi * f0 / SR)
    d = 1.0 + k / q + k * k
    a2 = np.array([1.0, 2 * (k * k - 1) / d, (1 - k / q + k * k) / d])
    h2 = ((1.0 - 2.0 * z + z ** 2)
          / (a2[0] + a2[1] * z + a2[2] * z ** 2))
    return np.fft.irfft(np.fft.rfft(sig) * h1 * h2, n)


def b_lufs(sig):
    """Gated loudness, BS.1770's 400 ms blocks at a 100 ms hop."""
    y = b_kweight(sig)
    win, hop = int(0.4 * SR), int(0.1 * SR)
    if len(y) < win:
        return -70.0
    blocks = np.array([np.mean(y[i:i + win] ** 2)
                       for i in range(0, len(y) - win, hop)])
    loud = -0.691 + 10 * np.log10(blocks + 1e-12)
    gated = blocks[loud > -70.0]
    if not len(gated):
        return -70.0
    rel = -0.691 + 10 * np.log10(np.mean(gated) + 1e-12) - 10.0
    gated2 = blocks[loud > rel]
    use = gated2 if len(gated2) else gated
    return -0.691 + 10 * np.log10(np.mean(use) + 1e-12)


def b_to_lufs(sig, target):
    """Level a bed by loudness. Exact in one pass — the gate is relative, so
    loudness is scale-equivariant and the correction cannot overshoot."""
    out = sig * (10.0 ** ((target - b_lufs(sig)) / 20.0))
    peak = float(np.max(np.abs(out)))
    assert peak < 0.95, f"peak {peak:.3f} — would clip in the WAV"
    return out


def b_graded(sig, part):
    """`graded()`, made circular — and with its tilt mapping put the right
    way round.

    Two defects in the shipped `graded()`, both invisible without measuring:

    *It breaks the loop.* The one-pole smoother starts from `acc = 0.0`, so
    the filter's state at the head does not match its state at the tail and
    the wrap no longer joins. On `snowhush_dawn` the step at the seam is 12.9
    million times the median sample-to-sample difference; measured as a click
    z-score it is 488 against a target of 3. It bites hardest on the quiet
    loops, where a thump every sixteen seconds is most exposed, and it
    affects every non-day file in the app. Running the identical filter as a
    frequency-domain multiply over a periodic buffer gives the same response
    with no start-up transient, so the seam survives the grade exactly.

    *Night came out brighter than dusk.* `a = 0.35 + 0.55 * tilt` makes a
    larger tilt a **faster** smoother — dusk's corner was 3694 Hz and night's
    4794 Hz. Measured centroid confirmed the inversion in sixteen of the
    eighteen shipped loops. The mapping below falls with tilt instead, which
    is what the table always meant.

    The knobs and the `LOOP_GRADES` table are untouched: still a spectral
    tilt and a level, still day unchanged, still darker and quieter as the
    day goes on.
    """
    if part == "day":
        return sig
    tilt, level = LOOP_GRADES[part]
    # 0.50 is not a taste: it is the coefficient at which this mapping
    # reproduces the shipped grade's measured strength. Old files, day to
    # dawn/dusk/night: centroid x0.83 / x0.68 / x0.69 and -1.9 / -3.5 / -4.5
    # dB. This gives x0.83 / x0.62 / x0.49 and -1.3 / -2.8 / -4.9 dB — dawn
    # identical, and dusk and night now in the order the table always meant.
    a = 0.35 * (1.0 - 0.50 * tilt)
    n = len(sig)
    w = 2.0 * np.pi * np.fft.rfftfreq(n, 1.0 / SR) / SR
    z = np.exp(-1j * w)
    one_pole = a / (1.0 - (1.0 - a) * z)
    resp = (1.0 - tilt) + tilt * one_pole ** 2
    return np.fft.irfft(np.fft.rfft(sig) * resp, n) * level


def write_loop_b(name, sig):
    """`write_loop`, on `b_graded`. Same files, same table, same encoder."""
    LOOP_FRAMES[name] = len(sig)
    total = 0
    for part in ("dawn", "day", "dusk", "night"):
        stem = name if part == "day" else f"{name}_{part}"
        wav_path = os.path.join(RES, stem + ".wav")
        m4a_path = os.path.join(RES, stem + ".m4a")
        write_wav(stem + ".wav", b_graded(sig, part))
        encode(wav_path, m4a_path)
        os.remove(wav_path)
        total += os.path.getsize(m4a_path)
    print(f"  {name}: 4 grades, {len(sig) / SR:.1f}s, "
          f"{total / 1024:.0f} KB, {len(sig)} frames")


def write_loop_i(name, maker, dur):
    """Four grades, each **synthesised** rather than filtered out of the day.

    `graded()` and `b_graded()` are one recipe seen through a tilt and a
    level, which is right for weather: rain at three in the morning is the
    same rain, darker and quieter. It is wrong for animals. Crickets are not
    quieter at night, they are *louder, more numerous and faster*, and no
    lowpass can make a chorus out of four singers. So the insects take the
    part as an argument and build the field for that hour.

    The contract the app cares about is unchanged and is asserted here: all
    four files are the same number of frames, because `Ambience.loopFrames`
    is one number per ambience and not one per grade.
    """
    n = int(SR * dur)
    LOOP_FRAMES[name] = n
    total = 0
    for part in ("dawn", "day", "dusk", "night"):
        sig = maker(part, n)
        assert len(sig) == n, f"{name}_{part}: {len(sig)} frames, expected {n}"
        stem = name if part == "day" else f"{name}_{part}"
        wav_path = os.path.join(RES, stem + ".wav")
        m4a_path = os.path.join(RES, stem + ".m4a")
        write_wav(stem + ".wav", sig)
        encode(wav_path, m4a_path)
        os.remove(wav_path)
        total += os.path.getsize(m4a_path)
    print(f"  {name}: 4 grades, {dur:.1f}s, {total / 1024:.0f} KB, {n} frames")


# -------------------------------------------------------------- ocean (Plus)
def make_ocean(dur=28.0):
    """Four waves in twenty-eight seconds, none of them the same size.

    The old ocean was an 18-second loop with a fixed 5.5-second wave, which
    is 83 waves in a focus phase and about three before you have the period.
    Four different waves over 28 seconds is 64 arrivals and no countable
    pattern. The foam was the other half of the problem: `exponent=0.3,
    cutoff=9000` is white noise by any measurement, and it was 42 % of the
    loop's energy sitting in the 2-8 kHz band. Foam is a band, not a hiss —
    it lives between 700 Hz and 2.6 kHz, and only on the crest.
    """
    rng = np.random.default_rng(59)
    n = int(SR * dur)
    swell = np.zeros(n)
    period = n // 4
    for i in range(4):
        rise = int(SR * rng.uniform(1.1, 1.9))
        fall = int(SR * rng.uniform(3.4, 5.0))
        shape = np.concatenate([
            np.linspace(0, 1, rise) ** 1.7,
            np.linspace(1, 0, fall) ** 0.75,
        ])
        idx = (i * period + np.arange(rise + fall)) % n
        np.add.at(swell, idx, shape * rng.uniform(0.70, 1.0))
    swell = np.clip(swell, 0.0, 1.25)
    # A slow tide under the waves, so the set builds and falls away.
    tide = b_gust(n, (1, 3), (0.6, 0.4), (0.4, 2.6), 0.70)

    body = b_shelf(b_cnoise(n, rng, exponent=0.75, corner=3600,
                            order=1, hp=110.0), 2000.0, -7.0)
    foam = b_band(b_cnoise(n, rng, exponent=0.5, corner=4200, order=2,
                           hp=500.0), 900.0, 3000.0, order=2)
    sig = body * (0.10 + 0.90 * swell) * tide + foam * (swell ** 2.6) * 0.30
    return b_to_lufs(sig, -26.0)


# ============================================================================
# The Second Shelf — Phase W's first six loops.
#
# Same rules as the first six: mono 22.05 kHz, seamless by crossfading the
# tail over the head, peak well under 1.0 so a track can sit on top without
# either of them clipping. Nothing here layers at runtime — every one is a
# finished loop the existing decode-once `.loops` path plays on one node,
# which is the law the music crash bought.
# ============================================================================

def make_drizzle(variant=0, dur=12.0):
    """Rain, thinner. Not quieter — thinner. Still the right intent.

    What was wrong was the execution. "High-pass by subtracting a lowpassed
    copy" only works if both copies are at the same scale, and `shaped_noise`
    peak-normalises each call independently, so the subtraction left a
    broadband residual instead of a high-passed one. That is why this loop
    measured a spectral flatness of 0.887 and a tilt of -0.1 dB per octave:
    it was, arithmetically, white noise. It is now thinner the honest way —
    the bed's own corner is put an octave up (230 Hz against rain's 175) and
    the drops are smaller, higher and half as frequent.

    Flatness 0.885 -> 0.325, 2-8 kHz share 0.55 -> 0.07, tilt -0.6 -> -7.2,
    envelope range 3.1 -> 11.3 dB.
    """
    rng = np.random.default_rng(101 + variant * 17)
    n = int(SR * dur)
    gust = _a_gust(n, cycles=(1, 4, 9), amps=(0.5, 0.32, 0.18),
                   floor=0.26, shape=1.25)
    bed = wet_bed(n, rng, exponent=0.85, cutoff=4200, shelf_hz=2400,
                  shelf_db=-3.0, base=230.0) * gust
    drops = scatter(
        n, rng, int(dur * 16), gust,
        lambda r: droplet(r, int(r.integers(160, 380)),
                          r.uniform(900.0, 2100.0), q=r.uniform(4.0, 8.0),
                          decay=11.0),
        gain=(0.3, 0.85), follow=1.2)
    return _a_cut_at_lull(_a_to_lufs(bed + drops * 0.5))


def make_wind(dur=24.0):
    """Two gusts beating against each other, both of them whole cycles.

    The intent is unchanged and it was a good one: a single sweep is a
    machine, two drifting against each other is weather. What was wrong was
    the rates. 0.037 Hz and 0.053 Hz over a sixteen-second loop means neither
    LFO completes even one cycle, so the multiplier arrived at the wrap
    halfway up a swing and the crossfade had to hide the step. Whole cycle
    counts per loop, chosen coprime, beat against each other in exactly the
    same way and land where they started.

    The air was the other half. `exponent=0.4, cutoff=6000` is a hiss that
    reaches 6 kHz, and it was riding the gust, so every swell was a rise in
    sibilance. Wind moving past you is a band around a kilohertz; above three
    it is a microphone, not a sound.
    """
    rng = np.random.default_rng(103)
    n = int(SR * dur)
    # Multiplied, not averaged. Averaging two gusts is shallower than either
    # of them — the shipped recipe averaged them and then floored the result
    # at 0.25, which is how a "gust" ended up moving the loop by 5.6 dB.
    slow = b_gust(n, (1, 3, 7), (0.60, 0.30, 0.16), (0.0, 1.7, 3.1), 0.36)
    fast = b_gust(n, (2, 5), (0.6, 0.4), (2.0, 0.5), 0.46)
    swell = slow * fast

    low = b_shelf(b_cnoise(n, rng, exponent=0.75, corner=3600,
                           order=2, hp=80.0), 1400.0, -5.0)
    air = b_band(b_cnoise(n, rng, exponent=0.6, corner=3400, order=2,
                          hp=350.0), 600.0, 2800.0, order=2)
    sig = low * swell + air * (swell ** 1.8) * 0.20
    return b_to_lufs(sig, -26.2)


def make_creek(dur=24.0):
    """Moving water over stones — with eddies, and with bubbles that are not
    beeps.

    This was the flattest loop on the shelf by a distance: 2.8 dB of movement
    across the whole fourteen seconds, and its modulation energy 30 dB under
    DC. That is not a stream, it is a hiss, and the reason is that the recipe
    had no envelope in it at all — nothing multiplied the body.

    Two other things were wrong. The body was `noise(0.5, cutoff=5200)` minus
    `noise(0.5, cutoff=400)` at the same seed, meaning to be a high-pass; but
    each call peak-normalises independently, so the two were never at
    matching scale and the subtraction left a broadband residual instead. And
    a bubble was `np.sin` of a rising sweep — a chirp is a pitch, and a
    thousand pitches a second is what "piercing" is made of. A creek's
    bubbles are resonances: noise in a band, short and struck.

    Slower and deeper than a river: eddies at one, three, seven and eleven
    per loop, and the bubbles crowd into the fast water.
    """
    rng = np.random.default_rng(107)
    n = int(SR * dur)
    eddy = b_gust(n, (1, 3, 7, 11), (0.55, 0.32, 0.20, 0.11),
                  (0.0, 2.2, 4.1, 1.0), 0.24)

    # The brightest of the four beds: a creek has no mass behind it, so it
    # keeps more of the low kilohertz than the ocean or the snow do.
    body = b_shelf(b_cnoise(n, rng, exponent=0.75, corner=4600,
                            order=1, hp=150.0), 2000.0, -7.0)
    sig = body * eddy

    # Two bubble sizes, each a band rather than a tone: the deep plocks in
    # the slack water, the fine ones only where it is running.
    for count, lo_len, hi_len, lo_hz, hi_hz, gain, dens in (
            (int(dur * 14), 220, 520, 380.0, 1100.0, 0.30, 1.15 - eddy),
            (int(dur * 34), 90, 240, 900.0, 2600.0, 0.22, eddy)):
        env = b_grains(n, rng, count, np.clip(dens, 0.0, 1.0),
                       lo_len, hi_len, decay=6.5)
        carrier = b_cnoise(n, rng, exponent=0.3, hp=250.0, hp_order=2)
        sig = sig + b_band(carrier * env, lo_hz, hi_hz, order=2) * gain
    return b_to_lufs(sig, -25.5)


def make_library(dur=26.0):
    """A big quiet room, and somebody two tables away.

    The intent was already right and the note above it was already right: the
    events are the whole feature, and they are what make silence read as *a
    room being quiet* rather than as no signal. What was wrong is that nobody
    could hear any of it. At -57.0 LUFS this was thirty-one decibels under the
    rest of the shelf on one shared node volume, with **100 %** of its energy
    below 60 Hz — the `exponent=1.6` room tone put everything in the
    infrasound and `normalize(peak)` then divided the whole loop by it. Its
    measured spectral flatness of 0.407 was reading the codec's noise floor.

    So the same room, levelled to the shelf and spent on the part you can
    hear. The tone is at 0.014 of its own noise and is meant to be right at
    the edge of noticing. Four pages across twenty-eight seconds, each with
    paper body under the flutter and a small grab before it; a chair and a
    footstep; one pencil. All of it lowpassed at 3.6 kHz and put in a 1.1 s
    room, because the whole sentence is *two tables away*.

    Levelled to a ceiling rather than to -29.0 exactly, and lands at -29.5:
    seven transients in twenty-eight seconds of near-silence is a 29 dB crest
    factor by definition, and clipping the page turn to buy half a decibel
    would be the wrong way round.

    Measured, day grade, on the >140 Hz part: -57.0 -> -29.5 LUFS, sub-60 Hz
    share 1.00 -> 0.00, centroid 3163 -> 1085 Hz, tilt -2.1 -> -8.9
    dB/octave, envelope modulation 3.84 -> 1.42 (it was that high because
    there was nothing between the events at all).
    """
    rng = np.random.default_rng(109)
    n = int(SR * dur)

    drift = b_gust(n, (1, 3), (0.6, 0.4), (0.0, 2.3), 0.55)
    air = b_shelf(b_cnoise(n, rng, exponent=1.0, corner=900, order=1,
                           hp=85.0, hp_order=6), 500.0, -9.0)
    sig = air * drift * 0.014

    events = np.zeros(n)
    for k in range(4):                                    # pages
        at = int(n * (0.07 + 0.245 * k + rng.uniform(-0.05, 0.05)))
        length = int(rng.integers(5200, 9000))
        paper = b_cnoise(length, rng, exponent=0.55, hp=260.0, hp_order=2)
        # Two bands off one noise, so the body and the flutter are the same
        # sheet of paper. Two independent noises would be two sheets.
        flick = (b_band(paper, 700.0, 4200.0, order=2)
                 + b_band(paper, 260.0, 1100.0, order=2) * 1.30)
        t = np.linspace(0.0, 1.0, length)
        flick *= (t ** 0.9) * np.exp(-t * 3.0)
        flick *= 0.55 + 0.45 * np.sin(2 * np.pi * rng.uniform(7.0, 11.0) * t)
        _r_place(events, flick / (np.max(np.abs(flick)) + 1e-12)
                 * rng.uniform(0.55, 1.0), at)
        grab = _r_struck(rng, 900, [(2100.0, 1.0, 3.0)], decay=22.0)
        _r_place(events, grab * 0.20, at - int(SR * rng.uniform(0.16, 0.30)))

    for k in range(2):                                    # a chair, a footstep
        at = int(n * (0.33 + 0.42 * k + rng.uniform(-0.06, 0.06)))
        length = int(SR * rng.uniform(0.35, 0.7))
        pitch = rng.uniform(150.0, 260.0)
        creak = _r_struck(rng, length,
                          [(pitch, 1.0, 7.0), (pitch * 2.2, 0.4, 9.0),
                           (pitch * 4.1, 0.15, 11.0)],
                          decay=9.0, strike=0.02)
        creak *= 0.4 + 0.6 * np.abs(np.sin(
            2 * np.pi * rng.uniform(6.0, 13.0) * np.arange(length) / SR))
        _r_place(events, creak * rng.uniform(0.30, 0.55), at)

    length = int(SR * 0.9)                                # a pencil, once
    scratch = b_band(b_cnoise(length, rng, exponent=0.3, hp=800.0,
                              hp_order=2), 1200.0, 4600.0, order=2)
    t = np.linspace(0.0, 1.0, length)
    scratch *= np.exp(-((t - 0.5) / 0.34) ** 2)
    scratch *= 0.35 + 0.65 * np.abs(np.sin(2 * np.pi * 5.5 * t)) ** 0.6
    _r_place(events, scratch / (np.max(np.abs(scratch)) + 1e-12) * 0.30,
             int(n * 0.62))

    events = distant(events, 3600.0, order=2)
    events = _r_room(events, rng, rt=1.1, pre=0.022, mix=0.36, cutoff=2600.0)
    sig = sig + events / (np.max(np.abs(events)) + 1e-12) * 0.60

    return _r_to_lufs(sig, -29.0)


def make_snowhush(dur=24.0):
    """The sound of sound being absorbed. Still the darkest loop in the app —
    now by timbre rather than by being inaudible.

    The old one was the clearest case of the headroom bug in the whole shelf.
    `exponent=1.9, cutoff=340` puts **100 %** of the signal's energy below 40
    Hz, where a phone speaker reproduces none of it; `normalize(peak)` then
    divided the entire loop by that inaudible rumble, and it landed at -48.8
    LUFS. Twenty-three decibels under the rest of the shelf on one shared
    node volume is not "the quietest loop", it is a loop nobody has heard.
    Its measured spectral flatness of 1.000 was the joke on top: there was no
    signal above a kilohertz at all, so the metric was reading the codec's
    own noise floor, which is white.

    So: the same absorbed, top-less sound, high-passed at 55 Hz so the level
    is spent on the part you can hear, and with a real — very quiet, very
    steeply tilted — tail through the low kilohertz, because falling snow
    does have a faint hiss and a loop with literally nothing up there is a
    drone. Deliberately the darkest of the four beds and the quietest of them
    by about a decibel, which is a difference you can hear rather than one
    that removes it from the app.

    The eight-second breath survives as three whole cycles per loop, with a
    slower drift under it so no two breaths are the same size.
    """
    rng = np.random.default_rng(113)
    n = int(SR * dur)
    breath = b_gust(n, (3, 1, 7), (0.62, 0.30, 0.10), (0.0, 1.2, 2.4), 0.26)
    body = b_shelf(b_cnoise(n, rng, exponent=0.75, corner=4000,
                            order=2, hp=70.0), 2000.0, -6.0)
    return b_to_lufs(body * breath, -26.8)


def make_temple(dur=30.0):
    """Pine wind, and a bell with a long tail. Mostly the air between them.

    The docstring's own promise — "you stop expecting it and then it
    happens" — was not what the file did. Two strikes in a twenty-four second
    loop is a bell every twelve seconds, which is a metronome, and each one
    was three sine partials on a single shared exponential: an organ chord,
    not bronze. The bed under them was `exponent=1.3` peak-normalised, which
    is why this was simultaneously the loudest loop on the shelf (-24.6 LUFS)
    and had a measured 2-8 kHz share of **0.000** and a spectral flatness of
    **0.000**. A drone.

    Now: thirty-six seconds, two strikes, and about eighteen seconds of pine
    wind between them. The bell is nine inharmonic partials each with its own
    decay — the hum rings for fifteen seconds and the top is gone in one, so
    it darkens as it fades, which is the sound of struck metal — and each
    partial is a beating pair, so the tail shimmers instead of sitting still.
    The second strike is at 0.68, because a bell struck twice is not struck
    identically.

    Note what did **not** get fixed, because it is not broken: the flatness
    is still 0.003. A temple bell is a tonal object and a low flatness is the
    correct measurement of one. The drone test is the envelope, and that
    reads 0.71 modulation over 18.3 dB of range against the old 0.43 over
    13.5 — measured on the >140 Hz part, where the old loop had almost
    nothing.

    Measured, day grade, on the >140 Hz part: -24.6 -> -27.0 LUFS, sub-60 Hz
    share 0.88 -> 0.00, centroid 243 -> 556 Hz, 2-8 kHz share 0.000 -> 0.024.
    """
    rng = np.random.default_rng(127)
    n = int(SR * dur)

    breath = b_gust(n, (1, 3, 8), (0.60, 0.28, 0.14), (0.0, 2.6, 4.9), 0.12)
    pines = b_shelf(
        b_band(b_cnoise(n, rng, exponent=0.8, corner=3000, order=1,
                        hp=180.0, hp_order=6), 380.0, 3000.0, order=2),
        1500.0, -3.0)
    sig = pines * breath * 0.15

    # (ratio, amplitude, decay in nepers/second). Roughly a bonshō: a hum an
    # octave down, a prime, a minor third, a fifth, and an inharmonic top
    # that dies first.
    partials = ((0.50, 0.26, 0.30), (1.00, 1.00, 0.40), (1.19, 0.42, 0.58),
                (1.50, 0.40, 0.70), (2.00, 0.36, 0.92), (2.54, 0.28, 1.30),
                (3.36, 0.20, 1.80), (4.22, 0.14, 2.40), (5.43, 0.09, 3.20))
    strikes = np.zeros(n)
    for at_s, level in ((2.0, 1.00), (17.0, 0.68)):
        length = min(int(SR * 16.0), n)
        bell = _r_bell(rng, length, 300.0, partials, beat=1.6)
        strikes = _r_place(strikes, distant(bell, 4200.0, order=2) * level,
                           int(SR * at_s))
    strikes = _r_room(strikes, rng, rt=1.8, pre=0.03, mix=0.30, cutoff=3200.0)
    sig = sig + strikes / (np.max(np.abs(strikes)) + 1e-12) * 0.90

    return _r_to_lufs(sig, -27.0)


def make_storm(variant=0, dur=20.0):
    """Rain with weight under it, and thunder that has already happened.

    The intent survives: a squall arriving rather than rain at a constant
    rate, and thunder rolled far enough away that it is not a transient. The
    swell is now a whole number of cycles per loop rather than a 9-second
    period inside a 20-second file, which is what used to need a crossfade,
    and the rolls wrap onto the head instead of being placed where they
    happened to fit. This is the deepest-breathing loop in the family — 14.6
    dB of envelope range against the old 3.6 — which is what a squall is.

    The `weight` layer is kept, because a storm without it is just loud rain,
    but it now starts rolling off at 75 Hz rather than running down to DC:
    the old one put 59 % of the file's energy below 40 Hz, none of which a
    phone can reproduce and all of which was setting the peak that the level
    was divided by.
    """
    rng = np.random.default_rng(131 + variant * 17)
    n = int(SR * dur)
    gust = _a_gust(n, cycles=(1, 2, 5), amps=(0.62, 0.26, 0.14),
                   floor=0.18, shape=1.6)
    bed = wet_bed(n, rng, exponent=1.0, cutoff=6800, shelf_hz=2400,
                  shelf_db=-2.5, base=150.0) * gust
    weight = _a_cnoise(n, rng, exponent=1.3, cutoff=260, order=2,
                       highpass=75.0, hp_order=3) * 0.30 * gust
    drops = scatter(
        n, rng, int(dur * 34), gust,
        lambda r: droplet(r, int(r.integers(220, 560)),
                          r.uniform(600.0, 1900.0), q=r.uniform(2.5, 5.5)),
        gain=(0.35, 1.0), follow=1.5)
    roll = thunder(n, rng, at=(0.21, 0.68))
    return _a_cut_at_lull(_a_to_lufs(bed + weight + drops * 0.55 + roll))


# ============================================================================
# The insects — crickets and cicadas. (Family I.)
#
# The owner pointed at these two on his phone and said the sound was bad
# noise. He was right, and the measurements say why: both were a continuous
# wash with something waved over the top of it, and on both of them the wash
# was inaudible.
#
#   * `crickets` put **80 %** of its energy below 150 Hz — a `shaped_noise`
#     at exponent 1.7 with no high-pass, peak-normalised, so the rumble no
#     phone can reproduce set the level for everything else. Its spectral
#     centroid was 500 Hz. A cricket is a 4-5 kHz event. What actually came
#     out of the speaker was the 9 % of the file that was not rumble: a
#     square-gated hiss at 4.5 Hz, which is a smoke alarm with the batteries
#     going, not a field.
#   * `cicadas` was worse in the opposite direction: three `np.sin` carriers
#     with a 30 Hz FM on them measured a spectral flatness of **0.006**, i.e.
#     a siren rather than an animal, and then `distant(..., 3000)` removed
#     the very band the insect lives in. 76 % of *its* energy was under
#     150 Hz too, from the same un-high-passed `shaped_noise` body.
#
# The fix is granular, not spectral, and it is the same fix in both cases:
# stop shaping a continuous noise and start synthesising **events** — a
# chirp, a song — each with its own envelope, its own carrier and its own
# distance, scattered over a bed quiet enough that the silence between them
# is audible. Silence between chirps is what makes them chirps.
#
# Four things carry the realism, and each is a knob the grades then turn:
#
#   * **Individuals.** Seven to eleven singers, each with its own carrier
#     frequency, its own chirp rate and its own phase. Beating between them
#     is the texture; it is also why no listener can find the period.
#   * **Distance.** Three depth layers. Far singers are quieter, rolled off,
#     and wet — `i_air` convolves them with a decaying noise tail, done as a
#     *circular* convolution so the reverb of the last chirp is already on
#     the head of the loop. Distance is what turns a stack of chirps into a
#     field with a size.
#   * **Rate as temperature.** Real crickets are thermometers — Dolbear's
#     law, chirps per minute rising with the temperature. This world has no
#     temperature, but it has four circadian grades, so the rate carries it:
#     fastest at dusk when the ground is still warm, slowest at dawn which
#     is the coldest hour of the night.
#   * **Density as season-of-the-day.** Crickets belong to the night and
#     cicadas to the hot part of the day, so the two loops' grades move in
#     opposite directions. See CRICKET_GRADES and CICADA_GRADES.
#
# Everything below is built on the `b_*` helpers, which say in their own
# banner that they are general rather than marine. Nothing here uses
# `seamless()`, `normalize()` or `shaped_noise()`: grains wrap with `% n`,
# every LFO is a whole number of cycles per loop, every filter is a multiply
# on the loop's own rfft grid, and the level is set by gated loudness.
# ============================================================================

def i_reson(x, centre, q, extra=()):
    """Noise through a resonance — a ringing body, not a beep.

    A cricket's file-and-scraper is a resonator being driven; its song is
    narrowband but it is not a sine, and the difference between those two is
    the whole distance between "insect" and "electronics". `extra` adds
    further modes as (multiple, amplitude, q).
    """
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    bw = centre / q
    g = 1.0 / (1.0 + ((f - centre) / bw) ** 2)
    for mult, amp, mq in extra:
        mbw = centre * mult / mq
        g = g + amp / (1.0 + ((f - centre * mult) / mbw) ** 2)
    y = np.fft.irfft(np.fft.rfft(x) * g, n)
    return y / (np.max(np.abs(y)) + 1e-12)


def i_air(sig, rng, decay=0.30, damp=4200.0, mix=0.25):
    """Distance, as a circular convolution with a decaying noise tail.

    Level and a lowpass alone read as "turned down", not as "further away";
    what the ear actually uses is the reflected energy arriving after the
    event. Doing it as a multiply in the frequency domain means the tail of
    the last chirp in the loop is already sitting on the head of the first,
    which is a reverb that survives looping — a time-domain one would have
    to be faded and would leave a hole.
    """
    n = len(sig)
    tail = rng.normal(size=n) * np.exp(-np.arange(n) / (SR * decay))
    tail = b_band(tail, 350.0, damp, order=2)
    tail /= np.sqrt(np.sum(tail ** 2)) + 1e-12
    wet = np.fft.irfft(np.fft.rfft(sig) * np.fft.rfft(tail), n)
    dry_rms = np.sqrt(np.mean(sig ** 2)) + 1e-15
    wet *= dry_rms / (np.sqrt(np.mean(wet ** 2)) + 1e-15)
    return sig * (1.0 - mix) + wet * mix


def i_chirp(rng, carrier, q, pulses, pulse_s, gap_s):
    """One cricket chirp: three to five pulses, each a struck resonance.

    The pulse is the unit, not the chirp. A field cricket's chirp is a burst
    of syllables at 25-35 Hz inside it, and that inner rate is most of why a
    chirp sounds like a chirp rather than like a beep of the same length.
    """
    pulse_n = max(8, int(SR * pulse_s))
    gap_n = max(4, int(SR * gap_s))
    out = np.zeros(pulses * (pulse_n + gap_n))
    t = np.arange(pulse_n) / SR
    env = (1.0 - np.exp(-t / 0.0016)) * np.exp(-t / (pulse_s * 0.42))
    for k in range(pulses):
        body = i_reson(rng.normal(size=pulse_n), carrier, q,
                       extra=((2.0, 0.09, q * 1.6),))
        # The first and last syllable of a chirp are quieter than the middle.
        amp = 1.0 if 0 < k < pulses - 1 else 0.72
        start = k * (pulse_n + gap_n)
        out[start:start + pulse_n] += body * env * amp
    return out


def i_song(rng, length, carrier, q, buzz_hz, rise, fall):
    """One cicada song: a swelling band of buzz that arrives and leaves.

    The buzz rate is the point. A cicada's tymbal clicks at 100-300 Hz and
    that rate, imposed as amplitude modulation on a resonant band, puts a
    ladder of sidebands either side of the carrier — which is what makes it
    a rattle instead of a hiss, and what stops the spectral flatness sitting
    at either end of its range.
    """
    x = i_reson(rng.normal(size=length), carrier, q,
                extra=((1.52, 0.38, q * 1.3), (2.14, 0.14, q * 1.6)))
    t = np.arange(length) / SR
    buzz = 0.30 + 0.70 * (0.5 + 0.5 * np.sin(2 * np.pi * buzz_hz * t)) ** 1.5
    total = length / SR
    env = np.minimum(1.0, t / rise) * np.minimum(
        1.0, np.maximum(0.0, (total - t) / fall))
    env = env * (0.86 + 0.14 * np.sin(2 * np.pi * 0.9 * t + rng.uniform(0, 6)))
    out = x * buzz * env
    return out / (np.max(np.abs(out)) + 1e-12)


def i_scatter(out, rng, grain, count, jitter, gain):
    """`count` copies of one voice's grain, evenly spaced, wrapped onto the head.

    Even spacing with a jitter, rather than a random scatter: a cricket keeps
    time. `count` is an integer number per loop by construction, so the last
    interval is the same length as the first and the pattern joins itself.
    """
    n = len(out)
    step = n / count
    for k in range(count):
        start = int((k + rng.uniform(-jitter, jitter)) * step) % n
        idx = (start + np.arange(len(grain))) % n
        np.add.at(out, idx, grain * gain)
    return out


def i_trill(n, rng, centre, q, cycles, depth=0.8):
    """A tree cricket: no chirps at all, a continuous shimmer.

    Narrowband by construction, so it can be the continuous layer of the
    sound without being the hiss the old recipe was — a 3 kHz band with a
    45 Hz tremolo measures nothing like white noise. `cycles` is per loop.
    """
    x = i_reson(b_cnoise(n, rng, exponent=0.0, hp=900.0), centre, q)
    t = np.arange(n) / float(n)
    am = (1.0 - depth) + depth * (0.5 + 0.5 * np.sin(2 * np.pi * cycles * t)) ** 2
    return x * am


def i_mix(layers):
    """Sum layers at stated dB *relative to each other*, not at raw gains.

    The first version of both recipes multiplied each layer by a hand-picked
    number, and the four grades came out incomparable: at day and dawn the
    bed buried the chirps (spectral centroid 733 Hz, envelope modulation
    0.10 — a flat hiss, i.e. exactly the complaint), while at dusk and night
    the field was 88 % 2-8 kHz with no body under it at all. A hand-picked
    gain cannot be right, because the RMS of a layer of scattered events
    depends on how many events this grade happens to have.

    So every layer is normalised to unit RMS first and then placed at a
    stated level in dB. `layers[0]` is the reference at 0 dB. That makes the
    table readable — "the bed sits 11 dB under the chorus" — and makes the
    four grades differ in the things they are meant to differ in.
    """
    out = None
    for sig, db in layers:
        rms = np.sqrt(np.mean(sig ** 2))
        if rms < 1e-12:
            continue
        scaled = sig / rms * 10.0 ** (db / 20.0)
        out = scaled if out is None else out + scaled
    return out


# Crickets belong to the night, so density, closeness and rate all rise
# towards it — the opposite direction from every other loop's grade table.
#
#   voices    how many individuals are singing
#   rate      chirp rate multiplier: Dolbear's law standing in for a
#             thermometer this world does not have. Dusk is the warmest hour
#             (the ground has been in the sun all day) and dawn the coldest.
#   near      fraction of the field that is close rather than far
#   trill_db  the continuous tree-cricket layer, under the chorus
#   bed_db    grass and air, under the chorus
#   top       high shelf above 4.5 kHz: the night is damper, damp air darker
#   lufs      gated loudness target
CRICKET_GRADES = {
    # A hot afternoon: a handful of singers, all of them across the field,
    # and the most air of the four — you hear the field more than the crickets.
    "day":   dict(voices=4, rate=1.04, near=0.00, trill_db=-19.0,
                  bed_db=-5.5, top=-1.0, lufs=-28.0),
    # The chorus thinning out in the cold hour before sunrise. Slowest
    # chirping in the app — three quarters of the dusk rate — and the last
    # few singers are the far ones.
    "dawn":  dict(voices=5, rate=0.76, near=0.10, trill_db=-16.0,
                  bed_db=-6.5, top=+0.5, lufs=-29.0),
    # The chorus starting, and the fastest chirping of the four: the ground
    # has been in the sun all day.
    "dusk":  dict(voices=8, rate=1.12, near=0.35, trill_db=-12.5,
                  bed_db=-7.5, top=-2.0, lufs=-27.0),
    # Full chorus. Most voices, some of them very close, the tree crickets
    # up, the least air of the four, and the top rolled off for the damp.
    "night": dict(voices=11, rate=0.98, near=0.45, trill_db=-10.5,
                  bed_db=-9.5, top=-3.5, lufs=-26.2),
}


def make_crickets(part, n):
    """A field of individuals, at one time of day."""
    g = CRICKET_GRADES[part]
    seed = 137 + 7 * ("day", "dawn", "dusk", "night").index(part)
    rng = np.random.default_rng(seed)
    dur = n / SR
    # The field breathes: crickets loosely synchronise and the whole chorus
    # swells. Coprime integer cycles, so it is exact over the loop.
    swell = b_gust(n, (1, 3, 7), (0.55, 0.27, 0.18), (0.0, 1.7, 3.9),
                   floor=0.32)

    layers = {"near": np.zeros(n), "far": np.zeros(n)}
    for _ in range(g["voices"]):
        close = rng.random() < g["near"]
        # 2.9-4.4 kHz. Higher than this is a field cricket at arm's length,
        # which measured as 88 % of the loop's energy in the 2-8 kHz band —
        # a whistle rather than a night. The band a chorus actually occupies
        # at any distance is lower, because the air took the top off it.
        carrier = rng.uniform(2900.0, 4400.0)
        q = rng.uniform(11.0, 18.0)
        pulses = int(rng.integers(3, 6))
        # 25-35 Hz syllables inside the chirp.
        syllable = rng.uniform(0.026, 0.038)
        pulse_s = syllable * rng.uniform(0.42, 0.55)
        chirp = i_chirp(rng, carrier, q, pulses, pulse_s, syllable - pulse_s)
        rate = g["rate"] * rng.uniform(1.55, 3.15)
        # An integer number of chirps per loop: the wrap lands where the next
        # chirp would have, so the loop has no seam in the rhythm either.
        count = max(2, int(round(rate * dur)))
        gain = rng.uniform(0.55, 1.0) * (1.0 if close else rng.uniform(0.22, 0.45))
        i_scatter(layers["near" if close else "far"], rng, chirp, count,
                  jitter=0.16, gain=gain)

    near = i_air(layers["near"], rng, decay=0.22, damp=5200.0, mix=0.14)
    far = i_air(layers["far"], rng, decay=0.42, damp=3200.0, mix=0.45)
    far = b_band(far, 700.0, 6800.0, order=1)
    chorus = (near + far) * (0.28 + 0.72 * swell)

    trill = np.zeros(n)
    for k in range(3):
        rate_hz = (38.0 + 7.0 * k) * g["rate"]
        trill += i_trill(n, rng, rng.uniform(2100.0, 2900.0), q=9.0,
                         cycles=int(round(rate_hz * dur))) * (0.6 ** k)
    trill = i_air(trill, rng, decay=0.5, damp=3000.0, mix=0.5)
    trill *= 0.55 + 0.45 * swell

    # Grass and night air. High-passed hard: the loop this replaces was four
    # fifths inaudible rumble, and none of that is coming back. It is also
    # the whole of the body under the chorus, which is why it is only 6-11 dB
    # down rather than the 20 dB "a much lower noise floor" first suggested —
    # at 20 dB the file measured as a 4 kHz whistle with nothing beneath it.
    bed = b_cnoise(n, rng, exponent=1.15, corner=900.0, order=2,
                   hp=170.0, hp_order=4)
    bed *= 0.6 + 0.4 * swell

    sig = i_mix([(chorus, 0.0), (trill, g["trill_db"]), (bed, g["bed_db"])])
    sig = b_shelf(sig, 4500.0, g["top"])
    return _a_cut_at_lull(b_to_lufs(sig, g["lufs"]))


# Cicadas belong to the hot part of the day, so this table runs the other
# way: noon is the peak chorus and the night has two stragglers left in it.
#
#   voices    individual songs overlapping across the loop
#   buzz      tymbal-rate multiplier — the same temperature idea as the
#             crickets' `rate`, on the inner rate rather than the outer one
#   near      fraction singing from the near tree rather than the far one
#   carrier   centre of the band the songs sit in, in Hz
#   bed_db    warm-air bed, under the chorus
#   top       high shelf above 5 kHz: this is exactly where "harsh" lives
#   lufs      gated loudness target
CICADA_GRADES = {
    # Noon: the whole tree at once, the brightest and loudest of the four.
    "day":   dict(voices=10, buzz=1.00, near=0.40, carrier=3600.0,
                  bed_db=-10.0, top=-5.0, lufs=-26.4),
    # First light: two or three starting up, all of them across the garden,
    # and slow with it — a cicada is as much a thermometer as a cricket.
    "dawn":  dict(voices=3, buzz=0.80, near=0.00, carrier=3400.0,
                  bed_db=-6.0, top=-6.0, lufs=-29.0),
    # Evening: still a chorus, winding down, and lower — the evening species
    # sings under the noon one.
    "dusk":  dict(voices=6, buzz=0.92, near=0.20, carrier=3200.0,
                  bed_db=-8.0, top=-7.0, lufs=-27.4),
    # Night: two, far off, nearly finished, over the most air of the four.
    # Quietest and darkest grade here.
    "night": dict(voices=2, buzz=0.76, near=0.00, carrier=2950.0,
                  bed_db=-5.0, top=-8.5, lufs=-30.2),
}


def make_cicadas(part, n):
    """A chorus of songs that arrive and leave, at one time of day."""
    g = CICADA_GRADES[part]
    seed = 139 + 7 * ("day", "dawn", "dusk", "night").index(part)
    rng = np.random.default_rng(seed)
    swell = b_gust(n, (1, 2, 5), (0.5, 0.3, 0.2), (0.4, 2.1, 4.7), floor=0.38)

    layers = {"near": np.zeros(n), "far": np.zeros(n)}
    for _ in range(g["voices"]):
        close = rng.random() < g["near"]
        length = min(n, int(SR * rng.uniform(3.4, 7.5)))
        song = i_song(
            rng, length,
            carrier=g["carrier"] * rng.uniform(0.82, 1.20),
            q=rng.uniform(4.5, 8.5),
            buzz_hz=g["buzz"] * rng.uniform(105.0, 250.0),
            rise=rng.uniform(0.7, 1.9), fall=rng.uniform(1.1, 2.8))
        # The near/far gap is 6-12 dB, not the 20 dB it started at: with the
        # wider gap one close singer owned the loop and the envelope range
        # came out at 17.8 dB, which is a bed that keeps taking the room.
        gain = rng.uniform(0.6, 1.0) * (1.0 if close else rng.uniform(0.26, 0.50))
        # One or two renditions of the same individual's song per loop.
        i_scatter(layers["near" if close else "far"], rng, song,
                  int(rng.integers(1, 3)), jitter=0.30, gain=gain)

    near = i_air(layers["near"], rng, decay=0.28, damp=6000.0, mix=0.18)
    far = i_air(layers["far"], rng, decay=0.55, damp=3400.0, mix=0.50)
    far = b_band(far, 800.0, 6200.0, order=1)
    chorus = (near + far) * (0.5 + 0.5 * swell)

    # Hot still air, and the leaves it is moving. Nothing under 200 Hz.
    bed = b_cnoise(n, rng, exponent=1.2, corner=900.0, order=2,
                   hp=200.0, hp_order=4)
    bed *= 0.55 + 0.45 * swell

    sig = i_mix([(chorus, 0.0), (bed, g["bed_db"])])
    # Rule 4 from the marine banner, and it matters most here: cicadas live
    # exactly where harshness does, so the band is tilted rather than removed.
    sig = b_shelf(sig, 5000.0, g["top"], order=1)
    return _a_cut_at_lull(b_to_lufs(sig, g["lufs"]))


def make_nighttrain(dur=18.0, joints=13):
    """The room the Night Train mixtape is playing in.

    A rail joint, twice per joint because a bogie has two axles, and
    **thirteen joints to the loop** rather than one every 1.36 s. That is the
    only real change to the rhythm and it is the one that mattered: 18 s is
    not a whole number of 1.36 s periods, so the old pattern arrived at the
    wrap mid-stride and left a gap no train has. Thirteen to the loop is
    1.385 s apart — the same walking pace, still half speed on purpose,
    because a real rhythm would fight the music — and it crosses the seam
    without a limp.

    Three layers: the carriage's rumble with a slow sway, a hail of small
    grains that is the wheels on the rail rather than more noise, and the
    joints themselves. Distance is the soft top on the whole mix — a night
    train is restful because it is *somewhere else*, and somewhere else is a
    spectrum, not a volume.

    Measured against the old rendering: **-67.7 -> -26.0 LUFS** (the old file
    was, strictly, inaudible), the share under 120 Hz 1.000 -> 0.330, the
    centroid 4 -> 316 Hz, envelope variation 0.54 -> 0.50 at forty times the
    level, and the envelope now peaks at 0.72 Hz — the joints — where before
    the only periodicity was the infrasonic drift.
    """
    rng = np.random.default_rng(149)
    n = int(SR * dur)
    sway = _a_gust(n, cycles=(1, 2, 5), amps=(0.50, 0.30, 0.20),
                   floor=0.50, shape=1.05)
    rumble = _a_shelf(_a_cnoise(n, rng, exponent=0.95, cutoff=700, order=1,
                                highpass=80.0, hp_order=2), 1100.0, -6.0) * sway

    roll = scatter(
        n, rng, int(dur * 110), sway,
        lambda r: droplet(r, int(r.integers(60, 240)),
                          r.uniform(300.0, 1800.0),
                          q=r.uniform(1.2, 2.5), decay=r.uniform(8.0, 14.0)),
        gain=(0.5, 2.2), follow=0.7)

    clacks = np.zeros(n)
    period = n / joints
    for j in range(joints):
        for offset, level in ((0.0, 1.0), (0.088, 0.82)):
            grain = droplet(rng, int(SR * 0.22), rng.uniform(210.0, 260.0),
                            q=1.2, second=3.2, decay=10.0)
            idx = (int(j * period + offset * SR) + np.arange(len(grain))) % n
            clacks[idx] += grain * level * rng.uniform(0.88, 1.12)

    mix = rumble * 0.60 + roll * 0.70 + clacks * 5.5
    return _a_cut_at_lull(_a_to_lufs(_a_shelf(mix, 1600.0, -5.0)))


def make_raintent(variant=0, dur=14.0):
    """Rain on a membrane a foot above your head.

    The one loop in this family the measurements say was too *dull* rather
    than too bright: it had nothing at all in the 2-8 kHz band, a tilt of
    -10.6 dB per octave and a centroid of 400 Hz, which is why it read as
    muffled rather than as being inside something. The targets have floors as
    well as ceilings for exactly this case, and this rendering moves up to
    meet them — a third layer of fine spray above the taps, the membrane's
    own note excited by noise instead of two sine partials, and the bed's
    corner an octave off the floor.

    The taps are the point and they stay the point: three modes with real
    bandwidth, which is a struck skin rather than a struck tuning fork.
    """
    rng = np.random.default_rng(151 + variant * 17)
    n = int(SR * dur)
    gust = _a_gust(n, cycles=(1, 3, 8), amps=(0.5, 0.3, 0.2),
                   floor=0.26, shape=1.30)
    bed = wet_bed(n, rng, exponent=1.0, cutoff=4200, shelf_hz=1800,
                  shelf_db=-3.0, base=190.0) * gust
    taps = scatter(
        n, rng, int(dur * 46), gust,
        lambda r: membrane_tap(r, int(r.integers(280, 660)),
                               r.uniform(330.0, 620.0)),
        gain=(0.3, 1.0), follow=1.3)
    spray = scatter(
        n, rng, int(dur * 22), gust,
        lambda r: droplet(r, int(r.integers(120, 260)),
                          r.uniform(1400.0, 2600.0), q=r.uniform(5.0, 9.0),
                          decay=12.0),
        gain=(0.15, 0.5), follow=1.2)
    return _a_cut_at_lull(_a_to_lufs(bed * 0.85 + taps * 0.6 + spray * 0.5))


def make_emberslate(dur=18.0):
    """The fireplace an hour after anybody put a log on.

    Same machinery as `make_fireplace` — that is the point of it — turned
    all the way down: three ticks a second instead of thirty, duller and
    quieter, and no roar under them at all. What is left is the room being
    warm, plus the occasional *shift*, a low soft thing a settling log does
    about once every three seconds.

    It is the one loop on the shelf that is deliberately not at -26 LUFS.
    A second and a half under is enough to hear as "the fire has gone down"
    beside `fireplace` without putting it back where nobody could hear it at
    all; anything further and the volume slider is doing the app's job.

    Measured against the old rendering: -45.6 -> -27.5 LUFS, the share under
    120 Hz 0.998 -> 0.309, the centroid 6 -> 305 Hz, and the wrap — which had
    been so far past measuring that the seam ratio overflowed in all four
    grades — now sits at 0.1 to 0.3 median sample steps.
    """
    rng = np.random.default_rng(157)
    n = int(SR * dur)
    settle = _a_gust(n, cycles=(1, 3, 7), amps=(0.50, 0.30, 0.20),
                     floor=0.34, shape=1.05)
    bed = _a_shelf(_a_cnoise(n, rng, exponent=1.05, cutoff=900, order=1,
                             highpass=110.0, hp_order=2), 1400.0, -5.0) * settle

    ticks = scatter(
        n, rng, int(dur * 3.5), settle,
        lambda r: droplet(r, int(r.integers(160, 520)),
                          r.uniform(700.0, 2400.0),
                          q=r.uniform(2.0, 4.5), decay=r.uniform(8.0, 14.0)),
        gain=(1.5, 5.0), follow=0.9)
    shifts = scatter(
        n, rng, max(1, int(dur * 0.35)), settle,
        lambda r: droplet(r, int(r.integers(2200, 5200)),
                          r.uniform(150.0, 340.0),
                          q=r.uniform(3.0, 6.0), decay=r.uniform(4.0, 7.0)),
        gain=(2.0, 5.0), follow=0.6)
    return _a_cut_at_lull(
        _a_to_lufs(bed * 0.80 + ticks * 0.90 + shifts * 0.45, target=-27.5))


# ------------------------------------------------------------------- chime
def make_chime(dur=1.8):
    n = int(SR * dur)
    t = np.arange(n) / SR
    # Soft two-note bell, a friendly major sixth.
    sig = np.zeros(n)
    for freq, amp, decay in ((880.0, 1.0, 3.2), (1318.5, 0.55, 3.8), (1760.0, 0.18, 5.0)):
        sig += amp * np.sin(2 * np.pi * freq * t) * np.exp(-decay * t)
    # Gentle attack so it never clicks.
    attack = np.minimum(1.0, t / 0.012)
    return normalize(sig * attack, 0.55)


# -------------------------------------------------------------------- icon
#
# One drawing, five palettes. The alternates exist because a Home screen is
# somebody's room and the app already asks which colours they like; what it
# must never become is sixteen near-identical squares, so the set is chosen by
# how far apart the hues land at 60 points rather than by how many themes
# there are. See `ICON_VARIANTS` for who got in and who did not.

def paw_colour(palette):
    """The pads, chosen by measurement rather than by eye.

    Off-white pads on a mid tomato is the shipped look and every alternate
    keeps it — unless off-white would read *worse* there than it does on the
    icon that already ships, which is what happens the moment the tomato goes
    pale (Midnight after dark: a periwinkle circle under white pads is one
    flat shape). The bar is Sakura's own measurement, computed here rather
    than written down, so it cannot drift from the icon it describes. The
    fallback is `onAccent`, which every palette already guarantees is legible
    on its own accent fill — the tomato *is* that fill.
    """
    bar = contrast(OFFWHITE, PALETTES["sakura"]["light"]["blossom"])
    if contrast(OFFWHITE, palette["blossom"]) >= bar - 1e-9:
        return OFFWHITE
    return palette["onAccent"]


def draw_icon(size, scale, palette):
    """The drawing itself, at `size` px, supersampled `scale`× and downsampled.

    Split out of `make_icon` so the same art can be rendered *at* a size rather
    than resized into one. That distinction is the whole of the macOS icon: a
    Mac wants the picture at 16, 32, 64, 128, 256, 512 and 1024 px, and taking
    the 1024 down to 16 in a second LANCZOS pass puts a resample on top of a
    resample — the rim highlight is `0.014·big` wide, about a pixel once it
    lands, and it does not survive being averaged twice.

    Always an opaque full-bleed square: that is what iOS wants (an app icon
    with an alpha channel is rejected at upload, not at build), and the macOS
    caller gets its rounded corners by masking this rather than by asking for
    a transparent canvas. The first attempt did ask, and the gradient went
    with it — the corners were right and the icon was a black tile.

    Every dimension here is a fraction of `big`, so the drawing is resolution
    independent; what is *not* independent is `int()`, which truncates a stem
    to nothing below about 70 px of `big`. Callers supersample accordingly.
    """
    cream, blush = palette["cream"], palette["blush"]
    blossom, sage, forest = palette["blossom"], palette["sage"], palette["forest"]
    bark, pads = palette["bark"], paw_colour(palette)

    big = size * scale
    # Vertical cream-to-blush gradient background (opaque, as Apple requires).
    top = np.array(blush, dtype=float)
    bottom = np.array(cream, dtype=float)
    ramp = np.linspace(0.0, 1.0, big)[:, None]
    grad = top[None, :] * (1 - ramp) + bottom[None, :] * ramp
    bg = np.repeat(grad[:, None, :], big, axis=1).astype(np.uint8)
    img = Image.fromarray(bg, mode="RGB")
    d = ImageDraw.Draw(img, "RGBA")

    cx = cy = big // 2
    radius = int(big * 0.335)

    # Soft drop shadow under the tomato.
    d.ellipse(
        [cx - radius, cy - radius + int(big * 0.02),
         cx + radius, cy + radius + int(big * 0.02)],
        fill=bark + (40,),
    )
    # The tomato body.
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=blossom)
    # Highlight crescent for a little depth — but only where it is at least a
    # pixel wide once the supersampling comes off.
    #
    # It is a hairline, 1.4 % of the square, which is 14 px on the 1024 that
    # ships and a fifth of a pixel on a 16 pt Mac icon. A sub-pixel white ring
    # does not read as depth; it reads as a second, paler circle laid over the
    # tomato's edge, and it is what turns the paw into a smudge down there.
    # Found by looking at the 32 px rendition beside Notes and Todoist: the
    # four toes separate the moment the ring goes.
    #
    # The threshold is on `size`, the finished width, so it cannot be moved by
    # changing `scale`. It keeps the ring on everything from 128 px up and on
    # every iOS rendition, which is why the shipped icon is unmoved.
    if size * RIM_WIDTH >= 1.0:
        inset = int(radius * 0.14)
        d.ellipse(
            [cx - radius + inset, cy - radius + inset,
             cx + radius - inset, cy + radius - inset],
            outline=(255, 255, 255, 46), width=int(big * RIM_WIDTH),
        )

    # Stem and two angled leaves on top, echoing the pomodoro tomato.
    stem_w = int(big * 0.015)
    d.rounded_rectangle(
        [cx - stem_w, cy - radius - int(big * 0.070),
         cx + stem_w, cy - radius + int(big * 0.010)],
        radius=stem_w, fill=forest,
    )
    leaf_w, leaf_h = int(big * 0.105), int(big * 0.052)
    for direction, angle in ((-1, 28), (1, -28)):
        leaf = Image.new("RGBA", (leaf_w * 2, leaf_h * 2), (0, 0, 0, 0))
        ImageDraw.Draw(leaf).ellipse(
            [leaf_w // 2, leaf_h // 2, leaf_w * 2 - leaf_w // 2, leaf_h * 2 - leaf_h // 2],
            fill=sage,
        )
        leaf = leaf.rotate(angle, resample=Image.BICUBIC, expand=False)
        lx = cx + direction * int(big * 0.042) - leaf_w
        ly = cy - radius - int(big * 0.048) - leaf_h
        img.paste(leaf, (lx, ly), leaf)

    # Paw print: one pad plus four toes, sized to stay clear of the rim.
    pad_w, pad_h = int(radius * 0.40), int(radius * 0.33)
    pad_cy = cy + int(radius * 0.20)
    d.ellipse([cx - pad_w, pad_cy - pad_h, cx + pad_w, pad_cy + pad_h], fill=pads)
    toes = [(-0.44, -0.30, 0.135), (-0.16, -0.47, 0.150),
            (0.16, -0.47, 0.150), (0.44, -0.30, 0.135)]
    for fx, fy, fr in toes:
        tx = cx + int(radius * fx)
        ty = cy + int(radius * fy)
        rr = int(radius * fr)
        d.ellipse([tx - rr, ty - int(rr * 1.2), tx + rr, ty + int(rr * 1.2)], fill=pads)

    return img.resize((size, size), Image.LANCZOS)


def make_icon(size=1024, scale=2, theme="sakura", appearance="light",
              name="AppIcon", quiet=False):
    """The iOS app icon: one opaque 1024 square, written to its `.appiconset`.

    `theme`/`appearance` pick which of `AppTheme.palette`'s colours it is drawn
    in; `name` is the `.appiconset` it is written to. The default arguments
    reproduce the shipped icon byte for byte — that is asserted by
    `check_icons.py`, because "the alternates landed" must never quietly mean
    "and the one on everybody's Home screen moved too".

    `AppIcon` also gets the macOS ladder written beside it; see `MAC_ICON`.
    """
    img = draw_icon(size, scale, PALETTES[theme][appearance])
    if quiet:
        return img
    folder = os.path.join(ASSETS, f"{name}.appiconset")
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, f"{name}.png")
    img.save(path, "PNG")
    entries = [{"filename": f"{name}.png", "idiom": "universal",
                "platform": "ios", "size": "1024x1024"}]
    if name == MAC_ICON:
        entries += write_mac_ladder(folder, name, theme, appearance)
    # Contents.json is written here rather than kept by hand, and that is not
    # tidiness. Ten macOS PNGs beside a Contents.json nobody updated are ten
    # files that ship in git, cost nothing at build time, and leave the Mac
    # with no icon — which is the exact bug this ladder exists to fix, one
    # level down. The manifest and the pixels come out of the same run or the
    # generator has not done its job.
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": entries, "info": {"author": "xcode", "version": 1}},
                  f, indent=2, separators=(",", " : "))
        f.write("\n")
    print(f"  {name}.png: {size}x{size}, mode={img.mode}, "
          f"{os.path.getsize(path) / 1024:.0f} KB")
    return img


# ------------------------------------------------------------ the macOS icon
#
# A Mac icon is not the iOS icon resized. iOS hands the system a full-bleed
# opaque square and the system rounds it; macOS hands the system a picture and
# the system draws exactly that, so the rounding, the inset and the shadow are
# all the app's job. Get it wrong and Pawmodoro is a hard pink square in a Dock
# of soft ones.
#
# **These four numbers were measured off this Mac, not copied out of a
# tutorial.** `NSWorkspace.icon(forFile:)` was drawn at 1024 for fifteen apps —
# eight of Apple's own (Notes, Mail, Music, Calendar, Reminders, App Store,
# Freeform, Terminal) and seven third-party (Slack, Telegram, Todoist, Claude,
# Obsidian, Postman, GitHub Desktop) — and the alpha channel measured:
#
#   * **Body 824×824 at (100, 100)** on the 1024 canvas. Fourteen of the
#     fifteen agree to the pixel. (The fifteenth is Safari, whose icon is a
#     circle; Apple's grid lets a circle run wider, which is not our shape.)
#   * **Corner radius 185.5 px**, fitted to the measured edge of the top-left
#     quadrant at 0.83 px mean error. Worth knowing because the folklore says
#     "squircle": a continuous superellipse fits the *same* curve at n≈5.1 and
#     1.7 px, i.e. worse. At 1024 the two shapes differ by about two pixels at
#     45°, so this is a circular-arc rounded rectangle and PIL can draw it.
#   * **Shadow: σ ≈ 10 px, offset 10 px down, peak alpha 0.30.** Read straight
#     off Apple's own icons rather than fitted by eye — their alpha is 0.145
#     one pixel outside the right edge, 0.251 one pixel below the bottom edge,
#     and 0.043 eight pixels above the top edge, which is a single blurred
#     rectangle nudged downwards and no more than that.
#
# Everything is a fraction of the canvas, so the same recipe draws the 16 px
# icon and the 1024 px one.
MAC_BODY = 824.0 / 1024.0
MAC_CORNER = 185.5 / 824.0
MAC_SHADOW_SIGMA = 10.0 / 1024.0
MAC_SHADOW_OFFSET = 10.0 / 1024.0
MAC_SHADOW_ALPHA = 0.30

# The ten renditions Xcode's `mac` idiom asks for. There is no single-size
# support for this idiom — checked in Xcode 26.3 — so it is all ten or none,
# and "none" is what the app shipped with.
MAC_LADDER = [(points, scale) for points in (16, 32, 128, 256, 512)
              for scale in (1, 2)]

# Only the primary icon carries the ladder, and that is a decision rather than
# an oversight.
#
# The four alternates are *user-facing on iOS*: Settings has a picker, and
# `UIApplication.setAlternateIconName` swaps the Home screen. **macOS has no
# equivalent.** `AppIcons.supported` is hard-coded false off iOS,
# `AppIcons.set` returns `false`, and there is no AppKit call that swaps an
# asset-catalogue app icon — `NSApp.applicationIconImage` only paints the Dock
# tile of the running process, and it forgets the moment the app quits, so it
# could not be the picker's answer even if somebody wired it up.
#
# So mac renditions on the alternates would be forty PNGs and ~1 MB of
# catalogue that nothing on any platform can ever select. Worse, they would
# read as support: the next person to open the picker on a Mac would assume it
# works and go hunting for the bug. `check_icons.py` asserts the shape of this
# decision in both directions — the primary has the ladder, the alternates do
# not — so if macOS ever gains alternate icons, the checker is where you go to
# change your mind, and it is one line.
MAC_ICON = "AppIcon"


def rounded_mask(side, corner=MAC_CORNER, supersample=8):
    """An L-mode rounded-square mask, antialiased by supersampling.

    PIL's `rounded_rectangle` is aliased, and at 16 px an aliased corner is the
    difference between an icon and a postage stamp with the corners bitten off.
    """
    big = side * supersample
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, big - 1, big - 1], radius=corner * big, fill=255)
    return mask.resize((side, side), Image.LANCZOS)


def make_mac_icon(px, theme="sakura", appearance="light"):
    """One macOS rendition: the art inside the grid's body, with its shadow.

    Returns an RGBA image `px` square. The art is drawn *at the body's own
    size* — `draw_icon(body, …)` — never by resizing the 1024.
    """
    body = int(round(px * MAC_BODY))
    inset = (px - body) / 2.0
    # Supersample enough that the drawing's `int()` truncations still land on
    # something: below about 70 px of internal canvas the stem rounds away to
    # nothing, and at 16 px the body is 13 px across.
    scale = max(2, -(-1024 // body))
    art = draw_icon(body, scale, PALETTES[theme][appearance]).convert("RGBA")
    art.putalpha(rounded_mask(body))

    canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    sigma = px * MAC_SHADOW_SIGMA
    if sigma > 0.05:
        shadow = Image.new("L", (px, px), 0)
        shadow.paste(art.getchannel("A"),
                     (int(round(inset)),
                      int(round(inset + px * MAC_SHADOW_OFFSET))))
        shadow = shadow.filter(ImageFilter.GaussianBlur(sigma))
        shadow = shadow.point(lambda v: int(v * MAC_SHADOW_ALPHA))
        canvas.paste(Image.new("RGBA", (px, px), (0, 0, 0, 255)), (0, 0), shadow)
    canvas.alpha_composite(art, (int(round(inset)), int(round(inset))))
    return canvas


def write_mac_ladder(folder, name, theme, appearance):
    """Write the ten `idiom: mac` PNGs and return their `Contents.json` rows.

    Ten entries, seven distinct pixel sizes: 16@2x and 32@1x are both 32 px of
    the same picture, and so on up the ladder. They are written as separate
    files anyway, because that is what the entries name and a shared filename
    is a thing to explain rather than a thing to read.
    """
    entries = []
    for points, scale in MAC_LADDER:
        px = points * scale
        suffix = f"@{scale}x" if scale > 1 else ""
        filename = f"{name}-mac-{points}{suffix}.png"
        make_mac_icon(px, theme, appearance).save(
            os.path.join(folder, filename), "PNG")
        entries.append({"filename": filename, "idiom": "mac",
                        "scale": f"{scale}x", "size": f"{points}x{points}"})
    total = sum(os.path.getsize(os.path.join(folder, e["filename"]))
                for e in entries)
    print(f"  {name} macOS ladder: {len(entries)} renditions, "
          f"{total / 1024:.0f} KB")
    return entries


# Which icons exist, and why these.
#
# Eight themes in two appearances is sixteen icons, and sixteen is the wrong
# answer. The set was cut by measurement — `check_icons.py --report` renders
# every candidate at 60 points under the Home-screen mask and compares them in
# CIELAB — and the measuring corrected the eye twice, which is the reason it
# was done:
#
# - **Sakura and Ink-in-daylight are near twins (ΔE 14.4).** Both are a pale
#   page with a warm pink-red disc on it. That pairing looked fine as
#   1024-pixel art and only collapsed at thumb size, which is the entire
#   failure mode this list exists to avoid. Ink is in the set as its *dark*
#   appearance instead: charcoal with one red, which is what the theme's own
#   blurb has always promised.
# - **Snowdrift is not a paler Sakura (ΔE 32.6),** which is what it was
#   assumed to be and would have been cut for. Its tomato is blue. It is one
#   of the four furthest-apart icons here.
#
# Cut for being too close to something already in: Cocoa (ΔE 5.0 from Ember),
# Midnight-after-dark (8.2 from Snowdrift), Lavender (10.4 from Midnight,
# 17.2 from Snowdrift), Ink-in-daylight (14.4 from Sakura).
#
# **Seasons are out entirely**, and not on separation grounds. A seasonal icon
# wants to turn over by itself, and every icon change on iOS pops a system
# alert the app cannot suppress — an app that interrupts your Home screen four
# times a year to announce its own cleverness has taken something and given
# nothing. Asking instead is no better: you would be picking autumn in July.
#
# What is left is five icons at ΔE 22.9 or further apart: pink, green, amber,
# ice, and one that is actually dark.
ICON_VARIANTS = [
    # (iconset name, theme, appearance)
    ("AppIcon", "sakura", "light"),
    ("AppIconMatcha", "matcha", "light"),
    ("AppIconEmber", "ember", "light"),
    ("AppIconSnowdrift", "snowdrift", "light"),
    # The one dark icon, and the reason it is an appearance rather than a
    # ninth palette: a Home screen full of dark widgets with one cream square
    # in it is the most-wanted alternate icon there is, and no light palette
    # in this family can supply it. Ink after dark is the best of them —
    # charcoal and one red — and it is also the furthest from everything else
    # in the set.
    ("AppIconInk", "ink", "dark"),
]

ALTERNATE_ICONS = [name for name, _, _ in ICON_VARIANTS if name != "AppIcon"]


def write_icon_preview(name, image, points=44):
    """A small copy of an icon, as an ordinary imageset the picker can draw.

    The picker needs to show the artwork, and an `.appiconset` cannot be
    asked for it: the renditions are in `Assets.car` under a name
    `UIImage(named:)` does not resolve — verified on screen, where every row
    of the picker drew its fallback rectangle and the five icons were five
    identical pink squares. (`assetutil` lists the names in the catalogue, so
    the trap is that the *inspection* looks right.)

    So the preview is a real imageset, generated from the same drawing. It is
    also the cheaper of the two: an app icon ships one 1024×1024 rendition,
    and five of those decoded for a 44-point row is about twenty megabytes of
    bitmap to fill a thumbnail.
    """
    folder = os.path.join(ASSETS, f"iconpreview_{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    entries = []
    for scale in (1, 2, 3):
        side = points * scale
        filename = f"iconpreview_{name}@{scale}x.png" if scale > 1 \
            else f"iconpreview_{name}.png"
        image.resize((side, side), Image.LANCZOS).save(
            os.path.join(folder, filename), "PNG")
        entries.append({"filename": filename, "idiom": "universal",
                        "scale": f"{scale}x"})
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": entries, "info": {"author": "xcode", "version": 1}},
                  f, indent=2, separators=(",", " : "))
        f.write("\n")


def make_icons():
    for name, theme, appearance in ICON_VARIANTS:
        image = make_icon(theme=theme, appearance=appearance, name=name)
        write_icon_preview(name, image)
    print(f"  {len(ICON_VARIANTS)} previews at 44 pt, x3 scales")


# --------------------------------------------------------------- things heard
#
# Five one-shots for the journal's quietest page: things that are only ever
# heard, never seen. They play once, low, under whatever else is going —
# headphone magic, and nearly free because nothing has to be drawn.
#
# All of them are *distant*, which in synthesis means three things: lowpassed
# hard, a slow attack, and a long soft tail. A close sound in this set would
# read as a notification.

def distant(sig, cutoff=1400.0, order=3):
    """Roll the top off so it sounds like it came from somewhere else."""
    spectrum = np.fft.rfft(sig)
    freq = np.fft.rfftfreq(len(sig), 1.0 / SR)
    return np.fft.irfft(
        spectrum / (1.0 + (freq / cutoff) ** (2 * order)) ** 0.5, len(sig)
    )


def envelope(n, attack, release):
    t = np.arange(n) / SR
    total = n / SR
    return np.minimum(1.0, t / attack) * np.minimum(
        1.0, np.maximum(0.0, (total - t) / release)
    )


def make_whalesong(dur=3.0):
    """Harbor, after dark. One long call that bends and falls away."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    # A glide down a fifth, with the slow wobble a real call has.
    freq = 132.0 * np.exp(-0.22 * t) + 6.0 * np.sin(2 * np.pi * 1.6 * t)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    sig = np.sin(phase) + 0.32 * np.sin(2 * phase) + 0.12 * np.sin(3 * phase)
    return normalize(distant(sig * envelope(n, 0.35, 1.1), 900.0), 0.34)


def make_trainhorn(dur=2.6):
    """From somewhere past Starfall. Two notes, because horns are chords."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for freq, amp in ((220.0, 1.0), (277.2, 0.8), (330.0, 0.45), (440.0, 0.2)):
        sig += amp * np.sin(2 * np.pi * freq * t)
    # Doppler-ish sag as it goes away from you.
    sig *= 1.0 - 0.04 * t
    return normalize(distant(sig * envelope(n, 0.25, 0.9), 1100.0), 0.30)


def make_owlcall(dur=2.8, seed=7):
    """The Woods, at night. Two hoots and then nothing at all."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    sig = np.zeros(n)
    # A tawny owl's call is nearly a pure tone with a breathy edge.
    for start, length, freq in ((0.10, 0.45, 402.0), (1.05, 0.62, 388.0)):
        begin, count = int(SR * start), int(SR * length)
        local = np.arange(count) / SR
        hoot = np.sin(2 * np.pi * (freq - 14.0 * local) * local)
        hoot += 0.09 * shaped_noise(count, rng, 1.0, cutoff=900.0)
        sig[begin:begin + count] += hoot * envelope(count, 0.06, 0.30)
    return normalize(distant(sig, 1500.0), 0.30)


def make_distantthunder(dur=4.0, seed=23):
    """Anywhere, in a storm. A long way off, and already going away.

    Thunder is not a bang at this distance — the high end is gone by the time
    it reaches you and what is left is a low roll. Shaped noise through a low
    cutoff, with two swells rather than one, because a single envelope reads
    as a door closing.
    """
    n = int(SR * dur)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    sig = shaped_noise(n, rng, 1.0, cutoff=220.0)
    # Two swells, the second smaller and later: the rumble arriving off the
    # hills after the first has passed.
    swell = np.exp(-1.1 * t) + 0.45 * np.exp(-2.2 * np.abs(t - 1.4))
    return normalize(distant(sig * swell * envelope(n, 0.18, 1.6), 400.0), 0.32)


def make_foghorn(dur=3.6):
    """Harbor Isle, in the mist. One note, held, and meant to be obeyed."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    # Low and nearly pure, with a second an octave up at a quarter strength —
    # a real horn is a single reed and the harmonic is what carries.
    for freq, amp in ((87.3, 1.0), (174.6, 0.26), (262.0, 0.08)):
        sig += amp * np.sin(2 * np.pi * freq * t)
    # It holds flat and then stops, which is the whole character of it.
    hold = np.minimum(1.0, t / 0.5) * np.minimum(1.0, (dur - t) / 0.8)
    return normalize(distant(sig * hold, 700.0), 0.30)


def make_geesesouth(dur=4.2, seed=29):
    """Autumn, overhead. Several of them, none in time with the others."""
    n = int(SR * dur)
    rng = np.random.default_rng(seed)
    sig = np.zeros(n)
    # Fourteen calls scattered over four seconds. A skein is a crowd, and a
    # regular interval would make it a machine.
    for _ in range(14):
        start = rng.uniform(0.05, dur - 0.7)
        begin = int(SR * start)
        count = int(SR * rng.uniform(0.16, 0.28))
        count = min(count, n - begin)
        local = np.arange(count) / SR
        freq = rng.uniform(430.0, 560.0)
        # The break upward at the end is what makes it a goose and not a duck.
        call = np.sin(2 * np.pi * (freq + 180.0 * local / (count / SR)) * local)
        call += 0.4 * np.sin(2 * np.pi * 2 * freq * local)
        call += 0.12 * shaped_noise(count, rng, 1.0, cutoff=2200.0)
        sig[begin:begin + count] += call * envelope(count, 0.02, 0.10) * rng.uniform(0.4, 1.0)
    return normalize(distant(sig, 2600.0), 0.26)


def make_farbell(dur=3.4):
    """Sunstone Keep, at dawn. One stroke, a long way off."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    # Bell partials are inharmonic — that ratio set is what stops it being a
    # sine with a decay on it.
    for ratio, amp, decay in (
        (1.0, 1.0, 1.1), (2.01, 0.55, 1.6), (2.98, 0.32, 2.2),
        (4.17, 0.18, 3.0), (5.43, 0.10, 3.8),
    ):
        sig += amp * np.sin(2 * np.pi * 196.0 * ratio * t) * np.exp(-decay * t)
    return normalize(distant(sig * np.minimum(1.0, t / 0.008), 1800.0), 0.28)


def make_windchime(dur=3.2, seed=11):
    """Blossom Village. Four rods, struck in no particular order."""
    n = int(SR * dur)
    rng = np.random.default_rng(seed)
    sig = np.zeros(n)
    # A pentatonic set, so any order of strikes is consonant.
    notes = (587.3, 659.3, 784.0, 880.0, 1046.5)
    for start, note in zip((0.05, 0.42, 0.78, 1.35, 2.05), notes):
        begin = int(SR * start)
        count = min(n - begin, int(SR * 1.6))
        local = np.arange(count) / SR
        rod = np.sin(2 * np.pi * note * local) * np.exp(-2.4 * local)
        rod += 0.25 * np.sin(2 * np.pi * note * 2.76 * local) * np.exp(-4.0 * local)
        sig[begin:begin + count] += rod * rng.uniform(0.6, 1.0)
    return normalize(distant(sig, 3200.0), 0.26)


# ----------------------------------------------------------- the hour bells
#
# Four voices, one per kind of place, each rendered at the four times of day
# through `graded(..., BELL_GRADES)`. Nothing is layered or filtered at
# runtime: a strike is a file, chosen by place and by the hour it strikes,
# and played once on its own `AVAudioPlayer` exactly the way a "heard" sound
# is. Sixteen small WAVs is the whole cost of the feature.
#
# They are all deliberately quieter and further away than `make_farbell`,
# which is a *findable* sound and wants to be noticed. These are not findable
# and must not be noticed — they mark the hour for somebody who is already
# sitting, and the best outcome is that most of them go by unremarked.


def make_bell_church(dur=3.2):
    """Meadow, Woods, Blossom. A parish bell a field or two away.

    `make_farbell`'s inharmonic partial set at a lower fundamental and a
    slower attack — the attack is what puts distance on a bell, more than the
    filter does.
    """
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for ratio, amp, decay in (
        (1.0, 1.0, 0.9), (2.02, 0.48, 1.4), (2.97, 0.26, 2.0),
        (4.21, 0.14, 2.8), (5.51, 0.07, 3.6),
    ):
        sig += amp * np.sin(2 * np.pi * 165.0 * ratio * t) * np.exp(-decay * t)
    # A hint of the second stroke a real tower gives you, well under the first.
    # The head is copied first: `sig[late:] += sig[:n - late]` reads samples it
    # has already overwritten, which numpy does not promise anything about.
    late = int(SR * 1.45)
    sig[late:] += 0.22 * sig[:n - late].copy()
    return normalize(distant(sig * np.minimum(1.0, t / 0.012), 1500.0), 0.24)


def make_bell_buoy(dur=3.2):
    """Harbor Isle, and Cloudspire. A bell on something that is moving.

    Two uneven strikes rather than one, because a bell buoy is rung by the
    swell and the swell is not a metronome. Lower, flatter partials: this is a
    struck iron cage, not a cast bell.
    """
    n = int(SR * dur)
    sig = np.zeros(n)
    for start_s, gain in ((0.04, 1.0), (1.18, 0.62)):
        begin = int(SR * start_s)
        count = n - begin
        local = np.arange(count) / SR
        strike = np.zeros(count)
        for ratio, amp, decay in (
            (1.0, 1.0, 1.6), (2.44, 0.60, 2.4), (3.71, 0.30, 3.4), (6.10, 0.12, 5.0),
        ):
            strike += amp * np.sin(2 * np.pi * 232.0 * ratio * local) * np.exp(-decay * local)
        sig[begin:] += strike * np.minimum(1.0, local / 0.004) * gain
    return normalize(distant(sig, 2400.0), 0.24)


def make_bell_bowl(dur=3.6):
    """Moonlit Onsen. A standing bowl, struck once, still going.

    One near-pure fundamental with a beat on it — two partials a fraction of a
    hertz apart is what gives a bowl its slow shimmer, and it is the reason
    this one does not need a second strike to stay interesting.
    """
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for ratio, amp, decay, detune in (
        (1.0, 1.0, 0.55, 0.7), (2.76, 0.34, 0.95, 1.3), (5.40, 0.11, 1.8, 2.1),
    ):
        base = 261.6 * ratio
        sig += amp * np.exp(-decay * t) * (
            np.sin(2 * np.pi * base * t) + 0.9 * np.sin(2 * np.pi * (base + detune) * t)
        )
    # The mallet, not the metal: a short knock under the first tenth of a second.
    knock = shaped_noise(n, np.random.default_rng(41), 0.8, cutoff=1800.0)
    sig += 0.20 * knock * np.exp(-38.0 * t)
    return normalize(distant(sig * np.minimum(1.0, t / 0.003), 2600.0), 0.24)


def make_bell_clock(dur=3.2):
    """Sunstone Keep, and Starfall Peaks. A cased movement striking the hour.

    A hammer on a coiled rod rather than a bell: a hard, dry attack, a short
    decay, and almost no low end. Struck twice at a fixed spacing, because the
    one thing a clock is, is regular.
    """
    n = int(SR * dur)
    sig = np.zeros(n)
    for start_s, gain in ((0.03, 1.0), (0.86, 0.86)):
        begin = int(SR * start_s)
        count = n - begin
        local = np.arange(count) / SR
        rod = np.zeros(count)
        for ratio, amp, decay in (
            (1.0, 1.0, 2.6), (2.71, 0.42, 3.6), (5.14, 0.20, 5.2), (8.03, 0.08, 7.0),
        ):
            rod += amp * np.sin(2 * np.pi * 349.2 * ratio * local) * np.exp(-decay * local)
        # The hammer itself, which is half of what a strike sounds like indoors.
        rod += 0.16 * shaped_noise(count, np.random.default_rng(59), 0.5,
                                   cutoff=5200.0) * np.exp(-90.0 * local)
        sig[begin:] += rod * gain
    return normalize(distant(sig, 3400.0), 0.24)


def write_bell(name, sig):
    """One strike, four times of day, as four one-shot WAVs.

    Not `write_loop`: there is nothing to loop, so nothing to keep
    frame-exact and no reason to pay AAC's priming frames. Same file shape and
    same naming convention as the "things heard" — the day grade keeps the
    bare name, so the app's filename rule stays "base, or base_<part>".
    """
    total = 0
    for part in ("dawn", "day", "dusk", "night"):
        stem = name if part == "day" else f"{name}_{part}"
        write_wav(stem + ".wav", graded(sig, part, BELL_GRADES))
        total += os.path.getsize(os.path.join(RES, stem + ".wav"))
    print(f"  {name}: 4 grades, {total / 1024:.0f} KB")


AMBIENCE_TABLE = os.path.join(ROOT, "Pawmodoro", "Model", "AmbienceLoops.swift")


def read_ambience_table():
    """The shipping frame counts, read back out of the generated Swift.

    Only for a partial run (`generate_assets.py loops crickets`), where the
    loops that were not re-rendered still have to appear in the table. Asking
    the Swift is the same rule the rest of the toolchain lives by; keeping a
    second copy of eighteen numbers in here would be the thing that rule
    exists to forbid. A partial run then asserts it removed nothing.
    """
    source = open(AMBIENCE_TABLE).read()
    return {name: int(frames) for name, frames in
            re.findall(r"case \.(\w+): (\d+)", source)}


def write_ambience_table(partial=False):
    """The generated companion to `Ambience`, holding one number per loop."""
    path = AMBIENCE_TABLE
    if partial:
        shipped = read_ambience_table()
        missing = set(shipped) - set(LOOP_FRAMES)
        for name in missing:
            LOOP_FRAMES[name] = shipped[name]
        added = set(LOOP_FRAMES) - set(shipped)
        assert not added, f"partial run invented loops: {sorted(added)}"
    lines = [
        "// Generated by tools/generate_assets.py — do not edit by hand.",
        "//",
        "// Exact loop length in frames at 22.05 kHz, per ambience. The app",
        "// trims the decoded AAC to this before scheduling it as a looping",
        "// buffer: the encoder's priming frames would otherwise tick at every",
        "// repeat. Same contract as MusicTrack.loopFrames, same reason.",
        "",
        "import Foundation",
        "",
        "extension Ambience {",
        "    /// Exact loop length in frames, or nil for `.off`.",
        "    var loopFrames: Int? {",
        "        switch self {",
        "        case .off: nil",
    ]
    for name in sorted(LOOP_FRAMES):
        lines.append(f"        case .{name}: {LOOP_FRAMES[name]}")
    lines += ["        }", "    }", "}", ""]
    with open(path, "w") as f:
        f.write("\n".join(lines))
    print(f"  AmbienceLoops.swift: {len(LOOP_FRAMES)} loops")


if __name__ == "__main__":
    # `generate_assets.py icons` skips the audio.
    #
    # Not a convenience: the audio half of this file re-renders and re-encodes
    # about two hundred files and takes minutes, and `afconvert` restamps three
    # MP4 timestamp atoms every time, so a run made to move one pixel of the
    # icon leaves eighteen bytes of churn per ambience behind it. The icons are
    # the only thing here anyone iterates on.
    if len(sys.argv) > 1 and sys.argv[1] == "icons":
        print("Icons:")
        make_icons()
        sys.exit(0)

    # `generate_assets.py loops crickets cicadas` re-renders named loops only.
    #
    # For the same reason as `icons`, turned the other way round: re-voicing
    # one loop should not restamp the other two hundred files and leave the
    # working tree unreadable. The table is then rewritten from the Swift's
    # own numbers plus whatever this run produced.
    if len(sys.argv) > 2 and sys.argv[1] == "loops":
        wanted = set(sys.argv[2:])
        known = {"crickets": lambda: write_loop_i("crickets", make_crickets, 20.0),
                 "cicadas": lambda: write_loop_i("cicadas", make_cicadas, 16.0)}
        unknown = wanted - set(known)
        if unknown:
            sys.exit(f"no partial recipe for: {sorted(unknown)}")
        print("Ambience loops (partial):")
        for name in sorted(wanted):
            known[name]()
        write_ambience_table(partial=True)
        sys.exit(0)

    print("Ambience loops:")
    write_varied("rain", make_rain)
    write_loop("purr", make_purr())
    write_loop("fireplace", make_fireplace())
    print("Ambience loops (Pawmodoro Plus):")
    write_loop_b("forest", make_forest())
    write_loop_b("cafe", make_cafe())
    write_loop_b("ocean", make_ocean())
    # The Second Shelf — Phase W, batch one.
    write_varied("drizzle", make_drizzle)
    write_loop_b("wind", make_wind())
    write_loop_b("creek", make_creek())
    write_loop_b("library", make_library())
    write_loop_b("snowhush", make_snowhush())
    write_loop_b("temple", make_temple())
    # The Second Shelf — batch two.
    write_varied("storm", make_storm)
    write_loop_i("crickets", make_crickets, 20.0)
    write_loop_i("cicadas", make_cicadas, 16.0)
    write_loop("nighttrain", make_nighttrain())
    write_varied("raintent", make_raintent)
    write_loop("emberslate", make_emberslate())
    write_ambience_table()
    print("Chime:")
    write_wav("chime.wav", make_chime())
    print("Things heard:")
    write_wav("heard_whalesong.wav", make_whalesong())
    write_wav("heard_trainhorn.wav", make_trainhorn())
    write_wav("heard_owlcall.wav", make_owlcall())
    write_wav("heard_farbell.wav", make_farbell())
    write_wav("heard_windchime.wav", make_windchime())
    write_wav("heard_distantthunder.wav", make_distantthunder())
    write_wav("heard_foghorn.wav", make_foghorn())
    write_wav("heard_geesesouth.wav", make_geesesouth())
    print("The bell of hours:")
    write_bell("bell_church", make_bell_church())
    write_bell("bell_buoy", make_bell_buoy())
    write_bell("bell_bowl", make_bell_bowl())
    write_bell("bell_clock", make_bell_clock())
    print("Icons:")
    make_icons()
