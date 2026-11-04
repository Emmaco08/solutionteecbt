-- SolutionTee CBT · XP1 (D-081): daily claim, earning rules, caps, bans, earned vs bought, admin. Always rolled back.
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

insert into auth.users (id, email, aud, role, created_at, email_confirmed_at) values
  ('00000000-0000-4000-8000-00000000b001', 'x1@x.test', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-4000-8000-00000000b002', 'x2@x.test', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-4000-8000-00000000b009', 'x9@x.test', 'authenticated', 'authenticated', now(), now());
insert into public.staff (user_id, role) values ('00000000-0000-4000-8000-00000000b009', 'admin');
-- default rules for the test (the live ones may differ; rolled back)
update public.app_settings set value = value || '{"enabled": true, "daily_claim": 10, "daily_cap": 300, "test": 5, "test_min_questions": 10, "test_min_seconds": 120, "tests_per_day": 10, "mock": 30, "mocks_per_day": 2, "score_bonus_per_10": 1, "qotd": 2, "qotd_right": 3}' where key = 'xp';
select tests.as_user('00000000-0000-4000-8000-00000000b001');
create temp table c1 as select public.xp_claim_daily() as j;
create temp table c2 as select public.xp_claim_daily() as j;
select tests.check((select (j ->> 'given')::int from c1) = 10 and (select (j ->> 'already')::boolean from c2), 'the daily claim gives 10 XP once a day', (select j::text from c2));
reset role;
insert into public.attempts (id, user_id, exam_id, mode, question_ids, started_at, submitted_at, time_used_s, server_score, status)
values (gen_random_uuid(), '00000000-0000-4000-8000-00000000b001', 1, 'quick', array[(select id from public.questions limit 1)], now() - interval '10 minutes', now(), 600,
        '{"answered": 20, "total": 20, "correct": 16}', 'submitted');
select tests.check((select sum(amount) from public.xp_ledger where user_id = '00000000-0000-4000-8000-00000000b001' and reason = 'test') = 8, 'a finished test earns 5 XP plus a score bonus');
insert into public.attempts (id, user_id, exam_id, mode, question_ids, started_at, submitted_at, time_used_s, server_score, status)
values (gen_random_uuid(), '00000000-0000-4000-8000-00000000b001', 1, 'quick', array[(select id from public.questions limit 1)], now() - interval '1 minute', now(), 40,
        '{"answered": 5, "total": 5, "correct": 5}', 'submitted');
select tests.check((select count(*) from public.xp_ledger where user_id = '00000000-0000-4000-8000-00000000b001' and reason = 'test') = 1, 'a very short test earns nothing');
insert into public.attempts (id, user_id, exam_id, mode, question_ids, started_at, submitted_at, time_used_s, server_score, status)
select gen_random_uuid(), '00000000-0000-4000-8000-00000000b001', 1, 'full', array[(select id from public.questions limit 1)], now() - interval '2 hours', now(), 7200,
        '{"answered": 180, "total": 180, "correct": 90}', 'submitted' from generate_series(1, 3);
select tests.check((select count(*) from public.xp_ledger where user_id = '00000000-0000-4000-8000-00000000b001' and reason = 'mock') = 2, 'mocks earn 30 XP, two a day');
insert into public.qotd_answers (user_id, day, choice, correct, answered_at, qotd_id) values ('00000000-0000-4000-8000-00000000b001', '2090-01-01', 'A', true, now(), (select id from public.qotd limit 1));
select tests.check((select amount from public.xp_ledger where user_id = '00000000-0000-4000-8000-00000000b001' and reason = 'qotd') = 5, 'question of the day right: 5 XP');
update public.app_settings set value = value || '{"daily_cap": 20}' where key = 'xp';
insert into public.attempts (id, user_id, exam_id, mode, question_ids, started_at, submitted_at, time_used_s, server_score, status)
values (gen_random_uuid(), '00000000-0000-4000-8000-00000000b001', 1, 'quick', array[(select id from public.questions limit 1)], now() - interval '10 minutes', now(), 600,
        '{"answered": 20, "total": 20, "correct": 10}', 'submitted');
select tests.check((select count(*) from public.xp_ledger where user_id = '00000000-0000-4000-8000-00000000b001' and reason = 'test') = 1, 'nothing more after the daily cap');
update public.app_settings set value = value || '{"daily_cap": 300}' where key = 'xp';
select tests.check((select xp_earned from public.profiles where id = '00000000-0000-4000-8000-00000000b001') = 10 + 8 + 60 + 5, 'the balance matches the ledger',
  (select xp_earned::text from public.profiles where id = '00000000-0000-4000-8000-00000000b001'));
update public.profiles set banned_at = now(), ban_reason = 'test' where id = '00000000-0000-4000-8000-00000000b002';
select tests.as_user('00000000-0000-4000-8000-00000000b002');
select tests.throws($q$ select public.xp_claim_daily() $q$, '42501', null, 'a banned student cannot claim XP');
reset role;
select private.xp_add('00000000-0000-4000-8000-00000000b001', 100, 'bought', 'pack', 'p1', 'pack:test1');
select tests.throws($q$ select private.xp_take('00000000-0000-4000-8000-00000000b001', 100, false, 'entry', 'c', 'entry:1') $q$, 'P0001', '%Bought XP cannot%',
  'bought XP is refused where only earned XP counts (cash challenges)');
select tests.check((select (private.xp_take('00000000-0000-4000-8000-00000000b001', 150, true, 'premium', 'x', 'spend:1') ->> 'bought')::int) = 100,
  'elsewhere bought XP is spent first');
select tests.check((select xp_bought = 0 and xp_earned = 83 - 50 from public.profiles where id = '00000000-0000-4000-8000-00000000b001'), 'balances after spending');
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-00000000b009', 'role', 'authenticated', 'aal', 'aal2')::text, true);
select public.admin_xp_adjust('00000000-0000-4000-8000-00000000b001', 500, 'Winner of the school quiz');
create temp table ov as select public.admin_xp_overview() as j;
select public.admin_xp_settings('{"enabled": false}');
reset role;
select tests.check((select xp_earned from public.profiles where id = '00000000-0000-4000-8000-00000000b001') = 533 and exists (select 1 from public.audit_log where action = 'xp.adjust'),
  'admin can give XP with a reason (logged)');
select tests.check((select (j -> 'totals' ->> 'in_wallets')::int >= 533 from ov), 'the overview has totals');
select tests.as_user('00000000-0000-4000-8000-00000000b001');
select tests.check((public.xp_claim_daily() ->> 'off')::boolean and not (public.my_xp() ->> 'enabled')::boolean, 'XP switched off: no claim, the app hides XP');
reset role;
do $r$ declare r text; begin select string_agg(n || ' ' || case when ok then 'ok' else 'FAIL' end || ' ' || name || coalesce(' | ' || detail, ''), E'\n' order by n) into r from tests.results; raise exception 'RESULTS %', E'\n' || r; end $r$;
