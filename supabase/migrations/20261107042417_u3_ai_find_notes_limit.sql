create or replace function public.ai_find_notes(p_uid uuid, p_q text, p_subject smallint default null)
returns jsonb language sql stable security definer set search_path to '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', n.id, 'title', n.title, 'subtitle', n.subtitle, 'locked', n.locked) order by n.rank desc), '[]')
  from (
    select * from (
      select i.id, i.title, i.subtitle, not (i.is_free or private.has_premium(p_uid)) as locked,
             (case when lower(i.title) like '%' || lower(trim(p_q)) || '%' then 10 else 0 end)
             + (select count(*) from regexp_split_to_table(lower(p_q), '[^a-z0-9]+') w where length(w) >= 4 and lower(i.title || ' ' || coalesce(i.subtitle, '')) like '%' || w || '%') as rank
      from public.study_items i
      where i.kind = 'note' and i.status = 'published' and i.deleted_at is null
        and (p_subject is null or i.subject_id = p_subject)
    ) r where r.rank > 0 order by r.rank desc limit 3
  ) n;
$$;
