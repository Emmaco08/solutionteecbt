-- SolutionTee CBT · Milestone 4E1 · question of the day + leaderboard (docs/plans/phase-4e.md, D-026, D-066)
-- Everything is marked and ranked on the server. A student never receives the answer before answering, and the
-- question of the day always comes from a year that Free students can open (so a Free phone never gets locked content).

-- ================================================================ helpers
/** private.year_open for a given plan ('free' or 'premium'), independent of who is calling. */
create or replace function private.tier_year_open(p_tier text, p_exam smallint, p_year smallint, p_kind text default 'cbt')
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  v_rules jsonb; v_code text; v_exam_rule jsonb; v_rule jsonb; v_which text; v_years smallint[];
begin
  select r.rules into v_rules from public.access_rules r where r.tier = p_tier;
  if v_rules is null then return false; end if;
  select lower(e.code) into v_code from public.exam_bodies e where e.id = p_exam and e.is_active;
  if v_code is null then return false; end if;
  v_exam_rule := v_rules -> v_code;
  if v_exam_rule is null or v_exam_rule in ('0'::jsonb, 'false'::jsonb) then return false; end if;
  v_rule := case when p_kind = 'pq' then v_rules -> 'pq' else v_exam_rule end;
  if v_rule is null or v_rule in ('0'::jsonb, 'false'::jsonb) then return false; end if;
  if v_rule = '"all"'::jsonb or v_rule = 'true'::jsonb then return true; end if;
  if jsonb_typeof(v_rule) <> 'number' then return false; end if;
  v_which := coalesce(v_rules ->> 'which', 'oldest');
  select array_agg(t.year order by case when v_which = 'newest' then -t.year else t.year end) into v_years
  from (select distinct y.year from public.exam_years y where y.exam_id = p_exam and y.status = 'published') t;
  return p_year = any (v_years[1:(v_rule::text)::int]);
end;
$$;

/** Today in Lagos. The question of the day changes at midnight Lagos time. */
create or replace function private.lagos_today() returns date language sql stable set search_path = '' as $$
  select (now() at time zone 'Africa/Lagos')::date;
$$;

-- ================================================================ question of the day
create table public.qotd (
  id uuid primary key default gen_random_uuid(),
  day date not null unique,
  question_id uuid not null references public.questions (id) on delete restrict,
  source text not null default 'admin' check (source in ('admin', 'auto')),
  created_by uuid default auth.uid() references auth.users (id),
  created_at timestamptz not null default now()
);

create table public.qotd_answers (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null references public.qotd (day) on delete restrict on update restrict,
  choice text not null check (choice in ('A', 'B', 'C', 'D', 'E')),
  correct boolean not null,
  answered_at timestamptz not null default now(),
  primary key (user_id, day)
);
create index qotd_answers_day on public.qotd_answers (day);

alter table public.qotd enable row level security;
alter table public.qotd_answers enable row level security;
create policy "staff read" on public.qotd for select to authenticated using (private.is_staff());
create policy "content edit" on public.qotd for all to authenticated
  using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));
create policy "own answers" on public.qotd_answers for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff());
revoke all on public.qotd, public.qotd_answers from anon;
revoke insert, update, delete on public.qotd_answers from authenticated;
create trigger qotd_audit after insert or update or delete on public.qotd for each row execute function private.audit_row();

/** The admin may schedule only published questions from years Free students can open, for today or later,
    and not change a day that students have already answered. */
create or replace function private.qotd_check()
returns trigger language plpgsql security definer set search_path = '' as $$
declare q record;
begin
  if tg_op in ('UPDATE', 'DELETE') and exists (select 1 from public.qotd_answers a where a.day = old.day) then
    raise exception 'Students have already answered this day''s question, so it cannot be changed.' using errcode = 'P0001';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  if new.day < private.lagos_today() then
    raise exception 'You can only schedule today or a later day.' using errcode = 'P0001';
  end if;
  select qq.status, qq.deleted_at, qq.exam_id, qq.year, qq.passage_id into q from public.questions qq where qq.id = new.question_id;
  if q.status is distinct from 'published' or q.deleted_at is not null then
    raise exception 'Choose a published question.' using errcode = 'P0001';
  end if;
  if q.passage_id is not null then
    raise exception 'Choose a question without a reading passage.' using errcode = 'P0001';
  end if;
  if not private.tier_year_open('free', q.exam_id, q.year, 'cbt') then
    raise exception 'Choose a question from a year Free students can open, so every student can answer it.' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
