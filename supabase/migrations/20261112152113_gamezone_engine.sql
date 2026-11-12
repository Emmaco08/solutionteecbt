-- Game Zone v2 (D-157), part 2: the engine. Everything is timed by the server clock; answers are only sent after a
-- round closes (or to the player who just answered); bots are deterministic; places, ratings and XP are set on the server.

create or replace function private.gz_conf(p_game text)
returns jsonb language sql immutable set search_path = '' as $$
  select case p_game
    when 'duel' then '{"kind":"sync","max":2,"min":2,"seconds":15,"gap":3500,"rounds":10}'
    when 'words' then '{"kind":"sync","max":2,"min":2,"seconds":10,"gap":3000,"rounds":10}'
    when 'survival' then '{"kind":"sync","max":20,"min":10,"seconds":12,"gap":3500,"rounds":20,"lobby":15}'
    when 'relay' then '{"kind":"sync","max":6,"min":6,"seconds":15,"gap":3500,"rounds":12,"lobby":15}'
    when 'rush' then '{"kind":"race","max":6,"min":4,"seconds":120,"target":10,"lobby":12}'
    when 'blitz' then '{"kind":"race","max":2,"min":2,"seconds":60,"target":999}'
    when 'memory' then '{"kind":"memory","max":2,"min":2,"seconds":180,"rounds":3}'
  end::jsonb;
$$;

create or replace function private.gz_rand(p_seed text)
returns double precision language sql immutable set search_path = '' as $$
  select ('x' || substr(md5(p_seed), 1, 8))::bit(32)::bigint::double precision / 4294967295.0;
$$;

create or replace function private.gz_ms(a timestamptz, b timestamptz)
returns integer language sql immutable set search_path = '' as $$
  select (extract(epoch from (a - b)) * 1000)::int;
$$;

create or replace function private.gz_round_at(m public.gz_matches, r integer)
returns timestamptz language sql stable set search_path = '' as $$
  select m.starts_at + make_interval(secs => r * (m.seconds * 1000 + m.gap_ms) / 1000.0);
$$;

-- A bot of the chosen level: accuracy and answer speed, a Nigerian first name and an avatar.
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
    'acc', case p_level when 'easy' then 0.5 when 'hard' then 0.86 else 0.68 end + (r - 0.5) * 0.08,
    'fast', case p_level when 'easy' then 0.55 when 'hard' then 0.18 else 0.32 end,
    'slow', case p_level when 'easy' then 0.85 when 'hard' then 0.42 else 0.62 end,
    'name', v_names[1 + floor(r * 20)::int % 20],
    'avatar', jsonb_build_object('skin', v_skins[1 + floor(private.gz_rand(p_seed || 's') * 4)::int % 4],
      'hair', v_hairs[1 + floor(private.gz_rand(p_seed || 'h') * 4)::int % 4],
      'shirt', v_shirts[1 + floor(private.gz_rand(p_seed || 't') * 6)::int % 6],
      'hairColor', '#1A1206', 'glasses', private.gz_rand(p_seed || 'g') < 0.25));
end $$;

-- A bot's answer to item i: right or wrong, and how many milliseconds it took.
create or replace function private.gz_bot_answer(p_bot jsonb, p_seed text, p_limit_ms integer)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object('ok', private.gz_rand(p_seed || 'ok') < (p_bot ->> 'acc')::float,
    'ms', greatest(900, (p_limit_ms * ((p_bot ->> 'fast')::float + private.gz_rand(p_seed || 'ms') * ((p_bot ->> 'slow')::float - (p_bot ->> 'fast')::float)))::int));
$$;

create or replace function private.gz_mem_points(p_pairs integer, p_moves integer, p_ms integer)
returns integer language sql immutable set search_path = '' as $$
  select greatest(0, p_pairs * 100 + greatest(0, 3000 - p_ms / 20) - greatest(0, p_moves - p_pairs) * 15);
$$;

