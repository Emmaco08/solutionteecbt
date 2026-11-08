# Google Play Console — what to declare for SolutionTee CBT

**Prepared 8 November 2026 for the owner and lawyer.** This is the content to enter in Play Console → App content, and on the store listing, for the **Play Store version** (`com.solutiontee.cbt`, Play build).

It describes the app's features as they are today:
- CBT practice, study content, AI tutor with voice and photos;
- challenges with prizes, referrals, XP;
- AdMob ads (banners, native, interstitial, app-open, rewarded, rewarded interstitial) and brand campaigns;
- Premium through Play Billing;
- push notifications, news, custom exam.

Items marked **[CONFIRM]** depend on the lawyer's answers in `00-README-for-lawyer.md`.

---

## 1. Privacy policy URL
`https://solutiontee.com/privacy` **[CONFIRM: publish `privacy-policy.md` there before submitting]**

## 2. App access (for Google's reviewers)
- "All or some functionality is restricted": **Yes** (sign-in required).
- Provide a **test account** (email + password) with a **Free** profile, and a second one with **Premium**, plus these steps: "Sign in → Test → Quick test; AI Tutor → ask 'Explain photosynthesis'; Study → Lesson notes."
- Sign-in codes are emailed: give reviewers an account that uses a password, or a fixed test OTP. **[CONFIRM: create reviewer accounts]**

## 3. Ads
**Contains ads: Yes** (Google AdMob; also own sponsored campaigns labelled "Ad").

## 4. Content rating (IARC questionnaire)
- **Category:** Reference, News, or Educational → choose **Education**.
- Violence, sexuality, language, controlled substances: **No**.
- **User interaction:**
  - users can share info? **No**, there is no chat between users;
  - the AI tutor generates content, which is **moderated** (answers education only and refuses unsafe requests).
- **Shares user location:** No.
- **Digital purchases:** Yes.
- **Gambling / simulated gambling:** **No.** Challenges are skill-based quizzes with free entry. **[CONFIRM: if paid entry is ever enabled, re-answer, and do not enable it in the Play build without Play approval.]**
- **Expected rating:** Everyone / PEGI 3 or 7, with "In-app purchases" and "Contains ads".

## 5. Target audience and content
- **Target age groups:** **13–15, 16–17, 18 and over**.
- **[CONFIRM with counsel.]** Choosing **under 13** puts the app in the **Families programme**, which requires Families-certified ad SDKs only, a teacher-approved-style design and stricter data rules.

  **Recommendation:** target **13+** (the users are secondary-school students). Keep the in-app age check: under-13s who sign up still get child-directed ads.
- **Appeals to children?** No (an exam-preparation tool for teenagers and adults).
- Because 13–17 is included, Play's policies for teen audiences apply:
  - no personalised ads to under-18s (done: the app sends non-personalised requests and the "teen" setting);
  - ads must be suitable (max ad content rating: G for under-18, T for adults; set in the app).

## 6. News app declaration
"Is your app a news app?" → **No.** The app is an educational app with a small News section about exams.

## 7. Data safety form

**Data is encrypted in transit:** Yes.
**Users can request that data is deleted:** Yes. Account deletion URL: `https://solutiontee.com/delete-account` (from `account-deletion.md`).
**Independent security review:** No.

| Data type (Play category) | Collected | Shared* | Optional? | Purposes |
|---|---|---|---|---|
| **Personal info → Name** | Yes | No | Required | App functionality, Account management |
| **Personal info → Email address** | Yes | No | Required | App functionality, Account management, Developer communications |
| **Personal info → Phone number** | Yes | No | Optional | Account management, Fraud prevention (prize and referral verification) |
| **Personal info → Other info** (state, school, birth year, exam subjects) | Yes | No | Required (birth year, state); optional (school) | App functionality, Personalisation, Advertising (age group only) |
| **Personal info → User IDs** | Yes | No | Required | App functionality, Account management, Fraud prevention |
| **Financial info → Purchase history** | Yes | No | Optional | App functionality |
| **Financial info → Other financial info** (prize payout bank account) | Yes | Yes (Paystack, to send the transfer) | Optional | App functionality |
| **Photos and videos → Photos** | Yes | Yes (AI provider processes question photos) | Optional | App functionality |
| **Audio → Voice or sound recordings** | **No** (speech is turned into text on the device; the app receives text only) | — | — | — |
| **Messages → Other in-app messages** (AI tutor chats) | Yes | Yes (AI provider processes them) | Optional | App functionality |
| **App activity → App interactions** | Yes | No | Required | App functionality, Analytics, Fraud prevention |
| **App activity → Other user-generated content** (answers, reports, appeals) | Yes | No | Optional | App functionality |
| **App info and performance → Crash logs / Diagnostics** | **[CONFIRM: No crash SDK today; server logs only]** | — | — | — |
| **Device or other IDs** (hashed Android ID and DRM ID; FCM token; advertising ID) | Yes | Yes (advertising ID with Google AdMob; token with Firebase) | Required | Fraud prevention, Security, Advertising or marketing, App functionality (notifications) |
| Location, Contacts, Calendar, Health, Files, Web browsing | **No** | — | — | — |

