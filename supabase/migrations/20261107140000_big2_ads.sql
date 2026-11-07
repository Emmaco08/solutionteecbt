-- Big update 2, step B: Google AdMob ads (docs/plans/big-update-2.md, D-101).
-- Admin level Off..Ultra in app_settings 'ads'; Premium never sees ads; red line (exam, CBT, checkout) is in the app.
-- Rewarded "watch to unlock" is granted ONLY by the server: AdMob server-side verification (Edge Function admob-ssv)
-- calls ad_reward_grant; test mode (Google test ads, which send no verification) may claim from the app.

-- ---------------------------------------------------------------- settings
insert into public.app_settings (key, value, is_public)
values ('ads', jsonb_build_object(
  'level', 'off', 'test_mode', true,
  'formats', jsonb_build_object('banner', true, 'native', true, 'interstitial', true, 'rewarded', true),
  'units', jsonb_build_object('banner', '', 'native', '', 'interstitial', '', 'rewarded', ''),
  'rewards', jsonb_build_object('ai_prompts', 2, 'note_hours', 24, 'streak_freeze', 1)), false)
on conflict (key) do nothing;

-- ---------------------------------------------------------------- age (personalised ads only 18+)
alter table public.profiles add column if not exists birth_year smallint check (birth_year is null or birth_year between 1940 and 2030);

