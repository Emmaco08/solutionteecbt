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

### 7.9 Phase 2 status and how to use the admin (2026-10-27)
**Already done for you:**
- The Supabase project `solutiontee-dev` was created through the Supabase connector (Free plan, London). Its ref is `mxeemubacnmcmmmzteax`, and its URL is https://mxeemubacnmcmmmzteax.supabase.co.
- All database migrations are applied.
- Supabase generated the database password, so nobody knows it. You only need it for the CLI (`supabase link`) or `pnpm db:test`. Reset it in *Project Settings → Database → Reset database password*, and keep it in your password manager.

**Run the admin on your laptop** (one heavy program at a time):
```powershell
pnpm install
pnpm web:dev
```
Open http://localhost:3000/admin, then follow these steps:
1. **First run:** the page says *Set up your admin account*. Enter your name, email and a strong password (at least 10 characters, with letters and numbers). This creates the **super admin**, and the form disappears for good.
2. **2-step login:** scan the QR code with Google Authenticator or Microsoft Authenticator, then type the 6-digit code. Every login after that asks for a new code.
3. Things to try:
   - *CSV import*: download the template, fill a few rows, check them, then import.
   - *Question bank*: select rows and publish them.
   - *Exams & years*: tap a year to publish it.
   - *Free vs Premium*: change a rule, then save.
   - *Plans & prices*: confirm the prices.
   - *Staff*: invite an editor.
   - *Audit log*: see each change.
4. Stop the server with `Ctrl+C` when you finish.

**R2 checks (D-049):**
- In Cloudflare, open *R2 → your bucket → Settings*. **Public access** must be **off** for the bucket that holds question images.
- Add a CORS rule that allows `PUT` and `GET` from `http://localhost:3000`, so uploads from the admin work.

**Brevo for student login codes (needed in Phase 3):** in Supabase, go to *Authentication → Emails → SMTP Settings* and enter the Brevo SMTP details (§7.4). The admin's staff invites already use your Brevo API key.

### 7.10 Emails (2026-10-27)
Login codes, password-reset codes, welcome emails and staff invites are sent by SolutionTee through your Brevo account (D-050). You don't need to put the SMTP key into Supabase for these. Two optional Supabase settings make the codes match the design. In the Supabase dashboard, open *Authentication → Sign In / Providers → Email* and set:
- **Email OTP Length:** `6` (it is 8 now; the app works with either)
- **Email OTP Expiration:** `600` seconds (10 minutes)

Check delivery yourself:
1. Run the admin (`pnpm web:dev`), log in, and open **System → Emails**.
2. Press **Send me a test email**. It arrives from `info@mail.solutiontee.com`; check spam the first time.
3. The same page shows today's count (limit 280 a day) and previews every template.

*For developers:* with `EMAIL_TRANSPORT=log` in development, emails go to the server log instead (`docs/AUTH_EMAIL.md`).


## 8. Phase 3: the Android app on your phone

Installed on the laptop (2026-10-28/29): Flutter stable at `C:\dev\flutter`, JDK 17 at `C:\dev\jdk-17`, Android command-line tools in `%LOCALAPPDATA%\Android\Sdk`. `JAVA_HOME`, `ANDROID_HOME` and `PATH` are set for your Windows user. `flutter config --jdk-dir=C:\dev\jdk-17` is set, because Android Studio's Java 25 is too new for Gradle. There is no emulator and Android Studio is not used.

Full steps are in `apps/mobile/README.md`. In short:

1. Phone: turn on Developer options → **USB debugging**, plug in, tap **Allow**.
2. `adb devices` (you should see `device`), then `adb reverse tcp:3000 tcp:3000`.
3. `pnpm -C apps/web dev` (the website API the app uses for codes, images and account deletion).
4. `cd apps/mobile`, then `flutter run -d <your phone id>`.

**Sample papers (dev only).** The dev database has `[SAMPLE]` papers so you can try the CBT:
- JAMB English, Maths, Physics and Chemistry for 2001–2004. A Free account opens 2001–2003, and 2004 shows as locked.
- WAEC Maths for 2001–2002.

They are not real past questions. Remove them once real questions are imported. The delete commands are at the bottom of `supabase/seed/dev-sample-questions.sql`.

**Still yours to do:**
- **OTP length.** In Supabase → Authentication → Providers → Email, set *Email OTP length* to 6 and *expiry* to 600 seconds. The app already works with 8-digit codes.
- **App icon.** Provide a 512×512 PNG icon (Play Store and launcher). The app still shows Flutter's default launcher icon until then.

## 9. Phase 4: accounts to prepare (do them when convenient)

**NVIDIA API key (needed for milestone 4B, the AI tutor)**
1. Go to build.nvidia.com and sign in or create a free account.
2. Open any model page, click **Get API Key**, then **Generate Key**. The key starts with `nvapi-`.
3. Put it in `apps/web/.env.local` as `NVIDIA_API_KEY=nvapi-...`. Never paste it in chat.
4. Later I will ask you to run one command that stores it as a Supabase Edge Function secret.

