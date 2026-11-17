"""Music, sound effects and mix for the feature ads (D-184): one track per ad, sound effects on every cut, tap and type.

    .venv/bin/python tools/audio_features.py [ai cbt game live offline board ...]  ->  public/audio/feat_<name>.wav

Everything is synthesised (helpers in tools/audio.py, tools/audio_short.py and tools/audio_pack.py); no samples.
"""
import os, sys
import numpy as np
from pedalboard import Pedalboard, Reverb, LowpassFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio as A  # noqa: E402
import audio_short as S  # noqa: E402
import audio_pack as P  # noqa: E402
from audio import SR, T, filt, noise, fx, hz  # noqa: E402

DUR = 19.0
END = 16.0  # end card: drums stop, a chord rings
rng = np.random.default_rng(31)
put = P.put


def notif(v=1.0):
    t = T(0.6)
    a = np.sin(2 * np.pi * hz("D6") * t) * np.exp(-t * 9) * (t < 0.3)
    b = np.sin(2 * np.pi * hz("A6") * t) * np.exp(-np.maximum(t - 0.11, 0) * 7) * (t >= 0.11)
    return fx((a + b) * 0.16 * v, Pedalboard([Reverb(room_size=0.3, wet_level=0.2)]))


def square(f, dur, v=1.0, duty=0.5):
    t = T(dur)
    x = np.where((f * t) % 1 < duty, 1.0, -1.0)
    env = np.minimum(t / 0.004, 1) * np.exp(-t * 6)
    return filt(x * env, "lowpass", 5000) * v * 0.06


def typing(s, at, seconds, cps, g=0.3):
    for k in range(int(seconds * cps)):
        put(s, A.tap(1900 + rng.integers(-300, 300)), at + k / cps, g)


def end_card(s):
    put(s, A.whoosh(0.6, False, 0.6), 15.9)
    put(s, A.chime(("A5", "C#6", "E6", "A6"), 0.09, 1.0), 16.1)
    put(s, A.pop(700), 17.3, 0.8)
    put(s, A.sparkle(1.5, 0.7), 17.4)


# ------------------------------------------------------------------ music beds

def bed_cine(beat, prog, start, bells=True, dark=False):
    """Half-time trap with pads (night, gold)."""
    m = P.B()
    bar = beat * 4
    s16 = beat / 4
    put(m, A.pad([hz(n) for n in prog[0][1]], start + 0.2, 1.3, 900 if dark else 1300), 0)
    for i in range(int(start / 0.3)):
        put(m, A.sub(hz(prog[0][0]), 0.22, 0.6), i * 0.3)
    bi = 0
    b0 = start
    while b0 < END - 0.05:
        root, ch = prog[bi % len(prog)]
        put(m, A.pad([hz(n) for n in ch], bar, 1.0, 1400 if dark else 1900), b0)
        put(m, S.k808(hz(root) * 2, 1.0, 1.0), b0)
        put(m, S.k808(hz(root) * 2, 0.5, 0.7), b0 + 3 * beat)
        put(m, S.kick2(0.95), b0)
        put(m, S.kick2(0.65), b0 + 2.5 * beat)
        put(m, S.snare2(0.9), b0 + 2 * beat)
        for s in range(16):
            ts = b0 + s * s16
            if ts >= END:
                break
            put(m, S.hat2(0.38 if s % 2 else 0.52), ts, 1.0, 0.3)
            if bi % 4 == 3 and s >= 12:
                put(m, S.hat2(0.28), ts + s16 / 2, 1.0, -0.3)
        if bells and bi % 2 == 0:
            for s, n in ((0, "A5"), (3, "F5"), (6, "D5"), (8, "C6"), (11, "A5"), (14, "F5")):
                if b0 + s * s16 < END:
                    put(m, S.bell(hz(n), 0.55), b0 + s * s16, 1.0, -0.25)
        b0 += bar
        bi += 1
    put(m, A.pad([hz(n) for n in ["F3", "A3", "C4", "E4", "A4"]], 3.0, 1.4, 2600), END)
    put(m, A.epiano([hz(n) for n in ["F3", "A3", "C4", "E4"]], 2.8, 1.0), END)
    return fx(m, Pedalboard([Reverb(room_size=0.5, wet_level=0.15, dry_level=0.92, width=1.0)]))


