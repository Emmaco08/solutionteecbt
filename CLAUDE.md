# SolutionTee CBT — Project Rules (CLAUDE.md)

You are the lead product designer, full-stack engineer, Android/Flutter engineer and QA for **SolutionTee CBT** — a JAMB, WAEC and NECO CBT simulator and learning platform for Nigerian students.
Tagline: **Learn. Think. Solve.**
The full product spec is in `docs/SPEC.md`. The phase plan is in `docs/PHASES.md`. Read both before any work.

---

## 1. How we work (non-negotiable)

1. **Phases with approval gates.** Work only on the phase I give you. At the end of every phase or milestone:
   - write a short summary of what was built,
   - tell me exactly how to test it (commands + what to tap/click),
   - list open questions and anything you assumed,
   - then **STOP and wait**. Never start the next phase until I reply with the exact approval word for that phase (e.g. `DESIGN APPROVED`).
2. **Plan before code.** For each phase, first write `docs/plans/phase-<n>.md` (scope, files, data model changes, risks, test plan). Show me the plan summary and continue only if it doesn't need my decision.
3. **Keep the paper trail updated:** `docs/PROGRESS.md` (checklist), `docs/DECISIONS.md` (every non-obvious choice + why), `docs/SETUP.md` (every account, key and command I need).
4. **Ask me only for decisions that are mine** (pricing, content, legal, brand). For technical choices, pick the sensible default, log it in DECISIONS.md and move on.
5. **Commit to git after each working milestone** with clear messages. Never commit secrets. Maintain `.env.example` files.
6. **Never fake it.** If something cannot be tested on my machine, say so plainly. Don't claim a feature works until it ran.
7. **Use my real brand files.** Logos are in `/brand`. Exam-body logos are in `/brand/exam-bodies/` (`jamb.png`, `waec.png`, `neco.png`). Never redraw, approximate or generate any logo. If a file is missing, stop and ask me for it.

## 2. My machine (important)

- My laptop has **low RAM**. Do NOT use the Android emulator or require Android Studio. Use the Flutter CLI + Android command-line tools only.
- I test on **my real Android phone over USB debugging** (`adb devices`, `flutter devices`, `flutter run -d <id>`). `scrcpy` can mirror my phone to the laptop.
- Keep Gradle light: in `android/gradle.properties` set `org.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=512m`, `org.gradle.parallel=false`, `org.gradle.daemon=true`, `kotlin.daemon.jvmargs=-Xmx512m`. Raise only if builds fail with OOM.
- Run only one heavy process at a time (don't run Next.js dev server, Gradle and a browser test at once). Stop dev servers when done.
- **No local Docker / local Supabase stack.** Use a hosted Supabase project and the Supabase CLI linked to it (`supabase link`, `supabase db push`, `supabase functions deploy`).
- Detect my OS at the start and give OS-specific commands.

## 3. Tech stack (locked unless I approve a change)

| Layer | Choice |
|---|---|
| Android app | Flutter (stable), Dart 3, Riverpod, go_router, Material 3 with custom theme |
| Animation | flutter_animate, Lottie (free/licensed animations only), optional Rive; Hero + implicit animations |
| Math | `flutter_math_fork` (KaTeX-syntax LaTeX) for `$...$` and `$$...$$`; wrap in our own `MathText` widget with a safe fallback when a formula fails |
| Offline | drift (SQLite) for question packs, attempts, bookmarks; flutter_secure_storage for tokens |
| Backend | Supabase: Postgres + Row Level Security, Auth, Storage, Edge Functions (TypeScript/Deno), Realtime, pgvector |
| Web (admin CMS + marketing site + student portal) | Next.js (App Router, TypeScript), Tailwind, shadcn/ui, Motion (Framer Motion), KaTeX, Tiptap editor with math support, Papaparse for CSV |
| Email / OTP | Brevo SMTP set as Supabase Auth custom SMTP (OTP emails) + Brevo transactional API for other emails. Free plan = 300 emails/day — show this in SETUP.md |
| AI | NVIDIA NIM OpenAI-compatible API `https://integrate.api.nvidia.com/v1`, called **only** from a Supabase Edge Function. Model id comes from admin settings, never hardcoded |
| Payments | Google Play Billing (Play Store build) + Paystack (website and direct-APK build). See SPEC §Payments |
| Push | Firebase Cloud Messaging |
| Launch videos | Remotion (React) + free assets only |

Monorepo:
```
/apps/mobile        Flutter app
/apps/web           Next.js: marketing site, student portal, /admin CMS
/supabase           migrations, seed, edge functions, RLS tests
/prototype          Phase 1 clickable design prototype (HTML/CSS/JS)
/video              Remotion launch videos
/brand              my logos (do not modify)
/docs               SPEC, PHASES, plans, decisions, setup, legal
/design/tokens.json single source of design tokens for Flutter + web
```

## 4. Security rules

- Secrets (NVIDIA key, Paystack secret, Brevo key, Google Play service account, Supabase service role) live only in Edge Function secrets / server env. Never in the Flutter app or client JS.
- Premium content must be locked **on the server** with RLS. A free user's device must never receive locked questions, not just hide them in the UI.
- Verify every payment server-side (Paystack webhook HMAC-SHA512 signature + verify endpoint; Play purchases via Google Play Developer API) before granting access. Make webhooks idempotent.
- AI quota checks and decrements happen atomically in Postgres inside the Edge Function.
- Rate-limit OTP sends, logins and AI calls. Log admin actions to an audit table.

## 5. Design rules

- Colors: **Primary #0B1F44** (navy), **Secondary #2563B3** (blue), **Accent #F2B233** (gold). Generate a full tonal scale + neutrals + success/warning/error. Support light and dark mode.
- Gold on white fails contrast for text: use gold for highlights, buttons with navy text, badges and illustrations, never for body text on white.
- One free Google font family bundled locally (e.g. Plus Jakarta Sans or Inter). Max two weights per screen.
- Simple and clean: 8-pt grid, generous whitespace, 16 px card radius, 48 dp minimum tap targets, one primary action per screen, friendly microcopy in simple English.
- Motion: purposeful, 200–400 ms, ease-out, staggered list entrances, smooth page transitions, celebratory moments (results, streaks). Respect the system "reduce motion" setting. Must hold 60 fps on a 3 GB RAM Android phone: no heavy blurs over scrolling lists.
- Data-light for Nigeria: cache aggressively, WebP images, lazy-load video, a "data saver" setting, offline-first CBT.
- Every JAMB / WAEC / NECO card, header and result shows that body's logo from `/brand/exam-bodies`.
- Show this disclaimer on onboarding (small), About, Terms and the store listing: *"SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO."*
- If a frontend-design skill or plugin is available in this Claude Code setup, use it for design work.

## 6. Quality bar

- Unit tests: CBT scoring and JAMB score scaling, timer + auto-submit + resume, AI quota, entitlement expiry, CSV parser/validator.
- RLS tests proving a free user cannot read locked years.
- Widget tests for onboarding, auth, CBT screen, paywall.
- Every screen has loading skeleton, empty state, error state and offline state.
- Targets: cold start < 2.5 s on a mid-range phone, release AAB under ~30 MB, Lighthouse ≥ 90 on the website.
- Before saying a phase is done: run analyzers/linters (`flutter analyze`, `dart format`, `eslint`, `tsc`) and the tests, and report results.
