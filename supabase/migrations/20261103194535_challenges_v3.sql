-- SolutionTee CBT · Challenges v3 (owner, D-074): same questions for everyone, random past questions with levels,
-- admin live leaderboard + analysis, copy a challenge, answer review after the close.

alter table public.challenges add column if not exists same_questions boolean not null default false;
comment on column public.challenges.same_questions is
  'Weekly mixed / one subject: true = every student who takes a subject gets the same questions for it (order still shuffled).';

/** Level of a past question: its saved level, else from how students did (20+ answers), else medium. */
create or replace function private.bank_level(p_question uuid)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select q.difficulty::text from public.questions q where q.id = p_question),
    (select case when r >= 0.75 then 'easy' when r >= 0.5 then 'medium' when r >= 0.25 then 'hard' else 'very_hard' end
       from (select avg(case when a.is_correct then 1.0 else 0.0 end) r, count(*) n
               from public.attempt_answers a where a.question_id = p_question) s where s.n >= 20),
    'medium');
$$;

-- The card now says whether everyone gets the same questions and whether answers can be reviewed.
create or replace function private.challenge_card(c public.challenges, p_uid uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'title', c.title, 'subtitle', c.subtitle, 'kind', c.kind, 'icon', c.icon, 'exam', c.exam_code,
    'mode', c.mode, 'subject', (select s.name from public.subjects s where s.id = c.subject_id), 'per_level', c.per_level,
    'same_questions', c.same_questions,
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
                                       'can_review', private.challenge_status(c) = 'ended' and e.status <> 'playing',
                                       'appeal', (select jsonb_build_object('status', a.status, 'note', a.admin_note, 'created_at', a.created_at)
                                                  from public.challenge_appeals a where a.entry_id = e.id))
             from public.challenge_entries e where e.challenge_id = c.id and e.user_id = p_uid));
$$;

-- Start: same_questions picks the same questions per subject for everyone (a hash of the challenge, not the student).
create or replace function public.challenge_start(p_id uuid, p_device text default null, p_device_flags text[] default '{}')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); c public.challenges; e record; v_ids uuid[]; v_subjects smallint[];
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
  insert into public.challenge_entries (challenge_id, user_id, question_order, device_hash, device_flags)
  values (p_id, v_uid, v_ids, left(p_device, 128), coalesce(p_device_flags[1:5], '{}'))
  returning * into e;
  return jsonb_build_object('status', 'playing', 'question', private.challenge_serve(e.id));
end;
$$;

