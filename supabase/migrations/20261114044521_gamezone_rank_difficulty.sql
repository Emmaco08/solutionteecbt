-- Game Zone: tougher as students rank up (owner, 14 Nov 2026). Quick and Ranked follow the players' rating in that game,
-- VS AI follows the chosen level: questions lean easy for beginners and hard at the top; Comprehension Clash also picks
-- harder passages and scrolls them faster. Group lobbies get their bot level from the first student's rating.

-- 0 (easy) … 2 (hard): the difficulty a match aims at.
create or replace function private.gz_target(m public.gz_matches)
returns numeric language sql stable security definer set search_path = '' as $$
  select case
    when m.mode = 'ai' then case m.level when 'easy' then 0.3 when 'hard' then 1.4 when 'expert' then 1.8 when 'legend' then 2 else 1 end
    else (select case when z.r < 1050 then 0.5 when z.r < 1200 then 1 when z.r < 1400 then 1.5 else 2 end
          from (select coalesce(avg(coalesce(g.rating, 1000)), 1000) r
                from public.gz_players p left join public.gz_ratings g on g.user_id = p.user_id and g.game = m.game
                where p.match_id = m.id and p.user_id is not null) z)
  end;
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
  select coalesce((select rating from public.gz_ratings where user_id = v_uid and game = p_game), 1000) into v_rating;
  if p_mode = 'ai' then
    v_id := private.gz_new(v_uid, p_game, 'ai', v_sub, p_level, 0);
    perform private.gz_start(v_id);
    return private.gz_found(v_id);
  elsif p_mode = 'friend' then
    v_id := private.gz_new(v_uid, p_game, 'friend', v_sub, p_level, 600);
    return private.gz_found(v_id);
  elsif (c ->> 'max')::int > 2 then
    select m.id into v_id from public.gz_matches m
    where m.game = p_game and m.mode = p_mode and m.status = 'lobby' and m.subject_id is not distinct from v_sub
      and m.lobby_until > now() + interval '2 seconds'
      and (select count(*) from public.gz_players p where p.match_id = m.id) < m.max_players
    order by m.created_at limit 1 for update skip locked;
    if v_id is null then
      -- Bots that fill the seats play at the level of the student who opened the lobby.
      v_id := private.gz_new(v_uid, p_game, p_mode, v_sub,
        case when v_rating < 950 then 'easy' when v_rating > 1600 then 'legend' when v_rating > 1400 then 'expert' when v_rating > 1150 then 'hard' else 'medium' end,
        coalesce((c ->> 'lobby')::int, 15));
    else
      insert into public.gz_players (match_id, user_id, name) values (v_id, v_uid, private.game_name(v_uid)) on conflict do nothing;
      select count(*) into v_n from public.gz_players where match_id = v_id;
      perform private.gz_send(v_id, 'joined', jsonb_build_object('n', v_n));
      if v_n >= (c ->> 'max')::int then perform private.gz_start(v_id); end if;
    end if;
    return private.gz_found(v_id);
  else
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

