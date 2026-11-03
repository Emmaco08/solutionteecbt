-- Same as in 20261103172950_challenges.sql (the first version declared c as record).
create or replace function public.challenge_answer(p_entry uuid, p_question uuid, p_choice text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); e record; c public.challenges; q record; v_ms integer; v_late boolean;
begin
  select * into e from public.challenge_entries where id = p_entry and user_id = v_uid for update;
  if not found then raise exception 'Not allowed' using errcode = '42501'; end if;
  if e.status <> 'playing' then return jsonb_build_object('status', e.status); end if;
  select * into c from public.challenges where id = e.challenge_id;
  if private.challenge_status(c) = 'ended' then
    perform private.challenge_finish(e.id, 'finished');
    return jsonb_build_object('status', 'finished');
  end if;
  if p_question is distinct from e.question_order[e.current + 1] then
    -- An old or a future question: just send the current one again.
    return jsonb_build_object('status', 'playing', 'question', private.challenge_serve(e.id));
  end if;
  select * into q from public.challenge_questions where id = p_question;
  v_ms := greatest(0, least(extract(epoch from (now() - coalesce(e.served_at, now()))) * 1000, c.seconds_per_question * 1000))::int;
  v_late := now() > coalesce(e.served_at, now()) + make_interval(secs => c.seconds_per_question + 3);
  insert into public.challenge_answers (entry_id, question_id, choice, correct, time_ms)
  values (e.id, q.id, case when v_late or p_choice is null or not (q.options ? p_choice) then null else p_choice end,
          not v_late and p_choice is not null and p_choice = q.answer, v_ms)
  on conflict (entry_id, question_id) do nothing;
  update public.challenge_entries set current = current + 1, served_at = null where id = e.id;
  if e.current + 1 >= cardinality(e.question_order) then
    perform private.challenge_finish(e.id, 'finished');
    return jsonb_build_object('status', 'finished');
  end if;
  return jsonb_build_object('status', 'playing', 'question', private.challenge_serve(e.id));
end;
$$;

