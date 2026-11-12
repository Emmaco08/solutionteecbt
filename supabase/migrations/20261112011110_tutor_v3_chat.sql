-- Tutor v3 (D-153): reactions, reply/quote, delete for everyone, star, report; live request updates; more tutor profile.
alter table public.tutor_messages
  add column if not exists reply_to bigint references public.tutor_messages(id) on delete set null,
  add column if not exists reactions jsonb not null default '{}'::jsonb,
  add column if not exists deleted_at timestamptz;

alter table public.tutors
  add column if not exists years_teaching smallint check (years_teaching between 0 and 60),
  add column if not exists qualification text check (char_length(qualification) <= 120);

create table if not exists public.tutor_message_stars (
  user_id uuid not null references auth.users(id) on delete cascade,
  message_id bigint not null references public.tutor_messages(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, message_id)
);
alter table public.tutor_message_stars enable row level security;
create policy "own stars" on public.tutor_message_stars for select to authenticated using (user_id = (select auth.uid()));
create index if not exists tutor_message_stars_msg on public.tutor_message_stars(message_id);

create table if not exists public.tutor_message_reports (
  id bigint generated always as identity primary key,
  message_id bigint not null references public.tutor_messages(id) on delete cascade,
  request_id uuid not null references public.tutor_requests(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (char_length(reason) between 1 and 500),
  status text not null default 'open' check (status in ('open', 'done')),
  created_at timestamptz not null default now(),
  unique (message_id, user_id)
);
alter table public.tutor_message_reports enable row level security;
create policy "admins" on public.tutor_message_reports for all to authenticated using (private.tutor_staff()) with check (private.tutor_staff());
create index if not exists tutor_message_reports_req on public.tutor_message_reports(request_id);
create index if not exists tutor_messages_reply on public.tutor_messages(reply_to) where reply_to is not null;

-- Live updates: the student's request (paid → matched) and all chat rows (RLS decides who receives what).
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'tutor_requests') then
    alter publication supabase_realtime add table public.tutor_requests;
  end if;
end $$;

create or replace function private.tutor_msg_json(m public.tutor_messages)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', m.id, 'role', m.sender_role, 'kind', case when m.deleted_at is null then m.kind else 'text' end,
    'body', case when m.deleted_at is null then m.body else '' end,
    'attachment', case when m.deleted_at is null then m.attachment_path end,
    'meta', case when m.deleted_at is null then m.meta else '{}'::jsonb end,
    'ref', case when m.deleted_at is null then m.ref end,
    'at', m.created_at, 'read_at', m.read_at, 'from_staff', m.from_staff,
    'reply_to', m.reply_to, 'reactions', m.reactions, 'deleted', m.deleted_at is not null,
    'reply', (select jsonb_build_object('id', o.id, 'role', o.sender_role, 'kind', o.kind,
                'body', case when o.deleted_at is null then left(o.body, 200) else '' end, 'deleted', o.deleted_at is not null,
                'meta', case when o.deleted_at is null then o.meta - 'url' else '{}'::jsonb end)
              from public.tutor_messages o where o.id = m.reply_to),
    'starred', exists (select 1 from public.tutor_message_stars s where s.message_id = m.id and s.user_id = (select auth.uid())));
$$;
revoke all on function private.tutor_msg_json(public.tutor_messages) from public, anon;

create or replace function private.tutor_card(p_tutor uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', t.id, 'name', t.name, 'subjects', t.subjects, 'bio', t.bio, 'photo_path', t.photo_path,
    'online', t.last_seen_at > now() - interval '2 minutes', 'last_seen_at', t.last_seen_at,
    'years', t.years_teaching, 'qualification', t.qualification,
    'students', (select count(distinct r.user_id) from public.tutor_requests r where r.tutor_id = t.id and r.status in ('matched', 'ended')))
  from public.tutors t where t.id = p_tutor;
$$;

