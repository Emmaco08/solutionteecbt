-- Pictures inside notes (and other study text) live in the private R2 bucket under n/… (D-056).
-- A student may see one only when a study item they can open uses it in its text; staff always.
create or replace function public.can_view_note_image(p_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_key ~ '^n/[A-Za-z0-9/_.-]+$' and (
    private.is_staff()
    or (not private.is_banned() and exists (
      select 1 from public.study_items i
      where i.status = 'published' and i.deleted_at is null
        and strpos(coalesce(i.body, ''), p_key) > 0
        and private.study_open(i.kind, i.is_free))));
$$;

revoke all on function public.can_view_note_image(text) from public, anon;
grant execute on function public.can_view_note_image(text) to authenticated;
