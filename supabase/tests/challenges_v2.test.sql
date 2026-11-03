-- SolutionTee CBT · Challenges, fair play, prize claims, winners wall (milestone 4E2). Always rolled back.
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

-- Subjects for the test: the first two subjects; s1 takes both, s2 takes only the first, s3 takes neither.
create temp table subj as select id, code, row_number() over (order by id) as n from public.subjects order by id limit 2;
grant select on subj to authenticated;
insert into auth.users (id, email, aud, role, created_at) values
  ('00000000-0000-4000-8000-0000000000b1', 'b1@b.test', 'authenticated', 'authenticated', now()),
  ('00000000-0000-4000-8000-0000000000b2', 'b2@b.test', 'authenticated', 'authenticated', now()),
  ('00000000-0000-4000-8000-0000000000b3', 'b3@b.test', 'authenticated', 'authenticated', now());
update public.profiles set full_name = 'Bisi One', jamb_subjects = (select array_agg(code order by id) from subj) where id = '00000000-0000-4000-8000-0000000000b1';
update public.profiles set full_name = 'Bayo Two', jamb_subjects = array[(select code from subj where n = 1)] where id = '00000000-0000-4000-8000-0000000000b2';
update public.profiles set full_name = 'Bimpe Three', jamb_subjects = '{}' where id = '00000000-0000-4000-8000-0000000000b3';

create temp table chs as
with ins as (insert into public.challenges (title, kind, mode, subject_id, starts_at, ends_at, prizes, per_level, published) values
  ('TSTV2 Mixed', 'cash', 'mixed', null, now() - interval '5 minutes', now() + interval '1 hour', '{1000}', '{"easy": 2, "medium": 1, "hard": 0, "very_hard": 1}', true),
  ('TSTV2 Subject', 'event', 'subject', (select id from subj where n = 2), now() - interval '5 minutes', now() + interval '1 hour', '{}', '{"easy": 1, "medium": 1, "hard": 0, "very_hard": 0}', true)
  returning id, title) select * from ins;
grant select on chs to authenticated;
-- pools: 6 easy, 4 medium, 3 very hard per subject (more than a paper needs)
insert into public.challenge_questions (challenge_id, body, options, answer, subject_id, difficulty)
select c.id, 'TSTV2 ' || s.n || ' ' || l.lvl || ' ' || g, '{"A": "1", "B": "2", "C": "3", "D": "4"}', 'A', s.id, l.lvl
from chs c cross join subj s
cross join (values ('easy', 6), ('medium', 4), ('very_hard', 3)) l(lvl, k) cross join lateral generate_series(1, l.k) g;

select tests.as_user('00000000-0000-4000-8000-0000000000b1');
create temp table m1 as select public.challenge_start((select id from chs where title = 'TSTV2 Mixed')) as j;
reset role;
select tests.check((select cardinality(question_order) from public.challenge_entries where user_id = '00000000-0000-4000-8000-0000000000b1') = 8,
  'mixed: a paper of 2 easy + 1 medium + 1 very hard for each of the student''s 2 subjects');
select tests.check((select count(*) filter (where q.difficulty = 'easy') = 4 and count(*) filter (where q.difficulty = 'very_hard') = 2
  and count(distinct q.subject_id) = 2 from public.challenge_entries e cross join lateral unnest(e.question_order) x(id)
  join public.challenge_questions q on q.id = x.id where e.user_id = '00000000-0000-4000-8000-0000000000b1'),
  'the same difficulty mix for every student, from their own subjects');

select tests.as_user('00000000-0000-4000-8000-0000000000b2');
create temp table m2 as select public.challenge_start((select id from chs where title = 'TSTV2 Mixed')) as j;
reset role;
select tests.check((select count(distinct q.subject_id) = 1 and count(*) = 4 from public.challenge_entries e cross join lateral unnest(e.question_order) x(id)
  join public.challenge_questions q on q.id = x.id where e.user_id = '00000000-0000-4000-8000-0000000000b2'),
  'a student with one subject gets questions only from it');

select tests.as_user('00000000-0000-4000-8000-0000000000b3');
select tests.throws($q$ select public.challenge_start((select id from chs where title = 'TSTV2 Mixed')) $q$, 'P0001', '%JAMB subjects%',
  'a student with no subjects is asked to choose them first');

-- subject-only challenge: only students who take that subject see it and can play
select tests.as_user('00000000-0000-4000-8000-0000000000b2');
select tests.check(not exists (select 1 from jsonb_array_elements(public.challenges_list() -> 'items') e where e ->> 'title' = 'TSTV2 Subject'),
  'a subject challenge is hidden from students who do not take that subject');