\* Play counts transfers to **service providers** acting on our behalf as **not "shared"**, for example Supabase, Cloudflare, Brevo and Paystack used as processors.
- **AdMob:** Google requires apps to declare data collected by the AdMob SDK (advertising ID, approximate IP-based location, app interactions, diagnostics) as **collected and shared for Advertising**. Use Google's AdMob data disclosure guide when filling this in.
- **AI provider (NVIDIA):** acts as a service provider. Counsel to confirm "not shared". **[CONFIRM]**

## 8. Permissions (Play build)
| Permission | Why | Declaration needed |
|---|---|---|
| INTERNET | Everything | None |
| RECORD_AUDIO | Voice questions in the AI tutor, only when the student taps the mic | None (runtime prompt), but mention it in the privacy policy (done) |
| DETECT_SCREEN_CAPTURE / DETECT_SCREEN_RECORDING | Fair play in exams and challenges (Android 14/15) | None (normal permissions) |
| AD_ID (added by Google Mobile Ads) | Ads | Answer "Yes, uses advertising ID" (Advertising, Fraud prevention) |
| POST_NOTIFICATIONS (Android 13+, added by the notifications library) | Reminders and challenge alerts | None (runtime prompt) |

**Not in the Play build:** REQUEST_INSTALL_PACKAGES. The Play build updates through Google Play; self-update is only in the website build. **[Engineering confirmed: the permission is only in the `direct` flavour manifest.]**

## 9. Financial features
"Does your app provide financial features?" → **No** (no loans, banking or payments between users). Prize payouts are a contest feature, not a financial service.

## 10. Payments policy (important)
- In the Play build, **Premium is sold only through Google Play Billing**. Paystack, XP packs and "pay for this item" are **hidden in the Play build**. Engineering changed this on 8 November 2026 for XP packs and single items.
- Rewarded ads that unlock content for a while are allowed.
- **[CONFIRM: Premium products in Play Console: create in-app products for each plan; set prices in Naira.]**

## 11. Real-money contests (Challenges with cash prizes)
- Play allows **skill-based contests with free entry and real-money prizes**, if the app follows local law and the contest rules are published.
- Rules: `contest-and-prize-rules.md`, linked in the app and on the store listing.
- **Paid entry must stay off in the Play build** (flag `paid_events_in_play_build` = off).
- XP entry fees use **earned XP only** for cash challenges (never bought).
- **[CONFIRM: lawyer's opinion under the National Lottery Act and state law before enabling cash prizes in the Play build.]**

## 12. Store listing text (must include)
- Short description (80 chars):

  > JAMB, WAEC & NECO CBT practice with past questions, AI tutor and mock exams.

- Disclaimer in the full description:

  > SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.

- Do not use JAMB, WAEC or NECO logos as the app icon or as the main graphic. Logos may appear only to identify the exam inside the app. **[CONFIRM permission to show exam-body logos at all.]**
- Mention: contains ads; in-app purchases; Premium removes ads.

## 13. Government / impersonation
Answer "No" to "government app". The disclaimer above avoids the impersonation and deceptive-behaviour policy.

## 14. Health, VPN, accessibility, background location
Not applicable.

## 15. Families / Teacher Approved
Not applying (target 13+), unless counsel decides otherwise.

## 16. Before submitting: checklist
- [ ] Privacy policy, Terms and Contest rules published on solutiontee.com and linked in the app (About / Settings).
- [ ] Account deletion page published.
- [ ] Reviewer test accounts created.
- [ ] Play in-app products created for each Premium plan.
- [ ] AdMob app linked to the Play listing; `app-ads.txt` on solutiontee.com (`google.com, pub-2578359096210288, DIRECT, f08c47fec0942fa0`).
- [ ] AdMob Test mode **off** only after the Play listing is live.
- [ ] Data safety form filled from section 7.
- [ ] Target audience 13+ set; content rating questionnaire done.
