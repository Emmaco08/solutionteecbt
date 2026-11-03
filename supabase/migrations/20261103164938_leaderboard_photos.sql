-- Owner (D-069): students' profile photos on leaderboards, if they allow it (allowed by default).
alter table public.profiles add column show_photo_on_leaderboard boolean not null default true;
grant update (show_photo_on_leaderboard) on public.profiles to authenticated;

/** May the signed-in student see this profile photo? Their own always; someone else's only when that student
    shows their photo on leaderboards, is not hidden or banned, and the leaderboard is on. */
create or replace function public.can_view_avatar(p_key text)
returns boolean language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and not private.is_banned() and (
    p_key like 'a/' || (select auth.uid())::text || '/%'
    or (coalesce((select (s.value ->> 'on')::boolean from public.app_settings s where s.key = 'leaderboard'), false)
        and exists (select 1 from public.profiles p where p.avatar_path = p_key and p.show_photo_on_leaderboard
                    and not p.hide_on_leaderboard and p.banned_at is null)));
$$;
revoke execute on function public.can_view_avatar(text) from public, anon;
grant execute on function public.can_view_avatar(text) to authenticated;

create or replace function public.leaderboard_for(p_exam text default 'JAMB', p_season integer default null,
                                                  p_scope text default 'ng', p_subject smallint default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_set jsonb;
  v_now integer := private.jamb_season(now());
  v_exams text[];
  v_exam text;
  v_subjects jsonb;
  v_subject smallint;
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
  select array_agg(x order by array_position(array['JAMB', 'WAEC', 'NECO'], x)) into v_exams
  from unnest(array['JAMB', 'WAEC', 'NECO']) x
  where coalesce((v_set -> 'exams' ->> x)::boolean, true);
  if v_exams is null then return jsonb_build_object('on', false); end if;
  v_exam := case when upper(p_exam) = any (v_exams) then upper(p_exam) else v_exams[1] end;

  v_min := greatest(coalesce((v_set ->> 'min_mocks')::int, 1), 1);
  v_names := coalesce(v_set ->> 'names', 'first-initial');
  select array_agg(distinct x order by x desc) into v_seasons
  from (select v_now as x union select (j)::int from jsonb_array_elements_text(coalesce(v_set -> 'past_seasons', '[]')) j
        where (j)::int < v_now) t;
  v_season := case when p_season = any (v_seasons) then p_season else v_now end;
  if v_season <> v_now then v_scope := 'ng'; end if;
  select p.state into v_state from public.profiles p where p.id = v_uid;
  if v_scope = 'state' and coalesce(v_state, '') = '' then v_scope := 'ng'; end if;

  if v_exam <> 'JAMB' then
    -- The exam's subjects (those with papers in the bank), so a student can pick one even before anyone has played.
    select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name) order by s.name), '[]'::jsonb) into v_subjects
    from public.subjects s
    where exists (select 1 from public.questions qq join public.exam_bodies e on e.id = qq.exam_id and e.code = v_exam
                  where qq.subject_id = s.id and qq.status = 'published' and qq.deleted_at is null);
    v_subject := coalesce(
      (select (x ->> 'id')::smallint from jsonb_array_elements(v_subjects) x where (x ->> 'id')::smallint = p_subject),
      (select (x ->> 'id')::smallint from jsonb_array_elements(v_subjects) x
       where (x ->> 'name') ilike any (array['%english%', '%mathematics%']) order by x ->> 'name' limit 1),
      (select (v_subjects -> 0 ->> 'id')::smallint));
  end if;

  with counted as (
    select x.* from private.lb_entries(v_exam, v_season, v_subject) x
    where x.review is distinct from 'rejected' and (x.held is null or x.review = 'ok')
  ), best as (
    select distinct on (c.user_id) c.user_id, c.score, c.time_s, c.submitted_at,
           count(*) over (partition by c.user_id) as mocks
    from counted c
    order by c.user_id, c.score desc, c.time_s asc, c.submitted_at asc
  ), ranked as (
    select b.user_id, b.score, b.mocks, private.lb_name(p.full_name, v_names) as name, p.state, p.school,
           case when p.show_photo_on_leaderboard and coalesce(p.avatar_path, '') <> '' then p.avatar_path end as photo,
           row_number() over (order by b.score desc, b.time_s asc, b.submitted_at asc)::int as rnk
    from best b
    join public.profiles p on p.id = b.user_id
    where b.mocks >= v_min and not p.hide_on_leaderboard and p.banned_at is null
      and (coalesce((v_set ->> 'include_staff')::boolean, false) or not exists (select 1 from public.staff st where st.user_id = b.user_id))
      and (v_scope = 'ng' or p.state = v_state)
  )
  select
    (select coalesce(jsonb_agg(jsonb_build_object('rank', l.rnk, 'name', l.name, 'state', l.state, 'score', l.score, 'photo', l.photo,
            'me', l.user_id = v_uid) order by l.rnk), '[]'::jsonb) from ranked l where l.rnk <= 50),
    (select jsonb_build_object('rank', l.rnk, 'score', l.score, 'mocks', l.mocks,
            'ahead', (select a2.score - l.score from ranked a2 where a2.rnk = l.rnk - 1)) from ranked l where l.user_id = v_uid),
    (select jsonb_build_object('name', l.name, 'state', l.state, 'school', l.school, 'score', l.score, 'photo', l.photo) from ranked l where l.rnk = 1),
    (select count(*)::int from counted c where c.user_id = v_uid)
    into v_top, v_me, v_best, v_my_mocks;

  if v_me is null then
    v_me := jsonb_build_object('rank', null, 'mocks', v_my_mocks, 'needs', greatest(v_min - v_my_mocks, 0),
      'hidden', coalesce((select p.hide_on_leaderboard from public.profiles p where p.id = v_uid), false));
  end if;
  if v_season = v_now then v_best := null; end if;

  return jsonb_build_object('on', true, 'exam', v_exam, 'exams', to_jsonb(v_exams), 'max', case when v_exam = 'JAMB' then 400 else 100 end,
    'subject', v_subject, 'subjects', coalesce(v_subjects, '[]'::jsonb),
    'seasons', to_jsonb(v_seasons), 'season', v_season, 'current', v_season = v_now,
    'scope', v_scope, 'my_state', v_state, 'min_mocks', v_min, 'top', v_top, 'me', v_me, 'best', v_best);
end;
$$;

