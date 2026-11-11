-- Online classes (C13, D-147): Free, Premium or Paid live classes. The join and recording links live in a staff-only
-- table and are handed out only by class_join() / class_recording() to students who may come in.
create table public.classes (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 3 and 120),
  about text check (char_length(about) <= 2000),
  subject_id smallint references public.subjects(id),
  exam text check (exam ~ '^[A-Z][A-Z0-9]{1,11}$'),
  teacher text not null check (char_length(teacher) between 2 and 80),
  starts_at timestamptz not null,
  minutes smallint not null default 60 check (minutes between 10 and 480),
  access text not null default 'free' check (access in ('free', 'premium', 'paid')),
  price_kobo integer check (price_kobo is null or price_kobo between 5000 and 100000000),
  seats integer check (seats is null or seats > 0),
  status text not null default 'draft' check (status in ('draft', 'published', 'cancelled')),
  web_only boolean not null default false,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (access <> 'paid' or price_kobo is not null)
);
create index classes_start_idx on public.classes (starts_at) where status = 'published';
create table public.class_links (
  class_id uuid primary key references public.classes(id) on delete cascade,
  join_url text check (join_url is null or join_url ~ '^https://'),
  recording_url text check (recording_url is null or recording_url ~ '^https://'),
  updated_at timestamptz not null default now()
);
create table public.class_registrations (
  class_id uuid not null references public.classes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  payment_id uuid references public.payments(id),
  created_at timestamptz not null default now(),
  joined_at timestamptz,
  primary key (class_id, user_id)
);
create index class_registrations_user_idx on public.class_registrations (user_id);
create table public.class_reminders_sent (
  class_id uuid not null references public.classes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  at_min integer not null,
  primary key (class_id, user_id, at_min)
);

alter table public.classes enable row level security;
alter table public.class_links enable row level security;
alter table public.class_registrations enable row level security;
alter table public.class_reminders_sent enable row level security;
create policy "read published" on public.classes for select to authenticated using (status <> 'draft' or private.is_staff());
create policy "editors" on public.classes for all to authenticated
  using (private.can_edit(array['super_admin','admin','editor']::staff_role[])) with check (private.can_edit(array['super_admin','admin','editor']::staff_role[]));
create policy "editors only" on public.class_links for all to authenticated
  using (private.can_edit(array['super_admin','admin','editor']::staff_role[])) with check (private.can_edit(array['super_admin','admin','editor']::staff_role[]));
create policy "own or staff" on public.class_registrations for select to authenticated using (user_id = (select auth.uid()) or private.is_staff());
grant select, insert, update, delete on public.classes, public.class_links to authenticated;
grant select on public.class_registrations to authenticated;
create trigger classes_audit after insert or update or delete on public.classes for each row execute function private.audit_row();
create trigger classes_touch before update on public.classes for each row execute function private.touch_updated_at();
create trigger class_links_audit after insert or update or delete on public.class_links for each row execute function private.audit_row();

-- Payments: 'class' (and 'tutor' for C12) join the item kinds.
alter table public.content_purchases drop constraint content_purchases_kind_check;
alter table public.content_purchases add constraint content_purchases_kind_check check (kind in ('item', 'year', 'class', 'tutor'));
alter table public.payments drop constraint payments_item_kind_check;
alter table public.payments add constraint payments_item_kind_check check (item_kind is null or item_kind in ('item', 'year', 'class', 'tutor'));

-- May this student come to this class? (registered, or Free/Premium rules; Paid needs a registration from payment)
create or replace function private.class_allowed(p_class uuid, p_uid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.class_registrations r where r.class_id = p_class and r.user_id = p_uid)
      or exists (select 1 from public.classes c where c.id = p_class and c.status = 'published'
                 and (c.access = 'free' or (c.access = 'premium' and private.has_premium(p_uid))))
      or private.is_staff();
$$;

