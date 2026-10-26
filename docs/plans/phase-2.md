# Phase 2 plan — Backend foundation & admin CMS core

Approval word at the end: **`BACKEND APPROVED`**
Contract: `docs/design-spec.md` (admin shell §7), `docs/SPEC.md` §2, §3, §6, §7, §12, `docs/SECURITY.md` §4–5.

## 1. Goal
A real, hosted backend and a working admin website. At the end, an admin can:
- log in with 2-step login;
- set up exams, subjects and years;
- write questions with live maths preview, or import them from CSV with validation and undo;
- control the Free vs Premium rules, tabs, onboarding, news, plans, flags and app settings;
- give a student Premium by hand.

Tests prove that a Free student's account can never read locked questions.

## 2. Scope

**In**
1. **Workspace:** pnpm monorepo (`apps/web`, `packages/shared`, `supabase`), Supabase CLI as a dev dependency, `.env.example` files.
2. **Hosted Supabase project** (dev), linked with the CLI. No Docker: migrations go up with `supabase db push`.
3. **Database migrations** (§4) with Row Level Security on every table. Default deny.
4. **Server rules in SQL:**
   - `has_premium(user)`, `is_staff(roles)`, `can_read_question(...)` (Free years follow the admin rule: N oldest or newest years per exam), and audit triggers.
   - All of these are `security definer` with a fixed `search_path`.
5. **Auth:**
   - Email + password, 6-digit email OTP through Brevo SMTP, rate limits.
   - Admin accounts must use TOTP 2-step login (aal2 is checked in RLS for every admin write).
6. **Admin website** (`apps/web`, Next.js App Router + TypeScript + Tailwind + shadcn/ui, built on the approved admin design), with these pages:
   - Login, 2-step setup and 2-step check.
   - Dashboard with real counts only: students, Premium, questions, imports. Money, AI and challenge cards show "Available in Phase 4".
   - Exams & years (publish or unpublish a year), subjects and topics, exam rules (`exam_configs`).
   - Question bank: search, filters, status tabs, bulk publish, duplicate check, export CSV.
   - Question editor: rich text with LaTeX (Tiptap + KaTeX live preview), options A–E, answer, explanation, topic, difficulty, image upload.
   - Passages: create one and attach questions.
   - **CSV import:** template download, column mapping, validation preview with row errors and LaTeX preview, dry run, commit, history, undo.
   - Users: search, details drawer, give, extend or revoke Premium by hand (with a reason), ban or unban.
   - Staff: invite, set role; super admin only.
   - App control:
     - Tabs manager, onboarding slides, news posts.
     - Free vs Premium rules, plans and prices, AI limits.
     - Feature flags, app settings (minimum app version, maintenance mode and message, support WhatsApp, company details).
   - Audit log: who, what, before and after.
7. **Seed:**
   - JAMB, WAEC, NECO and the main subjects.
   - JAMB rules (4 subjects, English compulsory, 60/40/40/40 = 180 questions, 120 min, /400).
   - The Free plan defaults from D-027, the three Premium plans, flags, and company and support settings from `docs/COMPANY.md`.
   - About 20 clearly marked sample questions.
8. **Tests:**
   - CSV parser and validator unit tests (Vitest).
   - **RLS tests against the hosted dev database** proving: a Free student cannot read locked years, cannot write anything, and cannot see another student's data; a Premium student can read all published years; staff without aal2 cannot write.
   - Plus `tsc`, `eslint` and a production `next build`.

**Out (later phases)**
- Flutter app and student sign-in screens (Phase 3).
- Google sign-in, which needs the Android app's signing key (Phase 3).
- Study content tables and pages (Phase 4).
- Payments, redeem codes and AI tutor (Phase 4).
- Challenges, referrals, fraud and winners wall (Phase 4b, D-044).
- Leaderboard, which needs real test attempts (Phase 4).
- Student web app (Phase 5).
- Hosting the admin online (Phase 5, or earlier if you ask). In Phase 2 it runs on the laptop.

## 3. Files
```
package.json, pnpm-workspace.yaml        workspace + supabase CLI
packages/shared/                         csv/ (parser, validator, template), types, tests
supabase/config.toml                     project config (auth settings)
supabase/migrations/2026102700xxxx_*.sql  schema, functions, RLS, storage, seed-safe defaults
supabase/seed.sql                        dev seed (exams, subjects, configs, plans, sample questions)
supabase/tests/*.test.sql                RLS tests (pgTAP), run by scripts/run-db-tests.mjs
apps/web/                                Next.js admin (app/admin/**), lib/supabase (server/client), components/admin/**
apps/web/.env.example, supabase/.env.example
docs/SETUP.md (Supabase, Brevo, keys), DECISIONS.md, PROGRESS.md
```

