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

**D-096 · 2026-11-07 · U3 AI tutor v2: locked down, education only, knows the student, tools, suggestions, voice (plan `docs/plans/u3-ai-tutor.md`)**
- Leak fixed: the tutor read any question (answer included) with the service role. Now questions come only through `ai_question_for_me` / `ai_pick`, called with the student's own login, so the plan's year rules apply: own finished test, open year (past-questions rule), or today's question of the day (without its answer until answered). Locked → "This question is in a Premium year" + Upgrade. Lesson-note search (`ai_match_for`) uses Premium notes only for Premium students.
- Education only: a short JSON router call (2 models × 7 s) plus word rules; off-topic gets a kind reply and uses no prompt.
- Memory: the whole thread up to ~14,000 characters; older parts kept as a model-written summary on the chat (free).
- Knows the student (`ai_student_context`, service role, own id only): first name (cleaned), exams, subjects, target, plan, streak, scores, 3 weakest topics. Passed as data; guard rules against prompt injection; output filter hides anything that looks like a key or token.
- Tools: practice_test, quiz, open_note (server-written, free), qotd, weak_topics, study_plan (the AI writes, 1 prompt). Logged in `ai_tools_log` (admins read). Suggestions come from the student's own data (no model, free). Quiz answers are marked on the server (`ai_quiz_check`); the phone never gets answers first.
- App: tool cards (Start test opens our CBT with the server-picked questions, quiz with instant marking and "Explain with AI", notes, weak-topic bars), server chips, typing shimmer, voice input (speech_to_text; the microphone is asked for on the first tap), "Free · no prompt used" note.
- Prompt use (technical default): free = off-topic, suggestions, tests/quizzes/notes, quiz marking, summaries, failures. 1 prompt = AI-written answers.
- Token management (owner, 2026-11-07): design, SQL, Edge Function and review by the lead model; app widgets/tests by a Sonnet helper and the 45 KB deploy by a Haiku helper, each checked (deployed copy diffed SAME; analyze clean, tests 127/127, shots at 360 px light/dark).
- DB checks (rolled back): free student refused a locked question; open question has its answer; quiz sends no answers; a student cannot call the context function.

