-- Milestone 4C: payments (Paystack + Google Play), redeem codes (docs/plans/phase-4c.md, D-061).
-- Premium is only ever granted by server code after the payment was checked with Paystack or Google.
-- Students read their own payments; they never write payments, codes or entitlements.

create type public.payment_status as enum ('pending', 'success', 'failed', 'abandoned', 'needs_review', 'refunded');
create type public.promo_kind as enum ('pct', 'amt', 'days');

-- ------------------------------------------------------------------ tables
create table public.promo_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z0-9-]{4,24}$'),
  kind public.promo_kind not null,
  -- pct: 1–100 (% off) · amt: kobo off · days: free Premium days
  value integer not null check (value > 0),
  plan_ids smallint[] not null default '{}',          -- discount codes: plans it works on; empty = all plans
  max_uses integer check (max_uses > 0),               -- null = no limit
  used_count integer not null default 0 check (used_count >= 0),
  new_only boolean not null default false,             -- only students who have never paid
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  paused boolean not null default false,
  note text check (char_length(note) <= 200),
  batch_id uuid,
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (kind <> 'pct' or value <= 100),
  check (kind <> 'days' or value <= 366),
  check (ends_at is null or ends_at > starts_at)
);
create index promo_codes_batch on public.promo_codes (batch_id) where batch_id is not null;

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  -- Kept for the accounts when a student deletes their account (no email or name is stored here).
  user_id uuid references auth.users (id) on delete set null,
  provider text not null check (provider in ('paystack', 'play', 'code')),
  plan_id smallint not null references public.plans (id),
  reference text not null unique,
  purchase_token text unique,
  list_kobo integer not null check (list_kobo >= 0),
  discount_kobo integer not null default 0 check (discount_kobo >= 0),
  amount_kobo integer not null check (amount_kobo >= 0),
  currency text not null default 'NGN',
  code_id uuid references public.promo_codes (id) on delete set null,
  status public.payment_status not null default 'pending',
  channel text,
  source text not null default 'app' check (source in ('app', 'web')),
  entitlement_id uuid references public.entitlements (id) on delete set null,
  provider_data jsonb not null default '{}',
  verified_at timestamptz,
  refunded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (amount_kobo = list_kobo - discount_kobo)
);
create index payments_user on public.payments (user_id, created_at desc);
create index payments_status on public.payments (status, created_at desc);
create index payments_plan on public.payments (plan_id);
create index payments_code on public.payments (code_id) where code_id is not null;
create index payments_entitlement on public.payments (entitlement_id) where entitlement_id is not null;

-- Every webhook, verify call, Google answer and refund, in order (the admin timeline).
-- event_key makes repeats harmless: the same webhook body twice is stored and acted on once.
create table public.payment_events (
  id bigint generated always as identity primary key,
  payment_id uuid references public.payments (id) on delete cascade,
  provider text not null,
  kind text not null,
  event_key text unique,
  ok boolean not null,
  note text,
  data jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index payment_events_payment on public.payment_events (payment_id, id);

create table public.promo_redemptions (
  id uuid primary key default gen_random_uuid(),
  code_id uuid not null references public.promo_codes (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  payment_id uuid references public.payments (id) on delete set null,
  discount_kobo integer,
  days integer,
  entitlement_id uuid references public.entitlements (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (code_id, user_id)
);
create index promo_redemptions_user on public.promo_redemptions (user_id);
create index promo_redemptions_payment on public.promo_redemptions (payment_id) where payment_id is not null;
create index promo_redemptions_entitlement on public.promo_redemptions (entitlement_id) where entitlement_id is not null;

-- Wrong code tries and payment starts, for rate limits.
create table public.pay_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  action text not null check (action in ('code', 'start')),
  ok boolean not null,
  created_at timestamptz not null default now()
);
create index pay_attempts_user on public.pay_attempts (user_id, action, created_at desc);

create or replace function private.promo_code_norm() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.code := private.norm_code(new.code);
  return new;
end;
$$;
create trigger promo_codes_norm before insert on public.promo_codes for each row execute function private.promo_code_norm();
create trigger promo_codes_touch before update on public.promo_codes for each row execute function private.touch_updated_at();
create trigger payments_touch before update on public.payments for each row execute function private.touch_updated_at();
create trigger promo_codes_audit after insert or update or delete on public.promo_codes for each row execute function private.audit_row();

-- ------------------------------------------------------------------ RLS
alter table public.promo_codes enable row level security;
alter table public.payments enable row level security;
alter table public.payment_events enable row level security;
alter table public.promo_redemptions enable row level security;
alter table public.pay_attempts enable row level security;

create policy "money staff read" on public.promo_codes for select to authenticated
  using (private.is_staff(array['super_admin', 'admin']::public.staff_role[]));
create policy "admins edit (insert)" on public.promo_codes for insert to authenticated
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]) and used_count = 0);
create policy "admins edit (update)" on public.promo_codes for update to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));
create policy "admins edit (delete)" on public.promo_codes for delete to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]) and used_count = 0);
-- Admins may change a code's limits and dates, never its use count or its code text.
revoke update on public.promo_codes from authenticated;
grant update (max_uses, new_only, starts_at, ends_at, paused, note, plan_ids) on public.promo_codes to authenticated;