-- The app's list: upcoming and live classes, then the last 30 days with recordings.
create or replace function public.classes_list() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', c.id, 'title', c.title, 'about', c.about, 'subject_id', c.subject_id, 'exam', c.exam, 'teacher', c.teacher,
      'starts_at', c.starts_at, 'minutes', c.minutes, 'access', c.access, 'price_kobo', c.price_kobo, 'status', c.status,
      'seats', c.seats, 'taken', (select count(*) from public.class_registrations r where r.class_id = c.id),
      'registered', exists (select 1 from public.class_registrations r where r.class_id = c.id and r.user_id = (select auth.uid())),
      'allowed', private.class_allowed(c.id, (select auth.uid())),
      'has_recording', coalesce((select l.recording_url is not null from public.class_links l where l.class_id = c.id), false),
      'live', now() between c.starts_at - interval '15 minutes' and c.starts_at + make_interval(mins => c.minutes))
    order by c.starts_at), '[]'::jsonb)
  from public.classes c
  where (select auth.uid()) is not null and c.status <> 'draft' and not c.web_only
    and c.starts_at + make_interval(mins => c.minutes) > now() - interval '30 days';
$$;

-- Register for a Free or Premium class (Paid classes register through payment).
create or replace function public.class_register(p_class uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.classes; v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  if private.is_banned(v_uid) then return jsonb_build_object('ok', false, 'error', 'banned'); end if;
  select * into c from public.classes where id = p_class and status = 'published';
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if c.starts_at + make_interval(mins => c.minutes) < now() then return jsonb_build_object('ok', false, 'error', 'ended'); end if;
  if exists (select 1 from public.class_registrations r where r.class_id = p_class and r.user_id = v_uid) then return jsonb_build_object('ok', true); end if;
  if c.access = 'paid' then return jsonb_build_object('ok', false, 'error', 'pay'); end if;
  if c.access = 'premium' and not private.has_premium(v_uid) then return jsonb_build_object('ok', false, 'error', 'premium'); end if;
  if c.seats is not null and (select count(*) from public.class_registrations r where r.class_id = p_class) >= c.seats then
    return jsonb_build_object('ok', false, 'error', 'full');
  end if;
  insert into public.class_registrations (class_id, user_id) values (p_class, v_uid) on conflict do nothing;
  return jsonb_build_object('ok', true);
end $$;

-- The join link: only for a student who may come in, from 15 minutes before the start until the end.
create or replace function public.class_join(p_class uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.classes; v_uid uuid := (select auth.uid()); v_url text;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into c from public.classes where id = p_class and status = 'published';
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not private.class_allowed(p_class, v_uid) then return jsonb_build_object('ok', false, 'error', case when c.access = 'paid' then 'pay' else 'premium' end); end if;
  if now() < c.starts_at - interval '15 minutes' then return jsonb_build_object('ok', false, 'error', 'early', 'opens_at', c.starts_at - interval '15 minutes'); end if;
  if now() > c.starts_at + make_interval(mins => c.minutes) then return jsonb_build_object('ok', false, 'error', 'ended'); end if;
  select l.join_url into v_url from public.class_links l where l.class_id = p_class;
  if v_url is null then return jsonb_build_object('ok', false, 'error', 'no_link'); end if;
  insert into public.class_registrations (class_id, user_id, joined_at) values (p_class, v_uid, now())
  on conflict (class_id, user_id) do update set joined_at = coalesce(public.class_registrations.joined_at, now());
  return jsonb_build_object('ok', true, 'url', v_url);
end $$;

create or replace function public.class_recording(p_class uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_url text;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  if not private.class_allowed(p_class, v_uid) then return jsonb_build_object('ok', false, 'error', 'locked'); end if;
  select l.recording_url into v_url from public.class_links l where l.class_id = p_class;
  if v_url is null then return jsonb_build_object('ok', false, 'error', 'no_recording'); end if;
  return jsonb_build_object('ok', true, 'url', v_url);
end $$;

-- Paying for a class registers the student (content_purchases kind 'class').
create or replace function private.class_paid() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.kind = 'class' then
    insert into public.class_registrations (class_id, user_id, payment_id) values (new.ref::uuid, new.user_id, new.payment_id)
    on conflict (class_id, user_id) do update set payment_id = excluded.payment_id;
  end if;
  return new;
end $$;
create trigger content_purchases_class after insert on public.content_purchases for each row execute function private.class_paid();

-- Price check for a paid class, used by content_pay_start.
create or replace function private.class_offer(p_class uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when c.id is null then null else jsonb_build_object(
    'mode', case when c.status = 'published' and c.access = 'paid' and c.starts_at + make_interval(mins => c.minutes) > now()
                  and (c.seats is null or (select count(*) from public.class_registrations r where r.class_id = c.id) < c.seats)
             then 'pay' else 'closed' end,
    'price_kobo', c.price_kobo, 'title', 'Class: ' || c.title) end
  from (select 1) x left join public.classes c on c.id = p_class;
$$;

-- Tutor plans come with C12; until then this sells nothing.
create or replace function private.tutor_offer(p_plan uuid) returns jsonb language sql stable set search_path = '' as 'select null::jsonb';

do $$
declare d text := pg_get_functiondef('public.content_pay_start(uuid,text,text,text)'::regprocedure);
begin
  d := replace(d, $r$  end if;
  if o is null or o ->> 'mode' <> 'pay' then$r$, $r$  elsif p_kind = 'class' then
    o := private.class_offer(nullif(p_ref, '')::uuid);
    v_title := o ->> 'title';
  elsif p_kind = 'tutor' then
    o := private.tutor_offer(nullif(p_ref, '')::uuid);
    v_title := o ->> 'title';
  end if;
  if o is null or o ->> 'mode' <> 'pay' then$r$);
  if position('class_offer' in d) = 0 then raise exception 'content_pay_start not changed'; end if;
  execute d;

  d := pg_get_functiondef('private.finish_payment(uuid,entitlement_source)'::regprocedure);
  d := replace(d, $r$values ('account', 'It is yours', 'Thanks! What you paid for is open for good.', 'user', p.user_id, 'scheduled', now(), 'premium',
            jsonb_build_object('type', 'screen', 'target', '/study'));$r$,
    $r$values (case when p.item_kind = 'class' then 'classes' else 'account' end,
            case p.item_kind when 'class' then 'You are in the class' when 'tutor' then 'Your tutor plan is on' else 'It is yours' end,
            case p.item_kind when 'class' then 'Thanks! We will remind you before it starts.' when 'tutor' then 'Thanks! Your tutor will be in touch in the app.'
                 else 'Thanks! What you paid for is open for good.' end,
            'user', p.user_id, 'scheduled', now(), 'premium',
            jsonb_build_object('type', 'screen', 'target', case p.item_kind when 'class' then '/classes/' || p.item_ref when 'tutor' then '/tutor' else '/study' end));$r$);
  if position('You are in the class' in d) = 0 then raise exception 'finish_payment not changed'; end if;
  execute d;
end $$;

-- Reminders every minute: 120, 60, 30, 10 and 3 minutes before, at the start (0), and 10 minutes in (-10) for
-- students who have not joined. Each once per student.
create or replace function private.class_reminders_job() returns integer
language plpgsql security definer set search_path = '' as $$
declare r record; v_n integer := 0;
begin
  for r in
    select c.id, c.title, g.user_id, m.at_min
    from public.classes c
    cross join (values (120), (60), (30), (10), (3), (0), (-10)) m(at_min)
    join lateral (
      select x.user_id from public.class_registrations x where x.class_id = c.id
        and (m.at_min <> -10 or x.joined_at is null)
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

-- Admin: registrations of a class with names and who joined.
create or replace function public.admin_class_students(p_class uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('name', coalesce(p.full_name, 'Student'), 'email', u.email, 'registered_at', r.created_at,
           'joined_at', r.joined_at, 'paid', r.payment_id is not null) order by r.created_at), '[]'::jsonb)
  from public.class_registrations r join public.profiles p on p.id = r.user_id left join auth.users u on u.id = r.user_id
  where r.class_id = p_class and private.is_staff();
$$;

revoke all on function private.class_allowed(uuid, uuid), private.class_paid(), private.class_offer(uuid), private.tutor_offer(uuid),
  private.class_reminders_job() from public, anon, authenticated;
revoke all on function public.classes_list(), public.class_register(uuid), public.class_join(uuid), public.class_recording(uuid),
  public.admin_class_students(uuid) from public, anon;
grant execute on function public.classes_list(), public.class_register(uuid), public.class_join(uuid), public.class_recording(uuid),
  public.admin_class_students(uuid) to authenticated;

select cron.schedule('class-reminders', '* * * * *', 'select private.class_reminders_job()');