**Firebase (needed for milestone 4D, push notifications)**
1. Go to console.firebase.google.com, then **Add project**. Name it `SolutionTee CBT`; Analytics is optional.
2. Click **Add app**, then **Android**, with package name `com.solutiontee.cbt`.
3. Download `google-services.json` and save it as `apps/mobile/android/app/google-services.json`. This file is ignored by git.
4. Go to Project settings → Service accounts → **Generate new private key**. Save the JSON as `apps/web/.secrets/firebase-admin.json` (also ignored by git). Never paste it in chat.

**Google Play Console (needed for the `play` build, milestone 4C)**
- A Play Console developer account (one-off $25) for SolutionTee.
- Payments can be tested with Paystack (test keys already set) until then.

## 10. The website on Vercel (2026-10-30)
The website (admin, sign-up codes, file links) runs on Vercel, so you can use the admin from any computer or phone.
- **Address:** https://admin.solutiontee.com/admin (your domain, added in *Vercel → Project → Settings → Domains*). https://solutiontee-cbt.vercel.app also works. The app calls the website at admin.solutiontee.com.
- **Account:** Vercel team `solution-tee`, project `solutiontee-cbt`. The project builds `apps/web`.
- **Keys:** copied from `apps/web/.env.local` into *Vercel → Project → Settings → Environment Variables* (Production and Preview). If you change a key, change it in both places and redeploy.
- **Deploy again** (from `C:\solutiontee-cbt`): `npx vercel@65.8.0 deploy --prod`. Only the website and `packages/shared` are uploaded (`.vercelignore`).

### 10.1 R2 CORS (needed for uploads, one time)
Uploads go straight from the browser to R2. The bucket must allow the admin's web address, or every upload fails with "CORS not configured".
1. Open https://dash.cloudflare.com → **R2 Object Storage** → bucket **solutiontee** → **Settings** → **CORS Policy** → **Add CORS policy** (or Edit).
2. Paste this and save:
```json
[
  {
    "AllowedOrigins": [
      "http://localhost:3000",
      "https://solutiontee-cbt.vercel.app",
      "https://solutiontee.com",
      "https://www.solutiontee.com",
      "https://app.solutiontee.com",
      "https://admin.solutiontee.com"
    ],
    "AllowedMethods": ["GET", "PUT", "HEAD"],
    "AllowedHeaders": ["content-type", "range"],
    "ExposeHeaders": ["ETag", "Content-Length", "Content-Range"],
    "MaxAgeSeconds": 3600
  }
]
```
3. To check it from the laptop: `node scripts/r2-cors.mjs` in `apps/web` (the R2 key has no permission to read bucket settings, so a 403 there is normal; the upload test is the real check).

