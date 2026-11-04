-- SolutionTee CBT · XP2 (owner, D-082; plan docs/plans/xp-streaks.md §3.5): the streak counts days with at least one
-- question (test, question of the day, challenge); streak freezes (bought with XP, used automatically), streak repair,
-- milestone bonuses with a celebration, and one call for the app's streak screens.

alter table public.profiles add column if not exists streak_freezes smallint not null default 0;
alter table public.profiles add column if not exists streak_seen text;

create table if not exists public.streak_saves (
  user_id uuid not null references public.profiles (id) on delete cascade,
  day date not null,
  kind text not null check (kind in ('freeze', 'repair')),
  created_at timestamptz not null default now(),
  primary key (user_id, day)
);
alter table public.streak_saves enable row level security;
create policy "own or staff" on public.streak_saves for select using (user_id = (select auth.uid()) or private.is_staff());
revoke all on public.streak_saves from anon;
revoke insert, update, delete on public.streak_saves from authenticated;

/** Lagos days that keep the streak: a finished test, a question of the day, a challenge, or a day saved by a freeze / repair. */
create or replace function private.practice_days(p_uid uuid)
returns table (day date) language sql stable security definer set search_path = '' as $$
  select (a.submitted_at at time zone 'Africa/Lagos')::date from public.attempts a
  where a.user_id = p_uid and a.status::text = 'submitted' and a.submitted_at is not null
  union
  select (q.answered_at at time zone 'Africa/Lagos')::date from public.qotd_answers q where q.user_id = p_uid
  union
  select (e.started_at at time zone 'Africa/Lagos')::date from public.challenge_entries e where e.user_id = p_uid
  union
  select s.day from public.streak_saves s where s.user_id = p_uid;
$$;

/** Days in a row ending on p_end (0 if p_end is not a practice day). */
create or replace function private.run_ending(p_uid uuid, p_end date)
returns integer language plpgsql stable security definer set search_path = '' as $$
declare v_days date[]; v_n integer := 0; v_d date := p_end;
begin
  select array_agg(day) into v_days from private.practice_days(p_uid) where day <= p_end and day > p_end - 4000;
  while v_d = any (coalesce(v_days, '{}')) loop
    v_n := v_n + 1;
    v_d := v_d - 1;
  end loop;
  return v_n;
end;
$$;

/** Milestone bonuses for the current run (once per milestone per run). */
create or replace function private.streak_check(p_uid uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare s jsonb := private.xp_settings(); v_cur integer; v_end date; v_start date; m record;
begin
  if not coalesce((s ->> 'enabled')::boolean, true) then return; end if;
  v_end := private.lagos_today();
  v_cur := private.run_ending(p_uid, v_end);
  if v_cur = 0 then return; end if;
  v_start := v_end - v_cur + 1;
  for m in select k::int as days, v::text::int as xp from jsonb_each(coalesce(s -> 'milestones', '{}')) e(k, v) where k::int <= v_cur order by k::int loop
    perform private.xp_add(p_uid, m.xp, 'earned', 'streak', m.days::text, 'streak:' || p_uid || ':' || v_start || ':' || m.days, false);
  end loop;
end;
$$;

create or replace function private.streak_on_practice()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform private.streak_check(new.user_id);
  return null;
end;
$$;
create trigger streak_on_attempt after insert or update of status on public.attempts
  for each row when (new.status = 'submitted') execute function private.streak_on_practice();
create trigger streak_on_qotd after insert on public.qotd_answers for each row execute function private.streak_on_practice();
create trigger streak_on_challenge after insert on public.challenge_entries for each row execute function private.streak_on_practice();

/** Every night (00:20 Lagos): a missed yesterday is saved by a freeze when the student holds one. */
create or replace function private.streak_freeze_job()
returns integer language plpgsql security definer set search_path = '' as $$
declare v_y date := private.lagos_today() - 1; r record; v_n integer := 0; v_len integer;
begin
  for r in select p.id from public.profiles p where p.streak_freezes > 0 and p.banned_at is null loop
    if not exists (select 1 from private.practice_days(r.id) d where d.day = v_y) then
      v_len := private.run_ending(r.id, v_y - 1);
      if v_len > 0 then
        insert into public.streak_saves (user_id, day, kind) values (r.id, v_y, 'freeze') on conflict do nothing;
        update public.profiles set streak_freezes = streak_freezes - 1 where id = r.id;
        insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
        values ('streak', 'Your streak freeze saved your streak', 'You missed yesterday, so a freeze kept your ' || (v_len + 1) || '-day streak. Practise today to keep it going.',
                'user', r.id, 'scheduled', now() + interval '7 hours', 'streak', jsonb_build_object('type', 'screen', 'target', '/me/streak'));
        v_n := v_n + 1;
      end if;
    end if;
  end loop;
  return v_n;
end;
$$;
select cron.schedule('streak-freezes', '20 23 * * *', $$select private.streak_freeze_job()$$);

/** Buy a streak freeze with XP (earned or bought). */
create or replace function public.streak_buy_freeze()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); s jsonb := private.xp_settings(); v_has integer;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if not coalesce((s ->> 'enabled')::boolean, true) then raise exception 'XP is paused right now.' using errcode = 'P0001'; end if;
  select streak_freezes into v_has from public.profiles where id = v_uid for update;
  if v_has >= coalesce((s ->> 'freeze_max')::int, 2) then raise exception 'You already hold the most freezes.' using errcode = 'P0001'; end if;
  perform private.xp_take(v_uid, coalesce((s ->> 'freeze_price')::int, 50), true, 'freeze', null, 'freeze:' || gen_random_uuid());
  update public.profiles set streak_freezes = streak_freezes + 1 where id = v_uid;
  return public.my_streak();
