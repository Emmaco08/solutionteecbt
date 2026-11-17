"""A small numpy/scipy stand-in for the parts of Spotify's `pedalboard` the audio scripts use (D-183).

pedalboard's Windows wheel crashes (access violation) on Python 3.14 on the owner's laptop, so on Windows the audio
scripts load this module under the name `pedalboard` (see `use_on_windows()`). Linux (the cloud machines) keeps the
real library. Same constructor arguments; the sound is close, not identical (reverb is a synthetic impulse).
"""
import sys

import numpy as np
from scipy import signal


def _db(x):
    return 10 ** (x / 20)


class _Plugin:
    def __call__(self, x, sr):
        return self.process(np.atleast_2d(np.asarray(x, np.float64)), sr)


def _biquad(b, a, x):
    return signal.lfilter(b, a, x, axis=-1)


class HighpassFilter(_Plugin):
    def __init__(self, cutoff_frequency_hz=50.0):
        self.f = cutoff_frequency_hz

    def process(self, x, sr):
        sos = signal.butter(2, self.f, "highpass", fs=sr, output="sos")
        return signal.sosfilt(sos, x, axis=-1)


class LowpassFilter(_Plugin):
    def __init__(self, cutoff_frequency_hz=50.0):
        self.f = cutoff_frequency_hz

    def process(self, x, sr):
        sos = signal.butter(2, min(self.f, sr * 0.45), "lowpass", fs=sr, output="sos")
        return signal.sosfilt(sos, x, axis=-1)


def _shelf(f, g_db, sr, high, q=0.707):
    # RBJ cookbook shelving filter
    A = 10 ** (g_db / 40)
    w = 2 * np.pi * f / sr
    alpha = np.sin(w) / (2 * q)
    c = np.cos(w)
    s = 2 * np.sqrt(A) * alpha
    if high:
        b = [A * ((A + 1) + (A - 1) * c + s), -2 * A * ((A - 1) + (A + 1) * c), A * ((A + 1) + (A - 1) * c - s)]
        a = [(A + 1) - (A - 1) * c + s, 2 * ((A - 1) - (A + 1) * c), (A + 1) - (A - 1) * c - s]
    else:
        b = [A * ((A + 1) - (A - 1) * c + s), 2 * A * ((A - 1) - (A + 1) * c), A * ((A + 1) - (A - 1) * c - s)]
        a = [(A + 1) + (A - 1) * c + s, -2 * ((A - 1) + (A + 1) * c), (A + 1) + (A - 1) * c - s]
    return np.array(b) / a[0], np.array(a) / a[0]


class LowShelfFilter(_Plugin):
    def __init__(self, cutoff_frequency_hz=440.0, gain_db=0.0, q=0.707):
        self.f, self.g, self.q = cutoff_frequency_hz, gain_db, q

    def process(self, x, sr):
        return _biquad(*_shelf(self.f, self.g, sr, False, self.q), x)


class HighShelfFilter(_Plugin):
    def __init__(self, cutoff_frequency_hz=440.0, gain_db=0.0, q=0.707):
        self.f, self.g, self.q = cutoff_frequency_hz, gain_db, q

    def process(self, x, sr):
        return _biquad(*_shelf(self.f, self.g, sr, True, self.q), x)


class PeakFilter(_Plugin):
    def __init__(self, cutoff_frequency_hz=440.0, gain_db=0.0, q=0.707):
        self.f, self.g, self.q = cutoff_frequency_hz, gain_db, q

    def process(self, x, sr):
        A = 10 ** (self.g / 40)
        w = 2 * np.pi * self.f / sr
        alpha = np.sin(w) / (2 * self.q)
        c = np.cos(w)
        b = np.array([1 + alpha * A, -2 * c, 1 - alpha * A])
        a = np.array([1 + alpha / A, -2 * c, 1 - alpha / A])
        return _biquad(b / a[0], a / a[0], x)


class Gain(_Plugin):
    def __init__(self, gain_db=0.0):
        self.g = gain_db

    def process(self, x, sr):
        return x * _db(self.g)


class Distortion(_Plugin):
    def __init__(self, drive_db=25.0):
        self.d = drive_db

    def process(self, x, sr):
        return np.tanh(x * _db(self.d))


