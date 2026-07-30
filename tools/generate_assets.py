"""Generate Pawmodoro assets: app icon (PNG) + synthesized ambience loops (WAV).

All audio is procedurally synthesized here, so it is original content with no
licensing concerns. Swap for professionally recorded loops later if desired.
"""
import os
import wave

import numpy as np
from PIL import Image, ImageDraw

SR = 22050
RES = "/home/user/iosPomodoro/Pawmodoro/Resources"
ICONSET = "/home/user/iosPomodoro/Pawmodoro/Assets.xcassets/AppIcon.appiconset"

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


if __name__ == "__main__":
    print("Ambience loops:")
    write_wav("rain.wav", make_rain())
    write_wav("purr.wav", make_purr())
    write_wav("fireplace.wav", make_fireplace())
    write_wav("chime.wav", make_chime())
    print("Icon:")
    make_icon()
