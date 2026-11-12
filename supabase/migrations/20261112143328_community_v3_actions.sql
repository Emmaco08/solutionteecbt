-- Community v3 (D-156), part 2: badges and pages in posts, posting with the after-check, take-downs, moderators,
-- SolutionTee AI in replies and on its own, pages.

create or replace function private.community_person_json(p_id uuid, p_me uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', pr.id, 'name', coalesce(nullif(btrim(pr.full_name), ''), 'Student'), 'handle', c.handle,
    'avatar_path', case when pr.id = p_me or coalesce(c.show_photo, true) then pr.avatar_path end, 'bio', c.bio,
    'badge', private.community_badge(pr.id),
    'following', exists (select 1 from public.community_follows f where f.follower = p_me and f.followee = pr.id),
    'follows_me', exists (select 1 from public.community_follows f where f.follower = pr.id and f.followee = p_me))
  from public.profiles pr left join public.community_profiles c on c.user_id = pr.id where pr.id = p_id;
$$;

create or replace function private.community_post_json(p public.community_posts, p_me uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', p.id, 'user_id', p.user_id,
    'name', coalesce(pg.name, nullif(btrim(pr.full_name), ''), 'Student'), 'handle', coalesce(pg.handle, c.handle),
    'avatar_path', case when pg.id is not null then pg.avatar_path when p.user_id = p_me or coalesce(c.show_photo, true) then pr.avatar_path end,
    'page_id', p.page_id, 'badge', case when pg.official then 'official' when pg.id is not null then 'page' else private.community_badge(p.user_id) end,
    'body', p.body, 'image_path', coalesce(p.images[1], p.image_path), 'images', p.images, 'subject_id', p.subject_id, 'status', p.status,
    'reason', case when p.user_id = p_me then p.reason end, 'likes', p.likes_count, 'comments', p.comments_count, 'reposts', p.reposts_count,
    'created_at', p.created_at, 'mine', p.user_id = p_me, 'ask_ai', p.ask_ai,
    'liked', exists (select 1 from public.community_likes l where l.post_id = p.id and l.user_id = p_me),
    'reposted', exists (select 1 from public.community_reposts r where r.post_id = p.id and r.user_id = p_me),
    'bookmarked', exists (select 1 from public.community_bookmarks b where b.post_id = p.id and b.user_id = p_me),
    'following', case when pg.id is not null then exists (select 1 from public.community_page_follows f where f.page_id = pg.id and f.user_id = p_me)
                 else exists (select 1 from public.community_follows f where f.follower = p_me and f.followee = p.user_id) end,
    'ai_answer', case when p.ask_ai then (select left(x.body, 280) from public.community_comments x where x.post_id = p.id and x.from_ai and x.status = 'shown' and x.parent_id is null order by x.id limit 1) end,
    'quote', case when p.quote_of is not null then private.community_quote_json(p.quote_of, p_me) end)
  from public.profiles pr left join public.community_profiles c on c.user_id = pr.id
  left join public.community_pages pg on pg.id = p.page_id
  where pr.id = p.user_id;
$$;

