-- SolutionTee CBT · Notifications, push tokens, badges (milestone 4D). Always rolled back.
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
  perform tests.check(sqlstate = state and (msg is null or sqlerrm = msg), name, sqlstate || ' ' || sqlerrm);
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

insert into auth.users (id, email, aud, role, created_at) values
  ('00000000-0000-4000-8000-0000000000e1', 'free@n.test', 'authenticated', 'authenticated', now() - interval '30 days'),
  ('00000000-0000-4000-8000-0000000000e2', 'prem@n.test', 'authenticated', 'authenticated', now() - interval '30 days'),
  ('00000000-0000-4000-8000-0000000000e9', 'staff@n.test', 'authenticated', 'authenticated', now() - interval '30 days');
insert into public.staff (user_id, role) values ('00000000-0000-4000-8000-0000000000e9', 'editor');
insert into public.entitlements (user_id, plan_id, source, reason, starts_at, expires_at)
select '00000000-0000-4000-8000-0000000000e2', id, 'manual', 'test grant', now() - interval '1 day', now() + interval '30 days' from public.plans where code = 'monthly';

select tests.check((select count(*) from public.notifications where source = 'premium' and user_id = '00000000-0000-4000-8000-0000000000e2') = 1,
  'Premium given: a personal "You are now Premium" message is queued');

insert into public.notifications (topic, title, body, audience, user_id, status, sent_at, source) values
  ('announcements', 'TST all', 'to everyone', 'all', null, 'sent', now(), 'admin'),
  ('announcements', 'TST free', 'to free', 'free', null, 'sent', now(), 'admin'),
  ('announcements', 'TST premium', 'to premium', 'premium', null, 'sent', now(), 'admin'),
  ('announcements', 'TST staff', 'to test phones', 'staff', null, 'sent', now(), 'admin'),
  ('streak', 'TST mine', 'to e1 only', 'user', '00000000-0000-4000-8000-0000000000e1', 'sent', now(), 'admin'),
  ('announcements', 'TST later', 'not sent yet', 'all', null, 'scheduled', null, 'admin');
update public.notifications set scheduled_at = now() + interval '1 day' where title = 'TST later';

-- ---------------------------------------------------------------- inbox
select tests.as_user('00000000-0000-4000-8000-0000000000e1');
select tests.check((select array_agg(title order by title) from public.my_notifications() where title like 'TST%') = array['TST all', 'TST free', 'TST mine'],
  'Free student sees: everyone, Free, and their own message');
select tests.check((select count(*) from public.notifications) = 0, 'students cannot read the notifications table directly');
select tests.check(public.mark_notifications_read(null) >= 3, 'mark all read');
select tests.check((select count(*) from public.my_notifications() where not read and title like 'TST%') = 0, 'nothing unread after mark all read');
select tests.throws($q$ insert into public.notifications (topic, title, body) values ('announcements', 'hack', 'hack') $q$, '42501', null,
  'students cannot create notifications');
select tests.throws($q$ select public.push_take_due() $q$, '42501', null, 'students cannot take messages to send');

select tests.as_user('00000000-0000-4000-8000-0000000000e2');
select tests.check((select array_agg(title order by title) from public.my_notifications() where title like 'TST%') = array['TST all', 'TST premium'],
  'Premium student sees: everyone and Premium (not Free, not others'' messages)');
select tests.check((select count(*) from public.my_notifications() where not read and title like 'TST%') = 2, 'another student''s reads do not count for me');

-- ---------------------------------------------------------------- push tokens and switches
select tests.as_user('00000000-0000-4000-8000-0000000000e1');
select public.register_push_token('tok-shared-phone-0000000001', 'android', '0.3.0');
select tests.check((select count(*) from public.push_tokens) = 1, 'a student saves their phone''s token');
insert into public.notification_prefs (user_id, topic, enabled) values ('00000000-0000-4000-8000-0000000000e1', 'streak', false);
select tests.as_user('00000000-0000-4000-8000-0000000000e2');
select public.register_push_token('tok-shared-phone-0000000001', 'android', '0.3.0');
select tests.check((select count(*) from public.push_tokens) = 1, 'the same phone moves to the account now logged in');
select tests.check((select count(*) from public.notification_prefs) = 0, 'students cannot read other students'' switches');
select tests.as_user('00000000-0000-4000-8000-0000000000e1');
select tests.check((select count(*) from public.push_tokens) = 0, 'the old account no longer has that phone');