class Reverb(_Plugin):
    """Stereo reverb from a decaying noise impulse; room_size sets the decay time, damping darkens the tail."""

    def __init__(self, room_size=0.5, damping=0.5, wet_level=0.33, dry_level=0.4, width=1.0, freeze_mode=0.0):
        self.room, self.damp, self.wet, self.dry, self.width = room_size, damping, wet_level, dry_level, width

    def process(self, x, sr):
        rt = 0.25 + self.room * 3.2  # seconds to -60 dB
        n = int(rt * sr)
        t = np.arange(n) / sr
        rng = np.random.default_rng(7)
        env = np.exp(-6.9 * t / rt)
        irs = []
        for ch in range(2):
            ir = rng.standard_normal(n) * env
            sos = signal.butter(1, 9000 - self.damp * 6000, "lowpass", fs=sr, output="sos")
            ir = signal.sosfilt(sos, ir)
            ir[: int(0.012 * sr)] *= np.linspace(0, 1, int(0.012 * sr))  # small pre-delay feel
            irs.append(ir / np.sqrt(np.sum(ir**2)))
        if x.shape[0] == 1:
            x = np.vstack([x, x])
        wet = np.vstack([signal.fftconvolve(x[c], irs[c])[: x.shape[1]] for c in range(2)])
        mid = wet.mean(axis=0, keepdims=True)
        wet = mid + (wet - mid) * self.width
        return x * self.dry + wet * self.wet * 0.9


class Delay(_Plugin):
    def __init__(self, delay_seconds=0.5, feedback=0.0, mix=0.5):
        self.d, self.fb, self.mix = delay_seconds, feedback, mix

    def process(self, x, sr):
        k = max(1, int(self.d * sr))
        y = np.zeros_like(x)
        tap = x.copy()
        g = 1.0
        for _ in range(8):
            tap = np.concatenate([np.zeros((x.shape[0], k)), tap[:, :-k]], axis=1)
            y += tap * g
            g *= self.fb
            if g < 0.01:
                break
        return x * (1 - self.mix) + y * self.mix


class Chorus(_Plugin):
    def __init__(self, rate_hz=1.0, depth=0.25, centre_delay_ms=7.0, feedback=0.0, mix=0.5):
        self.rate, self.depth, self.cd, self.mix = rate_hz, depth, centre_delay_ms, mix

    def process(self, x, sr):
        n = x.shape[1]
        t = np.arange(n)
        out = np.empty_like(x)
        for c in range(x.shape[0]):
            lfo = np.sin(2 * np.pi * self.rate * t / sr + c * np.pi / 2)
            d = (self.cd + self.depth * 5 * lfo) * sr / 1000
            idx = np.clip(t - d, 0, n - 1)
            out[c] = np.interp(idx, t, x[c])
        return x * (1 - self.mix) + out * self.mix


class Compressor(_Plugin):
    def __init__(self, threshold_db=0.0, ratio=1.0, attack_ms=1.0, release_ms=100.0):
        self.th, self.ratio, self.att, self.rel = threshold_db, ratio, attack_ms, release_ms

    def process(self, x, sr):
        level = np.max(np.abs(x), axis=0)
        # envelope: fast attack, slower release (one-pole each, via lfilter on a smoothed level)
        a_rel = np.exp(-1 / (self.rel / 1000 * sr))
        env = signal.lfilter([1 - a_rel], [1, -a_rel], level)
        env = np.maximum(env, signal.lfilter([1 - np.exp(-1 / (max(self.att, 0.1) / 1000 * sr))], [1, -np.exp(-1 / (max(self.att, 0.1) / 1000 * sr))], level))
        env_db = 20 * np.log10(np.maximum(env, 1e-9))
        over = np.maximum(env_db - self.th, 0)
        gain = _db(-over * (1 - 1 / self.ratio))
        return x * gain


class Limiter(_Plugin):
    def __init__(self, threshold_db=-10.0, release_ms=100.0):
        self.th, self.rel = threshold_db, release_ms

    def process(self, x, sr):
        lim = _db(self.th)
        peak = np.max(np.abs(x), axis=0)
        need = np.minimum(1.0, lim / np.maximum(peak, 1e-9))
        # hold the lowest gain over a 2 ms look-around, then release smoothly
        k = max(1, int(0.002 * sr))
        need = -signal.convolve(-need, np.ones(k), mode="same") / k
        need = np.minimum(need, np.minimum(1.0, lim / np.maximum(peak, 1e-9)))
        a = np.exp(-1 / (self.rel / 1000 * sr))
        g = np.empty_like(need)
        cur = 1.0
        for i in range(len(need)):  # simple release follower
            v = need[i]
            cur = v if v < cur else v + (cur - v) * a
            g[i] = cur
        return np.clip(x * g, -lim, lim)


class Pedalboard:
    def __init__(self, plugins=None):
        self.plugins = list(plugins or [])

    def __call__(self, x, sr):
        y = np.atleast_2d(np.asarray(x, np.float64))
        for p in self.plugins:
            y = p(y, sr)
        return y.astype(np.float32)


def use_on_windows():
    """Make `import pedalboard` load this module on Windows (the real wheel crashes there)."""
    if sys.platform == "win32":
        sys.modules["pedalboard"] = sys.modules[__name__]
