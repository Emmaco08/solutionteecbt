# Handoff: where the build is (read this first in a new or cloud session)

Last updated: **2026-11-07**, after ads v2 B2–B4, on branch **`claude/clever-gates-rdt2wx`** (not merged; the
laptop pulls this branch). Read `CLAUDE.md`, then this file, then `docs/PROGRESS.md`, `docs/DECISIONS.md` (D-001 to
**D-101**), `docs/SETUP.md` and the plans in `docs/plans/` (latest: `big-update.md`, `big-update-2.md`).

## Approved by the owner

- Phases 0–3 (`APP CORE APPROVED`, 2026-10-30).
- Phase 4 milestones: 4A/4B built, **4C ok**, **4D ok**, **4E1 ok**, **4E2 OK**, **4E3 ok** (2026-11-03).
- XP and streaks: **XP1 ok, XP2 ok, XP3 ok, XP4 ok**.
- Big update 1: **U1 ok** (2026-11-04), **U2 ok** (2026-11-05, after the phone test).
- Phase 4 as a whole is NOT approved yet: the word `PREMIUM APPROVED` comes after the big updates.

## Built and waiting for the owner's phone test / approval

| Item | What | Decision | App tests | Website |
|---|---|---|---|---|
| U3 + U3b | AI tutor v2 (education only, memory, tools, voice) + mock exam, year papers, AI quizzes, hint ladder, saved study plans, comeback messages | D-096, D-097 | 148 | deployed |
| U3c | JAMB papers always complete, English set the JAMB way, novel per year | D-098 | 154 | deployed |
| JAMB mock challenges | Tutorial-centre mocks in our CBT, codes/invites, analytics, leaderboard, optional updates | D-099 | 160 | deployed |
| Big update 2 · step A | Fixes A0–A14 + AI tutor upgrades (reminders, strikes, real-note quotes, web search, photo read-first, today's-question lock, keep-alive), screenshot fixes, one-call mock submit, admin **AI safety** page | D-100 | 171 | deployed |
| Big update 2 · step B | **Google AdMob** ads: admin levels Off…Ultra, banners, card ads, break ads, server-verified "watch to unlock", age rules, admin **Ads** page | D-101 | 171 | deployed |
| Ads v2 · B2 | Rebuilt levels + Custom, sticky banners, Ultra random breaks, app-open, video/note/quiz/section breaks, cards in notes, Home/AI/News ads, watch for XP, watch to open a year, birth year required | D-104 | 174 | deployed |
| Ads v2 · B3 | Brand campaigns (house ads): banner, card, break, video-lesson ads before/middle/after; admin **Brand ads** + report/CSV | D-105 | 175 | deployed |
| Ads limits · welcome · custom exam | Chosen years only + daily caps for watching, first-day welcome, custom exam (max 40 / English 60), Study boxes follow the kind rule, floating sticky banner, quiet picture download, background update download, new earn pop-up | D-107 | 177 | deployed |
| Ads v2 · B4 | How Study content opens: free / Premium / watch N ads / pay per item (Paystack); admin **How content opens** + item fields | D-106 | 176 | deployed |

Big update 2 needs the owner's approval word per step (plan `docs/plans/big-update-2.md`). Ads are **Off** until the owner
picks a level in admin → Money → Ads.

## Next steps (in the owner's order)

1. Big update 2: **C** JAMB countdown → **D** Request a tutor → **E** Online classes (YouTube Live + Jitsi) → **F** Games
   (Speed Quiz Duel, Live Exam Arena, Beat the AI Tutor first) → **G** Community. Each step ends with a phone test and
   the owner's approval.
2. Then the rest of Big update 1: **U4** careers/subject combinations/more exams/custom test, **U5** news v2, badges v2,
   leaderboards v2, fair play, resume any test, **U6** safety bans, emails, admin dashboard v2, navigation.
3. Then the Phase 4 report refresh and STOP for **`PREMIUM APPROVED`**.
4. **Phase 5** (website, classes, community; `WEBSITE APPROVED`), then **Phase 6** (legal, release, videos; `LAUNCH APPROVED`).

## Website "deploy" status

- The admin website was deployed on 2026-11-07 again on 2026-11-08 after ads limits, welcome and custom exam.
  Nothing in `apps/web` is waiting.
- Rule: the website is deployed only when the owner replies **"deploy"**.

## Open owner tasks

- **AdMob** (SETUP "Google AdMob"): create the account and app, send the **App ID** (public, fine in chat), create 4 ad
  units and paste them in admin → Ads, turn on server-side verification on the Rewarded unit with the URL
  `https://mxeemubacnmcmmmzteax.supabase.co/functions/v1/admob-ssv`, add payout details, then test with Test mode on.
- **Brave Search key:** added by the owner as the Edge Function secret `BRAVE_SEARCH_KEY` (2026-11-07). Waiting only for a
  phone test ("What is the latest JAMB news?" should show Sources).
- Phone tests of everything in the table above.
- Older open items: rotate the NVIDIA and Dahl AI keys (pasted in chat during early testing); press "Add new and edited
  notes" in admin → AI tutor → Knowledge after new notes; Google Play Console + products + service account (SETUP §14.3)
  for the Play Store build; OAuth consent screen publishing for Sign in with Google if not done (SETUP §17).

## Standing rule: how new app versions reach the owner (owner, 2026-11-07)

- **The owner no longer uses USB.** New app versions reach the phone **only** through https://admin.solutiontee.com/download
  and the in-app update (Me → App update), both fed by the GitHub workflow **`android-apk.yml`**.
- After every app change: push → check the GitHub run **passed** → check **https://admin.solutiontee.com/api/app/latest**
  shows the new build (version/build number and `built_at` newer than before) → only then tell the owner it is ready.
  A newer push cancels an older run, so check the run for the latest commit.
- Never upload an APK by hand; only the workflow has the website APK's signing key. App updates are optional (not forced).
- The workflow opens every build on an Android 14 emulator first (D-103); /download is updated only if the app keeps
  running. If it fails, read the `emulator` job log (crash buffer) or the `emulator-check` artifact.

## Live systems

- Website/admin: Vercel team `solution-tee`, project `solutiontee-cbt`, root `apps/web`, https://admin.solutiontee.com.
  Deploy from the repo root: `npx -y vercel@65.8.0 deploy --prod --yes --scope solution-tee` (only on "deploy").
- Supabase project `mxeemubacnmcmmmzteax`. Edge Functions in `supabase/functions/` (today's: `ai-chat` v12, `admob-ssv`).
- **Migrations:** `supabase/migrations/` matches the live migration history exactly (84 files = 84 applied versions, same
  number, name and content; D-102). Rule: apply with `apply_migration`, then read the applied version from
  `supabase_migrations.schema_migrations` and save the file as `<that version>_<name>.sql` with the applied text.
  Never hand-pick a version number.
- Files: Cloudflare R2, **private** bucket `solutiontee` (server-signed short links). Not Supabase Storage.
- Push: Firebase (FCM). Payments: Paystack (live in the app) and Google Play (later).

## Owner's standing rules

- Native **Android** app only; iPhone and desktop users get the web app.
- **Everything except free questions is gated on the server.** No client-side unlocks (ads rewards too: server-verified).
- Never ask for or paste keys in chat. Secrets live only in git-ignored `.env.local`, Vercel env, Edge Function secrets or
  Supabase Vault. Claude never types passwords or keys into web forms. Public ids (AdMob App ID, ad unit ids) are fine.
- Never redraw logos; use `/brand` files only. Keep the R2 bucket private.
- Never delete the owner's own account; cleanup only touches test accounts.
- Approval words per phase/step; the website deploys only on "deploy"; /download always has the newest app.
- **Do the work directly, no helper agents** (owner, 2026-11-07: "Don't use lower agent anymore").
- Explain things in simple English. Ask the owner only for decisions that are theirs (pricing, content, legal, brand).
- Commit after each working milestone, signed as the owner (`git -c user.name=Emmaco08 -c user.email=emmanuelakinbola08@gmail.com`),
  ending with the Co-Authored-By and Claude-Session trailers. Run the tests **before** committing.
- Supabase approval prompts: changes to the database show the owner an approval box that waits ~4 minutes. If it times
  out, tell the owner and wait; do not work around it.

## Useful commands

- App checks (from `apps/mobile`): `/opt/flutter/bin/flutter analyze`, `/opt/flutter/bin/dart format -l 160 lib test`,
  `/opt/flutter/bin/flutter test` (171 tests on 2026-11-07).
- Web checks (from `apps/web`): `npx tsc --noEmit` and `npm run lint` (15 old warnings are OK, 0 errors).
- Database types for the web: Supabase MCP `generate_typescript_types` → `packages/shared/src/database.types.ts`.
- Edge Function type check: copy to a scratch folder with a `Deno` shim and run `tsc` from `apps/web/node_modules`.
- DB tests: run in `execute_sql` inside a `do $$ … raise exception 'RESULT …' $$` block so everything rolls back.
- Build status: `https://api.github.com/repos/Emmaco08/solutionteecbt/actions/runs?head_sha=<sha>` (workflow "Android app").
