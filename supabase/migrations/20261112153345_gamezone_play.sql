-- Game Zone v2 (D-157), part 4: play (answers, race steps, memory levels), state, hub, leaders and avatars.

-- ---------- play ----------
-- One answer in a round game (Duel, Word War, Survival, Relay) or one step in a race (Speed Rush, Maths Blitz).
create or replace function public.gz_answer(p_match uuid, p_idx integer, p_choice text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); m public.gz_matches; p public.gz_players; c jsonb; v_key text; v_ok boolean; v_ms integer; v_pts integer;
  v_combo integer; v_fin boolean := false;
begin
  perform private.gz_settle(p_match);
  select * into m from public.gz_matches where id = p_match;
  select * into p from public.gz_players where match_id = p_match and user_id = v_uid for update;
  if m.id is null or p.id is null then raise exception 'not allowed' using errcode = '42501'; end if;
  if m.status <> 'playing' or now() < m.starts_at or not p.alive or p.left_at is not null then return jsonb_build_object('ok', false, 'error', 'closed'); end if;
  c := private.gz_conf(m.game);
  v_key := m.keys ->> p_idx;
  v_ok := p_choice is not null and p_choice = v_key;
  if c ->> 'kind' = 'sync' then
    if p_idx <> m.settled or now() < m.round_open or now() > m.round_open + make_interval(secs => m.seconds + 0.4) then
      return jsonb_build_object('ok', false, 'error', 'closed');
    end if;
    v_ms := least(m.seconds * 1000, greatest(0, private.gz_ms(now(), m.round_open)));
    v_pts := case when v_ok then 100 + round(50 * greatest(0, 1 - v_ms::float / (m.seconds * 1000)))::int else 0 end;
    if m.game = 'relay' and v_ok then v_pts := v_pts + 25 * least(p.combo, 4); end if;
    insert into public.gz_answers (match_id, player_id, idx, choice, correct, ms, points) values (m.id, p.id, p_idx, left(p_choice, 200), v_ok, v_ms, v_pts)
    on conflict do nothing;
    if not found then return jsonb_build_object('ok', false, 'error', 'answered'); end if;
    v_combo := case when v_ok then p.combo + 1 else 0 end;
    update public.gz_players set answered = answered + 1, correct = correct + v_ok::int, score = score + v_pts, combo = v_combo,
      best_combo = greatest(best_combo, v_combo), last_at = now() where id = p.id;
    perform private.gz_send(m.id, 'ans', jsonb_build_object('p', p.id, 'i', p_idx));
    perform private.gz_settle(m.id);
    return jsonb_build_object('ok', true, 'correct', v_ok, 'key', v_key, 'points', v_pts, 'score', p.score + v_pts, 'combo', v_combo, 'ms', v_ms);
  else
    if c ->> 'kind' <> 'race' or p.finished_at is not null then return jsonb_build_object('ok', false, 'error', 'closed'); end if;
    if p_idx <> p.pos or now() > m.ends_at + interval '1 second' then return jsonb_build_object('ok', false, 'error', 'closed'); end if;
    if p.penalty_until is not null and now() < p.penalty_until - interval '150 milliseconds' then return jsonb_build_object('ok', false, 'error', 'wait'); end if;
    if p_idx >= jsonb_array_length(m.items) then return jsonb_build_object('ok', false, 'error', 'closed'); end if;
    v_ms := greatest(0, private.gz_ms(now(), greatest(coalesce(p.last_at, m.starts_at), coalesce(p.penalty_until, m.starts_at))));
    -- Not humanly possible: under 0.35 s (Blitz) or 1.2 s (Rush) counts as a guess.
    if v_ms < (case when m.game = 'blitz' then 350 else 1200 end) then v_ok := false; end if;
    v_combo := case when v_ok then p.combo + 1 else 0 end;
    v_pts := case when not v_ok then 0 when m.game = 'blitz' then 10 * least(v_combo, 5) else 100 end;
    insert into public.gz_answers (match_id, player_id, idx, choice, correct, ms, points) values (m.id, p.id, p_idx, left(p_choice, 200), v_ok, v_ms, v_pts)
    on conflict do nothing;
    v_fin := m.game = 'rush' and v_ok and p.correct + 1 >= m.target;
    update public.gz_players set pos = pos + 1, answered = answered + 1, correct = correct + v_ok::int, score = score + v_pts, combo = v_combo,
      best_combo = greatest(best_combo, v_combo), last_at = now(),
      penalty_until = case when not v_ok and m.game = 'rush' then now() + interval '2 seconds' else null end,
      finished_at = case when v_fin then now() else null end
    where id = p.id;
    perform private.gz_send(m.id, 'step', jsonb_build_object('p', p.id, 'pos', p.pos + 1, 'c', p.correct + v_ok::int));
    if v_fin then perform private.gz_settle(m.id); end if;
    return jsonb_build_object('ok', true, 'correct', v_ok, 'key', v_key, 'points', v_pts, 'score', p.score + v_pts, 'combo', v_combo,
      'pos', p.pos + 1, 'finished', v_fin, 'penalty_ms', case when not v_ok and m.game = 'rush' then 2000 else 0 end,
      'next', case when not v_fin then m.items -> (p.pos + 1) end);
  end if;
