-- A challenge picture can be signed for a logged-in student when a published challenge uses it.
create or replace function public.can_view_challenge_image(p_key text)
returns boolean language sql stable security definer set search_path to '' as $$
  select (select auth.uid()) is not null and exists (
    select 1 from public.challenges c where (c.bg_light = p_key or c.bg_dark = p_key) and c.published);
$$;
