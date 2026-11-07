-- Lesson-note search for the tutor that respects the plan (D-096): Premium-only notes help Premium students only.
create or replace function public.ai_match_for(p_uid uuid, p_embedding extensions.vector, p_subject smallint default null, p_count integer default 4)
returns table(title text, content text, similarity double precision, item_id uuid)
language sql stable security definer set search_path to '' as $$
  select c.title, c.content, 1 - (c.embedding operator(extensions.<=>) p_embedding), c.source_id
  from public.ai_chunks c
  left join public.study_items i on i.id = c.source_id
  where (p_subject is null or c.subject_id = p_subject or c.subject_id is null)
    and (i.id is null or (i.deleted_at is null and i.status = 'published' and (i.is_free or private.has_premium(p_uid))))
  order by c.embedding operator(extensions.<=>) p_embedding
  limit least(greatest(p_count, 1), 8);
$$;
revoke execute on function public.ai_match_for(uuid, extensions.vector, smallint, integer) from public, anon, authenticated;
grant execute on function public.ai_match_for(uuid, extensions.vector, smallint, integer) to service_role;

-- Lesson notes the student may open, matching their words (title first), for the open_note tool.
create or replace function public.ai_find_notes(p_uid uuid, p_q text, p_subject smallint default null)
returns jsonb language sql stable security definer set search_path to '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', n.id, 'title', n.title, 'subtitle', n.subtitle, 'locked', n.locked) order by n.rank desc), '[]')
  from (
    select i.id, i.title, i.subtitle, not (i.is_free or private.has_premium(p_uid)) as locked,
           (case when lower(i.title) like '%' || lower(trim(p_q)) || '%' then 10 else 0 end)
           + (select count(*) from regexp_split_to_table(lower(p_q), '[^a-z0-9]+') w where length(w) >= 4 and lower(i.title || ' ' || coalesce(i.subtitle, '')) like '%' || w || '%') as rank
    from public.study_items i
    where i.kind = 'note' and i.status = 'published' and i.deleted_at is null
      and (p_subject is null or i.subject_id = p_subject)
  ) n where n.rank > 0
  limit 3;
$$;
revoke execute on function public.ai_find_notes(uuid, text, smallint) from public, anon, authenticated;
grant execute on function public.ai_find_notes(uuid, text, smallint) to service_role;
