-- D-126 / D-127 / D-128 (owner, 8 Nov 2026).
-- 1) Fraud: a phone is known by two ids (phone-wide "drm" id and Android ID). "Allow" changed only one of them, so the
--    other still blocked the account and admins had to allow twice. Allow/block now applies to every id of the phone,
--    accounts left half-allowed are fixed, and admin_fraud lists each phone once.
-- 2) Email outbox: important moments (ban, unban, second-account block, allowed on a phone, appeal decisions, payment
--    receipts, prize paid, parent turned the account off) queue an email; the website job sends them (shares the
--    Brevo daily limit with log-in codes and always leaves room for codes).
-- 3) Account deletion: a 6-digit email code confirms it, and the reason is kept without any link to the person.

-- ---------------------------------------------------------------- 1) fraud
create or replace function public.admin_device_allow(p_hash text, p_user uuid, p_allowed boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare v_group text[];
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  v_group := private.phone_group(p_hash) || array[p_hash];
  update public.device_accounts set allowed = coalesce(p_allowed, false) where device_hash = any (v_group) and user_id = p_user;
  if not found then raise exception 'Unknown phone or account' using errcode = 'P0002'; end if;
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), 'device.allow', 'device_accounts', left(p_hash, 10), jsonb_build_object('user', p_user, 'allowed', p_allowed, 'ids', cardinality(v_group)));
  perform private.referral_check(p_user);
end $$;

-- Accounts an admin allowed on one id of a phone are allowed on its other id too.
update public.device_accounts d set allowed = true
where not d.allowed and exists (
  select 1 from public.device_accounts o
  where o.user_id = d.user_id and o.allowed and o.device_hash = any (private.phone_group(d.device_hash)));

create or replace function public.admin_fraud()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  return jsonb_build_object(
    'stats', jsonb_build_object(
      'blocked_second', (select count(distinct d.user_id) from public.device_accounts d join public.profiles p on p.id = d.user_id
                          where p.banned_at is null and not private.phone_ok(d.user_id)),
      'banned_accounts', (select count(*) from public.profiles where banned_at is not null),
      'banned_phones', (select count(*) from (select distinct (select min(h) from unnest(private.phone_group(b.device_hash)) h)
                         from public.banned_devices b where b.lifted_at is null) x),
      'clones_7d', (select count(*) from public.device_events where kind = 'clone' and at > now() - interval '7 days'),
      'appeals_waiting', (select count(*) from public.ban_appeals where status = 'pending') + (select count(*) from public.device_appeals where status = 'pending'),
      'phones_seen', (select count(*) from (select distinct (select min(h) from unnest(private.phone_group(d.device_hash)) h) from public.device_accounts d) x)),
    -- One entry per phone (all its ids together); "hash" is the id used by the actions.
    'shared_phones', coalesce((select jsonb_agg(ph order by ph.last desc) from (
       select g.gk as hash, left(g.gk, 10) as device, array_agg(distinct g.device_hash) as hashes, max(d.last_seen) as last,
              bool_or(exists (select 1 from public.banned_devices b where b.device_hash = g.device_hash and b.lifted_at is null)) as banned,
              (select coalesce(array_agg(distinct f), '{}') from public.device_accounts y, unnest(y.flags) f where y.device_hash = any (array_agg(g.device_hash))) as flags,
              (select jsonb_agg(a order by a.first_seen, a.user_id) from (
                 select x.user_id, p.full_name as name, u.email, min(x.first_seen) as first_seen, max(x.last_seen) as last_seen,
                        p.banned_at is not null as banned, p.ban_reason, bool_and(x.allowed) as allowed,
                        not private.phone_ok(x.user_id) as blocked,
                        (select count(*) from public.attempts t where t.user_id = x.user_id) as attempts,
                        exists (select 1 from public.entitlements e where e.user_id = x.user_id and e.revoked_at is null and e.expires_at > now()) as premium
                 from public.device_accounts x join public.profiles p on p.id = x.user_id join auth.users u on u.id = x.user_id
                 where x.device_hash = any (array_agg(g.device_hash))
                 group by x.user_id, p.full_name, u.email, p.banned_at, p.ban_reason) a) as accounts
       from (select s.device_hash, (select min(h) from unnest(private.phone_group(s.device_hash)) h) as gk
             from (select device_hash from public.device_accounts group by device_hash having count(distinct user_id) > 1) s) g
       join public.device_accounts d on d.device_hash = g.device_hash
       group by g.gk order by max(d.last_seen) desc limit 200) ph), '[]'::jsonb),
    'banned_phones', coalesce((select jsonb_agg(bp order by bp.banned_at desc) from (
       select (select min(h) from unnest(private.phone_group(b.device_hash)) h) as hash, left((select min(h) from unnest(private.phone_group(b.device_hash)) h), 10) as device,
              max(b.reason) as reason, max(b.banned_at) as banned_at, max((select s.full_name from public.profiles s where s.id = b.banned_by)) as by,
              (select count(distinct d.user_id) from public.device_accounts d where d.device_hash = any (array_agg(b.device_hash))) as accounts
       from public.banned_devices b where b.lifted_at is null group by 1, 2) bp), '[]'::jsonb),
    'banned', coalesce((select jsonb_agg(jsonb_build_object('user_id', p.id, 'name', p.full_name, 'email', u.email, 'reason', p.ban_reason,
         'banned_at', p.banned_at) order by p.banned_at desc) from public.profiles p join auth.users u on u.id = p.id where p.banned_at is not null), '[]'::jsonb),
    'appeals', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'user_id', a.user_id, 'name', p.full_name, 'reason', a.reason,
         'ban_reason', p.ban_reason, 'status', a.status, 'note', a.admin_note, 'created_at', a.created_at) order by (a.status = 'pending') desc, a.created_at desc)
       from public.ban_appeals a join public.profiles p on p.id = a.user_id), '[]'::jsonb),
    'phone_appeals', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'hash', a.device_hash, 'device', left(a.device_hash, 10), 'email', a.email,
         'reason', a.reason, 'status', a.status, 'note', a.admin_note, 'created_at', a.created_at,
         'ban_reason', (select b.reason from public.banned_devices b where b.device_hash = a.device_hash)) order by (a.status = 'pending') desc, a.created_at desc)
       from public.device_appeals a), '[]'::jsonb),
    'flagged', coalesce((select jsonb_agg(t order by t.last desc) from (
       select d.user_id, p.full_name as name, u.email, max(d.last_seen) as last, array_agg(distinct f) as flags
       from public.device_accounts d cross join lateral unnest(d.flags) f join public.profiles p on p.id = d.user_id join auth.users u on u.id = d.user_id
       group by d.user_id, p.full_name, u.email order by max(d.last_seen) desc limit 100) t), '[]'::jsonb),
    'events', coalesce((select jsonb_agg(jsonb_build_object('at', e.at, 'kind', e.kind, 'detail', e.detail, 'device', left(e.device_hash, 10),
         'hash', e.device_hash, 'user_id', e.user_id, 'name', p.full_name) order by e.at desc)
       from (select * from public.device_events order by at desc limit 100) e left join public.profiles p on p.id = e.user_id), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------- 2) email outbox