create or replace function private.community_quote_json(p_id uuid, p_me uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce((
    select jsonb_build_object('id', q.id, 'user_id', q.user_id, 'name', coalesce(pg.name, nullif(btrim(pr.full_name), ''), 'Student'), 'handle', coalesce(pg.handle, c.handle),
      'avatar_path', case when pg.id is not null then pg.avatar_path when q.user_id = p_me or coalesce(c.show_photo, true) then pr.avatar_path end,
      'badge', case when pg.official then 'official' when pg.id is not null then 'page' else private.community_badge(q.user_id) end,
      'body', left(q.body, 500), 'images', q.images, 'subject_id', q.subject_id, 'created_at', q.created_at)
    from public.community_posts q join public.profiles pr on pr.id = q.user_id left join public.community_profiles c on c.user_id = q.user_id
    left join public.community_pages pg on pg.id = q.page_id
    where q.id = p_id and (q.status = 'shown' or q.user_id = p_me) and not private.community_blocked(p_me, q.user_id)),
    jsonb_build_object('id', p_id, 'unavailable', true));
$$;

create or replace function private.community_comment_json(x public.community_comments, p_me uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', x.id, 'post_id', x.post_id, 'parent_id', x.parent_id, 'user_id', x.user_id, 'from_ai', x.from_ai,
    'name', case when x.from_ai then 'SolutionTee AI' else coalesce(nullif(btrim(pr.full_name), ''), 'Student') end,
    'handle', case when x.from_ai then 'solutiontee' else c.handle end,
    'avatar_path', case when x.user_id = p_me or coalesce(c.show_photo, true) then pr.avatar_path end,
    'badge', case when x.from_ai then 'ai' else private.community_badge(x.user_id) end,
    'body', x.body, 'status', x.status, 'reason', case when x.user_id = p_me then x.reason end, 'mine', x.user_id = p_me,
    'likes', x.likes_count, 'replies', x.replies_count, 'created_at', x.created_at,
    'liked', exists (select 1 from public.community_comment_likes l where l.comment_id = x.id and l.user_id = p_me),
    'reply_to_handle', (select rc.handle from public.community_profiles rc where rc.user_id = x.reply_to))
  from (select 1) one left join public.profiles pr on pr.id = x.user_id left join public.community_profiles c on c.user_id = x.user_id;
$$;

-- ---------- posting (shown at once, checked right after, unless the admin chose "check before") ----------
create or replace function private.community_new_status()
returns text language sql stable security definer set search_path = '' as $$
  select case when coalesce((private.community_settings() ->> 'ai_check')::boolean, true) is false then 'shown'
              when coalesce(private.community_settings() ->> 'moderation', 'after') = 'before' then 'pending' else 'shown' end;
$$;

create or replace function public.community_post_send(p_body text, p_images text[] default '{}', p_subject smallint default null, p_quote uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); s jsonb := private.community_settings(); v_id uuid; v_status text; v_body text := btrim(coalesce(p_body, ''));
  v_imgs text[] := coalesce(p_images, '{}'); i text; q public.community_posts; v_ban timestamptz;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  if coalesce((s ->> 'on')::boolean, true) is false then return jsonb_build_object('ok', false, 'error', 'off'); end if;
  v_ban := private.community_banned_until(v_uid);
  if v_ban is not null then return jsonb_build_object('ok', false, 'error', 'banned', 'until', v_ban); end if;
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
  if (select count(*) from public.community_posts x where x.user_id = v_uid and x.page_id is null and x.created_at > now() - interval '1 day') >= coalesce((s ->> 'daily_posts')::int, 10) then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  perform private.community_profile_ensure(v_uid);
  v_status := private.community_new_status();
  insert into public.community_posts (user_id, body, image_path, images, subject_id, status, ask_ai, quote_of, tags)
  values (v_uid, v_body, v_imgs[1], v_imgs, p_subject, v_status, v_body ~* '@solutiontee\M', p_quote, private.community_tags(v_body))
  returning id into v_id;
  if v_status = 'shown' then perform private.community_post_shown(v_id); end if;
  return jsonb_build_object('ok', true, 'id', v_id, 'status', v_status);
end $$;

create or replace function public.community_reply(p_post uuid, p_body text, p_parent bigint default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); s jsonb := private.community_settings(); p public.community_posts; par public.community_comments;
  v_id bigint; v_status text; v_parent bigint; v_to uuid; v_body text := btrim(coalesce(p_body, '')); v_ban timestamptz;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  v_ban := private.community_banned_until(v_uid);
  if v_ban is not null then return jsonb_build_object('ok', false, 'error', 'banned', 'until', v_ban); end if;
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
  v_status := private.community_new_status();
  insert into public.community_comments (post_id, user_id, body, status, parent_id, reply_to, ask_ai)
  values (p_post, v_uid, v_body, v_status, v_parent, v_to, v_body ~* '@solutiontee\M' or (par.from_ai is true))
  returning id into v_id;
  if v_status = 'shown' then perform private.community_comment_shown(v_id); end if;
  return jsonb_build_object('ok', true, 'id', v_id, 'status', v_status);
end $$;

-- ---------- the check (AI or staff): passes, or takes it down with a strike ----------
create or replace function public.community_decide(p_kind text, p_id text, p_ok boolean, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_post public.community_posts; v_c public.community_comments; v_was text;
  v_reason text := coalesce(nullif(btrim(p_reason), ''), 'It does not follow the community guidelines.');
begin
  if p_kind = 'post' then
    select * into v_post from public.community_posts where id::text = p_id and (status = 'pending' or (status = 'shown' and checked_at is null)) for update;
    if not found then return jsonb_build_object('ok', false); end if;
    v_was := v_post.status;
    update public.community_posts set status = case when p_ok then 'shown' else 'rejected' end, reason = case when p_ok then null else left(v_reason, 300) end,
      checked_at = now() where id = v_post.id;
    if p_ok then
      if v_was = 'pending' then perform private.community_post_shown(v_post.id); end if;
    else
      if v_post.quote_of is not null then perform private.community_recount_reposts(v_post.quote_of); end if;
      perform private.community_note(v_post.user_id, null, case when v_was = 'shown' then 'removed' else 'rejected' end, v_post.id, null, v_reason);
      perform private.community_push(v_post.user_id, case when v_was = 'shown' then 'Your post was removed' else 'Your post was not shared' end,
        v_reason || ' Please follow the community guidelines.', '/community/post/' || v_post.id);
      perform private.community_strike(v_post.user_id, 'post', v_post.id::text, v_reason, null);
    end if;
    return jsonb_build_object('ok', true, 'ask_ai', v_post.ask_ai and p_ok and not v_post.ai_answered);
  end if;
  select * into v_c from public.community_comments where id::text = p_id and (status = 'pending' or (status = 'shown' and checked_at is null)) for update;
  if not found then return jsonb_build_object('ok', false); end if;
  v_was := v_c.status;
  update public.community_comments set status = case when p_ok then 'shown' else 'rejected' end, reason = case when p_ok then null else left(v_reason, 300) end,
    checked_at = now() where id = v_c.id;
  if p_ok then
    if v_was = 'pending' then perform private.community_comment_shown(v_c.id); end if;
  else
    perform private.community_comment_recount(v_c.id);
    if v_c.user_id is not null then
      perform private.community_note(v_c.user_id, null, case when v_was = 'shown' then 'removed' else 'rejected' end, v_c.post_id, v_c.id, v_reason);
      perform private.community_push(v_c.user_id, case when v_was = 'shown' then 'Your reply was removed' else 'Your reply was not shared' end,
        v_reason || ' Please follow the community guidelines.', '/community/post/' || v_c.post_id);
      perform private.community_strike(v_c.user_id, 'comment', v_c.id::text, v_reason, null);
    end if;
  end if;
  return jsonb_build_object('ok', true, 'ask_ai', v_c.ask_ai and p_ok and not v_c.ai_answered);
end $$;
revoke all on function public.community_decide(text, text, boolean, text) from public, anon, authenticated;

create or replace function private.community_comment_recount(p_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare c public.community_comments;
begin
  select * into c from public.community_comments where id = p_id;
  update public.community_posts set comments_count = (select count(*) from public.community_comments x where x.post_id = c.post_id and x.status = 'shown') where id = c.post_id;
  if c.parent_id is not null then
    update public.community_comments set replies_count = (select count(*) from public.community_comments x where x.parent_id = c.parent_id and x.status = 'shown') where id = c.parent_id;
  end if;
end $$;

-- Moderators, admins and super admins take down any post or reply (the student is told why and gets a strike).
create or replace function public.community_mod_remove(p_kind text, p_id text, p_reason text default null, p_strike boolean default true)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_reason text := coalesce(nullif(btrim(p_reason), ''), 'It breaks the community guidelines.');
  v_post public.community_posts; v_c public.community_comments;
begin
  if v_uid is null or not private.community_is_mod(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  if p_kind = 'post' then
    update public.community_posts set status = 'rejected', reason = left('Removed by SolutionTee: ' || v_reason, 300), checked_at = now()
    where id::text = p_id and status <> 'rejected' returning * into v_post;
    if v_post.id is null then return jsonb_build_object('ok', false); end if;
    if v_post.quote_of is not null then perform private.community_recount_reposts(v_post.quote_of); end if;
    if v_post.user_id <> v_uid and v_post.page_id is null then
      perform private.community_note(v_post.user_id, null, 'removed', v_post.id, null, v_reason);
      perform private.community_push(v_post.user_id, 'Your post was removed', v_reason || ' Please follow the community guidelines.', '/community/post/' || v_post.id);
      if p_strike then perform private.community_strike(v_post.user_id, 'post', v_post.id::text, v_reason, v_uid); end if;
    end if;
  else
    update public.community_comments set status = 'rejected', reason = left('Removed by SolutionTee: ' || v_reason, 300), checked_at = now()
    where id::text = p_id and status <> 'rejected' returning * into v_c;
    if v_c.id is null then return jsonb_build_object('ok', false); end if;
    perform private.community_comment_recount(v_c.id);
    if v_c.user_id is not null and v_c.user_id <> v_uid then
      perform private.community_note(v_c.user_id, null, 'removed', v_c.post_id, v_c.id, v_reason);
      perform private.community_push(v_c.user_id, 'Your reply was removed', v_reason || ' Please follow the community guidelines.', '/community/post/' || v_c.post_id);
      if p_strike then perform private.community_strike(v_c.user_id, 'comment', v_c.id::text, v_reason, v_uid); end if;
    end if;
  end if;
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values (v_uid, 'community_remove', case when p_kind = 'post' then 'community_posts' else 'community_comments' end, p_id, jsonb_build_object('reason', v_reason));
  return jsonb_build_object('ok', true);
end $$;

-- ---------- SolutionTee AI ----------
-- A top-level answer to a post that tagged @solutiontee.
create or replace function public.community_ai_answer(p_post uuid, p_body text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.community_posts; v_lim integer := coalesce((private.community_settings() ->> 'ai_answers_daily')::int, 5); v_id bigint;
begin
  select * into p from public.community_posts where id = p_post and status = 'shown' and ask_ai and not ai_answered for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_open'); end if;
  update public.community_posts set ai_answered = true, ai_seen = true where id = p.id;
  if (select count(*) from public.community_comments c where c.from_ai and c.ai_kind in ('answer', 'reply') and c.reply_to = p.user_id and c.created_at > now() - interval '1 day') >= v_lim then
    return jsonb_build_object('ok', false, 'error', 'quota');
  end if;
  if p_body is null or char_length(btrim(p_body)) < 2 then return jsonb_build_object('ok', false, 'error', 'empty'); end if;
  insert into public.community_comments (post_id, user_id, from_ai, body, status, checked_at, ai_kind, reply_to)
  values (p.id, null, true, left(btrim(p_body), 3000), 'shown', now(), 'answer', p.user_id) returning id into v_id;
  perform private.community_comment_shown(v_id);
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.community_ai_answer(uuid, text) from public, anon, authenticated;

-- A reply in a thread to someone who tagged @solutiontee (or answered the AI).
create or replace function public.community_ai_reply(p_comment bigint, p_body text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.community_comments; v_lim integer := coalesce((private.community_settings() ->> 'ai_answers_daily')::int, 5) * 3; v_id bigint;
begin
  select * into c from public.community_comments where id = p_comment and status = 'shown' and ask_ai and not ai_answered for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_open'); end if;
  update public.community_comments set ai_answered = true where id = c.id;
  if (select count(*) from public.community_comments x where x.from_ai and x.ai_kind in ('answer', 'reply') and x.reply_to = c.user_id and x.created_at > now() - interval '1 day') >= v_lim then
    return jsonb_build_object('ok', false, 'error', 'quota');
  end if;
  if p_body is null or char_length(btrim(p_body)) < 2 then return jsonb_build_object('ok', false, 'error', 'empty'); end if;
  insert into public.community_comments (post_id, user_id, from_ai, body, status, checked_at, ai_kind, parent_id, reply_to)
  values (c.post_id, null, true, left(btrim(p_body), 3000), 'shown', now(), 'reply', coalesce(c.parent_id, c.id), c.user_id) returning id into v_id;
  perform private.community_comment_recount(v_id);
  perform private.community_note(c.user_id, null, 'ai', c.post_id, v_id, p_body);
  perform private.community_push(c.user_id, 'SolutionTee AI replied to you', p_body, '/community/post/' || c.post_id);
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.community_ai_reply(bigint, text) from public, anon, authenticated;

-- Posts SolutionTee AI may join on its own (a few a day, admin cap): fresh, checked, not already answered.
create or replace function public.community_ai_candidates(p_limit integer default 2)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare s jsonb := private.community_settings(); v_left integer;
begin
  if coalesce((s ->> 'ai_auto')::boolean, true) is false then return '[]'::jsonb; end if;
  v_left := coalesce((s ->> 'ai_auto_daily')::int, 15)
    - (select count(*) from public.community_comments c where c.from_ai and c.ai_kind = 'auto' and c.created_at > now() - interval '1 day');
  if v_left <= 0 then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'body', x.body, 'name', split_part(coalesce(nullif(btrim(pr.full_name), ''), 'Student'), ' ', 1),
      'subject', (select s2.name from public.subjects s2 where s2.id = x.subject_id),
      'replies', (select coalesce(jsonb_agg(left(r.body, 200) order by r.created_at), '[]'::jsonb) from (select body, created_at from public.community_comments r
                  where r.post_id = x.id and r.status = 'shown' order by r.created_at limit 5) r)))
    from (select * from public.community_posts p
          where p.status = 'shown' and p.checked_at is not null and not p.ask_ai and not p.ai_seen and p.page_id is null
            and p.created_at > now() - interval '12 hours' and p.created_at < now() - interval '3 minutes' and char_length(p.body) >= 12
            and not exists (select 1 from public.community_comments c where c.post_id = p.id and c.from_ai)
          order by (p.body like '%?%') desc, p.comments_count, random() limit least(greatest(p_limit, 0), v_left)) x
    join public.profiles pr on pr.id = x.user_id), '[]'::jsonb);
end $$;
revoke all on function public.community_ai_candidates(integer) from public, anon, authenticated;

create or replace function public.community_ai_auto(p_post uuid, p_body text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.community_posts; v_id bigint;
begin
  update public.community_posts set ai_seen = true where id = p_post and status = 'shown' returning * into p;
  if p.id is null or p_body is null or char_length(btrim(p_body)) < 2 or upper(btrim(p_body)) like 'SKIP%' then return jsonb_build_object('ok', false); end if;
  if exists (select 1 from public.community_comments c where c.post_id = p.id and c.from_ai) then return jsonb_build_object('ok', false); end if;
  insert into public.community_comments (post_id, user_id, from_ai, body, status, checked_at, ai_kind, reply_to)
  values (p.id, null, true, left(btrim(p_body), 1500), 'shown', now(), 'auto', p.user_id) returning id into v_id;
  perform private.community_comment_recount(v_id);
  perform private.community_note(p.user_id, null, 'ai', p.id, v_id, p_body);
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.community_ai_auto(uuid, text) from public, anon, authenticated;

-- What the checker works on: waiting or just-posted (unchecked) posts and replies, @solutiontee in posts and replies,
-- profile changes. Picture posts are included (the checker reads the pictures with the cron token).
create or replace function public.community_pending(p_limit integer default 20)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'posts', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'user_id', p.user_id, 'body', p.body, 'images', p.images,
        'quote', (select left(q.body, 400) from public.community_posts q where q.id = p.quote_of)))
      from (select * from public.community_posts x where (x.status = 'pending' or (x.status = 'shown' and x.checked_at is null)) and x.page_id is null
            and x.created_at < now() - interval '40 seconds' and x.created_at > now() - interval '1 day' order by x.created_at limit p_limit) p), '[]'::jsonb),
    'comments', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'user_id', c.user_id, 'body', c.body, 'post', (select left(p.body, 600) from public.community_posts p where p.id = c.post_id)))
      from (select * from public.community_comments x where (x.status = 'pending' or (x.status = 'shown' and x.checked_at is null)) and not x.from_ai
            and x.created_at < now() - interval '40 seconds' and x.created_at > now() - interval '1 day' order by x.created_at limit p_limit) c), '[]'::jsonb),
    'answers', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'user_id', p.user_id, 'body', p.body,
        'name', (select split_part(coalesce(nullif(btrim(pr.full_name), ''), 'Student'), ' ', 1) from public.profiles pr where pr.id = p.user_id)))
      from (select * from public.community_posts x where x.status = 'shown' and x.checked_at is not null and x.ask_ai and not x.ai_answered
            and x.created_at > now() - interval '1 day' order by x.created_at limit 5) p), '[]'::jsonb),
    'replies', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'body', c.body,
        'name', (select split_part(coalesce(nullif(btrim(pr.full_name), ''), 'Student'), ' ', 1) from public.profiles pr where pr.id = c.user_id),
        'post', (select left(p.body, 600) from public.community_posts p where p.id = c.post_id),
        'thread', (select coalesce(jsonb_agg(case when t.from_ai then 'SolutionTee AI: ' else 'Student: ' end || left(t.body, 300) order by t.created_at), '[]'::jsonb)
                   from (select * from public.community_comments t where t.status = 'shown' and t.id <> c.id
                         and (t.id = coalesce(c.parent_id, c.id) or t.parent_id = coalesce(c.parent_id, c.id)) order by t.created_at desc limit 6) t)))
      from (select * from public.community_comments x where x.status = 'shown' and x.checked_at is not null and x.ask_ai and not x.ai_answered
            and x.created_at > now() - interval '1 day' order by x.created_at limit 5) c), '[]'::jsonb),
    'profiles', coalesce((select jsonb_agg(jsonb_build_object('user_id', c.user_id, 'handle', c.pending_handle, 'bio', c.pending_bio))
      from (select * from public.community_profiles x where x.pending_at is not null and x.pending_at < now() - interval '1 minute'
            and x.pending_at > now() - interval '3 days' order by x.pending_at limit p_limit) c), '[]'::jsonb));
