-- One row per indexed source with its newest chunk time (the ai-index function compares it with the note's updated_at).
create or replace function public.ai_chunk_sources(p_source text)
returns table (source_id uuid, indexed_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select c.source_id, max(c.created_at) from public.ai_chunks c where c.source = p_source group by c.source_id;
$$;
revoke all on function public.ai_chunk_sources(text) from public, anon, authenticated;
grant execute on function public.ai_chunk_sources(text) to service_role;
