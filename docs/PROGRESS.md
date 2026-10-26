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
- [ ] Not started

## Phase 3 — Mobile app core  (approval: `APP CORE APPROVED`)
- [ ] Not started

## Phase 4 — Study, premium, payments, AI  (approval: `PREMIUM APPROVED`)
- [ ] Not started

## Phase 5 — Website, classes, community  (approval: `WEBSITE APPROVED`)
- [ ] Not started

## Phase 6 — Legal, release, videos  (approval: `LAUNCH APPROVED`)
- [ ] Not started
