-- Big update 2, step A (A3, A8): AI safety strikes and blocks, and reading a real lesson note.

-- ---------------------------------------------------------------- A8: strikes and blocks
create table if not exists public.ai_strikes (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  at timestamptz not null default now(),
  kind text not null default 'injection' check (kind in ('injection', 'data_leak', 'other')),
  text text
);
create index if not exists ai_strikes_user_at on public.ai_strikes (user_id, at desc);
alter table public.ai_strikes enable row level security;

-- One row per student who was ever blocked. level 1 = 3 days, 2 = 7 days, 3 = reported to the admin (blocked until decided).
create table if not exists public.ai_safety (
  user_id uuid primary key references auth.users (id) on delete cascade,
  level smallint not null default 0,
  blocked_until timestamptz,
  forever boolean not null default false,
  reason text,
  reported_at timestamptz,
  decision text check (decision in ('lift', 'block_ai', 'ban')),
  decided_at timestamptz,
  decided_by uuid,
  updated_at timestamptz not null default now()
);
alter table public.ai_safety enable row level security;
drop policy if exists ai_safety_staff on public.ai_safety;
create policy ai_safety_staff on public.ai_safety for select to authenticated using (private.is_staff());
drop policy if exists ai_strikes_staff on public.ai_strikes;
create policy ai_strikes_staff on public.ai_strikes for select to authenticated using (private.is_staff());

/** Called by the ai-chat Edge Function (service role) when a message tries to change the rules or pull out data. */
create or replace function private.ai_strike(p_uid uuid, p_kind text, p_text text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_s public.ai_safety; v_since timestamptz; v_n integer; v_level smallint; v_until timestamptz; v_forever boolean := false;
begin
  insert into public.ai_strikes (user_id, kind, text) values (p_uid, coalesce(p_kind, 'injection'), left(p_text, 500));
  select * into v_s from public.ai_safety where user_id = p_uid;
  v_since := greatest(now() - interval '24 hours', coalesce(v_s.blocked_until, '-infinity'::timestamptz), coalesce(v_s.decided_at, '-infinity'::timestamptz));
  select count(*) into v_n from public.ai_strikes where user_id = p_uid and at > v_since;
  if v_n < 3 then
    return jsonb_build_object('strikes', v_n, 'left', 3 - v_n, 'blocked', false);
  end if;
  v_level := least(coalesce(v_s.level, 0) + 1, 3);
  if v_level = 1 then v_until := now() + interval '3 days';
  elsif v_level = 2 then v_until := now() + interval '7 days';
  else v_until := null; v_forever := true;
  end if;
  insert into public.ai_safety (user_id, level, blocked_until, forever, reason, reported_at, decision, decided_at, decided_by, updated_at)
  values (p_uid, v_level, v_until, v_forever,
          'Repeated attempts to break the AI tutor''s rules or get private data (' || v_n || ' times in a day).',
          case when v_forever then now() end, null, null, null, now())
  on conflict (user_id) do update set level = excluded.level, blocked_until = excluded.blocked_until, forever = excluded.forever,
    reason = excluded.reason, reported_at = coalesce(excluded.reported_at, public.ai_safety.reported_at), decision = null,
    decided_at = null, decided_by = null, updated_at = now();
  if v_forever then
    insert into public.notifications (topic, title, body, link, audience, source, source_ref)
    values ('account', 'AI safety report', 'A student broke the AI tutor rules a third time. Decide: ban, block AI or lift.',
            jsonb_build_object('type', 'screen', 'target', '/admin/ai-safety'), 'staff', 'ai', 'ai-safety:' || p_uid || ':' || extract(epoch from now())::bigint)
    on conflict do nothing;
  end if;
  return jsonb_build_object('strikes', v_n, 'left', 0, 'blocked', true, 'level', v_level, 'until', v_until, 'forever', v_forever);
end;
$$;
revoke all on function private.ai_strike(uuid, text, text) from public, anon, authenticated;
grant execute on function private.ai_strike(uuid, text, text) to service_role;

-- A public wrapper the Edge Function can call with the service role (private schema is not exposed by the API).
create or replace function public.ai_strike(p_uid uuid, p_kind text, p_text text)
returns jsonb language sql security definer set search_path = '' as $$ select private.ai_strike(p_uid, p_kind, p_text) $$;
revoke all on function public.ai_strike(uuid, text, text) from public, anon, authenticated;
grant execute on function public.ai_strike(uuid, text, text) to service_role;

/** Is the AI blocked for this student? {blocked, until, forever, reason}. */
create or replace function public.ai_block_status(p_uid uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce((select jsonb_build_object('blocked', true, 'until', s.blocked_until, 'forever', s.forever, 'reason', s.reason, 'level', s.level)
                   from public.ai_safety s
                   where s.user_id = p_uid and (s.forever or s.blocked_until > now()) and coalesce(s.decision, '') <> 'lift'),
                  jsonb_build_object('blocked', false));
$$;
revoke all on function public.ai_block_status(uuid) from public, anon, authenticated;
grant execute on function public.ai_block_status(uuid) to service_role;

/** Admin list: students with strikes in the last 30 days or any block, newest first. */
create or replace function public.admin_ai_safety_list()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(r order by r.sort_at desc) from (
      select u.id as user_id, p.full_name, u.email, p.banned_at,
             s.level, s.blocked_until, s.forever, s.reason, s.reported_at, s.decision, s.decided_at,
             (select count(*) from public.ai_strikes k where k.user_id = u.id and k.at > now() - interval '30 days') as strikes_30d,
             (select jsonb_agg(jsonb_build_object('at', k.at, 'kind', k.kind, 'text', k.text) order by k.at desc)
                from (select * from public.ai_strikes k where k.user_id = u.id order by k.at desc limit 5) k) as recent,
             greatest(s.updated_at, (select max(k.at) from public.ai_strikes k where k.user_id = u.id)) as sort_at
      from auth.users u
      left join public.profiles p on p.id = u.id
      left join public.ai_safety s on s.user_id = u.id
      where s.user_id is not null or exists (select 1 from public.ai_strikes k where k.user_id = u.id and k.at > now() - interval '30 days')
      limit 300
    ) r), '[]');
