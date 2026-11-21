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
  The music dips under the voice. The ad is now 24.5 s to fit the voice.

| Time | Voice |
|---|---|
| 0.15 s | JAMB is written on a computer. |
| 2.15 s | So why are you only practising on your phone? |
| 5.0 s | SolutionTee CBT is now on Windows! |
| 8.0 s | A real CBT, on a big screen. Timer, calculator, keyboard keys. Just like exam day. |
| 13.3 s | AI tutor, Game Zone, videos and notes. Everything, bigger. |
| 17.3 s | Same account. Same Premium. |
| 19.75 s | Download it free at cbt.solutiontee.com |

Checked: speech recognition on the final mix hears every line over the music ("Jam is written on a computer, so why are you only practicing on your phone? Solution T, CBT, is now on Windows. ...").

## v3 (owner, 21 Nov 2026: "continue, use a real 3D laptop with proper textures")

- Brushed aluminium: a procedural streak texture drives roughness and bump on the body and lid (`video/src/win/textures.ts`).
- Printed keycaps: white labels on every key (esc, F1–F12, QWERTY, shift, ctrl, fn, alt, arrows) laid exactly on the
  keycap tops; speaker grilles either side of the keyboard; ports on both sides; finger notch on the front edge.
- A walnut desk (CC0 texture "American Walnut Veneer", Jenelle van Heerden, Poly Haven), warmed in tone, fading into the
  page background like a product photo; the monitors in the hook stand on it too.
- No logos on the laptop (unbranded). Flat details sit above the surface with a depth offset so nothing flickers.

## v4 (owner, 21 Nov 2026: "I don't like these computers... background color is not good, I need white theme... motion graphics very poor... new better video with high professionalism")

Same script and voice; everything visual rebuilt for a white, product-launch look:
- White studio throughout (no dark scenes, no cream, no desk); navy titles, blue serif accents, each word sliding up out of a mask.
- Hook: the real exam screen assembles from its parts (header, timer, question, options A–D, calculator, keyboard help)
  flying in with motion blur and snapping into a Windows app window. No monitors.
- Match cut: the window shrinks into a phone; a laptop-sized outline draws around it ("A laptop screen" / "Your phone").
- Whip pan to the 3D laptop opening under a moving key light (highlight sweeps the aluminium), screen powers on, NEW badge.
- Camera dives into the laptop screen; the sharp screen takes over; Timer and Calculator lift out on the spoken words;
  keys B, →, F press and option B is selected; pull back out on "Just like exam day".
- Feature screens fly out of the laptop into a grid on each spoken name (AI tutor, Game Zone, Videos, Notes & news).
- Same account: a line draws from laptop to phone, "Premium" pops on both. White end card with the address typed.
- Every visual beat is placed on the voice's word timings (`video/public/vo_win/words.json`, speech recognition).
- Sharp screens: laptop screenshots re-rendered at 2x (`laptop_test.dart` with DPR=2).
