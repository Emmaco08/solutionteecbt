-- Owner (D-073): challenges by subject with difficulty levels, a random paper per student from large pools,
-- subject-only challenges, appeals with a screenshot, and notifications 15 min before, at start and 15 min before the end.

-- ================================================================ schema
alter table public.challenge_questions
  add column subject_id smallint references public.subjects (id),
  add column difficulty text not null default 'medium' check (difficulty in ('easy', 'medium', 'hard', 'very_hard'));
create index challenge_questions_pool on public.challenge_questions (challenge_id, subject_id, difficulty);

-- mode: 'fixed' = every student gets all questions (as before); 'mixed' = each student's own JAMB subjects;
-- 'subject' = one subject, only for students who take it. per_level = questions per subject at each difficulty.
alter table public.challenges
  add column mode text not null default 'fixed' check (mode in ('fixed', 'mixed', 'subject')),
  add column subject_id smallint references public.subjects (id),
  add column per_level jsonb not null default '{"easy": 3, "medium": 3, "hard": 3, "very_hard": 1}',
  add column soon_notified_at timestamptz,
  add column end_notified_at timestamptz,
  add constraint challenges_subject_mode check (mode <> 'subject' or subject_id is not null);

create table public.challenge_appeals (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null unique references public.challenge_entries (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  reason text not null check (char_length(reason) between 10 and 1000),
  image_path text check (image_path ~ '^a/[0-9a-f-]{36}/[A-Za-z0-9._-]+$'),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  admin_note text check (char_length(admin_note) <= 500),
  decided_by uuid references auth.users (id),
  decided_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.challenge_appeals enable row level security;
create policy "own or staff" on public.challenge_appeals for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff());
revoke all on public.challenge_appeals from anon;
revoke insert, update, delete on public.challenge_appeals from authenticated;
create trigger challenge_appeals_audit after insert or update or delete on public.challenge_appeals
  for each row execute function private.audit_row();

-- ================================================================ helpers
/** The student's JAMB subjects (ids, in subject order). */
create or replace function private.student_subjects(p_user uuid)
returns smallint[] language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(s.id order by s.sort, s.id), '{}')
  from public.profiles p cross join lateral unnest(p.jamb_subjects) u(c) join public.subjects s on s.code = u.c
  where p.id = p_user;
$$;

/** Can this student take this challenge? Subject challenges: only students who take that subject. */
create or replace function private.challenge_eligible(c public.challenges, p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select case c.mode
    when 'subject' then c.subject_id = any (private.student_subjects(p_user))
    when 'mixed' then cardinality(private.student_subjects(p_user)) > 0
    else true end;
$$;

/** How many questions one student's paper has. */
create or replace function private.challenge_paper_size(c public.challenges, p_user uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select case c.mode
    when 'fixed' then (select count(*)::int from public.challenge_questions q where q.challenge_id = c.id)
    else (select coalesce(sum(least((l.n)::int, (select count(*) from public.challenge_questions q
                 where q.challenge_id = c.id and q.subject_id = s.sid and q.difficulty = l.lvl))), 0)::int
          from unnest(case when c.mode = 'subject' then array[c.subject_id] else private.student_subjects(p_user) end) s(sid)
          cross join lateral jsonb_each_text(c.per_level) l(lvl, n))
  end;
$$;

create or replace function private.challenge_card(c public.challenges, p_uid uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'title', c.title, 'subtitle', c.subtitle, 'kind', c.kind, 'icon', c.icon, 'exam', c.exam_code,
    'mode', c.mode, 'subject', (select s.name from public.subjects s where s.id = c.subject_id), 'per_level', c.per_level,
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
                                       'appeal', (select jsonb_build_object('status', a.status, 'note', a.admin_note, 'created_at', a.created_at)
                                                  from public.challenge_appeals a where a.entry_id = e.id))
             from public.challenge_entries e where e.challenge_id = c.id and e.user_id = p_uid));
$$;

create or replace function public.challenges_list()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  if not coalesce((select f.enabled from public.feature_flags f where f.key = 'challenges_enabled'), true) then
    return jsonb_build_object('on', false);
  end if;
  return jsonb_build_object('on', true,
    'items', coalesce((select jsonb_agg(private.challenge_card(c, v_uid) order by c.starts_at)
                       from public.challenges c where c.published and c.closed_at is null and c.ends_at > now()
                         and (c.mode <> 'subject' or private.challenge_eligible(c, v_uid))), '[]'::jsonb),
    'past', coalesce((select jsonb_agg(x order by (x ->> 'ends_at') desc) from (
        select private.challenge_card(c, v_uid) || jsonb_build_object('winners', (
          select coalesce(jsonb_agg(jsonb_build_object('rank', e.rank, 'name', private.lb_name(p.full_name, 'first-initial'), 'state', p.state,
                 'score', e.score, 'time_ms', e.time_ms, 'prize', e.prize) order by e.rank), '[]'::jsonb)
          from public.challenge_entries e join public.profiles p on p.id = e.user_id
          where e.challenge_id = c.id and e.rank is not null and e.rank <= 3)) as x
        from public.challenges c where c.published and (c.closed_at is not null or c.ends_at <= now())
          and (c.mode <> 'subject' or private.challenge_eligible(c, v_uid))
        order by c.ends_at desc limit 10) t), '[]'::jsonb));
