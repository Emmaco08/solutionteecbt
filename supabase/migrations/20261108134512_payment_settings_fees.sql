-- D-113: payment settings chosen by the admin (owner, 8 Nov 2026).
--   play.google / play.website: which ways to pay the Google Play app shows (Google Play Billing, a link to the website,
--   or both). website_url: the payment website.
--   fees.paystack: add Paystack's processing fee to the price (on/off; % + flat naira from an amount, capped).
--   fees.google: use the second Google Play product of each plan (priced with the fee in Play Console).
insert into public.app_settings (key, value, is_public)
values ('payments', '{"play": {"google": true, "website": false},
                      "website_url": "https://cbt.solutiontee.com/pay",
                      "fees": {"paystack": {"on": false, "pct": 1.5, "flat": 100, "flat_from": 2500, "cap": 2000},
                               "google": {"on": false, "pct": 15}}}', true)
on conflict (key) do nothing;

alter table public.payments add column if not exists fee_kobo integer not null default 0;
alter table public.plans add column if not exists play_product_id_fee text unique;

-- Paystack fee to add so that, after Paystack's cut, we still receive the price (rounded up to a whole naira).
create or replace function private.paystack_fee(p_amount_kobo integer) returns integer
language plpgsql stable security definer set search_path = '' as $$
declare f jsonb := (select value -> 'fees' -> 'paystack' from public.app_settings where key = 'payments');
        v_pct numeric; v_flat integer; v_from integer; v_cap integer; v_total numeric; v_fee integer;
begin
  if p_amount_kobo is null or p_amount_kobo <= 0 or f is null or not coalesce((f ->> 'on')::boolean, false) then return 0; end if;
  v_pct := least(greatest(coalesce((f ->> 'pct')::numeric, 1.5), 0), 20) / 100;
  v_flat := greatest(coalesce((f ->> 'flat')::numeric, 0), 0) * 100;
  v_from := greatest(coalesce((f ->> 'flat_from')::numeric, 0), 0) * 100;
  v_cap := greatest(coalesce((f ->> 'cap')::numeric, 0), 0) * 100;
  v_total := p_amount_kobo / (1 - v_pct);
  if v_flat > 0 and v_total >= v_from then v_total := (p_amount_kobo + v_flat) / (1 - v_pct); end if;
  v_fee := ceil((v_total - p_amount_kobo) / 100.0)::int * 100;
  if v_cap > 0 then v_fee := least(v_fee, v_cap); end if;
  return greatest(v_fee, 0);
end;
$$;

