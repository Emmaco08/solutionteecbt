-- Game Zone: past-question difficulty is an enum (cast to text in the mix).
create or replace function private.gz_build_items(p_match uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.gz_matches; v_n integer; v_ids uuid[]; v_items jsonb := '[]'; v_keys jsonb := '[]'; q record; w record; r jsonb; lvl integer;
  v_pairs integer; v_mode text; v_humans uuid[]; v_free boolean; v_hard boolean; v_own integer; v_seen text[] := '{}';
begin
  select * into m from public.gz_matches where id = p_match;
  if m.game in ('duel', 'survival', 'relay', 'rush') then
    v_n := case when m.game = 'rush' then 40 else m.rounds end;
    v_hard := m.game = 'survival';
    select array_agg(user_id) into v_humans from public.gz_players where match_id = m.id and user_id is not null;
    v_free := exists (select 1 from unnest(coalesce(v_humans, '{}')) u where not private.has_premium(u));
    v_mode := private.gz_source(m.subject_id);
    select count(*) into v_own from public.gz_questions g where g.active and g.subject_id = m.subject_id;
    -- Too few of our own for a whole game: fill with past questions (and the other way round), so a game always starts.
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
      order by (k = any (v_seen)), case when v_hard then case difficulty when 'hard' then 0 when 'medium' then 1 else 2 end else 0 end, random()
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

