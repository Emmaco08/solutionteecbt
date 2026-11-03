-- SolutionTee CBT · Challenges v4 (owner, D-075): the admin decides per challenge whether students may review their
-- answers after it ends; screenshot / screen-recording attempts during a challenge become fair-play flags.

alter table public.challenges add column if not exists allow_review boolean not null default true;
comment on column public.challenges.allow_review is 'After the end, students may see their questions, answers and explanations.';

create or replace function private.challenge_card(c public.challenges, p_uid uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'title', c.title, 'subtitle', c.subtitle, 'kind', c.kind, 'icon', c.icon, 'exam', c.exam_code,
    'mode', c.mode, 'subject', (select s.name from public.subjects s where s.id = c.subject_id), 'per_level', c.per_level,
    'same_questions', c.same_questions, 'allow_review', c.allow_review,
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
                                       'can_review', c.allow_review and private.challenge_status(c) = 'ended' and e.status <> 'playing',
                                       'appeal', (select jsonb_build_object('status', a.status, 'note', a.admin_note, 'created_at', a.created_at)
                                                  from public.challenge_appeals a where a.entry_id = e.id))
             from public.challenge_entries e where e.challenge_id = c.id and e.user_id = p_uid));
$$;

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
  if not c.allow_review then
    raise exception 'Answer review is turned off for this challenge.' using errcode = 'P0001';
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

/** Admin: turn answer review on or off for one challenge (any time, also after it ends). */
create or replace function public.admin_challenge_set_review(p_id uuid, p_on boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_staff(array['super_admin', 'admin', 'editor']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  update public.challenges set allow_review = coalesce(p_on, false) where id = p_id;
  if not found then raise exception 'Unknown challenge' using errcode = 'P0002'; end if;
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), 'challenge.allow_review', 'challenges', p_id::text, jsonb_build_object('allow_review', p_on));
end;
$$;

/** The phone reports a screenshot or screen recording during a challenge: a fair-play flag for review (not a disqualification). */
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

revoke execute on function public.admin_challenge_set_review(uuid, boolean), public.challenge_report(uuid, text) from public, anon;
grant execute on function public.admin_challenge_set_review(uuid, boolean), public.challenge_report(uuid, text) to authenticated;
