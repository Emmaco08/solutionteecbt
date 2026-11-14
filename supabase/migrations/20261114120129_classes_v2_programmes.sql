-- Online classes v2 (owner, 14 Nov 2026; docs/plans/classes-v2.md, D-163): a programme (e.g. "JAMB Marathon Class")
-- is created once with its price, flyer and details; the admin then only adds sessions to it. A student pays once
-- (or registers once, for Free / Premium programmes) and may join every session of it.

create table public.class_programs (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) <= 80),
  title text not null check (char_length(title) between 3 and 120),
  tagline text check (tagline is null or char_length(tagline) <= 200),
  about text check (about is null or char_length(about) <= 6000),
  highlights text[] not null default '{}',
  exam text,
  subjects text,
  teacher text,
  teacher_bio text check (teacher_bio is null or char_length(teacher_bio) <= 1200),
  teacher_photo text check (teacher_photo is null or teacher_photo ~ '^public/classes/[A-Za-z0-9/_.-]+$'),
  flyer_path text check (flyer_path is null or flyer_path ~ '^public/classes/[A-Za-z0-9/_.-]+$'),
  schedule_note text check (schedule_note is null or char_length(schedule_note) <= 200),
  access text not null default 'paid' check (access in ('free', 'premium', 'paid')),
  price_kobo integer check (price_kobo is null or price_kobo >= 0),
  compare_kobo integer check (compare_kobo is null or compare_kobo >= 0),
  seats integer check (seats is null or seats > 0),
  starts_on date,
  ends_on date,
  faq jsonb not null default '[]'::jsonb check (jsonb_typeof(faq) = 'array'),
  status text not null default 'draft' check (status in ('draft', 'published', 'closed')),
  on_website boolean not null default true,
  sort integer not null default 0,
  created_by uuid references auth.users (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (access <> 'paid' or coalesce(price_kobo, 0) >= 5000),
  check (ends_on is null or starts_on is null or ends_on >= starts_on)
);
create index class_programs_created_by_fk on public.class_programs (created_by);
alter table public.class_programs enable row level security;
create policy "staff read" on public.class_programs for select to authenticated using ((select private.is_staff()));
create policy "editors" on public.class_programs for all to authenticated
  using ((select private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[])))
  with check ((select private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[])));
create trigger class_programs_touch before update on public.class_programs for each row execute function private.touch_updated_at();
create trigger class_programs_audit after insert or update or delete on public.class_programs for each row execute function private.audit_row();

