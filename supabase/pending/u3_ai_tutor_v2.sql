-- U3 AI tutor v2 (docs/plans/u3-ai-tutor.md, D-096).
-- The tutor reads questions only through ai_question_for_me / ai_pick, which run AS THE STUDENT (their login), so
-- the plan's year rules apply. Nothing here returns another student's data or a locked answer.

alter table public.ai_chats add column if not exists summary text, add column if not exists summary_upto timestamptz;
alter table public.ai_messages add column if not exists card jsonb;

create table if not exists public.ai_tools_log (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  chat_id uuid references public.ai_chats (id) on delete set null,
  tool text not null,
  args jsonb not null default '{}',
  ok boolean not null,
  ms integer,
  note text,
  at timestamptz not null default now()
);
create index if not exists ai_tools_log_at on public.ai_tools_log (at desc);
alter table public.ai_tools_log enable row level security;
drop policy if exists "admins read" on public.ai_tools_log;
create policy "admins read" on public.ai_tools_log for select to authenticated using (private.is_staff(array['super_admin', 'admin']::public.staff_role[]));

-- ------------------------------------------------------------------ run as the student
-- A question for the tutor to explain. Allowed when it is in the student's own finished test, its year is open to
-- their plan (past-questions rule), or it is today's question of the day. Today's question comes WITHOUT its answer
-- until the student has answered it.
create or replace function public.ai_question_for_me(p_id uuid)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare
  v_uid uuid := (select auth.uid());
  q record;
  v_today uuid;
  v_answered boolean;
  v_why text;
begin
  if v_uid is null or private.is_banned(v_uid) then return jsonb_build_object('ok', false, 'why', 'login'); end if;
  select x.id, x.body, x.options, x.answer, x.explanation, x.year, x.exam_id, x.subject_id, x.image_path, x.passage_id,
         e.code as exam, s.name as subject, t.name as topic, p.body as passage
    into q
  from public.questions x
  join public.exam_bodies e on e.id = x.exam_id
  left join public.subjects s on s.id = x.subject_id
  left join public.topics t on t.id = x.topic_id
  left join public.passages p on p.id = x.passage_id
  where x.id = p_id and x.deleted_at is null and x.status = 'published';
  if q.id is null then return jsonb_build_object('ok', false, 'why', 'missing'); end if;

  select d.question_id into v_today from public.qotd d where d.id = private.qotd_for_user(v_uid, private.qotd_day());
  if v_today = p_id then
    v_answered := exists (select 1 from public.qotd_answers a where a.user_id = v_uid and a.day = private.qotd_day());
    v_why := case when v_answered then 'qotd' else 'qotd_unanswered' end;
  elsif exists (select 1 from public.attempts a where a.user_id = v_uid and a.status = 'submitted' and p_id = any (a.question_ids)) then
    v_why := 'my_test';
  elsif private.year_open(q.exam_id, q.year, 'pq') then
    v_why := 'open';
  else
    return jsonb_build_object('ok', false, 'why', 'locked');
  end if;

  return jsonb_build_object('ok', true, 'why', v_why, 'question', jsonb_build_object(
    'id', q.id, 'body', q.body, 'options', q.options, 'year', q.year, 'exam', q.exam, 'subject', q.subject, 'topic', q.topic,
    'subject_id', q.subject_id, 'has_image', q.image_path is not null, 'passage', left(q.passage, 4000),
    'answer', case when v_why = 'qotd_unanswered' then null else q.answer end,
    'explanation', case when v_why = 'qotd_unanswered' then null else q.explanation end));
end;
$$;

-- Topics of a subject that match the student's words ("motion", "organic chemistry"), best first.
create or replace function private.ai_topics_like(p_subject smallint, p_q text)
returns integer[] language sql stable security definer set search_path to '' as $$
  with w as (select lower(trim(p_q)) as q),
  words as (select x from w, regexp_split_to_table((select q from w), '[^a-z0-9]+') x where length(x) >= 4)
  select coalesce(array_agg(id order by score desc, sort), '{}') from (
    select t.id, t.sort,
           (case when lower(t.name) like '%' || (select q from w) || '%' then 10 else 0 end)
           + (select count(*) from words where lower(t.name) like '%' || words.x || '%') as score
    from public.topics t
    where t.subject_id = p_subject and coalesce(trim(p_q), '') <> ''
  ) s where score > 0;
