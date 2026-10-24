# SolutionTee CBT — Phase Plan (docs/PHASES.md)

Rules: work on one phase at a time. Each phase starts with `docs/plans/phase-<n>.md` and ends with a summary, test steps, open questions, and a **STOP**. The next phase starts only when the owner replies with that phase's exact approval word.

> Note: the original kickoff message mentioned "Phases 0–6 from this file", but `docs/SPEC.md` has no phase list. The phase split below comes from the hints in CLAUDE.md and SPEC (Phase 1 = prototype, Phase 5 = website/classes/community, Phase 6 = launch videos). **Owner: please confirm or edit it.**

---

## Phase 0 — Environment & repo setup
**Goal:** A clean monorepo and a working toolchain on the owner's Windows laptop.
**Deliverables**
- Monorepo folders (`apps/mobile`, `apps/web`, `supabase`, `prototype`, `video`, `design`, `docs`), git initialised, `.gitignore` files.
- `docs/PHASES.md`, `PROGRESS.md`, `DECISIONS.md`, `SETUP.md`.
- Tool check report and install commands (Flutter, JDK 17, Android cmdline-tools, adb, Supabase CLI, scrcpy).
- Brand asset check (`/brand`, `/brand/exam-bodies`).
- Owner answers to the pre-design questions.
**Approval word:** `SETUP APPROVED`

## Phase 1 — Design system & clickable prototype
**Goal:** Lock the look, feel and flows before writing production code.
**Deliverables**
- `design/tokens.json`: colours (navy/blue/gold tonal scales, neutrals, success/warning/error, light and dark), type scale, spacing (8-pt), radius, elevation, motion durations and easing.
- `/prototype`: a clickable HTML/CSS/JS prototype at phone size covering splash, welcome, onboarding slides, sign-up, OTP, profile setup, guided tour, Home, Study, Test setup, CBT screen (timer, palette, passage pane, calculator), submit summary, results, review, AI chat, paywall sheet, Profile. Light and dark. Real logos only.
- A short admin CMS look (dashboard + question editor + CSV import) as static screens.
- Motion notes (what animates, duration, reduce-motion behaviour).
**Approval word:** `DESIGN APPROVED`

## Phase 2 — Backend foundation & admin CMS core
**Goal:** The data, security and content pipeline everything else depends on.
**Deliverables**
- Hosted Supabase project linked via CLI. Migrations for: users/profiles, roles, exam bodies, subjects, years, exam_configs, passages, questions, topics, app_tabs, onboarding slides, banners, plans, entitlements, free_access_rules, ai_limits, feature flags, audit_log.
- RLS on every table plus **RLS tests proving a free user cannot read locked years/exams**.
- Auth: email + password with 6-digit OTP via Brevo SMTP, Google sign-in, rate limits.
- Next.js `/admin`: login + roles, exams/subjects/years, question editor with live KaTeX, passages, **CSV import** (template, mapping, validation preview, dry run, commit, history + undo), export, app-control screens (tabs, onboarding, banners, free rules, flags, min version, maintenance), audit log.
- Seed data: exam configs (JAMB 4 subjects / 180 Qs / 120 min / 400), sample questions.
- Unit tests for the CSV parser/validator.
**Approval word:** `BACKEND APPROVED`

## Phase 3 — Mobile app core (offline CBT)
**Goal:** A student can install the app on a real phone, sign up and take a full CBT offline.
**Deliverables**
- Flutter app (Riverpod, go_router, Material 3 theme from tokens), light Gradle settings.
- Splash, welcome, onboarding (CMS-driven), auth + OTP, profile setup, guided tour.
- Server-driven bottom tabs (`app_tabs`, cached, "More" sheet).
- Home tab, Test tab: all modes, CBT screen, `MathText` widget, passages, calculator, auto-submit, **resume after kill/restart**, drift offline packs, sync of attempts.
- Results (JAMB scaling to 400, per-subject, weak topics, celebration, share card) and Review.
- Profile basics, settings (theme, reduce motion, data saver), delete account, log out.
- Tests: scoring + scaling, timer/auto-submit/resume, widget tests (onboarding, auth, CBT screen).
**Approval word:** `APP CORE APPROVED`

## Phase 4 — Study content, premium, payments & AI tutor
**Goal:** Full learning experience and a working business model.
**Deliverables**
- Study tab: past questions (study mode), video solutions, topic videos, lesson notes, novels, brochure/syllabus PDF viewer, custom sections, bookmarks, downloads.
- Free vs premium enforced server-side; paywall bottom sheet; entitlement expiry.
- Payments: `PaymentProvider` interface; `play` flavor (Play Billing + server verification via Google Play Developer API); `direct` flavor (Paystack, webhook HMAC + verify, idempotent); `paystack_in_play_build` flag. Admin plans & payments screens.
- SolutionTee AI: `ai-chat` Edge Function (JWT, atomic quota, RAG with pgvector + NVIDIA embeddings, streaming SSE, retry/backoff, fallback models, answer cache), chat UI with Markdown + LaTeX, hint mode, "Explain this question".
- FCM push notifications with per-topic opt-out.
- Profile dashboard: stats, charts, streaks, badges, history.
- Tests: AI quota, entitlement expiry, paywall widget test.
**Approval word:** `PREMIUM APPROVED`

## Phase 5 — Website, student portal, JAMB classes & community
**Goal:** Public website and the online classes product.
**Deliverables**
- Marketing landing page (animated hero, features, logos, pricing, FAQ, download buttons, news/blog, disclaimer).
- JAMB classes: info, timetable, teachers, register + pay with Paystack.
- Student dashboard: classes, schedule + meeting links, recordings, materials, assignments, CBT results, premium status, payments.
- Community: channels, announcements, threads, Q&A, reactions, moderation, Realtime.
- Admin: classes & community management.
- SEO, Lighthouse ≥ 90.
**Approval word:** `WEBSITE APPROVED`

## Phase 6 — Legal, release & launch videos
**Goal:** Ship to the Play Store and the website.
**Deliverables**
- Terms of Service + Privacy Policy drafts (NDPA 2023, marked "DRAFT — review by a lawyer"), Play Data safety answers in `docs/legal/`.
- Release builds: signed AAB (`play`) and APK (`direct`), size and cold-start checks, store listing text + screenshots, disclaimer.
- Remotion launch videos (16:9 and 9:16 app launch, website/classes promo) from real phone recordings, free TTS + licensed music, `video/CREDITS.md`.
- Pre-launch checklist (NVIDIA terms, Brevo limits, Paystack live keys, Play Console products).
**Approval word:** `LAUNCH APPROVED`
