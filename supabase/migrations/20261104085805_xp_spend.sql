-- SolutionTee CBT · XP3 (owner, D-083; plan docs/plans/xp-streaks.md §3.3): spending XP — challenge entry fees
-- (earned XP only for cash prizes), Premium with XP; XP prizes for challenge top 3 and the weekly JAMB mock top 3.

alter type public.entitlement_source add value if not exists 'xp';
alter table public.challenges add column if not exists xp_fee integer not null default 0;
alter table public.challenges add constraint challenges_xp_fee_ok check (xp_fee >= 0 and xp_fee <= 1000000);

create or replace function private.challenge_card(c public.challenges, p_uid uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'title', c.title, 'subtitle', c.subtitle, 'kind', c.kind, 'icon', c.icon, 'exam', c.exam_code,
    'mode', c.mode, 'subject', (select s.name from public.subjects s where s.id = c.subject_id), 'per_level', c.per_level,
    'same_questions', c.same_questions, 'allow_review', c.allow_review,
    'xp_fee', case when coalesce((private.xp_settings() ->> 'enabled')::boolean, true) then c.xp_fee else 0 end,
    'xp_earned_only', c.kind = 'cash',
    'eligible', private.challenge_eligible(c, p_uid),
    'starts_at', c.starts_at, 'ends_at', c.ends_at, 'status', private.challenge_status(c),
    'questions', coalesce((select cardinality(e.question_order) from public.challenge_entries e where e.challenge_id = c.id and e.user_id = p_uid),
                          private.challenge_paper_size(c, p_uid)),
    'seconds', c.seconds_per_question, 'prizes', to_jsonb(c.prizes), 'reward', c.reward_text,
    'premium_days', c.premium_days, 'premium_top', c.premium_top, 'allowed_exits', c.allowed_exits,
    'joined', (select count(*) from public.challenge_entries e where e.challenge_id = c.id),
    'mine', (select jsonb_build_object('status', e.status, 'score', e.score, 'time_ms', e.time_ms, 'rank', e.rank,
                                       'prize', e.prize, 'started_at', e.started_at, 'answered', e.current, 'dq_reason', e.dq_reason,
                                       'finished_at', e.finished_at,
                                       'can_review', c.allow_review and private.challenge_status(c) = 'ended' and e.status <> 'playing',
                                       'appeal', (select jsonb_build_object('status', a.status, 'note', a.admin_note, 'created_at', a.created_at)
                                                  from public.challenge_appeals a where a.entry_id = e.id))
             from public.challenge_entries e where e.challenge_id = c.id and e.user_id = p_uid));
$$;


create or replace function public.challenge_start(p_id uuid, p_device text default null, p_device_flags text[] default '{}')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); c public.challenges; e record; v_ids uuid[]; v_subjects smallint[]; v_fee integer;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if not coalesce((select f.enabled from public.feature_flags f where f.key = 'challenges_enabled'), true) then
    raise exception 'Challenges are switched off right now.' using errcode = 'P0001';
  end if;
  select * into c from public.challenges where id = p_id and published;
  if not found then raise exception 'This challenge is not available.' using errcode = 'P0002'; end if;
  select * into e from public.challenge_entries where challenge_id = p_id and user_id = v_uid;
  if found then
    if e.status = 'playing' then
      if private.challenge_status(c) = 'ended' then
        perform private.challenge_finish(e.id, 'finished');
        return jsonb_build_object('status', 'finished');
      end if;
      return public.challenge_exit(e.id, 'The app was closed or restarted during the challenge');
    end if;
    return jsonb_build_object('status', e.status);
  end if;
  if private.challenge_status(c) <> 'live' then raise exception 'This challenge is not live.' using errcode = 'P0001'; end if;
  if not private.challenge_eligible(c, v_uid) then
    raise exception '%', case when c.mode = 'subject' then 'This challenge is for students who take '
      || (select s.name from public.subjects s where s.id = c.subject_id) || '.' else 'Choose your JAMB subjects first (Me → Change JAMB subjects).' end
      using errcode = 'P0001';
  end if;
  if c.mode = 'fixed' then
    select array_agg(q.id order by md5(v_uid::text || q.id::text)) into v_ids from public.challenge_questions q where q.challenge_id = p_id;
  else
    v_subjects := case when c.mode = 'subject' then array[c.subject_id] else private.student_subjects(v_uid) end;
    select array_agg(t.id order by random()) into v_ids from (
      select q.id
      from unnest(v_subjects) s(sid)
      cross join lateral jsonb_each_text(c.per_level) l(lvl, n)
      cross join lateral (select x.id from public.challenge_questions x
                          where x.challenge_id = p_id and x.subject_id = s.sid and x.difficulty = l.lvl
                          order by case when c.same_questions then md5(p_id::text || x.id::text) end, random()
                          limit greatest((l.n)::int, 0)) q) t;
  end if;
  if v_ids is null then raise exception 'This challenge has no questions for your subjects yet.' using errcode = 'P0001'; end if;
  -- XP entry fee (D-083): earned XP only for cash-prize challenges (D-081). Taken in the same transaction as the entry.
  v_fee := case when coalesce((private.xp_settings() ->> 'enabled')::boolean, true) then coalesce(c.xp_fee, 0) else 0 end;
  if v_fee > 0 then
    perform private.xp_take(v_uid, v_fee, c.kind <> 'cash', 'entry', p_id::text, 'entry:' || p_id || ':' || v_uid);
  end if;
  insert into public.challenge_entries (challenge_id, user_id, question_order, device_hash, device_flags)
  values (p_id, v_uid, v_ids, left(p_device, 128), coalesce(p_device_flags[1:5], '{}'))
  returning * into e;
  return jsonb_build_object('status', 'playing', 'question', private.challenge_serve(e.id));
