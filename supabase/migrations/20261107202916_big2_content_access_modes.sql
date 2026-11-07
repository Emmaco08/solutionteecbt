-- Ads v2, part B4 (owner, 2026-11-07): how Study content opens is the admin's choice, per kind and per item:
-- 'default' (the Free vs Premium rules as before), 'free', 'premium', 'ads' (free students watch N rewarded videos to
-- open it for H hours; 0 = for good) or 'pay' (pay for this one item with Paystack; Premium included unless the admin
-- says Premium students pay too). Video lessons/solutions, notes, novels and documents per item; past-question years
-- (CBT and study mode) per exam year. Everything is checked on the server.

-- Per item (null = the kind's default from app_settings.content_access).
alter table public.study_items add column if not exists access text check (access is null or access in ('default', 'free', 'premium', 'ads', 'pay'));
alter table public.study_items add column if not exists ad_count smallint check (ad_count is null or ad_count between 1 and 20);
alter table public.study_items add column if not exists ad_hours smallint check (ad_hours is null or ad_hours between 0 and 720);
alter table public.study_items add column if not exists price_kobo integer check (price_kobo is null or price_kobo between 5000 and 10000000);
alter table public.study_items add column if not exists pay_premium boolean;

-- Per exam year (both CBT and study mode).
create table if not exists public.year_access (
  exam_id smallint not null references public.exam_bodies (id) on delete cascade,
  year smallint not null,
  access text not null check (access in ('free', 'premium', 'ads', 'pay')),
  ad_count smallint check (ad_count is null or ad_count between 1 and 20),
  ad_hours smallint check (ad_hours is null or ad_hours between 0 and 720),
  price_kobo integer check (price_kobo is null or price_kobo between 5000 and 10000000),
  pay_premium boolean,
  updated_at timestamptz not null default now(),
  primary key (exam_id, year)
);
alter table public.year_access enable row level security;
create policy "staff read year_access" on public.year_access for select to authenticated using (private.is_staff());

-- Bought items: kept for good.
create table if not exists public.content_purchases (
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('item', 'year')),
  ref text not null,
  payment_id uuid references public.payments (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (user_id, kind, ref)
);
alter table public.content_purchases enable row level security;
create policy "own purchases" on public.content_purchases for select to authenticated using (user_id = (select auth.uid()));

alter table public.payments add column if not exists item_kind text check (item_kind is null or item_kind in ('item', 'year'));
alter table public.payments add column if not exists item_ref text;
alter table public.payments drop constraint if exists payments_plan_or_pack;
alter table public.payments add constraint payments_plan_or_pack check (plan_id is not null or xp_pack is not null or item_kind is not null);

alter table public.ad_rewards drop constraint if exists ad_rewards_kind_check;
alter table public.ad_rewards add constraint ad_rewards_kind_check check (kind in ('ai_prompts', 'note', 'streak_freeze', 'xp', 'year', 'item'));

insert into public.app_settings (key, value, is_public)
values ('content_access', '{"items": {}, "years": {"mode": "default"}}', false)
on conflict (key) do nothing;

-- The resolved rule for one study item: its own settings over its kind's default.
create or replace function private.item_offer(p_item uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'mode', coalesce(nullif(i.access, 'default'), y.d ->> 'mode', 'default'),
    'ads', coalesce(i.ad_count, (y.d ->> 'ads')::int, 1),
    'hours', coalesce(i.ad_hours, (y.d ->> 'hours')::int, 24),
    'price_kobo', coalesce(i.price_kobo, (y.d ->> 'price_kobo')::int),
    'premium_pays', coalesce(i.pay_premium, (y.d ->> 'premium_pays')::boolean, false),
    'kind', i.kind, 'title', i.title)
  from public.study_items i
  left join lateral (select s.value -> 'items' -> i.kind as kd from public.app_settings s where s.key = 'content_access') x on true
  cross join lateral (select coalesce(x.kd, '{}'::jsonb) as d) y
  where i.id = p_item;
$$;

-- The resolved rule for one exam year ('default' = the Free vs Premium rules).
create or replace function private.year_offer(p_exam smallint, p_year smallint) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'mode', coalesce(a.access, z.d ->> 'mode', 'default'),
    'ads', coalesce(a.ad_count, (z.d ->> 'ads')::int, (z.r ->> 'year_ads')::int, 1),
    'hours', coalesce(a.ad_hours, (z.d ->> 'hours')::int, 1),
    'minutes', case when a.ad_hours is not null then a.ad_hours * 60 when z.d ? 'hours' then (z.d ->> 'hours')::int * 60
                    else coalesce((z.r ->> 'year_minutes')::int, 60) end,
    'price_kobo', coalesce(a.price_kobo, (z.d ->> 'price_kobo')::int),
    'premium_pays', coalesce(a.pay_premium, (z.d ->> 'premium_pays')::boolean, false))
  from (select 1) one
  left join public.year_access a on a.exam_id = p_exam and a.year = p_year
  left join lateral (select s.value -> 'years' as cd from public.app_settings s where s.key = 'content_access') ca on true
  left join lateral (select s.value -> 'rewards' as rd from public.app_settings s where s.key = 'ads') ad on true
  cross join lateral (select coalesce(ca.cd, '{}'::jsonb) as d, coalesce(ad.rd, '{}'::jsonb) as r) z;
