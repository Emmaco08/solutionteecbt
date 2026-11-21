"""Builds one app tutorial video's timeline, pictures and soundtrack (D-187).

Inputs: the real app screens and tap rectangles from apps/mobile/test_shots/tutorial_test.dart
(test_shots/shots/tutorial/<name>/), the script (video/tut/scripts.json) and the voice lines (tools/tut_vo.py).
Outputs: public/tut/<name>/NN.jpg, public/tut/<name>/audio.wav and src/tut/specs/<name>.json (what the Remotion
composition plays: chapters, every tap / typed field / drag with its time and rectangle, camera moves, screen changes).

    .venv/bin/python tools/tut_build.py signup custom
"""
import json, os, sys
import numpy as np
import soundfile as sf
from PIL import Image
from scipy.signal import resample_poly
from pedalboard import Pedalboard, Reverb

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio as A  # noqa: E402
import audio_pack as P  # noqa: E402
from audio import SR, hz, fx  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, "..", "apps", "mobile", "test_shots", "shots", "tutorial")
put = P.put

INTRO_MIN, OUTRO_MIN = 3.2, 4.0
TAP, DRAG, HOLD, SCROLL = 1.05, 1.4, 0.8, 1.35


def act_len(s):
    if "type" in s:
        return 0.55 + 0.055 * len(s["type"]["text"]) + 0.45
    if "drag" in s:
        return DRAG
    if "scroll" in s:
        return SCROLL
    if "tap" in s:
        return TAP
    return HOLD


def nav_change(a, b):
    """True when two pictures are different screens (slide), False for a change on the same screen (crossfade)."""
    x = np.asarray(Image.open(a).convert("L").resize((60, 130)), dtype=np.float32)
    y = np.asarray(Image.open(b).convert("L").resize((60, 130)), dtype=np.float32)
    return float(np.mean(np.abs(x - y) > 18)) > 0.33


def zoom_for(r):
    """Camera zoom for a target rectangle (1170-wide picture): small targets get a closer look."""
    w = max(r["w"], r["h"] * 1.6)
    return float(np.clip(560 / max(w, 1), 1.0, 1.55))


