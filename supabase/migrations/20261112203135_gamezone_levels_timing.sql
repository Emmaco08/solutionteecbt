-- Game Zone v2 changes (owner, 12 Nov 2026): tougher Practice vs AI (Expert and Legend), questions reach the phone 1.5 s
-- before a round opens (the app shows them exactly on time, so slow networks lose no answering time).

alter table public.gz_matches drop constraint if exists gz_matches_level_check;
alter table public.gz_matches add constraint gz_matches_level_check check (level in ('easy', 'medium', 'hard', 'expert', 'legend'));

create or replace function private.gz_bot_spec(p_level text, p_seed text)
returns jsonb language plpgsql stable set search_path = '' as $$
declare v_names text[] := array['Chidi','Amaka','Tunde','Zainab','Emeka','Fola','Ibrahim','Ngozi','Seyi','Halima','Obinna','Kemi','Musa','Adaeze','Bayo','Funmi','Yusuf','Chioma','Dayo','Hauwa'];
  v_skins text[] := array['#5C3A1E','#8D5524','#C68642','#F1C27D'];
  v_hairs text[] := array['afro','bun','braids','low'];
  v_shirts text[] := array['#2563B3','#E0335A','#1FA463','#7A4FD6','#22A6C4','#F2B233'];
  r double precision := private.gz_rand(p_seed);
begin
  return jsonb_build_object(
    'level', p_level,
    'acc', case p_level when 'easy' then 0.5 when 'hard' then 0.86 when 'expert' then 0.93 when 'legend' then 0.97 else 0.68 end + (r - 0.5) * 0.04,
    'fast', case p_level when 'easy' then 0.55 when 'hard' then 0.18 when 'expert' then 0.11 when 'legend' then 0.07 else 0.32 end,
    'slow', case p_level when 'easy' then 0.85 when 'hard' then 0.42 when 'expert' then 0.28 when 'legend' then 0.19 else 0.62 end,
    'name', v_names[1 + floor(r * 20)::int % 20],
    'avatar', jsonb_build_object('skin', v_skins[1 + floor(private.gz_rand(p_seed || 's') * 4)::int % 4],
      'hair', v_hairs[1 + floor(private.gz_rand(p_seed || 'h') * 4)::int % 4],
      'shirt', v_shirts[1 + floor(private.gz_rand(p_seed || 't') * 6)::int % 6],
      'hairColor', '#1A1206', 'glasses', private.gz_rand(p_seed || 'g') < 0.25));
end $$;

create or replace function private.gz_bot_answer(p_bot jsonb, p_seed text, p_limit_ms integer)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object('ok', private.gz_rand(p_seed || 'ok') < (p_bot ->> 'acc')::float,
    'ms', greatest(450, (p_limit_ms * ((p_bot ->> 'fast')::float + private.gz_rand(p_seed || 'ms') * ((p_bot ->> 'slow')::float - (p_bot ->> 'fast')::float)))::int));
$$;

create or replace function public.gz_find(p_game text, p_mode text, p_subject smallint default null, p_level text default 'medium')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); c jsonb := private.gz_conf(p_game); v_sub smallint; v_id uuid; v_rating integer; v_n integer;
begin
  perform private.gz_me_check(v_uid, p_game);
  if p_mode not in ('quick', 'ranked', 'ai', 'friend') then raise exception 'mode' using errcode = '22023'; end if;
  if p_level not in ('easy', 'medium', 'hard', 'expert', 'legend') then p_level := 'medium'; end if;
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
    v_level := case when q.rating < 950 then 'easy' when q.rating > 1600 then 'legend' when q.rating > 1400 then 'expert' when q.rating > 1150 then 'hard' else 'medium' end;
    v_id := private.gz_new(v_uid, q.game, case when q.ranked then 'ranked' else 'quick' end, q.subject_id, v_level, 0);
    perform private.gz_start(v_id);
    return private.gz_found(v_id, '{"bot":true}');
  end if;
  return jsonb_build_object('status', 'waiting', 'waited', extract(epoch from now() - q.joined_at)::int, 'wait', v_wait,
    'searching', (select count(*) from public.gz_queue x where x.game = q.game and x.match_id is null));
end $$;

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
      'item', case when now() >= m.round_open - interval '1500 milliseconds' then m.items -> m.settled end);
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