create trigger qotd_check before insert or update or delete on public.qotd for each row execute function private.qotd_check();

/** Makes sure a day has a question: the admin's choice, else an automatic pick from Free years, rotating subjects
    and not repeating a question used in the last year. Returns the question id or null when nothing fits. */
create or replace function private.qotd_ensure(p_day date)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_subjects smallint[];
begin
  select q.question_id into v_id from public.qotd q where q.day = p_day;
  if v_id is not null then return v_id; end if;

  select array_agg(distinct qq.subject_id order by qq.subject_id) into v_subjects
  from public.questions qq
  where qq.status = 'published' and qq.deleted_at is null and qq.passage_id is null
    and private.tier_year_open('free', qq.exam_id, qq.year, 'cbt');
  if v_subjects is null then return null; end if;

  select qq.id into v_id
  from public.questions qq
  where qq.status = 'published' and qq.deleted_at is null and qq.passage_id is null
    and qq.subject_id = v_subjects[1 + (p_day - date '2026-01-01') % cardinality(v_subjects)]
    and private.tier_year_open('free', qq.exam_id, qq.year, 'cbt')
    and not exists (select 1 from public.qotd d where d.question_id = qq.id and d.day > p_day - 365)
  order by md5(qq.id::text || p_day::text)
  limit 1;
  if v_id is null then return null; end if;

  insert into public.qotd (day, question_id, source, created_by) values (p_day, v_id, 'auto', null)
  on conflict (day) do nothing;
  select q.question_id into v_id from public.qotd q where q.day = p_day;
  return v_id;
end;
$$;

/** Days in a row this student answered the question of the day (today or up to yesterday). */
create or replace function private.qotd_streak(p_user uuid)
returns integer language plpgsql stable security definer set search_path = '' as $$
declare v_d date := private.lagos_today(); v_n integer := 0;
begin
  if not exists (select 1 from public.qotd_answers a where a.user_id = p_user and a.day = v_d) then v_d := v_d - 1; end if;
  while exists (select 1 from public.qotd_answers a where a.user_id = p_user and a.day = v_d) loop
    v_n := v_n + 1; v_d := v_d - 1;
  end loop;
  return v_n;
end;
$$;

/** Today's question for the signed-in student. Before they answer: no answer, no explanation.
    { day, next_at, streak, question: {id, body, options, image_path, exam, subject, year} | null,
      result: null | {choice, correct, answer, explanation, pct_right, answers} } */
create or replace function public.qotd_today()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_day date := private.lagos_today();
  v_qid uuid;
  q record;
  a record;
  v_total integer; v_right integer;
  v_out jsonb;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  v_qid := private.qotd_ensure(v_day);
  v_out := jsonb_build_object('day', v_day,
    'next_at', ((v_day + 1)::timestamp at time zone 'Africa/Lagos'),
    'streak', private.qotd_streak(v_uid), 'question', null, 'result', null);
  if v_qid is null then return v_out; end if;

  select qq.id, qq.body, qq.options, qq.image_path, qq.answer, qq.explanation, qq.exam_id, qq.year,
         e.code as exam, s.name as subject
    into q
  from public.questions qq
  join public.exam_bodies e on e.id = qq.exam_id
  join public.subjects s on s.id = qq.subject_id
  where qq.id = v_qid;
  -- Belt and braces: never send a question from a year this student cannot open.
  if not private.year_open(q.exam_id, q.year, 'cbt') then return v_out; end if;

  v_out := v_out || jsonb_build_object('question', jsonb_build_object(
    'id', q.id, 'body', q.body, 'options', q.options, 'image_path', q.image_path,
    'exam', q.exam, 'subject', q.subject, 'year', q.year));

  select x.choice, x.correct into a from public.qotd_answers x where x.user_id = v_uid and x.day = v_day;
  if found then
    select count(*), count(*) filter (where x.correct) into v_total, v_right from public.qotd_answers x where x.day = v_day;
    v_out := v_out || jsonb_build_object('result', jsonb_build_object(
      'choice', a.choice, 'correct', a.correct, 'answer', q.answer, 'explanation', q.explanation,
      'answers', v_total, 'pct_right', case when v_total > 0 then round(100.0 * v_right / v_total) else 0 end));
  end if;
  return v_out;
