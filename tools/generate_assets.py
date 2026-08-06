"""Generate Pawmodoro assets: app icon (PNG) + synthesized ambience loops (WAV).

All audio is procedurally synthesized here, so it is original content with no
licensing concerns. Swap for professionally recorded loops later if desired.
"""
import os
import subprocess
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
ICONSET = os.path.join(ROOT, "Pawmodoro", "Assets.xcassets", "AppIcon.appiconset")

# Theme colors (match Theme.swift)
CREAM = (252, 245, 227)
BLUSH = (250, 204, 209)
BLOSSOM = (237, 140, 168)
SAGE = (173, 201, 161)
FOREST = (74, 107, 87)
BARK = (115, 82, 61)
OFFWHITE = (255, 251, 246)

os.makedirs(RES, exist_ok=True)
os.makedirs(ICONSET, exist_ok=True)


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


def graded(sig, part):
    """One loop, at one time of day, by deterministic transform.

    The same idea `generate_scenes.py` applies to a place: draw it once, then
    grade it four ways rather than authoring four. A grade here is two knobs —
    a spectral tilt and a level — because those are what the ear actually
    reads as "later". Night is darker and quieter; dawn is thin and bright;
    dusk sits between. Day is the recipe unchanged, so the existing six sound
    exactly as they always have at noon.
    """
    if part == "day":
        return sig
    # A one-pole tilt: mix the signal with a smoothed copy of itself. More
    # smoothing is a darker sound, and it costs one pass.
    tilt, level = {
        "dawn": (0.25, 0.92),
        "dusk": (0.55, 0.86),
        "night": (0.80, 0.72),
    }[part]
    smoothed = np.copy(sig)
    # Two passes of a simple lowpass; coefficient from the tilt.
    a = 0.35 + 0.55 * tilt
    for _ in range(2):
        out = np.empty_like(smoothed)
        acc = 0.0
        for i in range(len(smoothed)):
            acc = acc + a * (smoothed[i] - acc)
            out[i] = acc
        smoothed = out
    return (sig * (1.0 - tilt) + smoothed * tilt) * level


def write_loop(name, sig):
    """A looping ambience: WAV out, AAC in, and the exact frame count kept.

    The same three-step the music takes, and for the same reason. AAC adds
    priming frames at the head and padding at the tail, so a decoder hands
    back more samples than were encoded; playing that back as a loop ticks
    every time round. The app trims the decoded buffer to the number below
    before scheduling it, which is why the number has to travel with the file.
    """
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


# -------------------------------------------------------------------- rain
def make_rain(dur=12.0, fade=0.5):
    rng = np.random.default_rng(7)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    # Broadband hiss with a gentle tilt: the body of the rain.
    body = shaped_noise(n, rng, exponent=0.4, cutoff=7000) * 0.8
    # Slow gusts so it breathes instead of sounding like static.
    t = np.arange(n) / SR
    gust = 0.85 + 0.15 * np.sin(2 * np.pi * 0.11 * t + 1.1)
    body *= gust
    # Individual droplets: short bright decaying pings.
    drops = np.zeros(n)
    for _ in range(int(dur * 55)):
        start = rng.integers(0, n - 900)
        length = int(rng.integers(180, 460))
        env = np.exp(-np.linspace(0, 7, length))
        freq = rng.uniform(1100.0, 3600.0)
        tone = np.sin(2 * np.pi * freq * np.arange(length) / SR)
        drops[start:start + length] += tone * env * rng.uniform(0.05, 0.22)
    return seamless(normalize(body + drops, 0.42), fade_n)


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


# -------------------------------------------------------------- ocean (Plus)
def make_ocean(dur=18.0, fade=1.0):
    rng = np.random.default_rng(59)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    # Each wave rushes in quickly and drains away slowly.
    envelope = np.zeros(n)
    period = int(SR * 5.5)
    for start in range(0, n, period):
        rise = int(SR * rng.uniform(1.0, 1.5))
        fall = int(SR * rng.uniform(2.6, 3.4))
        end = min(start + rise + fall, n)
        seg = end - start
        if seg <= rise:
            continue
        shape = np.concatenate([
            np.linspace(0, 1, rise) ** 1.6,
            np.linspace(1, 0, seg - rise) ** 0.7,
        ])
        envelope[start:end] += shape * rng.uniform(0.75, 1.0)
    envelope = np.clip(envelope, 0, 1.2)

    body = shaped_noise(n, rng, exponent=1.2, cutoff=1200, order=2)
    # Foam hiss rides on the crest of each wave, not the trough.
    foam = shaped_noise(n, rng, exponent=0.3, cutoff=9000) * (envelope ** 3) * 0.5
    swell = body * (0.18 + 0.82 * envelope)
    return seamless(normalize(swell + foam, 0.42), fade_n)


# ============================================================================
# The Second Shelf — Phase W's first six loops.
#
# Same rules as the first six: mono 22.05 kHz, seamless by crossfading the
# tail over the head, peak well under 1.0 so a track can sit on top without
# either of them clipping. Nothing here layers at runtime — every one is a
# finished loop the existing decode-once `.loops` path plays on one node,
# which is the law the music crash bought.
# ============================================================================

