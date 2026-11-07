-- JAMB mock challenges (owner, 2026-11-07; D-099): a challenge style that looks and works like the JAMB CBT:
-- the whole paper at once (Use of English + 3 subjects), free navigation, one timer, passages and pictures,
-- marked on submit (each subject /100, total /400). Access: open, Premium only, a shared code, or personal invite
-- codes. Leaving the screen is logged (how often, how long); the admin sets the limits. Rich analytics for teachers.

alter table public.challenges
  add column if not exists style text not null default 'standard' check (style in ('standard', 'jamb_mock')),
  add column if not exists access text not null default 'open' check (access in ('open', 'premium', 'code', 'invite')),
  add column if not exists access_code_hash text,
  add column if not exists duration_minutes smallint check (duration_minutes is null or duration_minutes between 5 and 300),
  add column if not exists max_away_seconds integer check (max_away_seconds is null or max_away_seconds >= 0),
  add column if not exists exit_action text not null default 'flag' check (exit_action in ('flag', 'submit')),
  add column if not exists results text not null default 'instant' check (results in ('instant', 'after_end', 'hidden')),
  add column if not exists mock_subjects jsonb not null default '{"english": true, "student_subjects": true}';

alter table public.challenge_questions
  add column if not exists number smallint,
  add column if not exists section text,
  add column if not exists topic text,
  add column if not exists passage_key text,
  add column if not exists passage_title text,
  add column if not exists passage_body text,
  add column if not exists image_path text;

alter table public.challenge_entries
  add column if not exists subjects smallint[],
  add column if not exists deadline timestamptz,
  add column if not exists away_ms integer not null default 0,
  add column if not exists subject_scores jsonb,
  add column if not exists via text;

-- Personal invite codes: one per student (stored hashed; the plain code is shown to the admin once).
create table if not exists public.challenge_invites (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  label text not null check (char_length(label) between 1 and 120),   -- the student's name, class or phone
  code_hash text not null,
  code_hint text,                                                    -- last 2 characters, to help the admin
  user_id uuid references auth.users (id) on delete set null,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (challenge_id, code_hash)
);
alter table public.challenge_invites enable row level security;
create policy "staff read" on public.challenge_invites for select to authenticated using (private.is_staff(array['super_admin', 'admin', 'editor']::public.staff_role[]));
create policy "staff delete" on public.challenge_invites for delete to authenticated using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));

-- Who passed the gate (code, invite or Premium), so they do not type the code again.
create table if not exists public.challenge_access (
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  via text not null,
  at timestamptz not null default now(),
  primary key (challenge_id, user_id)
);
alter table public.challenge_access enable row level security;
create policy "own or staff" on public.challenge_access for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff(array['super_admin', 'admin', 'editor']::public.staff_role[]));

-- Behaviour log: leaving and coming back, screenshots, copy attempts.
create table if not exists public.challenge_events (
  id bigint generated always as identity primary key,
  entry_id uuid not null references public.challenge_entries (id) on delete cascade,
  kind text not null check (kind in ('leave', 'return', 'screenshot', 'copy', 'rotate', 'warning', 'auto_submit', 'resume')),
  ms integer,
  at timestamptz not null default now()
);
create index if not exists challenge_events_entry on public.challenge_events (entry_id, at);
alter table public.challenge_events enable row level security;
create policy "staff read" on public.challenge_events for select to authenticated using (private.is_staff(array['super_admin', 'admin', 'editor']::public.staff_role[]));

create unique index if not exists challenge_answers_one on public.challenge_answers (entry_id, question_id);
-- Mock answers are saved unmarked (correct = null) until the student submits.
alter table public.challenge_answers alter column correct drop not null;

