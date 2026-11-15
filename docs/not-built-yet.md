# Planned but not built yet (15 Nov 2026)

Checked against `docs/SPEC.md`, `docs/PHASES.md`, `docs/PROGRESS.md` and the plans. The owner picks which to build.

## Features
1. **Student web app (for iPhone and laptop browsers)** — PHASES §5, the one big item left ("16 later" in
   `docs/plans/big-products.md`). Today an iPhone user cannot use SolutionTee at all (no iOS app, no web app); the
   website only has classes, payments and the tutor pages. A web app at `app.solutiontee.com` would give sign-in,
   Home, Study, CBT tests (timer, palette, calculator, resume), results, AI tutor and Premium in any browser.
2. **iPhone app (App Store)** — not in the plan (SPEC chose the web app for iPhone). Needs an Apple developer account
   ($99/year) and a Mac or cloud Mac to build.
3. **Community on the website** — students use Community only in the app; the website has the staff feed only.
4. **Windows: a way to earn what reward videos unlock** — AdMob has no Windows version (D-167). Owner decision.
5. **Windows notifications when the app is fully closed** — needs a background service or the Microsoft Store.
6. **Results share card** — SPEC §6 mentions a share card on the results screen; not found in the app.
7. **Testimonials on the website** — SPEC §14 (placeholders until real ones exist).
8. **Launch videos still to make** — 16:9 cut of the intro advert, and the website/classes promo (PHASES §6).

## Owner steps still open (not code)
- Supabase → Authentication: Email OTP length 6, expiry 600 s; turn on **leaked password protection**.
- Admin → AI tutor → Knowledge: press "Add new and edited notes" once.
- Google sign-in: SETUP §17 (and `http://localhost:53682/**` for the Windows app).
- Play Console: products, Data safety answers (`docs/legal/google-play-console-declarations.md`), live Paystack keys.
- Windows: code-signing certificate or Microsoft Store listing (removes the "Windows protected your PC" warning).
- Delete the unused `pay-probe` server function (an old payment connectivity test, not in the code any more).
- Phone walk-throughs listed in PROGRESS.
