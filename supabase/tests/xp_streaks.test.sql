-- SolutionTee CBT · XP2 (D-082): streak days, milestones, celebration once, freezes, repair. Always rolled back.
begin;
create schema tests;
grant usage on schema tests to anon, authenticated, service_role;
create table tests.results (n serial, ok boolean, name text, detail text);
grant all on tests.results to anon, authenticated, service_role;
grant usage, select on sequence tests.results_n_seq to anon, authenticated, service_role;
create function tests.check(cond boolean, name text, detail text default null) returns void
language sql as $$ insert into tests.results (ok, name, detail) values (coalesce(cond, false), name, detail); $$;
create function tests.throws(stmt text, state text, msg text, name text) returns void
language plpgsql as $$
begin
  execute stmt;
  perform tests.check(false, name, 'no error');
exception when others then
  perform tests.check(sqlstate = state and (msg is null or sqlerrm like msg), name, sqlstate || ' ' || sqlerrm);
end $$;
create function tests.as_user(uid uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  select set_config('role', 'authenticated', true);
$$;
grant execute on all functions in schema tests to anon, authenticated, service_role;

update public.app_settings set value = value || '{"enabled": true, "milestones": {"3": 20, "7": 50}, "freeze_price": 50, "freeze_max": 2, "repair_price": 200, "repair_on": true}' where key = 'xp';
insert into auth.users (id, email, aud, role, created_at, email_confirmed_at) values
  ('00000000-0000-4000-8000-00000000c001', 's1@s.test', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-4000-8000-00000000c002', 's2@s.test', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-4000-8000-00000000c003', 's3@s.test', 'authenticated', 'authenticated', now(), now());
create temp table q as select (select id from public.questions limit 1) as qid, (private.lagos_today()::timestamp at time zone 'Africa/Lagos') + interval '12 hours' as noon;
-- s1: tests 2 days ago and yesterday, question of the day today → 3-day streak
insert into public.attempts (id, user_id, exam_id, mode, question_ids, started_at, submitted_at, time_used_s, server_score, status)
select gen_random_uuid(), '00000000-0000-4000-8000-00000000c001', 1, 'quick', array[(select qid from q)], (select noon from q) - (d || ' days')::interval, (select noon from q) - (d || ' days')::interval, 30, '{"answered": 2, "total": 2, "correct": 1}', 'submitted'
from generate_series(1, 2) d;
insert into public.qotd_answers (user_id, day, choice, correct, answered_at, qotd_id) values ('00000000-0000-4000-8000-00000000c001', '2090-02-02', 'A', false, now(), (select id from public.qotd limit 1));
select tests.as_user('00000000-0000-4000-8000-00000000c001');
create temp table m1 as select public.my_streak() as j;
select tests.check((select (j ->> 'current')::int = 3 and (j ->> 'today_done')::boolean from m1), 'the question of the day keeps the streak too (3 days)', (select (j ->> 'current') from m1));
select tests.check((select (j -> 'celebrate' ->> 'days')::int = 3 and (j -> 'celebrate' ->> 'xp')::int = 20 from m1), 'reaching 3 days gives the bonus and a celebration');
select tests.check((select (j -> 'next' ->> 'days')::int = 7 and (j -> 'next' ->> 'left')::int = 4 from m1), 'the next milestone and days left');
select tests.check((select jsonb_array_length(j -> 'week') = 7 from m1), 'this week has 7 days');
select public.streak_seen((select j -> 'celebrate' ->> 'key' from m1));
select tests.check(public.my_streak() -> 'celebrate' = 'null'::jsonb or public.my_streak() -> 'celebrate' is null, 'a celebration shows once');
reset role;
select private.streak_check('00000000-0000-4000-8000-00000000c001');
select tests.check((select count(*) from public.xp_ledger where user_id = '00000000-0000-4000-8000-00000000c001' and reason = 'streak') = 1, 'the bonus is given once per streak');
-- s2: practised 2 days ago, missed yesterday → repair offered; with a freeze the nightly job saves it instead
insert into public.attempts (id, user_id, exam_id, mode, question_ids, started_at, submitted_at, time_used_s, server_score, status)
values (gen_random_uuid(), '00000000-0000-4000-8000-00000000c002', 1, 'quick', array[(select qid from q)], (select noon from q) - interval '2 days', (select noon from q) - interval '2 days', 30, '{"answered": 2, "total": 2, "correct": 1}', 'submitted');
select private.xp_add('00000000-0000-4000-8000-00000000c002', 300, 'earned', 'admin', null, 'test:give:c2', false, '00000000-0000-4000-8000-00000000c002');
select tests.as_user('00000000-0000-4000-8000-00000000c002');
select tests.check((select (public.my_streak() -> 'repair' ->> 'lost')::int) = 1, 'a streak lost yesterday can be repaired today');
create temp table f as select public.streak_buy_freeze() as j;
select tests.check((select (j ->> 'freezes')::int from f) = 1 and (select xp_earned from public.profiles where id = '00000000-0000-4000-8000-00000000c002') = 250, 'a freeze costs 50 XP');
reset role;
select tests.check(private.streak_freeze_job() >= 1, 'the nightly job uses the freeze');
select tests.as_user('00000000-0000-4000-8000-00000000c002');
create temp table m2 as select public.my_streak() as j;
select tests.check((select (j ->> 'current')::int = 2 and (j ->> 'freezes')::int = 0 and j -> 'repair' = 'null'::jsonb from m2), 'the streak is kept (2 days), the freeze is used');
reset role;
-- s3: lost a streak; repair costs 200 XP; not enough XP is refused
insert into public.attempts (id, user_id, exam_id, mode, question_ids, started_at, submitted_at, time_used_s, server_score, status)
select gen_random_uuid(), '00000000-0000-4000-8000-00000000c003', 1, 'quick', array[(select qid from q)], (select noon from q) - (d || ' days')::interval, (select noon from q) - (d || ' days')::interval, 30, '{"answered": 2, "total": 2, "correct": 1}', 'submitted'
from generate_series(2, 5) d;
select tests.as_user('00000000-0000-4000-8000-00000000c003');
select tests.throws($q$ select public.streak_repair() $q$, 'P0001', '%Not enough XP%', 'repair needs enough XP');
reset role;
select private.xp_add('00000000-0000-4000-8000-00000000c003', 250, 'earned', 'admin', null, 'test:give:c3', false, '00000000-0000-4000-8000-00000000c003');
select tests.as_user('00000000-0000-4000-8000-00000000c003');
create temp table r3 as select public.streak_repair() as j;
select tests.check((select (j ->> 'current')::int from r3) = 5, 'after repair the 4-day streak continues (5 with the repaired day)', (select (j ->> 'current') from r3));
reset role;
do $r$ declare r text; begin select string_agg(n || ' ' || case when ok then 'ok' else 'FAIL' end || ' ' || name || coalesce(' | ' || detail, ''), E'\n' order by n) into r from tests.results; raise exception 'RESULTS %', E'\n' || r; end $r$;
