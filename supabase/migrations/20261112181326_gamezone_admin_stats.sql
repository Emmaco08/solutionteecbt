-- Game Zone numbers for Admin -> Games (D-157). Staff only.
create or replace function public.admin_gz_stats()
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when not private.is_staff() then null else jsonb_build_object(
    'today', (select count(*) from public.gz_matches m where m.created_at >= private.lagos_day_start() and m.status <> 'cancelled'),
    'playing', (select count(*) from public.gz_matches m where m.status in ('lobby', 'playing') and m.created_at > now() - interval '20 minutes'),
    'students_today', (select count(distinct p.user_id) from public.gz_players p where p.user_id is not null and p.joined_at >= private.lagos_day_start()),
    'week', (select count(*) from public.gz_matches m where m.created_at >= now() - interval '7 days' and m.status = 'done'),
    'vs_students_week', (select count(*) from public.gz_matches m where m.created_at >= now() - interval '7 days' and m.status = 'done'
       and (select count(*) from public.gz_players p where p.match_id = m.id and p.user_id is not null) >= 2),
    'by_game', (select coalesce(jsonb_object_agg(game, n), '{}'::jsonb) from (
       select m.game, count(*) n from public.gz_matches m where m.created_at >= now() - interval '7 days' and m.status = 'done' group by 1) g),
    'xp_week', (select coalesce(sum(p.xp), 0) from public.gz_players p join public.gz_matches m on m.id = p.match_id where m.finished_at >= now() - interval '7 days'),
    'words', jsonb_build_object('active', (select count(*) from public.gz_words where active), 'total', (select count(*) from public.gz_words)),
    'cards', jsonb_build_object('active', (select count(*) from public.gz_cards where active), 'total', (select count(*) from public.gz_cards))) end;
$$;
revoke all on function public.admin_gz_stats() from public, anon;
grant execute on function public.admin_gz_stats() to authenticated;
