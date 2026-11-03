# SolutionTee CBT: Android app

Flutter (stable), Riverpod, go_router, drift (SQLite), supabase_flutter. This is a native **Android only** app. iPhone and laptop users get the web app at app.solutiontee.com (D-043).

## Run on your phone (no emulator)

1. On the phone, turn on **USB debugging**: Settings → About phone → tap *Build number* 7 times, then Settings → System → Developer options → *USB debugging*.
2. Plug the phone in and accept the "Allow USB debugging?" prompt.
3. In PowerShell:

```powershell
cd C:\solutiontee-cbt
adb devices                      # your phone should be listed as "device"
adb reverse tcp:3000 tcp:3000    # the phone's localhost:3000 now reaches the laptop
pnpm -C apps/web dev             # website API (sign-up codes, reset, images, delete account)
```

4. In a second PowerShell window:

```powershell
cd C:\solutiontee-cbt\apps\mobile
flutter devices                  # copy your phone's id
flutter run -d <id>
```

Run one heavy thing at a time (CLAUDE.md §2). Stop `pnpm dev` with Ctrl+C when you are done. `scrcpy` mirrors the phone on the laptop.

## Build settings (`--dart-define`)

| Name | Default | Notes |
|---|---|---|
| `SUPABASE_URL` | dev project | public |
| `SUPABASE_PUBLISHABLE_KEY` | dev publishable key | public by design; RLS protects data |
| `API_BASE` | `http://localhost:3000` | release builds must use `https://solutiontee.com` |
| `APP_VERSION` | `1.0.0` | compared with `min_app_version` for the update gate |

No secret ever goes in the app (SECURITY.md).

## Commands

```powershell
dart run build_runner build --delete-conflicting-outputs   # after changing lib/data/db.dart
flutter analyze
dart format lib test
flutter test
python ..\..\design\scripts\phosphor-to-dart.py            # after using a new icon
node ..\..\design\scripts\tokens-to-dart.mjs ..\..\design\tokens.json lib\theme\tokens.g.dart
flutter build apk --debug
```

## Two builds: `direct` and `play` (D-060)

| Build | Where it goes | Pays with | Command |
|---|---|---|---|
| `direct` (default) | APK on admin.solutiontee.com/download | Paystack | `flutter run -d <id>` or `flutter build apk --release --flavor direct --target-platform android-arm64` |
| `play` | Google Play Store | Google Play Billing | `flutter build appbundle --release --flavor play` |

`direct` is the default (`default-flavor` in pubspec.yaml), so `flutter run` works as before. The release APK is now
`build/app/outputs/flutter-apk/app-direct-release.apk`; `node scripts/upload-apk.mjs` (in `apps/web`) picks it up and refuses a Play build.
Google Play Billing only works in a build installed from a Play Console testing track.

## Layout

- `lib/core`: config, API client, providers, secure storage, screen protection
- `lib/data`: drift database (questions, attempts, answers, cache) and `TestsRepo` (fetch, start, submit, sync)
- `lib/features`: onboarding, auth, setup, shell, home, test, cbt (screen, clock, scoring, calculator), results, profile
- `lib/widgets`: MathText, states, exam logos, question images, Phosphor icons (generated)
- `lib/theme`: tokens (generated from `design/tokens.json`) and the Material 3 theme
