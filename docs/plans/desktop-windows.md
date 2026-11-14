# Windows desktop app (owner, 14 Nov 2026)

**Status:** in progress (D-166).

## Brief
"Make the Windows .exe my laptop can install. Almost exactly like mobile, just larger and broader, with the best UI.
Every screen and every function the Android app has. Test it well."

## Approach
- **Same Flutter app, built for Windows.** All 136 files and every feature come along; the backend is unchanged.
- **Desktop layout:** a left sidebar replaces the bottom tabs (Home, Study, Test, AI Tutor, Me, plus Game Zone,
  Community, Live classes, Tutors, Leaderboard, News, Downloads); a top bar with search (Ctrl+K), XP, streak,
  notifications and profile. Content sits in a comfortable width (no 2,000-px stretched lines). The main screens get
  real wide layouts (Home dashboard in columns, CBT with the question palette always open and keyboard keys A–D / ← →
  / F, results side by side, AI chat centred, community with a right rail, Game Zone in a stage). Every other screen
  keeps its mobile design in a centred column, so nothing is missing or untested.
- **Mouse and keyboard:** hover states, drag-to-scroll with the mouse, Esc to go back, Ctrl+K search, scroll bars.
- **Android-only parts replaced:**

| Android | Windows |
|---|---|
| Google Play billing / Paystack sheet / in-app WebView | Paystack opens in the default browser; the app waits and confirms with the server (the same status check the phone uses) |
| Google sign-in sheet | Sign-in in the browser, back to the app (needs one redirect URL in Supabase, then an admin switch) |
| Firebase push | In-app notifications list and live toasts while the app is open (Windows has no Firebase push) |
| AdMob ads | No ads (AdMob has no Windows SDK); house ads still show |
| In-app update (APK) | The app checks the website for a newer Windows version and downloads the installer |
| Screenshot block | Windows "exclude from capture" on the app window |
| Device check (one account per phone) | A hashed Windows machine ID |
| Camera for AI photos | Pick a photo file (laptops rarely have a document camera) |
| Quick actions, Play review, Play update | Not on Windows |

## Packaging
- `flutter build windows` on a GitHub Windows machine (Windows apps cannot be built on Linux).
- Inno Setup installer `SolutionTee-CBT-Setup-<version>.exe`: installs for the current user (no admin needed), Start
  menu + desktop shortcuts, uninstaller, the Visual C++ runtime files included.
- The workflow also opens the built app on the Windows machine and checks it keeps running before publishing to
  `cbt.solutiontee.com/download/windows`.
- **Owner decision later:** the installer is not code-signed, so Windows SmartScreen shows "Windows protected your PC
  → More info → Run anyway". Removing it needs a code-signing certificate or a Microsoft Store listing.

## Tests
- Analyzer and all unit/widget tests.
- Desktop screenshots at 1440 × 900 and 1366 × 768 of every main screen (reviewed one by one).
- The Windows build + launch check in CI.
