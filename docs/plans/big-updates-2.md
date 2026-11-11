# Plan — three big updates (owner, 2026-11-11)

Owner: "divide it to three … first do the most important one, you build and deploy, I check and I approve, we move to
the next." Each update ends with: deploy the website, a `[release]` app build on /download (direct + Google Play
preview + .aab), a short test guide, then **stop and wait for the owner's approval**.

| # | Update | Why this order |
|---|---|---|
| 1 | **Tutor v2** (owner points 1, 2, 3) | Students pay for it; today a matched student cannot see their tutor. |
| 2 | **Community v2** — X-style app inside the app, friendlier AI check (point 4) | Big UX change, no money flow. |
| 3 | **Game Zone v2** — live matchmaking vs real students for every game, subject combination only, new speed/memory games (point 5) | Largest build; reuses update 1's realtime work. |

---

## Update 1 — Tutor v2 (D-152)

### The flow (student)
1. **Request** (subject from their combination, exam, goals, free times) → straight to **plans** (the admin's plans +
   **Custom**: the student describes what they need; an admin sets a price for that student; the student pays it).
2. **Pay**: Paystack in the direct app (card, transfer, USSD, bank apps); **Google Play Billing** in the Play build
   (each plan gets a Play product id in admin, like Premium); **website**: cbt.solutiontee.com/tutor (email code
   sign-in, choose plan, Paystack) — the Play build follows the admin's payment setting (Google Play / website / both),
   exactly like Premium.
3. **Paid** → super admins and admins get a push + email; the student sees "Your tutor will be assigned within 24 hours"
   (animated waiting state with what happens next).
4. **Assigned** → the tutor gets an email; the student gets a notification and sees the tutor card (photo, name,
   subjects, bio) and the chat is now **with the tutor**.
5. **Chat like WhatsApp**: text, photos (camera/gallery), voice notes (hold to record, slide to cancel, waveform
   playback), files (PDF), Google Meet / WhatsApp call / video links as call cards, references to past questions and
   lesson notes that open in the app. Ticks: sent ✓, read ✓✓ (blue). Live: new messages appear instantly (Supabase
   Realtime), "online" and "typing…". Tutor messages reach the student as push notifications (not email).
6. Plan ends → chat becomes read-only with "Renew plan"; buying again adds days (existing rule).

### Tutor (new staff role `tutor`)
- Super admin invites a tutor in Admin → Staff (role **Tutor**); 2-step sign-in like all staff. The tutor profile
  (photo, subjects, bio) is linked to that login — no separate "create tutor" contacts needed.
- A tutor sees **only** their assigned students: `/admin/tutor` — a real chat app on desktop (list · chat · student
  details, three panes) and mobile (list → chat → details, swipe/back). Unread badges, search, online/typing, ticks,
  voice recorder in the browser, attach photo/PDF, quick buttons: **Send Google Meet link**, **WhatsApp call**,
  **Video link**, **Past question** (search by subject/year/text), **Lesson note**.
- **Student details panel**: name, age, school, state, email, phone, exams, JAMB subject combination, target score,
  dream career, strong and weak topics (from their practice), recent tests and scores, leaderboard position, streak,
  XP, plan and days left, free times and goals.
- Tutors get an email when a student is assigned and when a student writes (at most one email per student every 15
  minutes while unread).
- The tutor role is **not** general staff: it cannot open questions, users, payments or any other admin page or data.

### Admin
- Tutor requests page rebuilt as the same chat app: Waiting for payment · Paid, needs a tutor (top, with a timer
  since payment) · Active · Ended; assign / change tutor; set a custom price; read any chat (safeguarding); join it.
- Plans: Google Play product id field per plan.

### Data / security
- `staff_role` + `tutor`; `private.is_staff()` without roles excludes tutors (so no existing "staff read" opens to
  them); new `private.is_tutor_of(request)`.
- `tutors.user_id` (login), `photo_path`; `tutor_requests`: `plan_id`, `custom_price_kobo`, `custom_note`, `paid_at`,
  `assigned_at`, statuses `new → awaiting_payment → paid → matched → ended / closed`.
- `tutor_messages`: `sender_role` (student / tutor / admin / system), `kind` (text / image / voice / file / link /
  ref), `attachment_path`, `meta` (duration, size, name, mime, link type), `ref` (question / lesson), `read_at`.
- Realtime on `tutor_messages` with RLS (student of the request, its tutor, admins); typing/online via private
  Realtime broadcast channels with RLS on `realtime.messages`.
- Attachments in the private R2 bucket under `t/<request id>/…` (upload link only for people in that chat; signed
  reads only for them; deleted with the account). Voice ≤ 3 min, photos resized, files ≤ 10 MB.
- Payments: Paystack item flow (kind `tutor`, custom price checked on the server); Play: `tutor_plans.play_product_id`
  handled inside `pay_play_confirm` (no Edge Function change), same token-once rules as Premium.

### App
- New dependency: `record` (voice notes); playback with the existing `video_player` (plays audio files).
- Screens: Tutor home (request → plans → pay → waiting → chat), chat screen, tutor profile sheet. Motion: staggered
  entrances, bubble pop-in, send animation, recording pulse, read-tick transition; reduce-motion respected.

### Owner decisions / checks (not blocking the build)
- Tutors will see students' email and phone (owner asked). **Legal:** the Privacy Policy should say that a paid
  tutor sees these details; I add a draft sentence for your lawyer.
- **Safeguarding (students 13–17):** admins can read every tutor chat; tutors see only their students; students can
  report a message. Recommended to keep.
- **Play Console:** create a managed product for each tutor plan and paste its id in Admin → Tutor plans.
- Custom prices are set by an admin per request.

## Update 2 — Community v2 (D-153, after approval of 1)
Own full-screen shell (no app bars): Home (For you / Following), Explore (subjects, trending), Notifications, Profile;
compose as its own page (X-style: avatar, 280+ text, photos, maths preview, subject, @solutiontee); X-style post cells,
threads, reposts/quote, bookmarks, profiles with header, follower lists, pull-to-refresh, haptic likes with animation.
AI check relaxed: greetings and friendly chat allowed; still blocks sexual content, politics, sports betting/gossip,
religion fights, bullying, contacts/links, scams, exam "expo".

## Update 3 — Game Zone v2 (D-154, after approval of 2)
Quick Match (live opponent found automatically; bot if nobody within 15 s), Practice vs AI, Play a friend, and
ranked. Subjects limited to the student's JAMB combination. Games: **JAMB Duel** (live 1v1, same question at the
same time), **Speed Rush** (race track driven by fast correct answers), **Knowledge Survival** (up to 20, lives,
last one standing), **Maths Blitz** (mental maths rounds), **Word War** (synonyms/antonyms/spelling), **Memory
Flash** (formulas, symbols). Server-side scoring, no reward for guessing, speed/accuracy stats per subject.
