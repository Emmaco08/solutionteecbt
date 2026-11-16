-- Leaderboards for every exam (owner, 16 Nov 2026, D-175): exams the admin adds (JUPEB, Post-UTME, …) get a board like
-- WAEC and NECO: best single-subject paper, out of the exam's score scale (exam_configs.score_scale, 100 by default).
-- JAMB keeps the full-mock board out of 400. Admin → Leaderboard can switch each exam's board off.

create or replace function private.lb_entries_w(p_exam text, p_from timestamp with time zone, p_to timestamp with time zone, p_subject smallint)
 returns table(attempt_id uuid, user_id uuid, score integer, time_s integer, submitted_at timestamp with time zone, held text, review text)
 language plpgsql stable security definer set search_path to ''
as $function$
declare v_c jsonb := private.lb_cfg(); v_fast integer; v_minq integer; v_max integer;
begin
  if p_exam = 'JAMB' then
    return query select * from private.lb_attempts_w(p_from, p_to);
    return;
  end if;
  v_fast := coalesce((v_c ->> 'subject_fast_minutes')::int, 5);
  v_minq := coalesce((v_c ->> 'subject_min_questions')::int, 40);
  v_max := coalesce((select c.score_scale from public.exam_configs c join public.exam_bodies e on e.id = c.exam_id where e.code = p_exam), 100);
  return query
  select a.id, a.user_id, (a.server_score ->> 'total')::int, a.time_used_s, a.submitted_at,
         case when v_fast <= 0 then null
              when a.time_used_s < v_fast * 60 then 'Finished in under ' || v_fast || ' minutes'
              when (a.server_score ->> 'total')::int >= v_max * 95 / 100 and a.time_used_s < v_fast * 180 then 'Near-perfect score in under ' || (v_fast * 3) || ' minutes'
              when coalesce((v_c ->> 'fair_hold')::int, 50) > 0 and coalesce(a.risk, 0) >= coalesce((v_c ->> 'fair_hold')::int, 50)
                then 'Fair play ' || a.risk || '/100: ' || coalesce(a.fair ->> 'why', '')
         end,
         r.decision
  from public.attempts a
  join public.exam_bodies e on e.id = a.exam_id and e.code = p_exam
  left join public.leaderboard_reviews r on r.attempt_id = a.id
  where a.mode in ('subject', 'year') and a.status = 'submitted'
    and (a.server_score ->> 'max')::int = v_max
    and jsonb_array_length(coalesce(a.server_score -> 'subjects', '[]')) = 1
    and (a.server_score -> 'subjects' -> 0 ->> 'subject_id')::smallint = p_subject
    and (a.server_score ->> 'questions')::int >= v_minq
    and a.submitted_at >= p_from
    and a.submitted_at < p_to;
end;
$function$;

/** The exams with a board, in order: JAMB, WAEC, NECO, then the admin's own exams (oldest first). */
create or replace function private.lb_exams(v_set jsonb)
returns text[] language sql stable security definer set search_path = '' as $$
  select array_agg(e.code order by coalesce(array_position(array['JAMB', 'WAEC', 'NECO'], e.code::text), 100), e.id)
  from public.exam_bodies e
  where e.is_active and coalesce((v_set -> 'exams' ->> e.code)::boolean, true);
$$;

create or replace function public.leaderboard_for(p_exam text default 'JAMB'::text, p_season integer default null::integer, p_scope text default 'ng'::text,
  p_subject smallint default null::smallint, p_period text default 'season'::text, p_offset integer default 0)
 returns jsonb language plpgsql stable security definer set search_path to ''
as $function$
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
  v_period text := case when p_period in ('week', 'month', 'year', 'all') then p_period else 'season' end;
  v_from timestamptz; v_to timestamptz; v_label text;
  v_max integer;
  v_names_map jsonb;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  select s.value into v_set from public.app_settings s where s.key = 'leaderboard';
  if not coalesce((select f.enabled from public.feature_flags f where f.key = 'leaderboard_enabled'), true)
     or not coalesce((v_set ->> 'on')::boolean, false) then
    return jsonb_build_object('on', false);
  end if;
  v_exams := private.lb_exams(v_set);
  if v_exams is null then return jsonb_build_object('on', false); end if;
  v_exam := case when upper(p_exam) = any (v_exams) then upper(p_exam) else v_exams[1] end;
  v_max := case when v_exam = 'JAMB' then 400
                else coalesce((select c.score_scale from public.exam_configs c join public.exam_bodies e on e.id = c.exam_id where e.code = v_exam), 100) end;
  select jsonb_object_agg(e.code, e.name) into v_names_map from public.exam_bodies e where e.code = any (v_exams);

  v_min := greatest(coalesce((v_set ->> 'min_mocks')::int, 1), 1);
  v_names := coalesce(v_set ->> 'names', 'first-initial');
  select array_agg(distinct x order by x desc) into v_seasons
  from (select v_now as x union select (j)::int from jsonb_array_elements_text(coalesce(v_set -> 'past_seasons', '[]')) j
        where (j)::int < v_now) t;
  v_season := case when p_season = any (v_seasons) then p_season else v_now end;
  if v_season <> v_now or (v_period <> 'season' and coalesce(p_offset, 0) > 0) then v_scope := 'ng'; end if;
  select w.from_ts, w.to_ts, w.label into v_from, v_to, v_label
  from private.lb_window(v_period, least(greatest(coalesce(p_offset, 0), 0), 52), v_season) w;
  select p.state into v_state from public.profiles p where p.id = v_uid;
  if v_scope = 'state' and coalesce(v_state, '') = '' then v_scope := 'ng'; end if;

  if v_exam <> 'JAMB' then
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
    select x.* from private.lb_entries_w(v_exam, v_from, v_to, v_subject) x
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
  if (v_period = 'season' and v_season = v_now) or (v_period <> 'season' and coalesce(p_offset, 0) = 0) then v_best := null; end if;

  return jsonb_build_object('on', true, 'exam', v_exam, 'exams', to_jsonb(v_exams), 'exam_names', coalesce(v_names_map, '{}'::jsonb), 'max', v_max,
    'subject', v_subject, 'subjects', coalesce(v_subjects, '[]'::jsonb),
    'seasons', to_jsonb(v_seasons), 'season', v_season, 'current', case when v_period = 'season' then v_season = v_now else coalesce(p_offset, 0) = 0 end,
    'scope', v_scope, 'period', v_period, 'offset', coalesce(p_offset, 0), 'label', v_label, 'my_state', v_state, 'min_mocks', v_min, 'top', v_top, 'me', v_me, 'best', v_best);
