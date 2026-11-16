"""Music, sound effects and mix for the social ads pack (D-182). No voice: every word is on screen.

  A  "If JAMB was tomorrow"   21 s   120 BPM  warm Afro-house: clock ticks, paper tear, a drop on "practice"
  B  "Stop scrolling"         15.5 s 120 BPM  hard trap/club: a slam on every colour block
  C  "Screen time"            30 s   100 BPM  dark cinematic: booms, risers, a half-time beat under the chapters

    .venv/bin/python tools/audio_pack.py [A|B|C ...]   ->  public/audio/pack_{A,B,C}.wav  (-14 LUFS)
Everything is synthesised here (helpers in tools/audio.py and tools/audio_short.py); no samples.
"""
import os, sys
import numpy as np
import soundfile as sf
import pyloudnorm as pyln
from pedalboard import Pedalboard, Reverb, Compressor, Limiter, HighpassFilter, LowpassFilter, LowShelfFilter, HighShelfFilter, PeakFilter, Delay, Chorus

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio as A  # noqa: E402
import audio_short as S  # noqa: E402
from audio import SR, T, filt, noise, fx, hz  # noqa: E402

ROOT = A.ROOT
rng = np.random.default_rng(23)


def setup(dur):
    A.DUR = dur
    A.N = int((dur + 1) * SR)


def B():
    return A.bus()


def put(b, sig, at, g=1.0, pan=0.0):
    A.place(b, sig, at, g, pan)


def tear():
    """Paper tearing: crackly band-passed noise that rises."""
    t = T(0.45)
    n = noise(0.45) * (0.5 + 0.5 * (rng.random(len(t)) > 0.86))
    x = filt(n, "bandpass", [1800, 7000]) * np.minimum(t / 0.02, 1) * np.exp(-t * 4)
    return x * 0.45


def clock(v=1.0, hi=True):
    t = T(0.12)
    f = 3200 if hi else 2400
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 90) + filt(noise(0.12), "bandpass", [2000, 6000]) * np.exp(-t * 300) * 0.5
    return x * 0.4 * v


def boom(v=1.0):
    t = T(2.5)
    f = 38 + 60 * np.exp(-t * 6)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 1.6)
    hit = filt(noise(2.5), "lowpass", 900) * np.exp(-t * 9) * 0.5
    x = np.tanh((x + hit) * 1.6) * 0.8 * v
    return fx(x, Pedalboard([Reverb(room_size=0.95, wet_level=0.4, dry_level=0.9, width=1.0)]))


