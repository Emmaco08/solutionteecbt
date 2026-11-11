-- Badges v2 (B8, D-142): admin-made badges with bronze, silver, gold and diamond levels and rewards per level.
create table public.badges (
  id bigint generated always as identity primary key,
  key text not null unique check (key ~ '^[a-z0-9_]{2,40}$'),
  name text not null check (char_length(name) between 2 and 40),
  description text not null check (char_length(description) between 5 and 160),
  icon text not null default 'medal' check (icon ~ '^[a-zA-Z]{2,30}$'),
  metric text not null check (metric in ('streak','tests','correct','questions','jamb_best','full_mocks','perfect','score70',
    'night','early','weekend','speed','days','hours','topic_tests','subject_tests','quick_tests','custom_tests',
    'lessons','videos','notes','novels','ai_chats','challenges','podium','referrals','qotd','xp','comments','likes')),
  -- {"bronze": n, "silver": n, "gold": n, "diamond": n}, each level higher than the one before
  targets jsonb not null,
  -- {"bronze": {"xp": 20, "days": 0}, ...}
  rewards jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  sort integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((targets->>'bronze')::numeric > 0 and (targets->>'silver')::numeric > (targets->>'bronze')::numeric
     and (targets->>'gold')::numeric > (targets->>'silver')::numeric and (targets->>'diamond')::numeric > (targets->>'gold')::numeric)
);
create table public.user_badges (
  user_id uuid not null references public.profiles(id) on delete cascade,
  badge_id bigint not null references public.badges(id) on delete cascade,
  tier smallint not null check (tier between 1 and 4),
  reached_at timestamptz not null default now(),
  xp_given integer not null default 0,
  days_given integer not null default 0,
  -- true for levels found already reached when badges v2 started (no reward, no celebration)
  backfill boolean not null default false,
  seen_at timestamptz,
  primary key (user_id, badge_id, tier)
);
create index user_badges_unseen_idx on public.user_badges (user_id) where seen_at is null;
create index user_badges_badge_idx on public.user_badges (badge_id, tier);

alter table public.badges enable row level security;
alter table public.user_badges enable row level security;
create policy "read active" on public.badges for select to authenticated using (active or private.is_staff());
create policy "admins edit" on public.badges for all to authenticated
  using (private.can_edit(array['super_admin','admin']::staff_role[])) with check (private.can_edit(array['super_admin','admin']::staff_role[]));
create policy "own or staff read" on public.user_badges for select to authenticated using (user_id = (select auth.uid()) or private.is_staff());
grant select on public.badges, public.user_badges to authenticated;
grant insert, update, delete on public.badges to authenticated;
create trigger badges_audit after insert or update or delete on public.badges for each row execute function private.audit_row();
create trigger badges_touch before update on public.badges for each row execute function private.touch_updated_at();

insert into public.app_settings (key, value, is_public) values ('badges', jsonb_build_object('on', true, 'since', now()), true)
on conflict (key) do nothing;

