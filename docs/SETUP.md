# Setup guide (docs/SETUP.md)

Everything the owner needs to install, create or configure. Kept up to date every phase.

Machine: **Windows 11 Pro**, 4 cores, **7.9 GB RAM**, C: drive **~40 GB free** (2026-10-26; was 5.4 GB on 2026-10-24).
Shell for commands below: **PowerShell** (run as your normal user; only where noted, as Administrator).

---

## 0. Disk space (solved 2026-10-26: ~40 GB free)

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

---

## 5. Phase 1 prototype (design review)
```powershell
node prototype/serve.mjs
```
- Laptop: http://localhost:5173/
- Phone on the same Wi-Fi: `http://<your-LAN-IP>:5173/` (printed by the server; on 2026-10-24 it was `10.64.76.207`)
- **Windows Firewall:** your Wi-Fi is set to *Public*, so Windows blocks incoming connections by default. Either allow Node.js when Windows asks (tick *Public networks* only while testing at home), or set your home Wi-Fi to *Private* in *Settings → Network & internet → Wi-Fi → (your network) → Network profile type*. Do not allow it on public Wi-Fi such as cafés or campus networks.
- Stop the server with `Ctrl+C` when you are done.

---

## 6. Sharing the design with the client (GitHub + Vercel)
- Design repo (public, design files only): https://github.com/Emmaco08/solutiontee-cbt-design, local copy `C:\solutiontee-cbt-design`.
- Refresh it after design changes:
```powershell
node prototype/publish/sync.mjs
cd ..\solutiontee-cbt-design; git add -A; git commit -m "Design update"; git push
```
- **Vercel (one-time, free Hobby plan):** vercel.com → sign in with GitHub → *Add New… → Project* → import `solutiontee-cbt-design` → Framework preset **Other**, no build command, output directory `.` (already set in `vercel.json`) → **Deploy**. Every push to `main` redeploys automatically. Production URLs are public; preview URLs are protected by Vercel login by default.
- **Vercel MCP (optional, lets Claude check deployments):** Claude desktop → Connectors → Vercel (https://mcp.vercel.com) → Connect and sign in. In the terminal version of Claude Code instead: `claude mcp add --transport http vercel https://mcp.vercel.com`, then run `/mcp` and authenticate.
- **Client feedback:** the client taps *Give feedback* in the prototype (needs a free GitHub account). Feedback lands in the repo's Issues tab.

---

## 7. Phase 2: Supabase, Brevo and the admin (owner steps)

Do these once. **Never paste keys or passwords into the chat.** Put them only where shown.

### 7.1 Supabase project (free)
1. Go to https://supabase.com, choose **Start your project**, and sign in with GitHub.
2. Create an organisation (Free plan), then **New project**:
   - Name `solutiontee-dev`.
   - Region **West EU (London)**.
   - Click *Generate a password*, then **save it in your password manager**.
3. Wait about 2 minutes for the project to start.

Free plan limits: 500 MB database, 1 GB storage, 50k monthly users. The project **pauses after about 7 days without use**; *Restore* brings it back. We add a separate `solutiontee-prod` project on the Pro plan before launch.

### 7.2 Link the CLI (in PowerShell, in `C:\solutiontee-cbt`)
```powershell
pnpm supabase login
```
A browser opens; approve it. Then:
```powershell
pnpm supabase link --project-ref YOUR_PROJECT_REF
```
- The project ref is the part of the project URL `https://YOUR_PROJECT_REF.supabase.co`, also shown in *Project Settings → General*.
- When asked, type the database password from 7.1. It is not shown on screen.

Tell me "linked" in the chat. Then I can push the database (`pnpm db:push`) and run the tests.

### 7.3 Keys for the admin website and the tests
In Supabase, open *Project Settings → API Keys* (and *Data API* for the URL). Then copy the two templates:
```powershell
Copy-Item apps\web\.env.example apps\web\.env.local
Copy-Item supabase\.env.example supabase\.env
```
Open each new file in Notepad and paste the values where the template says:
```powershell
notepad apps\web\.env.local
notepad supabase\.env
```
- `apps\web\.env.local` needs:
  - the project URL;
  - the **publishable / anon** key;
  - the **secret / service_role** key (server only; the site never sends it to the browser).
- `supabase\.env` needs the **database connection string** for the RLS tests: *Connect → Session pooler*, with your password filled in.

Both files are git-ignored and never leave your laptop.

### 7.4 Brevo email (6-digit login codes)
1. Create a free account at https://www.brevo.com. The free plan allows **300 emails per day**.
2. *Senders, Domains & Dedicated IPs → Domains → Add a domain*: `solutiontee.com`. Add the DNS records Brevo shows (Brevo code, DKIM, DMARC) at your domain host, then click **Verify**.
3. *Senders → Add a sender*: name `SolutionTee CBT`, email `no-reply@solutiontee.com`.
4. *SMTP & API → SMTP*: note the server (`smtp-relay.brevo.com`), port `587` and your login, then **Generate a new SMTP key**.
5. In Supabase, go to *Authentication → Emails → SMTP Settings* and turn on **Custom SMTP**:
   - sender email `no-reply@solutiontee.com`, sender name `SolutionTee CBT`;
   - host `smtp-relay.brevo.com`, port `587`;
   - username = your Brevo SMTP login, password = the SMTP key.
6. Still in *Authentication*, apply the settings below (they match `supabase/config.toml`).

| Where | Setting |
|---|---|
| Sign In / Providers → Email | Confirm email **on**, Secure password change **on**, Minimum password length **8**, Password requirements **letters and digits**, Email OTP expiration **600** s, Email OTP length **6** |
| Rate limits | Emails sent per hour **30** (raise later), Sign-ups/sign-ins per 5 min per IP **30**, Token verifications **30** |
| URL Configuration | Site URL `http://localhost:3000`; redirect URLs `http://localhost:3000/**`, `https://solutiontee.com/**`, `https://app.solutiontee.com/**` |
| Multi-Factor | **TOTP (App Authenticator)**: enabled |
| Emails → Templates → *Confirm signup* and *Magic Link* | Use the code template from `supabase/templates/otp.html` (I add it). It shows `{{ .Token }}`, the 6-digit code, instead of a link. |

### 7.5 Authenticator app
Install **Google Authenticator** or **Microsoft Authenticator** on your phone. The admin asks you to scan a QR code the first time you log in (2-step login is required for every admin).

### 7.6 Run the admin on your laptop
```powershell
pnpm install
pnpm web:dev
```
Open http://localhost:3000/admin, then stop it with `Ctrl+C` when done (low-RAM rule: one heavy process at a time).

### 7.7 Cloudflare R2 (images)
Images are stored in Cloudflare R2 (D-045).
1. Go to https://dash.cloudflare.com, sign up, then open **R2 Object Storage**. You must add a card, but the free tier is 10 GB storage plus 1 million writes and 10 million reads a month, and there is no download (egress) fee.
2. Create the buckets:
   - **`st-question-images`**: private (leave public access off).
   - **`st-public`**: news and onboarding pictures. *Settings → Public access → Custom domain* `cdn.solutiontee.com` (your domain must be on Cloudflare DNS for this), or use the r2.dev URL while testing.
3. On `st-question-images`, open *Settings → CORS policy* and allow `PUT` and `GET` from `http://localhost:3000` (and later `https://solutiontee.com`) so the admin can upload.
4. *R2 → Manage R2 API tokens → Create API token*: permission **Object Read & Write**, limited to the two buckets.
5. Put the **Account ID**, **Access Key ID** and **Secret Access Key** into `apps\web\.env.local` (the template shows where). Never put them in the app or in chat.

### 7.8 Commands I use (for reference)
| Command | What it does |
|---|---|
| `pnpm db:push` | Applies new migrations to the linked project |
| `pnpm db:test` | Runs the RLS security tests on the dev database (each test is rolled back) |
| `pnpm shared:test` | CSV parser/validator unit tests |
| `pnpm web:check` | Lint + type-check the admin website |
