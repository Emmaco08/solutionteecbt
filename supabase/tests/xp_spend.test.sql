-- SolutionTee CBT · XP3 (D-083): entry fees (earned only for cash), Premium with XP, XP prizes. Always rolled back.
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

update public.app_settings set value = value || '{"enabled": true, "challenge_top": [200, 100, 50], "premium_prices": {"monthly": 500}}' where key = 'xp';
insert into auth.users (id, email, aud, role, created_at, email_confirmed_at) values
  ('00000000-0000-4000-8000-00000000d001', 'p1@p.test', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-4000-8000-00000000d002', 'p2@p.test', 'authenticated', 'authenticated', now(), now());
create temp table chs as with ins as (insert into public.challenges (title, kind, mode, starts_at, ends_at, prizes, published, xp_fee) values
  ('TSTXP cash', 'cash', 'fixed', now() - interval '5 minutes', now() + interval '1 hour', '{1000}', true, 100),
  ('TSTXP event', 'event', 'fixed', now() - interval '5 minutes', now() + interval '1 hour', '{}', true, 100) returning id, title) select * from ins;
grant select on chs to authenticated;
insert into public.challenge_questions (challenge_id, position, body, options, answer, difficulty)
select c.id, g, 'q' || g, '{"A":"1","B":"2","C":"3","D":"4"}', 'A', 'easy' from chs c, generate_series(1, 2) g;
select private.xp_add('00000000-0000-4000-8000-00000000d001', 100, 'bought', 'pack', null, 'pk:d1');
select private.xp_add('00000000-0000-4000-8000-00000000d001', 50, 'earned', 'admin', null, 'ad:d1', false, '00000000-0000-4000-8000-00000000d001');
select tests.as_user('00000000-0000-4000-8000-00000000d001');
select tests.check((select (public.challenge_detail((select id from chs where title = 'TSTXP cash')) ->> 'xp_fee')::int) = 100, 'the challenge shows its XP fee');
select tests.throws($q$ select public.challenge_start((select id from chs where title = 'TSTXP cash')) $q$, 'P0001', '%Bought XP cannot%', 'a cash challenge refuses bought XP');
select tests.check(not exists (select 1 from public.challenge_entries where user_id = '00000000-0000-4000-8000-00000000d001'), 'and no entry is made');
select public.challenge_start((select id from chs where title = 'TSTXP event'));
reset role;
select tests.check((select xp_bought = 0 and xp_earned = 50 from public.profiles where id = '00000000-0000-4000-8000-00000000d001'), 'a non-cash event takes bought XP first (100)');
select private.xp_add('00000000-0000-4000-8000-00000000d002', 600, 'earned', 'admin', null, 'ad:d2', false, '00000000-0000-4000-8000-00000000d002');
select tests.as_user('00000000-0000-4000-8000-00000000d002');
select tests.check((select jsonb_array_length(public.my_xp() -> 'premium_options')) >= 1, 'the wallet lists plans sold for XP');
create temp table pr as select public.xp_buy_premium('monthly') as j;
select tests.throws($q$ select public.xp_buy_premium('three_months') $q$, 'P0001', '%cannot be bought with XP%', 'a plan with no XP price cannot be bought');
reset role;
select tests.check((select (j ->> 'balance')::int from pr) = 100 and exists (select 1 from public.entitlements where user_id = '00000000-0000-4000-8000-00000000d002' and source = 'xp' and expires_at > now()),
  'Premium with XP: 500 XP taken, Premium given', (select j::text from pr));
update public.challenges set closed_at = now(), ends_at = now() - interval '1 minute' where title = 'TSTXP event';
update public.challenge_entries set status = 'finished', rank = 1, score = 2 where user_id = '00000000-0000-4000-8000-00000000d001';
select private.xp_prize_job();
select private.xp_prize_job();
select tests.check((select count(*) from public.xp_ledger where user_id = '00000000-0000-4000-8000-00000000d001' and reason = 'challenge_top' and amount = 200) = 1,
  'the winner gets 200 XP, once');
select tests.check(private.xp_weekly_job() >= 0, 'the weekly job runs');
do $r$ declare r text; begin select string_agg(n || ' ' || case when ok then 'ok' else 'FAIL' end || ' ' || name || coalesce(' | ' || detail, ''), E'\n' order by n) into r from tests.results; raise exception 'RESULTS %', E'\n' || r; end $r$;
