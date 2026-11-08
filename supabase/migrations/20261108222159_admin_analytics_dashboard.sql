-- D-124: full analytics for the admin dashboard, computed in Postgres (staff only). Days are Lagos days.
-- Students = accounts that are not staff. "Active" = did something that day: a test, an AI question, the question of
-- the day, a challenge, a study item, or opened the app (push token seen).

create or replace function private.activity_days(p_from timestamptz)
returns table (user_id uuid, day date)
language sql stable security definer set search_path = '' as $$
  select a.user_id, (a.started_at at time zone 'Africa/Lagos')::date from public.attempts a where a.started_at >= p_from
  union select u.user_id, u.day from public.ai_usage u where u.day >= (p_from at time zone 'Africa/Lagos')::date and u.used > 0
  union select q.user_id, q.day from public.qotd_answers q where q.answered_at >= p_from
  union select e.user_id, (coalesce(e.started_at, e.served_at) at time zone 'Africa/Lagos')::date
        from public.challenge_entries e where coalesce(e.started_at, e.served_at) >= p_from
  union select s.user_id, (s.updated_at at time zone 'Africa/Lagos')::date from public.study_progress s where s.updated_at >= p_from
  union select t.user_id, (t.last_seen at time zone 'Africa/Lagos')::date from public.push_tokens t where t.last_seen >= p_from;
$$;

-- Course area from the JAMB subject combination (the app does not ask for a course).
create or replace function private.course_area(s text[]) returns text
language sql immutable set search_path = '' as $$
  select case
    when s is null or cardinality(s) = 0 then 'Not set yet'
    when s @> array['bio','chm','phy'] then 'Medicine and health sciences'
    when s @> array['mth','phy','chm'] then 'Engineering and physical sciences'
    when s @> array['bio','chm'] or s @> array['bio','agr'] then 'Life and agricultural sciences'
    when s @> array['mth','phy'] or 'cmp' = any(s) or 'fmt' = any(s) then 'Computing and mathematical sciences'
    when (s && array['acc','com']) or s @> array['eco','mth'] then 'Business, economics and management'
    when 'lit' = any(s) and (s && array['gov','crs','irs','his']) then 'Arts, law and humanities'
    when s && array['gov','eco','geo','civ'] then 'Social sciences'
    else 'Other combinations' end;
$$;

create or replace function public.admin_analytics(p_days int default 30)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  d int := greatest(least(coalesce(p_days, 30), 365), 7);
  tz text := 'Africa/Lagos';
  today date := (now() at time zone 'Africa/Lagos')::date;
  f date; fp date;             -- first day of this period, and of the previous one
  t0 timestamptz; tp timestamptz;
  r jsonb := '{}'::jsonb;