create table public.class_enrollments (
  program_id uuid not null references public.class_programs (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  payment_id uuid references public.payments (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (program_id, user_id)
);
create index class_enrollments_user_id_fk on public.class_enrollments (user_id);
create index class_enrollments_payment_id_fk on public.class_enrollments (payment_id);
alter table public.class_enrollments enable row level security;
create policy "own" on public.class_enrollments for select to authenticated using (user_id = (select auth.uid()) or (select private.is_staff()));

alter table public.classes add column program_id uuid references public.class_programs (id) on delete set null;
create index classes_program_id_fk on public.classes (program_id);

alter table public.payments drop constraint payments_item_kind_check;
alter table public.payments add constraint payments_item_kind_check check (item_kind is null or item_kind = any (array['item', 'year', 'class', 'tutor', 'class_program']));
alter table public.content_purchases drop constraint content_purchases_kind_check;
alter table public.content_purchases add constraint content_purchases_kind_check check (kind = any (array['item', 'year', 'class', 'tutor', 'class_program']));

-- May this person attend this programme's sessions?
create or replace function private.program_allowed(p_program uuid, p_uid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.class_enrollments e where e.program_id = p_program and e.user_id = p_uid)
      or exists (select 1 from public.class_programs p where p.id = p_program and p.status = 'published'
                 and (p.access = 'free' or (p.access = 'premium' and private.has_premium(p_uid))))
      or private.is_staff();
$$;

create or replace function private.class_allowed(p_class uuid, p_uid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.class_registrations r where r.class_id = p_class and r.user_id = p_uid)
      or exists (select 1 from public.classes c where c.id = p_class and c.status = 'published' and c.program_id is null
                 and (c.access = 'free' or (c.access = 'premium' and private.has_premium(p_uid))))
      or exists (select 1 from public.classes c where c.id = p_class and c.status <> 'draft' and c.program_id is not null
                 and private.program_allowed(c.program_id, p_uid))
      or private.is_staff();
$$;

-- What paying for a programme costs, and whether it can be bought now.
create or replace function private.program_offer(p_program uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when p.id is null then null else jsonb_build_object(
    'mode', case when p.status = 'published' and p.access = 'paid'
                  and (p.ends_on is null or p.ends_on >= (now() at time zone 'Africa/Lagos')::date)
                  and (p.seats is null or (select count(*) from public.class_enrollments e where e.program_id = p.id) < p.seats)
             then 'pay' else 'closed' end,
    'price_kobo', p.price_kobo, 'title', 'Class: ' || p.title) end
  from (select 1) x left join public.class_programs p on p.id = p_program;
$$;

-- A paid purchase enrols the student (class_program) or registers them (old single class).
create or replace function private.class_paid()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.kind = 'class' then
    insert into public.class_registrations (class_id, user_id, payment_id) values (new.ref::uuid, new.user_id, new.payment_id)
    on conflict (class_id, user_id) do update set payment_id = excluded.payment_id;
  elsif new.kind = 'class_program' then
    insert into public.class_enrollments (program_id, user_id, payment_id) values (new.ref::uuid, new.user_id, new.payment_id)
    on conflict (program_id, user_id) do update set payment_id = excluded.payment_id;
  end if;
  return new;
end $$;

-- Register for a Free or Premium programme (paid ones go through Paystack).
create or replace function public.program_register(p_program uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.class_programs; v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  if private.is_banned(v_uid) then return jsonb_build_object('ok', false, 'error', 'banned'); end if;
  select * into p from public.class_programs where id = p_program and status = 'published';
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if exists (select 1 from public.class_enrollments e where e.program_id = p_program and e.user_id = v_uid) then return jsonb_build_object('ok', true); end if;
  if p.access = 'paid' then return jsonb_build_object('ok', false, 'error', 'pay'); end if;
  if p.access = 'premium' and not private.has_premium(v_uid) then return jsonb_build_object('ok', false, 'error', 'premium'); end if;
  if p.seats is not null and (select count(*) from public.class_enrollments e where e.program_id = p_program) >= p.seats then
    return jsonb_build_object('ok', false, 'error', 'full');
  end if;
  insert into public.class_enrollments (program_id, user_id) values (p_program, v_uid) on conflict do nothing;
  return jsonb_build_object('ok', true);
end $$;

-- A programme as cards and screens need it (no links).
create or replace function private.program_json(p public.class_programs, p_uid uuid, p_full boolean)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', p.id, 'slug', p.slug, 'title', p.title, 'tagline', p.tagline, 'flyer_path', p.flyer_path, 'exam', p.exam, 'subjects', p.subjects,
    'teacher', p.teacher, 'teacher_photo', p.teacher_photo, 'schedule_note', p.schedule_note, 'access', p.access,
    'price_kobo', p.price_kobo, 'compare_kobo', p.compare_kobo, 'starts_on', p.starts_on, 'ends_on', p.ends_on, 'status', p.status,
    'seats_left', case when p.seats is null then null else greatest(p.seats - (select count(*) from public.class_enrollments e where e.program_id = p.id), 0) end,
    'enrolled', p_uid is not null and exists (select 1 from public.class_enrollments e where e.program_id = p.id and e.user_id = p_uid),
    'allowed', p_uid is not null and private.program_allowed(p.id, p_uid),
    'buyable', coalesce(private.program_offer(p.id) ->> 'mode', '') = 'pay',
    'sessions_left', (select count(*) from public.classes c where c.program_id = p.id and c.status = 'published' and c.starts_at + make_interval(mins => c.minutes) > now()),
    'sessions_done', (select count(*) from public.classes c where c.program_id = p.id and c.status = 'published' and c.starts_at + make_interval(mins => c.minutes) <= now()),
    'next', (select jsonb_build_object('id', c.id, 'title', c.title, 'starts_at', c.starts_at, 'minutes', c.minutes,
                     'live', now() between c.starts_at - interval '15 minutes' and c.starts_at + make_interval(mins => c.minutes))
             from public.classes c where c.program_id = p.id and c.status = 'published' and c.starts_at + make_interval(mins => c.minutes) > now()
             order by c.starts_at limit 1))
  || case when not p_full then '{}'::jsonb else jsonb_build_object(
    'about', p.about, 'highlights', to_jsonb(p.highlights), 'teacher_bio', p.teacher_bio, 'faq', p.faq,
    'sessions', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title, 'starts_at', c.starts_at, 'minutes', c.minutes,
                   'status', c.status, 'live', now() between c.starts_at - interval '15 minutes' and c.starts_at + make_interval(mins => c.minutes),
                   'ended', now() > c.starts_at + make_interval(mins => c.minutes),
                   'has_recording', coalesce((select l.recording_url is not null from public.class_links l where l.class_id = c.id), false))
                 order by c.starts_at), '[]'::jsonb)
                 from public.classes c where c.program_id = p.id and c.status <> 'draft')) end;