select tests.throws($q$ select public.challenge_start((select id from chs where title = 'TSTV2 Subject')) $q$, 'P0001', '%for students who take%',
  'and they cannot start it');
select tests.as_user('00000000-0000-4000-8000-0000000000b1');
select tests.check(exists (select 1 from jsonb_array_elements(public.challenges_list() -> 'items') e where e ->> 'title' = 'TSTV2 Subject'),
  'students who take the subject see it');

-- appeals
select tests.as_user('00000000-0000-4000-8000-0000000000b2');
select public.challenge_exit((select j -> 'question' ->> 'entry_id' from m2)::uuid, 'Switched app');
select tests.throws($q$ select public.challenge_appeal((select id from chs where title = 'TSTV2 Mixed'), 'short') $q$, '22023', null, 'an appeal needs a reason');
select tests.throws($q$ select public.challenge_appeal((select id from chs where title = 'TSTV2 Mixed'), 'A phone call came in and the screen changed.', 'a/00000000-0000-4000-8000-0000000000b1/x.jpg') $q$,
  '22023', null, 'the screenshot must be the student''s own upload');
select tests.check((public.challenge_appeal((select id from chs where title = 'TSTV2 Mixed'), 'A phone call came in and the screen changed.',
  'a/00000000-0000-4000-8000-0000000000b2/shot.jpg') ->> 'ok')::boolean, 'a disqualified student sends an appeal with a screenshot');
select tests.throws($q$ select public.challenge_appeal((select id from chs where title = 'TSTV2 Mixed'), 'Again please, it was a call.') $q$, 'P0001', '%already%', 'only one appeal');
select tests.check((select public.challenge_detail((select id from chs where title = 'TSTV2 Mixed')) -> 'mine' -> 'appeal' ->> 'status') = 'pending', 'the student sees it is pending');
select tests.as_user('00000000-0000-4000-8000-0000000000b1');
select tests.throws($q$ select public.challenge_appeal((select id from chs where title = 'TSTV2 Mixed'), 'I was not disqualified at all.') $q$, 'P0001', '%disqualified%',
  'only disqualified entries can be appealed');
reset role;
insert into public.staff (user_id, role) values ('00000000-0000-4000-8000-0000000000b3', 'admin');
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-0000000000b3', 'role', 'authenticated', 'aal', 'aal2')::text, true);
select public.admin_challenge_appeal((select id from public.challenge_appeals where user_id = '00000000-0000-4000-8000-0000000000b2'), true, 'Thanks, we saw the call.');
reset role;
select tests.check((select status from public.challenge_entries where user_id = '00000000-0000-4000-8000-0000000000b2' and challenge_id = (select id from chs where title = 'TSTV2 Mixed')) = 'finished',
  'accepting the appeal reinstates the entry');
select tests.check((select count(*) from public.notifications where user_id = '00000000-0000-4000-8000-0000000000b2' and title = 'Appeal accepted') = 1, 'and the student is told');

-- notifications: 15 min before, at start, 15 min before the end; subject challenges only to that subject's students
update public.challenges set announced_at = null, starts_at = now() + interval '10 minutes', ends_at = now() + interval '2 hours'
where title = 'TSTV2 Subject';
select private.challenges_tick();
select tests.check((select count(*) from public.notifications where title = 'TSTV2 Subject starts in 15 minutes' and audience = 'user') >= 1
  and not exists (select 1 from public.notifications where title = 'TSTV2 Subject starts in 15 minutes' and user_id = '00000000-0000-4000-8000-0000000000b2'),
  'a subject challenge''s "starts in 15 minutes" goes only to students who take it');
update public.challenges set starts_at = now() - interval '30 minutes', ends_at = now() + interval '10 minutes' where title = 'TSTV2 Subject';
select private.challenges_tick();
select tests.check(exists (select 1 from public.notifications where title = 'TSTV2 Subject is live')
  and exists (select 1 from public.notifications where title = 'TSTV2 Subject ends in 15 minutes'), '"is live" and "ends in 15 minutes" are sent');
select private.challenges_tick();
select tests.check((select count(*) from public.notifications where title = 'TSTV2 Subject ends in 15 minutes' and user_id = '00000000-0000-4000-8000-0000000000b1') = 1,
  'each message only once');

reset role;
select n, ok, name, detail from tests.results order by n;
rollback;