def make_drizzle(dur=12.0, fade=0.5):
    """Rain, thinner. Not quieter — thinner.

    The body is the rain recipe high-passed: take the weight out from under
    it and what is left reads as drizzle rather than as rain heard through a
    wall. Drops at a third the density, and higher, because small drops on
    hard ground is the sound being described.
    """
    rng = np.random.default_rng(101)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    body = shaped_noise(n, rng, exponent=0.15, cutoff=9000) * 0.7
    # High-pass by subtracting a lowpassed copy of the same noise.
    body = body - shaped_noise(n, np.random.default_rng(101), 0.15, cutoff=700) * 0.7
    t = np.arange(n) / SR
    body *= 0.88 + 0.12 * np.sin(2 * np.pi * 0.09 * t + 0.4)
    drops = np.zeros(n)
    for _ in range(int(dur * 18)):
        start = rng.integers(0, n - 700)
        length = int(rng.integers(120, 300))
        env = np.exp(-np.linspace(0, 9, length))
        freq = rng.uniform(2200.0, 5200.0)
        tone = np.sin(2 * np.pi * freq * np.arange(length) / SR)
        drops[start:start + length] += tone * env * rng.uniform(0.04, 0.16)
    return seamless(normalize(body + drops, 0.34), fade_n)


def make_wind(dur=16.0, fade=0.8):
    """Two LFOs beating against each other, so it never quite repeats.

    A single sweep is a machine. Two at 0.037 Hz and 0.053 Hz drift in and
    out of phase over about eighty seconds, which is long enough that the
    sixteen-second loop underneath stops being audible as a loop.
    """
    rng = np.random.default_rng(103)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    t = np.arange(n) / SR
    low = shaped_noise(n, rng, exponent=1.1, cutoff=900)
    high = shaped_noise(n, rng, exponent=0.4, cutoff=6000)
    a = 0.5 + 0.5 * np.sin(2 * np.pi * 0.037 * t)
    b = 0.5 + 0.5 * np.sin(2 * np.pi * 0.053 * t + 2.0)
    swell = 0.25 + 0.75 * (a * 0.6 + b * 0.4)
    sig = low * swell + high * (swell ** 2) * 0.35
    return seamless(normalize(sig, 0.38), fade_n)


def make_creek(dur=14.0, fade=0.7):
    """The ocean recipe at a quarter of the scale, and no wave cycle.

    A creek is the same physics in miniature: moving water over stones,
    band-passed high because there is no mass behind it. The bubbles are
    what stop it being hiss — short rising chirps, densely scattered.
    """
    rng = np.random.default_rng(107)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    body = shaped_noise(n, rng, exponent=0.5, cutoff=5200)
    body = body - shaped_noise(n, np.random.default_rng(107), 0.5, cutoff=400)
    bubbles = np.zeros(n)
    for _ in range(int(dur * 40)):
        start = rng.integers(0, n - 500)
        length = int(rng.integers(90, 220))
        local = np.arange(length) / SR
        f0 = rng.uniform(700.0, 1900.0)
        chirp = np.sin(2 * np.pi * (f0 + 900.0 * local / (length / SR)) * local)
        bubbles[start:start + length] += chirp * envelope(length, 0.01, 0.06) * rng.uniform(0.05, 0.18)
    return seamless(normalize(body * 0.7 + bubbles, 0.36), fade_n)


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


def make_snowhush(dur=16.0, fade=0.9):
    """The sound of sound being absorbed.

    Snow takes the top off everything and gives nothing back, so this is the
    darkest loop in the app and the quietest: peak 0.18 against rain's 0.42.
    The eight-second breath is the only thing that happens, and it has to be
    slow enough that you notice it only after a minute.
    """
    rng = np.random.default_rng(113)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    t = np.arange(n) / SR
    body = shaped_noise(n, rng, exponent=1.9, cutoff=340) * 0.8
    breath = 0.72 + 0.28 * np.sin(2 * np.pi * (1.0 / 8.0) * t)
    return seamless(normalize(body * breath, 0.18), fade_n)


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


def make_storm(dur=20.0, fade=1.0):
    """Rain with weight under it, and thunder that has already happened.

    The swells are brown noise on a 9-second period — the sound of a squall
    arriving rather than of rain at a constant rate. Two thunder rolls are
    baked in at uneven spacing and `distant()`-ed hard: near thunder is a
    transient and would tick every time the loop came round.
    """
    rng = np.random.default_rng(131)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    t = np.arange(n) / SR
    body = shaped_noise(n, rng, exponent=0.5, cutoff=6000) * 0.8
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * (1.0 / 9.0) * t + 0.7)
    body *= swell
    weight = shaped_noise(n, rng, exponent=1.8, cutoff=260) * 0.5 * swell
    drops = np.zeros(n)
    for _ in range(int(dur * 80)):
        start = rng.integers(0, n - 900)
        length = int(rng.integers(160, 420))
        env = np.exp(-np.linspace(0, 7, length))
        freq = rng.uniform(900.0, 3400.0)
        drops[start:start + length] += (
            np.sin(2 * np.pi * freq * np.arange(length) / SR)
            * env * rng.uniform(0.05, 0.20))
    sig = body + weight + drops
    for start_s in (4.0, 13.5):
        begin = int(SR * start_s)
        length = min(int(SR * 3.2), n - begin)
        roll = shaped_noise(length, rng, exponent=2.2, cutoff=180)
        roll *= envelope(length, 0.35, 0.9)
        sig[begin:begin + length] += distant(roll, 300.0) * 0.55
    return seamless(normalize(sig, 0.44), fade_n)


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