$$;

-- App: the programmes a student can see (published, or ones they are enrolled in).
create or replace function public.programs_list()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(private.program_json(p, (select auth.uid()), false) order by p.sort, p.starts_on nulls last, p.created_at), '[]'::jsonb)
  from public.class_programs p
  where (select auth.uid()) is not null
    and (p.status = 'published' or exists (select 1 from public.class_enrollments e where e.program_id = p.id and e.user_id = (select auth.uid())));
$$;

-- App: one programme with its sessions.
create or replace function public.program_detail(p_program uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select private.program_json(p, (select auth.uid()), true)
  from public.class_programs p
  where p.id = p_program and (select auth.uid()) is not null
    and (p.status <> 'draft' or (select private.is_staff())
         or exists (select 1 from public.class_enrollments e where e.program_id = p.id and e.user_id = (select auth.uid())));
$$;

-- Website (no login): paid programmes on sale.
create or replace function public.public_programs()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(private.program_json(p, null, false) order by p.sort, p.starts_on nulls last, p.created_at), '[]'::jsonb)
  from public.class_programs p
  where p.status = 'published' and p.access = 'paid' and p.on_website
    and (p.ends_on is null or p.ends_on >= (now() at time zone 'Africa/Lagos')::date);
$$;

-- Website (no login): one paid programme's full page.
create or replace function public.public_program(p_slug text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select private.program_json(p, (select auth.uid()), true) - 'sessions' || jsonb_build_object('sessions',
    (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title, 'starts_at', c.starts_at, 'minutes', c.minutes) order by c.starts_at), '[]'::jsonb)
     from public.classes c where c.program_id = p.id and c.status = 'published' and c.starts_at + make_interval(mins => c.minutes) > now()))
  from public.class_programs p
  where p.slug = lower(p_slug) and p.status in ('published', 'closed') and p.access = 'paid' and p.on_website;
$$;

-- Flyers and teacher photos may be shown when a published programme uses them.
create or replace function public.can_view_class_image(p_key text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.class_programs p where p.status in ('published', 'closed') and (p.flyer_path = p_key or p.teacher_photo = p_key))
      or (select private.is_staff());
$$;

-- Sessions list (app): + the programme.
create or replace function public.classes_list()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', c.id, 'title', c.title, 'about', c.about, 'subject_id', c.subject_id, 'exam', c.exam, 'teacher', c.teacher,
      'starts_at', c.starts_at, 'minutes', c.minutes, 'access', c.access, 'price_kobo', c.price_kobo, 'status', c.status,
      'seats', c.seats, 'taken', (select count(*) from public.class_registrations r where r.class_id = c.id),
      'registered', exists (select 1 from public.class_registrations r where r.class_id = c.id and r.user_id = (select auth.uid())),
      'allowed', private.class_allowed(c.id, (select auth.uid())),
      'has_recording', coalesce((select l.recording_url is not null from public.class_links l where l.class_id = c.id), false),
      'live', now() between c.starts_at - interval '15 minutes' and c.starts_at + make_interval(mins => c.minutes),
      'program_id', c.program_id, 'program_title', p.title, 'program_flyer', p.flyer_path)
    order by c.starts_at), '[]'::jsonb)
  from public.classes c left join public.class_programs p on p.id = c.program_id
  where (select auth.uid()) is not null and c.status <> 'draft' and not c.web_only
    and (p.id is null or p.status <> 'draft')
    and c.starts_at + make_interval(mins => c.minutes) > now() - interval '30 days';
$$;

