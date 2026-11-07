-- The app now also reports ad load results as placement "name#ok" / "name#e<code>" (to find why an ad does not show).
-- They are not ads seen: the report counts only rows without "#", and lists the load results separately.
create or replace function public.admin_ads_report(p_days integer default 30) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  return jsonb_build_object(
    'settings', (select value from public.app_settings where key = 'ads'),
    'days', coalesce((select jsonb_agg(d order by d.day desc) from (
      select day,
             sum(impressions) filter (where format = 'banner' and placement not like '%#%') as banner,
             sum(impressions) filter (where format = 'native' and placement not like '%#%') as native,
             sum(impressions) filter (where format = 'interstitial' and placement not like '%#%') as interstitial,
             sum(impressions) filter (where format = 'rewarded' and placement not like 'granted:%' and placement not like '%#%') as rewarded_shown,
             sum(impressions) filter (where format = 'rewarded' and placement like 'granted:%') as unlocks,
             sum(clicks) as clicks
      from public.ad_daily where day > (now() at time zone 'Africa/Lagos')::date - least(greatest(p_days, 1), 180)
      group by day) d), '[]'::jsonb),
    'unlocks', coalesce((select jsonb_object_agg(kind, n) from (
      select kind, count(*) as n from public.ad_rewards where status = 'granted' and granted_at > now() - interval '30 days' group by kind) k), '{}'::jsonb),
    'loads', coalesce((select jsonb_object_agg(format || ' ' || placement, n) from (
      select format, placement, sum(impressions) as n from public.ad_daily
      where placement like '%#%' and day > (now() at time zone 'Africa/Lagos')::date - 7 group by format, placement) l), '{}'::jsonb));
end;
$$;