create or replace function private.gz_build_items(p_match uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches; v_n integer; v_ids uuid[]; v_items jsonb := '[]'; v_keys jsonb := '[]'; q record; w record; r jsonb; lvl integer;
  v_pairs integer; v_mode text; v_humans uuid[]; v_free boolean; v_hard boolean; v_own integer; v_seen text[] := '{}'; v_t numeric;
begin
  select * into m from public.gz_matches where id = p_match;
  if m.game in ('duel', 'survival', 'relay', 'rush') then
    v_n := case when m.game = 'rush' then 40 else m.rounds end;
    -- The difficulty follows the players' level (Survival always leans hard).
    v_t := private.gz_target(m);
    if m.game = 'survival' then v_t := greatest(v_t, 1.5); end if;
    v_hard := v_t >= 1.5;
    select array_agg(user_id) into v_humans from public.gz_players where match_id = m.id and user_id is not null;
    v_free := exists (select 1 from unnest(coalesce(v_humans, '{}')) u where not private.has_premium(u));
    v_mode := private.gz_source(m.subject_id);
    select count(*) into v_own from public.gz_questions g where g.active and g.subject_id = m.subject_id;
    if v_mode = 'own' and v_own < v_n then v_mode := 'both'; end if;
    if v_mode <> 'own' then
      v_ids := private.game_pick(m.exam_id, m.subject_id, v_n * 3, v_free, v_hard);
      if v_mode = 'jamb' and cardinality(v_ids) < least(v_n, 5) then v_mode := 'both'; end if;
    end if;
    select coalesce(array_agg(s.qkey), '{}') into v_seen from public.gz_seen s
    where s.user_id = any (coalesce(v_humans, '{}')) and s.seen_at > now() - interval '21 days';
    for q in
      with cand as (
        select 'g:' || g.id as k, g.body, g.options, g.answer, g.difficulty from public.gz_questions g
        where v_mode in ('own', 'both') and g.active and g.subject_id = m.subject_id
        union all
        select 'q:' || x.id, x.body, x.options, x.answer, coalesce(x.difficulty::text, 'medium') from public.questions x
        where v_mode in ('jamb', 'both') and x.id = any (coalesce(v_ids, '{}'))
      )
      select * from cand
      order by (k = any (v_seen)), abs((case difficulty when 'easy' then 0 when 'hard' then 2 else 1 end) - v_t), random()
      limit v_n
    loop
      v_items := v_items || jsonb_build_array(jsonb_build_object('body', q.body,
        'options', (select jsonb_agg(jsonb_build_object('key', o, 'text', q.options ->> o) order by md5(p_match::text || q.k || o)) from jsonb_object_keys(q.options) o)));
      v_keys := v_keys || to_jsonb(q.answer);
      insert into public.gz_seen (user_id, qkey) select u, q.k from unnest(coalesce(v_humans, '{}')) u
      on conflict (user_id, qkey) do update set seen_at = now();
    end loop;
    if jsonb_array_length(v_items) < least(v_n, 5) then raise exception 'no_questions'; end if;
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
-- Picks a passage the players have not seen lately (own and/or JAMB, by the English source setting) and its questions.
-- Higher-rated players (or a harder VS AI level) get harder passages that scroll faster (owner, 14 Nov 2026).
create or replace function private.gz_reading_build(p_match uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches; v_humans uuid[]; v_free boolean; v_mode text; v_years smallint[]; v_seen text[] := '{}';
  v_pick record; v_items jsonb := '[]'; v_keys jsonb := '[]'; rq record; v_words integer; v_wpm integer; v_read integer; v_n integer;
  v_t numeric;
begin
  select * into m from public.gz_matches where id = p_match;
  v_t := private.gz_target(m);
  select array_agg(user_id) into v_humans from public.gz_players where match_id = m.id and user_id is not null;
  v_free := exists (select 1 from unnest(coalesce(v_humans, '{}')) u where not private.has_premium(u));
  v_mode := private.gz_source(m.subject_id);
  v_n := least(6, greatest(3, coalesce((private.gz_set('reading', 'rounds') #>> '{}')::int, 5)));
  select array_agg(distinct y.year) into v_years from public.exam_years y
  where y.exam_id = coalesce(m.exam_id, 1) and y.status = 'published'
    and case when v_free then private.tier_year_open('free', coalesce(m.exam_id, 1::smallint), y.year) else private.year_open(coalesce(m.exam_id, 1::smallint), y.year) end;
  select coalesce(array_agg(s.qkey), '{}') into v_seen from public.gz_seen s
  where s.user_id = any (coalesce(v_humans, '{}')) and s.seen_at > now() - interval '21 days';

  with own as (
    select 'gp:' || g.id as k, g.id::text as ref, 'own' as src, g.title, g.body, (case g.difficulty when 'easy' then 0 when 'hard' then 2 else 1 end)::numeric as d from public.gz_passages g
    where v_mode in ('own', 'both') and g.active and (select count(*) from public.gz_passage_questions x where x.passage_id = g.id) >= 3),
  jamb as (
    select 'jp:' || p.id as k, p.id::text as ref, 'jamb' as src, coalesce(p.title, '') as title, p.body, 1.5::numeric as d from public.passages p
    where v_mode in ('jamb', 'both') and p.exam_id = coalesce(m.exam_id, 1) and char_length(p.body) between 200 and 6000
      and (select count(*) from public.questions q where q.passage_id = p.id and q.status = 'published' and q.deleted_at is null
             and q.year = any (coalesce(v_years, '{}')) and q.image_path is null and jsonb_typeof(q.options) = 'object' and q.options ? q.answer
             and coalesce(q.section::text, 'comprehension') = 'comprehension') >= 3),
  cand as (select * from own union all select * from jamb)
  select * into v_pick from cand order by (k = any (v_seen)), abs(d - v_t), random() limit 1;
  -- Too few of our own: use any.
  if v_pick.k is null and v_mode = 'own' then
    select 'jp:' || p.id as k, p.id::text as ref, 'jamb' as src, coalesce(p.title, '') as title, p.body into v_pick from public.passages p
    where p.exam_id = coalesce(m.exam_id, 1) and char_length(p.body) between 200 and 6000
      and (select count(*) from public.questions q where q.passage_id = p.id and q.status = 'published' and q.deleted_at is null
             and q.year = any (coalesce(v_years, '{}')) and q.image_path is null and jsonb_typeof(q.options) = 'object' and q.options ? q.answer
             and coalesce(q.section::text, 'comprehension') = 'comprehension') >= 3
    order by random() limit 1;
  end if;
  if v_pick.k is null then raise exception 'no_questions'; end if;

  for rq in
    select * from (
      select x.body, x.options, x.answer, x.kind, x.sort as o from public.gz_passage_questions x where v_pick.src = 'own' and x.passage_id = v_pick.ref::bigint
      union all
      select x.body, x.options, x.answer, 'other', 0 from public.questions x where v_pick.src = 'jamb' and x.passage_id = v_pick.ref::uuid
        and x.status = 'published' and x.deleted_at is null and x.year = any (coalesce(v_years, '{}')) and x.image_path is null
        and jsonb_typeof(x.options) = 'object' and x.options ? x.answer and coalesce(x.section::text, 'comprehension') = 'comprehension') t
    order by o, random() limit v_n
  loop
    v_items := v_items || jsonb_build_array(jsonb_build_object('body', rq.body, 'kind', rq.kind,
      'options', (select jsonb_agg(jsonb_build_object('key', o, 'text', rq.options ->> o) order by md5(p_match::text || rq.body || o)) from jsonb_object_keys(rq.options) o)));
    v_keys := v_keys || to_jsonb(rq.answer);
  end loop;

  v_words := coalesce(array_length(regexp_split_to_array(btrim(v_pick.body), '\s+'), 1), 150);
  v_wpm := greatest(120, least(600, coalesce((private.gz_set('reading', 'wpm') #>> '{}')::int, 240)));
  -- Speed follows the level: 90% for beginners up to 120% at the top.
  v_wpm := round(v_wpm * (0.8 + 0.2 * v_t));
  v_read := greatest(20000, least(180000, (v_words * 60000 / v_wpm)));
  insert into public.gz_seen (user_id, qkey) select u, v_pick.k from unnest(coalesce(v_humans, '{}')) u
  on conflict (user_id, qkey) do update set seen_at = now();
  update public.gz_matches set items = v_items, keys = v_keys, rounds = jsonb_array_length(v_items),
    passage = jsonb_build_object('title', v_pick.title, 'body', v_pick.body, 'words', v_words, 'read_ms', v_read, 'wpm', v_wpm)
  where id = p_match;
end $$;

