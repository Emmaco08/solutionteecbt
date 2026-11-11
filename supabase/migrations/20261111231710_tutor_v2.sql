-- Tutor v2 (D-152): pay first, then a real tutor (staff role `tutor`) chats with the student like WhatsApp: text,
-- photos, voice notes, files, call links and references to past questions and notes, read ticks, live updates.
-- Tutors see only their own students; general "staff" access and staff broadcasts never include them.

-- 1. Tutors are not general staff.
create or replace function private.is_staff(roles public.staff_role[] default null) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.is_aal2() and exists (
    select 1 from public.staff s
    where s.user_id = (select auth.uid())
      and ((roles is null and s.role <> 'tutor') or s.role = any (roles))
  );
$$;
do $$
declare d text := pg_get_functiondef('public.push_take_due'::regproc);
begin
  d := replace(d, $r$(t.audience = 'staff' and exists (select 1 from public.staff s where s.user_id = pt.user_id))$r$,
                  $r$(t.audience = 'staff' and exists (select 1 from public.staff s where s.user_id = pt.user_id and s.role <> 'tutor'))$r$);
  if position($r$s.role <> 'tutor'$r$ in d) = 0 then raise exception 'push_take_due not changed'; end if;
  execute d;
end $$;

-- 2. Tutors are logins; requests follow the paid flow.
alter table public.tutors add column if not exists user_id uuid unique references public.profiles(id) on delete set null,
  add column if not exists photo_path text check (photo_path is null or photo_path ~ '^[A-Za-z0-9/_.-]+$'),
  add column if not exists last_seen_at timestamptz;
alter table public.tutor_plans add column if not exists play_product_id text unique check (play_product_id is null or play_product_id ~ '^[a-z0-9._]{1,100}$');
alter table public.tutor_requests add column if not exists plan_id uuid references public.tutor_plans(id),
  add column if not exists custom_note text check (char_length(custom_note) <= 1000),
  add column if not exists custom_price_kobo integer check (custom_price_kobo is null or custom_price_kobo between 5000 and 100000000),
  add column if not exists custom_days smallint check (custom_days is null or custom_days between 1 and 366),
  add column if not exists paid_at timestamptz,
  add column if not exists assigned_at timestamptz,
  add column if not exists tutor_emailed_at timestamptz;
alter table public.tutor_requests drop constraint if exists tutor_requests_status_check;
update public.tutor_requests set status = 'new' where status = 'replied';
alter table public.tutor_requests add constraint tutor_requests_status_check check (status in ('new', 'quoted', 'paid', 'matched', 'ended', 'closed'));
alter table public.tutor_subscriptions alter column plan_id drop not null;

alter table public.tutor_messages add column if not exists sender_role text not null default 'student'
    check (sender_role in ('student', 'tutor', 'admin', 'system')),
  add column if not exists kind text not null default 'text' check (kind in ('text', 'image', 'voice', 'file', 'link', 'ref')),
  add column if not exists attachment_path text check (attachment_path is null or attachment_path ~ '^t/[0-9a-f-]{36}/[A-Za-z0-9._-]+$'),
  add column if not exists meta jsonb,
  add column if not exists ref jsonb;
update public.tutor_messages set sender_role = case when sender_id is null then 'system' else 'admin' end where from_staff;
alter table public.tutor_messages drop constraint if exists tutor_messages_body_check;
alter table public.tutor_messages add constraint tutor_messages_body_check check (char_length(body) <= 4000 and (kind <> 'text' or char_length(btrim(body)) >= 1));
alter table public.tutor_messages alter column body set default '';
create index if not exists tutor_messages_unread_idx on public.tutor_messages (request_id) where read_at is null;

-- 3. Who is in a chat.
create or replace function private.my_tutor_id() returns uuid language sql stable security definer set search_path = '' as $$
  select t.id from public.tutors t join public.staff s on s.user_id = t.user_id and s.role = 'tutor'
  where t.user_id = (select auth.uid()) and private.is_aal2() limit 1;
$$;
create or replace function private.is_tutor_of(p_request uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.tutor_requests r where r.id = p_request and r.tutor_id is not null and r.tutor_id = private.my_tutor_id());
$$;
create or replace function private.tutor_chat_member(p_request uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.tutor_requests r where r.id = p_request and r.user_id = (select auth.uid()))
      or private.is_tutor_of(p_request) or private.tutor_staff();
