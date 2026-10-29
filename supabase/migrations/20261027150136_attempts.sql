-- SolutionTee CBT · Phase 3 · test attempts, marked on the server
-- The app marks a test on the phone (instant, offline) and syncs it later. The server re-marks every
-- attempt from its own answer key, so a modified app cannot post a fake score. Leaderboards use server scores only.

create type public.attempt_status as enum ('submitted', 'abandoned');

create table public.attempts (
  id uuid primary key,                         -- made on the phone (UUID v4) so tests work offline
  user_id uuid not null references auth.users (id) on delete cascade,
  exam_id smallint not null references public.exam_bodies (id),
  mode text not null check (mode in ('full', 'subject', 'year', 'quick', 'topic')),
  config jsonb not null default '{}',          -- subjects, years, timed, minutes (for history display)
  question_ids uuid[] not null check (cardinality(question_ids) between 1 and 400),
  started_at timestamptz not null,
  submitted_at timestamptz not null,
  time_used_s integer not null check (time_used_s between 0 and 36000),
  client_score jsonb,
  server_score jsonb not null,
  status public.attempt_status not null default 'submitted',
  synced_at timestamptz not null default now(),
  check (submitted_at >= started_at)
);
create index attempts_user on public.attempts (user_id, submitted_at desc);
create index attempts_exam on public.attempts (exam_id);

create table public.attempt_answers (
  attempt_id uuid not null references public.attempts (id) on delete cascade,
  question_id uuid not null references public.questions (id) on delete cascade,
  choice text check (choice in ('A', 'B', 'C', 'D', 'E')),
  is_correct boolean not null default false,  -- set by the server, never by the app
  flagged boolean not null default false,
  time_ms integer check (time_ms between 0 and 36000000),
  primary key (attempt_id, question_id)
);
create index attempt_answers_question on public.attempt_answers (question_id);

alter table public.attempts enable row level security;
alter table public.attempt_answers enable row level security;

-- Students read only their own; nobody writes directly (only through submit_attempt). Staff read with 2-step.
create policy "own attempts" on public.attempts for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff(array['super_admin', 'admin']::public.staff_role[]));
create policy "own answers" on public.attempt_answers for select to authenticated
  using (exists (select 1 from public.attempts a where a.id = attempt_id
                 and (a.user_id = (select auth.uid()) or private.is_staff(array['super_admin', 'admin']::public.staff_role[]))));
revoke insert, update, delete on public.attempts, public.attempt_answers from anon, authenticated;
revoke all on public.attempts, public.attempt_answers from anon;

/** Save and mark one finished test. p jsonb:
    { id, exam_id, mode, config, question_ids[], started_at, submitted_at, time_used_s, client_score,
      answers: [{ q: uuid, c: 'A'..'E' | null, f: bool, t: ms }] }
    Idempotent: sending the same attempt again returns the stored server score.
    Score: per subject round(100 * correct / questions), summed (JAMB: 4 subjects → /400). */
create or replace function public.submit_attempt(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_id uuid := (p ->> 'id')::uuid;
  v_exam smallint := (p ->> 'exam_id')::smallint;
  v_qids uuid[];
  v_existing public.attempts;
  v_bad integer;
  v_score jsonb;
begin
  if v_uid is null then raise exception 'not_signed_in' using errcode = '28000'; end if;
  if private.is_banned(v_uid) then raise exception 'banned' using errcode = '42501'; end if;

  select * into v_existing from public.attempts where id = v_id;
  if found then
    if v_existing.user_id <> v_uid then raise exception 'not_allowed' using errcode = '42501'; end if;
    return v_existing.server_score;                       -- already synced: same answer again
  end if;

  select array_agg(x::uuid) into v_qids from jsonb_array_elements_text(p -> 'question_ids') x;
  if v_qids is null or cardinality(v_qids) = 0 or cardinality(v_qids) > 400 then
    raise exception 'bad_questions' using errcode = '22023';
  end if;

  -- Every question must be published, of this exam, and open to this student (same rule as fetch_questions).
  select count(*) into v_bad from unnest(v_qids) qid
  left join public.questions q on q.id = qid and q.exam_id = v_exam and q.status = 'published' and q.deleted_at is null
  where q.id is null or not private.year_open(q.exam_id, q.year, 'cbt');
  if v_bad > 0 then raise exception 'questions_not_allowed' using errcode = '42501'; end if;

  insert into public.attempts (id, user_id, exam_id, mode, config, question_ids, started_at, submitted_at, time_used_s, client_score, server_score)
  values (v_id, v_uid, v_exam, p ->> 'mode', coalesce(p -> 'config', '{}'), v_qids,
          (p ->> 'started_at')::timestamptz, (p ->> 'submitted_at')::timestamptz,
          least(greatest((p ->> 'time_used_s')::integer, 0), 36000), p -> 'client_score', '{}');

  insert into public.attempt_answers (attempt_id, question_id, choice, is_correct, flagged, time_ms)
  select v_id, a.q, nullif(upper(a.c), ''), coalesce(upper(a.c) = q.answer, false), coalesce(a.f, false), a.t
  from jsonb_to_recordset(coalesce(p -> 'answers', '[]')) as a(q uuid, c text, f boolean, t integer)
  join public.questions q on q.id = a.q
  where a.q = any (v_qids)
  on conflict do nothing;

  -- Mark per subject over ALL questions in the test (unanswered = wrong).
  with per as (
    select q.subject_id, count(*) as total,
           count(*) filter (where aa.is_correct) as correct,
           count(*) filter (where aa.choice is not null) as answered
    from unnest(v_qids) qid
    join public.questions q on q.id = qid
    left join public.attempt_answers aa on aa.attempt_id = v_id and aa.question_id = qid
    group by q.subject_id)
  select jsonb_build_object(
    'questions', sum(total), 'answered', sum(answered), 'correct', sum(correct),
    'total', sum(round(100.0 * correct / total)),
    'max', count(*) * 100,
    'subjects', jsonb_agg(jsonb_build_object('subject_id', subject_id, 'total', total, 'correct', correct,
                          'answered', answered, 'score', round(100.0 * correct / total)) order by subject_id))
  into v_score from per;

  update public.attempts set server_score = v_score where id = v_id;
  return v_score;
end;
$$;

revoke execute on function public.submit_attempt from public, anon;
grant execute on function public.submit_attempt to authenticated;

-- Audit is not needed for attempts (student data, high volume); the attempt row itself is the record.
