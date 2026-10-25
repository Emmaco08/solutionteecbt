# Decisions log (docs/DECISIONS.md)

Every non-obvious choice, newest at the bottom. Format: date · decision · why.

---

**D-001 · 2026-10-24 · Phase split for 0–6**
The kickoff referenced a phase list that is not in SPEC.md. I wrote PHASES.md from the hints in CLAUDE.md/SPEC: Phase 1 prototype, Phase 2 backend + CMS core, Phase 3 offline CBT app, Phase 4 study/premium/payments/AI, Phase 5 website/classes/community, Phase 6 legal/release/videos.
*Why:* backend and RLS must exist before the app can enforce premium; CSV import early so real questions can be loaded while the app is built. Pending owner confirmation.

**D-002 · 2026-10-24 · Use the Android SDK that is already installed; add only cmdline-tools**
An Android SDK already exists at `%LOCALAPPDATA%\Android\Sdk` (platform-tools, build-tools 36, platform android-37). I will reuse it and only add `cmdline-tools;latest`, instead of downloading a second SDK.
*Why:* disk is almost full; no duplicate downloads. Android Studio and the emulator are not used by this project (CLAUDE.md §2).

**D-003 · 2026-10-24 · JDK 17 (Eclipse Temurin) for Gradle, not the Android Studio JBR**
`JAVA_HOME` currently points to Android Studio's bundled JDK 25. CLAUDE.md requires JDK 17, and Flutter/AGP are most reliable on 17. Install Temurin 17 and point `JAVA_HOME` + `flutter config --jdk-dir` at it.

**D-004 · 2026-10-24 · Package managers: winget for system tools, pnpm for JS**
winget is present on the machine (no choco/scoop), so install commands use winget. pnpm 12 is already installed and will be used for `apps/web`, `video` and the workspace.

**D-005 · 2026-10-24 · Node 24 LTS**
Node v24.19.0 is installed and is an LTS line. Keep it; no upgrade needed.

**D-006 · 2026-10-24 · Prototype stack: plain HTML/CSS/JS, vendored libraries, tiny Node server**
No build step and no node_modules (low RAM, 98% full disk). KaTeX, Phosphor Icons, lottie-web (light build) and Plus Jakarta Sans are copied into `prototype/vendor/` so the prototype works on the LAN with no internet. `prototype/serve.mjs` serves only `prototype/`, `design/` and `brand/`.

**D-007 · 2026-10-24 · Tokens are generated and runtime-loaded**
`design/scripts/gen-tokens.mjs` builds `design/tokens.json` (tonal scales anchored exactly on #0B1F44 at navy-900, #2563B3 at blue-600 and #F2B233 at gold-400) and prints a contrast report. The prototype fetches the JSON and writes CSS variables at runtime, proving one file can feed Flutter and Next.js. Light-mode warning text uses amber-700 (amber-600 failed AA at 4.38:1).

**D-008 · 2026-10-24 · Exam-body logos: labelled empty slots until the files arrive**
Owner chose this. Cards always point to `/brand/exam-bodies/*.png`; if the file 404s, a grey slot reading "jamb.png missing" is shown. No logo is ever redrawn.

**D-009 · 2026-10-24 · Font: Plus Jakarta Sans 500 + 700 only**
Owner chose Plus Jakarta Sans. Only two weights are bundled, which matches the "max two weights per screen" rule and keeps size down. The latin-ext subset is included because the latin subset has no ₦ glyph.

**D-010 · 2026-10-24 · Icons: Phosphor (regular + fill)**
A single open-source (MIT) icon family, used as a web font in the prototype. Flutter has a `phosphor_flutter` package with the same names, so screens map 1:1 later.

**D-011 · 2026-10-24 · Sample content is clearly marked**
Plan prices are tagged SAMPLE. The featured JAMB novel is a placeholder (TBC). The comprehension passage and all questions are original text written for the prototype. Onboarding art is built from UI pieces as a placeholder for final Lottie illustrations. The Google sign-in button uses the Phosphor Google glyph in the prototype; the real app must use Google's official sign-in button assets.

**D-012 · 2026-10-24 · Wordmark**
No full SolutionTee lockup or wordmark file exists in /brand. Screens show the real mark (favicon.svg / mark PNGs) and the app name as plain UI text, not a designed wordmark.

**D-013 · 2026-10-24 · Exam-body logos: crop transparent margins on screen, never edit the files**
The owner's `jamb.png`, `waec.png` and `neco.png` carry wide transparent margins (JAMB's visible mark is only 115×112 px of a 246×144 canvas), so a plain `object-fit: contain` made them tiny. `ST.examLogo` stores each file's measured visible-content box and positions the image inside the slot with CSS so the mark fills it. The PNGs in `/brand` stay byte-for-byte as supplied. Slots keep a white tile in dark mode so the logos' own colours read correctly. The missing-file fallback (D-008) stays as a safety net. Flutter/Next will use the same crop boxes (or owner-supplied trimmed files).

**D-014 · 2026-10-24 · Test tab hero: exam logo without a tile**
Owner feedback: the white tile looked wrong on the navy "Full JAMB simulation" card. Added a `bare` logo variant (transparent, no border, 60 px instead of 44 px) and used it only there. Every other placement keeps the white tile.

**D-015 · 2026-10-24 · Official Google "G" on sign-in buttons (replaces the icon-font glyph from D-011)**
Owner asked for the real Google logo. Downloaded Google's own multi-colour "G" SVG, unmodified, from gstatic.com (the asset Google's FirebaseUI sign-in buttons use) into `prototype/vendor/google/` with a SOURCE.md. It is not stored in /brand because it is a third-party mark. Flutter will use the official asset from Google's sign-in branding guidelines.

