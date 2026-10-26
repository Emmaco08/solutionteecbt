-- SolutionTee CBT · RLS and server-rule tests (Phase 2)
-- Runs inside one transaction and is ALWAYS rolled back, so it is safe on the dev database.
-- Runner: scripts/run-db-tests.mjs (reads the _results table before the rollback).
begin;

-- Helpers live in a throw-away schema (rolled back with everything else).
create schema tests;
grant usage on schema tests to anon, authenticated;
create table tests.results (n serial, ok boolean, name text, detail text);
grant all on tests.results to anon, authenticated;
grant usage, select on sequence tests.results_n_seq to anon, authenticated;

create function tests.check(cond boolean, name text, detail text default null) returns void
language sql as $$ insert into tests.results (ok, name, detail) values (coalesce(cond, false), name, detail); $$;

-- Run a statement and expect it to fail with this SQLSTATE (and, optionally, this exact message).
create function tests.throws(stmt text, state text, msg text, name text) returns void
language plpgsql as $$
begin
  execute stmt;
  perform tests.check(false, name, 'no error');
exception when others then
  perform tests.check(sqlstate = state and (msg is null or sqlerrm = msg), name, sqlstate || ' ' || sqlerrm);
end $$;

create function tests.as_user(uid uuid, aal text default 'aal1') returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated', 'aal', aal)::text, true);
  select set_config('role', 'authenticated', true);
$$;
create function tests.as_anon() returns void
language sql as $$
  select set_config('request.jwt.claims', '{"role":"anon"}', true);
  select set_config('role', 'anon', true);
$$;
grant execute on all functions in schema tests to anon, authenticated;

-- ---------------------------------------------------------------- fixtures (as postgres)
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000a1', 'free@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a2', 'premium@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a3', 'banned@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a4', 'editor@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a5', 'admin@test.local', 'authenticated', 'authenticated');

update public.profiles set banned_at = now(), ban_reason = 'test' where id = '00000000-0000-4000-8000-0000000000a3';
insert into public.staff (user_id, role) values
  ('00000000-0000-4000-8000-0000000000a4', 'editor'), ('00000000-0000-4000-8000-0000000000a5', 'admin');
insert into public.entitlements (user_id, source, expires_at, reason)
  values ('00000000-0000-4000-8000-0000000000a2', 'manual', now() + interval '30 days', 'test grant');

-- Known rules for the test, whatever the admin has set.
update public.access_rules set rules = '{"jamb": 3, "waec": 3, "neco": 0, "pq": 2, "which": "oldest"}' where tier = 'free';
update public.access_rules set rules = '{"jamb": "all", "waec": "all", "neco": "all", "pq": "all", "which": "oldest"}' where tier = 'premium';

-- JAMB Mathematics 2000–2005 published, 2006 draft; one question per year (+ one draft question in 2000).
insert into public.exam_years (exam_id, subject_id, year, status)
select e.id, s.id, y, case when y = 2006 then 'draft' else 'published' end::public.year_status
from public.exam_bodies e, public.subjects s, generate_series(2000, 2006) y
where e.code = 'JAMB' and s.code = 'mth'
on conflict (exam_id, subject_id, year) do update set status = excluded.status;
insert into public.exam_years (exam_id, subject_id, year, status)
select e.id, s.id, 2000, 'published' from public.exam_bodies e, public.subjects s where e.code = 'NECO' and s.code = 'mth'
on conflict (exam_id, subject_id, year) do update set status = 'published';

insert into public.questions (exam_id, subject_id, year, number, body, options, answer, status, image_path)
select e.id, s.id, y, 1, 'TEST question ' || y, '{"A":"1","B":"2","C":"3","D":"4"}', 'B', 'published', 'test/q-' || y || '.webp'
from public.exam_bodies e, public.subjects s, generate_series(2000, 2006) y
where e.code = 'JAMB' and s.code = 'mth';
insert into public.questions (exam_id, subject_id, year, number, body, options, answer, status)
select e.id, s.id, 2000, 2, 'TEST draft question', '{"A":"1","B":"2","C":"3","D":"4"}', 'A', 'draft'
from public.exam_bodies e, public.subjects s where e.code = 'JAMB' and s.code = 'mth';
insert into public.questions (exam_id, subject_id, year, number, body, options, answer, status)
select e.id, s.id, 2000, 1, 'TEST neco question', '{"A":"1","B":"2","C":"3","D":"4"}', 'A', 'published'
from public.exam_bodies e, public.subjects s where e.code = 'NECO' and s.code = 'mth';

create table tests.ids as
select (select id from public.exam_bodies where code = 'JAMB') as jamb,
       (select id from public.exam_bodies where code = 'NECO') as neco,
       (select id from public.subjects where code = 'mth') as mth;
