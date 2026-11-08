# Backend plan: Supabase + Neon together (8 Nov 2026)

Owner's ask: the Supabase database is almost full. Use Supabase **and** Neon together:
- users, payments and the other small important data stay on one side;
- bulky data goes to several free Neon projects, so we never hit a limit;
- the app must get **faster, not slower**.

## 1. What is really filling Supabase (measured today)

| Table | Size | Share |
|---|---|---|
| `audit_log` | **312 MB** | 75% |
| `questions` | 45 MB | 11% |
| `ai_chunks` (AI tutor's note search) | 26 MB | 6% |
| everything else (users, payments, tests, challenges, settings…) | ~34 MB | 8% |
| **Total** | **417 MB of 500 MB** | |

- Inside `audit_log`, **144,000 rows (271 MB) are "a question was edited"** records. Each one keeps a full copy of the question before and after the edit (about 2 KB each).
- Bulk jobs (publishing years, tagging topics, imports) edited each of the 32,000 questions about 4–5 times, and every edit saved two full copies.
- Users, payments and practice data together are under 5 MB today.

**So the database is not full of app data. It is full of edit history.**

## 2. Neon free plan (from Neon's docs, 8 Nov 2026)
- 100 projects; **1 GB per project, 20 GB total**.
- 100 compute-hours per project per month; autoscaling up to 2 CU.
- **Scale to zero after 5 minutes idle.** The first query after a sleep takes about 0.3–1 s longer ("cold start").
- **5 GB of network transfer per month** (data leaving Neon).
- Over 1 GB in a project, or 20 GB in total, blocks writes.
- We already have one Neon project, "SolutionTee CBT", in **US East (Ohio)**. It is empty.

## 3. The design

Rule: **everything a student waits for stays on Supabase. Neon holds the history that grows forever.**

### 3.1 What stays on Supabase (the "live" database, kept small and fast)
- Sign-in (Supabase Auth), profiles, staff, bans.
- Payments, entitlements (Premium), XP balances, promo codes, referrals.
- All content and its locks: questions, years, topics, study items, access rules, ads settings.

  These must stay with the server-side locks (Row Level Security, `year_open`, `study_open`) so a free phone never receives locked questions. Moving them would break the locks or force slow calls across two clouds.
- Recent practice: the last **90 days** of test answers and challenge answers, plus every test's score summary (needed for results, history, leaderboards and the AI tutor's "your best score").
- Recent AI chats (last **30 days**), notifications, challenges, the current season's leaderboard.
- The last **30 days** of the audit log.

Target size: about 100–150 MB now, growing slowly. That is a long way under the 500 MB limit, and the smaller tables make every query and backup faster.

### 3.2 What moves to Neon (the "history" databases)
Four Neon projects in **London** (`aws-eu-west-2`, the same city as Supabase, so the two talk over a short distance). Each has one database and one job:

| Neon project | Holds | Why separate |
|---|---|---|
| `st-archive` | Audit log older than 30 days; cron and webhook logs; old payment events (the payment rows themselves stay on Supabase for 6 years, as the law requires) | Written once a night, read only by admins |
| `st-history` | Test answers and challenge answers older than 90 days (question by question) | Grows fastest with users; students rarely open old answer details |
| `st-ai` | AI chats older than 30 days; AI call logs; later, the AI note-search index if it grows | AI text is the next biggest grower |
| `st-analytics` | Daily ad statistics, usage events, admin dashboard numbers | Admin-only reports; never on a student's path |

- **Room to grow:** 4 GB today (1 GB each). When a project reaches about 800 MB, a new one is added for the next period (for example `st-history-2027`). A small table on Supabase (`private.neon_shards`: data kind + date range → project) records where each period lives. This goes up to 20 projects / 20 GB on the free plan.
- **Why not 20 projects now:** each Neon project sleeps after 5 minutes and wakes slowly. Spreading data thin would make reads slower and the system harder to run. We add projects only when one fills up.

### 3.3 How data moves (students never wait for it)
1. **Nightly mover:** a new Edge Function `archive-mover`, run by pg_cron at 02:00 Lagos time. For each kind of data it:
   - reads a batch of old rows from Supabase;
   - writes them to the right Neon project (Neon's HTTPS driver);
   - **checks the row count matches**;
   - only then deletes them from Supabase.

   It runs in small batches and is safe to re-run (each row keeps its id; inserts skip rows already copied).
2. **Reading old history:**
   - **Students:** the normal screens read Supabase only, so nothing gets slower. "Test history" shows every test's score from Supabase. Opening the question-by-question review of a test older than 90 days calls an Edge Function that fetches it from `st-history`. This is the only time a student touches Neon, and only for old tests. It takes about 1 s if Neon was asleep.
   - **Admins:** the admin website (Vercel) reads archives and reports straight from Neon, server-side.
3. **Secrets:** Neon connection strings live only in Supabase Edge Function secrets and Vercel environment variables. They are never in the app, never in git, never in chat.

### 3.4 Stop the audit log growing (step 0, today)
- `audit_row` will save **only the fields that changed**, not two full copies. That is about 100–300 bytes instead of 2 KB.
- Edits that change nothing are skipped. Big system jobs (imports, publishing a whole year, topic tagging) write **one summary row per job** instead of one per question.
- The 30-day window plus the nightly move keeps it small for good.

### 3.5 Speed: why the app gets faster
- Students' screens read only a small, tidy Supabase database. Smaller indexes mean faster queries; nothing a student does waits on Neon (except opening a 90-day-old answer review).
- Backups and restores are quicker; the risk of hitting the 500 MB limit (which blocks writes) goes away.
- Supabase's own limits (egress, database size) stay comfortable. Neon's 5 GB/month transfer is used only by the nightly mover and admin reports.

## 4. Steps (each tested and reported before the next)
1. **Step 0, stop the growth.** New `audit_row` (changed fields only, skip no-op and bulk edits).
2. **Neon setup.** Create the 4 projects in London (`st-archive`, `st-history`, `st-ai`, `st-analytics`) with tables matching Supabase's. Save the connection strings as secrets. Add the `private.neon_shards` table.
3. **Move the old audit log.** Copy all `audit_log` rows older than 30 days to `st-archive`, check counts, then delete them from Supabase and reclaim the space (`VACUUM FULL audit_log`, a few seconds' lock at a quiet time). Expected result: database about 110 MB.
4. **Nightly mover** for audit, answers, AI chats and logs, with an admin page showing what moved and the size of each Neon project.
5. **Old-test review** from `st-history` (app + Edge Function); admin archive viewer.
6. **Watchdog:** a daily check emails or notifies the admin when Supabase passes 70% or any Neon project passes 80%, and suggests the next project.
7. Docs: DECISIONS (D-108), SETUP (Neon section), HANDOFF.

## 5. Risks and how they are handled
- **Data loss while moving:** copy → verify count → delete, inside the mover. Rows are never deleted before they are confirmed in Neon.
- **Neon asleep / unreachable:** the mover retries the next night; students are unaffected; old-test review shows "try again".
- **Cross-database consistency:** only old, finished, never-edited data moves, so there are no updates across two databases.
- **Free-plan changes by Neon:** the data is plain Postgres and can be moved back to Supabase or exported at any time.
