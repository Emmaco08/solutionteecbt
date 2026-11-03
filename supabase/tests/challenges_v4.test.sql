-- SolutionTee CBT · Challenges v4 (D-075): answer review switch, screenshot reports. Always rolled back.
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

insert into auth.users (id, email, aud, role, created_at) values
  ('00000000-0000-4000-8000-0000000000d1', 'd1@d.test', 'authenticated', 'authenticated', now()),
  ('00000000-0000-4000-8000-0000000000d2', 'd2@d.test', 'authenticated', 'authenticated', now()),
  ('00000000-0000-4000-8000-0000000000d9', 'd9@d.test', 'authenticated', 'authenticated', now());
insert into public.staff (user_id, role) values ('00000000-0000-4000-8000-0000000000d9', 'editor');
create temp table chs as
with ins as (insert into public.challenges (title, kind, mode, starts_at, ends_at, prizes, published) values
  ('TSTV4', 'event', 'fixed', now() - interval '5 minutes', now() + interval '1 hour', '{}', true) returning id) select * from ins;
grant select on chs to authenticated;
insert into public.challenge_questions (challenge_id, position, body, options, answer, difficulty)
select (select id from chs), g, 'TSTV4 q' || g, '{"A":"1","B":"2","C":"3","D":"4"}', 'A', 'easy' from generate_series(1, 3) g;

-- screenshot / recording reports become fair-play flags
select tests.as_user('00000000-0000-4000-8000-0000000000d1');
create temp table p1 as select public.challenge_start((select id from chs)) as j;
select public.challenge_report((select (j -> 'question' ->> 'entry_id')::uuid from p1), 'screenshot');
select public.challenge_report((select (j -> 'question' ->> 'entry_id')::uuid from p1), 'screenshot');
select tests.throws($q$ select public.challenge_report((select (j -> 'question' ->> 'entry_id')::uuid from p1), 'other') $q$, '22023', null, 'only known reports');
select tests.as_user('00000000-0000-4000-8000-0000000000d2');
select public.challenge_report((select (j -> 'question' ->> 'entry_id')::uuid from p1), 'recording');
reset role;
select tests.check((select device_flags = array['Tried to take a screenshot'] from public.challenge_entries where user_id = '00000000-0000-4000-8000-0000000000d1'),
  'a screenshot attempt is saved once, and another student cannot add flags to it',
  (select device_flags::text from public.challenge_entries where user_id = '00000000-0000-4000-8000-0000000000d1'));
select private.challenge_finish((select (j -> 'question' ->> 'entry_id')::uuid from p1), 'finished');
select tests.check((select 'Tried to take a screenshot' = any (flags) from public.challenge_entries where user_id = '00000000-0000-4000-8000-0000000000d1'),
  'and it shows in the fair-play checks when the entry finishes');

-- the admin decides whether answers can be reviewed, also after the end
update public.challenges set ends_at = now() - interval '1 second' where id = (select id from chs);
select tests.as_user('00000000-0000-4000-8000-0000000000d1');
select tests.check((public.challenge_detail((select id from chs)) -> 'mine' ->> 'can_review')::boolean, 'review is on by default');
select tests.throws($q$ select public.admin_challenge_set_review((select id from chs), false) $q$, '42501', null, 'students cannot change it');
reset role;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-0000000000d9', 'role', 'authenticated', 'aal', 'aal2')::text, true);
select public.admin_challenge_set_review((select id from chs), false);
select tests.as_user('00000000-0000-4000-8000-0000000000d1');
select tests.check(not (public.challenge_detail((select id from chs)) -> 'mine' ->> 'can_review')::boolean, 'the admin can turn review off after the end');
select tests.throws($q$ select public.challenge_review((select id from chs)) $q$, 'P0001', '%turned off%', 'and the server then refuses the answers');

reset role;
do $r$ declare r text; begin select string_agg(n || ' ' || case when ok then 'ok' else 'FAIL' end || ' ' || name || coalesce(' | ' || detail, ''), E'\n' order by n) into r from tests.results; raise exception 'RESULTS %', E'\n' || r; end $r$;