end $$;

-- Memory Flash: the app reports each level when it is cleared; the server checks it is possible.
create or replace function public.gz_memory(p_match uuid, p_level integer, p_moves integer, p_ms integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); m public.gz_matches; p public.gz_players; v_pairs integer; v_pts integer; v_fin boolean;
begin
  select * into m from public.gz_matches where id = p_match;
  select * into p from public.gz_players where match_id = p_match and user_id = v_uid for update;
  if m.id is null or p.id is null then raise exception 'not allowed' using errcode = '42501'; end if;
  if m.game <> 'memory' or m.status <> 'playing' or p.finished_at is not null or p.left_at is not null or p_level <> p.pos + 1 then
    return jsonb_build_object('ok', false, 'error', 'closed');
  end if;
  v_pairs := (m.items -> (p_level - 1) ->> 'pairs')::int;
  if p_moves < v_pairs or p_ms < v_pairs * 700 or private.gz_ms(now(), coalesce(p.last_at, m.starts_at)) + 1500 < p_ms then
    return jsonb_build_object('ok', false, 'error', 'check');
  end if;
  v_pts := private.gz_mem_points(v_pairs, p_moves, p_ms);
  v_fin := p_level >= jsonb_array_length(m.items);
  update public.gz_players set pos = p_level, score = score + v_pts, answered = answered + 1, correct = correct + 1, last_at = now(),
    finished_at = case when v_fin then now() end where id = p.id;
  perform private.gz_send(m.id, 'step', jsonb_build_object('p', p.id, 'pos', p_level));
  if v_fin then perform private.gz_settle(m.id); end if;
  return jsonb_build_object('ok', true, 'points', v_pts, 'score', p.score + v_pts, 'finished', v_fin);
end $$;

-- Everything the game screen needs, timed by the server clock. The right option is only included for a round that
-- has closed, for the student's own answered item, or after the match.
create or replace function public.gz_state(p_match uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); m public.gz_matches; c jsonb; v_me public.gz_players; v_players jsonb; v_round jsonb; v_last jsonb;
  v_review jsonb; v_item jsonb; v_close timestamptz; v_mine jsonb;
