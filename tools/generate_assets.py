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
from PIL import Image, ImageDraw

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


# -------------------------------------------------------------------- purr
def make_purr(dur=8.0, fade=0.4):
    rng = np.random.default_rng(11)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    t = np.arange(n) / SR
    # Low rumble, heavily filtered.
    rumble = shaped_noise(n, rng, exponent=1.3, cutoff=260, order=3)
    # A cat purrs at roughly 25 Hz. Integer cycles per loop keeps it seamless.
    purr_rate = 26.0
    am = 0.5 + 0.5 * np.sin(2 * np.pi * purr_rate * t) ** 2
    # Breathing: slow swell in and out.
    breath = 0.62 + 0.38 * np.sin(2 * np.pi * 0.25 * t) ** 2
    # A touch of warm body tone under the noise.
    tone = 0.25 * np.sin(2 * np.pi * 62.0 * t) + 0.12 * np.sin(2 * np.pi * 124.0 * t)
    return seamless(normalize((rumble + tone) * am * breath, 0.40), fade_n)


# --------------------------------------------------------------- fireplace
def make_fireplace(dur=12.0, fade=0.5):
    rng = np.random.default_rng(23)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    t = np.arange(n) / SR
    # Low roar of the flame.
    roar = shaped_noise(n, rng, exponent=1.1, cutoff=850, order=2)
    roar *= 0.8 + 0.2 * np.sin(2 * np.pi * 0.17 * t + 0.4)
    # Crackles and pops from the wood.
    crackle = np.zeros(n)
    for _ in range(int(dur * 14)):
        start = rng.integers(0, n - 400)
        length = int(rng.integers(60, 220))
        env = np.exp(-np.linspace(0, 9, length))
        burst = rng.normal(size=length) * env
        crackle[start:start + length] += burst * rng.uniform(0.15, 0.55)
    return seamless(normalize(roar * 0.9 + crackle, 0.40), fade_n)


# ------------------------------------------------------------- forest (Plus)
def make_forest(dur=14.0, fade=0.6):
    rng = np.random.default_rng(31)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    t = np.arange(n) / SR
    # Wind through leaves: soft, slowly breathing.
    wind = shaped_noise(n, rng, exponent=0.9, cutoff=3000)
    wind *= 0.55 + 0.45 * np.sin(2 * np.pi * 0.07 * t + 0.6) ** 2
    # Rustles: brief bright bursts, like a branch moving.
    rustle = np.zeros(n)
    for _ in range(int(dur * 3)):
        start = rng.integers(0, n - 6000)
        length = int(rng.integers(2000, 5000))
        env = np.hanning(length)
        rustle[start:start + length] += (
            shaped_noise(length, rng, exponent=0.2, cutoff=8000) * env * rng.uniform(0.1, 0.3)
        )
    # Birdsong: short frequency-swept chirps in little phrases.
    birds = np.zeros(n)
    for _ in range(int(dur * 1.2)):
        phrase_start = rng.integers(0, n - 20000)
        for note in range(int(rng.integers(2, 5))):
            start = phrase_start + note * int(rng.integers(1600, 3200))
            length = int(rng.integers(700, 1500))
            if start + length >= n:
                break
            local = np.arange(length) / SR
            f0 = rng.uniform(2200.0, 3400.0)
            f1 = f0 * rng.uniform(0.75, 1.35)
            sweep = f0 + (f1 - f0) * (local / local[-1])
            env = np.hanning(length) ** 1.5
            birds[start:start + length] += (
                np.sin(2 * np.pi * sweep * local) * env * rng.uniform(0.06, 0.16)
            )
    return seamless(normalize(wind * 0.8 + rustle + birds, 0.40), fade_n)


# --------------------------------------------------------------- cafe (Plus)
def make_cafe(dur=14.0, fade=0.6):
    rng = np.random.default_rng(47)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    # Indistinct conversation: mid-band noise shaped by a slow, uneven envelope
    # so it swells and dips the way a room full of talking does.
    murmur = shaped_noise(n, rng, exponent=1.0, cutoff=1400, order=2)
    envelope = shaped_noise(n, rng, exponent=2.4, cutoff=6)
    envelope = 0.45 + 0.55 * (envelope - envelope.min()) / (np.ptp(envelope) + 1e-12)
    murmur *= envelope
    # Cups and spoons: short bright metallic taps.
    clinks = np.zeros(n)
    for _ in range(int(dur * 1.5)):
        start = rng.integers(0, n - 3000)
        length = int(rng.integers(500, 1400))
        local = np.arange(length) / SR
        env = np.exp(-local * rng.uniform(30, 60))
        tone = np.zeros(length)
        for freq, amp in ((rng.uniform(2300, 3100), 1.0), (rng.uniform(4200, 5400), 0.5)):
            tone += amp * np.sin(2 * np.pi * freq * local)
        clinks[start:start + length] += tone * env * rng.uniform(0.08, 0.22)
    return seamless(normalize(murmur + clinks, 0.38), fade_n)


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


