# SolutionTee CBT — launch videos (Remotion)

## Intro advert (D-164)
60 s, 1080 × 1920, 30 fps. Plan and script: `docs/plans/advert-intro.md`. Timeline (voice cues, words, scenes):
`src/timeline.json`.

### Rebuild
1. Voice (only if the script changes) — Kokoro-82M, Apache-2.0, voice `af_heart`:
   ```bash
   python3 -m venv .venv && . .venv/bin/activate
   pip install kokoro-onnx soundfile scipy pedalboard pyloudnorm
   B=https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/main
   curl -L -o model.onnx $B/onnx/model.onnx && curl -L -o af_heart.bin $B/voices/af_heart.bin
   python -c "import numpy as np; np.savez('voices.npz', af_heart=np.fromfile('af_heart.bin', dtype=np.float32).reshape(-1,1,256))"
   python tools/vo.py af_heart public/vo
   ```
   JAMB, WAEC and NECO are given as phonemes in `tools/vo.py` ("jam", "WAY-ek", "NEH-koh").
2. Music, sound effects and the final mix (all synthesised, no samples): `python tools/audio.py` → `public/audio/mix.wav`
   (−14 LUFS). Stems go to `out/stems/`.
3. Video: `npm install`, then `npm run render:vertical` → `out/solutiontee-intro-9x16.mp4`.
   Smaller copy for WhatsApp: `ffmpeg -i out/solutiontee-intro-9x16.mp4 -c:v libx264 -crf 25 -preset slow -c:a aac -b:a 160k out/solutiontee-intro-9x16-share.mp4`.
   Preview while editing: `npm run studio`. Stills for review: `node tools/stills.mjs 2.5 13.9 30.2` then `python3 tools/sheet.py out/sheet.jpg`.

### Assets and licences
- App screens: website store-kit screens captured at 3× and the Flutter golden renders (our own work).
- Brand: copies of `/brand` files, unchanged (exam-body logos, the logo Lottie, the wordmark).
- Fonts: Plus Jakarta Sans and Lilita One (SIL OFL). Voice: Kokoro-82M (Apache-2.0). Music and effects: made in
  `tools/audio.py`. No stock footage or sound libraries.

### Optional live-action inserts (Higgsfield, owner's credits)
The advert is complete without them. If you want real people in it, generate up to two 9:16 clips and send them to
me; I will cut them in (best spots: the first 2 s, and 12.0–12.6 s before the score).
1. *Cold open (5 s):* "Cinematic close-up of a Nigerian secondary-school student, about 17, studying late at night at a
   wooden desk, phone light on the face, textbooks, a wall clock ticking, warm desk lamp and cool blue phone light,
   shallow depth of field, slow push-in, photoreal, vertical 9:16."
2. *Celebration (4 s):* "A Nigerian teenage girl in school uniform looks at her phone, her eyes widen, then she
   celebrates with a joyful fist pump while two friends cheer behind her, bright classroom, handheld camera, golden
   light, photoreal, vertical 9:16."
Keep exam-body logos and readable text out of generated clips.

## 30 s short (D-165)
Plan: `docs/plans/advert-short.md`. Voice: `python tools/vo.py af_bella public/vo_short short`. Audio:
`python tools/audio_short.py` → `public/audio/short.wav`. Video: `npx remotion render src/index.ts Short916 out/solutiontee-short-30s.mp4 --codec h264 --crf 16`.

## Social ads pack (D-182)
Three ads in the style of launch videos the owner liked, each in 9:16 and 4:5. Plan: `docs/plans/advert-pack.md`.
Copy for posts: `docs/marketing/ad-copy.md`. Code: `src/pack/` (kit.tsx shared; AdTomorrow, AdStop, AdScreen).
1. Sound: `.venv/bin/python tools/audio_pack.py` → `public/audio/pack_{A,B,C}.wav` (same Python packages as above).
2. Video (compositions `AdTomorrow916/45`, `AdStop916/45`, `AdScreen916/45`), e.g.
   `npx remotion render src/index.ts AdStop916 out/pack/B_stop-scrolling_9x16.mp4 --codec h264 --crf 18`.
3. Small copies for WhatsApp: `ffmpeg -i in.mp4 -c:v libx264 -crf 24 -preset slow -c:a aac -b:a 160k -movflags +faststart out-share.mp4`.
Stills for review: `COMP=AdStop916 node tools/stills.mjs 0.2 1.5 5.6` then `python3 tools/sheet.py out/sheet.jpg`.

## Feature ads (D-184)
One ad per major feature, each in 9:16 and 4:5: `FeatAI`, `FeatMock`, `FeatGame`, `FeatLive`, `FeatOffline`,
`FeatBoard` (+ `916` / `45`). Plan: `docs/plans/advert-features.md`; copy: `docs/marketing/ad-copy-features.md`.
Sound: `.venv/bin/python tools/audio_features.py` → `public/audio/feat_*.wav`. Video, e.g.
`npx remotion render src/index.ts FeatAI916 out/features/1_ai-tutor_9x16.mp4 --codec h264 --crf 18`.