$$;

-- Questions the student may practise (open years for their plan), for a test or a chat quiz.
-- p_for 'test' → ids (the app builds the CBT); 'quiz' → questions WITHOUT answers (no passages, no pictures).
create or replace function public.ai_pick(p_subject smallint, p_topic text default null, p_difficulty text default null,
                                          p_count integer default 10, p_for text default 'test')
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_exams smallint[];
  v_topics integer[];
  v_open record;
  v_count integer := least(greatest(coalesce(p_count, 10), 1), case when p_for = 'quiz' then 5 else 60 end);
  v_pairs text[] := '{}';
  v_out jsonb;
begin
  if v_uid is null or private.is_banned(v_uid) then return jsonb_build_object('ok', false, 'why', 'login'); end if;
  -- The student's exams first (JAMB if none), then any active exam.
  select array_agg(e.id order by coalesce(array_position(p.target_exams, e.code), 99), e.sort) into v_exams
  from public.exam_bodies e left join public.profiles p on p.id = v_uid where e.is_active;
  -- Open (exam, year) pairs for this subject, checked once each.
  for v_open in
    select distinct y.exam_id, y.year from public.exam_years y
    where y.subject_id = p_subject and y.status = 'published' and y.exam_id = any (v_exams)
  loop
    if private.year_open(v_open.exam_id, v_open.year, 'cbt') then v_pairs := v_pairs || (v_open.exam_id || ':' || v_open.year); end if;
  end loop;
  if cardinality(v_pairs) = 0 then return jsonb_build_object('ok', false, 'why', 'no_open_years'); end if;
  v_topics := case when coalesce(trim(p_topic), '') = '' then null else private.ai_topics_like(p_subject, p_topic) end;
  if v_topics is not null and cardinality(v_topics) = 0 then return jsonb_build_object('ok', false, 'why', 'no_topic'); end if;

  with pool as (
    select x.id, x.exam_id, x.year, x.body, x.options, x.topic_id, x.difficulty,
           array_position(v_exams, x.exam_id) as exam_rank
    from public.questions x
    where x.subject_id = p_subject and x.status = 'published' and x.deleted_at is null
      and (x.exam_id || ':' || x.year) = any (v_pairs)
      and (v_topics is null or x.topic_id = any (v_topics))
      and (p_difficulty is null or p_difficulty not in ('easy', 'medium', 'hard') or x.difficulty::text = p_difficulty)
      and (p_for <> 'quiz' or (x.passage_id is null and x.image_path is null))
  ),
  best_exam as (select exam_id from pool group by exam_id order by min(exam_rank) limit 1),
  picked as (select * from pool where exam_id = (select exam_id from best_exam) order by random() limit v_count)
  select jsonb_build_object(
    'ok', count(*) > 0, 'why', case when count(*) = 0 then 'none' end,
    'exam_id', min(exam_id), 'exam', (select e.code from public.exam_bodies e where e.id = min(picked.exam_id)),
    'subject_id', p_subject, 'subject', (select s.name from public.subjects s where s.id = p_subject),
    'topics', (select coalesce(jsonb_agg(distinct t.name), '[]') from public.topics t where t.id in (select topic_id from picked)),
    'years', coalesce(jsonb_agg(distinct year), '[]'),
    'available', (select count(*) from pool where exam_id = (select exam_id from best_exam)),
    'ids', case when p_for = 'test' then coalesce(jsonb_agg(id), '[]') end,
    'questions', case when p_for = 'quiz' then coalesce(jsonb_agg(jsonb_build_object('id', id, 'body', body, 'options', options, 'year', year)), '[]') end)
    into v_out from picked;
  return v_out;
end;
$$;

-- Marks one chat-quiz answer (no prompt used). Only for questions the student may practise.
create or replace function public.ai_quiz_check(p_id uuid, p_choice text)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare v_uid uuid := (select auth.uid()); q record;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'Not allowed' using errcode = '42501'; end if;
  select x.answer, x.explanation, x.exam_id, x.year into q from public.questions x
  where x.id = p_id and x.status = 'published' and x.deleted_at is null;
  if q.answer is null or not (private.year_open(q.exam_id, q.year, 'cbt') or private.year_open(q.exam_id, q.year, 'pq')) then
    return jsonb_build_object('ok', false);
  end if;
  return jsonb_build_object('ok', true, 'correct', upper(trim(coalesce(p_choice, ''))) = upper(q.answer), 'answer', q.answer, 'explanation', q.explanation);
