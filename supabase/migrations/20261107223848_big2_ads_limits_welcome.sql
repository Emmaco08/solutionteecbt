-- Ads v2 limits + first-day welcome (owner, 2026-11-07).
-- 1) Watching ads opens only what the admin allows: past-question years chosen per exam (app_settings.content_access
--    -> years.ads_years = {"<exam id>": [years] | "all"}), plus a cap on how many years / items a student can open by
--    watching per day (content_access -> limits = {"year_per_day": 2, "item_per_day": {"note": 3, ...}}).
--    A year with its own "watch videos" rule (year_access) is always allowed.
-- 2) "Open a year" offers at breaks: ad_year_suggest() picks a locked year the student may open by watching.
-- 3) First-day welcome (app_settings.welcome = {on, hours, ads_level, extra_years}): for the first hours after joining,
--    a lighter ads level and more free years, without telling the student.

insert into public.app_settings (key, value, is_public)
values ('welcome', '{"on": false, "hours": 24, "ads_level": "low", "extra_years": 2}', false)
on conflict (key) do nothing;

update public.app_settings
set value = jsonb_set(jsonb_set(value, '{years,ads_years}', coalesce(value -> 'years' -> 'ads_years', '{}'::jsonb)),
                      '{limits}', coalesce(value -> 'limits', '{"year_per_day": 2, "item_per_day": {}}'::jsonb))
where key = 'content_access';

-- Is the student in their first-day welcome?
create or replace function private.welcome_active(p_uid uuid default null) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((w.value ->> 'on')::boolean, false)
     and exists (select 1 from public.profiles p where p.id = coalesce(p_uid, (select auth.uid()))
                 and p.created_at > now() - make_interval(hours => greatest(coalesce((w.value ->> 'hours')::int, 24), 1)))
  from public.app_settings w where w.key = 'welcome';
$$;

create or replace function private.welcome_extra_years() returns integer
language sql stable security definer set search_path = '' as $$
  select case when coalesce(private.welcome_active(), false)
              then greatest(coalesce((select (value ->> 'extra_years')::int from public.app_settings where key = 'welcome'), 0), 0) else 0 end;
$$;

-- The ads settings as this student gets them: in the welcome hours, the welcome ads level instead.
create or replace function private.welcome_settings(s jsonb) returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when coalesce(private.welcome_active(), false)
              and (select value ->> 'ads_level' from public.app_settings where key = 'welcome') in ('off', 'low', 'medium', 'high', 'high_extra', 'max', 'ultra')
              and coalesce(s ->> 'level', 'off') <> 'off'
              then s || jsonb_build_object('level', (select value ->> 'ads_level' from public.app_settings where key = 'welcome'))
              else s end;
$$;

-- May this year be opened by watching ads?
create or replace function private.year_ads_allowed(p_exam smallint, p_year smallint) returns boolean
language sql stable security definer set search_path = '' as $$
  select case
    when exists (select 1 from public.year_access a where a.exam_id = p_exam and a.year = p_year) then
      exists (select 1 from public.year_access a where a.exam_id = p_exam and a.year = p_year and a.access = 'ads')
    else coalesce((
      select case
        when jsonb_typeof(c.value -> 'years' -> 'ads_years' -> p_exam::text) = 'string' then c.value -> 'years' -> 'ads_years' ->> p_exam::text = 'all'
        when jsonb_typeof(c.value -> 'years' -> 'ads_years' -> p_exam::text) = 'array' then (c.value -> 'years' -> 'ads_years' -> p_exam::text) @> to_jsonb(p_year)
        else false end
      from public.app_settings c where c.key = 'content_access'), false)
       and coalesce((select value -> 'years' ->> 'mode' from public.app_settings where key = 'content_access'), 'default') in ('default', 'ads')
  end;
$$;

-- Watch-to-open caps: how many different years / items of a kind this student opened by watching in the last 24 hours.
create or replace function private.unlock_cap_left(p_kind text, p_ref text, p_item_kind text default null) returns integer
language plpgsql stable security definer set search_path = '' as $$
declare l jsonb; v_cap integer; v_used integer;
begin
  select coalesce(value -> 'limits', '{}'::jsonb) into l from public.app_settings where key = 'content_access';
  v_cap := case when p_kind = 'year' then (l ->> 'year_per_day')::int else (l -> 'item_per_day' ->> p_item_kind)::int end;
  if v_cap is null or v_cap <= 0 then return 999; end if;
  select count(distinct r.ref) into v_used from public.ad_rewards r
  where r.user_id = (select auth.uid()) and r.kind = p_kind and r.status = 'granted' and r.granted_at > now() - interval '24 hours'
    and r.ref <> p_ref
    and (p_kind = 'year' or exists (select 1 from public.study_items i where i.id::text = r.ref and i.kind = p_item_kind));
  return greatest(v_cap - v_used, 0);
end;
$$;

