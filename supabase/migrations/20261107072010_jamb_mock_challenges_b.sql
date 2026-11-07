create or replace function private.mock_paper(p_entry uuid) returns jsonb
language sql stable security definer set search_path to '' as $$
  select jsonb_build_object(
    'entry_id', e.id, 'status', e.status, 'deadline', e.deadline, 'now', now(),
    'leaves', e.exits, 'away_ms', e.away_ms,
    'allowed_exits', c.allowed_exits, 'max_away_seconds', c.max_away_seconds, 'exit_action', c.exit_action,
    'allow_calculator', c.allow_calculator, 'title', c.title, 'exam_code', c.exam_code,
    'candidate', (select p.full_name from public.profiles p where p.id = e.user_id),
    'subjects', (
      select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'questions', (
        select coalesce(jsonb_agg(jsonb_build_object(
                 'id', q.id, 'number', q.number, 'body', q.body, 'options', q.options, 'section', q.section,
                 'passage_key', q.passage_key, 'passage_title', q.passage_title, 'passage_body', q.passage_body,
                 'image_path', q.image_path, 'choice', a.choice)
               order by array_position(e.question_order, q.id)), '[]')
        from public.challenge_questions q
        left join public.challenge_answers a on a.entry_id = e.id and a.question_id = q.id
        where q.id = any (e.question_order) and q.subject_id = s.id))
        order by array_position(e.subjects, s.id)), '[]')
      from public.subjects s where s.id = any (e.subjects)))
  from public.challenge_entries e join public.challenges c on c.id = e.challenge_id
  where e.id = p_entry;
$$;

create or replace function public.mock_submit(p_entry uuid)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare e public.challenge_entries; v_scores jsonb; v_total integer;
begin
  select * into e from public.challenge_entries where id = p_entry for update;
  if not found then raise exception 'Not found' using errcode = 'P0002'; end if;
  if (select auth.uid()) is not null and e.user_id <> (select auth.uid()) and not private.is_staff() then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  if e.status <> 'playing' then return jsonb_build_object('status', e.status, 'score', e.score); end if;
  update public.challenge_answers a set correct = (a.choice is not null and upper(a.choice) = upper(q.answer))
  from public.challenge_questions q where a.entry_id = p_entry and q.id = a.question_id;
  select jsonb_agg(jsonb_build_object('subject_id', s.sid, 'name', (select x.name from public.subjects x where x.id = s.sid),
                                      'total', s.total, 'correct', s.correct, 'score', round(100.0 * s.correct / nullif(s.total, 0))) order by array_position(e.subjects, s.sid)),
         sum(round(100.0 * s.correct / nullif(s.total, 0)))::int
    into v_scores, v_total
  from (select q.subject_id as sid, count(*) as total, count(*) filter (where a.correct) as correct
        from public.challenge_questions q
        left join public.challenge_answers a on a.entry_id = p_entry and a.question_id = q.id
        where q.id = any (e.question_order) group by q.subject_id) s;
  update public.challenge_entries set status = 'finished', finished_at = now(), score = coalesce(v_total, 0),
         subject_scores = v_scores, time_ms = (extract(epoch from (least(now(), deadline) - started_at)) * 1000)::int
  where id = p_entry;
  return jsonb_build_object('status', 'finished', 'score', coalesce(v_total, 0), 'subjects', v_scores);
end;
$$;

