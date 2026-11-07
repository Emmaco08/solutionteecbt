-- Codes ignore spaces, dashes and case ("abcd efgh" = "ABCD-EFGH").
create or replace function private.code_hash(p_challenge uuid, p_code text) returns text
language sql immutable set search_path to '' as $$
  select encode(extensions.digest(p_challenge::text || ':' || upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')), 'sha256'), 'hex');
$$;
