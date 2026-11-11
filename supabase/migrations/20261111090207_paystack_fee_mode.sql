-- D-132: who pays the Paystack fee, matched with the Paystack dashboard.
--   payments.fees.paystack.mode: "none" (we pay it; Paystack: Charge me), "ours" (we add it to the price; Paystack:
--   Charge me), "paystack" (Paystack adds it at checkout; Paystack: Charge my customers). "on" stays for older apps
--   and is true only for "ours".
update public.app_settings
set value = jsonb_set(value, '{fees,paystack,mode}',
  to_jsonb(case when coalesce((value #>> '{fees,paystack,on}')::boolean, false) then 'ours' else 'none' end), true)
where key = 'payments' and value #> '{fees,paystack}' is not null and value #> '{fees,paystack,mode}' is null;

create or replace function private.paystack_fee(p_amount_kobo integer)
 returns integer language plpgsql stable security definer set search_path to ''
as $function$
declare f jsonb := (select value -> 'fees' -> 'paystack' from public.app_settings where key = 'payments');
        v_pct numeric; v_flat integer; v_from integer; v_cap integer; v_total numeric; v_fee integer;
begin
  -- Only when we add the fee ourselves; never when Paystack adds it at checkout (no double fee).
  if p_amount_kobo is null or p_amount_kobo <= 0 or f is null or not coalesce((f ->> 'on')::boolean, false)
     or coalesce(f ->> 'mode', 'ours') <> 'ours' then return 0; end if;
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
$function$;

-- Paystack's verify answer: when Paystack charges the customer its fee, "amount" is more than what we asked for and
-- "requested_amount" is what we asked for. Our price must match what we asked for exactly; the charged amount may
-- only be equal or higher (the difference is Paystack's fee, paid by the student).
drop function if exists public.pay_paystack_result(text, text, integer, text, text, jsonb, text, text);
create function public.pay_paystack_result(p_reference text, p_status text, p_amount_kobo integer, p_currency text,
  p_channel text, p_data jsonb, p_kind text, p_event_key text default null, p_requested_kobo integer default null)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare p public.payments; v_req integer;
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
    v_req := coalesce(p_requested_kobo, p_amount_kobo);
    if v_req is distinct from p.amount_kobo or p_amount_kobo is null or p_amount_kobo < v_req
       or upper(coalesce(p_currency, '')) <> p.currency then
      update public.payments set status = 'needs_review' where id = p.id;
      insert into public.payment_events (payment_id, provider, kind, ok, note)
      values (p.id, 'server', 'amount_mismatch', false,
              format('Paid %s %s (asked %s), expected %s %s. Premium not given; check in Paystack.', p_amount_kobo, p_currency, coalesce(p_requested_kobo::text, '?'), p.amount_kobo, p.currency));
      return jsonb_build_object('ok', true, 'status', 'needs_review', 'user_id', p.user_id);
    end if;
    if p_amount_kobo > v_req then
      insert into public.payment_events (payment_id, provider, kind, ok, note)
      values (p.id, 'server', 'customer_fee', true, format('The student also paid Paystack''s fee: %s kobo (Paystack: Charge my customers).', p_amount_kobo - v_req));
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
  return jsonb_build_object('ok', true, 'status', 'pending', 'user_id', p.user_id);
end;
$function$;
revoke all on function public.pay_paystack_result(text, text, integer, text, text, jsonb, text, text, integer) from public, anon, authenticated;
grant execute on function public.pay_paystack_result(text, text, integer, text, text, jsonb, text, text, integer) to service_role;

-- Admin → Payment settings: what Paystack actually did on the latest successful payments (read-only).
create or replace function public.admin_paystack_fee_check()
 returns jsonb language sql stable security definer set search_path to ''
as $function$
  select case when not private.is_staff() then null else coalesce((
    select jsonb_agg(x order by x->>'at' desc) from (
      select jsonb_build_object('at', p.verified_at, 'price_kobo', p.amount_kobo,
        'paid_kobo', nullif(p.provider_data ->> 'amount', '')::int,
        'requested_kobo', nullif(p.provider_data ->> 'requested_amount', '')::int,
        'fees_kobo', nullif(p.provider_data ->> 'fees', '')::int) x
      from public.payments p
      where p.provider = 'paystack' and p.status = 'success' and p.amount_kobo > 0 and p.provider_data ? 'amount'
      order by p.verified_at desc nulls last limit 5) t), '[]'::jsonb) end;
$function$;
revoke all on function public.admin_paystack_fee_check() from public, anon;
grant execute on function public.admin_paystack_fee_check() to authenticated;