$$;
-- Realtime channel names are "tutor:<request id>".
create or replace function private.tutor_topic_ok(p_topic text) returns boolean language sql stable security definer set search_path = '' as $$
  select case when p_topic ~ '^tutor:[0-9a-f-]{36}$' then private.tutor_chat_member(substr(p_topic, 7)::uuid) else false end;
$$;
grant execute on function private.my_tutor_id(), private.is_tutor_of(uuid), private.tutor_chat_member(uuid), private.tutor_topic_ok(text) to authenticated;

drop policy if exists "own or admins" on public.tutor_requests;
create policy "own, tutor or admins" on public.tutor_requests for select to authenticated
  using (user_id = (select auth.uid()) or private.tutor_staff() or (tutor_id is not null and tutor_id = private.my_tutor_id()));
drop policy if exists "own or admins" on public.tutor_messages;
create policy "chat members" on public.tutor_messages for select to authenticated using (private.tutor_chat_member(request_id));
create policy "tutor reads own" on public.tutors for select to authenticated using (user_id = (select auth.uid()));

-- Live messages and typing / online signals.
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'tutor_messages') then
    alter publication supabase_realtime add table public.tutor_messages;
  end if;
end $$;
drop policy if exists "tutor chat members read" on realtime.messages;
drop policy if exists "tutor chat members write" on realtime.messages;
create policy "tutor chat members read" on realtime.messages for select to authenticated using (private.tutor_topic_ok((select realtime.topic())));
create policy "tutor chat members write" on realtime.messages for insert to authenticated with check (private.tutor_topic_ok((select realtime.topic())));

-- 4. Prices: a plan, or this student's custom price for their own request.
drop function if exists private.tutor_offer(uuid);
create or replace function private.tutor_offer(p_ref uuid, p_uid uuid default null) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select jsonb_build_object('mode', case when p.active then 'pay' else 'closed' end, 'price_kobo', p.price_kobo, 'title', 'Tutor plan: ' || p.name)
     from public.tutor_plans p where p.id = p_ref),
    (select jsonb_build_object('mode', 'pay', 'price_kobo', r.custom_price_kobo, 'title', 'Custom tutor plan')
     from public.tutor_requests r where r.id = p_ref and r.custom_price_kobo is not null and r.status in ('quoted', 'matched', 'ended')
       and (p_uid is null or r.user_id = p_uid)));
$$;
revoke all on function private.tutor_offer(uuid, uuid) from public, anon, authenticated;
do $$
declare d text := pg_get_functiondef('public.content_pay_start(uuid,text,text,text)'::regprocedure);
begin
  d := replace(d, 'private.tutor_offer(p_ref::uuid) is not null', 'private.tutor_offer(p_ref::uuid, p_uid) is not null');
  d := replace(d, $r$o := private.tutor_offer(nullif(p_ref, '')::uuid);$r$, $r$o := private.tutor_offer(nullif(p_ref, '')::uuid, p_uid);$r$);
  if (length(d) - length(replace(d, ', p_uid)', ''))) / length(', p_uid)') < 2 then raise exception 'content_pay_start not changed'; end if;
  execute d;
end $$;

