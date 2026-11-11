-- Leaderboards v2 (B9, D-143): a Challenges board, top-10 weekly and monthly rewards, and past winners.

-- Top of a JAMB board in a time window (national), with the same fair rules as leaderboard_for. For the reward job.
create or replace function private.lb_top_jamb(p_from timestamptz, p_to timestamptz, p_limit integer default 10)
returns table (rnk integer, user_id uuid, score integer)
language sql stable security definer set search_path = '' as $$
  with cfg as (select private.lb_cfg() c),
  counted as (
    select x.* from private.lb_entries_w('JAMB', p_from, p_to, null) x
    where x.review is distinct from 'rejected' and (x.held is null or x.review = 'ok')
  ), best as (
    select distinct on (c.user_id) c.user_id, c.score, c.time_s, c.submitted_at, count(*) over (partition by c.user_id) mocks
    from counted c order by c.user_id, c.score desc, c.time_s asc, c.submitted_at asc
  )
  select (row_number() over (order by b.score desc, b.time_s asc, b.submitted_at asc))::int, b.user_id, b.score
  from best b cross join cfg
  join public.profiles p on p.id = b.user_id
  where b.mocks >= greatest(coalesce((cfg.c ->> 'min_mocks')::int, 1), 1) and not p.hide_on_leaderboard and p.banned_at is null
    and (coalesce((cfg.c ->> 'include_staff')::boolean, false) or not exists (select 1 from public.staff st where st.user_id = b.user_id))
  order by 1 limit p_limit;
$$;

-- Challenge points in a window: the scores of every finished challenge, added up (disqualified runs do not count).
create or replace function private.lb_top_challenges(p_from timestamptz, p_to timestamptz, p_limit integer default 50)
returns table (rnk integer, user_id uuid, score integer, played integer)
language sql stable security definer set search_path = '' as $$
  with pts as (
    select e.user_id, sum(e.score)::int score, count(*)::int played, max(e.finished_at) last_at
    from public.challenge_entries e
    where e.status = 'finished' and e.review is distinct from 'dq' and e.finished_at >= p_from and e.finished_at < p_to
    group by e.user_id
  )
  select (row_number() over (order by t.score desc, t.last_at asc))::int, t.user_id, t.score, t.played
  from pts t join public.profiles p on p.id = t.user_id
  where t.score > 0 and not p.hide_on_leaderboard and p.banned_at is null
    and (coalesce((private.lb_cfg() ->> 'include_staff')::boolean, false) or not exists (select 1 from public.staff st where st.user_id = t.user_id))
  order by 1 limit p_limit;
$$;

-- The Challenges board for the app (same shape as leaderboard_for: top, me).
create or replace function public.leaderboard_challenges(p_period text default 'week', p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_set jsonb := private.lb_cfg();
  v_period text := case when p_period in ('week', 'month', 'year', 'all') then p_period else 'week' end;
  v_from timestamptz; v_to timestamptz; v_label text; v_names text := coalesce(v_set ->> 'names', 'first-initial');
  v_top jsonb; v_me jsonb;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if not coalesce((v_set ->> 'on')::boolean, false) then return jsonb_build_object('on', false); end if;
  select w.from_ts, w.to_ts, w.label into v_from, v_to, v_label from private.lb_window(v_period, least(greatest(coalesce(p_offset, 0), 0), 52)) w;
  with r as (select * from private.lb_top_challenges(v_from, v_to, 100000))
  select
    (select coalesce(jsonb_agg(jsonb_build_object('rank', r.rnk, 'name', private.lb_name(p.full_name, v_names), 'state', p.state, 'score', r.score,
            'played', r.played, 'photo', case when p.show_photo_on_leaderboard and coalesce(p.avatar_path, '') <> '' then p.avatar_path end,
            'me', r.user_id = v_uid) order by r.rnk), '[]'::jsonb)
     from r join public.profiles p on p.id = r.user_id where r.rnk <= 50),
    (select jsonb_build_object('rank', r.rnk, 'score', r.score, 'mocks', r.played,
            'ahead', (select a.score - r.score from r a where a.rnk = r.rnk - 1)) from r where r.user_id = v_uid)
  into v_top, v_me;
  return jsonb_build_object('on', true, 'board', 'challenges', 'period', v_period, 'offset', coalesce(p_offset, 0), 'label', v_label,
    'current', coalesce(p_offset, 0) = 0 or v_period = 'all', 'top', v_top,
    'me', coalesce(v_me, jsonb_build_object('rank', null, 'mocks', 0, 'needs', 1)));
end $$;

create table public.lb_winners (
  id bigint generated always as identity primary key,
  board text not null check (board in ('jamb', 'challenges')),
  period text not null check (period in ('week', 'month')),
  period_start date not null,
  label text not null,
  rank smallint not null check (rank between 1 and 10),
  user_id uuid not null references public.profiles(id) on delete cascade,
  score integer not null,
  xp_given integer not null default 0,
  days_given integer not null default 0,
  created_at timestamptz not null default now(),
  unique (board, period, period_start, rank)
);
alter table public.lb_winners enable row level security;
create policy "staff read" on public.lb_winners for select to authenticated using (private.is_staff() or user_id = (select auth.uid()));
grant select on public.lb_winners to authenticated;

-- Past winners for the app: the last closed week and month of each board (short names only).
create or replace function public.leaderboard_winners()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(g order by g ->> 'period_start' desc, g ->> 'board'), '[]'::jsonb) from (
    select jsonb_build_object('board', w.board, 'period', w.period, 'period_start', w.period_start, 'label', w.label,
      'winners', jsonb_agg(jsonb_build_object('rank', w.rank, 'name', private.lb_name(p.full_name, coalesce(private.lb_cfg() ->> 'names', 'first-initial')),
                 'score', w.score, 'xp', w.xp_given, 'days', w.days_given, 'me', w.user_id = (select auth.uid())) order by w.rank)) g
    from public.lb_winners w join public.profiles p on p.id = w.user_id
    where (select auth.uid()) is not null
      and (w.board, w.period, w.period_start) in (select x.board, x.period, max(x.period_start) from public.lb_winners x group by 1, 2)
    group by w.board, w.period, w.period_start, w.label
  ) t;
