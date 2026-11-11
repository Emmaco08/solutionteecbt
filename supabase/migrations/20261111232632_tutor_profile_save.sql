-- A tutor edits their own public card (name, subjects, short bio) from their dashboard (D-152).
create or replace function public.tutor_profile_save(p_name text, p_subjects text, p_bio text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_id uuid := private.my_tutor_id();
begin
  if v_id is null then raise exception 'not allowed' using errcode = '42501'; end if;
  if char_length(btrim(coalesce(p_name, ''))) < 2 then return jsonb_build_object('ok', false, 'error', 'name'); end if;
  update public.tutors set name = left(btrim(p_name), 80), subjects = nullif(left(btrim(coalesce(p_subjects, '')), 200), ''),
    bio = nullif(left(btrim(coalesce(p_bio, '')), 600), '') where id = v_id;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.tutor_profile_save(text, text, text) from public, anon;
grant execute on function public.tutor_profile_save(text, text, text) to authenticated;

