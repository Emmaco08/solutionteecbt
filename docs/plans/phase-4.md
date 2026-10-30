# Phase 4 plan: Study content, Premium, payments and the AI tutor

Approval word at the end: **`PREMIUM APPROVED`**. Scope comes from `docs/PHASES.md` (Phase 4), `docs/SPEC.md` §5, §7–§11, the approved prototype (Study, paywall, checkout, AI, profile screens) and the owner's extra decisions (D-024 redeem codes, D-026 question of the day and leaderboard, D-028–D-033 challenges, anti-cheat, referrals and the winners wall).

Phase 4 is large, so it is built and shown in **five milestones**. Each milestone ends with a commit, a test on the owner's phone and a short report. The next milestone starts without a new approval word unless the owner says stop.

## Milestone 4A: Study tab and Premium gating (no external accounts needed)
- **Study hub** as in the prototype:
  - search, subject filter
  - CMS sections: past questions in study mode, video solutions, topic lessons, lesson notes, novels, syllabus and brochure
  - bookmarks
- **Past questions in study mode:** exam → subject → year grid (locked years shown with a lock). The answer and explanation show at once, with Prev/Next.
- **Lesson notes:** rich text with LaTeX, tables and images, and a text-size control. **Novels:** summary, themes, characters and chapter quizzes. **Syllabus and brochure:** PDF viewer and a topic list. **Videos:** player with quality and speed options, lazy loading, and data saver.
- **Bookmarks** (questions, notes, videos) and **downloads** for offline use. Premium downloads are encrypted on the phone and tied to the account and device; Free content can be cached.
- **Server:**
  - tables for study sections and items (type, free/premium flag, sort, hidden)
  - lesson notes, videos (R2 keys or a video host), novels, documents, bookmarks
  - RLS so a Free phone never receives Premium items
  - signed links for Premium files
  - admin screens to manage all of it
- **Paywall bottom sheet:** gives the reason, the benefits and the plans. It opens from every locked item.
- **Entitlement expiry:**
  - Premium ends exactly at `expires_at`, on the server and in the app.
  - Expired caches are re-checked when the app comes online.
  - Tests are added for this.

## Milestone 4B: SolutionTee AI tutor (needs an NVIDIA API key)
- **Edge Function `ai-chat`:**
  - Verifies the login, then checks and uses up quota in one Postgres step (Free 3 a day, Premium 100, reset at midnight Lagos time).
  - Looks up related material (pgvector + NVIDIA embeddings of syllabus topics, notes and explanations).
  - Calls NVIDIA with streaming, retry with back-off and fallback models.
  - Caches answers for "Explain this question", saves the chat, and rate-limits.
- **App:** chat with streaming answers in Markdown + LaTeX, subject picker, suggested prompts, hint mode, copy, history, new chat, the "x prompts left today" chip, the "quota finished" screen, and a "this answer is wrong" report. "Ask SolutionTee AI to explain" from Review sends the question with it.
- **Admin:** model id, temperature, max tokens, versioned system prompt, limits, AI health.
- **Tests:** AI quota (atomic, resets at midnight Lagos time, never below zero).

## Milestone 4C: Payments (Paystack now; Play Billing when the Play Console is ready)
- A `PaymentProvider` interface with two Flutter flavors:
  - **`direct` (APK from the website):** Paystack. The server starts the payment, checkout opens in an in-app browser, and Premium is granted only after the webhook (HMAC-SHA512 checked) and the verify call. Duplicate webhooks are handled safely.
  - **`play` (Play Store):** Google Play Billing (`in_app_purchase`). The purchase is checked on the server with the Google Play Developer API, then acknowledged. Pending purchases and refunds are handled.
- The remote flag `paystack_in_play_build` defaults to off. The Play build never steers students to the website.
- **Checkout as in the prototype:**
  - "SolutionTee Premium", the access period and the total
  - a redeem or discount code field (direct build only, D-024)
  - a success screen
  - "Redeem a code" on Me for free Premium days
