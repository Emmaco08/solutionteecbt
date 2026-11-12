-- Tutor v4 (D-154): instant messages and pushes, emoji-only messages, photos.

-- 1. A one-character message (one emoji) failed: the student's notification needs 2+ characters and its error undid
--    the whole send. The notification now pads it.
do $$ declare d text; begin
  d := pg_get_functiondef('public.tutor_message_send(uuid, text, text, text, jsonb, jsonb, bigint)'::regprocedure);
  d := replace(d, 'when ''ref'' then ''📚 '' || coalesce(nullif(v_body, ''''), ''Study link'') else v_body end, 140)',
                  'when ''ref'' then ''📚 '' || coalesce(nullif(v_body, ''''), ''Study link'') else case when char_length(v_body) < 2 then v_body || '' '' else v_body end end, 140)');
  if position('char_length(v_body) < 2' in d) = 0 then raise exception 'tutor_message_send: pattern not found'; end if;
  execute d;
end $$;

-- 2. Pushes go out at once: any notification that is due when it is written wakes the push sender (it takes each
--    message once, so this never sends twice). The schedule also runs every minute for the ones planned later.
create or replace function private.push_now()
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/push',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-token', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_token')),
    body := '{"run":"due"}'::jsonb, timeout_milliseconds := 30000);
exception when others then null; -- a push must never undo the action that caused it
end $$;
revoke all on function private.push_now() from public, anon, authenticated;

create or replace function private.notifications_push_now()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from new_rows n where n.status = 'scheduled' and n.scheduled_at <= now() + interval '5 seconds') then
    perform private.push_now();
  end if;
  return null;
end $$;
drop trigger if exists notifications_push_now on public.notifications;
create trigger notifications_push_now after insert on public.notifications
  referencing new table as new_rows for each statement execute function private.notifications_push_now();

select cron.alter_job(jobid, schedule := '* * * * *') from cron.job where jobname = 'push-due';

-- 3. Messages reach the chat at once: the database broadcasts each new or changed message to the chat's private
--    room (tutor:<request>), and to the person's own channel (user:<id>) for the in-app banner and the tutor desk.
create or replace function private.tutor_msg_broadcast()
returns trigger language plpgsql security definer set search_path = '' as $$
declare j jsonb; r public.tutor_requests; t public.tutors;
begin
  j := private.tutor_msg_json(new) - 'starred' || jsonb_build_object('request_id', new.request_id);
  perform realtime.send(j, case when tg_op = 'INSERT' then 'msg' else 'msg_update' end, 'tutor:' || new.request_id, true);
  if tg_op = 'INSERT' then
    select * into r from public.tutor_requests where id = new.request_id;
    select * into t from public.tutors where id = r.tutor_id;
    if new.sender_role <> 'student' then
      perform realtime.send(j || jsonb_build_object('from', case when new.sender_role = 'tutor' then coalesce(t.name, 'Your tutor') else 'SolutionTee' end,
                                                    'photo', case when new.sender_role = 'tutor' then t.photo_path end),
                            'tutor_msg', 'user:' || r.user_id, true);
    elsif t.user_id is not null then
      perform realtime.send(j, 'student_msg', 'user:' || t.user_id, true);
    end if;
  end if;
  return null;
exception when others then return null; -- never block a message because of a broadcast
end $$;
drop trigger if exists tutor_msg_broadcast on public.tutor_messages;
create trigger tutor_msg_broadcast after insert or update on public.tutor_messages
  for each row execute function private.tutor_msg_broadcast();

create or replace function private.tutor_req_broadcast()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status is distinct from old.status or new.tutor_id is distinct from old.tutor_id then
    perform realtime.send(jsonb_build_object('id', new.id, 'status', new.status), 'tutor_req', 'user:' || new.user_id, true);
  end if;
  return null;
exception when others then return null;
end $$;
drop trigger if exists tutor_req_broadcast on public.tutor_requests;
create trigger tutor_req_broadcast after update on public.tutor_requests
  for each row execute function private.tutor_req_broadcast();

-- Who may join a private topic: the chat's members (tutor:<request>) and the person themselves (user:<id>).
create or replace function private.tutor_topic_ok(p_topic text)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when p_topic ~ '^tutor:[0-9a-f-]{36}$' then private.tutor_chat_member(substr(p_topic, 7)::uuid)
    when p_topic ~ '^user:[0-9a-f-]{36}$' then substr(p_topic, 6)::uuid = (select auth.uid())
    else false end;
$$;

-- 4. Photos: tutors add theirs (a/<their id>/…, shown to everyone signed in); a tutor and admins see their students' photos.
create or replace function public.tutor_photo_save(p_path text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_t uuid := private.my_tutor_id();
begin
  if v_t is null then raise exception 'not allowed' using errcode = '42501'; end if;
  if p_path is not null and p_path !~ ('^a/' || (select auth.uid()) || '/[A-Za-z0-9._-]+$') then
    return jsonb_build_object('ok', false, 'error', 'path');
  end if;
  update public.tutors set photo_path = p_path where id = v_t;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.tutor_photo_save(text) from public, anon;
grant execute on function public.tutor_photo_save(text) to authenticated;

create or replace function public.can_view_avatar(p_key text)
returns boolean language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and not private.is_banned() and (
    p_key like 'a/' || (select auth.uid())::text || '/%'
    or (coalesce((select (s.value ->> 'on')::boolean from public.app_settings s where s.key = 'leaderboard'), false)
        and exists (select 1 from public.profiles p where p.avatar_path = p_key and p.show_photo_on_leaderboard
                    and not p.hide_on_leaderboard and p.banned_at is null))
    -- D-154: tutors' photos are shown to students; a tutor (and admins) see their students' photos.
    or exists (select 1 from public.tutors t where t.photo_path = p_key and t.active)
    or exists (select 1 from public.profiles p join public.tutor_requests r on r.user_id = p.id
               where p.avatar_path = p_key and (private.is_tutor_of(r.id) or private.tutor_staff())));
$$;
