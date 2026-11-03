-- 4E1 follow-up (owner, D-067): the leaderboard rules are admin settings, and the admin sees why each recent mock
-- counts or not. Settings in app_settings 'leaderboard': min_questions (default 100), fast_minutes (default 15,
-- 0 = no too-fast check), include_staff (default false; for testing with a staff account).

update public.app_settings
set value = jsonb_build_object('min_questions', 100, 'fast_minutes', 15, 'include_staff', false) || value
where key = 'leaderboard';

create or replace function private.lb_cfg()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce((select s.value from public.app_settings s where s.key = 'leaderboard'), '{}'::jsonb);
$$;

/** Why a mock is held back (null = fine). p_fast = minutes; 0 turns the check off. */
create or replace function private.lb_suspicious(p_score integer, p_time_s integer, p_fast integer)
returns text language sql immutable set search_path = '' as $$
  select case
    when p_fast <= 0 then null
    when p_time_s < p_fast * 60 then 'Finished in under ' || p_fast || ' minutes'
    when p_score >= 380 and p_time_s < p_fast * 180 then 'Near-perfect score in under ' || (p_fast * 3) || ' minutes'
  end;
$$;

create or replace function private.lb_attempts(p_season integer)
returns table (attempt_id uuid, user_id uuid, score integer, time_s integer, submitted_at timestamptz, held text, review text)
language sql stable security definer set search_path = '' as $$
  with cfg as (select private.lb_cfg() as c)
  select a.id, a.user_id, (a.server_score ->> 'total')::int, a.time_used_s, a.submitted_at,
         private.lb_suspicious((a.server_score ->> 'total')::int, a.time_used_s, coalesce((cfg.c ->> 'fast_minutes')::int, 15)), r.decision
  from public.attempts a
  cross join cfg
  join public.exam_bodies e on e.id = a.exam_id and e.code = 'JAMB'
  left join public.leaderboard_reviews r on r.attempt_id = a.id
  where a.mode = 'full' and a.status = 'submitted'
    and (a.server_score ->> 'max') = '400'
    and (a.server_score ->> 'questions')::int >= coalesce((cfg.c ->> 'min_questions')::int, 100)
    and a.submitted_at >= make_timestamptz(p_season - 1, 7, 1, 0, 0, 0, 'Africa/Lagos')
    and a.submitted_at < make_timestamptz(p_season, 7, 1, 0, 0, 0, 'Africa/Lagos');
$$;
revoke execute on function private.lb_attempts(integer), private.lb_cfg() from public, anon, authenticated;

create or replace function public.leaderboard(p_season integer default null, p_scope text default 'ng')
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_set jsonb;
  v_now integer := private.jamb_season(now());
  v_seasons integer[];
  v_season integer;
  v_scope text := case when p_scope = 'state' then 'state' else 'ng' end;
  v_state text;
  v_min integer;
  v_names text;
  v_top jsonb; v_me jsonb; v_best jsonb;
  v_my_mocks integer;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  select s.value into v_set from public.app_settings s where s.key = 'leaderboard';
  if not coalesce((select f.enabled from public.feature_flags f where f.key = 'leaderboard_enabled'), true)
     or not coalesce((v_set ->> 'on')::boolean, false) then
    return jsonb_build_object('on', false);
  end if;
  v_min := greatest(coalesce((v_set ->> 'min_mocks')::int, 1), 1);
  v_names := coalesce(v_set ->> 'names', 'first-initial');
  select array_agg(distinct x order by x desc) into v_seasons
  from (select v_now as x union select (j)::int from jsonb_array_elements_text(coalesce(v_set -> 'past_seasons', '[]')) j
        where (j)::int < v_now) t;
  v_season := case when p_season = any (v_seasons) then p_season else v_now end;
  if v_season <> v_now then v_scope := 'ng'; end if;
  select p.state into v_state from public.profiles p where p.id = v_uid;
  if v_scope = 'state' and coalesce(v_state, '') = '' then v_scope := 'ng'; end if;

  with counted as (
    select x.* from private.lb_attempts(v_season) x
    where x.review is distinct from 'rejected' and (x.held is null or x.review = 'ok')
  ), best as (
    select distinct on (c.user_id) c.user_id, c.score, c.time_s, c.submitted_at,
           count(*) over (partition by c.user_id) as mocks
    from counted c
    order by c.user_id, c.score desc, c.time_s asc, c.submitted_at asc
  ), ranked as (
    select b.user_id, b.score, b.mocks, private.lb_name(p.full_name, v_names) as name, p.state, p.school,
           row_number() over (order by b.score desc, b.time_s asc, b.submitted_at asc)::int as rnk
    from best b
    join public.profiles p on p.id = b.user_id
    where b.mocks >= v_min and not p.hide_on_leaderboard and p.banned_at is null
      and (coalesce((v_set ->> 'include_staff')::boolean, false) or not exists (select 1 from public.staff st where st.user_id = b.user_id))
      and (v_scope = 'ng' or p.state = v_state)
  )
  select
    (select coalesce(jsonb_agg(jsonb_build_object('rank', l.rnk, 'name', l.name, 'state', l.state, 'score', l.score,
            'me', l.user_id = v_uid) order by l.rnk), '[]'::jsonb) from ranked l where l.rnk <= 50),
    (select jsonb_build_object('rank', l.rnk, 'score', l.score, 'mocks', l.mocks,
            'ahead', (select a2.score - l.score from ranked a2 where a2.rnk = l.rnk - 1)) from ranked l where l.user_id = v_uid),
    (select jsonb_build_object('name', l.name, 'state', l.state, 'school', l.school, 'score', l.score) from ranked l where l.rnk = 1),
    (select count(*)::int from counted c where c.user_id = v_uid)
    into v_top, v_me, v_best, v_my_mocks;

  if v_me is null then
    v_me := jsonb_build_object('rank', null, 'mocks', v_my_mocks, 'needs', greatest(v_min - v_my_mocks, 0),
      'hidden', coalesce((select p.hide_on_leaderboard from public.profiles p where p.id = v_uid), false));
  end if;

  if v_season = v_now then v_best := null; end if;

  return jsonb_build_object('on', true, 'seasons', to_jsonb(v_seasons), 'season', v_season, 'current', v_season = v_now,
    'scope', v_scope, 'my_state', v_state, 'min_mocks', v_min, 'top', v_top, 'me', v_me, 'best', v_best);
