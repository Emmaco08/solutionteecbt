-- Backend plan (docs/plans/backend-neon.md), steps 2–4: Supabase keeps the live data; old history moves to Neon
-- every night (Edge Function archive-mover). This migration:
-- 1) keeps running totals per student+topic and per question (tiny tables, updated as tests are saved), so weak
--    topics and question difficulty use all history even after the raw answers move to Neon (and run faster);
-- 2) the windows (app_settings.archive, admin-editable): how many days each kind stays on Supabase;
-- 3) archive_take / archive_drop for the mover (service role only): read a batch of old rows, then delete exactly the
--    rows Neon confirmed. Rows still in use are never moved (ad unlocks that have not expired, payments themselves,
--    running challenges).

create table if not exists public.user_topic_stats (
  user_id uuid not null references auth.users (id) on delete cascade,
  topic_id integer not null,
  subject_id smallint not null,
  answered integer not null default 0,
  correct integer not null default 0,
  last_at timestamptz not null default now(),
  primary key (user_id, topic_id)
);
alter table public.user_topic_stats enable row level security;
create policy "own topic stats" on public.user_topic_stats for select to authenticated using (user_id = (select auth.uid()));

create table if not exists public.question_stats (
  question_id uuid primary key,
  answered integer not null default 0,
  correct integer not null default 0
);
alter table public.question_stats enable row level security;

-- Running totals, once per saved test (statement trigger with the inserted rows).
create or replace function private.answer_stats() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.user_topic_stats as s (user_id, topic_id, subject_id, answered, correct, last_at)
  select a.user_id, q.topic_id, q.subject_id, count(*), count(*) filter (where n.is_correct), max(a.submitted_at)
  from new_rows n join public.attempts a on a.id = n.attempt_id join public.questions q on q.id = n.question_id
  where n.choice is not null and q.topic_id is not null
  group by a.user_id, q.topic_id, q.subject_id
  on conflict (user_id, topic_id) do update
    set answered = s.answered + excluded.answered, correct = s.correct + excluded.correct, last_at = greatest(s.last_at, excluded.last_at);
  insert into public.question_stats as s (question_id, answered, correct)
  select n.question_id, count(*), count(*) filter (where n.is_correct) from new_rows n where n.choice is not null group by n.question_id
  on conflict (question_id) do update set answered = s.answered + excluded.answered, correct = s.correct + excluded.correct;
  return null;
end;
$$;
drop trigger if exists attempt_answers_stats on public.attempt_answers;
create trigger attempt_answers_stats after insert on public.attempt_answers
  referencing new table as new_rows for each statement execute function private.answer_stats();

-- Backfill from the answers we have now.
insert into public.user_topic_stats (user_id, topic_id, subject_id, answered, correct, last_at)
select a.user_id, q.topic_id, q.subject_id, count(*), count(*) filter (where n.is_correct), max(a.submitted_at)
from public.attempt_answers n join public.attempts a on a.id = n.attempt_id join public.questions q on q.id = n.question_id
where n.choice is not null and q.topic_id is not null
group by a.user_id, q.topic_id, q.subject_id
on conflict (user_id, topic_id) do nothing;
insert into public.question_stats (question_id, answered, correct)
select n.question_id, count(*), count(*) filter (where n.is_correct) from public.attempt_answers n where n.choice is not null group by n.question_id
on conflict (question_id) do nothing;

-- Weak topics and question difficulty read the totals (all history, faster).
create or replace function public.ai_weak_topics(p_uid uuid, p_limit integer default 5) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(w order by w.pct, w.answered desc), '[]') from (
    select s.name as subject, s.id as subject_id, t.name as topic, st.answered, st.correct,
           round(100.0 * st.correct / st.answered) as pct
    from public.user_topic_stats st
    join public.topics t on t.id = st.topic_id
    join public.subjects s on s.id = st.subject_id
    where st.user_id = p_uid and st.answered >= 3 and st.last_at > now() - interval '120 days'
    order by pct, st.answered desc
    limit least(greatest(coalesce(p_limit, 5), 1), 20)
  ) w;
