-- Every 2 minutes, only when something waits: AI check of posts / comments still pending, and @solutiontee answers.
select cron.schedule('community-sweep', '*/2 * * * *', $c$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/community',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-token', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_token')),
    body := '{"action":"sweep"}'::jsonb,
    timeout_milliseconds := 110000)
  where exists (select 1 from public.community_posts where created_at > now() - interval '1 day'
                and ((status = 'pending' and image_path is null) or (status = 'shown' and ask_ai and not ai_answered)))
     or exists (select 1 from public.community_comments where status = 'pending' and created_at > now() - interval '1 day');
$c$);

