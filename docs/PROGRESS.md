# Progress (docs/PROGRESS.md)

Legend: `[x]` done · `[~]` in progress · `[ ]` not started · `[!]` blocked on owner

## Phase 0 — Environment & repo setup  (approval: `SETUP APPROVED`)
- [x] Read CLAUDE.md and SPEC.md
- [x] OS detected: Windows 11 Pro (10.0.26200), 4 CPU cores, 7.9 GB RAM
- [x] Tool check done (see SETUP.md §1)
- [ ] Owner installs missing tools: Flutter, JDK 17, Android cmdline-tools, Supabase CLI, scrcpy (+ adb on PATH)
- [!] **Free disk space**: C: has only ~5.4 GB free (98% full)
- [x] Monorepo folders created
- [x] git initialised, `.gitignore` files added
- [x] PHASES.md, PROGRESS.md, DECISIONS.md, SETUP.md created
- [x] Brand check done
- [x] Exam-body logos provided (2026-10-24)
- [!] Missing: full logo / wordmark ("SolutionTee CBT" lockup), high-res mark
- [!] Owner answers to pre-design questions
- [ ] Owner confirms phase split in PHASES.md

## Phase 1 — Design system & prototype  (approval: `DESIGN APPROVED`)
- [x] Plan: `docs/plans/phase-1.md`
- [x] `design/tokens.json` (+ generator `design/scripts/gen-tokens.mjs`, all text/background pairs pass WCAG AA in light and dark)
- [x] Vendored KaTeX, Phosphor Icons, lottie-web light, Plus Jakarta Sans 500/700 (~1.3 MB total)
- [x] Static server `prototype/serve.mjs` (serves only prototype/, design/, brand/)
- [x] App prototype: 39 routed phone screens (plus 5 onboarding slides, 3 setup steps and sheets/dialogs for palette, calculator, submit, time-up, share, paywall), clickable flows, light/dark, reduce motion
- [x] Admin CMS: dashboard, question editor (live KaTeX), CSV import validation, tabs manager, plans & limits
- [x] Checked in the browser: splash Lottie, onboarding, setup, home, CBT (passage, maths, palette), results, AI streaming, paywall, dark mode, phone width, admin pages
- [x] Exam-body logos added by owner (brand/exam-bodies/jamb.png, waec.png, neco.png) and shown on all exam cards, headers and results
- [x] Feedback round 1: exam-body logos added (D-013)
- [x] Feedback round 2: bare JAMB logo on Test hero (D-014), official Google G (D-015)
- [x] Feedback round 3: student images: AI photo questions + profile photo (D-016)
- [x] Feedback rounds 4–9: tour/modes/premium fixes, news, leaderboard, QOTD, challenges, anti-cheat, Free vs Premium rules, referrals, anti multi-account, winners wall, security plan, skeletons, offline strip, QA pass
- [x] Feedback round 10: no "3 years free" badge, challenge result fixed, Challenges & events on Home (live / next / none), notifications screen, test history, bookmarks, checkout shows the amount once, admin CMS redesign + 8 new admin pages (D-037 to D-040)
- [x] Feedback round 11: roomier challenge cards on Home (D-041)
- [x] Owner tested and sent feedback (11 rounds)
- [x] `DESIGN APPROVED` (2026-10-26) → `docs/design-spec.md` written and committed