$$;

create or replace function private.bank_level(p_question uuid) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select q.difficulty::text from public.questions q where q.id = p_question),
    (select case when r >= 0.75 then 'easy' when r >= 0.5 then 'medium' when r >= 0.25 then 'hard' else 'very_hard' end
       from (select s.correct::numeric / nullif(s.answered, 0) r from public.question_stats s where s.question_id = p_question and s.answered >= 20) x),
    'medium');
$$;

-- How long each kind stays on Supabase (days). Admin-editable.
insert into public.app_settings (key, value, is_public)
values ('archive', '{"on": true, "audit_days": 30, "answers_days": 14, "challenge_days": 60, "chats_days": 14,
                     "ai_calls_days": 30, "ad_days": 90, "payment_events_days": 365, "batch": 2000}', false)
on conflict (key) do nothing;

create table if not exists public.archive_runs (
  id bigserial primary key,
  at timestamptz not null default now(),
  kind text not null,
  moved integer not null,
  ok boolean not null,
  note text
);
alter table public.archive_runs enable row level security;
create policy "staff read archive runs" on public.archive_runs for select to authenticated using (private.is_staff());

create or replace function private.archive_days(p_key text, p_default integer) returns integer
language sql stable security definer set search_path = '' as $$
  select greatest(coalesce((select (value ->> p_key)::int from public.app_settings where key = 'archive'), p_default), 1);
$$;

-- A batch of rows old enough to move. Returns {"rows": [...], "keys": [...]}.
create or replace function public.archive_take(p_kind text, p_limit integer default 2000) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_lim integer := least(greatest(coalesce(p_limit, 2000), 1), 5000); r jsonb;
begin
  if p_kind = 'audit' then
    select jsonb_build_object('rows', coalesce(jsonb_agg(to_jsonb(x)), '[]'), 'keys', coalesce(jsonb_agg(x.id), '[]')) into r
    from (select * from public.audit_log where at < now() - make_interval(days => private.archive_days('audit_days', 30)) order by id limit v_lim) x;
  elsif p_kind = 'payment_events' then
    select jsonb_build_object('rows', coalesce(jsonb_agg(to_jsonb(x)), '[]'), 'keys', coalesce(jsonb_agg(x.id), '[]')) into r
    from (select * from public.payment_events where created_at < now() - make_interval(days => private.archive_days('payment_events_days', 365)) order by id limit v_lim) x;
  elsif p_kind = 'ai_calls' then
    select jsonb_build_object('rows', coalesce(jsonb_agg(to_jsonb(x)), '[]'), 'keys', coalesce(jsonb_agg(x.id), '[]')) into r
    from (select * from public.ai_calls where at < now() - make_interval(days => private.archive_days('ai_calls_days', 30)) order by id limit v_lim) x;
  elsif p_kind = 'ai_messages' then
    select jsonb_build_object('rows', coalesce(jsonb_agg(to_jsonb(x)), '[]'), 'keys', coalesce(jsonb_agg(x.id), '[]')) into r
    from (select * from public.ai_messages where created_at < now() - make_interval(days => private.archive_days('chats_days', 14)) order by created_at limit v_lim) x;
  elsif p_kind = 'attempt_answers' then
    -- Whole tests at a time (the score summary stays on Supabase in attempts).
    with t as (select a.id, a.user_id, a.submitted_at from public.attempts a
               where a.submitted_at < now() - make_interval(days => private.archive_days('answers_days', 14))
                 and exists (select 1 from public.attempt_answers aa where aa.attempt_id = a.id)
               order by a.submitted_at limit greatest(v_lim / 60, 1))
    select jsonb_build_object(
      'rows', coalesce((select jsonb_agg(to_jsonb(aa) || jsonb_build_object('user_id', t.user_id, 'submitted_at', t.submitted_at))
                        from public.attempt_answers aa join t on t.id = aa.attempt_id), '[]'),
      'keys', coalesce((select jsonb_agg(t.id) from t), '[]')) into r;
  elsif p_kind = 'challenge_answers' then
    -- Whole entries whose last answer is older than the window (prizes and appeals are long settled by then).
    with e as (select ca.entry_id, max(ca.answered_at) last_at from public.challenge_answers ca group by ca.entry_id
               having max(ca.answered_at) < now() - make_interval(days => private.archive_days('challenge_days', 60))
               order by 2 limit greatest(v_lim / 50, 1))
    select jsonb_build_object(
      'rows', coalesce((select jsonb_agg(to_jsonb(ca) || jsonb_build_object('user_id', ce.user_id))
                        from public.challenge_answers ca join e on e.entry_id = ca.entry_id
                        left join public.challenge_entries ce on ce.id = ca.entry_id), '[]'),
      'keys', coalesce((select jsonb_agg(e.entry_id) from e), '[]')) into r;
  elsif p_kind = 'ad_rewards' then
    -- Never rewards still in use (an unlock that has not expired, or a pending one).
    select jsonb_build_object('rows', coalesce(jsonb_agg(to_jsonb(x)), '[]'), 'keys', coalesce(jsonb_agg(x.id), '[]')) into r
    from (select * from public.ad_rewards where created_at < now() - make_interval(days => private.archive_days('ad_days', 90))
            and status <> 'pending' and (expires_at is null or expires_at < now()) order by created_at limit v_lim) x;
  elsif p_kind = 'ad_daily' then
    select jsonb_build_object('rows', coalesce(jsonb_agg(to_jsonb(x)), '[]'),
                              'keys', coalesce(jsonb_agg(jsonb_build_object('day', x.day, 'format', x.format, 'placement', x.placement)), '[]')) into r
    from (select * from public.ad_daily where day < (now() - make_interval(days => private.archive_days('ad_days', 90)))::date limit v_lim) x;
  else
    raise exception 'unknown kind %', p_kind;
  end if;
  return r;
