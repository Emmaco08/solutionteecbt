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

**D-023 · 2026-10-25 · Calculator display fixed (owner bug report)**
The answer had no display panel, used a 34 px font that crowded the sum line, and long answers could wrap or spill. Now: a clear display panel (sum line on top, answer below), numbers with thousands separators, the answer shrinks to fit one line (40 to 20 px), very large/small answers shown as 9.99999 × 10²⁰, 15-digit precision (exact 123,456,789 × 98,765), "Can't divide by 0", correct operator chaining after "=", changing an operator by pressing another, and laptop keyboard support. Live region announces the answer to screen readers.

**D-024 · 2026-10-25 · Redeem codes for student discounts (owner request, beyond SPEC v1)**
- **Admin → Redeem codes:** create a code that gives % off, ₦ off, or free Premium days; choose plans; one shared code (e.g. LOYOLA20, with a total-use limit) or a batch of unique one-use codes (PREFIX-XXXX-XXXX from an alphabet without 0/O/1/I/L, crypto-random); start/end dates; one use per student; new students only; internal note; live "student sees" preview; copy/CSV export; pause/resume; usage bars; audit log.
- **Student:** "Have a discount code?" at checkout (direct/website builds) with price breakdown and clear errors (not found, expired, used, wrong plan, free-days code); "Redeem a code" in Me for free-day codes; savings shown on the receipt.
- **Google Play rule:** the Play build cannot discount Play Billing prices with our own codes, and must not steer to the website, so it only says Google Play promo codes go on the Google Play payment screen (created in Play Console). **Owner/legal to confirm** whether free-day codes may be redeemed inside the Play build.
- **Phase 2/4 server work:** tables `promo_codes` (code unique case-insensitive, type, value, plan_ids, max_uses, per_user_limit, new_users_only, starts_at, ends_at, status, note, created_by) and `promo_redemptions` (code, user, payment, discount, redeemed_at); the price is computed only on the server when the Paystack transaction is initialised (client total is display only); redemption counted atomically when the payment webhook is verified (refund/cancel releases it); free-day codes create an `entitlements` row with source `code`; rate-limit code attempts per user/IP to stop guessing; admin actions in the audit log.

**D-025 · 2026-10-25 · Owner feedback batch (bugs)**
- **Tour came back after Back:** the tour screen stayed in history. Ending or skipping the tour now replaces it with Home, so Back never re-opens it. Steps whose target is hidden (e.g. Upgrade for Premium students) are skipped instead of ending the tour.
- **Subject / Topic modes did nothing:** Test setup is rebuilt. JAMB: Full exam (4 subjects, 180 Q, 2 h, /400), Subject (one subject, 40 or 60 Q, 30 min, /100), Topic (subject, then topics, then 10/20/30 Q, 1 min per question), Quick (20 mixed Q, 15 min). WAEC/NECO: One subject (50 Q, 1 h) and Topic. Summary card and Start button update live; Topic needs at least one topic.
- **Always resumed the old test:** a test from Test setup now always starts EMPTY. The old attempt is only resumed from "Continue your test" (Home, Welcome back, Downloads) or by choosing "Continue unfinished test" in the dialog shown when a new test is started while one is unfinished; choosing "Start new test" submits the unfinished one so its score counts. The Continue card only appears when an unfinished attempt with answers exists, and disappears after submitting.
- **Submit hard to find:** a red "Submit" button sits in the CBT top bar next to the timer, and Next turns into a red Submit on the last question. (The Submit entry hidden at the end of the subject tabs was removed.)
- **WAEC/NECO stayed locked on Premium:** the payment-success screen reset the plan to Free. Premium now persists, and every screen reads the plan: exam cards, Test hub, test setup, past-question years and exams, videos, profile badge, upgrade banners hidden, 100 AI prompts. Prototype has a "Student plan: Free / Premium" switch (side panel and phone menu) for reviewers.

**D-026 · 2026-10-25 · News, leaderboard and better question of the day (owner request, beyond SPEC v1)**
- **News:** Home carousel of cards with cover images, a News screen (categories: JAMB registration, New questions, Classes, Exam tips…; pinned post on top) and a full article screen (cover, body, action button such as "Open the JAMB brochure", share, more news, reading progress). **Admin → News:** headline, category, cover image upload (shrunk to ~1200 px, e.g. 1.4 MB to 16 KB), summary, full story, optional button and target, pin, push notification, schedule, live card/story preview, published list. In the prototype a post is saved in that browser only; in Phase 2 posts live in a `news_posts` table with images in Storage and RLS (published rows readable by all signed-in students).
- **Leaderboard:** per JAMB year (current season ranks live; past years show the best student), Nigeria or My state, podium for top 3, ranks with movement, the student's own rank pinned at the bottom, rules sheet. **Admin → Leaderboard:** master on/off (when off, students see it nowhere), which years are visible, name format (first name + initial, never full names, because many students are minors), minimum full mocks to qualify. Students can hide themselves in Settings. Production default should be OFF until the owner switches it on. Phase 2: computed server-side from verified attempts; suspicious attempts (too fast/too perfect) held for review.
- **Question of the day:** subject + source year, a question-of-the-day streak, countdown to the next question, one attempt, right/wrong result, % of students who got it right, explanation with LaTeX, Ask AI, Share or "Similar question". Phase 2: scheduled from the CMS, rotated across the student's subjects.

**D-027 · 2026-10-26 · New Free plan, controlled by admin (owner request; replaces SPEC §7 defaults)**
- **Free now includes:** JAMB, WAEC and NECO CBT with 3 years each; study-mode past questions with answers for 2 years per exam; 2 syllabus/brochure documents; 3 AI prompts a day; challenges and events. **Not on Free:** video solutions, topic video lessons, lesson notes, novels.
- **Admin → Free vs Premium:** one table sets every limit for both plans: years per exam (number, All, or 0 = closed), study-mode years, oldest or newest years, each study feature on/off, number of syllabuses, AI prompts, offline downloads, challenges. Admin can also remove things from Premium. The paywall benefits are written from these rules, so they are always true. Free cannot be given more AI prompts than Premium.
- App enforcement in the prototype: every screen reads the rules (`ST.rule/can/yearOpen`); screens marked with a `needs` feature show a locked page instead of loading. **Phase 2:** rules live in `free_access_rules` per plan; RLS and the question-pack endpoint only return years/features the student's plan allows (locked content never reaches the phone).

**D-028 · 2026-10-26 · Challenges & events with cash prizes (owner request, beyond SPEC v1)**
- **Student:** Home "LIVE NOW · Win ₦20,000" card, Test → Challenges & events (live, coming up, past winners), challenge page (prizes or reward, entry free or paid, winner rule, fair-play rules + required agreement), one-question-at-a-time challenge with per-question timer, result with live rank, prize claim (18+ or guardian for under-18, bank + 10-digit account checked by name; no PIN/card/password ever asked), My winnings in Me. New onboarding slide 2 "Win cash prizes every week" and a tour step.
- **Admin → Challenges & events:** create cash challenge / event / practice; questions written new, picked from the bank or CSV; start, close, seconds per question; free or paid entry; reward cash (1st/2nd/3rd), Premium days, badge or none; winner rule; fair-play switches; push; fair-play review queue (keep disqualified / reinstate); winners to pay (Paystack Transfer, two-admin approval above ₦50,000).
- Open to Free and Premium (controlled by the `compete` rule).

**D-029 · 2026-10-26 · Anti-cheat for cash challenges**
Owner rule: when cheating is detected, submit automatically and disqualify. Layers (native app in Phase 4; the prototype demonstrates the first ones in the browser):
1. Leaving the challenge (app switch, home button, notification shade app, split screen, floating/overlay window, losing focus) → immediate auto-submit + disqualification. Prototype: `visibilitychange`, window blur and full-screen exit really trigger it; "Simulate cheating" in the side panel. Admin can allow 0–3 exits.
2. Screenshots/screen recording blocked (Android FLAG_SECURE), copy/paste/long-press disabled.
3. One question at a time, per-question timer, no going back, questions and options shuffled per student, only the current question is sent to the phone; answers checked on the server (no answer key on the device).
4. New questions written for each cash challenge (not searchable past questions).
5. Server-side review: too-fast or uniform answer times, identical answer patterns, duplicate phone/account/NIN → flagged; prizes only paid after review.
6. Device integrity (Play Integrity: no rooted phones/emulators), one account per person and device, identity check for winners.
Disqualified students get a clear reason and can appeal within 24 hours (e.g. a phone call).
**Owner/legal decisions needed before launch:** cash prizes and especially **paid entry** may fall under Nigerian lottery/gaming rules (National Lottery Act, state gaming authorities) and need a licence; many players are under 18; Google Play's real-money contest rules may block paid entry in the Play build (planned remote flag `paid_events_in_play_build`, default off); prize payouts need KYC and may have tax implications. Paid entry should stay off until a lawyer confirms.

**D-030 · 2026-10-26 · Challenge rules: one attempt, winners at close, tie-breaks, claim form (owner)**
- **New live indicator:** a quiet "broadcast" pill (ripple dot + LIVE + optional detail such as "1,284 playing"), light and dark versions, replaces the generic red badge everywhere (Home hero, challenge lists, onboarding art, Test hub). Ripple off under reduce motion.
- **One attempt:** each student can take a challenge once (finished or disqualified). The challenge page then shows their score and "Each challenge can be taken only once"; opening the play screen again goes to the result. Server: unique (challenge_id, user_id) attempt row created when the first question is served.
- **Ranking:** best score, then fastest time, then the student who **started earlier**. The result and winners screens show start times and explain each tie.
- **Winners announced the moment it closes:** automatic (no manual step); push + in-app "You won ₦X" with **Send my account details** (the claim form), to be completed within 7 days. Non-winners see their final place. Admin can also close early ("Close now").

**D-031 · 2026-10-26 · Referral programme (owner request, admin-configurable)**
Student gets a code/link (TOLU-7K3P). Defaults set in Admin → Referrals: **10% off per successful friend**, **10 friends = 100% off (free Premium, 3 Months)**, **30 friends (total) = ₦5,000 cash** paid to the bank after verification; a friend counts when they verify their phone and finish one practice test on their own phone (admin can choose "verify only" or "buys Premium"); monthly cap. Using a discount spends those friends; the cash counter never resets. Screens: Invite friends (code, WhatsApp share, discount meter, cash progress, friends list with Pending/Blocked), referral field on Sign up, Home and Me entry points. Admin: rules with live preview (warns when step × friends < 100%), cash rewards due (pay / review), top referrers.

**D-032 · 2026-10-26 · One person, one account (multiple accounts, app cloners) and bans**
Planned protections (native, Phase 3–4), shown in the prototype screens and admin:
- **One account per phone:** device ID bound to the account on the server (Android ID for our signing key + Play Integrity device verdict + hardware key attestation). A second sign-up on the same phone is blocked ("This phone already has an account").
- **App cloners / dual apps / work-profile copies blocked:** checks for a non-primary Android user or work profile, app data path not matching the real install, known cloner packages (Parallel Space, Dual Space, App Cloner, Island/Shelter), re-signed APK (signature check), Play Integrity "app not recognised", root/emulator/hooking frameworks. Detection shows a blocking screen and logs the device.
- **Identity signals:** phone number OTP before any reward or prize; one phone number, one NIN and one bank account per person; disposable emails blocked; sign-up bursts from one IP flagged.
- **Referral rules:** a friend only counts on a different phone, phone number, IP pattern and payment method; flagged groups have rewards held.
- **Enforcement:** linked-account groups appear in Admin → Fraud & bans; "Ban all" bans every linked account and the device, cancels unpaid rewards and prizes; banned students see a ban screen with one appeal within 14 days. Everything goes to the audit log.
No method is 100% (a determined person with several phones and SIMs can still try), so payouts always wait for review and KYC.

**D-033 · 2026-10-26 · Proof of payment / Winners wall (owner request)**
After paying a winner (or a referral cash reward), admin uploads the transfer receipt, must confirm that the account number, balance and other private details are hidden, can add the winner's message (with permission), and publishes it to the **Winners wall** (and optionally News). Students see the total paid, each winner (first name + initial, state), place, amount and the receipt image. Minors are paid through a guardian and shown by first name only. Sample receipts in the prototype are clearly labelled SAMPLE.

**D-034 · 2026-10-26 · Security plan; downloads are Premium only**
- Full plan in `docs/SECURITY.md` (private; not copied to the public design repo): server-authoritative everything, no secrets in the app, RLS on every table, packs encrypted with per-device keys released only after Play Integrity + active entitlement, per-user watermarking of questions, rate limits and scraping alerts, obfuscated release builds, tamper/root/hook detection judged by the server, certificate pinning, FLAG_SECURE on exam/payment screens, admin 2FA, audit log, pen-test before launch, and an honest list of what cannot be fully prevented.
- **Offline downloads are Premium only** (Free rule `offline` now defaults to off; admin can change it). Free students see "Practise without data · Premium" instead of downloaded packs; download buttons open the paywall; the Downloads screen is a locked page for Free.

