-- Game Zone: Comprehension Clash (owner, 13 Nov 2026). Both players get the same passage. It is shown quickly, a part at
-- a time, for a reading time set from its length (Admin: words per minute); then it goes away and the questions come:
-- main idea, the writer's purpose, a word in context, a deduction, a detail. Most correct wins; on a tie, who finished
-- first. Passages: SolutionTee's own (Admin → Games → Comprehension Clash, CSV) and/or JAMB comprehension passages.

create table if not exists public.gz_passages (
  id bigint generated always as identity primary key,
  title text not null default '' check (char_length(title) <= 160),
  body text not null check (char_length(body) between 200 and 6000),
  difficulty text not null default 'medium' check (difficulty in ('easy', 'medium', 'hard')),
  active boolean not null default true,
  batch text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.gz_passage_questions (
  id bigint generated always as identity primary key,
  passage_id bigint not null references public.gz_passages (id) on delete cascade,
  kind text not null default 'other' check (kind in ('main', 'intent', 'vocab', 'inference', 'detail', 'other')),
  body text not null check (char_length(body) between 3 and 1000),
  options jsonb not null check (jsonb_typeof(options) = 'object'),
  answer text not null,
  sort smallint not null default 0,
  check (options ? answer)
);
create index if not exists gz_passage_questions_passage_idx on public.gz_passage_questions (passage_id);
create index if not exists gz_passages_batch_idx on public.gz_passages (batch);
alter table public.gz_passages enable row level security;
alter table public.gz_passage_questions enable row level security;
create policy "staff read" on public.gz_passages for select using (private.is_staff());
create policy "staff edit" on public.gz_passages for all using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));
create policy "staff read" on public.gz_passage_questions for select using (private.is_staff());
create policy "staff edit" on public.gz_passage_questions for all using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));
grant select, insert, update, delete on public.gz_passages, public.gz_passage_questions to authenticated;

alter table public.gz_matches add column if not exists passage jsonb;
alter table public.gz_matches add column if not exists answer_at timestamptz;

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
    when 'reading' then '{"kind":"race","max":2,"min":2,"seconds":75,"target":999,"rounds":5}'
  end::jsonb;
$$;

create or replace function private.gz_subject(p_uid uuid, p_game text, p_subject smallint)
returns smallint language plpgsql stable security definer set search_path = '' as $$
declare v_codes text[]; v_code text;
begin
  if p_game in ('words', 'reading') then return (select id from public.subjects where code = 'eng'); end if;
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

-- Picks a passage the players have not seen lately (own and/or JAMB, by the English source setting) and its questions.
create or replace function private.gz_reading_build(p_match uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches; v_humans uuid[]; v_free boolean; v_mode text; v_years smallint[]; v_seen text[] := '{}';
  v_pick record; v_items jsonb := '[]'; v_keys jsonb := '[]'; rq record; v_words integer; v_wpm integer; v_read integer; v_n integer;
begin
  select * into m from public.gz_matches where id = p_match;
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
    select 'gp:' || g.id as k, g.id::text as ref, 'own' as src, g.title, g.body from public.gz_passages g
    where v_mode in ('own', 'both') and g.active and (select count(*) from public.gz_passage_questions x where x.passage_id = g.id) >= 3),
  jamb as (
    select 'jp:' || p.id as k, p.id::text as ref, 'jamb' as src, coalesce(p.title, '') as title, p.body from public.passages p
    where v_mode in ('jamb', 'both') and p.exam_id = coalesce(m.exam_id, 1) and char_length(p.body) between 200 and 6000
      and (select count(*) from public.questions q where q.passage_id = p.id and q.status = 'published' and q.deleted_at is null
             and q.year = any (coalesce(v_years, '{}')) and q.image_path is null and jsonb_typeof(q.options) = 'object' and q.options ? q.answer
             and coalesce(q.section::text, 'comprehension') = 'comprehension') >= 3),
  cand as (select * from own union all select * from jamb)
  select * into v_pick from cand order by (k = any (v_seen)), random() limit 1;
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
  v_read := greatest(20000, least(180000, (v_words * 60000 / v_wpm)));
  insert into public.gz_seen (user_id, qkey) select u, v_pick.k from unnest(coalesce(v_humans, '{}')) u
  on conflict (user_id, qkey) do update set seen_at = now();
  update public.gz_matches set items = v_items, keys = v_keys, rounds = jsonb_array_length(v_items),
    passage = jsonb_build_object('title', v_pick.title, 'body', v_pick.body, 'words', v_words, 'read_ms', v_read)
  where id = p_match;
