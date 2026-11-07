create or replace function public.cbt_paper(p_exam smallint, p_subject smallint, p_year smallint default null, p_count integer default null)
returns jsonb language plpgsql volatile security definer set search_path to '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_open smallint[] := '{}';
  y record; bp record;
  v_target integer; v_sum integer; v_left integer;
  v_ids uuid[] := '{}'; v_hashes text[] := '{}'; v_part uuid[]; v_sorted uuid[];
  v_secs jsonb := '[]'; v_counts integer[] := '{}'; v_fracs numeric[] := '{}';
  s jsonb; i integer; k integer;
begin
  if v_uid is null or private.is_banned(v_uid) then return jsonb_build_object('ok', false, 'why', 'login'); end if;
  for y in select distinct ey.year from public.exam_years ey where ey.exam_id = p_exam and ey.subject_id = p_subject and ey.status = 'published' loop
    if private.year_open(p_exam, y.year, 'cbt') then v_open := v_open || y.year; end if;
  end loop;
  if cardinality(v_open) = 0 then return jsonb_build_object('ok', false, 'why', 'no_open_years'); end if;
  if p_year is not null and not (p_year = any (v_open)) then return jsonb_build_object('ok', false, 'why', 'locked'); end if;

  select * into bp from public.exam_blueprints b where b.exam_id = p_exam and b.subject_id = p_subject;
  if bp.id is null then select * into bp from public.exam_blueprints b where b.exam_id = p_exam and b.subject_id is null; end if;
  v_target := least(greatest(coalesce(p_count, bp.total, 40), 1), 200);

  if bp.id is not null and jsonb_array_length(bp.sections) > 0 then
    select sum((x ->> 'count')::int) into v_sum from jsonb_array_elements(bp.sections) x;
    for s in select * from jsonb_array_elements(bp.sections) loop
      v_counts := v_counts || floor((s ->> 'count')::numeric * v_target / v_sum)::int;
      v_fracs := v_fracs || ((s ->> 'count')::numeric * v_target / v_sum - floor((s ->> 'count')::numeric * v_target / v_sum));
    end loop;
    v_left := v_target - (select sum(c) from unnest(v_counts) c);
    while v_left > 0 loop
      select o into k from unnest(v_fracs) with ordinality t(f, o) order by f desc, o limit 1;
      v_counts[k] := v_counts[k] + 1; v_fracs[k] := -1; v_left := v_left - 1;
    end loop;
    i := 0;
    for s in select * from jsonb_array_elements(bp.sections) loop
      i := i + 1;
      continue when v_counts[i] = 0;
      v_part := private.paper_take(p_exam, p_subject, v_open, p_year, s ->> 'key', v_counts[i], v_ids, v_hashes, coalesce((s ->> 'passage')::boolean, false),
                                   nullif(s ->> 'match', ''), (s ->> 'since')::smallint);
      select coalesce(array_agg(x.id order by (x.year = p_year) desc nulls last, x.year, coalesce(x.passage_id::text, ''), x.number nulls last), '{}'),
             v_hashes || coalesce(array_agg(x.content_hash) filter (where x.content_hash is not null), '{}')
        into v_sorted, v_hashes
      from public.questions x where x.id = any (v_part);
      if cardinality(v_sorted) > 0 then
        v_secs := v_secs || jsonb_build_object('key', s ->> 'key', 'label', s ->> 'label', 'instruction', s ->> 'instruction',
                                               'start', cardinality(v_ids), 'count', cardinality(v_sorted));
        v_ids := v_ids || v_sorted;
      end if;
    end loop;
    if cardinality(v_ids) < v_target then
      v_part := private.paper_take(p_exam, p_subject, v_open, p_year, null, v_target - cardinality(v_ids), v_ids, v_hashes, false, null::text, null::smallint);
      if cardinality(v_part) > 0 then
        v_secs := v_secs || jsonb_build_object('key', 'more', 'label', 'More questions', 'instruction', null, 'start', cardinality(v_ids), 'count', cardinality(v_part));
        v_ids := v_ids || v_part;
      end if;
    end if;
  else
    v_part := private.paper_take(p_exam, p_subject, v_open, p_year, null, v_target, '{}', '{}', false, null::text, null::smallint);
    select coalesce(array_agg(x.id order by (x.year = p_year) desc nulls last, x.year, x.number nulls last, x.id), '{}') into v_ids
    from public.questions x where x.id = any (v_part);
  end if;

  return jsonb_build_object('ok', cardinality(v_ids) > 0, 'ids', to_jsonb(v_ids), 'sections', v_secs, 'short', greatest(v_target - cardinality(v_ids), 0),
    'years', (select coalesce(jsonb_agg(distinct x.year), '[]') from public.questions x where x.id = any (v_ids)));
end;
$$;