end;
$$;

-- ------------------------------------------------------------------ service role only (the Edge Function)
-- The student's weakest topics from their own finished tests (last 120 days, at least 3 answers per topic).
create or replace function public.ai_weak_topics(p_uid uuid, p_limit integer default 5)
returns jsonb language sql stable security definer set search_path to '' as $$
  select coalesce(jsonb_agg(w order by w.pct, w.answered desc), '[]') from (
    select s.name as subject, s.id as subject_id, t.name as topic, count(*) as answered,
           count(*) filter (where aa.is_correct) as correct,
           round(100.0 * count(*) filter (where aa.is_correct) / count(*)) as pct
    from public.attempts a
    join public.attempt_answers aa on aa.attempt_id = a.id and aa.choice is not null
    join public.questions q on q.id = aa.question_id
    join public.topics t on t.id = q.topic_id
    join public.subjects s on s.id = q.subject_id
    where a.user_id = p_uid and a.status = 'submitted' and a.submitted_at > now() - interval '120 days'
    group by s.name, s.id, t.name
    having count(*) >= 3
    order by pct, count(*) desc
    limit least(greatest(coalesce(p_limit, 5), 1), 20)
  ) w;
$$;

-- What the tutor may know about the student: their own profile, plan, streak, scores and weak topics. Free text
-- (the name) is cleaned so it cannot carry instructions.
create or replace function public.ai_student_context(p_uid uuid)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare p record; s record; v_scores jsonb;
begin
  select * into p from public.profiles where id = p_uid;
  if p.id is null then return '{}'::jsonb; end if;
  select * into s from private.streak(p_uid);
  select coalesce(jsonb_agg(x order by x.tests desc), '[]') into v_scores from (
    select sub.name as subject, count(*) as tests,
           (array_agg((sc ->> 'score')::int order by a.submitted_at desc))[1] as latest,
           max((sc ->> 'score')::int) as best
    from public.attempts a
    cross join lateral jsonb_array_elements(coalesce(a.server_score -> 'subjects', '[]')) sc
    join public.subjects sub on sub.id = (sc ->> 'subject_id')::smallint
    where a.user_id = p_uid and a.status = 'submitted' and a.server_score is not null
    group by sub.name
    limit 8
  ) x;
  return jsonb_build_object(
    'first_name', left(regexp_replace(split_part(coalesce(p.full_name, ''), ' ', 1), '[^[:alpha:]''-]', '', 'g'), 30),
    'exams', coalesce(p.target_exams, '{}'),
    'subjects', (select coalesce(jsonb_agg(sub.name order by array_position(p.jamb_subjects, sub.code)), '[]')
                 from public.subjects sub where sub.code = any (coalesce(p.jamb_subjects, '{}'))),
    'target_score', p.target_score,
    'plan', case when private.has_premium(p_uid) then 'Premium' else 'Free' end,
    'streak_days', s.current_days, 'practised_today', s.today_done,
    'scores', v_scores,
    'weak_topics', public.ai_weak_topics(p_uid, 3));
end;
$$;

revoke execute on function public.ai_weak_topics(uuid, integer) from public, anon, authenticated;
revoke execute on function public.ai_student_context(uuid) from public, anon, authenticated;
grant execute on function public.ai_weak_topics(uuid, integer) to service_role;
grant execute on function public.ai_student_context(uuid) to service_role;
revoke execute on function private.ai_topics_like(smallint, text) from public, anon, authenticated;
revoke execute on function public.ai_question_for_me(uuid) from public, anon;
revoke execute on function public.ai_pick(smallint, text, text, integer, text) from public, anon;
revoke execute on function public.ai_quiz_check(uuid, text) from public, anon;
grant execute on function public.ai_question_for_me(uuid) to authenticated;
grant execute on function public.ai_pick(smallint, text, text, integer, text) to authenticated;
grant execute on function public.ai_quiz_check(uuid, text) to authenticated;
