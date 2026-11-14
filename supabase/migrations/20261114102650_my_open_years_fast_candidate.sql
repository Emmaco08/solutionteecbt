-- The free/premium year rule for one exam year, given the student's rules (same logic as private.year_open).
create or replace function private.rule_open(p_rules jsonb, p_code text, p_kind text, p_rank bigint, p_extra int)
returns boolean language plpgsql immutable set search_path = '' as $$
declare v_exam jsonb; v_rule jsonb;
begin
  if p_rules is null or p_code is null then return false; end if;
  v_exam := p_rules -> p_code;
  if v_exam is null or v_exam in ('0'::jsonb, 'false'::jsonb) then return false; end if;
  v_rule := case when p_kind = 'pq' then p_rules -> 'pq' else v_exam end;
  if v_rule is null or v_rule in ('0'::jsonb, 'false'::jsonb) then return false; end if;
  if v_rule = '"all"'::jsonb or v_rule = 'true'::jsonb then return true; end if;
  if jsonb_typeof(v_rule) <> 'number' then return false; end if;
  return p_rank <= (v_rule::text)::int + coalesce(p_extra, 0);
end $$;

-- Candidate: the same answers as my_open_years, but the student's plan, rules and bans are read once, and the
-- per-year checks (offers, ad unlocks) run once per exam year instead of once per subject row and kind.
create or replace function private.my_open_years_fast(p_exam smallint default null)
returns table(exam_id smallint, subject_id smallint, year smallint, cbt_open boolean, pq_open boolean)
language plpgsql stable security definer set search_path = '' as $$
declare v_rules jsonb; v_extra int; v_which text;
begin
  if private.is_staff() then
    return query select y.exam_id, y.subject_id, y.year, true, true from public.exam_years y
      where y.status = 'published' and (p_exam is null or y.exam_id = p_exam) order by 1, 2, 3;
    return;
  end if;
  if (select auth.uid()) is null or private.is_banned() then
    return query select y.exam_id, y.subject_id, y.year, false, false from public.exam_years y
      where y.status = 'published' and (p_exam is null or y.exam_id = p_exam) order by 1, 2, 3;
    return;
  end if;
  select r.rules into v_rules from public.access_rules r where r.tier = case when private.has_premium() then 'premium' else 'free' end;
  v_extra := private.welcome_extra_years();
  v_which := coalesce(v_rules ->> 'which', 'oldest');
  return query
  with ey as (
    select distinct y.exam_id as ex, y.year as yr from public.exam_years y
    where y.status = 'published' and (p_exam is null or y.exam_id = p_exam)),
  ranked as (
    select ey.ex, ey.yr, lower(e.code) as code,
           row_number() over (partition by ey.ex order by case when v_which = 'newest' then -ey.yr else ey.yr end) as rn
    from ey join public.exam_bodies e on e.id = ey.ex and e.is_active),
  chk as (
    select r.ex, r.yr, r.code, r.rn, private.year_override(r.ex, r.yr) as ovr,
           private.ad_unlocked('year', r.ex::text || ':' || r.yr::text) as ad
    from ranked r),
  dec as (
    select c.ex, c.yr,
           case when c.ovr is not null then c.ovr when c.ad then true else private.rule_open(v_rules, c.code, 'cbt', c.rn, v_extra) end as cbt,
           case when c.ovr is not null then c.ovr when c.ad then true else private.rule_open(v_rules, c.code, 'pq', c.rn, v_extra) end as pq
    from chk c)
  select y.exam_id, y.subject_id, y.year, coalesce(d.cbt, false), coalesce(d.pq, false)
  from public.exam_years y left join dec d on d.ex = y.exam_id and d.yr = y.year
  where y.status = 'published' and (p_exam is null or y.exam_id = p_exam)
  order by 1, 2, 3;
end $$;
revoke all on function private.my_open_years_fast(smallint) from public;