create or replace function public.mock_start(p_id uuid, p_device text default null, p_device_flags text[] default '{}')
returns jsonb language plpgsql security definer set search_path to '' as $$
declare v_uid uuid := (select auth.uid()); c public.challenges; e record; v_subjects smallint[]; v_ids uuid[]; v_eng smallint; v_min integer;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into c from public.challenges where id = p_id and published and style = 'jamb_mock';
  if not found then raise exception 'This mock exam is not available.' using errcode = 'P0002'; end if;
  if not private.mock_allowed(c, v_uid) then
    return jsonb_build_object('status', 'locked', 'need', c.access);
  end if;
  select * into e from public.challenge_entries where challenge_id = p_id and user_id = v_uid;
  if found then
    if e.status = 'playing' and (now() >= e.deadline or private.challenge_status(c) = 'ended') then
      perform public.mock_submit(e.id);
      return jsonb_build_object('status', 'finished');
    end if;
    if e.status = 'playing' then
      insert into public.challenge_events (entry_id, kind) values (e.id, 'resume');
      return jsonb_build_object('status', 'playing') || private.mock_paper(e.id);
    end if;
    return jsonb_build_object('status', e.status);
  end if;
  if private.challenge_status(c) <> 'live' then raise exception 'This mock exam is not live.' using errcode = 'P0001'; end if;
  if c.max_players is not null and (select count(*) from public.challenge_entries x where x.challenge_id = p_id) >= c.max_players then
    raise exception 'This mock exam is full.' using errcode = 'P0001';
  end if;
  select id into v_eng from public.subjects where name = 'Use of English';
  v_subjects := case
    when c.mock_subjects ? 'fixed' then array(select (x)::smallint from jsonb_array_elements_text(c.mock_subjects -> 'fixed') x)
    else (case when coalesce((c.mock_subjects ->> 'english')::boolean, true) then array[v_eng] else '{}' end)
         || array(select s from unnest(private.student_subjects(v_uid)) s where s <> v_eng) end;
  select array_agg(q.id order by array_position(v_subjects, q.subject_id), q.number nulls last, q.position)
    into v_ids from public.challenge_questions q where q.challenge_id = p_id and q.subject_id = any (v_subjects);
  if v_ids is null then raise exception 'This mock has no questions for your subjects yet. Choose your JAMB subjects in Me.' using errcode = 'P0001'; end if;
  v_min := coalesce(c.duration_minutes, 120);
  insert into public.challenge_entries (challenge_id, user_id, status, question_order, current, served_at, started_at, subjects, deadline, device_hash, device_flags, via)
  values (p_id, v_uid, 'playing', v_ids, 0, now(), now(), v_subjects, least(now() + make_interval(mins => v_min), c.ends_at), p_device, p_device_flags,
          (select a.via from public.challenge_access a where a.challenge_id = p_id and a.user_id = v_uid))
  returning * into e;
  return jsonb_build_object('status', 'playing') || private.mock_paper(e.id);
end;
$$;

create or replace function public.mock_save(p_entry uuid, p_question uuid, p_choice text, p_ms integer default 0)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare e public.challenge_entries;
begin
  select * into e from public.challenge_entries where id = p_entry and user_id = (select auth.uid());
  if not found or e.status <> 'playing' then return jsonb_build_object('ok', false, 'status', coalesce(e.status, 'missing')); end if;
  if now() > e.deadline + interval '15 seconds' then perform public.mock_submit(e.id); return jsonb_build_object('ok', false, 'status', 'finished'); end if;
  if not (p_question = any (e.question_order)) then return jsonb_build_object('ok', false); end if;
  insert into public.challenge_answers (entry_id, question_id, choice, correct, time_ms, answered_at)
  values (p_entry, p_question, nullif(upper(trim(p_choice)), ''), null, greatest(least(coalesce(p_ms, 0), 3600000), 0), now())
  on conflict (entry_id, question_id) do update set choice = excluded.choice, time_ms = public.challenge_answers.time_ms + excluded.time_ms, answered_at = now();
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.mock_event(p_entry uuid, p_kind text, p_ms integer default null)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare e public.challenge_entries; c public.challenges; v_over boolean := false;
begin
  select * into e from public.challenge_entries where id = p_entry and user_id = (select auth.uid()) for update;
  if not found or e.status <> 'playing' then return jsonb_build_object('status', coalesce(e.status, 'missing')); end if;
  select * into c from public.challenges where id = e.challenge_id;
  insert into public.challenge_events (entry_id, kind, ms) values (p_entry, p_kind, greatest(least(coalesce(p_ms, 0), 86400000), 0));
  if p_kind = 'leave' then
    update public.challenge_entries set exits = exits + 1 where id = p_entry returning * into e;
  elsif p_kind = 'return' then
    update public.challenge_entries set away_ms = away_ms + greatest(least(coalesce(p_ms, 0), 86400000), 0) where id = p_entry returning * into e;
  elsif p_kind in ('screenshot', 'copy') then
    update public.challenge_entries set flags = array(select distinct unnest(coalesce(flags, '{}') || p_kind)) where id = p_entry returning * into e;
  end if;
  v_over := (c.allowed_exits is not null and e.exits > c.allowed_exits)
         or (c.max_away_seconds is not null and e.away_ms > c.max_away_seconds * 1000);
  if v_over then
    update public.challenge_entries set flags = array(select distinct unnest(coalesce(flags, '{}') || 'left_too_much'::text)) where id = p_entry;
    if c.exit_action = 'submit' then
      insert into public.challenge_events (entry_id, kind) values (p_entry, 'auto_submit');
      perform public.mock_submit(p_entry);
      return jsonb_build_object('status', 'finished', 'reason', 'left_too_much');
    end if;
  end if;
  return jsonb_build_object('status', 'playing', 'leaves', e.exits, 'away_ms', e.away_ms, 'allowed_exits', c.allowed_exits,
                            'max_away_seconds', c.max_away_seconds, 'over', v_over);
