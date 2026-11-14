"""Music, sound effects and final mix for the SolutionTee CBT intro advert (D-164).

Everything is synthesised here (no samples, no licences): an original Afro-house / amapiano style groove at 120 BPM
arranged to the edit in src/timeline.json, designed sound effects at the picture's hit points, and the Kokoro
voice-over from public/vo. Output: public/audio/mix.wav (48 kHz, -14 LUFS, -1 dBTP) plus stems in out/stems.

    python tools/audio.py            (needs numpy, scipy, soundfile, pedalboard, pyloudnorm)
"""
import json, os
import numpy as np
import soundfile as sf
import pyloudnorm as pyln
from scipy.signal import butter, sosfilt, resample_poly
from pedalboard import (Pedalboard, Reverb, Compressor, Limiter, Chorus, HighpassFilter, LowpassFilter,
                        PeakFilter, LowShelfFilter, HighShelfFilter, Distortion, Delay, Gain)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 48000
TL = json.load(open(os.path.join(ROOT, "src", "timeline.json")))
DUR = TL["duration"]
BPM = TL["bpm"]
BEAT = 60 / BPM
BAR = BEAT * 4
S16 = BEAT / 4
N = int((DUR + 1) * SR)
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- helpers
def T(sec):
    return np.arange(int(sec * SR)) / SR


def bus():
    return np.zeros((2, N), dtype=np.float64)


def place(b, sig, at, gain=1.0, pan=0.0):
    """Add a mono or stereo signal into bus b at time `at` (seconds) with constant-power pan (-1..1)."""
    if sig.ndim == 1:
        a = (pan + 1) * np.pi / 4
        sig = np.stack([sig * np.cos(a), sig * np.sin(a)])
    i = int(at * SR)
    if i >= N or i + sig.shape[1] <= 0:
        return
    s0 = max(0, -i)
    j = min(N, i + sig.shape[1])
    b[:, max(i, 0):j] += sig[:, s0:s0 + j - max(i, 0)] * gain


def filt(x, kind, f, order=2):
    sos = butter(order, f, btype=kind, fs=SR, output="sos")
    return sosfilt(sos, x)


def noise(sec):
    return rng.standard_normal(int(sec * SR))


def fx(x, board):
    x = np.atleast_2d(x).astype(np.float32)
    return board(x, SR).astype(np.float64)


def hz(name):
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    n, o = name[:-1], int(name[-1])
    return 440 * 2 ** ((names[n] + (o + 1) * 12 - 69) / 12)


# ---------------------------------------------------------------- drums & instruments
def kick(v=1.0):
    t = T(0.45)
    f = 44 + 120 * np.exp(-t * 32)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t * 6.5)
    click = filt(noise(0.45), "highpass", 2500) * np.exp(-t * 400) * 0.35
    return np.tanh((body + click) * 1.6) * v * 0.9


def clap(v=1.0):
    t = T(0.35)
    n = filt(noise(0.35), "bandpass", [900, 3200])
    env = np.zeros_like(t)
    for d in (0, 0.011, 0.023):
        env += np.where(t >= d, np.exp(-(t - d) * 180), 0) * (t >= d)
    env += np.where(t >= 0.03, np.exp(-(t - 0.03) * 16), 0) * 0.55
    return n * env * v * 0.55


def shaker(v=1.0):
    t = T(0.09)
    n = filt(noise(0.09), "highpass", 6500)
    env = np.minimum(t / 0.004, 1) * np.exp(-t * 55)
    return n * env * v * 0.16


def hat(v=1.0, open_=False):
    t = T(0.35 if open_ else 0.08)
    sq = sum(np.sign(np.sin(2 * np.pi * f * t)) for f in (205.3, 304.4, 369.6, 522.7, 540.0, 800.0))
    x = filt(sq + noise(len(t) / SR) * 0.6, "highpass", 7500)
    return x * np.exp(-t * (9 if open_ else 60)) * v * 0.06


