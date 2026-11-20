"""Voice-over for the "Now on Windows" advert (D-186 v2).

Chatterbox TTS (Resemble AI, MIT licence: free for commercial ads), its own built-in voice, read with energy.
Each line is made in several takes; speech recognition (faster-whisper) keeps the take whose words match the script.

    /home/user/tts/.venv/bin/python tools/vo_win.py   ->  public/vo_win/*.wav + vo.json
"""
import json, os, re, sys
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly
import torch
from chatterbox.tts import ChatterboxTTS

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "public", "vo_win")

# (key, what is said, how it is spelt for the voice, exaggeration)
LINES = [
    ("w1", "JAMB is written on a computer.", "Jamb is written on a computer.", 0.55),
    ("w2", "So why are you only practising on your phone?", "So why are you only practising on your phone?", 0.6),
    ("w3", "SolutionTee CBT is now on Windows!", "Solution Tee, C.B.T., is now on Windows!", 0.75),
    ("w4", "A real CBT, on a big screen. Timer, calculator, keyboard keys. Just like exam day.", "A real C.B.T., on a big screen. Timer, calculator, keyboard keys. Just like exam day.", 0.6),
    ("w5", "AI tutor, Game Zone, videos and notes. Everything, bigger.", "A.I. tutor, Game Zone, videos and notes. Everything, bigger!", 0.65),
    ("w6", "Same account. Same Premium.", "Same account. Same Premium.", 0.55),
    ("w7", "Download it free at cbt.solutiontee.com", "Download it free, at C.B.T. dot Solution Tee dot com.", 0.6),
]
TAKES = 3


def words(s):
    s = s.lower().replace("jamb", "jam").replace("solutiontee", "solution tee").replace("cbt", "c b t").replace("ai ", "a i ")
    return re.findall(r"[a-z]+", s)


def score(heard, want):
    h, w = words(heard), words(want)
    hit = sum(1 for x in w if x in h)
    return hit / max(1, len(w)) - 0.02 * abs(len(h) - len(w))


def trim(a, sr, db=-42):
    thr = 10 ** (db / 20) * np.max(np.abs(a))
    idx = np.where(np.abs(a) > thr)[0]
    return a[max(idx[0] - int(0.03 * sr), 0): min(idx[-1] + int(0.08 * sr), len(a))]


if __name__ == "__main__":
    only = set(sys.argv[1:])
    os.makedirs(OUT, exist_ok=True)
    torch.set_num_threads(4)
    model = ChatterboxTTS.from_pretrained(device="cpu")
    from faster_whisper import WhisperModel
    asr = WhisperModel("small.en", device="cpu", compute_type="int8")
    meta_path = os.path.join(OUT, "vo.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    for key, text, spoken, ex in LINES:
        if only and key not in only:
            continue
        best = None
        for take in range(TAKES):
            torch.manual_seed(100 + take)
            wav = model.generate(spoken, exaggeration=ex, cfg_weight=0.45, temperature=0.75)
            a = trim(wav.squeeze(0).numpy(), model.sr)
            tmp = os.path.join(OUT, f"_{key}_{take}.wav")
            sf.write(tmp, a, model.sr)
            a16 = resample_poly(a, 2, 3).astype(np.float32) if model.sr == 24000 else a.astype(np.float32)
            heard = " ".join(seg.text for seg in asr.transcribe(a16, language="en")[0])
            sc = score(heard, spoken)
            print(key, take, round(len(a) / model.sr, 2), "s", round(sc, 2), "|", heard.strip(), flush=True)
            if best is None or sc > best[0]:
                best = (sc, take, a, heard)
        sf.write(os.path.join(OUT, f"{key}.wav"), best[2], model.sr)
        meta[key] = {"text": text, "spoken": spoken, "heard": best[3].strip(), "take": best[1], "seconds": round(len(best[2]) / model.sr, 3)}
        for take in range(TAKES):
            os.remove(os.path.join(OUT, f"_{key}_{take}.wav"))
        json.dump(meta, open(meta_path, "w"), indent=1)
