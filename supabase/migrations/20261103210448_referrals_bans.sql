-- SolutionTee CBT · 4E3 (D-078): referrals, one account per phone, bans with one appeal.
-- Plan: docs/plans/phase-4e3.md. Rules: D-031, D-032.

-- ── Settings ────────────────────────────────────────────────────────────────────────────────────────────────────
insert into public.app_settings (key, value, description, is_public)
values ('referrals', '{"enabled": true, "pct_per_friend": 10, "max_pct": 100, "count_on": "test", "cash_every": 30, "cash_naira": 5000, "monthly_cap": 20}',
        'Referral rewards (Admin → Referrals)', false)
on conflict (key) do nothing;

create or replace function private.ref_settings()
returns jsonb language sql stable security definer set search_path = '' as $$
  select '{"enabled": true, "pct_per_friend": 10, "max_pct": 100, "count_on": "test", "cash_every": 30, "cash_naira": 5000, "monthly_cap": 20}'::jsonb
         || coalesce((select value from public.app_settings where key = 'referrals'), '{}'::jsonb);
$$;

-- ── Codes ───────────────────────────────────────────────────────────────────────────────────────────────────────
alter table public.profiles add column if not exists referral_code text unique;

/** "TOLU-7K3P": the first name (letters only, up to 8) and 4 characters that cannot be confused (no 0/O, 1/I). */
create or replace function private.new_referral_code(p_name text)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare v_pre text; v_code text; v_tries integer := 0;
begin
  v_pre := left(regexp_replace(upper(split_part(trim(coalesce(p_name, '')), ' ', 1)), '[^A-Z]', '', 'g'), 8);
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

-- ── Phones ──────────────────────────────────────────────────────────────────────────────────────────────────────
create table if not exists public.device_accounts (
  device_hash text not null check (device_hash ~ '^[0-9a-f]{64}$'),
  user_id uuid not null references public.profiles (id) on delete cascade,
  first_seen timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  allowed boolean not null default false,
  primary key (device_hash, user_id)
);
create index if not exists device_accounts_user on public.device_accounts (user_id);
alter table public.device_accounts enable row level security;
create policy "staff read" on public.device_accounts for select using (private.is_staff());
revoke all on public.device_accounts from anon;
revoke insert, update, delete on public.device_accounts from authenticated;

/** The student is the first account on each of their phones (or the admin allowed them). */
create or replace function private.phone_ok(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select not exists (
    select 1 from public.device_accounts d
    where d.user_id = p_user and not d.allowed
      and exists (select 1 from public.device_accounts o where o.device_hash = d.device_hash and o.user_id <> p_user
                    and (o.first_seen, o.user_id::text) < (d.first_seen, d.user_id::text)));
$$;

-- ── Referrals ───────────────────────────────────────────────────────────────────────────────────────────────────
create table if not exists public.referrals (
  id uuid primary key default gen_random_uuid(),
  referrer uuid not null references public.profiles (id) on delete cascade,
  friend uuid not null unique references public.profiles (id) on delete cascade,
  code text,
  status text not null default 'pending' check (status in ('pending', 'counted', 'blocked')),
  reason text,
  created_at timestamptz not null default now(),
  counted_at timestamptz,
  spent_payment uuid references public.payments (id) on delete set null,
  check (referrer <> friend)
);
create index if not exists referrals_referrer on public.referrals (referrer, status);
alter table public.referrals enable row level security;
create policy "own or staff" on public.referrals for select using (referrer = (select auth.uid()) or private.is_staff());
revoke all on public.referrals from anon;
revoke insert, update, delete on public.referrals from authenticated;

create table if not exists public.referral_rewards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  milestone integer not null,
  amount integer not null,
  status text not null default 'due' check (status in ('due', 'claimed', 'paid', 'cancelled')),
  bank_name text, account_number text, account_name text,
  admin_note text, receipt_path text,
  created_at timestamptz not null default now(), claimed_at timestamptz, paid_at timestamptz, paid_by uuid,
  unique (user_id, milestone)
);
alter table public.referral_rewards enable row level security;
create policy "own or money admins" on public.referral_rewards for select
  using (user_id = (select auth.uid()) or private.is_staff(array['super_admin', 'admin']::public.staff_role[]));
revoke all on public.referral_rewards from anon;
revoke insert, update, delete on public.referral_rewards from authenticated;

