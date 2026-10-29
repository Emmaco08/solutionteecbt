# Phase 3 plan — Android app core (offline CBT)

Approval word at the end: **`APP CORE APPROVED`**
Contract: `docs/design-spec.md` §1–6 (screens, tokens, motion), `docs/SPEC.md` §1–3, §6, §10, `docs/AUTH_EMAIL.md`, `docs/SECURITY.md` §3.
Platform: **Android only** (D-043). Tested on the owner's own Android phone over USB, with no emulator (low RAM).

## 1. Goal
A student installs the app on a real phone, creates an account (email code), sets up their exams, and takes a full JAMB CBT. The test works offline, survives the app being killed or the phone restarting, and gets a correct JAMB score out of 400 with a review of every answer.

## 2. Scope

**In**
1. **Toolchain** (no Android Studio, no emulator):
   - Flutter stable, Temurin JDK 17 (portable), Android command-line tools, SDK platform and build-tools.
   - Light Gradle settings (CLAUDE.md §2).
   - `flutter doctor` must pass for Android.
2. **App skeleton** `apps/mobile`:
   - Package `com.solutiontee.cbt`, Riverpod, go_router, Material 3 theme generated from `design/tokens.json` (light and dark).
   - Plus Jakarta Sans bundled; Phosphor icons; real logos from `/brand`.
   - `flutter_animate` for motion, which respects the system reduce-motion setting.
3. **Data and security:**
   - `supabase_flutter` (publishable key only); tokens kept in `flutter_secure_storage`.
   - `drift` (SQLite) for question packs, attempts and answers.
   - Release builds obfuscated; `FLAG_SECURE` on CBT screens; `allowBackup=false`; no cleartext traffic in release.
4. **First launch and auth:**
   - Splash (brand Lottie from `/brand`), welcome, onboarding slides from the database, with the small disclaimer.
   - Sign up through `/api/auth/sign-up` with consent, then the email code screen (paste supported, 60 s resend timer, box count from `codeLength`).
   - Log in; forgot password (code, then new password, then notice); welcome-new and welcome-back screens.
   - Profile setup in 3 steps (exams, JAMB subjects with English compulsory, target score), saved to `profiles`.
   - Guided tour with coach marks.
5. **Navigation:** server-driven bottom tabs from `app_tabs` (cached for offline). Study, AI and Premium tabs show "coming soon" screens until Phase 4.
6. **Home:**
   - Greeting, Continue card, exam cards with logos.
   - "Start a CBT practice", a Free/Premium badge and plan status.
   - News carousel from the database.
   - Challenge, question-of-the-day and leaderboard sections stay hidden until their phases.
7. **Test hub and setup:**
   - Modes: full JAMB simulation (4 subjects), single subject, by year, quick test (20 questions), topic drill. Timed or untimed.
   - Years show lock icons from `my_open_years`; a locked year opens a paywall placeholder.
8. **CBT engine:**
   - Real JAMB-style layout: header with logo and name, countdown (warning colours at 10 and 5 minutes), subject tabs, question palette (answered, unanswered, flagged, current).
   - Questions show text, LaTeX (`MathText` widget with a safe fallback) and images (signed R2 links, cached).
   - Passages in a split, collapsible pane; options A–E with large tap targets.
   - Previous / Next / Flag, on-screen calculator, submit summary, auto-submit when time runs out.
   - Every answer is autosaved to SQLite; **resume after the app is killed or the phone restarts**; works offline once the questions are downloaded.
9. **Scoring and sync:**
   - Scores are calculated on the phone so they appear instantly offline: JAMB scaled to /400 per `exam_configs`.
   - Attempts sync when the phone is online. **The server re-marks each attempt from its own answer key** (new table `attempts` plus a `submit_attempt` RPC), so a changed app cannot post a fake score. Leaderboards will only ever use server scores.
10. **Results and review:**
    - Results: celebration (confetti, skipped when reduce motion is on), JAMB score, per-subject scores, accuracy, time used, weak topics, share card.
    - Review screen with filters (All, Wrong, Flagged, Skipped) and explanations.
11. **Profile basics:**
    - Name, plan, test history (from attempts).
    - Settings: theme, reduce motion, data saver.
    - Help (WhatsApp and support email from `app_settings`), Terms, Privacy and About (with the disclaimer).
    - **Delete account** (a Play requirement, through `/api/account/delete`) and log out.
