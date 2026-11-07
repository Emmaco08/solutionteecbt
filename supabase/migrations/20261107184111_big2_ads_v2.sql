-- Ads v2 (docs/plans/big2-ads-v2.md, D-104): rebuilt levels, video-first, watch-to-earn XP and "a year for 1 hour".

alter table public.ad_rewards drop constraint if exists ad_rewards_kind_check;
alter table public.ad_rewards add constraint ad_rewards_kind_check check (kind in ('ai_prompts', 'note', 'streak_freeze', 'xp', 'year'));
alter table public.ad_rewards drop constraint if exists ad_rewards_status_check;
alter table public.ad_rewards add constraint ad_rewards_status_check check (status in ('pending', 'counted', 'granted', 'expired'));
create index if not exists ad_rewards_unlock on public.ad_rewards (user_id, kind, ref) where status = 'granted';

create table if not exists public.ad_progress (
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null,
  ref text not null default '',
  count integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, kind, ref)
);
alter table public.ad_progress enable row level security;
drop policy if exists ad_progress_own on public.ad_progress;
create policy ad_progress_own on public.ad_progress for select to authenticated using (user_id = (select auth.uid()) or private.is_staff());

update public.app_settings set value = value
  || jsonb_build_object('rewards', jsonb_build_object('ai_prompts', 2, 'note_hours', 24, 'streak_freeze', 1,
                                                      'year_ads', 1, 'year_minutes', 60, 'xp_ads', 1, 'xp_amount', 5, 'xp_daily_cap', 20)
                                   || coalesce(value -> 'rewards', '{}'::jsonb))
  || jsonb_build_object('units', jsonb_build_object('app_open', '', 'rewarded_interstitial', 'ca-app-pub-2578359096210288/6869781120')
                                 || coalesce(value -> 'units', '{}'::jsonb))
  || jsonb_build_object('formats', jsonb_build_object('app_open', true, 'rewarded_interstitial', true)
                                   || coalesce(value -> 'formats', '{}'::jsonb))
where key = 'ads';

create or replace function private.ads_preset(p_level text) returns jsonb language sql immutable set search_path = '' as $$
  select case p_level
    when 'low' then '{"banner_screens":[],"home_cards":0,"native_every":0,"news_card":true,
      "inter_every_tests":3,"inter_spots":[],"ai_every":0,"interstitial_gap_s":900,"interstitial_per_day":2,
      "app_open_after_min":0,"rint_spots":[],"rewarded_per_day":5,"after_video":false}'
    when 'medium' then '{"banner_screens":["study","news","ai"],"home_cards":1,"native_every":8,"news_card":true,
      "inter_every_tests":2,"inter_spots":["video_end"],"ai_every":0,"interstitial_gap_s":480,"interstitial_per_day":4,
      "app_open_after_min":0,"rint_spots":["test"],"rewarded_per_day":8,"after_video":true}'
    when 'high' then '{"banner_screens":["study","news","ai","home","notes","pq","videos","leaderboard","challenges"],"home_cards":2,"native_every":6,"news_card":true,
      "inter_every_tests":1,"inter_spots":["video_start","video_end"],"ai_every":0,"interstitial_gap_s":300,"interstitial_per_day":8,
      "app_open_after_min":240,"rint_spots":["test","video_end"],"rewarded_per_day":10,"after_video":true}'
    when 'high_extra' then '{"banner_screens":["study","news","ai","home","notes","pq","videos","leaderboard","challenges","results","review","me","history","xp"],"home_cards":2,"native_every":4,"news_card":true,
      "inter_every_tests":1,"inter_spots":["video_start","video_end","note","quiz"],"ai_every":3,"interstitial_gap_s":180,"interstitial_per_day":12,
      "app_open_after_min":60,"rint_spots":["test","video_end","ai"],"rewarded_per_day":15,"after_video":true}'
    when 'max' then '{"banner_screens":["study","news","ai","home","notes","pq","videos","leaderboard","challenges","results","review","me","history","xp","novels","bookmarks"],"home_cards":3,"native_every":3,"news_card":true,
      "inter_every_tests":1,"inter_spots":["video_start","video_end","note","quiz","section"],"ai_every":3,"interstitial_gap_s":120,"interstitial_per_day":18,
      "app_open_after_min":30,"rint_spots":["test","video_end","ai","note"],"rewarded_per_day":20,"after_video":true}'
    when 'ultra' then '{"banner_screens":["study","news","ai","home","notes","pq","videos","leaderboard","challenges","results","review","me","history","xp","novels","bookmarks","settings","notifications"],"home_cards":4,"native_every":2,"news_card":true,
      "inter_every_tests":1,"inter_spots":["video_start","video_end","note","quiz","section","ai"],"ai_every":2,"interstitial_gap_s":90,"interstitial_per_day":25,
      "app_open_after_min":5,"rint_spots":["test","video_end","ai","note","quiz"],"rewarded_per_day":30,"after_video":true}'
    else '{"banner_screens":[],"home_cards":0,"native_every":0,"news_card":false,"inter_every_tests":0,"inter_spots":[],"ai_every":0,
      "interstitial_gap_s":0,"interstitial_per_day":0,"app_open_after_min":0,"rint_spots":[],"rewarded_per_day":0,"after_video":false}'
  end::jsonb;
$$;

create or replace function public.ads_config() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare s jsonb; v_uid uuid := (select auth.uid()); v_by smallint; v_age integer; v_group text; v_level text; r jsonb;
        v_xp_today integer;