-- Every metric a badge can count, for one student, worked out on the server from their own records.
create or replace function private.badge_metrics(p_uid uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare s record; a jsonb; st jsonb; o jsonb;
begin
  select * into s from private.streak(p_uid);
  select jsonb_build_object(
    'tests', count(*),
    'correct', coalesce(sum((x.sc->>'correct')::int), 0),
    'questions', coalesce(sum((x.sc->>'answered')::int), 0),
    'jamb_best', coalesce(max((x.sc->>'total')::int) filter (where x.mode = 'full' and x.sc->>'max' = '400'), 0),
    'full_mocks', count(*) filter (where x.mode = 'full' and (x.sc->>'answered')::int >= 0.9 * nullif((x.sc->>'questions')::int, 0)),
    'perfect', count(*) filter (where (x.sc->>'answered')::int >= 10 and (x.sc->>'correct')::int = (x.sc->>'questions')::int),
    'score70', count(*) filter (where (x.sc->>'answered')::int >= 10 and (x.sc->>'correct')::numeric >= 0.7 * nullif((x.sc->>'questions')::int, 0)),
    'night', count(*) filter (where x.h >= 22 or x.h < 4),
    'early', count(*) filter (where x.h >= 5 and x.h < 8),
    'weekend', count(*) filter (where x.dow in (0, 6)),
    'speed', count(*) filter (where (x.sc->>'answered')::int >= 20 and x.time_used_s > 0
                and x.time_used_s::numeric / nullif((x.sc->>'answered')::int, 0) < 30
                and (x.sc->>'correct')::numeric / nullif((x.sc->>'answered')::int, 0) >= 0.7),
    'days', count(distinct x.d),
    'hours', coalesce(sum(x.time_used_s), 0) / 3600,
    'topic_tests', count(*) filter (where x.mode = 'topic'),
    'subject_tests', count(*) filter (where x.mode = 'subject'),
    'quick_tests', count(*) filter (where x.mode = 'quick'),
    'custom_tests', count(*) filter (where x.mode = 'custom'))
  into a
  from (select t.mode, t.server_score sc, t.time_used_s,
               extract(hour from t.submitted_at at time zone 'Africa/Lagos')::int h,
               extract(dow from t.submitted_at at time zone 'Africa/Lagos')::int dow,
               (t.submitted_at at time zone 'Africa/Lagos')::date d
        from public.attempts t
        where t.user_id = p_uid and t.status::text = 'submitted' and t.server_score is not null) x;
  select jsonb_build_object(
    'lessons', count(*),
    'videos', count(*) filter (where i.kind::text in ('video_solution', 'lesson')),
    'notes', count(*) filter (where i.kind::text = 'note'),
    'novels', count(*) filter (where i.kind::text = 'novel'))
  into st
  from public.study_progress p left join public.study_items i on i.id = p.item_id
  where p.user_id = p_uid and p.progress >= 0.9;
  select jsonb_build_object(
    'streak', coalesce(s.longest_days, 0),
    'ai_chats', (select count(*) from public.ai_chats c where c.user_id = p_uid and c.deleted_at is null),
    'challenges', (select count(*) from public.challenge_entries e where e.user_id = p_uid and e.status = 'finished'),
    'podium', (select count(*) from public.challenge_entries e where e.user_id = p_uid and e.status = 'finished' and e.rank between 1 and 3),
    'referrals', (select count(*) from public.referrals r where r.referrer = p_uid and r.status = 'counted'),
    'qotd', (select count(*) from public.qotd_answers q where q.user_id = p_uid and q.correct),
    'xp', (select coalesce(pr.xp_earned, 0) from public.profiles pr where pr.id = p_uid),
    'comments', (select count(*) from public.news_comments c where c.user_id = p_uid and c.hidden_at is null),
    'likes', (select count(*) from public.news_likes l where l.user_id = p_uid))
  into o;
  return a || st || o;
end $$;

-- Checks every active badge for the signed-in student: new levels are recorded and rewarded once (XP and free
-- Premium days; never for banned students). Levels already reached when badges v2 started are recorded without a
-- reward or celebration. Returns every badge with its level and progress, and the levels won but not yet shown.
create or replace function public.badges_check() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  m jsonb; b record; v numeric; t int; lvl text; r jsonb; xp int; days int;
  cfg jsonb := coalesce((select value from public.app_settings where key = 'badges'), '{}'::jsonb);
  v_backfill boolean;
  v_banned boolean;
  names text[] := array['bronze', 'silver', 'gold', 'diamond'];
  out_badges jsonb := '[]'::jsonb;
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  if cfg ->> 'on' = 'false' then return jsonb_build_object('on', false, 'badges', '[]'::jsonb, 'won', '[]'::jsonb); end if;
  perform pg_advisory_xact_lock(hashtextextended('badges:' || v_uid::text, 0));
  m := private.badge_metrics(v_uid);
  v_banned := private.is_banned(v_uid);
  -- First check of an account made before badges v2 started: what it already reached is recorded quietly.
  v_backfill := not exists (select 1 from public.user_badges u where u.user_id = v_uid)
    and (select pr.created_at from public.profiles pr where pr.id = v_uid) < coalesce((cfg ->> 'since')::timestamptz, now());
  for b in select * from public.badges where active order by sort, id loop
    v := coalesce((m ->> b.metric)::numeric, 0);
    t := 0;
    for i in 1..4 loop
      if v >= (b.targets ->> names[i])::numeric then t := i; end if;
    end loop;
    for i in 1..t loop
      lvl := names[i];
      if not exists (select 1 from public.user_badges u where u.user_id = v_uid and u.badge_id = b.id and u.tier = i) then
        xp := 0; days := 0;
        if not v_backfill and not v_banned then
          r := coalesce(b.rewards -> lvl, '{}'::jsonb);
          xp := private.xp_add(v_uid, least(coalesce((r ->> 'xp')::int, 0), 5000), 'earned', 'badge', b.key || ':' || lvl,
                               'badge:' || b.id || ':' || i || ':' || v_uid, false);
          if coalesce((r ->> 'days')::int, 0) > 0 then
            perform private.grant_plan(v_uid, 1::smallint, 'prize', 'badge:' || b.id || ':' || i || ':' || v_uid,
                                       least((r ->> 'days')::int, 90), 'Badge: ' || b.name || ' (' || lvl || ')');
            days := least((r ->> 'days')::int, 90);
          end if;
        end if;
        insert into public.user_badges (user_id, badge_id, tier, xp_given, days_given, backfill, seen_at)
        values (v_uid, b.id, i, coalesce(xp, 0), days, v_backfill, case when v_backfill then now() end)
        on conflict do nothing;
      end if;
    end loop;
    out_badges := out_badges || jsonb_build_object(
      'id', b.id, 'key', b.key, 'name', b.name, 'description', b.description, 'icon', b.icon, 'metric', b.metric,
      'targets', b.targets, 'rewards', b.rewards, 'value', v,
      'tier', (select coalesce(max(u.tier), 0) from public.user_badges u where u.user_id = v_uid and u.badge_id = b.id),
      'next', case when t < 4 then (b.targets ->> names[t + 1])::numeric end);
  end loop;
  return jsonb_build_object('on', true, 'badges', out_badges,
    'won', coalesce((select jsonb_agg(jsonb_build_object('badge_id', u.badge_id, 'tier', u.tier, 'name', bb.name, 'icon', bb.icon,
                       'description', bb.description, 'xp', u.xp_given, 'days', u.days_given) order by u.reached_at, u.tier)
                     from public.user_badges u join public.badges bb on bb.id = u.badge_id
                     where u.user_id = v_uid and u.seen_at is null), '[]'::jsonb));
end $$;

-- The app showed the celebration for these levels.
create or replace function public.badges_seen(p_badges bigint[]) returns void
language sql security definer set search_path = '' as $$
  update public.user_badges set seen_at = now()
  where user_id = (select auth.uid()) and badge_id = any(p_badges) and seen_at is null;
$$;

-- Admin: how many students hold each level of each badge.
create or replace function public.admin_badge_counts() returns table (badge_id bigint, tier smallint, holders bigint)
language sql stable security definer set search_path = '' as $$
  select u.badge_id, u.tier, count(*) from public.user_badges u where private.is_staff() group by 1, 2;
$$;

revoke all on function private.badge_metrics(uuid) from public, anon, authenticated;
revoke all on function public.badges_check(), public.badges_seen(bigint[]), public.admin_badge_counts() from public, anon;
grant execute on function public.badges_check(), public.badges_seen(bigint[]), public.admin_badge_counts() to authenticated;

