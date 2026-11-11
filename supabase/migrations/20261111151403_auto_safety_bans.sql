-- Automatic safety bans (B11, D-145). Risk points from things the server already knows, a warning email first,
-- then a ban at the admin's limit; one kind of flag alone never bans; every ban can be appealed. Off until the
-- admin turns it on. Daily alert email to admins: bans, fraud, payment problems, payouts waiting.
create table public.risk_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('shared_phone', 'many_accounts', 'second_account', 'phone_banned', 'fair_play',
                                     'challenge_dq', 'referral_abuse', 'payment_abuse', 'reports', 'ai_strike')),
  points smallint not null check (points between 0 and 100),
  detail text,
  ref text not null,
  created_at timestamptz not null default now(),
  dismissed_at timestamptz,
  dismissed_by uuid,
  unique (kind, ref)
);
create index risk_events_user_idx on public.risk_events (user_id, created_at desc) where dismissed_at is null;

create table public.auto_safety (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  score integer not null default 0,
  kinds smallint not null default 0,
  warned_at timestamptz,
  banned_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.risk_events enable row level security;
alter table public.auto_safety enable row level security;
create policy "staff read" on public.risk_events for select to authenticated using (private.is_staff());
create policy "staff read" on public.auto_safety for select to authenticated using (private.is_staff());
grant select on public.risk_events, public.auto_safety to authenticated;

insert into public.app_settings (key, value, is_public) values ('auto_safety', jsonb_build_object(
  'on', false, 'warn', 40, 'ban', 80, 'alerts', true,
  'points', jsonb_build_object('shared_phone', 20, 'many_accounts', 30, 'second_account', 15, 'phone_banned', 40, 'fair_play', 15,
                               'challenge_dq', 20, 'referral_abuse', 15, 'payment_abuse', 25, 'reports', 5, 'ai_strike', 10)), false)
on conflict (key) do nothing;

-- Collects new risk events from the existing records (each event once).
create or replace function private.risk_collect() returns integer
language plpgsql security definer set search_path = '' as $$
declare pts jsonb := coalesce((select s.value -> 'points' from public.app_settings s where s.key = 'auto_safety'), '{}'::jsonb);
        v_n integer := 0; c integer;
  function_pts text;
begin
  -- Two or more accounts on one phone (not allowed by staff); 3 or more is "many accounts".
  insert into public.risk_events (user_id, kind, points, detail, ref)
  select d.user_id, 'shared_phone', coalesce((pts ->> 'shared_phone')::int, 20), 'Phone used by ' || g.n || ' accounts', 'shared:' || d.device_hash || ':' || d.user_id
  from public.device_accounts d
  join (select device_hash, count(distinct user_id) n from public.device_accounts group by 1 having count(distinct user_id) >= 2) g on g.device_hash = d.device_hash
  where not coalesce(d.allowed, false)
  on conflict do nothing;
  get diagnostics c = row_count; v_n := v_n + c;
  insert into public.risk_events (user_id, kind, points, detail, ref)
  select d.user_id, 'many_accounts', coalesce((pts ->> 'many_accounts')::int, 30), 'Phone used by ' || g.n || ' accounts', 'many:' || d.device_hash || ':' || d.user_id
  from public.device_accounts d
  join (select device_hash, count(distinct user_id) n from public.device_accounts group by 1 having count(distinct user_id) >= 3) g on g.device_hash = d.device_hash
  where not coalesce(d.allowed, false)
  on conflict do nothing;
  get diagnostics c = row_count; v_n := v_n + c;
  insert into public.risk_events (user_id, kind, points, detail, ref)
  select e.user_id, case e.kind when 'phone_banned' then 'phone_banned' else 'second_account' end,
         coalesce((pts ->> case e.kind when 'phone_banned' then 'phone_banned' else 'second_account' end)::int, 15),
         replace(e.kind, '_', ' '), 'dev:' || e.id
  from public.device_events e
  where e.user_id is not null and e.kind in ('second_account', 'phone_banned') and e.at > now() - interval '90 days'
  on conflict do nothing;
  get diagnostics c = row_count; v_n := v_n + c;
  insert into public.risk_events (user_id, kind, points, detail, ref)
  select a.user_id, 'fair_play', coalesce((pts ->> 'fair_play')::int, 15), 'Test risk ' || a.risk || '/100: ' || coalesce(a.fair ->> 'why', ''), 'att:' || a.id
  from public.attempts a
  where a.risk >= 70 and a.submitted_at > now() - interval '90 days'
    and not exists (select 1 from public.leaderboard_reviews r where r.attempt_id = a.id and r.decision = 'ok')
  on conflict do nothing;
  get diagnostics c = row_count; v_n := v_n + c;
  insert into public.risk_events (user_id, kind, points, detail, ref)
  select e.user_id, 'challenge_dq', coalesce((pts ->> 'challenge_dq')::int, 20), coalesce('Disqualified: ' || e.dq_reason, 'Disqualified in a challenge'), 'dq:' || e.id
  from public.challenge_entries e
  where (e.review = 'dq' or e.status = 'disqualified') and coalesce(e.finished_at, e.started_at) > now() - interval '90 days'
  on conflict do nothing;
  get diagnostics c = row_count; v_n := v_n + c;
  insert into public.risk_events (user_id, kind, points, detail, ref)
  select r.referrer, 'referral_abuse', coalesce((pts ->> 'referral_abuse')::int, 15), coalesce('Invite blocked: ' || r.reason, 'Invite blocked'), 'ref:' || r.id
  from public.referrals r
  where r.status = 'blocked' and r.created_at > now() - interval '90 days'
  on conflict do nothing;
  get diagnostics c = row_count; v_n := v_n + c;
  insert into public.risk_events (user_id, kind, points, detail, ref)
  select p.user_id, 'payment_abuse', coalesce((pts ->> 'payment_abuse')::int, 25), 'Payment refunded after Premium was given', 'pay:' || p.id
  from public.payments p
  where p.refunded_at is not null and p.entitlement_id is not null and p.refunded_at > now() - interval '90 days'
  on conflict do nothing;
  get diagnostics c = row_count; v_n := v_n + c;
  insert into public.risk_events (user_id, kind, points, detail, ref)
  select c2.user_id, 'reports', coalesce((pts ->> 'reports')::int, 5), 'News comment hidden (' || c2.hidden_reason || ')', 'nc:' || c2.id
  from public.news_comments c2
  where c2.hidden_at is not null and c2.created_at > now() - interval '90 days'
  on conflict do nothing;
  get diagnostics c = row_count; v_n := v_n + c;
  insert into public.risk_events (user_id, kind, points, detail, ref)
  select s.user_id, 'ai_strike', coalesce((pts ->> 'ai_strike')::int, 10), 'AI tutor rule broken (' || s.kind || ')', 'ai:' || s.id
  from public.ai_strikes s
  where s.at > now() - interval '90 days'
  on conflict do nothing;
  get diagnostics c = row_count; v_n := v_n + c;
  return v_n;
end $$;

-- Hourly: collect, score (last 90 days, dismissed points left out), warn, then ban. Off until switched on.
create or replace function private.auto_safety_job() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  cfg jsonb := coalesce((select s.value from public.app_settings s where s.key = 'auto_safety'), '{}'::jsonb);
  v_warn integer := greatest(coalesce((cfg ->> 'warn')::int, 40), 1);
  v_ban integer := greatest(coalesce((cfg ->> 'ban')::int, 80), 2);
  v_new integer; v_warned integer := 0; v_banned integer := 0; r record; v_why text;
begin
  if not coalesce((cfg ->> 'on')::boolean, false) then return jsonb_build_object('on', false); end if;
  v_new := private.risk_collect();
  insert into public.auto_safety (user_id, score, kinds, updated_at)
  select e.user_id, sum(e.points), count(distinct e.kind), now()
  from public.risk_events e
  where e.dismissed_at is null and e.created_at > now() - interval '90 days'
  group by e.user_id
  on conflict (user_id) do update set score = excluded.score, kinds = excluded.kinds, updated_at = now();
  -- Points that faded away.
  update public.auto_safety a set score = 0, kinds = 0, updated_at = now()
  where a.score > 0 and not exists (select 1 from public.risk_events e where e.user_id = a.user_id and e.dismissed_at is null and e.created_at > now() - interval '90 days');

  for r in select a.*, p.banned_at as profile_banned from public.auto_safety a join public.profiles p on p.id = a.user_id
           where a.score >= v_warn and p.banned_at is null and not exists (select 1 from public.staff s where s.user_id = a.user_id) loop
    if r.warned_at is null or r.warned_at < now() - interval '30 days' then
      perform private.queue_email(r.user_id, 'safety_warning', jsonb_build_object('reasons',
        (select jsonb_agg(distinct e.kind) from public.risk_events e where e.user_id = r.user_id and e.dismissed_at is null and e.created_at > now() - interval '90 days')));
      update public.auto_safety set warned_at = now() where user_id = r.user_id;
      v_warned := v_warned + 1;
    elsif r.score >= v_ban and r.kinds >= 2 and r.warned_at < now() - interval '24 hours' then
      select string_agg(distinct replace(e.kind, '_', ' '), ', ') into v_why
      from public.risk_events e where e.user_id = r.user_id and e.dismissed_at is null and e.created_at > now() - interval '90 days';
      update public.profiles set banned_at = now(), ban_reason = left('Automatic safety check: ' || v_why || '. You can appeal in the app.', 500)
      where id = r.user_id and banned_at is null;
      update public.auto_safety set banned_at = now() where user_id = r.user_id;
      v_banned := v_banned + 1;
    end if;
  end loop;
  return jsonb_build_object('on', true, 'new_events', v_new, 'warned', v_warned, 'banned', v_banned);
end $$;

-- Daily email to super admins and admins when there is something to look at.
create or replace function private.admin_alerts_job() returns integer
language plpgsql security definer set search_path = '' as $$
declare d jsonb; v_n integer := 0; s record;
begin
  if not coalesce((select (x.value ->> 'alerts')::boolean from public.app_settings x where x.key = 'auto_safety'), true) then return 0; end if;
  d := jsonb_build_object(
    'auto_bans', (select count(*) from public.auto_safety a where a.banned_at > now() - interval '24 hours'),
    'warnings', (select count(*) from public.auto_safety a where a.warned_at > now() - interval '24 hours'),
    'second_accounts', (select count(*) from public.device_events e where e.kind = 'second_account' and e.at > now() - interval '24 hours'),
    'new_risk', (select count(*) from public.risk_events e where e.created_at > now() - interval '24 hours'),
    'stuck_payments', (select count(*) from public.payments p where p.status = 'pending' and p.live
                         and p.created_at between now() - interval '24 hours' and now() - interval '1 hour'),
    'payouts_waiting', (select count(*) from public.prize_claims c where c.status not in ('paid', 'rejected'))
                       + (select count(*) from public.referral_rewards r where r.status = 'claimed'),
    'appeals_waiting', (select count(*) from public.ban_appeals a where a.status = 'pending'),
    'reported_comments', (select count(*) from public.news_comments c where c.reports > 0 and c.reviewed_at is null));
  if (select sum(v::int) from jsonb_each_text(d) x(k, v) where k <> 'new_risk') = 0 then return 0; end if;
  for s in select st.user_id from public.staff st where st.role in ('super_admin', 'admin') loop
    if not exists (select 1 from private.email_outbox o where o.user_id = s.user_id and o.kind = 'admin_alert' and o.created_at > now() - interval '20 hours') then
      insert into private.email_outbox (user_id, kind, data) values (s.user_id, 'admin_alert', d);
      v_n := v_n + 1;
    end if;
  end loop;
  return v_n;
end $$;

-- Admin page: students with points, highest first, with their events.
create or replace function public.admin_safety_list(p_limit integer default 100) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x order by (x ->> 'score')::int desc), '[]'::jsonb) from (
    select jsonb_build_object('user_id', a.user_id, 'name', coalesce(p.full_name, 'Student'), 'score', a.score, 'kinds', a.kinds,
      'warned_at', a.warned_at, 'banned_at', p.banned_at, 'auto_banned', a.banned_at,
      'events', (select coalesce(jsonb_agg(jsonb_build_object('kind', e.kind, 'points', e.points, 'detail', e.detail, 'at', e.created_at) order by e.created_at desc), '[]'::jsonb)
                 from (select * from public.risk_events e2 where e2.user_id = a.user_id and e2.dismissed_at is null and e2.created_at > now() - interval '90 days'
                       order by e2.created_at desc limit 12) e)) x
    from public.auto_safety a join public.profiles p on p.id = a.user_id
    where private.is_staff() and a.score > 0
    order by a.score desc limit p_limit) t;
