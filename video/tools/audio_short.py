"""Music, sound effects and mix for the 30 s short (D-165): a trap beat at 150 BPM (808s, hi-hat rolls, a bell riff),
snap-scroll whooshes and sticker pops, and the af_bella voice-over. Output: public/audio/short.wav (-14 LUFS).

    python tools/audio_short.py      (same Python packages as tools/audio.py)
"""
import json, os, sys
import numpy as np
import soundfile as sf
import pyloudnorm as pyln
from scipy.signal import resample_poly
from pedalboard import Pedalboard, Reverb, Compressor, Limiter, Chorus, HighpassFilter, LowpassFilter, PeakFilter, \
    LowShelfFilter, HighShelfFilter, Distortion, Delay, Gain

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio as A  # reuse the synth helpers and sound effects
from audio import SR, T, filt, noise, fx, hz

ROOT = A.ROOT
TL = json.load(open(os.path.join(ROOT, "src", "short", "timeline.json")))
DUR = TL["duration"]
A.DUR = DUR
A.N = N = int((DUR + 1) * SR)
BEAT = 60 / TL["bpm"]  # 0.4 s
BAR = BEAT * 4
S16 = BEAT / 4
rng = np.random.default_rng(11)
bus, place = A.bus, A.place
DROP = 2.4
END = 27.2  # beat stops, last hit rings out


def k808(f, dur, v=1.0, glide_from=None):
    t = T(dur + 0.3)
    f0 = glide_from or f
    fr = f + (f0 - f) * np.exp(-t * 18) + f * 1.6 * np.exp(-t * 55)
    x = np.sin(2 * np.pi * np.cumsum(fr) / SR)
    env = np.minimum(t / 0.003, 1) * np.exp(-t * 1.6) * np.where(t > dur, np.exp(-(t - dur) * 25), 1)
    x = np.tanh(x * env * 2.6) * 0.62
    return filt(x, "lowpass", 900) * v


def kick2(v=1.0):
    t = T(0.3)
    f = 55 + 160 * np.exp(-t * 45)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14)
    click = filt(noise(0.3), "highpass", 3000) * np.exp(-t * 500) * 0.6
    return np.tanh((body + click) * 1.8) * v * 0.8


def snare2(v=1.0):
    t = T(0.4)
    tone = np.sin(2 * np.pi * 210 * t) * np.exp(-t * 28) * 0.6
    n = filt(noise(0.4), "bandpass", [1200, 9000]) * np.exp(-t * 16)
    clapx = np.pad(A.clap(1.0), (0, max(0, len(t) - int(0.35 * SR))))[: len(t)] * 0.8
    return np.tanh((tone + n + clapx) * 1.3) * v * 0.5


def hat2(v=1.0, open_=False):
    return A.hat(v * 1.3, open_)


def bell(f, v=1.0):
    t = T(1.2)
    x = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 3) + 0.25 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t * 7)
         + 0.2 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 25))
    return x * np.exp(-t * 3.2) * np.minimum(t / 0.002, 1) * v * 0.16


PROG = [("A1", ["A3", "C4", "E4"]), ("F1", ["F3", "A3", "C4"]), ("C2", ["G3", "C4", "E4"]), ("G1", ["G3", "B3", "D4"])]
RIFF = [  # 16th steps per bar
    [(0, "E5"), (3, "C5"), (6, "A4"), (8, "E5"), (10, "D5"), (12, "C5"), (14, "B4")],
    [(0, "C5"), (3, "A4"), (6, "F4"), (8, "C5"), (10, "B4"), (12, "A4"), (14, "C5")],
    [(0, "E5"), (3, "C5"), (6, "G4"), (8, "E5"), (10, "D5"), (12, "E5"), (14, "G5")],
    [(0, "D5"), (3, "B4"), (6, "G4"), (8, "D5"), (10, "C5"), (12, "B4"), (14, "A4")],
]


def at(bar, s):
    return DROP + bar * BAR + s * S16


