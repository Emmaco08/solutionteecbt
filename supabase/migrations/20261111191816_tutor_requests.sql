-- Request a tutor (C12, D-149): a request, a chat with the SolutionTee team, tutor plans bought with Paystack, and the
-- assigned tutor's WhatsApp / phone shown only while the student's plan is active.
create table public.tutors (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 80),
  subjects text check (char_length(subjects) <= 200),
  bio text check (char_length(bio) <= 600),
  whatsapp text check (whatsapp is null or whatsapp ~ '^\+?[0-9]{10,15}$'),
  phone text check (phone is null or phone ~ '^\+?[0-9]{10,15}$'),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.tutor_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 80),
  description text check (char_length(description) <= 400),
  price_kobo integer not null check (price_kobo between 5000 and 100000000),
  days smallint not null default 30 check (days between 1 and 366),
  sessions smallint check (sessions is null or sessions between 1 and 200),
  active boolean not null default true,
  sort integer not null default 0,
  created_at timestamptz not null default now()
);
create table public.tutor_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  subject_id smallint references public.subjects(id),
  level text not null check (level in ('jamb', 'waec', 'neco', 'post_utme', 'other')),
  goals text not null check (char_length(btrim(goals)) between 5 and 1000),
  times text check (char_length(times) <= 300),
  status text not null default 'new' check (status in ('new', 'replied', 'matched', 'closed')),
  tutor_id uuid references public.tutors(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index tutor_requests_user_idx on public.tutor_requests (user_id, created_at desc);
create index tutor_requests_open_idx on public.tutor_requests (status, updated_at desc) where status <> 'closed';
create table public.tutor_messages (
  id bigint generated always as identity primary key,
  request_id uuid not null references public.tutor_requests(id) on delete cascade,
  from_staff boolean not null default false,
  sender_id uuid default auth.uid(),
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index tutor_messages_request_idx on public.tutor_messages (request_id, created_at);
create table public.tutor_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  plan_id uuid not null references public.tutor_plans(id),
  request_id uuid references public.tutor_requests(id) on delete set null,
  payment_id uuid references public.payments(id),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null
);
create index tutor_subscriptions_user_idx on public.tutor_subscriptions (user_id, ends_at desc);

alter table public.tutors enable row level security;
alter table public.tutor_plans enable row level security;
alter table public.tutor_requests enable row level security;
alter table public.tutor_messages enable row level security;
alter table public.tutor_subscriptions enable row level security;
create policy "staff" on public.tutors for all to authenticated
  using (private.can_edit(array['super_admin','admin']::staff_role[])) with check (private.can_edit(array['super_admin','admin']::staff_role[]));
create policy "staff read" on public.tutors for select to authenticated using (private.is_staff());
create policy "read active" on public.tutor_plans for select to authenticated using (active or private.is_staff());
create policy "admins" on public.tutor_plans for all to authenticated
  using (private.can_edit(array['super_admin','admin']::staff_role[])) with check (private.can_edit(array['super_admin','admin']::staff_role[]));
create policy "own or staff" on public.tutor_requests for select to authenticated using (user_id = (select auth.uid()) or private.is_staff());
create policy "staff edit" on public.tutor_requests for update to authenticated using (private.is_staff()) with check (private.is_staff());
create policy "own or staff" on public.tutor_messages for select to authenticated
  using (private.is_staff() or exists (select 1 from public.tutor_requests r where r.id = request_id and r.user_id = (select auth.uid())));
create policy "own or staff" on public.tutor_subscriptions for select to authenticated using (user_id = (select auth.uid()) or private.is_staff());
grant select, insert, update, delete on public.tutors, public.tutor_plans to authenticated;
grant select on public.tutor_requests, public.tutor_messages, public.tutor_subscriptions to authenticated;
grant update (status, tutor_id, updated_at) on public.tutor_requests to authenticated;
create trigger tutors_audit after insert or update or delete on public.tutors for each row execute function private.audit_row();
create trigger tutor_plans_audit after insert or update or delete on public.tutor_plans for each row execute function private.audit_row();

-- Price check for a tutor plan (used by content_pay_start; replaces the placeholder from D-147).
create or replace function private.tutor_offer(p_plan uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when p.id is null then null else jsonb_build_object('mode', case when p.active then 'pay' else 'closed' end,
    'price_kobo', p.price_kobo, 'title', 'Tutor plan: ' || p.name) end
  from (select 1) x left join public.tutor_plans p on p.id = p_plan;
$$;
revoke all on function private.tutor_offer(uuid) from public, anon, authenticated;

-- A tutor plan can be bought again (each purchase adds time), so it is not "owned for good" like a study item.
do $$
declare d text := pg_get_functiondef('public.content_pay_start(uuid,text,text,text)'::regprocedure);
begin
  d := replace(d, $r$  if exists (select 1 from public.content_purchases c where c.user_id = p_uid and c.kind = p_kind and c.ref = p_ref) then$r$,
                  $r$  if p_kind <> 'tutor' and exists (select 1 from public.content_purchases c where c.user_id = p_uid and c.kind = p_kind and c.ref = p_ref) then$r$);
  if position($r$p_kind <> 'tutor'$r$ in d) = 0 then raise exception 'content_pay_start not changed'; end if;
  execute d;
  d := pg_get_functiondef('private.finish_payment(uuid,entitlement_source)'::regprocedure);
  d := replace(d, $r$    insert into public.content_purchases (user_id, kind, ref, payment_id) values (p.user_id, p.item_kind, p.item_ref, p.id)
    on conflict (user_id, kind, ref) do nothing;$r$,
  $r$    if p.item_kind = 'tutor' then
      perform private.tutor_paid(p.id);
    else
      insert into public.content_purchases (user_id, kind, ref, payment_id) values (p.user_id, p.item_kind, p.item_ref, p.id)
      on conflict (user_id, kind, ref) do nothing;
    end if;$r$);
  if position('tutor_paid' in d) = 0 then raise exception 'finish_payment not changed'; end if;
  execute d;
end $$;

-- A paid tutor plan: adds the plan's days after any time still left, linked to the student's latest open request.
create or replace function private.tutor_paid(p_pay uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare p public.payments; pl public.tutor_plans; v_from timestamptz; v_req uuid;
begin
  select * into p from public.payments where id = p_pay;
  if exists (select 1 from public.tutor_subscriptions s where s.payment_id = p_pay) then return; end if;
  select * into pl from public.tutor_plans where id = p.item_ref::uuid;
  select greatest(now(), coalesce(max(s.ends_at), now())) into v_from from public.tutor_subscriptions s where s.user_id = p.user_id;
  select r.id into v_req from public.tutor_requests r where r.user_id = p.user_id and r.status <> 'closed' order by r.created_at desc limit 1;
  insert into public.tutor_subscriptions (user_id, plan_id, request_id, payment_id, starts_at, ends_at)
  values (p.user_id, pl.id, v_req, p.id, v_from, v_from + make_interval(days => pl.days));
  if v_req is not null then
    insert into public.tutor_messages (request_id, from_staff, sender_id, body)
    values (v_req, true, null, 'Thank you! Your ' || pl.name || ' plan is on until ' || to_char((v_from + make_interval(days => pl.days)) at time zone 'Africa/Lagos', 'DD Mon YYYY') || '. We will connect you with your tutor here.');
    update public.tutor_requests set updated_at = now() where id = v_req;
  end if;
end $$;
revoke all on function private.tutor_paid(uuid) from public, anon, authenticated;

-- Everything the app's tutor screen needs.
create or replace function public.tutor_overview() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); r public.tutor_requests; v_sub jsonb; t public.tutors;
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  select * into r from public.tutor_requests x where x.user_id = v_uid order by x.created_at desc limit 1;
  select jsonb_build_object('plan', pl.name, 'ends_at', max(s.ends_at)) into v_sub
  from public.tutor_subscriptions s join public.tutor_plans pl on pl.id = s.plan_id
  where s.user_id = v_uid and s.ends_at > now() group by pl.name order by max(s.ends_at) desc limit 1;
  if r.tutor_id is not null and v_sub is not null then select * into t from public.tutors where id = r.tutor_id; end if;
  return jsonb_build_object(
    'request', case when r.id is null then null else jsonb_build_object('id', r.id, 'subject_id', r.subject_id, 'level', r.level, 'goals', r.goals,
      'times', r.times, 'status', r.status, 'created_at', r.created_at) end,
    'messages', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'from_staff', m.from_staff, 'body', m.body, 'at', m.created_at) order by m.created_at)
                          from public.tutor_messages m where m.request_id = r.id), '[]'::jsonb),
    'plans', coalesce((select jsonb_agg(jsonb_build_object('id', pl.id, 'name', pl.name, 'description', pl.description, 'price_kobo', pl.price_kobo,
                         'days', pl.days, 'sessions', pl.sessions) order by pl.sort, pl.price_kobo) from public.tutor_plans pl where pl.active), '[]'::jsonb),
    'subscription', v_sub,
    'tutor', case when t.id is null then null else jsonb_build_object('name', t.name, 'subjects', t.subjects, 'bio', t.bio, 'whatsapp', t.whatsapp, 'phone', t.phone) end);
