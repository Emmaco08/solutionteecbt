-- SolutionTee CBT · Phase 2 · staff READS also need 2-step login (aal2)
-- Before: only staff writes required aal2, so a stolen staff password alone could read student
-- emails (admin RPCs) and all questions through the API. Now staff powers only apply at aal2;
-- an aal1 staff session is treated like any signed-in student. A staff member can still read
-- their own staff row (needed to show the 2-step page).
create or replace function private.is_staff(roles public.staff_role[] default null)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_aal2() and exists (
    select 1 from public.staff s
    where s.user_id = (select auth.uid())
      and (roles is null or s.role = any (roles))
  );
$$;