end $$;

create or replace function private.gz_add_bots(p_match uuid, p_n integer)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches; i integer; v_spec jsonb; v_seed text; v_plan jsonb; v_limit integer;
begin
  select * into m from public.gz_matches where id = p_match;
  for i in 1 .. greatest(p_n, 0) loop
    v_seed := p_match::text || ':bot:' || i || ':' || random();
    v_spec := private.gz_bot_spec(m.level, v_seed);
    if m.game in ('rush', 'blitz', 'reading') then
      v_limit := case when m.game = 'blitz' then 6000 when m.game = 'reading' then 22000 else 15000 end;
      select jsonb_agg(private.gz_bot_answer(v_spec, v_seed || ':' || g.n, v_limit) order by g.n) into v_plan
      from generate_series(0, case when m.game = 'reading' then 5 else 89 end) g(n);
      v_spec := v_spec || jsonb_build_object('plan', v_plan);
    elsif m.game = 'memory' then
      v_spec := v_spec || jsonb_build_object('plan', (select jsonb_agg(jsonb_build_object(
        'moves', (3 + g.n) + floor(private.gz_rand(v_seed || g.n) * (3 + g.n) * (1.4 - (v_spec ->> 'acc')::float))::int,
        'ms', ((3 + g.n) * (2600 - 1400 * (v_spec ->> 'acc')::float) + private.gz_rand(v_seed || 'm' || g.n) * 6000)::int) order by g.n)
        from generate_series(1, 3) g(n)));
    end if;
    insert into public.gz_players (match_id, user_id, bot, name) values (p_match, null, v_spec, v_spec ->> 'name');
  end loop;
end $$;

-- Bots answer from the moment the questions open; in Comprehension Clash they finish after the last question.
create or replace function private.gz_bot_progress(m public.gz_matches, p_bot jsonb, p_until timestamptz)
returns jsonb language plpgsql stable set search_path = '' as $$
declare v_base timestamptz := case when m.game = 'reading' then coalesce(m.answer_at, m.starts_at) else m.starts_at end;
  t integer := greatest(0, private.gz_ms(least(p_until, m.ends_at), v_base)); acc integer := 0; a jsonb; i integer := 0;
  v_correct integer := 0; v_score integer := 0; v_combo integer := 0; v_best integer := 0; v_fin timestamptz;
  v_n integer := coalesce(jsonb_array_length(m.items), 0);
begin
  for a in select x from jsonb_array_elements(p_bot -> 'plan') x loop
    exit when m.game = 'reading' and i >= v_n;
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
    if m.game = 'reading' and i >= v_n then v_fin := v_base + make_interval(secs => acc / 1000.0); end if;
  end loop;
  return jsonb_build_object('pos', i, 'answered', i, 'correct', v_correct, 'score', v_score, 'combo', v_combo, 'best', v_best, 'finished_at', v_fin);
end $$;