create policy "own or money staff read" on public.payments for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff(array['super_admin', 'admin']::public.staff_role[]));
create policy "money staff read" on public.payment_events for select to authenticated
  using (private.is_staff(array['super_admin', 'admin']::public.staff_role[]));
create policy "own or money staff read" on public.promo_redemptions for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff(array['super_admin', 'admin']::public.staff_role[]));
-- pay_attempts: no policies (server functions only).

revoke insert, update, delete, truncate on public.payments, public.payment_events, public.promo_redemptions,
  public.pay_attempts from anon, authenticated;
revoke all on public.payments, public.payment_events, public.promo_codes, public.promo_redemptions,
  public.pay_attempts from anon;
-- Students see only safe columns of their own payments.
revoke select on public.payments from authenticated;
grant select (id, user_id, provider, plan_id, reference, list_kobo, discount_kobo, amount_kobo, currency, status,
  channel, source, verified_at, refunded_at, created_at) on public.payments to authenticated;

-- ------------------------------------------------------------------ helpers
create or replace function private.lagos_today() returns date
language sql stable set search_path = '' as $$ select (now() at time zone 'Africa/Lagos')::date $$;

create or replace function private.norm_code(p text) returns text
language sql immutable set search_path = '' as $$ select upper(regexp_replace(coalesce(p, ''), '\s+', '', 'g')) $$;

/** When the student's current Premium ends (now() if none). */
create or replace function private.premium_end(p_uid uuid) returns timestamptz
language sql stable security definer set search_path = '' as $$
  select greatest(now(), coalesce(max(e.expires_at), now()))
  from public.entitlements e where e.user_id = p_uid and e.revoked_at is null and e.expires_at > now();
$$;

