-- Updates and maintenance v2 (owner, 14 Nov 2026).
-- play_update: Play Store app. prompt = show the "update available" pop-up when Google Play has a newer version;
--   force = block the app until it is updated; notes = optional "What's new" text in the pop-up.
-- min_build: every app (Play and website) older than this build number must update.
-- maintenance gains "until" (shown to students) and staff_bypass (staff keep using the app to test).
insert into public.app_settings (key, value, description, is_public)
values ('play_update', '{"prompt": true, "force": false, "notes": ""}', 'Play Store app update pop-up and forced update (Admin → Settings)', true),
       ('min_build', '{"build": 0}', 'Apps older than this build must update (Admin → Settings)', true)
on conflict (key) do nothing;

update public.app_settings
set value = value || jsonb_build_object('until', value -> 'until', 'staff_bypass', coalesce((value ->> 'staff_bypass')::boolean, true))
where key = 'maintenance';

-- One small call the app makes at start, on resume and every few minutes: maintenance, update rules, and whether this
-- person is staff (staff, not tutors, may use the app during maintenance). Works signed out too.
create or replace function public.app_gate()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'maintenance', coalesce((select value from public.app_settings where key = 'maintenance'), '{}'::jsonb),
    'play_update', coalesce((select value from public.app_settings where key = 'play_update'), '{}'::jsonb),
    'app_update', coalesce((select value from public.app_settings where key = 'app_update'), '{}'::jsonb),
    'min_build', coalesce(((select value from public.app_settings where key = 'min_build') ->> 'build')::bigint, 0),
    'staff', coalesce((select exists (select 1 from public.staff s where s.user_id = (select auth.uid()) and s.role <> 'tutor')), false),
    'now', now());
$$;
revoke all on function public.app_gate() from public;
grant execute on function public.app_gate() to anon, authenticated;