def bed_afro(start):
    """Warm Afro-house at 120 BPM (as ad A of the pack)."""
    m = P.B()
    beat, bar, s16 = 0.5, 2.0, 0.125
    prog = [("F#1", ["F#3", "A3", "C#4", "E4"]), ("D1", ["D3", "F#3", "A3", "C#4"]), ("A1", ["E3", "A3", "C#4", "E4"]), ("E1", ["E3", "G#3", "B3", "D4"])]
    hook = [(0, "C#5"), (3, "A4"), (6, "F#4"), (8, "E5"), (10, "C#5"), (12, "B4"), (14, "A4")]
    put(m, A.pad([hz(n) for n in ["F#3", "C#4", "A4"]], start + 0.2, 1.3, 1500), 0)
    bi = 0
    b0 = 0.0
    while b0 < END - 0.05:
        full = b0 >= start
        lvl = 1.0 if full else 0.4
        root, ch = prog[bi % 4]
        for q in range(4):
            tq = b0 + q * beat
            if tq >= END:
                break
            put(m, A.kick(lvl), tq)
            if q in (1, 3):
                put(m, A.clap(0.8 * lvl), tq, 1.0, 0.1)
        for s in range(16):
            ts = b0 + s * s16
            if ts >= END:
                break
            put(m, A.shaker(0.5 * lvl), ts, 1.0, -0.3)
            if full and s % 2:
                put(m, A.hat(0.42, s % 8 == 7), ts, 1.0, 0.35)
        if full:
            for s in (0, 3, 6, 10, 12):
                if b0 + s * s16 < END:
                    put(m, A.logdrum(hz(root) * 2, 0.9), b0 + s * s16)
            for s, n in hook:
                if b0 + s * s16 < END:
                    put(m, A.marimba(hz(n), 0.8), b0 + s * s16, 1.0, 0.25)
        put(m, A.epiano([hz(n) for n in ch], min(bar, END - b0), 0.85 * lvl), b0, 1.0, -0.15)
        b0 += bar
        bi += 1
    put(m, A.pad([hz(n) for n in ["A3", "C#4", "E4", "B4"]], 3.0, 1.5, 2400), END)
    put(m, A.epiano([hz(n) for n in ["A3", "C#4", "E4", "G#4"]], 2.8, 1.1), END)
    return fx(m, Pedalboard([Reverb(room_size=0.35, wet_level=0.12, dry_level=0.95)]))


def bed_club(start):
    """Hard four-on-the-floor with 808s and a bell riff (colour blocks)."""
    m = P.B()
    beat, bar, s16 = 0.5, 2.0, 0.125
    prog = [("A1", ["A3", "C4", "E4"]), ("F1", ["F3", "A3", "C4"]), ("C2", ["G3", "C4", "E4"]), ("G1", ["G3", "B3", "D4"])]
    bi = 0
    b0 = 0.0
    while b0 < END - 0.05:
        for q in range(4):
            tq = b0 + q * beat
            if tq < END:
                put(m, S.kick2(1.0 if b0 >= start else 0.7), tq)
                if q in (1, 3):
                    put(m, S.snare2(0.9), tq)
        if b0 >= start:
            for s in range(0, 16, 2):
                if b0 + s * s16 < END:
                    put(m, S.hat2(0.45), b0 + s * s16, 1.0, 0.3)
            root = prog[bi % 4][0]
            put(m, S.k808(hz(root), 1.3, 0.9), b0)
            for s, n in S.RIFF[bi % 4]:
                if b0 + s * s16 < END:
                    put(m, S.bell(hz(n), 0.8), b0 + s * s16, 1.0, 0.2)
        put(m, A.pad([hz(n) for n in prog[bi % 4][1]], min(bar, END - b0), 0.8, 2000), b0)
        b0 += bar
        bi += 1
    put(m, A.pad([hz(n) for n in ["A3", "C4", "E4", "G4"]], 3.0, 1.4, 2600), END)
    put(m, S.bell(hz("E5"), 1.0), END)
    return fx(m, Pedalboard([Reverb(room_size=0.3, wet_level=0.1, dry_level=0.95)]))


