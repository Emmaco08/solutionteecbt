-- Game Zone v2 (D-157), part 3: rounds that end early when everybody has answered, matchmaking (queue, lobbies,
-- friend codes, rematch).

alter table public.gz_matches add column if not exists round_open timestamptz;
alter table public.gz_players add column if not exists left_at timestamptz;
create index if not exists gz_players_user_idx on public.gz_players (user_id, joined_at desc) where user_id is not null;
create index if not exists gz_matches_lobby_idx on public.gz_matches (game, mode, status) where status = 'lobby';
create index if not exists gz_answers_idx on public.gz_answers (match_id, idx);

-- When the current round closes: at the time limit, or as soon as every student still playing has answered
-- (bots answer at their planned moment, so a round never closes before the bots are done).
create or replace function private.gz_close_at(m public.gz_matches)
returns timestamptz language plpgsql stable security definer set search_path = '' as $$
declare r integer := m.settled; v_full timestamptz := m.round_open + make_interval(secs => m.seconds); v_hum timestamptz; v_bot integer;
begin
  if m.round_open is null then return null; end if;
  if exists (select 1 from public.gz_players p where p.match_id = m.id and p.user_id is not null and p.alive
             and not exists (select 1 from public.gz_answers x where x.match_id = m.id and x.player_id = p.id and x.idx = r)) then
    return v_full;
  end if;
  select max(x.at) into v_hum from public.gz_answers x join public.gz_players p on p.id = x.player_id
  where x.match_id = m.id and x.idx = r and p.user_id is not null;
  select max((private.gz_bot_answer(b.bot, m.id::text || b.id || ':' || r, m.seconds * 1000) ->> 'ms')::int) into v_bot
  from public.gz_players b where b.match_id = m.id and b.user_id is null and b.alive;
  return least(v_full, greatest(coalesce(v_hum, m.round_open), m.round_open + make_interval(secs => coalesce(v_bot, 0) / 1000.0)) + interval '700 milliseconds');
end $$;