$$;
revoke all on function public.community_pending(integer) from public, anon, authenticated;

-- ---------- pages ----------
create or replace function public.community_my_pages()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', pg.id, 'handle', pg.handle, 'name', pg.name, 'official', pg.official, 'avatar_path', pg.avatar_path) order by pg.official desc, pg.name), '[]'::jsonb)
  from public.community_pages pg where private.community_can_page((select auth.uid()), pg.id);
$$;

create or replace function public.community_page_save(p_id uuid, p_handle text, p_name text, p_bio text default null, p_header smallint default 0, p_avatar text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); h text := lower(ltrim(btrim(coalesce(p_handle, '')), '@')); v_id uuid; pg public.community_pages;
begin
  if v_uid is null or not exists (select 1 from public.staff s where s.user_id = v_uid and s.role <> 'tutor') then raise exception 'not allowed' using errcode = '42501'; end if;
  if h !~ '^[a-z0-9][a-z0-9_.]{1,18}[a-z0-9_]$' then return jsonb_build_object('ok', false, 'error', 'format'); end if;
  if char_length(btrim(coalesce(p_name, ''))) < 2 then return jsonb_build_object('ok', false, 'error', 'name'); end if;
  if p_id is null then
    if exists (select 1 from public.community_profiles c where c.handle = h or c.pending_handle = h) or exists (select 1 from public.community_pages g where g.handle = h) then
      return jsonb_build_object('ok', false, 'error', 'taken');
    end if;
    insert into public.community_pages (handle, name, bio, header, avatar_path, created_by) values (h, btrim(p_name), nullif(btrim(coalesce(p_bio, '')), ''), coalesce(p_header, 0), p_avatar, v_uid)
    returning id into v_id;
    insert into public.community_page_members (page_id, user_id, role) values (v_id, v_uid, 'owner');
    return jsonb_build_object('ok', true, 'id', v_id);
  end if;
  select * into pg from public.community_pages where id = p_id;
  if not found or not private.community_can_page(v_uid, p_id) then raise exception 'not allowed' using errcode = '42501'; end if;
  if h <> pg.handle and (exists (select 1 from public.community_profiles c where c.handle = h or c.pending_handle = h) or exists (select 1 from public.community_pages g where g.handle = h)) then
    return jsonb_build_object('ok', false, 'error', 'taken');
  end if;
  update public.community_pages set handle = case when official then handle else h end, name = btrim(p_name), bio = nullif(btrim(coalesce(p_bio, '')), ''),
    header = coalesce(p_header, header), avatar_path = coalesce(p_avatar, avatar_path) where id = p_id;
  return jsonb_build_object('ok', true, 'id', p_id);
