# U3b — AI tutor, bigger upgrade (owner phone test, 2026-11-07)

## Bugs from the phone test
- "Give me jamb mock test", "set a Jamb test", "jamb 2004 questions" → "could not find the topic 'mock test' / 'test' / 'school' in Physics":
  - the router put filler words in the topic;
  - nothing could start a full mock;
  - the year was ignored;
  - the subject was guessed (Physics).
- Fix:
  - filler words ("test", "mock", "questions", "JAMB", "school", years…) are removed from topics;
  - new **mock exam** tool (full JAMB / WAEC / NECO, real questions, our CBT);
  - a **year** is understood ("2004");
  - when the subject is unclear, a **subject picker** card appears instead of a guess.

## Feature research
Based on what leading tutor apps offer: Khanmigo (Socratic hints), Photomath (step reveal), Duolingo Max ("Explain my answer", role-play), Gauth / Brainly (snap-and-solve, follow-ups), Socratic by Google (topic cards), and ChatGPT / Gemini (reactions, reply, copy, regenerate).

What we add:
1. **Hint ladder:**
   - hint 1 → hint 2 → step-by-step → full answer;
   - plus "Check my working": the student types their attempt and the AI marks it;
   - the hint level shows as dots.
2. **AI-made questions:**
   - the AI writes new practice questions on any topic (with answers kept on the server);
   - the chat quiz is marked on the server, as with real past questions.
3. **Quiz v2:**
   - one question at a time, with a progress bar and an animated right/wrong reveal;
   - a score screen with confetti;
   - "Try the wrong ones again", "More like this" and "Explain with AI".
4. **Mock exam and year papers:** "Take a full JAMB mock" opens our real CBT mock; "JAMB 2004 Physics" builds that year's paper.
5. **Knows the app:**
   - the AI knows every SolutionTee feature;
   - "take me to the leaderboard" (also challenges, past questions, notes, XP…) shows an **Open** card.
6. **Follow-up questions:** after each answer, 3 tappable "what next" questions written by the AI (free).
7. **Curious suggestions:**
   - continue your last chat;
   - your weak topics;
   - "most students miss this topic this week" (counted across all students, no names);
   - a surprising fact in your subject;
   - today's question;
   - a full mock.
8. **Message actions:**
   - react with ❤️ 👍 😂 😮 🙏 (saved, also used as feedback for the admin);
   - reply to a message (it is quoted);
   - copy;
   - select any text;
   - "Ask again".
9. **Motion:**
   - an animated welcome (floating sparkles, the greeting typed in, cards rising in);
   - agent steps with ticks ("Reading your results ✓ → Picking questions ✓ → Ready");
   - smooth cards;
   - all of it still with reduce motion.

## Prompt use
- 1 prompt: AI-written answers and AI-made questions.
- Free: mock and year tests, open-screen cards, reactions, follow-ups and suggestions.

## Split (token management)
- Lead: server and SQL.
- Sonnet helper: app UI and tests, then checked by the lead (tests, analyze, shots at 360 px in light and dark).
