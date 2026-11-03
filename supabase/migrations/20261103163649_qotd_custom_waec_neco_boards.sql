-- Owner (D-068): 1) the admin can write their own question of the day (not only past questions);
-- 2) leaderboards for WAEC and NECO: one board per subject, best subject paper out of 100.

-- ================================================================ 1. own questions of the day
alter table public.qotd alter column question_id drop not null;
alter table public.qotd
  add column custom_subject text check (char_length(custom_subject) <= 60),
  add column custom_body text check (char_length(custom_body) between 1 and 4000),
  add column custom_options jsonb check (custom_options is null or jsonb_typeof(custom_options) = 'object'),
  add column custom_answer text check (custom_answer in ('A', 'B', 'C', 'D', 'E')),
  add column custom_explanation text check (char_length(custom_explanation) <= 8000),
  add constraint qotd_question_or_own check (
    (question_id is not null and custom_body is null)
    or (question_id is null and custom_body is not null and custom_options ?& array['A', 'B', 'C', 'D']
        and custom_answer is not null and custom_options ? custom_answer));

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
  if new.question_id is null then return new; end if; -- the admin's own question: open to every student
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

/** True when a day is scheduled (with a bank question or the admin's own); picks one automatically otherwise. */
create or replace function private.qotd_ready(p_day date)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.qotd q where q.day = p_day) then return true; end if;
  return private.qotd_ensure(p_day) is not null;
end;
$$;
revoke execute on function private.qotd_ready(date) from public, anon, authenticated;

/** The day's question with its answer (server only): from the bank or the admin's own. */
create or replace function private.qotd_question(p_day date)
returns table (id uuid, own boolean, body text, options jsonb, image_path text, answer text, explanation text,
               exam_id smallint, year smallint, exam text, subject text)
language sql stable security definer set search_path = '' as $$
  select coalesce(d.question_id, d.id), d.question_id is null,
         coalesce(d.custom_body, qq.body), coalesce(d.custom_options, qq.options), qq.image_path,
         coalesce(d.custom_answer, qq.answer), case when d.question_id is null then d.custom_explanation else qq.explanation end,
         qq.exam_id, qq.year, e.code, coalesce(d.custom_subject, s.name)
  from public.qotd d
  left join public.questions qq on qq.id = d.question_id
  left join public.exam_bodies e on e.id = qq.exam_id
  left join public.subjects s on s.id = qq.subject_id
  where d.day = p_day;
$$;
revoke execute on function private.qotd_question(date) from public, anon, authenticated;

create or replace function public.qotd_today()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_day date := private.lagos_today();
  q record;
  a record;
  v_total integer; v_right integer;
  v_out jsonb;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  v_out := jsonb_build_object('day', v_day,
    'next_at', ((v_day + 1)::timestamp at time zone 'Africa/Lagos'),
    'streak', private.qotd_streak(v_uid), 'question', null, 'result', null);
  if not private.qotd_ready(v_day) then return v_out; end if;
  select * into q from private.qotd_question(v_day);
  -- A bank question is sent only to students who can open its year; the admin's own question goes to everyone.
  if not q.own and not private.year_open(q.exam_id, q.year, 'cbt') then return v_out; end if;

  v_out := v_out || jsonb_build_object('question', jsonb_build_object(
    'id', q.id, 'own', q.own, 'body', q.body, 'options', q.options, 'image_path', q.image_path,
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

create or replace function public.qotd_answer(p_choice text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_day date := private.lagos_today();
  q record;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if not private.qotd_ready(v_day) then raise exception 'There is no question today.' using errcode = 'P0001'; end if;
  select * into q from private.qotd_question(v_day);
  if not q.own and not private.year_open(q.exam_id, q.year, 'cbt') then raise exception 'Not allowed' using errcode = '42501'; end if;
  if p_choice is null or not (q.options ? p_choice) then raise exception 'Choose one of the options.' using errcode = '22023'; end if;
  insert into public.qotd_answers (user_id, day, choice, correct) values (v_uid, v_day, p_choice, p_choice = q.answer)
  on conflict (user_id, day) do nothing;
  return public.qotd_today();
end;
$$;

create or replace function public.admin_qotd_days(p_from date, p_to date)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff() then raise exception 'Not allowed' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'day', d.day, 'id', d.id, 'source', case when d.question_id is null then 'own' else d.source end, 'question_id', d.question_id,
      'body', left(coalesce(d.custom_body, qq.body), 240), 'exam', e.code, 'subject', coalesce(d.custom_subject, s.name),
      'year', qq.year, 'answer', coalesce(d.custom_answer, qq.answer),
      'answers', (select count(*) from public.qotd_answers a where a.day = d.day),
      'right', (select count(*) from public.qotd_answers a where a.day = d.day and a.correct)) order by d.day)
    from public.qotd d
    left join public.questions qq on qq.id = d.question_id
    left join public.exam_bodies e on e.id = qq.exam_id
    left join public.subjects s on s.id = qq.subject_id
    where d.day between p_from and p_to), '[]'::jsonb);