def bed_game():
    """Arcade energy: square-wave arpeggios, 4-on-the-floor, snare on 2 and 4 (Game Zone), 128 BPM."""
    m = P.B()
    beat = 60 / 128
    bar, s16 = beat * 4, beat / 4
    prog = [["C4", "E4", "G4", "C5"], ["A3", "C4", "E4", "A4"], ["F3", "A3", "C4", "F4"], ["G3", "B3", "D4", "G4"]]
    bass = ["C2", "A1", "F1", "G1"]
    bi = 0
    b0 = 0.0
    while b0 < END - 0.05:
        ch = prog[bi % 4]
        for q in range(4):
            tq = b0 + q * beat
            if tq < END:
                put(m, S.kick2(1.0), tq)
                if q in (1, 3):
                    put(m, S.snare2(0.85), tq)
        for s in range(16):
            ts = b0 + s * s16
            if ts >= END:
                break
            put(m, square(hz(ch[s % 4]) * (2 if s % 8 >= 4 else 1), s16 * 0.9, 1.0, 0.25), ts, 1.0, 0.2 if s % 2 else -0.2)
            if s % 2 == 0:
                put(m, S.hat2(0.4), ts, 1.0, 0.3)
            if s % 4 == 0:
                put(m, square(hz(bass[bi % 4]), s16 * 3, 2.2, 0.5), ts)
        b0 += bar
        bi += 1
    put(m, A.pad([hz(n) for n in ["C4", "E4", "G4", "B4"]], 3.0, 1.4, 2600), END)
    for i, n in enumerate(["C5", "E5", "G5", "C6"]):
        put(m, square(hz(n), 0.3, 1.4, 0.25), END + i * 0.08)
    return fx(m, Pedalboard([Reverb(room_size=0.3, wet_level=0.12, dry_level=0.95)]))


# ------------------------------------------------------------------ the six ads

def ai():
    P.setup(DUR)
    m = bed_cine(0.5, [("D1", ["D3", "F3", "A3", "C4"]), ("A#0", ["A#2", "D3", "F3", "A3"]), ("F1", ["F3", "A3", "C4", "E4"]), ("C1", ["C3", "E3", "G3", "A#3"])], 3.0, dark=True)
    s = P.B()
    put(s, A.impact(0.5), 0.0, 0.6)
    for i in range(3):
        put(s, A.pop(500 + i * 120), 0.25 + i * 0.18, 0.7)
    put(s, A.whoosh(0.4, True, 0.6), 1.55)
    put(s, A.pop(800), 1.65, 0.8)
    put(s, notif(0.6), 2.0)
    put(s, A.slam(130), 2.45, 0.5)
    put(s, A.slam(110), 2.75, 0.5)
    put(s, A.whoosh(0.5, True, 0.8), 2.95)
    put(s, A.chime(("E6", "B6"), 0.06, 0.7), 4.2)
    put(s, A.shutter(), 4.5, 1.2)
    put(s, A.whoosh(0.4, True, 0.6), 4.7)
    put(s, A.pop(700), 4.85, 0.7)
    typing(s, 5.35, 0.8, 45, 0.22)
    for a in (6.0, 6.75, 7.5):
        put(s, A.pop(800), a, 0.7)
    put(s, A.chime(("A5", "E6"), 0.06, 0.8), 8.05)
    put(s, A.whoosh(0.5, True, 0.7), 9.15)
    typing(s, 9.6, 0.9, 30, 0.3)
    put(s, A.pop(900), 10.55, 0.7)
    typing(s, 10.6, 1.2, 40, 0.18)
    put(s, A.whoosh(0.5, True, 0.8), 11.75)
    put(s, A.impact(0.6), 11.85, 0.7)
    for i in range(12):
        put(s, A.pop(600 + i * 50), 11.9 + i * 0.05, 0.35, (i % 3 - 1) * 0.6)
    put(s, A.whoosh(0.5, True, 0.8), 13.95)
    for a in (14.5, 14.75, 15.0):
        put(s, A.pop(800), a, 0.7)
    end_card(s)
    P.master(m * 0.4 + s * 0.62, "ai", DUR, "feat_ai.wav")


def cbt():
    P.setup(DUR)
    m = bed_afro(3.2)
    s = P.B()
    put(s, A.impact(0.6), 0.0, 0.6)
    put(s, A.slam(150), 0.5, 0.7)
    put(s, A.whoosh(0.4, True, 0.5), 0.65)
    for a in (1.65, 2.15, 2.65):
        put(s, A.pop(700), a, 0.7)
        put(s, P.clock(0.8), a + 0.25)
    put(s, A.whoosh(0.5, True, 0.8), 3.15)
    for a in (3.7, 4.15, 4.6, 5.1, 5.55, 6.0):
        put(s, A.tap(1500), a, 0.6)
        put(s, A.pop(900), a + 0.25, 0.6)
    put(s, A.whoosh(0.5, True, 0.8), 7.15)
    for k in range(9):
        put(s, P.clock(1.0, k % 2 == 0), 7.3 + k * 0.105)
    put(s, A.impact(1.0), 8.25)
    put(s, A.downbleep(), 8.25, 0.8)
    put(s, A.chime(("C#6", "G#6"), 0.06, 0.8), 8.45)
    put(s, A.whoosh(0.5, True, 0.8), 9.15)
    put(s, A.countup(1.0, 500, 1600), 9.6, 0.7)
    put(s, A.impact(0.8), 10.6)
    put(s, A.sparkle(1.4, 0.9), 10.65)
    put(s, A.whoosh(0.5, True, 0.7), 11.95)
    for i in range(3):
        put(s, A.pop(700), 12.35 + i * 0.18, 0.6)
        put(s, A.chime(("E6",), 0.0, 0.5), 13.4 + i * 0.25)
    put(s, A.whoosh(0.5, True, 0.7), 14.45)
    for i in range(3):
        put(s, A.slam(140 + i * 30), 14.65 + i * 0.15, 0.5)
    end_card(s)
    P.master(m * 0.42 + s * 0.6, "cbt", DUR, "feat_cbt.wav")