def logdrum(f, v=1.0):
    """Amapiano-style log drum: pitch-drop sine, a knock and soft saturation."""
    t = T(0.55)
    fr = f * (1 + 0.9 * np.exp(-t * 60))
    ph = 2 * np.pi * np.cumsum(fr) / SR
    x = np.sin(ph) + 0.25 * np.sin(2.01 * ph) * np.exp(-t * 14)
    x = x * np.exp(-t * 5.2) * np.minimum(t / 0.002, 1)
    knock = filt(noise(0.55), "bandpass", [300, 1400]) * np.exp(-t * 250) * 0.3
    return filt(np.tanh((x + knock) * 2.2), "lowpass", 2200) * v * 0.55


def sub(f, dur, v=1.0):
    t = T(dur)
    env = np.minimum(t / 0.008, 1) * np.minimum((dur - t) / 0.05, 1).clip(0, 1)
    return (np.sin(2 * np.pi * f * t) + 0.12 * np.sin(4 * np.pi * f * t)) * env * v * 0.45


def epiano(freqs, dur, v=1.0):
    """FM electric piano: bell-like attack, warm body."""
    t = T(dur + 0.6)
    out = np.zeros_like(t)
    for f in freqs:
        idx = 2.0 * np.exp(-t * 7) + 0.25
        x = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * t))
        tine = np.sin(2 * np.pi * f * 7.02 * t) * np.exp(-t * 40) * 0.12
        out += (x + tine)
    rel = np.where(t > dur, np.exp(-(t - dur) * 9), 1)
    return out * np.exp(-t * 2.4) * rel * np.minimum(t / 0.003, 1) * v * 0.09


def pad(freqs, dur, v=1.0, bright=1800):
    t = T(dur + 1.2)
    out = np.zeros_like(t)
    for f in freqs:
        for d in (-0.11, -0.04, 0.0, 0.05, 0.12):
            ff = f * 2 ** (d / 12)
            ph = rng.random()
            out += 2 * ((ff * t + ph) % 1) - 1
    env = np.minimum(t / 0.6, 1) * np.where(t > dur, np.exp(-(t - dur) * 3), 1)
    out = filt(out, "lowpass", bright, 2)
    return out * env * v * 0.012


def marimba(f, v=1.0):
    t = T(0.9)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 6) + 0.35 * np.sin(2 * np.pi * f * 3.98 * t) * np.exp(-t * 22) \
        + 0.12 * np.sin(2 * np.pi * f * 9.9 * t) * np.exp(-t * 60)
    return x * np.minimum(t / 0.0015, 1) * v * 0.22


def perc_tom(f, v=1.0):
    t = T(0.3)
    fr = f * (1 + 0.5 * np.exp(-t * 40))
    return np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t * 14) * v * 0.3


def snare(v=1.0):
    t = T(0.25)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30)
    n = filt(noise(0.25), "bandpass", [1500, 8000]) * np.exp(-t * 22)
    return (tone * 0.5 + n) * v * 0.35


# ---------------------------------------------------------------- arrangement
PROG = [  # (bass root, chord voicing) — F, G, Em, Am in C major
    (hz("F2"), [hz("F3"), hz("A3"), hz("C4"), hz("E4")]),
    (hz("G2"), [hz("G3"), hz("B3"), hz("D4"), hz("A4")]),
    (hz("E2"), [hz("E3"), hz("G3"), hz("B3"), hz("D4")]),
    (hz("A2"), [hz("A3"), hz("C4"), hz("E4"), hz("B4")]),
]
HOOK = [
    [(0, "A4"), (3, "C5"), (6, "A4"), (8, "G4"), (10, "A4"), (12, "C5"), (14, "D5")],
    [(0, "B4"), (3, "D5"), (6, "B4"), (8, "A4"), (10, "G4"), (12, "A4")],
    [(0, "G4"), (3, "B4"), (6, "G4"), (8, "E4"), (10, "G4"), (12, "B4"), (14, "D5")],
    [(0, "C5"), (3, "E5"), (6, "C5"), (8, "B4"), (10, "A4"), (12, "E4")],
]
SWING = 0.016