create or replace function public.set_birth_year(p_year integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_now integer := extract(year from now())::int;
begin
  if (select auth.uid()) is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  if p_year < v_now - 80 or p_year > v_now - 6 then return jsonb_build_object('ok', false, 'why', 'year'); end if;
  update public.profiles set birth_year = p_year where id = (select auth.uid()) and birth_year is null;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.set_birth_year(integer) from public, anon;
grant execute on function public.set_birth_year(integer) to authenticated;

-- ---------------------------------------------------------------- what this student sees
/** Level presets. native_every: a native ad after every N list items (0 = none). */
create or replace function private.ads_preset(p_level text) returns jsonb language sql immutable set search_path = '' as $$
  select case p_level
    when 'low'        then '{"banner_screens":[],"native_every":12,"interstitial_gap_s":600,"interstitial_per_day":2,"rewarded_per_day":3,"after_video":false}'
    when 'medium'     then '{"banner_screens":["study","news"],"native_every":8,"interstitial_gap_s":360,"interstitial_per_day":4,"rewarded_per_day":5,"after_video":false}'
    when 'high'       then '{"banner_screens":["study","news","notes","pq","leaderboard"],"native_every":6,"interstitial_gap_s":240,"interstitial_per_day":6,"rewarded_per_day":6,"after_video":false}'
    when 'high_extra' then '{"banner_screens":["study","news","notes","pq","leaderboard","history","challenges"],"native_every":5,"interstitial_gap_s":180,"interstitial_per_day":8,"rewarded_per_day":8,"after_video":true}'
    when 'max'        then '{"banner_screens":["study","news","notes","pq","leaderboard","history","challenges","videos"],"native_every":4,"interstitial_gap_s":150,"interstitial_per_day":10,"rewarded_per_day":10,"after_video":true}'
    when 'ultra'      then '{"banner_screens":["study","news","notes","pq","leaderboard","history","challenges","videos","me"],"native_every":3,"interstitial_gap_s":120,"interstitial_per_day":14,"rewarded_per_day":12,"after_video":true}'
    else '{"banner_screens":[],"native_every":0,"interstitial_gap_s":0,"interstitial_per_day":0,"rewarded_per_day":0,"after_video":false}'
  end::jsonb;
$$;

create or replace function public.ads_config() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare s jsonb; v_uid uuid := (select auth.uid()); v_by smallint; v_age integer; v_group text; v_level text;
begin
  select value into s from public.app_settings where key = 'ads';
  s := coalesce(s, '{}'::jsonb);
  v_level := coalesce(s ->> 'level', 'off');
  select birth_year into v_by from public.profiles where id = v_uid;
  v_age := case when v_by is null then null else extract(year from now())::int - v_by end;
  v_group := case when v_age is null then 'unknown' when v_age < 13 then 'child' when v_age < 18 then 'teen' else 'adult' end;
  if v_uid is null or v_level = 'off' or private.has_premium(v_uid) then
    return jsonb_build_object('on', false, 'premium', v_uid is not null and private.has_premium(v_uid), 'age_group', v_group, 'ask_birth_year', v_by is null);
  end if;
  return jsonb_build_object(
    'on', true, 'level', v_level, 'test', coalesce((s ->> 'test_mode')::boolean, true),
    'formats', coalesce(s -> 'formats', '{}'::jsonb), 'units', coalesce(s -> 'units', '{}'::jsonb),
    'rewards', coalesce(s -> 'rewards', '{}'::jsonb), 'age_group', v_group, 'ask_birth_year', v_by is null,
    'personalised', v_group = 'adult',
    'rewarded_left', greatest(0, (private.ads_preset(v_level) ->> 'rewarded_per_day')::int
                      - (select count(*) from public.ad_rewards r where r.user_id = v_uid and r.status = 'granted' and r.created_at > now() - interval '24 hours')::int)
  ) || private.ads_preset(v_level);
end;
$$;

-- ---------------------------------------------------------------- stats (admin report)
create table if not exists public.ad_daily (
  day date not null default (now() at time zone 'Africa/Lagos')::date,
  format text not null check (format in ('banner', 'native', 'interstitial', 'rewarded')),
  placement text not null default '',
  impressions integer not null default 0,
  clicks integer not null default 0,
  primary key (day, format, placement)
);
alter table public.ad_daily enable row level security;
drop policy if exists ad_daily_staff on public.ad_daily;
create policy ad_daily_staff on public.ad_daily for select to authenticated using (private.is_staff());

/** The app sends counts in batches: [{format, placement, impressions, clicks}]. */
create or replace function public.ads_log(p_events jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare e jsonb;
begin
  if (select auth.uid()) is null or jsonb_typeof(p_events) <> 'array' then return; end if;
  for e in select * from jsonb_array_elements(p_events) limit 50 loop
    if e ->> 'format' not in ('banner', 'native', 'interstitial', 'rewarded') then continue; end if;
    insert into public.ad_daily (format, placement, impressions, clicks)
    values (e ->> 'format', left(coalesce(e ->> 'placement', ''), 30),
            least(greatest(coalesce((e ->> 'impressions')::int, 0), 0), 50), least(greatest(coalesce((e ->> 'clicks')::int, 0), 0), 20))
    on conflict (day, format, placement) do update set impressions = public.ad_daily.impressions + excluded.impressions,
                                                      clicks = public.ad_daily.clicks + excluded.clicks;
  end loop;
end;
$$;
revoke all on function public.ads_log(jsonb) from public, anon;
grant execute on function public.ads_log(jsonb) to authenticated;

-- ---------------------------------------------------------------- rewarded unlocks (granted by the server only)
-- Extra AI prompts from an ad lower today's used count below zero (at most 50 extra a day).
do $$
declare c text;
begin
  select conname into c from pg_constraint where conrelid = 'public.ai_usage'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%used >= 0%';
  if c is not null then execute format('alter table public.ai_usage drop constraint %I', c); end if;
end $$;
alter table public.ai_usage drop constraint if exists ai_usage_used_floor;
alter table public.ai_usage add constraint ai_usage_used_floor check (used >= -50);

create table if not exists public.ad_rewards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('ai_prompts', 'note', 'streak_freeze')),
  ref text,
  status text not null default 'pending' check (status in ('pending', 'granted', 'expired')),
  transaction_id text unique,
  ad_unit text,
  via text check (via in ('ssv', 'test')),
  created_at timestamptz not null default now(),
  granted_at timestamptz,
  expires_at timestamptz
);
create index if not exists ad_rewards_user on public.ad_rewards (user_id, created_at desc);
alter table public.ad_rewards enable row level security;
drop policy if exists ad_rewards_own on public.ad_rewards;
create policy ad_rewards_own on public.ad_rewards for select to authenticated using (user_id = (select auth.uid()) or private.is_staff());