-- Admin settings for Game Zone: games.gz.<key>, and games.gz.games.<game>.<key> to override one game.
create or replace function private.gz_set(p_game text, p_key text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(private.games_settings() -> 'gz' -> 'games' -> p_game -> p_key, private.games_settings() -> 'gz' -> p_key);
$$;

create or replace function private.gz_xp(p_game text, p_key text, p_default integer)
returns integer language sql stable security definer set search_path = '' as $$
  select greatest(0, least(500, coalesce((private.gz_set(p_game, p_key) #>> '{}')::int, p_default)));
$$;

-- ---------- items ----------
create or replace function private.gz_blitz_items(p_seed text, p_n integer)
returns jsonb language plpgsql volatile set search_path = '' as $$
declare v_items jsonb := '[]'; v_keys jsonb := '[]'; i integer; t integer; a integer; b integer; ans integer; q text; opts integer[]; d integer; k integer;
begin
  for i in 0 .. p_n - 1 loop
    t := floor(random() * 6)::int;
    if t = 0 then a := 10 + floor(random() * (40 + i * 2))::int; b := 10 + floor(random() * (40 + i * 2))::int; ans := a + b; q := a || ' + ' || b;
    elsif t = 1 then a := 20 + floor(random() * (60 + i * 2))::int; b := 1 + floor(random() * a)::int; ans := a - b; q := a || ' − ' || b;
    elsif t = 2 then a := 2 + floor(random() * (8 + i / 10))::int; b := 2 + floor(random() * 11)::int; ans := a * b; q := a || ' × ' || b;
    elsif t = 3 then b := 2 + floor(random() * 11)::int; ans := 2 + floor(random() * (10 + i / 10))::int; a := b * ans; q := a || ' ÷ ' || b;
    elsif t = 4 then a := (array[5, 10, 15, 20, 25, 50])[1 + floor(random() * 6)::int]; b := 20 * (1 + floor(random() * 20)::int); ans := a * b / 100; q := a || '% of ' || b;
    else a := 2 + floor(random() * 14)::int; ans := a * a; q := a || '²';
    end if;
    opts := array[ans];
    while cardinality(opts) < 4 loop
      d := (1 + floor(random() * greatest(3, least(12, abs(ans) / 5 + 2)))::int) * (case when random() < 0.5 then -1 else 1 end);
      if t in (2, 5) and random() < 0.5 then d := d * 2; end if;
      k := ans + d;
      if k >= 0 and not (k = any (opts)) then opts := opts || k; end if;
    end loop;
    select array_agg(x order by random()) into opts from unnest(opts) x;
    v_items := v_items || jsonb_build_array(jsonb_build_object('body', q, 'options', (select jsonb_agg(jsonb_build_object('key', o::text, 'text', o::text)) from unnest(opts) o)));
    v_keys := v_keys || to_jsonb(ans::text);
  end loop;
  return jsonb_build_object('items', v_items, 'keys', v_keys);
end $$;

create or replace function private.gz_build_items(p_match uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches; v_n integer; v_ids uuid[]; v_items jsonb := '[]'; v_keys jsonb := '[]'; q record; w record; r jsonb; lvl integer; v_pairs integer;
begin
  select * into m from public.gz_matches where id = p_match;
  if m.game in ('duel', 'survival', 'relay', 'rush') then
    v_n := case when m.game = 'rush' then 40 else m.rounds end;
    v_ids := private.game_pick(m.exam_id, m.subject_id, v_n,
      exists (select 1 from public.gz_players p where p.match_id = m.id and p.user_id is not null and not private.has_premium(p.user_id)), m.game = 'survival');
    if cardinality(v_ids) < least(v_n, 5) then raise exception 'no_questions'; end if;
    for q in select qq.id, qq.body, qq.options, qq.answer, ord from unnest(v_ids) with ordinality u(id, ord) join public.questions qq on qq.id = u.id order by ord loop
      v_items := v_items || jsonb_build_array(jsonb_build_object('body', q.body,
        'options', (select jsonb_agg(jsonb_build_object('key', k, 'text', q.options ->> k) order by md5(p_match::text || q.id::text || k)) from jsonb_object_keys(q.options) k)));
      v_keys := v_keys || to_jsonb(q.answer);
    end loop;
    if m.game <> 'rush' then update public.gz_matches set rounds = least(rounds, jsonb_array_length(v_items)) where id = m.id; end if;
  elsif m.game = 'words' then
    for w in select * from public.gz_words where active order by random() limit m.rounds loop
      v_items := v_items || jsonb_build_array(jsonb_build_object('kind', w.kind, 'word', w.word,
        'body', case w.kind when 'synonym' then 'Same meaning as' when 'antonym' then 'Opposite of' else 'Which is spelt right?' end,
        'options', (select jsonb_agg(jsonb_build_object('key', o, 'text', o) order by random()) from unnest(w.answer || w.wrong[1:3]) o)));
      v_keys := v_keys || to_jsonb(w.answer);
    end loop;
    if jsonb_array_length(v_items) < 5 then raise exception 'no_content'; end if;
    update public.gz_matches set rounds = jsonb_array_length(v_items) where id = m.id;
  elsif m.game = 'blitz' then
    r := private.gz_blitz_items(p_match::text, 90);
    v_items := r -> 'items'; v_keys := r -> 'keys';
  elsif m.game = 'memory' then
    for lvl in 1 .. 3 loop
      v_pairs := 3 + lvl;
      v_items := v_items || jsonb_build_array((
        with picked as (select x.id, x.front, x.back from public.gz_cards x where x.active order by (x.subject_id = m.subject_id) desc nulls last, random() limit v_pairs),
        faces as (select id as pair, front as text from picked union all select id, back from picked)
        select jsonb_build_object('level', lvl, 'pairs', (select count(*) from picked),
          'cards', (select jsonb_agg(jsonb_build_object('pair', f.pair, 'text', f.text) order by md5(p_match::text || lvl || f.text || f.pair)) from faces f))));
    end loop;
    if (select count(*) from public.gz_cards where active) < 6 then raise exception 'no_content'; end if;
  end if;
  update public.gz_matches set items = v_items, keys = v_keys where id = p_match;
end $$;

-- ---------- players ----------
create or replace function private.gz_avatar(p_uid uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('photo', case when coalesce(c.show_photo, true) then pr.avatar_path end, 'preset', c.game_avatar)
  from public.profiles pr left join public.community_profiles c on c.user_id = pr.id where pr.id = p_uid;
$$;

create or replace function private.gz_add_bots(p_match uuid, p_n integer)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches; i integer; v_spec jsonb; v_seed text; v_plan jsonb; j integer; v_limit integer; k integer;
begin
  select * into m from public.gz_matches where id = p_match;
  for i in 1 .. greatest(p_n, 0) loop
    v_seed := p_match::text || ':bot:' || i || ':' || random();
    v_spec := private.gz_bot_spec(m.level, v_seed);
    if m.game in ('rush', 'blitz') then
      v_limit := case when m.game = 'blitz' then 6000 else 15000 end;
      select jsonb_agg(private.gz_bot_answer(v_spec, v_seed || ':' || j, v_limit) order by j) into v_plan from generate_series(0, 89) j;
      v_spec := v_spec || jsonb_build_object('plan', v_plan);
    elsif m.game = 'memory' then
      v_spec := v_spec || jsonb_build_object('plan', (select jsonb_agg(jsonb_build_object(
        'moves', (3 + k) + floor(private.gz_rand(v_seed || k) * (3 + k) * (1.4 - (v_spec ->> 'acc')::float))::int,
        'ms', ((3 + k) * (2600 - 1400 * (v_spec ->> 'acc')::float) + private.gz_rand(v_seed || 'm' || k) * 6000)::int) order by k) from generate_series(1, 3) k));
    end if;
    insert into public.gz_players (match_id, user_id, bot, name) values (p_match, null, v_spec, v_spec ->> 'name');
  end loop;
end $$;

create or replace function private.gz_player_json(p public.gz_players, p_me uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', p.id, 'me', p.user_id is not null and p.user_id = p_me, 'bot', p.user_id is null, 'name', p.name,
    'avatar', case when p.user_id is null then jsonb_build_object('photo', null, 'preset', p.bot -> 'avatar') else private.gz_avatar(p.user_id) end,
    'team', p.team, 'score', p.score, 'correct', p.correct, 'answered', p.answered, 'lives', p.lives, 'alive', p.alive, 'out_round', p.out_round,
    'pos', p.pos, 'combo', p.combo, 'finished', p.finished_at is not null, 'place', p.place,
    'rating', p.rating_before, 'rating_delta', p.rating_delta, 'xp', p.xp,
    'level', case when p.user_id is null then p.bot ->> 'level' end);
$$;

-- A race bot's progress at a moment (rush: a wrong answer costs 2 s; blitz: combo points).
create or replace function private.gz_bot_progress(m public.gz_matches, p_bot jsonb, p_until timestamptz)
returns jsonb language plpgsql stable set search_path = '' as $$
declare t integer := greatest(0, private.gz_ms(least(p_until, m.ends_at), m.starts_at)); acc integer := 0; a jsonb; i integer := 0;
  v_correct integer := 0; v_score integer := 0; v_combo integer := 0; v_best integer := 0; v_fin timestamptz;
begin
  for a in select x from jsonb_array_elements(p_bot -> 'plan') x loop
    acc := acc + (a ->> 'ms')::int;
    exit when acc > t;
    i := i + 1;
    if (a ->> 'ok')::boolean then
      v_correct := v_correct + 1; v_combo := v_combo + 1; v_best := greatest(v_best, v_combo);
      v_score := v_score + case when m.game = 'blitz' then 10 * least(v_combo, 5) else 100 end;
      if m.game = 'rush' and v_correct >= m.target then v_fin := m.starts_at + make_interval(secs => acc / 1000.0); exit; end if;
    else
      v_combo := 0;
      if m.game = 'rush' then acc := acc + 2000; end if;
    end if;
  end loop;
  return jsonb_build_object('pos', i, 'answered', i, 'correct', v_correct, 'score', v_score, 'combo', v_combo, 'best', v_best, 'finished_at', v_fin);
end $$;

-- ---------- start, settle, finish ----------
create or replace function private.gz_send(p_match uuid, p_event text, p_payload jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform realtime.send(p_payload, p_event, 'gz:' || p_match::text, true);
exception when others then null;
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
    perform private.gz_add_bots(m.id, greatest((c ->> 'min')::int, case when m.game = 'relay' then 6 else 0 end) - v_n);
  end if;
  if m.game = 'relay' then
    update public.gz_players p set team = 1 + (x.rn % 2) from (select id, row_number() over (order by user_id is null, id) - 1 as rn from public.gz_players where match_id = m.id) x where p.id = x.id;
  end if;
  perform private.gz_build_items(m.id);
  select * into m from public.gz_matches where id = p_match;
  v_secs := case when c ->> 'kind' = 'sync' then ceil(m.rounds * (m.seconds * 1000 + m.gap_ms) / 1000.0)::int else (c ->> 'seconds')::int end;
  update public.gz_matches set status = 'playing', starts_at = now() + interval '4 seconds', ends_at = now() + interval '4 seconds' + make_interval(secs => v_secs) where id = m.id;
  update public.gz_players gp set rating_before = coalesce((select r.rating from public.gz_ratings r where r.user_id = gp.user_id and r.game = m.game), 1000), last_at = now() + interval '4 seconds'
  where gp.match_id = m.id;
  perform private.gz_send(m.id, 'start', jsonb_build_object('id', m.id));
end $$;

create or replace function private.gz_finish(p_match uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches; r record; v_xp integer; v_k integer := 32; v_avg integer;
  v_win_team smallint; v_delta float; o record; v_n integer;
begin
  select * into m from public.gz_matches where id = p_match for update;
  if m.status = 'done' then return; end if;
  -- Places.
  if m.game = 'relay' then
    select team into v_win_team from public.gz_players where match_id = m.id group by team order by sum(score) desc limit 1;
    update public.gz_players set place = case when team = v_win_team then 1 else 2 end where match_id = m.id;
  else
    update public.gz_players p set place = x.pl from (
      select id, rank() over (order by
        case when m.game = 'survival' then (alive)::int else 0 end desc,
        case when m.game = 'survival' then coalesce(out_round, 999) else 0 end desc,
        case when m.game = 'rush' then coalesce(extract(epoch from finished_at), 9e12) else 0 end asc,
        case when m.game = 'rush' then correct else 0 end desc,
        score desc, correct desc) as pl
      from public.gz_players where match_id = m.id) x where p.id = x.id;
  end if;
  -- Ratings (ranked only; bots count at the players' average).
  if m.mode = 'ranked' then
    select coalesce(avg(rating_before), 1000)::int, count(*) into v_avg, v_n from public.gz_players where match_id = m.id;
    for r in select * from public.gz_players where match_id = m.id and user_id is not null loop
      v_delta := 0;
      for o in select * from public.gz_players where match_id = m.id and id <> r.id loop
        v_delta := v_delta + (case when r.place < o.place then 1 when r.place = o.place then 0.5 else 0 end)
          - 1.0 / (1 + power(10, (coalesce(o.rating_before, v_avg) - r.rating_before) / 400.0));
      end loop;
      update public.gz_players set rating_delta = round(v_k * v_delta / greatest(v_n - 1, 1)) where id = r.id;
    end loop;
  end if;
  -- XP and stats for students (every amount is set in Admin -> Games; a game can override the defaults).
  for r in select * from public.gz_players where match_id = m.id and user_id is not null loop
    v_xp := private.game_xp(r.user_id, private.gz_xp(m.game, 'xp_play', 5), 'game_play', m.id::text, 'gz:' || m.id || ':' || r.user_id || ':play');
    if r.place = 1 and (m.game = 'memory' or (r.answered > 0 and r.correct::float / r.answered >= 0.4))
       and (select count(*) from public.gz_players x where x.match_id = m.id) > 1 then
      v_xp := v_xp + private.game_xp(r.user_id, private.gz_xp(m.game, 'xp_win', 15)
        + case when m.mode = 'ranked' then private.gz_xp(m.game, 'xp_ranked_win', 10) else 0 end
        + case when coalesce((select g.streak from public.gz_ratings g where g.user_id = r.user_id and g.game = m.game), 0) + 1 >= 3
               then private.gz_xp(m.game, 'xp_streak', 10) else 0 end,
        'game_win', m.id::text, 'gz:' || m.id || ':' || r.user_id || ':win');
    end if;
    update public.gz_players set xp = v_xp where id = r.id;
    insert into public.gz_ratings as g (user_id, game, rating, played, won, streak, best_streak)
    values (r.user_id, m.game, 1000 + coalesce((select rating_delta from public.gz_players where id = r.id), 0), 1, (r.place = 1)::int,
            (r.place = 1)::int, (r.place = 1)::int)
    on conflict (user_id, game) do update set
      rating = g.rating + coalesce((select rating_delta from public.gz_players where id = r.id), 0),
      played = g.played + 1, won = g.won + (r.place = 1)::int,
      streak = case when r.place = 1 then g.streak + 1 else 0 end,
      best_streak = greatest(g.best_streak, case when r.place = 1 then g.streak + 1 else 0 end), updated_at = now();
  end loop;
  update public.gz_matches set status = 'done', finished_at = now() where id = m.id;
  perform private.gz_send(m.id, 'done', jsonb_build_object('id', m.id));
end $$;

create or replace function private.gz_settle(p_match uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches; c jsonb; v_closed integer; r integer; b record; a jsonb; v_key text; v_ok boolean; v_alive integer;
  v_end boolean := false; v_humans integer; v_left integer; v_pr jsonb; v_limit integer;
begin
  select * into m from public.gz_matches where id = p_match for update;
  if not found or m.status in ('done', 'cancelled') then return; end if;
  c := private.gz_conf(m.game);
  if m.status = 'lobby' then
    select count(*) filter (where user_id is not null), count(*) into v_humans, v_left from public.gz_players where match_id = m.id;
    if v_left >= m.max_players or (m.lobby_until <= now() and (m.mode <> 'friend' or v_humans >= 2)) then
      perform private.gz_start(m.id);
    elsif m.mode = 'friend' and m.lobby_until <= now() then
      update public.gz_matches set status = 'cancelled' where id = m.id;
    end if;
    return;
  end if;
  if now() < m.starts_at then return; end if;
  if c ->> 'kind' = 'sync' then
    v_limit := m.seconds * 1000;
    v_closed := least(m.rounds, floor(private.gz_ms(now(), m.starts_at + make_interval(secs => m.seconds + 0.4)) / (m.seconds * 1000.0 + m.gap_ms))::int + 1);
    if private.gz_ms(now(), m.starts_at) < v_limit + 400 then v_closed := 0; end if;
    r := m.settled;
    while r < v_closed loop
      v_key := m.keys ->> r;
      for b in select * from public.gz_players where match_id = m.id and user_id is null and alive loop
        a := private.gz_bot_answer(b.bot, m.id::text || b.id || ':' || r, v_limit);
        v_ok := (a ->> 'ok')::boolean;
        insert into public.gz_answers (match_id, player_id, idx, choice, correct, ms, points)
        values (m.id, b.id, r, case when v_ok then v_key else 'x' end, v_ok, (a ->> 'ms')::int,
                case when v_ok then 100 + round(50 * greatest(0, 1 - (a ->> 'ms')::float / v_limit))::int else 0 end)
        on conflict do nothing;
        update public.gz_players set answered = answered + 1, correct = correct + v_ok::int,
          score = score + case when v_ok then 100 + round(50 * greatest(0, 1 - (a ->> 'ms')::float / v_limit))::int else 0 end,
          combo = case when v_ok then combo + 1 else 0 end, best_combo = greatest(best_combo, case when v_ok then combo + 1 else 0 end)
        where id = b.id;
      end loop;
      if m.game = 'survival' then
        update public.gz_players p set lives = lives - 1 where p.match_id = m.id and p.alive
          and not exists (select 1 from public.gz_answers x where x.match_id = m.id and x.player_id = p.id and x.idx = r and x.correct);
        update public.gz_players set alive = false, out_round = r where match_id = m.id and alive and lives <= 0;
        select count(*) into v_alive from public.gz_players where match_id = m.id and alive;
        if v_alive <= 1 then v_end := true; end if;
        if not exists (select 1 from public.gz_players where match_id = m.id and alive and user_id is not null) then v_end := true; end if;
      end if;
      r := r + 1;
      update public.gz_matches set settled = r where id = m.id;
      exit when v_end;
    end loop;
    if v_end or r >= m.rounds then perform private.gz_finish(m.id); end if;
  elsif c ->> 'kind' = 'race' then
    select count(*) into v_left from public.gz_players where match_id = m.id and user_id is not null and finished_at is null and alive;
    if now() >= m.ends_at or v_left = 0 then
      for b in select * from public.gz_players where match_id = m.id and user_id is null loop
        v_pr := private.gz_bot_progress(m, b.bot, now());
        update public.gz_players set pos = (v_pr ->> 'pos')::int, answered = (v_pr ->> 'answered')::int, correct = (v_pr ->> 'correct')::int,
          score = (v_pr ->> 'score')::int, best_combo = (v_pr ->> 'best')::int, finished_at = (v_pr ->> 'finished_at')::timestamptz where id = b.id;
      end loop;
      perform private.gz_finish(m.id);
    end if;
  else
    select count(*) into v_left from public.gz_players where match_id = m.id and user_id is not null and finished_at is null and alive;
    if now() >= m.ends_at or v_left = 0 then
      for b in select * from public.gz_players where match_id = m.id and user_id is null loop
        update public.gz_players set pos = 3, finished_at = now(), score = (
          select sum(private.gz_mem_points(3 + k, ((b.bot -> 'plan' -> (k - 1)) ->> 'moves')::int, ((b.bot -> 'plan' -> (k - 1)) ->> 'ms')::int))::int
          from generate_series(1, 3) k) where id = b.id;
      end loop;
      perform private.gz_finish(m.id);
    end if;
  end if;
end $$;

-- Owner: SolutionTee reviews the starter words and cards in Admin before they go live.
update public.gz_words set active = false;
update public.gz_cards set active = false;
update public.app_settings set value = jsonb_set(value, '{gz}', coalesce(value -> 'gz', '{}') || '{"xp_ranked_win":10,"xp_streak":10}')
where key = 'games';