begin
  if not private.is_staff() then raise exception 'not_allowed' using errcode = '42501'; end if;
  f := today - (d - 1); fp := f - d;
  t0 := (f::timestamp at time zone tz); tp := (fp::timestamp at time zone tz);

  create temporary table if not exists _stu (id uuid primary key, created date, birth_year int, state text, targets text[], subjects text[], target_score int) on commit drop;
  truncate _stu;
  insert into _stu
  select p.id, (p.created_at at time zone tz)::date, p.birth_year, nullif(trim(p.state), ''), p.target_exams, p.jamb_subjects, p.target_score
  from public.profiles p where not exists (select 1 from public.staff s where s.user_id = p.id);

  create temporary table if not exists _act (user_id uuid, day date) on commit drop;
  truncate _act;
  insert into _act select a.user_id, a.day from private.activity_days(least(tp, (today - 75)::timestamp at time zone tz)) a join _stu s on s.id = a.user_id;

  create temporary table if not exists _pay (id uuid, user_id uuid, provider text, plan_id smallint, status text, amount int, discount int, channel text, created date, code_id uuid) on commit drop;
  truncate _pay;
  insert into _pay select p.id, p.user_id, p.provider, p.plan_id, p.status::text, p.amount_kobo, coalesce(p.discount_kobo, 0), p.channel, (p.created_at at time zone tz)::date, p.code_id
  from public.payments p where p.created_at >= tp;

  -- ---------------------------------------------------------------- overview
  r := r || jsonb_build_object('days', d, 'from', f, 'to', today, 'overview', jsonb_build_object(
    'students', (select count(*) from _stu),
    'new', (select count(*) from _stu where created >= f),
    'new_prev', (select count(*) from _stu where created >= fp and created < f),
    'dau', (select count(distinct user_id) from _act where day = today),
    'wau', (select count(distinct user_id) from _act where day > today - 7),
    'mau', (select count(distinct user_id) from _act where day > today - 30),
    'active', (select count(distinct user_id) from _act where day >= f),
    'active_prev', (select count(distinct user_id) from _act where day >= fp and day < f),
    'premium', (select count(distinct e.user_id) from public.entitlements e join _stu s on s.id = e.user_id
                where e.revoked_at is null and e.starts_at <= now() and e.expires_at > now()),
    'revenue', (select coalesce(sum(amount), 0) from _pay where status = 'success' and provider in ('paystack', 'play') and created >= f),
    'revenue_prev', (select coalesce(sum(amount), 0) from _pay where status = 'success' and provider in ('paystack', 'play') and created < f),
    'tests', (select count(*) from public.attempts a join _stu s on s.id = a.user_id where a.started_at >= t0),
    'tests_prev', (select count(*) from public.attempts a join _stu s on s.id = a.user_id where a.started_at >= tp and a.started_at < t0),
    'ai', (select coalesce(sum(u.used), 0) from public.ai_usage u join _stu s on s.id = u.user_id where u.day >= f),
    'ai_prev', (select coalesce(sum(u.used), 0) from public.ai_usage u join _stu s on s.id = u.user_id where u.day >= fp and u.day < f),
    'entries', (select count(*) from public.challenge_entries e join _stu s on s.id = e.user_id where coalesce(e.started_at, e.served_at) >= t0),
    'series', (select coalesce(jsonb_agg(jsonb_build_object(
        'day', g.day,
        'new', (select count(*) from _stu where created = g.day),
        'active', (select count(distinct user_id) from _act where day = g.day),
        'tests', (select count(*) from public.attempts a join _stu s on s.id = a.user_id where (a.started_at at time zone tz)::date = g.day),
        'ai', (select coalesce(sum(u.used), 0) from public.ai_usage u join _stu s on s.id = u.user_id where u.day = g.day),
        'revenue', (select coalesce(sum(amount), 0) from _pay where status = 'success' and provider in ('paystack', 'play') and created = g.day)
      ) order by g.day), '[]'::jsonb)
      from (select generate_series(f, today, interval '1 day')::date as day) g)
  ));

  -- ---------------------------------------------------------------- students
  r := r || jsonb_build_object('users', jsonb_build_object(
    'ages', (select coalesce(jsonb_agg(jsonb_build_object('label', label, 'n', n) order by o), '[]'::jsonb) from (
      select case when birth_year is null then 'Not given' when y < 13 then 'Under 13' when y <= 15 then '13 to 15' when y <= 17 then '16 to 17'
                  when y <= 20 then '18 to 20' when y <= 24 then '21 to 24' else '25 and over' end as label,
             min(case when birth_year is null then 9 when y < 13 then 0 when y <= 15 then 1 when y <= 17 then 2 when y <= 20 then 3 when y <= 24 then 4 else 5 end) as o,
             count(*) n
      from (select birth_year, extract(year from now())::int - birth_year as y from _stu) x group by 1) a),
    'exams', (select coalesce(jsonb_agg(jsonb_build_object('label', t, 'n', n) order by n desc), '[]'::jsonb)
              from (select t, count(*) n from _stu, unnest(targets) t group by t) e),
    'no_exam', (select count(*) from _stu where targets is null or cardinality(targets) = 0),
    'courses', (select coalesce(jsonb_agg(jsonb_build_object('label', c, 'n', n) order by n desc), '[]'::jsonb)
                from (select private.course_area(subjects) c, count(*) n from _stu group by 1) c),
    'subjects', (select coalesce(jsonb_agg(jsonb_build_object('label', coalesce(sb.name, x.code), 'n', x.n) order by x.n desc), '[]'::jsonb)
                 from (select code, count(*) n from _stu, unnest(subjects) code group by code) x left join public.subjects sb on sb.code = x.code),
    'combos', (select coalesce(jsonb_agg(jsonb_build_object('label', label, 'n', n) order by n desc), '[]'::jsonb) from (
      select (select string_agg(coalesce(sb.name, c), ', ' order by sb.sort) from unnest(subjects) c left join public.subjects sb on sb.code = c where c <> 'eng') label, count(*) n
      from _stu where subjects is not null and cardinality(subjects) > 1 group by subjects order by count(*) desc limit 10) c),
    'states', (select coalesce(jsonb_agg(jsonb_build_object('label', state, 'n', n) order by n desc), '[]'::jsonb)
               from (select coalesce(state, 'Not given') state, count(*) n from _stu group by 1 order by 2 desc limit 15) s),
    'scores', (select coalesce(jsonb_agg(jsonb_build_object('label', label, 'n', n) order by o), '[]'::jsonb) from (
      select case when target_score is null then 'Not set' when target_score < 200 then 'Under 200' when target_score < 250 then '200 to 249'
                  when target_score < 280 then '250 to 279' when target_score < 300 then '280 to 299' else '300 and above' end label,
             min(case when target_score is null then 9 when target_score < 200 then 0 when target_score < 250 then 1 when target_score < 280 then 2 when target_score < 300 then 3 else 4 end) o,
             count(*) n from _stu group by 1) s),
    'versions', (select coalesce(jsonb_agg(jsonb_build_object('label', v, 'n', n) order by n desc), '[]'::jsonb) from (
      select coalesce(t.app_version, 'Unknown') v, count(distinct t.user_id) n from public.push_tokens t join _stu s on s.id = t.user_id
      where t.last_seen > now() - interval '30 days' group by 1 order by 2 desc limit 8) v),
    'retention', jsonb_build_object(
      'd1', (select case when count(*) = 0 then null else round(100.0 * count(*) filter (where exists (select 1 from _act a where a.user_id = s.id and a.day = s.created + 1)) / count(*)) end
             from _stu s where s.created between today - 31 and today - 2),
      'd7', (select case when count(*) = 0 then null else round(100.0 * count(*) filter (where exists (select 1 from _act a where a.user_id = s.id and a.day between s.created + 7 and s.created + 13)) / count(*)) end
             from _stu s where s.created between today - 44 and today - 14),
      'd30', (select case when count(*) = 0 then null else round(100.0 * count(*) filter (where exists (select 1 from _act a where a.user_id = s.id and a.day between s.created + 30 and s.created + 36)) / count(*)) end
              from _stu s where s.created between today - 75 and today - 37),
      'cohort_d1', (select count(*) from _stu where created between today - 31 and today - 2))
  ));

  -- ---------------------------------------------------------------- learning and usage
  r := r || jsonb_build_object('usage', jsonb_build_object(
    'modes', (select coalesce(jsonb_agg(jsonb_build_object('label', mode, 'n', n, 'avg', avg_pct) order by n desc), '[]'::jsonb) from (
      select a.mode, count(*) n,
             round(avg(100.0 * (a.server_score ->> 'correct')::numeric / nullif((a.server_score ->> 'answered')::numeric, 0))) avg_pct
      from public.attempts a join _stu s on s.id = a.user_id where a.started_at >= t0 group by a.mode) m),
    'finished', (select count(*) from public.attempts a join _stu s on s.id = a.user_id where a.started_at >= t0 and a.status::text = 'submitted'),
    'abandoned', (select count(*) from public.attempts a join _stu s on s.id = a.user_id where a.started_at >= t0 and a.status::text = 'abandoned'),
    'avg_jamb', (select round(avg((a.server_score ->> 'total')::numeric)) from public.attempts a join _stu s on s.id = a.user_id
                 where a.started_at >= t0 and a.mode = 'full' and (a.server_score ->> 'max')::int = 400),
    'subjects', (select coalesce(jsonb_agg(jsonb_build_object('label', coalesce(sb.name, x.sid::text), 'n', x.answered, 'acc', x.acc) order by x.answered desc), '[]'::jsonb) from (
      select (j ->> 'subject_id')::int sid, sum((j ->> 'answered')::int) answered,
             round(100.0 * sum((j ->> 'correct')::int) / nullif(sum((j ->> 'answered')::int), 0)) acc
      from public.attempts a join _stu s on s.id = a.user_id, jsonb_array_elements(coalesce(a.server_score -> 'subjects', '[]'::jsonb)) j
      where a.started_at >= t0 group by 1) x left join public.subjects sb on sb.id = x.sid),
    'hours', (select jsonb_agg(coalesce(h.n, 0) order by g.h) from generate_series(0, 23) g(h) left join (
      select extract(hour from a.started_at at time zone tz)::int hr, count(*) n from public.attempts a join _stu s on s.id = a.user_id
      where a.started_at >= t0 group by 1) h on h.hr = g.h),
    'weekdays', (select jsonb_agg(coalesce(w.n, 0) order by g.w) from generate_series(1, 7) g(w) left join (
      select extract(isodow from day)::int dw, count(*) n from _act where day >= f group by 1) w on w.dw = g.w),
    'qotd', jsonb_build_object(
      'answers', (select count(*) from public.qotd_answers q join _stu s on s.id = q.user_id where q.day >= f),
      'correct_pct', (select round(100.0 * count(*) filter (where q.correct) / nullif(count(*), 0)) from public.qotd_answers q join _stu s on s.id = q.user_id where q.day >= f),
      'players', (select count(distinct q.user_id) from public.qotd_answers q join _stu s on s.id = q.user_id where q.day >= f)),
    'study', jsonb_build_object(
      'opened', (select count(*) from public.study_progress p join _stu s on s.id = p.user_id where p.updated_at >= t0),
      'learners', (select count(distinct p.user_id) from public.study_progress p join _stu s on s.id = p.user_id where p.updated_at >= t0),
      'finished', (select count(*) from public.study_progress p join _stu s on s.id = p.user_id where p.updated_at >= t0 and p.progress >= 0.95)),
    'ai', jsonb_build_object(
      'questions', (select coalesce(sum(u.used), 0) from public.ai_usage u join _stu s on s.id = u.user_id where u.day >= f),
      'users', (select count(distinct u.user_id) from public.ai_usage u join _stu s on s.id = u.user_id where u.day >= f and u.used > 0),
      'flagged', (select count(*) from public.ai_messages m where m.flagged_at >= t0)),
    'xp_streak', jsonb_build_object(
      'xp_earned', (select coalesce(sum(p.xp_earned), 0) from public.profiles p join _stu s on s.id = p.id))
  ));

  -- ---------------------------------------------------------------- challenges
  r := r || jsonb_build_object('challenges', jsonb_build_object(
    'held', (select count(*) from public.challenges c where c.published and c.starts_at >= t0 and c.starts_at <= now()),
    'live', (select count(*) from public.challenges c where c.published and c.starts_at <= now() and c.ends_at > now()),
    'upcoming', (select count(*) from public.challenges c where c.published and c.starts_at > now()),
    'entries', (select count(*) from public.challenge_entries e join _stu s on s.id = e.user_id where coalesce(e.started_at, e.served_at) >= t0),
    'players', (select count(distinct e.user_id) from public.challenge_entries e join _stu s on s.id = e.user_id where coalesce(e.started_at, e.served_at) >= t0),
    'finished', (select count(*) from public.challenge_entries e join _stu s on s.id = e.user_id where coalesce(e.started_at, e.served_at) >= t0 and e.finished_at is not null and e.dq_reason is null),
    'dq', (select count(*) from public.challenge_entries e join _stu s on s.id = e.user_id where coalesce(e.started_at, e.served_at) >= t0 and e.dq_reason is not null),
    'cash_paid', (select coalesce(sum(c.amount), 0) from public.prize_claims c where c.status = 'paid' and c.paid_at >= t0),
    'claims_waiting', (select count(*) from public.prize_claims c where c.status = 'submitted'),
    'premium_given', (select count(*) from public.challenge_entries e where e.premium_given and coalesce(e.finished_at, e.started_at) >= t0),
    'list', (select coalesce(jsonb_agg(x order by x.starts desc), '[]'::jsonb) from (
      select c.title, c.starts_at starts, c.mode, c.closed_at is not null closed,
             count(e.id) players, count(e.id) filter (where e.finished_at is not null and e.dq_reason is null) finished,
             count(e.id) filter (where e.dq_reason is not null) dq,
             round(avg(e.score) filter (where e.dq_reason is null and e.finished_at is not null)) avg_score,
             max(e.score) filter (where e.dq_reason is null) top_score
      from public.challenges c left join public.challenge_entries e on e.challenge_id = c.id
      where c.published and c.starts_at >= tp - interval '60 days' and c.starts_at <= now()
      group by c.id order by c.starts_at desc limit 12) x)
  ));

  -- ---------------------------------------------------------------- payments
  r := r || jsonb_build_object('payments', jsonb_build_object(
    'revenue', (select coalesce(sum(amount), 0) from _pay where status = 'success' and provider in ('paystack', 'play') and created >= f),
    'statuses', (select coalesce(jsonb_object_agg(status, n), '{}'::jsonb) from (select status, count(*) n from _pay where created >= f group by 1) s),
    'providers', (select coalesce(jsonb_agg(jsonb_build_object('label', provider, 'n', n, 'kobo', kobo) order by kobo desc, n desc), '[]'::jsonb) from (
      select provider, count(*) n, sum(amount) kobo from _pay where status = 'success' and created >= f group by 1) p),
    'plans', (select coalesce(jsonb_agg(jsonb_build_object('label', coalesce(pl.name, case when x.plan_id is null then 'Single items and other' else x.plan_id::text end), 'n', x.n, 'kobo', x.kobo) order by x.kobo desc), '[]'::jsonb) from (
      select plan_id, count(*) n, sum(amount) kobo from _pay where status = 'success' and provider in ('paystack', 'play') and created >= f group by 1) x
      left join public.plans pl on pl.id = x.plan_id),
    'channels', (select coalesce(jsonb_agg(jsonb_build_object('label', coalesce(channel, 'Not known'), 'n', n) order by n desc), '[]'::jsonb) from (
      select channel, count(*) n from _pay where status = 'success' and provider = 'paystack' and created >= f group by 1) c),
    'payers', (select count(distinct user_id) from _pay where status = 'success' and provider in ('paystack', 'play') and created >= f),
    'payers_ever', (select count(distinct p.user_id) from public.payments p join _stu s on s.id = p.user_id where p.status::text = 'success' and p.provider in ('paystack', 'play')),
    'repeat', (select count(*) from (select p.user_id from public.payments p join _stu s on s.id = p.user_id where p.status::text = 'success' and p.provider in ('paystack', 'play')
               group by 1 having count(*) > 1) x),
    'discounts', jsonb_build_object(
      'uses', (select count(*) from public.promo_redemptions pr where pr.created_at >= t0),
      'kobo', (select coalesce(sum(pr.discount_kobo), 0) from public.promo_redemptions pr where pr.created_at >= t0),
      'free_days', (select coalesce(sum(pr.days), 0) from public.promo_redemptions pr where pr.created_at >= t0)),
    'refunded', (select coalesce(sum(amount), 0) from _pay where status = 'refunded' and created >= f)
  ));

  -- ---------------------------------------------------------------- ads
  r := r || jsonb_build_object('ads', jsonb_build_object(
    'impressions', (select coalesce(sum(a.impressions), 0) from public.ad_daily a where a.day >= f and a.placement not like '%#%'),
    'clicks', (select coalesce(sum(a.clicks), 0) from public.ad_daily a where a.day >= f and a.placement not like '%#%'),
    'formats', (select coalesce(jsonb_agg(jsonb_build_object('label', format, 'n', n) order by n desc), '[]'::jsonb) from (
      select a.format, sum(a.impressions) n from public.ad_daily a where a.day >= f and a.placement not like '%#%' group by 1) x)
  ));
  return r;
end $$;

revoke all on function private.activity_days(timestamptz) from public, anon, authenticated;
revoke all on function public.admin_analytics(int) from public, anon;
grant execute on function public.admin_analytics(int) to authenticated;