def pos(bar, s16):
    return bar * BAR + s16 * S16 + (SWING if s16 % 2 == 1 else 0)


def section(bar):
    """Which part of the song a bar (2 s) belongs to."""
    if bar <= 1: return "intro"
    if bar == 2: return "build"
    if 3 <= bar <= 11: return "A"
    if 12 <= bar <= 18: return "B"
    if 19 <= bar <= 21: return "C"
    if 22 <= bar <= 23: return "build2"
    if 24 <= bar <= 26: return "final"
    if bar == 27: return "tail"
    return "end"


def music():
    drums, bass, keys, pads, lead = bus(), bus(), bus(), bus(), bus()
    for bar in range(30):
        sec = section(bar)
        root, chord = PROG[(bar - 3) % 4] if bar >= 3 else (hz("A1") * 2, [hz("A3"), hz("C4"), hz("E4")])
        t0 = bar * BAR
        if sec == "intro":
            place(pads, pad([hz("A2"), hz("E3"), hz("A3"), hz("C4")], BAR, 0.9, 700), t0)
            place(bass, sub(hz("A1"), BAR, 0.5), t0)
        if sec == "build":
            place(pads, pad([hz("F3"), hz("A3"), hz("C4"), hz("E4")], BAR - 0.25, 1.0, 2600), t0)
            # snare roll that speeds up into the drop, stops at 5.75 s
            hits = [i * 0.25 for i in range(4)] + [1 + i * 0.125 for i in range(4)] + [1.5 + i * 0.0625 for i in range(4)]
            for k, h in enumerate(hits):
                place(drums, snare(0.35 + 0.6 * k / len(hits)), t0 + h, pan=(-0.3 if k % 2 else 0.3))
        if sec in ("A", "B", "final", "build2", "C"):
            full = sec != "C"
            for s in range(16):
                if full and s % 4 == 0:
                    place(drums, kick(1.0 if s == 0 else 0.92), pos(bar, s))
                if full and s in (4, 12):
                    place(drums, clap(1.0), pos(bar, s), pan=0.05)
                sv = [0.9, 0.35, 0.6, 0.35][s % 4] * (0.8 if sec == "C" else 1)
                place(drums, shaker(sv), pos(bar, s), pan=0.35)
                if s in (2, 6, 10, 14) and sec != "C":
                    place(drums, hat(0.8, open_=(s == 14)), pos(bar, s), pan=-0.25)
            # log drum + sub
            if sec != "build2":
                for s, mul, v in [(0, 1, 1), (3, 1, 0.8), (6, 1.5, 0.75), (10, 1, 0.9), (11, 2, 0.6), (14, 1.5, 0.7)]:
                    place(bass, logdrum(root * mul, v), pos(bar, s))
                place(bass, sub(root / 2, BEAT * 1.8, 0.8), pos(bar, 0))
                place(bass, sub(root / 2, BEAT * 1.6, 0.6), pos(bar, 8))
            else:
                for s in (0, 4, 8, 12):
                    place(bass, sub(root / 2, BEAT * 0.9, 0.7), pos(bar, s))
            # electric piano stabs
            for s in (2, 6, 10, 13):
                place(keys, epiano(chord, S16 * 1.6, 0.9 if sec != "C" else 1.1), pos(bar, s), pan=0.15)
            place(pads, pad(chord, BAR, 0.55 if sec != "C" else 0.9, 1500 if sec != "C" else 2400), t0)
            if sec in ("B", "final"):
                for s, n in HOOK[(bar - 3) % 4]:
                    place(lead, marimba(hz(n), 0.9), pos(bar, s), pan=-0.2)
                    place(lead, marimba(hz(n) * 2, 0.25), pos(bar, s) + 0.375, pan=0.4)  # echo an octave up
                for s in (3, 7, 10):
                    place(drums, perc_tom(320 if s != 10 else 240, 0.7), pos(bar, s), pan=0.5)
            if sec == "build2":
                n = 16 if bar == 22 else 32
                for k in range(n):
                    tt = t0 + k * BAR / n
                    if tt < 47.75:
                        place(drums, snare(0.25 + 0.5 * (bar - 22 + k / n) / 2), tt, pan=(-0.2 if k % 2 else 0.2))
        if sec == "tail":
            place(drums, kick(1.0), t0)
            place(pads, pad([hz("F2"), hz("C3"), hz("A3"), hz("C4"), hz("E4"), hz("G4")], 3.5, 1.4, 2200), t0)
            place(keys, epiano([hz("F3"), hz("A3"), hz("C4"), hz("E4"), hz("G4")], 2.5, 1.2), t0)
            place(bass, sub(hz("F1"), 3.0, 0.9), t0)
    # drum fills before big moments
    for at in (23.5, 33.5):
        for k in range(4):
            place(drums, perc_tom(220 - k * 30, 0.9), at + k * 0.125, pan=-0.4 + k * 0.25)
    # silence before the drops
    for a, b in ((5.75, 6.0), (47.75, 48.0)):
        for x in (drums, bass, keys, pads, lead):
            x[:, int(a * SR):int(b * SR)] *= 0.0
    # FX per group
    drums = fx(drums, Pedalboard([Compressor(threshold_db=-14, ratio=3, attack_ms=3, release_ms=80)]))
    keys = fx(keys, Pedalboard([Chorus(rate_hz=0.6, depth=0.25, mix=0.4), Delay(delay_seconds=BEAT * 0.75, feedback=0.25, mix=0.18),
                                Reverb(room_size=0.55, wet_level=0.25, dry_level=0.8)]))
    pads = fx(pads, Pedalboard([Chorus(rate_hz=0.3, depth=0.4, mix=0.5), Reverb(room_size=0.85, wet_level=0.4, dry_level=0.7)]))
    lead = fx(lead, Pedalboard([Delay(delay_seconds=BEAT * 0.5, feedback=0.3, mix=0.2), Reverb(room_size=0.6, wet_level=0.3, dry_level=0.8)]))
    bass = fx(bass, Pedalboard([LowpassFilter(cutoff_frequency_hz=3000)]))
    # sidechain pump on pads/keys from the kick grid
    pump = np.ones(N)
    for bar in range(30):
        if section(bar) in ("A", "B", "final", "build2"):
            for s in (0, 4, 8, 12):
                i = int(pos(bar, s) * SR)
                L = int(0.22 * SR)
                if i + L < N:
                    pump[i:i + L] = np.minimum(pump[i:i + L], 1 - 0.55 * np.exp(-np.arange(L) / SR * 14))
    pads *= pump
    keys *= 0.6 + 0.4 * pump
    m = drums * 0.9 + bass * 1.0 + keys * 0.8 + pads * 0.9 + lead * 0.75
    # "No data?" — the music goes muffled like a lost signal, then "No wahala" brings it back
    m = automate_lowpass(m, [(0, 20000), (20.35, 20000), (20.6, 450), (21.15, 450), (21.25, 20000)])
    return m