def game():
    P.setup(DUR)
    m = bed_game()
    s = P.B()
    put(s, A.impact(0.6), 0.0, 0.6)
    put(s, A.whoosh(0.4, True, 0.8), 1.55)
    put(s, A.slam(110), 2.0, 0.9)
    put(s, A.glitch(0.3), 2.0, 0.5)
    put(s, A.whoosh(0.4, True, 0.8), 2.95)
    put(s, A.whoosh(0.4, True, 0.8), 3.1)
    put(s, P.boom(0.9), 3.45)
    put(s, A.slam(160), 3.75, 0.8)
    put(s, A.whoosh(0.5, True, 0.8), 5.15)
    put(s, A.pop(900), 5.9, 0.7)
    put(s, A.coin(), 6.7, 1.0)
    put(s, A.chime(("E6", "B6"), 0.05, 0.8), 6.72)
    put(s, A.downbleep(), 7.0, 0.7)
    put(s, A.fire(), 7.35, 0.9)
    put(s, A.slam(140), 7.65, 0.7)
    put(s, A.whoosh(0.5, True, 0.8), 8.55)
    for i in range(6):
        put(s, A.pop(600 + i * 90), 8.85 + i * 0.1, 0.7, (i % 2) * 0.6 - 0.3)
    put(s, A.whoosh(0.5, True, 0.8), 10.95)
    put(s, A.impact(1.0), 11.15)
    put(s, A.sparkle(1.4, 1.0), 11.2)
    for i in range(5):
        put(s, A.coin(), 11.4 + i * 0.09, 0.6)
    put(s, A.arp_up("C5"), 12.0, 0.8)
    put(s, A.whoosh(0.5, True, 0.7), 13.35)
    for i in range(4):
        put(s, A.slam(110 + i * 40), 13.6 + i * 0.5, 0.7)
        put(s, A.chime((["C6", "E6", "G6", "C7"][i],), 0.0, 0.7), 13.62 + i * 0.5)
    end_card(s)
    P.master(m * 0.4 + s * 0.62, "game", DUR, "feat_game.wav")


def live():
    P.setup(DUR)
    m = bed_cine(60 / 110, [("E1", ["E3", "G3", "B3", "D4"]), ("C1", ["C3", "E3", "G3", "B3"]), ("A0", ["A2", "C3", "E3", "G3"]), ("B0", ["B2", "D#3", "F#3", "A3"])], 1.6, bells=False, dark=True)
    s = P.B()
    put(s, P.boom(0.6), 0.0)
    put(s, A.whoosh(0.5, True, 0.6), 0.45)
    put(s, A.impact(0.9), 1.62)
    put(s, A.slam(120), 2.0, 0.6)
    put(s, A.slam(140), 2.3, 0.6)
    put(s, A.whoosh(0.5, True, 0.8), 3.15)
    for a in (3.8, 4.15, 4.5, 4.85):
        put(s, A.pop(800), a, 0.7)
    put(s, A.whoosh(0.5, True, 0.8), 5.95)
    for i in range(7):
        put(s, A.tick(i % 2 == 0), 6.3 + i * 0.07, 0.7)
    for k in range(2):
        put(s, P.clock(0.7), 7.0 + k)
    put(s, A.pop(700), 7.4, 0.6)
    put(s, A.whoosh(0.5, True, 0.7), 8.55)
    for i in range(5):
        put(s, notif(1.0 if i < 4 else 1.3), 8.95 + i * 0.32)
    put(s, A.pop(700), 10.3, 0.6)
    put(s, A.whoosh(0.5, True, 0.8), 10.95)
    put(s, A.tap(1400), 11.85, 0.8)
    put(s, A.pop(800), 12.2, 0.7)
    put(s, A.whoosh(0.5, True, 0.8), 13.35)
    put(s, A.pop(700), 13.7, 0.7)
    put(s, A.whoosh(0.6, True, 0.8), 14.2)
    put(s, A.sparkle(1.2, 0.8), 14.4)
    end_card(s)
    P.master(m * 0.42 + s * 0.6, "live", DUR, "feat_live.wav")


