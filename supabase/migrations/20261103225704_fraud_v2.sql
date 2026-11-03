-- SolutionTee CBT · Fraud v2 (owner, D-079): a phone-wide id (same in dual / cloned apps), clone detection,
-- second accounts refused by the server, phone bans (no new accounts, appeal only), activity log.

-- Longer names in referral codes (EMMANUEL-H9X8, OLUWASEUN-7K3P): up to 12 letters when made, 2–20 accepted.
create or replace function private.new_referral_code(p_name text)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare v_pre text; v_code text; v_tries integer := 0;
begin
  v_pre := left(regexp_replace(upper(split_part(trim(coalesce(p_name, '')), ' ', 1)), '[^A-Z]', '', 'g'), 12);
  if char_length(v_pre) < 2 then v_pre := 'FRIEND'; end if;
  loop
    v_code := v_pre || '-' || (select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1), '')
                               from generate_series(1, 4));
    exit when not exists (select 1 from public.profiles where referral_code = v_code);
    v_tries := v_tries + 1;
    if v_tries > 30 then v_pre := 'ST'; end if;
  end loop;
  return v_code;
end;
$$;

-- Each account now saves two ids per phone: 'drm' (Widevine, the same for every app copy and user on the phone)
-- and 'android' (Android ID, different for dual apps). A match on either links the accounts.
alter table public.device_accounts add column if not exists kind text not null default 'android';
alter table public.device_accounts add column if not exists flags text[] not null default '{}';

create table if not exists public.banned_devices (
  device_hash text primary key check (device_hash ~ '^[0-9a-f]{64}$'),
  reason text not null,
  banned_at timestamptz not null default now(),
  banned_by uuid,
  lifted_at timestamptz,
  lifted_by uuid
);
alter table public.banned_devices enable row level security;
create policy "staff read" on public.banned_devices for select using (private.is_staff());
revoke all on public.banned_devices from anon;
revoke insert, update, delete on public.banned_devices from authenticated;

create table if not exists public.device_appeals (
  id uuid primary key default gen_random_uuid(),
  device_hash text not null,
  email text not null,
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  admin_note text,
  created_at timestamptz not null default now(), decided_at timestamptz, decided_by uuid
);
create unique index if not exists device_appeals_one_pending on public.device_appeals (device_hash) where status = 'pending';
alter table public.device_appeals enable row level security;
create policy "staff read" on public.device_appeals for select using (private.is_staff());
revoke all on public.device_appeals from anon;
revoke insert, update, delete on public.device_appeals from authenticated;

create table if not exists public.device_events (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  user_id uuid references public.profiles (id) on delete set null,
  device_hash text,
  kind text not null,
  detail text
);
create index if not exists device_events_at on public.device_events (at desc);
alter table public.device_events enable row level security;
create policy "staff read" on public.device_events for select using (private.is_staff());
revoke all on public.device_events from anon;
revoke insert, update, delete on public.device_events from authenticated;

/** Every id of the phones this id was seen with (the drm and android ids saved together by the same accounts). */
create or replace function private.phone_group(p_hash text)
returns text[] language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(distinct x.device_hash), array[p_hash]) from public.device_accounts x
  where x.device_hash = p_hash
     or (x.user_id in (select d.user_id from public.device_accounts d where d.device_hash = p_hash)
         and x.kind <> (select coalesce(max(k.kind), '') from public.device_accounts k where k.device_hash = p_hash)
         and exists (select 1 from public.device_accounts y where y.user_id = x.user_id and y.device_hash = p_hash
                     and abs(extract(epoch from (y.first_seen - x.first_seen))) < 120));
$$;

create or replace function private.user_phone_banned(p_user uuid)
returns text language sql stable security definer set search_path = '' as $$
  select b.reason from public.device_accounts d join public.banned_devices b on b.device_hash = d.device_hash and b.lifted_at is null
  where d.user_id = p_user limit 1;
$$;

-- Banned now also means: a second account on a phone (unless the admin allowed it) or an account on a banned phone.
-- Every RPC that refuses banned students (questions, study, AI, payments, challenges, referrals) refuses these too.
create or replace function private.is_banned(uid uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p where p.id = uid and p.banned_at is not null)
      or not private.phone_ok(uid)
      or private.user_phone_banned(uid) is not null;
$$;