$$;

create or replace function private.bought(p_kind text, p_ref text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.content_purchases c where c.user_id = (select auth.uid()) and c.kind = p_kind and c.ref = p_ref);
$$;

-- Is this offer open for the student? null = 'default' (the caller applies the Free vs Premium rules).
create or replace function private.offer_open(o jsonb, p_kind text, p_ref text) returns boolean
language sql stable security definer set search_path = '' as $$
  select case o ->> 'mode'
    when 'free' then true
    when 'premium' then private.has_premium()
    when 'ads' then private.has_premium() or private.ad_unlocked(p_kind, p_ref)
    when 'pay' then (private.has_premium() and not coalesce((o ->> 'premium_pays')::boolean, false)) or private.bought(p_kind, p_ref)
    else null end;
$$;

-- Study items: the item's own rule first, then the Free vs Premium rules (and a note opened by "watch to unlock").
create or replace function private.study_open(p_kind text, p_is_free boolean, p_item uuid) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare v boolean;
begin
  if private.is_staff() then return true; end if;
  if (select auth.uid()) is null or private.is_banned() then return false; end if;
  v := private.offer_open(private.item_offer(p_item), 'item', p_item::text);
  if v is not null then return v; end if;
  return private.study_open(p_kind, p_is_free) or private.ad_unlocked('note', p_item::text);
end;
$$;

-- Exam years: the year's own rule first (null = the usual rules below it).
create or replace function private.year_override(p_exam smallint, p_year smallint) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.offer_open(private.year_offer(p_exam, p_year), 'year', p_exam::text || ':' || p_year::text);
$$;

