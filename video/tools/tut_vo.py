"""Voice-over for the app tutorial videos (D-187).

Chatterbox TTS (MIT, free for commercial use), its own voice, a calm and friendly teaching read. Every line of
video/tut/scripts.json (intro, each chapter's "say", outro) is made in three takes; speech recognition keeps the take
that says the script. Lines already made with the same text are kept.

    /home/user/tts/.venv/bin/python tools/tut_vo.py [signup custom ...]  ->  public/tut/vo/<key>.wav + vo.json
"""
import json, os, re, sys
import numpy as np
import soundfile as sf
import torch
from scipy.signal import resample_poly

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "public", "tut", "vo")
SPELL = [(r"\bJAMB\b", "Jamb"), (r"SolutionTee", "Solution Tee"), (r"\bCBT\b", "C.B.T."), (r"\bAI\b", "A.I."), (r"\bWAEC\b", "Way-ek"), (r"\bNECO\b", "Neh-ko")]
TAKES = 3


def spoken(text):
    for a, b in SPELL:
        text = re.sub(a, b, text)
    return text


def words(s):
    s = s.lower().replace("jamb", "jam").replace("solution tee", "solutiontee").replace("c.b.t.", "cbt").replace("a.i.", "ai")
    return re.findall(r"[a-z0-9]+", s)


def score(heard, want):
    h, w = words(heard), words(want)
    return sum(1 for x in w if x in h) / max(1, len(w)) - 0.02 * abs(len(h) - len(w))


def trim(a, sr, db=-42):
    thr = 10 ** (db / 20) * np.max(np.abs(a))
    idx = np.where(np.abs(a) > thr)[0]
    return a[max(idx[0] - int(0.03 * sr), 0): min(idx[-1] + int(0.1 * sr), len(a))]


def lines(scripts, names):
    for name in names:
        s = scripts[name]
        yield f"{name}_intro", s["intro"]
        for i, c in enumerate(s["chapters"]):
            yield f"{name}_c{i + 1}", c["say"]
        yield f"{name}_outro", s["outro"]


if __name__ == "__main__":
    scripts = json.load(open(os.path.join(ROOT, "tut", "scripts.json")))
    names = sys.argv[1:] or list(scripts)
    os.makedirs(OUT, exist_ok=True)
    meta_path = os.path.join(OUT, "vo.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    todo = [(k, t) for k, t in lines(scripts, names) if meta.get(k, {}).get("text") != t or not os.path.exists(os.path.join(OUT, f"{k}.wav"))]
    print(len(todo), "lines to make", flush=True)
    if not todo:
        sys.exit(0)
    from chatterbox.tts import ChatterboxTTS
    from faster_whisper import WhisperModel
    torch.set_num_threads(4)
    model = ChatterboxTTS.from_pretrained(device="cpu")
    asr = WhisperModel("small.en", device="cpu", compute_type="int8")
    for key, text in todo:
        say = spoken(text)
        best = None
        for take in range(TAKES):
            torch.manual_seed(200 + take)
            wav = model.generate(say, exaggeration=0.45, cfg_weight=0.5, temperature=0.7)
            a = trim(wav.squeeze(0).numpy(), model.sr)
            a16 = resample_poly(a, 2, 3).astype(np.float32)
            heard = " ".join(seg.text for seg in asr.transcribe(a16, language="en")[0]).strip()
            sc = score(heard, say)
            print(key, take, round(len(a) / model.sr, 2), round(sc, 2), "|", heard, flush=True)
            if best is None or sc > best[0]:
                best = (sc, a, heard)
            if sc >= 0.97:
                break
        sf.write(os.path.join(OUT, f"{key}.wav"), best[1], model.sr)
        meta[key] = {"text": text, "heard": best[2], "score": round(best[0], 2), "seconds": round(len(best[1]) / model.sr, 3)}
        json.dump(meta, open(meta_path, "w"), indent=1)