/** Bans one account from inside the server (phone bans, logins on a banned phone): same effects as admin_ban. */
create or replace function private.ban_account(p_user uuid, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_ch uuid;
begin
  if exists (select 1 from public.staff s where s.user_id = p_user) then return; end if;
  update public.profiles set banned_at = coalesce(banned_at, now()), ban_reason = coalesce(ban_reason, left(p_reason, 500)) where id = p_user;
  update public.referral_rewards set status = 'cancelled', admin_note = 'Account banned' where user_id = p_user and status in ('due', 'claimed');
  update public.referrals set status = 'blocked', reason = 'Account banned' where friend = p_user and status = 'pending';
  for v_ch in select distinct e.challenge_id from public.challenge_entries e
              where e.user_id = p_user and e.prize is not null
                and not exists (select 1 from public.prize_claims pc where pc.entry_id = e.id and pc.status = 'paid') loop
    update public.prize_claims set status = 'rejected', admin_note = 'Account banned'
    where entry_id in (select id from public.challenge_entries where challenge_id = v_ch and user_id = p_user) and status <> 'paid';
    update public.challenge_entries set review = 'dq', prize = null, rank = null where challenge_id = v_ch and user_id = p_user;
    perform private.challenge_rank(v_ch);
  end loop;
end;
$$;

create or replace function public.my_status()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); p public.profiles; a record; v_phone text;
begin
  if v_uid is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into p from public.profiles where id = v_uid;
  select * into a from public.ban_appeals b where b.user_id = v_uid and b.banned_at = p.banned_at;
  v_phone := private.user_phone_banned(v_uid);
  return jsonb_build_object(
    'banned', p.banned_at is not null and v_phone is null, 'ban_reason', p.ban_reason, 'banned_at', p.banned_at,
    'appeal', case when a.id is not null then jsonb_build_object('status', a.status, 'note', a.admin_note, 'created_at', a.created_at) end,
    'can_appeal', p.banned_at is not null and a.id is null and now() < p.banned_at + interval '14 days',
    'phone_banned', v_phone is not null, 'phone_ban_reason', v_phone,
    'phone_taken', not private.phone_ok(v_uid) and not exists (select 1 from public.staff s where s.user_id = v_uid));
end;
$$;

/** After sign-in and on every app start: save this phone's ids and what the phone noticed (clone, emulator). Logs a
    second account, a clone and a login on a banned phone; an account that signs in on a banned phone is banned. */
create or replace function public.device_check_in(p_ids text[], p_flags text[] default '{}')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_kinds text[] := array['drm', 'android']; i integer; v_hash text; v_any text;
        v_flags text[] := coalesce(p_flags[1:10], '{}'); v_ban text; v_clone boolean; v_taken_before boolean;
begin
  if v_uid is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  if exists (select 1 from public.staff s where s.user_id = v_uid) then
    return public.my_status() || jsonb_build_object('clone', false);
  end if;
  v_taken_before := not private.phone_ok(v_uid);
  for i in 1 .. least(coalesce(cardinality(p_ids), 0), 2) loop
    v_hash := p_ids[i];
    if v_hash ~ '^[0-9a-f]{64}$' then
      v_any := coalesce(v_any, v_hash);
      insert into public.device_accounts (device_hash, user_id, kind, flags) values (v_hash, v_uid, v_kinds[i], v_flags)
      on conflict (device_hash, user_id) do update set last_seen = now(), flags = excluded.flags;
    end if;
  end loop;
  v_clone := exists (select 1 from unnest(v_flags) f where f like 'clone:%');
  if v_clone and not exists (select 1 from public.device_events e where e.user_id = v_uid and e.kind = 'clone' and e.at > now() - interval '1 day') then
    insert into public.device_events (user_id, device_hash, kind, detail) values (v_uid, v_any, 'clone', array_to_string(v_flags, ', '));
  end if;
  select b.reason into v_ban from public.banned_devices b where b.device_hash = any (p_ids) and b.lifted_at is null limit 1;
  if v_ban is not null then
    if not exists (select 1 from public.profiles p where p.id = v_uid and p.banned_at is not null) then
      perform private.ban_account(v_uid, 'Phone banned: ' || v_ban);
      insert into public.device_events (user_id, device_hash, kind, detail) values (v_uid, v_any, 'banned_phone_login', v_ban);
    end if;
  elsif not v_taken_before and not private.phone_ok(v_uid) then
    insert into public.device_events (user_id, device_hash, kind, detail) values (v_uid, v_any, 'second_account', 'Signed in on a phone that already has an account');
  end if;
  perform private.referral_check(v_uid);
  return public.my_status() || jsonb_build_object('clone', v_clone);
end;
$$;

