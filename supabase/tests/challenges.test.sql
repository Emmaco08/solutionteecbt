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

insert into auth.users (id, email, aud, role, created_at) values
  ('00000000-0000-4000-8000-0000000000c1', 'c1@c.test', 'authenticated', 'authenticated', now()),
  ('00000000-0000-4000-8000-0000000000c2', 'c2@c.test', 'authenticated', 'authenticated', now()),
  ('00000000-0000-4000-8000-0000000000c3', 'c3@c.test', 'authenticated', 'authenticated', now()),
  ('00000000-0000-4000-8000-0000000000c4', 'c4@c.test', 'authenticated', 'authenticated', now()),
  ('00000000-0000-4000-8000-0000000000c9', 'c9@c.test', 'authenticated', 'authenticated', now());
insert into public.staff (user_id, role) values ('00000000-0000-4000-8000-0000000000c9', 'editor');
update public.profiles set full_name = 'Ada Obi', state = 'Oyo' where id = '00000000-0000-4000-8000-0000000000c1';
update public.profiles set full_name = 'Bola Ade', state = 'Lagos' where id = '00000000-0000-4000-8000-0000000000c2';
update public.profiles set full_name = 'Chika Eze', state = 'Enugu' where id = '00000000-0000-4000-8000-0000000000c3';
update public.profiles set full_name = 'Dayo Bello', state = 'Kwara' where id = '00000000-0000-4000-8000-0000000000c4';

create temp table ch as
with ins as (insert into public.challenges (title, kind, starts_at, ends_at, seconds_per_question, prizes, published)
  values ('TST Weekly', 'cash', now() - interval '10 minutes', now() + interval '1 hour', 30, '{1000,500}', true) returning id)
select id from ins;
insert into public.challenges (title, kind, starts_at, ends_at, prizes, published)
values ('TST Later', 'event', now() + interval '1 day', now() + interval '2 days', '{}', true);
insert into public.challenge_questions (challenge_id, position, body, options, answer)
select (select id from ch), v.p, v.b, '{"A": "1", "B": "2", "C": "3", "D": "4"}', v.a
from (values (1, 'TSTQ one', 'A'), (2, 'TSTQ two', 'B'), (3, 'TSTQ three', 'C')) v(p, b, a);
grant select on ch to authenticated;

-- ---------------------------------------------------------------- list and start
select tests.as_user('00000000-0000-4000-8000-0000000000c1');
select tests.check((select jsonb_array_length(public.challenges_list() -> 'items')) >= 2, 'students see live and coming-up challenges');
select tests.check((select count(*) from public.challenge_questions) = 0, 'students cannot read challenge questions or answers');
select tests.throws($q$ select public.challenge_start((select id from ch where false)) $q$, 'P0002', null, 'an unknown challenge is refused');
create temp table s1 as select public.challenge_start((select id from ch), 'phone-1') as j;
select tests.check((select j ->> 'status' = 'playing' and j -> 'question' ->> 'body' like 'TSTQ%' and not (j -> 'question' ? 'answer')
  and jsonb_array_length(j -> 'question' -> 'options') = 4 from s1), 'one question at a time, without the answer');

-- answer every question right (look the answer up as the server would)
do $$
declare j jsonb := (select j from s1); a text; n int := 0;
begin
  while j ->> 'status' = 'playing' and n < 5 loop
    reset role;
    select q.answer into a from public.challenge_questions q where q.id = (j -> 'question' ->> 'question_id')::uuid;
    perform set_config('role', 'authenticated', true);
    j := public.challenge_answer((j -> 'question' ->> 'entry_id')::uuid, (j -> 'question' ->> 'question_id')::uuid, a);
    n := n + 1;
  end loop;
  perform tests.check(j ->> 'status' = 'finished' and n = 3, 'answering moves on one question at a time and finishes', j::text);
end $$;
select tests.check((select (public.challenge_detail((select id from ch)) -> 'mine' ->> 'score')::int) = 3, 'marked on the server: 3 of 3');
select tests.check((select public.challenge_start((select id from ch)) ->> 'status') = 'finished', 'one attempt: starting again shows the result');
select tests.throws($q$ insert into public.challenge_entries (challenge_id, user_id, question_order) values ((select id from ch), '00000000-0000-4000-8000-0000000000c1', '{}') $q$,
  '42501', null, 'students cannot write entries directly');

-- c2: two right, one late
select tests.as_user('00000000-0000-4000-8000-0000000000c2');
do $$
declare j jsonb := public.challenge_start((select id from ch), 'phone-2'); a text; n int := 0;
begin
  while j ->> 'status' = 'playing' and n < 5 loop
    reset role;
    select q.answer into a from public.challenge_questions q where q.id = (j -> 'question' ->> 'question_id')::uuid;
    if n = 2 then update public.challenge_entries set served_at = now() - interval '60 seconds' where id = (j -> 'question' ->> 'entry_id')::uuid; end if;
    perform set_config('role', 'authenticated', true);
    j := public.challenge_answer((j -> 'question' ->> 'entry_id')::uuid, (j -> 'question' ->> 'question_id')::uuid, a);
    n := n + 1;
  end loop;
end $$;
select tests.check((select (public.challenge_detail((select id from ch)) -> 'mine' ->> 'score')::int) = 2, 'an answer after the timer runs out does not count');

