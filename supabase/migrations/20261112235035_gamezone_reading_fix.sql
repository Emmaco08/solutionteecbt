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

