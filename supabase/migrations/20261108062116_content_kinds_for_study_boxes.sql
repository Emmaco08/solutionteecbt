-- The Study boxes (past questions, notes, novels, videos, documents) follow the admin's rule for each kind (owner,
-- 2026-11-08): "Premium only" locks the whole box for free students; "watch videos", "pay per item" and "free" open the
-- box so students see the items (each item still carries its own lock and offer). The app reads only the modes.
create or replace function public.content_kinds() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce((select jsonb_object_agg(k.key, coalesce(k.value ->> 'mode', 'default'))
                   from public.app_settings s, jsonb_each(coalesce(s.value -> 'items', '{}'::jsonb)) k
                   where s.key = 'content_access'), '{}'::jsonb)
         || jsonb_build_object('pq', coalesce((select value -> 'years' ->> 'mode' from public.app_settings where key = 'content_access'), 'default'));
$$;
revoke all on function public.content_kinds() from public, anon;
grant execute on function public.content_kinds() to authenticated;
