-- DRAFT, not applied yet (the first try waited for a Supabase confirmation that never came). Apply with MCP, then move to
-- supabase/migrations/<version>_qotd_per_subject.sql.
-- Owner (D-071): question of the day per subject. Each day every subject can have its own question; each student
-- gets one of their own JAMB subjects (picked at random per student per day). Admin analysis and a daily notification.

-- ================================================================ schema
alter table public.qotd add column subject_id smallint references public.subjects (id);
update public.qotd d set subject_id = q.subject_id from public.questions q where q.id = d.question_id and d.subject_id is null;

alter table public.qotd_answers drop constraint if exists qotd_answers_day_fkey;
alter table public.qotd_answers add column qotd_id uuid references public.qotd (id) on delete restrict;
update public.qotd_answers a set qotd_id = d.id from public.qotd d where d.day = a.day and a.qotd_id is null;
alter table public.qotd_answers alter column qotd_id set not null;
create index qotd_answers_qotd on public.qotd_answers (qotd_id);

alter table public.qotd drop constraint if exists qotd_day_key;
create unique index qotd_day_subject on public.qotd (day, coalesce(subject_id, 0));   -- subject null = "general" (any student)

insert into public.app_settings (key, value, description, is_public, updated_by) values
  ('qotd', '{"notify": true, "notify_hour": 7, "last_notified": null}',
   'Question of the day: daily notification on/off and the hour (Lagos time).', false, null)
on conflict (key) do nothing;

-- ================================================================ rules
create or replace function private.qotd_check()
returns trigger language plpgsql security definer set search_path = '' as $$
declare q record;
begin
  if tg_op in ('UPDATE', 'DELETE') and exists (select 1 from public.qotd_answers a where a.qotd_id = old.id) then
    raise exception 'Students have already answered this question, so it cannot be changed.' using errcode = 'P0001';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  if new.day < private.lagos_today() then
    raise exception 'You can only schedule today or a later day.' using errcode = 'P0001';
  end if;
  if new.question_id is null then return new; end if;  -- the admin's own question (its subject is chosen in the form)
  select qq.status, qq.deleted_at, qq.exam_id, qq.year, qq.passage_id, qq.subject_id into q from public.questions qq where qq.id = new.question_id;
  if q.status is distinct from 'published' or q.deleted_at is not null then
    raise exception 'Choose a published question.' using errcode = 'P0001';
  end if;
  if q.passage_id is not null then
    raise exception 'Choose a question without a reading passage.' using errcode = 'P0001';
  end if;
  if not private.tier_year_open('free', q.exam_id, q.year, 'cbt') then
    raise exception 'Choose a question from a year Free students can open, so every student can answer it.' using errcode = 'P0001';
  end if;
  new.subject_id := q.subject_id;
  return new;
end;
$$;

/** The day's question for a subject: the admin's, else an automatic Free-year pick (saved, so all get the same). */
create or replace function private.qotd_pick(p_day date, p_subject smallint)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_q uuid;
begin
  select d.id into v_id from public.qotd d where d.day = p_day and d.subject_id is not distinct from p_subject;
  if v_id is not null or p_subject is null then return v_id; end if;
  select qq.id into v_q
  from public.questions qq
  where qq.status = 'published' and qq.deleted_at is null and qq.passage_id is null and qq.subject_id = p_subject
    and private.tier_year_open('free', qq.exam_id, qq.year, 'cbt')
    and not exists (select 1 from public.qotd d where d.question_id = qq.id and d.day > p_day - 365)
  order by md5(qq.id::text || p_day::text)
  limit 1;
  if v_q is null then
    -- every question was used this year: allow repeats rather than nothing
    select qq.id into v_q from public.questions qq
    where qq.status = 'published' and qq.deleted_at is null and qq.passage_id is null and qq.subject_id = p_subject
      and private.tier_year_open('free', qq.exam_id, qq.year, 'cbt')
    order by md5(qq.id::text || p_day::text) limit 1;
  end if;
  if v_q is null then return null; end if;
  insert into public.qotd (day, question_id, subject_id, source, created_by) values (p_day, v_q, p_subject, 'auto', null)
  on conflict do nothing;
  select d.id into v_id from public.qotd d where d.day = p_day and d.subject_id = p_subject;
  return v_id;
end;
$$;

/** Which question of the day a student gets: one of their JAMB subjects, picked at random per student per day;
    falls back to their other subjects, then a "general" question, then any subject with questions. */