def load_vo(key):
    a, sr = sf.read(os.path.join(ROOT, "public", "tut", "vo", f"{key}.wav"), dtype="float32")
    if a.ndim > 1:
        a = a.mean(axis=1)
    if sr != SR:
        g = np.gcd(sr, SR)
        a = resample_poly(a, SR // g, sr // g).astype(np.float32)
    return a / (np.abs(a).max() + 1e-9) * 0.9


def bed(dur):
    """A calm, friendly bed: soft electric piano chords, warm pad, gentle kick and shaker at 88 BPM."""
    m = P.B()
    beat = 60 / 88
    bar = beat * 4
    prog = [["A3", "C#4", "E4", "B4"], ["F#3", "A3", "C#4", "E4"], ["D3", "F#3", "A3", "C#4"], ["E3", "G#3", "B3", "D4"]]
    roots = ["A1", "F#1", "D1", "E1"]
    t, i = 0.0, 0
    while t < dur:
        ch = prog[i % 4]
        put(m, A.epiano([hz(n) for n in ch], bar, 0.55), t, 1.0, -0.1)
        put(m, A.pad([hz(n) for n in ch], bar, 0.35, 1100), t)
        put(m, A.sub(hz(roots[i % 4]) * 2, bar * 0.9, 0.35), t)
        for q in range(4):
            tq = t + q * beat
            if tq >= dur:
                break
            if t > 1.5:
                put(m, A.kick(0.35), tq) if q in (0, 2) else None
                put(m, A.shaker(0.18), tq + beat / 2, 1.0, 0.3)
        t += bar
        i += 1
    return fx(m, Pedalboard([Reverb(room_size=0.5, wet_level=0.18, dry_level=0.9)]))


def duck(m, spans, depth_db=-11.0):
    g = np.ones(m.shape[1])
    lo = 10 ** (depth_db / 20)
    r = int(0.15 * SR)
    for a, b in spans:
        i0, i1 = int(a * SR), int(b * SR)
        g[max(0, i0 - r): i0] = np.minimum(g[max(0, i0 - r): i0], np.linspace(1, lo, i0 - max(0, i0 - r)))
        g[i0:i1] = lo
        seg = g[i1: i1 + r]
        g[i1: i1 + r] = np.minimum(seg, np.linspace(lo, 1, len(seg)))
    return m * g


def build(name, scripts, vo_meta):
    sc = scripts[name]
    src = os.path.join(SHOTS, name)
    cap = json.load(open(os.path.join(src, "steps.json")))
    steps = cap["steps"]
    out_img = os.path.join(ROOT, "public", "tut", name)
    os.makedirs(out_img, exist_ok=True)
    frames = []
    for i, s in enumerate(steps):
        im = Image.open(os.path.join(src, s["png"])).convert("RGB")
        fn = f"{i:02d}.jpg"
        im.save(os.path.join(out_img, fn), quality=90)
        frames.append(f"tut/{name}/{fn}")

    sec = lambda k: vo_meta[k]["seconds"]  # noqa: E731
    t = 0.0
    intro = {"start": 0.0, "say": sc["intro"], "vo": 0.6}
    t = max(INTRO_MIN, 0.6 + sec(f"{name}_intro") + 0.6)
    intro["end"] = t
    chapters, actions, cam, vo_at = [], [], [], [(f"{name}_intro", 0.6)]
    cam.append({"t": 0.0, "z": 1.0, "x": 585, "y": 1266})
    shown = 0  # frame on screen
    for ci, ch in enumerate(sc["chapters"]):
        key = f"{name}_c{ci + 1}"
        v = sec(key)
        fr = ch["frames"]
        lens = [act_len(steps[f]) for f in fr]
        total = sum(lens)
        dur = max(v + 0.7, total + 0.5)
        gap = min(0.9, max(0.0, (v + 0.2 - total) / max(1, len(fr))))
        start = t
        vo_at.append((key, start + 0.15))
        at = start + 0.45
        for f, ln in zip(fr, lens):
            s = steps[f]
            kind = "type" if "type" in s else "drag" if "drag" in s else "scroll" if "scroll" in s else "tap" if "tap" in s else "hold"
            rect = s.get("type") or s.get("drag") or s.get("tap")
            if kind == "scroll":
                a_dy = s["scroll"]
                rect = None
            a = {"frame": f, "kind": kind, "start": round(at, 3), "end": round(at + ln, 3)}
            if kind == "scroll":
                a["dy"] = a_dy
            if rect:
                a["rect"] = {k: round(rect[k], 1) for k in ("x", "y", "w", "h")}
                if kind == "type":
                    a["text"] = rect["text"]
                if kind == "drag":
                    a["dx"] = rect["dx"]
                z = zoom_for(rect)
                cx, cy = rect["x"] + rect["w"] / 2, rect["y"] + rect["h"] / 2
                if kind == "drag":
                    cx += rect["dx"] / 2
                cam.append({"t": round(at - 0.35, 3), "z": round(z, 3), "x": round(cx, 1), "y": round(cy, 1)})
            nxt = f + 1 if f + 1 < len(steps) else None
            if nxt is not None:
                a["next"] = nxt
                a["nav"] = kind != "scroll" and nav_change(os.path.join(src, steps[f]["png"]), os.path.join(src, steps[nxt]["png"]))
            actions.append(a)
            at += ln + gap
            shown = nxt if nxt is not None else f
        t = start + dur
        chapters.append({"start": round(start, 3), "end": round(t, 3), "caption": ch["caption"], "say": ch["say"]})
        cam.append({"t": round(t - 0.25, 3), "z": 1.0, "x": 585, "y": 1266})
    outro = {"start": round(t, 3), "say": sc["outro"]}
    vo_at.append((f"{name}_outro", t + 0.9))
    t += max(OUTRO_MIN, 0.9 + sec(f"{name}_outro") + 0.8)
    outro["end"] = round(t, 3)
    duration = round(t + 0.3, 2)

    # ---- sound: bed, voice, taps and swishes
    P.setup(duration)
    m = bed(duration)
    s = P.B()
    v = P.B()
    spans = []
    for k, at in vo_at:
        a = load_vo(k)
        put(v, a, at)
        spans.append((at, at + len(a) / SR))
    put(s, A.chime(("A5", "E6"), 0.07, 0.6), 0.25)
    for a in actions:
        if a["kind"] == "tap":
            put(s, A.tap(1500), a["start"] + 0.45, 0.8)
        elif a["kind"] == "type":
            n = len(a["text"])
            for k in range(n):
                put(s, A.tap(1800 + (k % 3) * 140), a["start"] + 0.55 + k * 0.055, 0.28)
        elif a["kind"] in ("drag", "scroll"):
            put(s, A.whoosh(0.5, True, 0.25), a["start"] + 0.4)
        if a.get("nav"):
            put(s, A.whoosh(0.3, True, 0.35), a["end"] - 0.35)
    put(s, A.chime(("A5", "C#6", "E6"), 0.08, 0.7), outro["start"] + 0.3)
    m = duck(m, spans, -12.0)
    P.master(m * 0.32 + s * 0.45 + v * 1.25, name, duration, os.path.join("..", "tut", name, "audio.wav"))

    spec = {
        "name": name, "title": sc["title"], "kicker": sc["kicker"], "duration": duration,
        "intro": intro, "outro": outro, "chapters": chapters, "frames": frames, "actions": actions, "cam": cam,
        "audio": f"tut/{name}/audio.wav",
    }
    os.makedirs(os.path.join(ROOT, "src", "tut", "specs"), exist_ok=True)
    json.dump(spec, open(os.path.join(ROOT, "src", "tut", "specs", f"{name}.json"), "w"), indent=1)
    print(name, "duration", duration, "s,", len(chapters), "chapters,", len(actions), "actions")


if __name__ == "__main__":
    scripts = json.load(open(os.path.join(ROOT, "tut", "scripts.json")))
    vo_meta = json.load(open(os.path.join(ROOT, "public", "tut", "vo", "vo.json")))
    for n in sys.argv[1:] or list(scripts):
        build(n, scripts, vo_meta)
    # the list of tutorials the Remotion project registers
    names = sorted(f[:-5] for f in os.listdir(os.path.join(ROOT, "src", "tut", "specs")) if f.endswith(".json"))
    with open(os.path.join(ROOT, "src", "tut", "specs", "index.ts"), "w") as f:
        f.write("// Generated by tools/tut_build.py\n")
        for n in names:
            f.write(f'import {n} from "./{n}.json";\n')
        f.write("export const SPECS = { " + ", ".join(names) + " };\n")