**D-035 · 2026-10-26 · Skeleton loaders and online/offline indicator**
- Data screens (Home, Study, Test, Past questions, Videos, Novels, Syllabus, News, Article, Challenges, Leaderboard, Me, Winners wall, Referrals, Winnings) show a matching skeleton on first load, then fade in the content (in the app: until the API answers or the cache is read).
- A connection strip appears on every screen when offline ("You are offline. Downloaded tests still work." for Premium, "Some things need internet." for Free) and a green "Back online. Your results are syncing." for a few seconds after. Status-bar Wi-Fi icon follows. Actions that need internet explain it instead of failing: AI tutor, payments, codes, challenges, downloads, Free practice. Uses real browser `online/offline` events plus a prototype switch.

**D-036 · 2026-10-26 · Page-by-page QA pass (owner request)**
Automated sweep of all 55 screens for script errors, sideways overflow, clipped text, broken images and tiny tap targets (Free and Premium): **0 script errors**. Fixed:
- Buttons that did nothing: Study and Videos search (new global search sheet with gated results), subject filters (with empty state), video More/Download/Quality/Speed, note text size and download, novel bookmark and Chapters/Themes/Characters/Quizzes tabs, syllabus download and topic jump, past-question Prev/Next (real questions), Review filters and Prev/Next (real wrong/flagged/skipped items), AI "not helpful" (reasons sheet), Help Terms/Privacy/About (new draft legal pages), remove download, Home bell (notifications panel with unread dots).
- Home: shorter and clearer (challenge, continue, start practice, question of the day, news, a 2×2 "More for you" grid replacing three tall cards), time-of-day greeting, compact daily goal with a Practise button, upgrade copy matching the new Free plan.
- Removed a developer-only "broken formula" demo from the lesson note; removed inner padlocks inside already-Premium sections; syllabus Back goes to the list; bigger tap targets for standalone links; confetti canvas sized; locked page grammar.

**D-037 · 2026-10-26 · Home shows every challenge, and a calm empty state**
Home now has a "Challenges & events" section instead of one weekly card. A live challenge shows as the big card (a cash weekly challenge first). If nothing is live, the next one shows with a countdown and "Remind me". If nothing is planned, a friendly "No challenge right now" card offers alerts and past winners. Other live or upcoming events sit in a scroll row under it, and "See all" opens the full list. The prototype panel has a "Challenges on / No challenge" switch to preview both states. The "3 years free" badge was removed from the Start practice exam cards.

**D-038 · 2026-10-26 · Notifications are a full screen, plus history and bookmarks**
The bell shows an unread count and opens a full Notifications screen with filters (All, Challenges, Classes, Updates), Today/Earlier groups, unread dots, "Mark all read" and a link to settings. Tapping an item opens what it is about. Test history and Bookmarks became real screens (they used to point at placeholders). The challenge result screen got a close button, a solid background so the score card is never cut off, and the tie-break rule moved into a "How winners are decided" panel.

**D-039 · 2026-10-26 · Checkout shows the amount once**
On checkout, the plan line is just "SolutionTee Premium" (the duration is already in the Access row). The Price row only appears when a discount code is applied, as Price, then discount, then Total; otherwise only the Total shows. The Google Play payment sheet still names the plan because Google's own sheet does.

**D-040 · 2026-10-26 · Admin CMS redesign**
New shell: grouped sidebar (Overview, Content, Students, Money, App control, System) with live counts; top bar with breadcrumbs, theme switch, an alerts menu and an account menu; Ctrl+K quick search for pages and actions; a side panel (drawer) for details; the sidebar slides in on small screens. New dashboard: greeting, "Needs your attention", KPIs with trend lines, revenue chart, plan mix, live challenge, top subjects, AI tutor health and recent activity. New pages: Question bank (filters, tabs, bulk actions), Study content (sections + items), Exams & years (publish or unpublish a year), Users (details panel: grant Premium, device check, activity, payments, ban), Payments (server-verification timeline, refund), Onboarding & home, Feature flags & app (minimum version, maintenance mode) and Audit log (before/after view). All data is sample data; the real CMS is built in Phase 2 (Next.js).

**D-041 · 2026-10-26 · Cleaner challenge cards on Home (owner feedback)**
The small cards under the weekly challenge were cramped. They now have 16 px padding inside, a fixed width that hints there are more to scroll, 16 px space below the big card, equal heights, and a clear order: icon and status on top, the title, then a footer split off by a line with "Prize" and "Entry" side by side.