## 11. AI tutor (2026-11-03)
Everything is in **Admin → AI tutor** (https://admin.solutiontee.com/admin/ai), for super admins and admins.
1. **Replace the test keys** that were shared in chat:
   - **NVIDIA:** https://build.nvidia.com → your account → API keys → create a new key, then delete the old one.
   - **Dahl:** https://inference.dahl.global/account → create a new key, then delete the old one.
   - In the admin, under **Providers**, press **Change key** on each and paste the new key, then press **Test**.
2. **Dahl tokens:** on the Dahl account page, allocate your free tokens to the key. Without them the key answers "tokens exhausted" (402) and NVIDIA keeps answering alone.
3. **Knowledge:** under **Knowledge from your notes**, press **Add new and edited notes** once now. Press it again after adding many notes, so the tutor uses them.
4. **Models:**
   - **Add one:** pick the provider, press **Load model list**, choose a model, set **Used for** (text, photo or knowledge), save, then press **Test** on the new row.
   - **Order:** a lower number is tried first.
   - **Photos:** only put models that can read pictures under **Photo questions**.
5. **Limits:** the daily prompts (Free 3, Premium 100) are in **Free vs Premium** ("AI tutor prompts").
6. **Before launch:** check that NVIDIA's and Dahl's terms allow production use for SolutionTee, and plan paid capacity if usage grows (NVIDIA's free API is about 40 requests a minute per key).


## 12. Test app download page (2026-11-03)

Share **https://admin.solutiontee.com/download** with the team (Android only). To publish a new test version:

```
cd apps/mobile
flutter build apk --release --flavor direct --target-platform android-arm64
cd ../web
node scripts/upload-apk.mjs
```

The page picks up the new file at once (no website deploy needed). Testers install over the old version and keep their account.

## 13. Automatic app builds on GitHub (2026-11-03)

Add these at **github.com/Emmaco08/solutionteecbt → Settings → Secrets and variables → Actions → New repository secret**. Type them yourself; never paste them in chat.

| Secret name | Where to get the value on the laptop |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\solutiontee-cbt\apps\mobile\android\app\upload-keystore.jks")) \| Set-Clipboard`, then paste |
| `ANDROID_KEYSTORE_PASSWORD` | `apps/mobile/android/key.properties`, the `storePassword=` value |
| `ANDROID_KEY_PASSWORD` | same file, the `keyPassword=` value |
| `ANDROID_KEY_ALIAS` | `upload` |
| `R2_ENDPOINT` | `apps/web/.env.local`, the `R2_ENDPOINT=` value |
| `R2_BUCKET` | `apps/web/.env.local`, `R2_BUCKET=` |
| `R2_ACCESS_KEY_ID` | `apps/web/.env.local`, `R2_ACCESS_KEY_ID=` |
| `R2_SECRET_ACCESS_KEY` | `apps/web/.env.local`, `R2_SECRET_ACCESS_KEY=` |

Then on GitHub: **Actions → Android app → Run workflow**. About 10–15 minutes later the new app is at https://admin.solutiontee.com/download (main) or https://admin.solutiontee.com/download?channel=test (other branches).

**Back up the signing key:** copy `upload-keystore.jks` and `key.properties` to a private place (e.g. your own Google Drive). If it is lost, phones cannot update the app without uninstalling.

## 14. Payments (milestone 4C, 2026-11-03)

Premium is given only by our server after it checks the payment with Paystack or Google (D-061). **Never paste keys in chat.** You type them only into the Supabase and Paystack dashboards, as below.

### 14.1 Paystack (test mode first) — needed now
1. Open https://dashboard.paystack.com and make sure the switch at the top says **Test mode**.
2. *Settings → API Keys & Webhooks.* Copy the **Test Secret Key** (starts with `sk_test_`).
3. Open https://supabase.com/dashboard/project/mxeemubacnmcmmmzteax/functions/secrets → **Add new secret**:
   - Name `PAYSTACK_SECRET_KEY`, value = the test secret key. Save.
   - Optional: name `PAYSTACK_CALLBACK_URL`, value `https://admin.solutiontee.com/pay/done` (the "go back to the app" page; works after the next website deploy).
4. Back in Paystack *Settings → API Keys & Webhooks*, set **Test Webhook URL** to:
   `https://mxeemubacnmcmmmzteax.supabase.co/functions/v1/paystack-webhook` and save.
5. The public key is **not** needed: the server starts every payment.
6. Tell me "Paystack keys set" in the chat (no key in the message).

**Test it on your phone** (after installing a new `direct` build):
1. Log in with a test student account (not your own admin account), tap a locked item → paywall → *Continue* → *Pay*.
2. Paystack opens. Choose **Card** and use Paystack's test card `4084 0840 8408 4081`, any future expiry, CVV `408`, PIN `0000`, OTP `123456`.
3. Close the Paystack page. The app shows *Checking payment*, then *You are now Premium!*
4. Admin → **Payments**: the payment shows *Paid* with a timeline (started → Paystack checkout opened → webhook → verify → Premium given).
5. Optional: in Paystack *Transactions*, resend the webhook. The payment still has one Premium (shown in the timeline as a repeat).
6. Optional: press **Refund** on the payment. Premium is removed when Paystack finishes the refund.

**Going live later (Phase 6):** switch Paystack to Live mode, put the `sk_live_` key in the same Supabase secret, and set the **Live Webhook URL** to the same address.

### 14.2 Redeem codes — ready now
Admin → **Redeem codes**: make a shared code (e.g. `LOYOLA20`, 20% off) or a batch of one-use codes (download them as CSV). Free-day codes are typed by students in the app: Me → *Redeem a code*. Discount codes work only with Paystack (Google allows only its own promo codes in the Play app).

### 14.3 Google Play (the Play Store build) — later, when you have Play Console
1. Create the app in Play Console (package `com.solutiontee.cbt`) and upload a `play` build to **Internal testing**: `flutter build appbundle --release --flavor play` (needs the upload key, set up at launch).
2. *Monetise → Products → In-app products*: create one product per plan, type one-time, with these IDs (or your own, then put them in Admin → Plans → *Google Play product ID*): `premium_monthly`, `premium_three_months`, `premium_exam_season`. Set the same prices as Admin → Plans.
3. Google Cloud console (the project linked to Play Console): create a **service account**, make a **JSON key**. In Play Console *Users and permissions*, invite the service account email with **View financial data** and **Manage orders and subscriptions**.
4. Supabase → Edge Functions → Secrets: add `GOOGLE_PLAY_SERVICE_ACCOUNT` = the whole JSON key file content (open it in Notepad, copy all). Never send it in chat.
5. Refund notices: in Google Cloud create a Pub/Sub topic (e.g. `play-rtdn`), give `google-play-developer-notifications@system.gserviceaccount.com` the *Publisher* role on it, and add a **push** subscription to
   `https://mxeemubacnmcmmmzteax.supabase.co/functions/v1/play-rtdn?token=<a long random password you make up>`.
   Put the same random password in Supabase secrets as `PLAY_RTDN_TOKEN`. Then in Play Console *Monetisation setup* enter the topic name and press *Send test notification*.
6. Add your testers as **licence testers** in Play Console (*Settings → Licence testing*) so test purchases are free.
