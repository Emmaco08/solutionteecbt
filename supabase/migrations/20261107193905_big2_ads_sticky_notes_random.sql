-- Ads v2, part B2 extras (owner, 2026-11-07): sticky banners (stay at the top/bottom while scrolling), card ads inside
-- lesson notes, and random break pop-ups (Ultra only; still only between screens).
create or replace function private.ads_extras(p_level text) returns jsonb language sql immutable set search_path = '' as $$
  select case p_level
    when 'high' then '{"banner_sticky":"bottom","random_break_pct":0,"note_cards_every":8}'
    when 'high_extra' then '{"banner_sticky":"bottom","random_break_pct":0,"note_cards_every":6}'
    when 'max' then '{"banner_sticky":"bottom","random_break_pct":0,"note_cards_every":4}'
    when 'ultra' then '{"banner_sticky":"both","random_break_pct":15,"note_cards_every":3}'
    else '{"banner_sticky":"off","random_break_pct":0,"note_cards_every":0}'
  end::jsonb;
$$;

create or replace function private.ads_rules(s jsonb) returns jsonb language sql stable set search_path = '' as $$
  select case when coalesce(s ->> 'level', 'off') = 'custom'
              then private.ads_preset('medium') || private.ads_extras('medium') || coalesce(s -> 'custom', '{}'::jsonb)
              else private.ads_preset(coalesce(s ->> 'level', 'off')) || private.ads_extras(coalesce(s ->> 'level', 'off')) end;
$$;