def automate_lowpass(x, points):
    """Piecewise lowpass automation by processing short blocks (cheap, good enough for a filter dip)."""
    out = x.copy()
    times = [p[0] for p in points]
    vals = [np.log(p[1]) for p in points]
    blk = int(0.02 * SR)
    for i in range(0, N, blk):
        tsec = i / SR
        f = float(np.exp(np.interp(tsec, times, vals)))
        if f < 19000:
            j = min(N, i + blk)
            pad_ = int(0.05 * SR)
            a = max(0, i - pad_)
            seg = filt(x[:, a:j], "lowpass", f, 4)
            out[:, i:j] = seg[:, i - a:]
    return out


# ---------------------------------------------------------------- sound effects
def tick(hi=True):
    t = T(0.06)
    f = 3200 if hi else 2400
    x = filt(noise(0.06), "bandpass", [f * 0.8, f * 1.2]) * np.exp(-t * 160) + np.sin(2 * np.pi * f * t) * np.exp(-t * 120) * 0.4
    return x * 0.35


def impact(big=1.0):
    t = T(2.5)
    f = 30 + 70 * np.exp(-t * 9)
    boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.2) * 0.9
    crack = filt(noise(2.5), "highpass", 1200) * np.exp(-t * 30) * 0.5
    body = filt(noise(2.5), "lowpass", 400) * np.exp(-t * 6) * 0.6
    x = np.tanh((boom + crack + body) * 1.4) * big
    return fx(x, Pedalboard([Reverb(room_size=0.9, wet_level=0.35, dry_level=0.9, width=1.0)]))