def offline():
    P.setup(DUR)
    m = bed_club(3.2)
    s = P.B()
    put(s, A.glitch(0.35), 0.0, 0.6)
    put(s, A.downbleep(), 0.05, 0.9)
    put(s, A.slam(100), 0.85, 0.9)
    put(s, A.slam(130), 1.7, 0.7)
    put(s, A.whoosh(0.4, True, 0.7), 1.6)
    put(s, A.whoosh(0.4, True, 0.8), 3.1)
    put(s, A.tap(1600), 4.2, 0.9)
    put(s, A.countup(1.0, 500, 1500), 4.3, 0.5)
    put(s, A.chime(("A5", "E6"), 0.06, 0.9), 5.35)
    put(s, A.whoosh(0.4, True, 0.8), 5.9)
    put(s, A.tap(1100), 6.55, 1.0)
    put(s, A.pop(700), 7.1, 0.7)
    put(s, A.pop(800), 7.5, 0.7)
    put(s, A.whoosh(0.4, True, 0.8), 8.9)
    put(s, A.countup(1.0, 500, 1600), 9.5, 0.6)
    put(s, A.pop(800), 10.4, 0.7)
    put(s, A.whoosh(0.4, True, 0.8), 11.4)
    put(s, A.riser(0.7, 0.5), 12.0)
    put(s, A.chime(("E6", "B6"), 0.06, 0.9), 12.7)
    put(s, A.pop(800), 12.8, 0.7)
    put(s, A.pop(900), 13.05, 0.7)
    put(s, A.whoosh(0.4, True, 0.8), 13.9)
    for i in range(3):
        put(s, A.whoosh(0.3, True, 0.4), 14.3 + i * 0.15, 0.6, (i - 1) * 0.6)
    end_card(s)
    P.master(m * 0.42 + s * 0.6, "offline", DUR, "feat_offline.wav")


def board():
    P.setup(DUR)
    m = bed_cine(0.6, [("D1", ["D3", "F3", "A3", "C4"]), ("A#0", ["A#2", "D3", "F3", "A3"]), ("F1", ["F3", "A3", "C4", "E4"]), ("C1", ["C3", "E3", "G3", "A#3"])], 3.2)
    s = P.B()
    put(s, A.impact(0.6), 0.0, 0.6)
    for i in range(3):
        put(s, A.slam(110 + i * 25), 0.5 + i * 0.12, 0.6)
    put(s, P.boom(0.8), 1.6)
    put(s, A.impact(0.8), 1.9)
    put(s, A.coin(), 2.2, 0.9)
    put(s, A.whoosh(0.5, True, 0.8), 3.15)
    tt, gap = 3.7, 0.16
    while tt < 5.9:
        put(s, A.tick(True), tt, 0.5)
        tt += gap
        gap = max(0.05, gap * 0.94)
    put(s, A.chime(("A5", "E6", "A6"), 0.07, 0.9), 5.9)
    put(s, A.pop(800), 4.2, 0.7)
    put(s, A.whoosh(0.5, True, 0.8), 6.35)
    for i in range(3):
        put(s, A.slam(120 + i * 20), 6.7 + i * 0.1, 0.5)
        put(s, A.slam(120 + i * 20), 7.75 + i * 0.1, 0.5)
    put(s, A.tap(1300), 7.6, 0.8)
    put(s, A.whoosh(0.5, True, 0.8), 8.95)
    put(s, A.pop(800), 10.0, 0.7)
    put(s, A.tap(1500), 10.6, 0.8)
    put(s, A.whoosh(0.5, True, 0.8), 11.55)
    for i in range(6):
        put(s, A.pop(700 + i * 70), 11.9 + i * 0.1, 0.6)
    put(s, A.countup(1.0, 500, 1500), 12.4, 0.6)
    put(s, A.sparkle(1.2, 0.9), 13.4)
    put(s, A.coin(), 13.4, 0.8)
    put(s, A.whoosh(0.5, True, 0.8), 13.95)
    put(s, A.impact(0.8), 14.1)
    put(s, A.pop(800), 15.0, 0.7)
    end_card(s)
    P.master(m * 0.42 + s * 0.6, "board", DUR, "feat_board.wav")


if __name__ == "__main__":
    want = sys.argv[1:] or ["ai", "cbt", "game", "live", "offline", "board"]
    for w in want:
        globals()[w]()
