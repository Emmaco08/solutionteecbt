-- SolutionTee CBT · Phase 2 · account status for the sign-up endpoint (server only)
-- 'none' | 'unconfirmed' | 'confirmed'. Only the service role may call it, so it can't be used to check emails.
create or replace function public.auth_user_status(p_email text)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce((
    select case when u.email_confirmed_at is null then 'unconfirmed' else 'confirmed' end
    from auth.users u where lower(u.email) = lower(trim(p_email)) limit 1), 'none');
$$;
revoke execute on function public.auth_user_status from public, anon, authenticated;
grant execute on function public.auth_user_status to service_role;
