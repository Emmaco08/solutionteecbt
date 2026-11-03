-- SolutionTee CBT · Challenges v3 (D-074): same questions, random past questions, live analysis, copy, review. Always rolled back.
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

-- Mathematics has Free-year past questions (JAMB 2001-2003); both students take it.
create temp table subj as select id, code from public.subjects where code = 'mth';
grant select on subj to authenticated;
insert into auth.users (id, email, aud, role, created_at) values
  ('00000000-0000-4000-8000-0000000000c1', 'c1@c.test', 'authenticated', 'authenticated', now()),
  ('00000000-0000-4000-8000-0000000000c2', 'c2@c.test', 'authenticated', 'authenticated', now()),
  ('00000000-0000-4000-8000-0000000000c9', 'c9@c.test', 'authenticated', 'authenticated', now());
update public.profiles set full_name = 'Chidi One', jamb_subjects = array['mth'] where id = '00000000-0000-4000-8000-0000000000c1';
update public.profiles set full_name = 'Chioma Two', jamb_subjects = array['mth'] where id = '00000000-0000-4000-8000-0000000000c2';
insert into public.staff (user_id, role) values ('00000000-0000-4000-8000-0000000000c9', 'editor');

create temp table chs as
with ins as (insert into public.challenges (title, kind, mode, subject_id, exam_code, starts_at, ends_at, prizes, per_level, published, same_questions) values
  ('TSTV3 Same', 'event', 'subject', (select id from subj), 'JAMB', now() - interval '5 minutes', now() + interval '1 hour', '{}', '{"easy": 2, "medium": 2, "hard": 0, "very_hard": 0}', true, true)
  returning id, title) select * from ins;
grant select on chs to authenticated;

-- random past questions: students cannot, editors can; Free years only; no repeats
select tests.as_user('00000000-0000-4000-8000-0000000000c1');
select tests.throws($q$ select public.admin_challenge_add_random((select id from chs), array[(select id from subj)]::smallint[], 10) $q$, '42501', null,
  'a student cannot add questions');
reset role;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-0000000000c9', 'role', 'authenticated', 'aal', 'aal2')::text, true);
create temp table r1 as select public.admin_challenge_add_random((select id from chs), array[(select id from subj)]::smallint[], 8) as j;
create temp table r2 as select public.admin_challenge_add_random((select id from chs), array[(select id from subj)]::smallint[], 500) as j;
select tests.check((select (j -> 0 ->> 'added')::int from r1) = 8, 'random past questions are added to the pool', (select j::text from r1));
select tests.check((select count(*) from public.challenge_questions q where q.challenge_id = (select id from chs))
  = (select count(distinct source_question_id) from public.challenge_questions q where q.challenge_id = (select id from chs)),
  'the same past question is never added twice', (select j::text from r2));
select tests.check(exists (select 1 from public.challenge_questions cq join public.questions q on q.id = cq.source_question_id
  where cq.challenge_id = (select id from chs) and not private.tier_year_open('free', q.exam_id, q.year, 'cbt')),
  'Premium years are used too (owner, D-077)');
select tests.check((select (j -> 0 ->> 'left')::int from r2) = 0, 'it says how many are left');
select tests.check(not exists (select 1 from public.challenge_questions q where q.challenge_id = (select id from chs)
  and q.difficulty not in ('easy', 'medium', 'hard', 'very_hard')), 'every question gets a level');
-- give the pool a known mix for the paper
update public.challenge_questions set difficulty = case when position % 2 = 0 then 'easy' else 'medium' end where challenge_id = (select id from chs);
select public.admin_challenge_set_level((select id from public.challenge_questions where challenge_id = (select id from chs) order by position limit 1), 'hard');
select tests.check((select difficulty from public.challenge_questions where challenge_id = (select id from chs) order by position limit 1) = 'hard',
  'an editor can change a question''s level');
update public.challenge_questions set difficulty = 'medium' where challenge_id = (select id from chs) and difficulty = 'hard';
reset role;