begin
  select value into s from public.app_settings where key = 'ads';
  s := coalesce(s, '{}'::jsonb);
  v_level := coalesce(s ->> 'level', 'off');
  r := coalesce(s -> 'rewards', '{}'::jsonb);
  select birth_year into v_by from public.profiles where id = v_uid;
  v_age := case when v_by is null then null else extract(year from now())::int - v_by end;
  v_group := case when v_age is null then 'unknown' when v_age < 13 then 'child' when v_age < 18 then 'teen' else 'adult' end;
  if v_uid is null or v_level = 'off' or private.has_premium(v_uid) then
    return jsonb_build_object('on', false, 'premium', v_uid is not null and private.has_premium(v_uid), 'age_group', v_group, 'ask_birth_year', v_by is null);
  end if;
  select count(*) into v_xp_today from public.ad_rewards x
  where x.user_id = v_uid and x.kind = 'xp' and x.status in ('counted', 'granted') and x.created_at >= private.lagos_day_start();
  return jsonb_build_object(
    'on', true, 'level', v_level, 'test', coalesce((s ->> 'test_mode')::boolean, true),
    'formats', coalesce(s -> 'formats', '{}'::jsonb), 'units', coalesce(s -> 'units', '{}'::jsonb),
    'rewards', r, 'age_group', v_group, 'ask_birth_year', v_by is null, 'personalised', v_group = 'adult',
    'rewarded_left', greatest(0, (private.ads_preset(v_level) ->> 'rewarded_per_day')::int
                      - (select count(*) from public.ad_rewards x where x.user_id = v_uid and x.status in ('counted', 'granted')
                         and x.created_at > now() - interval '24 hours')::int),
    'xp_left', greatest(0, coalesce((r ->> 'xp_daily_cap')::int, 20) - v_xp_today),
    'xp_progress', coalesce((select p.count from public.ad_progress p where p.user_id = v_uid and p.kind = 'xp' and p.ref = ''), 0)
  ) || private.ads_preset(v_level);
end;
$$;

create or replace function private.ad_unlocked(p_kind text, p_ref text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.ad_rewards r where r.user_id = (select auth.uid()) and r.kind = p_kind and r.ref = p_ref
                 and r.status = 'granted' and r.expires_at is not null and r.expires_at > now());
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
  if p_kind not in ('ai_prompts', 'note', 'streak_freeze', 'xp', 'year') then return jsonb_build_object('ok', false, 'why', 'kind'); end if;
  if p_kind = 'note' and not exists (select 1 from public.study_items i where i.id::text = p_ref and i.status = 'published' and i.deleted_at is null) then
    return jsonb_build_object('ok', false, 'why', 'missing');
  end if;
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
    p_ref := v_exam || ':' || v_year;
  end if;
  insert into public.ad_rewards (user_id, kind, ref) values (v_uid, p_kind, coalesce(p_ref, '')) returning id into v_id;
  return jsonb_build_object('ok', true, 'nonce', v_id, 'test', coalesce((c ->> 'test')::boolean, true));
end;
$$;

create or replace function private.ad_reward_apply(p_nonce uuid, p_user uuid, p_tx text, p_unit text, p_via text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.ad_rewards; s jsonb; v_need integer; v_count integer; v_done boolean := true;
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
  if r.kind in ('xp', 'year') then
    v_need := greatest(coalesce((s ->> case when r.kind = 'xp' then 'xp_ads' else 'year_ads' end)::int, 1), 1);
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
         expires_at = case when not v_done then null
                           when r.kind = 'note' then now() + make_interval(hours => coalesce((s ->> 'note_hours')::int, 24))
                           when r.kind = 'year' then now() + make_interval(mins => coalesce((s ->> 'year_minutes')::int, 60)) end
  where id = p_nonce;
  insert into public.ad_daily (format, placement, impressions) values ('rewarded', 'granted:' || r.kind, 1)
  on conflict (day, format, placement) do update set impressions = public.ad_daily.impressions + 1;
  return jsonb_build_object('ok', true, 'done', v_done, 'count', v_count, 'need', v_need);
end;
$$;

create or replace function public.ad_reward_status(p_nonce uuid, p_test_claim boolean default false) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.ad_rewards; v_test boolean; v_need integer; v_count integer;
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
  select greatest(coalesce((value -> 'rewards' ->> case when r.kind = 'xp' then 'xp_ads' else 'year_ads' end)::int, 1), 1)
    into v_need from public.app_settings where key = 'ads';
  select p.count into v_count from public.ad_progress p where p.user_id = r.user_id and p.kind = r.kind and p.ref = coalesce(r.ref, '');
  return jsonb_build_object('status', r.status, 'kind', r.kind, 'ref', r.ref, 'expires_at', r.expires_at,
                            'count', coalesce(v_count, 0), 'need', case when r.kind in ('xp', 'year') then v_need end);
end;
$$;

do $$
declare d text;
begin
  select pg_get_functiondef('private.year_open(smallint,smallint,text)'::regprocedure) into d;
  if position('ad_unlocked' in d) = 0 then
    execute replace(d, 'if (select auth.uid()) is null or private.is_banned() then return false; end if;',
      'if (select auth.uid()) is null or private.is_banned() then return false; end if;
  -- Big update 2 (ads v2): a year opened by watching ads, for the admin''s minutes.
  if private.ad_unlocked(''year'', p_exam::text || '':'' || p_year::text) then return true; end if;');
  end if;
end $$;
