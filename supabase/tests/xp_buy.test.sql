-- SolutionTee CBT · XP4 (D-084): XP packs with Paystack — price, once, wrong amount, refund. Always rolled back.
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

update public.app_settings set value = value || '{"enabled": true, "packs": [{"xp": 200, "naira": 200}, {"xp": 550, "naira": 500}]}' where key = 'xp';
insert into auth.users (id, email, aud, role, created_at, email_confirmed_at) values ('00000000-0000-4000-8000-00000000e001', 'k1@k.test', 'authenticated', 'authenticated', now(), now());
create temp table st as select public.xp_pack_start('00000000-0000-4000-8000-00000000e001', 550, 'app') as j;
select tests.check((select (j ->> 'amount_kobo')::int = 50000 from st), 'the price comes from the admin''s packs (550 XP = ₦500)', (select j::text from st));
select tests.check((public.xp_pack_start('00000000-0000-4000-8000-00000000e001', 999, 'app') ->> 'error') = 'pack', 'a pack that does not exist is refused');
select public.pay_paystack_result((select j ->> 'reference' from st), 'success', 50000, 'NGN', 'card', '{}', 'webhook', 'evt-test-1');
select public.pay_paystack_result((select j ->> 'reference' from st), 'success', 50000, 'NGN', 'card', '{}', 'verify', null);
select tests.check((select xp_bought from public.profiles where id = '00000000-0000-4000-8000-00000000e001') = 550, 'paid: 550 bought XP added once');
select tests.check((select status from public.payments where reference = (select j ->> 'reference' from st)) = 'success', 'the payment is marked paid');
create temp table st2 as select public.xp_pack_start('00000000-0000-4000-8000-00000000e001', 200, 'app') as j;
select public.pay_paystack_result((select j ->> 'reference' from st2), 'success', 100, 'NGN', 'card', '{}', 'webhook', 'evt-test-2');
select tests.check((select xp_bought from public.profiles where id = '00000000-0000-4000-8000-00000000e001') = 550 and
  (select status from public.payments where reference = (select j ->> 'reference' from st2)) = 'needs_review', 'a wrong amount gives no XP and is checked by hand');
select private.xp_take('00000000-0000-4000-8000-00000000e001', 100, true, 'freeze', null, 'spend:k1');
select public.pay_refunded('paystack', (select j ->> 'reference' from st), null, null, '{}', 'evt-refund-1');
select tests.check((select xp_bought from public.profiles where id = '00000000-0000-4000-8000-00000000e001') = 0, 'a refund takes back the unspent bought XP');
do $r$ declare r text; begin select string_agg(n || ' ' || case when ok then 'ok' else 'FAIL' end || ' ' || name || coalesce(' | ' || detail, ''), E'\n' order by n) into r from tests.results; raise exception 'RESULTS %', E'\n' || r; end $r$;
