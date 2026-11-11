-- Fair-play tracking on leaderboard exams (B10, D-144). The app reports, per test: times it left the app, time
-- away and screenshot attempts; per-question times already arrive with the answers. The server turns them into a
-- risk score (0-100). Practice is never blocked: a risky run is only held off the leaderboards for review.
alter table public.attempts add column fair jsonb, add column risk smallint;
create index attempts_risk_idx on public.attempts (risk) where risk >= 30;

-- Risk from the attempt's own record: answers under 3 seconds, a very short median time with high marks, leaving
-- the app, time away, screenshot attempts. Returns {risk, why, fast, answered, median_ms}.
create or replace function private.fair_risk(p_attempt uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare a record; v_ans int; v_fast int; v_med numeric; v_acc numeric; v_away int; v_away_s int; v_shots int;
        r numeric := 0; why text[] := '{}';
begin
  select t.fair, t.server_score into a from public.attempts t where t.id = p_attempt;
  select count(*) filter (where x.choice is not null),
         count(*) filter (where x.choice is not null and x.time_ms between 1 and 2999),
         percentile_cont(0.5) within group (order by x.time_ms) filter (where x.choice is not null and x.time_ms > 0)
  into v_ans, v_fast, v_med
  from public.attempt_answers x where x.attempt_id = p_attempt;
  v_acc := coalesce((a.server_score ->> 'correct')::numeric / nullif((a.server_score ->> 'answered')::numeric, 0), 0);
  v_away := least(greatest(coalesce((a.fair ->> 'away')::int, 0), 0), 1000);
  v_away_s := least(greatest(coalesce((a.fair ->> 'away_ms')::bigint, 0), 0), 86400000) / 1000;
  v_shots := least(greatest(coalesce((a.fair ->> 'shots')::int, 0), 0), 1000);
  if v_ans >= 10 and v_fast > 0 then
    r := r + least(60, round(60.0 * v_fast / v_ans));
    if v_fast::numeric / v_ans >= 0.2 then why := why || (round(100.0 * v_fast / v_ans) || '% of answers in under 3 s'); end if;
  end if;
  if v_ans >= 10 and v_med is not null and v_med < 6000 and v_acc >= 0.8 then
    r := r + 20; why := why || ('median ' || round(v_med / 1000.0, 1) || ' s a question with ' || round(100 * v_acc) || '% right');
  end if;
  if v_away > 0 then
    r := r + least(v_away, 10) * 6 + least(v_away_s / 30, 20);
    why := why || ('left the app ' || v_away || ' time' || case when v_away = 1 then '' else 's' end || ' (' || (v_away_s / 60) || ' min ' || (v_away_s % 60) || ' s away)');
  end if;
  if v_shots > 0 then
    r := r + least(v_shots, 5) * 15;
    why := why || (v_shots || ' screenshot attempt' || case when v_shots = 1 then '' else 's' end);
  end if;
  return jsonb_build_object('risk', least(100, round(r))::int, 'why', array_to_string(why, ', '), 'fast', v_fast, 'answered', v_ans,
                            'median_ms', round(coalesce(v_med, 0)));
end $$;
revoke all on function private.fair_risk(uuid) from public, anon, authenticated;

-- submit_attempt keeps the app's report (only the known numbers) and stores the risk.
do $$
declare d text := pg_get_functiondef('public.submit_attempt(jsonb)'::regprocedure);
begin
  d := replace(d, $r$  update public.attempts set server_score = v_score where id = v_id;$r$,
$r$  update public.attempts set server_score = v_score,
    fair = jsonb_build_object('away', least(greatest(coalesce((p -> 'fair' ->> 'away')::int, 0), 0), 1000),
                              'away_ms', least(greatest(coalesce((p -> 'fair' ->> 'away_ms')::bigint, 0), 0), 86400000),
                              'shots', least(greatest(coalesce((p -> 'fair' ->> 'shots')::int, 0), 0), 1000),
                              'reported', p ? 'fair')
  where id = v_id;
  update public.attempts t set fair = t.fair || f, risk = (f ->> 'risk')::smallint
  from (select private.fair_risk(v_id) f) x where t.id = v_id;$r$);
  if position('fair_risk' in d) = 0 then raise exception 'submit_attempt: change not applied'; end if;
  execute d;
end $$;

-- The leaderboards hold a run whose risk reaches the admin's level (leaderboard.fair_hold, default 50; 0 = off),
-- with the reasons, next to the existing "too fast" check. Same change in the season and window versions.
do $$
declare f text; d text;
begin
  foreach f in array array['private.lb_attempts(integer)', 'private.lb_attempts_w(timestamp with time zone,timestamp with time zone)'] loop
    d := pg_get_functiondef(f::regprocedure);
    d := replace(d, $r$private.lb_suspicious((a.server_score ->> 'total')::int, a.time_used_s, coalesce((cfg.c ->> 'fast_minutes')::int, 15))$r$,
      $r$coalesce(private.lb_suspicious((a.server_score ->> 'total')::int, a.time_used_s, coalesce((cfg.c ->> 'fast_minutes')::int, 15)),
         case when coalesce((cfg.c ->> 'fair_hold')::int, 50) > 0 and coalesce(a.risk, 0) >= coalesce((cfg.c ->> 'fair_hold')::int, 50)
              then 'Fair play ' || a.risk || '/100: ' || coalesce(a.fair ->> 'why', '') end)$r$);
    if position('fair_hold' in d) = 0 then raise exception '% not changed', f; end if;
    execute d;
  end loop;
  foreach f in array array['private.lb_entries(text,integer,smallint)', 'private.lb_entries_w(text,timestamp with time zone,timestamp with time zone,smallint)'] loop
    d := pg_get_functiondef(f::regprocedure);
    d := replace(d, $r$              when (a.server_score ->> 'total')::int >= 95 and a.time_used_s < v_fast * 180 then 'Near-perfect score in under ' || (v_fast * 3) || ' minutes'
         end,$r$,
      $r$              when (a.server_score ->> 'total')::int >= 95 and a.time_used_s < v_fast * 180 then 'Near-perfect score in under ' || (v_fast * 3) || ' minutes'
              when coalesce((v_c ->> 'fair_hold')::int, 50) > 0 and coalesce(a.risk, 0) >= coalesce((v_c ->> 'fair_hold')::int, 50)
                then 'Fair play ' || a.risk || '/100: ' || coalesce(a.fair ->> 'why', '')
         end,$r$);
    if position('fair_hold' in d) = 0 then raise exception '% not changed', f; end if;
    execute d;
  end loop;
end $$;