grant select on tests.ids to authenticated, anon;
delete from public.audit_log where table_name in ('questions', 'exam_years', 'staff', 'entitlements', 'access_rules', 'profiles');

-- ---------------------------------------------------------------- anonymous visitor
select tests.as_anon();
select tests.throws('select count(*) from public.questions', '42501', null, 'anon cannot touch questions');
select tests.throws('select * from public.fetch_questions(1::smallint, 1::smallint, 2000::smallint)', '42501', null, 'anon cannot call fetch_questions');
select tests.check((select count(*) from public.exam_bodies) >= 3, 'anon can read exam list (onboarding)');
select tests.check((select count(*) from public.plans) >= 1, 'anon can read plans');
reset role;

-- ---------------------------------------------------------------- Free student
select tests.as_user('00000000-0000-4000-8000-0000000000a1');
select tests.check((select count(*) from public.questions) = 0, 'free: direct select on questions returns nothing');
select tests.check((select count(*) from public.passages) = 0, 'free: direct select on passages returns nothing');
select tests.check((select count(*) from public.fetch_questions((select jamb from tests.ids), (select mth from tests.ids), 2000::smallint)) = 1,
  'free: JAMB 2000 (oldest 3) opens, only published questions');
select tests.check((select count(*) from public.fetch_questions((select jamb from tests.ids), (select mth from tests.ids), 2002::smallint)) = 1,
  'free: JAMB 2002 opens');
select tests.throws(format('select * from public.fetch_questions(%s::smallint, %s::smallint, 2003::smallint)', (select jamb from tests.ids), (select mth from tests.ids)),
  '42501', 'locked', 'free: JAMB 2003 is locked on the server');
select tests.throws(format('select * from public.fetch_questions(%s::smallint, %s::smallint, 2005::smallint)', (select jamb from tests.ids), (select mth from tests.ids)),
  '42501', 'locked', 'free: JAMB 2005 is locked on the server');
select tests.check((select count(*) from public.fetch_questions((select jamb from tests.ids), (select mth from tests.ids), 2001::smallint, 'pq')) = 1,
  'free: study mode 2001 (oldest 2) opens');
select tests.throws(format('select * from public.fetch_questions(%s::smallint, %s::smallint, 2002::smallint, ''pq'')', (select jamb from tests.ids), (select mth from tests.ids)),
  '42501', 'locked', 'free: study mode 2002 is locked (pq rule is 2 years)');
select tests.throws(format('select * from public.fetch_questions(%s::smallint, %s::smallint, 2000::smallint)', (select neco from tests.ids), (select mth from tests.ids)),
  '42501', 'locked', 'free: exam set to 0 (NECO) is fully locked');
select tests.throws(format('select * from public.fetch_questions(%s::smallint, %s::smallint, 2006::smallint)', (select jamb from tests.ids), (select mth from tests.ids)),
  'P0002', 'not_found', 'free: draft year is not found');
select tests.throws(format('select * from public.fetch_questions(%s::smallint, %s::smallint, 2000::smallint, ''cbt'', 500)', (select jamb from tests.ids), (select mth from tests.ids)),
  '22023', 'bad_page', 'free: page size is capped');
select tests.check((select bool_and(cbt_open) from public.my_open_years((select jamb from tests.ids)) where year between 2000 and 2002)
  and not (select bool_or(cbt_open) from public.my_open_years((select jamb from tests.ids)) where year between 2003 and 2005),
  'free: my_open_years marks 2000–2002 open and 2003–2005 locked');
select tests.check(public.can_view_question_image('test/q-2000.webp'), 'free: image of an open question can be signed');
select tests.check(not public.can_view_question_image('test/q-2004.webp'), 'free: image of a locked question cannot be signed');
select tests.check(public.my_plan() ->> 'tier' = 'free', 'free: my_plan says free');

select tests.throws(format($q$insert into public.questions (exam_id, subject_id, year, body, options, answer)
  values (%s, %s, 2000, 'hack', '{"A":"1","B":"2","C":"3","D":"4"}', 'A')$q$, (select jamb from tests.ids), (select mth from tests.ids)),
  '42501', null, 'free: cannot insert a question');
select tests.check((with u as (update public.access_rules set rules = '{"jamb":"all"}' where tier = 'free' returning 1) select count(*) from u) = 0,
  'free: cannot change Free vs Premium rules');
select tests.throws($q$insert into public.entitlements (user_id, source, expires_at, reason, granted_by)
  values ('00000000-0000-4000-8000-0000000000a1', 'manual', now() + interval '1 year', 'free premium', '00000000-0000-4000-8000-0000000000a1')$q$,
  '42501', null, 'free: cannot give themselves Premium');