-- ---------------------------------------------------------------- automatic messages
reset role;
insert into public.news_posts (title, summary, status, publish_at, notify) values ('TST news', 'Read this', 'published', now(), true);
update public.news_posts set summary = 'Read this now' where title = 'TST news';
select tests.check((select count(*) from public.notifications where source = 'news' and title = 'TST news') = 1, 'a news post sent as notification is queued once');
insert into public.news_posts (title, status, publish_at, notify) values ('TST quiet news', 'published', now(), false);
select tests.check((select count(*) from public.notifications where title = 'TST quiet news') = 0, 'a news post without the switch sends nothing');

insert into public.exam_years (exam_id, subject_id, year, status)
select e.id, s.id, 2099, 'published' from public.exam_bodies e, public.subjects s where e.code = 'JAMB' order by s.sort limit 2;
select tests.check((select count(*) from public.notifications where source = 'year' and body like '%2099%') = 1,
  'two years published together become one message');
select tests.check((select body from public.notifications where source = 'year' and body like '%2099%') like '%, JAMB 2099%', 'the message lists both');

-- ---------------------------------------------------------------- sending
select tests.as_service();
create temp table taken as select public.push_take_due(200) as j;
select tests.check((select jsonb_array_length(j) from taken) >= 1, 'due messages are taken');
select tests.check(not exists (select 1 from taken, jsonb_array_elements(j) e where e ->> 'title' in ('TST later')), 'scheduled-for-later messages are not taken');
select tests.check(exists (select 1 from taken, jsonb_array_elements(j) e where e ->> 'title' = 'You are now Premium'
  and e -> 'tokens' = '["tok-shared-phone-0000000001"]'::jsonb), 'a personal message carries that student''s phone tokens');
select tests.check(jsonb_array_length(public.push_take_due(200)) = 0, 'a message is never taken twice');
select public.push_done((select (e ->> 'id')::uuid from taken, jsonb_array_elements(j) e where e ->> 'title' = 'TST news'), 0, 'Push is off');
select tests.check((select status = 'sent' and error = 'Push is off' from public.notifications where title = 'TST news'),
  'with push off a message is still marked sent (shows in the inbox) with the reason');

-- streak reminder: e1 practised yesterday and the day before, not today
reset role;
update public.app_settings set value = '{"streak_enabled": true, "streak_hour": 0}' where key = 'push';
insert into public.attempts (id, user_id, exam_id, mode, question_ids, started_at, submitted_at, time_used_s, server_score)
select gen_random_uuid(), '00000000-0000-4000-8000-0000000000e1', (select id from public.exam_bodies where code = 'JAMB'), 'quick', array[gen_random_uuid()],
       d - interval '10 minutes', d, 600, '{"correct": 15, "answered": 20, "total": 75, "max": 100, "questions": 20}'
from (values (now() - interval '1 day'), (now() - interval '2 days')) v(d);
select tests.as_user('00000000-0000-4000-8000-0000000000e1');
select public.register_push_token('tok-e1-phone-000000000000002', 'android', '0.3.0');
reset role;
select private.queue_streak_reminders();
select tests.check((select count(*) from public.notifications where source = 'streak' and user_id = '00000000-0000-4000-8000-0000000000e1') = 0,
  'no streak reminder when the student switched Streak reminders off');
update public.notification_prefs set enabled = true where user_id = '00000000-0000-4000-8000-0000000000e1' and topic = 'streak';
select private.queue_streak_reminders();
select private.queue_streak_reminders();
select tests.check((select count(*) from public.notifications where source = 'streak' and user_id = '00000000-0000-4000-8000-0000000000e1') = 1,
  'one streak reminder a day for a 2-day streak not kept today');
select tests.check((select title from public.notifications where source = 'streak' and user_id = '00000000-0000-4000-8000-0000000000e1') = 'Keep your 2-day streak',
  'the reminder names the streak');

-- ---------------------------------------------------------------- badges and dashboard
select tests.as_user('00000000-0000-4000-8000-0000000000e1');
select tests.check(jsonb_array_length(public.my_badges()) = 8, 'the 8 badges of the design');
select tests.check((select (b ->> 'earned')::boolean from jsonb_array_elements(public.my_badges()) b where b ->> 'key' = 'correct100') = false, '30 correct is not yet 100 correct');
select tests.check((select b ->> 'progress' from jsonb_array_elements(public.my_badges()) b where b ->> 'key' = 'correct100') = '30 of 100', 'badge progress');
select tests.check((public.my_dashboard() ->> 'streak')::int = 2, 'dashboard: current streak');
select tests.check((public.my_dashboard() ->> 'practised_today')::boolean = false, 'dashboard: not practised today');

reset role;
select n, ok, name, detail from tests.results order by n;
rollback;
