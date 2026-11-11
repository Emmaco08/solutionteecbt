# Plan — B. Engagement (owner: "Let's move to B. Engagement", 2026-11-11)

Built in this order, one commit each, tests and docs with each. Owner decisions are marked **Owner**; everything else
uses a sensible default logged in DECISIONS.md.

## B7 — News v2 (D-141)
Already there: push per post with an on/off switch (notify), categories, reading time.
- DB: `news_likes`, `news_saves` (own rows), `news_comments` (500 letters, 5 a minute / 30 a day, banned students
  cannot write), `news_comment_reports` (3 reports hide a comment until staff look), `news_posts.comments_on`.
  RPCs: `news_meta(ids)` (likes, comments, liked, saved), `news_comments_list(post)` (first name + initial only).
- Admin: comment counts and a Comments switch per post; News → Comments page (reported first; hide, show, delete).
- App: like (animated heart), save, share to WhatsApp (falls back to copy), comments with report and delete-own,
  category chips + Saved on the list, related posts (same category first).

## B8 — Badges v2 (D-142)
- DB: `badges` (name, description, icon, metric, bronze/silver/gold/diamond targets, reward per tier: XP, free
  Premium days, cash), `user_badges` (tier reached, when, reward given). Metrics are counted on the server from
  existing data (streak, tests, correct answers, best JAMB score, full mocks, lessons read, AI chats, challenges,
  referrals, night/speed). A check runs after each submitted test and daily; rewards are paid once per tier.
- Cash rewards go through the existing prize-claim flow and follow the cash-prizes switch (off: cash tiers give
  nothing until it is on). **Owner:** reward amounts — samples use XP and a few Premium days only.
- Admin: Badges page (add, edit, pause, see how many students hold each tier).
- App: Me → Badges grid with tier colours and progress; full-screen animated "Badge won" moment (reduce-motion
  respected); 30 sample badges replace the 8 fixed ones (same 8 kept as part of the 30).

## B9 — Leaderboards v2 (D-143)
- Weekly, monthly, yearly and all-time boards for JAMB full mocks (same fair rules and holds as today), plus a
  Challenges board (points from challenges). Africa/Lagos weeks start Monday.
- Top-10 rewards each week and month, set in admin (XP, Premium days; cash only when cash prizes are on), paid by a
  job after the period closes and after held runs are reviewed. **Owner:** reward amounts (defaults: XP only).
- App: period tabs on the leaderboard, "My place" card, past winners.

## B10 — Fair-play tracking (D-144)
- App sends per leaderboard exam: times it left the app, screenshot attempts, time per question, answers under
  3 seconds. The server turns them into a risk score (0–100) next to the existing too-fast check.
- Risky runs are held off the boards and listed in Admin → Leaderboard for keep/remove. Practice is never blocked.

## B11 — Automatic safety bans (D-145)
- `risk_events` with points: shared phone, cloned app, fair-play flags, many accounts, payment abuse, referral abuse,
  reports. Points fade after 90 days.
- Warning email at the warning level, ban at the ban level (both set in admin; one kind of flag alone never bans).
  Ban uses the existing ban, appeal and email flow. Admin alert emails: bans, fraud, payment problems, payouts waiting.
- **Owner:** warning and ban levels (defaults: warn at 40, ban at 80, off until switched on).

## Risks
- Comments are public text from students: rate limits, reports, hiding, and staff moderation; no links allowed.
- Rewards cost money: all cash paths stay behind the cash-prizes switch and admin approval.
- Auto-ban mistakes: starts switched off, never from one flag kind, every ban can be appealed.
