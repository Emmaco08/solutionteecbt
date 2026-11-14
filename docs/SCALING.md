# Scaling SolutionTee for busy times (14 Nov 2026)

What happens when very many students are on at once (exam season, a big challenge, a push notification to everyone),
what is already done, and the decisions that are yours.

## Where the limits are

| Part | Today | What limits it |
|---|---|---|
| Database (Supabase Postgres, London) | Small compute: about 1 GB memory, **60 connections** | Slow queries hold connections; when all 60 are busy, new requests wait and then fail |
| Supabase API (PostgREST, Auth, Storage) | Pooled in front of the database | Follows the database |
| Edge Functions (AI tutor, community AI, Paystack) | Scale out by themselves | NVIDIA AI rate limits; Paystack |
| Website + admin (Vercel) | Scales out by itself | Plan limits (function time, bandwidth) |
| App | Offline-first: downloaded tests, saved answers and bookmarks work without the server | Nothing on the server while offline |

The database is the part to protect: every app screen ends up there.

## Done today

1. **Staff security checks run once per query instead of once per row** (D-161). The admin question bank went from
   11.6 s to 0.08 s, and every staff-only table is protected from the same slowdown.
2. **`my_open_years` is 20–30× faster** (1.5–2 s to about 60 ms). The app calls this to know which exam years a
   student may open. It used to run the full permission check around 1,150 times per call. Now the student's plan,
   rules and bans are read once. Tested against the old version for free, premium, ad-unlock, staff, signed-out and
   random students: 0 differences.
3. **87 missing foreign-key indexes added, 4 duplicate indexes removed.** Joins and deletes stay fast as tables grow,
   and writes don't update useless copies.
4. **Scheduled-job history trimmed every night to 3 days.** Six jobs run every minute, adding about 9,000 rows a day
   with nothing ever deleted.
5. **The app is gentler on the server:**
   - Maintenance, update rules and the "staff can still use the app" pass come in one small call (`app_gate`), made at
     start, on resume and every 5 minutes.
   - The offline check only contacts the server when the phone's network changes.
   - Screens retry by themselves only when the internet comes back, not in a loop.
6. **Maintenance mode for the whole app** (Admin → Flags & settings). If the server is in trouble, students see a calm
   screen instead of errors, staff can keep testing, and the app comes back by itself when you switch it off.

Already in place from earlier work:
- Downloaded question packs and offline tests.
- Cached settings, tabs and onboarding.
- Rate limits on OTP, logins and AI calls.
- AI quota checked inside Postgres.
- Paystack webhooks that can safely run more than once.
- Small payloads (questions are sent once, then kept on the phone).

## Your decisions (pricing)

1. **Database compute size: the biggest single lever.** On the Supabase dashboard (Project → Settings → Compute and
   Disk), a bigger compute gives more memory and more connections. Check the Supabase pricing page for today's prices;
   roughly:
   - **Small:** 2 GB memory, about 90 connections.
   - **Medium:** 4 GB memory, about 120 connections.
   - **Large:** 8 GB memory, about 160 connections.

   My suggestion:
   - Move to **Small** before the first big marketing push.
   - Move to **Medium** a week before the UTME period or any challenge you expect thousands to join.
   - You can upgrade the day before and come back down afterwards. It takes a few minutes of downtime, so do it at
     night and use Maintenance mode.
2. **Supabase plan:** compute upgrades need the Pro plan (check Billing in the dashboard). Pro includes daily
   backups; add Point-in-Time Recovery only if you want to restore to any minute.
3. **Vercel plan:** Pro if the website or admin hits Hobby limits (Vercel emails you first).
4. **NVIDIA AI:** busy times mean more AI tutor questions. The per-student daily limits in Admin keep cost and rate
   limits under control.

## On the day of a big event

1. Upgrade the compute the day before (see above).
2. Download packs: remind students in a push to open the app once on Wi-Fi so their tests are on the phone.
3. Watch Supabase → Reports → Database (CPU, connections) and Admin → dashboard.
4. If things go wrong, switch on **Maintenance mode** with a message and a "Back by" time, fix it, then switch it off.

## What I watch

- Slow queries: `pg_stat_statements` (the slowest list is in this session's notes and re-checked after each big
  change).
- Supabase advisors (performance and security), run after every database change.
- New policies must use the `(select private.is_staff())` form, never a bare call (D-161).
