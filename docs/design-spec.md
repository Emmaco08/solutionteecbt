# SolutionTee CBT — Design Spec (contract for Phases 2–3)

Status: **APPROVED** by the owner on 2026-10-26 ("DESIGN APPROVED").
Source of truth for visuals: the prototype in `/prototype` (live copy: https://solutiontee-cbt-design.vercel.app) and the tokens in `/design/tokens.json`.
If this document and the prototype disagree, the prototype wins for looks and this document wins for rules. Every later change to an approved screen is logged in `docs/DECISIONS.md`.

---

## 1. Platforms

One Flutter codebase ships to:

| Target | Status | Notes |
|---|---|---|
| Android (phones, 3 GB RAM and up) | Primary | Tested on the owner's Android phone over USB. Play Store build and direct-APK build (see §8). |
| iOS (iPhone) | Required | Same screens and same rules. Needs macOS + Xcode to build, so builds run on a cloud Mac (Codemagic or GitHub Actions macOS). The owner has no Mac or iPhone, so iOS is tested through TestFlight with a tester device. |
| Desktop (Windows first, macOS later) | If possible | Same app with wide layouts (§6.3). Anti-cheat is weaker on desktop, so cash challenges can be phone-only (admin flag). |
| Web | Next.js site (Phase 5) | Marketing, student portal, `/admin` CMS. Not the Flutter app. |

Platform adaptations (same design, native feel):
- **Safe areas** on every screen (notch, Dynamic Island, Android gesture bar).
- **Back:** iOS swipe-back on pushed pages; Android system back. The CBT and challenge screens block back with the "Leave test?" dialog on both.
- **Scrolling:** platform scroll physics (bounce on iOS, glow or stretch on Android).
- **Haptics:** light haptic on answer select, submit and celebration, when the device supports it.
- **Fonts:** Plus Jakarta Sans is bundled on every platform; no system-font switching.
- **Payments:** platform-specific (§8). Icons, colors and layouts are identical.

## 2. Tokens

`/design/tokens.json` is the single source.
- `design/scripts/gen-tokens.mjs` generates CSS variables for the web.
- Phase 3 adds a generator for Dart `ThemeData`/`ThemeExtension`.

Values are never hard-coded in widgets.

| Group | Values |
|---|---|
| Brand | Navy `#0B1F44` (primary), Blue `#2563B3` (secondary), Gold `#F2B233` (accent) |
| Palettes | navy, blue, gold, neutral (50–950); green, amber, red (50–900) |
| Roles | Light and dark: bg, surface, surfaceAlt, surfaceSunken, border(Strong), text(Muted/Subtle/Inverse), primary/secondary/accent (+ on-, soft, on-soft), link, focus, success/warning/error (+ soft, on-soft), scrim, CBT palette (answered, unanswered, flagged, current) |
| Font | Plus Jakarta Sans 500 + 700 only (max two weights per screen); KaTeX fonts for maths; mono for codes and references |
| Type scale | display 32/38, h1 26/32, h2 21/28, h3 17/24, bodyLg 17/26, body 15/22, bodySm 13/18, label 14/20, caption 12/16, overline 11/14, question 17/27, timer 18/22 |
| Space (8-pt grid) | 0, 4, 8, 12, 16, 20, 24, 32, 40, 48, 56, 64, 80 |
| Radius | xs 6, sm 10, md 12, **lg 16 (cards)**, xl 24, sheet 28, pill |
| Sizes | tap target ≥ 48, button 52, input 52, app bar 56, bottom nav 68, icons 18/22/28 |
| Elevation | 0–4, light and dark sets |
| z-index | sticky 10, nav 20, sheet 40, dialog 50, toast 60, tour 70 |
| Breakpoints | sm 640, md 768, lg 1024, xl 1280 |

Color rules:
- Gold is never used for text on light surfaces. It is used for buttons with navy text, badges, highlights and illustrations.
- All text meets WCAG AA in light and dark.
- Dark mode follows the system unless the student picks Light or Dark in Settings.

## 3. Motion

| Rule | Value |
|---|---|
| Durations | instant 100, fast 200, base 280, slow 400, celebrate 1200 ms |
| Easing | standard `(0.2,0,0,1)`, out `(0.16,1,0.3,1)` (default for entrances), in `(0.4,0,1,1)`, emphasized `(0.3,0,0,1.15)` (celebrations only) |
| List entrance | Stagger 50 ms per item, first 8 items only |
| Press | Scale to 0.97 |
| Page transitions | Push or slide for drill-down, fade for tab and filter changes, bottom-sheet slide-up for sheets |
| Celebrations | Results score count-up, confetti on good scores and wins, streak flame |
| Live | "Live" pill pulse dot, countdowns tick each second |
| Skeletons | Shimmer skeleton on first load of each screen (types: home, list, grid, cards, article, profile) |

Rules:
- **Reduce motion** follows the OS setting and an in-app toggle. When on: no transforms, parallax or confetti; fades only, at 200 ms; timers update without animation.
- Hold 60 fps on a 3 GB Android phone. No blur over scrolling lists. Lottie only for splash, onboarding and empty states, and only free or licensed files.

## 4. Components

These are built once as shared widgets (Flutter) and components (web), with names kept close to the prototype CSS classes.

- **Buttons:** primary (navy), secondary (blue), accent (gold, navy text), tonal, outline, ghost, danger; sizes regular (52) and sm; loading state; block width.
- **Icon button:** 48 dp; glass variant on dark images.
- **Inputs:** text, password with show/hide, select with caret, textarea, OTP boxes with paste, search with leading icon; help and error text.
- **Selection controls:** switch, checkbox (consent), radio plan cards, segmented control (`seg`), filter chips.
- **Cards and lists:**
  - Cards have a 16 radius.
  - List items have a 40 lead icon tile, title, caption and trailing caret.
  - Stat tiles, study tiles, quick-grid tiles.
- **Badges and pills:** badge gold, soft, success, warning, error, neutral, SAMPLE; the "Live" pill; time chip; status pills (admin).
- **App bar:** back, title + subtitle, actions. **Bottom nav:** 5 tabs (Home, Study, Test, AI Tutor, Me).
- **Overlays:**
  - Bottom sheet (28 radius, drag handle), dialog, toast/snackbar, coach-mark tour.
  - Command palette, drawer and menus are admin only.
- **Feedback states:** banners (info, warn, error, success) and the `.state` block (art, title, text, action) for empty, error, offline and locked. There is also a connection strip (offline / back online).
- **Exam-body logo:** real files from `/brand/exam-bodies/` only. Transparent margins are cropped on screen; files are never edited. The bare variant is used on the Test hero.
- **MathText:** KaTeX syntax `$…$` and `$$…$$` via `flutter_math_fork`, with a safe plain-text fallback when a formula fails.
- **CBT kit:**
  - Question card with passage and figure.
  - Option rows A–E (selected, correct, wrong).
  - Timer pill (normal, then warning at 5 min, then danger at 1 min).
  - Question palette grid (answered, unanswered, flagged, current).
  - Calculator sheet, submit and time-up dialogs.
- **Challenge kit:** hero card, "next" card, empty card, mini cards (§5 Home), countdown, fair-play badge, winners list with tie-break note.
- **Charts:** score trend line, subject bars, donut (admin), sparkline (admin).
- **Avatar:** with photo upload and edit badge.

## 5. Screen inventory (student app)

Every screen has loading (skeleton), empty, error and offline states. `[needs]` means the server gates it by plan.

**First launch & sign-in**
- Splash (Lottie).
- Welcome.
- Onboarding: 6 animated slides (slide 2 is challenges). The independence disclaimer is shown small.
- Sign up: email, Google, required Terms + Privacy consent, optional referral code.
- Log in.
- Verify email (OTP, paste supported).
- Forgot password, set new password.
- Profile setup (3 steps: exams, subjects, goal).
- Welcome (new account): themed.
- Welcome back (after log in).
- Guided tour: coach marks; skipping ends on Home.

**Main tabs**
- **Home:**
  - Greeting and bell with unread count.
  - Daily goal strip.
  - "Continue" card (only when a test is unfinished).
  - **Challenges & events:** live hero, or the next challenge with countdown and "Remind me", or the "No challenge right now" card. Mini cards scroll underneath, each with icon and status on top, then title, then a Prize / Entry footer.
  - Start a CBT practice: exam cards with logos (no "years free" badge).
  - Question of the day, news carousel, "More for you" grid.
  - Upgrade banner (Free only).
- **Study:** search, subject filter, sections (Past questions, Video solutions, Topic lessons, Lesson notes, Novels, Syllabus & brochure), bookmarks.
- **Test hub:** exam hero with logo, modes (full simulation, subject, topic drill, quick test, timed or untimed), history icon.
- **Me (Profile):** stats, test history, bookmarks, invite friends, my winnings, winners wall, redeem a code, settings, help.
- **Notifications:**
  - Filters: All, Challenges, Classes, Updates.
  - Today and Earlier groups, unread dots, mark all read.
  - Tapping an item opens its target.

**Study**
- Past questions: browse by exam, year and subject. Free sees only admin-allowed years.
- Past question in study mode, with Prev/Next.
- Videos and topic lessons `[videos]/[lessons]`; video player with quality and speed controls `[videos]`.
- Lesson note (LaTeX, text size) `[notes]`.
- Novels list and detail `[novels]`.
- Syllabus and brochure list and viewer.
- Bookmarks (Questions, Notes, Videos tabs).

**Test & CBT**
- **Test setup:** all modes. A fresh test always starts empty; resume only when the student taps Continue.
- **CBT exam screen:**
  - Real JAMB-style layout with timer, palette, flag, calculator and passage.
  - Autosave each answer; auto-submit when time is up.
- **Results:** celebration, JAMB score /400 per subject, time used, share.
- **Review answers:** filter All, Wrong, Flagged, Skipped; solutions; video link if Premium.

**Premium & payments**
- Paywall sheet (reason-aware).
- **Checkout:**
  - "SolutionTee Premium", Access row and Total.
  - The Price and discount rows appear only when a code is applied.
  - Redeem or discount code field (Paystack build only).
- Payment success.

**AI tutor**
- Chat with streaming answers, LaTeX, photo questions and "this answer is wrong" report.
- Daily quota finished state.

**Profile**
- Settings: theme, reduce motion, data saver, notifications, text size.
- Help & support, Terms, Privacy, About (with disclaimer).
- Delete account.
- Test history.

**News & community**
- News list, article with image and "read more".
- Leaderboard (per JAMB year and overall; admin controls visibility).

**Challenges & events**
- List with live, upcoming and past sections, plus an empty state.
- Details with fair-play rules; **one attempt only**.
- In progress, with anti-cheat (leaving the app or copying blocks, then auto-submit and disqualify).
- Result, with a close button and "How winners are decided".
- Winners announced at close. Ranking is best score, then fastest time, then earliest start.
- Disqualified screen.
- Claim prize (bank details form, verification).
- My winnings.

**Referrals & trust**
- Invite friends: code and progress to free Premium and cash, as set by admin.
- Blocked: phone already has an account.
- Blocked: app cloner or dual app detected.
- Account banned.
- Winners wall: proof of payment.

**Sheets and dialogs:** paywall, search, calculator, question palette, submit, time-up, leave test, share, video options and quality, AI report.

## 6. Layout rules

### 6.1 Mobile
- 20 px side padding on screens (16 inside cards), 8-pt rhythm, one primary action per screen.
- Footer CTA sits above the bottom inset.
- Horizontal card rows bleed to the screen edge and snap; the first card lines up with the page padding.

### 6.2 Copy
- Simple English, friendly, short.
- Amounts in naira with `₦` and thousands separators. Show an amount once per screen section.
- Show the disclaimer on onboarding (small), About, Terms and the store listing: *"SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO."*

### 6.3 Tablet and desktop (Flutter desktop, web portal)
- **≥ 768:** bottom nav becomes a navigation rail.
- **≥ 1024:**
  - Lists and details go side by side (two panes).
  - The CBT shows question and palette side by side.
  - Content width is capped at 1200.
- Keyboard: A–E select an answer, N/P go to next/previous, F flags, Ctrl+K searches.

## 7. Admin CMS (Next.js `/admin`, Phase 2)

**Shell**
- Grouped sidebar with live counts (Overview, Content, Students, Money, App control, System).
- Top bar: breadcrumbs, theme, alerts menu, account menu.
- Ctrl+K command palette.
- Details open in a right-hand drawer; the sidebar slides in under 900 px.

**Pages**
- Dashboard: attention list, KPIs with sparklines, revenue, plan mix, live challenge, top subjects, AI health, activity.
- Content: Question bank (tabs, filters, bulk), question editor (live KaTeX), CSV import with validation, Study content, Exams & years (publish or unpublish a year), News.
- Students and money: Challenges & events (close, pay, proof), Users (drawer: grant Premium, device, activity, payments, ban), Referrals, Fraud & bans, Payments (verification timeline, refund), Redeem codes, Plans & AI limits.
- App control: Free vs Premium rules, Onboarding & home, Tabs manager, Leaderboard, Feature flags & app (minimum version, maintenance).
- Audit log (before and after).

**Rules**
- Every admin write is logged to the audit table.
- Destructive actions need a second confirm.

## 8. Security, access and payments (design-level rules)

- **Everything except Free content is gated on the server.** Locked questions, videos, notes, novels and AI never reach a Free device. The UI lock is only a hint; RLS and Edge Functions decide.
- The Free plan is admin-controlled. Defaults: JAMB, WAEC and NECO 3 years each; past questions 2 years; 2 syllabuses; AI 3 per day; no videos, lessons, notes, novels or downloads; challenges open to all.
- **Offline downloads are Premium only.** They are encrypted and tied to the account and device. Free questions may be cached for offline practice.
- **One person, one account.**
  - Device binding plus Play Integrity on Android and App Attest / DeviceCheck on iOS.
  - Cloner and dual-app detection on Android.
  - Bans are recorded server-side.
- **Payments:**
  - **Google Play** Billing in the Play build.
  - **Apple In-App Purchase** in the iOS build (Apple requires it for digital content).
  - **Paystack** in the website and direct-APK builds, with redeem codes.
  - Every purchase is verified on the server before access is given; webhooks are idempotent.
- Challenge scoring, ranking, tie-breaks and disqualification are decided on the server, from server timestamps.

## 9. Assets

- Logos: `/brand` (do not modify). Exam bodies: `/brand/exam-bodies/{jamb,waec,neco}.png`.
- Official Google "G" on Google sign-in.
- Icons: Phosphor (regular + fill).
- Illustrations: Lottie files that are free or licensed.

## 10. Acceptance for Phase 3 screens

A Flutter screen matches the design when:
1. It uses tokens only, no stray hex values or sizes.
2. Light, dark and reduce-motion all work.
3. Loading, empty, error and offline states exist.
4. Tap targets are ≥ 48 dp and text contrast is AA.
5. Its widget test passes.
6. It is checked side by side with the prototype on the owner's Android phone.