-- Can this student start watching to open this year / item now? null = yes, otherwise the reason.
create or replace function private.watch_block(p_kind text, p_ref text) returns text
language plpgsql stable security definer set search_path = '' as $$
declare v_exam smallint; v_year smallint; v_kind text;
begin
  if p_kind = 'year' then
    begin
      v_exam := split_part(p_ref, ':', 1)::smallint; v_year := split_part(p_ref, ':', 2)::smallint;
    exception when others then return 'missing';
    end;
    if not private.year_ads_allowed(v_exam, v_year) then return 'not_allowed'; end if;
    if private.unlock_cap_left('year', p_ref) <= 0 then return 'unlock_cap'; end if;
  elsif p_kind = 'item' then
    select i.kind into v_kind from public.study_items i where i.id::text = p_ref;
    if private.unlock_cap_left('item', p_ref, v_kind) <= 0 then return 'unlock_cap'; end if;
  end if;
  return null;
end;
$$;

create or replace function public.ad_reward_start(p_kind text, p_ref text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c jsonb := public.ads_config(); v_id uuid; v_uid uuid := (select auth.uid()); v_exam smallint; v_year smallint; v_block text;
begin
  if v_uid is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  if coalesce((c ->> 'on')::boolean, false) is false or coalesce((c -> 'formats' ->> 'rewarded')::boolean, true) is false then
    return jsonb_build_object('ok', false, 'why', 'off');
  end if;
  if coalesce((c ->> 'rewarded_left')::int, 0) <= 0 then return jsonb_build_object('ok', false, 'why', 'cap'); end if;
  if p_kind not in ('ai_prompts', 'note', 'streak_freeze', 'xp', 'year', 'item') then return jsonb_build_object('ok', false, 'why', 'kind'); end if;
  if p_kind in ('note', 'item') and not exists (select 1 from public.study_items i where i.id::text = p_ref and i.status = 'published' and i.deleted_at is null) then
    return jsonb_build_object('ok', false, 'why', 'missing');
  end if;
  if p_kind = 'item' and private.item_offer(p_ref::uuid) ->> 'mode' <> 'ads' then return jsonb_build_object('ok', false, 'why', 'kind'); end if;
  if p_kind = 'streak_freeze' and (select streak_freezes from public.profiles where id = v_uid) >= 2 then
    return jsonb_build_object('ok', false, 'why', 'full');
  end if;
  if p_kind = 'xp' and coalesce((c ->> 'xp_left')::int, 0) <= 0 then return jsonb_build_object('ok', false, 'why', 'xp_cap'); end if;
  if p_kind = 'year' then
    begin
      v_exam := split_part(p_ref, ':', 1)::smallint; v_year := split_part(p_ref, ':', 2)::smallint;
    exception when others then return jsonb_build_object('ok', false, 'why', 'missing');
    end;
    if not exists (select 1 from public.exam_years y where y.exam_id = v_exam and y.year = v_year and y.status = 'published') then
      return jsonb_build_object('ok', false, 'why', 'missing');
    end if;
    if private.year_offer(v_exam, v_year) ->> 'mode' in ('free', 'premium', 'pay') then return jsonb_build_object('ok', false, 'why', 'kind'); end if;
    p_ref := v_exam || ':' || v_year;
  end if;
  v_block := private.watch_block(p_kind, coalesce(p_ref, ''));
  if v_block is not null then return jsonb_build_object('ok', false, 'why', v_block); end if;
  insert into public.ad_rewards (user_id, kind, ref) values (v_uid, p_kind, coalesce(p_ref, '')) returning id into v_id;
  return jsonb_build_object('ok', true, 'nonce', v_id, 'test', coalesce((c ->> 'test')::boolean, true));
end;
$$;

-- The offer: also says whether watching is allowed now (watch_ok / watch_block).
create or replace function public.content_offer(p_kind text, p_ref text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare o jsonb; v_open boolean; v_exam smallint; v_year smallint; c jsonb := public.ads_config(); v_prog integer; v_block text;
begin
  if (select auth.uid()) is null then return jsonb_build_object('ok', false); end if;
  if p_kind = 'item' then
    o := private.item_offer(nullif(p_ref, '')::uuid);
    if o is null then return jsonb_build_object('ok', false); end if;
    select private.study_open(i.kind, i.is_free, i.id) into v_open from public.study_items i where i.id = p_ref::uuid;
  elsif p_kind = 'year' then
    v_exam := split_part(p_ref, ':', 1)::smallint; v_year := split_part(p_ref, ':', 2)::smallint;
    o := private.year_offer(v_exam, v_year);
    v_open := private.year_open(v_exam, v_year, 'cbt') or private.year_open(v_exam, v_year, 'pq');
    if o ->> 'mode' = 'default' then
      o := o || jsonb_build_object('ads', (private.reward_rule('year', p_ref) ->> 'need')::int,
                                   'minutes', (private.reward_rule('year', p_ref) ->> 'minutes')::int);
    end if;
  else
    return jsonb_build_object('ok', false);
  end if;
  v_block := private.watch_block(p_kind, p_ref);
  select p.count into v_prog from public.ad_progress p where p.user_id = (select auth.uid()) and p.kind = p_kind and p.ref = p_ref;
  return o || jsonb_build_object('ok', true, 'open', coalesce(v_open, false), 'premium', private.has_premium(),
    'bought', private.bought(p_kind, p_ref), 'progress', coalesce(v_prog, 0),
    'ads_on', coalesce((c ->> 'on')::boolean, false) and coalesce((c -> 'formats' ->> 'rewarded')::boolean, true),
    'rewarded_left', coalesce((c ->> 'rewarded_left')::int, 0),
    'watch_ok', v_block is null, 'watch_block', v_block);
end;
$$;

-- A locked year this student may open by watching (for the offer at breaks): their exams first, newest first.
create or replace function public.ad_year_suggest() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); c jsonb := public.ads_config(); r record; rule jsonb; v_prog integer;
begin
  if v_uid is null or not coalesce((c ->> 'on')::boolean, false) or coalesce((c ->> 'rewarded_left')::int, 0) <= 0 then
    return jsonb_build_object('ok', false);
  end if;
  if private.unlock_cap_left('year', '') <= 0 then return jsonb_build_object('ok', false, 'why', 'unlock_cap'); end if;
  for r in
    select distinct y.exam_id, y.year, e.code,
           (e.code = any (coalesce((select p.target_exams from public.profiles p where p.id = v_uid), '{}'::text[]))) as mine
    from public.exam_years y join public.exam_bodies e on e.id = y.exam_id and e.is_active
    where y.status = 'published'
    order by mine desc, y.year desc
  loop
    if private.year_ads_allowed(r.exam_id, r.year)
       and coalesce(private.year_offer(r.exam_id, r.year) ->> 'mode', 'default') in ('default', 'ads')
       and not private.year_open(r.exam_id, r.year, 'cbt') then
      rule := private.reward_rule('year', r.exam_id || ':' || r.year);
      select p.count into v_prog from public.ad_progress p where p.user_id = v_uid and p.kind = 'year' and p.ref = r.exam_id || ':' || r.year;
      return jsonb_build_object('ok', true, 'ref', r.exam_id || ':' || r.year, 'exam', r.code, 'year', r.year,
                                'need', (rule ->> 'need')::int, 'minutes', (rule ->> 'minutes')::int, 'progress', coalesce(v_prog, 0));
    end if;
  end loop;
  return jsonb_build_object('ok', false);
end;
$$;
revoke all on function public.ad_year_suggest() from public, anon;
grant execute on function public.ad_year_suggest() to authenticated;

-- The welcome in the ads settings and in the free years.
do $$
declare d text;
begin
  d := pg_get_functiondef('public.ads_config()'::regprocedure);
  if position('welcome_settings' in d) = 0 then
    d := replace(d, 'v_level := coalesce(s ->> ''level'', ''off'');',
                    's := private.welcome_settings(s);
  v_level := coalesce(s ->> ''level'', ''off'');');
    execute d;
  end if;
  d := pg_get_functiondef('private.year_open(smallint,smallint,text)'::regprocedure);
  if position('welcome_extra_years' in d) = 0 then
    d := replace(d, 'return p_year = any (v_years[1:(v_rule::text)::int]);',
                    'return p_year = any (v_years[1:(v_rule::text)::int + private.welcome_extra_years()]);');
    execute d;
  end if;
end $$;

-- Admin: save the welcome settings.
create or replace function public.admin_welcome_save(p jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_old jsonb; v jsonb;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  v := jsonb_build_object('on', coalesce((p ->> 'on')::boolean, false), 'hours', least(greatest(coalesce((p ->> 'hours')::int, 24), 1), 168),
                          'ads_level', case when p ->> 'ads_level' in ('off', 'low', 'medium', 'high', 'high_extra', 'max', 'ultra') then p ->> 'ads_level' else 'low' end,
                          'extra_years', least(greatest(coalesce((p ->> 'extra_years')::int, 0), 0), 20));
  select value into v_old from public.app_settings where key = 'welcome';
  insert into public.app_settings (key, value, is_public) values ('welcome', v, false)
  on conflict (key) do update set value = excluded.value, updated_at = now(), updated_by = (select auth.uid());
  insert into public.audit_log (actor, action, table_name, row_id, before, after)
  values ((select auth.uid()), 'welcome.save', 'app_settings', 'welcome', v_old, v);
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.admin_welcome_save(jsonb) from public, anon;
grant execute on function public.admin_welcome_save(jsonb) to authenticated;

create or replace function public.admin_welcome() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  return (select value from public.app_settings where key = 'welcome');
end;
$$;
revoke all on function public.admin_welcome() from public, anon;
grant execute on function public.admin_welcome() to authenticated;
