# Google Play launch kit — SolutionTee CBT

Everything to put SolutionTee CBT on Google Play, in order. Prepared 8 November 2026 (D-118).
Package name: **`com.solutiontee.cbt`**. Pages and files referred to below are all live or in this folder.

## 0. Files in this kit

| What | Where |
|---|---|
| **App file to upload (.aab)** | https://admin.solutiontee.com/download/aab (newest build, made by GitHub after every app change) |
| App icon 512 × 512 | `graphics/app-icon-512.png` |
| Feature graphic 1024 × 500 | `graphics/feature-graphic-1024x500.png` |
| Phone screenshots 1080 × 1920 (5) | `graphics/phone-1-cbt.png` … `graphics/phone-5-leaderboard.png` |
| Privacy Policy | https://cbt.solutiontee.com/privacy |
| Terms of Service | https://cbt.solutiontee.com/terms |
| Refund Policy | https://cbt.solutiontee.com/refunds |
| Delete account (without the app) | https://cbt.solutiontee.com/delete-account |
| app-ads.txt (AdMob) | https://cbt.solutiontee.com/app-ads.txt |

The screenshots show the app's real screens (exam, results, AI tutor, study, leaderboard) as drawn by our design. You may
replace them with your own phone screenshots later: in admin → Flags & settings, turn off "Block in the whole app" while
you take them, then turn it back on.

## 1. Before you start (one time)

1. **Developer account:** play.google.com/console → create the account (one-time US$25).
   - **Organisation** account (recommended for the business): needs a **D-U-N-S number** for SOLUTIONTEE EDUTECH AND ICT
     SERVICES (free from Dun & Bradstreet, takes days to weeks).
   - **Personal** account: before going public you must run a **closed test with at least 12 testers for 14 days**.
2. **Email addresses:** create **privacy@solutiontee.com** (it is in the Privacy Policy) and make sure
   support@mail.solutiontee.com receives mail.
