-- Challenges v3 fix: a question nobody answered has no % right (not 0%).
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
               count(a.*) as answers, round(100.0 * avg(case when a.correct then 1.0 when not a.correct then 0.0 end), 1) as right_pct,
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

