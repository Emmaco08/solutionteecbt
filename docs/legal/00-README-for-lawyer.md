# SolutionTee CBT — Legal pack for review

**Prepared:** 8 November 2026, by the product team, for review by SolutionTee's lawyer.
**Business:** SolutionTee (RC 9123561), Ipaja, Lagos, Nigeria.
**Product:** SolutionTee CBT, an Android app (Google Play and direct download from solutiontee.com) plus an admin website, for JAMB/WAEC/NECO exam practice.

These are **drafts**. They describe the app exactly as built today. Points marked **[CONFIRM]** in each document need your decision or wording. Nothing has been published yet.

## Documents in this pack
| # | File | Purpose | Where it will be shown |
|---|---|---|---|
| 1 | `privacy-policy.md` | Privacy Policy (NDPA 2023) | solutiontee.com/privacy, app (About, Settings, sign-up), Play listing |
| 2 | `terms-of-service.md` | Terms of Service | solutiontee.com/terms, app, sign-up |
| 3 | `contest-and-prize-rules.md` | Rules for challenges, cash prizes, mocks, referrals | solutiontee.com/contest-rules, each challenge page |
| 4 | `payments-and-refunds-policy.md` | Premium, XP, single items, refunds | solutiontee.com/refunds, checkout |
| 5 | `acceptable-use-and-ai-policy.md` | Conduct rules and AI tutor rules | solutiontee.com/acceptable-use, AI tutor |
| 6 | `advertising-and-rewards-policy.md` | Ads, rewarded videos, age-based ads | solutiontee.com/ads, Settings |
| 7 | `account-deletion.md` | Account deletion page (required by Google Play) | solutiontee.com/delete-account |
| 8 | `google-play-console-declarations.md` | What to enter in Play Console (data safety, ads, audience, rating) | Internal (for whoever submits the app) |

## What the app does (short)
- **Practice:** timed CBT with past questions; quick tests, topic drills, full JAMB mocks and custom exams; results and review.
- **Study:** video solutions and lessons, lesson notes, novel summaries, syllabus PDFs.
- **AI tutor:**
  - an AI model (NVIDIA API) answers school questions;
  - students may send photos of questions and speak (speech is turned into text on the phone);
  - a web search (Brave) is used for current exam news;
  - moderation and "strikes" for abuse.
- **Money:**
  - Premium plans (Paystack in the direct app; Google Play Billing in the Play app);
  - XP (virtual points: earned, or bought in the direct app only);
  - single items bought one by one (direct app only);
  - promo codes.
- **Ads (free users):**
  - Google AdMob banners, native, full-screen, app-open and rewarded ads;
  - our own sponsored brand campaigns;
  - **never during exams or checkout**;
  - Premium has no ads;
  - personalised ads only for 18+, child-directed for under 13.
- **Competitions:**
  - free-entry, skill-based challenges with cash or Premium prizes;
  - tutorial-centre mock challenges;
  - leaderboards; a winners wall with receipts;
  - referral rewards, including cash after 30 verified friends.
- **Trust and safety:**
  - one account per phone (hashed device IDs);
  - cheating detection (screenshot/recording detection, split screen, emulator, answer timing);
  - bans with appeal.
- **Data location:** database in London (Supabase); files in Cloudflare R2; website on Vercel; email on Brevo; push on Firebase.

## Decisions we need from you (most important first)
1. **Children's data (NDPA s.31).** Most users are 13–19, so many are "children" under the NDPA (under 18).
   - Which parental consent mechanism do we need: a checkbox and statement, a guardian's email or phone confirmation, or another method?
   - What should the minimum age be (we suggest 13)?
   - What about under-13 users (block them, or allow with verifiable consent)?
   - The app already asks for year of birth (required) and sets ads by age.
2. **Cash-prize challenges:** are free-entry, skill-based quiz contests with cash prizes lawful nationally and in Lagos, under the **National Lottery Act 2005**, the **Lagos State Lotteries and Gaming Authority** rules and other states' rules?
   - Do they need a licence or registration?
   - Is there an age limit, and may under-18s win (with a guardian)?
   - What are the tax and withholding obligations, and do we need KYC (NIN) for payouts?
3. **Paid entry** (money or bought XP) is **off**. Confirm it must stay off, or advise what licence would allow it.
4. **Referral cash reward** (₦5,000 after 30 verified friends): is this compliant with the Federal Competition and Consumer Protection Act (FCCPA) and the gaming rules?
5. **Past exam questions and exam-body logos:** do we have the right to use past JAMB/WAEC/NECO questions and show their logos to identify the exams? Do we need licences or permission? We show the disclaimer *"not affiliated with or endorsed by JAMB, WAEC or NECO"* everywhere.
6. **Personalised ads and consent:** should we show Google's consent message (UMP/CMP) to all users under the NDPA, or only to EEA/UK users?
7. **International transfers:** what wording and safeguards do we need for transfers to the UK, US and other countries (NDPA Part VIII)?
8. **Retention periods** in Privacy Policy §10 and the account deletion page.
9. **Refund rules** in Payments §4, the FCCPA position, and **VAT** on digital sales.
10. **Liability cap and disputes:** the amount (Terms §14), and Lagos courts versus mediation or arbitration (Terms §16).
11. **First-day welcome:** new students silently see fewer ads and extra free years in their first hours. Is a general disclosure enough ("ad frequency can vary")?
12. **DPO and NDPC registration:** given the number of data subjects (students), do we need to register with the NDPC as a data controller of major importance, appoint a DPO and file a compliance audit?

## Engineering notes for the reviewer
- Locked content and payments are enforced on the server.
- Rewards from ads are confirmed by Google's signed server callback.
- Bought XP and ad XP can never enter cash-prize contests.
- In the Play build, only Google Play Billing is used for digital goods. Paystack checkout, XP packs and single-item purchases are hidden there.
- Staff actions on money, bans and settings go to an audit log.
