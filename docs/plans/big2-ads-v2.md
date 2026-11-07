# Ads v2 — a real money plan (Big update 2, step B, second version)

Owner's ask (2026-11-07): ads must make real money; levels must feel truly different (Low hardly noticed, Ultra very
heavy and very profitable); video ads; rewarded ads everywhere it makes sense (more AI prompts, XP, unlock a year);
ads on Home.

## 1. What the research says (rough numbers; our own AdMob reports will be the truth)
| Format | What it is | Pay per 1,000 views, Nigeria-type market (est.) |
|---|---|---|
| Banner | small strip | $0.10–0.50 |
| Native (card) | looks like our cards | $0.30–1.50 |
| Interstitial (full screen, mostly **video**) | at a break | $1–6 |
| App open | full screen when the app comes back | $1–4 |
| **Rewarded video** (student chooses, gets a reward) | 15–30 s video | **highest: ~$3–10** |

**Money comes mainly from video:** rewarded video first, then full-screen video interstitials and app-open ads.
Banners pay little. So v2 is built around **lots of rewarded video (always the student's choice) + video breaks**, with
banners/cards as filler.

Rough example: 1,000 free students a day. Medium ≈ 3 breaks + 2 rewarded + 10 banners each → about **$15–25/day**.
Ultra ≈ 3–4× that. Real numbers depend on how many students watch rewarded videos — that is why rewards must be
attractive.

## 2. AdMob rules we must keep (breaking them can close the AdMob account and lose all earnings)
- No break ad when the app first loads or when it exits; breaks only **between** screens/tasks; never on every tap.
- Never an ad right before/after an app-open ad, and never one ad on top of another.
- Rewarded ads are always opt-in, with a clear reward. **No cash or cash-like rewards** for watching ads, so XP earned
  from ads cannot be cashed out (it can still be spent in the app).
- Never during an exam, CBT or checkout (our red line stays).
- No ads that look like buttons or sit right next to buttons (accidental clicks are banned).
- Video ads inside our own video player (pre-roll) need Google Ad Manager + IMA, not AdMob. Instead: a **video break
  before and after** a video solution (allowed at a transition) and **watch to unlock** for Premium videos.
- Ultra can be heavy, but only within these rules.

## 3. New formats to add
1. **App open ad** (video/full screen) when a student comes back to the app after a while.
2. **Rewarded interstitial**: a video at a break with an "earn X — skip" countdown (e.g. after a test: "Watch to
   double your XP").
3. **Video breaks** around video solutions and lessons.
4. **Home**: a card ad in Home's feed and a banner under the top card (levels below).

## 4. "Watch to earn" (rewarded video, all levels, all server-verified)
| Reward | Rule (owner decides the numbers, Q1–Q3) |
|---|---|
| More AI prompts | 1 video = +2 prompts (now) |
| XP | 1 video = +N XP, daily cap; XP from ads can be spent, not cashed out |
| **Unlock a Premium year** | watch **N videos** → that exam/subject/year opens for **H hours** (progress bar, server counts) |
| Premium video solution / lesson | 1 video → watch that one video |
| Premium lesson note | 1 video → 24 h (now) |
| Full explanations in a test review | 1 video → explanations for that test |
| Double XP after a test | 1 video at the end of a test |
| Streak freeze | 1 video (now) |
| Ad break pass | 3 videos → no break ads for 1 hour (makes heavy levels bearable and adds rewarded views) |
Daily cap on rewarded videos per level; when the cap is reached: "Go Premium — no ads, everything open".

## 5. The levels, rebuilt (Premium = no ads at every level)
| | Low | Medium | High | High Extra | Max | Ultra |
|---|---|---|---|---|---|---|
| Feel | barely noticed | light | noticeable | heavy | very heavy | extremely heavy |
| Banners | none | Study, News | + Home, lists | + results, review, Me | everywhere allowed | everywhere allowed, 2 on long pages |
| Cards in lists | News only, 1 | every 8 items + 1 on Home | every 6, Home ×2 | every 4 | every 3 | every 2 |
| Break (video) ads | after every 3rd test, 2/day, 15 min apart | after every 2nd test + after videos, 4/day, 8 min | every test + video start/end, 8/day, 5 min | + after notes, quizzes, AI answers (every 3rd), 12/day, 3 min | + section changes, 18/day, 2 min | every natural break, 25/day, 90 s |
| App open ad | no | no | after 4 h away | after 1 h | after 30 min | every return (≥ 5 min) |
| Rewarded interstitial (skippable "earn" video) | no | after tests (double XP) | after tests + videos | + after AI answers | + every break offer | at every break |
| Rewarded videos per day | 5 | 8 | 10 | 15 | 20 | 30 |
Low is designed to keep students happy and still earn from opt-in rewarded videos; Ultra squeezes every allowed slot.

## 6. Build steps (after the owner's answers)
1. Server: new presets, reward kinds (xp, year unlock with progress, video, review, double_xp, ad_pass), year-unlock
   gate in the paper/question functions (server-side, like Premium), app-open and rewarded-interstitial settings,
   admin Ads page with the new rewards and numbers.
2. App: app-open ads, rewarded interstitials, video breaks, Home ads, "Watch to earn" buttons in the right places
   (AI quota, locked year, locked video, review, XP wallet, end of test), ad-pass, a "Watch to earn" hub in Me → XP.
3. Tests + emulator check; report per format and placement in admin (already logging loads).

## 7. Owner's answers (2026-11-07)
- Premium is only for money or XP. Ad offers ("watch to earn", rewarded video, server-verified):
  - **a locked year for 1 hour** — admin sets how many videos (default 1) and the minutes (default 60);
  - **XP** — admin sets "N videos → X XP" and a daily cap (start: 1 video → 5 XP, at most 20 videos a day). XP from ads
    is stored like bought XP: spendable in the app, never for cash-prize entries (AdMob: no cash-like rewards);
  - kept: **more AI prompts**, **Premium note 24 h**, **streak freeze**.
- No ad break pass. Ultra = the strongest AdMob allows.
- **AI tutor:** a banner for free users (level ≥ Low? → Medium and up), besides "watch for more prompts".
- **Age:** asked during sign-up (birth year, required), and existing students get a pop-up once (must answer to go on);
  used for personalised ads (18+), non-personalised (13–17) and child treatment (under 13).
- Needs from the owner in AdMob: an **App open** ad unit; server-side verification also on the **Rewarded
  interstitial** unit (same callback URL).
