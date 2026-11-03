-- SolutionTee CBT · 4E3 referrals, one account per phone, bans (D-078). Always rolled back.
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

-- r = referrer, f1 = friend on their own phone, f2 = friend on r's phone, f3 = second account on f1's phone, a = admin
insert into auth.users (id, email, aud, role, created_at, email_confirmed_at) values
  ('00000000-0000-4000-8000-0000000000f0', 'r@f.test', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-4000-8000-0000000000fa', 'a@f.test', 'authenticated', 'authenticated', now(), now());
update public.profiles set full_name = 'Tolu Referrer' where id = '00000000-0000-4000-8000-0000000000f0';
insert into public.staff (user_id, role) values ('00000000-0000-4000-8000-0000000000fa', 'admin');
-- The test uses the default rules (the live ones may differ; everything is rolled back).
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-0000000000fa', 'role', 'authenticated', 'aal', 'aal2')::text, true);
select public.admin_referral_settings('{"enabled": true, "pct_per_friend": 10, "max_pct": 100, "count_on": "test", "cash_every": 30, "cash_naira": 5000, "monthly_cap": 20}');
reset role;
select tests.as_user('00000000-0000-4000-8000-0000000000f0');
create temp table my as select public.my_referrals() as j;
select tests.check((select j ->> 'code' from my) ~ '^TOLU-[A-Z2-9]{4}$', 'the student gets a code made from their name', (select j ->> 'code' from my));
select public.device_register(repeat('a', 64));
reset role;
insert into auth.users (id, email, aud, role, created_at, email_confirmed_at, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000000f1', 'f1@f.test', 'authenticated', 'authenticated', now(), now(), jsonb_build_object('referral_code', (select j ->> 'code' from my))),
  ('00000000-0000-4000-8000-0000000000f2', 'f2@f.test', 'authenticated', 'authenticated', now(), now(), jsonb_build_object('referral_code', lower((select j ->> 'code' from my)))),
  ('00000000-0000-4000-8000-0000000000f3', 'f3@f.test', 'authenticated', 'authenticated', now(), now(), '{}');
update public.profiles set full_name = 'Ada Friend' where id = '00000000-0000-4000-8000-0000000000f1';
select tests.check((select count(*) from public.referrals where referrer = '00000000-0000-4000-8000-0000000000f0' and status = 'pending') = 2,
  'the code typed at sign-up makes a pending friend (any letter case)');

-- f1: own phone, finishes a test → counts
select tests.as_user('00000000-0000-4000-8000-0000000000f1');
select public.device_register(repeat('b', 64));
reset role;
select tests.check((select reason from public.referrals where friend = '00000000-0000-4000-8000-0000000000f1') like '%finishes one practice test%',
  'not yet: the friend has not finished a test');
insert into public.attempts (id, user_id, exam_id, mode, question_ids, started_at, submitted_at, time_used_s, server_score, status)
values (gen_random_uuid(), '00000000-0000-4000-8000-0000000000f1', 1, 'quick', array[(select id from public.questions limit 1)], now() - interval '10 minutes', now(), 600, '{}', 'submitted');
select tests.check((select status from public.referrals where friend = '00000000-0000-4000-8000-0000000000f1') = 'counted',
  'a friend counts after one finished test on their own phone');
select tests.check(exists (select 1 from public.notifications where user_id = '00000000-0000-4000-8000-0000000000f0' and title = 'A friend joined with your code'),
  'and the student is told');
insert into public.attempts (id, user_id, exam_id, mode, question_ids, started_at, submitted_at, time_used_s, server_score, status)
values (gen_random_uuid(), '00000000-0000-4000-8000-0000000000f1', 1, 'quick', array[(select id from public.questions limit 1)], now() - interval '5 minutes', now(), 300, '{}', 'submitted');
select tests.check((select count(*) from public.notifications where user_id = '00000000-0000-4000-8000-0000000000f0' and title = 'A friend joined with your code') = 1,
  'a friend counts only once');

-- f2: on the referrer's phone → blocked
select tests.as_user('00000000-0000-4000-8000-0000000000f2');
select public.device_register(repeat('a', 64));
reset role;
insert into public.attempts (id, user_id, exam_id, mode, question_ids, started_at, submitted_at, time_used_s, server_score, status)
values (gen_random_uuid(), '00000000-0000-4000-8000-0000000000f2', 1, 'quick', array[(select id from public.questions limit 1)], now() - interval '10 minutes', now(), 600, '{}', 'submitted');
select tests.check((select status = 'blocked' and reason like 'Same phone%' from public.referrals where friend = '00000000-0000-4000-8000-0000000000f2'),
  'a friend on the referrer''s phone does not count');

-- f3: second account on f1's phone → phone taken; admin can allow it
select tests.as_user('00000000-0000-4000-8000-0000000000f3');
create temp table st as select public.device_register(repeat('b', 64)) as j;
select tests.check((select (j ->> 'phone_taken')::boolean from st), 'a second account on a phone sees "this phone already has an account"');
reset role;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-0000000000fa', 'role', 'authenticated', 'aal', 'aal2')::text, true);
select public.admin_device_allow(repeat('b', 64), '00000000-0000-4000-8000-0000000000f3', true);
select tests.as_user('00000000-0000-4000-8000-0000000000f3');
select tests.check(not (public.my_status() ->> 'phone_taken')::boolean, 'the admin can allow a second account on a shared phone');

-- self-referral
select tests.as_user('00000000-0000-4000-8000-0000000000f0');
select tests.throws($q$ select public.referral_apply((select j ->> 'code' from my)) $q$, 'P0001', '%own code%', 'a student cannot use their own code');

-- discount by the server, spent when paid
reset role;
create temp table pr as select private.price('00000000-0000-4000-8000-0000000000f0', p, null) as j from public.plans p where p.code = 'monthly';
select tests.check((select (j ->> 'referral_friends')::int = 1 and (j ->> 'discount_kobo')::int = 15000 from pr), '1 counted friend = 10% off, worked out on the server', (select j::text from pr));
create temp table pay as with ins as (
  insert into public.payments (user_id, provider, plan_id, reference, list_kobo, discount_kobo, amount_kobo, source, referral_friends)
  values ('00000000-0000-4000-8000-0000000000f0', 'paystack', (select id from public.plans where code = 'monthly'), 'st_test_ref_1', 150000, 15000, 135000, 'app', 1)
  returning id) select * from ins;
update public.payments set status = 'success' where id = (select id from pay);
select tests.check((select spent_payment = (select id from pay) from public.referrals where friend = '00000000-0000-4000-8000-0000000000f1'),
  'paying spends the friend');
select tests.check((select (j ->> 'discount_kobo')::int = 0 from (select private.price('00000000-0000-4000-8000-0000000000f0', p, null) as j from public.plans p where p.code = 'monthly') x),
  'so the next price has no discount');

-- cash every N friends (admin sets N = 1 here)
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-0000000000fa', 'role', 'authenticated', 'aal', 'aal2')::text, true);
select public.admin_referral_settings('{"enabled": true, "pct_per_friend": 10, "max_pct": 100, "count_on": "test", "cash_every": 1, "cash_naira": 5000, "monthly_cap": 20}');
reset role;
select private.referral_milestones('00000000-0000-4000-8000-0000000000f0');
select tests.check((select count(*) from public.referral_rewards where user_id = '00000000-0000-4000-8000-0000000000f0' and amount = 5000 and status = 'due') = 1,
  'a cash reward is due at the milestone');
select tests.as_user('00000000-0000-4000-8000-0000000000f0');
select tests.throws($q$ select public.referral_claim((select id from public.referral_rewards limit 1), 'GTBank', '12345', 'Tolu R') $q$, '22023', null,
  'the account number must have 10 digits');
select public.referral_claim((select id from public.referral_rewards where user_id = '00000000-0000-4000-8000-0000000000f0'), 'GTBank', '0123456789', 'Tolu Referrer');

-- ban: cancels unpaid rewards, blocks the app's data, one appeal, admin accepts
reset role;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-0000000000fa', 'role', 'authenticated', 'aal', 'aal2')::text, true);
create temp table b as select public.admin_ban('00000000-0000-4000-8000-0000000000f0', true, 'Many fake accounts', true) as j;
reset role;
select tests.check((select (j ->> 'accounts')::int from b) = 2, 'banning with linked accounts also bans the other account on the same phone', (select j::text from b));
select tests.check((select status from public.referral_rewards where user_id = '00000000-0000-4000-8000-0000000000f0') = 'cancelled', 'unpaid rewards are cancelled');
select tests.as_user('00000000-0000-4000-8000-0000000000f0');
select tests.check((public.my_status() ->> 'banned')::boolean and (public.my_status() ->> 'can_appeal')::boolean, 'the student sees the ban and can appeal');
select tests.throws($q$ select public.my_referrals() $q$, '42501', null, 'a banned student cannot use referrals');
select public.ban_appeal('I only have one account. My brother used my phone.');
select tests.throws($q$ select public.ban_appeal('Second appeal for the same ban please') $q$, 'P0001', '%already%', 'one appeal per ban');
reset role;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-0000000000fa', 'role', 'authenticated', 'aal', 'aal2')::text, true);
select public.admin_ban_appeal((select id from public.ban_appeals where user_id = '00000000-0000-4000-8000-0000000000f0'), true, 'Thanks for explaining.');
reset role;
select tests.check((select banned_at is null from public.profiles where id = '00000000-0000-4000-8000-0000000000f0'), 'accepting the appeal opens the account again');
select tests.check(exists (select 1 from public.audit_log where action = 'user.ban' and row_id = '00000000-0000-4000-8000-0000000000f0'), 'bans go to the audit log');

reset role;
do $r$ declare r text; begin select string_agg(n || ' ' || case when ok then 'ok' else 'FAIL' end || ' ' || name || coalesce(' | ' || detail, ''), E'\n' order by n) into r from tests.results; raise exception 'RESULTS %', E'\n' || r; end $r$;
