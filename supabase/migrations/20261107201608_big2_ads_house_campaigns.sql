-- Ads v2, part B3 (owner, 2026-11-07): our own ads (house ads / brand campaigns). The admin adds a brand campaign with
-- a banner, a card, a full-screen break (picture or video) and video ads before, in the middle of or after our own
-- video lessons. Dates, placements, a daily cap per student, a share against AdMob, and views/clicks per day for the
-- brand's report. Files live in the private R2 bucket under public/ads/ and are signed only while a campaign runs.
create table if not exists public.ad_campaigns (
  id uuid primary key default gen_random_uuid(),
  brand text not null check (length(btrim(brand)) between 1 and 80),
  name text not null check (length(btrim(name)) between 1 and 120),
  status text not null default 'draft' check (status in ('draft', 'active', 'paused', 'ended')),
  starts_on date,
  ends_on date,
  placements text[] not null default '{}'
    check (placements <@ array['banner', 'card', 'break', 'video_pre', 'video_mid', 'video_post']::text[]),
  share_pct smallint not null default 50 check (share_pct between 1 and 100),
  cap_per_day smallint not null default 3 check (cap_per_day between 1 and 50),
  weight smallint not null default 1 check (weight between 1 and 10),
  link text check (link is null or link ~ '^https://'),
  cta text not null default 'Learn more' check (length(cta) between 1 and 24),
  banner_key text check (banner_key is null or banner_key like 'public/ads/%'),
  card_key text check (card_key is null or card_key like 'public/ads/%'),
  card_title text check (card_title is null or length(card_title) <= 60),
  card_body text check (card_body is null or length(card_body) <= 140),
  break_kind text not null default 'image' check (break_kind in ('image', 'video')),
  break_key text check (break_key is null or break_key like 'public/ads/%'),
  video_key text check (video_key is null or video_key like 'public/ads/%'),
  skip_after_s smallint not null default 5 check (skip_after_s between 0 and 30),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.ad_campaigns enable row level security;
-- No direct access: students read through house_ads(), staff through the admin functions below.

create table if not exists public.ad_campaign_stats (
  campaign_id uuid not null references public.ad_campaigns (id) on delete cascade,
  day date not null,
  placement text not null,
  views integer not null default 0,
  clicks integer not null default 0,
  primary key (campaign_id, day, placement)
);
alter table public.ad_campaign_stats enable row level security;

create table if not exists public.ad_campaign_seen (
  campaign_id uuid not null references public.ad_campaigns (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  views integer not null default 0,
  primary key (campaign_id, user_id, day)
);
alter table public.ad_campaign_seen enable row level security;
create index if not exists ad_campaign_seen_user on public.ad_campaign_seen (user_id, day);

-- A campaign runs when it is active and today is inside its dates.
create or replace function private.campaign_live(c public.ad_campaigns) returns boolean language sql stable set search_path = '' as $$
  select c.status = 'active' and (c.starts_on is null or c.starts_on <= private.lagos_today())
     and (c.ends_on is null or c.ends_on >= private.lagos_today());
$$;

-- What a student can see: running campaigns, only when this student sees ads (free, level not Off) and is 13 or older
-- (brand ads are not shown to children), with how many views are left today.
create or replace function public.house_ads() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare c jsonb := public.ads_config(); v_uid uuid := (select auth.uid());
begin
  if v_uid is null or coalesce((c ->> 'on')::boolean, false) = false or c ->> 'age_group' = 'child' then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id, 'brand', a.brand, 'placements', a.placements, 'share', a.share_pct, 'weight', a.weight,
      'link', a.link, 'cta', a.cta, 'banner', a.banner_key, 'card', a.card_key, 'card_title', a.card_title,
      'card_body', a.card_body, 'break_kind', a.break_kind, 'break', a.break_key, 'video', a.video_key,
      'skip_after', a.skip_after_s,
      'left', greatest(0, a.cap_per_day - coalesce((select s.views from public.ad_campaign_seen s
                where s.campaign_id = a.id and s.user_id = v_uid and s.day = private.lagos_today()), 0))))
    from public.ad_campaigns a where private.campaign_live(a)), '[]'::jsonb);
