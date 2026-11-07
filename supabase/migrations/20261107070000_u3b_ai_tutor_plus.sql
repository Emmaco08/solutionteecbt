-- U3b (docs/plans/u3b-ai-tutor-plus.md, D-097): year papers, AI-made questions, reactions, "most missed" topics.

-- Questions the AI wrote for one student. Answers stay here; only the Edge Function (service role) reads them.
create table if not exists public.ai_gen_questions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  chat_id uuid references public.ai_chats (id) on delete set null,
  subject text,
  topic text,
  body text not null,
  options jsonb not null,
  answer text not null,
  explanation text,
  created_at timestamptz not null default now()
);
create index if not exists ai_gen_questions_user on public.ai_gen_questions (user_id, created_at desc);
alter table public.ai_gen_questions enable row level security;
create policy "admins read" on public.ai_gen_questions for select to authenticated using (private.is_staff(array['super_admin', 'admin']::public.staff_role[]));

-- A reaction on a tutor answer (❤️ 👍 😂 😮 🙏 👎), also feedback for the admin.
alter table public.ai_messages add column if not exists reaction text check (reaction is null or char_length(reaction) <= 8);
create or replace function public.ai_react(p_message uuid, p_reaction text)
returns void language plpgsql security definer set search_path to '' as $$
begin
  if p_reaction is not null and p_reaction not in ('❤️', '👍', '😂', '😮', '🙏', '👎') then raise exception 'Bad reaction' using errcode = '22023'; end if;
  update public.ai_messages set reaction = p_reaction
  where id = p_message and user_id = (select auth.uid()) and role = 'assistant';
end;
$$;
revoke execute on function public.ai_react(uuid, text) from public, anon;
grant execute on function public.ai_react(uuid, text) to authenticated;

-- Like ai_pick, with an optional year ("JAMB 2004 Physics"). Runs as the student, so the plan's year rules apply.
create or replace function public.ai_pick2(p_subject smallint, p_topic text default null, p_difficulty text default null,
                                           p_count integer default 10, p_for text default 'test', p_year smallint default null,
                                           p_exam text default null)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_exams smallint[];
  v_topics integer[];
  v_open record;
  v_count integer := least(greatest(coalesce(p_count, 10), 1), case when p_for = 'quiz' then 10 else 60 end);
  v_pairs text[] := '{}';
  v_any_year boolean := false;
  v_out jsonb;