-- Send, now with an optional reply.
drop function if exists public.tutor_message_send(uuid, text, text, text, jsonb, jsonb);
create or replace function public.tutor_message_send(p_request uuid, p_body text, p_kind text default 'text', p_attachment text default null,
  p_meta jsonb default null, p_ref jsonb default null, p_reply_to bigint default null)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare v_uid uuid := (select auth.uid()); r public.tutor_requests; v_role text; m public.tutor_messages; t public.tutors;
  v_body text := btrim(coalesce(p_body, '')); v_reply bigint;
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
  if p_reply_to is not null then
    select x.id into v_reply from public.tutor_messages x where x.id = p_reply_to and x.request_id = r.id;
  end if;
  if v_role = 'student' then
    if r.status in ('ended', 'closed') then return jsonb_build_object('ok', false, 'error', 'ended'); end if;
    if (select count(*) from public.tutor_messages x where x.request_id = r.id and x.sender_role = 'student' and x.created_at > now() - interval '1 hour') >= 60 then
      return jsonb_build_object('ok', false, 'error', 'too_many');
    end if;
  end if;
  insert into public.tutor_messages (request_id, from_staff, sender_id, sender_role, kind, body, attachment_path, meta, ref, reply_to)
  values (r.id, v_role <> 'student', v_uid, v_role, p_kind, v_body, p_attachment, p_meta, p_ref, v_reply) returning * into m;
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
    select * into t from public.tutors where id = r.tutor_id;
    if t.user_id is not null and (r.tutor_emailed_at is null or r.tutor_emailed_at < now() - interval '15 minutes') then
      insert into private.email_outbox (user_id, kind, data) values (t.user_id, 'tutor_student_message',
        jsonb_build_object('student', private.game_name(r.user_id), 'body', left(case when p_kind = 'text' then v_body else 'Sent a ' || p_kind end, 400), 'request', r.id));
      update public.tutor_requests set tutor_emailed_at = now() where id = r.id;
    end if;
  end if;
  return jsonb_build_object('ok', true, 'message', private.tutor_msg_json(m));
end $function$;
revoke all on function public.tutor_message_send(uuid, text, text, text, jsonb, jsonb, bigint) from public, anon;
grant execute on function public.tutor_message_send(uuid, text, text, text, jsonb, jsonb, bigint) to authenticated;

