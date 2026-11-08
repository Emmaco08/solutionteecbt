-- D-121 (lawyer, 8 Nov 2026): when cash prizes are on, an admin may also let students aged 13 to 17 win cash. Their
-- parent or guardian is emailed after each win (challenge prize or cash referral reward), and a teen's prize can only
-- be claimed once that email has gone out. The prize is paid to the parent's account (existing claim form).
-- app_settings.cash_prizes.teens (default false): min age 13 instead of 18.

update public.app_settings set value = value || '{"teens": false}'::jsonb
 where key = 'cash_prizes' and not (value ? 'teens');

create or replace function private.cash_min_age() returns integer
language sql stable security definer set search_path = '' as $$
  select case when coalesce((select (value ->> 'teens')::boolean from public.app_settings where key = 'cash_prizes'), false)
              then 13
              else coalesce((select (value ->> 'min_age')::int from public.app_settings where key = 'cash_prizes'), 18) end;
$$;

create table if not exists private.guardian_prize_notices (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('challenge', 'referral')),
  ref_id uuid not null,
  amount integer not null,
  title text,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  tries smallint not null default 0,
  error text,
  unique (kind, ref_id)
);

-- A win by a student under 18 queues the parent email.
create or replace function private.queue_minor_win() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_amount int; v_ref uuid; v_kind text; v_title text;
begin
  if tg_table_name = 'challenge_entries' then
    if coalesce(new.prize, 0) <= 0 or coalesce(old.prize, 0) > 0 then return new; end if;
    v_kind := 'challenge'; v_ref := new.id; v_amount := new.prize;
    select c.title into v_title from public.challenges c where c.id = new.challenge_id;
  else
    if coalesce(new.amount, 0) <= 0 then return new; end if;
    v_kind := 'referral'; v_ref := new.id; v_amount := new.amount; v_title := 'Invite friends reward';
  end if;
  if coalesce(private.user_age(new.user_id), 18) < 18 then
    insert into private.guardian_prize_notices (user_id, kind, ref_id, amount, title)
    values (new.user_id, v_kind, v_ref, v_amount, v_title)
    on conflict (kind, ref_id) do nothing;
  end if;
  return new;
end $$;

drop trigger if exists challenge_entries_minor_win on public.challenge_entries;
create trigger challenge_entries_minor_win after update of prize on public.challenge_entries
  for each row execute function private.queue_minor_win();
drop trigger if exists referral_rewards_minor_win on public.referral_rewards;
create trigger referral_rewards_minor_win after insert on public.referral_rewards
  for each row execute function private.queue_minor_win();

-- Has the parent been told about this win?
create or replace function private.minor_notice_sent(p_kind text, p_ref uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.guardian_prize_notices n where n.kind = p_kind and n.ref_id = p_ref and n.sent_at is not null);
$$;

-- Claims: cash on, age rule, and for under-18s the parent email must have gone out first.
create or replace function private.prize_claim_rules() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_age int := coalesce(private.user_age(new.user_id), 0);
begin
  if not private.cash_on() then
    raise exception 'Cash prizes are switched off for now.' using errcode = 'P0001';
  end if;
  if v_age < private.cash_min_age() then
    raise exception 'Cash prizes are only for students aged % and over.', private.cash_min_age() using errcode = 'P0001';
  end if;
  if v_age < 18 and not private.minor_notice_sent('challenge', new.entry_id) then
    if not exists (select 1 from public.guardian_consents g where g.user_id = new.user_id and g.withdrawn_at is null) then
      raise exception 'We need your parent or guardian''s email before we can pay this prize. Contact support and we will help.' using errcode = 'P0001';
    end if;
    raise exception 'We are emailing your parent or guardian about your prize first. Try again in a few minutes.' using errcode = 'P0001';
  end if;
  return new;
end $$;

create or replace function private.referral_minor_claim() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'claimed' and old.status = 'due' and coalesce(private.user_age(new.user_id), 18) < 18
     and not private.minor_notice_sent('referral', new.id) then
    raise exception 'We are emailing your parent or guardian about your reward first. Try again in a few minutes.' using errcode = 'P0001';
  end if;
  return new;
end $$;
drop trigger if exists referral_rewards_minor_claim on public.referral_rewards;
create trigger referral_rewards_minor_claim before update on public.referral_rewards
  for each row execute function private.referral_minor_claim();

-- Website job: which emails to send, and mark them sent / failed. Service role only.
create or replace function public.minor_win_notices_due(p_limit int default 50) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', n.id, 'kind', n.kind, 'amount', n.amount, 'title', n.title,
      'child', coalesce(p.full_name, ''), 'guardian_email', g.guardian_email)), '[]'::jsonb)
  from (select * from private.guardian_prize_notices
        where sent_at is null and tries < 5 order by created_at limit greatest(least(p_limit, 200), 0)) n
  join public.guardian_consents g on g.user_id = n.user_id and g.withdrawn_at is null
  left join public.profiles p on p.id = n.user_id;
$$;

create or replace function public.minor_win_notice_mark(p_id bigint, p_ok boolean, p_error text default null) returns void
language sql security definer set search_path = '' as $$
  update private.guardian_prize_notices
     set sent_at = case when p_ok then now() else sent_at end,
         tries = tries + case when p_ok then 0 else 1 end,
         error = case when p_ok then null else left(p_error, 300) end
   where id = p_id;
$$;

-- Admin: notices for the payouts screen (staff only).
create or replace function public.admin_minor_win_notices() returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when private.is_staff() then coalesce((select jsonb_agg(jsonb_build_object(
      'kind', n.kind, 'ref_id', n.ref_id, 'amount', n.amount, 'title', n.title, 'created_at', n.created_at,
      'sent_at', n.sent_at, 'error', n.error,
      'has_guardian', exists (select 1 from public.guardian_consents g where g.user_id = n.user_id and g.withdrawn_at is null))
      order by n.created_at desc) from private.guardian_prize_notices n), '[]'::jsonb) end;
$$;

revoke all on function private.queue_minor_win() from public, anon, authenticated;
revoke all on function private.minor_notice_sent(text, uuid) from public, anon, authenticated;
revoke all on function private.referral_minor_claim() from public, anon, authenticated;
revoke all on function public.minor_win_notices_due(int) from public, anon, authenticated;
revoke all on function public.minor_win_notice_mark(bigint, boolean, text) from public, anon, authenticated;
revoke all on function public.admin_minor_win_notices() from public, anon;
grant execute on function public.minor_win_notices_due(int) to service_role;
grant execute on function public.minor_win_notice_mark(bigint, boolean, text) to service_role;
grant execute on function public.admin_minor_win_notices() to authenticated;

-- Every 10 minutes: the website emails parents about new wins (and runs nothing else).
select cron.unschedule('minor-win-notices') where exists (select 1 from cron.job where jobname = 'minor-win-notices');
select cron.schedule('minor-win-notices', '*/10 * * * *', $cron$
  select net.http_post(
    url := 'https://admin.solutiontee.com/api/cron/accounts',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-token', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_token')),
    body := '{"only":"minor_wins"}'::jsonb,
    timeout_milliseconds := 30000)
  where exists (select 1 from private.guardian_prize_notices where sent_at is null and tries < 5);
$cron$);