def music():
    drums, bass, keys, pads = bus(), bus(), bus(), bus()
    # intro: the riff through a closed filter, vinyl crackle, a swell into the drop
    for bar in (-2, -1):  # 2 bars before the drop start at -0.8 s; we only keep what lands after 0
        for s, n in RIFF[bar % 4]:
            tt = DROP + bar * BAR + s * S16
            if tt >= 0:
                place(keys, bell(hz(n), 0.8), tt)
    crack = (rng.random(int(DROP * SR)) > 0.9992).astype(float) * rng.uniform(0.2, 1, int(DROP * SR))
    place(drums, filt(crack, "highpass", 1500) * 0.25 + filt(noise(DROP), "bandpass", [800, 4000]) * 0.004, 0)
    place(pads, A.pad([hz("A2"), hz("E3"), hz("A3"), hz("C4")], DROP, 0.9, 900), 0)
    swell = A.riser(1.2, 0.6)
    place(drums, swell, DROP - 1.2, 0.8)
    bars = int((END - DROP) / BAR) + 1
    for bar in range(bars):
        root, chord = PROG[bar % 4]
        r = hz(root)
        t0 = at(bar, 0)
        if t0 >= END:
            break
        light = 12.6 <= t0 < 15.6  # AI tutor: a lighter bar so the steps breathe
        # 808 pattern: 0, 6 (slide), 10, 14
        for s, d, slide in ((0, 0.55, None), (6, 0.35, r * 1.5), (10, 0.3, None), (14, 0.2, r * 2)):
            if at(bar, s) < END:
                place(bass, k808(r, d, 0.95, slide), at(bar, s))
        for s in (0, 7, 10) if not light else (0,):
            if at(bar, s) < END:
                place(drums, kick2(1.0 if s == 0 else 0.85), at(bar, s))
        if at(bar, 8) < END:
            place(drums, snare2(1.0), at(bar, 8))
        # hats: 8ths, with rolls at the end of every 2nd bar
        for s in range(0, 16, 2):
            place(drums, hat2(0.9 if s % 4 == 0 else 0.6), at(bar, s), pan=0.25)
        if bar % 2 == 1:
            for k in range(6):
                place(drums, hat2(0.35 + k * 0.08), at(bar, 12) + k * S16 * 2 / 3, pan=0.25)
            place(drums, hat2(0.6, True), at(bar, 14), pan=-0.3)
        for s, n in RIFF[bar % 4]:
            if at(bar, s) < END:
                place(keys, bell(hz(n), 0.9), at(bar, s), pan=-0.15)
        place(pads, A.pad([hz(n) for n in chord], BAR, 0.6, 1600), t0)
    # final hit
    place(bass, k808(hz("A1"), 2.2, 1.0), END)
    place(drums, kick2(1.0), END)
    place(keys, A.epiano([hz("A3"), hz("C4"), hz("E4"), hz("B4")], 2.5, 1.3), END)
    place(pads, A.pad([hz("A2"), hz("E3"), hz("C4"), hz("E4"), hz("B4")], 2.6, 1.3, 2000), END)
    drums = fx(drums, Pedalboard([Compressor(threshold_db=-14, ratio=3, attack_ms=2, release_ms=70)]))
    keys = fx(keys, Pedalboard([Delay(delay_seconds=BEAT * 0.75, feedback=0.3, mix=0.22), Reverb(room_size=0.6, wet_level=0.3, dry_level=0.8)]))
    pads = fx(pads, Pedalboard([Chorus(rate_hz=0.3, depth=0.4, mix=0.4), Reverb(room_size=0.85, wet_level=0.4, dry_level=0.7)]))
    # intro keys stay muffled until the drop
    keys = A.automate_lowpass(keys, [(0, 900), (DROP - 0.05, 900), (DROP, 20000)])
    return drums * 0.95 + bass * 1.0 + keys * 0.8 + pads * 0.7


def marker(dur=0.35):
    t = T(dur)
    n = filt(noise(dur), "bandpass", [2000, 7000]) * (np.sin(np.pi * t / dur) ** 0.5)
    return n * 0.25


def stamp():
    t = T(0.6)
    thud = np.sin(2 * np.pi * np.cumsum(60 + 120 * np.exp(-t * 40)) / SR) * np.exp(-t * 12)
    slap = filt(noise(0.6), "bandpass", [400, 3000]) * np.exp(-t * 60) * 0.8
    return np.tanh((thud + slap) * 1.6) * 0.7


def buzz():
    t = T(0.35)
    return filt(np.sign(np.sin(2 * np.pi * 110 * t)), "lowpass", 1800) * np.exp(-t * 6) * 0.12


