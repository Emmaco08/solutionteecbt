-- Game Zone settings: one entry per game (games.gz.games.<game>.on / xp_play / xp_win / ...), shared defaults in games.gz.
update public.app_settings set value = jsonb_set(value, '{gz}',
  ((value -> 'gz') - 'on') || jsonb_build_object('games', coalesce(value -> 'gz' -> 'games', '{}') || (
    select coalesce(jsonb_object_agg(k, jsonb_build_object('on', v)), '{}') from jsonb_each(coalesce(value -> 'gz' -> 'on', '{}')) e(k, v)
    where jsonb_typeof(value -> 'gz' -> 'on') = 'object')))
where key = 'games';

create or replace function private.gz_set(p_game text, p_key text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(private.games_settings() -> 'gz' -> 'games' -> p_game -> p_key,
    case when p_key <> 'on' then private.games_settings() -> 'gz' -> p_key end);
$$;
