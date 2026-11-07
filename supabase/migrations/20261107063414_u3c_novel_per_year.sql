-- Owner (2026-11-07): a year's paper uses THAT year's novel; mixed and quick tests use the current set novel (The Lekki Headmaster).
update public.exam_blueprints b set sections = (
  select jsonb_agg(case when x ->> 'key' = 'novel' then x || '{"novels":[
      {"title":"The Lekki Headmaster","match":"lekki"},
      {"title":"The Life Changer","match":"life changer"},
      {"title":"Sweet Sixteen","match":"sweet sixteen"},
      {"title":"In Dependence","match":"in dependence"},
      {"title":"The Last Days at Forcados High School","match":"forcados"}]}'::jsonb else x end order by o)
  from jsonb_array_elements(b.sections) with ordinality t(x, o))
where b.subject_id = (select id from public.subjects where name = 'Use of English');

-- The book a year's novel questions are on: the listed title they mention most (null if none is named).
create or replace function private.year_novel(p_exam smallint, p_subject smallint, p_year smallint, p_novels jsonb)
returns jsonb language sql stable security definer set search_path to '' as $$
  select n from jsonb_array_elements(coalesce(p_novels, '[]')) n
  cross join lateral (select count(*) as hits from public.questions q
    where q.exam_id = p_exam and q.subject_id = p_subject and q.year = p_year and q.section = 'novel' and q.deleted_at is null
      and q.body ~* (n ->> 'match')) h
  where h.hits > 0 order by h.hits desc limit 1;
$$;
revoke all on function private.year_novel(smallint, smallint, smallint, jsonb) from public, anon, authenticated;

-- paper_take: with a match or since, the chosen year's own questions of that section always count too.
create or replace function private.paper_take(p_exam smallint, p_subject smallint, p_years smallint[], p_year smallint, p_section text,
                                              p_need integer, p_exclude uuid[], p_hashes text[], p_split boolean,
                                              p_match text default null, p_since smallint default null)
returns uuid[] language plpgsql volatile security definer set search_path to '' as $$
declare v_out uuid[] := '{}'; v_hash text[] := coalesce(p_hashes, '{}'); v_left integer := p_need; u record; v_ids uuid[]; v_big uuid[];
begin
  if v_left <= 0 then return v_out; end if;
  for u in
    select z.unit, array_agg(z.id order by z.number nulls last, z.id) as ids, array_agg(z.content_hash) as hs, bool_or(z.year = p_year) as mine
    from (select x.id, x.year, x.number, x.content_hash, coalesce(x.passage_id::text, x.id::text) as unit
          from public.questions x
          where x.exam_id = p_exam and x.subject_id = p_subject and x.year = any (p_years)
            and x.status = 'published' and x.deleted_at is null
            and (p_section is null or x.section = p_section)
            and (p_match is null and p_since is null
                 or (p_match is not null and x.body ~* p_match)
                 or (p_since is not null and x.year >= p_since)
                 or (p_year is not null and x.year = p_year))
            and not (x.id = any (coalesce(p_exclude, '{}')))) z
    group by z.unit
    order by bool_or(z.year = p_year) desc nulls last, random()
  loop
    exit when v_left <= 0;
    select coalesce(array_agg(t.i order by t.o), '{}') into v_ids
    from unnest(u.ids, u.hs) with ordinality t(i, h, o) where t.h is null or not (t.h = any (v_hash));
    continue when cardinality(v_ids) = 0;
    if cardinality(v_ids) <= v_left then
      v_out := v_out || v_ids; v_left := v_left - cardinality(v_ids);
      v_hash := v_hash || u.hs;
    elsif p_split then
      v_out := v_out || v_ids[1:v_left]; v_left := 0;
    elsif v_big is null then
      v_big := v_ids;
    end if;
  end loop;
  if v_left > 0 and v_big is not null then v_out := v_out || v_big[1:v_left]; end if;
  return v_out;
end;
$$;