end;
$$;

/** Repair a streak lost yesterday (within the day after), for XP. */
create or replace function public.streak_repair()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); s jsonb := private.xp_settings(); v_y date := private.lagos_today() - 1;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if not coalesce((s ->> 'enabled')::boolean, true) or not coalesce((s ->> 'repair_on')::boolean, true) then
    raise exception 'Streak repair is not available.' using errcode = 'P0001';
  end if;
  if exists (select 1 from private.practice_days(v_uid) d where d.day = v_y) or private.run_ending(v_uid, v_y - 1) = 0 then
    raise exception 'There is no streak to repair.' using errcode = 'P0001';
  end if;
  perform private.xp_take(v_uid, coalesce((s ->> 'repair_price')::int, 200), true, 'repair', v_y::text, 'repair:' || v_uid || ':' || v_y);
  insert into public.streak_saves (user_id, day, kind) values (v_uid, v_y, 'repair') on conflict do nothing;
  perform private.streak_check(v_uid);
  return public.my_streak();
end;
$$;

/** The app's streak data: current and longest, this week (Mon–Sun), freezes, repair offer, milestones, a celebration
    to show once, and the daily XP claim. */
create or replace function public.my_streak()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); s jsonb := private.xp_settings(); st record; p public.profiles;
        v_today date := private.lagos_today(); v_mon date; v_cur integer; v_start date; v_lost integer; v_cel record;
begin
  if v_uid is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into st from private.streak(v_uid);
  select * into p from public.profiles where id = v_uid;
  v_mon := v_today - (extract(isodow from v_today)::int - 1);
  v_cur := st.current_days;
  v_start := (case when st.today_done then v_today else v_today - 1 end) - v_cur + 1;
  v_lost := case when not st.today_done and v_cur = 0 then private.run_ending(v_uid, v_today - 2) else 0 end;
  -- the highest milestone of this run not shown yet (streak_seen holds the last shown key of the run)
  select l.ref::int as days, l.amount as xp, l.key into v_cel from public.xp_ledger l
  where l.user_id = v_uid and l.reason = 'streak' and v_cur > 0 and l.key like 'streak:' || v_uid || ':' || v_start || ':%'
    and l.ref::int > case when p.streak_seen like 'streak:' || v_uid || ':' || v_start || ':%' then split_part(p.streak_seen, ':', 4)::int else 0 end
  order by l.ref::int desc limit 1;
  return jsonb_build_object(
    'current', v_cur, 'longest', st.longest_days, 'today_done', st.today_done,
    'week', (select jsonb_agg(jsonb_build_object('day', d::date, 'done', exists (select 1 from private.practice_days(v_uid) x where x.day = d::date
                                and not exists (select 1 from public.streak_saves z where z.user_id = v_uid and z.day = d::date)),
                              'saved', (select z.kind from public.streak_saves z where z.user_id = v_uid and z.day = d::date),
                              'today', d::date = v_today) order by d)
             from generate_series(v_mon, v_mon + 6, interval '1 day') d),
    'freezes', p.streak_freezes, 'freeze_max', coalesce((s ->> 'freeze_max')::int, 2), 'freeze_price', coalesce((s ->> 'freeze_price')::int, 50),
    'repair', case when coalesce((s ->> 'repair_on')::boolean, true) and v_lost > 0
                   then jsonb_build_object('lost', v_lost, 'price', coalesce((s ->> 'repair_price')::int, 200)) end,
    'milestones', coalesce((select jsonb_agg(jsonb_build_object('days', k::int, 'xp', v::text::int, 'reached', v_cur >= k::int) order by k::int)
                            from jsonb_each(coalesce(s -> 'milestones', '{}')) e(k, v)), '[]'::jsonb),
    'next', (select jsonb_build_object('days', k::int, 'xp', v::text::int, 'left', k::int - v_cur)
             from jsonb_each(coalesce(s -> 'milestones', '{}')) e(k, v) where k::int > v_cur order by k::int limit 1),
    'celebrate', case when v_cel.key is not null then jsonb_build_object('days', v_cel.days, 'xp', v_cel.xp, 'key', v_cel.key) end,
    'xp', jsonb_build_object('enabled', coalesce((s ->> 'enabled')::boolean, true), 'balance', p.xp_earned + p.xp_bought,
                             'daily_claim', coalesce((s ->> 'daily_claim')::int, 10),
                             'claimed_today', exists (select 1 from public.xp_ledger where key = 'daily:' || v_uid || ':' || v_today)),
    'name', p.full_name, 'avatar', p.avatar_path);
end;
$$;

/** The app showed this milestone celebration. */
create or replace function public.streak_seen(p_key text)
returns void language sql security definer set search_path = '' as $$
  update public.profiles set streak_seen = left(p_key, 200) where id = (select auth.uid());
$$;

-- The dashboard and badges use the same streak (now including the question of the day, challenges and saved days).

revoke execute on function private.run_ending(uuid, date), private.streak_check(uuid), private.streak_freeze_job() from public, anon, authenticated;
revoke execute on function public.streak_buy_freeze(), public.streak_repair(), public.my_streak(), public.streak_seen(text) from public, anon;
grant execute on function public.streak_buy_freeze(), public.streak_repair(), public.my_streak(), public.streak_seen(text) to authenticated;