begin
  select * into v_me from public.gz_players where match_id = p_match and user_id = v_uid;
  if v_me.id is null and not private.is_staff() then raise exception 'not allowed' using errcode = '42501'; end if;
  perform private.gz_settle(p_match);
  select * into m from public.gz_matches where id = p_match;
  select * into v_me from public.gz_players where match_id = p_match and user_id = v_uid;
  c := private.gz_conf(m.game);
  select coalesce(jsonb_agg(
    private.gz_player_json(p, v_uid)
    || case when m.status = 'playing' and p.user_id is null and c ->> 'kind' = 'race' then
         (select jsonb_build_object('pos', (x ->> 'pos')::int, 'correct', (x ->> 'correct')::int, 'score', (x ->> 'score')::int,
            'combo', (x ->> 'combo')::int, 'finished', x ->> 'finished_at' is not null) from private.gz_bot_progress(m, p.bot, now()) x)
       when m.status = 'playing' and p.user_id is null and m.game = 'memory' then
         jsonb_build_object('pos', least(3, floor(greatest(0, private.gz_ms(now(), m.starts_at)) / greatest(1, (
           select avg(((e ->> 'ms')::int)) from jsonb_array_elements(p.bot -> 'plan') e)))::int))
       else '{}' end
    || case when m.status = 'playing' and c ->> 'kind' = 'sync' then jsonb_build_object('cur',
         case when p.user_id is null then now() >= m.round_open + make_interval(secs => (private.gz_bot_answer(p.bot, m.id::text || p.id || ':' || m.settled, m.seconds * 1000) ->> 'ms')::int / 1000.0)
              else exists (select 1 from public.gz_answers x where x.match_id = m.id and x.player_id = p.id and x.idx = m.settled) end)
       else '{}' end
    order by p.team, coalesce(p.place, 99), p.score desc, p.id), '[]') into v_players
  from public.gz_players p where p.match_id = m.id;

  if m.status = 'playing' and c ->> 'kind' = 'sync' then
    v_close := private.gz_close_at(m);
    select jsonb_build_object('choice', x.choice, 'correct', x.correct, 'points', x.points, 'key', m.keys ->> m.settled) into v_mine
    from public.gz_answers x where x.match_id = m.id and x.player_id = v_me.id and x.idx = m.settled;
    v_round := jsonb_build_object('idx', m.settled, 'open_at', (extract(epoch from m.round_open) * 1000)::bigint,
      'close_at', (extract(epoch from v_close) * 1000)::bigint, 'mine', v_mine,
      'item', case when now() >= m.round_open - interval '200 milliseconds' then m.items -> m.settled end);
    if m.settled > 0 then
      select jsonb_build_object('idx', m.settled - 1, 'key', m.keys ->> (m.settled - 1), 'item', m.items -> (m.settled - 1),
        'results', coalesce(jsonb_agg(jsonb_build_object('p', x.player_id, 'correct', x.correct, 'points', x.points, 'ms', x.ms, 'choice', case when x.player_id = v_me.id then x.choice end)), '[]'))
      into v_last from public.gz_answers x where x.match_id = m.id and x.idx = m.settled - 1;
    end if;
  elsif m.status = 'playing' and c ->> 'kind' = 'race' and v_me.id is not null then
    v_item := m.items -> v_me.pos;
  end if;

  if m.status = 'done' and v_me.id is not null then
    select coalesce(jsonb_agg(jsonb_build_object('idx', i - 1, 'item', it, 'key', m.keys ->> (i - 1)::int,
        'choice', x.choice, 'correct', coalesce(x.correct, false), 'ms', x.ms, 'points', coalesce(x.points, 0), 'answered', x.idx is not null) order by i), '[]')
    into v_review
    from jsonb_array_elements(m.items) with ordinality t(it, i)
    left join public.gz_answers x on x.match_id = m.id and x.player_id = v_me.id and x.idx = (i - 1)
    where m.game <> 'memory' and (c ->> 'kind' = 'sync' and i <= m.rounds or x.idx is not null);
  end if;

  return jsonb_build_object('id', m.id, 'game', m.game, 'mode', m.mode, 'status', m.status, 'level', m.level, 'code', m.code,
    'subject', (select jsonb_build_object('id', s.id, 'code', s.code, 'name', s.name) from public.subjects s where s.id = m.subject_id),
    'host', m.created_by = v_uid, 'now', (extract(epoch from now()) * 1000)::bigint,
    'starts_at', (extract(epoch from m.starts_at) * 1000)::bigint, 'ends_at', (extract(epoch from m.ends_at) * 1000)::bigint,
    'lobby_until', (extract(epoch from m.lobby_until) * 1000)::bigint,
    'seconds', m.seconds, 'gap_ms', m.gap_ms, 'rounds', m.rounds, 'target', m.target, 'max', m.max_players,
    'players', v_players, 'me', case when v_me.id is not null then private.gz_player_json(v_me, v_uid) || jsonb_build_object(
      'penalty_until', (extract(epoch from v_me.penalty_until) * 1000)::bigint) end,
    'round', v_round, 'last', v_last, 'item', v_item,
    'levels', case when m.game = 'memory' and m.status <> 'lobby' then m.items end,
    'review', v_review);
