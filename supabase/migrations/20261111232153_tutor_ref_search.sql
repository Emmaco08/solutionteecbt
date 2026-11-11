-- Tutors and admins search lessons and past questions to send as a reference in the chat (D-152). Only titles and
-- short snippets go out; the student opens the item in the app under their own plan rules.
create or replace function public.tutor_ref_search(p_kind text, p_q text default '', p_subject smallint default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_q text := btrim(coalesce(p_q, ''));
begin
  if private.my_tutor_id() is null and not private.tutor_staff() then raise exception 'not allowed' using errcode = '42501'; end if;
  if p_kind = 'lesson' then
    return coalesce((select jsonb_agg(x) from (
      select jsonb_build_object('type', 'lesson', 'id', s.id, 'kind', s.kind, 'title', s.title, 'subtitle', s.subtitle,
        'subject', (select sb.name from public.subjects sb where sb.id = s.subject_id)) x
      from public.study_items s
      where s.status = 'published' and s.deleted_at is null and (p_subject is null or s.subject_id = p_subject)
        and (v_q = '' or s.title ilike '%' || v_q || '%' or coalesce(s.subtitle, '') ilike '%' || v_q || '%')
      order by s.updated_at desc limit 25) t), '[]'::jsonb);
  end if;
  return coalesce((select jsonb_agg(x) from (
    select jsonb_build_object('type', 'pq', 'question_id', q.id, 'exam_id', q.exam_id, 'subject_id', q.subject_id, 'year', q.year, 'number', q.number,
      'exam', e.code, 'subject', sb.name, 'title', e.code || ' ' || sb.name || ' ' || q.year || coalesce(' · Q' || q.number, ''),
      'snippet', left(regexp_replace(q.body, '\s+', ' ', 'g'), 160)) x
    from public.questions q join public.exam_bodies e on e.id = q.exam_id join public.subjects sb on sb.id = q.subject_id
    where q.status = 'published' and q.deleted_at is null and (p_subject is null or q.subject_id = p_subject)
      and (v_q = '' or q.body ilike '%' || v_q || '%' or (v_q ~ '^\d{4}$' and q.year = v_q::smallint))
    order by q.year desc, q.number limit 25) t), '[]'::jsonb);
end $$;
revoke all on function public.tutor_ref_search(text, text, smallint) from public, anon;
grant execute on function public.tutor_ref_search(text, text, smallint) to authenticated;