def make_raintent(dur=14.0, fade=0.7):
    """Rain on a membrane a foot above your head.

    The difference from rain is entirely resonance: canvas has a pitch, and
    every drop excites it. The drops are louder and far more present than in
    `make_rain`, and the body underneath is quieter — you are inside.
    """
    rng = np.random.default_rng(151)
    fade_n = int(SR * fade)
    n = int(SR * dur) + fade_n
    body = shaped_noise(n, rng, exponent=0.8, cutoff=3000) * 0.45
    taps = np.zeros(n)
    for _ in range(int(dur * 90)):
        start = rng.integers(0, n - 1200)
        length = int(rng.integers(300, 700))
        local = np.arange(length) / SR
        # Two partials a fifth apart: the membrane's own note.
        pitch = rng.uniform(320.0, 430.0)
        hit = (np.sin(2 * np.pi * pitch * local)
               + 0.5 * np.sin(2 * np.pi * pitch * 1.5 * local))
        taps[start:start + length] += hit * np.exp(-local * 42.0) * rng.uniform(0.10, 0.30)
    return seamless(normalize(body + taps, 0.38), fade_n)


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
def make_icon(size=1024, scale=2):
    """Cozy icon: a tomato-timer circle with a paw print, drawn supersampled."""
    big = size * scale
    # Vertical cream-to-blush gradient background (opaque, as Apple requires).
    top = np.array(BLUSH, dtype=float)
    bottom = np.array(CREAM, dtype=float)
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
        fill=(115, 82, 61, 40),
    )
    # The tomato body.
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=BLOSSOM)
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
        radius=stem_w, fill=FOREST,
    )
    leaf_w, leaf_h = int(big * 0.105), int(big * 0.052)
    for direction, angle in ((-1, 28), (1, -28)):
        leaf = Image.new("RGBA", (leaf_w * 2, leaf_h * 2), (0, 0, 0, 0))
        ImageDraw.Draw(leaf).ellipse(
            [leaf_w // 2, leaf_h // 2, leaf_w * 2 - leaf_w // 2, leaf_h * 2 - leaf_h // 2],
            fill=SAGE,
        )
        leaf = leaf.rotate(angle, resample=Image.BICUBIC, expand=False)
        lx = cx + direction * int(big * 0.042) - leaf_w
        ly = cy - radius - int(big * 0.048) - leaf_h
        img.paste(leaf, (lx, ly), leaf)

    # Paw print: one pad plus four toes, sized to stay clear of the rim.
    pad_w, pad_h = int(radius * 0.40), int(radius * 0.33)
    pad_cy = cy + int(radius * 0.20)
    d.ellipse([cx - pad_w, pad_cy - pad_h, cx + pad_w, pad_cy + pad_h], fill=OFFWHITE)
    toes = [(-0.44, -0.30, 0.135), (-0.16, -0.47, 0.150),
            (0.16, -0.47, 0.150), (0.44, -0.30, 0.135)]
    for fx, fy, fr in toes:
        tx = cx + int(radius * fx)
        ty = cy + int(radius * fy)
        rr = int(radius * fr)
        d.ellipse([tx - rr, ty - int(rr * 1.2), tx + rr, ty + int(rr * 1.2)], fill=OFFWHITE)

    img = img.resize((size, size), Image.LANCZOS)
    path = os.path.join(ICONSET, "AppIcon.png")
    img.save(path, "PNG")
    print(f"  AppIcon.png: {size}x{size}, mode={img.mode}, "
          f"{os.path.getsize(path) / 1024:.0f} KB")


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
    print("Ambience loops:")
    write_loop("rain", make_rain())
    write_loop("purr", make_purr())
    write_loop("fireplace", make_fireplace())
    print("Ambience loops (Pawmodoro Plus):")
    write_loop("forest", make_forest())
    write_loop("cafe", make_cafe())
    write_loop("ocean", make_ocean())
    # The Second Shelf — Phase W, batch one.
    write_loop("drizzle", make_drizzle())
    write_loop("wind", make_wind())
    write_loop("creek", make_creek())
    write_loop("library", make_library())
    write_loop("snowhush", make_snowhush())
    write_loop("temple", make_temple())
    # The Second Shelf — batch two.
    write_loop("storm", make_storm())
    write_loop("crickets", make_crickets())
    write_loop("cicadas", make_cicadas())
    write_loop("nighttrain", make_nighttrain())
    write_loop("raintent", make_raintent())
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
    print("Icon:")
    make_icon()
