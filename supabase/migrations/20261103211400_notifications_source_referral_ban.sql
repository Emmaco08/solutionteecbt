-- 4E3 (D-078): notifications can come from referrals and ban decisions.
alter table public.notifications drop constraint if exists notifications_source_check;
alter table public.notifications add constraint notifications_source_check
  check (source = any (array['admin', 'news', 'year', 'streak', 'premium', 'challenge', 'referral', 'ban']));
