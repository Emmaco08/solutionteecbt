# Big update — the owner's 17 fixes and ideas (after "XP4 ok", 2026-11-04)

Phase 5 has not started. This is one more round of changes inside Phase 4, split into **6 steps**.
Each step ends with a phone test and an approval word (`U1 ok` … `U6 ok`). The website deploys only when the owner says "deploy".

## 1. What is broken today (found in the code)

| # | Problem | Cause |
|---|---|---|
| 1 | The OTP boxes can't be typed into, only pasted | The boxes catch the tap and call `requestFocus()`. When the hidden field already has focus, Android does not open the keyboard again. The boxes are also narrow (8 across, 58 high). |
| 2 | The app tour freezes after step 4 of 5 | Step 5 points at the Upgrade card, which is below the screen. The tip card is placed off-screen, and the dark layer blocks every tap. |
| 5 | The Premium sheet has no way back | The sheet opens inside the tab, under the bottom bar. It has no close button, and the Pay button is hidden behind the tabs. |
| 13 | NECO says "Coming soon" | No NECO years are uploaded yet (JAMB 17, WAEC 2, NECO 0). The label will change to "No papers yet", and the admin can upload NECO years. |
| 13 | The quick test jumps between subjects | Quick mixes questions from all subjects in random order. |
| 14 | Bookmarks never save | The `bookmarks.ref` column is a UUID, but the app saves `note:<id>` and `exam/subject/year/q`. Every save is refused; 0 bookmarks exist. |

## 2. The steps

