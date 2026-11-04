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
- [ ] XP and streaks (plan `docs/plans/xp-streaks.md`): [~] XP1 core — wallet, earning, daily claim, admin XP & streaks (D-081; DB 14/14, app 82/82). Waiting for `XP1 ok` · [ ] XP2 streaks + welcome-back · [ ] XP3 spending · [ ] XP4 buying
- **4E Challenges, referrals, leaderboard, question of the day, winners wall** (plan: `docs/plans/phase-4e.md`, three parts)
  - [x] 4E1 Question of the day + leaderboard (D-066 to D-069: own questions, WAEC/NECO boards, rules as settings, photos; DB tests 43/43, app 50/50). **Owner approved: "4E1 ok" (2026-11-03)**. database + tests **32/32**; admin pages (Question of the day, Leaderboard); app card on Home, Leaderboard screen, Settings switch; app tests 48/48, analyzer clean. Waiting for owner check (`4E1 ok`)
  - [x] 4E2 Challenges & events, fair play, prize claims, winners wall (D-070): database + tests **30/30**; admin Challenges & events and Winners & payouts; app Home section, list, details with fair-play rules, protected play screen, result/winners, prize claim, My winnings, Winners wall; app tests 55/55. Owner corrections (D-073): weekly mixed from the student's JAMB subjects, one-subject challenges, question pools with difficulty levels and the same level mix for all, CSV import with sample, appeals with screenshot, 15-min/start/end notifications, tabs always visible; DB tests 18/18, app tests 60/60. Then (D-074): same questions for every student, random past questions (Free years) with levels, admin live leaderboard + analysis + results CSV, copy a challenge, review answers after the end; DB tests 16/16, app tests 62/62. Then (D-075): admin switch for answer review per challenge; screenshots blocked in tests, challenges and challenge reviews, with screenshot (Android 14+) / screen-recording (Android 15+) detection, flagged in challenges; DB tests 7/7, app tests 63/63. Then (D-076): screenshots and screen recording blocked in the whole app; app tests 64/64. Open question: how to take Play Store screenshots (a test build without the block, or the prototype). Then (D-077): random past questions from any year. **Owner approved: `4E2 OK` (2026-11-03).**
  - [x] 4E3 Referrals, one account per person, bans (D-078): database + tests **22/22**; admin Referrals (rules with live preview, cash rewards, top referrers, latest friends) and Fraud & bans (shared phones, allow family, ban all, appeals); app Invite friends (code, WhatsApp, discount, cash progress, friends, add a code, claim cash), Home and Me entry, ban screen with one appeal, phone-taken screen; app tests 72/72. Then (D-079): phone-wide id + clone detection, second accounts refused by the server, phone bans (no sign-up, appeal only, emailed answer), Fraud & bans page v2, longer referral codes; DB tests 12/12, app tests 75/75. **Owner approved: "4E3 ok" (2026-11-03).**

## Phase 5 — Website, classes, community  (approval: `WEBSITE APPROVED`)
- [ ] Not started

## Phase 6 — Legal, release, videos  (approval: `LAUNCH APPROVED`)
- [ ] Not started
