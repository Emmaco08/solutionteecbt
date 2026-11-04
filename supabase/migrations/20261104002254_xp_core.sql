-- SolutionTee CBT · XP1 (owner, D-081; plan docs/plans/xp-streaks.md): XP wallet (earned / bought), ledger,
-- admin settings, earning on the server (daily claim, tests, mocks, question of the day, challenges, referrals).

insert into public.app_settings (key, value, description, is_public)
values ('xp', '{
  "enabled": true, "daily_claim": 10, "daily_cap": 300,
  "test": 5, "test_min_questions": 10, "test_min_seconds": 120, "tests_per_day": 10,
  "mock": 30, "mocks_per_day": 2, "score_bonus_per_10": 1,
  "qotd": 2, "qotd_right": 3, "challenge_finish": 20, "referral": 50,
  "challenge_top": [200, 100, 50], "weekly_top": [300, 150, 75],
  "milestones": {"3": 20, "7": 50, "14": 100, "30": 250, "60": 500, "100": 1000},
  "freeze_price": 50, "freeze_max": 2, "repair_price": 200, "repair_on": true,
  "premium_prices": {"monthly": 3000, "three_months": 8000, "exam_season": 14000},
  "packs": [{"xp": 200, "naira": 200}, {"xp": 550, "naira": 500}, {"xp": 1200, "naira": 1000}, {"xp": 3200, "naira": 2500}]
}', 'XP and streaks (Admin → XP & streaks)', true)
on conflict (key) do nothing;

create or replace function private.xp_settings()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce((select value from public.app_settings where key = 'xp'), '{}'::jsonb);
$$;

alter table public.profiles add column if not exists xp_earned integer not null default 0;
alter table public.profiles add column if not exists xp_bought integer not null default 0;
alter table public.profiles add constraint profiles_xp_not_negative check (xp_earned >= 0 and xp_bought >= 0);

create table if not exists public.xp_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  amount integer not null check (amount <> 0),
  kind text not null check (kind in ('earned', 'bought')),
  reason text not null,
  ref text,
  key text unique,
  note text,
  created_by uuid,
  created_at timestamptz not null default now()
);
create index if not exists xp_ledger_user on public.xp_ledger (user_id, created_at desc);
create index if not exists xp_ledger_day on public.xp_ledger (created_at);
alter table public.xp_ledger enable row level security;
create policy "own or staff" on public.xp_ledger for select using (user_id = (select auth.uid()) or private.is_staff());
revoke all on public.xp_ledger from anon;
revoke insert, update, delete on public.xp_ledger from authenticated;

/** Lagos-day start (midnight) for daily limits. */
create or replace function private.lagos_day_start()
returns timestamptz language sql stable set search_path = '' as $$
  select (private.lagos_today()::timestamp at time zone 'Africa/Lagos');
$$;

/** Give XP once per key. Earned XP: not when XP is off, not to banned or second accounts, and within the daily cap
    (unless p_capped is false). Returns the XP actually given (0 = nothing). */