-- Tells super admins and admins (push + email; staff are skipped by queue_email, so the outbox is written directly).
create or replace function private.tutor_tell_admins(p_title text, p_body text, p_kind text, p_data jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare s record;
begin
  for s in select st.user_id from public.staff st where st.role in ('super_admin', 'admin') loop
    insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
    values ('account'::public.notif_topic, left(p_title, 80), left(p_body, 200), 'user', s.user_id, 'scheduled', now(), 'admin',
            jsonb_build_object('type', 'url', 'target', 'https://admin.solutiontee.com/admin/tutors'));
    insert into private.email_outbox (user_id, kind, data) values (s.user_id, p_kind, p_data);
  end loop;
end $$;

-- 5. A paid plan: adds days, moves the request to "paid" (or keeps the tutor on a renewal) and tells the admins.
create or replace function private.tutor_paid(p_pay uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare p public.payments; pl public.tutor_plans; r public.tutor_requests; v_from timestamptz; v_days integer; v_name text; v_until timestamptz;
begin
  select * into p from public.payments where id = p_pay;
  if exists (select 1 from public.tutor_subscriptions s where s.payment_id = p_pay) then return; end if;
  select * into pl from public.tutor_plans where id = p.item_ref::uuid;
  if pl.id is not null then
    v_days := pl.days; v_name := pl.name;
    select * into r from public.tutor_requests x where x.user_id = p.user_id and x.status <> 'closed' order by x.created_at desc limit 1;
  else
    select * into r from public.tutor_requests x where x.id = p.item_ref::uuid and x.user_id = p.user_id;
    v_days := coalesce(r.custom_days, 30); v_name := 'Custom';
  end if;
  select greatest(now(), coalesce(max(s.ends_at), now())) into v_from from public.tutor_subscriptions s where s.user_id = p.user_id;
  v_until := v_from + make_interval(days => v_days);
  insert into public.tutor_subscriptions (user_id, plan_id, request_id, payment_id, starts_at, ends_at)
  values (p.user_id, pl.id, r.id, p.id, v_from, v_until);
  if r.id is null then return; end if;
  update public.tutor_requests set paid_at = now(), plan_id = coalesce(pl.id, plan_id), updated_at = now(),
    status = case when tutor_id is not null then 'matched' else 'paid' end
  where id = r.id returning * into r;
  insert into public.tutor_messages (request_id, from_staff, sender_id, sender_role, body)
  values (r.id, true, null, 'system', case when r.tutor_id is not null
    then 'Payment received. Your ' || v_name || ' plan now runs until ' || to_char(v_until at time zone 'Africa/Lagos', 'DD Mon YYYY') || '.'
    else 'Payment received. Your ' || v_name || ' plan runs until ' || to_char(v_until at time zone 'Africa/Lagos', 'DD Mon YYYY') || '. A tutor will be assigned to you within 24 hours.' end);
  if r.tutor_id is null then
    perform private.tutor_tell_admins('Assign a tutor: ' || private.game_name(r.user_id) || ' paid',
      v_name || ' plan paid. Assign a tutor within 24 hours.', 'tutor_paid_admin',
      jsonb_build_object('student', private.game_name(r.user_id), 'plan', v_name, 'request', r.id));
  end if;
end $$;
revoke all on function private.tutor_paid(uuid), private.tutor_tell_admins(text, text, text, jsonb) from public, anon, authenticated;

-- Google Play: a tutor plan's product goes through the same token-once checks as Premium.
create or replace function public.pay_play_confirm(p_uid uuid, p_product text, p_token text, p_order_id text, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_plan public.plans; v_tp public.tutor_plans; p public.payments; v_pay uuid;
begin
  if private.is_banned(p_uid) then return jsonb_build_object('ok', false, 'error', 'banned'); end if;
  select * into v_plan from public.plans where play_product_id = p_product or play_product_id_fee = p_product;
  if v_plan.id is null then select * into v_tp from public.tutor_plans where play_product_id = p_product; end if;
  if v_plan.id is null and v_tp.id is null then return jsonb_build_object('ok', false, 'error', 'unknown_product'); end if;
  perform pg_advisory_xact_lock(hashtextextended('play:' || p_token, 0));
  select * into p from public.payments where purchase_token = p_token for update;
  if p.id is not null then
    if p.user_id is distinct from p_uid then
      insert into public.payment_events (payment_id, provider, kind, ok, note)
      values (p.id, 'play', 'token_reuse', false, 'Another account sent this purchase token');
      return jsonb_build_object('ok', false, 'error', 'token_used');
    end if;
    return jsonb_build_object('ok', true, 'status', p.status, 'duplicate', true,
      'expires_at', coalesce((select e.expires_at from public.entitlements e where e.id = p.entitlement_id),
                             (select s.ends_at from public.tutor_subscriptions s where s.payment_id = p.id)));
  end if;
  insert into public.payments (user_id, provider, plan_id, item_kind, item_ref, reference, purchase_token, list_kobo, amount_kobo, status, provider_data)
  values (p_uid, 'play', v_plan.id, case when v_tp.id is not null then 'tutor' end, v_tp.id::text,
          coalesce(nullif(p_order_id, ''), 'play_' || encode(extensions.digest(p_token, 'sha256'), 'hex')),
          p_token, coalesce(v_plan.price_kobo, v_tp.price_kobo), coalesce(v_plan.price_kobo, v_tp.price_kobo), 'pending',
          coalesce(p_data, '{}') || jsonb_build_object('product', p_product))
  returning id into v_pay;
  insert into public.payment_events (payment_id, provider, kind, ok, note, data)
  values (v_pay, 'play', 'verified', true, 'Google Play purchase checked with Google (' || p_product || ')', coalesce(p_data, '{}'));
  perform private.finish_payment(v_pay, 'play');
  return jsonb_build_object('ok', true, 'status', 'success',
    'expires_at', coalesce((select e.expires_at from public.entitlements e join public.payments x on x.entitlement_id = e.id where x.id = v_pay),
                           (select s.ends_at from public.tutor_subscriptions s where s.payment_id = v_pay)));
end $$;

-- 6. Student side.
create or replace function private.tutor_card(p_tutor uuid) returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', t.id, 'name', t.name, 'subjects', t.subjects, 'bio', t.bio, 'photo_path', t.photo_path,
    'online', t.last_seen_at > now() - interval '2 minutes', 'last_seen_at', t.last_seen_at)
  from public.tutors t where t.id = p_tutor;
$$;
create or replace function private.tutor_msg_json(m public.tutor_messages) returns jsonb language sql stable as $$
  select jsonb_build_object('id', m.id, 'role', m.sender_role, 'kind', m.kind, 'body', m.body, 'attachment', m.attachment_path, 'meta', m.meta,
    'ref', m.ref, 'at', m.created_at, 'read_at', m.read_at, 'from_staff', m.from_staff);
$$;

drop function if exists public.tutor_overview();
create or replace function public.tutor_overview() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); r public.tutor_requests; v_sub jsonb;
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  -- A plan that ran out ends the chat (renewing opens it again).
  update public.tutor_requests x set status = 'ended', updated_at = now()
  where x.user_id = v_uid and x.status = 'matched'
    and not exists (select 1 from public.tutor_subscriptions s where s.user_id = v_uid and s.ends_at > now());
  select * into r from public.tutor_requests x where x.user_id = v_uid and x.status <> 'closed' order by x.created_at desc limit 1;
  select jsonb_build_object('plan', coalesce(pl.name, 'Custom'), 'ends_at', s.ends_at) into v_sub
  from public.tutor_subscriptions s left join public.tutor_plans pl on pl.id = s.plan_id
  where s.user_id = v_uid and s.ends_at > now() order by s.ends_at desc limit 1;
  return jsonb_build_object(
    'request', case when r.id is null then null else jsonb_build_object('id', r.id, 'subject_id', r.subject_id, 'level', r.level, 'goals', r.goals,
      'times', r.times, 'status', r.status, 'created_at', r.created_at, 'paid_at', r.paid_at, 'custom_note', r.custom_note,
      'custom_price_kobo', r.custom_price_kobo, 'custom_days', r.custom_days) end,
    'messages', coalesce((select jsonb_agg(private.tutor_msg_json(m) order by m.id)
                          from (select * from public.tutor_messages x where x.request_id = r.id order by x.id desc limit 300) m), '[]'::jsonb),
    'plans', coalesce((select jsonb_agg(jsonb_build_object('id', pl.id, 'name', pl.name, 'description', pl.description, 'price_kobo', pl.price_kobo,
                         'days', pl.days, 'sessions', pl.sessions, 'play_product_id', pl.play_product_id) order by pl.sort, pl.price_kobo)
                       from public.tutor_plans pl where pl.active), '[]'::jsonb),
    'subscription', v_sub,
    'tutor', case when r.tutor_id is not null and r.status in ('matched', 'ended') then private.tutor_card(r.tutor_id) end,
    'unread', (select count(*) from public.tutor_messages m where m.request_id = r.id and m.sender_role in ('tutor', 'admin') and m.read_at is null));
end $$;

drop function if exists public.tutor_request_create(smallint, text, text, text);
create or replace function public.tutor_request_create(p_subject smallint, p_level text, p_goals text, p_times text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_id uuid;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  if exists (select 1 from public.tutor_requests r where r.user_id = v_uid and r.status in ('new', 'quoted', 'paid', 'matched')) then
    return jsonb_build_object('ok', false, 'error', 'open');
  end if;
  if (select count(*) from public.tutor_requests r where r.user_id = v_uid and r.created_at > now() - interval '1 day') >= 3 then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  if char_length(btrim(coalesce(p_goals, ''))) < 5 then return jsonb_build_object('ok', false, 'error', 'goals'); end if;
  -- A student whose plan ended starts a new request; the old one closes.
  update public.tutor_requests set status = 'closed', updated_at = now() where user_id = v_uid and status = 'ended';
  insert into public.tutor_requests (user_id, subject_id, level, goals, times)
  values (v_uid, p_subject, case when p_level in ('jamb', 'waec', 'neco', 'post_utme') then p_level else 'other' end, left(btrim(p_goals), 1000), left(btrim(coalesce(p_times, '')), 300))
  returning id into v_id;
  insert into public.tutor_messages (request_id, from_staff, sender_id, sender_role, body)
  values (v_id, true, null, 'system', 'Request received. Choose a plan to get your tutor, or ask for a custom plan.');
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

-- "Custom": the student says what they need; an admin sets the price.
create or replace function public.tutor_custom_request(p_request uuid, p_note text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); r public.tutor_requests;
begin
  select * into r from public.tutor_requests where id = p_request and user_id = v_uid and status in ('new', 'quoted', 'ended');
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if char_length(btrim(coalesce(p_note, ''))) < 5 then return jsonb_build_object('ok', false, 'error', 'short'); end if;
  update public.tutor_requests set custom_note = left(btrim(p_note), 1000), updated_at = now() where id = r.id;
  insert into public.tutor_messages (request_id, from_staff, sender_id, sender_role, body) values (r.id, false, v_uid, 'student', 'Custom plan: ' || left(btrim(p_note), 1000));
  perform private.tutor_tell_admins('Custom tutor plan asked', private.game_name(v_uid) || ': ' || left(btrim(p_note), 150), 'tutor_custom_admin',
    jsonb_build_object('student', private.game_name(v_uid), 'note', left(btrim(p_note), 600)));
  return jsonb_build_object('ok', true);
end $$;

-- 7. Messages: student, their tutor or an admin. Attachments live in the private bucket under t/<request id>/.
drop function if exists public.tutor_message_send(uuid, text);
create or replace function public.tutor_message_send(p_request uuid, p_body text, p_kind text default 'text', p_attachment text default null,
  p_meta jsonb default null, p_ref jsonb default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); r public.tutor_requests; v_role text; v_id bigint; m public.tutor_messages; t public.tutors;
  v_body text := btrim(coalesce(p_body, ''));
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into r from public.tutor_requests where id = p_request;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  v_role := case when r.user_id = v_uid then 'student' when private.is_tutor_of(r.id) then 'tutor' when private.tutor_staff() then 'admin' end;
  if v_role is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if p_kind not in ('text', 'image', 'voice', 'file', 'link', 'ref') then return jsonb_build_object('ok', false, 'error', 'kind'); end if;
  if p_kind = 'text' and char_length(v_body) < 1 then return jsonb_build_object('ok', false, 'error', 'length'); end if;
  if char_length(v_body) > 4000 then return jsonb_build_object('ok', false, 'error', 'length'); end if;
  if p_kind in ('image', 'voice', 'file') and (p_attachment is null or p_attachment !~ ('^t/' || r.id || '/[A-Za-z0-9._-]+$')) then
    return jsonb_build_object('ok', false, 'error', 'attachment');
  end if;
  if p_kind = 'link' and coalesce(p_meta ->> 'url', '') !~ '^https://' then return jsonb_build_object('ok', false, 'error', 'link'); end if;
  if v_role = 'student' then
    if r.status in ('ended', 'closed') then return jsonb_build_object('ok', false, 'error', 'ended'); end if;
    if (select count(*) from public.tutor_messages x where x.request_id = r.id and x.sender_role = 'student' and x.created_at > now() - interval '1 hour') >= 60 then
      return jsonb_build_object('ok', false, 'error', 'too_many');
    end if;
  end if;
  insert into public.tutor_messages (request_id, from_staff, sender_id, sender_role, kind, body, attachment_path, meta, ref)
  values (r.id, v_role <> 'student', v_uid, v_role, p_kind, v_body, p_attachment, p_meta, p_ref) returning * into m;
  update public.tutor_requests set updated_at = now() where id = r.id;
  if v_role = 'tutor' then update public.tutors set last_seen_at = now() where id = r.tutor_id; end if;
  if v_role in ('tutor', 'admin') then
    select * into t from public.tutors where id = r.tutor_id;
    insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
    values ('account'::public.notif_topic, left(case when v_role = 'tutor' then coalesce(t.name, 'Your tutor') else 'SolutionTee' end, 80),
            left(case p_kind when 'image' then '📷 Photo' when 'voice' then '🎤 Voice note' when 'file' then '📎 File'
                 when 'link' then '📞 ' || coalesce(nullif(v_body, ''), 'Call link') when 'ref' then '📚 ' || coalesce(nullif(v_body, ''), 'Study link') else v_body end, 140),
            'user', r.user_id, 'scheduled', now(), 'admin', jsonb_build_object('type', 'screen', 'target', '/tutor'));
  elsif r.tutor_id is not null and r.status = 'matched' then
    -- Email the tutor, at most once every 15 minutes per student while messages wait.
    select * into t from public.tutors where id = r.tutor_id;
    if t.user_id is not null and (r.tutor_emailed_at is null or r.tutor_emailed_at < now() - interval '15 minutes') then
      insert into private.email_outbox (user_id, kind, data) values (t.user_id, 'tutor_student_message',
        jsonb_build_object('student', private.game_name(r.user_id), 'body', left(case when p_kind = 'text' then v_body else 'Sent a ' || p_kind end, 400), 'request', r.id));
      update public.tutor_requests set tutor_emailed_at = now() where id = r.id;
    end if;
  end if;
  return jsonb_build_object('ok', true, 'message', private.tutor_msg_json(m));
end $$;

-- Read ticks: the reader marks the other side's messages as read.
create or replace function public.tutor_mark_read(p_request uuid) returns integer
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); r public.tutor_requests; n integer;
begin
  select * into r from public.tutor_requests where id = p_request;
  if not found then return 0; end if;
  if r.user_id = v_uid then
    update public.tutor_messages set read_at = now() where request_id = r.id and read_at is null and sender_role in ('tutor', 'admin', 'system');
  elsif private.is_tutor_of(r.id) then
    update public.tutor_messages set read_at = now() where request_id = r.id and read_at is null and sender_role = 'student';
    update public.tutors set last_seen_at = now() where id = r.tutor_id;
  elsif private.tutor_staff() then
    if r.tutor_id is not null then return 0; end if; -- with a tutor, only the tutor's reading counts
    update public.tutor_messages set read_at = now() where request_id = r.id and read_at is null and sender_role = 'student';
  else return 0;
  end if;
  get diagnostics n = row_count;
  return n;
end $$;

-- A page of older messages (newest first) for long chats.
create or replace function public.tutor_messages_before(p_request uuid, p_before bigint, p_limit integer default 50) returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when not private.tutor_chat_member(p_request) then '[]'::jsonb else coalesce((
    select jsonb_agg(private.tutor_msg_json(m) order by m.id)
    from (select * from public.tutor_messages x where x.request_id = p_request and x.id < p_before order by x.id desc limit least(greatest(p_limit, 1), 100)) m), '[]'::jsonb) end;
$$;

-- 8. Tutor dashboard (and admins): the chat list.
create or replace function public.tutor_chats(p_scope text default 'mine') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_tutor uuid := private.my_tutor_id(); v_admin boolean := private.tutor_staff();
begin
  if v_tutor is null and not v_admin then raise exception 'not allowed' using errcode = '42501'; end if;
  if v_tutor is not null then update public.tutors set last_seen_at = now() where id = v_tutor; end if;
  return coalesce((select jsonb_agg(x order by (x ->> 'sort') desc) from (
    select jsonb_build_object('id', r.id, 'user_id', r.user_id, 'name', coalesce(nullif(btrim(p.full_name), ''), 'Student'), 'avatar_path', p.avatar_path,
      'status', r.status, 'level', r.level, 'subject', s.name, 'tutor_id', r.tutor_id, 'tutor', t.name, 'paid_at', r.paid_at, 'created_at', r.created_at,
      'custom_note', r.custom_note, 'custom_price_kobo', r.custom_price_kobo, 'custom_days', r.custom_days, 'goals', r.goals, 'times', r.times,
      'plan', (select coalesce(pl.name, 'Custom') || '|' || su.ends_at from public.tutor_subscriptions su left join public.tutor_plans pl on pl.id = su.plan_id
               where su.user_id = r.user_id and su.ends_at > now() order by su.ends_at desc limit 1),
      'last', (select private.tutor_msg_json(m) from public.tutor_messages m where m.request_id = r.id order by m.id desc limit 1),
      'unread', (select count(*) from public.tutor_messages m where m.request_id = r.id and m.sender_role = 'student' and m.read_at is null),
      'sort', coalesce((select max(m.created_at) from public.tutor_messages m where m.request_id = r.id), r.updated_at)) x
    from public.tutor_requests r join public.profiles p on p.id = r.user_id
    left join public.subjects s on s.id = r.subject_id left join public.tutors t on t.id = r.tutor_id
    where case when v_tutor is not null and not (v_admin and p_scope <> 'mine') then r.tutor_id = v_tutor and r.status in ('matched', 'ended')
               when p_scope = 'open' then r.status in ('new', 'quoted', 'paid', 'matched')
               when p_scope in ('all', 'mine') then true else r.status = p_scope end
    order by r.updated_at desc limit 300) t), '[]'::jsonb);
end $$;

-- Everything a tutor needs to know the student.
create or replace function public.tutor_student_profile(p_request uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare r public.tutor_requests; p public.profiles; v_rank jsonb;
begin
  select * into r from public.tutor_requests where id = p_request;
  if not found or not (private.is_tutor_of(r.id) or private.tutor_staff()) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into p from public.profiles where id = r.user_id;
  return jsonb_build_object(
    'name', coalesce(nullif(btrim(p.full_name), ''), 'Student'), 'avatar_path', p.avatar_path,
    'age', case when p.birth_year is not null then extract(year from now())::int - p.birth_year end,
    'school', p.school, 'state', p.state, 'phone', p.phone, 'email', (select u.email from auth.users u where u.id = p.id),
    'exams', p.target_exams, 'jamb_subjects', p.jamb_subjects, 'target_score', p.target_score,
    'career', (select c.name from public.careers c where c.id = p.career_id),
    'joined', p.created_at, 'xp', coalesce(p.xp_earned, 0) + coalesce(p.xp_bought, 0),
    'premium', private.has_premium(p.id),
    'streak', (select to_jsonb(x) - 'user_id' from (select * from public.streaks st where st.user_id = p.id) x),
    'topics', (select coalesce(jsonb_agg(jsonb_build_object('topic', tp.name, 'subject', sb.name, 'answered', uts.answered, 'correct', uts.correct,
                 'pct', round(100.0 * uts.correct / nullif(uts.answered, 0))) order by (1.0 * uts.correct / nullif(uts.answered, 0))), '[]'::jsonb)
               from public.user_topic_stats uts join public.topics tp on tp.id = uts.topic_id join public.subjects sb on sb.id = tp.subject_id
               where uts.user_id = p.id and uts.answered >= 3),
    'tests', (select coalesce(jsonb_agg(jsonb_build_object('at', a.submitted_at, 'mode', a.mode, 'score', a.score, 'total', a.total) order by a.submitted_at desc), '[]'::jsonb)
              from (select * from public.attempts x where x.user_id = p.id and x.submitted_at is not null order by x.submitted_at desc limit 10) a),
    'leaderboard', (select jsonb_build_object('rank', e.rank, 'of', e.total) from (
        select rank() over (order by coalesce(pp.xp_earned, 0) desc) rank, count(*) over () total, pp.id
        from public.profiles pp where pp.banned_at is null) e where e.id = p.id),
    'request', jsonb_build_object('level', r.level, 'subject', (select s.name from public.subjects s where s.id = r.subject_id), 'goals', r.goals,
       'times', r.times, 'created_at', r.created_at, 'paid_at', r.paid_at, 'custom_note', r.custom_note),
    'plan', (select jsonb_build_object('name', coalesce(pl.name, 'Custom'), 'ends_at', su.ends_at, 'sessions', pl.sessions)
             from public.tutor_subscriptions su left join public.tutor_plans pl on pl.id = su.plan_id
             where su.user_id = p.id and su.ends_at > now() order by su.ends_at desc limit 1));
end $$;

-- 9. Admins: assign, quote, close.
create or replace function public.admin_tutor_assign(p_request uuid, p_tutor uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.tutor_requests; t public.tutors;
begin
  if not private.tutor_staff() then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into r from public.tutor_requests where id = p_request for update;
  select * into t from public.tutors where id = p_tutor and active;
  if r.id is null or t.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if t.user_id is null then return jsonb_build_object('ok', false, 'error', 'no_login'); end if;
  if r.status not in ('paid', 'matched') then return jsonb_build_object('ok', false, 'error', 'not_paid'); end if;
  update public.tutor_requests set tutor_id = t.id, status = 'matched', assigned_at = now(), updated_at = now() where id = r.id;
  insert into public.tutor_messages (request_id, from_staff, sender_id, sender_role, body)
  values (r.id, true, null, 'system', t.name || ' is your tutor now. Say hello and share what you want to work on first.');
  insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
  values ('account'::public.notif_topic, 'Your tutor is here', t.name || ' is your tutor now. Open the chat to say hello.', 'user', r.user_id,
          'scheduled', now(), 'admin', jsonb_build_object('type', 'screen', 'target', '/tutor'));
  insert into private.email_outbox (user_id, kind, data) values (t.user_id, 'tutor_assigned',
    jsonb_build_object('student', private.game_name(r.user_id), 'goals', left(r.goals, 400), 'request', r.id,
      'subject', (select s.name from public.subjects s where s.id = r.subject_id), 'level', r.level));
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.admin_tutor_quote(p_request uuid, p_price_kobo integer, p_days integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.tutor_requests;
begin
  if not private.tutor_staff() then raise exception 'not allowed' using errcode = '42501'; end if;
  if p_price_kobo is null or p_price_kobo < 5000 or p_days is null or p_days < 1 or p_days > 366 then return jsonb_build_object('ok', false, 'error', 'price'); end if;
  update public.tutor_requests set custom_price_kobo = p_price_kobo, custom_days = p_days, updated_at = now(),
    status = case when status = 'new' then 'quoted' else status end
  where id = p_request returning * into r;
  if r.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  insert into public.tutor_messages (request_id, from_staff, sender_id, sender_role, body, kind)
  values (r.id, true, (select auth.uid()), 'admin', 'Your custom plan is ready: ₦' || to_char(p_price_kobo / 100, 'FM999,999,999') || ' for ' || p_days || ' days. Tap Pay to start.', 'text');
  insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
  values ('account'::public.notif_topic, 'Your custom tutor plan is ready', '₦' || to_char(p_price_kobo / 100, 'FM999,999,999') || ' for ' || p_days || ' days.',
          'user', r.user_id, 'scheduled', now(), 'admin', jsonb_build_object('type', 'screen', 'target', '/tutor'));
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.admin_tutor_close(p_request uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not private.tutor_staff() then raise exception 'not allowed' using errcode = '42501'; end if;
  update public.tutor_requests set status = 'closed', updated_at = now() where id = p_request;
  return jsonb_build_object('ok', found);
end $$;

-- Website file routes: who may upload to or read a chat's files.
create or replace function public.tutor_file_ok(p_request uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select private.tutor_chat_member(p_request)
     and exists (select 1 from public.tutor_requests r where r.id = p_request and (r.status in ('new', 'quoted', 'paid', 'matched') or r.user_id <> (select auth.uid())));
$$;
create or replace function public.can_view_tutor_file(p_key text) returns boolean language sql stable security definer set search_path = '' as $$
  select case when p_key ~ '^t/[0-9a-f-]{36}/' then private.tutor_chat_member(substr(p_key, 3, 36)::uuid) else false end;
$$;

-- Plans end on their own: the chat turns read-only with "Renew".
create or replace function private.tutor_end_job() returns void language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in select x.id, x.user_id from public.tutor_requests x where x.status = 'matched'
           and not exists (select 1 from public.tutor_subscriptions s where s.user_id = x.user_id and s.ends_at > now()) loop
    update public.tutor_requests set status = 'ended', updated_at = now() where id = r.id;
    insert into public.tutor_messages (request_id, from_staff, sender_id, sender_role, body)
    values (r.id, true, null, 'system', 'Your tutor plan has ended. Renew it to keep chatting with your tutor.');
    insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
    values ('account'::public.notif_topic, 'Your tutor plan has ended', 'Renew it to keep learning with your tutor.', 'user', r.user_id, 'scheduled', now(), 'admin',
            jsonb_build_object('type', 'screen', 'target', '/tutor'));
  end loop;
end $$;
select cron.schedule('tutor-end', '7 * * * *', 'select private.tutor_end_job()');

revoke all on function private.tutor_card(uuid), private.tutor_end_job() from public, anon, authenticated;
revoke all on function public.tutor_overview(), public.tutor_request_create(smallint, text, text, text), public.tutor_custom_request(uuid, text),
  public.tutor_message_send(uuid, text, text, text, jsonb, jsonb), public.tutor_mark_read(uuid), public.tutor_messages_before(uuid, bigint, integer),
  public.tutor_chats(text), public.tutor_student_profile(uuid), public.admin_tutor_assign(uuid, uuid), public.admin_tutor_quote(uuid, integer, integer),
  public.admin_tutor_close(uuid), public.tutor_file_ok(uuid), public.can_view_tutor_file(text) from public, anon;
grant execute on function public.tutor_overview(), public.tutor_request_create(smallint, text, text, text), public.tutor_custom_request(uuid, text),
  public.tutor_message_send(uuid, text, text, text, jsonb, jsonb), public.tutor_mark_read(uuid), public.tutor_messages_before(uuid, bigint, integer),
  public.tutor_chats(text), public.tutor_student_profile(uuid), public.admin_tutor_assign(uuid, uuid), public.admin_tutor_quote(uuid, integer, integer),
  public.admin_tutor_close(uuid), public.tutor_file_ok(uuid), public.can_view_tutor_file(text) to authenticated;