alter table public.payments add column if not exists referral_friends smallint not null default 0;

/** Counted friends not yet used for a discount. */
create or replace function private.referral_unspent(p_user uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.referrals r where r.referrer = p_user and r.status = 'counted' and r.spent_payment is null;
$$;

/** Cash every N counted friends (never resets). */
create or replace function private.referral_milestones(p_user uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare s jsonb := private.ref_settings(); v_n integer; v_every integer; m integer;
begin
  v_every := greatest(coalesce((s ->> 'cash_every')::int, 30), 0);
  if v_every = 0 or coalesce((s ->> 'cash_naira')::int, 0) <= 0 then return; end if;
  select count(*) into v_n from public.referrals where referrer = p_user and status = 'counted';
  for m in 1 .. (v_n / v_every) loop
    insert into public.referral_rewards (user_id, milestone, amount) values (p_user, m * v_every, (s ->> 'cash_naira')::int)
    on conflict (user_id, milestone) do nothing;
    if found then
      insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
      values ('account', 'You earned ' || '₦' || to_char((s ->> 'cash_naira')::int, 'FM999,999,990'),
              m * v_every || ' friends joined with your code. Send your account details to get paid.', 'user', p_user, 'scheduled', now(),
              'referral', jsonb_build_object('type', 'screen', 'target', '/invite'));
    end if;
  end loop;
end;
$$;

/** Does this friend count now? Email verified, one finished test (or Premium), their own phone, under the monthly limit. */
create or replace function private.referral_check(p_friend uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare r public.referrals; s jsonb := private.ref_settings(); v_month integer; v_why text;
begin
  select * into r from public.referrals where friend = p_friend and status = 'pending' for update;
  if not found or not coalesce((s ->> 'enabled')::boolean, true) then return; end if;
  if private.is_banned(p_friend) or private.is_banned(r.referrer) then
    update public.referrals set status = 'blocked', reason = 'Account banned' where id = r.id; return;
  end if;
  if not exists (select 1 from auth.users u where u.id = p_friend and u.email_confirmed_at is not null) then
    v_why := 'Your friend has not verified their email yet';
  elsif s ->> 'count_on' = 'premium' and not exists (select 1 from public.payments p where p.user_id = p_friend and p.status = 'success' and p.amount_kobo > 0) then
    v_why := 'Counts when your friend buys Premium';
  elsif coalesce(s ->> 'count_on', 'test') <> 'premium' and not exists (select 1 from public.attempts a where a.user_id = p_friend and a.status = 'submitted') then
    v_why := 'Counts when your friend finishes one practice test';
  elsif not exists (select 1 from public.device_accounts d where d.user_id = p_friend) then
    v_why := 'Your friend needs to use the app on their own phone';
  end if;
  if v_why is not null then update public.referrals set reason = v_why where id = r.id; return; end if;
  if exists (select 1 from public.device_accounts d join public.device_accounts o on o.device_hash = d.device_hash
             where d.user_id = p_friend and o.user_id = r.referrer) then
    update public.referrals set status = 'blocked', reason = 'Same phone as yours. Friends must use their own phone.' where id = r.id; return;
  end if;
  if not private.phone_ok(p_friend) then
    update public.referrals set status = 'blocked', reason = 'That phone already had another account' where id = r.id; return;
  end if;
  select count(*) into v_month from public.referrals x where x.referrer = r.referrer and x.status = 'counted'
    and x.counted_at >= (date_trunc('month', now() at time zone 'Africa/Lagos') at time zone 'Africa/Lagos');
  if v_month >= coalesce((s ->> 'monthly_cap')::int, 20) then
    update public.referrals set reason = 'Monthly limit reached. Counts next month.' where id = r.id; return;
  end if;
  update public.referrals set status = 'counted', counted_at = now(), reason = null where id = r.id;
  insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
  values ('account', 'A friend joined with your code',
          (select coalesce(split_part(p.full_name, ' ', 1), 'Your friend') from public.profiles p where p.id = p_friend)
            || ' counts now. You get ' || (s ->> 'pct_per_friend') || '% off Premium.',
          'user', r.referrer, 'scheduled', now(), 'referral', jsonb_build_object('type', 'screen', 'target', '/invite'));
  perform private.referral_milestones(r.referrer);
end;
$$;

-- When a friend finishes a test or pays: check their referral. When a payment succeeds: spend the friends it used.
create or replace function private.referral_on_attempt()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'submitted' then perform private.referral_check(new.user_id); end if;
  return null;
end;
$$;
create trigger referral_on_attempt after insert or update of status on public.attempts
  for each row when (new.status = 'submitted') execute function private.referral_on_attempt();

create or replace function private.referral_on_payment()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'success' and old.status is distinct from 'success' then
    if new.referral_friends > 0 then
      update public.referrals set spent_payment = new.id where id in (
        select id from public.referrals where referrer = new.user_id and status = 'counted' and spent_payment is null
        order by counted_at limit new.referral_friends);
    end if;
    perform private.referral_check(new.user_id);
  end if;
  return null;
end;
$$;
create trigger referral_on_payment after update of status on public.payments
  for each row execute function private.referral_on_payment();

-- Sign-up: the code from the form makes a pending referral.
create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_code text := upper(trim(coalesce(new.raw_user_meta_data ->> 'referral_code', ''))); v_ref uuid;
begin
  insert into public.profiles (id, full_name)
  values (new.id, nullif(left(new.raw_user_meta_data ->> 'full_name', 120), ''))
  on conflict (id) do nothing;
  if v_code <> '' then
    select id into v_ref from public.profiles where referral_code = v_code;
    if v_ref is not null and v_ref <> new.id then
      insert into public.referrals (referrer, friend, code) values (v_ref, new.id, v_code) on conflict (friend) do nothing;
    end if;
  end if;
  return new;
end;
$$;

-- ── Price: invited friends give a discount when no promo code is used (Paystack / website / direct APK) ─────────
create or replace function private.price(p_uid uuid, p_plan public.plans, p_code text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_chk jsonb; v_off integer := 0; v_label text; s jsonb := private.ref_settings(); v_pct integer := 0; v_friends integer := 0; v_per integer;
begin
  if coalesce(private.norm_code(p_code), '') <> '' then
    v_chk := private.check_code(p_uid, p_code, p_plan.id, 'checkout');
    if not (v_chk ->> 'ok')::boolean then return v_chk; end if;
    if v_chk ->> 'kind' = 'pct' then
      v_off := round(p_plan.price_kobo * (v_chk ->> 'value')::integer / 100.0);
      v_label := (v_chk ->> 'value') || '% off';
    else
      v_off := least((v_chk ->> 'value')::integer, p_plan.price_kobo);
      v_label := '₦' || to_char((v_chk ->> 'value')::integer / 100, 'FM999,999,990') || ' off';
    end if;
  elsif p_uid is not null and coalesce((s ->> 'enabled')::boolean, true) then
    v_per := greatest(coalesce((s ->> 'pct_per_friend')::int, 10), 1);
    v_pct := least(private.referral_unspent(p_uid) * v_per, least(coalesce((s ->> 'max_pct')::int, 100), 100));
    if v_pct > 0 then
      v_friends := ceil(v_pct::numeric / v_per)::int;
      v_off := round(p_plan.price_kobo * v_pct / 100.0);
      v_label := v_pct || '% off from ' || v_friends || case when v_friends = 1 then ' invited friend' else ' invited friends' end;
    end if;
  end if;
  if v_off > 0 and v_off < p_plan.price_kobo then v_off := least(v_off, greatest(p_plan.price_kobo - 10000, 0)); end if;
  return jsonb_build_object('ok', true, 'plan', p_plan.code, 'list_kobo', p_plan.price_kobo, 'discount_kobo', v_off,
    'amount_kobo', p_plan.price_kobo - v_off, 'code', v_chk ->> 'code', 'code_id', v_chk ->> 'id', 'label', v_label,
    'referral_friends', v_friends);
end;
$$;

create or replace function public.pay_start(p_uid uuid, p_plan text, p_code text, p_source text default 'app')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_plan public.plans; v_price jsonb; v_ref text; v_pay uuid; v_ent uuid; v_email text; v_end timestamptz;
begin
  if p_uid is null then return jsonb_build_object('ok', false, 'error', 'auth'); end if;
  if private.is_banned(p_uid) then return jsonb_build_object('ok', false, 'error', 'banned'); end if;
  if (select count(*) from public.pay_attempts a
      where a.user_id = p_uid and a.action = 'start' and a.created_at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  insert into public.pay_attempts (user_id, action, ok) values (p_uid, 'start', true);
  select * into v_plan from public.plans where code = p_plan;
  if v_plan.id is null or not private.plan_on_sale(v_plan) then return jsonb_build_object('ok', false, 'error', 'plan'); end if;
  select pp.expires_at into v_end from private.plan_period(p_uid, v_plan.id) pp;
  if v_end is null then return jsonb_build_object('ok', false, 'error', 'covered'); end if;
  if coalesce(private.norm_code(p_code), '') <> '' and private.too_many_code_tries(p_uid) then
    return jsonb_build_object('ok', false, 'error', 'too_many_tries');
  end if;
  v_price := private.price(p_uid, v_plan, p_code);
  if not (v_price ->> 'ok')::boolean then return v_price; end if;
  select u.email into v_email from auth.users u where u.id = p_uid;
  v_ref := 'st_' || encode(extensions.gen_random_bytes(10), 'hex');
  insert into public.payments (user_id, provider, plan_id, reference, list_kobo, discount_kobo, amount_kobo, code_id, source, referral_friends)
  values (p_uid, case when (v_price ->> 'amount_kobo')::integer = 0 then 'code' else 'paystack' end, v_plan.id, v_ref,
          (v_price ->> 'list_kobo')::integer, (v_price ->> 'discount_kobo')::integer, (v_price ->> 'amount_kobo')::integer,
          (v_price ->> 'code_id')::uuid, case when p_source = 'web' then 'web' else 'app' end,
          coalesce((v_price ->> 'referral_friends')::int, 0))
  returning id into v_pay;
  insert into public.payment_events (payment_id, provider, kind, ok, note, data)
  values (v_pay, 'server', 'started', true, 'Price worked out on the server',
          jsonb_build_object('amount_kobo', v_price -> 'amount_kobo', 'code', v_price -> 'code', 'referral_friends', v_price -> 'referral_friends'));
  if (v_price ->> 'amount_kobo')::integer = 0 then
    perform private.finish_payment(v_pay, case when coalesce((v_price ->> 'referral_friends')::int, 0) > 0 then 'referral' else 'code' end::public.entitlement_source);
    return jsonb_build_object('ok', true, 'payment_id', v_pay, 'reference', v_ref, 'amount_kobo', 0, 'free', true,
      'expires_at', (select max(e.expires_at) from public.entitlements e where e.user_id = p_uid and e.revoked_at is null));
  end if;
  return jsonb_build_object('ok', true, 'payment_id', v_pay, 'reference', v_ref, 'amount_kobo', v_price -> 'amount_kobo',
    'list_kobo', v_price -> 'list_kobo', 'discount_kobo', v_price -> 'discount_kobo', 'email', v_email, 'free', false);
end;
$$;

-- ── Student RPCs ────────────────────────────────────────────────────────────────────────────────────────────────
/** After sign-in: saves this phone (hashed Android ID). Says if another account owns the phone, and if banned. */
create or replace function public.device_register(p_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  if p_hash is not null and p_hash ~ '^[0-9a-f]{64}$' and not exists (select 1 from public.staff s where s.user_id = v_uid) then
    insert into public.device_accounts (device_hash, user_id) values (p_hash, v_uid)
    on conflict (device_hash, user_id) do update set last_seen = now();
    perform private.referral_check(v_uid);
  end if;
  return public.my_status();
end;
$$;

/** Banned (with reason and appeal) and "this phone already has an account". */
create or replace function public.my_status()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); p public.profiles; a record;
begin
  if v_uid is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into p from public.profiles where id = v_uid;
  select * into a from public.ban_appeals b where b.user_id = v_uid and b.banned_at = p.banned_at;
  return jsonb_build_object(
    'banned', p.banned_at is not null, 'ban_reason', p.ban_reason, 'banned_at', p.banned_at,
    'appeal', case when a.id is not null then jsonb_build_object('status', a.status, 'note', a.admin_note, 'created_at', a.created_at) end,
    'can_appeal', p.banned_at is not null and a.id is null and now() < p.banned_at + interval '14 days',
    'phone_taken', not private.phone_ok(v_uid) and not exists (select 1 from public.staff s where s.user_id = v_uid));
end;
$$;

/** Invite friends: my code, discount, cash progress, friends. */
create or replace function public.my_referrals()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); p public.profiles; s jsonb := private.ref_settings(); v_counted integer; v_unspent integer;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into p from public.profiles where id = v_uid for update;
  if p.referral_code is null then
    update public.profiles set referral_code = private.new_referral_code(p.full_name) where id = v_uid returning * into p;
  end if;
  select count(*) into v_counted from public.referrals where referrer = v_uid and status = 'counted';
  v_unspent := private.referral_unspent(v_uid);
  return jsonb_build_object(
    'enabled', coalesce((s ->> 'enabled')::boolean, true), 'code', p.referral_code,
    'pct_per_friend', (s ->> 'pct_per_friend')::int, 'max_pct', (s ->> 'max_pct')::int, 'count_on', s ->> 'count_on',
    'cash_every', (s ->> 'cash_every')::int, 'cash_naira', (s ->> 'cash_naira')::int, 'monthly_cap', (s ->> 'monthly_cap')::int,
    'counted', v_counted, 'unspent', v_unspent,
    'discount_pct', least(v_unspent * greatest((s ->> 'pct_per_friend')::int, 1), least((s ->> 'max_pct')::int, 100)),
    'friends', coalesce((select jsonb_agg(jsonb_build_object('name', coalesce(nullif(split_part(f.full_name, ' ', 1), ''), 'A friend'),
                 'status', r.status, 'reason', r.reason, 'joined', r.created_at, 'used', r.spent_payment is not null) order by r.created_at desc)
               from public.referrals r join public.profiles f on f.id = r.friend where r.referrer = v_uid), '[]'::jsonb),
    'rewards', coalesce((select jsonb_agg(jsonb_build_object('id', w.id, 'milestone', w.milestone, 'amount', w.amount, 'status', w.status,
                 'paid_at', w.paid_at) order by w.milestone) from public.referral_rewards w where w.user_id = v_uid), '[]'::jsonb),
    'my_referrer', (select coalesce(nullif(split_part(x.full_name, ' ', 1), ''), 'A friend') from public.referrals r join public.profiles x on x.id = r.referrer where r.friend = v_uid),
    'can_enter_code', not exists (select 1 from public.referrals r where r.friend = v_uid)
                      and (select u.created_at from auth.users u where u.id = v_uid) > now() - interval '7 days');
end;
$$;

/** Forgot the code at sign-up: enter it within 7 days. */
create or replace function public.referral_apply(p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_code text := upper(trim(coalesce(p_code, ''))); v_ref uuid;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if exists (select 1 from public.referrals where friend = v_uid) then raise exception 'You already used a referral code.' using errcode = 'P0001'; end if;
  if (select u.created_at from auth.users u where u.id = v_uid) < now() - interval '7 days' then
    raise exception 'Referral codes can only be added in your first 7 days.' using errcode = 'P0001';
  end if;
  select id into v_ref from public.profiles where referral_code = v_code;
  if v_ref is null then raise exception 'We could not find that code. Check it and try again.' using errcode = 'P0002'; end if;
  if v_ref = v_uid then raise exception 'You cannot use your own code.' using errcode = 'P0001'; end if;
  insert into public.referrals (referrer, friend, code) values (v_ref, v_uid, v_code);
  perform private.referral_check(v_uid);
  return jsonb_build_object('ok', true);
end;
$$;

/** A cash reward: the student sends their bank details (never PIN, card or password). */
create or replace function public.referral_claim(p_reward uuid, p_bank text, p_account_number text, p_account_name text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if char_length(trim(coalesce(p_bank, ''))) < 2 or coalesce(p_account_number, '') !~ '^[0-9]{10}$' or char_length(trim(coalesce(p_account_name, ''))) < 3 then
    raise exception 'Check the bank, the 10-digit account number and the account name.' using errcode = '22023';
  end if;
  update public.referral_rewards set status = 'claimed', claimed_at = now(), bank_name = left(trim(p_bank), 80),
    account_number = p_account_number, account_name = left(trim(p_account_name), 120)
  where id = p_reward and user_id = v_uid and status = 'due';
  if not found then raise exception 'This reward cannot be claimed.' using errcode = 'P0001'; end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- ── Bans ────────────────────────────────────────────────────────────────────────────────────────────────────────
create table if not exists public.ban_appeals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  banned_at timestamptz not null,
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  admin_note text,
  created_at timestamptz not null default now(), decided_at timestamptz, decided_by uuid,
  unique (user_id, banned_at)
);
alter table public.ban_appeals enable row level security;
create policy "own or staff" on public.ban_appeals for select using (user_id = (select auth.uid()) or private.is_staff());
revoke all on public.ban_appeals from anon;
revoke insert, update, delete on public.ban_appeals from authenticated;

/** One appeal per ban, within 14 days. */
create or replace function public.ban_appeal(p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); p public.profiles;
begin
  if v_uid is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into p from public.profiles where id = v_uid;
  if p.banned_at is null then raise exception 'Your account is not banned.' using errcode = 'P0001'; end if;
  if now() > p.banned_at + interval '14 days' then raise exception 'Appeals must be sent within 14 days of the ban.' using errcode = 'P0001'; end if;
  if char_length(trim(coalesce(p_reason, ''))) < 10 then raise exception 'Tell us what happened in a sentence or two.' using errcode = '22023'; end if;
  insert into public.ban_appeals (user_id, banned_at, reason) values (v_uid, p.banned_at, left(trim(p_reason), 2000))
  on conflict (user_id, banned_at) do nothing;
  if not found then raise exception 'You already sent an appeal for this ban.' using errcode = 'P0001'; end if;
  return jsonb_build_object('ok', true);
end;
$$;

/** Admin: ban or unban; with p_linked, also every other account on the same phones. Banning cancels unpaid rewards
    and prizes (prizes go to the next fair entry). Everything is logged. */
create or replace function public.admin_ban(p_user uuid, p_banned boolean, p_reason text default null, p_linked boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_ids uuid[]; v_id uuid; v_ch uuid;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  v_ids := array[p_user];
  if p_linked then
    v_ids := v_ids || coalesce((select array_agg(distinct o.user_id) from public.device_accounts d
              join public.device_accounts o on o.device_hash = d.device_hash and o.user_id <> p_user
              where d.user_id = p_user and not exists (select 1 from public.staff s where s.user_id = o.user_id)), '{}');
  end if;
  foreach v_id in array v_ids loop
    perform public.admin_set_ban(v_id, p_banned, p_reason);
    if p_banned then
      update public.referral_rewards set status = 'cancelled', admin_note = 'Account banned' where user_id = v_id and status in ('due', 'claimed');
      update public.referrals set status = 'blocked', reason = 'Account banned' where friend = v_id and status = 'pending';
      for v_ch in select distinct e.challenge_id from public.challenge_entries e
                  where e.user_id = v_id and e.prize is not null
                    and not exists (select 1 from public.prize_claims pc where pc.entry_id = e.id and pc.status = 'paid') loop
        update public.prize_claims set status = 'rejected', admin_note = 'Account banned'
        where entry_id in (select id from public.challenge_entries where challenge_id = v_ch and user_id = v_id) and status <> 'paid';
        update public.challenge_entries set review = 'dq', prize = null, rank = null where challenge_id = v_ch and user_id = v_id;
        perform private.challenge_rank(v_ch);
      end loop;
    end if;
    insert into public.audit_log (actor, action, table_name, row_id, after)
    values ((select auth.uid()), case when p_banned then 'user.ban' else 'user.unban' end, 'profiles', v_id::text,
            jsonb_build_object('reason', p_reason, 'linked_to', case when v_id <> p_user then p_user end));
  end loop;
  return jsonb_build_object('ok', true, 'accounts', cardinality(v_ids));
end;
$$;

create or replace function public.admin_ban_appeal(p_appeal uuid, p_accept boolean, p_note text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare a public.ban_appeals;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  update public.ban_appeals set status = case when p_accept then 'accepted' else 'rejected' end, admin_note = left(p_note, 500),
    decided_at = now(), decided_by = (select auth.uid())
  where id = p_appeal and status = 'pending' returning * into a;
  if a.id is null then raise exception 'This appeal was already decided.' using errcode = 'P0001'; end if;
  if p_accept then perform public.admin_ban(a.user_id, false); end if;
  insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source)
  values ('account', case when p_accept then 'Your account is open again' else 'Your appeal was not accepted' end,
          coalesce(nullif(trim(p_note), ''), case when p_accept then 'Thanks for explaining. Welcome back.' else 'The ban stays.' end),
          'user', a.user_id, 'scheduled', now(), 'ban');
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), 'user.ban_appeal', 'ban_appeals', a.id::text, jsonb_build_object('accepted', p_accept, 'note', p_note));
end;
$$;

-- ── Admin RPCs ──────────────────────────────────────────────────────────────────────────────────────────────────
create or replace function public.admin_referrals()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  return jsonb_build_object(
    'settings', private.ref_settings(),
    'totals', (select jsonb_build_object('pending', count(*) filter (where status = 'pending'), 'counted', count(*) filter (where status = 'counted'),
                 'blocked', count(*) filter (where status = 'blocked'), 'this_month', count(*) filter (where status = 'counted'
                 and counted_at >= (date_trunc('month', now() at time zone 'Africa/Lagos') at time zone 'Africa/Lagos'))) from public.referrals),
    'rewards', coalesce((select jsonb_agg(jsonb_build_object('id', w.id, 'name', p.full_name, 'user_id', w.user_id, 'milestone', w.milestone,
                 'amount', w.amount, 'status', w.status, 'bank', w.bank_name, 'account_number', w.account_number, 'account_name', w.account_name,
                 'created_at', w.created_at, 'claimed_at', w.claimed_at, 'paid_at', w.paid_at, 'phone_ok', private.phone_ok(w.user_id))
                 order by case w.status when 'claimed' then 0 when 'due' then 1 else 2 end, w.created_at desc)
               from public.referral_rewards w join public.profiles p on p.id = w.user_id), '[]'::jsonb),
    'top', coalesce((select jsonb_agg(t order by t.counted desc) from (
               select p.full_name as name, r.referrer as user_id, p.referral_code as code, count(*) filter (where r.status = 'counted') as counted,
                      count(*) filter (where r.status = 'pending') as pending, count(*) filter (where r.status = 'blocked') as blocked
               from public.referrals r join public.profiles p on p.id = r.referrer group by p.full_name, r.referrer, p.referral_code
               order by 4 desc limit 30) t), '[]'::jsonb),
    'recent', coalesce((select jsonb_agg(t) from (
               select r.created_at, r.status, r.reason, rf.full_name as referrer, fr.full_name as friend, r.code
               from public.referrals r join public.profiles rf on rf.id = r.referrer join public.profiles fr on fr.id = r.friend
               order by r.created_at desc limit 50) t), '[]'::jsonb));
end;
$$;

create or replace function public.admin_referral_settings(p jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare v jsonb;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  v := jsonb_build_object(
    'enabled', coalesce((p ->> 'enabled')::boolean, true),
    'pct_per_friend', least(greatest(coalesce((p ->> 'pct_per_friend')::int, 10), 1), 100),
    'max_pct', least(greatest(coalesce((p ->> 'max_pct')::int, 100), 0), 100),
    'count_on', case when p ->> 'count_on' = 'premium' then 'premium' else 'test' end,
    'cash_every', least(greatest(coalesce((p ->> 'cash_every')::int, 30), 0), 1000),
    'cash_naira', least(greatest(coalesce((p ->> 'cash_naira')::int, 5000), 0), 1000000),
    'monthly_cap', least(greatest(coalesce((p ->> 'monthly_cap')::int, 20), 1), 1000));
  insert into public.app_settings (key, value, description, is_public, updated_by) values ('referrals', v, 'Referral rewards (Admin → Referrals)', false, (select auth.uid()))
  on conflict (key) do update set value = excluded.value, updated_at = now(), updated_by = excluded.updated_by;
  insert into public.audit_log (actor, action, table_name, row_id, after) values ((select auth.uid()), 'referrals.settings', 'app_settings', 'referrals', v);
end;
$$;

create or replace function public.admin_referral_paid(p_reward uuid, p_note text default null, p_receipt text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare w public.referral_rewards;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  update public.referral_rewards set status = 'paid', paid_at = now(), paid_by = (select auth.uid()), admin_note = left(p_note, 500),
    receipt_path = case when p_receipt ~ '^public/winners/[A-Za-z0-9._/-]+$' then p_receipt end
  where id = p_reward and status = 'claimed' returning * into w;
  if w.id is null then raise exception 'Only claimed rewards (with bank details) can be marked paid.' using errcode = 'P0001'; end if;
  insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
  values ('account', 'Your referral reward was paid', '₦' || to_char(w.amount, 'FM999,999,990') || ' was sent to your bank account.',
          'user', w.user_id, 'scheduled', now(), 'referral', jsonb_build_object('type', 'screen', 'target', '/invite'));
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), 'referral.paid', 'referral_rewards', w.id::text, jsonb_build_object('amount', w.amount, 'note', p_note));
end;
$$;

/** Fraud & bans: phones with more than one account, banned students, ban appeals. */
create or replace function public.admin_fraud()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  return jsonb_build_object(
    'shared_phones', coalesce((select jsonb_agg(jsonb_build_object('device', left(g.device_hash, 10), 'hash', g.device_hash, 'accounts', g.accounts) order by g.last desc)
       from (select d.device_hash, max(d.last_seen) as last,
                    jsonb_agg(jsonb_build_object('user_id', d.user_id, 'name', p.full_name, 'email', u.email, 'first_seen', d.first_seen,
                      'banned', p.banned_at is not null, 'allowed', d.allowed) order by d.first_seen) as accounts
             from public.device_accounts d join public.profiles p on p.id = d.user_id join auth.users u on u.id = d.user_id
             group by d.device_hash having count(*) > 1 limit 200) g), '[]'::jsonb),
    'banned', coalesce((select jsonb_agg(jsonb_build_object('user_id', p.id, 'name', p.full_name, 'email', u.email, 'reason', p.ban_reason,
         'banned_at', p.banned_at) order by p.banned_at desc) from public.profiles p join auth.users u on u.id = p.id where p.banned_at is not null), '[]'::jsonb),
    'appeals', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'user_id', a.user_id, 'name', p.full_name, 'reason', a.reason,
         'ban_reason', p.ban_reason, 'status', a.status, 'note', a.admin_note, 'created_at', a.created_at) order by (a.status = 'pending') desc, a.created_at desc)
       from public.ban_appeals a join public.profiles p on p.id = a.user_id), '[]'::jsonb));