def slam(f=110):
    """Logo slam: a punchy hit with a metallic ring."""
    t = T(1.4)
    boom = np.sin(2 * np.pi * np.cumsum(40 + 90 * np.exp(-t * 25)) / SR) * np.exp(-t * 5)
    ring = sum(np.sin(2 * np.pi * f * k * t) * np.exp(-t * (4 + k)) for k in (4.0, 5.43, 6.8, 8.21)) * 0.06
    snap = filt(noise(1.4), "bandpass", [1500, 9000]) * np.exp(-t * 70) * 0.5
    x = np.tanh((boom + ring + snap) * 1.5)
    return fx(x, Pedalboard([Reverb(room_size=0.7, wet_level=0.3, dry_level=0.9)]))


def whoosh(dur=0.6, up=True, v=1.0):
    t = T(dur)
    n = noise(dur)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2
    out = np.zeros_like(n)
    blk = int(0.01 * SR)
    for i in range(0, len(n), blk):
        p = i / len(n)
        fc = 300 * (16 ** (p if up else 1 - p))
        seg = filt(n[max(0, i - blk):i + blk], "bandpass", [fc * 0.6, min(fc * 1.8, 20000)])
        out[i:i + blk] = seg[-min(blk, len(n) - i):] if i else seg[:blk]
    x = out * env * v * 0.7
    pan = np.linspace(-0.7, 0.7, len(x)) if up else np.linspace(0.7, -0.7, len(x))
    a = (pan + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)])


def riser(dur, v=1.0):
    t = T(dur)
    p = t / dur
    n = noise(dur)
    hp = np.zeros_like(n)
    blk = int(0.02 * SR)
    for i in range(0, len(n), blk):
        fc = 200 * (40 ** (i / len(n)))
        hp[i:i + blk] = filt(n[i:i + blk + 2000], "highpass", fc)[:len(n[i:i + blk])]
    tone = sum(np.sin(2 * np.pi * np.cumsum(f0 * (1 + 3 * p ** 2)) / SR) for f0 in (110, 165, 220)) * 0.15
    x = (hp * 0.5 + tone) * (p ** 1.6) * v
    return fx(x, Pedalboard([Reverb(room_size=0.6, wet_level=0.3)]))


def glitch(dur=0.35):
    t = T(dur)
    x = np.zeros_like(t)
    seg = int(0.025 * SR)
    for i in range(0, len(t), seg):
        f = rng.choice([180, 360, 720, 1440, 95])
        x[i:i + seg] = np.sign(np.sin(2 * np.pi * f * t[i:i + seg])) * rng.choice([0, 0.5, 1, 1])
    x = x * 0.18 + filt(noise(dur), "highpass", 3000) * 0.08 * (rng.random(len(t)) > 0.6)
    return fx(x, Pedalboard([Distortion(drive_db=12), Gain(-10)]))


def tap(f=1500):
    t = T(0.08)
    return (np.sin(2 * np.pi * f * t) * np.exp(-t * 70) + filt(noise(0.08), "highpass", 4000) * np.exp(-t * 400) * 0.4) * 0.35


def pop(f=600):
    t = T(0.15)
    fr = f * (1 + 1.5 * np.exp(-t * 60))
    return np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t * 30) * 0.45


