-- Same as in 20261103172950_challenges.sql (text[] || unknown literal failed).
create or replace function private.challenge_finish(p_entry uuid, p_status text, p_reason text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare e record; v_avg numeric; v_sd numeric; v_n integer; v_flags text[] := '{}';
begin
  select * into e from public.challenge_entries where id = p_entry for update;
  if e.status <> 'playing' then return; end if;
  select count(*), avg(a.time_ms), stddev_pop(a.time_ms) into v_n, v_avg, v_sd
  from public.challenge_answers a where a.entry_id = p_entry and a.choice is not null;
  if v_n >= 3 and v_avg < 2000 then v_flags := array_append(v_flags, 'Answers under 2 seconds on average'::text); end if;
  if v_n >= 5 and v_sd < 250 then v_flags := array_append(v_flags, 'Answer times almost the same every time'::text); end if;
  if e.device_hash is not null and exists (select 1 from public.challenge_entries x where x.challenge_id = e.challenge_id
       and x.device_hash = e.device_hash and x.user_id <> e.user_id) then
    v_flags := array_append(v_flags, 'Same phone as another entry'::text);
  end if;
  if cardinality(e.device_flags) > 0 then v_flags := v_flags || e.device_flags; end if;
  update public.challenge_entries
  set status = p_status, finished_at = now(), dq_reason = p_reason, served_at = null, flags = v_flags,
      score = (select count(*) from public.challenge_answers a where a.entry_id = p_entry and a.correct),
      time_ms = (select coalesce(sum(a.time_ms), 0) from public.challenge_answers a where a.entry_id = p_entry)
  where id = p_entry;
end;
$$;

revoke execute on function private.challenge_finish(uuid, text, text) from public, anon, authenticated;
