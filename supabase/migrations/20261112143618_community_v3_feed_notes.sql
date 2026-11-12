-- Community v3 (D-156), part 3: the feed ranking, page profiles, personal notifications (posts from people you engage
-- with, like milestones, a daily summary, questions you could answer).

create or replace function public.community_home(p_tab text default 'for_you', p_offset integer default 0, p_subject smallint default null, p_tag text default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_subjects smallint[]; v_tag text := lower(nullif(ltrim(btrim(coalesce(p_tag, '')), '#'), ''));
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  if p_tab = 'following' then
    return coalesce((
      with items as (
        select x.id, x.created_at as at, null::uuid as by from public.community_posts x
        where ((x.page_id is null and (x.user_id = v_uid or exists (select 1 from public.community_follows f where f.follower = v_uid and f.followee = x.user_id)))
               or (x.page_id is not null and exists (select 1 from public.community_page_follows pf where pf.user_id = v_uid and pf.page_id = x.page_id)))
          and private.community_visible(x, v_uid)
          and not exists (select 1 from public.community_hidden h where h.user_id = v_uid and h.post_id = x.id)
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
  if p_subject is not null or v_tag is not null then
    return coalesce((
      select jsonb_agg(private.community_post_json(p, v_uid) order by p.created_at desc)
      from (select * from public.community_posts x
            where private.community_visible(x, v_uid) and (p_subject is null or x.subject_id = p_subject)
              and (v_tag is null or exists (select 1 from unnest(x.tags) t where lower(t) = v_tag))
              and not exists (select 1 from public.community_hidden h where h.user_id = v_uid and h.post_id = x.id)
            order by x.created_at desc offset greatest(p_offset, 0) limit 20) p), '[]'::jsonb);
  end if;
  -- For you: who you follow and interact with, friends of friends, your subjects and #topics, what is lively now,
  -- fresh questions with no answer yet, SolutionTee pages, a variety of authors, and less of what you hid.
  return coalesce((
    with aff as (
      select p.user_id as author, count(*) as n from (
        select l.post_id from public.community_likes l where l.user_id = v_uid and l.created_at > now() - interval '30 days'
        union all select c.post_id from public.community_comments c where c.user_id = v_uid and c.created_at > now() - interval '30 days'
        union all select r.post_id from public.community_reposts r where r.user_id = v_uid and r.created_at > now() - interval '30 days') x
      join public.community_posts p on p.id = x.post_id group by 1),
    fol as (select f.followee as author from public.community_follows f where f.follower = v_uid),
    pfol as (select pf.page_id from public.community_page_follows pf where pf.user_id = v_uid),
    second as (select f2.followee as author, count(*) as n from public.community_follows f1
               join public.community_follows f2 on f2.follower = f1.followee where f1.follower = v_uid and f2.followee <> v_uid group by 1),
    mytags as (select lower(t) as tag, count(*) as n from (
                 select unnest(p.tags) as t from public.community_posts p where p.user_id = v_uid and p.created_at > now() - interval '30 days'
                 union all select unnest(p.tags) from public.community_likes l join public.community_posts p on p.id = l.post_id
                 where l.user_id = v_uid and l.created_at > now() - interval '30 days') z group by 1),
    hid as (select h.author, count(*) as n from public.community_hidden h where h.user_id = v_uid group by 1),
    cand as (
      select x.id, x.user_id, x.page_id, rp.by,
        3.0 * (case when (x.page_id is null and exists (select 1 from fol where fol.author = x.user_id))
                      or (x.page_id is not null and exists (select 1 from pfol where pfol.page_id = x.page_id)) then 1 else 0 end)
        + 2.5 * ln(1 + coalesce((select aff.n from aff where aff.author = x.user_id), 0))
        + 1.2 * ln(1 + coalesce((select second.n from second where second.author = x.user_id), 0))
        + 2.0 * (case when rp.by is not null then 1 else 0 end)
        + 1.5 * (case when x.subject_id = any (coalesce(v_subjects, '{}')) then 1 else 0 end)
        + 0.8 * ln(1 + coalesce((select sum(mt.n) from mytags mt where mt.tag = any (select lower(t) from unnest(x.tags) t)), 0))
        + 1.0 * ln(1 + x.likes_count + 2 * x.comments_count + 3 * x.reposts_count)
        + (case when pg.official then 2.5 when pg.id is not null then 1.2 when exists (select 1 from public.staff s where s.user_id = x.user_id and s.role <> 'tutor') then 0.6 else 0 end)
        + (case when x.body like '%?%' and x.comments_count = 0 and x.created_at > now() - interval '24 hours' then 1.0 else 0 end)
        + (case when cardinality(x.images) > 0 then 0.3 else 0 end)
        + (case when x.created_at > now() - interval '2 hours' then 1.0 else 0 end)
        - 2.5 * ln(1 + coalesce((select hid.n from hid where hid.author = x.user_id), 0))
        - extract(epoch from (now() - x.created_at)) / 3600.0 / 18.0 as score
      from public.community_posts x
      left join public.community_pages pg on pg.id = x.page_id
      left join lateral (select r.user_id as by from public.community_reposts r join public.community_follows f on f.follower = v_uid and f.followee = r.user_id
                         where r.post_id = x.id and r.user_id <> x.user_id order by r.created_at desc limit 1) rp on true
      where private.community_visible(x, v_uid) and x.created_at > now() - interval '30 days'
        and not exists (select 1 from public.community_hidden h where h.user_id = v_uid and h.post_id = x.id)),
    ranked as (
      select c.*, c.score - 1.5 * (row_number() over (partition by coalesce(c.page_id::text, c.user_id::text) order by c.score desc) - 1) as final
      from cand c),
    page as (select * from ranked order by final desc offset greatest(p_offset, 0) limit 20)
    select jsonb_agg(private.community_post_json(p, v_uid) || case when t.by is null then '{}'::jsonb
             else jsonb_build_object('reposted_by', private.community_person_json(t.by, v_uid)) end order by t.final desc)
    from page t join public.community_posts p on p.id = t.id), '[]'::jsonb);
end $$;

-- ---------- profiles: students and pages ----------
create or replace function private.community_page_json(pg public.community_pages, p_me uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', pg.id, 'is_page', true, 'me', false, 'name', pg.name, 'handle', pg.handle, 'bio', pg.bio, 'header', pg.header,
    'avatar_path', pg.avatar_path, 'badge', case when pg.official then 'official' else 'page' end, 'official', pg.official, 'joined', pg.created_at,
    'posts', (select count(*) from public.community_posts p where p.page_id = pg.id and p.status = 'shown'),
    'followers', (select count(*) from public.community_page_follows f where f.page_id = pg.id), 'following_count', 0,
    'following', exists (select 1 from public.community_page_follows f where f.page_id = pg.id and f.user_id = p_me),
    'can_post', private.community_can_page(p_me, pg.id), 'exams', '[]'::jsonb, 'subjects', '[]'::jsonb, 'streak', 0);
$$;

create or replace function public.community_user(p_user uuid default null, p_handle text default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_id uuid; c public.community_profiles; pr public.profiles; v_me boolean; v_blocked boolean;
  pg public.community_pages; h text := lower(ltrim(btrim(coalesce(p_handle, '')), '@')); s jsonb := private.community_settings();
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  select * into pg from public.community_pages g where g.id = p_user or (p_user is null and g.handle = h);
  if found then return private.community_page_json(pg, v_uid); end if;
  v_id := coalesce(p_user, (select x.user_id from public.community_profiles x where x.handle = h), case when p_handle is null then v_uid end);
  select * into pr from public.profiles where id = v_id;
  if not found then return jsonb_build_object('status', 'not_found'); end if;
  c := private.community_profile_ensure(v_id);
  v_me := v_id = v_uid;
  v_blocked := not v_me and private.community_blocked(v_uid, v_id);
  return jsonb_build_object('id', v_id, 'me', v_me, 'name', coalesce(nullif(btrim(pr.full_name), ''), 'Student'), 'handle', c.handle,
    'bio', case when v_blocked then null else c.bio end, 'header', c.header, 'badge', private.community_badge(v_id),
    'avatar_path', case when v_me or (c.show_photo and not v_blocked) then pr.avatar_path end,
    'joined', pr.created_at,
    'exams', coalesce(to_jsonb(pr.target_exams), '[]'::jsonb),
    'subjects', coalesce((select jsonb_agg(s2.name order by s2.name) from public.subjects s2 where s2.code = any (coalesce(pr.jamb_subjects, '{}')) or s2.name = any (coalesce(pr.jamb_subjects, '{}'))), '[]'::jsonb),
    'streak', case when v_blocked then 0 else coalesce((select st.current_days from private.streak(v_id) st), 0) end,
    'posts', (select count(*) from public.community_posts p where p.user_id = v_id and p.page_id is null and p.status = 'shown'),
    'followers', (select count(*) from public.community_follows f where f.followee = v_id),
    'following_count', (select count(*) from public.community_follows f where f.follower = v_id),
    'following', exists (select 1 from public.community_follows f where f.follower = v_uid and f.followee = v_id),
    'follows_me', exists (select 1 from public.community_follows f where f.follower = v_id and f.followee = v_uid),
    'blocked', exists (select 1 from public.community_blocks b where b.blocker = v_uid and b.blocked = v_id),
    'blocked_me', exists (select 1 from public.community_blocks b where b.blocker = v_id and b.blocked = v_uid),
    'viewer_mod', private.community_is_mod(v_uid))
    || case when v_me then jsonb_build_object('show_photo', c.show_photo, 'pending_handle', c.pending_handle, 'pending_bio', c.pending_bio,
         'pending_reason', c.pending_reason, 'handle_auto', c.handle_auto,
         'handle_next', case when not c.handle_auto and c.handle_changed_at > now() - interval '30 days' then c.handle_changed_at + interval '30 days' end,
         'unread', public.community_unread(), 'mod', private.community_is_mod(v_uid), 'pages', public.community_my_pages(),
         'banned_until', private.community_banned_until(v_uid), 'notify', c.notify,
         'ad_every', coalesce((s ->> 'ad_every')::int, 5)) else '{}'::jsonb end;
end $$;

create or replace function public.community_user_list(p_user uuid, p_tab text default 'posts', p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  if exists (select 1 from public.community_pages g where g.id = p_user) then
    return coalesce((select jsonb_agg(private.community_post_json(p, v_uid) order by p.created_at desc)
      from (select * from public.community_posts x where x.page_id = p_user and x.status = 'shown' order by x.created_at desc offset greatest(p_offset, 0) limit 20) p), '[]'::jsonb);
  end if;
  if p_user <> v_uid and private.community_blocked(v_uid, p_user) then return '[]'::jsonb; end if;
  if p_tab = 'replies' then
    return coalesce((select jsonb_agg(private.community_comment_json(c, v_uid) || jsonb_build_object('post', private.community_quote_json(c.post_id, v_uid)) order by c.created_at desc)
      from (select * from public.community_comments x where x.user_id = p_user and (x.status = 'shown' or (x.user_id = v_uid and x.status in ('pending', 'rejected')))
            and exists (select 1 from public.community_posts p where p.id = x.post_id and private.community_visible(p, v_uid))
            order by x.created_at desc offset greatest(p_offset, 0) limit 20) c), '[]'::jsonb);
  end if;
  if p_tab in ('likes', 'saved') then
    if p_user <> v_uid then return '[]'::jsonb; end if;
    return coalesce((select jsonb_agg(private.community_post_json(p, v_uid) order by t.at desc)
      from (select l.post_id, l.created_at as at from public.community_likes l where p_tab = 'likes' and l.user_id = v_uid
            union all select b.post_id, b.created_at from public.community_bookmarks b where p_tab = 'saved' and b.user_id = v_uid
            order by 2 desc offset greatest(p_offset, 0) limit 20) t
      join public.community_posts p on p.id = t.post_id where private.community_visible(p, v_uid)), '[]'::jsonb);
  end if;
  return coalesce((
    with items as (
      select x.id, x.created_at as at, null::uuid as by from public.community_posts x where x.user_id = p_user and x.page_id is null and private.community_visible(x, v_uid)
      union all
      select r.post_id, r.created_at, r.user_id from public.community_reposts r join public.community_posts x on x.id = r.post_id
      where r.user_id = p_user and x.user_id <> p_user and x.status = 'shown' and not private.community_blocked(v_uid, x.user_id)),
    page as (select * from items order by at desc offset greatest(p_offset, 0) limit 20)
    select jsonb_agg(private.community_post_json(p, v_uid) || case when b.by is null then '{}'::jsonb
             else jsonb_build_object('reposted_by', private.community_person_json(b.by, v_uid)) end order by b.at desc)
    from page b join public.community_posts p on p.id = b.id), '[]'::jsonb);
end $$;

-- ---------- personal notifications ----------
-- A new post tells the followers who really engage with this author (2+ likes, replies or reposts in 30 days),
-- at most once in 6 hours per author, and pushes at most 3 of these a day.
create or replace function private.community_post_shown(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare p public.community_posts; v_q uuid; r record; v_name text;
begin
  select * into p from public.community_posts where id = p_id;
  if not found then return; end if;
  if p.checked_at is not null and p.page_id is null then perform private.community_note(p.user_id, null, 'shown', p.id, null, p.body); end if;
  if p.quote_of is not null then
    perform private.community_recount_reposts(p.quote_of);
    select user_id into v_q from public.community_posts where id = p.quote_of;
    if v_q is not null and v_q <> p.user_id and not private.community_blocked(v_q, p.user_id) then
      perform private.community_note(v_q, p.user_id, 'quote', p.id, null, p.body);
      perform private.community_push(v_q, private.game_name(p.user_id) || ' quoted your post', p.body, '/community/post/' || p.id);
    end if;
  end if;
  perform private.community_mentions(p.body, p.user_id, p.id, null, array[v_q]);
  if p.page_id is not null then return; end if;
  v_name := private.game_name(p.user_id);
  for r in
    select f.follower as uid from public.community_follows f
    where f.followee = p.user_id and f.follower <> coalesce(v_q, '00000000-0000-0000-0000-000000000000'::uuid)
      and (select count(*) from (
             select 1 from public.community_likes l join public.community_posts x on x.id = l.post_id where l.user_id = f.follower and x.user_id = p.user_id and l.created_at > now() - interval '30 days'
             union all select 1 from public.community_comments c join public.community_posts x on x.id = c.post_id where c.user_id = f.follower and x.user_id = p.user_id and c.created_at > now() - interval '30 days') z) >= 2
      and not exists (select 1 from public.community_notes n where n.user_id = f.follower and n.actor = p.user_id and n.kind = 'post' and n.created_at > now() - interval '6 hours')
    limit 300
  loop
    perform private.community_note(r.uid, p.user_id, 'post', p.id, null, p.body);
    if (select count(*) from public.community_notes n where n.user_id = r.uid and n.kind = 'post' and n.created_at > now() - interval '1 day') <= 3 then
      perform private.community_push(r.uid, v_name || ' just posted', p.body, '/community/post/' || p.id);
    end if;
  end loop;
end $$;

-- Likes: a milestone note at 10, 25, 50, 100, 250, 500 and 1000 likes.
create or replace function public.community_like(p_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); p public.community_posts; v_liked boolean;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into p from public.community_posts where id = p_id and status = 'shown' for update;
  if not found or private.community_blocked(v_uid, p.user_id) then return jsonb_build_object('ok', false); end if;
  delete from public.community_likes where post_id = p_id and user_id = v_uid;
  if found then v_liked := false; else insert into public.community_likes (post_id, user_id) values (p_id, v_uid); v_liked := true; end if;
  update public.community_posts set likes_count = greatest(0, likes_count + case when v_liked then 1 else -1 end) where id = p_id returning likes_count into p.likes_count;
  if v_liked and p.page_id is null then
    perform private.community_note(p.user_id, v_uid, 'like', p.id, null, p.body);
    if p.likes_count in (10, 25, 50, 100, 250, 500, 1000)
       and not exists (select 1 from public.community_notes n where n.user_id = p.user_id and n.kind = 'milestone' and n.post_id = p.id and n.body like p.likes_count || ' %') then
      perform private.community_note(p.user_id, null, 'milestone', p.id, null, p.likes_count || ' likes on your post. Students love it!');
      perform private.community_push(p.user_id, 'Your post reached ' || p.likes_count || ' likes', p.body, '/community/post/' || p.id);
    end if;
  end if;
  return jsonb_build_object('ok', true, 'liked', v_liked, 'likes', p.likes_count);
end $$;

-- Every evening: a short summary of the day for each student whose posts got activity, and one question in their
-- subjects that is still waiting for an answer.
create or replace function private.community_digest()
returns integer language plpgsql security definer set search_path = '' as $$
declare r record; v_n integer := 0; v_text text; v_qid uuid; v_qbody text; v_quser uuid; v_qsub text;
begin
  for r in
    select p.user_id,
      count(*) filter (where a.kind = 'like') as likes, count(*) filter (where a.kind = 'reply') as replies, count(*) filter (where a.kind = 'repost') as reposts
    from (select l.post_id, 'like' as kind from public.community_likes l where l.created_at > now() - interval '1 day'
          union all select c.post_id, 'reply' from public.community_comments c where c.created_at > now() - interval '1 day' and c.status = 'shown' and not c.from_ai
          union all select r2.post_id, 'repost' from public.community_reposts r2 where r2.created_at > now() - interval '1 day') a
    join public.community_posts p on p.id = a.post_id where p.page_id is null
    group by p.user_id having count(*) >= 3 limit 5000
  loop
    v_text := 'Today your posts got ' || concat_ws(', ',
      case when r.likes > 0 then r.likes || case when r.likes = 1 then ' like' else ' likes' end end,
      case when r.replies > 0 then r.replies || case when r.replies = 1 then ' reply' else ' replies' end end,
      case when r.reposts > 0 then r.reposts || case when r.reposts = 1 then ' repost' else ' reposts' end end) || '. Keep sharing!';
    perform private.community_note(r.user_id, null, 'digest', null, null, v_text);
    perform private.community_push(r.user_id, 'Your day in Community', v_text, '/community/notifications');
    v_n := v_n + 1;
  end loop;
  for r in
    select pr.id as uid, pr.jamb_subjects from public.profiles pr join public.community_profiles c on c.user_id = pr.id
    where cardinality(coalesce(pr.jamb_subjects, '{}')) > 0
      and (exists (select 1 from public.community_posts p where p.user_id = pr.id and p.created_at > now() - interval '14 days')
           or exists (select 1 from public.community_likes l where l.user_id = pr.id and l.created_at > now() - interval '14 days'))
    limit 5000
  loop
    v_qid := null;
    select p.id, p.body, p.user_id, s.name into v_qid, v_qbody, v_quser, v_qsub from public.community_posts p join public.subjects s on s.id = p.subject_id
    where p.status = 'shown' and p.page_id is null and p.user_id <> r.uid and p.body like '%?%' and p.comments_count = 0
      and p.created_at > now() - interval '1 day' and (s.code = any (r.jamb_subjects) or s.name = any (r.jamb_subjects))
      and not private.community_blocked(r.uid, p.user_id)
    order by p.created_at desc limit 1;
    if v_qid is not null then
      perform private.community_note(r.uid, v_quser, 'suggest', v_qid, null, private.game_name(v_quser) || ' asked a ' || v_qsub || ' question. Can you help? ' || v_qbody);
      v_n := v_n + 1;
    end if;
  end loop;
  return v_n;
end $$;

select cron.unschedule(jobid) from cron.job where jobname = 'community-digest';
select cron.schedule('community-digest', '31 18 * * *', 'select private.community_digest()');