def make_library(dur=20.0, fade=1.0):
    """A big quiet room, and somebody two tables away.

    Mostly a room tone: very dark noise with a slow tilt. The events are the
    whole feature — a page turned every few seconds, a pencil, once. They are
    what make silence read as *a room being quiet* rather than as no signal.
    """
    rng = np.random.default_rng(109)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    room = shaped_noise(n, rng, exponent=1.6, cutoff=520) * 0.55
    events = np.zeros(n)
    for _ in range(int(dur * 0.5)):                       # page turns
        start = rng.integers(0, n - 4000)
        length = int(rng.integers(1600, 3200))
        flick = shaped_noise(length, rng, exponent=0.2, cutoff=7000)
        events[start:start + length] += flick * envelope(length, 0.02, 0.5) * rng.uniform(0.10, 0.22)
    for _ in range(int(dur * 0.35)):                      # pencil
        start = rng.integers(0, n - 3000)
        length = int(rng.integers(900, 2000))
        scratch = shaped_noise(length, rng, exponent=0.1, cutoff=4200)
        scratch *= 0.6 + 0.4 * np.sin(2 * np.pi * 28.0 * np.arange(length) / SR)
        events[start:start + length] += scratch * envelope(length, 0.05, 0.4) * rng.uniform(0.05, 0.12)
    return seamless(normalize(room + events, 0.26), fade_n)


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


def make_temple(dur=24.0, fade=1.0):
    """Pine wind, and a bell every forty seconds or so.

    The bell is `make_farbell`'s voice at a longer decay, dropped in twice
    across the loop at uneven spacing — the whole point of a temple bell is
    that you stop expecting it and then it happens.
    """
    rng = np.random.default_rng(127)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    t = np.arange(n) / SR
    pines = shaped_noise(n, rng, exponent=1.3, cutoff=1500)
    pines *= 0.45 + 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.041 * t + 0.9))
    sig = pines * 0.55
    for start_s in (3.5, 15.2):
        begin = int(SR * start_s)
        length = min(int(SR * 7.0), n - begin)
        local = np.arange(length) / SR
        bell = np.zeros(length)
        for partial, gain in ((1.0, 1.0), (2.76, 0.34), (5.4, 0.12)):
            bell += gain * np.sin(2 * np.pi * 196.0 * partial * local)
        bell *= np.exp(-local * 0.85)
        sig[begin:begin + length] += distant(bell, 1900.0) * 0.5
    return seamless(normalize(sig, 0.30), fade_n)


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


def make_crickets(dur=14.0, fade=0.7):
    """Five voices at about 4.5 Hz, none of them agreeing.

    One pulse train is a smoke alarm. Five, detuned by a few per cent and
    started at different phases, is a field — the beating between them is the
    whole texture, and it is why the rate is per-voice rather than global.
    """
    rng = np.random.default_rng(137)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for voice in range(5):
        rate = 4.5 * rng.uniform(0.94, 1.07)
        phase = rng.uniform(0, 2 * np.pi)
        # A chirp is a burst of band-passed noise, not a tone: crickets are
        # broadband and a sine reads as electronics immediately.
        gate = (np.sin(2 * np.pi * rate * t + phase) > 0.72).astype(float)
        carrier = shaped_noise(n, rng, exponent=0.1, cutoff=5600)
        carrier = carrier - shaped_noise(n, np.random.default_rng(137 + voice),
                                         0.1, cutoff=2900)
        sig += gate * carrier * rng.uniform(0.5, 1.0)
    night = shaped_noise(n, rng, exponent=1.7, cutoff=400) * 0.35
    return seamless(normalize(sig * 0.5 + night, 0.32), fade_n)


def make_cicadas(dur=12.0, fade=0.6):
    """Summer, at full volume, tamed until it is bearable.

    Cicadas are a saw-shimmer around 4 kHz and genuinely painful up close, so
    this is `distant()`-ed harder than anything else here — the recipe is the
    sound heard from inside a room with the window open.
    """
    rng = np.random.default_rng(139)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    t = np.arange(n) / SR
    shimmer = np.zeros(n)
    for band in (3400.0, 4100.0, 4800.0):
        am = 0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(11.0, 15.0) * t
                                + rng.uniform(0, 6.0))
        tone = np.sin(2 * np.pi * band * t + 4.0 * np.sin(2 * np.pi * 30.0 * t))
        shimmer += tone * am
    swell = 0.5 + 0.5 * np.sin(2 * np.pi * 0.08 * t)
    body = shaped_noise(n, rng, exponent=0.6, cutoff=5000) * 0.4
    return seamless(normalize(distant(shimmer * swell * 0.35 + body, 3000.0), 0.28),
                    fade_n)