**D-016 · 2026-10-24 · Students can add images (owner request, beyond SPEC v1)**
Two places:
1. **SolutionTee AI: photo questions.** Camera button in the chat composer and a "Snap a question" suggestion. Source: camera, gallery or (prototype only) a sample photo. One photo per message, an optional note, preview with remove, tap to view full screen. One photo message uses 1 AI prompt.
2. **Profile photo.** Camera badge on the avatar: take a photo, choose from gallery, or remove; confirm before use. Falls back to initials.
Data-light: photos are shrunk on the phone before upload (max 1280 px long side, WebP or JPEG at ~0.72 quality; the sample goes from ~2.8 MB to ~48 KB).
Admin AI settings gain: allow photo questions, vision model ID, max photo size (300 KB), and auto-delete after N days (30).
**Backend impact (Phases 2 and 4):** private Supabase Storage buckets (`ai-uploads`, `avatars`) with RLS so only the owner can read; signed URLs; size and type checks server-side; the AI Edge Function needs a vision-capable NVIDIA model (configured, not hardcoded) and its own rate limit. Privacy Policy and Play Data safety must declare photos (collected, sent to the AI provider, deleted after the retention period). Avatars are visible to classmates only once community features exist (Phase 5), so they need a moderation/report path then.
**Should go into SPEC.md** (§2 profile, §9 AI tutor, §12 admin): owner to confirm.

**D-017 · 2026-10-24 · Public design repo + Vercel for client review**
`github.com/Emmaco08/solutiontee-cbt-design` is **public**, so the owner chose "design only": it holds the prototype, design tokens (+ generator), /brand files and a client README. SPEC, CLAUDE.md, docs and all future app code stay out of it. The design repo lives in a separate folder `C:\solutiontee-cbt-design` and is refreshed with `node prototype/publish/sync.mjs` (copies only those folders plus `prototype/publish/files/`: README, vercel.json, issue form), then committed and pushed. Vercel deploys it as a static site (no build; `/` redirects to `/prototype/`).
**Client feedback:** Vercel Comments only let outside people comment on Pro/Enterprise, so the free route is a "Give feedback" button in the prototype that opens a GitHub issue form (screen pre-filled, Needs changes / Approved, screenshots). The client needs a free GitHub account. Under CLAUDE.md the phase still only moves on when the **owner** types `DESIGN APPROVED`; client approvals are input to that.

**D-018 · 2026-10-25 · Onboarding pictures animate (owner request)**
Each onboarding picture now has a looping animation that shows its feature: floating exam logos and a live countdown (CBT), play-button ripple, progress fill and check pop (videos/notes), a scripted question, typing and answer loop (AI), line draw, ring fill and badge pop (progress), LIVE blink, Join pulse and a rising student count (classes). Welcome icon floats gently. Rules: transform/opacity only (60 fps on low-end phones), runs only on the visible slide, all loops off under reduce motion (the finished picture shows instead). In Flutter these map to flutter_animate loops or final Lottie files.

**D-019 · 2026-10-25 · Terms + Privacy consent is required to create an account (owner bug report)**
Sign-up used to ignore the checkbox. Now "Create account" and "Continue with Google" on the sign-up screen are both blocked until the box is ticked: the consent area turns red with "Please tick the box to agree to the Terms and Privacy Policy.", the form shakes and focus moves to the box; ticking clears the error. The Log in screen states that continuing with Google as a new user means agreeing to the Terms and Privacy Policy (Google can create a new account from there).
**Phase 2 must enforce this on the server, not only in the UI:** store `terms_version`, `privacy_version` and `accepted_at` (plus the under-18 guardian confirmation) on the profile; sign-up sends them as user metadata; profile setup and app access are refused until a consent record for the current versions exists; when the Terms change, ask again on next launch. Covered by a test.

**D-020 · 2026-10-25 · Welcome screens after sign-up and log-in (owner request)**
- **Welcome (new account)** sits between profile setup and the app tour: navy celebration (avatar with a gold ring that draws, success tick, light confetti) and a summary of the plan the student just set (exams with logos, JAMB subjects, target score, free-plan limits). Primary action "Take a 30-second tour", secondary "Skip, go to Home" (toast says the tour can be replayed from Me, then Help). Setup now saves the chosen exams, target and subjects so the summary is real.
- **Welcome back** follows Log in: time-of-day greeting, avatar with a waving hand, streak card with this week's days, "Pick up where you stopped" for an unfinished test, what is new since the last visit. Primary "Continue my test", secondary "Go to Home". In the real app the content comes from the server (streak, unfinished attempt, new content); if there is no unfinished test the primary action becomes "Start practising".

**D-021 · 2026-10-25 · OTP: paste the code (owner request)**
A "Paste code" button reads the clipboard and fills all six boxes (needs https or localhost; on plain http it falls back to "long-press the first box and tap Paste"). Pasting into any box, Android/iOS one-time-code autofill and keyboard suggestions that drop all digits into one box are spread across the six boxes. Text with no digits shows "There is no code in what you copied". In Flutter: `autofillHints: [AutofillHints.oneTimeCode]`, a paste action, and Android SMS Retriever if codes are ever sent by SMS.

**D-022 · 2026-10-25 · Welcome (new account) follows light and dark theme (owner request)**
The screen was always navy. It now has a light version (soft gold glow at the top fading into the app background, navy text, white cards, navy-tinted chips, blue "See Premium" link because gold text fails contrast on white) and a dark version (the navy celebration). All its colours come from `--wn-*` variables switched by the same theme rules as the rest of the app (system setting or the in-app toggle). Confetti uses navy and blue pieces instead of white on the light background. Contrast checked: every text pair passes AA in both themes. The gold ring and gold primary button (navy text, 8.65:1) stay in both themes as the brand celebration accent.