end;
$$;

-- Delete exactly the rows Neon confirmed (keys from archive_take).
create or replace function public.archive_drop(p_kind text, p_keys jsonb, p_note text default null) returns integer
language plpgsql security definer set search_path = '' as $$
declare n integer := 0;
begin
  if p_kind = 'audit' then
    delete from public.audit_log where id in (select (x)::bigint from jsonb_array_elements_text(p_keys) x);
  elsif p_kind = 'payment_events' then
    delete from public.payment_events where id in (select (x)::bigint from jsonb_array_elements_text(p_keys) x);
  elsif p_kind = 'ai_calls' then
    delete from public.ai_calls where id in (select (x)::bigint from jsonb_array_elements_text(p_keys) x);
  elsif p_kind = 'ai_messages' then
    delete from public.ai_messages where id in (select (x)::uuid from jsonb_array_elements_text(p_keys) x);
  elsif p_kind = 'attempt_answers' then
    delete from public.attempt_answers where attempt_id in (select (x)::uuid from jsonb_array_elements_text(p_keys) x);
  elsif p_kind = 'challenge_answers' then
    delete from public.challenge_answers where entry_id in (select (x)::uuid from jsonb_array_elements_text(p_keys) x);
  elsif p_kind = 'ad_rewards' then
    delete from public.ad_rewards where id in (select (x)::uuid from jsonb_array_elements_text(p_keys) x)
      and status <> 'pending' and (expires_at is null or expires_at < now());
  elsif p_kind = 'ad_daily' then
    delete from public.ad_daily d using jsonb_array_elements(p_keys) k
    where d.day = (k ->> 'day')::date and d.format = k ->> 'format' and d.placement = k ->> 'placement';
  else
    raise exception 'unknown kind %', p_kind;
  end if;
  get diagnostics n = row_count;
  insert into public.archive_runs (kind, moved, ok, note) values (p_kind, n, true, p_note);
  return n;
end;
$$;

revoke all on function public.archive_take(text, integer) from public, anon, authenticated;
revoke all on function public.archive_drop(text, jsonb, text) from public, anon, authenticated;
grant execute on function public.archive_take(text, integer) to service_role;
grant execute on function public.archive_drop(text, jsonb, text) to service_role;