end;
$$;

/** Answer today's question. One attempt: a second call returns the first answer's result. */
create or replace function public.qotd_answer(p_choice text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_day date := private.lagos_today();
  v_qid uuid;
  q record;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  v_qid := private.qotd_ensure(v_day);
  if v_qid is null then raise exception 'There is no question today.' using errcode = 'P0001'; end if;
  select qq.answer, qq.options, qq.exam_id, qq.year into q from public.questions qq where qq.id = v_qid;
  if not private.year_open(q.exam_id, q.year, 'cbt') then raise exception 'Not allowed' using errcode = '42501'; end if;
  if p_choice is null or not (q.options ? p_choice) then raise exception 'Choose one of the options.' using errcode = '22023'; end if;
  insert into public.qotd_answers (user_id, day, choice, correct) values (v_uid, v_day, p_choice, p_choice = q.answer)
  on conflict (user_id, day) do nothing;
  return public.qotd_today();
end;
$$;

/** Admin: days from p_from to p_to with their question and how students answered. */
create or replace function public.admin_qotd_days(p_from date, p_to date)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff() then raise exception 'Not allowed' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'day', d.day, 'id', d.id, 'source', d.source, 'question_id', d.question_id,
      'body', left(qq.body, 240), 'exam', e.code, 'subject', s.name, 'year', qq.year, 'answer', qq.answer,
      'answers', (select count(*) from public.qotd_answers a where a.day = d.day),
      'right', (select count(*) from public.qotd_answers a where a.day = d.day and a.correct)) order by d.day)
    from public.qotd d
    join public.questions qq on qq.id = d.question_id
    join public.exam_bodies e on e.id = qq.exam_id
    join public.subjects s on s.id = qq.subject_id
    where d.day between p_from and p_to), '[]'::jsonb);
end;
$$;

/** Admin: published questions that can be the question of the day (Free years, no passage), searchable. */
create or replace function public.admin_qotd_candidates(p_search text default null, p_subject smallint default null, p_limit integer default 30)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff() then raise exception 'Not allowed' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(x) from (
      select jsonb_build_object('id', qq.id, 'body', left(qq.body, 240), 'exam', e.code, 'subject', s.name, 'year', qq.year,
             'number', qq.number, 'used', (select max(d.day) from public.qotd d where d.question_id = qq.id)) as x
      from public.questions qq
      join public.exam_bodies e on e.id = qq.exam_id
      join public.subjects s on s.id = qq.subject_id
      where qq.status = 'published' and qq.deleted_at is null and qq.passage_id is null
        and (p_subject is null or qq.subject_id = p_subject)
        and (p_search is null or qq.body ilike '%' || p_search || '%')
        and private.tier_year_open('free', qq.exam_id, qq.year, 'cbt')
      order by qq.year desc, qq.subject_id, qq.number nulls last
      limit least(greatest(p_limit, 1), 100)) t), '[]'::jsonb);
end;
$$;

-- ================================================================ leaderboard
alter table public.profiles add column hide_on_leaderboard boolean not null default false;
grant update (hide_on_leaderboard) on public.profiles to authenticated;

insert into public.app_settings (key, value, description, is_public, updated_by) values
  ('leaderboard', '{"on": false, "past_seasons": [], "min_mocks": 1, "names": "first-initial"}',
   'Leaderboard: on/off (off by default), past JAMB seasons to show, full mocks needed to appear, name format.', false, null)
on conflict (key) do nothing;

/** The JAMB season an attempt counts for: UTME is sat around April-May, so from 1 July practice counts for next year. */
create or replace function private.jamb_season(p_at timestamptz)
returns integer language sql immutable set search_path = '' as $$
  select extract(year from (p_at at time zone 'Africa/Lagos'))::int
       + case when extract(month from (p_at at time zone 'Africa/Lagos')) >= 7 then 1 else 0 end;
$$;

