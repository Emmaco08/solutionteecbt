-- Send due push notifications now (instead of waiting up to 5 minutes for pg_cron), e.g. "Your AI answer is ready".
create or replace function public.push_kick() returns void
language sql security definer set search_path to '' as $$
  select null::void from (select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/push',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-token', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_token')),
    body := '{"run":"due"}'::jsonb,
    timeout_milliseconds := 30000)) x;
$$;
revoke execute on function public.push_kick() from public, anon, authenticated;
grant execute on function public.push_kick() to service_role;