def sfx():
    b = bus()
    stations = [s["at"] for s in TL["stations"]]
    for s in stations[1:]:
        place(b, A.whoosh(0.32, False, 0.9), s - 0.22, 0.7)
    place(b, marker(), 1.62, 0.9)
    place(b, A.impact(0.9), DROP, 0.9)
    place(b, A.pop(700), 3.1, 0.8)
    place(b, marker(0.3), 4.32, 0.8)
    place(b, A.chime(("C6", "G6"), 0.05), 4.6, 0.7)
    for t0 in (5.2, 5.54, 6.18):
        place(b, stamp(), t0, 0.9)
    place(b, marker(0.3), 8.0, 0.7)
    place(b, A.chime(("E6", "B6"), 0.05), 8.3, 0.7)
    for k in range(5):
        place(b, A.tick(k % 2 == 0), 9.4 + k * 0.4, 0.7)
    place(b, A.countup(0.8, 600, 1800), 11.5, 0.8)
    place(b, A.chime(("C6", "E6", "G6"), 0.05), 12.3, 0.9)
    place(b, A.pop(900), 13.5, 0.7)
    for t0 in (14.5, 14.75, 15.0):
        place(b, A.pop(800), t0, 0.7)
    place(b, buzz(), 15.9, 0.9)
    place(b, A.chime(("G5", "D6"), 0.05), 16.5, 0.9)
    place(b, A.slam(110), 17.8, 0.7)
    place(b, A.countup(0.35, 900, 2400), 19.95, 0.7)
    for k in range(50):
        place(b, A.coin(), 20.04 + rng.uniform(0, 1.8) ** 1.3 / 1.2, 0.5, pan=rng.uniform(-0.9, 0.9))
    place(b, A.chime(("E6", "A6", "E7"), 0.05, 1.2), 20.32, 0.9)
    place(b, A.riser(0.8, 0.6), 21.2, 0.6)
    place(b, A.sparkle(1.6, 1.2), 22.2, 0.9)
    for t0 in (24.4, 24.7, 25.0):
        place(b, A.pop(650), t0, 0.6)
    place(b, A.pop(700), 25.6, 0.6)
    place(b, A.sparkle(2.0, 0.9), 26.4, 0.7)
    return b


def voice():
    b = bus()
    chain = Pedalboard([HighpassFilter(cutoff_frequency_hz=85), LowShelfFilter(cutoff_frequency_hz=200, gain_db=1.5),
                        PeakFilter(cutoff_frequency_hz=3200, gain_db=2.5, q=0.9), HighShelfFilter(cutoff_frequency_hz=9000, gain_db=2),
                        Compressor(threshold_db=-22, ratio=3.5, attack_ms=4, release_ms=90), Gain(4),
                        Reverb(room_size=0.18, wet_level=0.06, dry_level=1.0)])
    for l in TL["vo"]:
        a, sr = sf.read(os.path.join(ROOT, "public", "vo_short", l["id"] + ".wav"))
        a = fx(resample_poly(a, SR, sr), chain)[0]
        place(b, a, l["at"], 1.0)
    return b


def main():
    os.makedirs(os.path.join(ROOT, "public", "audio"), exist_ok=True)
    m, s, v = music(), sfx(), voice()
    m = A.duck(m, v, -9.0)
    mix = (m * 0.28 + s * 0.5 + v * 1.0)[:, : int(DUR * SR)]
    fade = int(1.5 * SR)
    mix[:, -fade:] *= np.linspace(1, 0, fade) ** 1.5
    mix = fx(mix, Pedalboard([HighpassFilter(cutoff_frequency_hz=32), LowShelfFilter(cutoff_frequency_hz=110, gain_db=-3.0),
                              PeakFilter(cutoff_frequency_hz=2500, gain_db=1.0, q=0.7), HighShelfFilter(cutoff_frequency_hz=6500, gain_db=2.5),
                              Compressor(threshold_db=-12, ratio=2, attack_ms=10, release_ms=120)]))
    meter = pyln.Meter(SR)
    mix = mix * 10 ** ((-12.5 - meter.integrated_loudness(mix.T)) / 20)
    mix = fx(mix, Pedalboard([Limiter(threshold_db=-1.0, release_ms=60)]))
    mix = mix * 10 ** ((-14 - meter.integrated_loudness(mix.T)) / 20)
    print("loudness", round(meter.integrated_loudness(mix.T), 2), "LUFS, peak", round(20 * np.log10(np.abs(mix).max()), 2), "dBFS")
    sf.write(os.path.join(ROOT, "public", "audio", "short.wav"), mix.T, SR, subtype="PCM_24")
    db = lambda a: 20 * np.log10(np.sqrt(np.mean(a ** 2)) + 1e-9)
    print(" ".join(f"{l['id']}:{db(v[:, int(l['at'] * SR):int((l['at'] + l['seconds']) * SR)]) - db(m[:, int(l['at'] * SR):int((l['at'] + l['seconds']) * SR)] * 0.28):.1f}" for l in TL["vo"]))


if __name__ == "__main__":
    main()