end;
$$;

/** Start: one entry per student. Mixed/subject challenges draw a random paper from the pools: per_level questions
    of each difficulty for each of the student's subjects, so everyone gets the same mix but mostly different questions. */
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
                          order by random() limit greatest((l.n)::int, 0)) q) t;
  end if;
  if v_ids is null then raise exception 'This challenge has no questions for your subjects yet.' using errcode = 'P0001'; end if;
  insert into public.challenge_entries (challenge_id, user_id, question_order, device_hash, device_flags)
  values (p_id, v_uid, v_ids, left(p_device, 128), coalesce(p_device_flags[1:5], '{}'))
  returning * into e;
  return jsonb_build_object('status', 'playing', 'question', private.challenge_serve(e.id));
end;
$$;

-- ================================================================ appeals
/** A disqualified student explains (and may attach a screenshot) within 24 hours. */
create or replace function public.challenge_appeal(p_id uuid, p_reason text, p_image text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); e record;
begin
  if v_uid is null or private.is_banned() then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into e from public.challenge_entries where challenge_id = p_id and user_id = v_uid;
  if e.id is null or e.status <> 'disqualified' then raise exception 'Only a disqualified entry can be appealed.' using errcode = 'P0001'; end if;
  if now() > coalesce(e.finished_at, now()) + interval '24 hours' then
    raise exception 'Appeals must be sent within 24 hours.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.challenge_appeals a where a.entry_id = e.id) then
    raise exception 'You have already sent an appeal.' using errcode = 'P0001';
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 10 then raise exception 'Tell us what happened (at least a short sentence).' using errcode = '22023'; end if;
  if p_image is not null and p_image not like 'a/' || v_uid::text || '/%' then raise exception 'Upload the screenshot again.' using errcode = '22023'; end if;
  insert into public.challenge_appeals (entry_id, user_id, reason, image_path) values (e.id, v_uid, btrim(p_reason), p_image);
  return jsonb_build_object('ok', true);
end;
$$;

/** Admin: accept (reinstate the entry and rank again) or reject an appeal; the student is told. */
create or replace function public.admin_challenge_appeal(p_appeal uuid, p_accept boolean, p_note text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare a record; c record;
begin
  if not private.can_edit(array['super_admin', 'admin']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into a from public.challenge_appeals where id = p_appeal for update;
  if a.id is null or a.status <> 'pending' then raise exception 'This appeal has already been decided.' using errcode = 'P0001'; end if;
  select ch.* into c from public.challenges ch join public.challenge_entries e on e.challenge_id = ch.id where e.id = a.entry_id;
  update public.challenge_appeals set status = case when p_accept then 'accepted' else 'rejected' end,
    admin_note = left(p_note, 500), decided_by = (select auth.uid()), decided_at = now() where id = a.id;
  if p_accept then perform public.admin_challenge_review(a.entry_id, 'reinstate'); end if;
  insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
  values ('challenges', case when p_accept then 'Appeal accepted' else 'Appeal not accepted' end,
          left(case when p_accept then 'Your entry in ' || c.title || ' counts again.' else 'Your entry in ' || c.title || ' stays disqualified.' end
               || coalesce(' ' || nullif(btrim(p_note), ''), ''), 240),
          'user', a.user_id, 'scheduled', now(), 'challenge', jsonb_build_object('type', 'screen', 'target', '/challenges/' || c.id || '/result'));
  return jsonb_build_object('ok', true);
end;
$$;

/** Admin: pending and recent appeals. */
create or replace function public.admin_challenge_appeals()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff() then raise exception 'Not allowed' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', a.id, 'status', a.status, 'reason', a.reason, 'image', a.image_path, 'note', a.admin_note,
             'created_at', a.created_at, 'challenge', c.title, 'challenge_id', c.id, 'name', p.full_name, 'dq_reason', e.dq_reason,
             'answered', e.current, 'exits', e.exits) order by (a.status = 'pending') desc, a.created_at desc)
    from public.challenge_appeals a join public.challenge_entries e on e.id = a.entry_id
    join public.challenges c on c.id = e.challenge_id join public.profiles p on p.id = a.user_id
    where a.status = 'pending' or a.created_at > now() - interval '14 days'), '[]'::jsonb);
end;
$$;

-- ================================================================ notifications
/** Sends a challenge message to the right students: everyone (topic) for fixed/mixed challenges, or only students
    who take the subject (and kept Challenges notifications on) for subject challenges. p_unplayed: skip those who played. */