end;
$$;

/** Admin decision on a student: lift the AI block, block the AI for good, or ban the account. */
create or replace function public.admin_ai_safety_decide(p_user uuid, p_decision text, p_note text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  if p_decision not in ('lift', 'block_ai', 'ban') then raise exception 'Bad decision'; end if;
  insert into public.ai_safety (user_id, level, blocked_until, forever, reason, decision, decided_at, decided_by, updated_at)
  values (p_user, 3, null, p_decision <> 'lift', coalesce(p_note, 'Decided by the admin'), p_decision, now(), (select auth.uid()), now())
  on conflict (user_id) do update set
    forever = (p_decision <> 'lift'),
    blocked_until = case when p_decision = 'lift' then null else public.ai_safety.blocked_until end,
    level = case when p_decision = 'lift' then 2 else public.ai_safety.level end,
    reason = case when p_decision = 'block_ai' then coalesce(p_note, 'The admin blocked the AI tutor for this account after repeated rule breaking.') else public.ai_safety.reason end,
    decision = p_decision, decided_at = now(), decided_by = (select auth.uid()), updated_at = now();
  if p_decision = 'ban' then
    perform public.admin_ban(p_user, true, coalesce(p_note, 'Repeated attempts to break the AI tutor''s rules or get private data.'), false);
  end if;
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), 'ai_safety.' || p_decision, 'ai_safety', p_user::text, jsonb_build_object('note', p_note));
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.admin_ai_safety_list(), public.admin_ai_safety_decide(uuid, text, text) from public, anon;
grant execute on function public.admin_ai_safety_list(), public.admin_ai_safety_decide(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------- A3: read a real lesson note (plan-safe)
/** The best-matching published note for a title, with its text only when the student's plan opens it. */
create or replace function public.ai_read_note(p_uid uuid, p_q text, p_subject smallint default null)
returns jsonb language sql stable security definer set search_path = '' as $$
  with q as (select lower(trim(regexp_replace(coalesce(p_q, ''), '\s+', ' ', 'g'))) as q),
  words as (select w from q, regexp_split_to_table(q.q, '[^a-z0-9]+') w where length(w) >= 3),
  hits as (
    select i.id, i.title, i.subtitle, i.body, i.subject_id, not (i.is_free or private.has_premium(p_uid)) as locked,
           (case when lower(i.title) = (select q from q) then 100 when lower(i.title) like '%' || (select q from q) || '%' then 20 else 0 end)
           + (select count(*) from words where lower(i.title) like '%' || w || '%') * 3 as rank,
           (select count(*) from words) as nwords,
           (select count(*) from words where lower(i.title) like '%' || w || '%') as nmatch
    from public.study_items i
    where i.kind = 'note' and i.status = 'published' and i.deleted_at is null and (p_subject is null or i.subject_id = p_subject))
  select coalesce((
    select jsonb_build_object('found', true, 'id', h.id, 'title', h.title, 'subtitle', h.subtitle, 'locked', h.locked,
                              'subject', (select s.name from public.subjects s where s.id = h.subject_id),
                              'body', case when h.locked then null else left(h.body, 12000) end)
    from hits h
    where h.rank >= 20 or (h.nwords > 0 and h.nmatch * 1.0 / h.nwords >= 0.7)
    order by h.rank desc limit 1), jsonb_build_object('found', false));
$$;
revoke all on function public.ai_read_note(uuid, text, smallint) from public, anon, authenticated;
grant execute on function public.ai_read_note(uuid, text, smallint) to service_role;

-- Reminders the AI sets are personal notifications (source 'ai', source_ref 'remind:…') with a future scheduled_at.
create index if not exists notifications_ai_reminders on public.notifications (user_id, scheduled_at) where source = 'ai' and status = 'scheduled';

-- ---------------------------------------------------------------- Me: stats from the server, so they show on every phone
create or replace function public.my_stats() returns jsonb language sql stable security definer set search_path to '' as $$
  with me as (select (select auth.uid()) as uid),
  t as (select count(*) as n, coalesce(sum(a.time_used_s), 0) as secs from public.attempts a, me where a.user_id = me.uid and a.status = 'submitted'),
  m as (select count(*) as n, coalesce(sum(extract(epoch from (e.finished_at - e.started_at))), 0)::bigint as secs
        from public.challenge_entries e, me where e.user_id = me.uid and e.status = 'finished' and e.finished_at is not null and e.started_at is not null)
  select jsonb_build_object('tests', (select n from t) + (select n from m), 'minutes', ((select secs from t) + (select secs from m)) / 60)
         || public.my_best_jamb();
$$;
revoke all on function public.my_stats() from public, anon;
grant execute on function public.my_stats() to authenticated;
