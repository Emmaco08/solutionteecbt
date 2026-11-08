-- D-118 (Privacy Policy §10, lawyer's decision 8): AI tutor messages and question photos are kept for up to 12 months.
-- Nightly: messages older than 12 months are deleted on Supabase (the archive-mover deletes the Neon copies the same way),
-- chats with no activity for 12 months are deleted, and deleted chats are removed for good after 30 days.
select cron.unschedule('ai-retention') where exists (select 1 from cron.job where jobname = 'ai-retention');
select cron.schedule('ai-retention', '5 2 * * *', $cron$
  delete from public.ai_messages where created_at < now() - interval '12 months';
  delete from public.ai_chats where updated_at < now() - interval '12 months'
     or (deleted_at is not null and deleted_at < now() - interval '30 days');
$cron$);
