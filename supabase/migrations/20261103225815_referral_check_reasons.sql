-- D-079: referral reasons stay clear now that a second account on a phone counts as banned on the server.
create or replace function private.referral_check(p_friend uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare r public.referrals; s jsonb := private.ref_settings(); v_month integer; v_why text;
begin
  select * into r from public.referrals where friend = p_friend and status = 'pending' for update;
  if not found or not coalesce((s ->> 'enabled')::boolean, true) then return; end if;
  -- Real bans first (account or phone). A second account on a phone is handled below, with a clearer reason.
  if exists (select 1 from public.profiles p where p.id in (p_friend, r.referrer) and p.banned_at is not null)
     or private.user_phone_banned(p_friend) is not null or private.user_phone_banned(r.referrer) is not null then
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
