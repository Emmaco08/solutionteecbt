-- Made-up handles never end with "_" or "." when the student has one name only.
create or replace function private.community_handle_make(p_uid uuid)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare v_name text; v_first text; v_last text; v_try text; i integer;
begin
  select coalesce(btrim(full_name), '') into v_name from public.profiles where id = p_uid;
  v_first := left(lower(regexp_replace(split_part(v_name, ' ', 1), '[^A-Za-z0-9]', '', 'g')), 14);
  v_last := lower(left(regexp_replace(split_part(v_name, ' ', 2), '[^A-Za-z]', '', 'g'), 1));
  if char_length(v_first) < 2 or v_first !~ '^[a-z]' or private.community_handle_reserved(v_first) then v_first := 'student'; end if;
  foreach v_try in array case when v_last = '' then array[v_first] else array[v_first, v_first || '_' || v_last, v_first || '.' || v_last, v_first || v_last] end loop
    if char_length(v_try) >= 3 and v_try ~ '^[a-z0-9][a-z0-9_.]{1,18}[a-z0-9_]$' and private.community_handle_free(v_try, p_uid) then return v_try; end if;
  end loop;
  for i in 1..40 loop
    v_try := v_first || case when i <= 20 then (10 + floor(random() * 90))::int::text else (100 + floor(random() * 9900))::int::text end;
    if private.community_handle_free(v_try, p_uid) then return v_try; end if;
  end loop;
  return 'student' || substr(replace(p_uid::text, '-', ''), 1, 10);
end $$;

update public.community_profiles set handle = 'tmp' || substr(replace(user_id::text, '-', ''), 1, 12) where handle_auto and handle ~ '[_.]$';
update public.community_profiles set handle = private.community_handle_make(user_id) where handle_auto and handle ~ '^tmp[0-9a-f]{12}$';