def chime(notes=("E6", "B6"), gap=0.07, v=1.0):
    out = np.zeros(int(1.6 * SR))
    for k, n in enumerate(notes):
        f = hz(n)
        t = T(1.6 - k * gap)
        x = (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 6)) * np.exp(-t * 3.5)
        i = int(k * gap * SR)
        out[i:i + len(x)] += x[:len(out) - i]
    return fx(out * 0.18 * v, Pedalboard([Reverb(room_size=0.6, wet_level=0.35)]))


def coin(f=None):
    f = f or rng.uniform(2000, 3200)
    t = T(0.35)
    x = (np.sin(2 * np.pi * f * t) + 0.6 * np.sin(2 * np.pi * f * 1.5 * t) + 0.3 * np.sin(2 * np.pi * f * 2.9 * t)) * np.exp(-t * 12)
    clink = filt(noise(0.35), "highpass", 5000) * np.exp(-t * 300) * 0.5
    return (x * 0.12 + clink * 0.2)


def shutter():
    t = T(0.25)
    c1 = filt(noise(0.25), "bandpass", [1000, 6000]) * np.exp(-t * 120)
    c2 = np.zeros_like(t)
    i = int(0.075 * SR)
    c2[i:] = (filt(noise(0.25), "bandpass", [800, 5000]) * np.exp(-t * 90))[: len(t) - i]
    return (c1 + c2 * 0.8) * 0.5


def downbleep():
    t = T(0.5)
    f = 900 * np.exp(-t * 3)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 4) * 0.25


def sparkle(dur=1.2, v=1.0):
    out = np.zeros(int(dur * SR))
    for _ in range(18):
        f = rng.uniform(3000, 7000)
        st = rng.uniform(0, dur - 0.3)
        t = T(0.3)
        x = np.sin(2 * np.pi * f * t) * np.exp(-t * 20) * rng.uniform(0.3, 1)
        i = int(st * SR)
        out[i:i + len(x)] += x
    return fx(out * 0.06 * v, Pedalboard([Reverb(room_size=0.7, wet_level=0.5)]))


def scramble(dur):
    out = np.zeros(int(dur * SR))
    k = 0
    while k * 0.055 < dur - 0.05:
        x = tick(k % 2 == 0) * 0.35
        i = int(k * 0.055 * SR)
        out[i:i + len(x)] += x[:len(out) - i]
        k += 1
    return out


