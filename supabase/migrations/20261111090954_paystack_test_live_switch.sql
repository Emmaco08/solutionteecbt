-- D-133: Paystack Test / Live switch in admin → Payment settings. The four keys are typed by a super admin with 2-step
-- login and kept only in Supabase Vault (never shown again, never in the app or the browser). The payment server reads
-- them with paystack_config() (service role only). A payment remembers the mode it was made in (payments.live), so it is
-- always checked with the right key, and test payments never count as money.
alter table public.payments add column if not exists live boolean not null default true;
comment on column public.payments.live is 'false = made with Paystack test keys (no real money); left out of revenue (D-133)';

insert into public.app_settings (key, value, is_public) values ('paystack_env', '{"mode": "live"}', false)
on conflict (key) do nothing;

create or replace function private.paystack_secret(p_name text)
 returns text language sql stable security definer set search_path to ''
as $$ select decrypted_secret from vault.decrypted_secrets where name = p_name order by created_at desc limit 1 $$;
revoke all on function private.paystack_secret(text) from public, anon, authenticated;

create or replace function public.paystack_config()
 returns jsonb language sql stable security definer set search_path to ''
as $$
  select jsonb_build_object(
    'mode', coalesce((select value ->> 'mode' from public.app_settings where key = 'paystack_env'), 'live'),
    'sk_live', private.paystack_secret('paystack_sk_live'), 'pk_live', private.paystack_secret('paystack_pk_live'),
    'sk_test', private.paystack_secret('paystack_sk_test'), 'pk_test', private.paystack_secret('paystack_pk_test'));
$$;
revoke all on function public.paystack_config() from public, anon, authenticated;
grant execute on function public.paystack_config() to service_role;

create or replace function private.mask_key(v text)
 returns text language sql immutable set search_path to ''
as $$ select case when v is null or v = '' then null else left(v, 8) || '••••' || right(v, 4) end $$;

-- What admin → Payment settings shows: the mode and which keys are saved (masked), never a key.
create or replace function public.admin_paystack_keys()
 returns jsonb language plpgsql stable security definer set search_path to ''
as $$
begin
  if not private.can_edit(array['super_admin', 'admin']::public.staff_role[]) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'mode', coalesce((select value ->> 'mode' from public.app_settings where key = 'paystack_env'), 'live'),
    'sk_live', private.mask_key(private.paystack_secret('paystack_sk_live')), 'pk_live', private.mask_key(private.paystack_secret('paystack_pk_live')),
    'sk_test', private.mask_key(private.paystack_secret('paystack_sk_test')), 'pk_test', private.mask_key(private.paystack_secret('paystack_pk_test')),
    'test_payments', (select count(*) from public.payments where live = false));
end;
$$;
revoke all on function public.admin_paystack_keys() from public, anon;
grant execute on function public.admin_paystack_keys() to authenticated;

-- Saves one key in Vault. Super admins with 2-step login only. The key must look right for its slot.
create or replace function public.admin_set_paystack_key(p_name text, p_value text)
 returns jsonb language plpgsql volatile security definer set search_path to ''
as $$
declare v text := btrim(coalesce(p_value, '')); v_rule text; v_id uuid;
begin
  if not private.can_edit(array['super_admin']::public.staff_role[]) then
    raise exception 'Only a super admin with 2-step login can change Paystack keys.' using errcode = '42501';
  end if;
  v_rule := case p_name
    when 'paystack_sk_live' then '^sk_live_[A-Za-z0-9]{20,80}$' when 'paystack_pk_live' then '^pk_live_[A-Za-z0-9]{20,80}$'
    when 'paystack_sk_test' then '^sk_test_[A-Za-z0-9]{20,80}$' when 'paystack_pk_test' then '^pk_test_[A-Za-z0-9]{20,80}$' end;
  if v_rule is null then raise exception 'Unknown key.'; end if;
  if v !~ v_rule then
    raise exception 'That does not look like a Paystack % key (it starts with %).',
      replace(replace(replace(p_name, 'paystack_', ''), '_', ' '), 'sk', 'secret'), left(replace(v_rule, '^', ''), 8);
  end if;
  select id into v_id from vault.secrets where name = p_name order by created_at desc limit 1;
  if v_id is null then perform vault.create_secret(v, p_name, 'Paystack key (admin → Payment settings, D-133)');
  else perform vault.update_secret(v_id, v); end if;
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values (auth.uid(), 'paystack_key_saved', 'vault.secrets', p_name, jsonb_build_object('key', private.mask_key(v)));
  return jsonb_build_object('ok', true, 'masked', private.mask_key(v));