-- Joining a programme session the student has not paid for says which programme to buy.
create or replace function public.class_join(p_class uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.classes; v_uid uuid := (select auth.uid()); v_url text; v_access text;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into c from public.classes where id = p_class and status = 'published';
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not private.class_allowed(p_class, v_uid) then
    if c.program_id is not null then
      select p.access into v_access from public.class_programs p where p.id = c.program_id;
      return jsonb_build_object('ok', false, 'error', case when v_access = 'premium' then 'premium' else 'pay_program' end, 'program_id', c.program_id);
    end if;
    return jsonb_build_object('ok', false, 'error', case when c.access = 'paid' then 'pay' else 'premium' end);
  end if;
  if now() < c.starts_at - interval '15 minutes' then return jsonb_build_object('ok', false, 'error', 'early', 'opens_at', c.starts_at - interval '15 minutes'); end if;
  if now() > c.starts_at + make_interval(mins => c.minutes) then return jsonb_build_object('ok', false, 'error', 'ended'); end if;
  select l.join_url into v_url from public.class_links l where l.class_id = p_class;
  if v_url is null then return jsonb_build_object('ok', false, 'error', 'no_link'); end if;
  insert into public.class_registrations (class_id, user_id, joined_at) values (p_class, v_uid, now())
  on conflict (class_id, user_id) do update set joined_at = coalesce(public.class_registrations.joined_at, now());
  return jsonb_build_object('ok', true, 'url', v_url);
end $$;

-- My classes (website): + programme sessions the student may attend.
create or replace function public.my_class_dashboard()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title, 'teacher', c.teacher, 'starts_at', c.starts_at, 'minutes', c.minutes,
      'access', c.access, 'status', c.status, 'registered', r.user_id is not null or c.program_id is not null,
      'program_id', c.program_id, 'program_title', (select p.title from public.class_programs p where p.id = c.program_id),
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
    and (r.user_id is not null
         or (c.program_id is not null and exists (select 1 from public.class_enrollments e where e.program_id = c.program_id and e.user_id = (select auth.uid())))
         or (c.access <> 'paid' and c.program_id is null and private.class_allowed(c.id, (select auth.uid()))
             and c.starts_at + make_interval(mins => c.minutes) > now() - interval '30 days'));
$$;

-- Reminders: registered students, and everyone enrolled in the session's programme.
create or replace function private.class_reminders_job()
returns integer language plpgsql security definer set search_path = '' as $$
declare r record; v_n integer := 0;
begin
  for r in
    select c.id, c.title, g.user_id, m.at_min
    from public.classes c
    cross join (values (120), (60), (30), (10), (3), (0), (-10)) m(at_min)
    join lateral (
      select x.user_id from public.class_registrations x where x.class_id = c.id and (m.at_min <> -10 or x.joined_at is null)
      union
      select e.user_id from public.class_enrollments e where c.program_id is not null and e.program_id = c.program_id
        and (m.at_min <> -10 or not exists (select 1 from public.class_registrations x2 where x2.class_id = c.id and x2.user_id = e.user_id and x2.joined_at is not null))
    ) g on true
    where c.status = 'published'
      and now() >= c.starts_at - make_interval(mins => m.at_min)
      and now() < c.starts_at - make_interval(mins => m.at_min) + interval '5 minutes'
      and not exists (select 1 from public.class_reminders_sent s where s.class_id = c.id and s.user_id = g.user_id and s.at_min = m.at_min)
  loop
    insert into public.class_reminders_sent (class_id, user_id, at_min) values (r.id, r.user_id, r.at_min) on conflict do nothing;
    if not found then continue; end if;
    insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, source_ref, link)
    values ('classes',
      case when r.at_min > 60 then 'Class in 2 hours' when r.at_min = 60 then 'Class in 1 hour' when r.at_min > 0 then 'Class in ' || r.at_min || ' minutes'
           when r.at_min = 0 then 'Your class is starting now' else 'Your class started 10 minutes ago' end,
      r.title || case when r.at_min <= 10 then '. Tap to join.' else '.' end,
      'user', r.user_id, 'scheduled', now(), 'admin', 'class:' || r.id || ':' || r.at_min,
      jsonb_build_object('type', 'screen', 'target', '/classes/' || r.id));
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