create or replace function private.xp_add(p_user uuid, p_amount integer, p_kind text, p_reason text, p_ref text, p_key text,
                                          p_capped boolean default true, p_by uuid default null, p_note text default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare s jsonb := private.xp_settings(); v integer := p_amount; v_today integer;
begin
  if p_user is null or coalesce(p_amount, 0) <= 0 then return 0; end if;
  if p_kind = 'earned' and p_by is null then
    if not coalesce((s ->> 'enabled')::boolean, true) or private.is_banned(p_user) then return 0; end if;
    if p_capped then
      select coalesce(sum(amount), 0) into v_today from public.xp_ledger
      where user_id = p_user and kind = 'earned' and amount > 0 and created_by is null and reason <> 'daily_claim'
        and created_at >= private.lagos_day_start();
      v := least(v, greatest(coalesce((s ->> 'daily_cap')::int, 300) - v_today, 0));
      if v <= 0 then return 0; end if;
    end if;
  end if;
  insert into public.xp_ledger (user_id, amount, kind, reason, ref, key, created_by, note)
  values (p_user, v, p_kind, p_reason, p_ref, p_key, p_by, left(p_note, 300))
  on conflict (key) do nothing;
  if not found then return 0; end if;
  if p_kind = 'bought' then
    update public.profiles set xp_bought = xp_bought + v where id = p_user;
  else
    update public.profiles set xp_earned = xp_earned + v where id = p_user;
  end if;
  return v;
end;
$$;

/** Take XP (spending, admin removal). p_bought_ok: bought XP may be used (never for cash-prize entries, D-081);
    bought XP is used first. Raises when the balance is too small. Returns {earned, bought} taken. */
create or replace function private.xp_take(p_user uuid, p_amount integer, p_bought_ok boolean, p_reason text, p_ref text, p_key text,
                                           p_by uuid default null, p_note text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.profiles; v_b integer := 0; v_e integer;
begin
  if coalesce(p_amount, 0) <= 0 then return jsonb_build_object('earned', 0, 'bought', 0); end if;
  if p_key is not null and exists (select 1 from public.xp_ledger where key = p_key or key = p_key || ':b') then
    return jsonb_build_object('earned', 0, 'bought', 0, 'again', true);
  end if;
  select * into p from public.profiles where id = p_user for update;
  if p_bought_ok then v_b := least(p.xp_bought, p_amount); end if;
  v_e := p_amount - v_b;
  if v_e > p.xp_earned then
    raise exception '%', case when p_bought_ok then 'Not enough XP.' else 'Not enough earned XP. Bought XP cannot be used here.' end
      using errcode = 'P0001';
  end if;
  if v_e > 0 then
    insert into public.xp_ledger (user_id, amount, kind, reason, ref, key, created_by, note) values (p_user, -v_e, 'earned', p_reason, p_ref, p_key, p_by, left(p_note, 300));
  end if;
  if v_b > 0 then
    insert into public.xp_ledger (user_id, amount, kind, reason, ref, key, created_by, note) values (p_user, -v_b, 'bought', p_reason, p_ref, p_key || ':b', p_by, left(p_note, 300));
  end if;
  update public.profiles set xp_earned = xp_earned - v_e, xp_bought = xp_bought - v_b where id = p_user;
  return jsonb_build_object('earned', v_e, 'bought', v_b);
end;
$$;

-- ── Earning ─────────────────────────────────────────────────────────────────────────────────────────────────────
/** A finished test: mocks (full papers) and other tests, with a minimum length, daily limits and a score bonus. */
create or replace function private.xp_on_attempt()
returns trigger language plpgsql security definer set search_path = '' as $$
declare s jsonb := private.xp_settings(); v_answered integer; v_total integer; v_correct integer; v_mock boolean; v_n integer; v_xp integer; v_pct numeric;
begin
  if new.status::text <> 'submitted' then return null; end if;
  v_answered := coalesce((new.server_score ->> 'answered')::int, 0);
  v_total := coalesce((new.server_score ->> 'total')::int, 0);
  v_correct := coalesce((new.server_score ->> 'correct')::int, 0);
  if v_answered < coalesce((s ->> 'test_min_questions')::int, 10) or coalesce(new.time_used_s, 0) < coalesce((s ->> 'test_min_seconds')::int, 120) then
    return null;
  end if;
  v_mock := new.mode = 'full';
  select count(*) into v_n from public.xp_ledger where user_id = new.user_id and reason = case when v_mock then 'mock' else 'test' end
    and created_at >= private.lagos_day_start();
  if v_n >= coalesce((s ->> case when v_mock then 'mocks_per_day' else 'tests_per_day' end)::int, case when v_mock then 2 else 10 end) then
    return null;
  end if;
  v_xp := coalesce((s ->> case when v_mock then 'mock' else 'test' end)::int, case when v_mock then 30 else 5 end);
  v_pct := case when v_total > 0 then 100.0 * v_correct / v_total else 0 end;
  if v_pct > 50 then v_xp := v_xp + floor((v_pct - 50) / 10)::int * coalesce((s ->> 'score_bonus_per_10')::int, 1); end if;
  perform private.xp_add(new.user_id, v_xp, 'earned', case when v_mock then 'mock' else 'test' end, new.id::text, 'attempt:' || new.id);
  return null;
end;
$$;
create trigger xp_on_attempt after insert or update of status on public.attempts
  for each row when (new.status = 'submitted') execute function private.xp_on_attempt();

create or replace function private.xp_on_qotd()
returns trigger language plpgsql security definer set search_path = '' as $$
declare s jsonb := private.xp_settings();
begin
  perform private.xp_add(new.user_id, coalesce((s ->> 'qotd')::int, 2) + case when new.correct then coalesce((s ->> 'qotd_right')::int, 3) else 0 end,
                         'earned', 'qotd', new.day::text, 'qotd:' || new.user_id || ':' || new.day);
  return null;
end;
$$;
create trigger xp_on_qotd after insert on public.qotd_answers for each row execute function private.xp_on_qotd();

create or replace function private.xp_on_challenge()
returns trigger language plpgsql security definer set search_path = '' as $$
declare s jsonb := private.xp_settings();
begin
  if new.status = 'finished' and old.status is distinct from 'finished' then
    perform private.xp_add(new.user_id, coalesce((s ->> 'challenge_finish')::int, 20), 'earned', 'challenge', new.challenge_id::text, 'challenge:' || new.id);
  end if;
  return null;
end;
$$;
create trigger xp_on_challenge after update of status on public.challenge_entries for each row execute function private.xp_on_challenge();

create or replace function private.xp_on_referral()
returns trigger language plpgsql security definer set search_path = '' as $$
declare s jsonb := private.xp_settings();
begin
  if new.status = 'counted' and old.status is distinct from 'counted' then
    perform private.xp_add(new.referrer, coalesce((s ->> 'referral')::int, 50), 'earned', 'referral', new.friend::text, 'referral:' || new.id, false);
  end if;
  return null;
end;
$$;
create trigger xp_on_referral after update of status on public.referrals for each row execute function private.xp_on_referral();

-- ── Student ─────────────────────────────────────────────────────────────────────────────────────────────────────
/** The daily claim (first app open each Lagos day). */
create or replace function public.xp_claim_daily()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); s jsonb := private.xp_settings(); v integer;
begin
  if v_uid is null then raise exception 'Not allowed' using errcode = '42501'; end if;
  if not coalesce((s ->> 'enabled')::boolean, true) then return jsonb_build_object('ok', false, 'off', true); end if;
  if private.is_banned(v_uid) then raise exception 'Not allowed' using errcode = '42501'; end if;
  v := private.xp_add(v_uid, coalesce((s ->> 'daily_claim')::int, 10), 'earned', 'daily_claim', private.lagos_today()::text,
                      'daily:' || v_uid || ':' || private.lagos_today(), false);
  return jsonb_build_object('ok', true, 'given', v, 'already', v = 0,
    'balance', (select xp_earned + xp_bought from public.profiles where id = v_uid));
end;
$$;

/** Wallet: balance (earned / bought), today's claim, today's XP and the cap, ways to earn, the last 50 changes. */
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
    'history', coalesce((select jsonb_agg(jsonb_build_object('amount', l.amount, 'kind', l.kind, 'reason', l.reason, 'note', l.note, 'at', l.created_at) order by l.created_at desc)
                         from (select * from public.xp_ledger where user_id = v_uid order by created_at desc limit 50) l), '[]'::jsonb));