end;
$$;


create or replace function public.my_xp()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); s jsonb := private.xp_settings(); p public.profiles;
begin
  if v_uid is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into p from public.profiles where id = v_uid;
  return jsonb_build_object(
    'enabled', coalesce((s ->> 'enabled')::boolean, true),
    'balance', p.xp_earned + p.xp_bought, 'earned', p.xp_earned, 'bought', p.xp_bought,
    'claimed_today', exists (select 1 from public.xp_ledger where key = 'daily:' || v_uid || ':' || private.lagos_today()),
    'daily_claim', (s ->> 'daily_claim')::int,
    'today', (select coalesce(sum(amount), 0) from public.xp_ledger where user_id = v_uid and kind = 'earned' and amount > 0
              and created_by is null and reason <> 'daily_claim' and created_at >= private.lagos_day_start()),
    'daily_cap', (s ->> 'daily_cap')::int,
    'rules', s - 'packs' - 'premium_prices',
    'premium_prices', s -> 'premium_prices', 'packs', s -> 'packs',
    'premium_options', coalesce((select jsonb_agg(jsonb_build_object('code', pl.code, 'name', pl.name, 'xp', (s -> 'premium_prices' ->> pl.code)::int) order by pl.price_kobo)
                                 from public.plans pl where coalesce((s -> 'premium_prices' ->> pl.code)::int, 0) > 0 and private.plan_on_sale(pl)), '[]'::jsonb),
    'history', coalesce((select jsonb_agg(jsonb_build_object('amount', l.amount, 'kind', l.kind, 'reason', l.reason, 'note', l.note, 'at', l.created_at) order by l.created_at desc)
                         from (select * from public.xp_ledger where user_id = v_uid order by created_at desc limit 50) l), '[]'::jsonb));
end;
$$;


/** Premium paid with XP (earned or bought): the admin's XP price per plan; the period starts when current Premium ends. */
create or replace function public.xp_buy_premium(p_plan text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); s jsonb := private.xp_settings(); v_plan public.plans; v_price integer; v_end timestamptz; v_ent uuid; v_ref text := gen_random_uuid()::text;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if not coalesce((s ->> 'enabled')::boolean, true) then raise exception 'XP is paused right now.' using errcode = 'P0001'; end if;
  select * into v_plan from public.plans where code = p_plan;
  v_price := coalesce((s -> 'premium_prices' ->> p_plan)::int, 0);
  if v_plan.id is null or v_price <= 0 or not private.plan_on_sale(v_plan) then raise exception 'This plan cannot be bought with XP.' using errcode = 'P0001'; end if;
  select pp.expires_at into v_end from private.plan_period(v_uid, v_plan.id) pp;
  if v_end is null then raise exception 'Your Premium already lasts past the end of this plan.' using errcode = 'P0001'; end if;
  perform private.xp_take(v_uid, v_price, true, 'premium', p_plan, 'premium:' || v_ref);
  v_ent := private.grant_plan(v_uid, v_plan.id, 'xp'::public.entitlement_source, 'xp:' || v_ref, null, v_plan.name || ' · paid with ' || v_price || ' XP');
  insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source)
  values ('account', 'Premium is on', v_plan.name || ' paid with ' || v_price || ' XP. Enjoy every year and every exam.', 'user', v_uid, 'scheduled', now(), 'premium');
  return jsonb_build_object('ok', true, 'expires_at', (select e.expires_at from public.entitlements e where e.id = v_ent),
                            'balance', (select xp_earned + xp_bought from public.profiles where id = v_uid));
