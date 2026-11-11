-- Badges v2 (D-142): remember each student's first check, so only levels reached before badges v2 started are
-- recorded without a reward (a student with no level at the first check still gets every reward later).
create table public.badge_first_checks (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  checked_at timestamptz not null default now()
);
alter table public.badge_first_checks enable row level security;
create policy "staff read" on public.badge_first_checks for select to authenticated using (private.is_staff());

create or replace function private.badge_backfill(p_uid uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare v_new boolean;
begin
  insert into public.badge_first_checks (user_id) values (p_uid) on conflict do nothing;
  get diagnostics v_new = row_count;
  return v_new and (select pr.created_at from public.profiles pr where pr.id = p_uid)
    < coalesce((select (s.value ->> 'since')::timestamptz from public.app_settings s where s.key = 'badges'), now());
end $$;
revoke all on function private.badge_backfill(uuid) from public, anon, authenticated;

do $$
declare
  d text := pg_get_functiondef('public.badges_check()'::regprocedure);
  old text := $o$  v_backfill := not exists (select 1 from public.user_badges u where u.user_id = v_uid)
    and (select pr.created_at from public.profiles pr where pr.id = v_uid) < coalesce((cfg ->> 'since')::timestamptz, now());$o$;
begin
  if position(old in d) = 0 then raise exception 'badges_check: text to replace not found'; end if;
  execute replace(d, old, '  v_backfill := private.badge_backfill(v_uid);');
end $$;