create table if not exists private.email_outbox (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users (id) on delete cascade,
  kind text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  tries smallint not null default 0,
  error text
);
create index if not exists email_outbox_waiting on private.email_outbox (created_at) where sent_at is null;

-- Queue one email (no staff accounts; the same kind for the same person is not repeated within 10 minutes).
create or replace function private.queue_email(p_user uuid, p_kind text, p_data jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_user is null or exists (select 1 from public.staff s where s.user_id = p_user) then return; end if;
  if exists (select 1 from private.email_outbox o where o.user_id = p_user and o.kind = p_kind and o.created_at > now() - interval '10 minutes') then return; end if;
  -- An accepted appeal already says the account is open again.
  if p_kind = 'account_unbanned' and exists (select 1 from private.email_outbox o where o.user_id = p_user and o.kind = 'ban_appeal'
       and (o.data ->> 'accepted')::boolean and o.created_at > now() - interval '10 minutes') then return; end if;
  insert into private.email_outbox (user_id, kind, data) values (p_user, p_kind, coalesce(p_data, '{}'::jsonb));
end $$;

create or replace function private.mail_on_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.banned_at is null and new.banned_at is not null then
    perform private.queue_email(new.id, 'account_banned', jsonb_build_object('reason', new.ban_reason));
  elsif old.banned_at is not null and new.banned_at is null then
    perform private.queue_email(new.id, 'account_unbanned', '{}'::jsonb);
  end if;
  return new;
end $$;
drop trigger if exists profiles_mail on public.profiles;
create trigger profiles_mail after update of banned_at on public.profiles for each row execute function private.mail_on_profile();

create or replace function private.mail_on_device_event() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.kind = 'second_account' and new.user_id is not null then
    perform private.queue_email(new.user_id, 'second_account_blocked', '{}'::jsonb);
  end if;
  return new;
end $$;
drop trigger if exists device_events_mail on public.device_events;
create trigger device_events_mail after insert on public.device_events for each row execute function private.mail_on_device_event();

create or replace function private.mail_on_device_allow() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.allowed and not old.allowed then perform private.queue_email(new.user_id, 'phone_allowed', '{}'::jsonb); end if;
  return new;
end $$;
drop trigger if exists device_accounts_mail on public.device_accounts;
create trigger device_accounts_mail after update of allowed on public.device_accounts for each row execute function private.mail_on_device_allow();

create or replace function private.mail_on_ban_appeal() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.status = 'pending' and new.status in ('accepted', 'rejected') then
    perform private.queue_email(new.user_id, 'ban_appeal', jsonb_build_object('accepted', new.status = 'accepted', 'note', new.admin_note));
  end if;
  return new;
end $$;
drop trigger if exists ban_appeals_mail on public.ban_appeals;
create trigger ban_appeals_mail after update of status on public.ban_appeals for each row execute function private.mail_on_ban_appeal();

create or replace function private.mail_on_payment() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status::text = 'success' and old.status::text is distinct from 'success' and new.provider in ('paystack', 'play') and new.user_id is not null then
    perform private.queue_email(new.user_id, 'payment_receipt', jsonb_build_object(
      'reference', new.reference, 'provider', new.provider, 'amount_kobo', new.amount_kobo, 'discount_kobo', coalesce(new.discount_kobo, 0),
      'fee_kobo', coalesce(new.fee_kobo, 0), 'plan', (select pl.name from public.plans pl where pl.id = new.plan_id),
      'item', new.item_kind, 'at', now(),
      'expires_at', (select e.expires_at from public.entitlements e where e.id = new.entitlement_id)));
  end if;
  return new;
end $$;
drop trigger if exists payments_mail on public.payments;
create trigger payments_mail after update of status on public.payments for each row execute function private.mail_on_payment();

create or replace function private.mail_on_prize_paid() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'paid' and old.status is distinct from 'paid' then
    perform private.queue_email(new.user_id, 'prize_paid', jsonb_build_object('amount', new.amount, 'bank', new.bank_name,
      'title', (select c.title from public.challenge_entries e join public.challenges c on c.id = e.challenge_id where e.id = new.entry_id)));
  end if;
  return new;
end $$;
drop trigger if exists prize_claims_mail on public.prize_claims;
create trigger prize_claims_mail after update of status on public.prize_claims for each row execute function private.mail_on_prize_paid();

create or replace function private.mail_on_guardian_off() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.withdrawn_at is null and new.withdrawn_at is not null then
    perform private.queue_email(new.user_id, 'guardian_turned_off', '{}'::jsonb);
  end if;
  return new;
end $$;
drop trigger if exists guardian_consents_mail on public.guardian_consents;
create trigger guardian_consents_mail after update of withdrawn_at on public.guardian_consents for each row execute function private.mail_on_guardian_off();

-- Website job: emails waiting (never more than the room left today after keeping 60 for log-in codes).
create or replace function public.email_outbox_due(p_limit int default 50) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', o.id, 'kind', o.kind, 'data', o.data, 'email', u.email, 'name', coalesce(p.full_name, ''))), '[]'::jsonb)
  from (select * from private.email_outbox where sent_at is null and tries < 5 order by created_at
        limit greatest(least(p_limit, 220 - (select count(*)::int from private.email_send_log l where l.at > now() - interval '24 hours')), 0)) o
  join auth.users u on u.id = o.user_id
  left join public.profiles p on p.id = o.user_id
  where u.email is not null;
$$;

create or replace function public.email_outbox_mark(p_id bigint, p_ok boolean, p_error text default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update private.email_outbox set sent_at = case when p_ok then now() else sent_at end, tries = tries + case when p_ok then 0 else 1 end,
         error = case when p_ok then null else left(p_error, 300) end where id = p_id;
  if p_ok then insert into private.email_send_log (kind, email_hash, ip_hash) values ('notice', 'outbox:' || p_id, null); end if;
end $$;

-- Admin view of the outbox (Emails page).
create or replace function public.admin_email_outbox() returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then jsonb_build_object(
    'waiting', (select count(*) from private.email_outbox where sent_at is null and tries < 5),
    'failed', (select count(*) from private.email_outbox where sent_at is null and tries >= 5),
    'sent_7d', (select coalesce(jsonb_object_agg(kind, n), '{}'::jsonb) from (select kind, count(*) n from private.email_outbox where sent_at > now() - interval '7 days' group by 1) x))
  end;
$$;

-- ---------------------------------------------------------------- 3) account deletion
create table if not exists private.delete_codes (
  user_id uuid primary key references auth.users (id) on delete cascade,
  code_hash text not null,
  reason text,
  note text,
  expires_at timestamptz not null,
  tries smallint not null default 0,
  sends smallint not null default 1,
  first_sent_at timestamptz not null default now(),
  sent_at timestamptz not null default now()
);

-- Why students leave (no user id, no email: only the reason, how long they were members and if they had Premium).
create table if not exists public.account_deletion_reasons (
  id bigint generated always as identity primary key,
  reason text not null,
  note text check (char_length(note) <= 500),
  via text not null default 'app' check (via in ('app', 'web')),
  days_member integer,
  had_premium boolean,
  created_at timestamptz not null default now()
);
alter table public.account_deletion_reasons enable row level security;
drop policy if exists "staff read" on public.account_deletion_reasons;
create policy "staff read" on public.account_deletion_reasons for select using (private.is_staff());

-- Start: store the code's hash (10 minutes). At most one code a minute and 5 an hour for one account.
create or replace function public.delete_code_start(p_user uuid, p_hash text, p_reason text, p_note text) returns text
language plpgsql security definer set search_path = '' as $$
declare r private.delete_codes;
begin
  select * into r from private.delete_codes where user_id = p_user;
  if r.user_id is not null and r.sent_at > now() - interval '60 seconds' then return 'wait'; end if;
  if r.user_id is not null and r.first_sent_at > now() - interval '1 hour' and r.sends >= 5 then return 'too_many'; end if;
  insert into private.delete_codes (user_id, code_hash, reason, note, expires_at)
  values (p_user, p_hash, left(p_reason, 80), left(p_note, 500), now() + interval '10 minutes')
  on conflict (user_id) do update set code_hash = excluded.code_hash, reason = excluded.reason, note = excluded.note,
    expires_at = excluded.expires_at, tries = 0, sent_at = now(),
    sends = case when private.delete_codes.first_sent_at > now() - interval '1 hour' then private.delete_codes.sends + 1 else 1 end,
    first_sent_at = case when private.delete_codes.first_sent_at > now() - interval '1 hour' then private.delete_codes.first_sent_at else now() end;
  return 'ok';
end $$;

-- Check: 'ok' (and keep the reason), 'wrong', 'expired', 'too_many', 'none'. Five wrong tries end the code.
create or replace function public.delete_code_check(p_user uuid, p_hash text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r private.delete_codes;
begin
  select * into r from private.delete_codes where user_id = p_user for update;
  if r.user_id is null then return jsonb_build_object('result', 'none'); end if;
  if r.tries >= 5 then return jsonb_build_object('result', 'too_many'); end if;
  if r.expires_at < now() then return jsonb_build_object('result', 'expired'); end if;
  if r.code_hash <> p_hash then
    update private.delete_codes set tries = tries + 1 where user_id = p_user;
    return jsonb_build_object('result', 'wrong', 'left', 4 - r.tries);
  end if;
  return jsonb_build_object('result', 'ok', 'reason', r.reason, 'note', r.note);
end $$;

-- Keep the reason (anonymous), just before the account is deleted.
create or replace function public.delete_reason_log(p_user uuid, p_reason text, p_note text, p_via text) returns void
language sql security definer set search_path = '' as $$
  insert into public.account_deletion_reasons (reason, note, via, days_member, had_premium)
  select coalesce(nullif(left(trim(p_reason), 80), ''), 'Not given'), nullif(left(trim(coalesce(p_note, '')), 500), ''),
         case when p_via = 'web' then 'web' else 'app' end,
         (select (now()::date - u.created_at::date) from auth.users u where u.id = p_user),
         exists (select 1 from public.entitlements e where e.user_id = p_user and e.revoked_at is null and e.expires_at > now());
$$;

revoke all on function private.queue_email(uuid, text, jsonb) from public, anon, authenticated;
revoke all on function public.email_outbox_due(int) from public, anon, authenticated;
revoke all on function public.email_outbox_mark(bigint, boolean, text) from public, anon, authenticated;
revoke all on function public.admin_email_outbox() from public, anon;
revoke all on function public.delete_code_start(uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.delete_code_check(uuid, text) from public, anon, authenticated;
revoke all on function public.delete_reason_log(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.email_outbox_due(int) to service_role;
grant execute on function public.email_outbox_mark(bigint, boolean, text) to service_role;
grant execute on function public.admin_email_outbox() to authenticated;
grant execute on function public.delete_code_start(uuid, text, text, text) to service_role;
grant execute on function public.delete_code_check(uuid, text) to service_role;
grant execute on function public.delete_reason_log(uuid, text, text, text) to service_role;

-- Every 5 minutes: parents of teen winners and the outbox (only when something is waiting).
select cron.unschedule('minor-win-notices') where exists (select 1 from cron.job where jobname = 'minor-win-notices');
select cron.unschedule('email-outbox') where exists (select 1 from cron.job where jobname = 'email-outbox');
select cron.schedule('email-outbox', '*/5 * * * *', $cron$
  select net.http_post(
    url := 'https://admin.solutiontee.com/api/cron/accounts',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-token', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_token')),
    body := '{"only":"emails"}'::jsonb,
    timeout_milliseconds := 30000)
  where exists (select 1 from private.guardian_prize_notices where sent_at is null and tries < 5)
     or exists (select 1 from private.email_outbox where sent_at is null and tries < 5);
$cron$);