-- Who am I in this message's chat? (student / tutor / admin, or null)
create or replace function private.tutor_role_in(p_request uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case when exists (select 1 from public.tutor_requests r where r.id = p_request and r.user_id = (select auth.uid())) then 'student'
              when private.is_tutor_of(p_request) then 'tutor' when private.tutor_staff() then 'admin' end;
$$;

-- React (one reaction per side; the same emoji again removes it).
create or replace function public.tutor_message_react(p_message bigint, p_emoji text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare m public.tutor_messages; v_role text; v_e text := btrim(coalesce(p_emoji, ''));
begin
  if (select auth.uid()) is null then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into m from public.tutor_messages where id = p_message;
  if not found or m.deleted_at is not null or m.sender_role = 'system' then return jsonb_build_object('ok', false); end if;
  v_role := private.tutor_role_in(m.request_id);
  if v_role is null then return jsonb_build_object('ok', false); end if;
  if char_length(v_e) > 16 or v_e ~ '[A-Za-z0-9<>]' then return jsonb_build_object('ok', false, 'error', 'emoji'); end if;
  update public.tutor_messages set reactions = case when v_e = '' or reactions ->> v_role = v_e then reactions - v_role
                                                    else reactions || jsonb_build_object(v_role, v_e) end
  where id = m.id returning * into m;
  return jsonb_build_object('ok', true, 'reactions', m.reactions);
end $$;

-- Delete for everyone: your own message, within 48 hours (admins any time).
create or replace function public.tutor_message_delete(p_message bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare m public.tutor_messages; v_role text;
begin
  if (select auth.uid()) is null then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into m from public.tutor_messages where id = p_message;
  if not found or m.deleted_at is not null then return jsonb_build_object('ok', false); end if;
  v_role := private.tutor_role_in(m.request_id);
  if v_role is null then return jsonb_build_object('ok', false); end if;
  if v_role <> 'admin' and (m.sender_id <> (select auth.uid()) or m.created_at < now() - interval '48 hours') then
    return jsonb_build_object('ok', false, 'error', 'not_yours');
  end if;
  update public.tutor_messages set deleted_at = now(), body = '', attachment_path = null, meta = '{}'::jsonb, ref = null, reactions = '{}'::jsonb
  where id = m.id;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.tutor_message_star(p_message bigint, p_on boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_req uuid;
begin
  if (select auth.uid()) is null then raise exception 'not allowed' using errcode = '42501'; end if;
  select request_id into v_req from public.tutor_messages where id = p_message;
  if v_req is null or private.tutor_role_in(v_req) is null then return jsonb_build_object('ok', false); end if;
  if p_on then
    insert into public.tutor_message_stars (user_id, message_id) values ((select auth.uid()), p_message) on conflict do nothing;
  else
    delete from public.tutor_message_stars where user_id = (select auth.uid()) and message_id = p_message;
  end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.tutor_starred(p_request uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when private.tutor_role_in(p_request) is null then '[]'::jsonb else coalesce((
    select jsonb_agg(private.tutor_msg_json(m) order by s.created_at desc)
    from public.tutor_message_stars s join public.tutor_messages m on m.id = s.message_id
    where s.user_id = (select auth.uid()) and m.request_id = p_request and m.deleted_at is null), '[]'::jsonb) end;
$$;

create or replace function public.tutor_message_report(p_message bigint, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare m public.tutor_messages; v_role text; v_r text := left(btrim(coalesce(p_reason, '')), 500);
begin
  if (select auth.uid()) is null then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into m from public.tutor_messages where id = p_message;
  if not found then return jsonb_build_object('ok', false); end if;
  v_role := private.tutor_role_in(m.request_id);
  if v_role is null or m.sender_id = (select auth.uid()) then return jsonb_build_object('ok', false); end if;
  if v_r = '' then v_r := 'Reported from the chat'; end if;
  if (select count(*) from public.tutor_message_reports x where x.user_id = (select auth.uid()) and x.created_at > now() - interval '1 day') >= 20 then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  insert into public.tutor_message_reports (message_id, request_id, user_id, reason) values (m.id, m.request_id, (select auth.uid()), v_r)
  on conflict (message_id, user_id) do nothing;
  if found then
    perform private.tutor_tell_admins('A tutor chat message was reported', left(v_r, 140), 'tutor_report', jsonb_build_object('request', m.request_id, 'message', m.id));
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- Tutor profile: years teaching and qualification too.
drop function if exists public.tutor_profile_save(text, text, text);
create or replace function public.tutor_profile_save(p_name text, p_subjects text, p_bio text, p_years integer default null, p_qualification text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_t uuid := private.my_tutor_id();
begin
  if v_t is null then raise exception 'not allowed' using errcode = '42501'; end if;
  if char_length(btrim(coalesce(p_name, ''))) < 2 then return jsonb_build_object('ok', false, 'error', 'name'); end if;
  update public.tutors set name = left(btrim(p_name), 80), subjects = left(btrim(coalesce(p_subjects, '')), 200), bio = left(btrim(coalesce(p_bio, '')), 600),
    years_teaching = case when p_years between 0 and 60 then p_years end, qualification = nullif(left(btrim(coalesce(p_qualification, '')), 120), '')
  where id = v_t;
  return jsonb_build_object('ok', true);
end $$;

do $$ declare f text; begin
  foreach f in array array['public.tutor_message_react(bigint, text)', 'public.tutor_message_delete(bigint)', 'public.tutor_message_star(bigint, boolean)',
    'public.tutor_starred(uuid)', 'public.tutor_message_report(bigint, text)', 'public.tutor_profile_save(text, text, text, integer, text)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  execute 'revoke all on function private.tutor_role_in(uuid) from public, anon';
end $$;