def make_nighttrain(dur=18.0, fade=0.9):
    """The room the Night Train mixtape is playing in.

    A rail joint every 1.36 s — two hits, close together, because a bogie has
    two axles. Under it, the interior rumble of a carriage: dark noise with a
    slow sway. Half speed on purpose; a real rhythm would fight the music.
    """
    rng = np.random.default_rng(149)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    t = np.arange(n) / SR
    rumble = shaped_noise(n, rng, exponent=1.9, cutoff=300) * 0.75
    rumble *= 0.85 + 0.15 * np.sin(2 * np.pi * 0.13 * t)
    clacks = np.zeros(n)
    period = 1.36
    start_s = 0.2
    while start_s < dur:
        for offset in (0.0, 0.085):
            begin = int(SR * (start_s + offset))
            length = int(SR * 0.045)
            if begin + length >= n:
                break
            hit = shaped_noise(length, rng, exponent=0.5, cutoff=1800)
            clacks[begin:begin + length] += hit * envelope(length, 0.002, 0.9) * 0.5
        start_s += period
    return seamless(normalize(rumble + clacks * 0.7, 0.34), fade_n)


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


def make_emberslate(dur=18.0, fade=0.9):
    """The fireplace an hour after anybody put a log on.

    All settle and no flame: the crackles are sparser, lower and further
    apart than `make_fireplace`, and there is no roar under them at all —
    what is left is the room being warm.
    """
    rng = np.random.default_rng(157)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    t = np.arange(n) / SR
    bed = shaped_noise(n, rng, exponent=1.7, cutoff=420) * 0.5
    bed *= 0.8 + 0.2 * np.sin(2 * np.pi * 0.06 * t)
    ticks = np.zeros(n)
    for _ in range(int(dur * 3)):
        start = rng.integers(0, n - 800)
        length = int(rng.integers(220, 620))
        local = np.arange(length) / SR
        crack = shaped_noise(length, rng, exponent=0.3, cutoff=2600)
        ticks[start:start + length] += crack * np.exp(-local * 26.0) * rng.uniform(0.10, 0.28)
    return seamless(normalize(bed + ticks, 0.24), fade_n)


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


def make_icon(size=1024, scale=2, theme="sakura", appearance="light",
              name="AppIcon", quiet=False):
    """Cozy icon: a tomato-timer circle with a paw print, drawn supersampled.

    `theme`/`appearance` pick which of `AppTheme.palette`'s colours it is drawn
    in; `name` is the `.appiconset` it is written to. The default arguments
    reproduce the shipped icon byte for byte — that is asserted by
    `check_icons.py`, because "the alternates landed" must never quietly mean
    "and the one on everybody's Home screen moved too".
    """
    palette = PALETTES[theme][appearance]
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
    # Highlight crescent for a little depth.
    inset = int(radius * 0.14)
    d.ellipse(
        [cx - radius + inset, cy - radius + inset, cx + radius - inset, cy + radius - inset],
        outline=(255, 255, 255, 46), width=int(big * 0.014),
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

    img = img.resize((size, size), Image.LANCZOS)
    if quiet:
        return img
    folder = os.path.join(ASSETS, f"{name}.appiconset")
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, f"{name}.png")
    img.save(path, "PNG")
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({
            "images": [{"filename": f"{name}.png", "idiom": "universal",
                        "platform": "ios", "size": "1024x1024"}],
            "info": {"author": "xcode", "version": 1},
        }, f, indent=2, separators=(",", " : "))
        f.write("\n")
    print(f"  {name}.png: {size}x{size}, mode={img.mode}, "
          f"{os.path.getsize(path) / 1024:.0f} KB")
    return img


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


def write_ambience_table():
    """The generated companion to `Ambience`, holding one number per loop."""
    path = os.path.join(ROOT, "Pawmodoro", "Model", "AmbienceLoops.swift")
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

    print("Ambience loops:")
    write_varied("rain", make_rain)
    write_loop("purr", make_purr())
    write_loop("fireplace", make_fireplace())
    print("Ambience loops (Pawmodoro Plus):")
    write_loop("forest", make_forest())
    write_loop("cafe", make_cafe())
    write_loop_b("ocean", make_ocean())
    # The Second Shelf — Phase W, batch one.
    write_varied("drizzle", make_drizzle)
    write_loop_b("wind", make_wind())
    write_loop_b("creek", make_creek())
    write_loop("library", make_library())
    write_loop_b("snowhush", make_snowhush())
    write_loop("temple", make_temple())
    # The Second Shelf — batch two.
    write_varied("storm", make_storm)
    write_loop("crickets", make_crickets())
    write_loop("cicadas", make_cicadas())
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