$$;

alter table public.notifications drop constraint if exists notifications_source_check;
alter table public.notifications add constraint notifications_source_check check (source = any (array['admin','news','year','streak','premium',
  'challenge','referral','ban','plan','nudge','ai','leaderboard','badge']));

-- Pays the top 10 of the last closed week or month, two days after it closed (time to review held runs). Runs every
-- day; each place is paid once. Rewards: app_settings.leaderboard.rewards = {on, boards: {jamb, challenges},
-- week: [{xp, days} x10], month: [{xp, days} x10]}.
create or replace function private.lb_pay(p_period text) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  cfg jsonb := coalesce(private.lb_cfg() -> 'rewards', '{}'::jsonb);
  w record; r record; v_board text; v_n integer := 0; v_xp integer; v_days integer; v_place jsonb; v_key text;
begin
  if not coalesce((cfg ->> 'on')::boolean, false) or p_period not in ('week', 'month') then return 0; end if;
  select * into w from private.lb_window(p_period, 1);
  if now() < w.to_ts + interval '2 days' then return 0; end if;
  foreach v_board in array array['jamb', 'challenges'] loop
    continue when not coalesce((cfg -> 'boards' ->> v_board)::boolean, true);
    continue when exists (select 1 from public.lb_winners x where x.board = v_board and x.period = p_period
                          and x.period_start = (w.from_ts at time zone 'Africa/Lagos')::date);
    for r in select * from (
      select t.rnk, t.user_id, t.score from private.lb_top_jamb(w.from_ts, w.to_ts, 10) t where v_board = 'jamb'
      union all
      select t.rnk, t.user_id, t.score from private.lb_top_challenges(w.from_ts, w.to_ts, 10) t where v_board = 'challenges') q
    order by rnk loop
      v_place := coalesce(cfg -> p_period -> (r.rnk - 1), '{}'::jsonb);
      v_key := 'lb:' || v_board || ':' || p_period || ':' || (w.from_ts at time zone 'Africa/Lagos')::date || ':' || r.rnk;
      v_xp := private.xp_add(r.user_id, least(coalesce((v_place ->> 'xp')::int, 0), 10000), 'earned', 'leaderboard', v_key, v_key, false);
      v_days := 0;
      if coalesce((v_place ->> 'days')::int, 0) > 0 then
        perform private.grant_plan(r.user_id, 1::smallint, 'prize', v_key, least((v_place ->> 'days')::int, 90), w.label || ' leaderboard #' || r.rnk);
        v_days := least((v_place ->> 'days')::int, 90);
      end if;
      insert into public.lb_winners (board, period, period_start, label, rank, user_id, score, xp_given, days_given)
      values (v_board, p_period, (w.from_ts at time zone 'Africa/Lagos')::date, w.label, r.rnk, r.user_id, r.score, coalesce(v_xp, 0), v_days)
      on conflict do nothing;
      if coalesce(v_xp, 0) > 0 or v_days > 0 then
        insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, source_ref, link)
        values ('challenges', 'You are #' || r.rnk || ' on the ' || case v_board when 'jamb' then 'JAMB' else 'Challenges' end || ' leaderboard',
                w.label || ': ' || concat_ws(' and ', case when v_xp > 0 then '+' || v_xp || ' XP' end, case when v_days > 0 then v_days || ' days of Premium' end) || '. Well done!',
                'user', r.user_id, 'scheduled', now(), 'leaderboard', v_key, jsonb_build_object('type', 'screen', 'target', '/test/leaderboard'));
      end if;
      v_n := v_n + 1;
    end loop;
  end loop;
  return v_n;
end $$;

revoke all on function private.lb_top_jamb(timestamptz, timestamptz, integer), private.lb_top_challenges(timestamptz, timestamptz, integer),
  private.lb_pay(text) from public, anon, authenticated;
revoke all on function public.leaderboard_challenges(text, integer), public.leaderboard_winners() from public, anon;
grant execute on function public.leaderboard_challenges(text, integer), public.leaderboard_winners() to authenticated;

-- Reward settings start switched off, with sample XP amounts for the owner to change.
update public.app_settings set value = value || jsonb_build_object('rewards', jsonb_build_object(
  'on', false, 'boards', jsonb_build_object('jamb', true, 'challenges', true),
  'week', '[{"xp":200},{"xp":150},{"xp":120},{"xp":100},{"xp":80},{"xp":60},{"xp":50},{"xp":40},{"xp":30},{"xp":20}]'::jsonb,
  'month', '[{"xp":1000,"days":7},{"xp":750,"days":3},{"xp":500,"days":1},{"xp":400},{"xp":300},{"xp":250},{"xp":200},{"xp":150},{"xp":100},{"xp":50}]'::jsonb))
where key = 'leaderboard' and not value ? 'rewards';

select cron.schedule('leaderboard-rewards', '20 6 * * *', $c$select private.lb_pay('week'); select private.lb_pay('month');$c$);

