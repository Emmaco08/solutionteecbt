-- Leaderboards v2 (B9, D-143): week, month, year and all-time boards next to the JAMB season, with the same fair
-- rules (held runs, reviews, minimum mocks, hidden students).

-- The time window of a board: week (Monday to Sunday), month, year, all time or the JAMB season (July to June),
-- in Lagos time. p_offset 0 = now, 1 = the one before.
create or replace function private.lb_window(p_period text, p_offset integer default 0, p_season integer default null,
                                             out from_ts timestamptz, out to_ts timestamptz, out label text)
language plpgsql stable set search_path = '' as $$
declare l timestamp := (now() at time zone 'Africa/Lagos'); o integer := greatest(coalesce(p_offset, 0), 0); s timestamp;
begin
  case p_period
    when 'week' then s := date_trunc('week', l) - make_interval(weeks => o);
      from_ts := s at time zone 'Africa/Lagos'; to_ts := (s + interval '1 week') at time zone 'Africa/Lagos';
      label := 'Week of ' || to_char(s, 'FMDD Mon YYYY');
    when 'month' then s := date_trunc('month', l) - make_interval(months => o);
      from_ts := s at time zone 'Africa/Lagos'; to_ts := (s + interval '1 month') at time zone 'Africa/Lagos';
      label := to_char(s, 'FMMonth YYYY');
    when 'year' then s := date_trunc('year', l) - make_interval(years => o);
      from_ts := s at time zone 'Africa/Lagos'; to_ts := (s + interval '1 year') at time zone 'Africa/Lagos';
      label := to_char(s, 'YYYY');
    when 'all' then from_ts := '2020-01-01'::timestamptz; to_ts := now() + interval '1 day'; label := 'All time';
    else
      s := make_timestamp(coalesce(p_season, private.jamb_season(now())) - 1, 7, 1, 0, 0, 0);
      from_ts := s at time zone 'Africa/Lagos'; to_ts := (s + interval '1 year') at time zone 'Africa/Lagos';
      label := 'Season ' || coalesce(p_season, private.jamb_season(now()));
  end case;
end $$;

-- Copies of lb_attempts / lb_entries that take a time window instead of a season (the season versions stay for
-- the admin pages and older app versions).
do $$
declare d text;
begin
  d := pg_get_functiondef('private.lb_attempts(integer)'::regprocedure);
  d := replace(d, 'private.lb_attempts(p_season integer)', 'private.lb_attempts_w(p_from timestamp with time zone, p_to timestamp with time zone)');
  d := replace(d, $r$a.submitted_at >= make_timestamptz(p_season - 1, 7, 1, 0, 0, 0, 'Africa/Lagos')$r$, 'a.submitted_at >= p_from');
  d := replace(d, $r$a.submitted_at < make_timestamptz(p_season, 7, 1, 0, 0, 0, 'Africa/Lagos')$r$, 'a.submitted_at < p_to');
  if position('p_season' in d) > 0 then raise exception 'lb_attempts_w: season left in %', d; end if;
  execute d;

  d := pg_get_functiondef('private.lb_entries(text,integer,smallint)'::regprocedure);
  d := replace(d, 'private.lb_entries(p_exam text, p_season integer, p_subject smallint)', 'private.lb_entries_w(p_exam text, p_from timestamp with time zone, p_to timestamp with time zone, p_subject smallint)');
  d := replace(d, 'private.lb_attempts(p_season)', 'private.lb_attempts_w(p_from, p_to)');
  d := replace(d, $r$a.submitted_at >= make_timestamptz(p_season - 1, 7, 1, 0, 0, 0, 'Africa/Lagos')$r$, 'a.submitted_at >= p_from');
  d := replace(d, $r$a.submitted_at < make_timestamptz(p_season, 7, 1, 0, 0, 0, 'Africa/Lagos')$r$, 'a.submitted_at < p_to');
  if position('p_season' in d) > 0 then raise exception 'lb_entries_w: season left'; end if;
  execute d;

  -- leaderboard_for gains p_period and p_offset (old calls keep working: season, now).
  d := pg_get_functiondef('public.leaderboard_for(text,integer,text,smallint)'::regprocedure);
  d := replace(d, $r$p_subject smallint DEFAULT NULL::smallint)$r$, $r$p_subject smallint DEFAULT NULL::smallint, p_period text DEFAULT 'season'::text, p_offset integer DEFAULT 0)$r$);
  d := replace(d, '  v_my_mocks integer;', $r$  v_my_mocks integer;
  v_period text := case when p_period in ('week', 'month', 'year', 'all') then p_period else 'season' end;
  v_from timestamptz; v_to timestamptz; v_label text;$r$);
  d := replace(d, $r$  if v_season <> v_now then v_scope := 'ng'; end if;$r$, $r$  if v_season <> v_now or (v_period <> 'season' and coalesce(p_offset, 0) > 0) then v_scope := 'ng'; end if;
  select w.from_ts, w.to_ts, w.label into v_from, v_to, v_label
  from private.lb_window(v_period, least(greatest(coalesce(p_offset, 0), 0), 52), v_season) w;$r$);
  d := replace(d, 'private.lb_entries(v_exam, v_season, v_subject)', 'private.lb_entries_w(v_exam, v_from, v_to, v_subject)');
  d := replace(d, $r$  if v_season = v_now then v_best := null; end if;$r$, $r$  if (v_period = 'season' and v_season = v_now) or (v_period <> 'season' and coalesce(p_offset, 0) = 0) then v_best := null; end if;$r$);
  d := replace(d, $r$'scope', v_scope,$r$, $r$'scope', v_scope, 'period', v_period, 'offset', coalesce(p_offset, 0), 'label', v_label,$r$);
  d := replace(d, $r$'current', v_season = v_now,$r$, $r$'current', case when v_period = 'season' then v_season = v_now else coalesce(p_offset, 0) = 0 end,$r$);
  if position('lb_entries_w' in d) = 0 or position('v_label' in d) = 0 then raise exception 'leaderboard_for: change not applied'; end if;
  execute d;
end $$;
drop function public.leaderboard_for(text, integer, text, smallint);
revoke all on function public.leaderboard_for(text, integer, text, smallint, text, integer) from public, anon;
grant execute on function public.leaderboard_for(text, integer, text, smallint, text, integer) to authenticated;
revoke all on function private.lb_window(text, integer, integer), private.lb_attempts_w(timestamptz, timestamptz),
  private.lb_entries_w(text, timestamptz, timestamptz, smallint) from public, anon, authenticated;