/** Staff decisions on attempts the server held back as suspicious (too fast or too perfect). */
create table public.leaderboard_reviews (
  attempt_id uuid primary key references public.attempts (id) on delete cascade,
  decision text not null check (decision in ('ok', 'rejected')),
  decided_by uuid default auth.uid() references auth.users (id),
  decided_at timestamptz not null default now()
);
alter table public.leaderboard_reviews enable row level security;
create policy "admins" on public.leaderboard_reviews for all to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));
revoke all on public.leaderboard_reviews from anon;
create trigger leaderboard_reviews_audit after insert or update or delete on public.leaderboard_reviews
  for each row execute function private.audit_row();

create index attempts_lb on public.attempts (exam_id, mode, submitted_at) where status = 'submitted';

/** Why an attempt is held back from the leaderboard (null = fine): too fast, or near-perfect very fast. */
create or replace function private.lb_suspicious(p_score integer, p_time_s integer)
returns text language sql immutable set search_path = '' as $$
  select case
    when p_time_s < 900 then 'Finished a full mock in under 15 minutes'
    when p_score >= 380 and p_time_s < 2700 then 'Near-perfect score in under 45 minutes'
  end;
$$;

/** Full JAMB mocks (4 subjects, out of 400) for a season, with each one's score and whether it may count. */
create or replace function private.lb_attempts(p_season integer)
returns table (attempt_id uuid, user_id uuid, score integer, time_s integer, submitted_at timestamptz, held text, review text)
language sql stable security definer set search_path = '' as $$
  select a.id, a.user_id, (a.server_score ->> 'total')::int, a.time_used_s, a.submitted_at,
         private.lb_suspicious((a.server_score ->> 'total')::int, a.time_used_s), r.decision
  from public.attempts a
  join public.exam_bodies e on e.id = a.exam_id and e.code = 'JAMB'
  left join public.leaderboard_reviews r on r.attempt_id = a.id
  where a.mode = 'full' and a.status = 'submitted'
    and (a.server_score ->> 'max') = '400' and (a.server_score ->> 'questions')::int >= 100
    and a.submitted_at >= make_timestamptz(p_season - 1, 7, 1, 0, 0, 0, 'Africa/Lagos')
    and a.submitted_at < make_timestamptz(p_season, 7, 1, 0, 0, 0, 'Africa/Lagos');
$$;

/** "Chiamaka O." (first name + initial) or "Chiamaka". Never a full name: many students are minors. */
create or replace function private.lb_name(p_full text, p_format text)
returns text language sql immutable set search_path = '' as $$
  select case
    when coalesce(btrim(p_full), '') = '' then 'Student'
    when p_format = 'first' or array_length(regexp_split_to_array(btrim(p_full), '\s+'), 1) = 1
      then initcap(split_part(btrim(p_full), ' ', 1))
    else initcap(split_part(btrim(p_full), ' ', 1)) || ' ' ||
         upper(left((regexp_split_to_array(btrim(p_full), '\s+'))[array_length(regexp_split_to_array(btrim(p_full), '\s+'), 1)], 1)) || '.'
  end;
$$;

/** The leaderboard for a JAMB season, Nigeria or the student's state.
    Each student's best counting mock: higher score first, then faster, then earlier. Top 50 + the student's own rank.
    { on, seasons, season, current, scope, my_state, min_mocks, top: [{rank, name, state, score, me}],
      me: {rank, score, mocks, needs, ahead} | null, best: {name, state, school, score} | null } */
