-- Study covers and video preview pictures (s/…) are shown on lists, also for Premium items (they are teasers,
-- not content), so they get their own check without the plan rule (D-057). The catalog also says which
-- items have one, with the key the app uses to cache the picture on the phone.
create or replace function public.study_cover_key(p_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select i.files ->> 'cover' from public.study_items i
  where i.id = p_id and i.deleted_at is null and (i.status = 'published' or private.is_staff())
    and (select auth.uid()) is not null and not private.is_banned();
$$;
revoke all on function public.study_cover_key(uuid) from public, anon;
grant execute on function public.study_cover_key(uuid) to authenticated;

create or replace function public.study_catalog(p_kind text, p_subject smallint default null)
returns table(id uuid, kind text, title text, subtitle text, exam_id smallint, subject_id smallint, topic_id integer, topic text,
              year smallint, question_id uuid, meta jsonb, is_free boolean, locked boolean, sort smallint)
language sql
stable
security definer
set search_path = ''
as $$
  select i.id, i.kind, i.title, i.subtitle, i.exam_id, i.subject_id, i.topic_id, t.name, i.year, i.question_id,
         jsonb_strip_nulls(jsonb_build_object(
           'duration_s', i.data -> 'duration_s', 'pages', i.data -> 'pages', 'author', i.data -> 'author',
           'chapters', jsonb_array_length(coalesce(i.data -> 'chapters', '[]'::jsonb)),
           'size_360', i.files -> 'sizes' -> '360', 'size_720', i.files -> 'sizes' -> '720', 'size_pdf', i.files -> 'sizes' -> 'pdf',
           'cover', i.files -> 'cover', 'hd', case when i.files ? '720' then true end, 'book', case when i.kind = 'novel' and i.files ? 'pdf' then true end,
           'minutes', case when i.kind = 'note' then greatest(1, round(coalesce(char_length(i.body), 0) / 1100.0)) end)),
         i.is_free, not private.study_open(i.kind, i.is_free), i.sort
  from public.study_items i left join public.topics t on t.id = i.topic_id
  where i.kind = p_kind and i.status = 'published' and i.deleted_at is null
    and (p_subject is null or i.subject_id = p_subject)
    and (select auth.uid()) is not null
  order by i.sort, i.title;
$$;
