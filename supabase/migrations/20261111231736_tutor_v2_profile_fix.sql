-- Student details for the tutor: streak from private.streak(), test scores from attempts.server_score.
do $$
declare d text := pg_get_functiondef('public.tutor_student_profile(uuid)'::regprocedure);
begin
  d := replace(d, $r$'streak', (select to_jsonb(x) - 'user_id' from (select * from public.streaks st where st.user_id = p.id) x),$r$,
                  $r$'streak', (select jsonb_build_object('current', s.current_days, 'longest', s.longest_days, 'today', s.today_done) from private.streak(p.id) s),$r$);
  d := replace(d, $r$jsonb_build_object('at', a.submitted_at, 'mode', a.mode, 'score', a.score, 'total', a.total)$r$,
                  $r$jsonb_build_object('at', a.submitted_at, 'mode', a.mode, 'correct', a.server_score -> 'correct', 'answered', a.server_score -> 'answered',
                     'questions', a.server_score -> 'questions', 'score', a.server_score -> 'total', 'max', a.server_score -> 'max')$r$);
  if position('private.streak(p.id)' in d) = 0 or position('server_score' in d) = 0 then raise exception 'not changed'; end if;
  execute d;
end $$;

