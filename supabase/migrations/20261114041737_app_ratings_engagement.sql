-- App rating and nudges (owner, 13 Nov 2026). Students rate the app inside it now and then (stars + a comment); staff see
-- the results in Admin → App ratings. Google's own review box is asked for at a separate happy moment in the app (Play rules
-- do not allow asking our question first or showing Google's box only to happy students). Admin also sets how often the
-- app suggests Community, Game Zone and Request a tutor.

create table if not exists public.app_ratings (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  stars smallint not null check (stars between 1 and 5),
  comment text check (char_length(comment) <= 1000),
  app_version text check (char_length(app_version) <= 40),
  created_at timestamptz not null default now()
);
create index if not exists app_ratings_time_idx on public.app_ratings (created_at desc);
create index if not exists app_ratings_user_idx on public.app_ratings (user_id, created_at desc);
alter table public.app_ratings enable row level security;
create policy "staff read" on public.app_ratings for select using (private.is_staff());
grant select on public.app_ratings to authenticated;

-- One rating per student per 20 days: a newer one within that time replaces it.
create or replace function public.app_rating_submit(p_stars integer, p_comment text default null, p_version text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_id bigint;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  if p_stars is null or p_stars not between 1 and 5 then raise exception 'stars' using errcode = '22023'; end if;
  select id into v_id from public.app_ratings where user_id = v_uid and created_at > now() - interval '20 days' order by created_at desc limit 1;
  if v_id is not null then
    update public.app_ratings set stars = p_stars, comment = nullif(left(btrim(coalesce(p_comment, '')), 1000), ''),
      app_version = left(p_version, 40), created_at = now() where id = v_id;
  else
    insert into public.app_ratings (user_id, stars, comment, app_version)
    values (v_uid, p_stars, nullif(left(btrim(coalesce(p_comment, '')), 1000), ''), left(p_version, 40));
  end if;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.app_rating_submit(integer, text, text) from public, anon;
grant execute on function public.app_rating_submit(integer, text, text) to authenticated;

-- Admin: the numbers and the latest comments.
create or replace function public.admin_app_ratings(p_stars integer default null, p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff() then raise exception 'not allowed' using errcode = '42501'; end if;
  return jsonb_build_object(
    'total', (select count(*) from public.app_ratings),
    'average', (select round(avg(stars)::numeric, 2) from public.app_ratings),
    'average_30', (select round(avg(stars)::numeric, 2) from public.app_ratings where created_at > now() - interval '30 days'),
    'count_30', (select count(*) from public.app_ratings where created_at > now() - interval '30 days'),
    'by_stars', (select coalesce(jsonb_object_agg(s, n), '{}') from (select stars s, count(*) n from public.app_ratings group by stars) t),
    'rows', (select coalesce(jsonb_agg(x order by x ->> 'at' desc), '[]') from (
      select jsonb_build_object('id', r.id, 'stars', r.stars, 'comment', r.comment, 'version', r.app_version, 'at', r.created_at,
        'name', coalesce(nullif(btrim(p.full_name), ''), 'Student'), 'email', u.email) as x
      from public.app_ratings r left join public.profiles p on p.id = r.user_id left join auth.users u on u.id = r.user_id
      where p_stars is null or r.stars = p_stars
      order by r.created_at desc offset greatest(p_offset, 0) limit 50) t));
end $$;
revoke all on function public.admin_app_ratings(integer, integer) from public, anon;
grant execute on function public.admin_app_ratings(integer, integer) to authenticated;

insert into public.app_settings (key, value) values ('engagement', jsonb_build_object(
  'rating', jsonb_build_object('on', true, 'after_days', 3, 'after_opens', 6, 'every_days', 60),
  'review', jsonb_build_object('on', true, 'after_days', 5, 'every_days', 120),
  'nudges', jsonb_build_object('on', true, 'after_days', 2, 'every_days', 3, 'community', true, 'games', true, 'tutor', true)))
on conflict (key) do nothing;