end $$;

create or replace function public.community_page_post(p_page uuid, p_body text, p_images text[] default '{}', p_subject smallint default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_id uuid; v_body text := btrim(coalesce(p_body, '')); pg public.community_pages; r record; i text;
begin
  if v_uid is null or not private.community_can_page(v_uid, p_page) then raise exception 'not allowed' using errcode = '42501'; end if;
  if char_length(v_body) = 0 and cardinality(coalesce(p_images, '{}')) = 0 then return jsonb_build_object('ok', false, 'error', 'short'); end if;
  if char_length(v_body) > 1000 or cardinality(coalesce(p_images, '{}')) > 4 then return jsonb_build_object('ok', false, 'error', 'long'); end if;
  foreach i in array coalesce(p_images, '{}') loop
    if i !~ ('^c/' || v_uid || '/[A-Za-z0-9._-]+$') then return jsonb_build_object('ok', false, 'error', 'image'); end if;
  end loop;
  select * into pg from public.community_pages where id = p_page;
  perform private.community_profile_ensure(v_uid);
  insert into public.community_posts (user_id, page_id, body, image_path, images, subject_id, status, checked_at, ask_ai, ai_seen, tags)
  values (v_uid, p_page, v_body, p_images[1], coalesce(p_images, '{}'), p_subject, 'shown', now(), false, true, private.community_tags(v_body)) returning id into v_id;
  for r in select f.user_id from public.community_page_follows f where f.page_id = p_page and f.user_id <> v_uid limit 5000 loop
    perform private.community_note(r.user_id, null, 'page', v_id, null, pg.name || ': ' || v_body);
    perform private.community_push(r.user_id, pg.name || ' posted', v_body, '/community/post/' || v_id);
  end loop;
  return jsonb_build_object('ok', true, 'id', v_id, 'status', 'shown');
end $$;

create or replace function public.community_page_follow(p_page uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_on boolean;
begin
  if v_uid is null or not exists (select 1 from public.community_pages where id = p_page) then return jsonb_build_object('ok', false); end if;
  delete from public.community_page_follows where page_id = p_page and user_id = v_uid;
  if found then v_on := false; else insert into public.community_page_follows (page_id, user_id) values (p_page, v_uid); v_on := true; end if;
  return jsonb_build_object('ok', true, 'following', v_on);
end $$;

create or replace function public.community_page_members_save(p_page uuid, p_handle text, p_add boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_user uuid;
begin
  if v_uid is null or not private.community_can_page(v_uid, p_page) then raise exception 'not allowed' using errcode = '42501'; end if;
  select c.user_id into v_user from public.community_profiles c where c.handle = lower(ltrim(btrim(p_handle), '@'));
  if v_user is null or not exists (select 1 from public.staff s where s.user_id = v_user and s.role <> 'tutor') then
    return jsonb_build_object('ok', false, 'error', 'not_staff');
  end if;
  if p_add then insert into public.community_page_members (page_id, user_id) values (p_page, v_user) on conflict do nothing;
  else delete from public.community_page_members where page_id = p_page and user_id = v_user and role <> 'owner'; end if;
  return jsonb_build_object('ok', true);
end $$;

-- Staff choose Community moderators by @handle (super admins and admins).
create or replace function public.community_set_moderator(p_handle text, p_on boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null or not exists (select 1 from public.staff s where s.user_id = v_uid and s.role in ('super_admin', 'admin')) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.community_profiles set role = case when p_on then 'moderator' else 'student' end where handle = lower(ltrim(btrim(p_handle), '@'));
  return jsonb_build_object('ok', found);
end $$;

-- "Not interested in this post".
create or replace function public.community_hide(p_post uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then return jsonb_build_object('ok', false); end if;
  insert into public.community_hidden (user_id, post_id, author) select v_uid, p.id, p.user_id from public.community_posts p where p.id = p_post on conflict do nothing;
  return jsonb_build_object('ok', true);
end $$;

-- The student's push settings.
create or replace function public.community_notify_save(p_notify jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v jsonb := '{}';  k text;
begin
  if v_uid is null then return jsonb_build_object('ok', false); end if;
  perform private.community_profile_ensure(v_uid);
  foreach k in array array['replies', 'mentions', 'follows', 'ai', 'posts', 'milestones', 'digest', 'likes'] loop
    if p_notify ? k then v := v || jsonb_build_object(k, (p_notify ->> k)::boolean); end if;
  end loop;
  update public.community_profiles set notify = notify || v where user_id = v_uid;
  return jsonb_build_object('ok', true);
end $$;

revoke execute on function public.community_mod_remove(text, text, text, boolean), public.community_my_pages(), public.community_page_save(uuid, text, text, text, smallint, text),
  public.community_page_post(uuid, text, text[], smallint), public.community_page_follow(uuid), public.community_page_members_save(uuid, text, boolean),
  public.community_set_moderator(text, boolean), public.community_hide(uuid), public.community_notify_save(jsonb) from public, anon;
grant execute on function public.community_mod_remove(text, text, text, boolean), public.community_my_pages(), public.community_page_save(uuid, text, text, text, smallint, text),
  public.community_page_post(uuid, text, text[], smallint), public.community_page_follow(uuid), public.community_page_members_save(uuid, text, boolean),
  public.community_set_moderator(text, boolean), public.community_hide(uuid), public.community_notify_save(jsonb) to authenticated;