end;
$$;
revoke all on function public.house_ads() from public, anon;
grant execute on function public.house_ads() to authenticated;

-- A view or a click of a house ad. Views over the daily cap are not counted (the brand pays for real views).
create or replace function public.house_ad_log(p_campaign uuid, p_placement text, p_click boolean default false) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); a public.ad_campaigns; v_seen integer;
begin
  if v_uid is null then return jsonb_build_object('ok', false); end if;
  if p_placement not in ('banner', 'card', 'break', 'video_pre', 'video_mid', 'video_post') then return jsonb_build_object('ok', false); end if;
  select * into a from public.ad_campaigns where id = p_campaign;
  if not found or not private.campaign_live(a) then return jsonb_build_object('ok', false); end if;
  if p_click then
    -- A click counts only after a counted view today.
    if not exists (select 1 from public.ad_campaign_seen s where s.campaign_id = a.id and s.user_id = v_uid and s.day = private.lagos_today()) then
      return jsonb_build_object('ok', false);
    end if;
    insert into public.ad_campaign_stats (campaign_id, day, placement, clicks) values (a.id, private.lagos_today(), p_placement, 1)
    on conflict (campaign_id, day, placement) do update set clicks = public.ad_campaign_stats.clicks + 1;
    return jsonb_build_object('ok', true);
  end if;
  insert into public.ad_campaign_seen (campaign_id, user_id, day, views) values (a.id, v_uid, private.lagos_today(), 1)
  on conflict (campaign_id, user_id, day) do update set views = public.ad_campaign_seen.views + 1
  returning views into v_seen;
  if v_seen > a.cap_per_day then return jsonb_build_object('ok', false, 'left', 0); end if;
  insert into public.ad_campaign_stats (campaign_id, day, placement, views) values (a.id, private.lagos_today(), p_placement, 1)
  on conflict (campaign_id, day, placement) do update set views = public.ad_campaign_stats.views + 1;
  return jsonb_build_object('ok', true, 'left', a.cap_per_day - v_seen);
end;
$$;
revoke all on function public.house_ad_log(uuid, text, boolean) from public, anon;
grant execute on function public.house_ad_log(uuid, text, boolean) to authenticated;

-- The website signs a public/ads/ file only while a running campaign uses it.
create or replace function public.can_view_ad_file(p_key text) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and exists (
    select 1 from public.ad_campaigns a
    where private.campaign_live(a) and p_key in (a.banner_key, a.card_key, a.break_key, a.video_key));
$$;
revoke all on function public.can_view_ad_file(text) from public, anon;
grant execute on function public.can_view_ad_file(text) to authenticated;

-- Admin: list with totals, save, delete, and the report per campaign (for the brand).
create or replace function public.admin_ad_campaigns() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(to_jsonb(a) || jsonb_build_object(
      'live', private.campaign_live(a),
      'views', coalesce((select sum(s.views) from public.ad_campaign_stats s where s.campaign_id = a.id), 0),
      'clicks', coalesce((select sum(s.clicks) from public.ad_campaign_stats s where s.campaign_id = a.id), 0),
      'students', (select count(distinct x.user_id) from public.ad_campaign_seen x where x.campaign_id = a.id))
    order by a.created_at desc) from public.ad_campaigns a), '[]'::jsonb);
end;
$$;
revoke all on function public.admin_ad_campaigns() from public, anon;
grant execute on function public.admin_ad_campaigns() to authenticated;

