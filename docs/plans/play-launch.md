# Google Play launch: legal changes, payments and cbt.solutiontee.com (8 Nov 2026)

Owner's list of 8 Nov 2026 plus the lawyer's combined decisions document (same date). Part A is built. Parts B and C
are the plan the owner asked to see **before** the payment work starts.

## A. Built now (D-109 to D-112)
1. **No ads during sign-up and setup.** Welcome, sign-up, code, setup, parent step and age screens never show ads.
2. **6-digit email codes.** The app follows the length the server sends; the owner sets *Email OTP Length = 6* in
   the Supabase dashboard (SETUP §7.4).
3. **Age rules (D-109).**
   - Year of birth asked neutrally in "Tell us about you".
   - **Under 13:** the server refuses the year, and the new account is deleted at once. Nothing is kept. The
     screen says the app is for students aged 13 and older.
   - **13 to 17:** the next step asks for a parent's or guardian's email. We send a warm welcome email with:
     - a plain summary of the Privacy Policy and Terms;
     - the line "you do not need to click anything to approve";
     - a **Turn off my child's account** button.

     The button pauses the account at once (sign-in blocked) and it is deleted 30 days later. Each notice is kept
     (`guardian_consents`: who, when, which policy version, how).
   - **18+:** normal account.
   - Accounts made before these rules are asked once: the year of birth, then the parent step if they are 13 to 17.
4. **Cash prizes off (D-110).**
   - One admin switch (*Flags & settings → Legal switches*), off by default. The server refuses:
     - cash prizes on challenges;
     - cash prize claims;
     - new cash referral rewards.
   - When it is turned on later (after LSLGA approval): cash challenges must be free to enter (no XP fee) and are
     only for students aged 18 and over.
   - The app hides cash amounts, "My winnings" and the referral cash meter. It promises Premium days and XP instead.
5. **XP cannot be bought (D-110).** The server refuses XP packs, and the app no longer shows "Buy XP". XP is earned:
   daily claim, tests, mocks, streaks, challenges, referrals and watching ads.
6. **Personalised ads only for 18+ who say yes (D-110).** This was already 18+ only. Now adults also need to turn
   on *Settings → Personalised ads*, which is off by default (NDPA: consent must be a clear "yes").
7. **Exam logos switch (D-111).** Off by default. The app shows our own exam badges (an exam icon and the name in
   plain text). An admin turns the real logos on after written permission from JAMB, WAEC and NECO.
8. **Google Play preview build (D-112).** Every app build now also makes the Play version and puts it on
   https://admin.solutiontee.com/download?channel=play. It has:
   - no Paystack;
   - no self-update (Google Play updates it);
   - Google Play Billing only.

## B. Payments on Google Play — the plan (needs the owner's OK)

### B1. The rule we must follow
- In an app installed from Google Play, **every purchase of digital content inside the app must use Google Play
  Billing**: Premium, videos, past-question years, notes, everything.
- The app must not have a button, link or text that sends students to another way to pay. Google calls this
  "steering".
- Google allows outside-payment links only in the US, UK and EEA (programmes that started on 30 June 2026).
  **Nigeria is not included.**
- A "Pay on our website" button in the Play app would get the app rejected or removed, and repeated breaks can
  close the developer account.

So item 5 of the owner's list cannot be built exactly as written. This version gives students the same easy
choice and stays inside Google's rules:

### B2. How students without a card will pay
| Where | How they pay | Notes |
|---|---|---|
| **Play Store app** | Google Play Billing: card, plus MTN/Airtel airtime billing and Google Play balance where Google offers them in Nigeria | Nothing in the app mentions the website or other payment methods. |
| **cbt.solutiontee.com** (website) | Paystack: card, bank transfer, USSD, OPay and other wallets | The student logs in with the same email (6-digit code). Premium goes on the **account**. |
| **Voucher PIN** (website) | Paystack, no account needed | For a friend, a child, a school or an agent. The PIN is emailed after payment. |
| **Direct APK** (website download) | Paystack inside the app, as today | |

- **Premium follows the account.** Bought on the website, it shows in the Play app as soon as the student logs in.
  Google allows an app to unlock what a user bought elsewhere, as long as the app does not point them there.
  In the app we only say "Already have Premium? Log in with the same email."
