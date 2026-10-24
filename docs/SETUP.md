# Setup guide (docs/SETUP.md)

Everything the owner needs to install, create or configure. Kept up to date every phase.

Machine: **Windows 11 Pro**, 4 cores, **7.9 GB RAM**, C: drive **~5.4 GB free (98% full)**.
Shell for commands below: **PowerShell** (run as your normal user; only where noted, as Administrator).

---

## 0. FIRST: free disk space (blocking)

Flutter SDK (~2.5 GB after first run), Gradle caches (~2–4 GB) and `node_modules` will not fit in 5.4 GB. Aim for **at least 20 GB free**.

The quickest win on this machine: the Android **emulator** and its **system images** are installed but this project never uses them (CLAUDE.md §2).

| Folder | Size |
|---|---|
| `%LOCALAPPDATA%\Android\Sdk\system-images` | 8.2 GB |
| `%LOCALAPPDATA%\Android\Sdk\emulator` | 1.1 GB |

If you agree, delete them yourself (this is your call; nothing else in the SDK is touched):

```powershell
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Android\Sdk\system-images"
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Android\Sdk\emulator"
```

Also worth checking: Windows *Settings → System → Storage → Temporary files*, your Downloads folder, and (optional) uninstalling Android Studio via *Settings → Apps* — we only use the SDK folder, not the IDE.

---

## 1. Tool check (2026-10-24)

| Tool | Status | Found |
|---|---|---|
| git | ✅ installed | 2.54.0 |
| Node (LTS) | ✅ installed | v24.19.0 (LTS) |
| pnpm | ✅ installed | 12.8.1 |
| Flutter | ❌ missing | — |
| Dart | ❌ missing | (comes with Flutter) |
| Java JDK 17 | ❌ missing | only Android Studio's bundled JDK 25 (`JAVA_HOME` points to it) |
| Android SDK | ⚠️ partial | `%LOCALAPPDATA%\Android\Sdk`: platform-tools, build-tools 36.0.0, platform android-37. **No cmdline-tools** |
| adb | ⚠️ installed, not on PATH | v1.0.41 in `Sdk\platform-tools` |
| Supabase CLI | ❌ missing | — |
| scrcpy | ❌ missing | — |
| winget | ✅ | used for installs below |

---

## 2. Install missing tools (Windows, PowerShell)

### 2.1 JDK 17 (Eclipse Temurin)
```powershell
winget install --id EclipseAdoptium.Temurin.17.JDK -e
```
Then point `JAVA_HOME` at it (close and reopen PowerShell after):
```powershell
$jdk = (Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Directory | Where-Object Name -like "jdk-17*" | Select-Object -First 1).FullName
[Environment]::SetEnvironmentVariable("JAVA_HOME", $jdk, "User")
```
Check: `java -version` → `openjdk version "17..."`

### 2.2 Android command-line tools + adb on PATH (no Android Studio, no emulator)
```powershell
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
Invoke-WebRequest "https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip" -OutFile "$env:TEMP\cmdline-tools.zip"
Expand-Archive "$env:TEMP\cmdline-tools.zip" -DestinationPath "$env:TEMP\clt" -Force
New-Item -ItemType Directory -Force "$sdk\cmdline-tools\latest" | Out-Null
Move-Item "$env:TEMP\clt\cmdline-tools\*" "$sdk\cmdline-tools\latest" -Force
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdk, "User")
$p = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", "$p;$sdk\cmdline-tools\latest\bin;$sdk\platform-tools", "User")
```
Reopen PowerShell, then update to the newest cmdline-tools and accept licences:
```powershell
sdkmanager "cmdline-tools;latest" "platform-tools"
sdkmanager --licenses
```
(If the zip link above ever 404s, copy the current "Command line tools only → Windows" link from https://developer.android.com/studio#command-line-tools-only.)

### 2.3 Flutter (stable)
```powershell
git clone https://github.com/flutter/flutter.git -b stable --depth 1 C:\dev\flutter
$p = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", "$p;C:\dev\flutter\bin", "User")
```
Reopen PowerShell, then:
```powershell
flutter config --no-analytics
flutter config --jdk-dir "$env:JAVA_HOME"
flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"
flutter doctor --android-licenses
flutter doctor -v
```
`flutter doctor` will warn that Android Studio / Visual Studio / Chrome are not set up — that is expected and fine.

### 2.4 Supabase CLI
The CLI is installed per-project as a dev dependency (Supabase does not support a global npm install). We'll add it in Phase 2:
```powershell
pnpm add -D supabase -w
pnpm approve-builds   # allow the supabase postinstall that downloads the binary
pnpm supabase --version
```
Alternative (global, needs Scoop): `scoop bucket add supabase https://github.com/supabase/scoop-bucket.git; scoop install supabase`

### 2.5 scrcpy (mirror your phone)
```powershell
winget install --id Genymobile.scrcpy -e
```

### 2.6 Phone (USB debugging)
1. Phone: *Settings → About phone →* tap **Build number** 7 times.
2. *Settings → Developer options →* turn on **USB debugging**.
3. Connect USB, accept the "Allow USB debugging?" prompt on the phone.
4. Check: `adb devices` → your device shows `device`; `flutter devices` lists it.
5. Mirror: `scrcpy --max-size 1024 --video-bit-rate 4M` (lighter on RAM).

### 2.7 Verify everything
```powershell
git --version; node -v; pnpm -v; java -version; flutter --version; dart --version; adb version; sdkmanager --version; scrcpy --version
```

---

## 3. Accounts & keys (needed later — not yet)

| Service | Phase | What we'll need | Notes |
|---|---|---|---|
| Supabase (hosted) | 2 | Project URL, anon key, service-role key (server only), DB password | Free tier is fine to start |
| Brevo | 2 | SMTP login + key (for Supabase Auth OTP), API key (transactional) | **Free plan = 300 emails/day** |
| Google Cloud (OAuth) | 2–3 | Android + Web OAuth client IDs for Google Sign-In | SHA-1 of debug + release keystore |
| NVIDIA NIM (build.nvidia.com) | 4 | API key (Edge Function secret only) | Free tier ≈ 40 req/min. **Pre-launch: confirm NVIDIA terms allow production use; plan a paid provider if usage grows** |
| Paystack | 4 | Public key (client), secret key (server only), webhook URL | Test keys first |
| Google Play Console | 4 / 6 | Developer account, in-app products, service account JSON for Play Developer API | One-time $25 fee |
| Firebase | 4 | Project, `google-services.json`, FCM server credentials | |
| Domain + hosting for website | 5 | Domain DNS, Vercel (or similar) | |

All secrets go into Supabase Edge Function secrets or server env — never the app or client JS. Each app keeps a `.env.example`.

---

## 4. Low-RAM rules (from CLAUDE.md)
- One heavy process at a time (Next dev server **or** Gradle **or** browser tests).
- `android/gradle.properties`: `org.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=512m`, `org.gradle.parallel=false`, `org.gradle.daemon=true`, `kotlin.daemon.jvmargs=-Xmx512m`.
- Stop the Gradle daemon when done: `cd apps\mobile\android; .\gradlew --stop`.