- **Admin:** plans (price, duration, Play product id with a reminder to change the price in Play Console), payments (verification timeline, refund), redeem codes.

## Milestone 4D: Notifications and the Me dashboard
- **FCM push:**
  - Topics: announcements, new questions added, streak reminders, class reminders, challenges.
  - Per-topic opt-out in Settings (the prototype's switches).
  - Admin sends announcements.
- **Notifications screen:** filters, Today and Earlier groups, unread dots, mark all read, tap to open.
- **Me dashboard:** badges, bookmarks, downloads manager, "AI prompts left today", avatar photo (uploaded to R2 after compressing on the phone).

## Milestone 4E: Owner extras from Phase 1 (challenges, question of the day, leaderboard, referrals, winners wall)
- **Question of the day:**
  - It is scheduled and has one attempt.
  - The app shows the percentage who got it right, the question-of-the-day streak and the explanation, with "Ask AI".
- **Leaderboard:** per JAMB year, Nigeria or your state, a podium, your rank pinned. The admin can turn it off, and it is off by default.
- **Challenges and events (D-028 to D-030):**
  - One attempt per student.
  - Ranking is decided on the server: score, then time, then who started earlier.
  - Anti-cheat: leaving the app submits automatically and disqualifies. Copying is blocked, as is screen capture and split screen. Play Integrity checks for rooted phones and emulators. One account per device.
  - Winners are announced at close, then fill a claim form.
- **Referrals (D-031)** with fraud rules, and the **winners wall (D-033)**.
- The Home challenge cards and the "More for you" grid come back.

## Data model changes (summary)
New tables:
- study sections and items, lesson notes, videos, novels, documents
- bookmarks, downloads
- ai chats and messages, ai usage, an embeddings table (pgvector)
- payments, promo codes and redemptions
- push tokens and topic opt-outs, notifications
- question of the day and its attempts, leaderboard snapshots
- challenges with their questions, entries and winners, claims
- referrals, winners-wall posts

RLS on every table, with Premium checked by the server. All admin writes are audited.

## Risks
- **NVIDIA free API:** about 40 requests a minute and unclear terms for production use. The plan uses a queue, back-off, fallback models and caching, and lists a paid provider as a pre-launch item.
- **Play Billing:** it only works on a build uploaded to Play Console (internal testing) with products created. It can't be fully tested over USB until then.
- **Video hosting costs and data use:** decide where videos live (see question 4).
- **Novels:** only content you own or are licensed to publish (legal).
- **Laptop limits:** one heavy process at a time. Edge Functions are deployed to the hosted project, with no local Docker.

## Test plan
- **Unit:** AI quota, entitlement expiry, promo-code rules, Paystack webhook signature and duplicate handling, challenge ranking and tie-breaks.
- **RLS:** a Free user can't read Premium study items, files, locked years or other people's chats and payments.
- **Widget:** paywall, checkout, AI chat (streaming), study mode.
- **On your phone:**
  - study → locked item → paywall → Paystack test payment → Premium unlocks on phone and web
  - AI chat until the quota ends
  - a push notification arrives
  - a challenge with anti-cheat

## Decisions needed from the owner
1. **Video hosting** for video solutions and lessons. Options: Cloudflare R2 (private, signed links, no fees for viewing), YouTube unlisted (free but anyone with the link can watch), or Bunny Stream (paid; adaptive quality). Recommended: R2.
2. **Phase 4 scope:** build the extras (challenges with cash prizes, referrals, leaderboard, question of the day, winners wall) in Phase 4 as milestone 4E, or move them to a later phase.
3. **Plan prices:** still the SAMPLE prices (Monthly ₦1,500 · 3 Months ₦3,500 · Exam Season ₦6,000 to 31 Jul 2027). Payments can be built and tested in Paystack test mode with these and changed later in the admin.
4. **Accounts and keys the owner creates** (steps in SETUP.md when each milestone starts):
   - an NVIDIA API key (4B)
   - a Firebase project with `google-services.json` (4D)
   - Google Play Console and a service account (4C, `play` flavor)
   - Paystack test keys are already set.
