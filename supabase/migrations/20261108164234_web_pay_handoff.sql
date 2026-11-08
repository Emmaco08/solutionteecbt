-- D-115: "Pay on our website" from the app without logging in again. The app (signed in) asks the website for a
-- one-time code; the browser opens /pay?h=<code>; the website swaps it, once, within 2 minutes, for a sign-in of that
-- same account. Only a sha256 of the code is stored. Service role only (no policies).
create table if not exists public.web_handoffs (
  code_hash text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  plan text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '2 minutes',
  used_at timestamptz,
  ip_hash text
);
alter table public.web_handoffs enable row level security;
create index if not exists web_handoffs_user on public.web_handoffs (user_id, created_at desc);

-- Old codes are removed every night.
select cron.unschedule('web-handoffs-clean') where exists (select 1 from cron.job where jobname = 'web-handoffs-clean');
select cron.schedule('web-handoffs-clean', '50 1 * * *', $cron$ delete from public.web_handoffs where created_at < now() - interval '1 day'; $cron$);