end $$;

-- ---------- hub ----------
create or replace function public.gz_home()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_codes text[]; v_week timestamptz; v_games jsonb; v_subjects jsonb; v_active uuid;
begin
  if v_uid is null then raise exception 'not allowed' using errcode = '42501'; end if;
  v_week := (date_trunc('week', now() at time zone 'Africa/Lagos')) at time zone 'Africa/Lagos';
  select jamb_subjects into v_codes from public.profiles where id = v_uid;
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'code', s.code, 'name', s.name) order by (s.code = 'eng') desc, s.sort), '[]') into v_subjects
  from public.subjects s join public.exam_subjects es on es.subject_id = s.id and es.exam_id = 1
  where coalesce(cardinality(v_codes), 0) = 0 or s.code = 'eng' or s.code = any (v_codes);
  select coalesce(jsonb_agg(jsonb_build_object('id', g,
      'on', coalesce((private.gz_set(g, 'on') #>> '{}')::boolean, true) and coalesce((private.games_settings() ->> 'on')::boolean, true)
        and (g <> 'words' or (select count(*) from public.gz_words where active) >= 10)
        and (g <> 'memory' or (select count(*) from public.gz_cards where active) >= 6),
      'ready', (g <> 'words' or (select count(*) from public.gz_words where active) >= 10) and (g <> 'memory' or (select count(*) from public.gz_cards where active) >= 6),
      'online', (select count(distinct p.user_id) from public.gz_players p join public.gz_matches m on m.id = p.match_id
                 where m.game = g and m.status in ('lobby', 'playing') and p.user_id is not null and p.joined_at > now() - interval '15 minutes')
               + (select count(*) from public.gz_queue q where q.game = g and q.match_id is null),
      'rating', coalesce(r.rating, 1000), 'played', coalesce(r.played, 0), 'won', coalesce(r.won, 0), 'streak', coalesce(r.streak, 0),
      'xp_win', private.gz_xp(g, 'xp_win', 15), 'xp_play', private.gz_xp(g, 'xp_play', 5)) order by ord), '[]') into v_games
  from unnest(array['duel', 'rush', 'survival', 'blitz', 'words', 'memory', 'relay']) with ordinality u(g, ord)
  left join public.gz_ratings r on r.user_id = v_uid and r.game = g;
  select p.match_id into v_active from public.gz_players p join public.gz_matches m on m.id = p.match_id
  where p.user_id = v_uid and m.status = 'playing' and p.left_at is null and m.ends_at > now() - interval '1 minute' order by p.joined_at desc limit 1;
  return jsonb_build_object(
    'me', jsonb_build_object('name', private.game_name(v_uid), 'avatar', private.gz_avatar(v_uid),
      'rating', coalesce((select max(rating) from public.gz_ratings where user_id = v_uid and played > 0), 1000)),
    'games', v_games, 'subjects', v_subjects, 'active', v_active,
    'week', (select jsonb_build_object('played', count(*), 'won', count(*) filter (where p.place = 1), 'xp', coalesce(sum(p.xp), 0))
             from public.gz_players p join public.gz_matches m on m.id = p.match_id where p.user_id = v_uid and m.status = 'done' and m.finished_at >= v_week),
    'recent', (select coalesce(jsonb_agg(x order by x ->> 'at' desc), '[]') from (
      select jsonb_build_object('id', m.id, 'game', m.game, 'mode', m.mode, 'place', p.place, 'score', p.score, 'xp', p.xp,
        'rating_delta', p.rating_delta, 'at', m.finished_at, 'players', (select count(*) from public.gz_players z where z.match_id = m.id),
        'vs', (select o.name from public.gz_players o where o.match_id = m.id and o.id <> p.id order by o.place nulls last limit 1)) as x
      from public.gz_players p join public.gz_matches m on m.id = p.match_id
      where p.user_id = v_uid and m.status = 'done' order by m.finished_at desc limit 8) t));
end $$;

create or replace function public.gz_leaders(p_game text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'not allowed' using errcode = '42501'; end if;
  return jsonb_build_object('rows', (select coalesce(jsonb_agg(x order by (x ->> 'rank')::int), '[]') from (
      select jsonb_build_object('rank', rank() over (order by t.rating desc, t.won desc), 'name', private.game_name(t.user_id), 'me', t.user_id = v_uid,
        'avatar', private.gz_avatar(t.user_id), 'rating', t.rating, 'played', t.played, 'won', t.won) as x
      from (select g.user_id, case when p_game is null then max(g.rating) else max(g.rating) filter (where g.game = p_game) end as rating,
              sum(g.played) filter (where p_game is null or g.game = p_game) as played, sum(g.won) filter (where p_game is null or g.game = p_game) as won
            from public.gz_ratings g join public.profiles pr on pr.id = g.user_id
            where pr.banned_at is null and not coalesce(pr.hide_on_leaderboard, false)
            group by g.user_id) t
      where t.played >= 3 and t.rating is not null order by t.rating desc limit 50) z),
    'me', (select jsonb_build_object('rating', coalesce(max(rating) filter (where p_game is null or game = p_game), 1000),
             'played', coalesce(sum(played) filter (where p_game is null or game = p_game), 0))
           from public.gz_ratings where user_id = v_uid));
end $$;

-- The student's game look: their real photo when they have one (and allow it), otherwise the avatar they build.
create or replace function public.gz_avatar_save(p jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v jsonb := '{}'; k text;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  foreach k in array array['skin', 'shirt', 'hairColor', 'bg'] loop
    if p ->> k ~ '^#[0-9A-Fa-f]{6}$' then v := v || jsonb_build_object(k, p ->> k); end if;
  end loop;
  if p ->> 'hair' in ('afro', 'bun', 'braids', 'low', 'puffs', 'fade', 'cap', 'hijab') then v := v || jsonb_build_object('hair', p ->> 'hair'); end if;
  if p ->> 'face' in ('smile', 'grin', 'cool', 'focus') then v := v || jsonb_build_object('face', p ->> 'face'); end if;
  if jsonb_typeof(p -> 'glasses') = 'boolean' then v := v || jsonb_build_object('glasses', p -> 'glasses'); end if;
  if jsonb_typeof(p -> 'photo') = 'boolean' then v := v || jsonb_build_object('photo', p -> 'photo'); end if;
  perform private.community_profile_ensure(v_uid);
  update public.community_profiles set game_avatar = v where user_id = v_uid;
  return private.gz_avatar(v_uid);
end $$;

create or replace function private.gz_avatar(p_uid uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('photo', case when coalesce(c.show_photo, true) and coalesce((c.game_avatar ->> 'photo')::boolean, true) then pr.avatar_path end,
    'has_photo', pr.avatar_path is not null, 'preset', c.game_avatar)
  from public.profiles pr left join public.community_profiles c on c.user_id = pr.id where pr.id = p_uid;
$$;

-- Old matches leave the queue; abandoned lobbies close.
create or replace function private.gz_sweep()
returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.gz_queue where joined_at < now() - interval '10 minutes';
  update public.gz_matches set status = 'cancelled' where status = 'lobby' and lobby_until < now() - interval '2 minutes';
  update public.gz_matches set status = 'cancelled' where status = 'playing' and ends_at < now() - interval '30 minutes';
end $$;
select cron.schedule('gz-sweep', '*/10 * * * *', 'select private.gz_sweep()');

revoke all on function public.gz_answer(uuid, integer, text), public.gz_memory(uuid, integer, integer, integer), public.gz_state(uuid),
  public.gz_home(), public.gz_leaders(text), public.gz_avatar_save(jsonb) from public, anon;
grant execute on function public.gz_answer(uuid, integer, text), public.gz_memory(uuid, integer, integer, integer), public.gz_state(uuid),
  public.gz_home(), public.gz_leaders(text), public.gz_avatar_save(jsonb) to authenticated;
