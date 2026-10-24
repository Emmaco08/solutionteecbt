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
