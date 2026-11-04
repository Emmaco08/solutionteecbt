-- U2 (docs/plans/big-update.md, D-090, D-091).
-- 1. Prize payouts by Paystack Transfers, approved by an admin. The account name Paystack finds is stored by the server.
alter table public.prize_claims
  add column if not exists bank_code text,
  add column if not exists verified_name text,
  add column if not exists payout_status text not null default 'none',
  add column if not exists payout_ref text,
  add column if not exists transfer_code text,
  add column if not exists recipient_code text,
  add column if not exists payout_error text,
  add column if not exists payout_by uuid references auth.users(id),
  add column if not exists payout_at timestamptz;
alter table public.prize_claims drop constraint if exists prize_claims_payout_check;
alter table public.prize_claims add constraint prize_claims_payout_check check (
  payout_status in ('none', 'checked', 'sending', 'sent', 'failed', 'reversed')
  and (bank_code is null or bank_code ~ '^[0-9A-Za-z]{2,12}$')
  and (verified_name is null or char_length(verified_name) <= 120)
  and (payout_error is null or char_length(payout_error) <= 300)
  and (payout_ref is null or payout_ref ~ '^po_[0-9a-f]{20}$'));
create unique index if not exists prize_claims_payout_ref on public.prize_claims (payout_ref) where payout_ref is not null;

/** A winner sends their bank account (bank picked from Paystack's list, so the code is known). */
create or replace function public.prize_claim_v2(p_id uuid, p_adult boolean, p_bank text, p_bank_code text, p_account_number text,
  p_account_name text, p_guardian_name text default null, p_guardian_phone text default null)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare r jsonb;
begin
  if p_bank_code is null or p_bank_code !~ '^[0-9A-Za-z]{2,12}$' then raise exception 'Choose your bank from the list.' using errcode = '22023'; end if;
  r := public.prize_claim(p_id, p_adult, p_bank, p_account_number, p_account_name, p_guardian_name, p_guardian_phone);
  update public.prize_claims pc set bank_code = p_bank_code
  from public.challenge_entries e where e.id = pc.entry_id and e.challenge_id = p_id and pc.user_id = (select auth.uid());
  return r;
end;
$$;
revoke execute on function public.prize_claim_v2(uuid, boolean, text, text, text, text, text, text) from public, anon;
grant execute on function public.prize_claim_v2(uuid, boolean, text, text, text, text, text, text) to authenticated;

-- 2. Challenge rules: a player limit, and a minimum score (% of the questions) to win a prize.
alter table public.challenges add column if not exists max_players integer, add column if not exists min_win_pct smallint;
alter table public.challenges drop constraint if exists challenges_rules_check;
alter table public.challenges add constraint challenges_rules_check check (
  (max_players is null or max_players between 1 and 1000000) and (min_win_pct is null or min_win_pct between 0 and 100));

do $$
declare d text;
begin
  -- The card says how many places are left and the minimum score.
  d := pg_get_functiondef('private.challenge_card(public.challenges, uuid)'::regprocedure);
  if position('''max_players''' in d) = 0 then
    d := replace(d, '''bg_light'', c.bg_light,', '''bg_light'', c.bg_light, ''max_players'', c.max_players, ''min_win_pct'', c.min_win_pct,');
    if position('''max_players''' in d) = 0 then raise exception 'challenge_card anchor'; end if;
    execute d;
  end if;

  -- Joining: refused when the challenge is full (a lock per challenge so two students cannot take the last place).
  d := pg_get_functiondef('public.challenge_start(uuid, text, text[])'::regprocedure);
  if position('This challenge is full' in d) = 0 then
    d := replace(d, $a$  if private.challenge_status(c) <> 'live' then raise exception 'This challenge is not live.' using errcode = 'P0001'; end if;$a$,
      $b$  if private.challenge_status(c) <> 'live' then raise exception 'This challenge is not live.' using errcode = 'P0001'; end if;
  if c.max_players is not null then
    perform pg_advisory_xact_lock(hashtext('challenge_join:' || p_id::text));
    if (select count(*) from public.challenge_entries x where x.challenge_id = p_id) >= c.max_players then
      raise exception 'This challenge is full (% players). Look out for the next one.', c.max_players using errcode = 'P0001';
    end if;
  end if;$b$);
    if position('This challenge is full' in d) = 0 then raise exception 'challenge_start anchor'; end if;
    execute d;
  end if;

  -- Prizes and Premium days only for places that reached the minimum score.
  d := pg_get_functiondef('private.challenge_rank(uuid)'::regprocedure);
  if position('min_win_pct' in d) = 0 then
    d := replace(d, $a$prize = case when r.rnk <= cardinality(c.prizes) then c.prizes[r.rnk] end$a$,
      $b$prize = case when r.rnk <= cardinality(c.prizes) and private.challenge_reached_min(c.min_win_pct, r.entry_id) then c.prizes[r.rnk] end$b$);
    d := replace(d, $a$where e.challenge_id = p_id and e.rank <= c.premium_top and not e.premium_given;$a$,
      $b$where e.challenge_id = p_id and e.rank <= c.premium_top and not e.premium_given and private.challenge_reached_min(c.min_win_pct, e.id);$b$);
    d := replace(d, 'declare c record; r record;', 'declare c record; r record; -- min_win_pct (D-091)');
    if position('challenge_reached_min(c.min_win_pct, r.entry_id)' in d) = 0 or position('challenge_reached_min(c.min_win_pct, e.id)' in d) = 0 then
      raise exception 'challenge_rank anchor';
    end if;
  end if;
  -- (executed below, after the helper exists)
  perform set_config('u2.rank_def', d, true);
end $$;

/** Did this entry reach the challenge's minimum score (% of its questions)? No minimum: yes. */
create or replace function private.challenge_reached_min(p_min smallint, p_entry uuid)
returns boolean language sql stable set search_path to '' as $$
  select p_min is null or p_min = 0 or exists (
    select 1 from public.challenge_entries e
    where e.id = p_entry and coalesce(e.score, 0) * 100 >= p_min * greatest(coalesce(cardinality(e.question_order), 0), 1));
$$;

do $$ begin
  if position('min_win_pct' in current_setting('u2.rank_def')) > 0 then execute current_setting('u2.rank_def'); end if;
end $$;

-- XP prizes for 1st–3rd follow the same rule.
do $$
declare d text := pg_get_functiondef('private.xp_prize_job()'::regprocedure);
begin
  if position('challenge_reached_min' in d) = 0 then
    d := replace(d, $a$and e.status = 'finished' and e.review is distinct from 'dq' loop$a$,
      $b$and e.status = 'finished' and e.review is distinct from 'dq' and private.challenge_reached_min(c.min_win_pct, e.id) loop$b$);
    if position('challenge_reached_min' in d) = 0 then raise exception 'xp_prize_job anchor'; end if;
    execute d;
  end if;
end $$;
