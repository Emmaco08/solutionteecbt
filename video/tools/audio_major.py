"""Music, sound effects and mix for the two major adverts (D-183). No voice: every word is on screen.

  struggle  "Shouldn't be a struggle"   33 s  amapiano, 112 BPM: night crickets and the lamp click, a moody groove under
                                            the problems, the full groove when the app appears, a stop-start ending
  oneapp    "One app. Every subject."   34 s  afro-house, 120 BPM: bright keys and typing, a swoosh on every screen, a
                                            dark half-time drop inside the phone, a gold lift to the end card

    .venv/Scripts/python tools/audio_major.py [struggle|oneapp ...]  ->  public/audio/major_<name>.wav  (-14 LUFS)
Everything is synthesised (helpers in tools/audio.py and tools/audio_short.py); no samples, no licences.
"""
import os
import sys

import numpy as np
import pyloudnorm as pyln
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pedalboard_lite  # noqa: E402

pedalboard_lite.use_on_windows()  # the real pedalboard crashes on the owner's Windows laptop (Python 3.14)
from pedalboard import Compressor, HighpassFilter, HighShelfFilter, Limiter, LowpassFilter, LowShelfFilter, Pedalboard, PeakFilter, Reverb  # noqa: E402

import audio as A  # noqa: E402
import audio_short as S  # noqa: E402
from audio import SR, T, filt, fx, hz, noise  # noqa: E402

ROOT = A.ROOT
rng = np.random.default_rng(31)


def setup(dur):
    A.DUR = dur
    A.N = int((dur + 1) * SR)


def B():
    return A.bus()


def put(b, sig, at, g=1.0, pan=0.0):
    A.place(b, sig, at, g, pan)


def master(mix, name, dur):
    mix = mix[:, : int(dur * SR)]
    fade = int(0.9 * SR)
    mix[:, -fade:] *= np.linspace(1, 0, fade) ** 1.6
    mix = fx(mix, Pedalboard([HighpassFilter(cutoff_frequency_hz=30), LowShelfFilter(cutoff_frequency_hz=110, gain_db=-2.0),
                              PeakFilter(cutoff_frequency_hz=2600, gain_db=1.2, q=0.7), HighShelfFilter(cutoff_frequency_hz=7000, gain_db=2.0),
                              Compressor(threshold_db=-14, ratio=2.2, attack_ms=8, release_ms=120)]))
    meter = pyln.Meter(SR)
    mix = mix * 10 ** ((-12.5 - meter.integrated_loudness(mix.T)) / 20)
    mix = fx(mix, Pedalboard([Limiter(threshold_db=-1.2, release_ms=60)]))
    mix = mix * 10 ** ((-14 - meter.integrated_loudness(mix.T)) / 20)
    peak = 20 * np.log10(np.abs(mix).max())
    if peak > -1.0:
        mix = mix * 10 ** ((-1.0 - peak) / 20)
    os.makedirs(os.path.join(ROOT, "public", "audio"), exist_ok=True)
    sf.write(os.path.join(ROOT, "public", "audio", f"major_{name}.wav"), mix.T, SR, subtype="PCM_24")
    print(name, "loudness", round(meter.integrated_loudness(mix.T), 2), "LUFS, peak", round(20 * np.log10(np.abs(mix).max()), 2), "dBFS")


# ------------------------------------------------------------------ small synthesised effects
def crickets(dur, v=1.0):
    """Night crickets: bursts of a high, fast-pulsing tone."""
    t = T(dur)
    x = np.zeros_like(t)
    for k in range(3):
        f = 4300 + k * 380
        pulse = (np.sin(2 * np.pi * (28 + k * 3) * t) > 0.3).astype(float)
        chirp = (np.sin(2 * np.pi * (1.4 + k * 0.3) * t + k) > 0.1).astype(float)
        x += np.sin(2 * np.pi * f * t) * pulse * chirp * (0.5 - k * 0.12)
    x = filt(x, "lowpass", 7000) * np.minimum(t / 0.3, 1)
    return x * 0.08 * v


def click(v=1.0):
    t = T(0.05)
    return filt(noise(0.05), "bandpass", [1500, 6000]) * np.exp(-t * 160) * 0.6 * v


def type_ticks(b, start, n, rate=26, v=0.3):
    for k in range(n):
        put(b, A.tap(2000 + int(rng.integers(-260, 260))), start + k / rate, v)