/** Admin: copy random published past questions (Free years only, no passages or pictures) into the pool, with levels. */
create or replace function public.admin_challenge_add_random(p_id uuid, p_subjects smallint[], p_count integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.challenges; v_exam smallint; v_sid smallint; v_added integer; v_left integer; v_pos integer; v_out jsonb := '[]'::jsonb;
begin
  if not private.is_staff(array['super_admin', 'admin', 'editor']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into c from public.challenges where id = p_id;
  if not found then raise exception 'Unknown challenge' using errcode = 'P0002'; end if;
  if c.closed_at is not null then raise exception 'This challenge has ended.' using errcode = 'P0001'; end if;
  if exists (select 1 from public.challenge_entries e where e.challenge_id = p_id) then
    raise exception 'Students have started this challenge, so its questions cannot change.' using errcode = 'P0001';
  end if;
  if p_count is null or p_count < 1 or p_count > 500 then raise exception 'Choose 1 to 500 questions per subject.' using errcode = '22023'; end if;
  if coalesce(cardinality(p_subjects), 0) = 0 then raise exception 'Choose at least one subject.' using errcode = '22023'; end if;
  v_exam := (select b.id from public.exam_bodies b where b.code = c.exam_code);
  foreach v_sid in array p_subjects loop
    select coalesce(max(position), 0) into v_pos from public.challenge_questions where challenge_id = p_id;
    with pick as (
      select q.id, q.body, q.options, q.answer, q.explanation, q.subject_id
      from public.questions q
      where q.subject_id = v_sid and q.status = 'published' and q.deleted_at is null and q.passage_id is null and q.image_path is null
        and (v_exam is null or q.exam_id = v_exam)
        and q.answer in ('A', 'B', 'C', 'D') and q.options ?& array['A', 'B', 'C', 'D']
        and private.tier_year_open('free', q.exam_id, q.year, 'cbt')
        and not exists (select 1 from public.challenge_questions x where x.challenge_id = p_id and x.source_question_id = q.id)
      order by random() limit p_count),
    ins as (
      insert into public.challenge_questions (challenge_id, position, body, options, answer, explanation, source_question_id, subject_id, difficulty)
      select p_id, (v_pos + row_number() over ())::smallint, p.body,
             jsonb_build_object('A', p.options ->> 'A', 'B', p.options ->> 'B', 'C', p.options ->> 'C', 'D', p.options ->> 'D'),
             p.answer, p.explanation, p.id, p.subject_id, private.bank_level(p.id)
      from pick p returning 1)
    select count(*) into v_added from ins;
    select count(*) into v_left from public.questions q
      where q.subject_id = v_sid and q.status = 'published' and q.deleted_at is null and q.passage_id is null and q.image_path is null
        and (v_exam is null or q.exam_id = v_exam) and q.answer in ('A', 'B', 'C', 'D') and q.options ?& array['A', 'B', 'C', 'D']
        and private.tier_year_open('free', q.exam_id, q.year, 'cbt')
        and not exists (select 1 from public.challenge_questions x where x.challenge_id = p_id and x.source_question_id = q.id);
    v_out := v_out || jsonb_build_object('subject', (select s.name from public.subjects s where s.id = v_sid), 'added', v_added, 'left', v_left);
  end loop;
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), 'challenge.add_random', 'challenges', p_id::text, jsonb_build_object('subjects', to_jsonb(p_subjects), 'count', p_count, 'result', v_out));
  return v_out;
end;
$$;