**D-042 · 2026-10-26 · One app for Android, iOS and (if possible) desktop (owner, at DESIGN APPROVED)**
The owner wants a single app that runs on Android and iOS, and a desktop version if possible. Flutter, already the locked stack, builds all of these from one codebase, so the stack does not change, but the scope grows:
- iOS builds need macOS + Xcode. The owner's laptop is Windows, so iOS builds will run on a cloud Mac (Codemagic free tier or GitHub Actions macOS runners). iOS cannot be tested on the owner's machine; it needs TestFlight and an iPhone tester.
- iOS payments must use Apple In-App Purchase for Premium (Apple's rule for digital content), verified on the server like Play purchases.
- iOS anti-multi-account uses App Attest / DeviceCheck instead of Play Integrity. Cloner detection is Android-only (iOS does not allow cloners).
- Desktop (Windows first) reuses the same screens with wide layouts (design-spec §6.3). Building it on Windows needs the Visual Studio C++ workload (several GB; the laptop now has about 40 GB free). Cash challenges may be phone-only via an admin flag because desktop anti-cheat is weaker.
- Testing stays on the owner's real Android phone over USB debugging (no emulator, low RAM). We ask the owner before any step that needs the phone.
- The rule stays: everything except Free content is gated on the server.

**D-043 · 2026-10-26 · Android app + web app for iPhone users (owner; replaces the iOS and desktop parts of D-042)**
The owner chose to focus on Android and skip a native iOS app. iPhone users (and laptop users) will use a web app at a URL like `app.solutiontee.com`.
- **Android:** Flutter app, as planned (Play build + direct APK).
- **Web app:** built in Next.js (already the locked web stack) as an installable PWA, not Flutter web. Why: Flutter web downloads several MB before the first screen, which is bad for data costs in Nigeria. Next.js loads light, works well on iPhone Safari and shares the web code we already need for the site and admin.
- Both clients use the same Supabase backend and the same design spec. **CBT scoring, JAMB scaling, entitlements, AI quota and challenge ranking run on the server**, so the Android and web apps cannot disagree and neither can be tricked.
- **Payments on the web app:** Paystack with redeem codes (no Apple fee, because it is not an App Store app).
- **Web limits:** Premium offline downloads stay Android-only. Anti-cheat in a browser is weaker (tab switch, fullscreen exit and copy can be detected; app cloners and Play Integrity do not apply), so an admin flag can make cash challenges app-only. Default: web students can join free-prize challenges and see cash challenges with a "Play this in the Android app" note. The owner can change this.
- **Timing:** the web app sits in Phase 5 with the website, so iPhone users get access after the Android core is done. It can move earlier if the owner wants.
- No native desktop app for now; laptop users use the web app.

**D-044 · 2026-10-26 · Phase 4b for challenges, referrals and trust**
The approved design added challenges with cash prizes, anti-cheat, referrals, one-account-per-person, bans and the winners wall. These were not in the original phase list. They become **Phase 4b — Challenges, referrals & trust** (approval word `CHALLENGES APPROVED`), after payments (Phase 4), because they need entitlements, payments and server-side marking first. The phase plan in `docs/PHASES.md` gets this entry when Phase 4 starts. Phase 2 already creates the flags (`challenges_enabled`, `referrals_enabled`, `cash_challenges_on_web`).

**D-045 · 2026-10-26 · Images are stored in Cloudflare R2 (owner)**
This replaces Supabase Storage for all images.
- **Buckets:**
  - `st-question-images` is private. Its links are signed for a few minutes by server code (Next.js server or a Supabase Edge Function) only after `public.can_view_question_image(key)` returns true for that student. So a Free student cannot open the picture of a locked question.
  - `st-public` sits behind a Cloudflare CDN domain and holds news, onboarding art and logos.
- **Uploads:** the admin uploads with a short presigned PUT link, issued only after `public.can_upload_images()` returns true.
- **Keys:** R2 keys live only in server env or Edge Function secrets.
- **Database:** stores the object key.
- **Why R2:** the owner's choice. It has no egress fees, which suits image-heavy question banks and data-light users.

**D-046 · 2026-10-26 · Phase 2 data-model choices**
- **Students never read the `questions` table directly** (RLS gives them nothing). They call `public.fetch_questions(exam, subject, year, mode)`, which checks sign-in, bans, published year, the plan rule for that mode (test vs study mode, which have different Free year counts), page size (max 100) and an hourly cap (3,000 questions per hour) to slow down scraping. This enforces the per-mode Free rules on the server; plain RLS could not tell the modes apart.
- **One `access_rules` table with a `free` and a `premium` row** replaces the separate `free_access_rules` and `ai_limits` tables in SPEC §7. It has exactly the shape the approved admin edits (years per exam, oldest or newest, study-mode years, videos, notes, novels, syllabus, AI per day, offline, challenges). AI model settings (model id, prompt, temperature) come in Phase 4 with the AI tutor.
- **Every admin write needs 2-step login (TOTP, `aal2` in the JWT), checked inside RLS**, so a stolen password alone cannot change anything. The same check covers RPCs.
- **Audit:**
  - Triggers log every write to admin-editable tables with before and after values, even writes made outside the website.
  - Bulk actions (CSV import, undo, bulk publish) write one summary row instead of thousands.
- **CSV imports** arrive as drafts. Undo soft-deletes the batch.
- **Manual Premium grants** need a reason. Only server code can create Paystack, Play, code, referral or prize entitlements.
- **Google sign-in moves to Phase 3,** because it needs the Android app's signing-key fingerprint.
- **No local database:** tests run on the hosted dev project inside a transaction that is always rolled back (`scripts/run-db-tests.mjs`).

**D-047 · 2026-10-27 · Admin website build choices (Phase 2)**
- **Next.js 16.4 defaults kept:**
  - `proxy.ts` (the new name for middleware) refreshes the session and sends signed-out visitors to login.
  - `cacheComponents` is on: every page reads the session inside `<Suspense>`, which also gives each page its loading skeleton.
  - The Supabase server clients call `await connection()` first, so they are never prerendered.
- **shadcn/ui** ("base-nova", built on Base UI) is themed with our tokens: `design/scripts/tokens-to-css.mjs` turns `tokens.json` into `app/tokens.css`. Plus Jakarta Sans is bundled locally (500/700). Icons are Phosphor, as in the approved prototype. Real logos are copied unchanged into `public/brand`.
- **Question editor:** a plain text area with maths helper buttons and a live KaTeX preview, matching the approved design. KaTeX output is the only HTML; all other text is escaped. Tiptap rich text is kept for lesson notes in Phase 4, where formatting matters.
- **First super admin:**
  - A one-time form on the login page while no staff exists.
  - The server checks again before creating the account, using the secret key on the server only.
  - Later admins are invited by a super admin. The server makes a one-time Supabase link and sends it through the Brevo API from the owner's sender. If Brevo fails, the link is shown to copy and send by hand.
- **Ban:** besides `profiles.banned_at`, the student is also banned at the Supabase Auth level, so they cannot sign in at all.
- **Manual Premium grants:** start at the database's own time (avoids laptop or server clock skew); extensions start when the current Premium ends.
- **Every admin save refreshes all admin pages** (`revalidatePath('/admin', 'layout')`), so the dashboard never shows stale numbers.

**D-048 · 2026-10-27 · Staff reads also need 2-step login**
Browser testing showed that RLS only required `aal2` (2-step) for staff writes. A stolen staff password could therefore have read student emails and every question through the API. `private.is_staff()` now requires `aal2`, so without the 2-step code a staff account has only student rights. It can still read its own staff row, which the 2-step page needs. The RLS suite has new tests for this (68/68 pass).

**D-049 · 2026-10-27 · One R2 bucket with key prefixes (owner's env)**
The owner's `.env.local` has a single `R2_BUCKET`. The code stores question images under `q/…` and news images under `public/news/…` in that bucket, and only ever hands out short signed links (`R2_SIGNED_URL_TTL`). **The bucket must be private.** If public access (r2.dev or a custom domain) is on for it, anyone who guesses a key could open locked question images. If the owner wants a public CDN for news and onboarding pictures, the plan is a second, public bucket for those only. Open question for the owner.

**D-050 · 2026-10-27 · SolutionTee sends its own auth emails (Brevo API), not Supabase**
- **Why:**
  - The owner wanted OTP, forgot-password and similar emails set up.
  - Making Supabase send through Brevo SMTP needs the dashboard, and Claude may not type an SMTP key into a web form.
  - Our own sending also gives branded templates, our senders and our own limits.
- **How:**
  - The server (Next.js API, secret key on the server only) calls `auth.admin.generateLink` to create the account or reset and get the one-time code. Supabase sends nothing.
  - We email the code through the Brevo API from `noreply@mail.solutiontee.com`; replies go to `support@mail.solutiontee.com`.
  - The app verifies the code directly with Supabase (`verifyOtp`).
  - Contract: `docs/AUTH_EMAIL.md`.
- **Safety:**
  - Rate limits live in Postgres and store only HMAC hashes of email and IP.
  - Forgot-password always gives the same answer.
  - A second sign-up can never change an unconfirmed account's password (tested), and a resend needs the same password.
  - Notices need the user's own access token, and the welcome email goes out only once.
  - `EMAIL_TRANSPORT=log` (development only) logs emails instead of sending them, for tests.
- **Known setting:** the hosted project sends 8-digit codes. The app reads `codeLength` from the API, so 6 or 8 both work. The owner can set 6 digits and a 10-minute expiry in the dashboard.
- **Tested:** the full flow through the real endpoints, and an existing account answers 409 before any rate limit. **Not yet tested:** delivery to a real inbox (Claude cannot read email). The owner presses *Send me a test email* on the admin Emails page.


**D-049 update · 2026-10-27:** the owner confirmed the R2 bucket stays **private**. All images (questions and news) are served through short signed links from the server. A public CDN bucket for news and onboarding pictures can be added later if needed.


**D-051 · 2026-10-29 · Phase 3 app-core choices**
- **The exam clock pauses while the app is closed.** The phone saves the used time with every answer and whenever the app goes to the background. A test reopened later carries on with the time that was left. A student whose phone dies does not lose the paper. Real JAMB has no "app closed", so this is the fairest offline rule.
- **Two marks, one that counts.** The phone marks at once, so results show offline. The server re-marks from its own answer key when the attempt syncs (`submit_attempt`, idempotent), and the results screen then says "Checked by SolutionTee". The two formulas are identical and tested on both sides.
- **Dev API over USB.** Debug builds call the laptop's Next.js API at `http://localhost:3000` through `adb reverse tcp:3000 tcp:3000`. Plain http is allowed **only** for localhost and **only** in debug builds (`android/app/src/debug/res/xml/network_security_config.xml`). Release builds are HTTPS-only.
- **App id `com.solutiontee.cbt`.** The Play Store link in the force-update screen uses it.
- **Screenshots blocked in tests.** `FLAG_SECURE` is on while a CBT screen is open (MethodChannel `solutiontee/secure`) and off elsewhere.
- **No Android backup** (`allowBackup=false` + data-extraction rules). Login tokens and question packs never leave the phone in a backup.
- **Question images** come through `POST /api/images/sign`. The server runs `can_view_question_image` as the student, then returns a 5-minute R2 link. A locked image is never signed. With data saver on, diagrams load only on tap.
- **Icons: our own Phosphor set, not `phosphor_flutter`.** That package (last release 2024) no longer compiles on current Flutter, because `IconData` became a final class. `design/scripts/phosphor-to-dart.py` builds `lib/widgets/phosphor.g.dart` and two subset fonts (≈32 KB) from the MIT Phosphor fonts already vendored for the prototype. Calls look the same (`PhosphorIcons.house(PhosphorIconsStyle.fill)`). Re-run the script after using a new icon.
- **Fonts.** Plus Jakarta Sans 500/700 is converted to TTF from the prototype's woff2 files. The latin and latin-ext subsets are merged, so ₦ is included. Licence: OFL.
- **Legal pages in the app link to the website** (one source of truth). The lawyer's approved text will live at solutiontee.com/terms and /privacy.
- **Log out wipes the phone's test data.** It also clears cached questions and attempts. Synced attempts stay in the account.

**D-052 · 2026-10-30 · The app copies the approved prototype screen by screen**
The owner asked for the app to look exactly like the Phase 1 design.
- **Component kit.** `apps/mobile/lib/ui/kit.dart` holds Flutter versions of the prototype's CSS components, with the same names and sizes: `.btn` variants, `.icon-btn`, `.appbar`, `.footer-cta`, `.card`, `.list-item`, `.badge`, `.chip`, `.field`/`.input`, `.check` consent, `.seg`, `.switch`, `.bar`, `.steps`, `.ob-dots`, `.banner`, `.state`, `.art-disc`, `.mini`, the mark, the avatar, sheets, dialogs and toasts. Shadows come from `design/tokens.json` (generated `Shadows`).
- **Screens ported from the prototype source** (`prototype/js/screens-*.js`): splash, welcome, 6 onboarding slides (admin text, prototype art by `animation` key), sign up, log in, email code, forgot and reset (code plus new password on one screen), 3-step setup (about you, exams and target, JAMB subjects), welcome-new, welcome-back, home (goal strip, continue card, exam cards, news, upgrade banner, guided tour), Test hub, Test setup (mode switch, subjects, topics, year chips, summary card), CBT (top bar with timer and Submit, subject tabs with counts, collapsible passage, A–E option rows, palette sheet with legend, calculator sheet, submit summary, time-up dialog), Results (navy hero, ring, KPIs, score by subject, topics to practise, share), Review (one question at a time with filters), Me, history, settings, help (FAQ accordions), Terms, Privacy and About (prototype draft text with the "Draft, lawyer review" banner), and delete account.
- **Exam-body logos** are cropped on screen using the prototype's measured boxes. The files are never edited.
- **Checked side by side.** `test_preview/preview_test.dart` renders 17 screens in light and dark mode to PNG. They were compared with headless-Chrome screenshots of the prototype at 390×844.
- **Left out on purpose (no fake content):**
  - Challenges, Question of the day and "More for you" on Home, and badges and redeem code on Me: their features come in later phases.
  - The Notifications switches in Settings: push notifications come later.
  - Google sign-in: shown only once a Google OAuth client is set up.
  - Sample prices: Upgrade says "Premium payments are coming soon".
- **Behaviour taken from the prototype:**
  - Starting a new test **submits** the unfinished one as it is, so its score counts, instead of deleting it.
  - The quick test is 20 questions mixed across your subjects, in 15 minutes.
  - Sign-up asks only for email and password. The name is asked in setup step 1, so the API's `fullName` is now optional.

**D-053 · 2026-10-30 · Phase 4 scope and video hosting (owner)**
- **Videos** (video solutions and topic lessons) are stored in the private Cloudflare R2 bucket under `v/…`. The admin uploads a 360p and a 720p MP4 version. The app plays them only through short signed links issued after the server's Premium check (the same pattern as question images, D-045). The 360p version is used when data saver is on.
- **Phase 4 includes the owner's extras** as the last milestone (4E): challenges with cash prizes and anti-cheat, referrals, leaderboard, question of the day and the winners wall. They come after Study and Premium (4A), the AI tutor (4B), payments (4C), and notifications and the dashboard (4D).
- **Prices stay SAMPLE** (Monthly ₦1,500, 3 Months ₦3,500, Exam Season ₦6,000) until the owner changes them in Admin → Plans. Paystack works in test mode until launch.

**D-054 · 2026-10-30 · Study tab: how content reaches the phone**
- **The server decides everything.**
  - `study_catalog` lists titles with a `locked` flag and never the content.
  - `study_item` returns content only when the plan allows it.
  - Video and PDF links come from `/api/study/file` after `study_file_key` runs as the student.
  - The app only draws locks. The Free vs Premium rules (`access_rules`, public) are used to draw section locks and to write the paywall benefits.
- **Locked means gone.** If the server answers "locked" for an item the phone saved earlier (for example after Premium ends), the saved copy is deleted, not shown. Saved copies are used only when the server cannot be reached.
- **Premium videos block screenshots and screen recording** (`FLAG_SECURE`, the same switch the CBT screen uses). Free items do not.
- **PDFs are opened in memory** from a short signed link and are not written to storage. Video links last 3 hours so a long lesson never stops part-way.
- **Data saver** plays 360p. Otherwise the app plays 720p when the admin uploaded it. Both can be switched in the player.
- **Notes use a small text format** that teachers can type in the admin box:
  - `#` and `##` for headings
  - `-` for lists
  - `>` for an exam-tip box
  - `**bold**`
  - `$…$` and `$$…$$` for maths

  Tables are not supported yet.
- **Bookmarks:**
  - Questions are saved as `exam/subject/year/questionId`, so a bookmark opens that question in study mode.
  - Items are saved as `kind:id`.
- **Progress** ("Continue learning") stores the title and kind with the row. A student cannot read `study_items` directly, so the row carries what the list needs.
- **Downloads (for now)** lists the past papers saved on the phone (tests and study mode save them as you open them) and can remove them. Saving videos and PDFs for offline use is still to do. Each saved file would need an expiry check when Premium ends.
- **The paywall** reads plans and prices from the `plans` table (shown as SAMPLE PRICES). "Continue" says payments open in the next update; milestone 4C connects it to checkout.
- **The novel "Quizzes" tab from the prototype is left out** until there are chapter quizzes to show (no fake content).

**D-055 · 2026-10-30 · The website goes on Vercel before Phase 5 (owner)**
The owner asked to run the admin from Vercel instead of the laptop.
- **Address:** Vercel project `solutiontee-cbt` in team `solution-tee`, at https://solutiontee-cbt.vercel.app. The owner's own domain can be added later.
- **What is uploaded:** only `apps/web` and `packages/shared` (`.vercelignore`). Deploys are run from the laptop with the Vercel CLI. There is no Git connection yet.
- **Keys:** copied straight from `apps/web/.env.local` into Vercel's encrypted environment variables by a script that prints only the names. `NEXT_PUBLIC_SITE_URL` is the Vercel address.
- **Same database as development.** It still uses the `solutiontee-dev` Supabase project. A separate production project comes before launch (Phase 6).
- **R2 CORS** must list the Vercel address (SETUP §10.1). The R2 key only has object read/write, so the owner sets CORS in the Cloudflare dashboard.
- **Admin password reset** is now self-service at /admin/forgot: an emailed code, then a new password, then the authenticator step as always.

**D-056 · 2026-11-02 · Notes in Markdown with pictures, novel PDFs, speed fixes**
- **Notes are Markdown** (GitHub style: headings, bold and italics, bullet and numbered lists, tables, `>` tip boxes, pictures) plus `$…$` / `$$…$$` maths. Maths is taken out before Markdown runs, so `_` and `*` inside formulas stay maths. Admin preview (`lib/markdown.ts`, marked + KaTeX) and app (`note_markdown.dart`, markdown + flutter_math_fork) follow the same rule. Old notes still render, because their `#`, `-` and `>` lines are already Markdown.
- **Pictures in notes** are uploaded from the editor into the private bucket under `n/…`. The app gets a short signed link from `/api/images/sign` only when `can_view_note_image` finds a published study item the student can open whose text uses that picture. Raw HTML in a note is shown as text and never run.
- **Novels can carry the original book as a PDF** (`files.pdf`, same plan check as documents). It opens in the app's PDF reader from "Read the book". The admin form reminds editors to upload only books they have the right to share.
- **Speed.**
  - Cause of the slow maths notes: every scroll tick redrew the whole note (to move the progress bar), which rebuilt every formula.
  - Fix: the note is now parsed once and drawn lazily block by block, and scrolling only redraws the 3 px progress bar.
  - The video player redraws only itself while playing, not the whole screen.
  - The notes list (360+ notes) is built lazily.
  - The PDF page counter no longer rebuilds the viewer.
  - Speed should be judged on a **release** build: debug builds (what `flutter run` installs by default) are several times slower, especially with maths.
- **Admin Study list** pages 50 at a time with search, subject and status filters (it used to stop at 300).

**D-057 · 2026-11-02 · Video thumbnails, video player, per-video locks (owner)**
- **Thumbnails.** When a video is uploaded, the admin takes a frame from it (about a third of the way in, max 3 s), saves it as a 640 px WebP under `s/…` and uses it as the item's cover, unless a picture was chosen by hand. Videos uploaded before this can get one with "Make thumbnail". Novels and documents keep their uploaded covers.
- **Covers and thumbnails are teasers:** students see them on lists also for Premium items (`study_cover_key`, no plan check). The catalog says which items have one (`meta.cover`).
- **The app keeps pictures on the phone.** Covers, thumbnails and news pictures are downloaded once through a short signed link and kept in the cache folder by R2 key, so lists never download the same picture twice. Pictures inside notes are not kept (they are Premium content).
- **Fast-start videos.** Before upload the admin moves the MP4 index (`moov`) to the front when it sits at the end, so a phone can start playing while downloading. This runs in the browser without loading the whole video into memory.
- **Player** (study_player.dart, on video_player / ExoPlayer, no heavy video library, so the app stays small):
  - double-tap the left or right side for −/+10 s (taps add up)
  - hold for 2×, speeds 0.5×–2×
  - fullscreen in landscape (immersive)
  - seek bar shading the downloaded part
  - controls hide on their own
  - resume where you stopped
  - the screen stays awake while playing
- **Bad network:**
  - Starts in 360p on mobile data or with data saver, 720p on Wi-Fi when it exists.
  - Two stalls of 2.5 s or more within 45 s on HD switch to 360p by themselves, at the same spot.
  - A dropped connection shows "Try again", which gets a fresh link and carries on.
  - Real adaptive streaming (HLS) would need server-side transcoding (e.g. Cloudflare Stream, paid). Not used for now.
- **Videos are locked per video:**
  - The Video solutions and Topic lessons sections are always open, so every student sees every video.
  - A video marked "Free for everyone" plays for all students; the rest need Premium (`study_open`).
  - Notes and novels still follow the Free vs Premium section rules.

**D-058 · 2026-11-03 · AI tutor: providers, keys and models are managed in the admin (owner)**
- **Providers are any OpenAI-compatible API** (`/chat/completions`, `/models`, `/embeddings`).
  - NVIDIA is the main one; Dahl (inference.dahl.global) is the backup.
  - Admins add providers, change keys and add or reorder models in Admin → AI tutor. There is no code change and no redeploy.
- **Keys** go straight into Supabase Vault through `admin_set_ai_key` (admins with 2-step only). Only the last 4 characters are shown again.
  - Keys are read only by the Edge Functions (`ai_config`, service role) and by the admin "Test" button on the website server.
  - The owner shared the first keys in chat. They were stored the same way and must be replaced before launch.
- **One priority list per purpose:**
  - Text questions (`chat`), photo questions (`vision`) and knowledge (`embed`).
  - A photo is sent only to vision models. Dahl's models cannot read pictures.
  - The order came from live tests (`supabase/seed/ai-model-order-2026-11-02.sql`). The admin can reorder at any time.
- **Speed rules in `ai-chat`:**
  - A model must start replying within 20 s (35 s for photos) and start writing the answer within 25 s (45 s), even while it is thinking.
  - After that it may go on while something arrives every 30 s. The whole request stays under the server's time limit.
  - The next model takes over on 404/429/5xx, silence or too much thinking. "Thinking…" shows in the app meanwhile.
  - Once part of an answer is shown, there is no switch, so two models' answers are never mixed.
- **Thinking is hidden:** `<think>…</think>` and `reasoning_content` never reach students.
  - Some models need a larger max tokens because their thinking counts against it.
  - Optional "extra settings" JSON per model is merged into the request (for provider switches such as turning thinking off).
- **Quota is used up atomically in Postgres before calling a model** (`ai_take`):
  - Free and Premium limits come from the Free vs Premium rules (`ai`), and the day is Africa/Lagos.
  - 6 questions a minute at most.
  - The prompt is refunded when every model fails.
- **Knowledge (RAG):**
  - Published notes are split into about 1,200-character pieces and embedded with NVIDIA `nemotron-3.5-embed-1b` (768 dimensions) into pgvector.
  - The 4 closest pieces (similarity > 0.35, same subject first) are added to the system prompt.
  - Rebuilt from Admin → AI tutor → Knowledge, which also catches notes added or edited later.
- **Maths:** models often write `\( \)` and `\[ \]`. The app and the admin preview accept both, as well as `$ $` and `$$ $$`.
- **Photos** are shrunk on the phone (max 1280 px, JPEG about 72%), sent with that one message only, and not stored. The saved message notes that a photo was sent.
- **Cache:** "Explain this question" answers from Review/Study are cached per question and hint mode, and still count as a prompt.


**D-059 · 2026-11-03 · Test APK download page for the team**
- https://admin.solutiontee.com/download is a public, not-indexed page (robots noindex) with one button. The APK sits in the **private** R2 bucket under `apk/`; `apk/latest.json` points at the newest file.
- The button goes to `/download/apk`, which answers with a 10-minute signed link that saves as `SolutionTee-CBT-<version>.apk`. Nothing in the bucket becomes public.
- Anyone with the link can install the test build. This is acceptable because the app itself still enforces every lock on the server (free users get only free questions). It is debug-signed for now; the Play Store build (4C/launch) will use the upload key, and testers will need to uninstall this one first then.
- New version: build, then `node scripts/upload-apk.mjs` from `apps/web` (see SETUP §12). No redeploy needed.

**D-060 · 2026-11-03 · Permanent upload key + automatic APK builds on GitHub**
- The app is now signed with a permanent upload key (`apps/mobile/android/app/upload-keystore.jks`, alias `upload`, passwords in `android/key.properties`; both git-ignored). It will also be the Play Store upload key. With no key present, release builds fall back to the debug key.
- Changing from the debug key means phones with the old test app must **uninstall once** before installing the new one. After that, updates install over the top.
- `.github/workflows/android-apk.yml` runs analyzer + tests, builds the arm64 APK and uploads it: `main` goes to `/download`, any other branch (e.g. a cloud session's) goes to `/download?channel=test`. Build number = minutes since 1970, so each build installs over the last.
- Secrets live only in GitHub Actions secrets, added by the owner (SETUP §13).

**D-061 · 2026-11-03 · Payments: Paystack, Google Play and redeem codes (milestone 4C)**
- **The server sets every price.** The app (and later the website) sends only the plan and an optional code. `pay_start` works out the price from `plans` and the code and saves a `pending` payment with a random `st_…` reference. Paystack is asked to charge exactly that amount.
- **Premium only after our own check.**
  - Paystack: the webhook must carry a valid `x-paystack-signature` (HMAC-SHA512 of the raw body with the secret key), and even then we call Paystack's **verify** endpoint ourselves before granting.
  - The amount and currency Paystack reports must equal what we saved; otherwise the payment becomes **Needs review** and nothing is granted.
  - Google Play: `play-verify` calls `purchases.products.get`; the purchase must be *purchased* and carry this student's account id (sha256 of the user id, sent as Play's obfuscated account id). Then Premium is granted and the purchase is **consumed** (which also acknowledges it), so the same plan can be bought again later.
- **Idempotent.** One entitlement per payment (`entitlements.external_ref = pay:<id>`), the payment row is locked while it is processed, every webhook body is stored once (`payment_events.event_key` = sha256 of the body), and a Play token can belong to one account only. Webhook + app check + Paystack retry give exactly one Premium (tested).
- **Edge Functions, not the website,** hold the payment code (`paystack`, `paystack-webhook`, `play-verify`, `play-rtdn`). Why: they can be deployed from a cloud session, the keys live in one place (Supabase Edge Function secrets), and the website (Phase 5) calls the same `paystack` function with `source: "web"`.
- **Buying early never wastes days:** a new plan starts when the current Premium ends. Exam Season ends at the end of its date in Lagos; it cannot be bought again while Premium already covers that date.
- **Refunds:** Paystack `refund.processed` and Google voided purchases remove the Premium that payment gave; a part refund is only noted. Admin → Payments → *Refund* asks Paystack; Google refunds are made in Play Console. Google's refund notices are re-checked against the Voided Purchases API before acting.
- **Codes (D-024):** `%` off, `₦` off (Paystack only) and free Premium days (Me → Redeem a code). Shared codes (each student once) or batches of one-use codes like `STEE-7K3P-Q9XD` (no 0/O/1/I/L). Unpaid checkouts from the last 30 minutes hold a use of a limited code. A discount never leaves a charge between ₦0 and ₦100; a 100% code gives Premium without Paystack. 10 wrong codes in an hour lock code entry for that student. Students cannot read the codes table.
- **App:** two Gradle flavors with the same app id: `direct` (default; Paystack) and `play` (Google Play Billing via `in_app_purchase`). The Play build never mentions the website or discount codes; `paystack_in_play_build` (off) can switch Paystack on later. New flag `codes_in_play_build` (off) controls "Redeem a code" in the Play build until a lawyer confirms it is allowed.
- **Paystack opens in a Chrome Custom Tab** (`url_launcher` in-app browser, no new package). The app cannot read the tab's address, so it checks the payment when the student comes back (then every 5 s for 2 minutes) and offers "I have paid, check now". The webhook grants Premium even if the student never comes back.
- **Left out of the prototype on purpose:** the radio list of Card / Bank transfer / USSD. Paystack's own page asks how to pay, so the app shows the three as information instead of asking twice. "Receipt: sent to your email" is not shown, because receipts are not emailed yet.
- **Not tested yet:** a real Paystack payment (needs the owner's test key in Supabase secrets) and anything Google Play (needs Play Console and a test-track build). The functions are deployed and refuse unsigned or logged-out calls (checked live).

**D-062 · 2026-11-03 · Edit and delete redeem codes (owner)**
- **Edit** (Admin → Redeem codes → pencil): amount, plans, total uses, start and end dates, "new students only" and note. A batch is edited as one. The type (% / ₦ / days) and the code text stay as they are; students who already used a code keep what they got. Uses allowed can never go below the uses so far.
- **Delete** (bin, tap twice): codes nobody used are removed through the existing admin delete policy (which only allows unused codes). Used codes are **archived** instead (`deleted_at`): switched off, hidden from the list and refused like an unknown code, but payments and redemptions still show which code they used. An archived code's text cannot be reused.
- The database function has no `delete` statement on purpose: the Supabase connector asks for a confirmation on such SQL, and that question does not reach the owner's phone.
- Tests: 70/70 on the dev database; the 3 delete checks in `payments.test.sql` run only with `pnpm db:test` on the laptop (same reason).


**D-063 · 2026-11-03 · Notifications and the Me dashboard (milestone 4D)**
- **One inbox, two ways to arrive.** Every message is a row in `notifications`; the app's Notifications screen reads `my_notifications()` (audience: everyone, Free, Premium, one student, or staff test phones). Push is an extra on top. Messages are marked sent even when push is off or fails, so the inbox always works.
- **Sending** happens only in the `push` Edge Function with the Firebase service account (secret `FIREBASE_SERVICE_ACCOUNT`, FCM HTTP v1, signed with the same RS256 helper as Google Play). `pg_cron` calls it every 5 minutes with a random token kept in Vault; admins' "Send now" calls it with their own 2-step session. `push_take_due()` takes each message once (`FOR UPDATE SKIP LOCKED`, status `sending`).
- **Broadcasts use FCM topics**, not a list of phones: each phone subscribes to `t_<topic>` for the topics it keeps on, plus `tier_free` or `tier_premium` (FCM conditions narrow a message to Free or Premium). Personal and staff messages go to the saved tokens (`push_tokens`); tokens FCM rejects are removed. A phone's token moves to whoever logs in on it, and log-out deletes it, so a shared phone never gets the previous student's messages.
- **Switches** (Settings → Notifications): Announcements, New questions added, Streak reminders, Class reminders, Challenges. Saved on the server (`notification_prefs`, missing = on) and applied to the phone's topics, so a new phone gets the same choices. "You are now Premium" (topic `account`) is always on.
- **Automatic messages:** news posts with "Send as a notification" (once per post); newly published exam years (one message per exam, sent 10 minutes later so a batch of years is one message); Premium given (any entitlement); the daily streak reminder (7 pm Lagos, setting `push`, at most one a day, only for a 2+ day streak not yet kept today).
- **Permission** is asked once, after the student has finished a test, not at start-up.
- **Firebase is optional at build time:** the Google Services Gradle plugin is applied only when `google-services.json` exists, and the app starts with push off when Firebase cannot start. firebase_messaging 17 marks `getToken`/`onTokenRefresh`/`deleteToken` as old; we keep them because the HTTP v1 `token` field takes that registration token (the new installation-id API is not used until the server sends to it).
- **Me dashboard:** the 8 badges of the approved design, worked out on the server (`my_badges`: 7-day streak, First 250+ in a JAMB mock, Speedster = 20+ answers under 30 s each with 70% right, 100 correct, Score 300, Night owl = a test finished 10 pm–4 am, Bookworm = 5 lessons read to 90%, Full mock = 90% of a full mock answered); rows for Bookmarks, Downloads and "AI prompts left today".
- **Profile photo:** picked or taken on the phone, shrunk to 512 px JPEG (about 40 KB; JPEG instead of WebP because the phone's picker makes JPEG without an extra package), uploaded with a 10-minute link from `/api/account/avatar` to the private bucket under `a/<user id>/`, and shown through `/api/images/sign`, which signs only the student's own photo for now. Old photos are not deleted from R2 yet.
- **Not in the prototype on purpose:** the "My classes", "Invite friends", "My winnings" and "Winners wall" rows on Me (Phase 5 / 4E).

**D-064 · 2026-11-03 · Ask for notifications every time the app opens while they are off (owner)**
- Replaces "ask once after the first test" (D-063). Every app opening (once per run, 1.2 s after Home appears) checks Android's own switch for the app (`areNotificationsEnabled`, MethodChannel `solutiontee/notify`).
- While notifications are off: on Android 13+ the app shows Android's own "Allow notifications?" box, at most twice (Android stops showing it after two "Don't allow"); after that, and on older Android, it shows our "Turn on notifications" sheet whose button opens the phone's notification settings for SolutionTee. "Not now" closes it until the next opening.
- Settings → Notifications shows "Notifications are off on this phone" with a Turn on button. Coming back from the phone's settings re-checks.
- Builds without Firebase never ask (push is off there).

**D-065 · 2026-11-03 · Real app icon, and /download always has the newest app (owner)**
- **App icon:** made only from the owner's `brand/favicon.svg` (the real mark), by `design/scripts/make-app-icon.mjs`. Android 8+ gets an adaptive icon: the same paths without the file's navy square, scaled to fit the 66 dp always-visible circle, on that navy (`#0B1F44`) as the background colour, so round, squircle and square launchers all show the whole mark. Older Android gets the file itself, resized. Nothing redrawn; to change the icon, replace the brand file and run the script.
- **Automatic APK on /download:** GitHub workflow `android-apk.yml` on every push to `main` or `claude/*` that touches `apps/mobile/`, or by hand. It runs `flutter analyze` and `flutter test`, builds the `direct` arm64 APK and publishes it to the **main** channel (`apk/latest.json`), so /download always has the newest build from either branch (replaces D-060's "other branches go to ?channel=test").
- **No GitHub secrets:** the run proves itself to `POST /api/ci/apk` with GitHub's OIDC run token (audience `solutiontee-apk`). The website checks the RS256 signature against GitHub's published keys, the issuer, audience and expiry, repository id `1443641230`, the workflow file `android-apk.yml`, a push or manual run, `main` or `claude/*`, and a GitHub-hosted runner. Only then does it return the signing key and a 10-minute upload link for `apk/solutiontee-cbt-<version>.apk`, and on "publish" it checks the file arrived before pointing `latest.json` at it. R2 keys never leave Vercel. Tests: `apps/web/lib/github-oidc.test.mjs` (4/4).
- **New permanent signing key for the website APK** (RSA 4096, alias `solutiontee`, made in the cloud, kept only as hidden Vercel secrets). Reason: R2 and signing secrets on the laptop cannot reach cloud sessions, and cloud debug keys change with every new cloud computer, which would force an uninstall each time. One last uninstall is needed now; after that every build installs over the last. The laptop upload key (D-060) remains the Play Store upload key (Play re-signs with Google's key anyway, so Play and website installs never share a key).
- **Risk:** the key exists only in Vercel. If it is lost, make a new one the same way; testers uninstall once.

**D-066 · 2026-11-03 · Question of the day and leaderboard (milestone 4E1)**
- **One question a day for everyone** (so "% who got it right" means something), changing at midnight Lagos time. The admin schedules days ahead (Admin → Question of the day); empty days get an automatic pick on first request: a published question with no reading passage from a year **Free students can open**, rotating subjects by day and not repeating a question used in the last 365 days. The pick is saved, so every student gets the same one.
- **Never locked content on a Free phone:** scheduling refuses questions from years Free cannot open; if the Free rules change later, the server sends no question to a student who cannot open that year (Premium still gets it).
- **One try**, marked on the server (`qotd_answer`); the answer and explanation are sent only after answering. A second answer returns the first. Streak = days in a row the student answered (right or wrong), so one wrong answer does not break it. No XP (there is no XP system yet), so "+10 XP" from the prototype was left out. "Share" was left out (no share package yet); the buttons are Ask AI and Practise more.
- **Leaderboard:** best **full JAMB mock** (4 subjects, out of 400, 100+ questions, server-marked) per student per JAMB season; ties: faster, then earlier. **Season** = the UTME year it prepares for: from 1 July, practice counts for next year. Top 50 + the student's own rank, points to the next place, Nigeria or My state (current season only), past seasons the admin picks show their best student (with school). **Off by default** (setting `leaderboard`, plus the existing `leaderboard_enabled` flag). Names: first name + initial (or first name only); staff, banned and hidden students never appear (Settings → "Show me on leaderboards").
- **Held mocks:** a full mock finished in under 15 minutes, or 380+ in under 45 minutes, does not count until an admin lets it count (Admin → Leaderboard). Rank movement arrows from the prototype are left out for now (they need daily snapshots).
- Tests: `supabase/tests/qotd_leaderboard.test.sql` 32/32; app `test/compete_test.dart`.

**D-067 · 2026-11-03 · Leaderboard rules are admin settings; clearer Question of the day page (owner feedback)**
- Owner tested full JAMB mocks and saw nobody on the board: the sample bank gives a 20-question "full" mock (the rule needed 100+), the tests were finished in seconds (held as too fast), and most were on a staff account (always left out). None of this was visible.
- Now in Admin → Leaderboard: **Questions needed in a full mock** (default 100), **Too fast: held if finished in under N minutes** (default 15, 0 = off), **Include staff accounts (for testing)** (default off), plus a "How a student gets on the board" box and **Latest full JAMB mocks** with "Counts" or the exact reason it does not (staff, hidden, too few questions, held, kept off), and Let it count / Keep off on held ones. For testing with the sample bank: 20 / 0 / on; before launch: 180 / 15 / off.
- Admin → Question of the day: a step-by-step "Add a question of the day" box at the top (1. choose the day, 2. find a question and tap "Use for <day>"); the list of usable questions loads straight away.

**D-068 · 2026-11-03 · Own questions of the day; WAEC and NECO leaderboards (owner)**
- **Own question of the day:** Admin → Question of the day → "Write my own question": optional subject or topic, the question (LaTeX with `$...$`), options A–D (E optional), the correct answer, an explanation, with a live preview. Stored on the day itself (`qotd.custom_*`; `question_id` is null), so it is not added to the past-question bank. It goes to every student, Free or Premium (it is not locked content). The app shows "<subject> · set by SolutionTee". Ask AI is hidden for own questions (Ask AI explains bank questions by id); Practise more stays. Picking a past question still works ("Pick from past questions").
- **WAEC and NECO boards:** one board per subject; a student's best one-subject paper (Test → WAEC/NECO → a subject or year paper, out of 100, server-marked) counts; quick tests and topic drills do not. Settings: questions needed in a subject paper (default 40; real papers WAEC 50, NECO 60), too-fast minutes (default 5), plus the shared settings (tests needed, names, staff, past years). Each board (JAMB, WAEC, NECO) can be switched off. Same season rule (from 1 July practice counts for the next year).
- New RPC `leaderboard_for(exam, season, scope, subject)`; the old `leaderboard()` calls it for JAMB so older app builds keep working. Admin "Latest tests that can count" lists JAMB mocks and WAEC/NECO papers with the reason each does not count.
- Tests: `supabase/tests/qotd_leaderboard.test.sql` 43/43; app 50/50.

**D-069 · 2026-11-03 · Profile photos on leaderboards (owner; on by default)**
- New student setting **Show my photo on leaderboards** (Me → Settings), on by default (`profiles.show_photo_on_leaderboard`). When on and the student has a photo, every board (podium, ranks, best student) shows it; when off, their initials.
- Photos stay in the private R2 bucket. `/api/images/sign` now signs another student's photo only when `can_view_avatar` allows it: the leaderboard is on, that student shows their photo and is not hidden or banned, and the key is their current photo. Any other photo key stays locked. Checked on the live database (rolled back): shown when allowed, hidden when off, other keys refused.

**D-070 · 2026-11-03 · Challenges & events, fair play, prize claims, winners wall (milestone 4E2)**
- **Entry is free.** No paid entry until a lawyer confirms it is allowed (D-028). Cash prizes are paid **by hand** (bank transfer by a money admin), then the receipt is posted on the Winners wall; automatic Paystack Transfers can come later.
- **Server does everything that matters:** the phone gets one question at a time (never the answers), options shuffled per student, questions in a different order per student. Each answer is marked and timed on the server (time since the question was sent, capped at the per-question time; later than time + 3 s counts as no answer). One entry per student (unique), created when the first question is sent. Ranking: score, then total time, then who started earlier; disqualified, staff-reviewed "dq" and banned entries are left out.
- **Leaving the screen:** the app reports it (Android lifecycle inactive/paused, window focus lost = notification panel or floating window, split screen); the server counts exits and disqualifies past the allowed number (default 0, admin 0–3). Opening the challenge again after the app was closed counts as leaving. Screenshots and screen recording are blocked (FLAG_SECURE); text cannot be selected or copied. Back button asks first, then counts as leaving.
- **Fair-play flags** (for review before paying, not automatic disqualification): answers under 2 s on average, answer times almost the same every time, the same phone (hashed Android ID) as another entry, emulator, split screen at start. No Play Integrity yet (needs Play Console).
- **Close:** pg_cron every minute (`challenges-tick`) sends "… is live" when a published challenge starts, and at the end finishes running entries, freezes ranks, sets prizes (1st/2nd/3rd), adds Premium days for the top N if set, and sends "You won ₦X" to winners and "Winners of …" to everyone. Admin can "Close now". A later admin disqualify/reinstate ranks again; winners who already sent a claim keep their place.
- **Prize claims:** winner only, within 7 days of the close, once: 18+ or a parent/guardian (name + phone) for under-18; bank, 10-digit account number and account name; never PIN, card or password. Bank details are readable only by the winner and money admins (super_admin, admin), not editors. The account name is checked by the admin before paying (no automatic bank lookup yet).
- **Winners wall:** public; first name + initial (minors: first name only), state, place, amount, receipt image (`public/winners/…`, signed only when a published post uses it) and an optional message. The admin must confirm the account number and balance are hidden before posting.
- Copying a past question into a challenge is allowed only from years Free students can open (`admin_question_is_free`), so nothing locked reaches Free phones. New questions are recommended for cash challenges.
- The question timer on the phone counts ticks of its own clock; the server checks the real time.
- Tests: `supabase/tests/challenges.test.sql` 30/30; app `test/challenges_test.dart` (agreement, answering, leaving disqualifies, timer), all app tests 55/55.

**D-071 · 2026-11-03 · Question of the day per subject, analysis, daily notification (owner)**
- **One question per subject per day** (`qotd.subject_id`, unique day + subject). Each student gets **one of their own JAMB subjects** (profile `jamb_subjects`), picked at random per student per day (a hash of student + day, so it is fixed for the day). If that subject has no question, the next of their subjects is tried; students with no subjects use the subjects that have questions.
- For each day and subject: the admin's own question, a chosen past question (from that subject, Free years only), or an automatic pick (a Free-year past question in that subject, not used in the last 365 days if possible), saved so all students with that subject get the same one. % right is per question.
- Answers keep one per student per day (`qotd_answers` now also stores which question, `qotd_id`); the streak is unchanged.
- **Admin analysis:** answered today and % right, answers and students in the last 14 days, students ever, students on a 3-day streak, answers per day (with % right), by subject, and for every day × subject the count, % right and which options were picked.
- **Daily notification:** "Your question of the day is ready" (topic "New questions added", so students who switched that off do not get it), once a day at an hour set in the admin (default 07:00 Lagos; the questions change at midnight, and a midnight push would wake students). pg_cron `qotd-notify` every 10 minutes. Not sent on 3 Nov 2026 (it was already evening when this went live).
- Tests: `supabase/tests/qotd_leaderboard.test.sql` 47/47.

**D-072 · 2026-11-03 · The question of the day drops at 08:00 (owner)**
- The question day now changes at **08:00 Lagos time** (`app_settings.qotd.drop_hour`, default 8; `private.qotd_day()`), not midnight. Before 8:00 students still see the day before's question. The app's countdown ("New question in …") counts to 8:00.
- "Your question of the day is ready" is sent at the same moment (the check runs every minute; push sends every 5 minutes, so it arrives by about 8:05). Admin → Question of the day → "New question every day at" changes both. Midnight-based days (`private.lagos_today()`) stay for payments and streak reminders.

**D-073 · 2026-11-03 · Challenges by subject and difficulty, appeals, tabs always visible (owner)**
- **Three kinds of question paper** (`challenges.mode`): **Weekly mixed** — questions from each student's own JAMB subjects (profile `jamb_subjects`), mixed; **One subject** — only students who take that subject see it, can start it and get its notifications; **Same for all** — the old fixed list, shuffled.
- **Pools and levels.** Every question has a subject and a level: easy, medium, hard or very hard. The admin sets how many of each level a paper has per subject (`per_level`, e.g. 3/3/3/1). When a student starts, the server picks that many at random from the pool for each of their subjects, so every student gets the same mix but mostly different questions. The admin page shows the pool per subject × level and warns when a pool is smaller than ~3× what one paper needs. CSV import (sample at `/samples/challenge-questions-sample.csv`).
- A student with no JAMB subjects is asked to choose them first; a student without the subject sees "Not one of your subjects" (no Start). Checked on the server, not just in the app.
- **Appeals.** A disqualified student can send one appeal within 24 hours: a reason (10+ characters) and an optional screenshot (gallery, up to 3 MB, uploaded to the private bucket under their own folder `a/<id>/appeal-…`; the server refuses other keys). Admin → Challenges → Appeals: accept (entry is reinstated and ranked again) or reject, with a note; the student is told in notifications and sees the status on the result screen.
- **Notifications:** "starts in 15 minutes", "is live" and "ends in 15 minutes" (only to students who have not finished), each once; for one-subject challenges only to students who take that subject.
- **Tabs always show** except while playing a challenge or a CBT test: challenge screens now live inside the Test tab (`/test/challenges/…`, `/test/winners-wall`) and My winnings inside Me (`/me/winnings`). Every screen has a back button; after a challenge, back goes to the challenge, then the list, then Test. Old links in notifications (`/challenges/…`) are redirected.
- Tests: `supabase/tests/challenges_v2.test.sql` 18/18; app tests 60/60.

**D-074 · 2026-11-03 · Challenges: same questions, random past questions, live board and analysis, copy, review (owner)**
- **Same questions for every student** (`challenges.same_questions`, for Weekly mixed and One subject): the server picks a paper per subject with a hash of the challenge instead of at random, so everyone who takes a subject gets the same questions; the order (and the options) still differ per student. Off by default (random papers are harder to copy). "One list for everyone" (the old fixed mode) is unchanged.
- **Add random past questions:** the admin picks subjects (all JAMB subjects at once for the weekly challenge) and how many per subject; `admin_challenge_add_random` copies random published past questions into the pool. Only years Free students can open, no passage or picture questions, only A–D answers, never the same question twice (owner's rule: everything except free questions stays locked). Level: the question's saved level, else from how students did on it (20+ answers: 75%+ easy, 50%+ medium, 25%+ hard, below very hard), else medium. The admin can change any level in the list until someone starts. The result says how many Free past questions are left per subject. Logged in the audit table.
- **Live leaderboard and analysis** (`admin_challenge_live`, admin page refreshes every 15 s while the challenge is live): joined, playing now, finished, disqualified, fair-play flags, appeals waiting, average score and time; the live ranking (score so far, then time, like the final ranking); % right by subject and by level; a score spread; the hardest questions with the most-picked wrong option and time-outs; why students were disqualified; Results CSV download. The question pool table also shows how many students take each subject.
- **Copy for next time:** copies the settings and questions to a new start time (same length), hidden until published. Logged.
- **Review my answers:** after a challenge ends (never while it runs), a student who took it can see each of their questions, their choice, the right answer and the explanation (`challenge_review`).
- Tests: `supabase/tests/challenges_v3.test.sql` 16/16; app tests 62/62.

**D-075 · 2026-11-03 · Answer review per challenge; screenshot and screen-recording detection (owner)**
- **Answer review is the admin's choice per challenge** (`challenges.allow_review`, default on). Admin → the challenge → "After it ends": a switch that works any time, also after the end. Off: the app hides "Review my answers" and the server refuses the answers (`challenge_review`). Changes are logged in the audit table.
- **Screenshots and screen recording are blocked** (Android FLAG_SECURE: the picture comes out black) in the CBT test screen, the challenge screen, the challenge answer review and Premium videos. Other screens stay normal so students can share results, streaks and the app.
- **Detection:** Android 14+ tells the app when a screenshot is attempted (`Activity.ScreenCaptureCallback`), Android 15+ when the screen is being recorded (`WindowManager.addScreenRecordingCallback`); permissions `DETECT_SCREEN_CAPTURE` / `DETECT_SCREEN_RECORDING` (normal, no prompt). The student sees a short warning. In a challenge the attempt is also saved as a fair-play flag ("Tried to take a screenshot", "Screen recording was on") for the review before prizes — not an automatic disqualification, because a key press can be an accident. Older Android versions still block the picture but cannot tell us. Photos taken with a second phone cannot be detected by any app; one question at a time, random papers and short timers are the defence there.
- Tests: `supabase/tests/challenges_v4.test.sql` 7/7; app tests 63/63.

**D-076 · 2026-11-03 · Screenshots and screen recording blocked in the whole app (owner)**
- The owner chose to block screen capture in the **whole app** so it works on every Android phone (not only Android 15+). FLAG_SECURE is set in `MainActivity.onCreate` before the first frame and is never cleared; `SecureScreen.off()` no longer turns it off. A screenshot or recording of the app comes out black, on all Android versions.
- Side effects (accepted): students cannot screenshot their results, streaks or receipts to share; the recent-apps preview of the app is blank; store-listing screenshots must be taken another way (see open question in PROGRESS).
- On Android 14+ a screenshot attempt shows "Screenshots are turned off in SolutionTee CBT to protect our questions." (tests, challenges and challenge reviews keep their own message). In challenges, attempts stay fair-play flags (D-075).
- Briefly considered: screen recording on Android 15+ disqualifies a challenge entry (migration `challenges_v5`). Reverted at once (`challenges_v5_revert`) when the owner chose the whole-app block instead, so recording during a challenge is a fair-play flag, not a disqualification.
- App tests 64/64.

**D-077 · 2026-11-03 · Random past questions in challenges come from any year (owner)**
- Owner decision: "Add random past questions" uses **any published year, Free and Premium** (replaces the Free-years-only rule of D-074 for this button). So a Free student can meet Premium-year questions inside a challenge (one at a time, screenshots blocked) and, if the admin leaves answer review on, in "Review my answers" after the end. Premium years stay locked everywhere else (past questions, CBT tests).
- Still: published questions only, no passage or picture questions, A–D answers only, never the same question twice in one challenge.
- "Pick from past questions" (one by one, the search shared with the question of the day) still lists Free years only.
- DB check (rolled back): Mathematics now gives 69 questions instead of 15, 54 of them from Premium years. `challenges_v3.test.sql` updated.

**D-078 · 2026-11-03 · 4E3: referrals, one account per phone, bans with one appeal**
- **Codes:** every student gets a code like `TOLU-7K3P` (first name + 4 characters without 0/O/1/I), made the first time they open Invite friends. The sign-up form's code (any letter case) makes a pending friend; a student who skipped it can add a code in their first 7 days. Self-referral is refused.
- **A friend counts** when their email is verified, they finish one practice test (or buy Premium, if the admin chooses), they use the app on their own phone (hashed Android ID), that phone is not the referrer's and had no earlier account, and the referrer is under the monthly limit (default 20; a friend over the limit counts the next month, checked daily at 01:07 Lagos). Shared phone, fake accounts and bans → "Not counted" with the reason. Assumption 3 of `phase-4e.md` stands: no SMS check until the owner picks a provider.
- **Rewards** (Admin → Referrals, defaults from D-031): 10% off per friend up to 100% (10 friends = free Premium), applied by the server in `private.price` when no promo code is used, so it works for Paystack (website, direct APK); Google Play sets its own prices. Paying spends those friends (trigger on payments). Every 30 friends in total (never resets): ₦5,000 cash; the student sends bank details in the app (never PIN, card or password), the admin pays by transfer and marks it paid.
- **One account per phone:** the app saves the phone after sign-in (`device_register`; staff accounts are not saved). The first account owns the phone; a later account sees "This phone already has an account" and cannot use the app or earn rewards, unless the admin allows it in Fraud & bans (for example brothers and sisters). Android ID changes after a factory reset, which counts as a new phone.
- **Bans:** `admin_ban` (Users → Ban, or Fraud & bans → "Ban all on this phone") bans the student and optionally every account on the same phones, cancels unpaid referral cash and unpaid challenge prizes (the prize moves to the next fair entry), and logs everything. Sign-in now stays open (older bans also blocked sign-in at the Auth level; unbanning clears it) so the student sees the ban screen with the reason and can send **one appeal within 14 days**; the server already refuses a banned account's questions, study content, AI, payments, challenges and referrals. Admin accepts (unban) or rejects with a note; the student is told.
- Notifications: new sources `referral` and `ban` (topic "account").
- Tests: `supabase/tests/referrals_bans.test.sql` 22/22; app tests 72/72 (`test/invite_test.dart`).

**D-079 · 2026-11-03 · Stricter fraud checks: phone-wide id, clones, phone bans (owner)**
- **Why the dual app was missed:** the Android ID is different for every copy of an app (dual apps, cloners, work profiles), so a dual copy looked like a new phone. The app now also sends a **phone-wide id** (the Widevine device id, the same for every app copy and user on the phone; hashed with our salt), plus the Android ID. A match on either links the accounts. A factory reset still makes a phone look new.
- **Clone detection** (Android, `phoneFlags`): running as another Android user (dual apps, Secure Folder, work profile), app data outside the normal place (cloners such as Parallel Space), a changed package name → "clone:…" flags: the app shows "Use the original app" and the server logs it. A known cloner merely installed and emulators are flags for the admin only.
- **Server-side, not just the screen:** `is_banned` now also covers a second account on a phone (unless the admin allowed it) and any account on a banned phone, so questions, study, AI, payments, challenges and referrals are refused for them. `device_check_in` runs after sign-in and on every app start; a second account and clones go to the activity log.
- **Phone bans:** Admin → Fraud & bans → a phone → "Ban phone" bans all of that phone's ids and every account on it. Before sign-in the app checks the phone (`device_status`) and shows "This phone is banned"; the sign-up API refuses a banned phone; an account that signs in there is banned at once. The person can send **one waiting appeal** (3 in all) with an email, no account needed; the admin's answer is emailed (Brevo). Accepting lifts the phone ban and opens the accounts that were banned only because of it.
- **Fraud & bans page v2:** totals, tabs (Needs attention, Shared phones, Banned phones, Banned accounts, Flagged phones, Activity), search, phone cards with risk level, flags, each account's tests and Premium, and the actions (Allow family / Block, ban account, ban phone, lift).
- **Referral codes:** made with up to 12 letters of the first name, and 2–20 letters accepted at sign-up and in "Add code" (EMMANUEL-H9X8, OLUWASEUN-7K3P).
- Limits: a modified app could send false ids; a second phone is a second phone. Play Integrity (Play Console) can be added later.
- Tests: `supabase/tests/fraud_v2.test.sql` 12/12, `referrals_bans.test.sql` re-run; app tests 75/75.

**D-080 · 2026-11-03 · Screenshot block is an admin switch; the direct app updates itself (owner)**
- Replaces D-076. Admin → Flags & settings → "Screenshots and screen recording": **Block in the whole app** (default off, so the owner can send screenshots and recordings) and **Block in tests, challenges and Premium videos** (default on: CBT tests, challenges, challenge answer reviews, Premium videos). Saved in `app_settings.screen_protection` (public); the app applies it every time the settings load. Screenshot messages only show when the screen is really blocked; in challenges a screenshot attempt is still saved as a fair-play flag.
- **In-app update (direct app only):** GitHub now sends the build number (Android versionCode = minutes since 1970) with every published APK; `GET /api/app/latest` returns version, build, size and the download link. The app compares it with its own versionCode on start and every time it comes back to the front. If newer: with "Students must update to the newest app" on (default, `app_update.force`), a full-screen **Update needed** replaces every screen; off, a small "A new version is ready" card. **Update now** downloads the APK inside the app (progress, reused if already downloaded), asks once for Android's "install unknown apps" permission, then opens Android's installer (FileProvider; the permission and provider are only in the direct flavor). Same signing key, so it installs over the old app and keeps the account.
- The Play Store app is updated by Google Play (Play does not allow self-updates); its old "minimum version" screen stays.
- Builds published before this have no build number: the build time decides, with 30 minutes of slack. Developer builds (versionCode 1) are never asked.
- This first version with the updater must be installed once from /download; after that, updates happen in the app.
- App tests 78/78.

**D-081 · 2026-11-04 · XP, the app's game coin — step XP1 (owner; plan `docs/plans/xp-streaks.md`)**
- Owner decisions: bought XP is never used for cash-prize challenges (Google Play's real-money contest rule and Nigerian state gaming law); the streak needs one question a day (opening the app gives the daily XP only); default prices to start; build in 4 steps (XP1 core, XP2 streaks and welcome-back, XP3 spending, XP4 buying).
- **Wallet:** `profiles.xp_earned` and `xp_bought` (never below 0) with an append-only `xp_ledger` (unique key per action, so nothing is given twice). Only the server gives or takes XP (`private.xp_add` / `private.xp_take`, atomic, bought XP spent first where allowed).
- **Earning (all numbers in Admin → XP & streaks, `app_settings.xp`):** daily claim 10 (once per Lagos day), test 5 (at least 10 questions and 2 minutes, 10 a day) + 1 per 10% above 50%, full mock 30 (2 a day), question of the day 2 (+3 when right), challenge finished 20, friend counted 50; most 300 XP a day (daily claim, streak bonuses and admin gifts not counted). Banned, phone-banned and second accounts earn nothing.
- **Admin:** XP on/off (off hides XP everywhere, balances kept), every number, prizes, streak prices, Premium XP prices, packs; totals; a 30-day "given vs spent" chart (watch for inflation); top students; a student's wallet with give/take and a reason (audit log).
- **App:** XP chip on Home, "Your daily XP is ready → Claim" card, Me → My XP (balance, earned/bought, today against the limit, ways to earn, history).
- Tests: `supabase/tests/xp_core.test.sql` 14/14; app tests 82/82.

**D-082 · 2026-11-04 · XP2: streaks, the daily claim pop-up and the new welcome-back (owner)**
- **One question a day keeps the streak** (owner): a finished test, the question of the day or a challenge, counted on the server (`private.practice_days`), so the streak is the same on every phone and includes the question of the day. Offline the app falls back to the tests on the phone.
- **Milestones** 3 / 7 / 14 / 30 / 60 / 100 days (admin sets the XP): the bonus is given once per streak run (not capped by the daily limit); the app shows a full-screen celebration (confetti, the flame, the bonus) once (`streak_seen`).
- **Streak freeze:** bought with XP (default 50, hold up to 2). Every night at 00:20 Lagos a missed yesterday is saved by a held freeze; the student gets "Your streak freeze saved your streak" in the morning.
- **Streak repair:** the day after missing, the lost streak can be brought back for XP (default 200; admin can turn it off).
- **Daily claim pop-up:** the first app open of each day (after the account check): photo in a gold ring, the flame and streak, this week, the next bonus, "Claim +10 XP" with a coin burst and a vibration; "Later" keeps the Home card.
- **Welcome-back screen** (owner's screenshot): the student's photo in a gold ring that fills when today is done, a flame badge with the streak number, staggered entrance, the streak card with the animated week and the next bonus, the XP card with Claim; "Start practising" or "Continue my test".
- **Me → My streak:** the flame (grows at 7 / 30 / 100 days), longest, this week (gold = practised, snowflake = saved), repair, freezes, bonuses. The Home streak chip opens it.
- Animations: flutter_animate, no blur, simple versions under "reduce motion".
- Tests: `supabase/tests/xp_streaks.test.sql` 12/12; app tests 85/85.

**D-083 · 2026-11-04 · XP3: spending XP and XP prizes (owner)**
- **Challenge entry fee in XP:** Admin → a challenge → "Entry fee in XP" (0 = free). Taken by the server in the same step as the entry (no entry, no XP taken). **Cash-prize challenges accept earned XP only** (D-081: Google Play and Nigerian gaming law); events and practice challenges take bought XP first. Not returned after a disqualification. XP switched off → the fee is ignored (free entry). The app shows "100 XP entry" and asks "Join for 100 XP?" before starting.
- **Premium with XP:** Me → My XP → "Get Premium with XP" lists plans with an XP price (Admin → XP & streaks, default Monthly 3,000 · 3 Months 8,000 · Exam season 14,000); Premium starts now or when current Premium ends (same rules as paid plans, entitlement source `xp`). Bought XP counts here.
- **XP prizes:** challenge 1st / 2nd / 3rd (default 200 / 100 / 50) after the close, fair entries only (every 15 minutes, once per entry); **weekly**: every Monday 00:05 Lagos the 3 best JAMB mocks of last week (leaderboard rules: full 400-mark mock, not held for a fast finish, not rejected, no staff or banned) get 300 / 150 / 75 XP, with a notification.
- Tests: `supabase/tests/xp_spend.test.sql` 9/9; app tests 87/87.

**D-084 · 2026-11-04 · XP4: buying XP packs (owner)**
- Me → My XP → **Buy XP**: the admin's packs (default 200 XP ₦200 · 550 XP ₦500 · 1,200 XP ₦1,000 · 3,200 XP ₦2,500). Paystack in the direct app and the website (and the Play app only when the admin turns on "Paystack in the Play Store app"); the Play app shows "coming soon" until Google Play products are set up (Play Console).
- Same safety as Premium payments: the price comes from the server (`xp_pack_start`, the app never sends an amount), Paystack's webhook (HMAC-SHA512) and verify must agree on the amount, and the XP is added **once** per payment (ledger key `pack:<payment>`); a wrong amount goes to "needs review" with no XP. A refund takes back the pack's bought XP that is still unspent.
- `payments.plan_id` may now be empty for XP packs (`xp_pack` holds the XP); Admin → Payments shows them as "550 XP pack".
- Bought XP is kept apart in the wallet and never pays a cash-prize challenge entry (D-081).
- Tests: `supabase/tests/xp_buy.test.sql` 6/6; app tests 88/88.
- Fix (owner report, 2026-11-04): the "Join for 100 XP?" and "Get Premium with XP" buttons closed the screen behind the pop-up instead of the pop-up (inside the tabs the screen's navigator is not the pop-up's); both now close the pop-up with its own context. Challenge cards on Home, the list and the details now say "100 XP to join" / "Entry 100 XP" instead of "Free". A test with the tabs (ShellRoute) catches it; it fails with the old code.

**D-085 · 2026-11-04 · Calculator in challenges, per challenge (owner)**
- Admin → a challenge → "Students can use the calculator" (`challenges.allow_calculator`, default off). On: a calculator button on every question of that challenge, the same calculator as the CBT test. It opens inside the app (a sheet), so it does not count as leaving the challenge, and the question timer keeps running. Off (default): no button, for mental-maths or speed challenges.
- App tests 90/90.

**D-086 · 2026-11-04 · Big update, step U1: fixes, Home order, streak week (owner list after "XP4 ok")**
- Plan: `docs/plans/big-update.md` (6 steps, `U1 ok` … `U6 ok`).
- **OTP boxes:** the real text field now lies (invisible) on top of the boxes, so a tap always opens the keyboard (before, a tap only asked for focus, and Android did not reopen the keyboard when the field already had it), typing, long-press paste and SMS autofill work. Bigger boxes, 8 digits as 4 – 4, blinking cursor, digits pop in.
- **Tour:** each step scrolls its card into view before the spotlight moves there, and the tip card is placed in the bigger free space on screen (centred if none). Before, step 5 (Upgrade, below the screen) put the tip off-screen and the dark layer blocked every tap. New: icons, pulsing gold ring, gliding spotlight, progress bar, Back button, 8 steps (top card, XP & streak, challenges, start a test, Study, Test, AI, Upgrade). The phone's back button ends the tour.
- **Streak week:** done = flickering flame (gold chain joins days in a row), today done = glowing flame, today not yet = pulsing ring with an outline flame, frozen = turning snowflake, missed (a past day this week without practice) = drifting rain cloud, future = empty. All still with reduce motion.
- **Home order:** top card → challenges → Start a CBT practice → question of the day → Invite friends → news → upgrade (free only). The daily XP claim card stays under the top card while it can be claimed.
- **Top card:** an unfinished test (any mode) shows "Continue where you stopped" (logo, answered, time left, % ring, Continue). Otherwise "Today's motivation / study tip" from Admin → Daily motivation (`motivation_quotes`, 60 samples; the same line for everyone each Lagos day, in list order; `today_motivation()`), with today's goal ring and Practise.
- **Sheets** (paywall included) open on the root navigator, above the bottom tabs and inside the safe area, with a close (X) button; the phone's back button closes them. Before, the paywall opened under the tabs, so its Pay button was hidden and back did nothing visible.
- **Bookmarks:** `bookmarks.ref` was a UUID, but the app saves `note:<id>` / `exam/subject/year/q`, so every save failed (0 bookmarks existed). Now text (1–200 letters).
- **NECO:** "Coming soon" showed because no NECO years are uploaded (JAMB 17, WAEC 2, NECO 0). The label is now "No papers yet" and a tap explains it; NECO opens like WAEC once years are uploaded in Admin → Exams & years.
- **Quick test:** questions stay grouped by subject in the student's subject order (an even share each, passages kept together) instead of mixed, so it moves through subjects like the real exam.
- Tests: `supabase/tests/u1.test.sql` (bookmarks 2/2, motivation read + write refused); app tests 96/96 (`test/u1_test.dart`: OTP tap after the keyboard closes, tour reaching an off-screen 5th step and Done, Back, streak states).

**D-087 · 2026-11-04 · Sign in with Google (owner)**
- "Continue with Google" at the top of Create account and Log in, with an "or" line above the email form. It appears only when Admin → Flags & settings → Sign in with Google is on **and** a Web client ID is saved (`app_settings.google_auth`, public). The client secret lives only in Supabase Auth.
- Native Android account picker (`google_sign_in` 7, Credential Manager), then `signInWithIdToken` in Supabase. A fresh random **nonce** each time: Google gets its SHA-256, Supabase checks the raw value. This means a copied ID token can't be replayed.
- New Google accounts: name from Google, Terms consent recorded ("By continuing with Google you agree…" under the button, `terms_accepted_at`), the referral code applied if one was typed, the welcome email, then profile setup. Existing accounts with the same verified email are linked by Supabase, not duplicated.
- Fraud rules unchanged: `nextRoute` refuses banned phones before sign-in, and `device_check_in` right after any sign-in blocks second accounts and banned phones (D-079).
- Setup for the owner: SETUP §17. The APK's SHA-1 is read from the published APK.
- Tests: app 99/99 (`u1_test.dart`: button hidden when off or without a client ID, shown when on, on both screens).

**D-088 · 2026-11-04 · U1 fixes after the owner's phone test (owner: "after you fix that, U1 ok")**
- **Google logo:** the button now shows Google's official "G" (`assets/third_party/google_g.png`), cut from Google's own sign-in asset pack (`signin-assets.zip`, Light / no text / square SVG) with the button frame removed and rendered at 192 px with a clear background. It is not redrawn. The source is noted in `assets/third_party/README.md`.
- **Goal ring:** while going, it shows today's number inside. At the goal, a gold badge pops in, a check mark draws itself, three sparkles twinkle and a soft glow breathes. It stays still with reduce motion.
- **Today's questions from the server:** `my_practice_today()` counts answered questions in tests saved today (Lagos day) from any phone. The app adds its own finished tests not synced yet, so nothing is counted twice and the count survives logging out and changing phones. Offline with no answer from today, it uses the phone's own count.
- **Challenge background pictures:** Admin → a challenge → "Light mode picture" and "Dark mode picture" (`challenges.bg_light` / `bg_dark`, R2 `public/challenges/…`, WebP / PNG / JPG under 2 MB). If one is missing, the other is used. In the app, the live hero card and the challenge page lay a blue shade over the picture: navy in dark mode, brighter blue in light mode. The white text stays readable. Smaller cards (Home mini cards, the list and "Next" card) use a soft surface shade instead. Data saver hides the pictures. Links are signed only for published challenges (`can_view_challenge_image`).
- The hero card no longer says "free for everyone" when the challenge has an XP entry fee.
- Tests: `supabase/tests/u1.test.sql` (pictures, today's count); app 101/101.

**D-089 · 2026-11-04 · U2: paying inside the app (owner: "Paystack sheet in app")**
- Checkout and Buy XP ask "How do you want to pay?": **Card** (Paystack's own payment sheet inside the app, `com.paystack.android:paystack-ui` 0.1.8 in the direct build only, through `PaystackBridge.kt`; the main screen is now a `FlutterFragmentActivity`), **Bank transfer** or **USSD** (GTBank *737#, UBA *919#, Sterling *822#, Zenith *966#). Transfer and USSD use our own screen: account number / code with Copy, "Dial now", a countdown, and a check every 5 seconds that closes the screen when the money arrives. Every screen has a back button.
- Card details are typed only into Paystack's sheet, never into our screens (PCI DSS); students may see the Paystack name there. The 1.0.0 sheet needs compile SDK 37 (newer than our Android build tools), so 0.1.8 is used; it follows the phone's own light / dark theme.
- The server still decides everything. The price comes from `pay_start` / `xp_pack_start`; transfer and USSD use Paystack's Charge API with the server's reference. Premium / XP is given only after the webhook (HMAC-SHA512) or verify agrees on the amount, once per payment. Each try gets a new reference. If the sheet says "paid", the app still asks the server to verify. If the sheet is not available (Play build, no public key, or an error), the app uses Paystack's page in an in-app tab, as before.
- New Edge Function secret **PAYSTACK_PUBLIC_KEY** (pk_test_… / pk_live_…, public). It is used only when its mode matches the secret key. Without it, card payments use the in-app page.
- The direct APK grows from 28.5 MB to 30.7 MB (Paystack's sheet brings Jetpack Compose). The Play build is unchanged. The GitHub build ran out of memory in R8 with the 1.5 GB Gradle heap, so the workflow raises it to 6 GB for the GitHub machine only. The laptop setting in `gradle.properties` stays light (CLAUDE.md §2); a release build on the laptop may need `-Xmx3g`.
- Tests: app 107/107 (`test/u2_test.dart`: method → server request, transfer / USSD to our screen, sheet cancelled / failed, fallback to the page, sheet "paid" → server verify, transfer screen closes itself when confirmed).

**D-090 · 2026-11-04 · U2: prize payouts by Paystack Transfer, approved by an admin (owner: "Admin taps Approve")**
- Winners pick their bank from Paystack's bank list (`paystack` action `banks`) and type 10 digits. The app shows the account name Paystack finds (`resolve`, 10 tries / 10 min). The claim is saved with the bank code (`prize_claim_v2`; older apps keep `prize_claim` and are paid by hand).
- Admin → Winners & payouts → **Pay with Paystack**: 1) **Check account**: the server asks Paystack whose account it is and shows it next to the typed name and the profile name (with a "matches / check the name" hint). 2) **Send ₦X** (with a confirm): the server makes the recipient and the transfer with a one-time `po_…` reference. 3) Paystack's `transfer.success / failed / reversed` webhook is checked with transfer verify; success marks the claim paid and tells the winner in the app. "Ask Paystack again" checks a payout that is on its way. "I paid it myself" stays for hand payments.
- Safety: only admins with 2-step can check or send (`am_money_admin` in the Edge Function). The payout steps (`payout_checked / begin / recipient / result`) run only as the server, not for students. A payout cannot be sent twice (row lock + status). A sent payout stays sent. Every check and send is written to the audit log.
- Needs (owner, SETUP §18): a registered Paystack business with Transfers on, transfer OTP turned off, and money in the Paystack balance.
- **Off for now** (owner, 2026-11-04: the business is not registered yet): feature flag `paystack_payouts` (Flags & settings), default off. Off: Winners & payouts is the old flow ("I have paid" after paying by hand). The "Pay with Paystack" panel is hidden, and the server refuses payout check / send. Winners still pick their bank from Paystack's list, so their claims are ready for Paystack once it is turned on. Setup check `GET /functions/v1/paystack?health=1` says whether the keys are set and in the same mode (never the keys) and whether payouts are on.
- DB tests: `supabase/tests/u2.test.sql` (11/11).

**D-091 · 2026-11-04 · U2: challenge player limit and minimum winning score (owner)**
- Admin → a challenge → "Most players" (0 = no limit) and "Minimum score to win (%)" (0 = none).
- When full, nobody else can start: the server checks under a lock, so two students cannot take the last place. The app shows "N of M places left" or "Full", and the button says "Full · look out for the next one". A student who already joined is never locked out.
- Minimum score: 1st, 2nd or 3rd below the % of their questions get no cash prize, no Premium days and no XP prize (`challenge_reached_min` in `challenge_rank` and `xp_prize_job`). The app shows "Winners need 60% or more" before joining.

**D-092 · 2026-11-04 · Every Paystack way to pay inside the app (owner: "have all those options in app")**
- Research, from Paystack's own OpenAPI spec (github.com/PaystackOSS/openapi, `dist/paystack.yaml`; paystack.com refuses automated readers):
  - The Initialize channels are only apple_pay, bank, bank_transfer, capitec_pay, card, eft, mobile_money, payattitude, qr and ussd. There is no OPay, PocketApp or Zap channel.
  - USSD types 737, 919, 822 and 966 are all supported.
  - Pay with Bank has follow-up steps (submit_otp / phone / birthday / pin / address, check pending).
  - Our live account's Pay with Bank list (`GET /bank?pay_with_bank=true`, read through the new `?health=1&banks=1`) holds only **Kuda Bank and PalmPay**. So OPay, PocketApp and Zap are reachable only inside Paystack's own payment screen.
- The app's picker now has **Card · Bank transfer · USSD**, then **Pay with an app: OPay · PocketApp · Zap · Bank app (Kuda, PalmPay…)**.
  - Card opens Paystack's sheet straight on the card form (`channels: ["card"]`).
  - Transfer and USSD stay on our own screens.
  - The app options open Paystack's own secure screen inside the app (`method: "page"`, every channel on), with a note to tap that app there. The in-app tab is used only if the sheet cannot open.
  - The checking and the server rules are the same as for every payment (webhook + verify, the price from the server).
- The server also has a native Pay with Bank flow (`method: "bank"`, `pay_banks`, `charge_submit` for OTP / phone / birthday) for when Paystack offers more banks directly. The app does not use it yet: Kuda needs a Kuda app token, so Paystack's screen handles both banks better today.
- Note (2026-11-04): the Paystack keys in Supabase are now **live** (`?health=1` shows secret and public both live). Test payments now use real money.
- App tests 109/109.

**D-093 · 2026-11-04 · OPay, PocketApp, Zap and bank apps in an embedded Paystack checkout; new plan sheet (owner: "after you have done and fixed this, U2 ok")**
- Phone test: Paystack's Android sheet (0.1.8) offers only Card, Bank Transfer and Zap, so OPay and the others were missing when tapped. These four options now open **Paystack's web checkout inside our own screen**, an embedded WebView (`webview_flutter`), where Paystack shows every method on the account. The screen has:
  - our top bar and back button (the phone's back goes back a page first, then closes);
  - a "secured by Paystack · tap OPay below" strip and a loading bar;
  - a check every 4 seconds, which closes the screen as soon as the server confirms the payment;
  - an "I have paid" button, and a retry or secure-tab fallback when the page cannot load.
- Links the checkout sends to bank or wallet apps (`intent://`, `opay://`, `tel:`, …) open the real app: an `intent://` link tries the app's own link, then its fallback page, then the app in the Play Store. Paystack's `standard.paystack.co/close` cancels, and our `/pay/done` callback page closes and checks.
- Card still opens Paystack's native sheet straight on the card form. Transfer and USSD stay on our own screens. The server rules are unchanged.
- **Plan sheet redesign:**
  - no close (X) button (swipe down or back still close it);
  - a navy hero with a floating, shining gold crown;
  - benefits with tick badges that slide in one by one;
  - plan cards that lift with a gold glow and pop a tick in when chosen, a "per month" price for longer plans, and a shimmering "Best value" ribbon;
  - a gold "Continue · ₦3,500" button, and a row listing every way to pay.
- The payment options slide in one by one. All of it stays still with reduce motion.
- Tests: app 111/111 (embedded checkout link rules, `intent://` targets, web result for app options).
- Phone test 2 (owner): no "tap OPay below" step, and no strip. Paystack's checkout has no link that opens it on a chosen method, so once it has loaded the app taps that option itself (`autoTapScript`, a `StApp` JavaScript channel). Meanwhile our own animated cover shows: a pulsing icon, "Opening OPay…", what is being paid for, a moving bar and "Secured by Paystack". So students go straight to the OPay / Zap / Bank step. The cover always lifts (after the tap, or after 10 s). If the option is not on the account (PocketApp today), a small notice says so and the student picks another way on Paystack's page. Checked in Chromium against a copy of Paystack's list: OPay, Zap and Bank tap the right row, "Bank" does not match "Pay with Transfer", PocketApp reports not found. App tests 112/112.
- PocketApp is hidden from our list (owner, 2026-11-04): Paystack does not offer it on this account's checkout. Add its line back in `pay_methods.dart` when it does.

**D-094 · 2026-11-04 · OPay / Zap / Bank open on their own step (fixed and tested on Paystack's real page), real logos, new loading and empty-challenge designs (owner)**
- Phone test: the cover showed, but Paystack's list stayed. Paystack's real checkout (read from a real checkout page) is `li.nav__item > a > span.text > span.mobile-only "Pay with OPay"`, and only the `<a>` listens for taps. The old script tapped the outer `<li>`, so Paystack never got it. The new script taps the `<a>` / button itself, with a fallback for rows without links. Checked in Chromium on a copy built from the real page:
  - the old script reported "clicked" but nothing reached Paystack (the bug, reproduced);
  - the new script reaches "Pay with OPay", "NEW Pay with Zap" and "Pay with Bank".
  - Paystack's Cloudflare check stopped further automated loads of the live page; the phone's WebView is not affected.
- A one-channel checkout was tried first (a temporary, token-guarded `pay-probe` function, now a 404 stub): Paystack answers "No active channel" for `opay` and `zap`; `bank` works. So the tap is the only way to open OPay and Zap directly.
- Real logos (`assets/third_party`, sources in its README):
  - OPay's official SVG from opayweb.com (the full wordmark, plus its ring symbol for small tiles, only re-framed);
  - the "Zap by Paystack" app icon from Apple's App Store lookup (seller Paystack Payments Limited).
  - Used in the payment list and the loading screen.
- New loading screen:
  - the real logo pops in, with brand-coloured ripples moving out and a turning gold arc;
  - "Connecting securely… → Opening OPay…" with bouncing dots;
  - a green tick and "OPay is ready" when the step is open, then a smooth fade to Paystack's OPay step.
- New "No challenge right now" card on Home: a navy card with a floating, shining gold trophy and twinkling sparkles, "The next challenge is coming", Past winners and All challenges.
- All animations stay still with reduce motion. App tests 112/112.

**D-095 · 2026-11-04 · Leaving or cancelling a payment is detected at once; "Leave this payment?" pop-up; new "Opening OPay" screen (owner)**
- Problem: closing Paystack's checkout (back button, our back arrow, Paystack's own "Cancel", closing the card sheet) left the app on "Checking payment" and the admin page on "Waiting", although nothing was paid.
- Server:
  - new `cancel` action in the `paystack` function and `pay_cancel(reference, user, note)` (service role only; migration `20261104214211_pay_cancel`);
  - it asks Paystack first: if the payment went through after all (for example in the OPay app), Premium / XP is given and the app shows success;
  - otherwise the payment becomes `abandoned` ("Not finished" in Admin → Payments) with a `cancelled` event saying how the student left;
  - only the student who started it can cancel it; a cancelled payment that Paystack later reports as paid still counts (webhook or check);
  - `check` re-checks abandoned payments with Paystack and answers `abandoned` while unpaid.
- App:
  - Back (phone button or our arrow) on the Paystack screen and on the bank transfer / USSD screen opens an animated pop-up (hourglass turning over in a breathing amber ring, with the OPay / Zap / bank logo): **Stay and pay** · **I have paid · check now** · **Leave and cancel payment**. Tapping outside = stay.
  - Leave → "Cancelling payment…" → the server cancel → back on the plan / XP screen with "Payment cancelled. You were not charged." No more "checking".
  - I have paid → checks at once; if not confirmed yet, the plan / XP screen keeps checking as before.
  - Paystack's own "Cancel payment" and closing the card sheet cancel straight away (no second question).
  - Inside a bank's own page (for example a card check) back still goes back one page; on Paystack's checkout it asks.
  - The "Checking payment" card has a new **I did not pay · cancel** button.
  - With no internet the app still leaves; the payment then ends as "Not finished" after a day (as before).
- New "Opening OPay / Zap / your bank" screen (replaces the ripple design): SolutionTee's app icon and the partner's real logo joined by a dashed secure line with a gold light running along it; a shield in the middle turns into a green tick; three steps tick off (Secure connection → Opening OPay → Ready to pay), driven by the real page load and the tap; a sweeping progress bar; "Secured by Paystack · We never see your PIN". Light and dark mode from the theme tokens; everything still with reduce motion.
- App tests 116/116 (new: leave pop-up choices, cancel on the server, paid-after-all, card sheet cancel, opening steps). DB check (rolled back): cancel → abandoned, stranger cannot cancel, later success → Premium given.
- Phone test fixes (2026-11-05): the sweeping progress bar under the steps is removed; "Cancelling payment…" on the bank transfer / USSD screen no longer shows Flutter's yellow underlines (the card now has its own Material layer; a test checks it). App tests 117/117.
- The XP payment sheet ("How do you want to pay?") has no × any more, like the plan sheet: swipe down, tap outside or press back to close (owner, 2026-11-05). U2 approved ("U2 ok").