def groove(b, start, end, beat, prog, level=1.0, full=True, hook=None):
    """Amapiano/afro-house groove from [start] to [end]."""
    bar = beat * 4
    s16 = beat / 4
    bi = 0
    while start + bi * bar < end - 0.05:
        b0 = start + bi * bar
        root, ch = prog[bi % len(prog)]
        for q in range(4):
            tq = b0 + q * beat
            if tq >= end:
                break
            put(b, A.kick(0.95 * level), tq)
            if q in (1, 3):
                put(b, A.clap(0.75 * level), tq, 1.0, 0.1)
        for s in range(16):
            ts = b0 + s * s16
            if ts >= end:
                break
            put(b, A.shaker(0.5 * level * (1.2 if s % 4 == 2 else 0.8)), ts, 1.0, -0.3)
            if full and s % 2 == 1:
                put(b, A.hat(0.4 * level, s % 8 == 7), ts, 1.0, 0.35)
        if full:
            for s in (0, 3, 6, 10, 12):
                if b0 + s * s16 < end:
                    put(b, A.logdrum(hz(root) * 2, 0.9 * level), b0 + s * s16)
            for s, n in hook or []:
                if b0 + s * s16 < end:
                    put(b, A.marimba(hz(n), 0.8 * level), b0 + s * s16, 1.0, 0.25)
        put(b, A.epiano([hz(n) for n in ch], min(bar, end - b0), 0.85 * level), b0, 1.0, -0.15)
        bi += 1


# ================================================================== Ad 1: Shouldn't be a struggle (112 BPM)
def struggle():
    dur = 33.0
    setup(dur)
    beat = 60 / 112
    prog_low = [("D1", ["D3", "F3", "A3", "C4"]), ("A#0", ["A#2", "D3", "F3", "A3"]), ("G1", ["G2", "A#2", "D3", "F3"]), ("A1", ["A2", "C#3", "E3", "G3"])]
    prog_hi = [("F1", ["F3", "A3", "C4", "E4"]), ("D1", ["D3", "F3", "A3", "C4"]), ("A#0", ["A#2", "D3", "F3", "A3"]), ("C1", ["C3", "E3", "G3", "A#3"])]
    hook = [(0, "A5"), (3, "F5"), (6, "C5"), (8, "G5"), (10, "F5"), (12, "E5"), (14, "C5")]
    m = B()
    # 0–2.3: night. A warm pad under the lamp; after the click (1.1, when the lamp dies in the clip) a low, sad chord.
    put(m, crickets(2.6, 1.0), 0)
    put(m, A.pad([hz(n) for n in ["F3", "A3", "C4", "E4"]], 1.15, 0.9, 1500), 0)
    put(m, A.pad([hz(n) for n in ["D3", "F3", "A3"]], 2.2, 1.0, 700), 1.15)
    # 3.4–8.2: the problems, a filtered, moody groove (no log drums yet)
    groove(m, 3.4, 8.2, beat, prog_low, 0.75, full=False)
    # 8.2–10.3: lift
    put(m, A.pad([hz(n) for n in ["F3", "A3", "C4", "G4"]], 2.1, 1.1, 2200), 8.2)
    # 10.3–12.9: the brand moment, chords only
    put(m, A.pad([hz(n) for n in ["F3", "A3", "C4", "E4", "A4"]], 2.6, 1.3, 2600), 10.3)
    # 12.9–26.7: the full groove
    groove(m, 12.9, 26.7, beat, prog_hi, 1.0, full=True, hook=hook)
    # 26.7–28.15: stop-start hits; 28.15–29.5: the groove back for "Just practise and go"
    groove(m, 28.15, 29.5, beat, prog_hi, 1.0, full=True, hook=hook)
    # end card
    put(m, A.pad([hz(n) for n in ["F3", "A3", "C4", "E4", "G4"]], 3.5, 1.4, 2600), 29.5)
    put(m, A.epiano([hz(n) for n in ["F3", "A3", "C4", "E4"]], 3.3, 1.0), 29.5)
    m = fx(m, Pedalboard([Reverb(room_size=0.35, wet_level=0.12, dry_level=0.95)]))
    # the problem section stays muffled
    pre = (np.arange(m.shape[1]) / SR >= 3.4) & (np.arange(m.shape[1]) / SR < 8.2)
    lp = fx(m, Pedalboard([LowpassFilter(cutoff_frequency_hz=900)]))
    m[:, pre] = lp[:, pre]

    s = B()
    put(s, click(1.0), 1.1, 1.0)
    put(s, A.sub(hz("D1"), 0.8, 0.8), 1.15, 0.6)
    put(s, A.whoosh(0.4, True, 0.6), 2.2)
    for i in range(4):
        put(s, A.pop(520 + i * 70), 2.4 + i * 0.14, 0.7, (i % 3 - 1) * 0.4)
    put(s, A.whoosh(0.5, True, 0.7), 3.3)
    for a in (3.6, 5.1, 6.6):
        put(s, A.whoosh(0.35, True, 0.6), a - 0.12)
        put(s, A.pop(640), a + 0.05, 0.7)
    put(s, A.whoosh(0.5, True, 0.7), 8.15)
    put(s, A.riser(2.0, 0.7), 8.3)
    put(s, A.tick(True), 10.32, 0.8)
    put(s, A.tick(False), 10.5, 0.6)
    put(s, A.impact(0.9), 10.8)
    put(s, A.chime(("F5", "C6", "F6"), 0.08, 1.0), 10.85)
    put(s, A.sparkle(1.2, 0.8), 11.1)
    for i in range(3):
        put(s, A.slam(140 + i * 30), 11.75 + i * 0.16, 0.55)
    put(s, A.whoosh(0.5, True, 0.8), 12.85)
    put(s, A.impact(1.0), 12.9)
    put(s, A.tap(1700), 14.5)
    put(s, A.chime(("C6", "G6"), 0.06, 0.9), 14.62)
    put(s, A.whoosh(0.5, True, 0.7), 15.85)
    put(s, A.countup(0.6, 600, 1700), 16.0, 0.5)
    put(s, A.impact(0.8), 16.6)
    put(s, A.sparkle(1.4, 1.0), 16.65)
    put(s, A.whoosh(0.5, True, 0.7), 18.35)
    type_ticks(s, 19.35, 34, 27)
    put(s, A.pop(900), 19.6, 0.6)
    put(s, A.whoosh(0.5, True, 0.8), 21.45)
    put(s, A.coin(), 22.1, 0.6)
    put(s, A.whoosh(0.6, True, 0.8), 23.65)
    put(s, A.sparkle(1.0, 0.6), 24.2)
    put(s, A.slam(110), 26.75, 1.0)
    put(s, A.slam(130), 27.25, 1.0)
    put(s, A.riser(0.8, 0.6), 27.4)
    put(s, A.impact(1.0), 28.15)
    for i in range(10):
        put(s, A.pop(700 + i * 40), 28.15 + i * 0.03, 0.25)
    put(s, A.whoosh(0.6, False, 0.6), 29.45)
    put(s, A.chime(("F5", "A5", "C6", "F6"), 0.09, 1.0), 29.55)
    put(s, A.pop(700), 30.8, 0.8)
    put(s, A.sparkle(1.5, 0.7), 30.9)
    master(m * 0.42 + s * 0.6, "struggle", dur)


