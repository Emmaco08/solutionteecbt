# Plan — XP (game coins) and better daily streaks

Status: **plan, waiting for the owner's decisions** (questions at the end). Nothing is built yet.
Decision log entry when built: D-081.

## 1. What the owner asked
- XP: earned for daily login, tests, mocks, challenges and events, and for top places on leaderboards.
- Spend XP: entry to challenges/events that cost XP (amount per challenge, set by the admin), and Premium (XP price per plan, set by the admin).
- Buy XP with money.
- The admin controls every number, and can switch XP off completely.
- Better daily streaks: a "claim" pop-up the first time the app opens each day, better animation and design, the student's photo on the welcome-back screen.

## 2. What the research says (short)
- **Streaks work through loss aversion.** Duolingo's team says people hold on much more strongly once they reach a 7-day streak; a **streak freeze** (miss a day without losing the streak) cuts drop-off for people about to lose it; small celebrations at **milestones** (3, 7, 14, 30 …) help more than constant noise. Risk: people do the smallest thing just to keep the streak, so the streak must need a little real learning.
- **Coin economies need "sinks" as well as "faucets".** Every way to earn XP adds coins; without enough ways to spend them, XP loses value (inflation). Good sinks are things people want and save up for (Premium, entries to events, streak freezes). Daily caps stop farming.
- **Google Play policy:** virtual currency is allowed and is sold as a consumable through Play Billing, **but** an app may not let users "wager, stake or participate using real money (including in-app items purchased with money) to obtain a prize of real-world monetary value". XP **bought with money** must therefore never be the entry fee for a **cash-prize** challenge in the Play app.
- **Nigeria:** after the Supreme Court judgment of November 2024, lotteries and paid-entry prize competitions are regulated by each state (for example Lagos); the old law also covered competitions of "skill and chance". Free entry (XP that can only be earned, not bought) keeps a cash challenge "no purchase needed". A lawyer should confirm before any money — directly or through XP — buys entry to a cash prize (this is already open item D-028).

## 3. The design

### 3.1 Two kinds of XP in one wallet
- **Earned XP** (from using the app) and **bought XP** (paid with money) are kept apart in the wallet; the student sees one total, with a small line "of which bought".
- Spending uses bought XP first where it is allowed, then earned XP.
- **Cash-prize challenges accept earned XP only** (recommended; see question 1). Premium, non-cash events and streak freezes accept both.

### 3.2 Ways to earn (defaults; every number and switch in the admin)
| Action | Default XP | Limits (anti-farming) |
|---|---|---|
| Daily claim (first app open of the day) | 10 | once per Lagos day |
| Streak bonus at 3 / 7 / 14 / 30 / 60 / 100 days | 20 / 50 / 100 / 250 / 500 / 1000 | once per milestone |
| Quick test / subject test finished | 5 | at least 10 questions and 2 minutes; 10 tests per day |
| Full mock (JAMB 4 subjects / WAEC / NECO paper) finished | 30 | 2 per day |
| Score bonus | +1 per 10% above 50% | — |
| Question of the day answered / right | 2 / +3 | once per day |
| Challenge or event finished (not disqualified) | 20 | once per challenge |
| Challenge top 1 / 2 / 3 | 200 / 100 / 50 | after the fair-play review |
| Weekly leaderboard top 1 / 2 / 3 | 300 / 150 / 75 | every Monday 00:05 Lagos |
| Friend counted (referral) | 50 | uses the referral rules |
| Daily cap on all earned XP | 300 | — |
- XP is only given by the server, once per action (a unique key per action), never by the phone.
- Second accounts on a phone, banned and phone-banned accounts earn nothing (`is_banned`).

### 3.3 Ways to spend
| Item | Default | Who sets it |
|---|---|---|
| Challenge / event entry | free unless the admin sets an XP fee on that challenge (e.g. 100 XP) | per challenge |
| Premium with XP | Monthly 3,000 XP · 3 Months 8,000 XP · Exam season 14,000 XP | per plan |
| Streak freeze | 50 XP each, hold up to 2 | admin |
- An entry fee is taken when the student starts (atomic, in Postgres) and refunded if the challenge is cancelled. No refund after a disqualification.

### 3.4 Buying XP (packs; prices are the owner's decision — question 3)
| Pack | Default price |
|---|---|
| 200 XP | ₦200 |
| 550 XP | ₦500 (+10%) |
| 1,200 XP | ₦1,000 (+20%) |
| 3,200 XP | ₦2,500 (+28%) |
- Website and direct app: Paystack (same verified, idempotent payments as Premium). Play app: Google Play consumable products (needs Play Console).
- Bought XP never expires; it is not refundable once spent; refunds of unused packs follow the payment refund rules (the XP is taken back).
- Buying Premium with bought XP must cost more than paying for Premium directly (3,000 XP ≈ ₦2,500 > ₦1,500), so XP never undercuts plan prices.