def countup(dur, f0=600, f1=1800):
    out = np.zeros(int(dur * SR) + SR // 10)
    n = int(dur / 0.045)
    for k in range(n):
        f = f0 * (f1 / f0) ** (k / max(n - 1, 1))
        t = T(0.04)
        x = np.sin(2 * np.pi * f * t) * np.exp(-t * 90) * 0.18
        i = int(k * 0.045 * SR)
        out[i:i + len(x)] += x
    return out


def arp_up(base="C5"):
    out = np.zeros(int(1.0 * SR))
    for k, st in enumerate([0, 4, 7, 12, 16]):
        f = hz(base) * 2 ** (st / 12)
        t = T(0.4)
        x = np.sin(2 * np.pi * f * t) * np.exp(-t * 9) * 0.16
        i = int(k * 0.08 * SR)
        out[i:i + len(x)] += x
    return fx(out, Pedalboard([Reverb(room_size=0.5, wet_level=0.3)]))


def fire():
    t = T(0.9)
    n = filt(noise(0.9), "bandpass", [200, 2500])
    crack = (rng.random(len(t)) > 0.9985) * rng.uniform(0.5, 1, len(t))
    crack = filt(crack, "highpass", 2000) * 3
    env = np.sin(np.pi * t / 0.9) ** 0.7
    return (n * 0.25 + crack * 0.2) * env


def sfx():
    b = bus()
    w = lambda name, at: [w for w in next(l for l in TL["vo"] if l["id"] == name)["words"]]
    # cold open: clock ticks + a scramble of numbers
    for k in range(4):
        place(b, tick(k % 2 == 0), k * 0.5, 0.8, pan=(-0.2 if k % 2 else 0.2))
    place(b, scramble(1.3), 0.6, 0.5)
    # logos
    for at, f in ((2.0, 98), (2.75, 110), (3.5, 123)):
        place(b, slam(f), at - 0.04, 0.5)
    # ready
    place(b, glitch(0.3), 4.4, 0.8)
    place(b, glitch(0.2), 5.1, 0.6)
    place(b, riser(1.75, 0.8), 4.0, 0.9)
    # drop + brand
    place(b, impact(1.0), 6.0, 1.0)
    place(b, sparkle(1.5), 6.3, 0.9)
    place(b, whoosh(0.7, True), 7.3, 0.8)
    # cbt
    place(b, whoosh(0.5, False), 7.9, 0.6)
    place(b, tap(), 9.5, 0.9)
    for k in range(6):
        place(b, tick(k % 2 == 0) * 0.5, 10.0 + k * 0.5, 0.6)
    place(b, pop(700), 11.0, 0.8)
    # result
    place(b, whoosh(0.45, True), 11.85, 0.8)
    place(b, countup(1.2), 12.62, 0.9)
    place(b, chime(("C6", "E6", "G6", "C7"), 0.06, 1.2), 13.85, 1.0)
    for k in range(10):
        place(b, pop(rng.uniform(500, 1200)) * 0.5, 13.85 + rng.uniform(0, 0.5), 0.6, pan=rng.uniform(-0.8, 0.8))
    # ai tutor
    place(b, whoosh(0.5, False), 15.9, 0.7)
    place(b, shutter(), 17.17, 1.0)
    place(b, pop(900), 17.5, 0.7)
    for k in range(12):
        place(b, tap(rng.uniform(2500, 3500)) * 0.25, 18.0 + k * 0.08, 0.6)
    for at in (18.5, 19.2, 19.75):
        place(b, pop(800), at, 0.7)
    # offline
    place(b, whoosh(0.5, True), 19.9, 0.7)
    place(b, downbleep(), 20.45, 0.9)
    place(b, chime(("G5", "D6"), 0.06), 21.22, 1.0)
    place(b, countup(1.0, 400, 1200), 22.3, 0.6)
    place(b, chime(("C6", "G6"), 0.05), 23.4, 0.9)
    # games
    place(b, impact(0.8), 24.0, 0.9)
    place(b, whoosh(0.35, True), 23.75, 0.6)
    for at in (25.0, 25.5, 26.0, 26.5, 27.0, 27.5):
        place(b, whoosh(0.22, at * 2 % 2 == 0, 0.6), at - 0.08, 0.6)
    # cash
    place(b, whoosh(0.5, False), 27.85, 0.7)
    place(b, pop(1200), 28.45, 0.6)
    place(b, countup(0.75, 900, 2400), 29.5, 0.7)
    for k in range(70):
        place(b, coin(), 30.1 + rng.uniform(0, 2.6) ** 1.3 / 1.3, 0.55, pan=rng.uniform(-0.9, 0.9))
    place(b, chime(("E6", "A6", "E7"), 0.05, 1.3), 30.9, 1.0)
    # leaderboard
    place(b, whoosh(0.5, True), 33.85, 0.7)
    place(b, arp_up("C5"), 34.6, 1.0)
    place(b, fire(), 35.7, 0.9)
    # classes
    place(b, whoosh(0.5, False), 37.85, 0.7)
    for at in (38.3, 39.56, 40.64):
        place(b, pop(500), at, 0.8)
        place(b, whoosh(0.3, True, 0.5), at - 0.15, 0.5)
    # wall
    place(b, whoosh(1.2, True, 1.0), 43.8, 0.8)
    place(b, riser(1.75, 1.0), 46.0, 1.0)
    # outro
    place(b, impact(1.1), 48.0, 1.0)
    place(b, sparkle(1.8, 1.3), 48.2, 1.0)
    for at in (50.2, 50.8, 51.2):
        place(b, slam(130), at, 0.55)
    # cta
    place(b, whoosh(0.6, False, 0.7), 51.9, 0.6)
    place(b, pop(700), 52.6, 0.6)
    place(b, sparkle(2.0, 0.9), 54.0, 0.7)
    return b


# ---------------------------------------------------------------- voice-over
def voice():
    b = bus()
    chain = Pedalboard([HighpassFilter(cutoff_frequency_hz=85), LowShelfFilter(cutoff_frequency_hz=200, gain_db=1.5),
                        PeakFilter(cutoff_frequency_hz=3200, gain_db=2.5, q=0.9), HighShelfFilter(cutoff_frequency_hz=9000, gain_db=2),
                        Compressor(threshold_db=-22, ratio=3.5, attack_ms=4, release_ms=90), Gain(4),
                        Reverb(room_size=0.18, wet_level=0.06, dry_level=1.0)])
    for l in TL["vo"]:
        a, sr = sf.read(os.path.join(ROOT, "public", "vo", l["id"] + ".wav"))
        a = resample_poly(a, SR, sr)
        a = fx(a, chain)[0]
        place(b, a, l["at"], 1.0)
    return b


def duck(music_bus, vo_bus, depth_db=-9.0):
    env = np.abs(vo_bus).max(axis=0)
    win = int(0.03 * SR)
    env = np.convolve(env, np.ones(win) / win, mode="same")
    on = (env > 0.01).astype(float)
    # attack 40 ms, release 350 ms
    g = np.zeros(N)
    a, r = np.exp(-1 / (0.04 * SR)), np.exp(-1 / (0.35 * SR))
    s = 0.0
    for i in range(0, N, 48):  # control rate 1 kHz
        x = on[i]
        s = (a if x > s else r) ** 48 * s + (1 - (a if x > s else r) ** 48) * x
        g[i:i + 48] = s
    gain = 10 ** (depth_db * g / 20)
    return music_bus * gain


def main():
    os.makedirs(os.path.join(ROOT, "out", "stems"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "public", "audio"), exist_ok=True)
    m = music()
    print("music done")
    s = sfx()
    print("sfx done")
    v = voice()
    print("voice done")
    m = duck(m, v)
    mix = m * 0.32 + s * 0.5 + v * 1.0
    mix = mix[:, : int(DUR * SR)]
    fade = int(2.5 * SR)
    mix[:, -fade:] *= np.linspace(1, 0, fade) ** 1.5
    # JUCE's limiter (pedalboard) adds make-up gain so the threshold maps to 0 dBFS; Gain() after it sets the ceiling.
    # Phones first: less deep sub, a little more air.
    mix = fx(mix, Pedalboard([HighpassFilter(cutoff_frequency_hz=32), LowShelfFilter(cutoff_frequency_hz=110, gain_db=-4.0),
                              PeakFilter(cutoff_frequency_hz=2500, gain_db=1.0, q=0.7), HighShelfFilter(cutoff_frequency_hz=6500, gain_db=2.5),
                              Compressor(threshold_db=-12, ratio=2, attack_ms=10, release_ms=120)]))
    meter = pyln.Meter(SR)
    lufs = meter.integrated_loudness(mix.T)
    mix = mix * 10 ** ((-12.5 - lufs) / 20)
    mix = fx(mix, Pedalboard([Limiter(threshold_db=-1.0, release_ms=60)]))
    lufs = meter.integrated_loudness(mix.T)
    mix = mix * 10 ** ((-14 - lufs) / 20)  # a plain gain: lands on -14 LUFS, peaks fall with it
    print("loudness", round(meter.integrated_loudness(mix.T), 2), "LUFS, peak", round(20 * np.log10(np.abs(mix).max()), 2), "dBFS")
    sf.write(os.path.join(ROOT, "public", "audio", "mix.wav"), mix.T, SR, subtype="PCM_24")
    for name, x in (("music", m), ("sfx", s), ("voice", v)):
        sf.write(os.path.join(ROOT, "out", "stems", name + ".wav"), (x[:, : int(DUR * SR)] * 0.5).T, SR, subtype="PCM_24")


if __name__ == "__main__":
    main()