# ================================================================== Ad 2: One app. Every subject. (120 BPM)
def oneapp():
    dur = 34.0
    setup(dur)
    beat = 0.5
    prog = [("A1", ["A3", "C#4", "E4", "G#4"]), ("F#1", ["F#3", "A3", "C#4", "E4"]), ("D1", ["D3", "F#3", "A3", "C#4"]), ("E1", ["E3", "G#3", "B3", "D4"])]
    hook = [(0, "E5"), (2, "C#5"), (4, "A4"), (7, "B4"), (8, "C#5"), (10, "E5"), (12, "F#5"), (14, "E5")]
    m = B()
    # 0–3: bright keys under the typing; 3–5: the logo; 5–21: afro-house groove; 21–23: the dive (riser, no drums);
    # 23–28.6: dark half-time with sub; 28.6–30.9: gold lift; 30.9: end card
    put(m, A.pad([hz(n) for n in ["A3", "C#4", "E4", "B4"]], 3.0, 1.0, 2400), 0)
    for i, n in enumerate(["E5", "A5", "C#6", "B5", "A5", "E5"]):
        put(m, A.marimba(hz(n), 0.5), 0.3 + i * 0.4, 1.0, (i % 2) * 0.4 - 0.2)
    put(m, A.pad([hz(n) for n in ["A3", "C#4", "E4", "G#4", "B4"]], 2.0, 1.3, 2800), 3.0)
    groove(m, 5.0, 21.0, beat, prog, 1.0, full=True, hook=hook)
    put(m, A.pad([hz(n) for n in ["D3", "A3", "D4", "F#4"]], 2.1, 1.2, 1600), 21.0)
    dprog = [("F#1", ["F#3", "A3", "C#4"]), ("D1", ["D3", "F#3", "A3"]), ("A1", ["A2", "C#3", "E3"]), ("E1", ["E3", "G#3", "B3"])]
    bar2 = 2.0
    for bi in range(3):
        b0 = 23.0 + bi * bar2
        if b0 >= 28.6:
            break
        root, ch = dprog[bi % 4]
        put(m, A.pad([hz(n) for n in ch], min(bar2, 28.6 - b0), 1.0, 1400), b0)
        put(m, S.k808(hz(root) * 2, 1.2, 1.0), b0)
        put(m, S.kick2(0.9), b0)
        put(m, S.snare2(0.85), b0 + 1.0)
        for s in range(8):
            if b0 + s * 0.25 < 28.6:
                put(m, S.hat2(0.4 if s % 2 else 0.55), b0 + s * 0.25, 1.0, 0.3)
        for s, n in ((0, "C#6"), (3, "A5"), (6, "F#5")):
            put(m, S.bell(hz(n), 0.5), b0 + s * 0.25, 1.0, -0.25)
    groove(m, 28.6, 30.9, beat, prog, 1.0, full=True, hook=hook)
    put(m, A.pad([hz(n) for n in ["A3", "C#4", "E4", "G#4", "B4"]], 3.2, 1.4, 2800), 30.9)
    put(m, A.epiano([hz(n) for n in ["A3", "C#4", "E4", "G#4"]], 3.0, 1.0), 30.9)
    m = fx(m, Pedalboard([Reverb(room_size=0.4, wet_level=0.13, dry_level=0.95)]))
    # the dive section: groove filtered down as the camera goes in
    tt = np.arange(m.shape[1]) / SR
    lp = fx(m, Pedalboard([LowpassFilter(cutoff_frequency_hz=800)]))
    sel = (tt >= 21.0) & (tt < 23.0)
    m[:, sel] = lp[:, sel]

    s = B()
    for k, x in enumerate((0.15, 0.3, 0.45, 0.6, 0.75)):
        put(s, A.pop(600 + k * 90), x, 0.6, (k % 2) * 0.6 - 0.3)
    type_ticks(s, 0.35, 28, 24, 0.32)
    put(s, A.tap(1500), 2.55, 0.9)
    put(s, A.whoosh(0.5, True, 0.8), 2.85)
    put(s, A.chime(("A5", "E6", "A6"), 0.08, 1.0), 3.5)
    put(s, A.sparkle(1.2, 0.8), 3.7)
    put(s, A.whoosh(0.5, True, 0.8), 4.9)
    put(s, A.impact(0.8), 5.0)
    for k in range(3):
        put(s, A.pop(700 + k * 120), 6.0 + k * 0.18, 0.8)
    for i in range(6):
        a = 7.2 + i * 1.3
        put(s, A.whoosh(0.35, True, 0.7), a - 0.1)
        put(s, A.pop(800 + i * 60), a + 0.15, 0.5)
    put(s, A.whoosh(0.6, True, 0.8), 14.95)
    put(s, A.sparkle(1.0, 0.5), 15.6)
    put(s, A.whoosh(0.5, True, 0.7), 17.95)
    put(s, A.tap(1700), 19.75)
    put(s, A.chime(("E6", "B6"), 0.06, 0.8), 19.85)
    put(s, A.riser(1.9, 0.9), 21.0)
    put(s, A.whoosh(1.2, True, 1.0), 21.7)
    put(s, A.impact(1.0), 23.0)
    put(s, A.sparkle(1.6, 0.9), 23.2)
    for k in range(8):
        put(s, A.pop(900 + k * 50), 23.3 + k * 0.08, 0.35)
    put(s, A.whoosh(0.5, True, 0.7), 25.55)
    put(s, A.whoosh(0.7, True, 0.9), 28.5)
    put(s, A.impact(0.9), 28.6)
    put(s, A.tap(1400), 29.95, 1.0)
    put(s, A.whoosh(0.5, True, 0.8), 30.5)
    put(s, A.chime(("A5", "C#6", "E6", "A6"), 0.09, 1.0), 30.95)
    put(s, A.pop(700), 32.2, 0.8)
    put(s, A.sparkle(1.5, 0.7), 32.3)
    master(m * 0.42 + s * 0.6, "oneapp", dur)


if __name__ == "__main__":
    want = sys.argv[1:] or ["struggle", "oneapp"]
    for w in want:
        {"struggle": struggle, "oneapp": oneapp}[w]()
