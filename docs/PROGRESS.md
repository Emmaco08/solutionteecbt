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
- [!] Missing: `brand/exam-bodies/jamb.png`, `waec.png`, `neco.png`
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
- [!] Exam-body logos still missing (placeholder slots shown)
- [ ] Owner tests on laptop + phone and sends feedback
- [ ] `DESIGN APPROVED` → write `docs/design-spec.md`, commit

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
