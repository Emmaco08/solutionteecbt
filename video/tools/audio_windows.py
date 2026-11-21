"""Music, sound effects, voice-over and mix for the "Now on Windows" advert (D-186 v2).

    .venv/bin/python tools/audio_windows.py  ->  public/audio/win_ad.wav

Everything except the voice is synthesised (helpers in tools/audio.py, tools/audio_pack.py, tools/audio_features.py).
The voice is public/vo_win/w1..w7.wav (tools/vo_win.py, Chatterbox, MIT). Lines start at the times in VO below (the same
as VO in src/win/WinAd.tsx); the music dips under the voice and stops for the end card.
"""
import os, sys
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio as A  # noqa: E402
import audio_pack as P  # noqa: E402
import audio_features as FE  # noqa: E402
from audio import SR  # noqa: E402

DUR = 24.5
T = {"tiny": 2.1, "reveal": 4.5, "open": 4.6, "cbt": 7.9, "all": 13.2, "same": 17.2, "end": 19.4}
VO = [("w1", 0.15), ("w2", 2.15), ("w3", 5.0), ("w4", 8.0), ("w5", 13.3), ("w6", 17.3), ("w7", 19.75)]
FE.END = T["end"]
put = P.put
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def voice_bus():
    b = P.B()
    spans = []
    for key, at in VO:
        a, sr = sf.read(os.path.join(ROOT, "public", "vo_win", f"{key}.wav"), dtype="float32")
        if a.ndim > 1:
            a = a.mean(axis=1)
        if sr != SR:
            g = np.gcd(sr, SR)
            a = resample_poly(a, SR // g, sr // g).astype(np.float32)
        a = a / (np.abs(a).max() + 1e-9) * 0.9
        put(b, a, at)
        spans.append((at, at + len(a) / SR))
    return b, spans


def duck(m, spans, depth_db=-10.0):
    """Lower the music while the voice speaks, with 120 ms ramps."""
    n = m.shape[1]
    g = np.ones(n)
    lo = 10 ** (depth_db / 20)
    ramp = int(0.12 * SR)
    for a, b in spans:
        i0, i1 = int(a * SR), int(b * SR)
        g[max(0, i0 - ramp): i0] = np.minimum(g[max(0, i0 - ramp): i0], np.linspace(1, lo, i0 - max(0, i0 - ramp)))
        g[i0:i1] = lo
        g[i1: i1 + ramp] = np.minimum(g[i1: i1 + ramp], np.linspace(lo, 1, len(g[i1: i1 + ramp])))
    return m * g


def main():
    P.setup(DUR)
    m = FE.bed_afro(T["reveal"] - 0.15)
    s = P.B()
    # hook: the exam screen's parts fly in and snap together
    put(s, A.whoosh(0.5, True, 0.5), 0.15)
    for i, d in enumerate((0.0, 0.1, 0.14, 0.18, 0.2, 0.22, 0.24, 0.26, 0.3, 0.32, 0.36)):
        put(s, A.tap(1400 + (i % 4) * 150), 0.62 + d, 0.35)
    put(s, A.pop(650), 1.2, 0.6)
    # match cut into the phone, the outline draws, the whip
    put(s, A.whoosh(0.4, False, 0.6), T["tiny"] - 0.25)
    put(s, A.pop(900), T["tiny"] + 0.15, 0.5)
    put(s, A.whoosh(0.6, True, 0.6), 2.66)   # the laptop-size screen grows out from behind the phone
    put(s, A.impact(0.35), 3.05)
    put(s, A.countup(0.45, 700, 1400), 3.25, 0.3)   # measurement lines draw
    put(s, A.chime(("E6", "B6"), 0.05, 0.55), 3.6)
    put(s, A.whoosh(0.35, True, 0.9), T["reveal"] - 0.3)
    # laptop: lid, light, screen on
    put(s, A.slam(90), T["open"] + 1.0, 0.45)
    put(s, A.impact(0.7), T["open"] + 0.9)
    put(s, A.chime(("A5", "E6", "A6"), 0.06, 0.7), T["open"] + 0.95)
    put(s, A.pop(700), 7.09, 0.8)
    # dive into the screen
    put(s, A.whoosh(0.8, True, 0.8), T["cbt"] - 0.05)
    put(s, A.impact(0.4), T["cbt"] + 0.8)
    # spotlights and keys
    for at in (10.16, 10.64):
        put(s, A.pop(820), at, 0.7)
        put(s, A.whoosh(0.25, True, 0.35), at - 0.05)
    for i, at in enumerate((11.46, 11.76, 11.99)):
        put(s, A.tap(1700 - i * 150), at, 1.0)
        put(s, A.tick(True), at, 0.5)
    put(s, A.whoosh(0.7, False, 0.6), 12.07)
    # screens fly out of the laptop
    for i, at in enumerate((13.2, 14.22, 15.18, 15.48)):
        put(s, A.whoosh(0.35, True, 0.55), at)
        put(s, A.pop(700 + i * 90), at + 0.25, 0.5)
    put(s, A.sparkle(1.0, 0.5), 16.04)
    put(s, A.whoosh(0.4, True, 0.6), T["same"] - 0.3)
    # same account: the line draws, Premium on both
    put(s, A.countup(0.6, 600, 1500), 17.6, 0.35)
    put(s, A.chime(("E6", "B6"), 0.06, 0.8), 18.24)
    put(s, A.pop(900), 18.32, 0.6)
    # end card: logo, button, address typed
    put(s, A.whoosh(0.6, False, 0.5), T["end"] - 0.1)
    put(s, A.chime(("A5", "C#6", "E6", "A6"), 0.09, 0.9), T["end"] + 0.1)
    put(s, A.pop(750), 19.65, 0.7)
    for i in range(19):
        put(s, A.tap(1900 + (i % 3) * 120), 20.54 + i / 14, 0.25)
    put(s, A.sparkle(1.5, 0.5), 21.9)
    v, spans = voice_bus()
    m = duck(m, spans, -9.0)
    s = duck(s, spans, -4.0)
    P.master(m * 0.42 + s * 0.55 + v * 1.25, "win", DUR, "win_ad.wav")


if __name__ == "__main__":
    main()