3. **Reviewer account** (Google's reviewers must log in): in Supabase → Authentication → Users → **Add user** →
   email `playreview@solutiontee.com` (or any address you own), a strong password, tick **Auto confirm**. Open the app once
   with it and finish setup with a birth year that makes it 18+. Keep the password to yourself; you type it only into
   Play Console (section 4.2). Optional: give it Premium in admin → Users so reviewers can see everything.
4. **AdMob:** the app already uses your App ID `ca-app-pub-2578359096210288~4598149074`. Put the ad unit IDs in admin →
   Money → Ads and keep **Test mode on** until the app is live on Play. Then, in AdMob:
   - **Privacy & messaging → European regulations → Create message** (pick the app, languages English, Publish). The
     app shows it only to students in the EEA, UK and Switzerland (D-119).
   - **Apps → View all apps → link the app to Google Play** once it is published, so AdMob checks
     `https://cbt.solutiontee.com/app-ads.txt`. In Play Console → Store settings, set **Website** to
     `https://cbt.solutiontee.com`. If AdMob still says "not found", put the same one-line file at
     `https://solutiontee.com/app-ads.txt` too.
5. **Payment settings for the review** (admin → Money → Payment settings): **Google Play payments: on**,
   **"Pay on our website" button: off**, **"Have a code?": off**. Google rejects apps that send users to other ways
   to pay; you can change these after approval at your own risk (see the warning on that page).

## 2. Create the app

Play Console → **Create app**:
- **App name:** `SolutionTee CBT – JAMB & WAEC` (29/30) — or `SolutionTee CBT: Exam Practice` (30/30)
- **Default language:** English (United Kingdom) – en-GB
- **App or game:** App · **Free or paid:** Free
- Tick the declarations (Developer Program Policies, US export laws) → **Create app**.

## 3. Upload the first build (Internal testing)

1. Download the newest **.aab** from https://admin.solutiontee.com/download/aab.
2. Play Console → **Test and release → Testing → Internal testing → Create new release**.
3. **App integrity / App signing:** choose **"Let Google manage and protect your app signing key"** (recommended).
   - The .aab is signed with our key; Google treats it as the **upload key**. Keep using files from /download/aab for
     every update.
   - Because Google re-signs the Play version, the Play version and the website (APK) version cannot install over each
     other: a student who switches must uninstall first. Their account and Premium stay (they live on the server).
4. Upload the .aab, release name e.g. `0.3.0`, **release notes**:

   > First release of SolutionTee CBT: real CBT practice for JAMB, WAEC and NECO, explanations for every answer, AI tutor, video solutions, lesson notes, challenges and leaderboards.

5. **Testers:** create an email list with your own Gmail and your team → Save → **Review release → Start rollout to
   Internal testing**. Open the tester link on your phone and install from Google Play.
6. **Licence testing** (Settings → Licence testing): add the same Gmail addresses so test purchases are free.

## 4. App content (Policy → App content)

### 4.1 Privacy policy
`https://cbt.solutiontee.com/privacy`

### 4.2 App access
**All or some functionality is restricted** → Add instructions:
- Name: `Reviewer account`
- Username / email: the reviewer email from step 1.3 · Password: the one you set
- Instructions: *"Open the app → Log in with email and password. Test → Quick test (a timed CBT). AI Tutor → ask
  'Explain photosynthesis'. Study → Lesson notes. Premium screen: Me → Get Premium (Google Play test purchase)."*

### 4.3 Ads
**Yes, my app contains ads.**

### 4.4 Content rating (IARC questionnaire)
- Email: support@mail.solutiontee.com · Category: **Reference, news, or educational**
- Violence / fear / sexuality / bad language / drugs / alcohol / tobacco: **No** to all
- Gambling: **No** (no real-money gambling, no simulated gambling; challenges give Premium days and XP)
- User interaction: users can interact or exchange content? **No** (no chat between users; the AI tutor is moderated)
- Shares user's current location with others? **No** · Digital purchases? **Yes**
- Expected result: **Everyone / PEGI 3 (3+)**, "In-app purchases", "Contains ads"

### 4.5 Target audience and content
- Target age groups: **13–15, 16–17, 18 and over** (do **not** tick under 13)
- Could the app unintentionally appeal to children? **No** (exam preparation for secondary-school students)
- The app blocks under-13 sign-ups and never shows personalised ads to under-18s.

### 4.6 Data safety
- Does your app collect or share user data? **Yes** · Encrypted in transit? **Yes**
- Account creation: **Username and password / other** (email + password, Google sign-in)
- **Delete account URL:** `https://cbt.solutiontee.com/delete-account` · Users can ask for data deletion: **Yes**

| Data type | Collected | Shared | Required? | Purposes |
|---|---|---|---|---|
| Name | Yes | No | Required | App functionality, Account management |
| Email address | Yes | No | Required | App functionality, Account management, Developer communications |
| User IDs | Yes | No | Required | App functionality, Account management, Fraud prevention |
| Phone number | Yes | No | Optional | Account management |
| Other info (state, school, year of birth, exams, parent/guardian email) | Yes | No | Required (year of birth, state) | App functionality, Personalisation |
| Purchase history | Yes | No | Optional | App functionality |
| Approximate location (from IP, by AdMob) | Yes | Yes | Required | Advertising or marketing, Analytics, Fraud prevention |
| Photos | Yes | No | Optional | App functionality (AI tutor question photos, profile photo) |
| Other in-app messages (AI tutor chats) | Yes | No | Optional | App functionality |
| App interactions | Yes | Yes (AdMob) | Required | App functionality, Analytics, Advertising or marketing, Fraud prevention |
| Other user-generated content (answers, reports, appeals) | Yes | No | Optional | App functionality |
| Crash logs and Diagnostics (AdMob and Firebase SDKs) | Yes | Yes | Required | Analytics, Advertising or marketing, Fraud prevention |
| Device or other IDs (advertising ID, push token, hashed device IDs) | Yes | Yes (advertising ID with AdMob) | Required | Advertising or marketing, Fraud prevention, App functionality |
| Voice or sound recordings | **No** (the phone turns speech into text; the app receives text only) | | | |

Not collected: precise location, contacts, calendar, health, files and documents, web browsing, SMS, call logs.
Service providers acting for us (Supabase, Neon, Cloudflare, Brevo, Paystack, NVIDIA) are **not "shared"** under Google's definitions.

### 4.7 Other declarations
- **Advertising ID:** Yes, the app uses it → Advertising or marketing, Analytics, Fraud prevention.
- **Government app:** No · **Financial features:** No · **Health:** No · **News app:** No
- **Photo and video permissions / Foreground service / Exact alarms:** not used (the app uses Android's photo picker).
- **Real-money contests:** not offered (cash prizes are switched off).

## 5. Store listing (Grow → Store presence → Main store listing)

- **App name:** `SolutionTee CBT – JAMB & WAEC`
- **Short description (74/80):** `Practise JAMB, WAEC & NECO past questions in a real CBT, with an AI tutor.`
- **Full description (2,445/4,000):**

```
Practise like it’s the real exam.

SolutionTee CBT helps Nigerian secondary-school students prepare for JAMB UTME, WAEC WASSCE and NECO SSCE with a computer-based test (CBT) that feels like exam day, clear explanations for every answer and an AI tutor that helps you understand.

★ A REAL CBT EXPERIENCE
• Timed tests that look and work like the real computer-based exams
• Switch subjects, flag questions, use the calculator and the question map
• Full JAMB mocks (English + 3 subjects), quick tests, topic drills and custom exams
• Auto-submit when time runs out; nothing is lost if your phone goes off

★ YOUR SCORE THE MOMENT YOU FINISH
• Estimated JAMB score out of 400 and your score in each subject
• Accuracy, time per question and progress over time
• Every question with the right answer and a step-by-step explanation
• Weak topics to practise next

★ AI TUTOR FOR SCHOOLWORK
• Type a question or snap a photo of it
• Step-by-step working in simple English, with the final answer clearly marked
• Ask it to explain again, give you a quick quiz or plan your study week
• It only helps with schoolwork, so it is safe for students

★ STUDY HUB
• Past questions in study mode, with answers and explanations
• Video solutions and topic lessons
• Lesson notes with formulas, JAMB literature novels, the syllabus and brochures
• Download to study offline

★ CHALLENGES, STREAKS AND LEADERBOARDS
• Weekly challenges with the same questions for everyone
• National and state leaderboards
• Daily question, XP and streaks to keep you going
• Win Premium days and XP

★ MADE FOR NIGERIAN STUDENTS
• Works offline: practise without data and sync later
• Data saver and small downloads
• Light and dark mode

FREE AND PREMIUM
SolutionTee CBT is free to use, with daily free practice and ads. Premium opens every past-question year, video solutions, lessons and notes, gives more AI tutor help and removes ads. Premium is a one-time purchase for the period you choose; it does not renew by itself.

FOR STUDENTS AGED 13 AND OVER
Students aged 13 to 17 give a parent’s or guardian’s email so we can let them know they joined. Students under 18 never see personalised ads.

Privacy Policy: https://cbt.solutiontee.com/privacy
Terms: https://cbt.solutiontee.com/terms
Help: support@mail.solutiontee.com · WhatsApp +234 812 244 5948

SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.
```

- **App icon:** `graphics/app-icon-512.png` · **Feature graphic:** `graphics/feature-graphic-1024x500.png`
- **Phone screenshots:** the 5 files `graphics/phone-*.png` (in order 1 → 5)
- Tablet screenshots: not needed (leave empty).
- **Store settings:** Category **Education**; Tags: *Exam preparation*, *Study*, *Education* (choose what Play offers);
  Contact email **support@mail.solutiontee.com**, phone **+234 812 244 5948**, website **https://cbt.solutiontee.com**.
- **Do not** use the JAMB, WAEC or NECO logos in the icon, graphics or screenshots (our graphics don't).

## 6. Premium products (Monetise → Products → In-app products)

Create three **one-time** products (Play Console calls them *one-time products*), each **active**, priced in Naira:

| Product ID | Name | Price (same as admin → Plans) |
|---|---|---|
| `premium_monthly` | Premium · 30 days | ₦2,000 |
| `premium_three_months` | Premium · 90 days | ₦5,000 |
| `premium_exam_season` | Premium · Exam Season | ₦7,000 |

Then admin → Money → **Plans & prices**: put each ID in *Google Play product ID*.
- **Google's fee option:** to pass Google's 15% on to students, also create `premium_monthly_fee`,
  `premium_three_months_fee`, `premium_exam_season_fee` at the prices shown in admin → Payment settings, put them in
  *Google Play product ID with fee*, and turn on "Add Google's fee".
- **Google Play promo codes** (free Premium from Google): Monetise → Promo codes; students type them in Google's payment screen
  ("Redeem code").
- Server checks (already built): follow SETUP §14.3 steps 3–5 (service account → `GOOGLE_PLAY_SERVICE_ACCOUNT`
  secret; Pub/Sub refunds → `PLAY_RTDN_TOKEN`).

## 7. Countries and release

1. **Test and release → Production → Countries / regions:** Nigeria (add more if you like).
2. Personal accounts: **Closed testing** with 12+ testers for 14 days first (Play Console shows the progress), then
   **Apply for production**.
3. Production → **Create new release** → upload the newest .aab → release notes (as above) → **Review and roll out**.
   Google's first review usually takes a few days.
4. After approval: put the Play link in admin → Payment settings → **Google Play link**; the website's Google Play
   button switches on. Turn AdMob **Test mode off**.

## 8. Every update after launch

Push app changes as usual → GitHub builds → download the new .aab from /download/aab → Play Console → Production (or a
testing track) → Create new release → upload → roll out. The version number goes up by itself.