## Phase 2 — Backend & CMS core  (approval: `BACKEND APPROVED`)
- [x] Plan written (`docs/plans/phase-2.md`); company details recorded (`docs/COMPANY.md`); wordmark saved to `/brand`
- [x] Hosted Supabase dev project `solutiontee-dev` (eu-west-2, Free plan) created through the Supabase connector
- [x] 8 migrations applied: schema, rules + RLS, RPCs, reference data, R2 image access, performance fixes, admin helpers, staff reads need 2-step
- [x] RLS suite: **68/68 pass** on the live dev DB (rolled back); public-API student check **15/15**; banned student refused at sign-in
- [x] CSV parser/validator (`packages/shared`): **25/25** unit tests
- [x] Admin website (`apps/web`, Next.js 16 + Tailwind 4 + shadcn/ui on design tokens): login, first-run super admin, 2-step (TOTP) enrol + verify, invite/reset links
- [x] Admin pages: dashboard (real counts), question bank (filters, bulk publish), question editor (live KaTeX, R2 images), passages, CSV import (map, check, server dry run, import, undo), exams & years, news, users (Premium grant/revoke, ban), plans, Free vs Premium, onboarding, tabs, flags & settings, staff (invite by Brevo email), audit log
- [x] Browser-tested end to end on the dev DB with a temporary QA admin and student (both deleted after; database left empty for the owner)
- [x] `eslint` 0 errors, `tsc` clean, `next build` passes
- [x] Owner: R2 bucket stays private (D-049); support email `support@mail.solutiontee.com`; transparent logo added to `/brand`
- [x] Email services (owner's condition for approval): sign-up code, resend, forgot-password code, password-changed notice, welcome email, staff invites, all sent through Brevo with branded templates and DB rate limits (D-050, `docs/AUTH_EMAIL.md`)
- [x] Email flows tested end to end through the real API in log mode (sign-up → code → confirm → welcome once → forgot → code → new password → notice; limits; existing-account answers). Brevo account and `mail.solutiontee.com` senders checked (read-only)
- [x] Admin **Emails** page: Brevo status, verified senders, sends in the last 24 h, template previews, "Send me a test email"
- [x] `BACKEND APPROVED` (2026-10-27, conditional on the email services, now done)
- [ ] Owner: create the first super admin; press *Send me a test email* on the Emails page; in Supabase set Email OTP length 6 and expiry 600 s (SETUP §7.10)

## Phase 3 — Mobile app core  (approval: `APP CORE APPROVED`)
- [x] Plan: `docs/plans/phase-3.md`
- [x] Toolchain on the laptop: Flutter stable, JDK 17, Android command-line tools (no emulator, no Android Studio)
- [x] Server: attempts tables + `submit_attempt` (server re-marks, idempotent), account deletion API, image-link API `/api/images/sign`
- [x] App: splash, welcome, onboarding (server slides), sign-up/login/verify code/forgot/reset, 3-step profile setup
- [x] App: tabs from the server, maintenance and force-update gates, Home (continue card, exam cards, news, plan badge)
- [x] App: Test hub and setup (modes, subjects, years with server locks, timed switch)
- [x] App: CBT screen (timer with warnings, subject tabs, passages, LaTeX, palette, flag, calculator, autosave, resume, auto-submit, FLAG_SECURE)
- [x] App: results (score /400, per subject, weak topics, confetti) and review with filters and explanations
- [x] App: Me, history, settings (theme, reduce motion, data saver), help, about/terms/privacy, delete account, log out
- [x] Tests: scoring, exam clock, calculator, widget tests (onboarding, sign-up consent, CBT answer/flag/submit): 18/18 pass. `flutter analyze` clean
- [x] Dev sample papers (`supabase/seed/dev-sample-questions.sql`, `[SAMPLE]`, dev project only)
- [x] Debug APK builds on the laptop (2026-10-29, first build ~40 min because of downloads; later builds reuse the cache)
- [x] App matches the approved prototype screen by screen (D-052); checked side by side in light and dark
- [x] Run on the owner's Samsung Galaxy A16 (Android 16) over USB: sign-up with email code, setup, tour, Home, CBT test, results, review, Me, log out. Owner: "the test i did is perfect"; fixed on device: start-up crash, code-screen crash, reversed lists, sign-up loop, tour targets, log-out wipe, welcome circles, State required
- [x] Owner approval: `APP CORE APPROVED` (2026-10-30)

## Phase 4 — Study, premium, payments, AI  (approval: `PREMIUM APPROVED`)
Plan: `docs/plans/phase-4.md`.
- **4A Study + Premium gating**
  - [x] Database: `study_items`, `study_catalog` / `study_item` / `study_file_key` (server decides Free vs Premium), bookmarks, study progress. RLS tests 21/21 (`supabase/tests/study.test.sql`)
  - [x] Website: `/api/study/file` (signed R2 link only after the plan check), uploads for videos (`v/`), PDFs (`d/`) and covers (`s/`)
  - [x] Admin: Study content (list by kind, add/edit form per kind, video and PDF upload with progress, maths preview, novel chapters, soft delete). Teachers may edit. `next build` passes. Not yet clicked through by the owner (needs the owner's 2-step login)
  - [x] App: Study hub (sections from the admin), past questions browse + study mode, video solutions / lessons + player, lesson notes + reader, novels + detail, syllabus & brochure + PDF viewer, bookmarks, search, Downloads (saved past papers), paywall sheet (benefits from the Free vs Premium rules, SAMPLE prices)
  - [x] Tests: `flutter analyze` clean, 23/23 tests (4 new: paywall benefits, prices, paywall sheet, note renderer); light/dark renders of 12 Study screens
  - [x] [SAMPLE] study items in the dev database (`supabase/seed/dev-sample-study.sql`)
  - [ ] Phone walk-through
  - [x] Video thumbnails, full video player, per-video locks, Markdown notes with pictures, novel PDFs, faster notes (D-056, D-057)
  - [ ] Saving videos and PDFs on the phone for offline use (Downloads lists saved past papers for now)
- **4B AI tutor** (plan: `docs/plans/phase-4b.md`)
  - [x] Database: providers and models managed in the admin, keys in Supabase Vault (only the last 4 characters shown), versioned system prompt, own chats and messages, Lagos-day quota (Free 3, Premium 100, 6 a minute), health log, answer cache, pgvector knowledge. Tests 28/28 (`supabase/tests/ai.test.sql`)
  - [x] Edge Function `ai-chat`: streams answers; photos go to image models only; falls back to the next model when one is busy or slow; hides model "thinking"; finds matching notes; gives the prompt back when every model fails. Live: text 1.8 s to first words / 4 s total, photo 3.7 s / 4.7 s
  - [x] Edge Function `ai-index`: builds knowledge from published notes (admins, 2-step)
  - [x] Admin → AI tutor: providers and keys, models (order, purpose, settings, Test), prompt versions, knowledge rebuild, 24 h health, answers marked wrong. Live at admin.solutiontee.com
  - [x] App AI tab: streaming chat in the prototype design, photo questions, hint mode, subjects, copy, report, quota chip and countdown, past chats, "Ask AI" from Study and Review. 28/28 app tests, analyzer clean
  - [ ] Owner: press "Add new and edited notes" in Admin → AI tutor → Knowledge (builds the knowledge from the 360 notes)
  - [ ] Phone walk-through
- [x] Test APK download page for the team: admin.solutiontee.com/download (private R2 + 10-minute link, D-059)
- **4C Payments** (plan: `docs/plans/phase-4c.md`, D-061, D-062) — **owner: "4C ok" (2026-11-03)**
  - [x] Database: payments, payment timeline, redeem codes and redemptions, server-only grant / confirm / refund, rate limits, admin lists. Tests **58/58** (`supabase/tests/payments.test.sql`, run on the dev DB, rolled back)
  - [x] Edge Functions deployed: `paystack` (start, check, admin refund), `paystack-webhook` (HMAC-SHA512 + verify), `play-verify`, `play-rtdn`. Helper tests 7/7 (`node --test supabase/functions/_shared/paycrypto.test.mjs`). Live check: unsigned or logged-out calls are refused
  - [x] Admin: Payments (filters, totals, timeline, check again, refund), Redeem codes (shared or unique batches, pause, CSV), Play product ID reminder on Plans. `tsc` clean, `eslint` 0 errors. Live at admin.solutiontee.com (deployed 2026-11-03 from the cloud session)
  - [x] App: checkout, checking payment, success, Redeem a code, paywall → checkout, Google prices in the Play build; `direct` / `play` flavors. `flutter analyze` clean, tests 36/36
  - [x] Builds compile in the cloud: `direct` release APK 27.5 MB, `play` debug APK. Sent to the owner as a test file (cloud-signed: uninstall the old app first). Not run on a phone yet
  - [x] Owner set the Paystack test key and webhook; **test payment on the phone worked** (3 Months, card): webhook signature OK → verified with Paystack → Premium given once
  - [!] Google Play: Play Console, products, service account (SETUP §14.3); cannot be tested before that
- **4D Notifications + Me dashboard** (plan: `docs/plans/phase-4d.md`, D-063)
  - [x] Database: inbox, push tokens, topic switches, automatic messages (news, new years, Premium, daily streak), badges, dashboard; pg_cron every 5 minutes. Tests **30/30** (`supabase/tests/notifications.test.sql`)
  - [x] Edge Function `push` deployed (FCM HTTP v1, topics per plan, dead tokens removed); the schedule reaches it every 5 minutes (checked). Message tests 3/3
  - [x] Admin: Notifications (write, who gets it, link, now or later, history, cancel), news "Send as a notification". `tsc` clean, `eslint` 0 errors. Live at admin.solutiontee.com (owner: "deploy 4D", 2026-11-03)
  - [x] App: Notifications screen, bell with unread count, Settings switches, push service (off without Firebase), permission after the first test, Me badges, Bookmarks/Downloads/AI rows, profile photo. `flutter analyze` clean, tests 41/41
  - [x] Owner: Firebase project, `google-services.json`, `FIREBASE_SERVICE_ACCOUNT` (SETUP §15)
  - [x] Phone test of a real push: arrived on the owner's phone; asks for notifications every opening while off (D-064)
  - [x] **Owner approved: "4D ok" (2026-11-03)**
- [x] Real app icon from `brand/favicon.svg`; /download updated automatically by GitHub after every app change (D-065)
- [x] Owner changes after the Phase 4 report: screenshot block as admin switches, in-app forced update of the direct app (D-080); app tests 78/78
- [ ] XP and streaks (plan `docs/plans/xp-streaks.md`): [x] XP1 core (D-081; DB 14/14, app 82/82; owner "XP1 ok") · [x] XP2 streaks + welcome-back (D-082; owner "XP2 ok") · [x] XP3 spending (D-083; owner "XP3 ok") · [x] XP4 buying (D-084; DB 6/6, app 88/88; owner "XP4 ok")
- **4E Challenges, referrals, leaderboard, question of the day, winners wall** (plan: `docs/plans/phase-4e.md`, three parts)
  - [x] 4E1 Question of the day + leaderboard (D-066 to D-069: own questions, WAEC/NECO boards, rules as settings, photos; DB tests 43/43, app 50/50). **Owner approved: "4E1 ok" (2026-11-03)**. database + tests **32/32**; admin pages (Question of the day, Leaderboard); app card on Home, Leaderboard screen, Settings switch; app tests 48/48, analyzer clean. Waiting for owner check (`4E1 ok`)
  - [x] 4E2 Challenges & events, fair play, prize claims, winners wall (D-070): database + tests **30/30**; admin Challenges & events and Winners & payouts; app Home section, list, details with fair-play rules, protected play screen, result/winners, prize claim, My winnings, Winners wall; app tests 55/55. Owner corrections (D-073): weekly mixed from the student's JAMB subjects, one-subject challenges, question pools with difficulty levels and the same level mix for all, CSV import with sample, appeals with screenshot, 15-min/start/end notifications, tabs always visible; DB tests 18/18, app tests 60/60. Then (D-074): same questions for every student, random past questions (Free years) with levels, admin live leaderboard + analysis + results CSV, copy a challenge, review answers after the end; DB tests 16/16, app tests 62/62. Then (D-075): admin switch for answer review per challenge; screenshots blocked in tests, challenges and challenge reviews, with screenshot (Android 14+) / screen-recording (Android 15+) detection, flagged in challenges; DB tests 7/7, app tests 63/63. Then (D-076): screenshots and screen recording blocked in the whole app; app tests 64/64. Open question: how to take Play Store screenshots (a test build without the block, or the prototype). Then (D-077): random past questions from any year. **Owner approved: `4E2 OK` (2026-11-03).**
  - [x] 4E3 Referrals, one account per person, bans (D-078): database + tests **22/22**; admin Referrals (rules with live preview, cash rewards, top referrers, latest friends) and Fraud & bans (shared phones, allow family, ban all, appeals); app Invite friends (code, WhatsApp, discount, cash progress, friends, add a code, claim cash), Home and Me entry, ban screen with one appeal, phone-taken screen; app tests 72/72. Then (D-079): phone-wide id + clone detection, second accounts refused by the server, phone bans (no sign-up, appeal only, emailed answer), Fraud & bans page v2, longer referral codes; DB tests 12/12, app tests 75/75. **Owner approved: "4E3 ok" (2026-11-03).**

- [ ] **Big update** (owner's 17 fixes and ideas, plan `docs/plans/big-update.md`): [x] U1 fixes, Home order, streak week (D-086; DB checks pass, app 96/96) + Sign in with Google (D-087, owner steps SETUP §17) + fixes after the phone test (D-088: Google's real G, animated goal ring, today's questions from the server, challenge background pictures; app 101/101). **Owner approved: "U1 ok" with these fixes (2026-11-04)** · [x] U2 payments in the app (D-089), prize payouts by Paystack Transfer (D-090), challenge player limit + minimum winning score (D-091), every Paystack way to pay in the app incl. OPay / PocketApp / Zap / bank apps (D-092), embedded Paystack checkout + plan sheet redesign (D-093); DB 11/11, app 111/111. **Owner approved: "U2 ok" with these fixes (2026-11-04)**; then leaving / cancelling a payment detected at once with a "Leave this payment?" pop-up + new Opening OPay screen (D-095; app 117/117), no × on the XP payment sheet. **Owner approved again: "U2 ok" after the phone test (2026-11-05)** · [x] U3 AI tutor v2: locked down, education only, memory, knows the student, tools, suggestions, voice (D-096; DB checks pass, app 127/127) + U3b after the phone test: mock exam, year papers, AI-written quizzes, hint ladder, quiz v2, saved study plans with morning reminders, comeback messages, answers finish in the background (D-097; app 148/148) — waiting for the owner's phone test · [x] JAMB mock challenges for tutorial students (D-099; app 160/160; admin needs "deploy") · [x] U3c JAMB papers always complete + English set the JAMB way (D-098; app 154/154; admin needs "deploy") · [ ] U4 careers, subject combinations, more exams, custom test · [ ] U5 news, badges, leaderboards · [ ] U6 safety, emails, admin dashboard, navigation

- [ ] **Big update 2** (owner's list of 2026-11-07, plan `docs/plans/big-update-2.md`, D-100, D-101; one approval per step)
  - [x] Plan written; owner chose: ads mix of levels + rewarded unlocks, YouTube Live + Jitsi for classes, Brave Search for the web, order A → B → C → D → E → F → G → U4–U6
  - [x] **Step A — fixes and AI tutor upgrades** (D-100): A0 mock leaderboard while writing · A1 AI reminders (push at the time, list + cancel) · A2 long answers (bigger allowance, auto-continue, numbered steps to a final answer) · A3 "use the note titled …" quotes the real note, never invents one · A4 note cards after the answer · A5 photo read-first (check, then Solve) + sharper photos · A6 internet search (Brave, sources) · A7 Me best JAMB score + tests/time/streak from the server · A8 rule-breaking strikes (3 a day → 3 days, then 7, then admin) · A9 today's question locked until answered · A10 AI-written off-topic and greeting replies (free) · A11 better "What next?" · A12 CBT pictures downloaded before the timer · A13 new accounts only get new notifications · A14 "Start drill" starts at once · admin **AI safety** page (lift / block AI / ban). Plus fixes from the owner's 20 screenshots (study-plan keep-alive, hyphens/`<br>`, teach vs notes, sheet X, underlined words, quiz pictures, multi-step requests, mixed messages, Home challenges refresh, live mock card, passage title) and one-call mock submit. App tests **171/171**, analyzer clean, web `tsc` + lint clean; DB checks run (rolled back). Deployed (website + `ai-chat` v12). **Waiting for the owner's phone test and approval.**
  - [x] **Step B — Google AdMob ads** (D-101): admin levels Off · Low · Medium · High · High Extra · Max · Ultra, formats on/off, ad unit ids, test mode, rewards, 30-day report (admin → Money → Ads); banners at the top of lists, card ads in News and Notes, break ads after results / mock result / video with gaps and caps; "watch to unlock" (+2 AI prompts, a Premium note for 24 h, a streak freeze) granted only by the server (`admob-ssv` checks Google's signature; signature check tested 50/50); never during exams, CBT, challenges or checkout; Premium = no ads; birth year asked once (18+ personalised only). App tests **171/171** (5 new ads tests), DB flow checked (rolled back). Website deployed. Ads are **Off** until the owner chooses a level. **Waiting for the owner's AdMob account (App ID, ad units) and phone test.**
  - [x] **Ads v2 · B2** (D-104): rebuilt levels (Low…Ultra + Custom), sticky banners, random breaks (Ultra), app-open ads, video breaks, cards inside notes, Home + AI tutor + News + more screens, "watch for XP", "watch to open a year for 1 hour", birth year required at setup + one-time pop-up. App tests **174/174**.
  - [x] **B3** brand campaigns (D-105): admin Brand ads page (uploads, dates, places, share, cap, report + CSV), app house banner/card/break and video-lesson ads before/middle/after; DB flow tested (rolled back). App tests **175/175**.
  - [x] **Ads limits + welcome + custom exam** (D-107): chosen years only + daily caps for watching, first-day welcome, custom exam (max 40 / English 60), floating sticky banner, quiet picture download, background update download, new earn pop-up. App tests **177/177**.
  - [x] **B4** content access modes (D-106): per kind / per item / per year — free, Premium, watch N videos, pay per item (Paystack v13 `start_item`); admin How content opens + item fields; DB flow tested (rolled back). App tests **176/176**.
  - [x] **Supabase + Neon** (D-108, plan `docs/plans/backend-neon.md`): audit log saves only changed fields; 4 Neon projects in London; nightly mover with copy → count → delete; running totals for weak topics; old AI chat messages fetched from Neon in the app. First move: 141,998 old audit rows → Neon, Supabase **417 MB → 125 MB**. App change (old chat messages) ships with the next app build.
  - [x] **Play launch, part A** (D-109–D-112, plan `docs/plans/play-launch.md`): no ads in sign-up/setup; 6-digit codes; under 13 blocked; parent/guardian notice for 13–17 with a turn-off link; cash prizes off (admin switch, 18+ and free entry when on); XP not for sale; personalised ads only with an adult's yes; exam logos switch (badges by default); Google Play preview build on /download?channel=play. **Waiting:** owner's answers on payments (plan B4), "deploy" for the website parts, phone test.
  - [x] **Payment settings + website** (D-113, D-114): admin chooses Google Play / website link / both in the Play app; Paystack fee (grossed up, shown before paying) and Google fee products; public site (landing + /pay with email code + /pay/done). Live at https://cbt.solutiontee.com (deployed 2026-11-08).
  - [x] **Back to the app + codes** (D-116, D-117): after a website payment the app opens on its success screen; up to 3 discount codes on the website; "Have a code?" in the Play app. Migration tested (₦5,000 − 10% − ₦500 = ₦4,000; 4 codes refused). App build via GitHub.
  - [x] **Play Console kit** (D-118): legal pages, /delete-account, 12-month retention, `.aab` build + /download/aab, store images and `docs/play-console/README.md`. Deployed 2026-11-08.
  - [x] **Lawyer's list finished** (D-119, D-120): Google consent message for EEA/UK, 24-month inactivity deletion with email notice, clean-up of deleted accounts in R2 and Neon, "Past Questions" / "SolutionTee Mock" labels with a super-admin switch. Owner paperwork left: NDPC registration, DPIA, licence letters to JAMB/WAEC/NECO.
  - [x] **Cash for 13 to 17 + website CMS** (D-121, D-122): admin switch for teen cash prizes with a parent email after each win (claims wait for it); admin → Website edits every section of cbt.solutiontee.com with on/off switches, new Invite & earn and Challenges sections; Privacy/Terms follow the cash switches; store images 6 and 7. **Waiting:** "deploy". **Next:** email templates, then the analytics dashboard.
  - [ ] Step C JAMB countdown · [ ] D Request a tutor · [ ] E Online classes · [ ] F Games · [ ] G Community
  - [x] **Payments fixed for good** (D-129, D-130): payments confirmed by the webhook, the result page/app (by reference, no login needed) and a 2-minute scheduler; the website never logs the app out (local sign-out only); "You are already on Premium" on /pay; new receipt page. Server parts live 2026-11-11. **Waiting:** "deploy" (website) and the app build on /download.
  - [x] **Website exam logos + smooth landing page** (D-131): logos follow the admin switch; landing page 47 → 58 fps on a slowed phone, 0 janky frames. **Waiting:** "deploy".
  - [x] **Paystack fee choice + Test/Live switch + /pay redesign** (D-132, D-133): who pays Paystack's fee (matched with the Paystack dashboard, with a live check), keys typed in admin and kept in Vault, Test/Live switch (test = staff only), test payments left out of revenue; new /pay with steps, code boxes, plan cards, benefits. Server parts live 2026-11-11. **Waiting:** "deploy" (website), owner saves live keys and chooses Live.
  - [x] **Smaller features, part 1** (D-135, D-136, D-137): exam countdown (admin dates, daily full-screen, Home chip); resume any test; one search for the whole app, back button, tab re-tap, app-icon shortcuts; **careers and JAMB subject combinations** (44 sample careers, admin Careers page, Study card, career page with the path, "Not sure? Pick by career" in setup, Settings → My dream career, careers in search); **more exams added by the admin** (D-138: Add exam, details, logo upload, Free vs Premium for every exam, dynamic Test tab and setup). **save videos and PDFs for offline** (D-139). App tests 201/201. **Waiting:** "deploy" (admin pages), owner checks each career against this year's brochure, owner tests on the phone.
  - [x] **B. Engagement** (plan: docs/plans/engagement.md): [x] B7 News v2 (D-141) · [x] B8 Badges v2 (D-142) · [x] B9 Leaderboards v2 (D-143) · [x] B10 Fair-play tracking (D-144) · [x] B11 Automatic safety bans (D-145)
  - [x] **C. Big new products** (plan: docs/plans/big-products.md; 16 later): [x] C13 Online classes (D-147) · [x] C17 JAMB classes on the website (D-148) · [x] C12 Request a tutor (D-149) · [x] C14 Games (D-150) · [x] C15 Community (D-151)
  - [ ] **Big updates 2** (plan: docs/plans/big-updates-2.md): [x] 1 Tutor v2 (D-152) + [x] 1b Tutor v3 corrections (D-153) + [x] 1c Tutor v4 fixes and quizzes (D-154, TUTOR APPROVED) · [x] 2 Community v2 (D-155, COMMUNITY APPROVED) + v3 changes (D-156) · [ ] 3 Game Zone v2

## Phase 5 — Website, classes, community  (approval: `WEBSITE APPROVED`)
- [ ] Not started

## Phase 6 — Legal, release, videos  (approval: `LAUNCH APPROVED`)
- [ ] Not started