select tests.check((select count(*) from public.entitlements) = 0, 'free: cannot see other students'' entitlements');
select tests.check((select count(*) from public.profiles) = 1, 'free: sees only their own profile');
select tests.throws($q$update public.profiles set banned_at = null where id = '00000000-0000-4000-8000-0000000000a1'$q$,
  '42501', null, 'free: cannot touch ban fields');
select tests.check((with u as (update public.profiles set full_name = 'Tolu' where id = '00000000-0000-4000-8000-0000000000a1' returning 1) select count(*) from u) = 1,
  'free: can edit own name');
select tests.check((with u as (update public.profiles set full_name = 'Hacked' where id = '00000000-0000-4000-8000-0000000000a2' returning 1) select count(*) from u) = 0,
  'free: cannot edit another student');
select tests.check((select count(*) from public.audit_log) = 0, 'free: cannot read the audit log');
select tests.check((select count(*) from public.staff) = 0, 'free: cannot list staff');
select tests.throws('select * from public.admin_list_users()', '42501', 'not_allowed', 'free: cannot list users');
select tests.throws($q$select public.import_questions('x.csv', '[{"exam":"JAMB"}]'::jsonb)$q$, '42501', 'not_allowed', 'free: cannot import');
select tests.throws('select public.admin_dashboard()', '42501', 'not_allowed', 'free: cannot open the dashboard');
reset role;

-- ---------------------------------------------------------------- Premium student
select tests.as_user('00000000-0000-4000-8000-0000000000a2');
select tests.check((select count(*) from public.fetch_questions((select jamb from tests.ids), (select mth from tests.ids), 2005::smallint)) = 1,
  'premium: JAMB 2005 opens');
select tests.check((select count(*) from public.fetch_questions((select neco from tests.ids), (select mth from tests.ids), 2000::smallint)) = 1,
  'premium: NECO opens');
select tests.check((select count(*) from public.questions) = 0, 'premium: still no direct select on questions');
select tests.check((select count(*) from public.entitlements) = 1, 'premium: sees own entitlement');
select tests.check(public.my_plan() ->> 'tier' = 'premium', 'premium: my_plan says premium');
reset role;

-- Expired / revoked Premium falls back to Free.
update public.entitlements set revoked_at = now() where user_id = '00000000-0000-4000-8000-0000000000a2';
select tests.as_user('00000000-0000-4000-8000-0000000000a2');
select tests.throws(format('select * from public.fetch_questions(%s::smallint, %s::smallint, 2005::smallint)', (select jamb from tests.ids), (select mth from tests.ids)),
  '42501', 'locked', 'revoked premium: JAMB 2005 locked again');
reset role;

-- ---------------------------------------------------------------- banned student
select tests.as_user('00000000-0000-4000-8000-0000000000a3');
select tests.throws(format('select * from public.fetch_questions(%s::smallint, %s::smallint, 2000::smallint)', (select jamb from tests.ids), (select mth from tests.ids)),
  '42501', 'banned', 'banned: cannot fetch questions');
select tests.check(not public.can_view_question_image('test/q-2000.webp'), 'banned: no image links');
reset role;

-- ---------------------------------------------------------------- editor without / with 2-step
select tests.as_user('00000000-0000-4000-8000-0000000000a4', 'aal1');
select tests.check((select count(*) from public.questions where body like 'TEST%') = 9, 'editor (aal1): can read all questions incl. drafts');
select tests.throws(format($q$insert into public.questions (exam_id, subject_id, year, body, options, answer)
  values (%s, %s, 2000, 'no 2fa', '{"A":"1","B":"2","C":"3","D":"4"}', 'A')$q$, (select jamb from tests.ids), (select mth from tests.ids)),
  '42501', null, 'editor (aal1): cannot write without 2-step login');
reset role;

select tests.as_user('00000000-0000-4000-8000-0000000000a4', 'aal2');
select tests.check((with i as (insert into public.questions (exam_id, subject_id, year, body, options, answer)
  values ((select jamb from tests.ids), (select mth from tests.ids), 2000, 'TEST editor question', '{"A":"1","B":"2","C":"3","D":"4"}', 'C') returning 1) select count(*) from i) = 1,
  'editor (aal2): can add a question');
select tests.throws($q$insert into public.questions (exam_id, subject_id, year, body, options, answer)
  select exam_id, subject_id, year, 'bad answer', '{"A":"1","B":"2","C":"3","D":"4"}', 'E' from public.questions limit 1$q$,
  '23514', null, 'editor: answer must be one of the options (constraint)');
select tests.check((with u as (update public.access_rules set rules = '{"jamb":"all"}' where tier = 'free' returning 1) select count(*) from u) = 0,
  'editor: cannot change Free vs Premium rules (admins only)');