/** Old apps (before D-079) keep working: one id. */
create or replace function public.device_register(p_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  return public.device_check_in(array[null, p_hash]::text[], '{}');
end;
$$;

/** Before sign-in (the app's first screen, the sign-up API): is this phone banned? */
create or replace function public.device_status(p_ids text[])
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'banned', b.device_hash is not null, 'reason', b.reason,
    'appeal', (select jsonb_build_object('status', a.status, 'note', a.admin_note, 'created_at', a.created_at)
               from public.device_appeals a where a.device_hash = any (p_ids) order by a.created_at desc limit 1))
  from (select 1) one
  left join lateral (select x.device_hash, x.reason from public.banned_devices x
                     where x.device_hash = any (coalesce(p_ids[1:2], '{}')) and x.lifted_at is null limit 1) b on true;
$$;

/** A banned phone can send an appeal without an account (email to reply to). One waiting appeal per phone, 3 in all. */
create or replace function public.device_appeal(p_ids text[], p_email text, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_hash text;
begin
  select x.device_hash into v_hash from public.banned_devices x where x.device_hash = any (coalesce(p_ids[1:2], '{}')) and x.lifted_at is null limit 1;
  if v_hash is null then raise exception 'This phone is not banned.' using errcode = 'P0001'; end if;
  if coalesce(trim(p_email), '') !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Enter your email so we can reply.' using errcode = '22023'; end if;
  if char_length(trim(coalesce(p_reason, ''))) < 10 then raise exception 'Tell us what happened in a sentence or two.' using errcode = '22023'; end if;
  if exists (select 1 from public.device_appeals a where a.device_hash = v_hash and a.status = 'pending') then
    raise exception 'We already have an appeal for this phone. We will reply by email.' using errcode = 'P0001';
  end if;
  if (select count(*) from public.device_appeals a where a.device_hash = v_hash) >= 3 then
    raise exception 'This phone has sent too many appeals.' using errcode = 'P0001';
  end if;
  insert into public.device_appeals (device_hash, email, reason) values (v_hash, lower(trim(p_email)), left(trim(p_reason), 2000));
  insert into public.device_events (device_hash, kind, detail) values (v_hash, 'phone_appeal', lower(trim(p_email)));
  return jsonb_build_object('ok', true);
end;
$$;

/** Admin: ban a phone (all its ids) and every account on it. Nobody can create or use an account there; appeal only. */
create or replace function public.admin_ban_device(p_hash text, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_group text[]; v_users uuid[]; v_u uuid;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  if char_length(trim(coalesce(p_reason, ''))) < 3 then raise exception 'Write the reason (the person sees it).' using errcode = '22023'; end if;
  v_group := private.phone_group(p_hash);
  insert into public.banned_devices (device_hash, reason, banned_by)
  select h, left(trim(p_reason), 500), (select auth.uid()) from unnest(v_group) h where h ~ '^[0-9a-f]{64}$'
  on conflict (device_hash) do update set reason = excluded.reason, banned_at = now(), banned_by = excluded.banned_by, lifted_at = null, lifted_by = null;
  select coalesce(array_agg(distinct d.user_id), '{}') into v_users from public.device_accounts d
  where d.device_hash = any (v_group) and not exists (select 1 from public.staff s where s.user_id = d.user_id);
  foreach v_u in array v_users loop
    perform private.ban_account(v_u, 'Phone banned: ' || trim(p_reason));
  end loop;
  insert into public.device_events (device_hash, kind, detail) values (p_hash, 'phone_banned', p_reason);
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), 'device.ban', 'banned_devices', left(p_hash, 10), jsonb_build_object('reason', p_reason, 'ids', cardinality(v_group), 'accounts', cardinality(v_users)));
  return jsonb_build_object('ok', true, 'accounts', cardinality(v_users), 'ids', cardinality(v_group));
end;
$$;

/** Admin: lift a phone ban; accounts banned only because of it open again. */
create or replace function public.admin_unban_device(p_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_group text[]; v_u uuid; v_n integer := 0;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  v_group := private.phone_group(p_hash) || array[p_hash];
  update public.banned_devices set lifted_at = now(), lifted_by = (select auth.uid()) where device_hash = any (v_group) and lifted_at is null;
  for v_u in select distinct p.id from public.device_accounts d join public.profiles p on p.id = d.user_id
             where d.device_hash = any (v_group) and p.ban_reason like 'Phone banned:%' loop
    update public.profiles set banned_at = null, ban_reason = null where id = v_u;
    v_n := v_n + 1;
  end loop;
  insert into public.device_events (device_hash, kind, detail) values (p_hash, 'phone_unbanned', null);
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), 'device.unban', 'banned_devices', left(p_hash, 10), jsonb_build_object('accounts_opened', v_n));
  return jsonb_build_object('ok', true, 'accounts', v_n);
