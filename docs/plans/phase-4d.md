# Milestone 4D: Notifications and the Me dashboard (detailed plan)

Part of Phase 4 (`docs/plans/phase-4.md`). Approval for the phase stays `PREMIUM APPROVED`. I stop at the end of 4D for the owner's review.

## Goal
Students get useful push notifications they can switch off per topic, an in-app Notifications screen, and a fuller Me screen (badges, bookmarks, downloads, AI prompts left, profile photo), all as in the approved prototype.

## Scope
1. **Push notifications (Firebase Cloud Messaging)**
   - Topics, each with its own switch in Settings: **Announcements**, **New questions added**, **Streak reminders**, **Class reminders** (used in Phase 5), **Challenges** (used in 4E).
   - Broadcasts go to FCM topics (cheap, no list of phones needed). Personal messages (streak reminder, "payment received") go to the student's own phones.
   - The app asks for notification permission at a friendly moment (after the first finished test), not at start-up. Android 13+ needs it.
   - Tapping a notification opens the right screen (news item, Study, a test setup, the Notifications screen).
2. **Notifications screen** (prototype `notifications`): All / Challenges / Classes / Updates filters, Today and Earlier groups, unread dots, "Mark all read", tap to open. The bell on Home shows the unread count. Works offline from the last copy.
3. **Automatic messages**
   - Admin publishes a news post marked "Send as notification" → Announcements.
   - Admin publishes a new exam year → "JAMB 2026 Physics is now available" (New questions added).
   - Streak reminder: once a day at **7:00 pm Lagos** (admin can change), only to students with a streak of 2+ days who have not practised today.
   - Premium given (payment or code) → a personal "You are now Premium" message.
4. **Admin → Notifications**: write a message (title, text, where it opens, topic, who gets it: everyone / Free / Premium / only my test phones), send now or schedule, see the history with how many were sent.
5. **Me dashboard** (prototype `profile`)
   - **Badges** (the 8 from the approved design): 7-day streak, First 250+, Speedster, 100 correct, Score 300, Night owl, Bookworm, Full mock. Worked out on the server from the student's synced tests and study progress.
   - Rows: Test history, Bookmarks, Downloads, **AI prompts left today: N**, Redeem a code, Settings, Help. (My classes, Invite friends, My winnings and Winners wall come with Phase 5 / 4E.)
   - **Profile photo**: pick or take a photo, crop to a square, shrink on the phone (512 px WebP), upload to the private R2 bucket under `a/`; shown through a short signed link. Remove photo.

**Not in 4D:** class reminders content (Phase 5), challenge notifications content (4E), email notifications.

## How it works
- **Sending** happens only in a Supabase Edge Function `push` with the Firebase service account (secret `FIREBASE_SERVICE_ACCOUNT`). It signs in to Google (same RS256 helper as Google Play in 4C) and calls the FCM HTTP v1 API.
- **Scheduling:** `pg_cron` runs every 5 minutes and calls `push` for messages that are due (scheduled admin messages, the daily streak run). Each message is sent once (a `sent_at` lock).
- **Opt-out:** the app subscribes and unsubscribes FCM topics from the Settings switches, and saves the same choices on the server (`notification_prefs`), so personal messages respect them too and a new phone gets the same settings.
- **Tokens:** each phone saves its FCM token (`push_tokens`, own rows only). Old tokens that FCM rejects are removed.

## Data model changes (one migration)
- `push_tokens` (user, token, platform, app version, last seen): students manage their own; server reads.
- `notification_prefs` (user, topic, on/off).
- `notifications` (title, body, topic/category, link, audience, scheduled_at, sent_at, sent_count, created_by) and `notification_reads` (user, notification). Students read the published ones meant for them and mark their own reads.
- Functions: `my_notifications()`, `mark_notifications_read()`, `my_badges()`, `my_dashboard()` (AI left, counts), admin compose/list; server-only `push_due()`.
- `news_posts.notify` and an exam-year publish hook create announcement rows automatically.

## What the owner must do (never paste keys in chat)
1. Create a Firebase project (free): console.firebase.google.com → Add project "SolutionTee CBT" → Add app → Android → package `com.solutiontee.cbt`.
2. Download `google-services.json`. Put it in the GitHub secret `GOOGLE_SERVICES_JSON` (for the automatic APK builds) and on the laptop at `apps/mobile/android/app/google-services.json`. Steps in SETUP §15.
3. Firebase → Project settings → Service accounts → Generate new private key → paste the whole JSON into Supabase → Edge Functions → Secrets as `FIREBASE_SERVICE_ACCOUNT`.

Until then everything except actually delivering a push can be built and tested; the app runs without Firebase (push is simply off).

## Risks
- **Delivery can only be tested on a real phone** with a build that includes `google-services.json`.
- **Many Android phones (Tecno, Infinix, itel) stop apps in the background** and may delay pushes. The in-app Notifications screen still shows everything when the app opens.
- **App size:** Firebase Messaging adds about 1–2 MB.
- Streak reminders must not feel like spam: at most one a day, only when it helps, and easy to switch off.

## Test plan
- **SQL:** students see only messages meant for them (Free/Premium audience), read marks are their own, cannot read other students' tokens or prefs, cannot send; badges from sample attempts; `push_due()` sends each message once; streak picks the right students and skips opted-out ones.
- **Unit:** FCM message building (topic vs token, Android channel, link data), badge rules.
- **App:** Notifications screen (groups, filters, mark all read, empty and offline states), Settings switches, Me rows and badges, photo picker flow (widget tests). `flutter analyze`, `flutter test`.
- **Live (after Firebase):** admin sends a test message to "only my test phones" → it arrives on the owner's phone and opens the right screen; switch a topic off → the next one on that topic does not arrive.
