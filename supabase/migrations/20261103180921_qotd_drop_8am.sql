-- Owner (D-072): the new question of the day drops at 08:00 Lagos time every day (not midnight), with the notification.
-- private.qotd_day() is the question day: it changes at the drop hour (app_settings qotd.drop_hour, default 8).
-- private.lagos_today() (midnight) stays as it is for payments and streak reminders.

update public.app_settings set value = value || '{"drop_hour": 8}'::jsonb where key = 'qotd';

create or replace function private.qotd_hour() returns integer language sql stable security definer set search_path = '' as $$
  select least(greatest(coalesce((select (s.value ->> 'drop_hour')::int from public.app_settings s where s.key = 'qotd'), 8), 0), 23);
$$;

create or replace function private.qotd_day() returns date language sql stable security definer set search_path = '' as $$
  select ((now() at time zone 'Africa/Lagos') - make_interval(hours => private.qotd_hour()))::date;
$$;

create or replace function private.qotd_check()
returns trigger language plpgsql security definer set search_path = '' as $$
declare q record;
begin
  if tg_op in ('UPDATE', 'DELETE') and exists (select 1 from public.qotd_answers a where a.qotd_id = old.id) then
    raise exception 'Students have already answered this question, so it cannot be changed.' using errcode = 'P0001';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  if new.day < private.qotd_day() then
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

create or replace function private.qotd_streak(p_user uuid)
returns integer language plpgsql stable security definer set search_path = '' as $$
declare v_d date := private.qotd_day(); v_n integer := 0;
begin
  if not exists (select 1 from public.qotd_answers a where a.user_id = p_user and a.day = v_d) then v_d := v_d - 1; end if;
  while exists (select 1 from public.qotd_answers a where a.user_id = p_user and a.day = v_d) loop
    v_n := v_n + 1; v_d := v_d - 1;
  end loop;
  return v_n;
end;
$$;

create or replace function public.qotd_today()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_day date := private.qotd_day();
  v_qid uuid;
  q record;
  a record;
  v_total integer; v_right integer;
  v_out jsonb;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  v_out := jsonb_build_object('day', v_day,
    'next_at', ((v_day + 1)::timestamp + make_interval(hours => private.qotd_hour())) at time zone 'Africa/Lagos',
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
  v_day date := private.qotd_day();
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

create or replace function public.admin_qotd_stats(p_days integer default 14)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_today date := private.qotd_day(); v_from date := private.qotd_day() - greatest(least(p_days, 90), 1) + 1;
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

create or replace function private.qotd_notify()
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_set jsonb; v_today date := private.qotd_day();
begin
  select s.value into v_set from public.app_settings s where s.key = 'qotd';
  if v_set is null or not coalesce((v_set ->> 'notify')::boolean, true) then return false; end if;
  if (v_set ->> 'last_notified') = v_today::text then return false; end if;  -- the day changes at the drop hour, so this sends once at 08:00
  update public.app_settings set value = value || jsonb_build_object('last_notified', v_today::text) where key = 'qotd';
  insert into public.notifications (topic, title, body, audience, status, scheduled_at, source, link)
  values ('new_questions', 'Your question of the day is ready', 'One question from your subjects. One try. Keep your streak going!',
          'all', 'scheduled', now(), 'admin', jsonb_build_object('type', 'screen', 'target', '/home'));
  return true;
end;
$$;
select cron.schedule('qotd-notify', '* * * * *', $$select private.qotd_notify()$$);
