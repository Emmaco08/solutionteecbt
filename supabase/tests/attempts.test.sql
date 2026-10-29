-- SolutionTee CBT · attempts and server marking tests (Phase 3). Always rolled back.
begin;
create schema tests;
grant usage on schema tests to anon, authenticated;
create table tests.results (n serial, ok boolean, name text, detail text);
grant all on tests.results to anon, authenticated;
grant usage, select on sequence tests.results_n_seq to anon, authenticated;
create function tests.check(cond boolean, name text, detail text default null) returns void
language sql as $$ insert into tests.results (ok, name, detail) values (coalesce(cond, false), name, detail); $$;
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
grant execute on all functions in schema tests to anon, authenticated;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000b1', 'stu1@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000b2', 'stu2@test.local', 'authenticated', 'authenticated');
update public.access_rules set rules = '{"jamb": 1, "pq": 1, "which": "oldest"}' where tier = 'free';

-- JAMB: English 2001 (published, open), Maths 2001 (published, open), Maths 2002 (published, locked for Free: only 1 year)
insert into public.exam_years (exam_id, subject_id, year, status)
select e.id, s.id, y, 'published' from public.exam_bodies e, public.subjects s, (values (2001), (2002)) v(y)
where e.code = 'JAMB' and s.code in ('eng', 'mth') on conflict (exam_id, subject_id, year) do update set status = 'published';
create table tests.q (k text primary key, id uuid);
grant select on tests.q to authenticated;
with ins as (
  insert into public.questions (exam_id, subject_id, year, body, options, answer, status)
  select e.id, s.id, v.y, 'ATT ' || v.k, '{"A":"1","B":"2","C":"3","D":"4"}', v.ans, 'published'
  from public.exam_bodies e, public.subjects s,
       (values ('e1','eng',2001,'A'), ('e2','eng',2001,'B'), ('m1','mth',2001,'C'), ('m2','mth',2001,'D'), ('m3','mth',2001,'A'), ('lk','mth',2002,'A')) v(k, subj, y, ans)
  where e.code = 'JAMB' and s.code = v.subj
  returning id, body)
insert into tests.q select substr(body, 5), id from ins;

select tests.as_user('00000000-0000-4000-8000-0000000000b1');
-- English: 1 of 2 right (50). Maths: 2 of 3 right (67). Total 117 of 200.
select tests.check(
  (public.submit_attempt(jsonb_build_object(
    'id', '11111111-1111-4111-8111-111111111111', 'exam_id', (select id from public.exam_bodies where code = 'JAMB'),
    'mode', 'quick', 'started_at', now() - interval '10 minutes', 'submitted_at', now(), 'time_used_s', 600,
    'client_score', '{"total": 400}'::jsonb,
    'question_ids', (select jsonb_agg(id) from tests.q where k <> 'lk'),
    'answers', jsonb_build_array(
      jsonb_build_object('q', (select id from tests.q where k = 'e1'), 'c', 'A'),
      jsonb_build_object('q', (select id from tests.q where k = 'e2'), 'c', 'C'),
      jsonb_build_object('q', (select id from tests.q where k = 'm1'), 'c', 'c'),
      jsonb_build_object('q', (select id from tests.q where k = 'm2'), 'c', 'D', 'f', true)))) ->> 'total')::int = 117,
  'server marks from its own key (client claimed 400, server says 117)');
select tests.check((select (server_score ->> 'correct')::int = 3 and (server_score ->> 'answered')::int = 4 and (server_score ->> 'max')::int = 200
  from public.attempts where id = '11111111-1111-4111-8111-111111111111'), 'correct/answered/max stored');
select tests.check((public.submit_attempt('{"id":"11111111-1111-4111-8111-111111111111"}'::jsonb) ->> 'total')::int = 117,
  'sending the same attempt again returns the same score (idempotent)');
select tests.check((select count(*) from public.attempts) = 1, 'student sees own attempt');
select tests.check((select count(*) from public.attempt_answers where is_correct) = 3, 'student sees own marked answers');
select tests.throws(format($q$select public.submit_attempt(jsonb_build_object('id','22222222-2222-4222-8222-222222222222','exam_id',%s,'mode','quick',
  'started_at',now(),'submitted_at',now(),'time_used_s',5,'question_ids',jsonb_build_array('%s')))$q$,
  (select id from public.exam_bodies where code = 'JAMB'), (select id from tests.q where k = 'lk')),
  '42501', 'questions_not_allowed', 'cannot submit a question from a locked year');
select tests.throws($q$insert into public.attempts (id, user_id, exam_id, mode, question_ids, started_at, submitted_at, time_used_s, server_score)
  values ('33333333-3333-4333-8333-333333333333', '00000000-0000-4000-8000-0000000000b1', 1, 'quick', array[gen_random_uuid()], now(), now(), 1, '{"total":400}')$q$,
  '42501', null, 'cannot write a score directly');
select tests.throws($q$update public.attempt_answers set is_correct = true$q$, '42501', null, 'cannot mark own answers correct');
reset role;

select tests.as_user('00000000-0000-4000-8000-0000000000b2');
select tests.check((select count(*) from public.attempts) = 0, 'other student cannot see the attempt');
select tests.throws($q$select public.submit_attempt('{"id":"11111111-1111-4111-8111-111111111111"}'::jsonb)$q$,
  '42501', 'not_allowed', 'other student cannot reuse the attempt id');
reset role;

select n, ok, name, detail from tests.results order by n;
rollback;
