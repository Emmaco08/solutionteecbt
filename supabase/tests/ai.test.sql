-- SolutionTee CBT · AI tutor tests (milestone 4B, D-058). Always rolled back.
begin;
create schema tests;
grant usage on schema tests to anon, authenticated, service_role;
create table tests.results (n serial, ok boolean, name text, detail text);
grant all on tests.results to anon, authenticated, service_role;
grant usage, select on sequence tests.results_n_seq to anon, authenticated, service_role;
create function tests.check(cond boolean, name text, detail text default null) returns void
language sql as $$ insert into tests.results (ok, name, detail) values (coalesce(cond, false), name, detail); $$;
create function tests.throws(stmt text, state text, name text) returns void
language plpgsql as $$
begin
  execute stmt;
  perform tests.check(false, name, 'no error');
exception when others then
  perform tests.check(state is null or sqlstate = state, name, sqlstate || ' ' || sqlerrm);
end $$;
create function tests.as_user(uid uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  select set_config('role', 'authenticated', true);
$$;
create function tests.as_service() returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  select set_config('role', 'service_role', true);
$$;
grant execute on all functions in schema tests to anon, authenticated, service_role;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000d1', 'ai-free@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000d2', 'ai-prem@test.local', 'authenticated', 'authenticated');
insert into public.entitlements (user_id, plan_id, source, reason, starts_at, expires_at)
select '00000000-0000-4000-8000-0000000000d2', id, 'manual', 'test grant', now() - interval '1 day', now() + interval '30 days' from public.plans where code = 'monthly';
update public.access_rules set rules = rules || '{"ai": 3}' where tier = 'free';
update public.access_rules set rules = rules || '{"ai": 100}' where tier = 'premium';

-- ---------------------------------------------------------------- quota (service role, as the Edge Function)
select tests.as_service();
select tests.check(public.ai_take('00000000-0000-4000-8000-0000000000d1') = 2, 'Free: first prompt leaves 2');
select tests.check(public.ai_take('00000000-0000-4000-8000-0000000000d1') = 1, 'Free: second prompt leaves 1');
select tests.check(public.ai_take('00000000-0000-4000-8000-0000000000d1') = 0, 'Free: third prompt leaves 0');
select tests.check(public.ai_take('00000000-0000-4000-8000-0000000000d1') = -1, 'Free: fourth prompt is refused (quota)');
select tests.check((select used from public.ai_usage where user_id = '00000000-0000-4000-8000-0000000000d1') = 3, 'a refused prompt is not counted');
select public.ai_refund('00000000-0000-4000-8000-0000000000d1');
select tests.check((select used from public.ai_usage where user_id = '00000000-0000-4000-8000-0000000000d1') = 2, 'refund gives one prompt back');
select public.ai_refund('00000000-0000-4000-8000-0000000000d2');
select tests.check(not exists (select 1 from public.ai_usage where user_id = '00000000-0000-4000-8000-0000000000d2' and used < 0), 'refund never goes below zero');
select tests.check(public.ai_take('00000000-0000-4000-8000-0000000000d2') = 99, 'Premium: 100 a day');
select tests.check((select day from public.ai_usage where user_id = '00000000-0000-4000-8000-0000000000d2') = (now() at time zone 'Africa/Lagos')::date, 'the day is the Lagos date');
reset role;

-- burst limit: 6 questions in the last minute → slow down
insert into public.ai_chats (id, user_id, title) values ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000d2', 'Burst');
insert into public.ai_messages (chat_id, user_id, role, content)
select '00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000d2', 'user', 'q' || g from generate_series(1, 6) g;
insert into public.ai_messages (id, chat_id, user_id, role, content) values
  ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000d2', 'assistant', 'An answer');
select tests.as_service();
select tests.check(public.ai_take('00000000-0000-4000-8000-0000000000d2') = -2, 'burst limit: the 7th question within a minute must wait');
select tests.check((public.ai_config() -> 'models') is not null, 'service role can read the AI config');
reset role;

-- ---------------------------------------------------------------- students
select tests.as_user('00000000-0000-4000-8000-0000000000d1');
select tests.check((public.ai_quota() ->> 'left')::int = 1 and (public.ai_quota() ->> 'limit')::int = 3, 'Free: quota shows 1 of 3 left');
select tests.check((select count(*) from public.ai_providers) = 0, 'students cannot see providers');
select tests.check((select count(*) from public.ai_models) = 0, 'students cannot see models');
select tests.check((select count(*) from public.ai_prompts) = 0, 'students cannot see the system prompt');
select tests.check((select count(*) from public.ai_chats) = 0, 'students cannot see other students'' chats');
select tests.check((select count(*) from public.ai_messages) = 0, 'students cannot see other students'' messages');
select tests.throws($q$ select public.ai_config() $q$, '42501', 'students cannot read the AI config (keys)');
select tests.throws($q$ select public.ai_provider_key((select id from public.ai_providers limit 1)) $q$, '42501', 'students cannot read a provider key');
select tests.throws($q$ select public.ai_take('00000000-0000-4000-8000-0000000000d1') $q$, '42501', 'students cannot use up prompts directly');
select tests.throws($q$ select public.ai_refund('00000000-0000-4000-8000-0000000000d1') $q$, '42501', 'students cannot give themselves prompts back');
select tests.throws($q$ select public.admin_set_ai_key((select id from public.ai_providers limit 1), 'stolen-key-123') $q$, null, 'students cannot set a provider key');
select public.ai_flag('00000000-0000-4000-8000-0000000000f1', 'not mine');
reset role;
select tests.check((select flagged_at from public.ai_messages where id = '00000000-0000-4000-8000-0000000000f1') is null, 'students cannot report someone else''s answer');

select tests.as_user('00000000-0000-4000-8000-0000000000d2');
select tests.check((select count(*) from public.ai_chats) = 1, 'Premium: sees own chat');
select tests.check((select count(*) from public.ai_messages) = 7, 'Premium: sees own messages');
select public.ai_flag('00000000-0000-4000-8000-0000000000f1', 'The answer is wrong');
update public.ai_chats set title = 'Renamed' where id = '00000000-0000-4000-8000-0000000000e1';
select tests.throws($q$ update public.ai_chats set user_id = '00000000-0000-4000-8000-0000000000d1' where id = '00000000-0000-4000-8000-0000000000e1' $q$, '42501', 'a chat cannot be moved to another student');
reset role;
select tests.check((select flagged_at from public.ai_messages where id = '00000000-0000-4000-8000-0000000000f1') is not null, 'students can report their own answer');
select tests.check((select title from public.ai_chats where id = '00000000-0000-4000-8000-0000000000e1') = 'Renamed', 'students can rename their own chat');

reset role;
select count(*) filter (where ok) passed, count(*) total, string_agg(case when not ok then name || ' (' || coalesce(detail, '') || ')' end, '; ') failed from tests.results;
rollback;