## 4. Data model (new tables)

| Area | Tables |
|---|---|
| People | `profiles` (1:1 auth.users, name, phone, state, school, target exams, subjects, target score, banned_at), `staff` (user, role: super_admin, admin, editor, teacher) |
| Exams | `exam_bodies`, `subjects`, `exam_subjects` (per-exam subject rules: compulsory, question count, minutes), `exam_configs` (subjects per candidate, total minutes, score scale, options), `exam_years` (exam + subject + year, draft/published) |
| Content | `topics` (per subject, nested), `passages`, `questions` (body, options A–E as jsonb, answer, explanation, difficulty, image, status draft/review/published, content hash for duplicates, import batch, soft delete), `import_batches` |
| Access & money | `plans` (price in kobo, days or end date, Play product id), `entitlements` (user, plan, source, starts/expires/revoked, granted_by, reason), `free_access_rules` (key → jsonb, same keys as the approved prototype), `ai_limits` |
| App control | `app_tabs`, `onboarding_slides`, `news_posts`, `feature_flags`, `app_settings` (key → jsonb) |
| System | `audit_log` (actor, action, table, row id, before, after, at), filled by triggers on every admin-editable table |

Images live in **Cloudflare R2**, not Supabase Storage (D-045). There are two buckets: private `st-question-images` (short signed links, issued only after `can_view_question_image()` says yes) and public `st-public` behind a CDN domain (news, onboarding art). The database stores the R2 object key.

## 5. Security decisions
- Students can only `select`, and only rows their plan allows. All writes to content and control tables are staff-only and need aal2 (2-step).
- `answer` and `explanation` sit on the same row as the question in Phase 2. In Phase 4b, challenge questions are served by an Edge Function that strips answers.
- The service-role key is used only by trusted server code (Next.js server actions for staff invites; Edge Functions later). It is never sent to the browser.
- Every admin write is logged by a trigger, so a bypass of the website still lands in the audit log.

## 6. Risks
| Risk | Plan |
|---|---|
| No local Docker, so tests run on the hosted dev database | A separate **dev** project; each test runs in a transaction and is rolled back; production gets its own project later. |
| Free Supabase projects pause after about 1 week idle | Fine for dev; restore with one click. Upgrade to Pro before launch. |
| Low RAM with the Next.js dev server | One heavy process at a time; Turbopack dev; stop the server after testing. |
| Brevo free plan: 300 emails a day | Enough for dev and early launch; documented in SETUP. |
| Rich-text and LaTeX safety | Sanitise HTML on the server with an allow-list. LaTeX is rendered on display, never trusted as HTML. |

## 7. Test plan
1. `pnpm -C packages/shared test`: CSV parser and validator cases (quotes, commas, UTF-8, LaTeX, bad answers, missing columns, duplicates, wrong exam or year, 5 000 rows).
2. `pnpm db:test`: RLS suite on the dev database (Free, Premium, banned, staff without 2-step, staff with 2-step).
3. `pnpm -C apps/web lint && pnpm -C apps/web typecheck && pnpm -C apps/web build`.
4. Manual, in the browser at desktop and phone width, light and dark: log in with 2-step, create a question with maths, import a CSV with errors, then fix, commit and undo it, publish a year, give Premium, see it in the audit log.
5. The owner repeats step 4 from `docs/SETUP.md`.

## 8. Owner actions (accounts and keys; I never ask you to paste secrets into chat)
1. Create a Supabase account and a **free** project named `solutiontee-dev` (region **West EU (London)**; it has no Africa region yet).
2. In a terminal, log in and link the CLI (commands in SETUP.md).
3. Copy the project URL, anon key and service-role key into `apps/web/.env.local` and `supabase/.env` yourself (templates provided; both files are git-ignored).
4. Create a Cloudflare account, an R2 bucket pair and an R2 API token (SETUP §7.8); the keys go only in `apps/web/.env.local`.
5. Create a Brevo account, verify the sender `no-reply@solutiontee.com` (SPF/DKIM DNS records on solutiontee.com), create an SMTP key and paste it into Supabase → Auth → SMTP.
6. Install an authenticator app on your phone (Google Authenticator or Microsoft Authenticator) for 2-step admin login.
