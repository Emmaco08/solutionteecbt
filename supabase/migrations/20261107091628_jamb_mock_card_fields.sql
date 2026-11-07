-- Challenge cards tell the app about JAMB mocks: style, access, time, results and whether this student may enter.
do $do$
declare d text;
begin
  select pg_get_functiondef('private.challenge_card(public.challenges,uuid)'::regprocedure) into d;
  if position('''style'', c.style' in d) > 0 then return; end if;
  d := replace(d, $a$'min_win_pct', c.min_win_pct, 'bg_dark', c.bg_dark,$a$,
    $b$'min_win_pct', c.min_win_pct, 'bg_dark', c.bg_dark,
    'style', c.style, 'access', c.access, 'duration_minutes', c.duration_minutes, 'results', c.results,
    'allowed_exits', c.allowed_exits, 'max_away_seconds', c.max_away_seconds, 'exit_action', c.exit_action,
    'unlocked', p_uid is not null and private.mock_allowed(c, p_uid),$b$);
  if position('''style'', c.style' in d) = 0 then raise exception 'challenge_card marker not found'; end if;
  execute d;
end
$do$;