end;
$$;

-- ================================================================ 2. WAEC and NECO boards
update public.app_settings
set value = jsonb_build_object('exams', jsonb_build_object('JAMB', true, 'WAEC', true, 'NECO', true),
                               'subject_min_questions', 40, 'subject_fast_minutes', 5) || value
where key = 'leaderboard';

/** Counting tests for one board. JAMB: full mocks (out of 400). WAEC/NECO: one-subject papers (out of 100) in p_subject. */
create or replace function private.lb_entries(p_exam text, p_season integer, p_subject smallint)
returns table (attempt_id uuid, user_id uuid, score integer, time_s integer, submitted_at timestamptz, held text, review text)
language plpgsql stable security definer set search_path = '' as $$
declare v_c jsonb := private.lb_cfg(); v_fast integer; v_minq integer;
begin
  if p_exam = 'JAMB' then
    return query select * from private.lb_attempts(p_season);
    return;
  end if;
  v_fast := coalesce((v_c ->> 'subject_fast_minutes')::int, 5);
  v_minq := coalesce((v_c ->> 'subject_min_questions')::int, 40);
  return query
  select a.id, a.user_id, (a.server_score ->> 'total')::int, a.time_used_s, a.submitted_at,
         case when v_fast <= 0 then null
              when a.time_used_s < v_fast * 60 then 'Finished in under ' || v_fast || ' minutes'
              when (a.server_score ->> 'total')::int >= 95 and a.time_used_s < v_fast * 180 then 'Near-perfect score in under ' || (v_fast * 3) || ' minutes'
         end,
         r.decision
  from public.attempts a
  join public.exam_bodies e on e.id = a.exam_id and e.code = p_exam
  left join public.leaderboard_reviews r on r.attempt_id = a.id
  where a.mode in ('subject', 'year') and a.status = 'submitted'
    and (a.server_score ->> 'max') = '100'
    and jsonb_array_length(coalesce(a.server_score -> 'subjects', '[]')) = 1
    and (a.server_score -> 'subjects' -> 0 ->> 'subject_id')::smallint = p_subject
    and (a.server_score ->> 'questions')::int >= v_minq
    and a.submitted_at >= make_timestamptz(p_season - 1, 7, 1, 0, 0, 0, 'Africa/Lagos')
    and a.submitted_at < make_timestamptz(p_season, 7, 1, 0, 0, 0, 'Africa/Lagos');
end;
$$;
revoke execute on function private.lb_entries(text, integer, smallint) from public, anon, authenticated;

/** The leaderboard for one exam (JAMB, WAEC or NECO), season, scope and (WAEC/NECO) subject.
    Adds to the JAMB answer: exam, exams (boards that are on), subject, subjects (WAEC/NECO subjects with entries). */
