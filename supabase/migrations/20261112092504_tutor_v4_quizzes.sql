-- Tutor quizzes (D-154): a tutor sets a quiz for their student (random past questions, their own questions, or both);
-- the student sees it in the chat, on Home and in Test, takes it in the app; the tutor sees the score and every miss.
create table if not exists public.tutor_quizzes (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.tutor_requests(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  title text not null check (char_length(title) between 2 and 120),
  note text check (char_length(note) <= 500),
  minutes smallint check (minutes between 1 and 180),
  due_at timestamptz,
  subject_id smallint references public.subjects(id),
  created_at timestamptz not null default now(),
  closed_at timestamptz
);
create index if not exists tutor_quizzes_req on public.tutor_quizzes(request_id, created_at desc);

create table if not exists public.tutor_quiz_questions (
  id bigint generated always as identity primary key,
  quiz_id uuid not null references public.tutor_quizzes(id) on delete cascade,
  sort smallint not null,
  question_id uuid references public.questions(id) on delete set null,
  body text not null check (char_length(body) between 2 and 4000),
  options jsonb not null,
  answer text not null check (answer in ('A', 'B', 'C', 'D', 'E')),
  explanation text check (char_length(explanation) <= 4000)
);
create index if not exists tutor_quiz_questions_quiz on public.tutor_quiz_questions(quiz_id, sort);

create table if not exists public.tutor_quiz_attempts (
  quiz_id uuid not null references public.tutor_quizzes(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  answers jsonb not null default '{}'::jsonb,
  score integer, total integer,
  primary key (quiz_id, user_id)
);
alter table public.tutor_quizzes enable row level security;
alter table public.tutor_quiz_questions enable row level security;
alter table public.tutor_quiz_attempts enable row level security;
-- Everything goes through the functions below (answers never reach the app before the quiz is submitted).

/** Student-facing summary of one quiz. */
create or replace function private.tutor_quiz_json(q public.tutor_quizzes, p_uid uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', q.id, 'request_id', q.request_id, 'title', q.title, 'note', q.note, 'minutes', q.minutes, 'due_at', q.due_at,
    'created_at', q.created_at, 'closed', q.closed_at is not null,
    'count', (select count(*) from public.tutor_quiz_questions x where x.quiz_id = q.id),
    'subject', (select s.name from public.subjects s where s.id = q.subject_id),
    'tutor', (select t.name from public.tutor_requests r join public.tutors t on t.id = r.tutor_id where r.id = q.request_id),
    'tutor_photo', (select t.photo_path from public.tutor_requests r join public.tutors t on t.id = r.tutor_id where r.id = q.request_id),
    'started_at', a.started_at, 'submitted_at', a.submitted_at, 'score', a.score, 'total', a.total,
    'state', case when a.submitted_at is not null then 'done' when a.started_at is not null then 'started' when q.closed_at is not null then 'closed' else 'new' end)
  from (select 1) one left join public.tutor_quiz_attempts a on a.quiz_id = q.id and a.user_id = p_uid;
$$;

create or replace function public.tutor_quiz_create(p_request uuid, p_title text, p_note text default null, p_minutes integer default null,
  p_due timestamptz default null, p_pq jsonb default null, p_custom jsonb default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare r public.tutor_requests; v_id uuid; v_sort integer := 0; v_subject smallint; v_count integer; q record; c jsonb; v_keys text[];
  v_n integer; v_send jsonb;
begin
  select * into r from public.tutor_requests where id = p_request;
  if not found or not (private.is_tutor_of(r.id) or private.tutor_staff()) then raise exception 'not allowed' using errcode = '42501'; end if;
  if r.status <> 'matched' and not private.tutor_staff() then return jsonb_build_object('ok', false, 'error', 'not_active'); end if;
  if char_length(btrim(coalesce(p_title, ''))) < 2 then return jsonb_build_object('ok', false, 'error', 'title'); end if;
  if (select count(*) from public.tutor_quizzes x where x.request_id = r.id and x.created_at > now() - interval '1 day') >= 20 then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  v_subject := nullif(p_pq ->> 'subject_id', '')::smallint;
  insert into public.tutor_quizzes (request_id, created_by, title, note, minutes, due_at, subject_id)
  values (r.id, (select auth.uid()), left(btrim(p_title), 120), nullif(left(btrim(coalesce(p_note, '')), 500), ''),
          case when p_minutes between 1 and 180 then p_minutes end, p_due, v_subject)
  returning id into v_id;

  -- Random past questions (text only: no passage or picture), from one subject and optional years.
  if p_pq is not null and v_subject is not null then
    v_count := least(greatest(coalesce((p_pq ->> 'count')::integer, 10), 1), 50);
    for q in select x.id, x.body, x.options, x.answer, x.explanation from public.questions x
             where x.subject_id = v_subject and x.status::text = 'published' and x.deleted_at is null and x.passage_id is null
               and x.image_path is null and x.answer in ('A', 'B', 'C', 'D', 'E') and jsonb_typeof(x.options) = 'object'
               and (p_pq -> 'year_from' is null or x.year >= (p_pq ->> 'year_from')::smallint)
               and (p_pq -> 'year_to' is null or x.year <= (p_pq ->> 'year_to')::smallint)
               and (p_pq -> 'exam_id' is null or x.exam_id = (p_pq ->> 'exam_id')::smallint)
             order by random() limit v_count loop
      v_sort := v_sort + 1;
      insert into public.tutor_quiz_questions (quiz_id, sort, question_id, body, options, answer, explanation)
      values (v_id, v_sort, q.id, q.body, q.options, q.answer, q.explanation);
    end loop;
  end if;

  -- The tutor's own questions: [{body, options: {A: …, B: …}, answer: "B", explanation}].
  if jsonb_typeof(p_custom) = 'array' then
    for c in select * from jsonb_array_elements(p_custom) loop
      select array_agg(k order by k) into v_keys from jsonb_object_keys(coalesce(c -> 'options', '{}'::jsonb)) k;
      if char_length(btrim(coalesce(c ->> 'body', ''))) < 2 or coalesce(cardinality(v_keys), 0) < 2 or not (v_keys <@ array['A', 'B', 'C', 'D', 'E'])
         or not ((c ->> 'answer') = any(v_keys)) then
        raise exception 'question %: needs a question, 2 to 5 options and the right answer', v_sort + 1 using errcode = '22023';
      end if;
      v_sort := v_sort + 1;
      insert into public.tutor_quiz_questions (quiz_id, sort, body, options, answer, explanation)
      values (v_id, v_sort, left(btrim(c ->> 'body'), 4000), c -> 'options', c ->> 'answer', nullif(left(btrim(coalesce(c ->> 'explanation', '')), 4000), ''));
    end loop;
  end if;

  select count(*) into v_n from public.tutor_quiz_questions where quiz_id = v_id;
  if v_n = 0 then raise exception 'no questions' using errcode = '22023'; end if;
  if v_n > 80 then raise exception 'too many questions' using errcode = '22023'; end if;

  -- The quiz card in the chat (the student taps it to start).
  v_send := public.tutor_message_send(r.id, left(btrim(p_title), 120), 'ref', null, null,
    jsonb_build_object('type', 'quiz', 'id', v_id, 'title', left(btrim(p_title), 120), 'count', v_n, 'minutes', p_minutes, 'due_at', p_due,
                       'snippet', v_n || ' question' || case when v_n = 1 then '' else 's' end || case when p_minutes between 1 and 180 then ' · ' || p_minutes || ' min' else '' end));
  return jsonb_build_object('ok', true, 'id', v_id, 'count', v_n);
exception when sqlstate '22023' then
  return jsonb_build_object('ok', false, 'error', sqlerrm);
end $$;

/** The student's quizzes, newest first (Home, Test and the chat). */
create or replace function public.tutor_quizzes_mine()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(private.tutor_quiz_json(q, (select auth.uid())) order by q.created_at desc), '[]'::jsonb)
  from public.tutor_quizzes q join public.tutor_requests r on r.id = q.request_id
  where r.user_id = (select auth.uid()) and q.created_at > now() - interval '180 days';
$$;

/** Start (or open again) a quiz: the questions without answers, or the full review once submitted. */
create or replace function public.tutor_quiz_start(p_quiz uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare q public.tutor_quizzes; r public.tutor_requests; a public.tutor_quiz_attempts; v_uid uuid := (select auth.uid());
begin
  select * into q from public.tutor_quizzes where id = p_quiz;
  select * into r from public.tutor_requests where id = q.request_id;
  if q.id is null or r.user_id is distinct from v_uid then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into a from public.tutor_quiz_attempts where quiz_id = q.id and user_id = v_uid;
  if a.submitted_at is not null then return public.tutor_quiz_review(q.id, v_uid); end if;
  if q.closed_at is not null then return jsonb_build_object('ok', false, 'error', 'closed'); end if;
  if a.quiz_id is null then
    insert into public.tutor_quiz_attempts (quiz_id, user_id) values (q.id, v_uid) returning * into a;
  end if;
  return jsonb_build_object('ok', true, 'quiz', private.tutor_quiz_json(q, v_uid), 'started_at', a.started_at, 'answers', a.answers,
    'questions', (select jsonb_agg(jsonb_build_object('id', x.id, 'body', x.body, 'options', x.options) order by x.sort)
                  from public.tutor_quiz_questions x where x.quiz_id = q.id));
end $$;

/** Save progress (answers so far) without submitting. */
create or replace function public.tutor_quiz_save(p_quiz uuid, p_answers jsonb)
returns jsonb language sql security definer set search_path = '' as $$
  update public.tutor_quiz_attempts set answers = coalesce(p_answers, '{}'::jsonb)
  where quiz_id = p_quiz and user_id = (select auth.uid()) and submitted_at is null and jsonb_typeof(p_answers) = 'object'
  returning jsonb_build_object('ok', true);
$$;

create or replace function public.tutor_quiz_submit(p_quiz uuid, p_answers jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare q public.tutor_quizzes; r public.tutor_requests; a public.tutor_quiz_attempts; v_uid uuid := (select auth.uid()); v_score integer; v_total integer;
  t public.tutors;
begin
  select * into q from public.tutor_quizzes where id = p_quiz;
  select * into r from public.tutor_requests where id = q.request_id;
  if q.id is null or r.user_id is distinct from v_uid then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into a from public.tutor_quiz_attempts where quiz_id = q.id and user_id = v_uid for update;
  if a.quiz_id is null then return jsonb_build_object('ok', false, 'error', 'not_started'); end if;
  if a.submitted_at is null then
    select count(*), count(*) filter (where (coalesce(p_answers, '{}'::jsonb) ->> x.id::text) = x.answer) into v_total, v_score
    from public.tutor_quiz_questions x where x.quiz_id = q.id;
    update public.tutor_quiz_attempts set submitted_at = now(), answers = coalesce(p_answers, '{}'::jsonb), score = v_score, total = v_total
    where quiz_id = q.id and user_id = v_uid;
    -- The tutor sees it in the chat at once (and gets an email if they are away).
    insert into public.tutor_messages (request_id, from_staff, sender_id, sender_role, body)
    values (r.id, true, null, 'system', private.game_name(v_uid) || ' finished the quiz "' || q.title || '": ' || v_score || '/' || v_total || '.');
    select * into t from public.tutors where id = r.tutor_id;
    if t.user_id is not null then
      insert into private.email_outbox (user_id, kind, data) values (t.user_id, 'tutor_student_message',
        jsonb_build_object('student', private.game_name(v_uid), 'body', 'Finished your quiz "' || q.title || '": ' || v_score || '/' || v_total, 'request', r.id));
    end if;
  end if;
  return public.tutor_quiz_review(q.id, v_uid);
end $$;

/** A quiz with answers, explanations and one student's choices: for that student after submitting, their tutor and admins. */
create or replace function public.tutor_quiz_review(p_quiz uuid, p_student uuid default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare q public.tutor_quizzes; r public.tutor_requests; a public.tutor_quiz_attempts; v_uid uuid := (select auth.uid()); v_student uuid;
begin
  select * into q from public.tutor_quizzes where id = p_quiz;
  select * into r from public.tutor_requests where id = q.request_id;
  if q.id is null then raise exception 'not allowed' using errcode = '42501'; end if;
  v_student := r.user_id;
  if v_uid = r.user_id then
    select * into a from public.tutor_quiz_attempts where quiz_id = q.id and user_id = v_student;
    if a.submitted_at is null then raise exception 'not allowed' using errcode = '42501'; end if;
  elsif private.is_tutor_of(r.id) or private.tutor_staff() then
    select * into a from public.tutor_quiz_attempts where quiz_id = q.id and user_id = v_student;
  else
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return jsonb_build_object('ok', true, 'review', true, 'quiz', private.tutor_quiz_json(q, v_student),
    'score', a.score, 'total', a.total, 'started_at', a.started_at, 'submitted_at', a.submitted_at,
    'questions', (select jsonb_agg(jsonb_build_object('id', x.id, 'body', x.body, 'options', x.options, 'answer', x.answer,
                    'explanation', x.explanation, 'chosen', a.answers ->> x.id::text,
                    'correct', (a.answers ->> x.id::text) = x.answer) order by x.sort)
                  from public.tutor_quiz_questions x where x.quiz_id = q.id));
end $$;

/** A chat's quizzes, for the tutor desk and admins (with the student's score). */
create or replace function public.tutor_quiz_list(p_request uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when not (private.is_tutor_of(p_request) or private.tutor_staff()
                        or exists (select 1 from public.tutor_requests r where r.id = p_request and r.user_id = (select auth.uid())))
    then '[]'::jsonb else coalesce((
      select jsonb_agg(private.tutor_quiz_json(q, r.user_id) order by q.created_at desc)
      from public.tutor_quizzes q join public.tutor_requests r on r.id = q.request_id where q.request_id = p_request), '[]'::jsonb) end;
$$;

create or replace function public.tutor_quiz_close(p_quiz uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare q public.tutor_quizzes;
begin
  select * into q from public.tutor_quizzes where id = p_quiz;
  if q.id is null or not (private.is_tutor_of(q.request_id) or private.tutor_staff()) then raise exception 'not allowed' using errcode = '42501'; end if;
  update public.tutor_quizzes set closed_at = case when closed_at is null then now() end where id = q.id;
  return jsonb_build_object('ok', true);
end $$;

do $$ declare f text; begin
  foreach f in array array['public.tutor_quiz_create(uuid, text, text, integer, timestamptz, jsonb, jsonb)', 'public.tutor_quizzes_mine()',
    'public.tutor_quiz_start(uuid)', 'public.tutor_quiz_save(uuid, jsonb)', 'public.tutor_quiz_submit(uuid, jsonb)',
    'public.tutor_quiz_review(uuid, uuid)', 'public.tutor_quiz_list(uuid)', 'public.tutor_quiz_close(uuid)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  execute 'revoke all on function private.tutor_quiz_json(public.tutor_quizzes, uuid) from public, anon, authenticated';
end $$;
