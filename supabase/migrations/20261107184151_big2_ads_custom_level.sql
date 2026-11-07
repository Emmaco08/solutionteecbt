-- Custom ads level (owner, 2026-11-07): the admin's own rules in app_settings.ads.custom, on top of Medium's defaults.
create or replace function private.ads_rules(s jsonb) returns jsonb language sql stable set search_path = '' as $$
  select case when coalesce(s ->> 'level', 'off') = 'custom'
              then private.ads_preset('medium') || coalesce(s -> 'custom', '{}'::jsonb)
              else private.ads_preset(coalesce(s ->> 'level', 'off')) end;
$$;

do $$
declare d text;
begin
  select pg_get_functiondef('public.ads_config()'::regprocedure) into d;
  if position('ads_rules' in d) = 0 then
    d := replace(d, '(private.ads_preset(v_level) ->> ''rewarded_per_day'')::int', '(private.ads_rules(s) ->> ''rewarded_per_day'')::int');
    d := replace(d, ') || private.ads_preset(v_level);', ') || private.ads_rules(s);');
    execute d;
  end if;
  select pg_get_functiondef('public.admin_ads_save(jsonb)'::regprocedure) into d;
  if position('''custom''' in d) = 0 then
    execute replace(d, '''max'', ''ultra'')', '''max'', ''ultra'', ''custom'')');
  end if;
end $$;
