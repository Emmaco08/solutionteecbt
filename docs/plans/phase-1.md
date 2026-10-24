# Phase 1 plan — Design system & clickable prototype

**Goal:** the owner approves the full look, feel and flows before any app code is written.
**Approval word:** `DESIGN APPROVED`

## Decisions taken with the owner (2026-10-24)
- Exam-body logos are still missing → cards load `/brand/exam-bodies/{jamb,waec,neco}.png`; until the files exist, a plain grey slot reads "jamb.png missing". Never a redrawn logo. Real logos appear on refresh.
- Output: local prototype only (no hosted canvas).
- Font: **Plus Jakarta Sans**, bundled locally (weights 500 + 700 only; max two per screen).
- Plans: sample plans clearly tagged **SAMPLE** (Monthly ₦1,500 · 3 Months ₦3,500 · Exam Season ₦6,000).

## Scope
1. `design/tokens.json` — single source of truth (colour tonal scales from #0B1F44 / #2563B3 / #F2B233, neutrals, semantic colours, light + dark roles, type scale, spacing, radius, elevation, motion durations/easings, breakpoints, z-index).
2. `/prototype` — plain HTML/CSS/vanilla JS, no build step:
   - `index.html` — screen inventory with links.
   - `app.html` — 390×844 phone frame (fills the screen when opened on a real phone), hash-routed screens, clickable flows.
   - `admin.html` — desktop-width CMS screens.
   - `js/tokens.js` — fetches `/design/tokens.json` and writes CSS custom properties for light/dark at runtime (proves Flutter/Next can consume the same file).
   - `serve.mjs` — zero-dependency Node static server that serves only `prototype/`, `design/` and `brand/`, bound to `0.0.0.0` so the phone on the same Wi-Fi can open it.
3. Vendored locally (no CDN at runtime, works on LAN without internet): KaTeX, Plus Jakarta Sans (fontsource woff2), Phosphor Icons (web font), lottie-web light player (plays the real `brand/solutiontee-loader-*.json` on splash).

## Files
```
design/tokens.json
prototype/index.html, app.html, admin.html, serve.mjs, README.md
prototype/css/base.css, app.css, admin.css
prototype/js/tokens.js, router.js, ui.js, screens/*.js, admin.js
prototype/vendor/{katex,fonts,phosphor,lottie}/
```

## Screen list
Splash · Welcome · 5 onboarding slides · Sign up · Log in · OTP · Forgot password (+ reset) · Profile setup (3 steps incl. JAMB combination) · Guided tour · Home · Study hub · Past questions (exam→subject→year + study mode) · Video solutions/lessons · Lesson note (LaTeX) · Novels + novel detail · Document (syllabus/brochure) viewer · Test hub · Test setup · CBT exam (timer, subject tabs, palette, KaTeX maths, comprehension passage, calculator, submit dialog) · Results (celebration) · Review (+ Ask AI) · Paywall sheet · Plan checkout · Payment success · AI chat (streaming, LaTeX, quota) · AI quota finished · Profile dashboard (chart) · Settings · Help · Delete account · Locked state · Empty state · Offline state · Error state · Loading skeleton.
Admin: Dashboard · Question editor (live KaTeX) · CSV import (validation preview) · Tabs manager · Plans & limits.

## Data model changes
None (design only). Screen content uses obviously sample data.

## Risks
- Disk is 98% full: vendored assets kept small (~3 MB). No node_modules.
- Exam-body logos missing: placeholder slots, flagged in summary.
- Laptop RAM: prototype is static; the server is a single tiny Node process; stop it when done.
- Windows Firewall may block the LAN URL the first time → allow Node on *Private networks*.

## Test plan
- Open laptop URL → index lists every screen; each opens in the phone frame.
- Walk flows: splash → onboarding → sign up → OTP → profile setup → tour → home → test → CBT → submit → results → review → Ask AI; locked year → paywall → plan → success.
- Toggle light/dark and check contrast; enable OS "reduce motion" and confirm animations stop.
- Open LAN URL on the phone: full-screen, no frame, taps work.
