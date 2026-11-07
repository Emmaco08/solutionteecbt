-- The JAMB set novel (owner, 2026-11-07): The Lekki Headmaster. The novel section only uses questions on that book:
-- the body mentions it (match), or it is a novel question from the years the book has been set (since).
update public.exam_blueprints b set sections = (
  select jsonb_agg(case when x ->> 'key' = 'novel'
    then x || '{"label":"JAMB novel: The Lekki Headmaster","match":"lekki","since":2025,"instruction":"These questions are based on the JAMB recommended text, The Lekki Headmaster by Kabir Alabi Garba."}'::jsonb
    else x end order by o)
  from jsonb_array_elements(b.sections) with ordinality t(x, o))
where b.subject_id = (select id from public.subjects where name = 'Use of English');

-- Questions that name the book are novel questions, whatever the rules said.
update public.questions set section = 'novel', section_source = 'rule'
where subject_id = (select id from public.subjects where name = 'Use of English') and body ~* 'lekki' and section_source is distinct from 'admin';

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
                 or (p_since is not null and x.year >= p_since))
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
revoke all on function private.paper_take(smallint, smallint, smallint[], smallint, text, integer, uuid[], text[], boolean, text, smallint) from public, anon, authenticated;
