-- D-154: a tutor's name and photo change everywhere at once: the tutor card, their account profile (staff lists,
-- account menu), the login's display name, and their students' apps (told live to refresh).
create or replace function private.tutor_profile_sync(p_tutor uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare t public.tutors; r record;
begin
  select * into t from public.tutors where id = p_tutor;
  if t.user_id is null then return; end if;
  update public.profiles set full_name = t.name, avatar_path = coalesce(t.photo_path, avatar_path) where id = t.user_id;
  update auth.users set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('full_name', t.name, 'name', t.name)
  where id = t.user_id;
  for r in select x.user_id from public.tutor_requests x where x.tutor_id = t.id and x.status in ('matched', 'ended') loop
    perform realtime.send(jsonb_build_object('tutor', t.id), 'tutor_req', 'user:' || r.user_id, true);
  end loop;
exception when others then null; -- the tutor card itself is already saved
end $$;
revoke all on function private.tutor_profile_sync(uuid) from public, anon, authenticated;

create or replace function public.tutor_profile_save(p_name text, p_subjects text, p_bio text, p_years integer default null, p_qualification text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_t uuid := private.my_tutor_id();
begin
  if v_t is null then raise exception 'not allowed' using errcode = '42501'; end if;
  if char_length(btrim(coalesce(p_name, ''))) < 2 then return jsonb_build_object('ok', false, 'error', 'name'); end if;
  update public.tutors set name = left(btrim(p_name), 80), subjects = left(btrim(coalesce(p_subjects, '')), 200), bio = left(btrim(coalesce(p_bio, '')), 600),
    years_teaching = case when p_years between 0 and 60 then p_years end, qualification = nullif(left(btrim(coalesce(p_qualification, '')), 120), '')
  where id = v_t;
  perform private.tutor_profile_sync(v_t);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.tutor_photo_save(p_path text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_t uuid := private.my_tutor_id();
begin
  if v_t is null then raise exception 'not allowed' using errcode = '42501'; end if;
  if p_path is not null and p_path !~ ('^a/' || (select auth.uid()) || '/[A-Za-z0-9._-]+$') then
    return jsonb_build_object('ok', false, 'error', 'path');
  end if;
  update public.tutors set photo_path = p_path where id = v_t;
  if p_path is null then update public.profiles set avatar_path = null where id = (select auth.uid()); end if;
  perform private.tutor_profile_sync(v_t);
  return jsonb_build_object('ok', true);
end $$;

-- Admin edits of a tutor (Tutors page) follow too.
create or replace function private.tutors_after_edit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.name is distinct from old.name or new.photo_path is distinct from old.photo_path then
    perform private.tutor_profile_sync(new.id);
  end if;
  return null;
end $$;
drop trigger if exists tutors_after_edit on public.tutors;
create trigger tutors_after_edit after update on public.tutors for each row execute function private.tutors_after_edit();