create or replace function private.qotd_for_user(p_user uuid, p_day date)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_subjects smallint[]; v_n integer; v_start integer; i integer;
begin
  select a.qotd_id into v_id from public.qotd_answers a where a.user_id = p_user and a.day = p_day;
  if v_id is not null then return v_id; end if;
  select array_agg(s.id order by s.sort, s.id) into v_subjects
  from public.profiles p cross join lateral unnest(p.jamb_subjects) u(c) join public.subjects s on s.code = u.c
  where p.id = p_user;
  if v_subjects is null or cardinality(v_subjects) = 0 then
    select array_agg(distinct qq.subject_id order by qq.subject_id) into v_subjects
    from public.questions qq where qq.status = 'published' and qq.deleted_at is null and qq.passage_id is null
      and private.tier_year_open('free', qq.exam_id, qq.year, 'cbt');
  end if;
  v_n := coalesce(cardinality(v_subjects), 0);
  if v_n > 0 then
    v_start := abs(hashtext(p_user::text || p_day::text)) % v_n;
    for i in 0 .. v_n - 1 loop
      v_id := private.qotd_pick(p_day, v_subjects[1 + (v_start + i) % v_n]);
      if v_id is not null then return v_id; end if;
    end loop;
  end if;
  select d.id into v_id from public.qotd d where d.day = p_day and d.subject_id is null;
  return v_id;
end;
$$;

create or replace function private.qotd_row(p_id uuid)
returns table (id uuid, own boolean, body text, options jsonb, image_path text, answer text, explanation text,
               exam_id smallint, year smallint, exam text, subject text)
language sql stable security definer set search_path = '' as $$
  select d.id, d.question_id is null,
         coalesce(d.custom_body, qq.body), coalesce(d.custom_options, qq.options), qq.image_path,
         coalesce(d.custom_answer, qq.answer), case when d.question_id is null then d.custom_explanation else qq.explanation end,
         qq.exam_id, qq.year, e.code, coalesce(sd.name, d.custom_subject, s.name)
  from public.qotd d
  left join public.questions qq on qq.id = d.question_id
  left join public.exam_bodies e on e.id = qq.exam_id
  left join public.subjects s on s.id = qq.subject_id
  left join public.subjects sd on sd.id = d.subject_id
  where d.id = p_id;
$$;

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
  v_out := jsonb_build_object('day', v_day,
    'next_at', ((v_day + 1)::timestamp at time zone 'Africa/Lagos'),
    'streak', private.qotd_streak(v_uid), 'question', null, 'result', null);
  v_qid := private.qotd_for_user(v_uid, v_day);
  if v_qid is null then return v_out; end if;
  select * into q from private.qotd_row(v_qid);
  if not q.own and not private.year_open(q.exam_id, q.year, 'cbt') then return v_out; end if;
  v_out := v_out || jsonb_build_object('question', jsonb_build_object(
    'id', coalesce((select d.question_id from public.qotd d where d.id = v_qid), q.id), 'qotd_id', q.id, 'own', q.own,
    'body', q.body, 'options', q.options, 'image_path', q.image_path, 'exam', q.exam, 'subject', q.subject, 'year', q.year));
  select x.choice, x.correct into a from public.qotd_answers x where x.user_id = v_uid and x.day = v_day;
  if found then
    select count(*), count(*) filter (where x.correct) into v_total, v_right from public.qotd_answers x where x.qotd_id = v_qid;
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
  v_qid uuid;
  q record;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  v_qid := private.qotd_for_user(v_uid, v_day);
  if v_qid is null then raise exception 'There is no question today.' using errcode = 'P0001'; end if;
  select * into q from private.qotd_row(v_qid);
  if not q.own and not private.year_open(q.exam_id, q.year, 'cbt') then raise exception 'Not allowed' using errcode = '42501'; end if;
  if p_choice is null or not (q.options ? p_choice) then raise exception 'Choose one of the options.' using errcode = '22023'; end if;
  insert into public.qotd_answers (user_id, day, qotd_id, choice, correct) values (v_uid, v_day, v_qid, p_choice, p_choice = q.answer)
  on conflict (user_id, day) do nothing;
  return public.qotd_today();
end;
$$;

