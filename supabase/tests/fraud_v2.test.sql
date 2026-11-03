-- SolutionTee CBT · Fraud v2 (D-079): phone-wide id, clones, second accounts refused, phone bans. Always rolled back.
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

create temp table h as select repeat('d', 64) as drm, repeat('1', 64) as a1, repeat('2', 64) as a2, repeat('3', 64) as a3;
grant select on h to authenticated, anon;
insert into auth.users (id, email, aud, role, created_at, email_confirmed_at) values
  ('00000000-0000-4000-8000-00000000a001', 'u1@g.test', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-4000-8000-00000000a002', 'u2@g.test', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-4000-8000-00000000a003', 'u3@g.test', 'authenticated', 'authenticated', now(), now()),
  ('00000000-0000-4000-8000-00000000a009', 'a9@g.test', 'authenticated', 'authenticated', now(), now());
insert into public.staff (user_id, role) values ('00000000-0000-4000-8000-00000000a009', 'admin');
select tests.check(private.new_referral_code('Oluwaseunfunmi Ade') ~ '^OLUWASEUNFUN-[A-Z2-9]{4}$', 'long first names fit in the code (12 letters)', private.new_referral_code('Oluwaseunfunmi Ade'));

select tests.as_user('00000000-0000-4000-8000-00000000a001');
select public.device_check_in(array[(select drm from h), (select a1 from h)], '{}');
-- the dual app copy: same phone-wide id, different Android ID, and the phone says it is a second user
select tests.as_user('00000000-0000-4000-8000-00000000a002');
create temp table s2 as select public.device_check_in(array[(select drm from h), (select a2 from h)], array['clone:second-user']) as j;
select tests.check((select (j ->> 'phone_taken')::boolean and (j ->> 'clone')::boolean from s2), 'a dual-app account on the same phone is caught (phone-wide id) and the clone is seen', (select j::text from s2));
select tests.check(private.is_banned('00000000-0000-4000-8000-00000000a002') and not private.is_banned('00000000-0000-4000-8000-00000000a001'),
  'the server refuses the second account''s data, not the first');
reset role;
select tests.check((select count(*) from public.device_events where user_id = '00000000-0000-4000-8000-00000000a002' and kind in ('clone', 'second_account')) = 2,
  'both are in the activity log');

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-00000000a009', 'role', 'authenticated', 'aal', 'aal2')::text, true);
create temp table bd as select public.admin_ban_device((select drm from h), 'Many fake accounts on one phone') as j;
create temp table fr as select public.admin_fraud() as j;
reset role;
select tests.check((select (j ->> 'accounts')::int = 2 and (j ->> 'ids')::int = 3 from bd), 'banning the phone bans all its ids and every account on it', (select j::text from bd));
select tests.check((select (j -> 'stats' ->> 'banned_phones')::int >= 3 and jsonb_array_length(j -> 'events') > 0 from fr), 'the fraud page shows banned phones and activity');
set local role anon;
select tests.check((public.device_status(array[(select drm from h), (select a1 from h)]) ->> 'banned')::boolean, 'before sign-in, the app learns the phone is banned');
select tests.check((public.device_status(array[null, (select a2 from h)]) ->> 'banned')::boolean, 'also by the Android ID alone (older app)');
reset role;
select tests.as_user('00000000-0000-4000-8000-00000000a003');
create temp table s3 as select public.device_check_in(array[(select drm from h), (select a3 from h)], '{}') as j;
select tests.check((select (j ->> 'phone_banned')::boolean from s3) and private.is_banned('00000000-0000-4000-8000-00000000a003'),
  'a new account on a banned phone is banned at once');
reset role;
set local role anon;
select tests.throws($q$ select public.device_appeal(array[(select drm from h)], 'not-an-email', 'Please let me back in, it was my brother') $q$, '22023', null, 'the appeal needs an email to reply to');
select public.device_appeal(array[(select drm from h)], 'u1@g.test', 'It was my brother. I only have one account.');
select tests.throws($q$ select public.device_appeal(array[(select drm from h)], 'u1@g.test', 'Again please, it was my brother.') $q$, 'P0001', '%already%', 'one waiting appeal per phone');
reset role;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-00000000a009', 'role', 'authenticated', 'aal', 'aal2')::text, true);
select public.admin_device_appeal((select id from public.device_appeals where device_hash = (select drm from h)), true, 'OK');
reset role;
select tests.check(not exists (select 1 from public.banned_devices where device_hash in ((select drm from h), (select a1 from h)) and lifted_at is null)
  and (select banned_at is null from public.profiles where id = '00000000-0000-4000-8000-00000000a001'), 'accepting the appeal lifts the phone ban and opens its accounts');
do $r$ declare r text; begin select string_agg(n || ' ' || case when ok then 'ok' else 'FAIL' end || ' ' || name || coalesce(' | ' || detail, ''), E'\n' order by n) into r from tests.results; raise exception 'RESULTS %', E'\n' || r; end $r$;
