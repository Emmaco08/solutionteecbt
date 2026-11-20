# Advert: "SolutionTee CBT is now on Windows" (D-186)

Owner asked (20 Nov 2026): an advert announcing the Windows app. Same tools and style as the feature ads (D-184):
Remotion motion graphics, synthesised music and sound effects, real app screens.

## Hook and message

JAMB UTME is written on a computer at a CBT centre. Most students only practise on a phone. The hook uses that truth:
"JAMB is written on a computer. So why practise only on a phone?" Then the reveal: the app is now on Windows.

## Claims (only what the app does today, the same list as the website's Windows section)

- A real CBT on a big screen: timer, question grid, keyboard keys (A–E, arrows, F to flag, Shift+C calculator), calculator.
- AI tutor, Game Zone, study (videos, notes), news and badges, as on the phone.
- The same account and Premium as the phone.
- Windows 10 or 11, 64-bit, free to start. Download at cbt.solutiontee.com.

No promised scores. No Microsoft or Windows logo is drawn (their trademark; the word "Windows" only). Exam-body logos
come from `video/public/brand` (the owner's files) and the end card carries the independence disclaimer.

## Storyboard (20 s, 120 BPM)

| Time | Scene |
|---|---|
| 0–2.1 s | Cream. Three CBT-centre monitors drop in, each showing the real CBT screen. "JAMB is written / *on a computer.*" |
| 2.1–3.7 s | A small phone wobbles in. "So why practise / only on a *phone?*" |
| 3.7–6.8 s | Navy. A laptop lid rises and the screen powers on to the real Home screen. "SolutionTee CBT / is now on *Windows.*" NEW badge, flash, sparks |
| 6.8–10.8 s | Cream. The CBT on the laptop with the calculator open; keycaps press in time with the beat (A, →, F, Shift+C) with labels. "A real CBT. / *On a big screen.*" |
| 10.8–13.6 s | Navy. The laptop screen flips through AI tutor, Game Zone, Study, News, Badges; a label for each. "Everything you love. / *Bigger.*" |
| 13.6–16.1 s | Cream. Phone and laptop side by side, a gold line joins them. "Same account. / *Same Premium.*" Pill: Windows 10 & 11 · 64-bit · Free to start |
| 16.1–20 s | End card: logo, "Download for Windows", cbt.solutiontee.com, platforms, exam logos, disclaimer |

## Formats

9:16 (TikTok, Reels, Stories, WhatsApp Status), 4:5 (Facebook and Instagram feeds) and 16:9 (YouTube, X, Facebook in-stream, the website).

## Screens

Real laptop screens from `apps/mobile/test_shots/laptop_test.dart` at 1920 × 1080, re-rendered on 20 Nov 2026. The test
now loads the KaTeX fonts so maths draws as it does in the app (it showed empty boxes before). Copied to
`video/public/screens/win/`.

## Note for the owner

The Windows installer is not code-signed yet, so Windows shows "Windows protected your PC" on first run (More info → Run
anyway). Before spending money on this ad, signing the installer will stop people giving up at that warning.

## v2 (owner, 20 Nov 2026: "the laptop is not realistic, I need it super realistic, and a good voice-over")

- **Laptop:** real 3D in three.js (`video/src/win/Laptop3D.tsx`, through @remotion/three): aluminium body with rounded
  edges, recessed keyboard with 80 keycaps, trackpad, hinge, glossy black bezel, webcam, glass over the screen, lit by a
  CC0 studio HDRI from Poly Haven (`public/hdri/studio_small_09.hdr`, Sergej Majboroda), soft shadows and a contact
  shadow. The lid really opens on its hinge; the camera moves around the laptop and into the question.
- The CBT-centre monitors in the hook are 3D too.
- **Voice:** Chatterbox TTS (Resemble AI, MIT licence, free for ads), its own voice, read with energy
  (`video/tools/vo_win.py`). Each line is made in three takes; speech recognition keeps the take that says the script.
  The music dips under the voice. The ad is now 22 s to fit the voice.

| Time | Voice |
|---|---|
| 0.15 s | JAMB is written on a computer. |
| 2.05 s | So why are you only practising on your phone? |
| 4.55 s | SolutionTee CBT is now on Windows! |
| 7.1 s | A real CBT, on a big screen. Timer, calculator, keyboard keys. Just like exam day. |
| 11.7 s | AI tutor, Game Zone, videos and notes. Everything, bigger. |
| 14.75 s | Same account. Same Premium. |
| 17.3 s | Download it free at cbt.solutiontee.com |
