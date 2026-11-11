-- Tutor requests hold students' contact details and chats: only super admins and admins see or answer them (D-149).
create or replace function private.tutor_staff() returns boolean language sql stable security definer set search_path = '' as $$
  select private.can_edit(array['super_admin','admin']::public.staff_role[]);
$$;
revoke all on function private.tutor_staff() from public, anon;
grant execute on function private.tutor_staff() to authenticated;
drop policy "staff read" on public.tutors;
drop policy "own or staff" on public.tutor_requests;
drop policy "staff edit" on public.tutor_requests;
drop policy "own or staff" on public.tutor_messages;
drop policy "own or staff" on public.tutor_subscriptions;
create policy "own or admins" on public.tutor_requests for select to authenticated using (user_id = (select auth.uid()) or private.tutor_staff());
create policy "admins edit" on public.tutor_requests for update to authenticated using (private.tutor_staff()) with check (private.tutor_staff());
create policy "own or admins" on public.tutor_messages for select to authenticated
  using (private.tutor_staff() or exists (select 1 from public.tutor_requests r where r.id = request_id and r.user_id = (select auth.uid())));
create policy "own or admins" on public.tutor_subscriptions for select to authenticated using (user_id = (select auth.uid()) or private.tutor_staff());
do $$
declare d text;
begin
  d := replace(pg_get_functiondef('public.tutor_message_send(uuid,text)'::regprocedure), 'v_staff boolean := private.is_staff();', 'v_staff boolean := private.tutor_staff();');
  if position('private.tutor_staff()' in d) = 0 then raise exception 'tutor_message_send not changed'; end if;
  execute d;
  d := replace(pg_get_functiondef('public.admin_tutor_requests(text)'::regprocedure), 'where private.is_staff() and', 'where private.tutor_staff() and');
  if position('private.tutor_staff()' in d) = 0 then raise exception 'admin_tutor_requests not changed'; end if;
  execute d;
end $$;

