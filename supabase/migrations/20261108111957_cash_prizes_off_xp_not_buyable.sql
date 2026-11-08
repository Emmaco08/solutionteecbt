-- Cash prizes off until the regulator (LSLGA) approves; XP can no longer be bought (D-110, lawyer's decisions 8 Nov 2026).
-- One admin switch, app_settings.cash_prizes.on (default off). While off:
--   * no challenge can have cash prizes (rewards are Premium days, XP and badges);
--   * no new cash prize claims and no new cash referral rewards.
-- When an admin turns it on later: cash-prize challenges must be free to enter (no XP fee) and only students aged 18+
-- can enter them or claim (min_age).
-- XP: app_settings.xp.buy_on = false; buying XP packs is refused by the server. XP is earned (daily, tests, ads...).

insert into public.app_settings (key, value, is_public)
values ('cash_prizes', '{"on": false, "min_age": 18}', true)
on conflict (key) do nothing;

update public.app_settings set value = value || '{"buy_on": false}'::jsonb where key = 'xp';

create or replace function private.cash_on() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select (value ->> 'on')::boolean from public.app_settings where key = 'cash_prizes'), false);
$$;

create or replace function private.cash_min_age() returns integer
language sql stable security definer set search_path = '' as $$
  select coalesce((select (value ->> 'min_age')::int from public.app_settings where key = 'cash_prizes'), 18);
$$;

create or replace function private.user_age(p_uid uuid) returns integer
language sql stable security definer set search_path = '' as $$
  select extract(year from now())::int - birth_year from public.profiles where id = p_uid;
$$;

-- Challenges: no cash while off; cash challenges are always free to enter.
create or replace function private.challenge_cash_rules() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_cash boolean := exists (select 1 from unnest(coalesce(new.prizes, '{}')) p where p > 0);
begin
  if tg_op = 'UPDATE' and new.prizes is not distinct from old.prizes and new.xp_fee is not distinct from old.xp_fee
     and not (new.published and not old.published) then
    return new;
  end if;
  if v_cash and not private.cash_on() then
    raise exception 'Cash prizes are switched off. Give Premium days or XP instead (Settings → Rewards to turn cash on after approval).' using errcode = 'P0001';
  end if;
  if v_cash and coalesce(new.xp_fee, 0) > 0 then
    raise exception 'A cash-prize challenge must be free to enter (no XP fee).' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
drop trigger if exists challenges_cash_rules on public.challenges;
create trigger challenges_cash_rules before insert or update on public.challenges
  for each row execute function private.challenge_cash_rules();

-- Entering a cash-prize challenge: 18+ only.
create or replace function private.entry_cash_age() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.challenges c, unnest(coalesce(c.prizes, '{}')) p where c.id = new.challenge_id and p > 0)
     and coalesce(private.user_age(new.user_id), 0) < private.cash_min_age() then
    raise exception 'Cash-prize challenges are only for students aged % and over.', private.cash_min_age() using errcode = 'P0001';
  end if;
  return new;
end;
$$;
drop trigger if exists challenge_entries_cash_age on public.challenge_entries;
create trigger challenge_entries_cash_age before insert on public.challenge_entries
  for each row execute function private.entry_cash_age();

-- Claims: none while off; 18+ when on.
create or replace function private.prize_claim_rules() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not private.cash_on() then
    raise exception 'Cash prizes are switched off for now.' using errcode = 'P0001';
  end if;
  if coalesce(private.user_age(new.user_id), 0) < private.cash_min_age() then
    raise exception 'Cash prizes are only for students aged % and over.', private.cash_min_age() using errcode = 'P0001';
  end if;
  return new;
end;
$$;
drop trigger if exists prize_claims_rules on public.prize_claims;
create trigger prize_claims_rules before insert on public.prize_claims
  for each row execute function private.prize_claim_rules();

-- Cash referral rewards: not created while off (the milestone is simply not paid); claims refused while off.
create or replace function private.referral_cash_rules() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if not private.cash_on() or coalesce(private.user_age(new.user_id), 0) < private.cash_min_age() then return null; end if;
    return new;
  end if;
  if new.status = 'claimed' and old.status = 'due' and not private.cash_on() then
    raise exception 'Cash rewards are switched off for now.' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
drop trigger if exists referral_rewards_cash_rules on public.referral_rewards;
create trigger referral_rewards_cash_rules before insert or update on public.referral_rewards
  for each row execute function private.referral_cash_rules();

-- XP packs: buying XP is refused while xp.buy_on is false.
create or replace function private.xp_buy_rules() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.xp_pack is not null and not coalesce((select (value ->> 'buy_on')::boolean from public.app_settings where key = 'xp'), false) then
    raise exception 'XP cannot be bought. Earn XP by practising every day, finishing tests and watching short videos.' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
drop trigger if exists payments_xp_buy_rules on public.payments;
create trigger payments_xp_buy_rules before insert on public.payments
  for each row execute function private.xp_buy_rules();