alter table public.gz_matches drop constraint if exists gz_matches_game_check;
alter table public.gz_matches add constraint gz_matches_game_check check (game in ('duel', 'rush', 'survival', 'blitz', 'words', 'memory', 'relay', 'reading'));
create or replace function private.gz_start(p_match uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches; c jsonb; v_n integer; v_secs integer; v_read integer := 0;
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
  if m.game = 'reading' then perform private.gz_reading_build(m.id); else perform private.gz_build_items(m.id); end if;
  select * into m from public.gz_matches where id = p_match;
  if m.game = 'reading' then v_read := (m.passage ->> 'read_ms')::int; end if;
  v_secs := case when c ->> 'kind' = 'sync' then ceil(m.rounds * (m.seconds * 1000 + m.gap_ms) / 1000.0)::int
                 when m.game = 'reading' then m.seconds else (c ->> 'seconds')::int end;
  update public.gz_matches set status = 'playing', starts_at = now() + interval '4 seconds', round_open = now() + interval '4 seconds',
    answer_at = case when m.game = 'reading' then now() + interval '4 seconds' + make_interval(secs => v_read / 1000.0) end,
    ends_at = now() + interval '4 seconds' + make_interval(secs => v_read / 1000.0 + v_secs) where id = m.id;
  update public.gz_players gp set last_at = now() + interval '4 seconds' + make_interval(secs => v_read / 1000.0),
    rating_before = case when gp.user_id is null then null else coalesce((select r.rating from public.gz_ratings r where r.user_id = gp.user_id and r.game = m.game), 1000) end
  where gp.match_id = m.id;
  perform private.gz_send(m.id, 'start', jsonb_build_object('id', m.id));
end $$;

create or replace function public.gz_answer(p_match uuid, p_idx integer, p_choice text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); m public.gz_matches; p public.gz_players; c jsonb; v_key text; v_ok boolean; v_ms integer; v_pts integer;
  v_combo integer; v_fin boolean := false; v_n integer;
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
    -- Comprehension Clash: no answers while the passage is still showing.
    if m.game = 'reading' and now() < m.answer_at - interval '200 milliseconds' then return jsonb_build_object('ok', false, 'error', 'wait'); end if;
    if p.penalty_until is not null and now() < p.penalty_until - interval '150 milliseconds' then return jsonb_build_object('ok', false, 'error', 'wait'); end if;
    v_n := jsonb_array_length(m.items);
    if p_idx >= v_n then return jsonb_build_object('ok', false, 'error', 'closed'); end if;
    v_ms := greatest(0, private.gz_ms(now(), greatest(coalesce(p.last_at, m.starts_at), coalesce(p.penalty_until, m.starts_at), coalesce(m.answer_at, m.starts_at))));
    -- Not humanly possible: under 0.35 s (Blitz), 1.2 s (Rush) or 1.5 s (a comprehension question) counts as a guess.
    if v_ms < (case when m.game = 'blitz' then 350 when m.game = 'reading' then 1500 else 1200 end) then v_ok := false; end if;
    v_combo := case when v_ok then p.combo + 1 else 0 end;
    v_pts := case when not v_ok then 0 when m.game = 'blitz' then 10 * least(v_combo, 5) else 100 end;
    insert into public.gz_answers (match_id, player_id, idx, choice, correct, ms, points) values (m.id, p.id, p_idx, left(p_choice, 200), v_ok, v_ms, v_pts)
    on conflict do nothing;
    v_fin := (m.game = 'rush' and v_ok and p.correct + 1 >= m.target) or (m.game = 'reading' and p.pos + 1 >= v_n);
    -- Comprehension Clash: finishing early earns a time bonus (2 points a second left).
    if m.game = 'reading' and v_fin then v_pts := v_pts + 2 * greatest(0, extract(epoch from (m.ends_at - now()))::int); end if;
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
          -- Comprehension Clash: a bot gets its whole answering time even when the student finished first.
          v_pr := private.gz_bot_progress(m, b.bot, case when m.game = 'reading' then m.ends_at else now() end);
          update public.gz_players set pos = (v_pr ->> 'pos')::int, answered = (v_pr ->> 'answered')::int, correct = (v_pr ->> 'correct')::int,
            score = (v_pr ->> 'score')::int + case when m.game = 'reading' and v_pr ->> 'finished_at' is not null
              then 2 * greatest(0, extract(epoch from (m.ends_at - (v_pr ->> 'finished_at')::timestamptz))::int) else 0 end,
            best_combo = (v_pr ->> 'best')::int, finished_at = (v_pr ->> 'finished_at')::timestamptz where id = b.id;
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
        case when m.game = 'reading' then correct else 0 end desc,
        case when m.game in ('rush', 'reading') then coalesce(extract(epoch from finished_at), 9e12) else 0 end asc,
        case when m.game = 'rush' then correct else 0 end desc,
        score desc, correct desc) as pl
      from public.gz_players where match_id = m.id) x where p.id = x.id;
  end if;
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