end;
$$;

create or replace function public.admin_device_appeal(p_id uuid, p_accept boolean, p_note text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare a public.device_appeals;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  update public.device_appeals set status = case when p_accept then 'accepted' else 'rejected' end, admin_note = left(p_note, 500),
    decided_at = now(), decided_by = (select auth.uid())
  where id = p_id and status = 'pending' returning * into a;
  if a.id is null then raise exception 'This appeal was already decided.' using errcode = 'P0001'; end if;
  if p_accept then perform public.admin_unban_device(a.device_hash); end if;
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), 'device.appeal', 'device_appeals', a.id::text, jsonb_build_object('accepted', p_accept, 'note', p_note));
  return jsonb_build_object('ok', true, 'email', a.email);
end;
$$;

/** Fraud & bans page (v2): totals, shared phones (with flags and ban state), banned phones and accounts, both kinds
    of appeals, accounts the phone flagged, and the latest activity. */
create or replace function public.admin_fraud()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  return jsonb_build_object(
    'stats', jsonb_build_object(
      'shared_phones', (select count(*) from (select device_hash from public.device_accounts group by device_hash having count(*) > 1) s),
      'blocked_second', (select count(distinct d.user_id) from public.device_accounts d where not private.phone_ok(d.user_id)),
      'banned_accounts', (select count(*) from public.profiles where banned_at is not null),
      'banned_phones', (select count(*) from public.banned_devices where lifted_at is null),
      'clones_7d', (select count(*) from public.device_events where kind = 'clone' and at > now() - interval '7 days'),
      'appeals_waiting', (select count(*) from public.ban_appeals where status = 'pending') + (select count(*) from public.device_appeals where status = 'pending'),
      'phones_seen', (select count(distinct device_hash) from public.device_accounts)),
    'shared_phones', coalesce((select jsonb_agg(g order by g.last desc) from (
       select d.device_hash as hash, left(d.device_hash, 10) as device, max(d.kind) as kind, max(d.last_seen) as last,
              exists (select 1 from public.banned_devices b where b.device_hash = d.device_hash and b.lifted_at is null) as banned,
              (select coalesce(array_agg(distinct f), '{}') from public.device_accounts y, unnest(y.flags) f where y.device_hash = d.device_hash) as flags,
              jsonb_agg(jsonb_build_object('user_id', d.user_id, 'name', p.full_name, 'email', u.email, 'first_seen', d.first_seen,
                'last_seen', d.last_seen, 'banned', p.banned_at is not null, 'ban_reason', p.ban_reason, 'allowed', d.allowed,
                'attempts', (select count(*) from public.attempts a where a.user_id = d.user_id),
                'premium', exists (select 1 from public.entitlements e where e.user_id = d.user_id and e.revoked_at is null and e.expires_at > now()))
                order by d.first_seen, d.user_id) as accounts
       from public.device_accounts d join public.profiles p on p.id = d.user_id join auth.users u on u.id = d.user_id
       group by d.device_hash having count(*) > 1 order by max(d.last_seen) desc limit 200) g), '[]'::jsonb),
    'banned_phones', coalesce((select jsonb_agg(jsonb_build_object('hash', b.device_hash, 'device', left(b.device_hash, 10), 'reason', b.reason,
         'banned_at', b.banned_at, 'by', (select s.full_name from public.profiles s where s.id = b.banned_by),
         'accounts', (select count(distinct d.user_id) from public.device_accounts d where d.device_hash = b.device_hash)) order by b.banned_at desc)
       from public.banned_devices b where b.lifted_at is null), '[]'::jsonb),
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
end;
$$;

revoke execute on function private.phone_group(text), private.user_phone_banned(uuid), private.ban_account(uuid, text) from public, anon, authenticated;
revoke execute on function public.device_check_in(text[], text[]), public.admin_ban_device(text, text), public.admin_unban_device(text),
  public.admin_device_appeal(uuid, boolean, text) from public, anon;
grant execute on function public.device_check_in(text[], text[]), public.admin_ban_device(text, text), public.admin_unban_device(text),
  public.admin_device_appeal(uuid, boolean, text) to authenticated;
grant execute on function public.device_status(text[]), public.device_appeal(text[], text, text) to anon, authenticated;