end;
$$;

/** Every 15 minutes: XP prizes for the top 3 of closed challenges (fair entries only). */
create or replace function private.xp_prize_job()
returns integer language plpgsql security definer set search_path = '' as $$
declare s jsonb := private.xp_settings(); r record; v_n integer := 0; v_xp integer;
begin
  if not coalesce((s ->> 'enabled')::boolean, true) then return 0; end if;
  for r in select e.id, e.user_id, e.rank, c.id as cid, c.title from public.challenge_entries e join public.challenges c on c.id = e.challenge_id
           where c.closed_at is not null and c.closed_at > now() - interval '7 days' and e.rank between 1 and 3
             and e.status = 'finished' and e.review is distinct from 'dq' loop
    v_xp := coalesce((s -> 'challenge_top' ->> (r.rank - 1))::int, 0);
    if v_xp > 0 and private.xp_add(r.user_id, v_xp, 'earned', 'challenge_top', r.cid::text, 'challenge_top:' || r.id, false) > 0 then
      insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
      values ('challenges', '+' || v_xp || ' XP for place ' || r.rank, 'You finished #' || r.rank || ' in ' || r.title || '.', 'user', r.user_id, 'scheduled', now(), 'challenge',
              jsonb_build_object('type', 'screen', 'target', '/me/xp'));
      v_n := v_n + 1;
    end if;
  end loop;
  return v_n;
end;
$$;
select cron.schedule('xp-prizes', '*/15 * * * *', $$select private.xp_prize_job()$$);

/** Every Monday 00:05 Lagos: XP for the 3 best JAMB mocks of last week (Monday–Sunday), with the leaderboard's fair-play rules. */
create or replace function private.xp_weekly_job()
returns integer language plpgsql security definer set search_path = '' as $$
declare s jsonb := private.xp_settings(); v_mon date := private.lagos_today() - (extract(isodow from private.lagos_today())::int - 1);
        v_from timestamptz; v_to timestamptz; r record; v_n integer := 0; v_xp integer;
begin
  if not coalesce((s ->> 'enabled')::boolean, true) then return 0; end if;
  v_to := (v_mon::timestamp at time zone 'Africa/Lagos');
  v_from := v_to - interval '7 days';
  for r in
    with best as (
      select distinct on (a.user_id) a.user_id, a.score, a.time_s
      from private.lb_attempts(private.jamb_season(v_from)) a join public.profiles p on p.id = a.user_id
      where a.submitted_at >= v_from and a.submitted_at < v_to and a.held is null and a.review is distinct from 'reject'
        and p.banned_at is null and not exists (select 1 from public.staff st where st.user_id = a.user_id)
      order by a.user_id, a.score desc, a.time_s asc)
    select user_id, score, row_number() over (order by score desc, time_s asc) as rnk from best order by 3 limit 3
  loop
    v_xp := coalesce((s -> 'weekly_top' ->> (r.rnk - 1)::int)::int, 0);
    if v_xp > 0 and private.xp_add(r.user_id, v_xp, 'earned', 'weekly_top', v_mon::text, 'weekly:' || v_mon || ':' || r.user_id, false) > 0 then
      insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
      values ('account', '+' || v_xp || ' XP: #' || r.rnk || ' this week', 'Your JAMB mock score of ' || r.score || ' was #' || r.rnk || ' last week. Well done!',
              'user', r.user_id, 'scheduled', now() + interval '7 hours', 'admin', jsonb_build_object('type', 'screen', 'target', '/me/xp'));
      v_n := v_n + 1;
    end if;
  end loop;
  return v_n;
end;
$$;
select cron.schedule('xp-weekly', '5 23 * * 0', $$select private.xp_weekly_job()$$);

revoke execute on function private.xp_prize_job(), private.xp_weekly_job() from public, anon, authenticated;
revoke execute on function public.xp_buy_premium(text) from public, anon;
grant execute on function public.xp_buy_premium(text) to authenticated;
