-- Community v2 (D-155), part 3: feeds, thread, notes, search, explore, profiles.

-- ---------- Feeds ----------
create or replace function public.community_home(p_tab text default 'for_you', p_offset integer default 0, p_subject smallint default null, p_tag text default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_subjects smallint[]; v_tag text := lower(nullif(ltrim(btrim(coalesce(p_tag, '')), '#'), ''));
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  if p_tab = 'following' then
    return coalesce((
      with items as (
        select x.id, x.created_at as at, null::uuid as by from public.community_posts x
        where (x.user_id = v_uid or exists (select 1 from public.community_follows f where f.follower = v_uid and f.followee = x.user_id))
          and private.community_visible(x, v_uid)
        union all
        select r.post_id, r.created_at, r.user_id from public.community_reposts r
        join public.community_follows f on f.follower = v_uid and f.followee = r.user_id
        join public.community_posts x on x.id = r.post_id
        where x.status = 'shown' and not private.community_blocked(v_uid, x.user_id)),
      best as (select distinct on (id) id, at, by from items order by id, at desc),
      page as (select * from best order by at desc offset greatest(p_offset, 0) limit 20)
      select jsonb_agg(private.community_post_json(p, v_uid) || case when b.by is null then '{}'::jsonb
               else jsonb_build_object('reposted_by', private.community_person_json(b.by, v_uid)) end order by b.at desc)
      from page b join public.community_posts p on p.id = b.id), '[]'::jsonb);
  end if;
  select array_agg(s.id) into v_subjects from public.profiles pr join public.subjects s
    on s.code = any (coalesce(pr.jamb_subjects, '{}')) or s.name = any (coalesce(pr.jamb_subjects, '{}')) where pr.id = v_uid;
  return coalesce((
    select jsonb_agg(private.community_post_json(p, v_uid) || case when t.by is null then '{}'::jsonb
             else jsonb_build_object('reposted_by', private.community_person_json(t.by, v_uid)) end order by t.score desc, p.created_at desc)
    from (
      select x.id, rp.by,
        case when p_subject is null and v_tag is null then
          (case when exists (select 1 from public.community_follows f where f.follower = v_uid and f.followee = x.user_id) then 3 else 0 end)
          + (case when rp.by is not null then 2 else 0 end)
          + (case when x.subject_id = any (coalesce(v_subjects, '{}')) then 2 else 0 end)
          + ln(1 + x.likes_count + x.comments_count + x.reposts_count) - extract(epoch from (now() - x.created_at)) / 86400.0
        else extract(epoch from x.created_at) / 86400.0 end as score
      from public.community_posts x
      left join lateral (select r.user_id as by from public.community_reposts r join public.community_follows f on f.follower = v_uid and f.followee = r.user_id
                         where r.post_id = x.id and r.user_id <> x.user_id order by r.created_at desc limit 1) rp on true
      where private.community_visible(x, v_uid)
        and x.created_at > now() - interval '60 days'
        and (p_subject is null or x.subject_id = p_subject)
        and (v_tag is null or exists (select 1 from unnest(x.tags) t where lower(t) = v_tag))
      order by 3 desc, x.created_at desc
      offset greatest(p_offset, 0) limit 20) t
    join public.community_posts p on p.id = t.id), '[]'::jsonb);
end $$;
grant execute on function public.community_home(text, integer, smallint, text) to authenticated;

-- How many new posts since the student last loaded the feed ("N new posts" pill).
create or replace function public.community_new_count(p_tab text, p_since timestamptz)
returns integer language sql stable security definer set search_path = '' as $$
  select least(99, count(*))::int from public.community_posts x
  where x.status = 'shown' and x.created_at > p_since and x.user_id <> (select auth.uid())
    and not private.community_blocked((select auth.uid()), x.user_id)
    and (p_tab <> 'following' or exists (select 1 from public.community_follows f where f.follower = (select auth.uid()) and f.followee = x.user_id));
$$;
grant execute on function public.community_new_count(text, timestamptz) to authenticated;

-- A post with its replies (top-level replies, each with its own replies).
create or replace function public.community_thread(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); p public.community_posts;
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  select * into p from public.community_posts where id = p_id;
  if not found or not private.community_visible(p, v_uid) then return jsonb_build_object('status', 'not_found'); end if;
  return private.community_post_json(p, v_uid) || jsonb_build_object('replies', coalesce((
    select jsonb_agg(private.community_comment_json(c, v_uid) || jsonb_build_object('reply_list', coalesce((
        select jsonb_agg(private.community_comment_json(r, v_uid) order by r.created_at)
        from public.community_comments r
        where r.parent_id = c.id and (r.status = 'shown' or (r.user_id = v_uid and r.status in ('pending', 'rejected')))
          and (r.user_id is null or not private.community_blocked(v_uid, r.user_id))), '[]'::jsonb))
      order by c.from_ai desc, c.created_at)
    from public.community_comments c
    where c.post_id = p.id and c.parent_id is null and (c.status = 'shown' or (c.user_id = v_uid and c.status in ('pending', 'rejected')))
      and (c.user_id is null or not private.community_blocked(v_uid, c.user_id))), '[]'::jsonb));
end $$;
grant execute on function public.community_thread(uuid) to authenticated;

-- ---------- Notes ----------
create or replace function public.community_notes_list(p_tab text default 'all', p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  return coalesce((
    with n as (
      select * from public.community_notes x
      where x.user_id = v_uid and x.created_at > now() - interval '60 days'
        and (p_tab <> 'mentions' or x.kind in ('mention', 'reply', 'quote'))
        and (x.actor is null or not private.community_blocked(v_uid, x.actor))),
    g as (
      select kind, post_id, comment_id, case when kind in ('like', 'repost', 'comment_like') then 0 else id end as solo,
        max(created_at) as at, max(id) as last_id, bool_or(read_at is null) as unread, count(distinct actor) as n_actors,
        (array_agg(actor order by created_at desc))[1:3] as actors, (array_agg(body order by created_at desc))[1] as body
      from n group by 1, 2, 3, 4),
    page as (select * from g order by at desc offset greatest(p_offset, 0) limit 30)
    select jsonb_agg(jsonb_build_object('id', g.last_id, 'kind', g.kind, 'post_id', g.post_id, 'comment_id', g.comment_id, 'at', g.at,
      'unread', g.unread, 'count', g.n_actors, 'body', g.body,
      'actors', coalesce((select jsonb_agg(private.community_person_json(u.a, v_uid) order by u.ord) from unnest(g.actors) with ordinality u(a, ord) where u.a is not null), '[]'::jsonb),
      'post', (select jsonb_build_object('body', left(p.body, 140), 'status', p.status) from public.community_posts p where p.id = g.post_id))
      order by g.at desc)
    from page g), '[]'::jsonb);
end $$;
grant execute on function public.community_notes_list(text, integer) to authenticated;

create or replace function public.community_unread()
returns integer language sql stable security definer set search_path = '' as $$
  select least(99, count(*))::int from public.community_notes x where x.user_id = (select auth.uid()) and x.read_at is null
    and (x.actor is null or not private.community_blocked((select auth.uid()), x.actor));
$$;
grant execute on function public.community_unread() to authenticated;

create or replace function public.community_notes_read()
returns jsonb language sql volatile security definer set search_path = '' as $$
  with u as (update public.community_notes set read_at = now() where user_id = (select auth.uid()) and read_at is null returning 1)
  select jsonb_build_object('ok', true, 'read', (select count(*) from u));
$$;
grant execute on function public.community_notes_read() to authenticated;

-- ---------- Search and Explore ----------
create or replace function public.community_search(p_q text, p_kind text default 'top', p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_q text := btrim(coalesce(p_q, '')); v_like text; v_tag text; v_people jsonb; v_posts jsonb;
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  if char_length(v_q) < 1 then return jsonb_build_object('people', '[]'::jsonb, 'posts', '[]'::jsonb); end if;
  v_q := left(v_q, 60);
  v_like := '%' || replace(replace(replace(ltrim(v_q, '@#'), '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_tag := case when v_q ~ '^#' then lower(substr(v_q, 2)) end;
  if p_kind in ('top', 'people') and v_tag is null then
    select coalesce(jsonb_agg(private.community_person_json(z.user_id, v_uid) order by z.rank desc, z.followers desc), '[]'::jsonb) into v_people from (
      select c.user_id, (c.handle = lower(ltrim(v_q, '@')))::int * 2 + (c.handle like lower(ltrim(v_q, '@')) || '%')::int as rank,
        (select count(*) from public.community_follows f where f.followee = c.user_id) as followers
      from public.community_profiles c join public.profiles pr on pr.id = c.user_id
      where (c.handle ilike v_like or pr.full_name ilike v_like) and pr.banned_at is null and not private.community_blocked(v_uid, c.user_id)
      order by 2 desc, 3 desc offset case when p_kind = 'people' then greatest(p_offset, 0) else 0 end limit case when p_kind = 'top' then 3 else 20 end) z;
  end if;
  if p_kind in ('top', 'posts') then
    select coalesce(jsonb_agg(private.community_post_json(p, v_uid) order by p.created_at desc), '[]'::jsonb) into v_posts from (
      select * from public.community_posts x
      where x.status = 'shown' and not private.community_blocked(v_uid, x.user_id)
        and (case when v_tag is not null then exists (select 1 from unnest(x.tags) t where lower(t) = v_tag) else x.body ilike v_like end)
      order by x.created_at desc offset greatest(p_offset, 0) limit 20) p;
  end if;
  return jsonb_build_object('people', coalesce(v_people, '[]'::jsonb), 'posts', coalesce(v_posts, '[]'::jsonb));
end $$;
grant execute on function public.community_search(text, text, integer) to authenticated;

create or replace function public.community_explore()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_subjects smallint[]; v_since timestamptz := now() - interval '1 day'; v_trending jsonb;
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  select array_agg(s.id) into v_subjects from public.profiles pr join public.subjects s
    on s.code = any (coalesce(pr.jamb_subjects, '{}')) or s.name = any (coalesce(pr.jamb_subjects, '{}')) where pr.id = v_uid;
  if (select count(distinct lower(t)) from public.community_posts x, unnest(x.tags) t where x.status = 'shown' and x.created_at > v_since) < 4 then
    v_since := now() - interval '7 days';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('tag', z.tag, 'posts', z.n, 'rising', z.recent * 2 >= z.n and z.recent >= 2,
      'subject', (select s.name from public.subjects s where s.id = z.subject)) order by z.n desc, z.tag), '[]'::jsonb) into v_trending
  from (
    select mode() within group (order by t) as tag, count(*) as n, count(*) filter (where x.created_at > now() - interval '6 hours') as recent,
      mode() within group (order by x.subject_id) as subject
    from public.community_posts x, unnest(x.tags) t
    where x.status = 'shown' and x.created_at > v_since and not private.community_blocked(v_uid, x.user_id)
    group by lower(t) order by 2 desc limit 8) z;
  return jsonb_build_object(
    'trending', v_trending,
    'subjects', coalesce((select jsonb_agg(jsonb_build_object('id', z.id, 'name', z.name, 'today', z.today, 'mine', z.mine) order by z.mine desc, z.today desc, z.name)
      from (select s.id, s.name, s.id = any (coalesce(v_subjects, '{}')) as mine,
              (select count(*) from public.community_posts x where x.subject_id = s.id and x.status = 'shown' and x.created_at > now() - interval '1 day') as today
            from public.subjects s
            where s.id = any (coalesce(v_subjects, '{}'))
               or exists (select 1 from public.community_posts x where x.subject_id = s.id and x.status = 'shown' and x.created_at > now() - interval '30 days')
            order by 3 desc, 4 desc limit 8) z), '[]'::jsonb),
    'people', coalesce((select jsonb_agg(private.community_person_json(z.id, v_uid) || jsonb_build_object('why', z.why) order by z.rank desc, z.n desc)
      from (select pr.id,
              case when exists (select 1 from public.community_follows f where f.follower = pr.id and f.followee = v_uid) then 2 else 0 end
                + case when pr.jamb_subjects && (select p2.jamb_subjects from public.profiles p2 where p2.id = v_uid) then 1 else 0 end as rank,
              (select count(*) from public.community_posts x where x.user_id = pr.id and x.status = 'shown' and x.created_at > now() - interval '30 days') as n,
              case when exists (select 1 from public.community_follows f where f.follower = pr.id and f.followee = v_uid) then 'Follows you' end as why
            from public.profiles pr
            where pr.id <> v_uid and pr.banned_at is null
              and not exists (select 1 from public.community_follows f where f.follower = v_uid and f.followee = pr.id)
              and not private.community_blocked(v_uid, pr.id)
              and (exists (select 1 from public.community_follows f where f.follower = pr.id and f.followee = v_uid)
                   or exists (select 1 from public.community_posts x where x.user_id = pr.id and x.status = 'shown' and x.created_at > now() - interval '30 days'))
            order by 2 desc, 3 desc limit 5) z), '[]'::jsonb));
end $$;
grant execute on function public.community_explore() to authenticated;

-- ---------- Profiles ----------
create or replace function public.community_user(p_user uuid default null, p_handle text default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_id uuid; c public.community_profiles; pr public.profiles; v_me boolean; v_blocked boolean;
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  v_id := coalesce(p_user, (select x.user_id from public.community_profiles x where x.handle = lower(ltrim(btrim(coalesce(p_handle, '')), '@'))),
                   case when p_handle is null then v_uid end);
  select * into pr from public.profiles where id = v_id;
  if not found then return jsonb_build_object('status', 'not_found'); end if;
  c := private.community_profile_ensure(v_id);
  v_me := v_id = v_uid;
  v_blocked := not v_me and private.community_blocked(v_uid, v_id);
  return jsonb_build_object('id', v_id, 'me', v_me, 'name', coalesce(nullif(btrim(pr.full_name), ''), 'Student'), 'handle', c.handle,
    'bio', case when v_blocked then null else c.bio end, 'header', c.header,
    'avatar_path', case when v_me or (c.show_photo and not v_blocked) then pr.avatar_path end,
    'joined', pr.created_at,
    'exams', coalesce(to_jsonb(pr.target_exams), '[]'::jsonb),
    'subjects', coalesce((select jsonb_agg(s.name order by s.name) from public.subjects s where s.code = any (coalesce(pr.jamb_subjects, '{}')) or s.name = any (coalesce(pr.jamb_subjects, '{}'))), '[]'::jsonb),
    'streak', case when v_blocked then 0 else coalesce((select st.current_days from private.streak(v_id) st), 0) end,
    'posts', (select count(*) from public.community_posts p where p.user_id = v_id and p.status = 'shown'),
    'followers', (select count(*) from public.community_follows f where f.followee = v_id),
    'following_count', (select count(*) from public.community_follows f where f.follower = v_id),
    'following', exists (select 1 from public.community_follows f where f.follower = v_uid and f.followee = v_id),
    'follows_me', exists (select 1 from public.community_follows f where f.follower = v_id and f.followee = v_uid),
    'blocked', exists (select 1 from public.community_blocks b where b.blocker = v_uid and b.blocked = v_id),
    'blocked_me', exists (select 1 from public.community_blocks b where b.blocker = v_id and b.blocked = v_uid))
    || case when v_me then jsonb_build_object('show_photo', c.show_photo, 'pending_handle', c.pending_handle, 'pending_bio', c.pending_bio,
         'pending_reason', c.pending_reason, 'handle_auto', c.handle_auto,
         'handle_next', case when not c.handle_auto and c.handle_changed_at > now() - interval '30 days' then c.handle_changed_at + interval '30 days' end,
         'unread', public.community_unread()) else '{}'::jsonb end;
end $$;
grant execute on function public.community_user(uuid, text) to authenticated;

create or replace function public.community_user_list(p_user uuid, p_tab text default 'posts', p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  if p_user <> v_uid and private.community_blocked(v_uid, p_user) then return '[]'::jsonb; end if;
  if p_tab = 'replies' then
    return coalesce((select jsonb_agg(private.community_comment_json(c, v_uid) || jsonb_build_object('post', private.community_quote_json(c.post_id, v_uid)) order by c.created_at desc)
      from (select * from public.community_comments x where x.user_id = p_user and (x.status = 'shown' or (x.user_id = v_uid and x.status in ('pending', 'rejected')))
            and exists (select 1 from public.community_posts p where p.id = x.post_id and private.community_visible(p, v_uid))
            order by x.created_at desc offset greatest(p_offset, 0) limit 20) c), '[]'::jsonb);
  end if;
  if p_tab in ('likes', 'saved') then
    if p_user <> v_uid then return '[]'::jsonb; end if;  -- likes and saved posts are private
    return coalesce((select jsonb_agg(private.community_post_json(p, v_uid) order by t.at desc)
      from (select l.post_id, l.created_at as at from public.community_likes l where p_tab = 'likes' and l.user_id = v_uid
            union all select b.post_id, b.created_at from public.community_bookmarks b where p_tab = 'saved' and b.user_id = v_uid
            order by 2 desc offset greatest(p_offset, 0) limit 20) t
      join public.community_posts p on p.id = t.post_id where private.community_visible(p, v_uid)), '[]'::jsonb);
  end if;
  return coalesce((
    with items as (
      select x.id, x.created_at as at, null::uuid as by from public.community_posts x where x.user_id = p_user and private.community_visible(x, v_uid)
      union all
      select r.post_id, r.created_at, r.user_id from public.community_reposts r join public.community_posts x on x.id = r.post_id
      where r.user_id = p_user and x.user_id <> p_user and x.status = 'shown' and not private.community_blocked(v_uid, x.user_id)),
    page as (select * from items order by at desc offset greatest(p_offset, 0) limit 20)
    select jsonb_agg(private.community_post_json(p, v_uid) || case when b.by is null then '{}'::jsonb
             else jsonb_build_object('reposted_by', private.community_person_json(b.by, v_uid)) end order by b.at desc)
    from page b join public.community_posts p on p.id = b.id), '[]'::jsonb);
end $$;
grant execute on function public.community_user_list(uuid, text, integer) to authenticated;

create or replace function public.community_follow_list(p_user uuid, p_kind text default 'followers', p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  if p_user <> v_uid and private.community_blocked(v_uid, p_user) then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(private.community_person_json(z.id, v_uid) order by z.at desc)
    from (select case when p_kind = 'following' then f.followee else f.follower end as id, f.created_at as at
          from public.community_follows f
          where ((p_kind = 'following' and f.follower = p_user) or (p_kind <> 'following' and f.followee = p_user))
            and not private.community_blocked(v_uid, case when p_kind = 'following' then f.followee else f.follower end)
          order by f.created_at desc offset greatest(p_offset, 0) limit 30) z), '[]'::jsonb);
end $$;
grant execute on function public.community_follow_list(uuid, text, integer) to authenticated;

-- Handle availability while the student types.
create or replace function public.community_handle_check(p_handle text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); h text := lower(ltrim(btrim(coalesce(p_handle, '')), '@'));
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  if h !~ '^[a-z0-9][a-z0-9_.]{1,18}[a-z0-9_]$' or h ~ '\.\.' then return jsonb_build_object('ok', false, 'error', 'format', 'handle', h); end if;
  if private.community_handle_reserved(h) then return jsonb_build_object('ok', false, 'error', 'reserved', 'handle', h); end if;
  if not private.community_handle_free(h, v_uid) then return jsonb_build_object('ok', false, 'error', 'taken', 'handle', h); end if;
  return jsonb_build_object('ok', true, 'handle', h);
end $$;
grant execute on function public.community_handle_check(text) to authenticated;

create or replace function public.community_profile_save(p_handle text default null, p_bio text default null, p_show_photo boolean default null, p_header smallint default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); c public.community_profiles; v_ai boolean := coalesce((private.community_settings() ->> 'ai_check')::boolean, true);
  h text; b text; v_chk jsonb; v_new_handle boolean := false; v_new_bio boolean := false;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  c := private.community_profile_ensure(v_uid);
  if p_handle is not null then
    h := lower(ltrim(btrim(p_handle), '@'));
    if h <> c.handle and h is distinct from c.pending_handle then
      v_chk := public.community_handle_check(h);
      if not (v_chk ->> 'ok')::boolean then return v_chk; end if;
      if not c.handle_auto and c.handle_changed_at > now() - interval '30 days' then
        return jsonb_build_object('ok', false, 'error', 'wait', 'next', c.handle_changed_at + interval '30 days');
      end if;
      v_new_handle := true;
    elsif h = c.handle and c.pending_handle is not null then
      update public.community_profiles set pending_handle = null where user_id = v_uid;
    end if;
  end if;
  if p_bio is not null then
    b := nullif(btrim(regexp_replace(p_bio, '\s+', ' ', 'g')), '');
    if char_length(b) > 160 then return jsonb_build_object('ok', false, 'error', 'bio_long'); end if;
    if b is null then update public.community_profiles set bio = null, pending_bio = null where user_id = v_uid;
    elsif b is distinct from c.bio and b is distinct from c.pending_bio then v_new_bio := true;
    end if;
  end if;
  update public.community_profiles set
    show_photo = coalesce(p_show_photo, show_photo),
    header = case when p_header is null then header else least(greatest(p_header, 0), 5) end,
    pending_handle = case when v_new_handle and v_ai then h else pending_handle end,
    handle = case when v_new_handle and not v_ai then h else handle end,
    handle_auto = case when v_new_handle and not v_ai then false else handle_auto end,
    handle_changed_at = case when v_new_handle and not v_ai then now() else handle_changed_at end,
    pending_bio = case when v_new_bio and v_ai then b else pending_bio end,
    bio = case when v_new_bio and not v_ai then b else bio end,
    pending_at = case when (v_new_handle or v_new_bio) and v_ai then now() else pending_at end,
    pending_reason = case when v_new_handle or v_new_bio then null else pending_reason end
  where user_id = v_uid returning * into c;
  return jsonb_build_object('ok', true, 'pending', c.pending_handle is not null or c.pending_bio is not null, 'handle', c.handle);
end $$;
grant execute on function public.community_profile_save(text, text, boolean, smallint) to authenticated;

-- The AI (or staff) decision on a waiting handle and bio.
create or replace function public.community_profile_decide(p_user uuid, p_ok boolean, p_reason text default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare c public.community_profiles; v_reason text := coalesce(nullif(btrim(p_reason), ''), 'Please choose a friendlier name and bio.');
begin
  select * into c from public.community_profiles where user_id = p_user and pending_at is not null for update;
  if not found then return jsonb_build_object('ok', false); end if;
  if p_ok then
    update public.community_profiles set
      handle = case when pending_handle is not null and private.community_handle_free(pending_handle, p_user) then pending_handle else handle end,
      handle_auto = case when pending_handle is not null then false else handle_auto end,
      handle_changed_at = case when pending_handle is not null then now() else handle_changed_at end,
      bio = coalesce(pending_bio, bio), pending_handle = null, pending_bio = null, pending_at = null, pending_reason = null
    where user_id = p_user;
    perform private.community_note(p_user, null, 'profile', null, null, 'Your profile changes are live.');
  else
    update public.community_profiles set pending_handle = null, pending_bio = null, pending_at = null, pending_reason = left(v_reason, 200) where user_id = p_user;
    perform private.community_note(p_user, null, 'profile', null, null, left(v_reason, 200));
    perform private.community_push(p_user, 'Your profile change was not saved', v_reason, '/community/me');
  end if;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.community_profile_decide(uuid, boolean, text) from public, anon, authenticated;

create or replace function public.community_pending(p_limit integer default 20)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'posts', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'user_id', p.user_id, 'body', p.body, 'image_path', p.image_path,
        'quote', (select left(q.body, 400) from public.community_posts q where q.id = p.quote_of)))
      from (select * from public.community_posts x where x.status = 'pending' and cardinality(x.images) = 0 and x.image_path is null and x.created_at < now() - interval '1 minute'
            and x.created_at > now() - interval '1 day' order by x.created_at limit p_limit) p), '[]'::jsonb),
    'comments', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'user_id', c.user_id, 'body', c.body, 'post', (select left(p.body, 600) from public.community_posts p where p.id = c.post_id)))
      from (select * from public.community_comments x where x.status = 'pending' and x.created_at < now() - interval '1 minute'
            and x.created_at > now() - interval '1 day' order by x.created_at limit p_limit) c), '[]'::jsonb),
    'answers', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'user_id', p.user_id, 'body', p.body))
      from (select * from public.community_posts x where x.status = 'shown' and x.ask_ai and not x.ai_answered and x.created_at > now() - interval '1 day'
            order by x.created_at limit 5) p), '[]'::jsonb),
    'profiles', coalesce((select jsonb_agg(jsonb_build_object('user_id', c.user_id, 'handle', c.pending_handle, 'bio', c.pending_bio))
      from (select * from public.community_profiles x where x.pending_at is not null and x.pending_at < now() - interval '1 minute'
            and x.pending_at > now() - interval '3 days' order by x.pending_at limit p_limit) c), '[]'::jsonb));
