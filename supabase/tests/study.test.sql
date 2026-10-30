-- SolutionTee CBT · Study content access tests (Phase 4A). Always rolled back.
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
create function tests.as_user(uid uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  select set_config('role', 'authenticated', true);
$$;
create function tests.as_anon() returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  select set_config('role', 'anon', true);
$$;
grant execute on all functions in schema tests to anon, authenticated;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000c1', 'free@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c2', 'prem@test.local', 'authenticated', 'authenticated');
insert into public.entitlements (user_id, plan_id, source, reason, starts_at, expires_at)
select '00000000-0000-4000-8000-0000000000c2', id, 'manual', 'test grant', now() - interval '1 day', now() + interval '30 days' from public.plans where code = 'monthly';

-- Free plan: notes allowed (free items only), videos not allowed at all
update public.access_rules set rules = rules || '{"notes": true, "videos": false, "syllabus": 2}' where tier = 'free';

create table tests.i (k text primary key, id uuid);
grant select on tests.i to authenticated, anon;
with ins as (
  insert into public.study_items (kind, title, body, files, is_free, status)
  values
    ('note', 'TST free note', 'Free body', '{}', true, 'published'),
    ('note', 'TST premium note', 'Premium body', '{}', false, 'published'),
    ('note', 'TST draft note', 'Draft body', '{}', true, 'draft'),
    ('video_solution', 'TST free video', 'Working', '{"360": "v/tst/free-360.mp4"}', true, 'published'),
    ('video_solution', 'TST premium video', 'Working', '{"360": "v/tst/prem-360.mp4", "720": "v/tst/prem-720.mp4"}', false, 'published')
  returning id, title)
insert into tests.i select replace(substr(title, 5), ' ', '_'), id from ins;

-- ---------------------------------------------------------------- Free student
select tests.as_user('00000000-0000-4000-8000-0000000000c1');
select tests.check((select count(*) from public.study_items) = 0, 'students cannot read study_items directly');
select tests.check((select count(*) from public.study_catalog('note') where title like 'TST%') = 2, 'catalogue lists published notes only (no drafts)');
select tests.check((select not locked from public.study_catalog('note') where title = 'TST free note'), 'Free: free note open');
select tests.check((select locked from public.study_catalog('note') where title = 'TST premium note'), 'Free: premium note locked');
select tests.check((select locked from public.study_catalog('video_solution') where title = 'TST free video'), 'Free: videos off in the Free plan, even free ones');
select tests.check((select public.study_item((select id from tests.i where k = 'free_note')) ->> 'body') = 'Free body', 'Free: can open free note');
select tests.throws($q$ select public.study_item((select id from tests.i where k = 'premium_note')) $q$, 'P0001', 'locked', 'Free: premium note raises locked');
select tests.throws($q$ select public.study_item((select id from tests.i where k = 'draft_note')) $q$, 'P0002', 'not_found', 'drafts are not found');
select tests.check(not public.can_view_study_file('v/tst/prem-360.mp4'), 'Free: cannot get a link to a premium video file');
select tests.check(not public.can_view_study_file('v/tst/free-360.mp4'), 'Free: cannot get a link to a video when videos are off');
select tests.throws($q$ select public.study_file_key((select id from tests.i where k = 'premium_video'), '720') $q$, 'P0001', 'locked', 'Free: no file key for a premium video');
select tests.check(not public.can_view_study_file('v/does/not/exist.mp4'), 'unknown keys are never signed');

-- bookmarks and progress: own rows only
insert into public.bookmarks (kind, ref, label) values ('item', (select id from tests.i where k = 'free_note'), 'Free note');
insert into public.study_progress (item_id, progress) values ((select id from tests.i where k = 'free_note'), 0.5);
select tests.throws($q$ insert into public.bookmarks (user_id, kind, ref) values ('00000000-0000-4000-8000-0000000000c2', 'item', gen_random_uuid()) $q$, '42501', null, 'cannot write a bookmark for someone else');

-- ---------------------------------------------------------------- Premium student
select tests.as_user('00000000-0000-4000-8000-0000000000c2');
select tests.check((select count(*) from public.bookmarks) = 0, 'cannot see other students bookmarks');
select tests.check((select count(*) from public.study_progress) = 0, 'cannot see other students progress');
select tests.check((select not locked from public.study_catalog('note') where title = 'TST premium note'), 'Premium: premium note open');
select tests.check((select public.study_item((select id from tests.i where k = 'premium_video')) -> 'files') = '{"360": true, "720": true}', 'Premium: video item says which files exist (no keys)');
select tests.check(public.can_view_study_file('v/tst/prem-720.mp4'), 'Premium: can get a link to a premium video');
select tests.check(public.study_file_key((select id from tests.i where k = 'premium_video'), '720') = 'v/tst/prem-720.mp4', 'Premium: file key for the signer');

-- expired Premium is Free again
reset role;
update public.entitlements set expires_at = now() - interval '1 minute' where user_id = '00000000-0000-4000-8000-0000000000c2';
select tests.as_user('00000000-0000-4000-8000-0000000000c2');
select tests.check((select locked from public.study_catalog('note') where title = 'TST premium note'), 'expired Premium: premium note locked again');

-- ---------------------------------------------------------------- not signed in
select tests.as_anon();
select tests.throws($q$ select * from public.study_catalog('note') $q$, '42501', null, 'anon cannot call study_catalog');

reset role;
select n, ok, name, detail from tests.results order by n;
rollback;
