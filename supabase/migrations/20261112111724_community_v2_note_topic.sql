-- Community notes go to their own private topic cnote:<user id> (the tutor banner keeps user:<user id>; one socket
-- cannot join the same topic twice).
create or replace function private.tutor_topic_ok(p_topic text)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when p_topic ~ '^tutor:[0-9a-f-]{36}$' then private.tutor_chat_member(substr(p_topic, 7)::uuid)
    when p_topic ~ '^user:[0-9a-f-]{36}$' then substr(p_topic, 6)::uuid = (select auth.uid())
    when p_topic ~ '^cnote:[0-9a-f-]{36}$' then substr(p_topic, 7)::uuid = (select auth.uid())
    else false end;
$$;

create or replace function private.community_note_broadcast()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform realtime.send(jsonb_build_object('kind', new.kind, 'id', new.id, 'post_id', new.post_id,
    'from', case when new.actor is null then 'SolutionTee AI' else coalesce((select nullif(btrim(p.full_name), '') from public.profiles p where p.id = new.actor), 'A student') end),
    'community_note', 'cnote:' || new.user_id::text, true);
  return null;
exception when others then return null;
end $$;