- **Voucher redemption:**
  - At launch, PINs are redeemed **on the website** (always allowed).
  - The app's "Redeem a code" stays **off in the Play build** (`codes_in_play_build`) until the lawyer or Google
    confirms it.
- **How students hear about the website:** WhatsApp, TikTok, Instagram, schools, SMS, email and the landing page.
  Telling users about other ways to pay outside the app is allowed. Inside the Play app we never do.

### B3. What we build (after approval)
1. Play Console products:
   - Premium monthly, 3 months and Exam Season (one-time purchases, like today's `play-verify`);
   - "single item" price levels (₦200, ₦500, ₦1,000…) that the server maps to the item being bought.
2. Play prices:
   - Google keeps 15% (the owner chooses: the same price as the website, or a little higher);
   - Google adds VAT itself, as the owner said.
3. Website payment pages (C below) using the existing `paystack` Edge Function with `source: "web"` (D-061).
4. Vouchers: one-use codes that give Premium days (the existing promo-code system, D-024), created automatically
   after a website payment and emailed to the buyer.
5. Play testing:
   - Play Console **internal testing** track: the workflow builds an AAB, and the owner's Google account is a
     licence tester, so test purchases cost nothing.
   - The preview APK on /download shows the look but cannot buy, because Google Play Billing only works for apps
     installed from a Play testing track.

### B4. Owner decisions needed
1. Approve B2 (Google-compliant: no website link inside the Play app). **Recommended.**
2. Play prices: the same as the website, or higher to cover Google's 15%?
3. Play Console account:
   - Does the owner already have one? An **organisation** account needs a D-U-N-S number.
   - New **personal** accounts must run a closed test with **12 testers for 14 days** before going public.

## C. cbt.solutiontee.com — landing and payment website (after approval)
- **Where:**
  - the same Next.js app (`apps/web`), served on the `cbt.solutiontee.com` host;
  - the owner adds one DNS record (a CNAME to Vercel), and we add the domain to the Vercel project;
  - no new hosting cost.
- **Pages:**
  - `/`: the landing page. It has:
    - a hero with the real app on an animated phone;
    - features (real CBT, every answer explained, AI tutor, video lessons, study notes, challenges, offline,
      data saver);
    - exam coverage with our badges (no official logos) and pricing;
    - FAQ, the disclaimer, and **Get it on Google Play** (Google's official badge) + **Download the APK**.
  - `/pay`: log in with an email code → choose Premium or an item → Paystack → done (Premium is on the account).
  - `/voucher`: buy a PIN without an account. `/redeem`: use a PIN.
  - `/privacy`, `/terms`, `/refunds`, `/contest-rules`, `/acceptable-use`, `/ads` and `/delete-account`: needed
    for Play Console, using the corrected legal texts.
- **Design and motion:**
  - our tokens and brand files; Motion (Framer Motion) for scroll reveals, parallax phone screens, animated counters
    and smooth section transitions;
  - follows "reduce motion"; light and dark; fast on 3G (images in WebP, video loaded only when needed);
  - Lighthouse 90+.
- **Order:** landing page → legal pages → /pay → vouchers → Play products.

## D. Lawyer's document: built items (D-118 to D-120, 2026-11-08); owner paperwork still open: NDPC, DPIA, licence letters
- Corrected legal documents (8), published at the URLs above. The business name is
  "SOLUTIONTEE EDUTECH AND ICT SERVICES, Business Name, RC 9123561", not "Limited".
- The lawyer's text prefers the parent **confirming**. The owner chose **notice + turn off**, which is what is
  built. The table records the method, so "confirm" can be added later if the lawyer or NDPC asks.
- Google UMP consent message for adults in the EEA/UK. Nigeria is covered by the in-app switch.
- Automatic deletion of AI chats and question photos after 12 months (Supabase and Neon), and the 24-month
  inactivity purge.
- DPO + privacy@solutiontee.com, NDPC registration, DPIA (owner's paperwork).
- "Past Questions" and "SolutionTee Mock Questions" labels; licence letters to JAMB, WAEC and NECO.
- Play Console reviewer accounts with fixed codes; Data safety form checked against the real build.
- App-open ads: remove them from the policies or from the build (they are in the build today).