/** Admin: change a pool question's level (before anyone starts). */
create or replace function public.admin_challenge_set_level(p_question uuid, p_level text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_ch uuid;
begin
  if not private.is_staff(array['super_admin', 'admin', 'editor']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  if p_level not in ('easy', 'medium', 'hard', 'very_hard') then raise exception 'Unknown level' using errcode = '22023'; end if;
  select challenge_id into v_ch from public.challenge_questions where id = p_question;
  if v_ch is null then raise exception 'Unknown question' using errcode = 'P0002'; end if;
  if exists (select 1 from public.challenge_entries e where e.challenge_id = v_ch) then
    raise exception 'Students have started this challenge, so its questions cannot change.' using errcode = 'P0001';
  end if;
  update public.challenge_questions set difficulty = p_level where id = p_question;
end;
$$;

/** Admin: copy a challenge (settings + questions) to new times, hidden from students until published. */
create or replace function public.admin_challenge_copy(p_id uuid, p_starts timestamptz)
returns uuid language plpgsql security definer set search_path = '' as $$
declare c public.challenges; v_new uuid;
begin
  if not private.is_staff(array['super_admin', 'admin', 'editor']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into c from public.challenges where id = p_id;
  if not found then raise exception 'Unknown challenge' using errcode = 'P0002'; end if;
  insert into public.challenges (title, subtitle, kind, icon, exam_code, starts_at, ends_at, seconds_per_question, prizes, reward_text,
                                 premium_days, premium_top, allowed_exits, published, created_by, mode, subject_id, per_level, same_questions)
  values (left(c.title || ' (copy)', 80), c.subtitle, c.kind, c.icon, c.exam_code, p_starts, p_starts + (c.ends_at - c.starts_at),
          c.seconds_per_question, c.prizes, c.reward_text, c.premium_days, c.premium_top, c.allowed_exits, false, (select auth.uid()),
          c.mode, c.subject_id, c.per_level, c.same_questions)
  returning id into v_new;
  insert into public.challenge_questions (challenge_id, position, body, options, answer, explanation, source_question_id, subject_id, difficulty)
  select v_new, q.position, q.body, q.options, q.answer, q.explanation, q.source_question_id, q.subject_id, q.difficulty
  from public.challenge_questions q where q.challenge_id = p_id;
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), 'challenge.copy', 'challenges', v_new::text, jsonb_build_object('from', p_id));
  return v_new;
end;
$$;

/** Admin: live leaderboard and analysis of one challenge (works while it runs and after). */
create or replace function public.admin_challenge_live(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare c public.challenges; v jsonb;
begin
  if not private.is_staff() then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into c from public.challenges where id = p_id;
  if not found then raise exception 'Unknown challenge' using errcode = 'P0002'; end if;
  with e as (
    select x.*, p.full_name, p.state,
           cardinality(x.question_order) as total,
           (select count(*) from public.challenge_answers a where a.entry_id = x.id and a.correct)::int as live_score,
           (select coalesce(sum(a.time_ms), 0) from public.challenge_answers a where a.entry_id = x.id)::int as live_ms
    from public.challenge_entries x join public.profiles p on p.id = x.user_id where x.challenge_id = p_id),
  ranked as (
    select e.*, case when e.status in ('playing', 'finished') and e.review is distinct from 'dq'
                     then rank() over (partition by (e.status in ('playing', 'finished') and e.review is distinct from 'dq')
                                       order by e.live_score desc, e.live_ms asc) end as live_rank
    from e),
  a as (
    select a.*, q.subject_id, q.difficulty, q.body, q.answer as right_answer
    from public.challenge_answers a join public.challenge_entries x on x.id = a.entry_id and x.challenge_id = p_id
    join public.challenge_questions q on q.id = a.question_id)
  select jsonb_build_object(
    'status', private.challenge_status(c),
    'summary', (select jsonb_build_object(
        'joined', count(*), 'playing', count(*) filter (where status = 'playing'), 'finished', count(*) filter (where status = 'finished'),
        'disqualified', count(*) filter (where status = 'disqualified' or review = 'dq'),
        'flagged', count(*) filter (where cardinality(flags) > 0),
        'appeals_pending', (select count(*) from public.challenge_appeals ap join public.challenge_entries y on y.id = ap.entry_id
                            where y.challenge_id = p_id and ap.status = 'pending'),
        'avg_pct', round(avg(100.0 * live_score / nullif(total, 0)) filter (where status = 'finished'), 1),
        'avg_ms', round(avg(live_ms) filter (where status = 'finished')),
        'best', max(live_score) filter (where status = 'finished')) from e),
    'board', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'rank', coalesce(r.rank, r.live_rank), 'name', r.full_name, 'state', r.state,
          'status', r.status, 'review', r.review, 'score', r.live_score, 'answered', r.current, 'total', r.total, 'time_ms', r.live_ms,
          'exits', r.exits, 'flags', to_jsonb(r.flags), 'dq_reason', r.dq_reason, 'prize', r.prize, 'started_at', r.started_at,
          'finished_at', r.finished_at)
        order by coalesce(r.rank, r.live_rank) nulls last, r.live_score desc, r.live_ms) from ranked r), '[]'::jsonb),
    'by_subject', coalesce((select jsonb_agg(jsonb_build_object('subject', coalesce(s.name, 'No subject'), 'answers', t.n, 'right_pct', t.pct) order by t.pct)
        from (select subject_id, count(*) n, round(100.0 * avg(case when correct then 1 else 0 end), 1) pct from a group by subject_id) t
        left join public.subjects s on s.id = t.subject_id), '[]'::jsonb),
    'by_level', coalesce((select jsonb_agg(jsonb_build_object('level', t.difficulty, 'answers', t.n, 'right_pct', t.pct, 'avg_ms', t.ms)
          order by array_position(array['easy', 'medium', 'hard', 'very_hard'], t.difficulty))
        from (select difficulty, count(*) n, round(100.0 * avg(case when correct then 1 else 0 end), 1) pct, round(avg(time_ms)) ms
              from a group by difficulty) t), '[]'::jsonb),
    'spread', (select jsonb_agg(jsonb_build_object('from', b * 10, 'students',
          (select count(*) from e where e.status = 'finished' and e.total > 0
             and least(floor(10.0 * e.live_score / e.total), 9) = b)) order by b) from generate_series(0, 9) b),
    'questions', coalesce((select jsonb_agg(t order by t.right_pct nulls last, t.answers desc) from (
        select q.id, left(q.body, 160) as body, s.name as subject, q.difficulty as level, q.answer,
               count(a.*) as answers, round(100.0 * avg(case when a.correct then 1 else 0 end), 1) as right_pct,
               round(avg(a.time_ms)) as avg_ms, count(a.*) filter (where a.choice is null) as no_answer,
               (select a2.choice from a a2 where a2.question_id = q.id and a2.choice is not null and a2.choice <> q.answer
                group by a2.choice order by count(*) desc limit 1) as top_wrong
        from public.challenge_questions q left join a on a.question_id = q.id left join public.subjects s on s.id = q.subject_id
        where q.challenge_id = p_id group by q.id, s.name order by 7 nulls last limit 200) t), '[]'::jsonb),
    'exits', coalesce((select jsonb_agg(jsonb_build_object('reason', t.r, 'students', t.n) order by t.n desc)
        from (select coalesce(dq_reason, 'Unknown') r, count(*) n from e where status = 'disqualified' group by 1) t), '[]'::jsonb),
    'students_per_subject', coalesce((select jsonb_object_agg(t.sid, t.n) from (
        select s.id sid, count(*) n from public.profiles p cross join lateral unnest(p.jamb_subjects) u(code)
        join public.subjects s on s.code = u.code where p.banned_at is null group by s.id) t), '{}'::jsonb),
    'paper_size', case when c.mode = 'fixed' then (select count(*) from public.challenge_questions q where q.challenge_id = p_id)
                       else (select coalesce(sum((value)::int), 0) from jsonb_each_text(c.per_level)) end
  ) into v;
  return v;
