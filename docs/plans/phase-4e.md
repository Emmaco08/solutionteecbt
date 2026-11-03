# Milestone 4E — Question of the day, leaderboard, challenges, referrals, winners wall

Approved design: prototype screens `home` (question of the day card, challenge cards, "More for you"), `leaderboard`,
`compete`, `challenge`, `challenge-play`, `challenge-dq`, `challenge-result`, `challenge-winners`, `claim-prize`,
`winnings`, `referral`, `winners-wall`, `banned`, `device-taken`, `unsafe-app`. Rules: D-026, D-028 to D-033, D-037, D-041.

4E is large, so it is built in **three parts**. Each part ends with a short report and a stop for the owner to try it
on the phone (reply `4E1 ok`, `4E2 ok`, `4E3 ok`). After 4E3: the Phase 4 report and STOP for `PREMIUM APPROVED`.

Everything is decided on the server: who answered right, scores, ranks, winners and rewards. The app only shows them.

---

## 4E1 — Question of the day + leaderboard

**Database**
- `qotd` (date, question_id, subject, exam): one question per day, scheduled by the admin; if a day has none, the
  server picks a free-year question from the student's subjects (so Free students never see locked content).
- `qotd_answers` (user, date, choice, correct, answered_at): **one attempt** (unique user + date); marked on the server.
- RPCs: `qotd_today()` (question without the answer until answered), `qotd_answer(choice)` (marks, returns right/wrong,
  explanation, % right today, streak), `qotd_streak`.
- `leaderboard_settings` in `app_settings`: on/off (**off by default**, D-026), visible years, minimum full mocks to
  qualify, name format (first name + initial; never full names, many students are minors).
- `leaderboard(exam year, scope nigeria|state)`: built from **server-scored full JAMB mocks only**; best score, then
  fastest; top 50 + the student's own rank pinned. Students can hide themselves (Settings switch, `profiles.hide_on_leaderboard`).
  Suspicious attempts (too fast or too perfect) are left out and listed for review.

**App**: Home question-of-the-day card → QOTD screen (countdown to the next one, one attempt, result, % right,
explanation with LaTeX, Ask AI); Leaderboard screen (podium, ranks, Nigeria / My state, rules sheet), hidden when off.
**Admin**: Question of the day (schedule a question per day from the bank, see answers and % right);
Leaderboard settings (on/off, years, qualification, review list).
**Tests**: DB tests (one attempt, no answer before answering, locked questions never served, leaderboard ranking,
hidden students, off means empty); widget test for the QOTD card.

## 4E2 — Challenges & events + fair play + prize claims + winners wall

**Database**
- `challenges` (title, kind cash|event|practice, starts_at, ends_at, seconds_per_question, prizes 1st/2nd/3rd,
  reward Premium days or badge, allowed exits 0–3, status), `challenge_questions` (written new or picked from the bank).
- `challenge_entries`: **one per student** (unique challenge + user), created when the first question is served;
  answers marked on the server one question at a time (the next question is only sent after the last is answered or
  timed out, so the whole paper is never on the phone); exits recorded; disqualified when exits > allowed.
- **Ranking on the server**: best score, then fastest total time, then who started earlier (D-030).
- **Close** (pg_cron every minute, or admin "Close now"): ranks are frozen, winners saved, push + in-app "You won ₦X".
- `prize_claims`: winner sends account name, bank and 10-digit account number within 7 days (never PIN, card or
  password); under-18 winners give a guardian's details. Admin marks paid and uploads the transfer receipt
  (account number and balance hidden) → `winners_wall` post (first name + initial, state, place, amount, receipt).
- Fair-play review flags: answers too fast or too even, identical answer patterns, same device on two accounts.

**App**: Home challenge cards (live, coming up with "Remind me", calm empty state); Test → Challenges & events;
challenge page with rules and the required agreement; play screen (one question at a time, per-question timer);
**anti-cheat**: leaving the app (going to the background, split screen, notification shade opened over it) submits and
disqualifies, after the allowed exits; screenshots and screen recording blocked (`FLAG_SECURE`) on challenge screens;
copying blocked; result with live rank and "How winners are decided"; winners screen; claim form; My winnings in Me;
Winners wall.
**Admin**: Challenges (create, questions, schedule, prizes, fair-play switches, close now), live entries, fair-play
review queue (keep disqualified / reinstate), winners to pay, claims, receipt upload → winners wall.
**Tests**: ranking + tie-breaks (unit and DB), one entry per student, no question sent early, exits → disqualified,
automatic close and winners, claim only by the winner, RLS on claims (bank details: owner role only).

## 4E3 — Referrals + one account per person + bans

**Database**
- Each student gets a referral code (e.g. `TOLU-7K3P`); the sign-up form already sends it (`referral_code` in the
  user's sign-up data).
- `referrals` (referrer, friend, status pending|counted|blocked, reason). A friend **counts** when their email is
  verified and they finish one practice test **on a different phone** from the referrer (admin can switch to "buys Premium").
- Rewards from Admin → Referrals (defaults D-031): 10% off per counted friend, 10 friends = free 3-month Premium,
  30 friends in total = ₦5,000 cash (paid by the admin after review, like prizes); monthly cap. The discount is applied
  by the server in `pay_start` (like promo codes).
- **Device check**: the app sends a device id (Android ID, hashed); one account per device for rewards and prizes;
  "This phone is already used by another account" screen (`device-taken`).
- **Bans**: admin bans a student (and linked accounts on the same device); ban screen with one appeal within 14 days;
  unpaid rewards and prizes cancelled. Everything goes to the audit log.

**App**: Invite friends (code, WhatsApp share, discount meter, cash progress, friends list with Pending / Blocked);
entry points on Home and Me; ban and device-taken screens. **Admin**: Referral rules (live preview), rewards due,
top referrers, Fraud & bans.
**Tests**: friend counts only once and only on another phone, self-referral blocked, reward steps, discount applied by
the server, banned student cannot use the app's data.

---

## Assumptions (sensible defaults; logged in DECISIONS when built)
1. **No paid entry** for challenges in 4E. Entry is free. Paid entry may need a gaming licence (D-028), so it waits for a lawyer.
2. **Prize and referral cash are paid by hand** by the admin (bank transfer), then the receipt is uploaded. Automatic
   Paystack Transfers can come later (Paystack needs extra business checks for transfers).
3. **No SMS phone check yet.** D-031/D-032 count a friend after a phone-number OTP; SMS costs money and needs a provider.
   Until the owner chooses one, a verified email + a different phone (device id) + a finished test is used.
4. **No Play Integrity yet** (it needs Play Console). Until then: screen capture blocked, leaving the app detected,
   emulators detected with Android's own build details, and the server's fair-play flags.
5. Leaderboard starts **off** in production (D-026); the owner switches it on in the admin.

## Risks
- Cash prizes to minors and gaming rules (D-028): legal review before the first real cash challenge.
- Anti-cheat on Android cannot stop a second phone; the server's flags and the review before paying are the main protection.
- Size: about 3 new admin pages per part; each part is committed and deployed separately.

## Test plan (phone)
- 4E1: answer today's question once, see % right and the streak; try again → "already answered"; leaderboard on → your rank.
- 4E2: a test challenge starting in 2 minutes; play; leave the app → disqualified; second account plays properly →
  closes → winner push → claim form → admin uploads receipt → Winners wall.
- 4E3: invite a second account on another phone; it finishes a test → counts; discount shows at checkout.
