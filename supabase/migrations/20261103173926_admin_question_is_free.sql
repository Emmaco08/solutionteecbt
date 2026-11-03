-- 4E2: copying a past question into a challenge is allowed only from years Free students can open (D-070).
create or replace function public.admin_question_is_free(p_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_staff() and exists (
    select 1 from public.questions q
    where q.id = p_id and q.status = 'published' and q.deleted_at is null and q.passage_id is null
      and private.tier_year_open('free', q.exam_id, q.year, 'cbt'));
$$;
revoke execute on function public.admin_question_is_free(uuid) from public, anon;
grant execute on function public.admin_question_is_free(uuid) to authenticated;