create or replace function public.admin_ad_campaign_save(p jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_id uuid := nullif(p ->> 'id', '')::uuid; v_old jsonb; v_row public.ad_campaigns;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  if v_id is not null then select to_jsonb(a) into v_old from public.ad_campaigns a where a.id = v_id; end if;
  if v_id is null then
    insert into public.ad_campaigns (brand, name) values (p ->> 'brand', p ->> 'name') returning id into v_id;
  end if;
  update public.ad_campaigns set
    brand = p ->> 'brand', name = p ->> 'name', status = coalesce(p ->> 'status', 'draft'),
    starts_on = nullif(p ->> 'starts_on', '')::date, ends_on = nullif(p ->> 'ends_on', '')::date,
    placements = coalesce((select array_agg(x) from jsonb_array_elements_text(coalesce(p -> 'placements', '[]'::jsonb)) x), '{}'),
    share_pct = coalesce((p ->> 'share_pct')::smallint, 50), cap_per_day = coalesce((p ->> 'cap_per_day')::smallint, 3),
    weight = coalesce((p ->> 'weight')::smallint, 1), link = nullif(p ->> 'link', ''), cta = coalesce(nullif(p ->> 'cta', ''), 'Learn more'),
    banner_key = nullif(p ->> 'banner_key', ''), card_key = nullif(p ->> 'card_key', ''),
    card_title = nullif(p ->> 'card_title', ''), card_body = nullif(p ->> 'card_body', ''),
    break_kind = coalesce(nullif(p ->> 'break_kind', ''), 'image'), break_key = nullif(p ->> 'break_key', ''),
    video_key = nullif(p ->> 'video_key', ''), skip_after_s = coalesce((p ->> 'skip_after_s')::smallint, 5),
    updated_at = now()
  where id = v_id returning * into v_row;
  if v_row.ends_on is not null and v_row.starts_on is not null and v_row.ends_on < v_row.starts_on then
    raise exception 'The end date is before the start date.';
  end if;
  if v_row.status = 'active' and (
      ('banner' = any(v_row.placements) and v_row.banner_key is null) or
      ('card' = any(v_row.placements) and (v_row.card_key is null or v_row.card_title is null)) or
      ('break' = any(v_row.placements) and v_row.break_key is null) or
      (v_row.placements && array['video_pre', 'video_mid', 'video_post'] and v_row.video_key is null)) then
    raise exception 'Add the file for every place this campaign shows in before turning it on.';
  end if;
  insert into public.audit_log (actor, action, table_name, row_id, before, after)
  values ((select auth.uid()), 'ad_campaign.save', 'ad_campaigns', v_id::text, v_old, to_jsonb(v_row));
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;
revoke all on function public.admin_ad_campaign_save(jsonb) from public, anon;
grant execute on function public.admin_ad_campaign_save(jsonb) to authenticated;

create or replace function public.admin_ad_campaign_delete(p_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_old jsonb;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  select to_jsonb(a) into v_old from public.ad_campaigns a where a.id = p_id;
  delete from public.ad_campaigns where id = p_id;
  insert into public.audit_log (actor, action, table_name, row_id, before, after)
  values ((select auth.uid()), 'ad_campaign.delete', 'ad_campaigns', p_id::text, v_old, null);
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.admin_ad_campaign_delete(uuid) from public, anon;
grant execute on function public.admin_ad_campaign_delete(uuid) to authenticated;

create or replace function public.admin_ad_campaign_report(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  return jsonb_build_object(
    'campaign', (select to_jsonb(a) from public.ad_campaigns a where a.id = p_id),
    'students', (select count(distinct x.user_id) from public.ad_campaign_seen x where x.campaign_id = p_id),
    'rows', coalesce((select jsonb_agg(jsonb_build_object('day', s.day, 'placement', s.placement, 'views', s.views, 'clicks', s.clicks)
                      order by s.day desc, s.placement) from public.ad_campaign_stats s where s.campaign_id = p_id), '[]'::jsonb));
end;
$$;
revoke all on function public.admin_ad_campaign_report(uuid) from public, anon;
grant execute on function public.admin_ad_campaign_report(uuid) to authenticated;