$$;
revoke all on function public.community_pending(integer) from public, anon, authenticated;

create or replace function public.admin_community_counts()
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when not private.is_staff() then null else jsonb_build_object(
    'pending', (select count(*) from public.community_posts where status = 'pending') + (select count(*) from public.community_comments where status = 'pending'),
    'hidden', (select count(*) from public.community_posts where status = 'hidden') + (select count(*) from public.community_comments where status = 'hidden'),
    'rejected_week', (select count(*) from public.community_posts where status = 'rejected' and created_at > now() - interval '7 days'),
    'posts_week', (select count(*) from public.community_posts where created_at > now() - interval '7 days'),
    'profiles_pending', (select count(*) from public.community_profiles where pending_at is not null),
    'quotes_week', (select count(*) from public.community_posts where quote_of is not null and created_at > now() - interval '7 days'),
    'reposts_week', (select count(*) from public.community_reposts where created_at > now() - interval '7 days')) end;
$$;

-- Signed-in students only (older D-151 RPCs keep working: community_feed, community_post_get, community_profile).
revoke execute on function public.community_post_send(text, text[], smallint, uuid), public.community_reply(uuid, text, bigint), public.community_repost(uuid),
  public.community_bookmark(uuid), public.community_comment_like(bigint), public.community_home(text, integer, smallint, text),
  public.community_new_count(text, timestamptz), public.community_thread(uuid), public.community_notes_list(text, integer), public.community_unread(),
  public.community_notes_read(), public.community_search(text, text, integer), public.community_explore(), public.community_user(uuid, text),
  public.community_user_list(uuid, text, integer), public.community_follow_list(uuid, text, integer), public.community_handle_check(text),
  public.community_profile_save(text, text, boolean, smallint) from public, anon;
