-- D-117: up to 3 discount codes on one payment (website and app checkout). The codes travel in the same text field as
-- before, separated by commas, so the app, the website and the Edge Function keep their calls. Every code is checked on its
-- own (expiry, uses, one per student, plan, new students only); the discounts add up; a part discount still leaves at least
-- ₦100 to pay; each code's use and share of the discount is recorded.
alter table public.payments add column if not exists extra_code_ids uuid[] not null default '{}';
alter table public.payments add column if not exists code_discounts jsonb not null default '{}';

-- The codes in a code field: "A, b c;D" → {A,B,C,D} (upper case, no spaces, duplicates removed, order kept).
create or replace function private.code_list(p text) returns text[]
language sql immutable set search_path = '' as $$
  select coalesce(array_agg(x order by i), '{}') from (
    select upper(x) x, min(i) i from regexp_split_to_table(coalesce(p, ''), '[\s,;]+') with ordinality t(x, i)
    where x <> '' group by upper(x)) s;
$$;

-- A limited code also counts unpaid checkouts (last 30 minutes) that hold it as a second or third code.
create or replace function private.check_code(p_uid uuid, p_code text, p_plan smallint, p_for text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare c public.promo_codes; v_pending integer;
begin
  select * into c from public.promo_codes where code = private.norm_code(p_code) and deleted_at is null;
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
    select count(*) into v_pending from public.payments p
    where (p.code_id = c.id or c.id = any (p.extra_code_ids)) and p.status = 'pending'
      and p.created_at > now() - interval '30 minutes' and p.user_id <> p_uid;
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

-- Plan price with up to 3 codes (or the referral discount when no code), then the processing fee.
create or replace function private.price(p_uid uuid, p_plan public.plans, p_code text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_codes text[] := private.code_list(p_code); v_code text; v_chk jsonb; v_off integer := 0; v_one integer; v_label text;
        s jsonb := private.ref_settings(); v_pct integer := 0; v_friends integer := 0; v_per integer; v_amount integer; v_fee integer;
        v_ids uuid[] := '{}'; v_list jsonb := '[]'; v_labels text[] := '{}'; v_scale numeric;
begin
  if cardinality(v_codes) > 3 then return jsonb_build_object('ok', false, 'error', 'too_many_codes'); end if;
  if cardinality(v_codes) > 0 then
    foreach v_code in array v_codes loop
      v_chk := private.check_code(p_uid, v_code, p_plan.id, 'checkout');
      if not (v_chk ->> 'ok')::boolean then return v_chk || jsonb_build_object('code', v_code); end if;
      if v_chk ->> 'kind' = 'pct' then
        v_one := round(p_plan.price_kobo * (v_chk ->> 'value')::integer / 100.0);
        v_labels := v_labels || ((v_chk ->> 'value') || '% off');
      else
        v_one := least((v_chk ->> 'value')::integer, p_plan.price_kobo);
        v_labels := v_labels || ('₦' || to_char((v_chk ->> 'value')::integer / 100, 'FM999,999,990') || ' off');
      end if;
      v_ids := v_ids || (v_chk ->> 'id')::uuid;
      v_list := v_list || jsonb_build_array(jsonb_build_object('id', v_chk ->> 'id', 'code', v_chk ->> 'code', 'off_kobo', v_one, 'label', v_labels[cardinality(v_labels)]));
      v_off := v_off + v_one;
    end loop;
    v_label := array_to_string(v_labels, ' + ');
  elsif p_uid is not null and coalesce((s ->> 'enabled')::boolean, true) then
    v_per := greatest(coalesce((s ->> 'pct_per_friend')::int, 10), 1);
    v_pct := least(private.referral_unspent(p_uid) * v_per, least(coalesce((s ->> 'max_pct')::int, 100), 100));
    if v_pct > 0 then
      v_friends := ceil(v_pct::numeric / v_per)::int;
      v_off := round(p_plan.price_kobo * v_pct / 100.0);
      v_label := v_pct || '% off from ' || v_friends || case when v_friends = 1 then ' invited friend' else ' invited friends' end;
    end if;
  end if;
  v_off := least(v_off, p_plan.price_kobo);
  if v_off > 0 and v_off < p_plan.price_kobo then v_off := least(v_off, greatest(p_plan.price_kobo - 10000, 0)); end if;
  -- When the total was trimmed, each code's share is trimmed in proportion (what is recorded per code adds up).
  if jsonb_array_length(v_list) > 0 then
    v_scale := v_off::numeric / greatest((select sum((x ->> 'off_kobo')::int) from jsonb_array_elements(v_list) x), 1);
    if v_scale < 1 then
      v_list := (select jsonb_agg(x || jsonb_build_object('off_kobo', floor((x ->> 'off_kobo')::int * v_scale)::int)) from jsonb_array_elements(v_list) x);
    end if;
  end if;
  v_amount := p_plan.price_kobo - v_off;
  v_fee := private.paystack_fee(v_amount);
  return jsonb_build_object('ok', true, 'plan', p_plan.code, 'list_kobo', p_plan.price_kobo, 'discount_kobo', v_off,
    'fee_kobo', v_fee, 'amount_kobo', v_amount + v_fee,
    'code', nullif(array_to_string(array(select x ->> 'code' from jsonb_array_elements(v_list) x), ', '), ''),
    'code_id', v_ids[1], 'code_ids', to_jsonb(v_ids),
    'codes', (select coalesce(jsonb_agg(x - 'id'), '[]') from jsonb_array_elements(v_list) x),
    'code_discounts', (select coalesce(jsonb_object_agg(x ->> 'id', (x ->> 'off_kobo')::int), '{}') from jsonb_array_elements(v_list) x),
    'label', v_label, 'referral_friends', v_friends);
end;
$$;

-- The quote never shows code ids.
create or replace function public.quote_price(p_plan text, p_code text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
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
  return (v_res - 'code_id' - 'code_ids' - 'code_discounts') || jsonb_build_object('period_end', v_end);
end;
$$;

create or replace function public.pay_start(p_uid uuid, p_plan text, p_code text, p_source text default 'app') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_plan public.plans; v_price jsonb; v_ref text; v_pay uuid; v_ent uuid; v_email text; v_end timestamptz; v_ids uuid[];
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
  v_ids := array(select (x)::uuid from jsonb_array_elements_text(coalesce(v_price -> 'code_ids', '[]')) x);
  select u.email into v_email from auth.users u where u.id = p_uid;
  v_ref := 'st_' || encode(extensions.gen_random_bytes(10), 'hex');
  insert into public.payments (user_id, provider, plan_id, reference, list_kobo, discount_kobo, amount_kobo, fee_kobo, code_id, extra_code_ids,
                               code_discounts, source, referral_friends)
  values (p_uid, case when (v_price ->> 'amount_kobo')::integer = 0 then 'code' else 'paystack' end, v_plan.id, v_ref,
          (v_price ->> 'list_kobo')::integer, (v_price ->> 'discount_kobo')::integer, (v_price ->> 'amount_kobo')::integer,
          coalesce((v_price ->> 'fee_kobo')::integer, 0),
          v_ids[1], coalesce(v_ids[2:], '{}'), coalesce(v_price -> 'code_discounts', '{}'),
          case when p_source = 'web' then 'web' else 'app' end,
          coalesce((v_price ->> 'referral_friends')::int, 0))
  returning id into v_pay;
  insert into public.payment_events (payment_id, provider, kind, ok, note, data)
  values (v_pay, 'server', 'started', true, 'Price worked out on the server',
          jsonb_build_object('amount_kobo', v_price -> 'amount_kobo', 'fee_kobo', v_price -> 'fee_kobo', 'code', v_price -> 'code',
                             'codes', v_price -> 'codes', 'referral_friends', v_price -> 'referral_friends'));
  if (v_price ->> 'amount_kobo')::integer = 0 then
    perform private.finish_payment(v_pay, case when coalesce((v_price ->> 'referral_friends')::int, 0) > 0 then 'referral' else 'code' end::public.entitlement_source);
    return jsonb_build_object('ok', true, 'payment_id', v_pay, 'reference', v_ref, 'amount_kobo', 0, 'free', true,
      'expires_at', (select max(e.expires_at) from public.entitlements e where e.user_id = p_uid and e.revoked_at is null));
  end if;
  return jsonb_build_object('ok', true, 'payment_id', v_pay, 'reference', v_ref, 'amount_kobo', v_price -> 'amount_kobo',
    'list_kobo', v_price -> 'list_kobo', 'discount_kobo', v_price -> 'discount_kobo', 'fee_kobo', v_price -> 'fee_kobo',
    'email', v_email, 'free', false);
end;
$$;

-- Every code of a paid checkout counts one use, with its own share of the discount.
create or replace function private.finish_payment(p_pay uuid, p_source public.entitlement_source) returns uuid
language plpgsql security definer set search_path = '' as $$
declare p public.payments; v_ent uuid; v_plan_name text; v_id uuid;
begin
  select * into p from public.payments where id = p_pay;
  if p.item_kind is not null then
    insert into public.content_purchases (user_id, kind, ref, payment_id) values (p.user_id, p.item_kind, p.item_ref, p.id)
    on conflict (user_id, kind, ref) do nothing;
    update public.payments set status = 'success', verified_at = coalesce(verified_at, now()) where id = p.id;
    insert into public.payment_events (payment_id, provider, kind, ok, note)
    values (p.id, 'server', 'item_given', true, 'Opened for good: ' || p.item_kind || ' ' || p.item_ref);
    insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
    values ('account', 'It is yours', 'Thanks! What you paid for is open for good.', 'user', p.user_id, 'scheduled', now(), 'premium',
            jsonb_build_object('type', 'screen', 'target', '/study'));
    return null;
  end if;
  if p.xp_pack is not null then
    perform private.xp_add(p.user_id, p.xp_pack, 'bought', 'pack', p.id::text, 'pack:' || p.id, false);
    update public.payments set status = 'success', verified_at = coalesce(verified_at, now()) where id = p.id;
    insert into public.payment_events (payment_id, provider, kind, ok, note)
    values (p.id, 'server', 'xp_given', true, p.xp_pack || ' XP added');
    insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
    values ('account', '+' || p.xp_pack || ' XP added', 'Thanks! Your ' || p.xp_pack || ' XP is in your wallet.', 'user', p.user_id, 'scheduled', now(), 'premium',
            jsonb_build_object('type', 'screen', 'target', '/me/xp'));
    return null;
  end if;
  select pl.name into v_plan_name from public.plans pl where pl.id = p.plan_id;
  v_ent := private.grant_plan(p.user_id, p.plan_id, p_source, 'pay:' || p.id, null,
                              v_plan_name || ' · ' || p.provider || ' ' || p.reference);
  update public.payments set status = 'success', verified_at = coalesce(verified_at, now()), entitlement_id = v_ent where id = p.id;
  foreach v_id in array (case when p.code_id is null then '{}'::uuid[] else array[p.code_id] end || coalesce(p.extra_code_ids, '{}')) loop
    insert into public.promo_redemptions (code_id, user_id, payment_id, discount_kobo, entitlement_id)
    values (v_id, p.user_id, p.id,
            coalesce((p.code_discounts ->> v_id::text)::int, case when v_id = p.code_id and cardinality(p.extra_code_ids) = 0 then p.discount_kobo else 0 end),
            v_ent)
    on conflict (code_id, user_id) do nothing;
    if found then update public.promo_codes set used_count = used_count + 1 where id = v_id; end if;
  end loop;
  insert into public.payment_events (payment_id, provider, kind, ok, note)
  values (p.id, 'server', 'premium_given', true, 'Premium given until ' ||
          to_char((select e.expires_at from public.entitlements e where e.id = v_ent) at time zone 'Africa/Lagos', 'DD Mon YYYY HH24:MI'));
  return v_ent;
end;
$$;
