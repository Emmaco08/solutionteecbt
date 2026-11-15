-- Security advisor tidy-up (15 Nov 2026). These functions already check sign-in / staff inside; signed-out callers
-- (anon) are now refused at the door too. Two pure helper functions get a fixed search_path.
revoke execute on function public.admin_program_stats() from public, anon;
revoke execute on function public.admin_program_students(uuid) from public, anon;
revoke execute on function public.program_register(uuid) from public, anon;
revoke execute on function public.program_detail(uuid) from public, anon;
revoke execute on function public.programs_list() from public, anon;
grant execute on function public.admin_program_stats(), public.admin_program_students(uuid), public.program_register(uuid),
  public.program_detail(uuid), public.programs_list() to authenticated;
alter function private.arena_end(public.arenas) set search_path = '';
alter function private.game_points(boolean, integer, integer) set search_path = '';
