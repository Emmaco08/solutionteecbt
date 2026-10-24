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
