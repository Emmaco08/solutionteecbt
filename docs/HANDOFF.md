# Handoff: where the build is (read this first in a new or cloud session)

Last updated: 2026-11-03, after milestone 4C (payments) on branch `claude/clever-gates-rdt2wx`. Read `CLAUDE.md`, then this file, then `docs/PROGRESS.md`, `docs/DECISIONS.md` (D-001 to D-060), `docs/SETUP.md` and `docs/plans/phase-4*.md`.

## Where we are

- Phases 0–3 are approved. We are in **Phase 4 (Premium)**. Approval word for the whole phase: `PREMIUM APPROVED` (not given yet).
- Done in Phase 4:
  - **4A Study tab:** past questions, video solutions (thumbnails, own player), notes (Markdown + KaTeX + pictures), novels (PDF + summary), docs, downloads, bookmarks, progress; admin Study manager; per-item locks (video list always visible, each video locked).
  - **4B AI tutor:** NVIDIA primary, Dahl backup, providers/keys/models/prompts managed in Admin → AI tutor; keys in Supabase Vault; `ai-chat` and `ai-index` Edge Functions; app AI tab with streaming, photos, hint mode, history and quota. DB tests 28/28 (ai) and 22/22 (study); app tests 28/28.
  - **Test APK page:** https://admin.solutiontee.com/download (D-059).
  - **4C Payments** (built, waiting for the owner's review and Paystack test key): Paystack and Google Play, server-verified, idempotent, redeem codes, admin Payments and Codes, app checkout; `direct` / `play` flavors (D-060). Branch `claude/clever-gates-rdt2wx`, not merged.
- Next milestones, in order: **4D** push (FCM) + Me dashboard, **4E** challenges, referrals, leaderboard, question of the day, winners wall. Then the Phase 4 report and STOP for `PREMIUM APPROVED`.
- Waiting on the owner: press "Add new and edited notes" in Admin → AI tutor → Knowledge; rotate the NVIDIA and Dahl keys (they were pasted in chat for testing); Paystack test secret key in Supabase secrets + webhook URL (SETUP §13.1) and a Play Console account (§13.3) for 4C; deploy the website from the laptop (new admin pages); Firebase project for 4D.

## Live systems

- Website/admin: Vercel team `solution-tee`, project `solutiontee-cbt`, root `apps/web`, production https://admin.solutiontee.com.
- Supabase dev project ref `mxeemubacnmcmmmzteax`. Schema changes go in `supabase/migrations/<version>_<name>.sql` **and** are applied to the project (Supabase MCP `apply_migration` or `supabase db push`). The filename version must match the applied version. Edge Functions in `supabase/functions/`.
- Files and pictures: Cloudflare R2, **private** bucket `solutiontee`; the server signs short links after an access check (prefixes: `q/` question images, `public/news`, `v/` videos, `d/` PDFs, `s/` covers, `n/` note images, `apk/` test app). Not Supabase Storage.

## Owner's standing rules (from earlier sessions; not all are in CLAUDE.md)

- Native **Android** app only; iPhone and desktop users get the web app.
- **Everything except free questions is gated on the server.** No client-side unlocks.
- Never ask for or paste keys in chat. Secrets live only in git-ignored `.env.local`, Vercel env, Edge Function secrets or Supabase Vault. Claude never types passwords or keys into web forms.
- Never redraw logos; use `/brand` files only. Keep the R2 bucket private.
- Never delete the owner's own account; cleanup only touches test accounts.
- Owner's laptop has low RAM: no emulator; they test on a real Android phone over USB.
- Explain things in simple English. Ask the owner only for decisions that are theirs (pricing, content, legal, brand).
- Commit after each working milestone; end commit messages with the Co-Authored-By trailer.
- **Commits are signed as the owner** (`git config user.name Emmaco08`, `user.email emmanuelakinbola08@gmail.com`, set per repo at the start of each session), still ending with the `Co-Authored-By: Claude` trailer. Why: Vercel blocks deploys whose latest commit author is not a team member (owner's choice, 2026-11-03).
- **Website deploys from a cloud session:** `npx vercel@65.8.0 login` (the owner approves the device link on their phone), `npx vercel@65.8.0 link --yes --project solutiontee-cbt --scope solution-tee`, then `npx vercel@65.8.0 deploy --prod --yes --scope solution-tee` from the repo root. Project `solutiontee-cbt` serves admin.solutiontee.com.

## Working from a cloud session (no laptop)

What works the same: reading and writing code, plans, docs, migrations, Edge Function code, web code, Dart code, git commits and pushes, and Supabase/Vercel changes **if** those connectors are enabled for the session.

What does not work from the cloud, and what to do instead:
- **No USB phone:** a cloud session cannot install on the owner's phone or take phone screenshots. Build the APK in the cloud only if Flutter + Android SDK are installed there; otherwise leave building to the laptop and say so.
- **No `.env.local`:** the R2 upload script and `vercel` CLI need secrets that are only on the laptop. Do not ask for them in chat. Deploys can happen by the owner later, or by Vercel's Git integration if the owner connects the repo in the Vercel dashboard.
- Say plainly what was not run or tested (CLAUDE.md "Never fake it").
- Work on a branch, push it, and tell the owner the branch name so the laptop can pull it later.

## Useful commands

- Web checks (from `apps/web`): `npx tsc --noEmit -p .` and `npx eslint .`
- App checks (from `apps/mobile`): `flutter analyze`, `dart format .`, `flutter test`
- Icons: `python design/scripts/phosphor-to-dart.py`
- Release APK (website build): `flutter build apk --release --flavor direct --target-platform android-arm64`, then from `apps/web` `node scripts/upload-apk.mjs`. Play Store: `flutter build appbundle --release --flavor play`.
- Edge Functions with shared code: deploy with files `<name>/index.ts`, `_shared/pay.ts`, `_shared/paycrypto.ts` and entrypoint `<name>/index.ts`. `paystack-webhook` and `play-rtdn` use verify_jwt = false (they check a signature / URL token).
- DB tests from a cloud session: paste a test file into Supabase `execute_sql`, replacing the final `select … rollback` with a `raise exception` that prints the results (the error rolls everything back).
- DB tests: run `supabase/tests/*.test.sql` against the project (each runs inside `begin … rollback`).
