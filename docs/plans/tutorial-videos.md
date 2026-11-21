# App tutorial videos (D-187)

Owner (21 Nov 2026): videos on how to use the app (how to sign up, use Community, use custom exams, and everything
students cannot easily find), in 9:16 and 16:9, showing the actual Android screens exactly as they are, with the best
voice-over, background music, animation and motion graphics.

## How the screens are made (exactly as in the app)

- A Flutter widget test (`apps/mobile/test_shots/tutorial_test.dart`) runs the real app router and real screens at
  Android phone size (390 × 844 logical, ×3 = 1170 × 2532), Android platform, sample data, Supabase pointed at a closed
  port (nothing reaches the live server).
- Each tutorial is a list of steps. A step opens a screen, taps a real widget or types into a real field, waits for the
  app to settle and saves a picture. Before each tap the test records the widget's exact rectangle, so the finger in
  the video lands where the student must tap. Output: `shots/tutorial/<name>/NN.png` + `steps.json`.
- Where a step needs the server (sending the sign-up code, posting), the next screen is opened the way the app opens it
  on success, so every picture is a real screen in the real order.

## Video pipeline

- Remotion composition `Tutorial` (`video/src/tut/`) driven by a spec per tutorial: steps (picture, tap rectangle,
  caption, voice line), intro card ("How to …"), numbered steps, outro (logo + next tutorial).
- 9:16: the phone large in the middle, step number + caption at the top, chapter progress bar.
- 16:9: the phone on the left, step title, short instruction and the step list on the right.
- Motion: screen changes slide like the app's own navigation, a finger tap with ripple on the recorded rectangle,
  camera push-in on small targets, typed text appears letter by letter where a field is filled, highlight rings.
- Voice: Chatterbox (MIT), one line per step, picked by speech recognition; the step lasts as long as its line.
- Music: a calm, friendly synthesised bed that dips under the voice; soft clicks on taps, swishes on screen changes.

## The videos

| # | Tutorial | Why students need it |
|---|---|---|
| 1 | Create your account (sign up, email code, set-up) | first thing, has several steps |
| 2 | Make a custom exam | owner asked; options are many |
| 3 | Use Community (post, photo, subject, reply, @mention, follow, report) | owner asked |
| 4 | Sit a full JAMB mock (start, navigate, calculator, flag, submit, result) | the core feature |
| 5 | Review your answers and corrections (history, review, explanations, bookmarks) | hidden behind results |
| 6 | Practise offline (download questions, videos and PDFs) | not obvious |
| 7 | Use the AI tutor (type, snap a photo, hint mode, follow-ups) | photo and hint mode are hidden |
| 8 | Play Game Zone (quick match, friend code, ranks) | many modes |
| 9 | Weekly challenges and the leaderboard | joining rules |
| 10 | Live classes (find a programme, enrol, join, reminders) | |
| 11 | Request a tutor | |
| 12 | Go Premium and redeem a code | payment steps |
| 13 | Invite friends and earn | hidden in Me |
| 14 | Study: past questions by year, videos, notes | |
| 15 | Settings that help (data saver, change subjects, notifications, dream career) | hidden in Settings |
| 16 | Careers and subject combinations | hard to find |
| 17 | Shortcuts and search (long-press the icon, search everything) | hidden |

Delivered in batches; batch 1 (videos 1–4) first for the owner's review of the style before the rest.