-- c3: leaves the app (0 exits allowed) -> disqualified
select tests.as_user('00000000-0000-4000-8000-0000000000c3');
create temp table s3 as select public.challenge_start((select id from ch), 'phone-1') as j;
select tests.check((select public.challenge_exit((j -> 'question' ->> 'entry_id')::uuid, 'Switched app') ->> 'status' from s3) = 'disqualified',
  'leaving the challenge screen disqualifies');
select tests.check((select public.challenge_detail((select id from ch)) -> 'mine' ->> 'status') = 'disqualified', 'and the entry stays disqualified');

-- c4: same score as c1 and same time, but started later
select tests.as_user('00000000-0000-4000-8000-0000000000c4');
do $$
declare j jsonb := public.challenge_start((select id from ch), 'phone-4'); a text; n int := 0;
begin
  while j ->> 'status' = 'playing' and n < 5 loop
    reset role;
    select q.answer into a from public.challenge_questions q where q.id = (j -> 'question' ->> 'question_id')::uuid;
    perform set_config('role', 'authenticated', true);
    j := public.challenge_answer((j -> 'question' ->> 'entry_id')::uuid, (j -> 'question' ->> 'question_id')::uuid, a);
    n := n + 1;
  end loop;
end $$;
reset role;
update public.challenge_entries set started_at = now() - interval '5 minutes', time_ms = 40000 where user_id = '00000000-0000-4000-8000-0000000000c1';
update public.challenge_entries set started_at = now() - interval '2 minutes', time_ms = 40000 where user_id = '00000000-0000-4000-8000-0000000000c4';
update public.challenge_entries set time_ms = 30000 where user_id = '00000000-0000-4000-8000-0000000000c2';
select tests.check((select 'Same phone as another entry' = any (flags) from public.challenge_entries where user_id = '00000000-0000-4000-8000-0000000000c3'),
  'fair play: two accounts on one phone are flagged');
select tests.check((select 'Answers under 2 seconds on average' = any (flags) from public.challenge_entries where user_id = '00000000-0000-4000-8000-0000000000c1'),
  'fair play: very fast answers are flagged');

select tests.as_user('00000000-0000-4000-8000-0000000000c2');
create temp table live as select public.challenge_result((select id from ch)) as j;
select tests.check((select array_agg(e ->> 'name' order by (e ->> 'rank')::int) from live, jsonb_array_elements(j -> 'top') e) = array['Ada O.', 'Dayo B.', 'Bola A.'],
  'ranking: best score, then time, then who started earlier; disqualified left out');
select tests.check((select (j ->> 'my_rank')::int from live) = 3, 'my live rank');

-- ---------------------------------------------------------------- close, winners, claims
reset role;
update public.challenges set ends_at = now() - interval '1 second', starts_at = now() - interval '2 hours' where id = (select id from ch);
select tests.check(private.challenges_tick() >= 1, 'the schedule closes ended challenges');
select tests.check((select array_agg(prize order by rank) from public.challenge_entries where challenge_id = (select id from ch) and rank <= 2) = array[1000, 500],
  'winners get the prizes for their places');
select tests.check((select count(*) from public.notifications where source = 'challenge' and audience = 'user' and title like 'You won%') = 2,
  'each winner gets a "You won" message');
select tests.check((select count(*) from public.notifications where source = 'challenge' and title like 'TST Weekly is live') = 0
  and (select announced_at is null from public.challenges where id = (select id from ch)), 'it was already running, so it closes without a late "is live" message');

select tests.as_user('00000000-0000-4000-8000-0000000000c2');
select tests.throws($q$ select public.prize_claim((select id from ch), true, 'GTBank', '0123456789', 'Bola Ade') $q$, '42501', null, 'only winners can claim');
select tests.as_user('00000000-0000-4000-8000-0000000000c4');
select tests.throws($q$ select public.prize_claim((select id from ch), false, 'GTBank', '0123456789', 'Dayo Bello') $q$, '22023', '%guardian%',
  'under 18 needs a parent or guardian');
select tests.throws($q$ select public.prize_claim((select id from ch), true, 'GTBank', '12345', 'Dayo Bello') $q$, '22023', '%10-digit%',
  'the account number must have 10 digits');
select tests.check((public.prize_claim((select id from ch), true, 'GTBank', '0123456789', 'Dayo Bello') ->> 'ok')::boolean, 'a winner sends the account to pay');
select tests.throws($q$ select public.prize_claim((select id from ch), true, 'GTBank', '0123456789', 'Dayo Bello') $q$, 'P0001', '%already%', 'only once');
select tests.check((select (public.my_winnings() ->> 'total')::int) = 500, 'My winnings shows the prize');
select tests.as_user('00000000-0000-4000-8000-0000000000c1');
select tests.check((select count(*) from public.prize_claims) = 0, 'other students cannot see bank details');
select tests.as_user('00000000-0000-4000-8000-0000000000c9');
select tests.check((select count(*) from public.prize_claims) = 0, 'an editor (not a money admin) cannot see bank details');
select tests.throws($q$ select public.admin_prize_claims() $q$, '42501', null, 'editors cannot list claims');

-- winners wall: everyone can read published posts
reset role;
insert into public.winners_wall (challenge_title, name, state, place, amount) values ('TST Weekly', 'Dayo B.', 'Kwara', '2nd place', 500);
set local role anon;
select tests.check((select (public.winners_wall_list() ->> 'total')::int) >= 500, 'the winners wall is public');

reset role;
set local role anon;
select tests.throws($q$ select public.challenges_list() $q$, '42501', null, 'not signed in: no challenges');

reset role;
select n, ok, name, detail from tests.results order by n;
rollback;
