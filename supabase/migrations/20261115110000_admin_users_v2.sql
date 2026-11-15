-- Admin → Users v2 (owner, 15 Nov 2026): which app each student uses (website Android app, Play Store app, Windows app),
-- their subject combination and activity, filters and summary counts.

-- Which app a student opens: one row per platform + flavour, refreshed at most every 10 minutes (or on a new build).
create table if not exists public.user_apps (
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null check (platform in ('android', 'windows', 'ios', 'macos', 'linux', 'web')),
  flavor text not null default 'unknown' check (flavor in ('direct', 'play', 'desktop', 'unknown')),
  version text,
  build bigint,
  first_seen timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  primary key (user_id, platform, flavor)
);
alter table public.user_apps enable row level security; -- no policies: read only through the admin functions below
create index if not exists user_apps_last_seen on public.user_apps (last_seen desc);

/** Called by the app when it opens (signed in). */
create or replace function public.app_seen(p_platform text, p_flavor text default 'unknown', p_version text default null, p_build bigint default null)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_flavor text := coalesce(nullif(p_flavor, ''), 'unknown');
begin
  if v_uid is null or p_platform not in ('android', 'windows', 'ios', 'macos', 'linux', 'web') then return; end if;
  if v_flavor not in ('direct', 'play', 'desktop', 'unknown') then v_flavor := 'unknown'; end if;
  insert into public.user_apps (user_id, platform, flavor, version, build)
  values (v_uid, p_platform, v_flavor, left(p_version, 40), p_build)
  on conflict (user_id, platform, flavor) do update set version = excluded.version, build = excluded.build, last_seen = now()
    where public.user_apps.last_seen < now() - interval '10 minutes' or public.user_apps.build is distinct from excluded.build;
end;
$$;
revoke all on function public.app_seen(text, text, text, bigint) from public, anon;
grant execute on function public.app_seen(text, text, text, bigint) to authenticated;

-- Students who used the app before this: their phone or computer is known from the one-account check (D-078, D-166).
insert into public.user_apps (user_id, platform, flavor, first_seen, last_seen)
select d.user_id, case when 'desktop' = any (d.flags) then 'windows' else 'android' end, 'unknown', min(d.first_seen), max(d.last_seen)
from public.device_accounts d join auth.users u on u.id = d.user_id
group by 1, 2
on conflict do nothing;
update public.user_apps a set version = t.app_version
from (select distinct on (user_id) user_id, app_version from public.push_tokens order by user_id, last_seen desc) t
where a.user_id = t.user_id and a.platform = 'android' and a.version is null;

/** The apps a student uses, newest first; an "unknown" Android row is hidden once a known one exists. */
create or replace function private.user_apps_json(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('platform', a.platform, 'flavor', a.flavor, 'version', a.version, 'build', a.build,
           'first_seen', a.first_seen, 'last_seen', a.last_seen) order by a.last_seen desc), '[]'::jsonb)
  from public.user_apps a
  where a.user_id = p_user
    and not (a.flavor = 'unknown' and exists (select 1 from public.user_apps b where b.user_id = a.user_id and b.platform = a.platform and b.flavor <> 'unknown'));
$$;

drop function if exists public.admin_list_users(text, integer, integer);
create or replace function public.admin_list_users(p_search text default null, p_limit integer default 50, p_offset integer default 0,
  p_platform text default null, p_plan text default null)
returns table (id uuid, email text, full_name text, phone text, state text, school text, created_at timestamptz, last_sign_in_at timestamptz,
  last_active timestamptz, is_premium boolean, premium_until timestamptz, banned_at timestamptz, staff_role public.staff_role,
  target_exams text[], subjects text[], apps jsonb, xp integer, tests bigint, total bigint)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  return query
    with base as (
      select u.id, u.email::text as email, p.full_name, p.phone, p.state, p.school, u.created_at, u.last_sign_in_at, p.banned_at,
             p.target_exams, p.jamb_subjects, s.role, private.has_premium(u.id) as prem
      from auth.users u
      left join public.profiles p on p.id = u.id
      left join public.staff s on s.user_id = u.id
      where (p_search is null or p_search = ''
             or u.email ilike '%' || p_search || '%' or p.full_name ilike '%' || p_search || '%' or p.phone ilike '%' || p_search || '%'
             or p.school ilike '%' || p_search || '%')
        and (p_platform is null or p_platform = '' or exists (
             select 1 from public.user_apps a where a.user_id = u.id and case p_platform
               when 'windows' then a.platform = 'windows'
               when 'android' then a.platform = 'android'
               when 'direct' then a.platform = 'android' and a.flavor = 'direct'
               when 'play' then a.platform = 'android' and a.flavor = 'play'
               else false end)
             or (p_platform = 'none' and not exists (select 1 from public.user_apps a where a.user_id = u.id)))
    ), filtered as (
      select b.* from base b
      where p_plan is null or p_plan = ''
         or (p_plan = 'premium' and b.prem) or (p_plan = 'free' and not b.prem and b.role is null)
         or (p_plan = 'staff' and b.role is not null) or (p_plan = 'banned' and b.banned_at is not null)
    )
    select f.id, f.email, f.full_name, f.phone, f.state, f.school, f.created_at, f.last_sign_in_at,
           greatest(f.last_sign_in_at, (select max(a.last_seen) from public.user_apps a where a.user_id = f.id),
                    (select max(t.submitted_at) from public.attempts t where t.user_id = f.id)),
           f.prem,
           (select max(e.expires_at) from public.entitlements e where e.user_id = f.id and e.revoked_at is null and e.expires_at > now()),
           f.banned_at, f.role, f.target_exams,
           (select array_agg(coalesce(sj.name, c) order by ord) from unnest(f.jamb_subjects) with ordinality x(c, ord)
              left join public.subjects sj on sj.code = x.c),
           private.user_apps_json(f.id),
           (select coalesce(sum(l.amount), 0)::integer from public.xp_ledger l where l.user_id = f.id),
           (select count(*) from public.attempts t where t.user_id = f.id and t.status = 'submitted'),
           count(*) over ()
    from filtered f
    order by f.created_at desc
    limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0);
