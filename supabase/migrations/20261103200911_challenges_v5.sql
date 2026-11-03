-- SolutionTee CBT · Challenges v5 (owner, D-076): screen recording during a challenge disqualifies the entry
-- (Android 15+ tells the app). A screenshot attempt stays a fair-play flag.
create or replace function public.challenge_report(p_entry uuid, p_what text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_flag text := case p_what when 'screenshot' then 'Tried to take a screenshot' when 'recording' then 'Screen recording was on' end;
        e record;
begin
  if v_flag is null then raise exception 'Unknown report' using errcode = '22023'; end if;
  select * into e from public.challenge_entries where id = p_entry and user_id = (select auth.uid()) for update;
  if not found then return; end if;
  if coalesce(cardinality(e.device_flags), 0) < 10 and not (v_flag = any (coalesce(e.device_flags, '{}'))) then
    update public.challenge_entries set device_flags = array_append(device_flags, v_flag) where id = e.id;
  end if;
  if e.status = 'playing' and p_what = 'recording' then
    perform private.challenge_finish(e.id, 'disqualified', 'Screen recording was turned on during the challenge');
  elsif e.status <> 'playing' and not (v_flag = any (coalesce(e.flags, '{}'))) then
    update public.challenge_entries set flags = array_append(flags, v_flag) where id = e.id;
  end if;
end;
$$;