-- Put the item rule into every function that checks a study item, and the year rule into year_open.
do $$
declare f record; d text;
begin
  for f in select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private') and p.prokind = 'f' and p.proname <> 'study_open'
             and pg_get_functiondef(p.oid) like '%study_open(%' loop
    d := pg_get_functiondef(f.oid);
    d := replace(d, 'private.study_open(r.kind, r.is_free) and not private.ad_unlocked(''note'', r.id::text)', 'private.study_open(r.kind, r.is_free, r.id)');
    d := replace(d, 'private.study_open(r.kind, r.is_free)', 'private.study_open(r.kind, r.is_free, r.id)');
    d := replace(d, 'private.study_open(i.kind, i.is_free)', 'private.study_open(i.kind, i.is_free, i.id)');
    execute d;
  end loop;
  d := pg_get_functiondef('private.year_open(smallint,smallint,text)'::regprocedure);
  if position('year_override' in d) = 0 then
    d := replace(d, '  if private.ad_unlocked(''year'', p_exam::text || '':'' || p_year::text) then return true; end if;',
      '  if private.year_override(p_exam, p_year) is not null then return private.year_override(p_exam, p_year); end if;
  if private.ad_unlocked(''year'', p_exam::text || '':'' || p_year::text) then return true; end if;');
    execute d;
  end if;
end $$;

-- Watch-to-open: how many videos a reward needs and how long it lasts.
create or replace function private.reward_rule(p_kind text, p_ref text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare s jsonb; o jsonb; v_exam smallint; v_year smallint;
begin
  select coalesce(value -> 'rewards', '{}'::jsonb) into s from public.app_settings where key = 'ads';
  s := coalesce(s, '{}'::jsonb);
  if p_kind = 'item' then
    o := private.item_offer(nullif(p_ref, '')::uuid);
    return jsonb_build_object('need', greatest(coalesce((o ->> 'ads')::int, 1), 1),
                              'minutes', case when coalesce((o ->> 'hours')::int, 24) = 0 then 52560000 else (o ->> 'hours')::int * 60 end);
  elsif p_kind = 'year' then
    v_exam := split_part(p_ref, ':', 1)::smallint; v_year := split_part(p_ref, ':', 2)::smallint;
    o := private.year_offer(v_exam, v_year);
    if o ->> 'mode' = 'ads' then
      return jsonb_build_object('need', greatest(coalesce((o ->> 'ads')::int, 1), 1),
                                'minutes', case when coalesce((o ->> 'hours')::int, 1) = 0 then 52560000 else (o ->> 'minutes')::int end);
    end if;
    return jsonb_build_object('need', greatest(coalesce((s ->> 'year_ads')::int, 1), 1), 'minutes', coalesce((s ->> 'year_minutes')::int, 60));
  elsif p_kind = 'xp' then
    return jsonb_build_object('need', greatest(coalesce((s ->> 'xp_ads')::int, 1), 1));
  elsif p_kind = 'note' then
    return jsonb_build_object('need', 1, 'minutes', coalesce((s ->> 'note_hours')::int, 24) * 60);
  end if;
  return jsonb_build_object('need', 1);
end;
$$;

create or replace function public.ad_reward_start(p_kind text, p_ref text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c jsonb := public.ads_config(); v_id uuid; v_uid uuid := (select auth.uid()); v_exam smallint; v_year smallint;
begin
  if v_uid is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  if coalesce((c ->> 'on')::boolean, false) is false or coalesce((c -> 'formats' ->> 'rewarded')::boolean, true) is false then
    return jsonb_build_object('ok', false, 'why', 'off');
  end if;
  if coalesce((c ->> 'rewarded_left')::int, 0) <= 0 then return jsonb_build_object('ok', false, 'why', 'cap'); end if;
  if p_kind not in ('ai_prompts', 'note', 'streak_freeze', 'xp', 'year', 'item') then return jsonb_build_object('ok', false, 'why', 'kind'); end if;
  if p_kind in ('note', 'item') and not exists (select 1 from public.study_items i where i.id::text = p_ref and i.status = 'published' and i.deleted_at is null) then
    return jsonb_build_object('ok', false, 'why', 'missing');
  end if;
  if p_kind = 'item' and private.item_offer(p_ref::uuid) ->> 'mode' <> 'ads' then return jsonb_build_object('ok', false, 'why', 'kind'); end if;
  if p_kind = 'streak_freeze' and (select streak_freezes from public.profiles where id = v_uid) >= 2 then
    return jsonb_build_object('ok', false, 'why', 'full');
  end if;
  if p_kind = 'xp' and coalesce((c ->> 'xp_left')::int, 0) <= 0 then return jsonb_build_object('ok', false, 'why', 'xp_cap'); end if;
  if p_kind = 'year' then
    begin
      v_exam := split_part(p_ref, ':', 1)::smallint; v_year := split_part(p_ref, ':', 2)::smallint;
    exception when others then return jsonb_build_object('ok', false, 'why', 'missing');
    end;
    if not exists (select 1 from public.exam_years y where y.exam_id = v_exam and y.year = v_year and y.status = 'published') then
      return jsonb_build_object('ok', false, 'why', 'missing');
    end if;
    if private.year_offer(v_exam, v_year) ->> 'mode' in ('free', 'premium', 'pay') then return jsonb_build_object('ok', false, 'why', 'kind'); end if;
    p_ref := v_exam || ':' || v_year;
  end if;
  insert into public.ad_rewards (user_id, kind, ref) values (v_uid, p_kind, coalesce(p_ref, '')) returning id into v_id;
  return jsonb_build_object('ok', true, 'nonce', v_id, 'test', coalesce((c ->> 'test')::boolean, true));
end;
$$;

create or replace function private.ad_reward_apply(p_nonce uuid, p_user uuid, p_tx text, p_unit text, p_via text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.ad_rewards; s jsonb; rule jsonb; v_need integer; v_count integer; v_done boolean := true;
begin
  select * into r from public.ad_rewards where id = p_nonce for update;
  if not found or r.user_id <> p_user then return jsonb_build_object('ok', false, 'why', 'missing'); end if;
  if r.status in ('granted', 'counted') then return jsonb_build_object('ok', true, 'already', true); end if;
  if r.created_at < now() - interval '2 hours' then
    update public.ad_rewards set status = 'expired' where id = p_nonce;
    return jsonb_build_object('ok', false, 'why', 'expired');
  end if;
  select value -> 'rewards' into s from public.app_settings where key = 'ads';
  s := coalesce(s, '{}'::jsonb);
  rule := private.reward_rule(r.kind, coalesce(r.ref, ''));
  if r.kind in ('xp', 'year', 'item') then
    v_need := greatest(coalesce((rule ->> 'need')::int, 1), 1);
    insert into public.ad_progress as p (user_id, kind, ref, count) values (p_user, r.kind, coalesce(r.ref, ''), 1)
    on conflict (user_id, kind, ref) do update set count = p.count + 1, updated_at = now()
    returning count into v_count;
    v_done := v_count >= v_need;
    if v_done then update public.ad_progress set count = 0 where user_id = p_user and kind = r.kind and ref = coalesce(r.ref, ''); end if;
  end if;
  if v_done then
    if r.kind = 'ai_prompts' then
      insert into public.ai_usage as u (user_id, day, used) values (p_user, private.ai_day(), -coalesce((s ->> 'ai_prompts')::int, 2))
      on conflict (user_id, day) do update set used = u.used - coalesce((s ->> 'ai_prompts')::int, 2);
    elsif r.kind = 'streak_freeze' then
      update public.profiles set streak_freezes = least(streak_freezes + coalesce((s ->> 'streak_freeze')::int, 1), 2) where id = p_user;
    elsif r.kind = 'xp' then
      perform private.xp_add(p_user, greatest(coalesce((s ->> 'xp_amount')::int, 5), 1), 'bought', 'ad_reward', p_nonce::text, 'ad:' || p_nonce, false);
    end if;
  end if;
  update public.ad_rewards set status = case when v_done then 'granted' else 'counted' end, granted_at = now(),
         transaction_id = p_tx, ad_unit = p_unit, via = p_via,
         expires_at = case when not v_done or r.kind not in ('note', 'year', 'item') then null
                           else now() + make_interval(mins => coalesce((rule ->> 'minutes')::int, 60)) end
  where id = p_nonce;
  insert into public.ad_daily (format, placement, impressions) values ('rewarded', 'granted:' || r.kind, 1)
  on conflict (day, format, placement) do update set impressions = public.ad_daily.impressions + 1;
  return jsonb_build_object('ok', true, 'done', v_done, 'count', v_count, 'need', v_need);
end;
$$;

create or replace function public.ad_reward_status(p_nonce uuid, p_test_claim boolean default false) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.ad_rewards; v_test boolean; v_count integer;
begin
  select * into r from public.ad_rewards where id = p_nonce and user_id = (select auth.uid());
  if not found then return jsonb_build_object('status', 'missing'); end if;
  if r.status = 'pending' and p_test_claim then
    select coalesce((value ->> 'test_mode')::boolean, true) into v_test from public.app_settings where key = 'ads';
    if v_test then
      perform private.ad_reward_apply(p_nonce, r.user_id, 'test:' || p_nonce, null, 'test');
      select * into r from public.ad_rewards where id = p_nonce;
    end if;
  end if;
  select p.count into v_count from public.ad_progress p where p.user_id = r.user_id and p.kind = r.kind and p.ref = coalesce(r.ref, '');
  return jsonb_build_object('status', r.status, 'kind', r.kind, 'ref', r.ref, 'expires_at', r.expires_at,
                            'count', coalesce(v_count, 0),
                            'need', case when r.kind in ('xp', 'year', 'item') then (private.reward_rule(r.kind, coalesce(r.ref, '')) ->> 'need')::int end);
end;
$$;

-- What a locked item or year offers this student (the app's "how to open" sheet).
create or replace function public.content_offer(p_kind text, p_ref text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare o jsonb; v_open boolean; v_exam smallint; v_year smallint; c jsonb := public.ads_config(); v_prog integer;
begin
  if (select auth.uid()) is null then return jsonb_build_object('ok', false); end if;
  if p_kind = 'item' then
    o := private.item_offer(nullif(p_ref, '')::uuid);
    if o is null then return jsonb_build_object('ok', false); end if;
    select private.study_open(i.kind, i.is_free, i.id) into v_open from public.study_items i where i.id = p_ref::uuid;
  elsif p_kind = 'year' then
    v_exam := split_part(p_ref, ':', 1)::smallint; v_year := split_part(p_ref, ':', 2)::smallint;
    o := private.year_offer(v_exam, v_year);
    v_open := private.year_open(v_exam, v_year, 'cbt') or private.year_open(v_exam, v_year, 'pq');
    if o ->> 'mode' = 'default' then
      o := o || jsonb_build_object('ads', (private.reward_rule('year', p_ref) ->> 'need')::int,
                                   'minutes', (private.reward_rule('year', p_ref) ->> 'minutes')::int);
    end if;
  else
    return jsonb_build_object('ok', false);
  end if;
  select p.count into v_prog from public.ad_progress p where p.user_id = (select auth.uid()) and p.kind = p_kind and p.ref = p_ref;
  return o || jsonb_build_object('ok', true, 'open', coalesce(v_open, false), 'premium', private.has_premium(),
    'bought', private.bought(p_kind, p_ref), 'progress', coalesce(v_prog, 0),
    'ads_on', coalesce((c ->> 'on')::boolean, false) and coalesce((c -> 'formats' ->> 'rewarded')::boolean, true),
    'rewarded_left', coalesce((c ->> 'rewarded_left')::int, 0));
end;
$$;
revoke all on function public.content_offer(text, text) from public, anon;
grant execute on function public.content_offer(text, text) to authenticated;

-- Paying for one item or year (called by the paystack Edge Function with the student's id; the price is the server's).
create or replace function public.content_pay_start(p_uid uuid, p_kind text, p_ref text, p_source text default 'app') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare o jsonb; v_ref text; v_pay uuid; v_email text; v_price integer; v_title text; v_exam smallint; v_year smallint;
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
  insert into public.pay_attempts (user_id, action, ok) values (p_uid, 'start', true);
  select u.email into v_email from auth.users u where u.id = p_uid;
  v_ref := 'st_' || encode(extensions.gen_random_bytes(10), 'hex');
  insert into public.payments (user_id, provider, plan_id, item_kind, item_ref, reference, list_kobo, discount_kobo, amount_kobo, source)
  values (p_uid, 'paystack', null, p_kind, p_ref, v_ref, v_price, 0, v_price, case when p_source = 'web' then 'web' else 'app' end)
  returning id into v_pay;
  insert into public.payment_events (payment_id, provider, kind, ok, note, data)
  values (v_pay, 'server', 'started', true, 'Item: ' || left(coalesce(v_title, p_ref), 80) || ' for ₦' || (v_price / 100),
          jsonb_build_object('kind', p_kind, 'ref', p_ref, 'amount_kobo', v_price));
  return jsonb_build_object('ok', true, 'payment_id', v_pay, 'reference', v_ref, 'amount_kobo', v_price, 'email', v_email, 'title', v_title);
end;
$$;
revoke all on function public.content_pay_start(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.content_pay_start(uuid, text, text, text) to service_role;

create or replace function private.finish_payment(p_pay uuid, p_source public.entitlement_source)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare p public.payments; v_ent uuid; v_plan_name text;
begin
  select * into p from public.payments where id = p_pay;
  if p.item_kind is not null then
    insert into public.content_purchases (user_id, kind, ref, payment_id) values (p.user_id, p.item_kind, p.item_ref, p.id)
    on conflict (user_id, kind, ref) do nothing;
    update public.payments set status = 'success', verified_at = coalesce(verified_at, now()) where id = p.id;
    insert into public.payment_events (payment_id, provider, kind, ok, note)
    values (p.id, 'server', 'item_given', true, 'Opened for good: ' || p.item_kind || ' ' || p.item_ref);
    insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
    values ('account', 'It is yours', 'Thanks! What you paid for is open for good.', 'user', p.user_id, 'scheduled', now(), 'premium', null);
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

-- Admin: kind defaults, per-year rules.
create or replace function public.admin_content_access() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  return jsonb_build_object(
    'defaults', (select value from public.app_settings where key = 'content_access'),
    'years', coalesce((select jsonb_agg(to_jsonb(a) || jsonb_build_object('exam', e.code) order by e.code, a.year desc)
                       from public.year_access a join public.exam_bodies e on e.id = a.exam_id), '[]'::jsonb),
    'exams', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'code', e.code,
                         'years', (select jsonb_agg(distinct y.year) from public.exam_years y where y.exam_id = e.id and y.status = 'published')) order by e.id)
                       from public.exam_bodies e where e.is_active), '[]'::jsonb),
    'sales', coalesce((select jsonb_agg(x) from (
        select p.item_kind as kind, p.item_ref as ref, count(*) as sold, sum(p.amount_kobo) as kobo
        from public.payments p where p.item_kind is not null and p.status = 'success'
        group by 1, 2 order by 4 desc limit 50) x), '[]'::jsonb));
end;
$$;
revoke all on function public.admin_content_access() from public, anon;
grant execute on function public.admin_content_access() to authenticated;

create or replace function public.admin_content_access_save(p_defaults jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_old jsonb;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  select value into v_old from public.app_settings where key = 'content_access';
  insert into public.app_settings (key, value, is_public) values ('content_access', p_defaults, false)
  on conflict (key) do update set value = excluded.value, updated_at = now(), updated_by = (select auth.uid());
  insert into public.audit_log (actor, action, table_name, row_id, before, after)
  values ((select auth.uid()), 'content_access.save', 'app_settings', 'content_access', v_old, p_defaults);
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.admin_content_access_save(jsonb) from public, anon;
grant execute on function public.admin_content_access_save(jsonb) to authenticated;

create or replace function public.admin_year_access_save(p_exam smallint, p_year smallint, p_access text, p_ads smallint, p_hours smallint,
                                                         p_price_kobo integer, p_premium_pays boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_old jsonb;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  select to_jsonb(a) into v_old from public.year_access a where a.exam_id = p_exam and a.year = p_year;
  if p_access is null or p_access = 'default' then
    delete from public.year_access where exam_id = p_exam and year = p_year;
  else
    if p_access = 'pay' and coalesce(p_price_kobo, 0) < 5000 then raise exception 'Set a price of at least ₦50.'; end if;
    insert into public.year_access (exam_id, year, access, ad_count, ad_hours, price_kobo, pay_premium)
    values (p_exam, p_year, p_access, p_ads, p_hours, p_price_kobo, p_premium_pays)
    on conflict (exam_id, year) do update set access = excluded.access, ad_count = excluded.ad_count, ad_hours = excluded.ad_hours,
      price_kobo = excluded.price_kobo, pay_premium = excluded.pay_premium, updated_at = now();
  end if;
  insert into public.audit_log (actor, action, table_name, row_id, before, after)
  values ((select auth.uid()), 'year_access.save', 'year_access', p_exam || ':' || p_year, v_old,
          jsonb_build_object('access', p_access, 'ads', p_ads, 'hours', p_hours, 'price_kobo', p_price_kobo, 'premium_pays', p_premium_pays));
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.admin_year_access_save(smallint, smallint, text, smallint, smallint, integer, boolean) from public, anon;
grant execute on function public.admin_year_access_save(smallint, smallint, text, smallint, smallint, integer, boolean) to authenticated;