create or replace function public.leaderboard(p_season integer default null, p_scope text default 'ng')
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_set jsonb;
  v_now integer := private.jamb_season(now());
  v_seasons integer[];
  v_season integer;
  v_scope text := case when p_scope = 'state' then 'state' else 'ng' end;
  v_state text;
  v_min integer;
  v_names text;
  v_top jsonb; v_me jsonb; v_best jsonb;
  v_my_mocks integer;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  select s.value into v_set from public.app_settings s where s.key = 'leaderboard';
  if not coalesce((select f.enabled from public.feature_flags f where f.key = 'leaderboard_enabled'), true)
     or not coalesce((v_set ->> 'on')::boolean, false) then
    return jsonb_build_object('on', false);
  end if;
  v_min := greatest(coalesce((v_set ->> 'min_mocks')::int, 1), 1);
  v_names := coalesce(v_set ->> 'names', 'first-initial');
  select array_agg(distinct x order by x desc) into v_seasons
  from (select v_now as x union select (j)::int from jsonb_array_elements_text(coalesce(v_set -> 'past_seasons', '[]')) j
        where (j)::int < v_now) t;
  v_season := case when p_season = any (v_seasons) then p_season else v_now end;
  if v_season <> v_now then v_scope := 'ng'; end if;
  select p.state into v_state from public.profiles p where p.id = v_uid;
  if v_scope = 'state' and coalesce(v_state, '') = '' then v_scope := 'ng'; end if;

  with counted as (
    select x.* from private.lb_attempts(v_season) x
    where x.review is distinct from 'rejected' and (x.held is null or x.review = 'ok')
  ), best as (
    select distinct on (c.user_id) c.user_id, c.score, c.time_s, c.submitted_at,
           count(*) over (partition by c.user_id) as mocks
    from counted c
    order by c.user_id, c.score desc, c.time_s asc, c.submitted_at asc
  ), ranked as (
    select b.user_id, b.score, b.mocks, private.lb_name(p.full_name, v_names) as name, p.state, p.school,
           row_number() over (order by b.score desc, b.time_s asc, b.submitted_at asc)::int as rnk
    from best b
    join public.profiles p on p.id = b.user_id
    where b.mocks >= v_min and not p.hide_on_leaderboard and p.banned_at is null
      and not exists (select 1 from public.staff st where st.user_id = b.user_id)
      and (v_scope = 'ng' or p.state = v_state)
  )
  select
    (select coalesce(jsonb_agg(jsonb_build_object('rank', l.rnk, 'name', l.name, 'state', l.state, 'score', l.score,
            'me', l.user_id = v_uid) order by l.rnk), '[]'::jsonb) from ranked l where l.rnk <= 50),
    (select jsonb_build_object('rank', l.rnk, 'score', l.score, 'mocks', l.mocks,
            'ahead', (select a2.score - l.score from ranked a2 where a2.rnk = l.rnk - 1)) from ranked l where l.user_id = v_uid),
    (select jsonb_build_object('name', l.name, 'state', l.state, 'school', l.school, 'score', l.score) from ranked l where l.rnk = 1),
    (select count(*)::int from counted c where c.user_id = v_uid)
    into v_top, v_me, v_best, v_my_mocks;

  if v_me is null then
    v_me := jsonb_build_object('rank', null, 'mocks', v_my_mocks, 'needs', greatest(v_min - v_my_mocks, 0),
      'hidden', coalesce((select p.hide_on_leaderboard from public.profiles p where p.id = v_uid), false));
  end if;

  if v_season = v_now then v_best := null; end if;

  return jsonb_build_object('on', true, 'seasons', to_jsonb(v_seasons), 'season', v_season, 'current', v_season = v_now,
    'scope', v_scope, 'my_state', v_state, 'min_mocks', v_min, 'top', v_top, 'me', v_me, 'best', v_best);
end;
$$;

/** Admin: mocks held back this season (too fast or too perfect) and decisions taken. */
create or replace function public.admin_leaderboard_held(p_season integer default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('attempt_id', x.attempt_id, 'user_id', x.user_id, 'name', p.full_name,
           'state', p.state, 'score', x.score, 'time_s', x.time_s, 'submitted_at', x.submitted_at, 'held', x.held,
           'review', x.review) order by x.submitted_at desc)
    from private.lb_attempts(coalesce(p_season, private.jamb_season(now()))) x
    join public.profiles p on p.id = x.user_id
    where x.held is not null), '[]'::jsonb);
end;
$$;

revoke execute on function public.qotd_today(), public.qotd_answer(text), public.leaderboard(integer, text),
  public.admin_qotd_days(date, date), public.admin_qotd_candidates(text, smallint, integer),
  public.admin_leaderboard_held(integer) from public, anon;
grant execute on function public.qotd_today(), public.qotd_answer(text), public.leaderboard(integer, text),
  public.admin_qotd_days(date, date), public.admin_qotd_candidates(text, smallint, integer),
  public.admin_leaderboard_held(integer) to authenticated;
revoke execute on function private.qotd_ensure(date), private.qotd_streak(uuid), private.lb_attempts(integer),
  private.tier_year_open(text, smallint, smallint, text) from public, anon, authenticated;
