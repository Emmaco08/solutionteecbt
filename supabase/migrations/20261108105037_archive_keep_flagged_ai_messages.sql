-- Flagged AI messages stay on Supabase for 90 days after the flag, so the admin AI safety page still lists them.
-- A batch of rows old enough to move. Returns {"rows": [...], "keys": [...]}.
create or replace function public.archive_take(p_kind text, p_limit integer default 2000) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_lim integer := least(greatest(coalesce(p_limit, 2000), 1), 5000); r jsonb;
begin
  if p_kind = 'audit' then
    select jsonb_build_object('rows', coalesce(jsonb_agg(to_jsonb(x)), '[]'), 'keys', coalesce(jsonb_agg(x.id), '[]')) into r
    from (select * from public.audit_log where at < now() - make_interval(days => private.archive_days('audit_days', 30)) order by id limit v_lim) x;
  elsif p_kind = 'payment_events' then
    select jsonb_build_object('rows', coalesce(jsonb_agg(to_jsonb(x)), '[]'), 'keys', coalesce(jsonb_agg(x.id), '[]')) into r
    from (select * from public.payment_events where created_at < now() - make_interval(days => private.archive_days('payment_events_days', 365)) order by id limit v_lim) x;
  elsif p_kind = 'ai_calls' then
    select jsonb_build_object('rows', coalesce(jsonb_agg(to_jsonb(x)), '[]'), 'keys', coalesce(jsonb_agg(x.id), '[]')) into r
    from (select * from public.ai_calls where at < now() - make_interval(days => private.archive_days('ai_calls_days', 30)) order by id limit v_lim) x;
  elsif p_kind = 'ai_messages' then
    select jsonb_build_object('rows', coalesce(jsonb_agg(to_jsonb(x)), '[]'), 'keys', coalesce(jsonb_agg(x.id), '[]')) into r
    from (select * from public.ai_messages where created_at < now() - make_interval(days => private.archive_days('chats_days', 14))
            and (flagged_at is null or flagged_at < now() - interval '90 days') order by created_at limit v_lim) x;
  elsif p_kind = 'attempt_answers' then
    -- Whole tests at a time (the score summary stays on Supabase in attempts).
    with t as (select a.id, a.user_id, a.submitted_at from public.attempts a
               where a.submitted_at < now() - make_interval(days => private.archive_days('answers_days', 14))
                 and exists (select 1 from public.attempt_answers aa where aa.attempt_id = a.id)
               order by a.submitted_at limit greatest(v_lim / 60, 1))
    select jsonb_build_object(
      'rows', coalesce((select jsonb_agg(to_jsonb(aa) || jsonb_build_object('user_id', t.user_id, 'submitted_at', t.submitted_at))
                        from public.attempt_answers aa join t on t.id = aa.attempt_id), '[]'),
      'keys', coalesce((select jsonb_agg(t.id) from t), '[]')) into r;
  elsif p_kind = 'challenge_answers' then
    -- Whole entries whose last answer is older than the window (prizes and appeals are long settled by then).
    with e as (select ca.entry_id, max(ca.answered_at) last_at from public.challenge_answers ca group by ca.entry_id
               having max(ca.answered_at) < now() - make_interval(days => private.archive_days('challenge_days', 60))
               order by 2 limit greatest(v_lim / 50, 1))
    select jsonb_build_object(
      'rows', coalesce((select jsonb_agg(to_jsonb(ca) || jsonb_build_object('user_id', ce.user_id))
                        from public.challenge_answers ca join e on e.entry_id = ca.entry_id
                        left join public.challenge_entries ce on ce.id = ca.entry_id), '[]'),
      'keys', coalesce((select jsonb_agg(e.entry_id) from e), '[]')) into r;
  elsif p_kind = 'ad_rewards' then
    -- Never rewards still in use (an unlock that has not expired, or a pending one).
    select jsonb_build_object('rows', coalesce(jsonb_agg(to_jsonb(x)), '[]'), 'keys', coalesce(jsonb_agg(x.id), '[]')) into r
    from (select * from public.ad_rewards where created_at < now() - make_interval(days => private.archive_days('ad_days', 90))
            and status <> 'pending' and (expires_at is null or expires_at < now()) order by created_at limit v_lim) x;
  elsif p_kind = 'ad_daily' then
    select jsonb_build_object('rows', coalesce(jsonb_agg(to_jsonb(x)), '[]'),
                              'keys', coalesce(jsonb_agg(jsonb_build_object('day', x.day, 'format', x.format, 'placement', x.placement)), '[]')) into r
    from (select * from public.ad_daily where day < (now() - make_interval(days => private.archive_days('ad_days', 90)))::date limit v_lim) x;
  else
    raise exception 'unknown kind %', p_kind;
  end if;
  return r;
end;
$$;