end;
$$;


/** Admin: the latest full JAMB mocks (any student) and whether each counts on the leaderboard, with the reason. */
create or replace function public.admin_leaderboard_recent(p_limit integer default 40)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_c jsonb := private.lb_cfg(); v_minq integer; v_fast integer; v_staff boolean;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  v_minq := coalesce((v_c ->> 'min_questions')::int, 100);
  v_fast := coalesce((v_c ->> 'fast_minutes')::int, 15);
  v_staff := coalesce((v_c ->> 'include_staff')::boolean, false);
  return coalesce((
    select jsonb_agg(x order by (x ->> 'submitted_at') desc) from (
      select jsonb_build_object('attempt_id', a.id, 'name', p.full_name, 'state', p.state,
        'score', (a.server_score ->> 'total')::int, 'questions', (a.server_score ->> 'questions')::int, 'time_s', a.time_used_s,
        'submitted_at', a.submitted_at, 'season', private.jamb_season(a.submitted_at),
        'reason', case
          when p.banned_at is not null then 'Banned account'
          when not v_staff and exists (select 1 from public.staff st where st.user_id = a.user_id) then 'Staff account (staff are left out)'
          when p.hide_on_leaderboard then 'The student chose to hide'
          when (a.server_score ->> 'max') is distinct from '400' then 'Not a 4-subject mock'
          when (a.server_score ->> 'questions')::int < v_minq then 'Only ' || (a.server_score ->> 'questions') || ' questions (needs ' || v_minq || ')'
          when r.decision = 'rejected' then 'You kept it off'
          when private.lb_suspicious((a.server_score ->> 'total')::int, a.time_used_s, v_fast) is not null and r.decision is distinct from 'ok'
            then 'Held: ' || private.lb_suspicious((a.server_score ->> 'total')::int, a.time_used_s, v_fast)
        end,
        'held', private.lb_suspicious((a.server_score ->> 'total')::int, a.time_used_s, v_fast) is not null
                and (a.server_score ->> 'questions')::int >= v_minq and r.decision is null) as x
      from public.attempts a
      join public.exam_bodies e on e.id = a.exam_id and e.code = 'JAMB'
      join public.profiles p on p.id = a.user_id
      left join public.leaderboard_reviews r on r.attempt_id = a.id
      where a.mode = 'full' and a.status = 'submitted'
      order by a.submitted_at desc
      limit least(greatest(p_limit, 1), 100)) t), '[]'::jsonb);
end;
$$;
revoke execute on function public.admin_leaderboard_recent(integer) from public, anon;
grant execute on function public.admin_leaderboard_recent(integer) to authenticated;