-- ================================================================ admin
/** Days × subjects that have a question, with how students answered each. */
create or replace function public.admin_qotd_days(p_from date, p_to date)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff() then raise exception 'Not allowed' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'day', d.day, 'id', d.id, 'source', case when d.question_id is null then 'own' else d.source end, 'question_id', d.question_id,
      'subject_id', d.subject_id, 'subject', coalesce(sd.name, d.custom_subject, s.name, 'General'),
      'body', left(coalesce(d.custom_body, qq.body), 240), 'exam', e.code, 'year', qq.year, 'answer', coalesce(d.custom_answer, qq.answer),
      'answers', (select count(*) from public.qotd_answers a where a.qotd_id = d.id),
      'right', (select count(*) from public.qotd_answers a where a.qotd_id = d.id and a.correct),
      'choices', (select coalesce(jsonb_object_agg(x.choice, x.n), '{}'::jsonb) from
                   (select a.choice, count(*) as n from public.qotd_answers a where a.qotd_id = d.id group by a.choice) x))
      order by d.day, coalesce(sd.sort, s.sort, 999))
    from public.qotd d
    left join public.questions qq on qq.id = d.question_id
    left join public.exam_bodies e on e.id = qq.exam_id
    left join public.subjects s on s.id = qq.subject_id
    left join public.subjects sd on sd.id = d.subject_id
    where d.day between p_from and p_to), '[]'::jsonb);
end;
$$;

/** Analysis: totals, per day, per subject, streaks. */
create or replace function public.admin_qotd_stats(p_days integer default 14)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_today date := private.lagos_today(); v_from date := private.lagos_today() - greatest(least(p_days, 90), 1) + 1;
begin
  if not private.is_staff() then raise exception 'Not allowed' using errcode = '42501'; end if;
  return jsonb_build_object(
    'today', (select jsonb_build_object('answers', count(*), 'right', count(*) filter (where a.correct)) from public.qotd_answers a where a.day = v_today),
    'period', (select jsonb_build_object('answers', count(*), 'right', count(*) filter (where a.correct), 'students', count(distinct a.user_id))
               from public.qotd_answers a where a.day between v_from and v_today),
    'all_time_students', (select count(distinct a.user_id) from public.qotd_answers a),
    'streak3', (select count(*) from (select a.user_id from public.qotd_answers a where a.day between v_today - 2 and v_today
                group by a.user_id having count(distinct a.day) = 3) t),
    'by_day', coalesce((select jsonb_agg(jsonb_build_object('day', g.d::date, 'answers', coalesce(x.n, 0), 'right', coalesce(x.r, 0)) order by g.d)
               from generate_series(v_from, v_today, interval '1 day') g(d)
               left join (select a.day, count(*) as n, count(*) filter (where a.correct) as r from public.qotd_answers a
                          where a.day between v_from and v_today group by a.day) x on x.day = g.d::date), '[]'::jsonb),
    'by_subject', coalesce((select jsonb_agg(jsonb_build_object('subject', t.subject, 'answers', t.n, 'right', t.r) order by t.n desc)
               from (select coalesce(s.name, 'General') as subject, count(*) as n, count(*) filter (where a.correct) as r
                     from public.qotd_answers a join public.qotd d on d.id = a.qotd_id left join public.subjects s on s.id = d.subject_id
                     where a.day between v_from and v_today group by 1) t), '[]'::jsonb));
end;
$$;

-- ================================================================ daily notification
create or replace function private.qotd_notify()
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_set jsonb; v_today date := private.lagos_today(); v_hour integer := extract(hour from (now() at time zone 'Africa/Lagos'))::int;
begin
  select s.value into v_set from public.app_settings s where s.key = 'qotd';
  if v_set is null or not coalesce((v_set ->> 'notify')::boolean, true) then return false; end if;
  if v_hour < coalesce((v_set ->> 'notify_hour')::int, 7) or (v_set ->> 'last_notified') = v_today::text then return false; end if;
  update public.app_settings set value = value || jsonb_build_object('last_notified', v_today::text) where key = 'qotd';
  insert into public.notifications (topic, title, body, audience, status, scheduled_at, source, link)
  values ('new_questions', 'Your question of the day is ready', 'One question from your subjects. One try. Keep your streak going!',
          'all', 'scheduled', now(), 'admin', jsonb_build_object('type', 'screen', 'target', '/home'));
  return true;
end;
$$;
revoke execute on function private.qotd_notify(), private.qotd_pick(date, smallint), private.qotd_for_user(uuid, date),
  private.qotd_row(uuid) from public, anon, authenticated;
select cron.schedule('qotd-notify', '*/10 * * * *', $$select private.qotd_notify()$$);

revoke execute on function public.admin_qotd_stats(integer) from public, anon;
grant execute on function public.admin_qotd_stats(integer) to authenticated;

-- The old day-only helpers (private.qotd_ensure, qotd_ready, qotd_question) are left in place but no longer used.