end $$;

-- A new request (one open request at a time; 3 a day).
create or replace function public.tutor_request_create(p_subject smallint, p_level text, p_goals text, p_times text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_id uuid;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  if exists (select 1 from public.tutor_requests r where r.user_id = v_uid and r.status in ('new', 'replied', 'matched')) then
    return jsonb_build_object('ok', false, 'error', 'open');
  end if;
  if (select count(*) from public.tutor_requests r where r.user_id = v_uid and r.created_at > now() - interval '1 day') >= 3 then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  if char_length(btrim(coalesce(p_goals, ''))) < 5 then return jsonb_build_object('ok', false, 'error', 'goals'); end if;
  insert into public.tutor_requests (user_id, subject_id, level, goals, times)
  values (v_uid, p_subject, case when p_level in ('jamb', 'waec', 'neco', 'post_utme') then p_level else 'other' end, left(btrim(p_goals), 1000), left(btrim(coalesce(p_times, '')), 300))
  returning id into v_id;
  insert into public.tutor_messages (request_id, from_staff, sender_id, body)
  values (v_id, true, null, 'Thanks! We got your request. Someone from SolutionTee will reply here, usually within a day. You also get an email.');
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

-- A message from the student (20 an hour) or from staff (also emails and notifies the student).
create or replace function public.tutor_message_send(p_request uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); r public.tutor_requests; v_staff boolean := private.is_staff();
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into r from public.tutor_requests where id = p_request;
  if not found or (r.user_id <> v_uid and not v_staff) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if char_length(btrim(coalesce(p_body, ''))) < 1 or char_length(p_body) > 2000 then return jsonb_build_object('ok', false, 'error', 'length'); end if;
  if not v_staff and (select count(*) from public.tutor_messages m where m.request_id = p_request and not m.from_staff and m.created_at > now() - interval '1 hour') >= 20 then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  insert into public.tutor_messages (request_id, from_staff, sender_id, body) values (p_request, v_staff and r.user_id <> v_uid, v_uid, btrim(p_body));
  update public.tutor_requests set updated_at = now(),
    status = case when v_staff and r.user_id <> v_uid and r.status = 'new' then 'replied' when r.status = 'closed' then 'new' else r.status end
  where id = p_request;
  if v_staff and r.user_id <> v_uid then
    perform private.queue_email(r.user_id, 'tutor_reply', jsonb_build_object('body', left(btrim(p_body), 600)));
    insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
    values ('account', 'SolutionTee replied about your tutor', left(btrim(p_body), 140), 'user', r.user_id, 'scheduled', now(), 'admin',
            jsonb_build_object('type', 'screen', 'target', '/tutor'));
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- Staff: the requests list with the student's name, plan and last message.
create or replace function public.admin_tutor_requests(p_status text default 'open') returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x order by (x ->> 'updated_at') desc), '[]'::jsonb) from (
    select jsonb_build_object('id', r.id, 'user_id', r.user_id, 'name', coalesce(p.full_name, 'Student'), 'email', u.email, 'phone', p.phone,
      'subject', s.name, 'level', r.level, 'goals', r.goals, 'times', r.times, 'status', r.status, 'tutor_id', r.tutor_id,
      'created_at', r.created_at, 'updated_at', r.updated_at,
      'plan_until', (select max(t.ends_at) from public.tutor_subscriptions t where t.user_id = r.user_id and t.ends_at > now()),
      'messages', (select coalesce(jsonb_agg(jsonb_build_object('from_staff', m.from_staff, 'body', m.body, 'at', m.created_at) order by m.created_at), '[]'::jsonb)
                   from public.tutor_messages m where m.request_id = r.id)) x
    from public.tutor_requests r
    join public.profiles p on p.id = r.user_id left join auth.users u on u.id = r.user_id left join public.subjects s on s.id = r.subject_id
    where private.is_staff() and (p_status = 'all' or (p_status = 'open' and r.status <> 'closed') or r.status = p_status)
    order by r.updated_at desc limit 200) t;
$$;

revoke all on function public.tutor_overview(), public.tutor_request_create(smallint, text, text, text), public.tutor_message_send(uuid, text),
  public.admin_tutor_requests(text) from public, anon;
grant execute on function public.tutor_overview(), public.tutor_request_create(smallint, text, text, text), public.tutor_message_send(uuid, text),
  public.admin_tutor_requests(text) to authenticated;

