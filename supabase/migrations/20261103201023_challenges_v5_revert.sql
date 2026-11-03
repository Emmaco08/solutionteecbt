-- SolutionTee CBT · owner chose to block screen recording in the whole app instead (D-076): a recording report is a
-- fair-play flag again, not a disqualification (same as v4).
create or replace function public.challenge_report(p_entry uuid, p_what text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_flag text := case p_what when 'screenshot' then 'Tried to take a screenshot' when 'recording' then 'Screen recording was on' end;
begin
  if v_flag is null then raise exception 'Unknown report' using errcode = '22023'; end if;
  update public.challenge_entries
  set device_flags = case when v_flag = any (coalesce(device_flags, '{}')) then device_flags else array_append(device_flags, v_flag) end,
      flags = case when status = 'playing' or v_flag = any (flags) then flags else array_append(flags, v_flag) end
  where id = p_entry and user_id = (select auth.uid()) and coalesce(cardinality(device_flags), 0) < 10;
end;
$$;
