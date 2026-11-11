-- JAMB classes on the website (C17, D-148): a public timetable, materials and assignments for registered students.
create table public.class_materials (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 120),
  url text not null check (url ~ '^https://'),
  created_at timestamptz not null default now()
);
create table public.class_assignments (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 120),
  instructions text check (char_length(instructions) <= 4000),
  due_at timestamptz,
  max_score smallint not null default 10 check (max_score between 1 and 100),
  created_at timestamptz not null default now()
);
create table public.class_submissions (
  assignment_id uuid not null references public.class_assignments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  answer text not null check (char_length(btrim(answer)) between 1 and 8000),
  submitted_at timestamptz not null default now(),
  score smallint,
  feedback text check (char_length(feedback) <= 2000),
  marked_at timestamptz,
  marked_by uuid,
  primary key (assignment_id, user_id)
);
alter table public.class_materials enable row level security;
alter table public.class_assignments enable row level security;
alter table public.class_submissions enable row level security;
create policy "editors" on public.class_materials for all to authenticated
  using (private.can_edit(array['super_admin','admin','editor','teacher']::staff_role[])) with check (private.can_edit(array['super_admin','admin','editor','teacher']::staff_role[]));
create policy "editors" on public.class_assignments for all to authenticated
  using (private.can_edit(array['super_admin','admin','editor','teacher']::staff_role[])) with check (private.can_edit(array['super_admin','admin','editor','teacher']::staff_role[]));
create policy "own or staff read" on public.class_submissions for select to authenticated using (user_id = (select auth.uid()) or private.is_staff());
create policy "staff mark" on public.class_submissions for update to authenticated
  using (private.can_edit(array['super_admin','admin','editor','teacher']::staff_role[])) with check (private.can_edit(array['super_admin','admin','editor','teacher']::staff_role[]));
grant select, insert, update, delete on public.class_materials, public.class_assignments to authenticated;
grant select on public.class_submissions to authenticated;
grant update (score, feedback, marked_at, marked_by) on public.class_submissions to authenticated;

-- The website page text (admin → Online classes → Website page).
insert into public.app_settings (key, value, is_public) values ('jamb_classes', jsonb_build_object(
  'on', true,
  'title', 'JAMB classes with real teachers',
  'intro', 'Live online classes for UTME: we teach each topic step by step, solve past questions with you and answer your questions in class. Join from your phone or laptop.',
  'price_note', 'Some classes are free, some are for Premium students and some are paid one by one. You see the price on each class.',
  'teachers', '[]'::jsonb,
  'faq', jsonb_build_array(
    jsonb_build_object('q', 'How do I join a class?', 'a', 'Register for the class, then open "My classes" here or the SolutionTee app 15 minutes before it starts and tap Join.'),
    jsonb_build_object('q', 'What if I miss a class?', 'a', 'Registered students can watch the recording when the teacher adds it.'),
    jsonb_build_object('q', 'Do I need data?', 'a', 'Yes. An hour of class uses about 300–500 MB. Join on Wi-Fi if you can.'))), true)
on conflict (key) do nothing;

-- Public timetable (no login): upcoming published classes, no links.
create or replace function public.public_classes() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title, 'about', c.about, 'subject', s.name, 'exam', c.exam,
      'teacher', c.teacher, 'starts_at', c.starts_at, 'minutes', c.minutes, 'access', c.access, 'price_kobo', c.price_kobo,
      'seats_left', case when c.seats is null then null else greatest(c.seats - (select count(*) from public.class_registrations r where r.class_id = c.id), 0) end)
    order by c.starts_at), '[]'::jsonb)
  from public.classes c left join public.subjects s on s.id = c.subject_id
  where c.status = 'published' and c.starts_at + make_interval(mins => c.minutes) > now()
    and (c.web_only or c.exam is null or c.exam = 'JAMB');
$$;
grant execute on function public.public_classes() to anon, authenticated;

-- A student's dashboard: classes they registered for (or may join), with materials and assignments.
create or replace function public.my_class_dashboard() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title, 'teacher', c.teacher, 'starts_at', c.starts_at, 'minutes', c.minutes,
      'access', c.access, 'status', c.status, 'registered', r.user_id is not null,
      'has_recording', coalesce((select l.recording_url is not null from public.class_links l where l.class_id = c.id), false),
      'materials', (select coalesce(jsonb_agg(jsonb_build_object('title', m.title, 'url', m.url) order by m.created_at), '[]'::jsonb) from public.class_materials m where m.class_id = c.id),
      'assignments', (select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'title', a.title, 'instructions', a.instructions, 'due_at', a.due_at,
          'max_score', a.max_score, 'answer', sb.answer, 'submitted_at', sb.submitted_at, 'score', sb.score, 'feedback', sb.feedback) order by a.created_at), '[]'::jsonb)
        from public.class_assignments a left join public.class_submissions sb on sb.assignment_id = a.id and sb.user_id = (select auth.uid())
        where a.class_id = c.id))
    order by c.starts_at desc), '[]'::jsonb)
  from public.classes c
  left join public.class_registrations r on r.class_id = c.id and r.user_id = (select auth.uid())
  where (select auth.uid()) is not null and c.status <> 'draft'
    and (r.user_id is not null or (c.access <> 'paid' and private.class_allowed(c.id, (select auth.uid()))
         and c.starts_at + make_interval(mins => c.minutes) > now() - interval '30 days'));
$$;

-- Hand in (or change before it is marked) an assignment of a class the student may come to.
create or replace function public.class_submit(p_assignment uuid, p_answer text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare a public.class_assignments; v_uid uuid := (select auth.uid());
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into a from public.class_assignments where id = p_assignment;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not private.class_allowed(a.class_id, v_uid) then return jsonb_build_object('ok', false, 'error', 'locked'); end if;
  if char_length(btrim(coalesce(p_answer, ''))) < 1 or char_length(p_answer) > 8000 then return jsonb_build_object('ok', false, 'error', 'length'); end if;
  if a.due_at is not null and now() > a.due_at + interval '1 day' then return jsonb_build_object('ok', false, 'error', 'late'); end if;
  insert into public.class_submissions (assignment_id, user_id, answer) values (p_assignment, v_uid, btrim(p_answer))
  on conflict (assignment_id, user_id) do update set answer = excluded.answer, submitted_at = now()
    where public.class_submissions.marked_at is null;
  if not found then return jsonb_build_object('ok', false, 'error', 'marked'); end if;
  return jsonb_build_object('ok', true);
end $$;

-- Staff: the submissions of a class for marking.
create or replace function public.admin_class_submissions(p_class uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('assignment_id', s.assignment_id, 'assignment', a.title, 'max_score', a.max_score, 'user_id', s.user_id,
      'name', coalesce(p.full_name, 'Student'), 'answer', s.answer, 'submitted_at', s.submitted_at, 'score', s.score, 'feedback', s.feedback)
    order by s.marked_at nulls first, s.submitted_at), '[]'::jsonb)
  from public.class_submissions s join public.class_assignments a on a.id = s.assignment_id left join public.profiles p on p.id = s.user_id
  where a.class_id = p_class and private.is_staff();
$$;

revoke all on function public.my_class_dashboard(), public.class_submit(uuid, text), public.admin_class_submissions(uuid) from public, anon;
grant execute on function public.my_class_dashboard(), public.class_submit(uuid, text), public.admin_class_submissions(uuid) to authenticated;