end;
$$;

/** Student: their own questions, answers and explanations — only after the challenge has ended. */
create or replace function public.challenge_review(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); c public.challenges; e record;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into c from public.challenges where id = p_id and published;
  if not found then raise exception 'This challenge is not available.' using errcode = 'P0002'; end if;
  if private.challenge_status(c) <> 'ended' then
    raise exception 'You can review your answers when the challenge ends.' using errcode = 'P0001';
  end if;
  select * into e from public.challenge_entries where challenge_id = p_id and user_id = v_uid;
  if not found then raise exception 'You did not take this challenge.' using errcode = 'P0002'; end if;
  return jsonb_build_object('title', c.title, 'score', e.score, 'total', cardinality(e.question_order), 'items', coalesce((
    select jsonb_agg(jsonb_build_object('n', o.n, 'body', q.body, 'options', q.options, 'answer', q.answer, 'explanation', q.explanation,
             'subject', s.name, 'level', q.difficulty, 'choice', a.choice, 'correct', coalesce(a.correct, false),
             'answered', a.question_id is not null, 'time_ms', a.time_ms) order by o.n)
    from unnest(e.question_order) with ordinality o(id, n)
    join public.challenge_questions q on q.id = o.id
    left join public.subjects s on s.id = q.subject_id
    left join public.challenge_answers a on a.entry_id = e.id and a.question_id = q.id), '[]'::jsonb));
end;
$$;

revoke execute on function private.bank_level(uuid) from public, anon, authenticated;
revoke execute on function public.admin_challenge_add_random(uuid, smallint[], integer), public.admin_challenge_set_level(uuid, text),
  public.admin_challenge_copy(uuid, timestamptz), public.admin_challenge_live(uuid), public.challenge_review(uuid) from public, anon;
grant execute on function public.admin_challenge_add_random(uuid, smallint[], integer), public.admin_challenge_set_level(uuid, text),
  public.admin_challenge_copy(uuid, timestamptz), public.admin_challenge_live(uuid), public.challenge_review(uuid) to authenticated;