12. **App control from the admin:** minimum app version (force update) and maintenance mode.
13. **Every screen** has loading (skeleton), empty, error and offline states.

**Out (later phases)**
- Study content, paywall and payments (Play Billing and Paystack flavors), AI tutor, push notifications, downloads of Premium packs, leaderboards (Phase 4).
- Challenges, referrals, one-account-per-phone checks, bans by device (Phase 4b).
- Google sign-in: optional in this phase. It needs your Google Cloud OAuth client; if that isn't ready, it moves to Phase 4.

## 3. Database changes (one migration)
| Table / function | Purpose |
|---|---|
| `attempts` | One test: user, exam, mode, subjects, years, started, submitted, time used, client score, **server score**, status |
| `attempt_answers` | Question, chosen option, flagged, time spent (no answer key here) |
| `submit_attempt(p_attempt, p_answers)` | Saves the answers and marks them from `questions.answer` on the server; returns per-subject and /400 scores. Idempotent per attempt. |
| `my_attempts()` | History for the profile |
| RLS | Students read and write only their own attempts; staff read all (2-step) |

Plus an API route `/api/account/delete`: Bearer token, then the service role deletes the account (profile and attempts cascade). It is logged.

## 4. Files
```
apps/mobile/
  lib/main.dart, app.dart, router.dart
  lib/theme/            tokens.g.dart (generated from design/tokens.json), theme.dart
  lib/core/             supabase.dart, api.dart (website API), storage.dart, connectivity.dart
  lib/data/             db.dart (drift), repositories (auth, catalogue, questions, attempts)
  lib/features/         onboarding/, auth/, setup/, home/, test/, cbt/, results/, review/, profile/, common/
  lib/widgets/          math_text.dart, exam_logo.dart, skeletons.dart, states.dart
  test/                 scoring_test.dart, jamb_scaling_test.dart, timer_resume_test.dart, widget tests
  android/              gradle.properties (light), network security config (debug LAN only)
design/scripts/tokens-to-dart.mjs
supabase/migrations/…_attempts.sql, supabase/tests (new RLS cases)
apps/web/app/api/account/delete/route.ts
```

## 5. Key decisions (to log)
- Scoring runs on both sides: on the phone for instant offline results, on the server for trust. The server score wins whenever they differ.
- Practice packs are the Free and opened questions fetched through `fetch_questions` and cached in SQLite for that test. Premium encrypted downloads come in Phase 4.
- During development the phone talks to the website API on the laptop over Wi-Fi (debug-only cleartext to the LAN). The release build uses https only.

## 6. Risks
| Risk | Plan |
|---|---|
| Low RAM during Gradle builds | Gradle heap 1.5 GB, no parallel builds, stop the Next.js server while building, stop the daemon after |
| First build downloads a lot (Gradle, SDK) | Done once (about 3–4 GB of disk; you have about 37 GB free) |
| Phone and laptop on different networks | Same Wi-Fi needed in development (or USB reverse port: `adb reverse tcp:3000 tcp:3000`) |
| 8-digit vs 6-digit codes | The app reads `codeLength` from the API |

## 7. Test plan
1. Unit tests: JAMB scaling (per subject /100, total /400), quick-test scoring, timer (pause on kill, resume with the correct time left, auto-submit at 0), resume from SQLite.
2. Widget tests: onboarding, sign-up and code screen, CBT screen (answer, flag, palette, submit).
3. RLS tests for attempts (own only; the server score can't be faked).
4. `flutter analyze`, `dart format --set-exit-if-changed`, `flutter test`.
5. **On your phone:** install the debug build over USB, sign up with a real email (you receive the code), set up, take a quick test offline (airplane mode), kill the app mid-test, reopen and resume, submit, see results and review, delete a test account.

## 8. Owner actions
1. **Allow the toolchain downloads** (I can install them for you; see the next message), or run SETUP §2 yourself.
2. **Phone:** turn on Developer options and USB debugging (SETUP §2.6). I'll say exactly when to plug it in.
3. Optional: a Google Cloud OAuth client for Google sign-in.
4. The 512×512 app icon (needed before the Play Store, not for testing).