create or replace function private.gz_start(p_match uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches; c jsonb; v_n integer; v_secs integer;
begin
  select * into m from public.gz_matches where id = p_match for update;
  if m.status <> 'lobby' then return; end if;
  c := private.gz_conf(m.game);
  select count(*) into v_n from public.gz_players where match_id = m.id;
  if m.mode <> 'friend' or m.game in ('survival', 'relay', 'rush') then
    perform private.gz_add_bots(m.id, (c ->> 'min')::int - v_n);
  end if;
  if m.game = 'relay' then
    update public.gz_players p set team = 1 + (x.rn % 2)
    from (select id, row_number() over (order by user_id is null, id) - 1 as rn from public.gz_players where match_id = m.id) x where p.id = x.id;
  end if;
  perform private.gz_build_items(m.id);
  select * into m from public.gz_matches where id = p_match;
  v_secs := case when c ->> 'kind' = 'sync' then ceil(m.rounds * (m.seconds * 1000 + m.gap_ms) / 1000.0)::int else (c ->> 'seconds')::int end;
  update public.gz_matches set status = 'playing', starts_at = now() + interval '4 seconds', round_open = now() + interval '4 seconds',
    ends_at = now() + interval '4 seconds' + make_interval(secs => v_secs) where id = m.id;
  update public.gz_players gp set last_at = now() + interval '4 seconds',
    rating_before = case when gp.user_id is null then null else coalesce((select r.rating from public.gz_ratings r where r.user_id = gp.user_id and r.game = m.game), 1000) end
  where gp.match_id = m.id;
  perform private.gz_send(m.id, 'start', jsonb_build_object('id', m.id));
end $$;

create or replace function private.gz_finish(p_match uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches; r record; v_xp integer; v_avg integer; v_win_team smallint; v_delta float; o record; v_n integer; v_streak integer;
begin
  select * into m from public.gz_matches where id = p_match for update;
  if m.status = 'done' then return; end if;
  if m.game = 'relay' then
    select team into v_win_team from public.gz_players where match_id = m.id group by team order by sum(score) desc, sum(correct) desc limit 1;
    update public.gz_players set place = case when team = v_win_team then 1 else 2 end where match_id = m.id;
  else
    update public.gz_players p set place = x.pl from (
      select id, rank() over (order by (left_at is null) desc,
        case when m.game = 'survival' then (alive)::int else 0 end desc,
        case when m.game = 'survival' then coalesce(out_round, 999) else 0 end desc,
        case when m.game = 'rush' then coalesce(extract(epoch from finished_at), 9e12) else 0 end asc,
        case when m.game = 'rush' then correct else 0 end desc,
        score desc, correct desc) as pl
      from public.gz_players where match_id = m.id) x where p.id = x.id;
  end if;
  -- Ratings (Ranked only; a bot counts at the average rating in the match).
  if m.mode = 'ranked' then
    select coalesce(avg(rating_before), 1000)::int, count(*) into v_avg, v_n from public.gz_players where match_id = m.id;
    for r in select * from public.gz_players where match_id = m.id and user_id is not null loop
      v_delta := 0;
      for o in select * from public.gz_players where match_id = m.id and id <> r.id loop
        v_delta := v_delta + (case when r.place < o.place then 1 when r.place = o.place then 0.5 else 0 end)
          - 1.0 / (1 + power(10, (coalesce(o.rating_before, v_avg) - r.rating_before) / 400.0));
      end loop;
      update public.gz_players set rating_delta = greatest(-40, least(40, round(32 * v_delta / greatest(v_n - 1, 1) * case when v_n > 2 then 2 else 1 end)))
      where id = r.id;
    end loop;
  end if;
  -- XP (amounts set in Admin -> Games) and stats. A student who left gets nothing.
  for r in select * from public.gz_players where match_id = m.id and user_id is not null loop
    select g.streak into v_streak from public.gz_ratings g where g.user_id = r.user_id and g.game = m.game;
    v_xp := 0;
    if r.left_at is null then
      v_xp := private.game_xp(r.user_id, private.gz_xp(m.game, 'xp_play', 5), 'game_play', m.id::text, 'gz:' || m.id || ':' || r.user_id || ':play');
      if r.place = 1 and (m.game = 'memory' or (r.answered > 0 and r.correct::float / r.answered >= 0.4)) then
        v_xp := v_xp + private.game_xp(r.user_id, private.gz_xp(m.game, 'xp_win', 15)
          + case when m.mode = 'ranked' then private.gz_xp(m.game, 'xp_ranked_win', 10) else 0 end
          + case when coalesce(v_streak, 0) + 1 >= 3 then private.gz_xp(m.game, 'xp_streak', 10) else 0 end,
          'game_win', m.id::text, 'gz:' || m.id || ':' || r.user_id || ':win');
      end if;
    end if;
    update public.gz_players set xp = v_xp where id = r.id;
    insert into public.gz_ratings as g (user_id, game, rating, played, won, streak, best_streak)
    values (r.user_id, m.game, 1000 + coalesce(r.rating_delta, 0), 1, (r.place = 1)::int, (r.place = 1)::int, (r.place = 1)::int)
    on conflict (user_id, game) do update set
      rating = greatest(100, g.rating + coalesce((select x.rating_delta from public.gz_players x where x.id = r.id), 0)),
      played = g.played + 1, won = g.won + (r.place = 1)::int,
      streak = case when r.place = 1 then g.streak + 1 else 0 end,
      best_streak = greatest(g.best_streak, case when r.place = 1 then g.streak + 1 else 0 end), updated_at = now();
  end loop;
  update public.gz_matches set status = 'done', finished_at = now() where id = m.id;
  perform private.gz_send(m.id, 'done', jsonb_build_object('id', m.id));
end $$;

create or replace function private.gz_settle(p_match uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches; c jsonb; r integer; b record; a jsonb; v_key text; v_ok boolean; v_alive integer; v_end boolean := false;
  v_humans integer; v_left integer; v_pr jsonb; v_limit integer; v_close timestamptz; v_full timestamptz; v_pts integer; v_moved boolean := false;
begin
  select * into m from public.gz_matches where id = p_match for update;
  if not found or m.status in ('done', 'cancelled') then return; end if;
  c := private.gz_conf(m.game);
  if m.status = 'lobby' then
    select count(*) filter (where user_id is not null), count(*) into v_humans, v_left from public.gz_players where match_id = m.id;
    if v_humans = 0 then
      update public.gz_matches set status = 'cancelled' where id = m.id;
    elsif v_left >= m.max_players or (m.lobby_until <= now() and (m.mode <> 'friend' or v_humans >= 2 or m.game in ('survival', 'relay', 'rush'))) then
      perform private.gz_start(m.id);
    elsif m.lobby_until <= now() then
      update public.gz_matches set status = 'cancelled' where id = m.id;
      perform private.gz_send(m.id, 'cancelled', jsonb_build_object('id', m.id));
    end if;
    return;
  end if;
  if now() < m.starts_at then return; end if;
  -- Everyone left: end it now.
  if not exists (select 1 from public.gz_players where match_id = m.id and user_id is not null and left_at is null) then
    perform private.gz_finish(m.id); return;
  end if;
  if c ->> 'kind' = 'sync' then
    v_limit := m.seconds * 1000;
    loop
      exit when m.settled >= m.rounds or now() < m.round_open;
      r := m.settled;
      v_full := m.round_open + make_interval(secs => m.seconds);
      v_close := private.gz_close_at(m);
      exit when now() < v_close + case when v_close >= v_full then interval '400 milliseconds' else interval '0' end;
      v_key := m.keys ->> r;
      for b in select * from public.gz_players where match_id = m.id and user_id is null and alive loop
        a := private.gz_bot_answer(b.bot, m.id::text || b.id || ':' || r, v_limit);
        v_ok := (a ->> 'ok')::boolean;
        v_pts := case when v_ok then 100 + round(50 * greatest(0, 1 - (a ->> 'ms')::float / v_limit))::int else 0 end;
        insert into public.gz_answers (match_id, player_id, idx, choice, correct, ms, points, at)
        values (m.id, b.id, r, case when v_ok then v_key else 'x' end, v_ok, (a ->> 'ms')::int, v_pts, m.round_open + make_interval(secs => (a ->> 'ms')::int / 1000.0))
        on conflict do nothing;
        update public.gz_players set answered = answered + 1, correct = correct + v_ok::int, score = score + v_pts,
          combo = case when v_ok then combo + 1 else 0 end, best_combo = greatest(best_combo, case when v_ok then combo + 1 else 0 end)
        where id = b.id;
      end loop;
      -- A student who did not answer loses the combo.
      update public.gz_players p set combo = 0 where p.match_id = m.id and p.user_id is not null
        and not exists (select 1 from public.gz_answers x where x.match_id = m.id and x.player_id = p.id and x.idx = r and x.correct);
      if m.game = 'survival' then
        update public.gz_players p set lives = lives - 1 where p.match_id = m.id and p.alive
          and not exists (select 1 from public.gz_answers x where x.match_id = m.id and x.player_id = p.id and x.idx = r and x.correct);
        update public.gz_players set alive = false, out_round = r where match_id = m.id and alive and lives <= 0;
        select count(*) into v_alive from public.gz_players where match_id = m.id and alive;
        if v_alive <= 1 or not exists (select 1 from public.gz_players where match_id = m.id and alive and user_id is not null) then v_end := true; end if;
      end if;
      update public.gz_matches set settled = r + 1, round_open = v_close + make_interval(secs => m.gap_ms / 1000.0) where id = m.id returning * into m;
      v_moved := true;
      exit when v_end;
    end loop;
    if v_end or m.settled >= m.rounds then perform private.gz_finish(m.id);
    elsif v_moved then perform private.gz_send(m.id, 'round', jsonb_build_object('r', m.settled));
    end if;
  else
    select count(*) into v_left from public.gz_players where match_id = m.id and user_id is not null and finished_at is null and left_at is null;
    if now() >= m.ends_at or v_left = 0 then
      for b in select * from public.gz_players where match_id = m.id and user_id is null loop
        if c ->> 'kind' = 'race' then
          v_pr := private.gz_bot_progress(m, b.bot, now());
          update public.gz_players set pos = (v_pr ->> 'pos')::int, answered = (v_pr ->> 'answered')::int, correct = (v_pr ->> 'correct')::int,
            score = (v_pr ->> 'score')::int, best_combo = (v_pr ->> 'best')::int, finished_at = (v_pr ->> 'finished_at')::timestamptz where id = b.id;
        else
          update public.gz_players set pos = 3, finished_at = now(), score = (
            select sum(private.gz_mem_points(3 + k, ((b.bot -> 'plan' -> (k - 1)) ->> 'moves')::int, ((b.bot -> 'plan' -> (k - 1)) ->> 'ms')::int))::int
            from generate_series(1, 3) k) where id = b.id;
        end if;
      end loop;
      perform private.gz_finish(m.id);
    end if;
  end if;
end $$;

-- ---------- matchmaking ----------
create or replace function private.gz_subject(p_uid uuid, p_game text, p_subject smallint)
returns smallint language plpgsql stable security definer set search_path = '' as $$
declare v_codes text[]; v_code text;
begin
  if p_game = 'words' then return (select id from public.subjects where code = 'eng'); end if;
  if p_game = 'blitz' then return (select id from public.subjects where code = 'mth'); end if;
  if p_game = 'memory' then return p_subject; end if;
  if p_subject is null then raise exception 'subject' using errcode = '22023'; end if;
  select code into v_code from public.subjects where id = p_subject;
  if v_code is null or not exists (select 1 from public.exam_subjects where exam_id = 1 and subject_id = p_subject) then
    raise exception 'subject' using errcode = '22023';
  end if;
  select jamb_subjects into v_codes from public.profiles where id = p_uid;
  if coalesce(cardinality(v_codes), 0) > 0 and v_code <> 'eng' and not (v_code = any (v_codes)) then
    raise exception 'subject' using errcode = '22023';
  end if;
  return p_subject;
end $$;

create or replace function private.gz_new(p_uid uuid, p_game text, p_mode text, p_subject smallint, p_level text, p_lobby_secs integer)
returns uuid language plpgsql security definer set search_path = '' as $$
declare c jsonb := private.gz_conf(p_game); v_id uuid; v_code text; v_secs integer;
begin
  if p_mode = 'friend' then
    loop
      select string_agg(substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789', 1 + floor(random() * 31)::int, 1), '') into v_code from generate_series(1, 6);
      exit when not exists (select 1 from public.gz_matches where code = v_code);
    end loop;
  end if;
  v_secs := coalesce((private.gz_set(p_game, 'seconds') #>> '{}')::int, (c ->> 'seconds')::int);
  insert into public.gz_matches (game, mode, subject_id, exam_id, code, level, max_players, min_players, seconds, gap_ms, rounds, target, lobby_until, created_by)
  values (p_game, p_mode, p_subject, 1, v_code, coalesce(p_level, 'medium'), (c ->> 'max')::int, (c ->> 'min')::int,
    greatest(5, least(case when c ->> 'kind' = 'sync' then 30 else 300 end, v_secs)), coalesce((c ->> 'gap')::int, 0),
    greatest(3, least(30, coalesce((private.gz_set(p_game, 'rounds') #>> '{}')::int, (c ->> 'rounds')::int, 10))),
    coalesce((c ->> 'target')::int, 10), now() + make_interval(secs => p_lobby_secs), p_uid)
  returning id into v_id;
  if p_uid is not null then
    insert into public.gz_players (match_id, user_id, name) values (v_id, p_uid, private.game_name(p_uid));
  end if;
  return v_id;
end $$;

-- Pairs a waiting student with the closest rating in the same game and subject (the window widens while they wait).
create or replace function private.gz_pair(p_uid uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare q public.gz_queue; o public.gz_queue; v_id uuid;
begin
  select * into q from public.gz_queue where user_id = p_uid for update;
  if not found then return null; end if;
  if q.match_id is not null then return q.match_id; end if;
  select * into o from public.gz_queue x
  where x.user_id <> p_uid and x.match_id is null and x.game = q.game and x.subject_id is not distinct from q.subject_id and x.ranked = q.ranked
    and x.joined_at > now() - interval '2 minutes'
    and abs(x.rating - q.rating) <= 150 + 25 * greatest(extract(epoch from now() - q.joined_at), extract(epoch from now() - x.joined_at))
    and (not q.ranked or (select count(*) from public.gz_matches mm
          where mm.mode = 'ranked' and mm.created_at >= private.lagos_day_start()
            and exists (select 1 from public.gz_players a where a.match_id = mm.id and a.user_id = p_uid)
            and exists (select 1 from public.gz_players b where b.match_id = mm.id and b.user_id = x.user_id)) < 3)
  order by abs(x.rating - q.rating), x.joined_at limit 1 for update skip locked;
  if not found then return null; end if;
  v_id := private.gz_new(p_uid, q.game, case when q.ranked then 'ranked' else 'quick' end, q.subject_id, 'medium', 0);
  insert into public.gz_players (match_id, user_id, name) values (v_id, o.user_id, private.game_name(o.user_id));
  perform private.gz_start(v_id);
  update public.gz_queue set match_id = v_id where user_id = o.user_id;
  delete from public.gz_queue where user_id = p_uid;
  begin
    perform realtime.send(jsonb_build_object('match', v_id), 'matched', 'gzu:' || o.user_id::text, true);
  exception when others then null;
  end;
  return v_id;
end $$;

create or replace function private.gz_me_check(p_uid uuid, p_game text)
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if p_uid is null or private.is_banned(p_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  if private.gz_conf(p_game) is null then raise exception 'game' using errcode = '22023'; end if;
  if coalesce((private.games_settings() ->> 'on')::boolean, true) is false
     or coalesce((private.gz_set(p_game, 'on') #>> '{}')::boolean, true) is false then
    raise exception 'off' using errcode = 'P0001';
  end if;
  if (select count(*) from public.gz_players where user_id = p_uid and joined_at >= private.lagos_day_start())
     >= coalesce((private.gz_set(p_game, 'daily_matches') #>> '{}')::int, 80) then
    raise exception 'too_many' using errcode = 'P0001';
  end if;
end $$;

-- Leaves any lobby or queue the student is waiting in (one game at a time).
create or replace function private.gz_drop_waiting(p_uid uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v record;
begin
  delete from public.gz_queue where user_id = p_uid and match_id is null;
  for v in select p.id, p.match_id from public.gz_players p join public.gz_matches m on m.id = p.match_id
           where p.user_id = p_uid and m.status = 'lobby' loop
    delete from public.gz_players where id = v.id;
    if not exists (select 1 from public.gz_players where match_id = v.match_id and user_id is not null) then
      update public.gz_matches set status = 'cancelled' where id = v.match_id;
    end if;
  end loop;
end $$;

create or replace function private.gz_found(p_match uuid, p_extra jsonb default '{}')
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('status', case m.status when 'lobby' then 'lobby' else 'matched' end, 'match', m.id, 'code', m.code, 'game', m.game) || p_extra
  from public.gz_matches m where m.id = p_match;
$$;

-- Start a game. p_mode: quick, ranked, ai (Practice vs AI, with p_level) or friend (a code to share).
create or replace function public.gz_find(p_game text, p_mode text, p_subject smallint default null, p_level text default 'medium')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); c jsonb := private.gz_conf(p_game); v_sub smallint; v_id uuid; v_rating integer; v_n integer;
begin
  perform private.gz_me_check(v_uid, p_game);
  if p_mode not in ('quick', 'ranked', 'ai', 'friend') then raise exception 'mode' using errcode = '22023'; end if;
  if p_level not in ('easy', 'medium', 'hard') then p_level := 'medium'; end if;
  v_sub := private.gz_subject(v_uid, p_game, p_subject);
  perform private.gz_drop_waiting(v_uid);
  if p_mode = 'ai' then
    v_id := private.gz_new(v_uid, p_game, 'ai', v_sub, p_level, 0);
    perform private.gz_start(v_id);
    return private.gz_found(v_id);
  elsif p_mode = 'friend' then
    v_id := private.gz_new(v_uid, p_game, 'friend', v_sub, p_level, 600);
    return private.gz_found(v_id);
  elsif (c ->> 'max')::int > 2 then
    -- Group games: join an open lobby or open one; bots fill the empty seats when the lobby timer ends.
    select m.id into v_id from public.gz_matches m
    where m.game = p_game and m.mode = p_mode and m.status = 'lobby' and m.subject_id is not distinct from v_sub
      and m.lobby_until > now() + interval '2 seconds'
      and (select count(*) from public.gz_players p where p.match_id = m.id) < m.max_players
    order by m.created_at limit 1 for update skip locked;
    if v_id is null then
      v_id := private.gz_new(v_uid, p_game, p_mode, v_sub, 'medium', coalesce((c ->> 'lobby')::int, 15));
    else
      insert into public.gz_players (match_id, user_id, name) values (v_id, v_uid, private.game_name(v_uid)) on conflict do nothing;
      select count(*) into v_n from public.gz_players where match_id = v_id;
      perform private.gz_send(v_id, 'joined', jsonb_build_object('n', v_n));
      if v_n >= (c ->> 'max')::int then perform private.gz_start(v_id); end if;
    end if;
    return private.gz_found(v_id);
  else
    select coalesce((select rating from public.gz_ratings where user_id = v_uid and game = p_game), 1000) into v_rating;
    insert into public.gz_queue (user_id, game, subject_id, ranked, rating, joined_at, match_id)
    values (v_uid, p_game, v_sub, p_mode = 'ranked', v_rating, now(), null)
    on conflict (user_id) do update set game = excluded.game, subject_id = excluded.subject_id, ranked = excluded.ranked,
      rating = excluded.rating, joined_at = now(), match_id = null;
    v_id := private.gz_pair(v_uid);
    if v_id is not null then return private.gz_found(v_id); end if;
    return jsonb_build_object('status', 'waiting', 'waited', 0,
      'wait', coalesce((private.gz_set(p_game, 'queue_seconds') #>> '{}')::int, 15));
  end if;
end $$;

-- While waiting in the queue: matched, still waiting, or a SolutionTee Bot joins after the wait.
create or replace function public.gz_poll()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); q public.gz_queue; v_id uuid; v_wait integer; v_level text;
begin
  if v_uid is null then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into q from public.gz_queue where user_id = v_uid;
  if not found then return jsonb_build_object('status', 'none'); end if;
  if q.match_id is not null then
    delete from public.gz_queue where user_id = v_uid;
    return private.gz_found(q.match_id);
  end if;
  v_id := private.gz_pair(v_uid);
  if v_id is not null then return private.gz_found(v_id); end if;
  v_wait := coalesce((private.gz_set(q.game, 'queue_seconds') #>> '{}')::int, 15);
  if now() - q.joined_at >= make_interval(secs => v_wait) then
    delete from public.gz_queue where user_id = v_uid and match_id is null;
    if not found then return jsonb_build_object('status', 'waiting', 'waited', v_wait, 'wait', v_wait); end if;
    v_level := case when q.rating < 950 then 'easy' when q.rating > 1150 then 'hard' else 'medium' end;
    v_id := private.gz_new(v_uid, q.game, case when q.ranked then 'ranked' else 'quick' end, q.subject_id, v_level, 0);
    perform private.gz_start(v_id);
    return private.gz_found(v_id, '{"bot":true}');
  end if;
  return jsonb_build_object('status', 'waiting', 'waited', extract(epoch from now() - q.joined_at)::int, 'wait', v_wait,
    'searching', (select count(*) from public.gz_queue x where x.game = q.game and x.match_id is null));
end $$;

create or replace function public.gz_cancel()
returns void language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then raise exception 'not allowed' using errcode = '42501'; end if;
  perform private.gz_drop_waiting((select auth.uid()));
end $$;

create or replace function public.gz_join(p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); m public.gz_matches; v_n integer;
begin
  select * into m from public.gz_matches where code = upper(btrim(p_code)) for update;
  if not found or m.status <> 'lobby' or m.lobby_until <= now() then return jsonb_build_object('status', 'gone'); end if;
  perform private.gz_me_check(v_uid, m.game);
  if exists (select 1 from public.gz_players where match_id = m.id and user_id = v_uid) then return private.gz_found(m.id); end if;
  if m.game not in ('words', 'blitz', 'memory') then perform private.gz_subject(v_uid, 'duel', m.subject_id); end if;
  select count(*) into v_n from public.gz_players where match_id = m.id;
  if v_n >= m.max_players then return jsonb_build_object('status', 'full'); end if;
  perform private.gz_drop_waiting(v_uid);
  insert into public.gz_players (match_id, user_id, name) values (m.id, v_uid, private.game_name(v_uid));
  perform private.gz_send(m.id, 'joined', jsonb_build_object('n', v_n + 1, 'name', private.game_name(v_uid)));
  if v_n + 1 >= m.max_players then perform private.gz_start(m.id); end if;
  return private.gz_found(m.id);
exception when sqlstate '22023' then
  return jsonb_build_object('status', 'subject');
end $$;

-- The host starts a friend lobby (two students or more; bots fill a group game).
create or replace function public.gz_start_now(p_match uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches;
begin
  select * into m from public.gz_matches where id = p_match;
  if not found or m.created_by is distinct from (select auth.uid()) or m.status <> 'lobby' then return jsonb_build_object('ok', false); end if;
  if m.game not in ('survival', 'relay', 'rush') and (select count(*) from public.gz_players where match_id = m.id and user_id is not null) < 2 then
    return jsonb_build_object('ok', false, 'error', 'alone');
  end if;
  perform private.gz_start(m.id);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.gz_leave(p_match uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); m public.gz_matches;
begin
  select * into m from public.gz_matches where id = p_match;
  if not found or v_uid is null then return; end if;
  if m.status = 'lobby' then
    perform private.gz_drop_waiting(v_uid);
  elsif m.status = 'playing' then
    update public.gz_players set left_at = now(), alive = false where match_id = m.id and user_id = v_uid and left_at is null;
    perform private.gz_send(m.id, 'left', jsonb_build_object('name', private.game_name(v_uid)));
    perform private.gz_settle(m.id);
  end if;
end $$;

-- Rematch: vs AI starts at once; with students it opens a 2-minute lobby and invites the others.
create or replace function public.gz_rematch(p_match uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); m public.gz_matches; v_id uuid; o record;
begin
  select * into m from public.gz_matches where id = p_match;
  if not found or not exists (select 1 from public.gz_players where match_id = m.id and user_id = v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  if m.mode = 'ai' or not exists (select 1 from public.gz_players where match_id = m.id and user_id is not null and user_id <> v_uid) then
    return public.gz_find(m.game, case when m.mode = 'friend' then 'ai' else m.mode end, m.subject_id, m.level);
  end if;
  perform private.gz_me_check(v_uid, m.game);
  perform private.gz_drop_waiting(v_uid);
  v_id := private.gz_new(v_uid, m.game, 'friend', m.subject_id, m.level, 120);
  for o in select user_id from public.gz_players where match_id = m.id and user_id is not null and user_id <> v_uid loop
    begin
      perform realtime.send(jsonb_build_object('code', (select code from public.gz_matches where id = v_id), 'game', m.game,
        'name', private.game_name(v_uid), 'match', v_id), 'rematch', 'gzu:' || o.user_id::text, true);
    exception when others then null;
    end;
  end loop;
  return private.gz_found(v_id);
end $$;

revoke all on function public.gz_find(text, text, smallint, text), public.gz_poll(), public.gz_cancel(), public.gz_join(text),
  public.gz_start_now(uuid), public.gz_leave(uuid), public.gz_rematch(uuid) from public, anon;
grant execute on function public.gz_find(text, text, smallint, text), public.gz_poll(), public.gz_cancel(), public.gz_join(text),
  public.gz_start_now(uuid), public.gz_leave(uuid), public.gz_rematch(uuid) to authenticated;
