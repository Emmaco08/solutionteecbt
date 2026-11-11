-- Friend duels are played in turn (D-150): the host plays at once and shares the code; the friend plays when they join.
do $$
declare d text := pg_get_functiondef('public.game_next(uuid)'::regprocedure);
begin
  d := replace(d, $r$  if g.status = 'waiting' then
    return jsonb_build_object('status', 'waiting', 'code', g.code, 'mode', g.mode, 'subject_id', g.subject_id, 'expires_at', g.expires_at);
  end if;
$r$, '');
  d := replace(d, $r$return jsonb_build_object('status', 'finished', 'mode', g.mode,$r$,
                  $r$return jsonb_build_object('status', 'finished', 'code', case when g.host = v_uid then g.code end, 'waiting', g.status = 'waiting', 'exam_id', g.exam_id, 'mode', g.mode,$r$);
  d := replace(d, $r$return jsonb_build_object('status', 'playing', 'mode', g.mode,$r$,
                  $r$return jsonb_build_object('status', 'playing', 'code', case when g.host = v_uid then g.code end, 'waiting', g.status = 'waiting', 'exam_id', g.exam_id, 'mode', g.mode,$r$);
  if position($r$'status', 'waiting'$r$ in d) > 0 or (length(d) - length(replace(d, '''waiting'', g.status', ''))) = 0 then raise exception 'game_next not changed'; end if;
  execute d;
  d := replace(pg_get_functiondef('public.game_join(text)'::regprocedure), $r$update public.games set status = 'playing' where id = g.id;$r$,
               $r$update public.games set status = 'playing' where id = g.id and status = 'waiting';$r$);
  if position($r$and status = 'waiting'$r$ in d) = 0 then raise exception 'game_join not changed'; end if;
  execute d;
end $$;

