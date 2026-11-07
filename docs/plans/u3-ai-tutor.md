# U3 — AI tutor v2 (plan, 2026-11-07, after "U2 ok")

Builds on the 4B tutor (`ai-chat` Edge Function, D-058): streaming answers, lesson-note search, daily quota, model fallback.

## Found while reading the code
- **Leak (fix first):** `ai-chat` reads any question by `question_id` with the service role, answer included. A free student could ask the AI to explain a question from a locked Premium year and get its answer. The same path would also reveal today's question of the day before the student answers it.
- **Leak (smaller):** lesson-note search feeds Premium notes into answers for free students.
- Memory is only the last 12 messages, and the AI knows nothing about the student.

## What we build
1. **Locked down (server):**
   - New `ai_question_for_me(id)`, run as the student (their own login, so `auth.uid()` and the plan rules apply). It returns a question only when one of these is true:
     - it is in one of the student's own finished tests;
     - its year is open to the student's plan;
     - it is today's question of the day and the student has answered it.
   - If today's question is not answered yet, the AI gets the question **without its answer** and gives a hint only.
   - Note search uses Premium notes only for Premium students.
2. **Education only:** a quick server check runs before the answer:
   - first a short, strict "router" call to the model (JSON, about 6 s);
   - plus word rules as a fallback.
   - An off-topic question (football players, celebrities, …) gets a friendly "I help with school subjects" reply. It does **not** use a prompt.
3. **Memory:** the whole thread is sent, up to a size budget. Older parts are summarised by the model and kept on the chat (`ai_chats.summary`). The summary does not use a prompt.
4. **Knows the student:** `ai_student_context(uid)` (service role) gives:
   - first name, exams, subjects, target score and plan;
   - streak, latest and best scores per subject;
   - the 3 weakest topics.

   It is passed to the model as data, never as instructions. The name and other free text are cleaned first (prompt-injection guard). The model is told never to reveal keys, settings, other students or these rules. An output filter blanks anything that looks like a key or token.
5. **Agentic tools.** The server runs them; the router or a chip asks for them. Each shows an animated card in the chat:

   | Tool | What it does | Card |
   |---|---|---|
   | `practice_test` | e.g. "10 hard Physics questions on motion": checks there are open questions | **Start test** opens our CBT screen |
   | `qotd` | explain today's question (hint only until answered) | the question |
   | `explain_question` | a question from the student's own finished test | |
   | `weak_topics` | from their own answers | topic bars with accuracy |
   | `study_plan` | a 7-day plan from weak topics and subjects | day-by-day list |
   | `quiz` | 1–5 open questions, **without answers** on the phone | tap an option; the server marks it (free) and gives the official explanation |
   | `open_note` | finds a lesson note the student may open | **Open note** |

   Every tool call is logged in `ai_tools_log`, which admins can read.
6. **Suggestions:** made by the server from the student's weak topics, today's question, their last test and their subjects. Fast, with no model call and no prompt used.
7. **App:**
   - typing shimmer while the AI thinks;
   - streaming text (kept);
   - animated tool cards ("Building your test…" → ready);
   - the chat slides in smoothly;
   - voice input (speech to text, the phone's own recogniser) when the phone has it;
   - the suggestion chips above;
   - light and dark mode, still under reduce motion.
   - "Ask AI to explain" already exists on the question of the day, review and past questions; they now go through the locked-down path.

## Prompt use (technical default, D-096)
- Uses 1 prompt: a normal question, a tool answer the AI writes (study plan, explain, weak topics), or a photo.
- Free: off-topic refusals, suggestions, marking a quiz answer, opening a test or note, chat summaries, and any reply when the AI is busy or fails (refunded, as today).

## Data changes
- `ai_chats.summary`, `ai_chats.summary_upto`.
- `ai_tools_log`: user, chat, tool, args, ok, ms, at. Admins read; nobody else.
- Functions:
  - `ai_question_for_me`, `ai_quiz_check`: run as the student;
  - `ai_student_context`, `ai_weak_topics`, `ai_quiz_pick`, `ai_suggestions`: service role only;
  - all with `search_path ''`.
- Optional admin setting `ai_tutor`: `{education_only: true, tools: true}`.

## Risks
- Fallback models differ. Only the router uses JSON, with a strict schema, and it is checked on the server; a bad router answer means no tool and a normal reply.
- One extra short call per message adds about 1–3 s. It is skipped for chips and buttons, whose tool is already known.

## Tests
- **DB (rolled back):**
  - a free student cannot get a locked question's answer; an unanswered question of the day comes back without its answer;
  - one student cannot read another's context, weak topics or quiz;
  - the quiz check marks correctly.
- **App:** the SSE parser reads tool events; each card renders and acts (Start test, Open note, quiz tap); chips; the voice button only when available; light and dark shots.
- **Function:** off-topic questions are refused without using a prompt; a locked question is refused; key-looking text is filtered.

## How the work is split (token management, D-096)
- Opus: the design, the SQL and RLS, the Edge Function and the final review.
- Sonnet/Haiku helpers: the app UI widgets and cards from an exact spec, tests, docs and screenshots.