**D-097 · 2026-11-07 · U3b AI tutor upgrade after the owner's phone test (plan `docs/plans/u3b-ai-tutor-plus.md`)**
- Bugs fixed: filler words ("test", "mock test", "school", years) were taken as topics and the subject was guessed. Now `cleanTopic` strips them, a **mock exam** tool opens the real CBT mock (`/test/setup?exam=JAMB&mode=full`), years are understood (`ai_pick2`, Premium years → Upgrade), and an unclear subject gives a **subject picker** card.
- New tools: AI-written quizzes (`ai_gen_questions`; answers only on the server, 1 prompt), open-a-page (`SCREENS`), saved 7-day study plans (`study_plans`, today's part on Home via `my_today_plan`, morning push at 06:00 Lagos via `plan-reminders` cron, tick days / reminders via `plan_update`).
- Hint ladder (3 levels + "Check my working"), follow-up questions after answers (free), curious suggestions (weak topics, "most students miss" counted across all students without names, last chat, mock, AI questions, a surprising fact), the app guide in the prompt.
- Answers finish in the background: the server keeps working under `EdgeRuntime.waitUntil` after the phone disconnects, saves the answer and sends "Your AI answer is ready" (`push_kick`); the app shows "Finishing in the background…" and picks it up (polling and on resume).
- Comeback messages (`ai-nudge` Edge Function, daily 16:41 Lagos by pg_cron with the push token): students away 2–30 days, at most one per 3 days, max 300/day, streak-reminder setting respected, AI-written per student with a kind template fallback. Admin switch `app_settings.ai_nudges`. Notification sources now include plan, nudge, ai.
- App (Sonnet helper, reviewed): quiz v2 (one at a time, reveal, score + confetti, retry wrong, more like this), agent steps, choices/open/plan cards, reactions (`ai_react`), reply quote, selectable text, living welcome, Home today plan, `/ai?tool=&args=` deep link. Tests 148/148, analyze clean, cards rendered with the real font at 360 px in light and dark.

**D-098 · 2026-11-07 · JAMB papers always complete; Use of English set the JAMB way (owner; plan `docs/plans/u3c-jamb-papers.md`)**
- Owner's pattern (60): comprehension 5, cloze 10, JAMB novel 10, sentence interpretation 5, antonyms 5, synonyms 5, basic grammar 10, oral 10 — in that order, in every year and scaled in mixed/quick tests. Research agrees (syllabus parts A/B/C; comprehension 5, cloze 10, novel 10). Stored as an admin-editable blueprint (`exam_blueprints`); other JAMB subjects 40.
- `questions.section` (+ `section_source` rule/ai/admin/import): 5,000 English questions sorted by wording rules; ~480 bare-word ones by the AI sorter (`sort-sections`, uses the correct answer; nightly + catch-up); new and edited questions sorted by a trigger; CSV `section` column; admin can override.
- Novels (owner, corrected): a year's paper uses that year's novel (2015 Forcados, 2017 In Dependence, 2019–20 Sweet Sixteen, 2021–24 The Life Changer, 2025 The Lekki Headmaster — detected from each year's questions; topped up only with the same book). Mixed and quick tests use the current set novel, The Lekki Headmaster. For mixed tests the novel section only uses questions on it (`match` "lekki" or novel questions from 2025 on). Only 27 such questions exist (2025): Premium students get them; free students' novel places are filled with other English questions — never an old novel.
- `cbt_paper` (as the student, plan rules apply): English by blueprint with whole passages and section instructions; other subjects exact size — random if a year has too many, quietly topped up from other open years if too few; duplicates (content_hash) never repeated. `fetch_questions_by_ids` downloads only the paper's questions (data-light). Offline: local fallback.
- App: JAMB full/subject/year/quick use the server paper; section instruction cards in CBT and review; palette grouped by section. Admin: Blueprints page with year × section coverage and "Sort English sections with AI", section field in the editor and list, CSV section column.
- Checks: Premium 2019 English = exact pattern with 10 Lekki Headmaster questions; Geography 2016 (493) → 40 random; Geography 2021 (1) → 40 from other years; app 154/154, web tsc + lint clean.
- Home "Continue where you stopped" redesign (owner, 2026-11-07): animated progress ring (answered/total), stats (answered, time left, to go), "Paused · started … ago" chip, light sweep + gold sparks, bobbing exam logo, gold Continue with a moving arrow, staggered entrance; still under reduce motion. The empty gap under it came from hidden Home sections each adding spacing; spacing is now added only above sections that show. App tests 157/157.

**D-099 · 2026-11-07 · JAMB mock challenges for SolutionTee tutorial students (owner)**
- A challenge style `jamb_mock`: the whole paper at once (Use of English + the student's 3 subjects, or fixed subjects), laid out like the JAMB CBT (candidate bar + timer, subject buttons, A–D, Previous/Next, numbered grid, Submit, calculator), always light like a CBT centre. Answers save as chosen and can change until submit; marked on the server (each subject /100, total /400); rank by score then time. Passages and pictures per question.
- Access: open, Premium only, a shared code, or personal invite codes (one per student, stored hashed, shown to the admin once; a used code cannot be reused by another student; 10 wrong tries per hour).
- Behaviour: leaving the screen, time away, screenshots/copy logged (`challenge_events`); the admin sets allowed leaves and total time away, and whether going over flags or auto-submits. Results: instant, after the end, or hidden.
- Teacher analytics (`mock_analytics`): leaderboard with subject scores, leaves, away time, flags, answered; most-missed questions with option picks and time; miss rate by topic/section; slowest questions; behaviour summary; per-student timeline.
- Checks (rolled back): wrong code refused; personal code works (any case); another student cannot reuse it or submit someone else's entry; paper has no answers; answers can change; 2nd leave with 1 allowed auto-submits; analytics show score, leaves, away time and the invite name. App 160/160.
- Admin (D-099): challenge "style" (standard / JAMB mock) with mock settings (time, who can enter, shared code, leaves and minutes away, flag or submit, when scores show); Access codes panel (make personal codes from a list of names, download once as CSV, see which are used); Pictures for questions (upload, copy key); JAMB mock CSV columns (number, section, topic, passage_key, passage_title, passage, image; sample /samples/jamb-mock-sample.csv); Mock analysis for teachers (summary, leaderboard with subject scores and behaviour, per-student timeline, most-missed questions with option picks, topics to teach again, slowest questions, results CSV).
- Owner correction (2026-11-07): JAMB mocks run in OUR normal CBT screen (not a separate JAMB-look screen). The server paper is saved on the phone without answers as a local attempt (id = server entry, mode "mock"); the CBT screen sends each choice, leaving/returning and submit to the server, follows the server deadline (never pauses), shows the leave warning, and after submit shows the JAMB-style result (each subject /100) and removes the phone copy. Admin: an ended challenge's title, description, background pictures, reward text and (mocks) results setting can still be edited.
- App updates are optional (owner): `app_update.force` is now false and the app treats anything but `true` as optional. Me → App update shows this phone's version, checks for a new one and downloads/installs it with progress; a "New" badge shows when one is ready, plus the small dismissible card.
- JAMB mock leaderboard (owner, 2026-11-07): mocks use the standard challenge leaderboard (Test → Challenges → the mock → ranking/winners), ranked by score then time, showing each score out of the student's maximum (100 per subject). The admin's "when scores show" setting also hides the leaderboard (always, or until the end). The mock result screen has "See the leaderboard".

**D-100 · 2026-11-07 · Big update 2 plan and owner decisions (plan `docs/plans/big-update-2.md`)**
- Order: A fixes + AI items 1–14 → B AdMob ads → C JAMB countdown → D Request a tutor → E Online classes → F Games (Duel, Arena, Beat the AI first) → G Community → rest of U4–U6.
- Ads: the mix — ads where eyes are (top banners under headers, native cards inside lists, interstitials only at breaks with caps); Low/Medium follow the soft plan, High→Ultra add the 23 "Watch to unlock" rewards capped at 15 a day then "Go Premium". Premium ad-free at every level; never during a running exam or checkout; rewarded unlocks verified on the server (AdMob SSV).
- Classes: YouTube Live (unlisted, played inside the app, link never shown) for lectures + Jitsi Meet (free, no time limit; new room and password per class, opened from the app only for allowed students) for interactive classes.
- Web search: Brave Search API (owner adds BRAVE_SEARCH_KEY as an Edge Function secret).

## D-101 — Big update 2, step B: Google AdMob ads (2026-11-07)
- **Levels** Off · Low · Medium · High · High Extra · Max · Ultra live in `app_settings.ads` (admin → Money → Ads). The server
  turns a level into rules (`private.ads_preset`): banner screens, a card (native) ad every N list items, break
  (interstitial) gap and daily cap, rewarded per day, ads after videos. The app reads `ads_config()` on open, so changing
  the level needs no app update. **Premium = no ads**, at every level.
- **Red line** in the app (`AdsGate`): CBT screen, challenge play, mock and checkout (paywall) block every ad.
- **Placements:** banners at the top of Study, News, Notes, Past questions, Videos, Leaderboard, History, Challenges, Me
  (only the screens the level lists). Card ads in News and Notes. Break ads when leaving results, a mock result or a video.
- **Rewarded ("watch to unlock")**, mix of soft levels and unlocks as the owner chose: +2 AI prompts, a Premium lesson
  note for 24 h, a streak freeze. Always the student's choice; daily cap per level, then "Go Premium". The reward is
  granted only by the server: `ad_reward_start` makes a nonce → AdMob server-side verification calls the Edge Function
  `admob-ssv`, which checks Google's ECDSA signature (keys from gstatic) → `ad_reward_grant` (once per nonce). In **test
  mode** (Google test ads send no verification) the app may claim the reward; turn test mode off for real ads.
  A note opened by an ad is served by `study_item` like a free one until it expires (`private.ad_unlocked`).
- **Age:** birth year asked once (`set_birth_year`). 18+ personalised; 13–17 or unknown: non-personalised and teen
  treatment; under 13: child treatment and G-rated ads.
- **Report:** the app counts impressions/clicks (`ads_log`, batched) into `ad_daily`; admin sees ads per day and unlocks.
  Money and payouts are in the AdMob account.
- AdMob app id is public (not a secret): gradle property / env `ADMOB_APP_ID`, Google's sample id until set.

## D-102 — Migration files match the live database exactly (2026-11-07)
- **Problem:** on 2026-11-07 the files in `supabase/migrations/` stopped matching the migration history on the project:
  25 versions were applied that day but the repo had 9 files with hand-picked numbers (e.g. `big2_ads` applied as
  `20261107144842`, file `20261107140000`), some combining several applied migrations.
- **Fix (no change to the live database):** the 9 files were replaced by 25 files, one per applied version, named
  `<version>_<name>.sql` exactly as in `supabase_migrations.schema_migrations`, with the applied statements as the content
  (checked by md5 against the database: 25/25 equal). The repo now has 84 files for 84 applied versions; versions and
  names before 2026-11-07 already matched. The comments that were in the old hand-written files are kept in git history.
- **Rule from now on:** apply with `apply_migration`, then read the applied version and save the file under that version
  with the applied text. Data-only actions (for example submitting a stuck mock entry for a student) are not migrations.

## D-103 — The ads start-up crash and the emulator check before /download (2026-11-07)
- **Crash:** after the ads update the app closed on opening. Real cause, from the emulator log:
  `Unable to get provider androidx.startup.InitializationProvider … Failed to create an instance of
  androidx.work.impl.WorkDatabase`. Google Mobile Ads brings WorkManager, which creates its Room database by reflection;
  the release shrinker (R8) removed that class. Two earlier guesses (androidx.lifecycle 2.9.4, then 2.10.0) did not fix it.
- **Fix:** `android/app/proguard-rules.pro` keeps Room databases, WorkManager and the ads/consent classes; WorkManager
  2.10.0 instead of 2.7.0; androidx.lifecycle pinned to 2.10.0 (the plugin's 2.11 needs compileSdk 37).
- **Rule:** the app workflow now has three jobs: `apk` (phone build), `emulator` (same app for x86_64, installed on an
  Android 14 emulator, opened, must keep running 40 s; crash log + screenshot kept as an artifact) and `publish`
  (/download only when both passed). Limit: the check opens the Welcome screen without signing in, so it does not show
  an ad; ads start only for a signed-in free student when the level is not Off.

## D-104 — Ads v2: video-first levels, watch to earn, ads everywhere except the red line (2026-11-07)
- **Plan:** `docs/plans/big2-ads-v2.md`. Money comes mostly from video (rewarded, break and app-open ads), so the levels
  are rebuilt around those, with banners and cards as filler. Low is hardly noticed; Ultra uses every slot AdMob allows.
- **Server:** level rules in `private.ads_preset` + `private.ads_extras` (sticky banner, random breaks, cards inside
  notes), merged by `private.ads_rules`; Custom = Medium defaults overwritten by the admin's `ads.custom`. Rewards are
  started by `ad_reward_start`, confirmed only by Google's signed callback (`admob-ssv`) and counted/granted in
  `private.ad_reward_apply`: XP (stored as bought XP, never usable for cash-prize entries: AdMob forbids cash-like
  rewards) and "a locked year for N minutes" (checked inside `private.year_open`, so papers stay locked on the server).
- **App (B2):** sticky banners wrap the whole app (`StickyAds`, hidden on the red-line screens through `AdsGate`);
  Ultra's random breaks come from a router observer (only on a new page, never inside a task); app-open ads when the
  student returns after the level's minutes; breaks at tests, before/after videos, after notes, novel chapters, AI
  quizzes, Study sections and every N AI answers (counted, shown at the next break, never over an answer); skippable
  "earn XP" videos after tests, videos, notes and AI chats; banners on Home, AI tutor, News (list + article), notes,
  results, review, XP, novels, bookmarks, settings and notifications; cards on Home, in News and inside notes.
- **Rule kept:** at most one full-screen ad at a time, 30 s after any other, the level's gap and daily cap; banners keep a
  6 px gap from the app's own buttons. Birth year is required in profile setup; students who joined before must answer a
  one-time pop-up.

## D-105 — Our own ads: brand campaigns (house ads), ads v2 part B3 (2026-11-07)
- **What:** admin → Money → Brand ads. A campaign has a brand, dates, places (banner, card, full-screen break as a
  picture or video, and video ads before / in the middle of / after our own video lessons), a share of the slots
  (the rest stays AdMob), a daily cap per student, a weight when brands overlap, a link and button text.
- **Never more ads:** a campaign only takes a share of slots the ads level already has. Video-lesson ads show only where
  the level has a break around videos (mid-roll only on videos over 2 minutes, once). Same red line, same gaps and daily
  break cap as AdMob. Not for Premium, not for students under 13.
- **Server:** `ad_campaigns`, `ad_campaign_stats` (views/clicks per day and place), `ad_campaign_seen` (per student per
  day; views over the cap are not counted, a click counts only after a counted view). `house_ads()`, `house_ad_log()`,
  `can_view_ad_file()` (the website signs `public/ads/…` files only while a running campaign uses them), and admin
  list/save/delete/report functions (audit-logged). Files are uploaded to the private R2 bucket (pictures ≤ 2 MB,
  MP4 videos ≤ 60 MB, made "fast start").
- **Report:** per campaign: views, clicks, click rate, students reached, per day and place, with a CSV for the brand.

## D-106 — How Study content opens: Free, Premium, watch N ads, or pay per item (ads v2 part B4, 2026-11-07)
- **Admin:** App control → How content opens: a rule for each kind (video solutions, video lessons, notes, novels,
  documents) and for past-question years; a year can have its own rule; a single study item can have its own rule in
  its edit page. Modes: as in Free vs Premium (unchanged behaviour), free for everyone, Premium only, free students
  watch N rewarded videos to open it for H hours (0 = for good), or pay for that one item (Paystack, at least ₦50,
  yours for good; Premium included unless "Premium students pay too").
- **Server:** `study_items.access/ad_count/ad_hours/price_kobo/pay_premium`, `year_access`, `content_purchases`,
  `payments.item_kind/item_ref`. `private.study_open(kind, is_free, id)` (the item's rule first) now guards the
  catalogue, the item, files, note pictures; `private.year_open` checks `year_override` first. Watching counts toward
  `ad_rewards` kind `item`/`year` (need and minutes from `reward_rule`). Paying: `content_pay_start` (service role,
  the server's price) → Paystack (`paystack` Edge Function v13, action `start_item`) → `finish_payment` adds the
  purchase. `content_offer` tells the app what a locked item or year offers.
- **App:** a locked item/year opens a "How to open it" sheet: watch (with progress), pay (all Paystack ways), or
  Premium; it opens the content once the server says so.
- **Known gap:** the admin Payments list shows no plan name for an item payment (the timeline note says what it was).

## D-107 — Ads limits, first-day welcome, custom exam, background updates (2026-11-08)
- **Watching ads opens only what the admin allows:** How content opens → per exam, no years / chosen years / all years
  can be opened by watching (default: none until the admin picks), plus daily caps (years per day, items per kind per
  day). The server refuses anything else (`watch_block`), and the break pop-up only offers allowed years
  (`ad_year_suggest`).
- **First-day welcome** (off by default): for N hours after joining, a lighter ads level and N extra free years per exam,
  silently (`welcome_settings` in `ads_config`, `welcome_extra_years` in `year_open`).
- **Custom exam:** subjects, questions per subject (default max 40, English 60), topics, open years only, time; mode
  `custom` on the server; the admin sets on/off, everyone or Premium, and the limits.
- **App:** sticky banner floats over the screen just above the tab bar (placement follows the router); CBT pictures
  download behind the normal loading circle; "No ads" is the first Premium benefit; new animated earn pop-up for XP and
  for opening a year; updates download through Android's download manager (keep going when the app is closed).

## D-108 — Supabase + Neon: live data on Supabase, growing history on Neon (2026-11-08)
- **Why:** Supabase was at 417 MB of 500 MB. 75% (312 MB) was the audit log: every edit saved two full copies of the
  row (144,000 question edits alone = 271 MB). Real app data was about 100 MB. Plan: `docs/plans/backend-neon.md`.
- **Audit log:** saves only the fields that changed; edits that change only `updated_at/updated_by` are skipped.
- **Supabase keeps** everything a student waits for: auth, profiles, payments, entitlements, XP, all content with its
  server-side locks, recent answers and chats, challenges, settings.
- **Neon (free, London `aws-eu-west-2`)**, one database per job:
  - `st-archive` (wandering-unit-72542883): audit log, payment events, AI call logs;
  - `st-history` (broad-night-56722155): test and challenge answers;
  - `st-ai` (summer-union-46331421): AI chat messages;
  - `st-analytics` (wild-truth-62109375): ad statistics and reward records.

  New projects are added only when one nears 1 GB (free plan: 1 GB each, 20 GB total), never spread thin, because
  each Neon project sleeps after 5 minutes.
- **Windows** (`app_settings.archive`): audit 30 days, test answers 14, AI chats 14, challenge answers 60, AI call
  logs 30, ad data 90, payment events 365. Rows still in use never move (unexpired ad unlocks, pending rewards; the
  payments themselves stay on Supabase).
- **Running totals:** `user_topic_stats` and `question_stats` (trigger on `attempt_answers`) feed weak topics and
  question difficulty, so they keep all history after raw answers move, and run faster.
- **Mover:** Edge Function `archive-mover`, nightly at 02:15, 02:25 and 02:35 Lagos (pg_cron, token in Vault), 20
  batches of 1,000 rows per call (the free Edge Function CPU limit stops a call at about 25 batches). `archive_take` →
  insert into Neon (duplicates skipped) → count in Neon → `archive_drop`. Nothing is deleted before Neon has every
  row. Log: `archive_runs`. Flagged AI messages stay on Supabase 90 days after the flag (admin AI safety page).
- **First move (2026-11-08):** 141,998 audit rows copied to `st-archive` (Neon count = rows deleted, no duplicates),
  then `VACUUM FULL audit_log`. Supabase **417 MB → 125 MB**; `st-archive` 307 MB of 1 GB.
- **Known effect:** admin challenge analytics for a challenge older than 60 days, and the AI tutor's "most missed"
  (last 7 days only) read Supabase only. Test review in the app reads the phone's own copy; `archive-read` can serve
  answers of tests older than 14 days.
- **Reading:** `archive-read` returns a student's own older AI chat messages or test answers. The app fetches older
  chat messages only for chats 13+ days old.
- **Secrets:** the Supabase connector's secret saving was paused, so the four Neon connection strings are in
  **Supabase Vault** (`NEON_*_URL`). Functions read them via `neon_url()` (service role only). Edge Function secrets
  with the same names, if added later, take priority. Never in git or the app.

## D-109 — Age rules: under 13 blocked, parent/guardian notice for 13–17 (2026-11-08)
- **Why:** NDPA 2023 s.31 and the lawyer's combined decisions (8 Nov 2026). Owner's flow: the parent gets a welcome
  notice and only acts to withdraw ("seeing the email is consent").
- **Under 13:** `set_birth_year` refuses the year (nothing stored); the app deletes the new account at once
  (`/api/account/delete`) and shows "SolutionTee CBT is for students aged 13 and older". The year is asked neutrally.
- **13–17:** setup step "Your parent or guardian" → `POST /api/account/guardian` (website) saves
  `guardian_consents` (email, child's birth year, `method = email_notice`, policy version, sha256 of a one-time link
  token, sent time) and sends the notice by Brevo. The link opens `/guardian/stop` → the parent ticks "I am the
  parent or guardian" and turns the account off: `withdrawn_at`, `profiles.paused_at`, Supabase Auth ban, audit row;
  cron `guardian-withdrawn-delete` deletes the account 30 days later.
- **Existing accounts:** the shell calls `age_status()` after the ban checks: unknown → asks the birth year once
  (even with ads off); 13–17 without a notice → `/guardian`; paused → `/account-paused`.
- **Risk noted:** the lawyer's text prefers a parent *confirmation*. `method` allows `email_confirm` later.

## D-110 — Cash prizes off (admin switch), XP not for sale, personalised ads only with an adult's "yes" (2026-11-08)
- **Cash:** `app_settings.cash_prizes` `{on:false, min_age:18}`. Triggers:
  - `challenges`: no prizes while off; a cash challenge must have `xp_fee = 0`;
  - `challenge_entries`: cash challenges are 18+ only;
  - `prize_claims`: refused while off, and 18+ only;
  - `referral_rewards`: no new cash rewards while off or under 18; claims refused while off.
  - Old closed cash challenges keep their history.
  - App: global `cashPrizesOn` hides prize amounts, the cash badge, My winnings and the referral cash meter. The
    onboarding slide now promises Premium days and XP.
- **XP:** `app_settings.xp.buy_on = false`; trigger on `payments` refuses XP packs; "Buy XP" hidden. Spending XP
  (Premium, freezes, events) stays.
- **Ads:** `ads_config` already allows personalised ads only for 18+. Now `profiles.ads_consent` (off by default,
  `set_ads_consent`, adults only) must also be on: *Settings → Personalised ads*. NDPA s.26: consent must be a clear
  yes.

## D-111 — Exam-body logos behind an admin switch (2026-11-08)
- `app_settings.exam_logos.on` (default off). `ExamLogo` shows `ExamBadge` (exam colour, graduation-cap icon, the
  exam name in plain text) until JAMB, WAEC and NECO give written permission. Plain-text exam names stay (nominative
  use, with the disclaimer). This replaces CLAUDE.md §5 "every card shows the body's logo" while the switch is off.

## D-112 — Google Play preview build on /download; Play payments plan (2026-11-08)
- The workflow also builds `--flavor play` (no Paystack, no self-update, no install permission). It is published with
  step `publish-play` to `apk/play.json`, which is `/download?channel=play`. It never touches `apk/latest.json`, so
  the direct app's updater never offers it.
- Payments on Play follow Google's rules: Google Play Billing in the app, and no link to the website (Nigeria is not
  in Google's external-link programmes). Website payments and voucher PINs happen outside the app. Plan and owner
  decisions: `docs/plans/play-launch.md`.

## D-113 — Payment settings: Google Play / website link / both, processing fees (admin, 2026-11-08)
- Owner's choice: the admin decides which ways the Google Play app offers, and whether processing fees are added.
- `app_settings.payments` (public) `{play:{google, website}, website_url, fees:{paystack:{on,pct,flat,flat_from,cap}, google:{on,pct}}}`.
  Admin page: **Money → Payment settings**.
- **Play app:** Google Play Billing, a "Pay on our website" button (opens `website_url?plan=…&email=…&from=app` in the
  browser), or both; never neither. Admin sees a warning: outside Google's billing-choice countries a link to another
  way to pay breaks Google Play's payments policy and can get updates rejected. It can be turned off at any time without an
  app update.
- **Paystack fee:** `private.paystack_fee` grosses the price up so the business still receives the price after Paystack's cut
  (default 1.5% + ₦100 from ₦2,500, cap ₦2,000), rounded up to a whole naira. It is applied in `private.price` (plans) and
  `content_pay_start` (items), stored in `payments.fee_kobo`, and shown as its own line before paying (app checkout,
  item sheet, website).
- **Google fee:** Google charges the Play Console price, so each plan may have a second product `plans.play_product_id_fee`.
  With the Google fee on, the app sells that product; `pay_play_confirm` accepts either product. The admin page shows the
  price to set in Play Console.

## D-114 — Public website and website payments (2026-11-08)
- Same Next.js app: `/site` (landing) and `/pay` (payments). The proxy serves `/site` at `/` on any `cbt.*` host and sends
  `/admin` on that host to admin.solutiontee.com.
- Landing: Motion (Framer Motion) scroll reveals, word-by-word hero, a phone that answers a practice question in a loop
  (our own question), count-ups, an AI chat demo, a scroll-drawn steps line, live plans, prices and fee from the
  database (cached for an hour), FAQ, footer with the legal business name and disclaimer. Follows reduce-motion.
  The Google Play button reads `app_settings.site.play_url` (set in Payment settings; "coming soon" until then).
  The APK button points at `/download/apk`.
- `/pay`: log-in code by email (`/api/web/login-code` → a Supabase **recovery** code, never creates an account, same answer for
  unknown emails, Brevo template) → `verifyOtp(type: recovery)` in the browser → plans + `quote_price` (discount, fee)
  → Paystack Edge Function `start` with `source: web, method: page` (every Paystack method) → Paystack.
- `/pay/done`: shows the result by payment reference (status, plan name, Premium end date only), checking every 4 s.

## D-115 — Website: 3D phone feature tour, safer payments, cancel detection, app-to-web login (2026-11-08)
- **Landing:** a CSS 3D phone (`Phone3D`: frame, buttons, camera island, moving glass reflection, pointer tilt, float) shows
  live re-creations of the real app screens at the app's 390×844 design size: CBT exam (answer, Next, question map), result
  (score ring, subject bars, topics), AI tutor (photo question, step-by-step answer, follow-up chips), Study hub (tiles →
  video solution playing), leaderboard (podium, ranks, "You" bar). Hero: two phones + floating chips + parallax. Feature
  tour: five steps, each with three "how it works" points; on large screens a sticky phone switches screens as each step
  scrolls past, on phones each step has its own phone. Subject ribbon, reduce-motion respected throughout.
- **App → website without logging in again:** `POST /api/web/handoff` (app token) → 256-bit one-time code (sha256 stored in
  `web_handoffs`, 2 minutes, 10 an hour) → the app opens `/pay?h=…` → `POST /api/web/handoff/redeem` marks it used in
  the same statement that checks it, then returns a magic-link token hash → the browser `verifyOtp` signs in (any older
  website session is signed out first) and the code is removed from the address bar.
- **Cancel detection:** the website sends `callback` (/pay/done) and `cancel` (/pay) with each payment; the Paystack Edge
  Function (v18) accepts only our own pages and makes Paystack's Cancel button return to `/pay?cancelled=<ref>`. /pay
  then asks the server (`cancel`, which checks Paystack first) and shows "Payment cancelled, nothing was charged". The
  back button and pages restored from browser memory are handled too (pending reference in sessionStorage, `pageshow`).
- **Security:** CSP (no third-party scripts, `frame-ancestors 'none'`, `form-action 'self'`), HSTS, nosniff, COOP,
  Permissions-Policy; payment pages `Referrer-Policy: no-referrer` and `no-store`; the browser only follows a
  `https://checkout.paystack.com/` address; the website logs out after 15 minutes idle and right after a successful payment.
  Unchanged: price only from the server, webhook HMAC + verify, amount check, idempotent grants.

## D-116 — Back to the app after paying on the website (2026-11-08)
- The app registers `solutiontee://app/paid?ref=…&plan=…` (intent filter, VIEW + BROWSABLE). On Android, Chrome opens it
  with an `intent://…#Intent;scheme=solutiontee;package=com.solutiontee.cbt;end` link from /pay/done.
- When the payment was started from the app (`from=app`, kept in sessionStorage), /pay/done opens the app by itself 0.9 s
  after the server confirms success, and also shows a "Back to the app" button. The website signs out at the same time.
- The app never trusts the link: `PaidReturnScreen` checks the reference format, asks the server (`pay check`) and only
  then shows the normal Premium success screen; it retries every 5 seconds for up to 2 minutes.

## D-117 — Up to 3 discount codes per payment; codes in the Google Play app (2026-11-08)
- Codes travel comma-separated in the existing `p_code` field, so old app versions keep working with one code.
  `private.price` applies them one after another (each on the price left after the earlier ones), refuses a 4th
  (`too_many_codes`), keeps at least ₦100 to pay and returns each code's share; `payments.extra_code_ids` and
  `code_discounts` record them; `finish_payment` counts every code as used.
- Google Play cannot take our prices, so in the Play app "Have a code?" (admin feature flag `codes_in_play_build`) redeems
  free-days codes directly. A money-off code shows "Pay on the website with CODE" when website pay is switched on, and
  otherwise explains it cannot be used with Google Play. For Play review, keep the website button and this switch off
  (outside-payment steering rule).

## D-118 — Legal pages, data retention, Play bundle and store kit (2026-11-08)
- Privacy Policy, Terms and Refund Policy live as Markdown in `apps/web/content/legal/` and render at /privacy, /terms,
  /refunds (lawyer-approved text). /delete-account deletes an account from the website (email code → type DELETE), as
  Google Play requires a web deletion link.
- Retention: AI tutor messages and per-student rewarded-ad records are kept 12 months (cron `ai-retention` on Supabase;
  `archive-mover` v8 trims Neon).
- The GitHub workflow also builds the Play `.aab` (`aab` + `publish-aab` jobs); it is offered at /download/aab for
  admins, signed with the upload key, for Google Play App Signing.
- `/store-kit/<shot>` (no-index) draws the store images at their real sizes from the same screens as the website;
  the finished PNGs and every Play Console answer are in `docs/play-console/`. `public/app-ads.txt` lists the AdMob
  publisher ID.

## D-119 — Lawyer's list: Google consent message (EEA/UK), 24-month inactivity, clean-up of deleted accounts (2026-11-08)
- **Consent (UMP):** before any ad loads, the app asks Google's User Messaging Platform. In the EEA, UK and Switzerland
  Google shows its consent message (made in AdMob → Privacy & messaging → European regulations); everywhere else it
  answers "not required" and nothing shows. Under-18s are tagged as under the age of consent. No ads load until Google
  says ads may be requested. Settings shows "Ad privacy choices" only where Google requires it. Our own "Personalised ads"
  switch (adults only, NDPA consent) is unchanged.
- **AI question photos** are never stored (sent to the AI and dropped; only `has_image` is kept), so the 12-month rule is
  met by the existing message retention (D-118).
- **24 months without activity:** activity = sign-in, token refresh, push token seen on app open, or sign-up. At 23
  months the student gets an email ("log in before <date>"); 30+ days later, still inactive and past 24 months with no
  running Premium, the account is deleted. Staff accounts (the owner's included) are never selected. Website job
  `/api/cron/accounts`, nightly Supabase cron `accounts-nightly` (02:20 UTC), at most 100 notices a night (Brevo free plan).
- **Every deleted account** (app, website, parent turn-off, inactivity) is queued by a trigger on `auth.users`
  (`private.deleted_users`, id only): the website job removes its photos in R2 (`a/<id>/`), and `archive-mover` (v9)
  removes its archived AI messages, answers and ad records in Neon. Payment records keep their amounts with the user
  link cleared (`on delete set null`), for the 6-year tax rule.

## D-120 — "Past Questions" and "SolutionTee Mock Questions" (2026-11-08)
- Lawyer: label the two kinds clearly so that, if a licence is refused, past questions can be switched off and the app
  keeps working. `questions.source` is `past` (default; all 33,444 published bank questions today) or `mock`. Challenge
  and JAMB mock questions are "mock" when written by us (2,980 today) and otherwise take the source of the bank question
  they were copied from (`question_sources`).
- App labels: every question in the CBT/test and JAMB mock screen, every challenge question, the question of the day
  and AI quizzes show "Past Question" (blue) or "SolutionTee Mock" (gold).
- Admin: "Kind of question" on each question, an optional `source` CSV column (past/mock), counts on the Question bank
  page, and a super-admin "Hide all past questions" switch (published → review, remembered by `paused_by_switch`, so
  "Show past questions again" restores exactly those). Tested both ways in a rolled-back transaction.
- Not covered by the switch: past questions already copied into challenges; replace those challenges' questions if the
  switch is ever used.

## D-121 — Cash prizes for students aged 13 to 17, with a parent email after each win (2026-11-08)
- Lawyer: allowed if the parent is emailed after the win. New admin switch *Flags & settings → Legal switches →
  Students aged 13 to 17 can win cash too* (`app_settings.cash_prizes.teens`, off by default; works only while cash
  prizes are on). `private.cash_min_age()` is then 13 instead of 18, so entry, claims and invite cash follow.
- A cash win by an under-18 (challenge prize set on `challenge_entries.prize`, or a cash `referral_rewards` row) queues
  `private.guardian_prize_notices`. The website job (`/api/cron/accounts`, every 10 minutes via cron
  `minor-win-notices`, only when something is queued) emails the parent or guardian from `guardian_consents`.
  The email says what was won, that entry was free, that it is paid to a parent's or guardian's account, and that they
  can reply within 7 days to stop it.
- Claims by under-18s are refused until that email has gone out (`prize_claim_rules`, `referral_minor_claim`); without
  a parent email on file the student is asked to contact support. The claim form already takes the guardian's name,
  phone and bank account. Winners & payouts shows "Parents told" with the status of each email.
- Tested in a rolled-back transaction: a 15-year-old's win queued the email, the claim was refused, then allowed after
  the email was marked sent.

## D-122 — Website CMS, invite and challenge sections, store images 6 and 7, legal text that follows the cash switch (2026-11-08)
- **Admin → Website** edits cbt.solutiontee.com: section on/off switches (exams strip, subjects ribbon, feature tour,
  "and there's more", **Invite friends and earn**, **Practise in challenges and win**, three steps, prices, download,
  FAQ), announcement bar, hero texts, the two earn sections (title, text, points), steps, download box, FAQ list and
  footer line. Stored in `app_settings.site_cms`, cleaned by `mergeCms` both when saving and when reading (defaults
  fill anything missing). Saving refreshes the site at once (`updateTag("site")`).
- Texts can use `{rewards}` (now "Premium days and XP"; "cash prizes, Premium days and XP" while cash is on),
  `{pct}`, `{maxPct}`, `{xp}`, `{finishXp}`, `{cashNaira}`, `{cashEvery}`, `{questions}`, `{firstYear}`, `{lastYear}`,
  filled from the live settings, so a text never promises cash while cash is off.
- New phone screens `InviteScreen` and `ChallengeScreen` (same style as the others; cash shown only when on) are used on
  the website and for store images `/store-kit/6`, `/7` (Premium days + XP, for Play now) and `6-cash`, `7-cash` (for
  later). PNGs in `docs/play-console/graphics/`.
- **Privacy Policy and Terms** carry `<!-- if cash=off|adults|teens|on -->` paragraphs; the pages show only the ones that
  match the switches (`cashState`, refreshed when an admin flips a cash switch). Off: cash is switched off. 18+: who can
  win, prize payout data. 13+: parents are emailed after a win, the prize is paid to the parent's or guardian's account,
  and they can stop it.
- The app's own Privacy/Terms summaries lost the "Draft, to be reviewed by a lawyer" banner and now link to the full
  current text on the website.

## D-123 — Professional email design (2026-11-08, revised the same day after the owner's review)
- First version (navy gradient banner, badges, emoji) was "too AI generic". Revised to a calm company letter: white card
  with a thin navy top rule, the real brand mark (`/brand/solutiontee-mark-transparent.png` on cbt.solutiontee.com, or
  EMAIL_LOGO_URL) and name, plain heading, short paragraphs, a plain code box, thin left-rule notes, numbered steps, label
  and value rows for amounts and dates, one navy button (red outline for "turn off"), "Best wishes, The SolutionTee
  team", and a quiet footer (why you got it, help email, WhatsApp, website, Privacy, Terms, company line, disclaimer).
  No badges or pills, no emoji in headings or subjects, no gradients.
- Covers all 11 emails the website sends. Table layout with inline styles (Gmail, Outlook, Yahoo, phone mail apps),
  hidden preview line, 600 px on computers, full width under 620 px with smaller heading and code. Checked at 360 px
  and 680 px for 10 templates: no sideways scrolling, nothing cut off.
- Admin → Emails previews all of them; "Send me a test email" sends the new design.

## D-124 — Full analytics dashboard (2026-11-08)
- `public.admin_analytics(p_days)` (staff only; Lagos days; students = non-staff accounts) returns everything the
  dashboard shows in one call. "Active" = a test, an AI question (`ai_usage`, not archived), the question of the day,
  a challenge, a study item or the app opened (push token seen). Revenue = successful Paystack + Google Play payments
  (codes counted separately). Retention: next day (joined 2–31 days ago), week 2 (active 7–13 days after joining),
  month (30–36 days after).
- Admin → Dashboard: period 7 / 30 / 90 days and tabs:
  - **Overview:** students, active (vs previous period), revenue, Premium now, active today/week/month, tests, AI
    questions, new students; daily trends for active, new, tests and revenue.
  - **Students:** retention, age groups, exams, target score, course area, top subject combinations, JAMB subjects,
    states, app versions.
  - **Learning:** tests finished, average full mock score, question of the day, AI tutor, study items, XP; kinds of test
    with average %, subjects practised with accuracy, tests by hour (Lagos time), active by weekday.
  - **Challenges:** held/live/coming, entries, players, finished fairly, disqualified, cash paid, claims waiting,
    recent challenges table.
  - **Payments** (admins only): revenue, paying students, average per payer, paid vs started, revenue per day, how
    payments ended, revenue by plan, Paystack vs Google Play vs codes, Paystack methods, discount codes, ads shown,
    clicks and click rate.
- **Course:** the app does not ask for an intended course, so "course area" is worked out from the JAMB subject
  combination (Medicine and health; Engineering and physical sciences; Life and agricultural; Computing and maths;
  Business; Arts, law and humanities; Social sciences). Asking students for their course is the owner's decision.
- Charts follow the dataviz rules: plain SVG/HTML, one series per trend in brand blue (#2563B3 / #5B8DEF dark),
  validated categorical slots for splits, 2px lines, bars ≤24px with 4px ends, hover tooltips, values in text, readable
  on phones (2 tiles per row, HTML date labels). Checked at 1280 px, 390 px and in dark mode with sample data; the SQL
  was checked against live data.

## D-125 — admin.solutiontee.com is only for staff; students and parents use cbt.solutiontee.com (2026-11-08)
- Parent "turn off" links, delete-account, pay, privacy, terms, refunds and the store images live on cbt.solutiontee.com.
  On admin.solutiontee.com these paths redirect (308) to cbt, so old links in emails keep working; "/" goes to /admin.
- `/download` (the team's page with test and Google Play builds) and `/download/aab` need a signed-in staff member with
  2-step login; `/download/apk?channel=test|play` too. The students' app file `/download/apk` stays public and
  `/api/app/latest` now points downloads at cbt.solutiontee.com (old apps asking the admin address still work).
- New app builds call the API on cbt.solutiontee.com; the invite message links to cbt.solutiontee.com.
- Admin hardening: `X-Robots-Tag: noindex` on every admin page, robots.txt disallows admin/api/download/one-time pages,
  admin pages are never cached, never framed, send no referrer to other sites (on top of login + 2-step + RLS).

## D-126 — Deleting an account: reason, email code, goodbye email (2026-11-08)
- App: Settings → Delete account → what is removed + "Why are you leaving?" (9 reasons + optional note) → "Email me a
  code" (`/api/account/delete/start`: 6-digit code, 10 minutes, one a minute, five an hour, only its hash stored) →
  type the code → deleted → "Your account has been deleted" email.
- Website /delete-account: email code (sign-in) → reason → type DELETE; the server accepts it only if that email
  sign-in was less than 15 minutes ago. Older app versions without a code are told to update or use the website.
- Reasons go to `account_deletion_reasons` with no user id or email (reason, note, app/web, days as a member, had
  Premium), readable by staff only.

## D-127 — Emails for important moments (2026-11-08)
- `private.email_outbox`, filled by database triggers, sent by the website job every 5 minutes (only when something is
  waiting): account suspended (with reason and how to appeal), account open again, second account paused on a phone
  (what to do, family phones), allowed on a shared phone, ban appeal decided, payment receipt (plan, amount, fee,
  reference, Premium until), prize paid, parent turned the account off. The same kind is not repeated within 10
  minutes; an accepted appeal replaces the "open again" email. Sending stops at 220 emails a day so log-in codes
  always get through (Brevo free plan: 300). Admin → Emails shows waiting/failed/sent and previews every email.

## D-128 — Fraud page fixed and redesigned (2026-11-08)
- Bug: a phone is known by two ids (phone-wide and Android ID). "Allow" changed only one, so the student stayed paused
  and admins had to allow twice (the page hid the second card). `admin_device_allow` now updates every id of the phone;
  accounts already half-allowed were fixed; `admin_fraud` returns each phone once with all its ids and a real
  "paused" status per account. Tested: one Allow → the account works.
- New page: a short "how it works", four totals, tabs To do (appeals + paused second accounts with Allow / Ban),
  Shared phones (plain statuses: first on this phone / allowed by an admin / paused / banned), Banned (accounts, phones,
  decided appeals) and Activity (events + phones with warning signs). Ban reasons are typed in a dialog with ready
  reasons instead of browser pop-ups. Every decision emails the student.

## D-129 — Payments are confirmed without waiting for the webhook or the student's login (2026-11-11)
- Cause of "paid but still says not paid": the Paystack live webhook was not set (owner fixed it), and the result page
  only read our database. Now three independent ways confirm a payment, all through Paystack's own verify answer
  (amount + currency checked by `pay_paystack_result`, idempotent): (1) the webhook; (2) the result page and the app
  ask the payment server with the reference alone (`paystack` action `status`, no login, 60 checks per reference and
  150 per IP per 10 minutes, only the status comes back); (3) a scheduler (`paystack-sweep`, every 2 minutes, only
  when something is waiting) checks every unfinished Paystack payment of the last 2 days.
- Cause of "Please log in again" in the app after paying on the website: the website's Log out button, its 15-minute
  idle log-out and two admin pages used Supabase's default sign-out, which is global (it ends every session of the
  account, the app included). All sign-outs on the website are now `scope: "local"` (this browser only). The app also
  renews an expired login once and, if that fails, asks by reference, so a paid student is never told to log in.
- "Not paid yet" answers from repeated checks are no longer written to the payment log (it filled with copies).
- /pay shows "You are already on Premium" (plan, end date, days left, Open the app, Add more time) to a logged-in
  Premium student; extra time starts after the current end date. `my_plan()` now also returns the plan name.
- New result page: a receipt (plan, Premium until, amount, reference with copy), one main action (Open the app),
  a three-step waiting state, no emoji.

## D-130 — Dedicated virtual accounts: not now (2026-11-11)
- With the registered business, Paystack offers Dedicated Virtual Accounts (one permanent account number per student).
  Not needed: "Bank transfer" already gives a fresh account number for each payment and confirms it automatically
  (Paystack Pay with Transfer), and a DVA needs each student's full name and phone number, and in Nigeria often a BVN
  check, which is more personal data than we want from teenagers. Revisit if students ask to top up a wallet by
  transfer without opening the app.

## D-131 — Exam logos on the website follow the app switch; the landing page made smooth (2026-11-11)
- Admin → Settings → "Show the JAMB, WAEC and NECO logos" now changes the app and the website together. On: the exam
  strip shows each body's own logo file from /brand/exam-bodies (never redrawn); off: our text badges. The switch
  refreshes the website at once (cache tag "site"); the cash prize switch now does too.
- Landing page lag: animated blur glows, text revealed through a blur filter, endless JavaScript-driven floats and
  marquee, a see-through blurred menu over scrolling content, scroll parallax and finger-triggered 3D tilt on phones,
  and demo phones that kept animating off screen. Now: gradient glows (same look, no blur), CSS loops (run on the
  graphics chip), parallax and tilt only on computers with a mouse, a solid menu on phones, demo phones paused off
  screen. Measured on an emulated phone with the CPU slowed 4×, scrolling the whole page: 47 → 58 frames a second,
  janky frames 4% → 0%, blocking work 441 ms → 0 ms; idle 41 → 60 frames a second.

## D-132 — Who pays the Paystack fee, matched with the Paystack dashboard (2026-11-11)
- Admin → Payment settings → "Who pays Paystack’s fee?": SolutionTee pays it (Paystack: Charge me) · students pay it,
  added by SolutionTee (our own line before paying; Paystack: Charge me) · students pay it, added by Paystack
  (Paystack: Charge my customers; we only say "+ Paystack fee at checkout"). Our own fee is never added when Paystack
  adds its fee (no double fee). `fees.paystack.mode`; `on` stays for older apps (true only for "ours").
- The server accepts both ways safely: Paystack's `requested_amount` must equal our price exactly and the charged
  `amount` may only be equal or higher (the difference is logged as the student's Paystack fee). A smaller amount or a
  smaller requested amount goes to review. Tested in a rolled-back transaction (4 cases).
- The settings page shows what Paystack did on the latest payment and warns when it does not match the choice.
- Transfer/USSD show Paystack's own figure to send when it is higher than our price (its fee added).

## D-133 — Paystack Test / Live switch and keys in the admin (2026-11-11)
- The four keys (live/test, secret/public) are typed by a super admin with 2-step login in admin → Payment settings and
  saved in Supabase Vault (`admin_set_paystack_key`, shape checked, audit-logged masked). Never shown again, never in
  the app, a browser or chat. The payment server reads them with `paystack_config()` (service role only), cached 30 s.
- `paystack_env.mode` (Test/Live, super admin only). Each payment remembers its mode (`payments.live`) and is always
  verified, refunded and webhook-checked with that mode's key; the webhook accepts either key's signature.
- Test mode: only staff can start a payment (students: "payments are paused for a few minutes"). Test payments are
  marked Test in admin → Payments and left out of revenue (analytics, payments totals, content sales).
- Found: the only key on the server was a Paystack TEST key, so every Paystack payment so far was a test payment (no
  real money; anyone could have got Premium with Paystack's public test cards). All 69 earlier Paystack payments are
  now marked Test, and test mode is staff-only from now on. Until live keys are saved and Live is chosen, students
  cannot pay on the website or in the direct app.

## D-134 — App builds use far fewer GitHub Actions minutes (2026-11-11)
- GitHub's free plan has 2,000 minutes a month; each app change used ~82 (phone app 20, emulator copy 23, Google Play
  preview 18, Play bundle 18), so the minutes ran out on 11 Nov.
- Now: every push that changes the app runs only a ~3-minute check (analyzer + tests). A new version (build, emulator
  check, /download) only when the commit message has [release] or the workflow is run by hand. The emulator copy is
  built right after the phone app on the same machine (warm Gradle) and the emulator job only opens it. The Google
  Play preview APK and the .aab only with [play] or "Also build the Google Play versions" when run by hand. Gradle
  downloads are cached. Expected: ~3 minutes per change, ~30 per release, ~65 with the Play files.

## D-135 — Exam countdown (2026-11-11)
- Admin → Motivation → Exam countdown: a date for each exam body (UTME, WASSCE, SSCE), "Show the countdown" and
  "Full-screen countdown once a day" (`app_settings.exam_countdown`, public). No date = no countdown for that exam.
- App: each student counts down to the nearest future date among the exams they chose at setup (else the nearest of
  any exam). A chip under Home's first card ("143 days to your UTME · 24 April 2027"); on the first open of each day,
  before the daily claim, a full-screen countdown (exam logo, days counting up, today's goal ring, streak, today's
  motivation line, "Start today's practice", "Later"). Fits small phones (scrolls if needed), still with reduce motion.
- "Resume any test" (U5) was already in the app: every test mode is saved on the phone and continues from Home.

## D-136 — One search for the whole app, and navigation polish (2026-11-11)
- Search (magnifying glass on Home and Study, `/search`): pages of the app ("streak", "premium", "delete account"),
  past question papers by subject and year ("Physics 2015", with the lock shown), subjects, topics (opens a topic drill
  with the subject and topic already picked), and lessons, notes, novels and documents. Every word must match, in any
  order. It uses data the app already caches, so it also works offline. Careers join it when they are added.
- Back button on a tab: other tabs go back to Home; on Home, "Press back again to leave" (2 seconds).
- Tapping the tab you are on: back to that tab's first page and smoothly to the top.
- Long-press on the app icon: Continue my test · Quick practice · Ask the AI tutor · Search (`quick_actions`).

## D-137 — Careers and JAMB subject combinations (2026-11-11)
- New `careers` table (public read, editors manage it, audit-logged): name, group, university course and years, what
  the job is, the three JAMB subjects besides English (subject codes), a note on alternatives, O'level credits, after
  school (internship, NYSC, licence), skills, good universities and a rough pay guide. `profiles.career_id` (the
  student may change only that column; deleting a career clears it).
- 44 sample careers across Health, Engineering and Tech, Science and Agriculture, Business, Law and Social Sciences,
  Arts and Education. They are a starting point, not checked facts: each row has a **checked** flag and Admin →
  Careers shows "Not checked" until the owner ticks it after checking this year's JAMB brochure (IBASS). The app always
  says to confirm the combination in the brochure and that pay is a rough guide.
- App: Study card (my career and its combination, or "Careers and subject combinations"); Careers list (my career
  first, search, group chips); career page (what the job is, JAMB subjects, path: secondary → JAMB → university → after
  school, skills, where to study, pay) with "This is my dream career", then "Use these as my JAMB subjects" when they
  differ; "Not sure? Pick by the career you want" on setup's JAMB subjects step fills in the subjects (only ones the
  JAMB exam offers; the student picks any missing one); Settings → My dream career; careers in app search.
- Kept optional (no extra setup step), so sign-up stays as short as before.

## D-138 — More exams, added by the admin (2026-11-11)
- Admin → Exams & years → **Add exam**: short name (2 to 12 letters/numbers, e.g. BECE), full name and a short line.
  A new exam starts **hidden** and the database gives it a rules row and its own Free vs Premium rule: Premium all
  years, free **locked** (0) until the admin opens some. Without that rule the server would open it for nobody.
- **Exam details** panel for each exam: name, short line, order, Show in the app (JAMB cannot be hidden) and, for
  added exams only, an optional logo upload (PNG/WebP, 500 KB, kept in the private bucket under `public/exams/`,
  signed for students only while an exam shown in the app uses it). JAMB, WAEC and NECO keep the bundled
  /brand/exam-bodies files and the exam-logos switch. An uploaded logo shows whenever it is set, so the admin should
  upload only logos they have permission to use; without one the app shows our badge with the short name.
- Free vs Premium lists a "years (tests)" rule for every exam, not only the three.
- App: Test tab → Other exams lists every shown exam (2 per row, same lock / free years / no papers labels); setup's
  "Which exams are you writing?" lists them with their short line; the test setup title and the paywall heading work
  for any exam. Subjects, rules, years and questions for a new exam use the existing tools (subjects in this exam,
  CSV import, publish years).
- Not in this step: new subjects (the 18 subjects stay; add more when an exam needs them) and the website's landing
  page, which still shows the three main exams.

## D-139 — Save videos and PDFs for offline (2026-11-11)
- A download button on every video (solutions and topic lessons) and PDF document. Videos with an HD copy ask
  Standard (360p) or HD (720p) with the size; on mobile data the app shows the size and asks first. Progress shows in
  the button (tap to stop) and on Downloads; the student can keep studying while it saves.
- Files are fetched through the same plan-checked link used to stream them (the website decides, D-045), and kept in
  the app's own private folder (other apps cannot read them). Saved videos play from the file and saved PDFs open from
  the file: no data, and the video's stall/quality switching does not apply.
- Premium files: each time a saved file is opened online, the website is asked again; if the plan no longer opens it,
  the file is removed and the Premium screen shows. Offline, a Premium file opens for **30 days** after the last check
  ("connect once to open" after that). Free items always open. Log out removes every saved file.
- Downloads (Premium by default, the admin's `offline` rule) now lists Videos and PDFs (size, remove, open) above
  Past papers, with the total space used.
- Not encrypted: Android keeps app files private, and encrypting large videos would be slow on 3 GB phones. Revisit if
  copying from rooted phones becomes a problem.

## D-140 — Google Play versions with every release (2026-11-11)
- Owner: "always build play version". Every new version (`[release]` in the commit message, or run by hand) now also
  builds the Google Play preview APK (/download?channel=play) and the .aab. `[play]` on its own still works. The
  quick check on other pushes is unchanged. Costs more GitHub minutes per release; fine while the repository is public.

## D-141 — News v2: likes, comments, saved posts, sharing (2026-11-11)
- Plan for all of B: docs/plans/engagement.md. The push per post (with its switch) and reading time already existed.
- Likes and saves are each student's own rows; counts come from `news_meta()`. Comments: 2–500 letters, no links
  (blocked on the server), 5 a minute and 30 a day, banned students cannot comment or like, one Comments switch per
  post (on by default). Other students see only the first name and initial (`news_comments_list()`); nobody can
  read the comments table directly except their own rows and staff.
- Reports (rude, spam, wrong, other), one per student per comment; 3 reports hide a comment until staff look.
  Admin → News → Comments: Reported / Hidden / All; Keep (shows it and stops new reports hiding it again), Hide,
  Delete. The News list shows likes, comments and how many reports wait.
- App: like (heart pops, haptic), comments count (jumps to comments), Save, Share (WhatsApp, copy if WhatsApp is not
  there; the link points to cbt.solutiontee.com because the website has no news pages yet). News list: group chips
  and Saved, likes and comments under each post, pull to refresh. Related news: same group first.

## D-142 — Badges v2: admin badges with four levels and rewards (2026-11-11)
- `badges` (name, how to win, icon, what it counts, bronze/silver/gold/diamond targets, XP and free Premium days per
  level) and `user_badges` (one row per level reached). 30 metrics are counted on the server from the student's own
  records (tests, correct answers, best JAMB mock, streak, night/early/weekend tests, lessons, videos, notes, novels, AI
  chats, challenges and top-3 finishes, invites, question of the day, XP, news comments and likes, ...).
- `badges_check()` records new levels and pays each level once (XP outside the daily cap; Premium days via the
  normal grant, source "prize"; nothing for banned students). The app calls it when it opens and after each test.
- Fair start: the first check of an account made before badges v2 started records what it had already reached with
  no reward and no celebration, so old accounts do not get a burst of XP. Every level reached after that pays.
- 30 sample badges replace the 8 fixed ones (`my_badges` stays for older app versions). Sample rewards: 20/50/100/250
  XP, and 7 Premium days at diamond for the hardest badges; the owner sets real amounts in Admin → Badges.
- Cash rewards for badges are not offered while cash prizes wait for approval (D-110).
- App: Me shows the 8 badges with the most progress (level colour, ring to the next level) and "See all"; a sheet per
  badge lists the levels and rewards; a full-screen "Badge won" moment (medal pop, confetti, reward; reduce motion
  respected) shows each new level once.

## D-143 — Leaderboards v2: week, month, year, all time, Challenges board, top-10 rewards (2026-11-11)
- `leaderboard_for` takes `p_period` (week | month | year | all | season) and `p_offset` (0 now, 1 the one before);
  without them it behaves as before (season), so older app versions keep working. Same fair rules for every period:
  held mocks, reviews, minimum mocks, hidden, banned and staff students. Weeks run Monday to Sunday, Lagos time.
- Challenges board (`leaderboard_challenges`): points = the scores of every finished challenge in the period, added
  up; disqualified runs do not count.
- Rewards (`app_settings.leaderboard.rewards`, admin → Leaderboard): on/off, which boards (JAMB, Challenges), XP and
  free Premium days for places 1–10 each week and month. A daily job pays the last closed week/month two days after
  it ends (time to review held mocks), once per place (`lb_winners`), and sends the winner a notification. Starts
  **off** with sample XP; the owner sets the real amounts. No cash while cash prizes wait for approval (D-110).
- App: Week · Month · Year · All time · Season tabs, This/Last week or month, a Challenges board next to the exams,
  and a Winners card with the last closed period's top 3 and what they won. Saving the leaderboard settings now keeps
  the rewards (it used to replace the whole setting).

## D-144 — Fair-play tracking on leaderboard exams (2026-11-11)
- The app keeps, per test, the times it left the app (a glance under 1.5 s does not count), the time away and
  screenshot attempts, and sends them with the test (`fair`). Times per question already arrive with the answers.
- The server works out a risk score (0–100, `attempts.risk`) with the reasons in plain words: share of answers under
  3 s (up to 60), a very short median time with 80%+ right (20), each time away (6, up to 10 times) plus the time
  away (up to 20), each screenshot attempt (15, up to 5).
- A leaderboard run whose risk reaches the admin's level (Leaderboard → "Fair play: hold a run with a risk of at
  least", default 50, 0 = off) is held off every board (week, month, year, all time, season) and listed under
  "Latest tests that can count" with the reasons, for Let it count / Keep off. The existing "too fast" reason comes
  first when both apply. Practice and results are never blocked or changed. JAMB mock challenges keep their own
  leave rules.
- Note: on WAEC/NECO boards, setting "Too fast" to 0 also skips the fair-play hold there (the check order of that
  rule); keep it above 0 in production.

## D-145 — Automatic safety bans and admin alert emails (2026-11-11)
- `risk_events` (one row per flag, never twice): shared phone 20, 3+ accounts on a phone 30, second account tried 15,
  phone blocked 40, unfair test (fair-play risk 70+, not cleared by staff) 15, challenge disqualification 20, blocked
  invite 15, refund after Premium was given 25, news comment hidden 5, AI rule broken 10. Points are set in admin and
  fade after 90 days. Staff can clear a student's points (kept for the record).
- Hourly job (`auto_safety_job`): at the warning level (default 40) a warning email (`safety_warning`, plain list of
  reasons, reply to contest); at the ban level (default 80), only if warned at least 24 hours earlier and with at
  least **two kinds** of flags, the account is suspended with the reason "Automatic safety check: …". The normal
  ban email and in-app appeal follow. Staff are never warned or banned. **Off** until the owner switches it on in
  Admin → Safety checks ("Check now" counts points without warning or banning while it is off).
- Daily admin alert email (`admin_alert`) to super admins and admins at 07:05 Lagos, only when something needs a look:
  automatic bans and warnings, second accounts tried, stuck pending payments, payouts and appeals waiting, reported
  comments. Starts **off** because the website must be deployed first (the email template lives there).
- Tested in rolled-back transactions on real data: first run warns only (10 test accounts), a later run bans only
  warned accounts over the level with two kinds of flags (3), no staff, no single-kind bans.

## D-146 — Admin password reset works with 2-step login (2026-11-11)
- Supabase changes a password only at assurance level 2 when an authenticator is set up ("AAL2 session is required").
  The admin reset now goes: email code → (if the account has an authenticator) the 6-digit authenticator code →
  the new password is saved → straight into the admin. A code already used in the same browser keeps its sign-in,
  so a second try does not need a new email code.

## D-147 — Online classes (2026-11-11)
- Plan for all of C: docs/plans/big-products.md (16, the student web app, is for later).
- `classes` (title, what it covers, subject, exam, teacher, start, minutes, Free / Premium / Paid with a price, seats,
  Draft / Published / Cancelled, "website only" for the JAMB classes of C17). The class and recording links are in
  `class_links`, which only staff can read; `class_join()` gives the join link only to a student who may come in and
  only from 15 minutes before the start to the end (and records that they joined); `class_recording()` gives the
  recording to the same students afterwards.
- Who may come in: Free = anyone who registers; Premium = Premium students; Paid = after payment. Payment uses the
  existing Paystack item flow: the app starts an "item" payment with the class id, the server recognises the class,
  takes the price from the class and records kind `class`; when Paystack confirms, the student is registered and
  told "You are in the class". The Paystack Edge Function did not change. In the Google Play build (no Paystack) a
  paid class opens the website instead.
- Reminders (job every minute): 2 h, 1 h, 30, 10 and 3 minutes before, at the start, and 10 minutes in for students
  who have not joined; each once per student, sent as push notifications that open the class.
- Admin → Online classes: add, edit, publish, cancel, links, seats, students (registered, paid, joined). A class with
  paid students cannot be deleted: cancel it and refund in Payments.
- App: Live classes screen (Live now, Coming up, Past with recordings), class page with one action (Register, Pay,
  Go Premium, Join, Watch the recording), next-class card on Home and Study, search.
- Fixed during testing: a change to finish_payment briefly broke finishing paid study items (wrong notification
  type) for about two minutes; no real payment was affected (checked).

## D-148 — JAMB classes on the website (2026-11-11)
- cbt.solutiontee.com/classes (public, no login): heading, introduction, price note, teachers and questions written
  in Admin → Online classes → Website page, and the timetable of upcoming published classes (JAMB, any exam, or
  "website only"), with time in Lagos, length, seats left and price. Class links are never on this page
  (`public_classes()` has none). Cached for minutes; admin changes refresh it at once.
- cbt.solutiontee.com/classes/me: log in with the email code (same as /pay); the student's classes (Coming up, Past),
  Join (opens 15 minutes before, link from `class_join()`), recordings, materials and assignments; other classes to
  register for; Register or Register and pay. Paying uses the same Paystack checkout as /pay and returns to
  /pay/done, which says "You are in the class" with a link back to My classes.
- Materials (title + https link, e.g. a Google Drive PDF) and assignments (instructions, due date, marks) per class,
  added in Admin → Online classes → Materials and assignments; students hand in a written answer (until a day after
  the due date, changeable until it is marked); teachers mark with a score and feedback. Teachers (staff role
  teacher) can manage these too. Students read materials and assignments only through `my_class_dashboard()`.
- Fixed in passing: the website footer's support email made phone screens scroll sideways (all pages).


## D-149 — Request a tutor (C12, 2026-11-11)
- A student sends one request at a time (exam, subject, what they need, free times; 3 a day at most) from
  Study → Request a tutor. The SolutionTee team replies in Admin → Tutor requests; each reply shows in the app chat,
  sends a notification that opens /tutor and an email (`tutor_reply`). Students can send 20 messages an hour. The app
  checks for new replies every 20 s only while the screen is open.
- Only super admins and admins see tutor requests (they hold students' contacts and chats); editors and teachers do not.
- Tutor plans (name, price, days, optional number of lessons) are made in Admin → Tutor requests. **Owner:** prices.
  There are no plans until the owner adds them; until then the app shows the chat only.
- Paying uses the Paystack item flow (D-147): `content_pay_start` sees the plan id and records kind `tutor`;
  `finish_payment` calls `private.tutor_paid`, which adds the plan's days after any time still left (buying again
  extends it), links it to the open request and posts a message in the chat. It runs once per payment.
- The assigned tutor's name, bio, WhatsApp and phone reach the student only while a plan is active (checked by the
  server in `tutor_overview()`); tutors' table is admins only.
- The Play Store build has no Paystack: "Ask about this plan" posts a message in the chat and the team helps the
  student, so the Play app does not link to an outside payment.

## D-150 — Games (C14, 2026-11-11)
- Study → Games (and search). Three ways to play, all scored on the server: the app gets one question at a time
  without the answer; the answer, points and (against a bot) the bot's result come back only after answering.
  Points: 100 for a right answer + up to 50 for speed. A question left open past its time (+3 s) counts as missed.
- **Speed Quiz Duel** against the SolutionTee bot (about 55–75% right) and **Beat the AI Tutor** (harder questions
  first; the AI Tutor gets about 80–90% right) use years the student can open.
- **Duel a friend** is played in turn: the host plays at once and sends a 6-letter code (WhatsApp); the friend joins
  with the code within a day and plays the same 10 questions. Both get a notification when the result is in. Friend
  duels use only years open on the free plan, so a free student never sees locked questions through a friend.
- **Live Exam Arena** is scheduled by staff in Admin → Games (title, exam, subject, start, questions, seconds,
  seconds to show the answer, most players, default 50). Everyone gets the same question at the same time; the phase
  comes from the server clock (the app asks every 2 s while open). 1.5 s grace for slow networks. Questions are picked
  from free-plan years when the first student joins. Players get a reminder 5 minutes before.
- XP (never money; admin can change): finish a duel 5, win 15, beat the AI Tutor 25, play an arena 5, arena top 3:
  30 / 20 / 10 (only with points above 0 and at least 5 players). Game XP is capped at 100 a day and also counts
  toward the normal daily XP cap. A student can start 40 games a day.

## D-151 — Community (C15, 2026-11-11)
- Study → Community (and search): learning posts (text with $maths$, one picture, optional subject), comments, likes,
  follows, block, report. Tabs: For you (people I follow and my JAMB subjects first, then likes, comments and how
  new), Following, My posts; subject chips.
- **Checked before anyone else sees it.** Posts and comments start as "being checked" (only the author sees them).
  The app asks the new Edge Function `community` to check at once; a 2-minute job (`community-sweep`, only when
  something waits) catches anything missed. The AI (models from the admin AI settings, key only on the server)
  allows learning content and rejects off-topic posts, phone numbers or links, insults, adult content, scams or
  selling, exam malpractice ("expo") and politics or religion arguments; the student sees the reason. Pictures are
  checked by a vision model, which reads the picture through the website with the student's own login. Until the
  website is deployed with the new `c/` picture route, posts with pictures wait for staff. When the AI cannot
  decide, the item waits in Admin → Community. Tested live: a maths question was shown; an off-topic post with a
  phone number was rejected with a reason (test posts removed).
- **@solutiontee** in a post: after it passes the check, the AI answers as a "SolutionTee AI" comment, at most 5 a
  day per student, once per post.
- Limits (admin can change): 10 posts and 60 comments a day; 3 reports hide a post or comment until staff look.
  Blocking hides both students from each other and removes follows. Students see each other's first name and
  initials only, never profile photos, emails or phone numbers. Banned students cannot post, comment or like.
- Pictures: private R2 under `c/<user id>/`, uploaded through the existing upload route (purpose "post", up to
  3 MB); signed only for the author, staff, or anyone once the post is shown and not blocked
  (`can_view_community_image`). Removed with the account (nightly account clean-up).
- Admin → Community (super admins and admins): Waiting, Hidden after reports, Rejected, Shown; Show, Reject with
  a reason (the student is told), Hide, Delete (audit-logged); settings.

## D-152 — Tutor v2 (update 1 of 3, 2026-11-11)
- Flow: request → plans (or **Custom**: the student describes it, an admin sends a price and days) → pay → admins get a
  push and an email → an admin assigns a tutor (only after payment) → the tutor gets an email → the student and the
  tutor chat. A plan that runs out ends the chat (read-only, "Renew"); buying again adds days.
- **Tutor role**: new staff role `tutor`, invited in Admin → Staff (its tutor profile is created at once). Tutors use
  2-step login like all staff but are walled off: `private.is_staff()` without roles excludes them, staff push
  broadcasts skip them, every admin page sends them to `/admin/tutor`, and tested: a tutor reads 0 questions and sees
  a request only once assigned to it.
- **Chat**: Realtime (`tutor_messages` in the publication with RLS for the student, their tutor and admins; typing and
  online on private broadcast/presence channels `tutor:<request>` with RLS on `realtime.messages`). Kinds: text,
  photo, voice note (app: AAC m4a via the `record` package; web: MediaRecorder webm/mp4), PDF (tutors), call link
  (Meet / WhatsApp / Zoom / other, shown as a call card), reference (past question → the paper in the app; lesson →
  the item in the app, under the student's plan rules). Read ticks via `tutor_mark_read`. Files are private in R2
  under `t/<request>/`, uploaded and signed only for the chat's members.
- **Notifications**: tutor/admin → student: push only (no email). Student → tutor: dashboard (live) + email at most
  once every 15 minutes per student. Tutor assigned: email to the tutor, push to the student.
- **Student details for the tutor**: name, age, school, state, email, phone, exams, JAMB subjects, target score,
  dream career, strong and weak topics, recent tests, leaderboard rank, streak, XP, plan and days left, goals.
- **Payments**: Paystack item flow (`tutor_offer(ref, uid)` accepts a plan id or the student's own request id for a
  custom price); Google Play: `tutor_plans.play_product_id` handled in `pay_play_confirm` (token-once, like Premium);
  the Play app pays on Google Play when the plan has a product and the admin allows Google, otherwise on
  cbt.solutiontee.com/tutor (one-time login from the app). The website page also lets students request and pay.
- **Admin**: Tutor requests is the same chat app (filters, assign, custom price, close, read any chat); plans have a
  Google Play product id; tutors show whether they have a login.
- **Owner / legal**: tutors see students' contacts (asked by the owner) — the Privacy Policy needs a line saying a paid
  tutor sees the student's name, contacts and practice results (draft for the lawyer). Admins can read every chat
  (safeguarding for 13–17). Create Play products for tutor plans in Play Console when ready.

## D-153 — Tutor v3: the owner's corrections (2026-11-12)
**Context:** the owner tested Tutor v2: tutor payments said "You are now Premium", the website pay page and success page
looked poor and did not return to the app, chat messages appeared only after reopening the app, and the chat lacked
emoji, reactions, swipe to reply and a good voice recorder. They approved new designs for the tutor pages only
("don't change anything on my home … only the tutor related pages").
**Decisions:**
- **Scope:** only tutor screens change. Home, Study and every other screen are untouched (the Study tutor card and the
  payment-return screen change only for tutor payments).
- **Realtime root cause and fix:** Realtime logs showed `MissingPartition` on the first private-channel join (the tenant
  was waking up); supabase-js / supabase_flutter do not join a failed channel again. Fix: `LiveChannel` (app) and
  `liveChannel` (web) re-join on error / time-out / close with back-off 1, 2, 4 … 30 s; each (re)join and each return
  to the app/tab refetches the last 60 messages and merges them (ticks, reactions, deletes too); a poll (12–15 s while a
  channel is down, 60 s otherwise) is the last safety net. Message rows use a public channel (`tutor-db:<id>`, row
  security decides who receives rows); typing and online stay on the private room `tutor:<id>`. `tutor_requests` joined
  the publication so "paid" and "tutor assigned" change the screen live.
- **Messages:** `reply_to`, `reactions` (one per side, jsonb {student, tutor, admin}), `deleted_at` (delete for
  everyone: own messages for 48 h, admins any time; body, file key, meta and reactions are cleared),
  `tutor_message_stars` (private per user), `tutor_message_reports` (admins notified). RPCs: `tutor_message_react`,
  `tutor_message_delete`, `tutor_message_star`, `tutor_starred`, `tutor_message_report`; `tutor_message_send` takes
  `p_reply_to`. `tutor_msg_json` returns a short copy of the replied message and my star.
- **Requests:** up to 4 subjects (`subject_ids`, `subject_id` = the first, for old screens); names via
  `private.tutor_subject_names`. Tutors: `years_teaching`, `qualification`.
- **Payments:** a tutor payment never shows Premium. The website link back to the app carries `kind=tutor`; the app's
  payment-return screen then opens `/tutor/paid`. The website tutor page remembers "from the app", so /pay/done counts
  down 3-2-1 and opens the app. (The app also understands a `kind` from the payment server; the server does not send it
  yet, which is not needed.)
- **Logos:** official Google Meet, WhatsApp and Zoom files from Wikimedia Commons, unchanged (PNG renders for the app
  because Flutter cannot draw the WhatsApp SVG's blur filter). Used only to mark "Join with …" call links.
- **Sound:** the tutor desk / admin plays a short two-note tone (Web Audio, no file) for a new student message when the
  tab is hidden or another chat is open, and for a new paid request (admin).

## D-154 — Tutor v4: fixes from the owner's test, photos and tutor quizzes (2026-11-12)
**Found:** (1) the admin site's `Permissions-Policy: microphone=()` blocked voice notes on the tutor desk (the browser
never asked); (2) an emoji-only message from a tutor failed: the student's notification must be 2+ characters and its
error undid the whole send; (3) pushes waited for a 5-minute schedule; (4) the app read broadcast payloads at the
wrong level (supabase_flutter passes `{type, event, payload}`); (5) a quick tap on the app's mic started a recording
after the finger had already lifted, with no way to stop it.
**Decisions:**
- Admin pages allow `microphone=(self)`; public pages keep it off.
- `tutor_message_send` pads a one-character notification body. Any notification written as due now wakes the push
  sender at once (statement trigger → `private.push_now()` via pg_net; the sender takes each message once, so no
  double sends); the `push-due` schedule runs every minute for planned ones.
- Messages are broadcast by the database (`realtime.send`, trigger on `tutor_messages`) to the chat room
  `tutor:<request>` (events `msg`, `msg_update`) and to the person's own private topic `user:<id>` (`tutor_msg` for the
  student's in-app banner, `student_msg` for the tutor desk; `tutor_req` when the request status changes). Row changes
  and polling stay as backups. `tutor_topic_ok` lets a user join only their own `user:` topic. The app opens its
  `user:` channel only for students with a paid or active tutor plan (keeps realtime connections low).
- In-app banner for tutor messages anywhere in the app, never on tutor screens or during tests, challenges or quizzes.
- The "class is live" bar hides once the student taps Join (ids kept on the phone).
- Web bubbles keep their React key when the server copy replaces the "sending" copy, enter with a short fade (no
  sideways slide), and the chat follows new messages and typing only when the tutor is already at the bottom.
- Photos: tutors upload a square 512 px JPEG (same private `a/<id>/` path as student photos); `can_view_avatar` lets any
  signed-in user see an active tutor's photo and lets a tutor or admin see their students' photos.
- Tutor quizzes: `tutor_quizzes`, `tutor_quiz_questions` (a snapshot of each past question, text-only ones without a
  passage or picture, or the tutor's own), `tutor_quiz_attempts`; all through functions, RLS on with no direct access.
  Answers are never sent to the app before submitting; scoring is on the server; the tutor sees score, time and every
  answer; a system message and an email tell the tutor when it is done. Past questions in a tutor quiz are open to the
  student even if that year is Premium-only, because the tutor chose them for a paying tutor student.
- Home shows "From your tutor" (quizzes to do) only when there are some; Test shows "Tutor quizzes" only when there are
  some. Nothing changes for students without a tutor.
- **Follow-ups (owner, same day):** a tap on the app's mic records hands-free (delete, pause, send), a hold keeps the
  WhatsApp hold (slide to cancel with a bin animation, slide up to lock); a tap on a quoted reply jumps to the original
  and makes it glow (app and tutor desk); the in-app banner is a navy card with the tutor's photo, a "TUTOR" or "QUIZ"
  tag, a time bar, swipe to close, and never shows while a tutor chat is open; a livelier typing indicator with the
  tutor's photo; a tutor's name and photo now update their account profile and login too, and their students' apps
  refresh at once (`private.tutor_profile_sync`, also after admin edits).
- **New students:** the app tour comes first; the exam countdown and the other daily pop-ups wait for the next open.
- **Countdown push:** every day at 07:00 Lagos (`countdown-push` cron, `private.countdown_notify`), "N days to JAMB UTME"
  with a short line that changes with the days left, while the countdown is on and the date is ahead. The admin can
  stop it with `exam_countdown.push = false`.


## D-155 — Community v2: its own space like X (2026-11-12)
Owner: "COMMUNITY DESIGN APPROVED, option b for photos but on by default, handles okay". Plan: `docs/plans/community-v2.md`.
- **Its own full-screen space** (Study → Community): bottom bar Home · Explore · Notifications · Profile, a gold compose
  button, header and bars slide away while scrolling down and return on scrolling up; back returns to Study. Colours come
  from the app theme (the approved canvas is the dark theme; light mode uses the same layout with light tokens).
- **Handles:** everyone got one from their first name (`tolu`, `tolu_a`, `tolu27` …); it follows the name until the student
  picks their own. 3–20 small letters, numbers, `_` and `.`; unique; names with SolutionTee, JAMB, WAEC, NECO, admin,
  staff, tutor and similar are kept; a picked handle can change once every 30 days. New handles and bios wait for the AI
  check (`pending_handle`, `pending_bio`); others keep seeing the old ones until it passes. Undecided ones wait in
  Admin → Community → @handles and bios.
- **Photos (option b, on by default):** `community_profiles.show_photo` defaults to true; a student can turn it off in
  Edit profile. `can_view_avatar` allows any signed-in student to see a Community photo that is on, unless one blocked the
  other. Community is only inside the app, never on the public web.
- **Posts:** up to 500 characters, up to 4 pictures (`images text[]`, `image_path` kept = first picture for older apps),
  quotes (`quote_of`), reposts (`community_reposts`, the count includes shown quotes), bookmarks (private), #topics
  (`tags`, used for trending and tag pages), `$maths$`. Replies are threaded one level (`parent_id` = the top reply,
  `reply_to` = the person answered) with likes. Likes and saved posts are visible only to their owner.
- **Feeds:** For you ranks by follow (+3), a followed person's repost (+2), the student's subjects (+2), activity and age
  (60 days); Following shows posts and reposts by people followed, newest first; tag and subject pages are newest first;
  a "N new posts" pill polls `community_new_count` every 45 s while Home is on screen (cheap, no realtime per post).
- **Notifications:** `community_notes` (like, reply, repost, quote, follow, mention, AI answer, shown, rejected, reply
  like, profile) grouped in the list ("Tolu and 3 others liked your post"), live on the student's own private
  `cnote:<id>` topic (a separate topic from the tutor banner's `user:<id>` because one socket cannot join a topic twice).
  Phone pushes only for replies, mentions, quotes, follows (once a day per person), AI answers and rejections — never
  for likes or reposts.
- **AI check, friendlier:** greetings, friendly chat, motivation, school life and study jokes pass; still blocked: sexual
  content and dating, politics, betting and sports gossip, religious fights, bullying and hate, contacts and links,
  scams and selling, exam "expo", drugs and weapons, spam; self-harm gets a kind message. "When unsure and friendly,
  allow." Posts with pictures are checked with a vision model (all pictures); quotes are checked with the quoted text.
- **Blocking:** blocked people never see each other anywhere (feeds, search, threads, notes, profiles, photos).
- Old app versions keep working: `community_feed`, `community_post_get`, `community_profile`, `community_post_create` and
  `community_comment_add` are unchanged in shape.
- Share uses the phone's share sheet (`share_plus`), text plus the website link (no public post pages).

## D-156 — Community v3: checked after posting, a livelier SolutionTee AI, SolutionTee team and pages (2026-11-12)
Owner: "COMMUNITY IS APPROVED, only few changes…" (same day as D-155).
- **Checked right after posting** (admin can switch back to "before"): posts and replies show at once; the AI checks them in
  seconds (the app asks at once; the 2-minute sweep is the backup and reads post pictures with the cron token through
  `/api/images/sign`). A post or reply that breaks the guidelines is taken down; the student gets a note and a push
  ("Your post was removed …") and a **strike**. At the admin's limit (default 3 strikes in 30 days) posting and replying
  pause for the admin's time (default 24 hours): `community_strikes`, `community_bans`; staff can lift a pause early.
- **SolutionTee AI** (@solutiontee): a warm, chatty, funny and careful persona (never claims to be human), writes Markdown
  and maths; answers posts **and replies** that tag it (and keeps chatting when a student answers it, a thread reply);
  joins a few fresh posts on its own (admin cap a day, default 15; it answers "SKIP" when it has nothing kind or useful).
  The app and the staff feed draw its replies as Markdown with maths (the same note renderer as lessons).
- **Badges:** the SolutionTee mark next to staff (any role but tutor), Community moderators (chosen by admins by
  @handle) and SolutionTee pages; a gold-edged mark for the official page; a gold seal for SolutionTee AI. Moderators,
  admins and super admins can take down any post or reply (reason, strike, audit log). Staff powers in Community do not
  need the admin console's 2-step sign-in (they only act on Community content).
- **Pages:** the official **SolutionTee (@solutiontee)** page (only super admins post as it) and pages any staff member
  creates; page posts show the page's name and mark, are not checked by the AI, notify the page's followers, and rank
  higher in For you. Students follow pages. Handles are unique across students and pages.
- **Staff feed** (website, Admin → Community feed): the same feed as students, post as yourself or a page, like, repost,
  reply (threads, AI Markdown), delete or take down; create pages; choose moderators.
- **Feed ranking (For you):** follows (+3), how often you liked or replied to the author in 30 days, friends of friends,
  reposts by people you follow, your subjects, the #topics you use and like, activity (likes, 2×replies, 3×reposts), page and
  team posts, fresh questions with no answer yet, pictures, the first 2 hours, minus age (about one point per 18 hours),
  minus authors you marked "Not interested", and a variety rule (each extra post by the same author in a page drops 1.5).
- **Personal notifications:** posts from people you really engage with (2+ likes or replies in 30 days; at most one a
  person every 6 hours, 3 pushes a day), like milestones (10, 25, 50 … 1000), a daily summary at 19:31 Lagos ("Today your
  posts got 12 likes and 3 replies"), a question in your subjects that nobody has answered yet, page posts, take-downs and
  pauses. Each student chooses which of these buzz the phone (Edit profile → Phone notifications; likes off by default).
- **Ads:** an ad card after every N posts in the Home feed (admin setting, default 5), through the existing ads level,
  consent and Premium rules (no ads for Premium where the ads level says so).
- **Profile:** exams, subjects and joined date each on their own line with an icon, separated by commas.

## D-157 · Game Zone v2 (owner: GAMES DESIGN APPROVED, 12 Nov 2026)
- **Seven live games** replace Study → Games: JAMB Duel, Speed Rush, Knowledge Survival, Maths Blitz, Word War, Memory
  Flash and Team Relay. The old Live Exam Arenas and classic duels stay reachable (Game Zone → "Live Exam Arenas and
  classic games", `/games/classic`).
- **Ways to play:** Quick Match (the server pairs students of a similar rating; the window widens while they wait), Practice
  vs AI (Easy, Medium, Hard bots with set accuracy and speed), Play a friend (6-letter code, share link, Rematch invite on
  a private topic) and Ranked (Elo, K = 32, limited to ±40; the same two students can play at most 3 rated games a day).
  Nobody free in 15 s (admin setting) → a clearly labelled SolutionTee Bot joins, so a game always starts.
- **Group games** (Survival up to 20, Relay 3 v 3, Rush up to 6) open a lobby for 12–15 s; **bots fill the empty seats**
  (owner, answer 1).
- **Fair play on the server:** one Postgres match; every round has its own open time on the server clock; answers are
  scored by the server's time (faster right answers score more, up to 150); the right option is only sent after the round
  closes or to the student who just answered; a round closes early once every student has answered (bots answer at their
  planned moment); race answers faster than humanly possible count as a guess; Memory Flash levels are checked (moves ≥
  pairs, time possible). Free students only get free-year questions. Bots are deterministic (seeded) and settle lazily
  when anybody reads the match; a sweep closes old lobbies and queues every 10 minutes.
- **Rewards are XP only** (owner, answer 3) and **every amount is set in Admin → Games**: XP for playing, for winning, extra
  for a Ranked win, extra for 3 wins in a row, each overridable per game; a win only pays when at least 40% of the answers
  were right; game XP stays inside the daily game XP cap and the normal daily XP cap. Students who leave a game get none.
- **Starter content waits for review** (owner, answer 2): 102 Word War words and 96 Memory Flash card pairs are seeded
  switched off; Admin → Games has Approve all, approve/hide each, edit and add. Word War needs 10 live words and Memory
  Flash 6 live pairs before they open ("SOON" on the card until then).
- **Players' pictures** (owner): the student's real photo when they have one (and allow it in Community), otherwise the
  avatar they build in Game Zone (skin, 8 hair styles incl. hijab and cap, hair colour, shirt, face, glasses, background);
  "Use my photo" can be switched off. Bots get their own avatar and a BOT tag.
- **Look:** a real mobile-game style drawn in code (no image downloads): night stadium with moving spotlights, VS split,
  race track with cars and nitro, floating islands over rising lava, neon arcade, castle, card table with 3D card flips,
  chunky 3D buttons that press down, treasure chest, ribbons, stars, spark bursts, confetti; Lilita One (SIL OFL, 27 KB)
  for game words. Performance: each scene is one painter in a RepaintBoundary, moving parts are small separate painters,
  timers repaint only themselves from a Ticker, no blur over lists; everything still under "reduce motion". Haptics on
  taps, right and wrong answers; no sounds (off by default, none added).
- **Live updates:** private Realtime topics `gz:<match>` (start, answers, rounds, steps, done) and `gzu:<user>` (match found,
  rematch invites), with timed refreshes at each round's open/close and a 3–5 s backup, so a dropped connection never
  freezes a game. The app keeps the server-clock offset from the quickest round trip.
- **Owner changes (12 Nov 2026, after the first check):**
  - **Sound and music:** synthesised by `design/scripts/gz_sounds.py` (ours, no licences, 476 KB): 17 effects (tap, right,
    wrong, last-3-second ticks, 3-2-1-GO, match found, flips, pairs, coins, combo, spin-out, win, lose …) and two music loops
    (an Afro-pop hub groove at 112 BPM and a battle track at 128 BPM). Played with `audioplayers` (low-latency pools for
    effects), mixed with other apps, paused in the background. Effects and music are on by default; the speaker button in
    the hub turns each off (remembered on the phone).
  - **Tougher Practice vs AI:** Expert and Legend levels (93% and 97% right, answering in 7–28% of the time). Quick Match
    bots follow the student's rating up to Legend.
  - **Word War and Memory Flash open** (the owner's earlier review step is dropped): 89 more words and 76 more card pairs,
    with Economics, Government, Geography, Literature and Agriculture cards; Memory Flash lists all the student's subjects.
  - **Less waiting online:** the question reaches the phone 1.5 s before its round opens and shows exactly at the open time
    on the server clock, so a slow network no longer eats answering time.
  - **Look:** the round result is a game screen (CORRECT!/WRONG! banner with points, the answer as a green tile, "ROUND 7 IN
    3" countdown, the timer ring counting to the next round); no shine on the portrait ring; underlined words in questions
    are bold with a thick gold line (everywhere in the app).
- **Community fixes:** a page post opens the page (logo, badge, follow the page), not the staff member who wrote it; the
  AI reply no longer overlaps the next reply (the row is laid out at its real height) and long answers fold with "Show
  more"; @solutiontee answers within seconds (the app asks the server to check every new reply at once, the AI writes
  while the check runs, shorter replies, 25 s per model before the next one), with "SolutionTee AI is typing…" meanwhile.
- **Text size on every phone:** the phone's font size setting is followed between 90% and 115% (very large settings broke
  layouts), narrow screens under 360 dp scale down a little; the Home greeting and name stay on one line; the search button
  left the Home header (search stays in the menus and app shortcuts).
- **Admin → Games crashed** (12 Nov 2026): the page (a server component) read the games list from a "use client" file,
  which Next.js turns into a client reference, so `.map` failed on the server. The list now lives in `gamezone-shared.ts`.
- **SolutionTee's own game questions** (owner, 12 Nov 2026): Admin → Games → "Game questions" takes a CSV per subject
  (question, option_a–e, answer as a letter or the option text, difficulty), checks every row in the browser first, adds
  the good rows as one undoable batch, and lists, hides or deletes them. They live in `gz_questions` (staff-only RLS; the
  answer never leaves the server, like past questions). "Where game questions come from" sets JAMB past questions only,
  SolutionTee questions only or both, for all subjects and per subject (`games.gz.source`, `games.gz.sources.<id>`).
  Students are never told the source: items carry no source field. If a subject has fewer own questions than a game needs,
  past questions fill the gap so a game always starts. To cut repeats, `gz_seen` remembers each question a student got
  (30 days); questions seen in the last 21 days go to the back of the queue.

## D-158 · Owner corrections and new features, 13 Nov 2026 (Game Zone, Community, Home, ratings, onboarding)
- **Names in full.** A shared `FitText` / `NameLine` (apps/mobile/lib/widgets/fit_text.dart) shows a name whole, sets it up
  to 15–25% smaller when it is a little long, and only then ends a really long name with "…". In posts the @handle gives way
  first and the time always shows; the "…" menu now sits in its own column at the right edge. Home shows the first name with
  XP and streak under it; the Game Zone hub shows the name on a plate under the header.
- **Game music stopped after a sound effect:** every effect asked Android for audio focus ("gain"), which made our own music
  player lose focus for good. All Game Zone players now use AudioFocus none / iOS ambient + mix, so music and effects share.
- **Profile photos** crop a little above the middle (faces in 9:16 photos); staff, the official page and pages show no
  streak; "0 Following  1 Follower" spacing.
- **Challenges** show no "Past Question / SolutionTee Mock" label (owner's call; the legal list in D-120 asked for it — it
  stays in normal practice). The challenge card has no "LIVE · n playing" pill. The JAMB mock result no longer *replaces* the
  router page (that left go_router's page list out of step, so "See the leaderboard" opened a blank screen).
- **Countdown:** back to the small one-line chip, "122 days to your UTME (15 Mar 2027)", number counts up, hourglass turns,
  a gold shine passes (owner preferred the small chip to a big card). The full-screen daily countdown is unchanged.
- **Community:** @ suggestions while typing (pages first, then people you follow, then handles, then names); SolutionTee AI
  replies read the post, its pictures (vision model), the quoted post and the last 16 replies; likes, reposts and reply likes
  now push (one per post an hour, on by default, switchable); opening a notification or the post a push opened marks it read
  at once (`community_note_open`).
- **Comprehension Clash** (game `reading`, race engine): same passage for both players, shown part by part for words ÷ wpm
  (Admin, default 240, 20 s–3 min); answers are refused until the passage closes and the passage text is withheld after it;
  3–6 questions (main idea, writer's purpose, word in context, deduction, detail); most right wins, ties to the earlier finish;
  2 points a second left. Bots get their whole answering time. Passages: our own (`gz_passages` + questions, CSV in Admin,
  8 original starter passages) and/or JAMB comprehension passages (free-tier years for free players), following the English
  source setting. Answers under 1.5 s count as guesses.
- **Admin → Games** is now tabs: Overview (stats, settings, XP, question source), one tab per game (how it works, best content,
  its CSV format), Classic games. CSV for Word War words, Memory Flash cards and Comprehension Clash passages (one row per
  question, grouped by passage title), all checked in the browser (`gz-csv-check.ts`) and again on the server.
- **Home:** "Play and connect" cards for Game Zone and Community just before News (painted, light, motion off with reduce motion).
- **App rating + reviews:** our own rating card (stars + comment; `app_ratings`, one per 20 days) after N days/opens, then every
  N days; staff read it in Admin → App ratings. Google's in-app review is asked at a happy moment (score ≥ 60% on 10+
  questions, a game win), separately and for everyone: Play forbids asking an opinion first or showing Google's box only to
  happy users. Feature suggestions (Game Zone, Community, Request a tutor) rotate, skip features opened in 7 days; at most
  one pop-up an app open, never on top of the countdown, a badge or the daily XP. All timings in Admin.
- **Onboarding:** slides for Game Zone, Community and Request a tutor (painted art), new order; the tour has a "Play and
  connect" step. **Play listing:** new short/full description, store images 8–10 from the app's own renders, feature
  graphic, screenshot order, data safety line, what's new text (docs/play-console/README.md).

## D-159 — Game Zone: harder with rank, difficulty per game bank, teleprompter reading, board per game (14 Nov 2026)

- **Harder as you rank up:** `private.gz_target(match)` gives a difficulty target from 0 (easy) to 2 (hard): in ranked and
  quick games from the players' average rating (Bronze ≈ easy/medium, Silver medium, Gold/Platinum medium-hard, Diamond
  hard); in VS AI from the level picked (Easy → easy … Legend → hardest). Questions, words, cards and passages are
  picked closest to the target (still preferring ones not seen in 21 days, so content never runs out). Bots were already
  stronger with rating. Comprehension Clash also scrolls faster: 90% of the admin reading speed for beginners up to 120%.
- **Difficulty in every game's bank:** game questions (with an optional "this game only" list), words, card pairs and
  passages each have easy/medium/hard; the CSV templates have a `difficulty` column (blank = medium).
  `admin_gz_difficulty()` counts each level per game; each Admin → Games tab shows step-by-step "How to add content",
  a "Difficulty and ranks" box, and a bar of easy/medium/hard with a warning when a level has fewer than 20.
- **Teleprompter reading (owner):** the passage moves up by itself at a steady pace from the first line to the last,
  synced to the match clock, inside a window of about 7 lines with fades, and a gold reading line. Nobody can scroll it
  or see the whole passage. Painted with one laid-out TextPainter per frame (no rebuilds) to stay smooth on 3 GB phones.
  Shows the words-a-minute speed, the word count and both readers.
- **Board per game:** the hub shows the selected game's leaderboard (top 3 + your rank and rating in that game); RANKS and
  SEE ALL open the ranks screen on that game's tab (all-games tab still there).

## D-160 — Owner fixes 14 Nov 2026 (GAMES APPROVED)

- **Home header:** XP and streak are back on the right of the name, as before; a very long first name is cut with "…"
  (owner: showing names in full had broken the layout).
- **JAMB mock "See the leaderboard" blank:** the leaderboard was opened by jumping from the full-screen mock page into
  the Test tab through the router, which left a blank page. It now opens straight on top of the result
  (`openChallengeBoard`), from both the end of the exam and the mock page; back returns to the result. Test with the
  server's real answer: test/mock_board_test.dart.
- **Community profile photo:** with a ring, the photo was inset by the ring but cut at the outer circle, so tall (9:16)
  photos showed as a rounded square with dark corners. The ring is now outside and the photo is cut to its own circle.
- **Countdown chip:** the hourglass is still, with nothing behind it.
- **Challenge cards v2 (waiting for the owner's approval):** clean, not game-like (owner): LIVE pill with a beating dot +
  "N playing" (counts up), prize or title, details, "You took part · #rank" / Disqualified / writing, countdown whose
  numbers slide, a time bar that fills, and the app's gold button. A blue "Coming up" card counts down to the start.
  Small Home cards and the Test → Challenges rows use the same look on the normal card surface. lib/features/compete/
  challenge_cards.dart; screenshots from test_shots/cards_shots_test.dart.
- **Onboarding films:** Game Zone (players slide in, VS lands, a question, the right answer, +100 and confetti),
  Community (a question types out, likes, AI typing then answering, a thank-you) and Request a tutor (a live lesson: the
  tutor writes the steps on a board, a tick, "Now I get it!"). Each loops while its slide shows and stands still with
  reduce motion. Shorter, clearer slide text (app fallback + Admin rows that still had the first text).

## D-161 — Admin pages timing out: staff checks run once per query (14 Nov 2026)

- /admin/questions always showed "canceling statement due to statement timeout". The staff read rule on `questions`
  called `private.is_staff()` bare, so Postgres ran it for every row: 25 questions took 11.6 s (33,444 rows checked),
  plus four exact counts, past the 8 s limit.
- Every policy in `public` that called `private.is_staff(...)` or `private.can_edit(...)` bare now wraps it as
  `(select ...)`, so the check runs once per query. Same rules, same answers: tested that a student and a staff member
  without two-step sign-in still read 0 rows, and a signed-in super admin reads all. Added an index for the newest-first
  list. The same query now takes 0.08 s. New policies must use the `(select private.…())` form.

## D-162 — Updates, maintenance, no-internet mode and a scaling pass (14 Nov 2026)

- **Leaderboard:** exam chips show the logo above the full name (no "J…", "Ch…"). **Challenge list rows:** the
  coloured edge on the left is removed (owner).
- **Play Store update pop-up:** Google Play's own update check (`in_app_update`) says when a newer version is live. The
  pop-up follows the owner's example: "Discover a new version", the version in gold, a rocket picture, a short note,
  and Ignore / Update now. Update now opens the Play Store; Ignore hides it for a day.
- **Admin → Flags & settings:**
  - **Maintenance:** message, "Back by" time (Lagos), and "staff can still use the app" (not tutors). The app checks
    every 30 s while showing it and opens again by itself.
  - **Play app:** show the pop-up, or make the update a must.
  - **Minimum build:** every app (Play and website) below that build number must update. This replaces the old
    "minimum version 1.0.0" check, which compared a version name the release build never set.
  - All of it comes from one small call, `public.app_gate()`. The checks wrap the whole app, so signed-out screens
    are covered too.
- **No internet:**
  - A real check (the phone says "connected", and one tiny request to our server confirms it), re-checked every 10 s
    while offline.
  - A small banner at the top ("No internet · downloaded tests still work") that shrinks to "Offline", and a green
    "Back online" when the connection returns.
  - Offline screens list what still works, link to My downloads, and reload by themselves when the internet is back.
- **Scaling:** `my_open_years` made 20–30× faster (same answers, tested), 87 foreign-key indexes added, 4 duplicate
  indexes dropped, scheduled-job history trimmed nightly. Compute-size advice for busy times is in docs/SCALING.md
  (owner's pricing decision).

## D-163 — Online classes v2: pay once for a class, attend every session (14 Nov 2026)

- **Class programmes.** The admin creates a class once (e.g. "JAMB Marathon Class"): title, tagline, flyer, about,
  what you get, exam and subjects, teacher with photo and bio, timetable note, start and end dates, price (and an
  optional "was" price), seats, FAQ, Draft / Published / Closed, and "show on the website". After that the admin only
  adds **sessions** (title, time, length, link) to it. Students are reminded before every session.
- **Pay once.** A student pays for the programme one time (Paystack, kind `class_program`) and is enrolled. Every
  session of that programme then opens for them, past and future, with recordings. Paying again is refused
  ("already bought"). Locked on the server: the join link and recordings are only given to enrolled students.
- **Decisions I made (not asked):** access lasts until the programme's end date (no end date = for ever). Paid
  programmes are **not** included in Premium, because they are separate products with their own teachers. Free and
  Premium programmes are possible in the app but only paid ones are shown on the website (owner: "That site is only
  for paid classes").
- **Website `cbt.solutiontee.com/classes`:** a shop of paid classes with flyer cards (price, seats left, LIVE, next
  session countdown), trust points (Paystack, real teachers, recordings, pay once), how it works, teachers and FAQ.
  Each card opens `/classes/<slug>`: the flyer, everything the admin set, a live countdown to the next session (and to
  its end while live), the timetable, the teacher, how joining works, FAQ, and **Pay** right on the page (email code,
  then Paystack). A price bar stays at the bottom on phones. Flyers stay in the private bucket and are shown through
  short signed links.
- **App:** a Classes section with programme cards, a programme screen (flyer, countdown, price, timetable, FAQ, one
  button: Pay once / You are in / Join live), session screens counting down to the start and then to the end with a
  progress bar, and a new Home "Next live class" card with the countdown. Numbers slide; LIVE pulses; respects reduce
  motion.
- **Offline banner:** the double yellow underline under the no-internet messages is fixed (the banner had no Material
  behind its text).
