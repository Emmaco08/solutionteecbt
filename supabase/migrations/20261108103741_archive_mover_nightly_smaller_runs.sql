-- The free Edge Function plan allows little CPU per call: one call moves at most 20 batches. The nightly job now calls
-- the mover three times, 10 minutes apart (02:15, 02:25, 02:35 Lagos), each with 20 batches.
select cron.unschedule('archive-mover') where exists (select 1 from cron.job where jobname = 'archive-mover');
select cron.schedule('archive-mover', '15,25,35 1 * * *', $cron$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/archive-mover',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-token', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_token')),
    body := '{"max_batches": 20}'::jsonb,
    timeout_milliseconds := 150000);
$cron$);