end;
$$;
revoke all on function public.admin_list_users(text, integer, integer, text, text) from public, anon;
grant execute on function public.admin_list_users(text, integer, integer, text, text) to authenticated;

/** The counts at the top of Admin → Users. */
create or replace function public.admin_users_summary()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'total', (select count(*) from auth.users),
    'new_7d', (select count(*) from auth.users where created_at > now() - interval '7 days'),
    'active_7d', (select count(distinct x.uid) from (
        select id as uid from auth.users where last_sign_in_at > now() - interval '7 days'
        union all select user_id from public.user_apps where last_seen > now() - interval '7 days'
        union all select user_id from public.attempts where submitted_at > now() - interval '7 days') x),
    'premium', (select count(*) from public.profiles p where private.has_premium(p.id)),
    'banned', (select count(*) from public.profiles where banned_at is not null),
    'android', (select count(distinct user_id) from public.user_apps where platform = 'android'),
    'direct', (select count(distinct user_id) from public.user_apps where platform = 'android' and flavor = 'direct'),
    'play', (select count(distinct user_id) from public.user_apps where platform = 'android' and flavor = 'play'),
    'windows', (select count(distinct user_id) from public.user_apps where platform = 'windows'),
    'no_app', (select count(*) from auth.users u where not exists (select 1 from public.user_apps a where a.user_id = u.id)));
end;
$$;
revoke all on function public.admin_users_summary() from public, anon;
grant execute on function public.admin_users_summary() to authenticated;

create or replace function public.admin_user_detail(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_streak record;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  select * into v_streak from private.streak(p_user);
  return (
    select jsonb_build_object(
      'id', u.id, 'email', u.email, 'created_at', u.created_at, 'last_sign_in_at', u.last_sign_in_at,
      'email_confirmed', u.email_confirmed_at is not null,
      'profile', to_jsonb(p) - 'id',
      'is_premium', private.has_premium(u.id),
      'entitlements', coalesce((select jsonb_agg(jsonb_build_object(
          'id', e.id, 'source', e.source, 'plan', pl.name, 'starts_at', e.starts_at, 'expires_at', e.expires_at,
          'revoked_at', e.revoked_at, 'reason', e.reason) order by e.created_at desc)
        from public.entitlements e left join public.plans pl on pl.id = e.plan_id where e.user_id = u.id), '[]'::jsonb),
      'staff_role', (select s.role from public.staff s where s.user_id = u.id),
      'apps', private.user_apps_json(u.id),
      'subjects', (select coalesce(jsonb_agg(coalesce(sj.name, x.c) order by x.ord), '[]'::jsonb)
                   from unnest(p.jamb_subjects) with ordinality x(c, ord) left join public.subjects sj on sj.code = x.c),
      'career', (select c.name from public.careers c where c.id = p.career_id),
      'xp', (select coalesce(sum(l.amount), 0) from public.xp_ledger l where l.user_id = u.id),
      'streak', jsonb_build_object('current', coalesce(v_streak.current_days, 0), 'longest', coalesce(v_streak.longest_days, 0)),
      'tests', (select jsonb_build_object('count', count(*), 'last_at', max(t.submitted_at),
                  'average', round(avg(100.0 * (t.server_score ->> 'total')::numeric / nullif((t.server_score ->> 'max')::numeric, 0))),
                  'best', round(max(100.0 * (t.server_score ->> 'total')::numeric / nullif((t.server_score ->> 'max')::numeric, 0))))
                from public.attempts t where t.user_id = u.id and t.status = 'submitted'),
      'devices', (select count(*) from public.device_accounts d where d.user_id = u.id))
    from auth.users u left join public.profiles p on p.id = u.id
    where u.id = p_user);
end;
$$;
revoke all on function public.admin_user_detail(uuid) from public, anon;
grant execute on function public.admin_user_detail(uuid) to authenticated;