/** Is this study item open for the student through a watched ad? */
create or replace function private.ad_unlocked(p_kind text, p_ref text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.ad_rewards r where r.user_id = (select auth.uid()) and r.kind = p_kind and r.ref = p_ref
                 and r.status = 'granted' and (r.expires_at is null or r.expires_at > now()));
$$;

/** Step 1 (app): ask for a reward. Returns a nonce the app passes to AdMob as custom_data. */
create or replace function public.ad_reward_start(p_kind text, p_ref text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c jsonb := public.ads_config(); v_id uuid; v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  if coalesce((c ->> 'on')::boolean, false) is false or coalesce((c -> 'formats' ->> 'rewarded')::boolean, true) is false then
    return jsonb_build_object('ok', false, 'why', 'off');
  end if;
  if coalesce((c ->> 'rewarded_left')::int, 0) <= 0 then return jsonb_build_object('ok', false, 'why', 'cap'); end if;
  if p_kind not in ('ai_prompts', 'note', 'streak_freeze') then return jsonb_build_object('ok', false, 'why', 'kind'); end if;
  if p_kind = 'note' and not exists (select 1 from public.study_items i where i.id::text = p_ref and i.status = 'published' and i.deleted_at is null) then
    return jsonb_build_object('ok', false, 'why', 'missing');
  end if;
  if p_kind = 'streak_freeze' and (select streak_freezes from public.profiles where id = v_uid) >= 2 then
    return jsonb_build_object('ok', false, 'why', 'full');
  end if;
  insert into public.ad_rewards (user_id, kind, ref) values (v_uid, p_kind, p_ref) returning id into v_id;
  return jsonb_build_object('ok', true, 'nonce', v_id, 'test', coalesce((c ->> 'test')::boolean, true));
end;
$$;
revoke all on function public.ad_reward_start(text, text) from public, anon;
grant execute on function public.ad_reward_start(text, text) to authenticated;

/** Applies a reward once (from admob-ssv with the service role, or the test claim). */
create or replace function private.ad_reward_apply(p_nonce uuid, p_user uuid, p_tx text, p_unit text, p_via text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.ad_rewards; s jsonb;
begin
  select * into r from public.ad_rewards where id = p_nonce for update;
  if not found or r.user_id <> p_user then return jsonb_build_object('ok', false, 'why', 'missing'); end if;
  if r.status = 'granted' then return jsonb_build_object('ok', true, 'already', true); end if;
  if r.created_at < now() - interval '2 hours' then
    update public.ad_rewards set status = 'expired' where id = p_nonce;
    return jsonb_build_object('ok', false, 'why', 'expired');
  end if;
  select value -> 'rewards' into s from public.app_settings where key = 'ads';
  if r.kind = 'ai_prompts' then
    insert into public.ai_usage as u (user_id, day, used) values (p_user, private.ai_day(), -coalesce((s ->> 'ai_prompts')::int, 2))
    on conflict (user_id, day) do update set used = u.used - coalesce((s ->> 'ai_prompts')::int, 2);
  elsif r.kind = 'streak_freeze' then
    update public.profiles set streak_freezes = least(streak_freezes + coalesce((s ->> 'streak_freeze')::int, 1), 2) where id = p_user;
  end if;
  update public.ad_rewards set status = 'granted', granted_at = now(), transaction_id = p_tx, ad_unit = p_unit, via = p_via,
         expires_at = case when r.kind = 'note' then now() + make_interval(hours => coalesce((s ->> 'note_hours')::int, 24)) end
  where id = p_nonce;
  insert into public.ad_daily (format, placement, impressions) values ('rewarded', 'granted:' || r.kind, 1)
  on conflict (day, format, placement) do update set impressions = public.ad_daily.impressions + 1;
  return jsonb_build_object('ok', true);
end;
$$;

/** Called by the admob-ssv Edge Function (service role) after it checked Google's signature. */
create or replace function public.ad_reward_grant(p_nonce uuid, p_user uuid, p_tx text, p_unit text) returns jsonb
language sql security definer set search_path = '' as $$ select private.ad_reward_apply(p_nonce, p_user, p_tx, p_unit, 'ssv') $$;
revoke all on function public.ad_reward_grant(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.ad_reward_grant(uuid, uuid, text, text) to service_role;

/** Step 2 (app): has the reward arrived? In test mode (Google test ads send no verification) the app may claim it. */
create or replace function public.ad_reward_status(p_nonce uuid, p_test_claim boolean default false) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.ad_rewards; v_test boolean;
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
  return jsonb_build_object('status', r.status, 'kind', r.kind, 'ref', r.ref, 'expires_at', r.expires_at);
end;
$$;
revoke all on function public.ad_reward_status(uuid, boolean) from public, anon;
grant execute on function public.ad_reward_status(uuid, boolean) to authenticated;

-- A study item (note, video, novel) opened by a watched ad is served like a free one, for the unlock time only.
do $$
declare d text;
begin
  select pg_get_functiondef('public.study_item'::regproc) into d;
  if position('ad_unlocked' in d) = 0 then
    execute replace(d, 'if not private.study_open(r.kind, r.is_free) then',
                       'if not private.study_open(r.kind, r.is_free) and not private.ad_unlocked(''note'', r.id::text) then');
  end if;
end $$;

-- ---------------------------------------------------------------- admin report and settings
create or replace function public.admin_ads_report(p_days integer default 30) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  return jsonb_build_object(
    'settings', (select value from public.app_settings where key = 'ads'),
    'days', coalesce((select jsonb_agg(d order by d.day desc) from (
      select day,
             sum(impressions) filter (where format = 'banner') as banner,
             sum(impressions) filter (where format = 'native') as native,
             sum(impressions) filter (where format = 'interstitial') as interstitial,
             sum(impressions) filter (where format = 'rewarded' and placement not like 'granted:%') as rewarded_shown,
             sum(impressions) filter (where format = 'rewarded' and placement like 'granted:%') as unlocks,
             sum(clicks) as clicks
      from public.ad_daily where day > (now() at time zone 'Africa/Lagos')::date - least(greatest(p_days, 1), 180)
      group by day) d), '[]'::jsonb),
    'unlocks', coalesce((select jsonb_object_agg(kind, n) from (
      select kind, count(*) as n from public.ad_rewards where status = 'granted' and granted_at > now() - interval '30 days' group by kind) k), '{}'::jsonb));
end;
$$;
revoke all on function public.admin_ads_report(integer) from public, anon;
grant execute on function public.admin_ads_report(integer) to authenticated;

create or replace function public.admin_ads_save(p_value jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_old jsonb;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  if coalesce(p_value ->> 'level', '') not in ('off', 'low', 'medium', 'high', 'high_extra', 'max', 'ultra') then raise exception 'Bad level'; end if;
  select value into v_old from public.app_settings where key = 'ads';
  insert into public.app_settings (key, value, is_public) values ('ads', p_value, false)
  on conflict (key) do update set value = excluded.value, updated_at = now(), updated_by = (select auth.uid());
  insert into public.audit_log (actor, action, table_name, row_id, before, after)
  values ((select auth.uid()), 'ads.save', 'app_settings', 'ads', v_old, p_value);
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.admin_ads_save(jsonb) from public, anon;
grant execute on function public.admin_ads_save(jsonb) to authenticated;

revoke all on function public.ads_config() from public, anon;
grant execute on function public.ads_config() to authenticated;