create or replace function public.gz_state(p_match uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); m public.gz_matches; c jsonb; v_me public.gz_players; v_players jsonb; v_round jsonb; v_last jsonb;
  v_review jsonb; v_item jsonb; v_close timestamptz; v_mine jsonb; v_passage jsonb;
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
    -- Comprehension Clash: the first question only once the passage is gone.
    v_item := case when m.game <> 'reading' or now() >= m.answer_at - interval '1500 milliseconds' then m.items -> v_me.pos end;
  end if;

  -- The passage: while it is being read (and a moment after), and in the review at the end.
  if m.game = 'reading' and m.passage is not null and (m.status = 'done' or (m.status = 'playing' and now() < m.answer_at + interval '1 second')) then
    v_passage := m.passage;
  elsif m.game = 'reading' and m.passage is not null then
    v_passage := m.passage - 'body';
  end if;

  if m.status = 'done' and v_me.id is not null then
    select coalesce(jsonb_agg(jsonb_build_object('idx', i - 1, 'item', it, 'key', m.keys ->> (i - 1)::int,
        'choice', x.choice, 'correct', coalesce(x.correct, false), 'ms', x.ms, 'points', coalesce(x.points, 0), 'answered', x.idx is not null) order by i), '[]')
    into v_review
    from jsonb_array_elements(m.items) with ordinality t(it, i)
    left join public.gz_answers x on x.match_id = m.id and x.player_id = v_me.id and x.idx = (i - 1)
    where m.game <> 'memory' and ((c ->> 'kind' = 'sync' or m.game = 'reading') and i <= m.rounds or x.idx is not null);
  end if;

  return jsonb_build_object('id', m.id, 'game', m.game, 'mode', m.mode, 'status', m.status, 'level', m.level, 'code', m.code,
    'subject', (select jsonb_build_object('id', s.id, 'code', s.code, 'name', s.name) from public.subjects s where s.id = m.subject_id),
    'host', m.created_by = v_uid, 'now', (extract(epoch from now()) * 1000)::bigint,
    'starts_at', (extract(epoch from m.starts_at) * 1000)::bigint, 'ends_at', (extract(epoch from m.ends_at) * 1000)::bigint,
    'answer_at', (extract(epoch from m.answer_at) * 1000)::bigint,
    'lobby_until', (extract(epoch from m.lobby_until) * 1000)::bigint,
    'seconds', m.seconds, 'gap_ms', m.gap_ms, 'rounds', m.rounds, 'target', m.target, 'max', m.max_players,
    'players', v_players, 'me', case when v_me.id is not null then private.gz_player_json(v_me, v_uid) || jsonb_build_object(
      'penalty_until', (extract(epoch from v_me.penalty_until) * 1000)::bigint) end,
    'round', v_round, 'last', v_last, 'item', v_item, 'passage', v_passage,
    'levels', case when m.game = 'memory' and m.status <> 'lobby' then m.items end,
    'review', v_review);
end $$;
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
  from unnest(array['duel', 'reading', 'rush', 'survival', 'blitz', 'words', 'memory', 'relay']) with ordinality u(g, ord)
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