$$;

-- Admin: clear a student's points (they were checked and are fine); the events stay for the record.
create or replace function public.admin_safety_clear(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.can_edit(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'not_allowed' using errcode = '42501'; end if;
  update public.risk_events set dismissed_at = now(), dismissed_by = (select auth.uid()) where user_id = p_user and dismissed_at is null;
  update public.auto_safety set score = 0, kinds = 0, warned_at = null, updated_at = now() where user_id = p_user;
end $$;

-- Admin: run a check now (collects and scores; warns and bans only when switched on).
create or replace function public.admin_safety_run() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v integer;
begin
  if not private.can_edit(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'not_allowed' using errcode = '42501'; end if;
  if coalesce((select (s.value ->> 'on')::boolean from public.app_settings s where s.key = 'auto_safety'), false) then
    return private.auto_safety_job();
  end if;
  v := private.risk_collect();
  insert into public.auto_safety (user_id, score, kinds, updated_at)
  select e.user_id, sum(e.points), count(distinct e.kind), now() from public.risk_events e
  where e.dismissed_at is null and e.created_at > now() - interval '90 days' group by e.user_id
  on conflict (user_id) do update set score = excluded.score, kinds = excluded.kinds, updated_at = now();
  return jsonb_build_object('on', false, 'new_events', v);
end $$;

revoke all on function private.risk_collect(), private.auto_safety_job(), private.admin_alerts_job() from public, anon, authenticated;
revoke all on function public.admin_safety_list(integer), public.admin_safety_clear(uuid), public.admin_safety_run() from public, anon;
grant execute on function public.admin_safety_list(integer), public.admin_safety_clear(uuid), public.admin_safety_run() to authenticated;

select cron.schedule('auto-safety', '17 * * * *', 'select private.auto_safety_job()');
select cron.schedule('admin-alerts', '5 6 * * *', 'select private.admin_alerts_job()');