### 3.5 Streaks, made better
- **What keeps the streak:** recommended — answering **at least one question** (any test, practice or question of the day) that Lagos day; opening the app alone gives the daily XP but not the streak (question 2).
- **Daily claim pop-up:** the first time the app opens each day, a sheet slides up: the student's photo, the flame with the streak number, this week's 7 days (today pulsing), today's reward ("+10 XP"), the next milestone ("4 days to your 7-day bonus"), and **Claim**. Claiming plays a short coin burst into the XP chip at the top and a gentle vibration. Shown once a day; if dismissed, a small "Claim +10 XP" chip stays on Home until claimed (no XP is lost that day).
- **Streak freeze:** if a day is missed and a freeze is held, it is used automatically and shown the next day ("Your freeze saved your 12-day streak"). Buy freezes with XP.
- **Milestones:** 3, 7, 14, 30, 60, 100 days — a full-screen celebration (confetti, the flame growing, the bonus XP), shared as an image (screenshots allowed outside tests).
- **Streak repair:** within 24 hours after losing a streak, restore it for 200 XP (admin price, can be turned off).
- **Reminders:** the existing evening streak reminder also says how much XP is waiting.
- Respects "reduce motion" (no bursts, simple fades) and holds 60 fps on a 3 GB phone (no blurs; Rive/Lottie only if a free-licensed file is used, otherwise flutter_animate).

### 3.6 Welcome-back screen (the screenshot)
- The student's **photo** (or initials if none) in a gold ring that fills to show today's progress, with a soft glow.
- The flame grows with the streak (small → medium → big at 7 / 30 / 100 days) and flickers gently.
- The week row: done days filled with a flame, today pulsing, a freeze day shown with a snowflake.
- XP balance and today's reward; the **Claim +10 XP** button with the coin burst; then **Start practising**.
- Staggered entrance (photo, greeting, card, button), 200–400 ms ease-out, as in the design rules. The empty dark area in the screenshot is filled by the XP and milestone card.

### 3.7 XP switched off
- One switch (Admin → XP & streaks → "XP is on"). Off: no XP chip, no claim pop-up XP (streak still works), XP prices hidden, challenge XP fees ignored (entry free), "Pay with XP" hidden, packs not sold. Balances are kept, so switching back on restores them.

### 3.8 Admin → XP & streaks (new page)
- On/off switch; every earn amount, cap and limit; streak milestones and bonuses; freeze and repair prices; Premium XP prices per plan; packs and prices; weekly leaderboard prizes.
- Totals: XP given vs spent per day (faucet / sink chart), bought XP sold, top earners.
- A student's wallet and history (search); give or take XP with a reason (logged in the audit table).
- Each challenge gets "Entry fee (XP)" in its form.

### 3.9 Data (server)
- `xp_ledger` (append-only: user, amount ±, kind earned|bought, reason, reference, unique key) and a balance on the profile kept in step by the same transaction; `xp_settings` in `app_settings.xp`.
- Functions: `xp_claim_daily()`, award inside the existing finish-test / challenge / question-of-the-day / referral functions, `xp_spend(item)`, `xp_buy_start(pack)` (Paystack, like `pay_start`), weekly leaderboard job (pg_cron), `admin_xp_*`.
- Streak table gains freezes and repair; the current streak rule moves to the server where it is not already.

### 3.10 Tests
DB: claim once per day; caps; no XP for banned / second accounts; spend is atomic (no negative balance under two taps at once); bought XP refused for a cash-prize entry; Premium with XP; XP off hides prices and makes fees free; weekly prize once; pack purchase gives XP once (webhook replay). App: claim sheet, wallet, pay-with-XP confirmation, reduce-motion version.

## 4. Steps (each checked by the owner on the phone)
1. **XP core:** ledger, settings, earn rules, daily claim, wallet screen, admin XP page. (`XP1 ok`)
2. **Streaks and welcome-back:** claim pop-up, new animations, freezes, milestones, repair, photo. (`XP2 ok`)
3. **Spending:** challenge XP fees, Premium with XP, weekly leaderboard prizes. (`XP3 ok`)
4. **Buying XP:** packs with Paystack (Play later). (`XP4 ok`)

## 5. Risks
- Inflation if earning is too generous → caps, sinks and the admin's numbers; the faucet/sink chart shows it early.
- Legal: money → XP → cash prize. Avoided by rule 3.1 until a lawyer says otherwise.
- Farming with fake accounts → XP only for the first account on a phone, caps, minimum test length.