end;
$$;

-- ── Admin ───────────────────────────────────────────────────────────────────────────────────────────────────────
create or replace function public.admin_xp_overview()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  return jsonb_build_object(
    'settings', private.xp_settings(),
    'totals', (select jsonb_build_object('in_wallets', coalesce(sum(xp_earned + xp_bought), 0), 'earned', coalesce(sum(xp_earned), 0),
                 'bought', coalesce(sum(xp_bought), 0), 'students', count(*) filter (where xp_earned + xp_bought > 0)) from public.profiles),
    'days', coalesce((select jsonb_agg(t order by t.day) from (
       select (created_at at time zone 'Africa/Lagos')::date as day,
              coalesce(sum(amount) filter (where amount > 0 and kind = 'earned'), 0) as given,
              coalesce(sum(amount) filter (where amount > 0 and kind = 'bought'), 0) as sold,
              coalesce(-sum(amount) filter (where amount < 0), 0) as spent,
              count(distinct user_id) filter (where reason = 'daily_claim') as claims
       from public.xp_ledger where created_at > now() - interval '30 days' group by 1) t), '[]'::jsonb),
    'by_reason', coalesce((select jsonb_object_agg(reason, total) from (
       select reason, sum(amount) as total from public.xp_ledger where created_at > now() - interval '30 days' group by reason) r), '{}'::jsonb),
    'top', coalesce((select jsonb_agg(t) from (
       select p.id as user_id, p.full_name as name, u.email, p.xp_earned as earned, p.xp_bought as bought
       from public.profiles p join auth.users u on u.id = p.id where p.xp_earned + p.xp_bought > 0
       order by p.xp_earned + p.xp_bought desc limit 20) t), '[]'::jsonb));
end;
$$;

