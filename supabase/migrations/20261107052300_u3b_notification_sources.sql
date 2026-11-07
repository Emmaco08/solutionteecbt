-- Notifications from the AI tutor: study-plan mornings, comeback messages, and "your answer is ready".
alter table public.notifications drop constraint notifications_source_check;
alter table public.notifications add constraint notifications_source_check
  check (source = any (array['admin', 'news', 'year', 'streak', 'premium', 'challenge', 'referral', 'ban', 'plan', 'nudge', 'ai']));
