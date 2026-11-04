-- The Home daily goal from the server (owner, 2026-11-04): questions answered today (Lagos day) in tests saved
-- from any phone, so it survives logging out and changing phones. The app adds its own not-yet-synced tests.
create or replace function public.my_practice_today()
returns jsonb language sql stable security definer set search_path to '' as $$
  select jsonb_build_object(
    'day', (now() at time zone 'Africa/Lagos')::date,
    'answered', coalesce(sum(coalesce((a.server_score ->> 'answered')::int, (a.client_score ->> 'answered')::int, 0)), 0),
    'tests', count(*)
  )
  from public.attempts a
  where a.user_id = (select auth.uid())
    and a.submitted_at is not null
    and (a.submitted_at at time zone 'Africa/Lagos')::date = (now() at time zone 'Africa/Lagos')::date;
$$;
revoke execute on function public.my_practice_today() from public, anon;
grant execute on function public.my_practice_today() to authenticated;