-- same questions for everyone
select tests.as_user('00000000-0000-4000-8000-0000000000c1');
create temp table p1 as select public.challenge_start((select id from chs)) as j;
select tests.as_user('00000000-0000-4000-8000-0000000000c2');
create temp table p2 as select public.challenge_start((select id from chs)) as j;
reset role;
select tests.check((select array_agg(x order by x) from public.challenge_entries e, unnest(e.question_order) x
                     where e.user_id = '00000000-0000-4000-8000-0000000000c1')
                 = (select array_agg(x order by x) from public.challenge_entries e, unnest(e.question_order) x
                     where e.user_id = '00000000-0000-4000-8000-0000000000c2'),
  '"same questions" gives both students the same questions');
select tests.check((select cardinality(question_order) from public.challenge_entries where user_id = '00000000-0000-4000-8000-0000000000c1') = 4,
  'with the level mix the admin set');

-- live leaderboard while playing
create temp table ans as select (j -> 'question' ->> 'entry_id')::uuid e, (j -> 'question' ->> 'question_id')::uuid q,
  (select answer from public.challenge_questions where id = (j -> 'question' ->> 'question_id')::uuid) a from p1;
grant select on ans to authenticated;
select tests.as_user('00000000-0000-4000-8000-0000000000c1');
select public.challenge_answer((select e from ans), (select q from ans), (select a from ans));
select tests.throws($q$ select public.admin_challenge_live((select id from chs)) $q$, '42501', null, 'students cannot see the admin live board');
select tests.throws($q$ select public.challenge_review((select id from chs)) $q$, 'P0001', '%when the challenge ends%',
  'answers cannot be reviewed while the challenge is running');
reset role;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-0000000000c9', 'role', 'authenticated', 'aal', 'aal2')::text, true);
create temp table lv as select public.admin_challenge_live((select id from chs)) as j;
reset role;
select tests.check((select (j -> 'summary' ->> 'playing')::int from lv) = 2 and (select j -> 'board' -> 0 ->> 'name' from lv) = 'Chidi One'
  and (select (j -> 'board' -> 0 ->> 'score')::int from lv) = 1, 'the live board shows who is playing and the live score', (select (j -> 'board')::text from lv));
select tests.check((select jsonb_array_length(j -> 'by_level') from lv) >= 1 and (select jsonb_array_length(j -> 'spread') from lv) = 10
  and (select (j ->> 'paper_size')::int from lv) = 4, 'analysis by level, score spread and paper size');

-- copy for next week
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-0000000000c9', 'role', 'authenticated', 'aal', 'aal2')::text, true);
create temp table cp as select public.admin_challenge_copy((select id from chs), now() + interval '7 days') as id;
reset role;
select tests.check((select not published and same_questions and ends_at - starts_at = interval '1 hour 5 minutes' from public.challenges where id = (select id from cp))
  and (select count(*) from public.challenge_questions where challenge_id = (select id from cp))
    = (select count(*) from public.challenge_questions where challenge_id = (select id from chs)),
  'a copy keeps the settings and questions and is hidden until published');

-- after the end: students review their own answers
update public.challenges set ends_at = now() - interval '1 second' where id = (select id from chs);
select tests.as_user('00000000-0000-4000-8000-0000000000c1');
create temp table rv as select public.challenge_review((select id from chs)) as j;
reset role;
select tests.check((select jsonb_array_length(j -> 'items') from rv) = 4 and (select (j -> 'items' -> 0 ->> 'correct')::boolean from rv)
  and (select j -> 'items' -> 0 ? 'answer' from rv), 'after the end, the student sees each question, the right answer and their choice');
select tests.as_user('00000000-0000-4000-8000-0000000000c9');
select tests.throws($q$ select public.challenge_review((select id from chs)) $q$, 'P0002', '%did not take%', 'only students who took it');

reset role;
do $r$ declare r text; begin select string_agg(n || ' ' || case when ok then 'ok' else 'FAIL' end || ' ' || name || coalesce(' | ' || detail, ''), E'\n' order by n) into r from tests.results; raise exception 'RESULTS %', E'\n' || r; end $r$;
