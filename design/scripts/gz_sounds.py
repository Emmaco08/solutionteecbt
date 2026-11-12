"""Game Zone sounds (D-157): every effect and music loop is synthesised here, so they are fully ours (no licences).
usage: python3 design/scripts/gz_sounds.py   ->  apps/mobile/assets/sounds/*.ogg  (needs numpy and ffmpeg with libvorbis)
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "apps", "mobile", "assets", "sounds")
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def hz(note):
    """'A4' style note name to Hz."""
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    n, o = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((names[n] + (o - 4) * 12) / 12)


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, hold=0.0):
    a_n, d_n, h_n, r_n = int(a * SR), int(d * SR), int(hold * SR), int(r * SR)
    e = np.concatenate([np.linspace(0, 1, max(a_n, 1)), np.linspace(1, s, max(d_n, 1)), np.full(h_n, s), np.linspace(s, 0, max(r_n, 1))])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):  # one-pole; fine for short sounds
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def lp_fast(x, cutoff):
    """One-pole low-pass for long signals (scipy-free, block recursion via cumulative weights)."""
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    block = 2048
    pw = a ** np.arange(1, block + 1)
    for s in range(0, len(x), block):
        xb = x[s : s + block] * (1 - a)
        n = len(xb)
        # y[k] = sum_{j<=k} a^(k-j) xb[j] + a^(k+1) acc
        w = a ** np.arange(n)
        conv = np.convolve(xb, w)[:n]
        y[s : s + n] = conv + pw[:n] * acc
        acc = y[s + n - 1]
    return y


def highpass(x, cutoff):
    return x - lp_fast(x, cutoff)


def comb(x, delay_s, g):
    d = int(delay_s * SR)
    y = x.copy()
    for k in range(d, len(y), d):
        y[k : k + d] += g * y[k - d : k][: len(y[k : k + d])]
    return y


def reverb(x, mix=0.18, size=1.0):
    wet = sum(comb(x, dly * size, g) for dly, g in ((0.0297, 0.77), (0.0371, 0.74), (0.0411, 0.72), (0.0437, 0.7))) / 4
    wet = lp_fast(wet, 5000)
    return x * (1 - mix) + wet * mix


def norm(x, peak=0.89):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def soft(x, drive=1.2):
    return np.tanh(x * drive) / np.tanh(drive)


# ---------------------------------------------------------------- instruments


def bell(f, d=0.6, bright=1.0):
    tt = t(d)
    parts = [(1, 1.0, 3.5), (2.0, 0.45 * bright, 6), (3.01, 0.22 * bright, 9), (4.2, 0.12 * bright, 13), (5.43, 0.06 * bright, 18)]
    x = sum(a * np.sin(2 * np.pi * f * m * tt) * np.exp(-k * tt) for m, a, k in parts)
    return x * env(len(tt), 0.002, d, 0.0, 0.01)


def kalimba(f, d=0.45):
    tt = t(d)
    x = np.sin(2 * np.pi * f * tt) * np.exp(-7 * tt) + 0.35 * np.sin(2 * np.pi * f * 5.95 * tt) * np.exp(-28 * tt)
    x += 0.15 * np.sin(2 * np.pi * f * 2 * tt) * np.exp(-12 * tt)
    click = rng.standard_normal(len(tt)) * np.exp(-tt * 900) * 0.15
    return (x + click) * env(len(tt), 0.001, d, 0.0, 0.01)


def marimba(f, d=0.4):
    tt = t(d)
    x = np.sin(2 * np.pi * f * tt) * np.exp(-9 * tt) + 0.25 * np.sin(2 * np.pi * f * 4 * tt) * np.exp(-30 * tt)
    return x * env(len(tt), 0.002, d, 0.0, 0.01)


def bass(f, d=0.3, grit=1.6):
    tt = t(d)
    x = np.sin(2 * np.pi * f * tt) + 0.35 * np.sin(2 * np.pi * 2 * f * tt) + 0.12 * np.sin(2 * np.pi * 3 * f * tt)
    return soft(x * env(len(tt), 0.004, 0.08, 0.7, 0.06, hold=max(0, d - 0.15)), grit) * 0.9


def saw(f, tt):
    return 2 * ((f * tt) % 1.0) - 1


def square(f, tt, duty=0.5):
    return np.where((f * tt) % 1.0 < duty, 1.0, -1.0)


def lead(f, d=0.2, wave="square"):
    tt = t(d)
    x = square(f, tt, 0.35) if wave == "square" else saw(f, tt)
    x = lowpass(x * 0.6, 1700)
    return x * env(len(tt), 0.004, 0.06, 0.6, 0.05, hold=max(0, d - 0.12))


def pad(freqs, d):
    tt = t(d)
    x = sum(saw(f * dt, tt) for f in freqs for dt in (0.997, 1.003)) / (2 * len(freqs))
    x = lp_fast(x, 1400)
    return x * env(len(tt), 0.3, 0.2, 0.8, 0.4, hold=max(0, d - 0.9))


def kick(d=0.35):
    tt = t(d)
    f = 45 + 110 * np.exp(-tt * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) * np.exp(-tt * 7) + rng.standard_normal(len(tt)) * np.exp(-tt * 300) * 0.25
    return soft(x, 1.4)


def snare(d=0.2):
    tt = t(d)
    noise = highpass(rng.standard_normal(len(tt)), 1200) * np.exp(-tt * 22)
    tone = np.sin(2 * np.pi * 190 * tt) * np.exp(-tt * 30)
    return (noise * 0.8 + tone * 0.5)


def clap(d=0.22):
    tt = t(d)
    n = highpass(rng.standard_normal(len(tt)), 900)
    e = sum(np.exp(-np.clip(tt - o, 0, None) * 60) * (tt >= o) for o in (0, 0.011, 0.022)) * np.exp(-tt * 9)
    return n * e * 0.8


def hat(d=0.05, open_=False):
    tt = t(0.25 if open_ else d)
    n = highpass(highpass(rng.standard_normal(len(tt)), 6000), 6000)
    return n * np.exp(-tt * (12 if open_ else 70)) * 0.5


def shaker(d=0.07):
    tt = t(d)
    n = highpass(rng.standard_normal(len(tt)), 4000)
    return n * np.sin(np.pi * np.clip(tt / d, 0, 1)) * 0.25


def conga(f=210, d=0.25):
    tt = t(d)
    ff = f * (1 + 0.25 * np.exp(-tt * 40))
    return np.sin(2 * np.pi * np.cumsum(ff) / SR) * np.exp(-tt * 14) * 0.7


def rim(d=0.06):
    tt = t(d)
    return (np.sin(2 * np.pi * 1700 * tt) * 0.6 + highpass(rng.standard_normal(len(tt)), 2000) * 0.4) * np.exp(-tt * 80)


def place(buf, x, at, gain=1.0):
    i = int(at * SR)
    if i >= len(buf):
        return
    n = min(len(x), len(buf) - i)
    buf[i : i + n] += x[:n] * gain


# ---------------------------------------------------------------- music loops


def loop_hub():
    """Bright Afro-pop groove, 112 BPM, A minor (Am F C G), 8 bars: hub, matchmaking and lobbies."""
    bpm = 112
    beat = 60 / bpm
    bars = 8
    total = bars * 4 * beat
    buf = np.zeros(int(total * SR) + SR * 2)
    chords = [("A", ["A3", "C4", "E4"], "A2"), ("F", ["F3", "A3", "C4"], "F2"), ("C", ["C4", "E4", "G4"], "C2"), ("G", ["G3", "B3", "D4"], "G2")]
    for bar in range(bars):
        name, tones, root = chords[bar % 4]
        b0 = bar * 4 * beat
        # Drums: afrobeats-style kick, rim on 2 and 4, hats, shaker 16ths, congas.
        for k in (0, 1.5, 2.5):
            place(buf, kick(), b0 + k * beat, 0.9)
        for k in (1, 3):
            place(buf, rim(), b0 + k * beat, 0.55)
            place(buf, clap(), b0 + k * beat, 0.25)
        for k in range(8):
            place(buf, hat(), b0 + k * beat / 2 + (0.02 if k % 2 else 0), 0.14 if k % 2 else 0.08)
        for k in range(16):
            place(buf, shaker(), b0 + k * beat / 4, 0.2 if k % 4 == 2 else 0.11)
        for k, f in ((0.75, 260), (1.75, 210), (2.25, 260), (3.5, 190)):
            place(buf, conga(f), b0 + k * beat, 0.35)
        # Bass: syncopated root and fifth.
        rf = hz(root)
        for k, mul, dur in ((0, 1, 0.45), (0.75, 1, 0.2), (1.5, 1.5, 0.3), (2.5, 1, 0.3), (3.25, 2, 0.2), (3.5, 1.5, 0.3)):
            place(buf, bass(rf * mul, dur), b0 + k * beat, 0.75)
        # Pad.
        place(buf, pad([hz(n) for n in tones], 4 * beat), b0, 0.18)
        # Kalimba hook: chord tones in a catchy 16th pattern, the second half answers the first.
        seq = [0, 2, 1, 2, 0, 2, 1, 2] if bar < 4 else [2, 1, 0, 1, 2, 1, 0, 2]
        for i, s in enumerate(seq):
            f = hz(tones[s]) * 2
            at = b0 + i * beat / 2 + (beat / 4 if i in (3, 7) else 0)
            place(buf, kalimba(f), at, 0.32 if i % 2 == 0 else 0.22)
        if bar % 2 == 1:
            place(buf, marimba(hz(tones[2]) * 2), b0 + 3.75 * beat, 0.25)
    buf = reverb(buf, 0.16)
    # Fold the tail back to the start so the loop is seamless.
    n = int(total * SR)
    out = buf[:n].copy()
    out[: len(buf) - n] += buf[n:]
    return norm(soft(lp_fast(out, 7000), 1.1), 0.7)


def loop_battle():
    """Driving battle track, 128 BPM, E minor (Em C G D), 8 bars: in-game."""
    bpm = 128
    beat = 60 / bpm
    bars = 8
    total = bars * 4 * beat
    buf = np.zeros(int(total * SR) + SR * 2)
    chords = [(["E4", "G4", "B4"], "E2"), (["C4", "E4", "G4"], "C2"), (["G4", "B4", "D5"], "G2"), (["D4", "F#4", "A4"], "D2")]
    for bar in range(bars):
        tones, root = chords[bar % 4]
        b0 = bar * 4 * beat
        for k in range(4):
            place(buf, kick(0.3), b0 + k * beat, 0.95)
            place(buf, hat(open_=True), b0 + k * beat + beat / 2, 0.1)
        for k in (1, 3):
            place(buf, clap(), b0 + k * beat, 0.42)
            place(buf, snare(), b0 + k * beat, 0.3)
        for k in range(16):
            place(buf, hat(), b0 + k * beat / 4, 0.07 if k % 2 else 0.04)
        rf = hz(root)
        for k in range(8):
            place(buf, bass(rf * (2 if k % 4 == 3 else 1), 0.18, 2.2), b0 + k * beat / 2, 0.7)
        place(buf, pad([hz(n) for n in tones], 4 * beat), b0, 0.14)
        arp = [0, 1, 2, 1] * 4
        for i, s in enumerate(arp):
            up = 2 if (i // 4) % 2 else 1
            place(buf, lead(hz(tones[s]) * up, 0.12), b0 + i * beat / 4, 0.11)
        if bar in (3, 7):
            for i, f in enumerate([hz(tones[2]) * 2, hz(tones[1]) * 2, hz(tones[0]) * 2]):
                place(buf, bell(f, 0.5), b0 + (3 + i / 3) * beat, 0.25)
    buf = reverb(buf, 0.12, 0.8)
    n = int(total * SR)
    out = buf[:n].copy()
    out[: len(buf) - n] += buf[n:]
    return norm(soft(lp_fast(out, 7000), 1.15), 0.7)


# ---------------------------------------------------------------- effects


def sfx():
    s = {}
    tt = t(0.05)
    s["tap"] = norm(np.sin(2 * np.pi * 1400 * tt) * np.exp(-tt * 120) + highpass(rng.standard_normal(len(tt)), 3000) * np.exp(-tt * 300) * 0.3, 0.6)

    x = np.zeros(int(0.7 * SR))
    place(x, bell(hz("E6"), 0.5), 0)
    place(x, bell(hz("B6"), 0.6), 0.08)
    s["correct"] = norm(reverb(x, 0.2), 0.85)

    tt = t(0.35)
    f = 260 - 120 * tt / 0.35
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = lowpass(np.sign(np.sin(ph)) * 0.6 + np.sin(ph * 0.5) * 0.4, 1800) * env(len(tt), 0.005, 0.1, 0.6, 0.12, hold=0.12)
    s["wrong"] = norm(x, 0.7)

    tt = t(0.06)
    s["tick"] = norm(np.sin(2 * np.pi * 900 * tt) * np.exp(-tt * 90) + np.sin(2 * np.pi * 2200 * tt) * np.exp(-tt * 160) * 0.4, 0.55)

    s["count"] = norm(bell(hz("A5"), 0.35, 0.5), 0.7)
    x = np.zeros(int(0.9 * SR))
    for i, n in enumerate(["C6", "E6", "G6"]):
        place(x, bell(hz(n), 0.7, 0.8), 0, 0.6)
    place(x, kick(0.3), 0, 0.5)
    s["go"] = norm(reverb(x, 0.25), 0.9)

    tt = t(0.3)
    n = rng.standard_normal(len(tt))
    sweep = np.sin(np.pi * tt / 0.3)
    s["whoosh"] = norm(lp_fast(highpass(n, 500), 3500) * sweep ** 2 * 0.6, 0.55)

    tt = t(0.09)
    s["flip"] = norm(lp_fast(highpass(rng.standard_normal(len(tt)), 1500), 4500) * np.exp(-tt * 45) * 0.6 + np.sin(2 * np.pi * 600 * tt) * np.exp(-tt * 70) * 0.3, 0.55)

    x = np.zeros(int(0.6 * SR))
    for i, n in enumerate(["G5", "C6", "E6"]):
        place(x, kalimba(hz(n), 0.35), i * 0.06, 0.8)
    s["pair"] = norm(reverb(x, 0.2), 0.8)

    x = np.zeros(int(0.45 * SR))
    place(x, bell(hz("B6"), 0.2, 0.6), 0)
    place(x, bell(hz("E7"), 0.35, 0.6), 0.07)
    s["coin"] = norm(x, 0.75)

    x = np.zeros(int(0.7 * SR))
    place(x, kick(0.4), 0, 0.9)
    place(x, bell(hz("D6"), 0.5), 0.05, 0.5)
    place(x, bell(hz("A6"), 0.5), 0.12, 0.4)
    s["found"] = norm(reverb(x, 0.2), 0.9)

    tt = t(0.45)
    f = 400 * 2 ** (tt / 0.45 * 2)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s["combo"] = norm(lowpass(np.sign(np.sin(ph)) * 0.5, 4000) * env(len(tt), 0.01, 0.2, 0.6, 0.15, hold=0.1), 0.6)

    tt = t(0.12)
    f = 300 + 900 * tt / 0.12
    s["pop"] = norm(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 30), 0.6)

    tt = t(0.6)
    f = 700 * np.exp(-tt * 3)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s["spin"] = norm((np.sin(ph) + 0.4 * np.sign(np.sin(ph * 3))) * np.exp(-tt * 3) * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * tt)), 0.6)

    # Victory fanfare: brassy saw chord stabs and a bell melody.
    x = np.zeros(int(2.6 * SR))
    stabs = [(0.0, ["C4", "E4", "G4"]), (0.18, ["C4", "E4", "G4"]), (0.36, ["C4", "E4", "G4"]), (0.6, ["F4", "A4", "C5"]), (0.9, ["G4", "B4", "D5"]), (1.2, ["C5", "E5", "G5"])]
    for at, ch in stabs:
        d = 1.2 if at == 1.2 else 0.2
        tt = t(d)
        y = sum(saw(hz(n) * dt, tt) for n in ch for dt in (0.996, 1.004)) / 6
        y = lowpass(y, 2400) * env(len(tt), 0.01, 0.08, 0.7, 0.2, hold=max(0, d - 0.3))
        place(x, y, at, 0.6)
    for at, n in ((1.2, "C6"), (1.35, "E6"), (1.5, "G6"), (1.65, "C7")):
        place(x, bell(hz(n), 0.8), at, 0.35)
    place(x, kick(0.4), 1.2, 0.6)
    s["win"] = norm(reverb(x, 0.25), 0.9)

    x = np.zeros(int(1.6 * SR))
    for i, n in enumerate(["G4", "F4", "E4", "C4"]):
        place(x, marimba(hz(n), 0.6), i * 0.22, 0.7)
    s["lose"] = norm(reverb(x, 0.25), 0.7)

    x = np.zeros(int(1.0 * SR))
    for i, n in enumerate(["C5", "E5", "G5", "C6"]):
        place(x, kalimba(hz(n), 0.5), i * 0.08, 0.7)
    s["level"] = norm(reverb(x, 0.2), 0.8)
    return s


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    # Tiny fades at both ends: no click when a sound starts, stops or loops.
    f = int(0.006 * SR)
    x = x.copy()
    if name.startswith("music_"):
        x[:f] *= np.linspace(0, 1, f)
    else:
        x = np.concatenate([np.zeros(int(0.004 * SR)), x])  # a tiny lead-in keeps the attack crisp
    x[-f:] *= np.linspace(1, 0, f)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    q = "3" if name.startswith("music_") else "4"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", q, os.path.join(OUT, f"{name}.ogg")], check=True)
    os.unlink(path)


if __name__ == "__main__":
    for k, v in sfx().items():
        write(k, v)
    write("music_hub", loop_hub())
    write("music_battle", loop_battle())
    for f in sorted(os.listdir(OUT)):
        print(f, os.path.getsize(os.path.join(OUT, f)) // 1024, "KB")
