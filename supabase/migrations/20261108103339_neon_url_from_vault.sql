-- Neon connection strings live in Supabase Vault (names NEON_ARCHIVE_URL, NEON_HISTORY_URL, NEON_AI_URL,
-- NEON_ANALYTICS_URL). Only the server (service role, used by Edge Functions) can read them through this function.
create or replace function public.neon_url(p_name text) returns text
language sql stable security definer set search_path = '' as $$
  select decrypted_secret from vault.decrypted_secrets
  where name = p_name and name in ('NEON_ARCHIVE_URL', 'NEON_HISTORY_URL', 'NEON_AI_URL', 'NEON_ANALYTICS_URL');
$$;
revoke all on function public.neon_url(text) from public, anon, authenticated;
grant execute on function public.neon_url(text) to service_role;
