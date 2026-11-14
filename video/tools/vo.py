"""Voice-over for the SolutionTee CBT intro advert (D-164).

Kokoro-82M (Apache-2.0) through kokoro-onnx. Exam-body names are given as phonemes so they are said the Nigerian way:
JAMB = "jam" /dʒæm/, WAEC = "WAY-ek" /ˈweɪ.ɛk/, NECO = "NEH-koh" /ˈnɛkoʊ/. Run from a folder holding model.onnx and
voices.npz:  python vo.py <voice> <out_dir>
"""
import json, re, sys
import numpy as np, soundfile as sf
from kokoro_onnx import Kokoro

LINES = [
    ("l01", "Exam day is coming.", 1.0),
    ("l02", "JAMB.", 0.95),
    ("l03", "WAEC.", 0.95),
    ("l04", "NECO.", 0.95),
    ("l05", "Are you ready?", 1.0),
    ("l06", "Meet SolutionTee CBT.", 1.0),
    ("l07", "Practise real past questions, with the real exam timer.", 1.08),
    ("l08", "See your JAMB score the moment you submit.", 1.08),
    ("l09", "Stuck on a question? Snap it. Your AI tutor explains it, step by step.", 1.1),
    ("l10", "No data? No wahala. Download, and practise offline.", 1.06),
    ("l11", "Battle your friends live, in the Game Zone.", 1.08),
    ("l12", "Join live challenges, and win cash prizes.", 1.05),
    ("l13", "Climb the leaderboard. Keep your streak alive.", 1.08),
    ("l14", "Live classes. Real tutors. And a community that learns with you.", 1.08),
    ("l15", "Everything you need to pass, in one app.", 1.04),
    ("l16", "SolutionTee CBT.", 0.95),
    ("l17", "Learn. Think. Solve.", 0.9),
    ("l18", "Download it free, today.", 1.0),
]
FIX = {"JAMB": "dʒˈæm", "WAEC": "wˈeɪɛk", "NECO": "nˈɛkoʊ", "wahala": "wɑːhˈɑːlɑ", "SolutionTee": "səlˈuːʃən tˈiː", "CBT": "sˌiː bˌiː tˈiː"}

def phonemes(tok, text):
    out = []
    for part in re.split(r"(\b(?:%s)\b)" % "|".join(FIX), text):
        if not part:
            continue
        out.append(FIX[part] if part in FIX else tok.phonemize(part, "en-us"))
    return re.sub(r"\s+", " ", " ".join(out)).replace(" .", ".").replace(" ,", ",").replace(" ?", "?").strip()

def trim(a, sr, db=-45):
    thr = 10 ** (db / 20) * np.max(np.abs(a))
    idx = np.where(np.abs(a) > thr)[0]
    s, e = max(idx[0] - int(0.02 * sr), 0), min(idx[-1] + int(0.06 * sr), len(a))
    return a[s:e]

if __name__ == "__main__":
    voice, out = sys.argv[1], sys.argv[2]
    k = Kokoro("model.onnx", "voices.npz")
    meta = {}
    for key, text, speed in LINES:
        ph = phonemes(k.tokenizer, text)
        a, sr = k.create(ph, voice=voice, speed=speed, is_phonemes=True)
        a = trim(a, sr)
        sf.write(f"{out}/{key}.wav", a, sr)
        meta[key] = {"text": text, "phonemes": ph, "seconds": round(len(a) / sr, 3)}
        print(key, meta[key]["seconds"], ph)
    json.dump(meta, open(f"{out}/vo.json", "w"), indent=1, ensure_ascii=False)