/** One student's wallet and history (search by email or name). */
create or replace function public.admin_xp_user(p_query text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_id uuid;
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  select p.id into v_id from public.profiles p join auth.users u on u.id = p.id
  where lower(u.email) = lower(trim(p_query)) or p.full_name ilike '%' || trim(p_query) || '%'
  order by (lower(u.email) = lower(trim(p_query))) desc, p.created_at limit 1;
  if v_id is null then return null; end if;
  return (select jsonb_build_object('user_id', p.id, 'name', p.full_name, 'email', u.email, 'earned', p.xp_earned, 'bought', p.xp_bought,
     'history', coalesce((select jsonb_agg(jsonb_build_object('amount', l.amount, 'kind', l.kind, 'reason', l.reason, 'note', l.note, 'at', l.created_at,
                 'by', (select s.full_name from public.profiles s where s.id = l.created_by)) order by l.created_at desc)
               from (select * from public.xp_ledger where user_id = p.id order by created_at desc limit 100) l), '[]'::jsonb))
    from public.profiles p join auth.users u on u.id = p.id where p.id = v_id);
end;
$$;

/** Give (+) or take (−) earned XP with a reason. Logged in the ledger and the audit table. */
create or replace function public.admin_xp_adjust(p_user uuid, p_amount integer, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_key text := 'admin:' || gen_random_uuid();
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  if char_length(trim(coalesce(p_reason, ''))) < 3 then raise exception 'Write the reason (the student sees it).' using errcode = '22023'; end if;
  if p_amount is null or p_amount = 0 or abs(p_amount) > 1000000 then raise exception 'Choose an amount.' using errcode = '22023'; end if;
  if p_amount > 0 then
    perform private.xp_add(p_user, p_amount, 'earned', 'admin', null, v_key, false, (select auth.uid()), trim(p_reason));
  else
    perform private.xp_take(p_user, -p_amount, true, 'admin', null, v_key, (select auth.uid()), trim(p_reason));
  end if;
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), 'xp.adjust', 'profiles', p_user::text, jsonb_build_object('amount', p_amount, 'reason', p_reason));
  return (select jsonb_build_object('earned', xp_earned, 'bought', xp_bought) from public.profiles where id = p_user);
end;
$$;

/** Save the XP rules (numbers kept inside safe limits). */
create or replace function public.admin_xp_settings(p jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare n text; v jsonb := private.xp_settings();
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  v := v || jsonb_build_object('enabled', coalesce((p ->> 'enabled')::boolean, true), 'repair_on', coalesce((p ->> 'repair_on')::boolean, true));
  foreach n in array array['daily_claim', 'daily_cap', 'test', 'test_min_questions', 'test_min_seconds', 'tests_per_day', 'mock', 'mocks_per_day',
                           'score_bonus_per_10', 'qotd', 'qotd_right', 'challenge_finish', 'referral', 'freeze_price', 'freeze_max', 'repair_price'] loop
    if p ? n then v := v || jsonb_build_object(n, least(greatest(coalesce((p ->> n)::int, 0), 0), 1000000)); end if;
  end loop;
  foreach n in array array['challenge_top', 'weekly_top'] loop
    if jsonb_typeof(p -> n) = 'array' then
      v := v || jsonb_build_object(n, (select coalesce(jsonb_agg(least(greatest(coalesce(x::text::int, 0), 0), 1000000)), '[]') from jsonb_array_elements(p -> n) x));
    end if;
  end loop;
  if jsonb_typeof(p -> 'milestones') = 'object' then
    v := v || jsonb_build_object('milestones', (select coalesce(jsonb_object_agg(k, least(greatest(coalesce(x::text::int, 0), 0), 1000000)), '{}')
                                             from jsonb_each(p -> 'milestones') e(k, x) where k ~ '^[0-9]{1,4}$'));
  end if;
  if jsonb_typeof(p -> 'premium_prices') = 'object' then
    v := v || jsonb_build_object('premium_prices', (select coalesce(jsonb_object_agg(k, least(greatest(coalesce(x::text::int, 0), 0), 10000000)), '{}')
                                                 from jsonb_each(p -> 'premium_prices') e(k, x) where k in (select code from public.plans)));
  end if;
  if jsonb_typeof(p -> 'packs') = 'array' then
    v := v || jsonb_build_object('packs', (select coalesce(jsonb_agg(jsonb_build_object('xp', (x ->> 'xp')::int, 'naira', (x ->> 'naira')::int)
                                                                     order by (x ->> 'xp')::int), '[]')
                                        from jsonb_array_elements(p -> 'packs') x
                                        where (x ->> 'xp')::int between 1 and 1000000 and (x ->> 'naira')::int between 100 and 10000000));
  end if;
  update public.app_settings set value = v, updated_at = now(), updated_by = (select auth.uid()) where key = 'xp';
  insert into public.audit_log (actor, action, table_name, row_id, after) values ((select auth.uid()), 'xp.settings', 'app_settings', 'xp', v);
end;
$$;

revoke execute on function private.xp_settings(), private.lagos_day_start(),
  private.xp_add(uuid, integer, text, text, text, text, boolean, uuid, text),
  private.xp_take(uuid, integer, boolean, text, text, text, uuid, text) from public, anon, authenticated;
revoke execute on function public.xp_claim_daily(), public.my_xp(), public.admin_xp_overview(), public.admin_xp_user(text),
  public.admin_xp_adjust(uuid, integer, text), public.admin_xp_settings(jsonb) from public, anon;
grant execute on function public.xp_claim_daily(), public.my_xp(), public.admin_xp_overview(), public.admin_xp_user(text),
  public.admin_xp_adjust(uuid, integer, text), public.admin_xp_settings(jsonb) to authenticated;
