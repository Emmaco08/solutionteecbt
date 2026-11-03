# Phase 4 report — Study, Premium, payments, AI tutor, push, competition

Date: 2026-11-03. Approval word: `PREMIUM APPROVED`.

## Built (all milestones approved by the owner on the phone)
| Milestone | What | Owner check |
|---|---|---|
| 4A Study | Study hub with sections from the admin; past questions in study mode; video solutions and lessons with player; lesson notes (Markdown, maths, pictures); novels; syllabus and brochure PDFs; bookmarks; Free vs Premium decided by the server (signed links only after the plan check) | walk-through open (see below) |
| 4B AI tutor | `ai-chat` Edge Function (streaming, fallback models, image questions, notes search, Lagos-day quota checked atomically), admin AI tutor (providers, keys in Vault, models, prompt versions, knowledge, health), app AI tab with hint mode and "Ask AI" | walk-through open |
| 4C Payments | Paystack (webhook HMAC-SHA512 + verify, idempotent), Play Billing code (verify + RTDN), redeem codes, admin Payments / Codes / Plans | real test payment worked ("4C ok") |
| 4D Push + profile | FCM topics and inbox, automatic messages, streaks, badges, dashboard, notification switches | real push arrived ("4D ok") |
| 4E1 | Question of the day (per subject, 08:00 Lagos, admin questions, analysis, notification), leaderboards JAMB/WAEC/NECO with photos | "4E1 ok" |
| 4E2 | Challenges & events: weekly mixed / one subject / one list; pools by subject and level; random past questions (any year); same-questions option; CSV import; live leaderboard and analysis; appeals with screenshot; answer review switch; notifications 15 min before / start / 15 min before end; prize claims; Winners wall; screenshots and screen recording blocked in the whole app | "4E2 OK" |
| 4E3 | Referrals (codes, discount by the server, cash every N friends, monthly limit), one account per phone (phone-wide id + Android ID, dual / cloned app detection, second accounts refused by the server), bans with one appeal, phone bans with email appeal, Fraud & bans board | "4E3 ok" |

Decisions: D-044 to D-079 in `docs/DECISIONS.md`.

## Checks run (2026-11-03)
- App: `flutter analyze` clean, `dart format` clean, **75/75** tests.
- Website: `tsc` clean, `eslint` 0 errors (15 old warnings), unit tests 4/4.
- Edge Function helpers: 10/10.
- Database (live project, every run rolled back): study 21/21, payments 58/58, notifications 30/30, question of the day + leaderboard 47/47, challenges 30/30, challenges v2 18/18, v3 16/16, v4 7/7, referrals + bans 22/22, fraud v2 12/12.
- Builds: the direct APK is built and published to /download by GitHub after every app change (latest 0.3.0-202611032319).

## Open (not blocking the approval, listed honestly)
1. Phone walk-through of Study (4A) and AI (4B) was not recorded as a separate check.
2. Saving videos and PDFs on the phone for offline use is not built (Downloads lists saved past papers).
3. Owner: Admin → AI tutor → Knowledge → "Add new and edited notes" once, to build knowledge from the notes.
4. Google Play: Play Console, products and service account (SETUP §14.3) — Play Billing cannot be tested before that; Play Integrity can come with it.
5. Before the first real cash challenge: lawyer check of cash prizes and minors (D-028).
6. No SMS check for referrals until a provider is chosen (cost).
7. Store-listing screenshots: the app blocks screenshots everywhere (D-076); use a test build without the block, or the prototype.
