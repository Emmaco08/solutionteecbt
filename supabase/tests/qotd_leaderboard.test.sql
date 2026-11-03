-- SolutionTee CBT · Question of the day + leaderboard (milestone 4E1). Always rolled back.
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
  ('00000000-0000-4000-8000-0000000000f1', 'free1@q.test', 'authenticated', 'authenticated', now() - interval '30 days'),
  ('00000000-0000-4000-8000-0000000000f2', 'free2@q.test', 'authenticated', 'authenticated', now() - interval '30 days'),
  ('00000000-0000-4000-8000-0000000000f3', 'prem@q.test', 'authenticated', 'authenticated', now() - interval '30 days'),
  ('00000000-0000-4000-8000-0000000000f4', 'fast@q.test', 'authenticated', 'authenticated', now() - interval '30 days'),
  ('00000000-0000-4000-8000-0000000000f5', 'hidden@q.test', 'authenticated', 'authenticated', now() - interval '30 days'),
  ('00000000-0000-4000-8000-0000000000f9', 'staff@q.test', 'authenticated', 'authenticated', now() - interval '30 days');
insert into public.staff (user_id, role) values ('00000000-0000-4000-8000-0000000000f9', 'editor');
insert into public.entitlements (user_id, plan_id, source, reason, starts_at, expires_at)
select '00000000-0000-4000-8000-0000000000f3', id, 'manual', 'test grant', now() - interval '1 day', now() + interval '30 days' from public.plans where code = 'monthly';
update public.profiles set full_name = 'chiamaka obi', state = 'Lagos' where id = '00000000-0000-4000-8000-0000000000f1';
update public.profiles set full_name = 'Abdullahi Musa', state = 'Kano' where id = '00000000-0000-4000-8000-0000000000f2';
update public.profiles set full_name = 'Temi', state = 'Lagos', school = 'Test College' where id = '00000000-0000-4000-8000-0000000000f3';
update public.profiles set full_name = 'Fast Finger', state = 'Lagos' where id = '00000000-0000-4000-8000-0000000000f4';
update public.profiles set full_name = 'Hidden Person', state = 'Lagos', hide_on_leaderboard = true where id = '00000000-0000-4000-8000-0000000000f5';
update public.profiles set full_name = 'Staff Member', state = 'Lagos' where id = '00000000-0000-4000-8000-0000000000f9';
-- Everyone takes the first subject (the test questions' subject), so the daily pick is predictable (D-071).
update public.profiles set jamb_subjects = array[(select code from public.subjects order by id limit 1)] where id::text like '00000000-0000-4000-8000-0000000000f%';

-- The test runs on a pretend "today" far ahead, so the real question of the day is not touched (rolled back).
create or replace function private.lagos_today() returns date language sql stable set search_path = '' as $f$ select date '2090-06-15' $f$;
create or replace function private.qotd_day() returns date language sql stable security definer set search_path = '' as $f$ select date '2090-06-15' $f$;

-- Free can open every JAMB year in this test; WAEC is closed for Free.
update public.access_rules set rules = jsonb_set(jsonb_set(rules, '{jamb}', '"all"'), '{waec}', '0') where tier = 'free';

create temp table tq as
with ins as (
  insert into public.questions (exam_id, subject_id, year, number, body, options, answer, explanation, status)
  select e.id, (select s.id from public.subjects s order by s.id limit 1), 2001, v.n, v.body,
         '{"A": "1", "B": "2", "C": "3", "D": "5"}'::jsonb, 'B', 'Because 5 - 3 = 2.', 'published'::public.content_status
  from public.exam_bodies e, (values (491, 'TSTQ jamb one'), (492, 'TSTQ jamb two')) v(n, body)
  where e.code = 'JAMB'
  union all
  select e.id, (select s.id from public.subjects s order by s.id limit 1), 2001, 493, 'TSTQ waec locked',
         '{"A": "1", "B": "2", "C": "3", "D": "5"}'::jsonb, 'B', null, 'published'::public.content_status
  from public.exam_bodies e where e.code = 'WAEC'
  returning id, body)
select * from ins;
grant select on tq to authenticated;

-- ---------------------------------------------------------------- scheduling rules
select tests.throws($q$ insert into public.qotd (day, question_id) values (private.lagos_today(), (select id from tq where body = 'TSTQ waec locked')) $q$,
  'P0001', '%Free students can open%', 'a question from a year Free cannot open cannot be scheduled');
select tests.throws($q$ insert into public.qotd (day, question_id) values (private.lagos_today() - 1, (select id from tq where body = 'TSTQ jamb two')) $q$,
  'P0001', '%today or a later day%', 'a past day cannot be scheduled');
insert into public.qotd (day, question_id) values (private.lagos_today(), (select id from tq where body = 'TSTQ jamb one'));
select tests.check(exists (select 1 from public.qotd where day = private.lagos_today() and source = 'admin'), 'staff schedule today''s question');

-- ---------------------------------------------------------------- answering
select tests.as_user('00000000-0000-4000-8000-0000000000f1');
create temp table t1 as select public.qotd_today() as j;
select tests.check((select j -> 'question' ->> 'body' from t1) = 'TSTQ jamb one', 'the student gets today''s question');
select tests.check((select not (j -> 'question' ? 'answer') and not (j -> 'question' ? 'explanation') and j -> 'result' = 'null'::jsonb from t1),
  'before answering: no answer and no explanation are sent');
select tests.check((select count(*) from public.qotd) = 0, 'students cannot read the schedule (tomorrow''s questions)');
select tests.throws($q$ select public.qotd_answer('Z') $q$, '22023', null, 'an option that does not exist is refused');
create temp table t2 as select public.qotd_answer('A') as j;
select tests.check((select (j -> 'result' ->> 'correct')::boolean = false and j -> 'result' ->> 'answer' = 'B'
  and j -> 'result' ->> 'explanation' like 'Because%' from t2), 'a wrong answer: marked wrong by the server, with the answer and explanation');
select tests.check((select (public.qotd_answer('B') -> 'result' ->> 'choice')) = 'A', 'one attempt: answering again keeps the first answer');
select tests.throws($q$ insert into public.qotd_answers (user_id, day, choice, correct) values ('00000000-0000-4000-8000-0000000000f1', private.lagos_today() + 1, 'B', true) $q$,
  '42501', null, 'students cannot write answers directly');
select tests.check((select (public.qotd_today() ->> 'streak')::int) = 1, 'streak: 1 after answering today');

select tests.as_user('00000000-0000-4000-8000-0000000000f2');
select tests.check((select (public.qotd_answer('B') -> 'result' ->> 'pct_right')::int) = 50, '% right counts every student (1 of 2)');

-- streak over earlier days
reset role;
alter table public.qotd disable trigger qotd_check;
insert into public.qotd (day, question_id) values (private.lagos_today() - 1, (select id from tq where body = 'TSTQ jamb two')),
  (private.lagos_today() - 2, (select id from tq where body = 'TSTQ jamb two')), (private.lagos_today() - 4, (select id from tq where body = 'TSTQ jamb two'));
insert into public.qotd_answers (user_id, day, qotd_id, choice, correct)
select '00000000-0000-4000-8000-0000000000f1', d.day, d.id, v.c, v.ok from public.qotd d
join (values (1, 'B', true), (2, 'C', false), (4, 'B', true)) v(n, c, ok) on d.day = private.lagos_today() - v.n;
alter table public.qotd enable trigger qotd_check;
select tests.as_user('00000000-0000-4000-8000-0000000000f1');
select tests.check((select (public.qotd_today() ->> 'streak')::int) = 3, 'streak: days in a row answered (a missed day ends it)');

reset role;
select tests.throws($q$ update public.qotd set question_id = (select id from tq where body = 'TSTQ jamb two') where day = private.lagos_today() $q$,
  'P0001', '%already answered%', 'a day students have answered cannot be changed');

-- Free rules change after scheduling: a Free phone never receives a now-locked question, Premium still does
update public.access_rules set rules = jsonb_set(rules, '{jamb}', '0') where tier = 'free';
select tests.as_user('00000000-0000-4000-8000-0000000000f2');
select tests.check((select public.qotd_today() -> 'question') = 'null'::jsonb, 'locked for Free now: the Free student gets no question');
select tests.as_user('00000000-0000-4000-8000-0000000000f3');
select tests.check((select public.qotd_today() -> 'question' ->> 'body') = 'TSTQ jamb one', 'Premium still gets it');
reset role;
update public.access_rules set rules = jsonb_set(rules, '{jamb}', '"all"') where tier = 'free';

-- automatic pick for an unscheduled day: a published Free-year question without a passage
create temp table auto as select private.qotd_pick(private.lagos_today() + 30, (select id from public.subjects order by id limit 1)) as id;
select tests.check((select q.status = 'published' and q.passage_id is null and private.tier_year_open('free', q.exam_id, q.year, 'cbt')
  from auto join public.qotd d on d.id = auto.id join public.questions q on q.id = d.question_id), 'an unscheduled day and subject gets an automatic Free-year question');
select tests.check((select source from public.qotd where id = (select id from auto)) = 'auto', 'and it is saved, so everyone with that subject gets the same one');

-- each student gets a question from one of their own subjects (D-071)
create temp table s2 as select id, code from public.subjects where id = (select q.subject_id from public.questions q
  where q.status = 'published' and q.deleted_at is null and q.passage_id is null and q.subject_id <> (select id from public.subjects order by id limit 1)
    and private.tier_year_open('free', q.exam_id, q.year, 'cbt') limit 1);
grant select on s2 to authenticated;
update public.profiles set jamb_subjects = array[(select code from s2)] where id = '00000000-0000-4000-8000-0000000000f4';
select tests.as_user('00000000-0000-4000-8000-0000000000f4');
select tests.check((select public.qotd_today() -> 'question' ->> 'subject') = (select name from public.subjects where id = (select id from s2)),
  'a student with another subject gets a question in their own subject');
reset role;
select tests.check((select count(distinct subject_id) from public.qotd where day = private.lagos_today()) >= 2, 'one question per subject per day');

-- ---------------------------------------------------------------- leaderboard
reset role;
update public.app_settings set value = '{"on": false}' where key = 'leaderboard';
select tests.as_user('00000000-0000-4000-8000-0000000000f1');
select tests.check((public.leaderboard() ->> 'on')::boolean = false, 'leaderboard off: nothing shown');
reset role;
update public.app_settings set value = '{"on": true, "past_seasons": [], "min_mocks": 1, "names": "first-initial"}' where key = 'leaderboard';

-- full JAMB mocks this season: f1 300 in 2 h, f2 300 in 1.5 h (faster), f3 280, f4 395 in 10 min (held), f5 hidden 390, staff 399
insert into public.attempts (id, user_id, exam_id, mode, question_ids, started_at, submitted_at, time_used_s, server_score)
select gen_random_uuid(), v.u::uuid, (select id from public.exam_bodies where code = 'JAMB'), 'full', array[gen_random_uuid()],
       now() - interval '1 day' - (v.t || ' seconds')::interval, now() - interval '1 day', v.t,
       jsonb_build_object('questions', 180, 'answered', 180, 'correct', 100, 'total', v.s, 'max', 400)
from (values ('00000000-0000-4000-8000-0000000000f1', 300, 7200), ('00000000-0000-4000-8000-0000000000f1', 250, 7000),
             ('00000000-0000-4000-8000-0000000000f2', 300, 5400), ('00000000-0000-4000-8000-0000000000f3', 280, 6000),
             ('00000000-0000-4000-8000-0000000000f4', 395, 600), ('00000000-0000-4000-8000-0000000000f5', 390, 6000),
             ('00000000-0000-4000-8000-0000000000f9', 399, 6000)) v(u, s, t);
-- a quick test and a WAEC mock never count
insert into public.attempts (id, user_id, exam_id, mode, question_ids, started_at, submitted_at, time_used_s, server_score)
select gen_random_uuid(), '00000000-0000-4000-8000-0000000000f3', (select id from public.exam_bodies where code = 'JAMB'), 'quick', array[gen_random_uuid()],
       now() - interval '2 hours', now() - interval '1 hour', 3600, '{"questions": 180, "answered": 180, "correct": 180, "total": 400, "max": 400}';

select tests.as_user('00000000-0000-4000-8000-0000000000f1');
create temp table lb1 as select public.leaderboard() as j;
select tests.check((select array_agg(e ->> 'name' order by (e ->> 'rank')::int) from lb1, jsonb_array_elements(j -> 'top') e)
  = array['Abdullahi M.', 'Chiamaka O.', 'Temi'], 'ranked by best score, a tie goes to the faster student; names are first name + initial');
select tests.check((select (j -> 'me' ->> 'rank')::int = 2 and (j -> 'me' ->> 'mocks')::int = 2 and (j -> 'me' ->> 'ahead')::int = 0 from lb1),
  'my own rank, my number of mocks and the points to the next place');
select tests.check(not exists (select 1 from lb1, jsonb_array_elements(j -> 'top') e where e ->> 'name' in ('Hidden P.', 'Staff M.', 'Fast F.')),
  'hidden students, staff and held (too fast) mocks are left out');
select tests.check((select (j -> 'top' -> 0 ->> 'score')::int from lb1) = 300, 'quick tests do not count, only full mocks');

select tests.check((select jsonb_array_length(public.leaderboard(null, 'state') -> 'top')) = 2, 'My state: only students from Lagos');

reset role;
insert into public.leaderboard_reviews (attempt_id, decision)
select id, 'ok' from public.attempts where user_id = '00000000-0000-4000-8000-0000000000f4';
select tests.as_user('00000000-0000-4000-8000-0000000000f2');
select tests.check((select public.leaderboard() -> 'top' -> 0 ->> 'name') = 'Fast F.', 'after an admin approves a held mock it counts');
select tests.throws($q$ select public.admin_leaderboard_held() $q$, '42501', null, 'students cannot see the review list');

reset role;
update public.app_settings set value = '{"on": true, "past_seasons": [], "min_mocks": 2, "names": "first"}' where key = 'leaderboard';
select tests.as_user('00000000-0000-4000-8000-0000000000f2');
create temp table lb2 as select public.leaderboard() as j;
select tests.check((select (j -> 'me' ->> 'needs')::int = 1 and j -> 'me' -> 'rank' = 'null'::jsonb from lb2), 'with 2 mocks needed, a student with 1 is told how many more');
select tests.check((select j -> 'top' -> 0 ->> 'name' from lb2) = 'Chiamaka', 'name format "first name only"');

-- past season shows its best student
reset role;
update public.attempts set submitted_at = submitted_at - interval '1 year', started_at = started_at - interval '1 year'
where user_id = '00000000-0000-4000-8000-0000000000f3' and mode = 'full';
update public.app_settings set value = jsonb_build_object('on', true, 'past_seasons', jsonb_build_array(private.jamb_season(now()) - 1), 'min_mocks', 1, 'names', 'first-initial')
where key = 'leaderboard';
select tests.as_user('00000000-0000-4000-8000-0000000000f1');
select tests.check((select public.leaderboard(private.jamb_season(now()) - 1) -> 'best' ->> 'school') = 'Test College', 'a past season shows its best student');
select tests.check((select jsonb_array_length(public.leaderboard() -> 'seasons')) = 2, 'seasons: this one and the chosen past one');

-- ---------------------------------------------------------------- the admin's own question (D-068)
reset role;
alter table public.qotd disable trigger qotd_check;
update public.qotd set question_id = null, custom_subject = 'General knowledge', custom_body = 'TSTOWN Which planet is red?',
  custom_options = '{"A": "Venus", "B": "Mars", "C": "Earth", "D": "Jupiter"}', custom_answer = 'B', custom_explanation = 'Iron oxide.'
where day = private.lagos_today() and subject_id = (select id from public.subjects order by id limit 1);
alter table public.qotd enable trigger qotd_check;
select tests.throws($q$ insert into public.qotd (day, custom_body, custom_options, custom_answer) values (private.lagos_today() + 3, 'x', '{"A": "1", "B": "2"}', 'A') $q$,
  '23514', null, 'an own question needs options A to D');
select tests.throws($q$ insert into public.qotd (day, custom_body, custom_options, custom_answer) values (private.lagos_today() + 3, 'x', '{"A": "1", "B": "2", "C": "3", "D": "4"}', 'E') $q$,
  '23514', null, 'the answer must be one of the options');
insert into public.qotd (day, custom_body, custom_options, custom_answer) values (private.lagos_today() + 3, 'TSTOWN later', '{"A": "1", "B": "2", "C": "3", "D": "4"}', 'C');
select tests.check(exists (select 1 from public.qotd where day = private.lagos_today() + 3 and question_id is null), 'staff can write their own question for a day');
update public.access_rules set rules = jsonb_set(rules, '{jamb}', '0') where tier = 'free';
select tests.as_user('00000000-0000-4000-8000-0000000000f5');
create temp table own1 as select public.qotd_today() as j;
select tests.check((select j -> 'question' ->> 'body' = 'TSTOWN Which planet is red?' and (j -> 'question' ->> 'own')::boolean
  and j -> 'question' ->> 'subject' = (select name from public.subjects order by id limit 1) and not (j -> 'question' ? 'answer') from own1),
  'an own question reaches every student (even when Free years are closed), without the answer');
select tests.check((select (public.qotd_answer('B') -> 'result' ->> 'correct')::boolean), 'and is marked with the admin''s answer');
reset role;
update public.access_rules set rules = jsonb_set(rules, '{jamb}', '"all"') where tier = 'free';

-- ---------------------------------------------------------------- WAEC and NECO boards (one per subject, out of 100)
insert into public.attempts (id, user_id, exam_id, mode, question_ids, started_at, submitted_at, time_used_s, server_score)
select gen_random_uuid(), v.u::uuid, (select id from public.exam_bodies where code = 'WAEC'), 'subject', array[gen_random_uuid()],
       now() - interval '3 hours', now() - interval '2 hours', v.t,
       jsonb_build_object('questions', v.q, 'answered', v.q, 'correct', 30, 'total', v.s, 'max', 100,
         'subjects', jsonb_build_array(jsonb_build_object('subject_id', (select id from public.subjects order by id limit 1), 'score', v.s)))
from (values ('00000000-0000-4000-8000-0000000000f1', 70, 3000, 50), ('00000000-0000-4000-8000-0000000000f2', 85, 2400, 50),
             ('00000000-0000-4000-8000-0000000000f3', 99, 120, 50), ('00000000-0000-4000-8000-0000000000f4', 90, 2000, 10)) v(u, s, t, q);
select tests.as_user('00000000-0000-4000-8000-0000000000f1');
create temp table w1 as select public.leaderboard_for('WAEC', null, 'ng', (select id from public.subjects order by id limit 1)) as j;
select tests.check((select j ->> 'exam' = 'WAEC' and (j ->> 'max')::int = 100 and jsonb_array_length(j -> 'exams') = 3 from w1), 'WAEC board: out of 100, all three exams listed');
select tests.check((select array_agg(e ->> 'name' order by (e ->> 'rank')::int) from w1, jsonb_array_elements(j -> 'top') e) = array['Abdullahi M.', 'Chiamaka O.'],
  'WAEC subject board: too fast and too-short papers are left out, best score first');
select tests.check((select (j -> 'top' -> 0 ->> 'score')::int from w1) = 85, 'WAEC scores are the subject paper out of 100');
select tests.check((select jsonb_array_length(public.leaderboard_for('NECO') -> 'top')) = 0, 'NECO board is separate');
select tests.check((select public.leaderboard() ->> 'exam') = 'JAMB', 'the old call still gives the JAMB board');
reset role;
update public.app_settings set value = value || '{"exams": {"JAMB": true, "WAEC": false, "NECO": true}}' where key = 'leaderboard';
select tests.as_user('00000000-0000-4000-8000-0000000000f1');
select tests.check((select public.leaderboard_for('WAEC') ->> 'exam') = 'JAMB' and (select jsonb_array_length(public.leaderboard_for() -> 'exams')) = 2,
  'the admin can switch one exam''s board off');

select tests.as_user('00000000-0000-4000-8000-0000000000f1');
select tests.throws($q$ select public.admin_qotd_stats() $q$, '42501', null, 'students cannot see the question of the day analysis');
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-0000000000f9', 'role', 'authenticated', 'aal', 'aal2')::text, true);
select tests.check((select (public.admin_qotd_stats() -> 'today' ->> 'answers')::int) >= 3, 'staff see how many answered today');

reset role;
set local role anon;
select tests.throws($q$ select public.leaderboard() $q$, '42501', null, 'not signed in: no leaderboard');
select tests.throws($q$ select public.qotd_today() $q$, '42501', null, 'not signed in: no question of the day');

reset role;
select n, ok, name, detail from tests.results order by n;
rollback;
