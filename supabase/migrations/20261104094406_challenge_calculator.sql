-- D-085 (owner): the admin decides per challenge whether students can use the in-app calculator.
alter table public.challenges add column if not exists allow_calculator boolean not null default false;
comment on column public.challenges.allow_calculator is 'Students may open the calculator during this challenge.';

create or replace function private.challenge_card(c public.challenges, p_uid uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'title', c.title, 'subtitle', c.subtitle, 'kind', c.kind, 'icon', c.icon, 'exam', c.exam_code,
    'mode', c.mode, 'subject', (select s.name from public.subjects s where s.id = c.subject_id), 'per_level', c.per_level,
    'same_questions', c.same_questions, 'allow_review', c.allow_review,
    'xp_fee', case when coalesce((private.xp_settings() ->> 'enabled')::boolean, true) then c.xp_fee else 0 end,
    'xp_earned_only', c.kind = 'cash',
    'calculator', c.allow_calculator,
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