/** Start and end of the Premium a plan (or a number of days) would give now. Null end = nothing to give. */
create or replace function private.plan_period(p_uid uuid, p_plan smallint, p_days integer default null,
  out starts_at timestamptz, out expires_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare v_plan public.plans;
begin
  starts_at := private.premium_end(p_uid);
  if p_days is not null then
    expires_at := starts_at + make_interval(days => p_days);
    return;
  end if;
  select * into v_plan from public.plans where id = p_plan;
  if v_plan.duration_days is not null then
    expires_at := starts_at + make_interval(days => v_plan.duration_days);
  else
    -- Fixed end date (Exam Season): to the end of that day in Lagos.
    expires_at := ((v_plan.ends_on + 1)::timestamp at time zone 'Africa/Lagos');
    if expires_at <= starts_at then expires_at := null; end if;
  end if;
end;
$$;

/** Adds Premium after any Premium already running. Idempotent on p_ref (entitlements.external_ref). */
create or replace function private.grant_plan(p_uid uuid, p_plan smallint, p_source public.entitlement_source,
  p_ref text, p_days integer default null, p_reason text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_start timestamptz; v_end timestamptz;
begin
  select e.id into v_id from public.entitlements e where e.external_ref = p_ref;
  if v_id is not null then return v_id; end if;
  -- One grant at a time per student, so two payments never stack on the same start.
  perform pg_advisory_xact_lock(hashtextextended('grant:' || p_uid::text, 0));
  select pp.starts_at, pp.expires_at into v_start, v_end from private.plan_period(p_uid, p_plan, p_days) pp;
  if v_end is null then
    -- Premium already runs past this plan's fixed end date: record it as a zero-length extension is not allowed,
    -- so give it from now (overlapping); the student keeps what they had.
    v_start := now();
    select ((pl.ends_on + 1)::timestamp at time zone 'Africa/Lagos') into v_end from public.plans pl where pl.id = p_plan;
    if v_end <= v_start then raise exception 'plan has ended' using errcode = 'P0001'; end if;
  end if;
  insert into public.entitlements (user_id, plan_id, source, starts_at, expires_at, external_ref, granted_by, reason)
  values (p_uid, p_plan, p_source, v_start, v_end, p_ref, null, p_reason)
  on conflict (external_ref) do nothing
  returning id into v_id;
  if v_id is null then select e.id into v_id from public.entitlements e where e.external_ref = p_ref; end if;
  return v_id;
end;
$$;

/** Is the plan on sale today? */
create or replace function private.plan_on_sale(p public.plans) returns boolean
language sql stable set search_path = '' as $$
  select p.is_active and (p.ends_on is null or p.ends_on >= private.lagos_today());
$$;

create or replace function private.too_many_code_tries(p_uid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select count(*) from public.pay_attempts a
          where a.user_id = p_uid and a.action = 'code' and not a.ok and a.created_at > now() - interval '1 hour') >= 10;
$$;

/**
 * Checks a code for a student (and a plan, for discount codes). Never raises.
 * Returns {ok, id, kind, value, label} or {ok:false, error}.
 * error: not_found · paused · not_started · expired · used_up · already_used · new_only · wrong_plan ·
 *        days_code (a free-days code typed at checkout) · discount_code (a discount code typed in Redeem)
 */
create or replace function private.check_code(p_uid uuid, p_code text, p_plan smallint, p_for text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare c public.promo_codes; v_pending integer;
begin
  select * into c from public.promo_codes where code = private.norm_code(p_code);
  if c.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if c.paused then return jsonb_build_object('ok', false, 'error', 'paused'); end if;
  if c.starts_at > now() then return jsonb_build_object('ok', false, 'error', 'not_started'); end if;
  if c.ends_at is not null and c.ends_at <= now() then return jsonb_build_object('ok', false, 'error', 'expired'); end if;
  if p_for = 'checkout' and c.kind = 'days' then return jsonb_build_object('ok', false, 'error', 'days_code'); end if;
  if p_for = 'redeem' and c.kind <> 'days' then return jsonb_build_object('ok', false, 'error', 'discount_code'); end if;
  if exists (select 1 from public.promo_redemptions r where r.code_id = c.id and r.user_id = p_uid) then
    return jsonb_build_object('ok', false, 'error', 'already_used');
  end if;
  if c.max_uses is not null then
    -- Unpaid checkouts from the last 30 minutes hold a use, so a limited code is not oversold.
    select count(*) into v_pending from public.payments p
    where p.code_id = c.id and p.status = 'pending' and p.created_at > now() - interval '30 minutes' and p.user_id <> p_uid;
    if c.used_count + v_pending >= c.max_uses then return jsonb_build_object('ok', false, 'error', 'used_up'); end if;
  end if;
  if c.new_only and exists (select 1 from public.payments p where p.user_id = p_uid and p.status in ('success', 'refunded')) then
    return jsonb_build_object('ok', false, 'error', 'new_only');
  end if;
  if c.kind <> 'days' and cardinality(c.plan_ids) > 0 and not (p_plan = any (c.plan_ids)) then
    return jsonb_build_object('ok', false, 'error', 'wrong_plan',
      'plans', (select jsonb_agg(pl.name order by pl.sort) from public.plans pl where pl.id = any (c.plan_ids)));
  end if;
  return jsonb_build_object('ok', true, 'id', c.id, 'kind', c.kind, 'value', c.value, 'code', c.code);
end;
$$;

/** Server price for a plan and an optional code. Discounts never leave a charge between ₦0 and ₦100. */
create or replace function private.price(p_uid uuid, p_plan public.plans, p_code text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_chk jsonb; v_off integer := 0; v_label text;
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
    if v_off < p_plan.price_kobo then v_off := least(v_off, greatest(p_plan.price_kobo - 10000, 0)); end if;
  end if;
  return jsonb_build_object('ok', true, 'plan', p_plan.code, 'list_kobo', p_plan.price_kobo, 'discount_kobo', v_off,
    'amount_kobo', p_plan.price_kobo - v_off, 'code', v_chk ->> 'code', 'code_id', v_chk ->> 'id', 'label', v_label);
end;
$$;

-- ------------------------------------------------------------------ student functions
/**
 * The price the server will charge: {ok, plan, list_kobo, discount_kobo, amount_kobo, code, label, period_end}
 * or {ok:false, error}. Wrong codes count towards a limit of 10 an hour.
 */
create or replace function public.quote_price(p_plan text, p_code text default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_plan public.plans; v_res jsonb; v_end timestamptz;
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  if private.is_banned(v_uid) then return jsonb_build_object('ok', false, 'error', 'banned'); end if;
  select * into v_plan from public.plans where code = p_plan;
  if v_plan.id is null or not private.plan_on_sale(v_plan) then return jsonb_build_object('ok', false, 'error', 'plan'); end if;
  if coalesce(private.norm_code(p_code), '') <> '' then
    if private.too_many_code_tries(v_uid) then return jsonb_build_object('ok', false, 'error', 'too_many_tries'); end if;
  end if;
  v_res := private.price(v_uid, v_plan, p_code);
  if coalesce(private.norm_code(p_code), '') <> '' then
    insert into public.pay_attempts (user_id, action, ok) values (v_uid, 'code', (v_res ->> 'ok')::boolean);
  end if;
  if not (v_res ->> 'ok')::boolean then return v_res; end if;
  select pp.expires_at into v_end from private.plan_period(v_uid, v_plan.id) pp;
  if v_end is null then return jsonb_build_object('ok', false, 'error', 'covered'); end if;
  return (v_res - 'code_id') || jsonb_build_object('period_end', v_end);
end;
$$;
revoke all on function public.quote_price(text, text) from public, anon;
grant execute on function public.quote_price(text, text) to authenticated;

/** Redeems a free-Premium-days code: {ok, days, expires_at} or {ok:false, error}. */
create or replace function public.redeem_code(p_code text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_chk jsonb; v_id uuid; v_days integer; v_ent uuid;
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  if private.is_banned(v_uid) then return jsonb_build_object('ok', false, 'error', 'banned'); end if;
  if private.too_many_code_tries(v_uid) then return jsonb_build_object('ok', false, 'error', 'too_many_tries'); end if;
  v_chk := private.check_code(v_uid, p_code, null, 'redeem');
  if not (v_chk ->> 'ok')::boolean then
    insert into public.pay_attempts (user_id, action, ok) values (v_uid, 'code', false);
    return v_chk;
  end if;
  v_id := (v_chk ->> 'id')::uuid;
  v_days := (v_chk ->> 'value')::integer;
  -- Take one use atomically; a code with no uses left is refused even under a race.
  update public.promo_codes c set used_count = c.used_count + 1
  where c.id = v_id and (c.max_uses is null or c.used_count < c.max_uses);
  if not found then return jsonb_build_object('ok', false, 'error', 'used_up'); end if;
  begin
    insert into public.promo_redemptions (code_id, user_id, days) values (v_id, v_uid, v_days);
  exception when unique_violation then
    raise exception 'already used' using errcode = 'P0001';  -- rolls back the use taken above
  end;
  v_ent := private.grant_plan(v_uid, null, 'code', 'code:' || v_id || ':' || v_uid, v_days, 'Code ' || (v_chk ->> 'code'));
  update public.promo_redemptions set entitlement_id = v_ent where code_id = v_id and user_id = v_uid;
  insert into public.pay_attempts (user_id, action, ok) values (v_uid, 'code', true);
  return jsonb_build_object('ok', true, 'days', v_days,
    'expires_at', (select e.expires_at from public.entitlements e where e.id = v_ent));
exception when sqlstate 'P0001' then
  return jsonb_build_object('ok', false, 'error', 'already_used');
end;
$$;
revoke all on function public.redeem_code(text) from public, anon;
grant execute on function public.redeem_code(text) to authenticated;

-- ------------------------------------------------------------------ server functions (Edge Functions only)
/**
 * Starts a payment. Works out the price on the server and saves a pending payment.
 * Returns {ok, payment_id, reference, amount_kobo, list_kobo, discount_kobo, email, free}
 * or {ok:false, error}. A 100% code gives Premium at once (free = true, no Paystack).
 */
create or replace function public.pay_start(p_uid uuid, p_plan text, p_code text, p_source text default 'app')
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
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
  insert into public.payments (user_id, provider, plan_id, reference, list_kobo, discount_kobo, amount_kobo, code_id, source)
  values (p_uid, case when (v_price ->> 'amount_kobo')::integer = 0 then 'code' else 'paystack' end, v_plan.id, v_ref,
          (v_price ->> 'list_kobo')::integer, (v_price ->> 'discount_kobo')::integer, (v_price ->> 'amount_kobo')::integer,
          (v_price ->> 'code_id')::uuid, case when p_source = 'web' then 'web' else 'app' end)
  returning id into v_pay;
  insert into public.payment_events (payment_id, provider, kind, ok, note, data)
  values (v_pay, 'server', 'started', true, 'Price worked out on the server',
          jsonb_build_object('amount_kobo', v_price -> 'amount_kobo', 'code', v_price -> 'code'));
  if (v_price ->> 'amount_kobo')::integer = 0 then
    perform private.finish_payment(v_pay, 'code');
    return jsonb_build_object('ok', true, 'payment_id', v_pay, 'reference', v_ref, 'amount_kobo', 0, 'free', true,
      'expires_at', (select max(e.expires_at) from public.entitlements e where e.user_id = p_uid and e.revoked_at is null));
  end if;
  return jsonb_build_object('ok', true, 'payment_id', v_pay, 'reference', v_ref, 'amount_kobo', v_price -> 'amount_kobo',
    'list_kobo', v_price -> 'list_kobo', 'discount_kobo', v_price -> 'discount_kobo', 'email', v_email, 'free', false);
end;
$$;

/** Marks a locked pending payment as paid: grants Premium, uses the code. Called only from the functions below. */
create or replace function private.finish_payment(p_pay uuid, p_source public.entitlement_source)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare p public.payments; v_ent uuid; v_plan_name text;
begin
  select * into p from public.payments where id = p_pay;
  select pl.name into v_plan_name from public.plans pl where pl.id = p.plan_id;
  v_ent := private.grant_plan(p.user_id, p.plan_id, p_source, 'pay:' || p.id, null,
                              v_plan_name || ' · ' || p.provider || ' ' || p.reference);
  update public.payments set status = 'success', verified_at = coalesce(verified_at, now()), entitlement_id = v_ent where id = p.id;
  if p.code_id is not null then
    insert into public.promo_redemptions (code_id, user_id, payment_id, discount_kobo, entitlement_id)
    values (p.code_id, p.user_id, p.id, p.discount_kobo, v_ent)
    on conflict (code_id, user_id) do nothing;
    if found then update public.promo_codes set used_count = used_count + 1 where id = p.code_id; end if;
  end if;
  insert into public.payment_events (payment_id, provider, kind, ok, note)
  values (p.id, 'server', 'premium_given', true, 'Premium given until ' ||
          to_char((select e.expires_at from public.entitlements e where e.id = v_ent) at time zone 'Africa/Lagos', 'DD Mon YYYY HH24:MI'));
  return v_ent;
end;
$$;

/**
 * Applies what Paystack's verify endpoint said about a reference. Idempotent and safe to call from both the webhook
 * and the app's check at the same time (the payment row is locked).
 * p_kind: 'webhook' or 'verify' or 'admin_check'. p_event_key: unique per webhook body (null for verify calls).
 * Returns {ok, status, user_id, duplicate?}.
 */
create or replace function public.pay_paystack_result(p_reference text, p_status text, p_amount_kobo integer,
  p_currency text, p_channel text, p_data jsonb, p_kind text, p_event_key text default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare p public.payments;
begin
  select * into p from public.payments where reference = p_reference and provider = 'paystack' for update;
  if p.id is null then
    insert into public.payment_events (provider, kind, event_key, ok, note, data)
    values ('paystack', p_kind, p_event_key, false, 'Unknown reference ' || left(p_reference, 60), coalesce(p_data, '{}'))
    on conflict (event_key) do nothing;
    return jsonb_build_object('ok', false, 'error', 'unknown_reference');
  end if;
  if p_event_key is not null then
    insert into public.payment_events (payment_id, provider, kind, event_key, ok, note, data)
    values (p.id, 'paystack', p_kind, p_event_key, true, 'Paystack says: ' || coalesce(p_status, '?'), coalesce(p_data, '{}'))
    on conflict (event_key) do nothing;
    if not found then
      return jsonb_build_object('ok', true, 'status', p.status, 'user_id', p.user_id, 'duplicate', true);
    end if;
  else
    insert into public.payment_events (payment_id, provider, kind, ok, note, data)
    values (p.id, 'paystack', p_kind, true, 'Paystack says: ' || coalesce(p_status, '?'), coalesce(p_data, '{}'));
  end if;
  if p.status in ('success', 'refunded', 'needs_review') then
    return jsonb_build_object('ok', true, 'status', p.status, 'user_id', p.user_id);
  end if;
  update public.payments set channel = coalesce(p_channel, channel),
    provider_data = coalesce(p_data, '{}') where id = p.id;
  if p_status = 'success' then
    if p_amount_kobo is distinct from p.amount_kobo or upper(coalesce(p_currency, '')) <> p.currency then
      update public.payments set status = 'needs_review' where id = p.id;
      insert into public.payment_events (payment_id, provider, kind, ok, note)
      values (p.id, 'server', 'amount_mismatch', false,
              format('Paid %s %s, expected %s %s. Premium not given; check in Paystack.', p_amount_kobo, p_currency, p.amount_kobo, p.currency));
      return jsonb_build_object('ok', true, 'status', 'needs_review', 'user_id', p.user_id);
    end if;
    if p.user_id is null then
      update public.payments set status = 'needs_review' where id = p.id;
      return jsonb_build_object('ok', true, 'status', 'needs_review', 'user_id', null);
    end if;
    perform private.finish_payment(p.id, 'paystack');
    return jsonb_build_object('ok', true, 'status', 'success', 'user_id', p.user_id);
  elsif p_status = 'failed' then
    update public.payments set status = 'failed' where id = p.id;
    return jsonb_build_object('ok', true, 'status', 'failed', 'user_id', p.user_id);
  end if;
  -- 'abandoned', 'ongoing', 'pending', 'processing', 'queued': not paid yet, keep waiting.
  return jsonb_build_object('ok', true, 'status', 'pending', 'user_id', p.user_id);
end;
$$;

/**
 * A refund finished (Paystack refund.processed, Google voided purchase, or admin). A full refund removes the Premium
 * the payment gave; a part refund is only noted. Idempotent on p_event_key.
 */
create or replace function public.pay_refunded(p_provider text, p_reference text, p_token text, p_refund_kobo integer,
  p_data jsonb, p_event_key text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare p public.payments; v_full boolean;
begin
  select * into p from public.payments
  where (p_reference is not null and reference = p_reference) or (p_token is not null and purchase_token = p_token)
  for update;
  if p.id is null then
    insert into public.payment_events (provider, kind, event_key, ok, note, data)
    values (p_provider, 'refund', p_event_key, false, 'Refund for an unknown payment', coalesce(p_data, '{}'))
    on conflict (event_key) do nothing;
    return jsonb_build_object('ok', false, 'error', 'unknown_payment');
  end if;
  insert into public.payment_events (payment_id, provider, kind, event_key, ok, note, data)
  values (p.id, p_provider, 'refund', p_event_key, true,
          'Refund ' || coalesce(p_refund_kobo::text || ' kobo', 'in full'), coalesce(p_data, '{}'))
  on conflict (event_key) do nothing;
  if not found or p.status = 'refunded' then return jsonb_build_object('ok', true, 'status', p.status, 'duplicate', true); end if;
  v_full := p_refund_kobo is null or p_refund_kobo >= p.amount_kobo;
  if not v_full then return jsonb_build_object('ok', true, 'status', p.status, 'partial', true); end if;
  update public.payments set status = 'refunded', refunded_at = now() where id = p.id;
  update public.entitlements set revoked_at = now(), revoked_by = null
  where id = p.entitlement_id and revoked_at is null;
  insert into public.payment_events (payment_id, provider, kind, ok, note)
  values (p.id, 'server', 'premium_removed', true, 'Premium from this payment removed');
  return jsonb_build_object('ok', true, 'status', 'refunded', 'user_id', p.user_id);
end;
$$;

/**
 * A Google Play purchase that play-verify has already checked with Google (purchaseState = purchased,
 * account id matches this student). Idempotent on the purchase token; a token can belong to one student only.
 * Returns {ok, status, expires_at} or {ok:false, error: unknown_product | token_used | banned}.
 */
create or replace function public.pay_play_confirm(p_uid uuid, p_product text, p_token text, p_order_id text, p_data jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_plan public.plans; p public.payments; v_pay uuid;
begin
  if private.is_banned(p_uid) then return jsonb_build_object('ok', false, 'error', 'banned'); end if;
  select * into v_plan from public.plans where play_product_id = p_product;
  if v_plan.id is null then return jsonb_build_object('ok', false, 'error', 'unknown_product'); end if;
  perform pg_advisory_xact_lock(hashtextextended('play:' || p_token, 0));
  select * into p from public.payments where purchase_token = p_token for update;
  if p.id is not null then
    if p.user_id is distinct from p_uid then
      insert into public.payment_events (payment_id, provider, kind, ok, note)
      values (p.id, 'play', 'token_reuse', false, 'Another account sent this purchase token');
      return jsonb_build_object('ok', false, 'error', 'token_used');
    end if;
    return jsonb_build_object('ok', true, 'status', p.status, 'duplicate', true,
      'expires_at', (select e.expires_at from public.entitlements e where e.id = p.entitlement_id));
  end if;
  insert into public.payments (user_id, provider, plan_id, reference, purchase_token, list_kobo, amount_kobo, status, provider_data)
  values (p_uid, 'play', v_plan.id, coalesce(nullif(p_order_id, ''), 'play_' || encode(extensions.digest(p_token, 'sha256'), 'hex')),
          p_token, v_plan.price_kobo, v_plan.price_kobo, 'pending', coalesce(p_data, '{}'))
  returning id into v_pay;
  insert into public.payment_events (payment_id, provider, kind, ok, note, data)
  values (v_pay, 'play', 'verified', true, 'Google Play purchase checked with Google', coalesce(p_data, '{}'));
  perform private.finish_payment(v_pay, 'play');
  return jsonb_build_object('ok', true, 'status', 'success',
    'expires_at', (select e.expires_at from public.entitlements e join public.payments x on x.entitlement_id = e.id where x.id = v_pay));
end;
$$;

/** Notes a server step on a payment's timeline (Edge Functions: consume, refund requested, errors). */
create or replace function public.pay_note(p_reference text, p_provider text, p_kind text, p_ok boolean, p_note text, p_data jsonb default '{}')
returns void language sql volatile security definer set search_path = '' as $$
  insert into public.payment_events (payment_id, provider, kind, ok, note, data)
  values ((select id from public.payments where reference = p_reference or purchase_token = p_reference limit 1),
          p_provider, p_kind, p_ok, left(p_note, 500), coalesce(p_data, '{}'));
$$;

revoke all on function public.pay_start(uuid, text, text, text), public.pay_paystack_result(text, text, integer, text, text, jsonb, text, text),
  public.pay_refunded(text, text, text, integer, jsonb, text), public.pay_play_confirm(uuid, text, text, text, jsonb),
  public.pay_note(text, text, text, boolean, text, jsonb) from public, anon, authenticated;
grant execute on function public.pay_start(uuid, text, text, text), public.pay_paystack_result(text, text, integer, text, text, jsonb, text, text),
  public.pay_refunded(text, text, text, integer, jsonb, text), public.pay_play_confirm(uuid, text, text, text, jsonb),
  public.pay_note(text, text, text, boolean, text, jsonb) to service_role;
revoke all on function private.grant_plan(uuid, smallint, public.entitlement_source, text, integer, text),
  private.finish_payment(uuid, public.entitlement_source), private.check_code(uuid, text, smallint, text),
  private.price(uuid, public.plans, text), private.plan_period(uuid, smallint, integer),
  private.premium_end(uuid), private.too_many_code_tries(uuid) from public, anon, authenticated;

-- ------------------------------------------------------------------ admin
/** Is the caller an admin with 2-step login? (Edge Functions ask this before an admin refund.) */
create or replace function public.am_money_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select private.can_edit(array['super_admin', 'admin']::public.staff_role[]);
$$;
revoke all on function public.am_money_admin() from public, anon;
grant execute on function public.am_money_admin() to authenticated;

/** Payments list for the admin, with the student's email. */
create or replace function public.admin_payments(p_status text default null, p_provider text default null,
  p_q text default null, p_limit integer default 50, p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'rows', coalesce((
      select jsonb_agg(r order by r.created_at desc) from (
        select p.id, p.reference, p.provider, p.status, p.amount_kobo, p.list_kobo, p.discount_kobo, p.channel, p.source,
               p.created_at, p.verified_at, p.refunded_at, pl.name as plan, u.email, pc.code as promo
        from public.payments p
        join public.plans pl on pl.id = p.plan_id
        left join auth.users u on u.id = p.user_id
        left join public.promo_codes pc on pc.id = p.code_id
        where (p_status is null or p.status::text = p_status)
          and (p_provider is null or p.provider = p_provider)
          and (p_q is null or p.reference ilike '%' || p_q || '%' or u.email ilike '%' || p_q || '%')
        order by p.created_at desc
        limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0)) r), '[]'::jsonb),
    'totals', (select jsonb_build_object(
        'today_kobo', coalesce(sum(p.amount_kobo) filter (where p.status = 'success' and p.verified_at >= (private.lagos_today()::timestamp at time zone 'Africa/Lagos')), 0),
        'month_kobo', coalesce(sum(p.amount_kobo) filter (where p.status = 'success' and p.verified_at >= (date_trunc('month', private.lagos_today())::timestamp at time zone 'Africa/Lagos')), 0),
        'success', count(*) filter (where p.status = 'success'),
        'pending', count(*) filter (where p.status = 'pending' and p.created_at > now() - interval '1 day'),
        'review', count(*) filter (where p.status = 'needs_review'),
        'refunded_month_kobo', coalesce(sum(p.amount_kobo) filter (where p.status = 'refunded' and p.refunded_at >= (date_trunc('month', private.lagos_today())::timestamp at time zone 'Africa/Lagos')), 0))
      from public.payments p));
end;
$$;
revoke all on function public.admin_payments(text, text, text, integer, integer) from public, anon;
grant execute on function public.admin_payments(text, text, text, integer, integer) to authenticated;

/** One payment with its timeline. */
create or replace function public.admin_payment(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return (
    select jsonb_build_object(
      'payment', to_jsonb(p) - 'provider_data' - 'purchase_token' || jsonb_build_object('plan', pl.name, 'email', u.email, 'promo', pc.code,
        'premium_until', e.expires_at, 'premium_revoked', e.revoked_at),
      'events', coalesce((select jsonb_agg(jsonb_build_object('at', ev.created_at, 'provider', ev.provider, 'kind', ev.kind, 'ok', ev.ok, 'note', ev.note) order by ev.id)
                          from public.payment_events ev where ev.payment_id = p.id), '[]'::jsonb))
    from public.payments p
    join public.plans pl on pl.id = p.plan_id
    left join auth.users u on u.id = p.user_id
    left join public.promo_codes pc on pc.id = p.code_id
    left join public.entitlements e on e.id = p.entitlement_id
    where p.id = p_id);
end;
$$;
revoke all on function public.admin_payment(uuid) from public, anon;
grant execute on function public.admin_payment(uuid) to authenticated;

/** Creates a batch of unique one-use codes, e.g. STEE-7K3P-Q9XD. Letters that look alike (0/O, 1/I/L) are left out. */
create or replace function public.admin_create_code_batch(p_prefix text, p_count integer, p_kind public.promo_kind, p_value integer,
  p_plan_ids smallint[], p_starts timestamptz, p_ends timestamptz, p_note text, p_new_only boolean default false)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_alpha constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_batch uuid := gen_random_uuid();
  v_prefix text := private.norm_code(p_prefix);
  v_code text; v_bytes bytea; v_made integer := 0; v_tries integer := 0;
begin
  if not private.can_edit(array['super_admin', 'admin']::public.staff_role[]) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_count not between 1 and 1000 then raise exception 'count must be 1 to 1000' using errcode = '22023'; end if;
  if v_prefix !~ '^[A-Z0-9]{2,8}$' then raise exception 'prefix: 2 to 8 letters or numbers' using errcode = '22023'; end if;
  perform set_config('app.bulk_audit', 'on', true);
  while v_made < p_count loop
    v_tries := v_tries + 1;
    if v_tries > p_count * 3 then raise exception 'could not make enough unique codes' using errcode = 'P0001'; end if;
    v_bytes := extensions.gen_random_bytes(8);
    v_code := v_prefix || '-';
    for i in 0..7 loop
      v_code := v_code || substr(v_alpha, (get_byte(v_bytes, i) % 31) + 1, 1);
      if i = 3 then v_code := v_code || '-'; end if;
    end loop;
    insert into public.promo_codes (code, kind, value, plan_ids, max_uses, new_only, starts_at, ends_at, note, batch_id)
    values (v_code, p_kind, p_value, coalesce(p_plan_ids, '{}'), 1, coalesce(p_new_only, false),
            coalesce(p_starts, now()), p_ends, p_note, v_batch)
    on conflict (code) do nothing;
    if found then v_made := v_made + 1; end if;
  end loop;
  perform set_config('app.bulk_audit', 'off', true);
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), 'code_batch', 'promo_codes', v_batch::text,
          jsonb_build_object('count', v_made, 'prefix', v_prefix, 'kind', p_kind, 'value', p_value, 'note', p_note));
  return jsonb_build_object('batch_id', v_batch, 'count', v_made,
    'codes', (select jsonb_agg(c.code order by c.code) from public.promo_codes c where c.batch_id = v_batch));
end;
$$;
revoke all on function public.admin_create_code_batch(text, integer, public.promo_kind, integer, smallint[], timestamptz, timestamptz, text, boolean) from public, anon;
grant execute on function public.admin_create_code_batch(text, integer, public.promo_kind, integer, smallint[], timestamptz, timestamptz, text, boolean) to authenticated;

/** Codes for the admin list, grouped: shared codes one row each, unique batches one row per batch. */
create or replace function public.admin_codes()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'rows', coalesce((select jsonb_agg(r order by r.created_at desc) from (
      select (array_agg(c.id order by c.code))[1] as id, c.batch_id, count(*) as codes,
             case when c.batch_id is null then min(c.code) else split_part(min(c.code), '-', 1) || '-····-····' end as code,
             min(c.kind::text) as kind, min(c.value) as value, (jsonb_agg(to_jsonb(c.plan_ids)) -> 0) as plan_ids,
             sum(c.used_count) as used, case when c.batch_id is null then min(c.max_uses) else count(*) end as max_uses,
             bool_or(c.new_only) as new_only, min(c.starts_at) as starts_at, max(c.ends_at) as ends_at,
             bool_and(c.paused) as paused, min(c.note) as note, min(c.created_at) as created_at,
             (select u.email from auth.users u where u.id = min(c.created_by::text)::uuid) as created_by
      from public.promo_codes c
      group by coalesce(c.batch_id, c.id), c.batch_id) r), '[]'::jsonb),
    'totals', jsonb_build_object(
      'active', (select count(*) from public.promo_codes c where not c.paused and (c.ends_at is null or c.ends_at > now())
                   and (c.max_uses is null or c.used_count < c.max_uses)),
      'used_month', (select count(*) from public.promo_redemptions r where r.created_at >= date_trunc('month', now())),
      'discount_month_kobo', (select coalesce(sum(r.discount_kobo), 0) from public.promo_redemptions r where r.created_at >= date_trunc('month', now()))));
end;
$$;
revoke all on function public.admin_codes() from public, anon;
grant execute on function public.admin_codes() to authenticated;

/** Pauses or resumes a shared code or a whole batch. */
create or replace function public.admin_pause_codes(p_id uuid, p_paused boolean)
returns integer language plpgsql volatile security definer set search_path = '' as $$
declare v_batch uuid; v_n integer;
begin
  if not private.can_edit(array['super_admin', 'admin']::public.staff_role[]) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select batch_id into v_batch from public.promo_codes where id = p_id;
  update public.promo_codes set paused = p_paused where (v_batch is not null and batch_id = v_batch) or id = p_id;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke all on function public.admin_pause_codes(uuid, boolean) from public, anon;
grant execute on function public.admin_pause_codes(uuid, boolean) to authenticated;

/** All codes of a batch, for CSV export. */
create or replace function public.admin_batch_codes(p_batch uuid)
returns table (code text, used integer) language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return query select c.code, c.used_count from public.promo_codes c where c.batch_id = p_batch order by c.code;
end;
$$;
revoke all on function public.admin_batch_codes(uuid) from public, anon;
grant execute on function public.admin_batch_codes(uuid) to authenticated;

insert into public.feature_flags (key, enabled, description, updated_by) values
  ('codes_in_play_build', false, 'Show "Redeem a code" (free Premium days) in the Play Store app. Ask a lawyer before turning on.', null)
on conflict (key) do nothing;
