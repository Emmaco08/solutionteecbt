-- Community v2 (D-155), part 2: JSON shapes, feed, thread, actions, notes, search, explore, profiles.

-- ---------- JSON ----------
create or replace function private.community_person_json(p_id uuid, p_me uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', pr.id, 'name', coalesce(nullif(btrim(pr.full_name), ''), 'Student'), 'handle', c.handle,
    'avatar_path', case when pr.id = p_me or coalesce(c.show_photo, true) then pr.avatar_path end, 'bio', c.bio,
    'following', exists (select 1 from public.community_follows f where f.follower = p_me and f.followee = pr.id),
    'follows_me', exists (select 1 from public.community_follows f where f.follower = pr.id and f.followee = p_me))
  from public.profiles pr left join public.community_profiles c on c.user_id = pr.id where pr.id = p_id;
$$;

create or replace function private.community_quote_json(p_id uuid, p_me uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce((
    select jsonb_build_object('id', q.id, 'user_id', q.user_id, 'name', coalesce(nullif(btrim(pr.full_name), ''), 'Student'), 'handle', c.handle,
      'avatar_path', case when q.user_id = p_me or coalesce(c.show_photo, true) then pr.avatar_path end,
      'body', left(q.body, 500), 'images', q.images, 'subject_id', q.subject_id, 'created_at', q.created_at)
    from public.community_posts q join public.profiles pr on pr.id = q.user_id left join public.community_profiles c on c.user_id = q.user_id
    where q.id = p_id and (q.status = 'shown' or q.user_id = p_me) and not private.community_blocked(p_me, q.user_id)),
    jsonb_build_object('id', p_id, 'unavailable', true));
$$;

create or replace function private.community_post_json(p public.community_posts, p_me uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', p.id, 'user_id', p.user_id, 'name', coalesce(nullif(btrim(pr.full_name), ''), 'Student'), 'handle', c.handle,
    'avatar_path', case when p.user_id = p_me or coalesce(c.show_photo, true) then pr.avatar_path end,
    'body', p.body, 'image_path', coalesce(p.images[1], p.image_path), 'images', p.images, 'subject_id', p.subject_id, 'status', p.status,
    'reason', case when p.user_id = p_me then p.reason end, 'likes', p.likes_count, 'comments', p.comments_count, 'reposts', p.reposts_count,
    'created_at', p.created_at, 'mine', p.user_id = p_me, 'ask_ai', p.ask_ai,
    'liked', exists (select 1 from public.community_likes l where l.post_id = p.id and l.user_id = p_me),
    'reposted', exists (select 1 from public.community_reposts r where r.post_id = p.id and r.user_id = p_me),
    'bookmarked', exists (select 1 from public.community_bookmarks b where b.post_id = p.id and b.user_id = p_me),
    'following', exists (select 1 from public.community_follows f where f.follower = p_me and f.followee = p.user_id),
    'ai_answer', case when p.ask_ai then (select left(x.body, 280) from public.community_comments x where x.post_id = p.id and x.from_ai and x.status = 'shown' order by x.id limit 1) end,
    'quote', case when p.quote_of is not null then private.community_quote_json(p.quote_of, p_me) end)
  from public.profiles pr left join public.community_profiles c on c.user_id = pr.id where pr.id = p.user_id;
$$;

create or replace function private.community_comment_json(x public.community_comments, p_me uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', x.id, 'post_id', x.post_id, 'parent_id', x.parent_id, 'user_id', x.user_id, 'from_ai', x.from_ai,
    'name', case when x.from_ai then 'SolutionTee AI' else coalesce(nullif(btrim(pr.full_name), ''), 'Student') end,
    'handle', case when x.from_ai then 'solutiontee' else c.handle end,
    'avatar_path', case when x.user_id = p_me or coalesce(c.show_photo, true) then pr.avatar_path end,
    'body', x.body, 'status', x.status, 'reason', case when x.user_id = p_me then x.reason end, 'mine', x.user_id = p_me,
    'likes', x.likes_count, 'replies', x.replies_count, 'created_at', x.created_at,
    'liked', exists (select 1 from public.community_comment_likes l where l.comment_id = x.id and l.user_id = p_me),
    'reply_to_handle', (select rc.handle from public.community_profiles rc where rc.user_id = x.reply_to))
  from (select 1) one left join public.profiles pr on pr.id = x.user_id left join public.community_profiles c on c.user_id = x.user_id;
$$;

create or replace function private.community_visible(x public.community_posts, p_me uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select (x.status = 'shown' or (x.user_id = p_me and x.status in ('pending', 'rejected'))) and not private.community_blocked(p_me, x.user_id);
$$;

-- ---------- Push helper (important kinds only) ----------
create or replace function private.community_push(p_user uuid, p_title text, p_body text, p_target text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_user is null then return; end if;
  insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
  values ('account'::public.notif_topic, left(p_title, 80), case when char_length(btrim(coalesce(p_body, ''))) < 2 then 'Open Community to see it.' else left(p_body, 200) end,
          'user', p_user, 'scheduled', now(), 'community', jsonb_build_object('type', 'screen', 'target', p_target));
end $$;

-- @handle mentions in a shown post or reply (at most 5 people).
create or replace function private.community_mentions(p_body text, p_actor uuid, p_post uuid, p_comment bigint, p_skip uuid[])
returns void language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in
    select distinct c.user_id from (select (regexp_matches(lower(coalesce(p_body, '')), '@([a-z0-9][a-z0-9_.]{1,18}[a-z0-9_])', 'g'))[1] as h limit 8) m
    join public.community_profiles c on c.handle = m.h
    where c.user_id <> p_actor and not (c.user_id = any (array_remove(coalesce(p_skip, '{}'), null))) limit 5
  loop
    if not private.community_blocked(r.user_id, p_actor) then
      perform private.community_note(r.user_id, p_actor, 'mention', p_post, p_comment, p_body);
      perform private.community_push(r.user_id, private.game_name(p_actor) || ' mentioned you', p_body, '/community/post/' || p_post);
    end if;
  end loop;
end $$;

create or replace function private.community_recount_reposts(p_id uuid)
returns integer language sql volatile security definer set search_path = '' as $$
  update public.community_posts set reposts_count = (select count(*) from public.community_reposts r where r.post_id = p_id)
    + (select count(*) from public.community_posts q where q.quote_of = p_id and q.status = 'shown')
  where id = p_id returning reposts_count;
$$;

-- A post just became visible to everyone: tell the author, quoted author and mentioned people.
create or replace function private.community_post_shown(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare p public.community_posts; v_q uuid;
begin
  select * into p from public.community_posts where id = p_id;
  if not found then return; end if;
  if p.checked_at is not null then perform private.community_note(p.user_id, null, 'shown', p.id, null, p.body); end if;
  if p.quote_of is not null then
    perform private.community_recount_reposts(p.quote_of);
    select user_id into v_q from public.community_posts where id = p.quote_of;
    if v_q is not null and v_q <> p.user_id and not private.community_blocked(v_q, p.user_id) then
      perform private.community_note(v_q, p.user_id, 'quote', p.id, null, p.body);
      perform private.community_push(v_q, private.game_name(p.user_id) || ' quoted your post', p.body, '/community/post/' || p.id);
    end if;
  end if;
  perform private.community_mentions(p.body, p.user_id, p.id, null, array[v_q]);
end $$;

-- Replies: counts, notes and pushes (replaces the D-151 version).
create or replace function private.community_comment_shown(p_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare c public.community_comments; p public.community_posts;
begin
  select * into c from public.community_comments where id = p_id;
  select * into p from public.community_posts where id = c.post_id;
  update public.community_posts set comments_count = (select count(*) from public.community_comments x where x.post_id = p.id and x.status = 'shown') where id = p.id;
  if c.parent_id is not null then
    update public.community_comments set replies_count = (select count(*) from public.community_comments x where x.parent_id = c.parent_id and x.status = 'shown') where id = c.parent_id;
  end if;
  if c.from_ai then
    perform private.community_note(p.user_id, null, 'ai', p.id, c.id, c.body);
    perform private.community_push(p.user_id, 'SolutionTee AI answered your post', c.body, '/community/post/' || p.id);
    return;
  end if;
  if c.user_id is distinct from p.user_id then
    perform private.community_note(p.user_id, c.user_id, 'reply', p.id, c.id, c.body);
    perform private.community_push(p.user_id, private.game_name(c.user_id) || ' replied to your post', c.body, '/community/post/' || p.id);
  end if;
  if c.reply_to is not null and c.reply_to is distinct from p.user_id and c.reply_to is distinct from c.user_id then
    perform private.community_note(c.reply_to, c.user_id, 'reply', p.id, c.id, c.body);
    perform private.community_push(c.reply_to, private.game_name(c.user_id) || ' replied to you', c.body, '/community/post/' || p.id);
  end if;
  perform private.community_mentions(c.body, c.user_id, p.id, c.id, array[p.user_id, c.reply_to]);
end $$;

create or replace function public.community_decide(p_kind text, p_id text, p_ok boolean, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_post public.community_posts; v_c public.community_comments;
begin
  if p_kind = 'post' then
    update public.community_posts set status = case when p_ok then 'shown' else 'rejected' end, reason = case when p_ok then null else left(p_reason, 300) end, checked_at = now()
    where id::text = p_id and status = 'pending' returning * into v_post;
    if v_post.id is not null and p_ok then perform private.community_post_shown(v_post.id); end if;
    if v_post.id is not null and not p_ok then
      perform private.community_note(v_post.user_id, null, 'rejected', v_post.id, null, coalesce(nullif(p_reason, ''), 'It does not follow the community rules.'));
      perform private.community_push(v_post.user_id, 'Your post was not shared', coalesce(nullif(p_reason, ''), 'It does not follow the community rules.'), '/community/post/' || v_post.id);
    end if;
    return jsonb_build_object('ok', v_post.id is not null, 'ask_ai', coalesce(v_post.ask_ai, false) and p_ok);
  end if;
  update public.community_comments set status = case when p_ok then 'shown' else 'rejected' end, reason = case when p_ok then null else left(p_reason, 300) end, checked_at = now()
  where id::text = p_id and status = 'pending' returning * into v_c;
  if v_c.id is not null and p_ok then perform private.community_comment_shown(v_c.id); end if;
  return jsonb_build_object('ok', v_c.id is not null);
end $$;
revoke all on function public.community_decide(text, text, boolean, text) from public, anon, authenticated;

-- ---------- Posting ----------
create or replace function public.community_post_send(p_body text, p_images text[] default '{}', p_subject smallint default null, p_quote uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); s jsonb := private.community_settings(); v_id uuid; v_status text; v_body text := btrim(coalesce(p_body, ''));
  v_imgs text[] := coalesce(p_images, '{}'); i text; q public.community_posts;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  if coalesce((s ->> 'on')::boolean, true) is false then return jsonb_build_object('ok', false, 'error', 'off'); end if;
  if char_length(v_body) = 0 and cardinality(v_imgs) = 0 then return jsonb_build_object('ok', false, 'error', 'short'); end if;
  if char_length(v_body) > 500 then return jsonb_build_object('ok', false, 'error', 'long'); end if;
  if cardinality(v_imgs) > 4 then return jsonb_build_object('ok', false, 'error', 'image'); end if;
  foreach i in array v_imgs loop
    if i !~ ('^c/' || v_uid || '/[A-Za-z0-9._-]+$') then return jsonb_build_object('ok', false, 'error', 'image'); end if;
  end loop;
  if p_quote is not null then
    select * into q from public.community_posts where id = p_quote and status = 'shown';
    if not found or private.community_blocked(v_uid, q.user_id) then return jsonb_build_object('ok', false, 'error', 'quote_gone'); end if;
  end if;
  if (select count(*) from public.community_posts x where x.user_id = v_uid and x.created_at > now() - interval '1 day') >= coalesce((s ->> 'daily_posts')::int, 10) then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  perform private.community_profile_ensure(v_uid);
  v_status := case when coalesce((s ->> 'ai_check')::boolean, true) then 'pending' else 'shown' end;
  insert into public.community_posts (user_id, body, image_path, images, subject_id, status, ask_ai, quote_of, tags)
  values (v_uid, v_body, v_imgs[1], v_imgs, p_subject, v_status, v_body ~* '@solutiontee\M', p_quote, private.community_tags(v_body))
  returning id into v_id;
  if v_status = 'shown' then perform private.community_post_shown(v_id); end if;
  return jsonb_build_object('ok', true, 'id', v_id, 'status', v_status);
end $$;
grant execute on function public.community_post_send(text, text[], smallint, uuid) to authenticated;

-- D-151 entry point kept for older app versions.
create or replace function public.community_post_create(p_body text, p_image text default null, p_subject smallint default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); s jsonb := private.community_settings(); v_id uuid; v_status text;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  if coalesce((s ->> 'on')::boolean, true) is false then return jsonb_build_object('ok', false, 'error', 'off'); end if;
  if char_length(btrim(coalesce(p_body, ''))) < 3 then return jsonb_build_object('ok', false, 'error', 'short'); end if;
  if p_image is not null and p_image !~ ('^c/' || v_uid || '/[A-Za-z0-9._-]+$') then return jsonb_build_object('ok', false, 'error', 'image'); end if;
  if (select count(*) from public.community_posts x where x.user_id = v_uid and x.created_at > now() - interval '1 day') >= coalesce((s ->> 'daily_posts')::int, 10) then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  v_status := case when coalesce((s ->> 'ai_check')::boolean, true) then 'pending' else 'shown' end;
  insert into public.community_posts (user_id, body, image_path, images, subject_id, status, ask_ai, tags)
  values (v_uid, left(btrim(p_body), 2000), p_image, array_remove(array[p_image], null), p_subject, v_status, btrim(p_body) ~* '@solutiontee\M', private.community_tags(p_body))
  returning id into v_id;
  if v_status = 'shown' then perform private.community_post_shown(v_id); end if;
  return jsonb_build_object('ok', true, 'id', v_id, 'status', v_status);
end $$;

create or replace function public.community_post_delete(p_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_q uuid; v_found boolean;
begin
  delete from public.community_posts where id = p_id and user_id = (select auth.uid()) returning quote_of, true into v_q, v_found;
  if v_q is not null then perform private.community_recount_reposts(v_q); end if;
  return jsonb_build_object('ok', coalesce(v_found, false));
end $$;

create or replace function public.community_reply(p_post uuid, p_body text, p_parent bigint default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); s jsonb := private.community_settings(); p public.community_posts; par public.community_comments;
  v_id bigint; v_status text; v_parent bigint; v_to uuid; v_body text := btrim(coalesce(p_body, ''));
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into p from public.community_posts where id = p_post and status = 'shown';
  if not found or private.community_blocked(v_uid, p.user_id) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if char_length(v_body) < 1 or char_length(v_body) > 500 then return jsonb_build_object('ok', false, 'error', 'length'); end if;
  if p_parent is not null then
    select * into par from public.community_comments where id = p_parent and post_id = p_post and status = 'shown';
    if not found or (par.user_id is not null and private.community_blocked(v_uid, par.user_id)) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
    v_parent := coalesce(par.parent_id, par.id);
    v_to := par.user_id;
  end if;
  if (select count(*) from public.community_comments c where c.user_id = v_uid and c.created_at > now() - interval '1 day') >= coalesce((s ->> 'daily_comments')::int, 60) then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  perform private.community_profile_ensure(v_uid);
  v_status := case when coalesce((s ->> 'ai_check')::boolean, true) then 'pending' else 'shown' end;
  insert into public.community_comments (post_id, user_id, body, status, parent_id, reply_to) values (p_post, v_uid, v_body, v_status, v_parent, v_to) returning id into v_id;
  if v_status = 'shown' then perform private.community_comment_shown(v_id); end if;
  return jsonb_build_object('ok', true, 'id', v_id, 'status', v_status);
end $$;
grant execute on function public.community_reply(uuid, text, bigint) to authenticated;

create or replace function public.community_comment_delete(p_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_post uuid; v_parent bigint;
begin
  delete from public.community_comments where id = p_id and user_id = (select auth.uid()) returning post_id, parent_id into v_post, v_parent;
  if v_post is not null then
    update public.community_posts set comments_count = (select count(*) from public.community_comments x where x.post_id = v_post and x.status = 'shown') where id = v_post;
  end if;
  if v_parent is not null then
    update public.community_comments set replies_count = (select count(*) from public.community_comments x where x.parent_id = v_parent and x.status = 'shown') where id = v_parent;
  end if;
  return jsonb_build_object('ok', v_post is not null);
end $$;

-- ---------- Toggles ----------
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
  if v_liked then perform private.community_note(p.user_id, v_uid, 'like', p.id, null, p.body); end if;
  return jsonb_build_object('ok', true, 'liked', v_liked, 'likes', p.likes_count);
end $$;

create or replace function public.community_repost(p_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); p public.community_posts; v_on boolean; v_n integer;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into p from public.community_posts where id = p_id and status = 'shown' for update;
  if not found or private.community_blocked(v_uid, p.user_id) then return jsonb_build_object('ok', false); end if;
  delete from public.community_reposts where post_id = p_id and user_id = v_uid;
  if found then v_on := false; else insert into public.community_reposts (post_id, user_id) values (p_id, v_uid); v_on := true; end if;
  v_n := private.community_recount_reposts(p_id);
  if v_on then perform private.community_note(p.user_id, v_uid, 'repost', p.id, null, p.body); end if;
  return jsonb_build_object('ok', true, 'reposted', v_on, 'reposts', v_n);
end $$;
grant execute on function public.community_repost(uuid) to authenticated;

create or replace function public.community_bookmark(p_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); p public.community_posts; v_on boolean;
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  select * into p from public.community_posts where id = p_id;
  if not found or not private.community_visible(p, v_uid) then return jsonb_build_object('ok', false); end if;
  delete from public.community_bookmarks where post_id = p_id and user_id = v_uid;
  if found then v_on := false; else insert into public.community_bookmarks (post_id, user_id) values (p_id, v_uid); v_on := true; end if;
  return jsonb_build_object('ok', true, 'bookmarked', v_on);
end $$;
grant execute on function public.community_bookmark(uuid) to authenticated;

create or replace function public.community_comment_like(p_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); c public.community_comments; v_on boolean;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  select x.* into c from public.community_comments x join public.community_posts p on p.id = x.post_id
    where x.id = p_id and x.status = 'shown' and p.status = 'shown' and not private.community_blocked(v_uid, p.user_id) for update of x;
  if not found or (c.user_id is not null and private.community_blocked(v_uid, c.user_id)) then return jsonb_build_object('ok', false); end if;
  delete from public.community_comment_likes where comment_id = p_id and user_id = v_uid;
  if found then v_on := false; else insert into public.community_comment_likes (comment_id, user_id) values (p_id, v_uid); v_on := true; end if;
  update public.community_comments set likes_count = greatest(0, likes_count + case when v_on then 1 else -1 end) where id = p_id returning likes_count into c.likes_count;
  if v_on and c.user_id is not null then perform private.community_note(c.user_id, v_uid, 'comment_like', c.post_id, c.id, c.body); end if;
  return jsonb_build_object('ok', true, 'liked', v_on, 'likes', c.likes_count);
end $$;
grant execute on function public.community_comment_like(bigint) to authenticated;

create or replace function public.community_follow(p_user uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_on boolean;
begin
  if v_uid is null or p_user = v_uid or private.community_blocked(v_uid, p_user) then return jsonb_build_object('ok', false); end if;
  delete from public.community_follows where follower = v_uid and followee = p_user;
  if found then v_on := false;
  else
    insert into public.community_follows (follower, followee) values (v_uid, p_user); v_on := true;
    if not exists (select 1 from public.community_notes n where n.user_id = p_user and n.actor = v_uid and n.kind = 'follow' and n.created_at > now() - interval '1 day') then
      perform private.community_note(p_user, v_uid, 'follow', null, null, null);
      perform private.community_push(p_user, 'You have a new follower', private.game_name(v_uid) || ' follows your posts now.', '/community/user/' || v_uid);
    end if;
  end if;
  return jsonb_build_object('ok', true, 'following', v_on);
end $$;

