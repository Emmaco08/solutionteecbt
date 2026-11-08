-- The nightly mover (D-108): 01:15 UTC = 02:15 Lagos time, a quiet hour. Same token pattern as the push job.
select cron.unschedule('archive-mover') where exists (select 1 from cron.job where jobname = 'archive-mover');
select cron.schedule('archive-mover', '15 1 * * *', $cron$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/archive-mover',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-token', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_token')),
    body := '{"max_batches": 60}'::jsonb,
    timeout_milliseconds := 150000);
$cron$);
