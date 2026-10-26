# SolutionTee CBT — Security plan (docs/SECURITY.md)

Private document. Do **not** publish it in the public design repo.

**Goal:** the app and website can be reverse-engineered, so nothing valuable is trusted to the phone. The server decides what each student may see, checks every answer, and pays nobody without verification.

---

## 1. Principles
1. **Server is the source of truth.** Plans, access rules, prices, quotas, scores, rankings, rewards and prizes are computed in Postgres / Edge Functions. The app only displays.
2. **No secrets in the app.** Only the Supabase *anon* key and public Paystack key ship in the app. Service-role key, NVIDIA key, Paystack secret, Brevo key and the Google Play service account live only in Edge Function secrets.
3. **Least data to the phone.** A student's phone only ever receives questions their plan allows (RLS + server endpoints). Locked content is never downloaded and then "hidden".
4. **Assume the client is hostile.** Every request is validated (JWT, plan, rate limit, input schema). A modified app cannot unlock content, change scores or win prizes.

## 2. Content protection
| Threat | Defence |
|---|---|
| Free user pulls Premium questions via the API | Row Level Security on `questions` joined to `entitlements` + `free_access_rules`; packs are built by an Edge Function that re-checks the plan. RLS tests prove it (Phase 2). |
| Someone scrapes the whole bank | Per-user and per-IP rate limits; questions served in pages; anomaly alerts (one account reading thousands of questions/hour); auto-suspend. |
| Downloaded packs copied off a phone | **Only Premium can download** (rule `offline`). Packs are encrypted (AES-256-GCM) with a per-device key wrapped by Android Keystore (hardware-backed where available); the key is released by the server only to a device that passes Play Integrity and has an active entitlement; packs expire and are re-keyed when Premium ends. |
| Leaked questions shared online | Invisible per-user watermark (question order + option order + zero-width markers in passages) so a leaked copy can be traced to the account; DMCA/takedown process. |
| Correct answers read from app memory/traffic during CBT | In practice mode answers ship inside the encrypted pack (needed offline). **In challenges, answers never reach the phone**: only the current question is sent, the server marks it. |

## 3. App hardening (Flutter, Android)
- Release builds with `--obfuscate --split-debug-info`, R8/ProGuard shrinking and resource obfuscation; no debug logs; `android:debuggable=false`, `allowBackup=false`, `usesCleartextTraffic=false`.
- **Play Integrity API** on login, on pack-key requests, before challenges and before payouts: app recognised, device integrity, licensed (Play build). Verdicts verified server-side with Google, never on the device.
- **Tamper checks:** APK signature/certificate pinned in code and verified server-side via Integrity; detect re-signed or repackaged builds, root (Magisk/su), hooking frameworks (Frida, Xposed/LSPosed), debuggers and emulators. Result is sent to the server, which decides (block sensitive actions, flag, or ban).
- **TLS:** HTTPS only, HSTS on the website, **certificate pinning** for the API domain in the app (with a backup pin and a remote-config kill switch to avoid bricking).
- `FLAG_SECURE` on CBT, challenge and payment screens (no screenshots/recording); copy/paste disabled in challenges.
- Tokens in `flutter_secure_storage` (Keystore-backed); short-lived access tokens (≤1 h) with rotating refresh tokens; logout everywhere on password change or ban.
- App-cloner / dual-app / work-profile detection (see DECISIONS D-032).

## 4. Backend (Supabase)
- RLS **on every table**, default deny; policies tested in CI (`supabase/tests`). Service role used only in Edge Functions.
- Edge Functions: verify JWT, validate input (zod), check plan/quota atomically in SQL, rate limit (per user, IP, device), idempotency keys for payments and payouts.
- Payments: Paystack webhook HMAC-SHA512 + `verify` call; Play purchases via Google Play Developer API; entitlements only created server-side.
- Challenges: one attempt row per (challenge, user) created when the first question is served; server-side timing per question; answers checked server-side; ranking computed in SQL at close.
- Rewards and prizes: never automatic. Phone OTP, device/NIN/bank uniqueness, fraud review, then payout with two-admin approval above a threshold.
- Storage: private buckets, signed URLs that expire in minutes; uploads type/size checked; images re-encoded server-side.
- Postgres: `pgaudit`-style admin audit table, point-in-time backups, least-privilege roles, no public schema writes.

## 5. Admin CMS (website)
- Admin login with email + password + **mandatory 2FA (TOTP)**; roles (`super_admin`, `admin`, `editor`, `teacher`) enforced by RLS, not just the UI.
- IP allow-list option for super-admins; session timeout; every admin action in the audit log (who, what, before/after).
- CSP, `X-Frame-Options: DENY`, `SameSite=strict` cookies, CSRF protection on mutations, server-side input sanitising for rich text (Tiptap HTML allow-list), no secrets in client bundles.

## 6. Monitoring and response
- Alerts: spikes in failed logins, OTP sends, pack-key requests, scraping patterns, Integrity failures, payout requests.
- Dependency scanning (Dependabot/`pnpm audit`, `flutter pub outdated`), secrets scanning on every push.
- Incident playbook: rotate keys, revoke sessions, re-key packs, notify users where the NDPA 2023 requires.
- Before launch: an independent penetration test of the API, admin CMS and Android app.

## 7. What can never be fully prevented (be honest)
A determined attacker with a rooted phone can still read what is shown on their own screen, and a person with several phones and SIM cards can try to make several accounts. The plan makes that **slow, detectable and unprofitable**: limited data per account, watermarking, server-side marking, verification before any money moves, and bans.
