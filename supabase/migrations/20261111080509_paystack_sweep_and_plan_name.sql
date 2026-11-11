-- D-129: confirm unfinished Paystack payments with Paystack every 2 minutes (never depends on the webhook or the
-- student's browser). Runs only when there is something to check.
select cron.unschedule(jobid) from cron.job where jobname = 'paystack-sweep';
select cron.schedule('paystack-sweep', '*/2 * * * *', $job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/paystack',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-token', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_token')),
    body := '{"action":"sweep"}'::jsonb,
    timeout_milliseconds := 55000)
  where exists (select 1 from public.payments where provider = 'paystack' and status in ('pending', 'abandoned')
                and created_at > now() - interval '48 hours');
$job$);

-- my_plan also names the plan behind the latest Premium end date (website "You're on Premium", D-129).
create or replace function public.my_plan()
 returns jsonb
 language sql
 stable security definer
 set search_path to ''
as $function$
  with e as (
    select e.expires_at, p.name as plan
    from public.entitlements e left join public.plans p on p.id = e.plan_id
    where e.user_id = (select auth.uid()) and e.revoked_at is null and e.expires_at > now()
    order by e.expires_at desc limit 1)
  select jsonb_build_object(
    'tier', case when private.has_premium() then 'premium' else 'free' end,
    'expires_at', (select expires_at from e),
    'plan', (select plan from e),
    'banned', private.is_banned());
$function$;