begin
  if v_uid is null or private.is_banned(v_uid) then return jsonb_build_object('ok', false, 'why', 'login'); end if;
  select array_agg(e.id order by case when upper(e.code) = upper(coalesce(p_exam, '')) then 0 else 1 end,
                   coalesce(array_position(p.target_exams, e.code), 99), e.sort) into v_exams
  from public.exam_bodies e left join public.profiles p on p.id = v_uid
  where e.is_active and (p_exam is null or upper(e.code) = upper(p_exam));
  if v_exams is null then return jsonb_build_object('ok', false, 'why', 'no_exam'); end if;
  for v_open in
    select distinct y.exam_id, y.year from public.exam_years y
    where y.subject_id = p_subject and y.status = 'published' and y.exam_id = any (v_exams)
      and (p_year is null or y.year = p_year)
  loop
    v_any_year := true;
    if private.year_open(v_open.exam_id, v_open.year, 'cbt') then v_pairs := v_pairs || (v_open.exam_id || ':' || v_open.year); end if;
  end loop;
  if cardinality(v_pairs) = 0 then
    return jsonb_build_object('ok', false, 'why', case when p_year is not null and v_any_year then 'locked_year'
                                                       when p_year is not null then 'no_year' else 'no_open_years' end);
  end if;
  v_topics := case when coalesce(trim(p_topic), '') = '' then null else private.ai_topics_like(p_subject, p_topic) end;
  if v_topics is not null and cardinality(v_topics) = 0 then return jsonb_build_object('ok', false, 'why', 'no_topic'); end if;

  with pool as (
    select x.id, x.exam_id, x.year, x.number, x.body, x.options, x.topic_id, x.difficulty,
           array_position(v_exams, x.exam_id) as exam_rank
    from public.questions x
    where x.subject_id = p_subject and x.status = 'published' and x.deleted_at is null
      and (x.exam_id || ':' || x.year) = any (v_pairs)
      and (v_topics is null or x.topic_id = any (v_topics))
      and (p_difficulty is null or p_difficulty not in ('easy', 'medium', 'hard') or x.difficulty::text = p_difficulty)
      and (p_for <> 'quiz' or (x.passage_id is null and x.image_path is null))
  ),
  best_exam as (select exam_id from pool group by exam_id order by min(exam_rank) limit 1),
  picked as (
    select * from pool where exam_id = (select exam_id from best_exam)
    order by case when p_year is not null and p_for = 'test' then coalesce(number, 999) end, random()
    limit v_count
  )
  select jsonb_build_object(
    'ok', count(*) > 0, 'why', case when count(*) = 0 then 'none' end,
    'exam_id', min(exam_id), 'exam', (select e.code from public.exam_bodies e where e.id = min(picked.exam_id)),
    'subject_id', p_subject, 'subject', (select s.name from public.subjects s where s.id = p_subject),
    'topics', (select coalesce(jsonb_agg(distinct t.name), '[]') from public.topics t where t.id in (select topic_id from picked)),
    'years', coalesce(jsonb_agg(distinct year), '[]'),
    'available', (select count(*) from pool where exam_id = (select exam_id from best_exam)),
    'ids', case when p_for = 'test' then coalesce(jsonb_agg(id order by number), '[]') end,
    'questions', case when p_for = 'quiz' then coalesce(jsonb_agg(jsonb_build_object('id', id, 'body', body, 'options', options, 'year', year)), '[]') end)
    into v_out from picked;
  return v_out;
end;
$$;
revoke execute on function public.ai_pick2(smallint, text, text, integer, text, smallint, text) from public, anon;
grant execute on function public.ai_pick2(smallint, text, text, integer, text, smallint, text) to authenticated;

-- The topics most students got wrong in the last 7 days (counts only, no names), for curious suggestions.
create or replace function public.ai_most_missed(p_subjects smallint[] default null, p_limit integer default 3)
returns jsonb language sql stable security definer set search_path to '' as $$
  select coalesce(jsonb_agg(x), '[]') from (
    select s.name as subject, t.name as topic, round(100.0 * count(*) filter (where not aa.is_correct) / count(*)) as missed_pct
    from public.attempts a
    join public.attempt_answers aa on aa.attempt_id = a.id and aa.choice is not null
    join public.questions q on q.id = aa.question_id
    join public.topics t on t.id = q.topic_id
    join public.subjects s on s.id = q.subject_id
    where a.status = 'submitted' and a.submitted_at > now() - interval '7 days'
      and (p_subjects is null or q.subject_id = any (p_subjects))
    group by s.name, t.name
    having count(*) >= 20 and count(distinct a.user_id) >= 3
    order by 3 desc
    limit least(greatest(coalesce(p_limit, 3), 1), 10)
  ) x;
$$;
revoke execute on function public.ai_most_missed(smallint[], integer) from public, anon, authenticated;
grant execute on function public.ai_most_missed(smallint[], integer) to service_role;

-- Send due push notifications now (instead of waiting up to 5 minutes for pg_cron), e.g. "Your AI answer is ready".
-- (applied as migration u3b_push_kick)
create or replace function public.push_kick() returns void
language sql security definer set search_path to '' as $$
  select null::void from (select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/push',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-token', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_token')),
    body := '{"run":"due"}'::jsonb,
    timeout_milliseconds := 30000)) x;
$$;
revoke execute on function public.push_kick() from public, anon, authenticated;
grant execute on function public.push_kick() to service_role;