create or replace function public.leaderboard_for(p_exam text default 'JAMB', p_season integer default null,
                                                  p_scope text default 'ng', p_subject smallint default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_set jsonb;
  v_now integer := private.jamb_season(now());
  v_exams text[];
  v_exam text;
  v_subjects jsonb;
  v_subject smallint;
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
  select array_agg(x order by array_position(array['JAMB', 'WAEC', 'NECO'], x)) into v_exams
  from unnest(array['JAMB', 'WAEC', 'NECO']) x
  where coalesce((v_set -> 'exams' ->> x)::boolean, true);
  if v_exams is null then return jsonb_build_object('on', false); end if;
  v_exam := case when upper(p_exam) = any (v_exams) then upper(p_exam) else v_exams[1] end;

  v_min := greatest(coalesce((v_set ->> 'min_mocks')::int, 1), 1);
  v_names := coalesce(v_set ->> 'names', 'first-initial');
  select array_agg(distinct x order by x desc) into v_seasons
  from (select v_now as x union select (j)::int from jsonb_array_elements_text(coalesce(v_set -> 'past_seasons', '[]')) j
        where (j)::int < v_now) t;
  v_season := case when p_season = any (v_seasons) then p_season else v_now end;
  if v_season <> v_now then v_scope := 'ng'; end if;
  select p.state into v_state from public.profiles p where p.id = v_uid;
  if v_scope = 'state' and coalesce(v_state, '') = '' then v_scope := 'ng'; end if;

  if v_exam <> 'JAMB' then
    -- The exam's subjects (those with papers in the bank), so a student can pick one even before anyone has played.
    select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name) order by s.name), '[]'::jsonb) into v_subjects
    from public.subjects s
    where exists (select 1 from public.questions qq join public.exam_bodies e on e.id = qq.exam_id and e.code = v_exam
                  where qq.subject_id = s.id and qq.status = 'published' and qq.deleted_at is null);
    v_subject := coalesce(
      (select (x ->> 'id')::smallint from jsonb_array_elements(v_subjects) x where (x ->> 'id')::smallint = p_subject),
      (select (x ->> 'id')::smallint from jsonb_array_elements(v_subjects) x
       where (x ->> 'name') ilike any (array['%english%', '%mathematics%']) order by x ->> 'name' limit 1),
      (select (v_subjects -> 0 ->> 'id')::smallint));
  end if;

  with counted as (
    select x.* from private.lb_entries(v_exam, v_season, v_subject) x
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
      and (coalesce((v_set ->> 'include_staff')::boolean, false) or not exists (select 1 from public.staff st where st.user_id = b.user_id))
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

  return jsonb_build_object('on', true, 'exam', v_exam, 'exams', to_jsonb(v_exams), 'max', case when v_exam = 'JAMB' then 400 else 100 end,
    'subject', v_subject, 'subjects', coalesce(v_subjects, '[]'::jsonb),
    'seasons', to_jsonb(v_seasons), 'season', v_season, 'current', v_season = v_now,
    'scope', v_scope, 'my_state', v_state, 'min_mocks', v_min, 'top', v_top, 'me', v_me, 'best', v_best);
end;
$$;

/** The original JAMB call keeps working (older app builds). */
create or replace function public.leaderboard(p_season integer default null, p_scope text default 'ng')
returns jsonb language sql stable security definer set search_path = '' as $$
  select public.leaderboard_for('JAMB', p_season, p_scope, null);
$$;

/** Admin: the latest counted-type tests for every board, with whether each counts and why not. */
create or replace function public.admin_leaderboard_recent(p_limit integer default 40)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_c jsonb := private.lb_cfg(); v_minq integer; v_fast integer; v_sminq integer; v_sfast integer; v_staff boolean;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  v_minq := coalesce((v_c ->> 'min_questions')::int, 100);
  v_fast := coalesce((v_c ->> 'fast_minutes')::int, 15);
  v_sminq := coalesce((v_c ->> 'subject_min_questions')::int, 40);
  v_sfast := coalesce((v_c ->> 'subject_fast_minutes')::int, 5);
  v_staff := coalesce((v_c ->> 'include_staff')::boolean, false);
  return coalesce((
    select jsonb_agg(x order by (x ->> 'submitted_at') desc) from (
      select jsonb_build_object('attempt_id', t.id, 'exam', t.code, 'subject', t.subject, 'name', t.full_name, 'state', t.state,
        'score', t.score, 'max', t.mx, 'questions', t.qs, 'time_s', t.time_used_s, 'submitted_at', t.submitted_at,
        'reason', case
          when t.banned then 'Banned account'
          when not v_staff and t.is_staff then 'Staff account (staff are left out)'
          when t.hidden then 'The student chose to hide'
          when t.qs < t.need_q then 'Only ' || t.qs || ' questions (needs ' || t.need_q || ')'
          when t.decision = 'rejected' then 'You kept it off'
          when t.held is not null and t.decision is distinct from 'ok' then 'Held: ' || t.held
        end,
        'held', t.held is not null and t.qs >= t.need_q and t.decision is null) as x
      from (
        select a.id, e.code, a.time_used_s, a.submitted_at, p.full_name, p.state, p.banned_at is not null as banned, p.hide_on_leaderboard as hidden,
               exists (select 1 from public.staff st where st.user_id = a.user_id) as is_staff, r.decision,
               (a.server_score ->> 'total')::int as score, (a.server_score ->> 'max')::int as mx, (a.server_score ->> 'questions')::int as qs,
               case when e.code = 'JAMB' then null else (select s.name from public.subjects s where s.id = (a.server_score -> 'subjects' -> 0 ->> 'subject_id')::smallint) end as subject,
               case when e.code = 'JAMB' then v_minq else v_sminq end as need_q,
               case when e.code = 'JAMB' then private.lb_suspicious((a.server_score ->> 'total')::int, a.time_used_s, v_fast)
                    when v_sfast <= 0 then null
                    when a.time_used_s < v_sfast * 60 then 'Finished in under ' || v_sfast || ' minutes'
                    when (a.server_score ->> 'total')::int >= 95 and a.time_used_s < v_sfast * 180 then 'Near-perfect score in under ' || (v_sfast * 3) || ' minutes'
               end as held
        from public.attempts a
        join public.exam_bodies e on e.id = a.exam_id
        join public.profiles p on p.id = a.user_id
        left join public.leaderboard_reviews r on r.attempt_id = a.id
        where a.status = 'submitted'
          and ((e.code = 'JAMB' and a.mode = 'full' and (a.server_score ->> 'max') = '400')
            or (e.code in ('WAEC', 'NECO') and a.mode in ('subject', 'year') and (a.server_score ->> 'max') = '100'
                and jsonb_array_length(coalesce(a.server_score -> 'subjects', '[]')) = 1))
        order by a.submitted_at desc
        limit least(greatest(p_limit, 1), 100)) t) y), '[]'::jsonb);
end;
$$;

revoke execute on function public.leaderboard_for(text, integer, text, smallint) from public, anon;
grant execute on function public.leaderboard_for(text, integer, text, smallint) to authenticated;