-- Plan price: discount first, then the processing fee (only when something is paid).
create or replace function private.price(p_uid uuid, p_plan public.plans, p_code text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_chk jsonb; v_off integer := 0; v_label text; s jsonb := private.ref_settings(); v_pct integer := 0; v_friends integer := 0; v_per integer;
        v_amount integer; v_fee integer;
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
  v_amount := p_plan.price_kobo - v_off;
  v_fee := private.paystack_fee(v_amount);
  return jsonb_build_object('ok', true, 'plan', p_plan.code, 'list_kobo', p_plan.price_kobo, 'discount_kobo', v_off,
    'fee_kobo', v_fee, 'amount_kobo', v_amount + v_fee, 'code', v_chk ->> 'code', 'code_id', v_chk ->> 'id', 'label', v_label,
    'referral_friends', v_friends);
end;
$$;

create or replace function public.pay_start(p_uid uuid, p_plan text, p_code text, p_source text default 'app') returns jsonb
language plpgsql security definer set search_path = '' as $$
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
  insert into public.payments (user_id, provider, plan_id, reference, list_kobo, discount_kobo, amount_kobo, fee_kobo, code_id, source, referral_friends)
  values (p_uid, case when (v_price ->> 'amount_kobo')::integer = 0 then 'code' else 'paystack' end, v_plan.id, v_ref,
          (v_price ->> 'list_kobo')::integer, (v_price ->> 'discount_kobo')::integer, (v_price ->> 'amount_kobo')::integer,
          coalesce((v_price ->> 'fee_kobo')::integer, 0),
          (v_price ->> 'code_id')::uuid, case when p_source = 'web' then 'web' else 'app' end,
          coalesce((v_price ->> 'referral_friends')::int, 0))
  returning id into v_pay;
  insert into public.payment_events (payment_id, provider, kind, ok, note, data)
  values (v_pay, 'server', 'started', true, 'Price worked out on the server',
          jsonb_build_object('amount_kobo', v_price -> 'amount_kobo', 'fee_kobo', v_price -> 'fee_kobo', 'code', v_price -> 'code',
                             'referral_friends', v_price -> 'referral_friends'));
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

create or replace function public.content_pay_start(p_uid uuid, p_kind text, p_ref text, p_source text default 'app') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare o jsonb; v_ref text; v_pay uuid; v_email text; v_price integer; v_fee integer; v_title text; v_exam smallint; v_year smallint;
begin
  if p_uid is null then return jsonb_build_object('ok', false, 'error', 'auth'); end if;
  if private.is_banned(p_uid) then return jsonb_build_object('ok', false, 'error', 'banned'); end if;
  if exists (select 1 from public.content_purchases c where c.user_id = p_uid and c.kind = p_kind and c.ref = p_ref) then
    return jsonb_build_object('ok', false, 'error', 'bought');
  end if;
  if (select count(*) from public.pay_attempts a where a.user_id = p_uid and a.action = 'start' and a.created_at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  if p_kind = 'item' then
    o := private.item_offer(nullif(p_ref, '')::uuid);
    select plain into v_title from (select regexp_replace(coalesce(o ->> 'title', 'Study item'), '\s+', ' ', 'g') as plain) t;
  elsif p_kind = 'year' then
    v_exam := split_part(p_ref, ':', 1)::smallint; v_year := split_part(p_ref, ':', 2)::smallint;
    o := private.year_offer(v_exam, v_year);
    select e.code || ' ' || v_year into v_title from public.exam_bodies e where e.id = v_exam;
  end if;
  if o is null or o ->> 'mode' <> 'pay' then return jsonb_build_object('ok', false, 'error', 'not_for_sale'); end if;
  v_price := (o ->> 'price_kobo')::int;
  if v_price is null or v_price < 5000 then return jsonb_build_object('ok', false, 'error', 'not_for_sale'); end if;
  v_fee := private.paystack_fee(v_price);
  insert into public.pay_attempts (user_id, action, ok) values (p_uid, 'start', true);
  select u.email into v_email from auth.users u where u.id = p_uid;
  v_ref := 'st_' || encode(extensions.gen_random_bytes(10), 'hex');
  insert into public.payments (user_id, provider, plan_id, item_kind, item_ref, reference, list_kobo, discount_kobo, amount_kobo, fee_kobo, source)
  values (p_uid, 'paystack', null, p_kind, p_ref, v_ref, v_price, 0, v_price + v_fee, v_fee, case when p_source = 'web' then 'web' else 'app' end)
  returning id into v_pay;
  insert into public.payment_events (payment_id, provider, kind, ok, note, data)
  values (v_pay, 'server', 'started', true, 'Item: ' || left(coalesce(v_title, p_ref), 80) || ' for ₦' || (v_price / 100)
            || case when v_fee > 0 then ' + ₦' || (v_fee / 100) || ' fee' else '' end,
          jsonb_build_object('kind', p_kind, 'ref', p_ref, 'amount_kobo', v_price + v_fee, 'fee_kobo', v_fee));
  return jsonb_build_object('ok', true, 'payment_id', v_pay, 'reference', v_ref, 'amount_kobo', v_price + v_fee, 'price_kobo', v_price,
                            'fee_kobo', v_fee, 'email', v_email, 'title', v_title);
end;
$$;

-- Google Play: either product of a plan (the plain one, or the one priced with the fee).
create or replace function public.pay_play_confirm(p_uid uuid, p_product text, p_token text, p_order_id text, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_plan public.plans; p public.payments; v_pay uuid;
begin
  if private.is_banned(p_uid) then return jsonb_build_object('ok', false, 'error', 'banned'); end if;
  select * into v_plan from public.plans where play_product_id = p_product or play_product_id_fee = p_product;
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
          p_token, v_plan.price_kobo, v_plan.price_kobo, 'pending', coalesce(p_data, '{}') || jsonb_build_object('product', p_product))
  returning id into v_pay;
  insert into public.payment_events (payment_id, provider, kind, ok, note, data)
  values (v_pay, 'play', 'verified', true, 'Google Play purchase checked with Google (' || p_product || ')', coalesce(p_data, '{}'));
  perform private.finish_payment(v_pay, 'play');
  return jsonb_build_object('ok', true, 'status', 'success',
    'expires_at', (select e.expires_at from public.entitlements e join public.payments x on x.entitlement_id = e.id where x.id = v_pay));
end;
$$;