-- ------------------------------------------------------------------ admin: codes
create or replace function private.code_hash(p_challenge uuid, p_code text) returns text
language sql immutable set search_path to '' as $$
  select encode(extensions.digest(p_challenge::text || ':' || upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')), 'sha256'), 'hex');
$$;

-- Set (or clear) the shared code for a challenge.
create or replace function public.challenge_set_code(p_id uuid, p_code text)
returns void language plpgsql security definer set search_path to '' as $$
begin
  if not private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  if p_code is not null and char_length(regexp_replace(p_code, '\s', '', 'g')) < 4 then raise exception 'The code needs at least 4 characters.' using errcode = 'P0001'; end if;
  update public.challenges set access_code_hash = case when p_code is null then null else private.code_hash(p_id, p_code) end where id = p_id;
end;
$$;

-- Make one personal code per label (student). Returns the plain codes ONCE: [{label, code}].
create or replace function public.challenge_make_invites(p_id uuid, p_labels text[])
returns jsonb language plpgsql security definer set search_path to '' as $$
declare v_out jsonb := '[]'; l text; v_code text; v_alpha text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if not private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  if coalesce(cardinality(p_labels), 0) not between 1 and 2000 then raise exception 'Give 1 to 2000 names.' using errcode = 'P0001'; end if;
  foreach l in array p_labels loop
    continue when coalesce(trim(l), '') = '';
    loop
      select string_agg(substr(v_alpha, 1 + (get_byte(extensions.gen_random_bytes(1), 0) % 32), 1), '') into v_code from generate_series(1, 8);
      begin
        insert into public.challenge_invites (challenge_id, label, code_hash, code_hint)
        values (p_id, left(trim(l), 120), private.code_hash(p_id, v_code), right(v_code, 2));
        exit;
      exception when unique_violation then null;
      end;
    end loop;
    v_out := v_out || jsonb_build_object('label', left(trim(l), 120), 'code', substr(v_code, 1, 4) || '-' || substr(v_code, 5, 4));
  end loop;
  return v_out;
end;
$$;

-- ------------------------------------------------------------------ student: gate
-- Can this student enter? {ok, need: null|'premium'|'code'|'invite'}
create or replace function private.mock_allowed(c public.challenges, p_uid uuid) returns boolean
language sql stable security definer set search_path to '' as $$
  select c.access = 'open'
      or (c.access = 'premium' and private.has_premium(p_uid))
      or exists (select 1 from public.challenge_access a where a.challenge_id = c.id and a.user_id = p_uid)
      or private.is_staff();
$$;

-- Enter a shared or personal code. A personal code works for one student only (claimed on first use).
create or replace function public.challenge_unlock(p_id uuid, p_code text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare v_uid uuid := (select auth.uid()); c public.challenges; v_hash text; inv record; v_fails integer;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into c from public.challenges where id = p_id and published;
  if not found then raise exception 'This challenge is not available.' using errcode = 'P0002'; end if;
  if private.mock_allowed(c, v_uid) then return jsonb_build_object('ok', true); end if;
  if c.access = 'premium' then return jsonb_build_object('ok', false, 'need', 'premium'); end if;
  -- Slow down guessing: at most 10 wrong codes per student per challenge per hour.
  select count(*) into v_fails from public.audit_log where actor = v_uid and action = 'challenge_code_wrong' and row_id = p_id::text and at > now() - interval '1 hour';
  if v_fails >= 10 then raise exception 'Too many wrong codes. Try again in an hour.' using errcode = 'P0001'; end if;
  v_hash := private.code_hash(p_id, p_code);
  if c.access = 'code' and c.access_code_hash = v_hash then
    insert into public.challenge_access (challenge_id, user_id, via) values (p_id, v_uid, 'code') on conflict do nothing;
    return jsonb_build_object('ok', true);
  end if;
  if c.access in ('invite', 'code') then
    select * into inv from public.challenge_invites where challenge_id = p_id and code_hash = v_hash for update;
    if found and (inv.user_id is null or inv.user_id = v_uid) then
      update public.challenge_invites set user_id = v_uid, claimed_at = coalesce(claimed_at, now()) where id = inv.id;
      insert into public.challenge_access (challenge_id, user_id, via) values (p_id, v_uid, 'invite:' || inv.label) on conflict do nothing;
      return jsonb_build_object('ok', true, 'label', inv.label);
    elsif found then
      raise exception 'This code has already been used by another student.' using errcode = 'P0001';
    end if;
  end if;
  insert into public.audit_log (actor, action, table_name, row_id) values (v_uid, 'challenge_code_wrong', 'challenges', p_id::text);
  return jsonb_build_object('ok', false, 'need', c.access, 'wrong', true);
end;
$$;

-- ------------------------------------------------------------------ student: the exam
-- The paper for an entry, WITHOUT answers: subjects in JAMB order (Use of English first), each with its questions,
-- passages and pictures, the saved choices, the deadline and the leave rules.
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

-- Start (or resume) a JAMB mock. Resuming within the time is allowed (logged); after the deadline it is submitted.
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

-- Save one choice (can be changed until submit). p_ms = time spent on the question since the last save.
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

-- Leaving the screen and coming back (and other signals). Applies the admin's limits.
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

-- Submit and mark on the server: each subject out of 100 (JAMB style), total out of 400.
create or replace function public.mock_submit(p_entry uuid)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare e public.challenge_entries; v_scores jsonb; v_total integer;
begin
  select * into e from public.challenge_entries where id = p_entry for update;
  if not found then raise exception 'Not found' using errcode = 'P0002'; end if;
  -- A student may submit only their own entry; staff may submit any; the timer job (no login) may submit any.
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

-- The student's result, honouring the admin's "results" setting (instant, after the end, hidden).
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

-- What the app needs before showing a mock: its style, access, rules, and whether this student may enter.
create or replace function public.mock_gate(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare c public.challenges; v_uid uuid := (select auth.uid());
begin
  select * into c from public.challenges where id = p_id and published;
  if not found then return null; end if;
  return jsonb_build_object('style', c.style, 'access', c.access, 'allowed', v_uid is not null and private.mock_allowed(c, v_uid),
    'premium', v_uid is not null and private.has_premium(v_uid), 'duration_minutes', coalesce(c.duration_minutes, 120),
    'allowed_exits', c.allowed_exits, 'max_away_seconds', c.max_away_seconds, 'exit_action', c.exit_action, 'results', c.results,
    'entry', (select jsonb_build_object('status', e.status, 'deadline', e.deadline) from public.challenge_entries e where e.challenge_id = p_id and e.user_id = v_uid));
end;
$$;
revoke execute on function public.mock_gate(uuid) from public, anon;
grant execute on function public.mock_gate(uuid) to authenticated;

-- ------------------------------------------------------------------ admin: analytics for teachers
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

-- One student's timeline (events) for the admin.
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

-- Finish mock entries whose time is up (runs with challenges-tick every minute) and rank finished mocks.
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

-- (applied as jamb_mock_card_fields) private.challenge_card also returns style, access, duration_minutes, results,
-- allowed_exits, max_away_seconds, exit_action and unlocked (private.mock_allowed) — edited in place.
-- Note: challenges.kind stays cash/event/practice; a JAMB mock is style = 'jamb_mock' with any kind.

-- (applied as jamb_mock_leaderboard) challenge_result for mocks: each top row also has 'max' (100 × subjects) and
-- 'subjects' (scores per subject), the student's 'my_max', and 'board_hidden' = true (empty top, no rank) when the
-- admin hides scores (always, or until the mock ends). Edited in place.