def master(mix, name, dur):
    mix = mix[:, : int(dur * SR)]
    fade = int(0.9 * SR)
    mix[:, -fade:] *= np.linspace(1, 0, fade) ** 1.6
    mix = fx(mix, Pedalboard([HighpassFilter(cutoff_frequency_hz=30), LowShelfFilter(cutoff_frequency_hz=110, gain_db=-2.5),
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
    sf.write(os.path.join(ROOT, "public", "audio", f"pack_{name}.wav"), mix.T, SR, subtype="PCM_24")
    print(name, "loudness", round(meter.integrated_loudness(mix.T), 2), "LUFS, peak", round(20 * np.log10(np.abs(mix).max()), 2), "dBFS")


def chords(b, prog, start, end, bar, v=1.0, kind="epiano", pan=0.0):
    i = 0
    tt = start
    while tt < end - 0.05:
        _, ch = prog[i % len(prog)]
        d = min(bar, end - tt)
        sig = A.epiano([hz(n) for n in ch], d, v) if kind == "epiano" else A.pad([hz(n) for n in ch], d, v)
        put(b, sig, tt, 1.0, pan)
        tt += bar
        i += 1


# ================================================================== A: If JAMB was tomorrow (120 BPM)
def ad_a():
    dur = 21.0
    setup(dur)
    beat = 0.5
    bar = beat * 4
    s16 = beat / 4
    prog = [("F#1", ["F#3", "A3", "C#4", "E4"]), ("D1", ["D3", "F#3", "A3", "C#4"]), ("A1", ["E3", "A3", "C#4", "E4"]), ("E1", ["E3", "G#3", "B3", "D4"])]
    m = B()
    # 0–1.5: a soft hit and a dark pad; 1.5–3: only the clock; 3–4.5: the groove fades in under a filter; 4.5: drop
    put(m, A.pad([hz(n) for n in ["F#3", "C#4", "A4"]], 1.6, 1.4, 1400), 0)
    put(m, A.pad([hz(n) for n in ["D3", "A3", "F#4"]], 3.2, 1.2, 1100), 1.5)
    drop = 4.5
    hook = [(0, "C#5"), (3, "A4"), (6, "F#4"), (8, "E5"), (10, "C#5"), (12, "B4"), (14, "A4")]
    for bi in range(int((18.0 - 3.0) / bar) + 1):
        b0 = 3.0 + bi * bar
        if b0 >= 18.0:
            break
        full = b0 >= drop
        lvl = 1.0 if full else 0.45
        root, _ = prog[bi % 4]
        for q in range(4):
            tq = b0 + q * beat
            if tq >= 18.0:
                break
            put(m, A.kick(1.0 * lvl), tq)
            if q in (1, 3):
                put(m, A.clap(0.8 * lvl), tq, 1.0, 0.1)
        for s in range(16):
            ts = b0 + s * s16
            if ts >= 18.0:
                break
            put(m, A.shaker(0.5 * lvl * (1.2 if s % 4 == 2 else 0.8)), ts, 1.0, -0.3)
            if s % 2 == 1 and full:
                put(m, A.hat(0.45, s % 8 == 7), ts, 1.0, 0.35)
        if full:
            for s in (0, 3, 6, 10, 12):
                put(m, A.logdrum(hz(root) * 2, 0.9), b0 + s * s16)
            for s, n in hook:
                if b0 + s * s16 < 18.0:
                    put(m, A.marimba(hz(n), 0.85), b0 + s * s16, 1.0, 0.25)
        put(m, A.epiano([hz(n) for n in prog[bi % 4][1]], min(bar, 18.0 - b0), 0.9 * lvl), b0, 1.0, -0.15)
    # end card: warm chord, no drums
    put(m, A.pad([hz(n) for n in ["A3", "C#4", "E4", "B4"]], 3.0, 1.5, 2400), 18.0)
    put(m, A.epiano([hz(n) for n in ["A3", "C#4", "E4", "G#4"]], 2.8, 1.1), 18.0)
    m = fx(m, Pedalboard([Reverb(room_size=0.35, wet_level=0.12, dry_level=0.95)]))
    # filter the groove before the drop
    pre = (np.arange(m.shape[1]) / SR < drop)
    lp = fx(m, Pedalboard([LowpassFilter(cutoff_frequency_hz=700)]))
    m[:, pre] = lp[:, pre]

    s = B()
    put(s, A.impact(0.6), 0.0, 0.6)
    put(s, tear(), 0.62, 1.0)
    put(s, A.whoosh(0.4, True, 0.6), 1.45)
    for i in range(4):
        put(s, clock(1.0, i % 2 == 0), 1.5 + i * 0.5)
        put(s, clock(0.6, i % 2 == 1), 1.75 + i * 0.5)
    for i in range(8):
        put(s, A.pop(500 + i * 60), 3.05 + i * 0.09, 0.6, (i % 3 - 1) * 0.5)
    put(s, A.whoosh(0.5, False, 0.9), 4.1)
    put(s, A.riser(1.0, 0.7), 3.5)
    put(s, A.impact(1.0), 4.75)
    put(s, A.chime(("A5", "E6", "A6"), 0.08, 1.0), 5.6)
    put(s, A.sparkle(1.2, 0.8), 6.0)
    put(s, A.whoosh(0.5, True, 0.8), 7.2)
    put(s, A.tap(1700), 8.55)
    put(s, A.chime(("E6", "B6"), 0.06, 0.9), 8.7)
    put(s, A.whoosh(0.5, True, 0.7), 9.95)
    for at0, n in ((10.45, 15), (10.95, 18), (11.5, 16)):
        for k in range(n):
            put(s, A.tap(1900 + rng.integers(-200, 200)), at0 + k / 30, 0.35)
    put(s, A.chime(("C#6", "G#6"), 0.06, 0.6), 11.95)
    put(s, A.whoosh(0.5, True, 0.7), 12.45)
    for k in range(27):
        put(s, A.tap(2100 + rng.integers(-250, 250)), 12.75 + k / 32, 0.3)
    put(s, A.pop(900), 13.45, 0.8)
    put(s, A.sparkle(1.0, 0.7), 13.6)
    put(s, A.whoosh(0.5, True, 0.8), 14.45)
    put(s, A.countup(0.9, 500, 1600), 14.85, 0.7)
    put(s, A.impact(0.9), 15.75)
    put(s, A.sparkle(1.4, 1.0), 15.8)
    put(s, A.whoosh(0.4, True, 0.6), 16.45)
    for i in range(3):
        put(s, A.slam(140 + i * 30), 16.6 + i * 0.18, 0.55)
    put(s, A.whoosh(0.6, False, 0.6), 17.95)
    put(s, A.chime(("A5", "C#6", "E6", "A6"), 0.09, 1.0), 18.1)
    put(s, A.pop(700), 19.3, 0.8)
    put(s, A.sparkle(1.5, 0.7), 19.4)
    master(m * 0.42 + s * 0.6, "A", dur)


# ================================================================== B: Stop scrolling (120 BPM)
def ad_b():
    dur = 15.5
    setup(dur)
    beat = 0.5
    bar = 2.0
    s16 = beat / 4
    prog = [("A1", ["A3", "C4", "E4"]), ("F1", ["F3", "A3", "C4"]), ("C2", ["G3", "C4", "E4"]), ("G1", ["G3", "B3", "D4"])]
    m = B()
    # 0–2: hits only. 2–5: four-on-the-floor builds. 5–11: full beat with 808s and bell riff. 11–12.5: riser. 12.5: end.
    for tq in np.arange(2.0, 12.5, beat):
        put(m, S.kick2(1.0), tq)
    for tq in np.arange(2.5, 12.5, 1.0):
        put(m, S.snare2(0.8 if tq < 5 else 1.0), tq)
    for ts in np.arange(5.0, 11.0, s16 * 2):
        put(m, S.hat2(0.5), ts, 1.0, 0.3)
    for ts in np.arange(10.25, 11.0, s16 / 2):
        put(m, S.hat2(0.35), ts, 1.0, -0.3)
    for bi in range(3):
        b0 = 5.0 + bi * bar
        root = prog[bi % 4][0]
        put(m, S.k808(hz(root), 1.4, 1.0), b0)
        put(m, S.k808(hz(root), 0.5, 0.8), b0 + 1.5)
        for s, n in S.RIFF[bi % 4]:
            put(m, S.bell(hz(n), 0.9), b0 + s * s16, 1.0, 0.2)
    chords(m, prog, 3.5, 11.0, bar, 0.9, "pad")
    put(m, A.pad([hz(n) for n in ["A3", "C4", "E4", "G4"]], 3.0, 1.4, 2600), 12.5)
    put(m, S.bell(hz("E5"), 1.0), 12.5)
    m = fx(m, Pedalboard([Reverb(room_size=0.3, wet_level=0.1, dry_level=0.95)]))

    s = B()
    put(s, A.slam(90), 0.0, 1.0)
    put(s, A.glitch(0.3), 0.02, 0.6)
    put(s, A.whoosh(0.35, True, 0.8), 0.45)
    put(s, A.slam(120), 0.5, 0.7)
    put(s, A.slam(150), 1.0, 0.8)
    put(s, A.countup(0.6, 700, 1500), 1.3, 0.5)
    put(s, A.riser(0.9, 0.6), 1.1)
    for i, a in enumerate((2.0, 2.5, 3.0)):
        put(s, A.impact(0.6), a, 0.8)
        put(s, A.whoosh(0.3, True, 0.6), a - 0.12)
    put(s, A.whoosh(0.5, True, 0.8), 3.45)
    for i in range(4):
        put(s, A.pop(600 + i * 120), 3.75 + i * 0.12, 0.7)
    for a in (5.0, 6.5, 8.0, 9.5):
        put(s, A.whoosh(0.35, True, 0.9), a - 0.15)
        put(s, A.slam(100), a, 0.6)
    put(s, A.whoosh(0.6, True, 0.9), 10.9)
    put(s, A.riser(1.4, 0.8), 11.1)
    put(s, A.impact(1.0), 12.5)
    put(s, A.chime(("A5", "E6", "A6"), 0.08, 1.0), 12.6)
    put(s, A.pop(700), 13.8, 0.8)
    put(s, A.sparkle(1.4, 0.8), 13.9)
    master(m * 0.42 + s * 0.6, "B", dur)


# ================================================================== C: Screen time (100 BPM)
def ad_c():
    dur = 30.0
    setup(dur)
    beat = 0.6
    bar = 2.4
    s16 = beat / 4
    prog = [("D1", ["D3", "F3", "A3", "C4"]), ("A#0", ["A#2", "D3", "F3", "A3"]), ("F1", ["F3", "A3", "C4", "E4"]), ("C1", ["C3", "E3", "G3", "A#3"])]
    m = B()
    # Intro: dark pad and a pulse; 4.8: the beat comes in (half-time trap with sub); 24: lift; 26.4: resolve.
    put(m, A.pad([hz(n) for n in ["D3", "A3", "F4"]], 2.6, 1.3, 900), 0)
    put(m, A.pad([hz(n) for n in ["D3", "A3", "D4", "F4", "A4"]], 2.4, 1.4, 1800), 2.4)
    for i in range(8):
        put(m, A.sub(hz("D1"), 0.25, 0.7), i * 0.3)
    for bi in range(int((24.0 - 4.8) / bar)):
        b0 = 4.8 + bi * bar
        root, ch = prog[bi % 4]
        put(m, A.pad([hz(n) for n in ch], bar, 1.0, 1600), b0)
        put(m, S.k808(hz(root) * 2, 1.0, 1.0), b0)
        put(m, S.k808(hz(root) * 2, 0.5, 0.7), b0 + 1.5 * beat * 2)
        put(m, S.kick2(0.95), b0)
        put(m, S.kick2(0.7), b0 + 2.5 * beat)
        put(m, S.snare2(0.9), b0 + 2 * beat)
        for s in range(16):
            ts = b0 + s * s16
            roll = bi % 4 == 3 and s >= 12
            put(m, S.hat2(0.4 if s % 2 else 0.55), ts, 1.0, 0.3)
            if roll:
                put(m, S.hat2(0.3), ts + s16 / 2, 1.0, -0.3)
        if bi % 2 == 0:
            for s, n in ((0, "A5"), (3, "F5"), (6, "D5"), (8, "C6"), (11, "A5"), (14, "F5")):
                put(m, S.bell(hz(n), 0.6), b0 + s * s16, 1.0, -0.25)
    put(m, A.pad([hz(n) for n in ["D3", "A3", "D4", "F4", "A4"]], 2.4, 1.3, 2400), 24.0)
    put(m, A.pad([hz(n) for n in ["F3", "A3", "C4", "E4", "A4"]], 3.6, 1.4, 2600), 26.4)
    put(m, A.epiano([hz(n) for n in ["F3", "A3", "C4", "E4"]], 3.4, 1.0), 26.4)
    m = fx(m, Pedalboard([Reverb(room_size=0.55, wet_level=0.16, dry_level=0.92, width=1.0)]))

    s = B()
    for i in range(4):
        put(s, A.pop(800 + i * 90), 0.15 + i * 0.15, 0.7, (i % 2) * 0.6 - 0.3)
        put(s, A.whoosh(0.25, True, 0.5), 1.18 + i * 0.12, 0.6)
    put(s, A.riser(1.3, 0.8), 1.1)
    put(s, boom(1.0), 2.4)
    put(s, A.chime(("D6", "A6", "D7"), 0.09, 1.0), 2.5)
    put(s, A.sparkle(1.6, 1.0), 2.7)
    put(s, A.riser(1.0, 0.5), 3.8)
    for a in (4.8, 9.6, 14.4, 19.2):
        put(s, A.impact(0.8), a)
        put(s, A.whoosh(0.5, True, 0.8), a - 0.3)
        put(s, A.sparkle(1.0, 0.6), a + 0.5)
    for a in (6.2, 7.4, 11.0, 12.2, 15.8, 17.0, 20.6, 21.8):
        put(s, A.pop(900), a, 0.7)
    put(s, A.chime(("A5", "E6"), 0.06, 0.6), 7.5)
    put(s, A.countup(0.5, 900, 1800), 15.85, 0.4)
    put(s, A.whoosh(0.8, True, 0.9), 23.8)
    put(s, A.riser(2.3, 0.9), 24.1)
    put(s, boom(0.9), 26.4)
    put(s, A.chime(("F5", "A5", "C6", "F6"), 0.09, 1.0), 26.5)
    put(s, A.pop(700), 27.7, 0.8)
    put(s, A.sparkle(1.4, 0.7), 27.8)
    master(m * 0.42 + s * 0.6, "C", dur)


if __name__ == "__main__":
    want = sys.argv[1:] or ["A", "B", "C"]
    for w in want:
        {"A": ad_a, "B": ad_b, "C": ad_c}[w]()