end;
$$;
revoke all on function public.admin_set_paystack_key(text, text) from public, anon;
grant execute on function public.admin_set_paystack_key(text, text) to authenticated;

-- Test or Live. Test needs both test keys. Super admins with 2-step login only (logged by the settings trigger).
create or replace function public.admin_set_paystack_mode(p_mode text)
 returns jsonb language plpgsql volatile security definer set search_path to ''
as $$
begin
  if not private.can_edit(array['super_admin']::public.staff_role[]) then
    raise exception 'Only a super admin with 2-step login can switch Paystack between Test and Live.' using errcode = '42501';
  end if;
  if p_mode not in ('test', 'live') then raise exception 'Choose Test or Live.'; end if;
  if p_mode = 'test' and (private.paystack_secret('paystack_sk_test') is null or private.paystack_secret('paystack_pk_test') is null) then
    raise exception 'Save the test secret key and test public key first.';
  end if;
  insert into public.app_settings (key, value, is_public) values ('paystack_env', jsonb_build_object('mode', p_mode), false)
  on conflict (key) do update set value = excluded.value;
  return jsonb_build_object('ok', true, 'mode', p_mode);
end;
$$;
revoke all on function public.admin_set_paystack_mode(text) from public, anon;
grant execute on function public.admin_set_paystack_mode(text) to authenticated;

-- Test payments are not money: left out of the revenue figures (the payments list still shows them, marked Test).
do $$
declare d text;
begin
  d := pg_get_functiondef('public.admin_analytics(integer)'::regprocedure);
  if position('from public.payments p where p.created_at >= tp;' in d) = 0
     or position('where p.status::text = ''success'' and p.provider in (''paystack'', ''play'')' in d) = 0 then
    raise exception 'admin_analytics changed; update this migration';
  end if;
  d := replace(d, 'from public.payments p where p.created_at >= tp;', 'from public.payments p where p.created_at >= tp and p.live;');
  d := replace(d, 'where p.status::text = ''success'' and p.provider in (''paystack'', ''play'')', 'where p.status::text = ''success'' and p.live and p.provider in (''paystack'', ''play'')');
  execute d;

  d := pg_get_functiondef('public.admin_payments(text, text, text, integer, integer)'::regprocedure);
  if position('p.created_at, p.verified_at, p.refunded_at,' in d) = 0 or position('      from public.payments p));' in d) = 0 then
    raise exception 'admin_payments changed; update this migration';
  end if;
  d := replace(d, 'p.created_at, p.verified_at, p.refunded_at,', 'p.created_at, p.verified_at, p.refunded_at, p.live,');
  d := replace(d, '      from public.payments p));', '      from public.payments p where p.live));');
  execute d;

  d := pg_get_functiondef('public.admin_content_access()'::regprocedure);
  if position('from public.payments p where p.item_kind is not null and p.status = ''success''' in d) = 0 then
    raise exception 'admin_content_access changed; update this migration';
  end if;
  d := replace(d, 'from public.payments p where p.item_kind is not null and p.status = ''success''', 'from public.payments p where p.item_kind is not null and p.status = ''success'' and p.live');
  execute d;
end $$;