### U1 — Fixes, Home order, streak week (no owner decision needed)
- **OTP:** big boxes in two groups of 4 with a dash, a blinking cursor, and the real text field on top, so tap, typing, long-press paste and SMS autofill all work. Paste code stays.
- **Tour:** each step scrolls its target into view first and keeps the tip card on screen. Skip and Next always work. New look: a pulsing gold ring, a sliding tip card with an icon, a progress bar and a "Back" button. Two more steps: challenges and XP/streak.
- **Streak week:** done days show an animated flame. Missed days show a grey "snow/missed" icon with a small shake. A frozen day (streak saver used) shows ice. Today shows a glowing, flickering flame (or a pulsing ring until you practise). Future days stay empty. Respects reduce motion.
- **Home order:** 1) top card, 2) challenges, 3) Start a CBT practice, 4) question of the day, 5) invite friends, 6) news, 7) upgrade (free users only).
- **Top card:** if a test is unfinished, show "Continue where you stopped" (exam, subject, question 23 of 60, a time-left ring, Continue button). Otherwise show "Today" with a daily motivation quote (admin list, sample of 60 included) and today's goal progress.
- **Sheets:** every sheet opens above the bottom tabs, has a close (X) button, and closes with the phone's back button.
- **Bookmarks:** the database column changes to text. Notes, videos, novels, documents and questions all save.
- **NECO label** as above. **Quick test:** questions grouped by subject in order (Use of English first, then the student's subjects), with a subject bar on the screen.

### U2 — Payments inside the app, and automatic prize payouts
- **Card:** Paystack's official Flutter SDK (`paystack_flutter_sdk`, beta) opens Paystack's own secure payment sheet inside the app. No browser and no website. The student stays in the app.
- **Bank transfer and USSD:** our own screens, built on Paystack's Charge API. We show the account number to pay into (or the USSD code) in our design, with a countdown and "I have paid", and the webhook confirms the payment.
- **Honest note:** card details must be typed into Paystack's sheet, never into our own boxes. That is the card-security rule (PCI DSS). The sheet's look is Paystack's, so students may see the Paystack name there. Bank transfer and USSD can look 100% like our app.
- **Security:** the price comes only from the server. Each payment is checked with Paystack's webhook signature plus a verify call, and given only once. The reference is tied to the user and expires after 30 minutes. A fast-retry limit applies. The amount and currency must match exactly. The admin gets an alert for any mismatch.
- **Back button** on every payment screen. Leaving mid-payment is safe, and the payment is checked again later.
- **Automatic prize payouts:** Paystack Transfers. A winner adds a bank account once, and we check the name with Paystack ("Resolve account"). This needs a **registered Paystack business**, transfer OTP turned off, and money in the Paystack balance (owner, SETUP). The payout mode is the owner's decision (question 2).
- **Challenge rules:** a maximum number of players, plus a "minimum winning score". If 1st, 2nd or 3rd place scores below it, that place gets no prize.

### U3 — AI tutor v2
- **Education only:** a server check before the model refuses off-topic questions (for example football players) and points back to school subjects. Off-topic questions don't use a prompt from the daily allowance.
- **Memory:** the whole chat thread is sent each time (summarised when long).
- **Knows the student:** first name, exam, subjects, best and latest scores, weak topics, streak and plan, all read on the server. It can only see this student's own data, never another student's, and never keys or settings. Prompt-injection guard and output filter.
- **Agentic tools** (the server runs them, the AI asks): set a practice test ("10 hard Physics questions on motion"), explain today's question of the day, explain a question from a finished test, show my weak topics, make a study plan for the week, quiz me, and open a lesson note.
- **Dynamic suggestions:** chips made for each student from weak topics, the next exam, recent mistakes and today's question.
- **UI:** typing shimmer, streaming text, animated tool cards ("Building your test…"), a smooth chat entrance, and voice input (speech to text) if the phone has it. Every feature is checked end to end.
- An **"Ask AI to explain"** button on the question of the day and on review screens.

### U4 — Careers, subject combinations, more exams, custom test
- **Careers:** an optional career pick after the OTP and in Settings. The Study tab gets a **Career** section: what the job is, the path (secondary, JAMB, university course, after school), skills, top Nigerian universities, and earnings range. It also gets **Subject combinations**: the JAMB combination for my career first, then search all careers. The admin can add, edit and remove both (sample: 40 careers). The sample comes from the JAMB brochure format and must be checked by the owner against this year's brochure.
- **More exams:** the admin creates exams (Post-UTME, Common Entrance, etc.) with their own logo upload, years, subjects, time and number of questions, and can hide or remove them. They show in Test like JAMB, WAEC and NECO.
- **Custom test:** the student picks subjects, number of questions, time, difficulty (easy, medium, hard, mixed), and type (past questions, topic, wrong-before, unseen).

### U5 — News, badges, leaderboards
- **News v2:** a push notification on publish (admin switch per post), likes, comments (with report and admin hide; a word filter), saved posts, share to WhatsApp (link), reading time, related posts, and categories.
- **Badges v2:** the admin creates badges (rule, level, icon, reward). Rewards are XP, Premium days (1, 2, 7…) or cash (cash goes through the prize-claim flow). Harder tiers (bronze, silver, gold, diamond). An animated unlock moment. Sample: 30 badges.
- **Leaderboards v2:** weekly, monthly, yearly and lifetime, with old seasons removed. A separate challenges board. Top 10 rewards each week and month (rules in the admin, question 3).
- **Fair-play tracking on leaderboard exams:** leaving the app, time per question, copy and screenshot attempts, too-fast perfect answers, and patterns. This builds a risk score. Suspicious runs go to the admin, who can remove them from the board. Normal practice is never blocked, only tracked.
- **Resume any test** (all modes except challenges) from the Home top card.

### U6 — Safety, emails, admin dashboard, navigation
- **Automatic bans from many signals:** risk points for shared phones, clones, fair-play flags, many accounts, payment abuse, referral abuse and reports. A warning email comes first, then an auto-ban at the limit, all limits set by the admin. One flag alone never bans.
- **Emails:** new templates in the SolutionTee look with a moving GIF header (GIFs work in Gmail; CSS animation doesn't work in most email apps). New emails: warning, ban, phone ban, appeal answer, prize sent, badge reward, and the weekly winners. **Admin alert emails** for bans, fraud, payment mismatch, and payouts waiting.
- **Admin dashboard v2:** daily, weekly and monthly active users, new sign-ups, tests taken, AI use, revenue, retention, top subjects, countries and states (from the network, no GPS), devices, app versions, and when students study.
- **Navigation:** a search across the app (subjects, notes, past questions, careers), the phone's back button that works the same everywhere, a double back to leave, tab re-tap to scroll to the top, and quick actions on the app icon (Continue test, Ask AI).

## 3. Data changes (summary)
- U1: `bookmarks.ref` → text; `motivation_quotes`.
- U2: `payout_accounts`, `payouts`, `challenges.max_players` and `min_win_score`.
- U3: `ai_threads` and `ai_messages` (already partly there), `ai_tools_log`.
- U4: `careers`, `career_subjects`, `profiles.career_id`, admin-made `exam_bodies` with `logo_path`.
- U5: `news_likes`, `news_comments`, `news_saves`, `badges` v2 with rewards, `leaderboard_periods`, `attempt_signals`.
- U6: `risk_events`, `risk_rules`, `app_sessions` (country, version).

## 4. Tests
Each step adds DB tests (rolled back) and app widget tests (the OTP typing, the tour reaching step 5, sheets closing on back, bookmarks saving). `flutter analyze`, `tsc` and `eslint` stay clean.

## 5. Risks
- The Paystack Flutter SDK is beta. If it fails on the owner's phone, the card falls back to Paystack checkout in an in-app window with our own top bar and back button.
- Payouts need a registered business on Paystack plus a funded balance. Until then they stay manual.
- AI tools increase the model's cost per message. The admin sets the limits.
- Career and subject-combination samples must be checked by the owner. JAMB changes them yearly.
