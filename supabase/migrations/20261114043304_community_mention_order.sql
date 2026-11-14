-- @ suggestions: a student whose @handle starts with the letters comes before one matched only by name.
create or replace function public.community_mention_suggest(p_q text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_q text := lower(ltrim(btrim(coalesce(p_q, '')), '@')); v_like text;
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  v_q := left(regexp_replace(v_q, '[^a-z0-9_. ]', '', 'g'), 30);
  v_like := replace(replace(v_q, '_', '\_'), '%', '\%') || '%';
  return coalesce((
    select jsonb_agg(x.j order by x.rank) from (
      select * from (
        select jsonb_build_object('handle', g.handle, 'name', g.name, 'avatar_path', g.avatar_path, 'badge', case when g.official then 'official' else 'page' end, 'page', true) as j,
          (case when g.official then 0 else 1 end) as rank
        from public.community_pages g where g.handle like v_like or lower(g.name) like v_like
        union all
        select private.community_person_json(c.user_id, v_uid) - 'bio' - 'follows_me',
          10 + (case when c.handle like v_like then 0 else 20 end)
             + (case when exists (select 1 from public.community_follows f where f.follower = v_uid and f.followee = c.user_id) then 0 else 10 end)
             + (case when c.handle = v_q then 0 else 1 end)
        from public.community_profiles c join public.profiles pr on pr.id = c.user_id
        where c.handle is not null and c.user_id <> v_uid and pr.banned_at is null
          and (c.handle like v_like or lower(pr.full_name) like v_like or lower(pr.full_name) like '% ' || v_like)
          and not private.community_blocked(v_uid, c.user_id)
        order by 2 limit 12) t
      order by t.rank limit 8) x), '[]'::jsonb);
end $$;