create or replace function private.challenge_notify(c public.challenges, p_title text, p_body text, p_unplayed boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if c.mode = 'subject' then
    insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
    select 'challenges', left(p_title, 80), left(p_body, 240), 'user', p.id, 'scheduled', now(), 'challenge',
           jsonb_build_object('type', 'screen', 'target', '/challenges/' || c.id)
    from public.profiles p join public.subjects s on s.id = c.subject_id
    where s.code = any (p.jamb_subjects) and p.banned_at is null
      and not exists (select 1 from public.notification_prefs np where np.user_id = p.id and np.topic = 'challenges' and not np.enabled)
      and (not p_unplayed or not exists (select 1 from public.challenge_entries e where e.challenge_id = c.id and e.user_id = p.id));
  else
    insert into public.notifications (topic, title, body, audience, status, scheduled_at, source, link)
    values ('challenges', left(p_title, 80), left(p_body, 240), 'all', 'scheduled', now(), 'challenge',
            jsonb_build_object('type', 'screen', 'target', '/challenges/' || c.id));
  end if;
end;
$$;

create or replace function private.challenges_tick()
returns integer language plpgsql security definer set search_path = '' as $$
declare c public.challenges; e record; v_n integer := 0; v_prize text;
begin
  -- 15 minutes before it starts
  for c in select * from public.challenges where published and soon_notified_at is null
           and starts_at > now() and starts_at <= now() + interval '15 minutes' loop
    update public.challenges set soon_notified_at = now() where id = c.id;
    v_prize := case when cardinality(c.prizes) > 0 then ' Win ₦' || to_char(c.prizes[1], 'FM999,999,999') || '.' else '' end;
    perform private.challenge_notify(c, c.title || ' starts in 15 minutes', 'Get ready.' || v_prize || ' Find a quiet place and stay on the screen.');
  end loop;
  -- it starts now
  for c in select * from public.challenges where published and announced_at is null and starts_at <= now() and ends_at > now() loop
    update public.challenges set announced_at = now() where id = c.id;
    v_prize := case when cardinality(c.prizes) > 0 then 'Win ₦' || to_char(c.prizes[1], 'FM999,999,999') || '. ' else '' end;
    perform private.challenge_notify(c, c.title || ' is live', v_prize || 'Tap to play before it closes.');
  end loop;
  -- 15 minutes before the end (only if it ran for longer than that)
  for c in select * from public.challenges where published and closed_at is null and end_notified_at is null
           and ends_at > now() and ends_at <= now() + interval '15 minutes' and starts_at < now() - interval '5 minutes' loop
    update public.challenges set end_notified_at = now() where id = c.id;
    perform private.challenge_notify(c, c.title || ' ends in 15 minutes', 'Last chance to play.', true);
  end loop;
  -- close the ended ones: winners + messages
  for c in select * from public.challenges where published and closed_at is null and ends_at <= now() loop
    for e in select id from public.challenge_entries where challenge_id = c.id and status = 'playing' loop
      perform private.challenge_finish(e.id, 'finished');
    end loop;
    update public.challenges set closed_at = now() where id = c.id;
    perform private.challenge_rank(c.id);
    insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
    select 'challenges', left('You won ₦' || to_char(x.prize, 'FM999,999,999') || '!', 80),
           left('You are #' || x.rank || ' in ' || c.title || '. Send your account details within 7 days.', 240),
           'user', x.user_id, 'scheduled', now(), 'challenge', jsonb_build_object('type', 'screen', 'target', '/challenges/' || c.id || '/winners')
    from public.challenge_entries x where x.challenge_id = c.id and x.prize > 0;
    insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
    select 'challenges', left('Results: ' || c.title, 80), 'See the winners and your place.', 'user', x.user_id, 'scheduled', now(), 'challenge',
           jsonb_build_object('type', 'screen', 'target', '/challenges/' || c.id || '/winners')
    from public.challenge_entries x where x.challenge_id = c.id and coalesce(x.prize, 0) = 0;
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

-- ================================================================ admin
create or replace function public.admin_challenge_entries(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff() then raise exception 'Not allowed' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', e.id, 'name', p.full_name, 'state', p.state, 'status', e.status, 'score', e.score,
             'answered', e.current, 'total', cardinality(e.question_order), 'time_ms', e.time_ms, 'exits', e.exits, 'dq_reason', e.dq_reason,
             'flags', to_jsonb(e.flags), 'review', e.review, 'rank', e.rank, 'prize', e.prize, 'started_at', e.started_at,
             'finished_at', e.finished_at, 'claim', (select pc.status from public.prize_claims pc where pc.entry_id = e.id),
             'appeal', (select a.status from public.challenge_appeals a where a.entry_id = e.id))
           order by e.rank nulls last, e.score desc, e.time_ms)
    from public.challenge_entries e join public.profiles p on p.id = e.user_id where e.challenge_id = p_id), '[]'::jsonb);
end;
$$;

revoke execute on function private.student_subjects(uuid), private.challenge_eligible(public.challenges, uuid),
  private.challenge_paper_size(public.challenges, uuid), private.challenge_notify(public.challenges, text, text, boolean)
  from public, anon, authenticated;
revoke execute on function public.challenge_appeal(uuid, text, text), public.admin_challenge_appeal(uuid, boolean, text),
  public.admin_challenge_appeals() from public, anon;
grant execute on function public.challenge_appeal(uuid, text, text), public.admin_challenge_appeal(uuid, boolean, text),
  public.admin_challenge_appeals() to authenticated;