select tests.throws($q$insert into public.entitlements (user_id, source, expires_at, reason, granted_by)
  values ('00000000-0000-4000-8000-0000000000a1', 'manual', now() + interval '30 days', 'friend', '00000000-0000-4000-8000-0000000000a4')$q$,
  '42501', null, 'editor: cannot give Premium');
select tests.throws($q$insert into public.staff (user_id, role) values ('00000000-0000-4000-8000-0000000000a1', 'admin')$q$,
  '42501', null, 'editor: cannot make staff');
reset role;
select tests.check(exists (select 1 from public.audit_log where table_name = 'questions' and action = 'insert'
  and actor = '00000000-0000-4000-8000-0000000000a4'), 'audit: editor''s insert is logged with their id');

-- ---------------------------------------------------------------- admin with 2-step
select tests.as_user('00000000-0000-4000-8000-0000000000a5', 'aal2');
select tests.check((with i as (insert into public.entitlements (user_id, source, expires_at, reason, granted_by)
  values ('00000000-0000-4000-8000-0000000000a1', 'manual', now() + interval '7 days', 'support case', '00000000-0000-4000-8000-0000000000a5') returning 1) select count(*) from i) = 1,
  'admin (aal2): can give Premium with a reason');
select tests.throws($q$insert into public.entitlements (user_id, source, expires_at, reason, granted_by)
  values ('00000000-0000-4000-8000-0000000000a1', 'paystack', now() + interval '7 days', 'fake payment', '00000000-0000-4000-8000-0000000000a5')$q$,
  '42501', null, 'admin: cannot fake a Paystack entitlement (server only)');
select tests.check((select count(*) from public.admin_list_users('test.local')) = 5, 'admin: can list users');
select public.admin_set_ban('00000000-0000-4000-8000-0000000000a1', true, 'test ban');
select tests.throws($q$select public.admin_set_ban('00000000-0000-4000-8000-0000000000a4', true, 'ban staff')$q$, '22023', 'cannot_ban_staff', 'admin: cannot ban staff');
select tests.throws($q$insert into public.staff (user_id, role) values ('00000000-0000-4000-8000-0000000000a1', 'admin')$q$,
  '42501', null, 'admin: cannot make staff (super admin only)');
reset role;
select tests.check((select banned_at is not null from public.profiles where id = '00000000-0000-4000-8000-0000000000a1'), 'admin_set_ban: student banned');
select tests.check(exists (select 1 from public.audit_log where table_name = 'profiles' and actor = '00000000-0000-4000-8000-0000000000a5'), 'audit: ban is logged');

-- ---------------------------------------------------------------- CSV import RPC (editor, 2-step)
select tests.as_user('00000000-0000-4000-8000-0000000000a4', 'aal2');
select tests.check((public.import_questions('t.csv', '[{"exam":"JAMB","year":"2007","subject":"mth","question":"TEST imp 1 $x$","option_a":"1","option_b":"2","option_c":"3","option_d":"4","answer":"A","topic":"TEST topic"}]'::jsonb, true) ->> 'inserted')::int = 1,
  'import: dry run reports 1 row');
select tests.check((select count(*) from public.questions where body = 'TEST imp 1 $x$') = 0, 'import: dry run writes nothing');
select tests.check((public.import_questions('t.csv', '[{"exam":"JAMB","year":"2007","subject":"Mathematics","question":"TEST imp 1 $x$","option_a":"1","option_b":"2","option_c":"3","option_d":"4","answer":"A","topic":"TEST topic"},{"exam":"jamb","year":"2007","subject":"mth","question":"TEST imp 2","option_a":"1","option_b":"2","option_c":"3","option_d":"4","answer":"D"}]'::jsonb) ->> 'inserted')::int = 2,
  'import: commits 2 rows (subject by name, lower-case exam)');
select tests.check((select count(*) from public.questions where body like 'TEST imp%' and status = 'draft') = 2, 'import: rows arrive as drafts');
select tests.throws($q$select public.import_questions('t.csv', '[{"exam":"GCE","year":"2007","subject":"mth","question":"x","option_a":"1","option_b":"2","option_c":"3","option_d":"4","answer":"A"}]'::jsonb)$q$,
  '22023', 'unknown_exam_or_subject', 'import: unknown exam aborts the whole file');
select tests.check(public.undo_import((select id from public.import_batches where file_name = 't.csv' and undone_at is null order by created_at desc limit 1)) = 2,
  'import: undo removes the 2 rows');
select tests.check((select count(*) from public.questions where body like 'TEST imp%' and deleted_at is null) = 0, 'import: undone rows are hidden');
reset role;
select tests.check((select count(*) from public.audit_log where action in ('import', 'undo_import') and actor = '00000000-0000-4000-8000-0000000000a4') = 2, 'audit: one row per import and per undo');

-- ---------------------------------------------------------------- results
reset role;
select n, ok, name, detail from tests.results order by n;
rollback;
