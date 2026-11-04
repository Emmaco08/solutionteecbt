-- SolutionTee CBT · XP4 (owner, D-084; plan docs/plans/xp-streaks.md §3.4): XP packs bought with Paystack (website and
-- direct app). Same payments table, webhook (HMAC + verify) and idempotency as Premium; bought XP never enters cash challenges.

alter table public.payments alter column plan_id drop not null;
alter table public.payments add column if not exists xp_pack integer;
alter table public.payments add constraint payments_xp_pack_ok check (xp_pack is null or xp_pack > 0);
alter table public.payments add constraint payments_plan_or_pack check (plan_id is not null or xp_pack is not null);

/** Starts an XP pack payment (called by the paystack Edge Function with the student's id). Price from the admin's packs. */
create or replace function public.xp_pack_start(p_uid uuid, p_xp integer, p_source text default 'app')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare s jsonb := private.xp_settings(); v_naira integer; v_ref text; v_pay uuid; v_email text;
begin
  if p_uid is null then return jsonb_build_object('ok', false, 'error', 'auth'); end if;
  if private.is_banned(p_uid) then return jsonb_build_object('ok', false, 'error', 'banned'); end if;
  if not coalesce((s ->> 'enabled')::boolean, true) then return jsonb_build_object('ok', false, 'error', 'xp_off'); end if;
  if (select count(*) from public.pay_attempts a where a.user_id = p_uid and a.action = 'start' and a.created_at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  insert into public.pay_attempts (user_id, action, ok) values (p_uid, 'start', true);
  select (x ->> 'naira')::int into v_naira from jsonb_array_elements(coalesce(s -> 'packs', '[]')) x where (x ->> 'xp')::int = p_xp limit 1;
  if v_naira is null or v_naira < 100 then return jsonb_build_object('ok', false, 'error', 'pack'); end if;
  select u.email into v_email from auth.users u where u.id = p_uid;
  v_ref := 'st_' || encode(extensions.gen_random_bytes(10), 'hex');
  insert into public.payments (user_id, provider, plan_id, xp_pack, reference, list_kobo, discount_kobo, amount_kobo, source)
  values (p_uid, 'paystack', null, p_xp, v_ref, v_naira * 100, 0, v_naira * 100, case when p_source = 'web' then 'web' else 'app' end)
  returning id into v_pay;
  insert into public.payment_events (payment_id, provider, kind, ok, note, data)
  values (v_pay, 'server', 'started', true, 'XP pack: ' || p_xp || ' XP for ₦' || v_naira, jsonb_build_object('xp', p_xp, 'amount_kobo', v_naira * 100));
  return jsonb_build_object('ok', true, 'payment_id', v_pay, 'reference', v_ref, 'amount_kobo', v_naira * 100, 'email', v_email, 'xp', p_xp);
end;
$$;

-- A verified payment: an XP pack adds bought XP once (key per payment); a plan gives Premium as before.
create or replace function private.finish_payment(p_pay uuid, p_source public.entitlement_source)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare p public.payments; v_ent uuid; v_plan_name text;
begin
  select * into p from public.payments where id = p_pay;
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

/** A refunded XP pack takes back the bought XP that is still unspent. */
create or replace function private.xp_on_pack_refund()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v integer;
begin
  if new.xp_pack is not null and new.status = 'refunded' and old.status is distinct from 'refunded' then
    select least(new.xp_pack, xp_bought) into v from public.profiles where id = new.user_id for update;
    if coalesce(v, 0) > 0 then
      insert into public.xp_ledger (user_id, amount, kind, reason, ref, key, note)
      values (new.user_id, -v, 'bought', 'refund', new.id::text, 'refund:' || new.id, 'XP pack refunded');
      if found then update public.profiles set xp_bought = xp_bought - v where id = new.user_id; end if;
    end if;
  end if;
  return null;
end;
$$;
create trigger xp_on_pack_refund after update of status on public.payments for each row execute function private.xp_on_pack_refund();

revoke all on function public.xp_pack_start(uuid, integer, text) from public, anon, authenticated;
grant execute on function public.xp_pack_start(uuid, integer, text) to service_role;