end;
$$;

create or replace function public.mock_result(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare c public.challenges; e public.challenge_entries;
begin
  select * into c from public.challenges where id = p_id;
  select * into e from public.challenge_entries where challenge_id = p_id and user_id = (select auth.uid());
  if e.id is null then return jsonb_build_object('status', 'none'); end if;
  if e.status = 'playing' then return jsonb_build_object('status', 'playing'); end if;
  if c.results = 'hidden' or (c.results = 'after_end' and private.challenge_status(c) <> 'ended') then
    return jsonb_build_object('status', e.status, 'visible', false, 'when', c.results, 'ends_at', c.ends_at);
  end if;
  return jsonb_build_object('status', e.status, 'visible', true, 'score', e.score, 'subjects', e.subject_scores, 'rank', e.rank,
    'players', (select count(*) from public.challenge_entries x where x.challenge_id = p_id and x.status = 'finished'),
    'leaves', e.exits, 'away_ms', e.away_ms, 'time_ms', e.time_ms);
end;
$$;

create or replace function public.mock_analytics(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin', 'editor']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  return jsonb_build_object(
    'players', (select count(*) from public.challenge_entries e where e.challenge_id = p_id),
    'finished', (select count(*) from public.challenge_entries e where e.challenge_id = p_id and e.status = 'finished'),
    'average', (select round(avg(e.score)) from public.challenge_entries e where e.challenge_id = p_id and e.status = 'finished'),
    'leaderboard', (select coalesce(jsonb_agg(r order by r.score desc nulls last, r.time_ms), '[]') from (
        select e.id as entry_id, p.full_name as name, e.via, e.status, e.score, e.subject_scores, e.time_ms, e.exits as leaves,
               e.away_ms, e.flags, e.started_at, e.finished_at,
               (select count(*) from public.challenge_answers a where a.entry_id = e.id and a.choice is not null) as answered
        from public.challenge_entries e left join public.profiles p on p.id = e.user_id
        where e.challenge_id = p_id) r),
    'most_missed', (select coalesce(jsonb_agg(m order by m.missed_pct desc, m.attempts desc), '[]') from (
        select q.id, q.number, left(q.body, 160) as body, (select s.name from public.subjects s where s.id = q.subject_id) as subject,
               q.section, q.topic, q.answer, count(a.*) as attempts,
               round(100.0 * count(*) filter (where a.correct is false) / nullif(count(a.*), 0)) as missed_pct,
               round(avg(a.time_ms) / 1000.0) as avg_seconds,
               (select jsonb_object_agg(x.choice, x.n) from (select a2.choice, count(*) n from public.challenge_answers a2
                 where a2.question_id = q.id and a2.choice is not null group by a2.choice) x) as picks
        from public.challenge_questions q
        left join public.challenge_answers a on a.question_id = q.id and a.correct is not null
        where q.challenge_id = p_id group by q.id
        having count(a.*) > 0 limit 50) m),
    'by_topic', (select coalesce(jsonb_agg(t order by t.missed_pct desc), '[]') from (
        select (select s.name from public.subjects s where s.id = q.subject_id) as subject, coalesce(q.topic, q.section, 'Other') as topic,
               count(a.*) as answers, round(100.0 * count(*) filter (where a.correct is false) / nullif(count(a.*), 0)) as missed_pct
        from public.challenge_questions q join public.challenge_answers a on a.question_id = q.id and a.correct is not null
        where q.challenge_id = p_id group by 1, 2) t),
    'slowest', (select coalesce(jsonb_agg(s order by s.avg_seconds desc), '[]') from (
        select q.id, q.number, left(q.body, 120) as body, (select x.name from public.subjects x where x.id = q.subject_id) as subject,
               round(avg(a.time_ms) / 1000.0) as avg_seconds
        from public.challenge_questions q join public.challenge_answers a on a.question_id = q.id
        where q.challenge_id = p_id group by q.id order by 5 desc limit 15) s),
    'behaviour', (select jsonb_build_object(
        'left_screen', count(*) filter (where e.exits > 0), 'avg_leaves', round(avg(e.exits), 1),
        'avg_away_seconds', round(avg(e.away_ms) / 1000.0), 'flagged', count(*) filter (where cardinality(coalesce(e.flags, '{}')) > 0),
        'avg_minutes', round(avg(e.time_ms) / 60000.0))
        from public.challenge_entries e where e.challenge_id = p_id));
end;
$$;

create or replace function public.mock_timeline(p_entry uuid)
returns jsonb language sql stable security definer set search_path to '' as $$
  select case when private.is_staff(array['super_admin', 'admin', 'editor']::public.staff_role[]) then
    (select coalesce(jsonb_agg(jsonb_build_object('kind', kind, 'ms', ms, 'at', at) order by at), '[]') from public.challenge_events where entry_id = p_entry)
  end;
$$;

revoke execute on function public.challenge_set_code(uuid, text), public.challenge_make_invites(uuid, text[]), public.challenge_unlock(uuid, text),
  public.mock_start(uuid, text, text[]), public.mock_save(uuid, uuid, text, integer), public.mock_event(uuid, text, integer),
  public.mock_submit(uuid), public.mock_result(uuid), public.mock_analytics(uuid), public.mock_timeline(uuid) from public, anon;
grant execute on function public.challenge_set_code(uuid, text), public.challenge_make_invites(uuid, text[]), public.challenge_unlock(uuid, text),
  public.mock_start(uuid, text, text[]), public.mock_save(uuid, uuid, text, integer), public.mock_event(uuid, text, integer),
  public.mock_submit(uuid), public.mock_result(uuid), public.mock_analytics(uuid), public.mock_timeline(uuid) to authenticated;
revoke all on function private.mock_paper(uuid), private.mock_allowed(public.challenges, uuid), private.code_hash(uuid, text) from public, anon, authenticated;

create or replace function private.mock_tick() returns void
language plpgsql security definer set search_path to '' as $$
declare r record;
begin
  for r in select e.id from public.challenge_entries e join public.challenges c on c.id = e.challenge_id
           where c.style = 'jamb_mock' and e.status = 'playing' and now() > e.deadline + interval '30 seconds' loop
    perform public.mock_submit(r.id);
  end loop;
  update public.challenge_entries e set rank = x.rk
  from (select e2.id, rank() over (partition by e2.challenge_id order by e2.score desc, e2.time_ms) as rk
        from public.challenge_entries e2 join public.challenges c on c.id = e2.challenge_id
        where c.style = 'jamb_mock' and e2.status = 'finished') x
  where e.id = x.id and e.rank is distinct from x.rk;
end;
$$;
select cron.schedule('mock-tick', '* * * * *', $c$ select private.mock_tick(); $c$);
