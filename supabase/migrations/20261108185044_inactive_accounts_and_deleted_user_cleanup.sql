-- D-119 (Privacy Policy §10, lawyer's list): accounts with no activity for 24 months are deleted after an email notice,
-- and every deleted account (app, website, parent turn-off, inactivity) also loses its files in R2 and its archived
-- history in Neon. The owner's and all staff accounts are never touched.

create table if not exists private.inactive_notices (
  user_id uuid primary key references auth.users (id) on delete cascade,
  notified_at timestamptz not null default now()
);

-- Only the id of a deleted account (no personal data), kept until its R2 files and Neon rows are gone, then 90 days.
create table if not exists private.deleted_users (
  user_id uuid primary key,
  deleted_at timestamptz not null default now(),
  r2_done_at timestamptz,
  neon_done_at timestamptz
);

create or replace function private.on_auth_user_deleted() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into private.deleted_users (user_id) values (old.id) on conflict (user_id) do nothing;
  return old;
end $$;

drop trigger if exists on_auth_user_deleted on auth.users;
create trigger on_auth_user_deleted after delete on auth.users
  for each row execute function private.on_auth_user_deleted();

-- Last sign of life: sign-in, token refresh (any app or website use), push token seen on app open, or account creation.
create or replace function private.last_active(p_uid uuid) returns timestamptz
language sql stable security definer set search_path = '' as $$
  select greatest(
    u.created_at, u.last_sign_in_at,
    (select max(greatest(s.updated_at, s.refreshed_at at time zone 'UTC')) from auth.sessions s where s.user_id = u.id),
    (select max(t.last_seen) from public.push_tokens t where t.user_id = u.id))
  from auth.users u where u.id = p_uid;
$$;

-- Who gets the notice (inactive 23 months, not told since their last activity) and who is deleted (told 30+ days ago,
-- still inactive, 24 months reached, no running Premium). Service role only (the website's nightly job).
create or replace function public.inactive_due(p_limit int default 100) returns jsonb
language sql stable security definer set search_path = '' as $$
  with act as (
    select u.id, u.email::text as email, coalesce(p.full_name, '') as name, private.last_active(u.id) as last_at
    from auth.users u left join public.profiles p on p.id = u.id
    where u.email is not null
      and not exists (select 1 from public.staff s where s.user_id = u.id)
  )
  select jsonb_build_object(
    'notify', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'email', a.email, 'name', a.name, 'last_at', a.last_at))
       from (select * from act a
             where a.last_at < now() - interval '23 months'
               and not exists (select 1 from private.inactive_notices n where n.user_id = a.id and n.notified_at > a.last_at)
             order by a.last_at limit greatest(least(p_limit, 250), 0)) a), '[]'::jsonb),
    'delete', coalesce((select jsonb_agg(a.id)
       from (select a.id from act a join private.inactive_notices n on n.user_id = a.id
             where n.notified_at > a.last_at and n.notified_at < now() - interval '30 days'
               and a.last_at < now() - interval '24 months'
               and not exists (select 1 from public.entitlements e where e.user_id = a.id and e.expires_at > now())
             order by a.last_at limit greatest(least(p_limit, 250), 0)) a), '[]'::jsonb));
$$;

create or replace function public.inactive_mark(p_ids uuid[]) returns int
language sql security definer set search_path = '' as $$
  with x as (
    insert into private.inactive_notices (user_id, notified_at)
    select u.id, now() from auth.users u where u.id = any(p_ids)
    on conflict (user_id) do update set notified_at = now()
    returning 1)
  select count(*)::int from x;
$$;

-- Clean-up queue for files (r2) and archived history (neon).
create or replace function public.deleted_users_pending(p_what text, p_limit int default 200) returns uuid[]
language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(user_id), '{}') from (
    select d.user_id from private.deleted_users d
    where case p_what when 'r2' then d.r2_done_at is null when 'neon' then d.neon_done_at is null else false end
    order by d.deleted_at limit greatest(least(p_limit, 1000), 0)) x;
$$;

create or replace function public.deleted_users_done(p_what text, p_ids uuid[]) returns int
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  if p_what = 'r2' then
    update private.deleted_users set r2_done_at = now() where user_id = any(p_ids) and r2_done_at is null;
  elsif p_what = 'neon' then
    update private.deleted_users set neon_done_at = now() where user_id = any(p_ids) and neon_done_at is null;
  else
    raise exception 'bad_kind';
  end if;
  get diagnostics n = row_count;
  delete from private.deleted_users
   where r2_done_at is not null and neon_done_at is not null and deleted_at < now() - interval '90 days';
  return n;
end $$;

revoke all on function private.on_auth_user_deleted() from public, anon, authenticated;
revoke all on function private.last_active(uuid) from public, anon, authenticated;
revoke all on function public.inactive_due(int) from public, anon, authenticated;
revoke all on function public.inactive_mark(uuid[]) from public, anon, authenticated;
revoke all on function public.deleted_users_pending(text, int) from public, anon, authenticated;
revoke all on function public.deleted_users_done(text, uuid[]) from public, anon, authenticated;
grant execute on function public.inactive_due(int) to service_role;
grant execute on function public.inactive_mark(uuid[]) to service_role;
grant execute on function public.deleted_users_pending(text, int) to service_role;
grant execute on function public.deleted_users_done(text, uuid[]) to service_role;

-- Nightly at 03:20 Lagos time: the website job sends notices, deletes due accounts and removes deleted accounts' files.
select cron.unschedule('accounts-nightly') where exists (select 1 from cron.job where jobname = 'accounts-nightly');
select cron.schedule('accounts-nightly', '20 2 * * *', $cron$
  select net.http_post(
    url := 'https://admin.solutiontee.com/api/cron/accounts',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-token', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_token')),
    body := '{}'::jsonb,
    timeout_milliseconds := 55000);
$cron$);