end;
$$;

/** Allow a second account on a shared phone (for example brothers and sisters). */
create or replace function public.admin_device_allow(p_hash text, p_user uuid, p_allowed boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  update public.device_accounts set allowed = coalesce(p_allowed, false) where device_hash = p_hash and user_id = p_user;
  if not found then raise exception 'Unknown phone or account' using errcode = 'P0002'; end if;
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), 'device.allow', 'device_accounts', left(p_hash, 10), jsonb_build_object('user', p_user, 'allowed', p_allowed));
  perform private.referral_check(p_user);
end;
$$;

-- Pending friends waiting for next month: check again every day at 01:07 Lagos.
create or replace function private.referrals_daily()
returns void language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in select friend from public.referrals where status = 'pending' and created_at > now() - interval '120 days' loop
    perform private.referral_check(r.friend);
  end loop;
end;
$$;
select cron.schedule('referrals-daily', '7 0 * * *', $$select private.referrals_daily()$$);

revoke execute on function private.ref_settings(), private.new_referral_code(text), private.phone_ok(uuid), private.referral_unspent(uuid),
  private.referral_milestones(uuid), private.referral_check(uuid), private.referrals_daily() from public, anon, authenticated;
revoke execute on function public.device_register(text), public.my_status(), public.my_referrals(), public.referral_apply(text),
  public.referral_claim(uuid, text, text, text), public.ban_appeal(text), public.admin_ban(uuid, boolean, text, boolean),
  public.admin_ban_appeal(uuid, boolean, text), public.admin_referrals(), public.admin_referral_settings(jsonb),
  public.admin_referral_paid(uuid, text, text), public.admin_fraud(), public.admin_device_allow(text, uuid, boolean) from public, anon;
grant execute on function public.device_register(text), public.my_status(), public.my_referrals(), public.referral_apply(text),
  public.referral_claim(uuid, text, text, text), public.ban_appeal(text), public.admin_ban(uuid, boolean, text, boolean),
  public.admin_ban_appeal(uuid, boolean, text), public.admin_referrals(), public.admin_referral_settings(jsonb),
  public.admin_referral_paid(uuid, text, text), public.admin_fraud(), public.admin_device_allow(text, uuid, boolean) to authenticated;
