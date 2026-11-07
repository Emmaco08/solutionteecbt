# Big update 2 — owner's list of 2026-11-07

Each step ends with a phone test and the owner's approval word. The website deploys only on "deploy".

## Step A — Fixes and AI tutor upgrades (first)
| # | What | How |
|---|---|---|
| A0 | Mock leaderboard not reachable while students write | **Done**: a Leaderboard row on every live or ended challenge; "You are still writing" on the board |
| A1 | AI sets reminders ("remind me at 6pm to study Physics") | `remind` tool: the server saves a reminder, a push is sent at the time, and the reminders are listed in the chat |
| A2 | AI fails on long step-by-step answers | **Needs the screenshot again.** Plan: a larger answer allowance, "continue" when cut off, and a check that the steps reach the final answer |
| A3 | "Use the note titled … and quote it" shows a suggestion card only, even for a note that does not exist | The AI reads the real note (only notes the student's plan opens) and quotes it. If the note does not exist, it says so and does not invent one |
| A4 | A suggested note shows at the top | Note cards go at the end of the answer |
| A5 | Handwriting photos read badly | A two-step photo read: the vision model first writes out exactly what it sees, the student can correct it, then it solves. Better image quality sent from the phone |
| A6 | Search the internet for recent education news | A `web_search` tool (owner chooses the search service, below), with sources shown |
| A7 | Me → best JAMB score is sometimes blank | Read it from the server results (and challenges), not only the phone |
| A8 | Prompt injection / data leak attempts | Refuse politely and log them as strikes. 3 strikes in a day → no AI for 3 days (with the reason shown). Again after that → 7 days. Again → reported to the admin, who can ban the account or block it from AI |
| A9 | AI answers today's question before the student answers it | Hard lock: until answered, the AI gives the question only (no hints that reveal the option) |
| A10 | Off-topic replies are flat; "hello" is static | The AI writes a short, warm "I can't help with that" plus a study suggestion, without using a prompt. "Hello" gets a real AI greeting using the student's data |
| A11 | Improve "What next?" | Better follow-ups: practise this, quiz me, explain simpler, real-life example, past question on it |
| A12 | CBT pictures load during the exam | Download every picture before the test starts (progress shown); missing ones are retried |
| A13 | New accounts get all old notifications | Show only notifications sent after the account was created (plus personal ones) |
| A14 | "Start drill" from a lesson note asks for the topic again | Start the topic test at once with the note's topic |

## Step B — Ads with Google AdMob (first new feature)
- An admin **Ads level** (Off · Low · Medium · High · High Extra · Max · Ultra) and switches in Flags & settings. Read on app open, so no app update is needed to change it. **Premium = no ads at every level.**
- Formats:
  - **native ads inside lists** (look like a card);
  - **banners at the top under headers** (not the bottom);
  - **interstitials only at breaks** (after results, after a video, after a challenge, with caps and gaps);
  - **rewarded "Watch to unlock"** for free extras, always the student's choice, with a daily cap and then "Go Premium".
- **Red line: never during a running exam timer, the CBT question screen, or checkout.**
- Rewarded unlocks are checked **on the server** (AdMob server-side verification), so locked content is still only opened by the server.
- Personalised ads only for students 18+. Under 18 → non-personalised. Under 13 → child-directed. This needs a birth year (asked once).
- Admin report: impressions and rewarded unlocks per day. AdMob pays out.

## Step C — JAMB countdown
- On the first app open each day, a full-screen animated countdown: days to the UTME, today's goal, streak, and one motivational line. The admin sets the exam dates (UTME, WAEC, NECO).
- A small countdown chip stays on Home.

## Step D — Request a tutor
- An entry point in Study, Home (for weak students), the AI tutor ("talk to a real tutor"), results and Me.
- The student requests a tutor (subject, level, goals). The admin replies in an in-app chat and by email. A paid plan is bought in the app (Paystack). The tutor is assigned, then chat and call (WhatsApp / phone link) any time.
- Admin: requests, tutors, plans and prices, and conversations.

## Step E — Online classes
- The admin posts a class: title, teacher, time, platform and link, and who can join (Free · Premium · Paid, the paid ones with registration and payment).
- Reminders at 2 h, 1 h, 30 min, 10 min, 3 min and at the start, plus "you have not joined yet" 10 minutes in.
- Free students can see a Premium or paid class but cannot open it.
- Links are never shown: the app asks the server for the link at join time, and only for allowed students. See the platform question below.
- Future website payments (not built now) will add students to paid classes through the same table.

## Step F — Games (Study → Games)
Built first:
1. **Speed Quiz Duel**: vs the AI bot (Easy / Medium / Hard) or live vs a friend or a random student.
2. **Live Exam Arena**: a room of 20–50 students, the same question for everyone, points for speed, a live board.
3. **Beat the AI Tutor**: it gets harder with each right answer, 3 lives.

Real-time play uses Supabase Realtime. XP rewards and XP entry fees are applied on the server; questions come from the bank (Free years for free players). The other 7 games (Trivia Race, Maths Blitz, Word Clash, True/False Lightning, Last Student Standing, School vs School, Diagram Match) follow after these 3 work.

## Step G — Community (like X, education only)
- Posts with text, pictures and maths; comments, likes, shares and follows; a profile page and a "For you" feed.
- Premium posts are boosted in the feed.
- **Every post and comment is checked by the AI before it shows**; anything not educational is removed automatically, with an appeal.
- Mention **@solutiontee** and the AI answers in the comments.
- Report and block; admin moderation.

## Then — the rest of Big update 1
- **U4:** careers and subject combinations, more exams, custom test.
- **U5:** news v2, badges v2, leaderboards v2, fair-play tracking, resume any test.
- **U6:** automatic safety bans, emails, admin dashboard v2, navigation.

## Owner decisions needed
1. **Ads spec:** soft levels, hard levels with the 23 rewarded unlocks, or a mix (recommended).
2. **Web search service:** a key from Brave Search (2,000 free searches a month) or Tavily (1,000 a month). The owner adds it as an Edge Function secret, never in chat.
3. **Class platform:** see the recommendation in the chat.
4. **Order:** A → B → C → D → E → F → G → U4–U6 (as the owner asked: fixes first, ads first among new features).
