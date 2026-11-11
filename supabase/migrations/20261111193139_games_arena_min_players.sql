-- Arena top-3 XP only with points above 0 and at least 5 players who answered (admin: games.arena_min_players).
update public.app_settings set value = value || '{"arena_min_players": 5}'::jsonb where key = 'games' and not value ? 'arena_min_players';
do $$
declare d text := pg_get_functiondef('private.arenas_job()'::regprocedure);
begin
  d := replace(d, $r$declare a public.arenas; s jsonb := private.games_settings() -> 'xp'; r record; v_xp integer; v_place integer;$r$,
                  $r$declare a public.arenas; s jsonb := private.games_settings() -> 'xp'; r record; v_xp integer; v_place integer; v_n integer;
  v_min integer := coalesce((private.games_settings() ->> 'arena_min_players')::int, 5);$r$);
  d := replace(d, $r$    v_place := 0;
    for r in select p.user_id from$r$, $r$    v_place := 0;
    select count(distinct aa.user_id) into v_n from public.arena_answers aa where aa.arena_id = a.id;
    for r in select p.user_id, p.score from$r$);
  d := replace(d, $r$      if v_place <= 3 then$r$, $r$      if v_place <= 3 and r.score > 0 and v_n >= v_min then$r$);
  if position('v_n >= v_min' in d) = 0 or position('p.user_id, p.score' in d) = 0 then raise exception 'arenas_job not changed'; end if;
  execute d;
end $$;