-- Paystack start: a programme id is a "class_program" purchase (one payment per student, ever).
create or replace function public.content_pay_start(p_uid uuid, p_kind text, p_ref text, p_source text default 'app'::text)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare o jsonb; v_ref text; v_pay uuid; v_email text; v_price integer; v_fee integer; v_title text; v_exam smallint; v_year smallint;
begin
  if p_uid is null then return jsonb_build_object('ok', false, 'error', 'auth'); end if;
  if p_kind = 'item' and p_ref ~ '^[0-9a-f-]{36}$' then
    if exists (select 1 from public.class_programs cp where cp.id = p_ref::uuid) then p_kind := 'class_program';
    elsif exists (select 1 from public.classes c where c.id = p_ref::uuid) then p_kind := 'class';
    elsif to_regclass('public.tutor_plans') is not null and private.tutor_offer(p_ref::uuid, p_uid) is not null then p_kind := 'tutor';
    end if;
  end if;
  if private.is_banned(p_uid) then return jsonb_build_object('ok', false, 'error', 'banned'); end if;
  if p_kind <> 'tutor' and exists (select 1 from public.content_purchases c where c.user_id = p_uid and c.kind = p_kind and c.ref = p_ref) then
    return jsonb_build_object('ok', false, 'error', 'bought');
  end if;
  if p_kind = 'class_program' and exists (select 1 from public.class_enrollments e where e.user_id = p_uid and e.program_id = p_ref::uuid) then
    return jsonb_build_object('ok', false, 'error', 'bought');
  end if;
  if (select count(*) from public.pay_attempts a where a.user_id = p_uid and a.action = 'start' and a.created_at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  if p_kind = 'item' then
    o := private.item_offer(nullif(p_ref, '')::uuid);
    select plain into v_title from (select regexp_replace(coalesce(o ->> 'title', 'Study item'), '\s+', ' ', 'g') as plain) t;
  elsif p_kind = 'year' then
    v_exam := split_part(p_ref, ':', 1)::smallint; v_year := split_part(p_ref, ':', 2)::smallint;
    o := private.year_offer(v_exam, v_year);
    select e.code || ' ' || v_year into v_title from public.exam_bodies e where e.id = v_exam;
  elsif p_kind = 'class' then
    o := private.class_offer(nullif(p_ref, '')::uuid);
    v_title := o ->> 'title';
  elsif p_kind = 'class_program' then
    o := private.program_offer(nullif(p_ref, '')::uuid);
    v_title := o ->> 'title';
  elsif p_kind = 'tutor' then
    o := private.tutor_offer(nullif(p_ref, '')::uuid, p_uid);
    v_title := o ->> 'title';
  end if;
  if o is null or o ->> 'mode' <> 'pay' then return jsonb_build_object('ok', false, 'error', 'not_for_sale'); end if;
  v_price := (o ->> 'price_kobo')::int;
  if v_price is null or v_price < 5000 then return jsonb_build_object('ok', false, 'error', 'not_for_sale'); end if;
  v_fee := private.paystack_fee(v_price);
  insert into public.pay_attempts (user_id, action, ok) values (p_uid, 'start', true);
  select u.email into v_email from auth.users u where u.id = p_uid;
  v_ref := 'st_' || encode(extensions.gen_random_bytes(10), 'hex');
  insert into public.payments (user_id, provider, plan_id, item_kind, item_ref, reference, list_kobo, discount_kobo, amount_kobo, fee_kobo, source)
  values (p_uid, 'paystack', null, p_kind, p_ref, v_ref, v_price, 0, v_price + v_fee, v_fee, case when p_source = 'web' then 'web' else 'app' end)
  returning id into v_pay;
  insert into public.payment_events (payment_id, provider, kind, ok, note, data)
  values (v_pay, 'server', 'started', true, 'Item: ' || left(coalesce(v_title, p_ref), 80) || ' for ₦' || (v_price / 100)
            || case when v_fee > 0 then ' + ₦' || (v_fee / 100) || ' fee' else '' end,
          jsonb_build_object('kind', p_kind, 'ref', p_ref, 'amount_kobo', v_price + v_fee, 'fee_kobo', v_fee));
  return jsonb_build_object('ok', true, 'payment_id', v_pay, 'reference', v_ref, 'amount_kobo', v_price + v_fee, 'price_kobo', v_price,
                            'fee_kobo', v_fee, 'email', v_email, 'title', v_title);
end;
$function$;

-- The "paid" notification for a programme opens it in the app.
do $do$
declare d text := pg_get_functiondef('private.finish_payment'::regproc); n text;
begin
  n := replace(d, $a$case when p.item_kind = 'class' then 'classes'$a$, $a$case when p.item_kind in ('class', 'class_program') then 'classes'$a$);
  n := replace(n, $a$case p.item_kind when 'class' then 'You are in the class'$a$, $a$case p.item_kind when 'class' then 'You are in the class' when 'class_program' then 'You are in the class'$a$);
  n := replace(n, $a$case p.item_kind when 'class' then 'Thanks! We will remind you before it starts.'$a$,
               $a$case p.item_kind when 'class' then 'Thanks! We will remind you before it starts.' when 'class_program' then 'Thanks! You can join every session. We will remind you before each one.'$a$);
  n := replace(n, $a$case p.item_kind when 'class' then '/classes/' || p.item_ref$a$, $a$case p.item_kind when 'class' then '/classes/' || p.item_ref when 'class_program' then '/classes/program/' || p.item_ref$a$);
  if n = d or (length(n) - length(d)) < 200 then raise exception 'finish_payment did not change as expected'; end if;
  execute n;
end $do$;
