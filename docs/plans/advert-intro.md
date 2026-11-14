# Intro advert: "Exam day is coming" (owner, 14 Nov 2026)

**Status:** first cut rendered 14 Nov 2026, waiting for the owner's review (D-164).

## Brief (owner)
An introduction advert that shows the app and all its features: the best motion graphics, animation, camera moves,
design, visual and sound effects; a very good free voice-over; free sound libraries; cash rewards; the JAMB, WAEC and
NECO logos, said correctly. Owner has 50 Higgsfield credits (optional).

## Format
- 60 s, 1080 × 1920 (9:16) at 30 fps for WhatsApp Status, Instagram Reels, TikTok, YouTube Shorts and Play.
  A 16:9 cut follows from the same scenes if time allows.
- Music at 120 BPM: every beat is 15 frames, every bar is 2 s, so cuts and hits land on the beat.

## Script (voice: Kokoro "af_heart", Apache-2.0)
| Time | Line | Picture |
|---|---|---|
| 0.6 | Exam day is coming. | Dark, a countdown racing to 0 days, clock ticks |
| 2.0 / 2.75 / 3.5 | JAMB. WAEC. NECO. | The three real logos slam in on white cards |
| 4.1 | Are you ready? | Glitch type, riser, blackout |
| 6.25 | Meet SolutionTee CBT. | Drop: brand mark animation, phone flies in |
| 8.4 | Practise real past questions, with the real exam timer. | CBT screen in 3D, timer pops out, tap on an answer |
| 12.3 | See your JAMB score the moment you submit. | Score ring counts to 312/400, subject bars fill, confetti |
| 16.2 | Stuck on a question? Snap it. Your AI tutor explains it, step by step. | Camera flash, photo into chat, steps appear |
| 21.2 | No data? No wahala. Download, and practise offline. | Wi-Fi cut, download ring fills, "works offline" |
| 25.3 | Battle your friends live, in the Game Zone. | VS slam, beat-cut game screens |
| 29.4 | Join live challenges, and win cash prizes. | ₦ counter, gold coins raining, LIVE badge |
| 34.3 | Climb the leaderboard. Keep your streak alive. | Rank climbing, streak flame |
| 38.3 | Live classes. Real tutors. And a community that learns with you. | Three phones fan out |
| 44.2 | Everything you need to pass, in one app. | Isometric wall of every screen, camera fly-over |
| 48.4 / 50.5 | SolutionTee CBT. Learn. Think. Solve. | White end card, brand mark and wordmark |
| 53.0 | Download it free, today. | Google Play (text), cbt.solutiontee.com, logos, disclaimer |

Pronunciation is fixed with phonemes: JAMB /dʒæm/ ("jam"), WAEC /ˈweɪ.ɛk/ ("WAY-ek"), NECO /ˈnɛkoʊ/ ("NEH-koh").
Checked with speech recognition (heard as "Jam", "Wayak", "Necco").

## Sound (all made here, no licence risk)
- Original music: Afro-house/amapiano style groove written in code (kick, clap, shaker, log drum, sub, electric piano,
  pad, marimba hook), arranged to the edit: intro, build, drop at 6 s, energy lift at 25 s, lighter at 38 s, riser,
  final drop at 48 s, outro.
- Designed sound effects: clock ticks, logo slams, risers, whooshes, impacts, glitch, UI taps, camera shutter, coins,
  confetti pops. Free sound sites (Pixabay, Freesound) are blocked from this machine, so every sound is synthesised.
- Mix: voice compressed and EQ'd, music ducks under the voice, loudness −14 LUFS, peaks −1 dBTP.

## Pictures
- Real app screens: the website store-kit screens (captured at 3×) and the Flutter golden renders.
- Real brand files only: `/brand/exam-bodies/*.png`, `brand/solutiontee-loader-light.json` (the brand's own logo
  animation), `brand/solutiontee-wordmark.jpg`. Nothing redrawn.
- Google Play is written as text (no badge artwork, which is not in /brand).
- The disclaimer is on the end card. Cash prizes carry "Eligibility and terms apply."

## Files
- `video/` Remotion 4.0.539 project (`src/`, `public/`, `tools/` for voice, music, sound effects and mix).
- Output: `video/out/solutiontee-intro-9x16.mp4` (not committed; sent to the owner).

## Higgsfield (optional, owner's 50 credits)
Not needed for the advert. Prompts for 2 optional live-action inserts are in `video/README.md`.

## Test plan
- Watch every frame at the beat points (contact sheet of stills), check text inside safe areas (top 220 px and bottom
  320 px kept clear for app UI on Reels/TikTok), check loudness and that the voice is always clear over music.