end;
$function$;

-- Admin → Leaderboard "Recent tests": the admin's own exams too.
create or replace function public.admin_leaderboard_recent(p_limit integer default 40)
 returns jsonb language plpgsql stable security definer set search_path to ''
as $function$
declare v_c jsonb := private.lb_cfg(); v_minq integer; v_fast integer; v_sminq integer; v_sfast integer; v_staff boolean;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  v_minq := coalesce((v_c ->> 'min_questions')::int, 100);
  v_fast := coalesce((v_c ->> 'fast_minutes')::int, 15);
  v_sminq := coalesce((v_c ->> 'subject_min_questions')::int, 40);
  v_sfast := coalesce((v_c ->> 'subject_fast_minutes')::int, 5);
  v_staff := coalesce((v_c ->> 'include_staff')::boolean, false);
  return coalesce((
    select jsonb_agg(x order by (x ->> 'submitted_at') desc) from (
      select jsonb_build_object('attempt_id', t.id, 'exam', t.code, 'subject', t.subject, 'name', t.full_name, 'state', t.state,
        'score', t.score, 'max', t.mx, 'questions', t.qs, 'time_s', t.time_used_s, 'submitted_at', t.submitted_at,
        'reason', case
          when t.banned then 'Banned account'
          when not v_staff and t.is_staff then 'Staff account (staff are left out)'
          when t.hidden then 'The student chose to hide'
          when t.qs < t.need_q then 'Only ' || t.qs || ' questions (needs ' || t.need_q || ')'
          when t.decision = 'rejected' then 'You kept it off'
          when t.held is not null and t.decision is distinct from 'ok' then 'Held: ' || t.held
        end,
        'held', t.held is not null and t.qs >= t.need_q and t.decision is null) as x
      from (
        select a.id, e.code, a.time_used_s, a.submitted_at, p.full_name, p.state, p.banned_at is not null as banned, p.hide_on_leaderboard as hidden,
               exists (select 1 from public.staff st where st.user_id = a.user_id) as is_staff, r.decision,
               (a.server_score ->> 'total')::int as score, (a.server_score ->> 'max')::int as mx, (a.server_score ->> 'questions')::int as qs,
               case when e.code = 'JAMB' then null else (select s.name from public.subjects s where s.id = (a.server_score -> 'subjects' -> 0 ->> 'subject_id')::smallint) end as subject,
               case when e.code = 'JAMB' then v_minq else v_sminq end as need_q,
               case when e.code = 'JAMB' then private.lb_suspicious((a.server_score ->> 'total')::int, a.time_used_s, v_fast)
                    when v_sfast <= 0 then null
                    when a.time_used_s < v_sfast * 60 then 'Finished in under ' || v_sfast || ' minutes'
                    when (a.server_score ->> 'total')::int >= (a.server_score ->> 'max')::int * 95 / 100 and a.time_used_s < v_sfast * 180
                      then 'Near-perfect score in under ' || (v_sfast * 3) || ' minutes'
               end as held
        from public.attempts a
        join public.exam_bodies e on e.id = a.exam_id
        join public.profiles p on p.id = a.user_id
        left join public.leaderboard_reviews r on r.attempt_id = a.id
        where a.status = 'submitted'
          and ((e.code = 'JAMB' and a.mode = 'full' and (a.server_score ->> 'max') = '400')
            or (e.code <> 'JAMB' and a.mode in ('subject', 'year')
                and (a.server_score ->> 'max')::int = coalesce((select c.score_scale from public.exam_configs c where c.exam_id = e.id), 100)
                and jsonb_array_length(coalesce(a.server_score -> 'subjects', '[]')) = 1))
        order by a.submitted_at desc
        limit least(greatest(p_limit, 1), 100)) t) y), '[]'::jsonb);
end;
$function$;
