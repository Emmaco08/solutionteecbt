-- Community (C15, D-151): education-only posts (text, maths, one picture), comments, likes, follows, a "For you" feed.
-- Every post and comment is checked by the AI (Edge Function `community`) before anyone else sees it; the author sees
-- their own while it waits. "@solutiontee" in a post asks the AI for an answer (a few a day). Reports, blocks and
-- staff moderation. Students reach all of it through the functions below only.
insert into public.app_settings (key, value) values ('community', jsonb_build_object(
  'on', true, 'ai_check', true, 'daily_posts', 10, 'daily_comments', 60, 'ai_answers_daily', 5, 'report_hide', 3))
on conflict (key) do nothing;

alter table public.notifications drop constraint notifications_source_check;
alter table public.notifications add constraint notifications_source_check check (source = any (array['admin','news','year','streak','premium',
  'challenge','referral','ban','plan','nudge','ai','leaderboard','badge','game','community']));

create table public.community_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 3 and 2000),
  image_path text check (image_path is null or image_path ~ '^c/[0-9a-f-]{36}/[A-Za-z0-9._-]+$'),
  subject_id smallint references public.subjects(id),
  status text not null default 'pending' check (status in ('pending', 'shown', 'rejected', 'hidden')),
  reason text,
  likes_count integer not null default 0,
  comments_count integer not null default 0,
  ask_ai boolean not null default false,
  ai_answered boolean not null default false,
  checked_at timestamptz,
  created_at timestamptz not null default now()
);
create index community_posts_feed_idx on public.community_posts (status, created_at desc);
create index community_posts_user_idx on public.community_posts (user_id, created_at desc);
create table public.community_comments (
  id bigint generated always as identity primary key,
  post_id uuid not null references public.community_posts(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  from_ai boolean not null default false,
  body text not null check (char_length(btrim(body)) between 1 and 3000),
  status text not null default 'pending' check (status in ('pending', 'shown', 'rejected', 'hidden')),
  reason text,
  checked_at timestamptz,
  created_at timestamptz not null default now(),
  check (from_ai or user_id is not null)
);
create index community_comments_post_idx on public.community_comments (post_id, created_at);
create table public.community_likes (
  post_id uuid not null references public.community_posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create table public.community_follows (
  follower uuid not null references public.profiles(id) on delete cascade,
  followee uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower, followee),
  check (follower <> followee)
);
create index community_follows_followee_idx on public.community_follows (followee);
create table public.community_blocks (
  blocker uuid not null references public.profiles(id) on delete cascade,
  blocked uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);
create table public.community_reports (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('post', 'comment')),
  ref text not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reason text check (char_length(reason) <= 300),
  created_at timestamptz not null default now(),
  unique (kind, ref, user_id)
);

alter table public.community_posts enable row level security;
alter table public.community_comments enable row level security;
alter table public.community_likes enable row level security;
alter table public.community_follows enable row level security;
alter table public.community_blocks enable row level security;
alter table public.community_reports enable row level security;
create policy "staff read" on public.community_posts for select to authenticated using (private.is_staff());
create policy "staff moderate" on public.community_posts for update to authenticated using (private.can_edit(array['super_admin','admin']::public.staff_role[])) with check (private.can_edit(array['super_admin','admin']::public.staff_role[]));
create policy "staff delete" on public.community_posts for delete to authenticated using (private.can_edit(array['super_admin','admin']::public.staff_role[]));
create policy "staff read" on public.community_comments for select to authenticated using (private.is_staff());
create policy "staff moderate" on public.community_comments for update to authenticated using (private.can_edit(array['super_admin','admin']::public.staff_role[])) with check (private.can_edit(array['super_admin','admin']::public.staff_role[]));
create policy "staff delete" on public.community_comments for delete to authenticated using (private.can_edit(array['super_admin','admin']::public.staff_role[]));
create policy "staff read" on public.community_reports for select to authenticated using (private.is_staff());
grant select, update (status, reason, checked_at), delete on public.community_posts, public.community_comments to authenticated;
grant select on public.community_reports to authenticated;
create trigger community_posts_audit after update or delete on public.community_posts for each row execute function private.audit_row();

create or replace function private.community_settings() returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce((select value from public.app_settings where key = 'community'), '{}'::jsonb);
$$;

-- True when either student has blocked the other.
create or replace function private.community_blocked(a uuid, b uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.community_blocks x where (x.blocker = a and x.blocked = b) or (x.blocker = b and x.blocked = a));
$$;

create or replace function private.community_post_json(p public.community_posts, p_me uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', p.id, 'user_id', p.user_id, 'name', coalesce(nullif(btrim(pr.full_name), ''), 'Student'), 'avatar_path', pr.avatar_path,
    'body', p.body, 'image_path', p.image_path, 'subject_id', p.subject_id, 'status', p.status,
    'reason', case when p.user_id = p_me then p.reason end, 'likes', p.likes_count, 'comments', p.comments_count, 'created_at', p.created_at,
    'mine', p.user_id = p_me, 'liked', exists (select 1 from public.community_likes l where l.post_id = p.id and l.user_id = p_me),
    'following', exists (select 1 from public.community_follows f where f.follower = p_me and f.followee = p.user_id))
  from public.profiles pr where pr.id = p.user_id;
$$;

-- Feed: for_you (followed people and my subjects first, then popular and new), following, mine, or one subject.
create or replace function public.community_feed(p_tab text default 'for_you', p_subject smallint default null, p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_subjects smallint[];
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  select array_agg(s.id) into v_subjects from public.profiles pr join public.subjects s
    on s.code = any (coalesce(pr.jamb_subjects, '{}')) or s.name = any (coalesce(pr.jamb_subjects, '{}')) where pr.id = v_uid;
  return coalesce((
    select jsonb_agg(private.community_post_json(p, v_uid) order by t.rank_score desc, p.created_at desc)
    from (
      select x.id, case when p_tab = 'for_you' then
          (case when exists (select 1 from public.community_follows f where f.follower = v_uid and f.followee = x.user_id) then 3 else 0 end)
          + (case when x.subject_id = any (coalesce(v_subjects, '{}')) then 2 else 0 end)
          + ln(1 + x.likes_count + x.comments_count) - extract(epoch from (now() - x.created_at)) / 86400.0
        else 0 end as rank_score, x.created_at
      from public.community_posts x
      where (x.status = 'shown' or (x.user_id = v_uid and x.status in ('pending', 'rejected')))
        and not private.community_blocked(v_uid, x.user_id)
        and case p_tab
          when 'following' then exists (select 1 from public.community_follows f where f.follower = v_uid and f.followee = x.user_id)
          when 'mine' then x.user_id = v_uid
          else x.created_at > now() - interval '60 days' end
        and (p_subject is null or x.subject_id = p_subject)
      order by 2 desc, x.created_at desc
      offset greatest(p_offset, 0) limit 20) t
    join public.community_posts p on p.id = t.id), '[]'::jsonb);
end $$;

create or replace function public.community_post_get(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); p public.community_posts;
begin
  select * into p from public.community_posts where id = p_id;
  if not found or (p.status <> 'shown' and p.user_id <> v_uid) or private.community_blocked(v_uid, p.user_id) then
    return jsonb_build_object('status', 'not_found');
  end if;
  return private.community_post_json(p, v_uid) || jsonb_build_object('comment_list', coalesce((
    select jsonb_agg(jsonb_build_object('id', c.id, 'user_id', c.user_id, 'from_ai', c.from_ai,
      'name', case when c.from_ai then 'SolutionTee AI' else coalesce(nullif(btrim(pr.full_name), ''), 'Student') end, 'avatar_path', pr.avatar_path,
      'body', c.body, 'status', c.status, 'reason', case when c.user_id = v_uid then c.reason end, 'mine', c.user_id = v_uid, 'created_at', c.created_at)
      order by c.created_at)
    from public.community_comments c left join public.profiles pr on pr.id = c.user_id
    where c.post_id = p.id and (c.status = 'shown' or (c.user_id = v_uid and c.status in ('pending', 'rejected')))
      and (c.user_id is null or not private.community_blocked(v_uid, c.user_id))), '[]'::jsonb));
end $$;

create or replace function public.community_post_create(p_body text, p_image text default null, p_subject smallint default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
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
  insert into public.community_posts (user_id, body, image_path, subject_id, status, ask_ai)
  values (v_uid, left(btrim(p_body), 2000), p_image, p_subject, v_status, btrim(p_body) ~* '@solutiontee\M')
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id, 'status', v_status);
end $$;

create or replace function public.community_post_delete(p_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.community_posts where id = p_id and user_id = (select auth.uid());
  return jsonb_build_object('ok', found);
end $$;

create or replace function public.community_like(p_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); p public.community_posts; v_liked boolean;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into p from public.community_posts where id = p_id and status = 'shown' for update;
  if not found or private.community_blocked(v_uid, p.user_id) then return jsonb_build_object('ok', false); end if;
  delete from public.community_likes where post_id = p_id and user_id = v_uid;
  if found then v_liked := false; else insert into public.community_likes (post_id, user_id) values (p_id, v_uid); v_liked := true; end if;
  update public.community_posts set likes_count = greatest(0, likes_count + case when v_liked then 1 else -1 end) where id = p_id returning likes_count into p.likes_count;
  return jsonb_build_object('ok', true, 'liked', v_liked, 'likes', p.likes_count);
end $$;

-- A comment became visible: count it and tell the post's author.
create or replace function private.community_comment_shown(p_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare c public.community_comments; p public.community_posts;
begin
  select * into c from public.community_comments where id = p_id;
  select * into p from public.community_posts where id = c.post_id;
  update public.community_posts set comments_count = (select count(*) from public.community_comments x where x.post_id = p.id and x.status = 'shown') where id = p.id;
  if c.user_id is distinct from p.user_id then
    insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
    values ('account'::public.notif_topic, case when c.from_ai then 'SolutionTee AI answered your post' else 'New comment on your post' end,
            left(c.body, 140), 'user', p.user_id, 'scheduled', now(), 'community', jsonb_build_object('type', 'screen', 'target', '/community/post/' || p.id));
  end if;
end $$;

create or replace function public.community_comment_add(p_post uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); s jsonb := private.community_settings(); p public.community_posts; v_id bigint; v_status text;
begin
  if v_uid is null or private.is_banned(v_uid) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into p from public.community_posts where id = p_post and status = 'shown';
  if not found or private.community_blocked(v_uid, p.user_id) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if char_length(btrim(coalesce(p_body, ''))) < 1 or char_length(p_body) > 1000 then return jsonb_build_object('ok', false, 'error', 'length'); end if;
  if (select count(*) from public.community_comments c where c.user_id = v_uid and c.created_at > now() - interval '1 day') >= coalesce((s ->> 'daily_comments')::int, 60) then
    return jsonb_build_object('ok', false, 'error', 'too_many');
  end if;
  v_status := case when coalesce((s ->> 'ai_check')::boolean, true) then 'pending' else 'shown' end;
  insert into public.community_comments (post_id, user_id, body, status) values (p_post, v_uid, btrim(p_body), v_status) returning id into v_id;
  if v_status = 'shown' then perform private.community_comment_shown(v_id); end if;
  return jsonb_build_object('ok', true, 'id', v_id, 'status', v_status);
end $$;

create or replace function public.community_comment_delete(p_id bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_post uuid;
begin
  delete from public.community_comments where id = p_id and user_id = (select auth.uid()) returning post_id into v_post;
  if v_post is not null then
    update public.community_posts set comments_count = (select count(*) from public.community_comments x where x.post_id = v_post and x.status = 'shown') where id = v_post;
  end if;
  return jsonb_build_object('ok', v_post is not null);
end $$;

create or replace function public.community_follow(p_user uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_on boolean;
begin
  if v_uid is null or p_user = v_uid or private.community_blocked(v_uid, p_user) then return jsonb_build_object('ok', false); end if;
  delete from public.community_follows where follower = v_uid and followee = p_user;
  if found then v_on := false;
  else
    insert into public.community_follows (follower, followee) values (v_uid, p_user); v_on := true;
    -- One "new follower" note a day per pair at most.
    if not exists (select 1 from public.notifications n where n.user_id = p_user and n.source = 'community' and n.title = 'You have a new follower'
                   and n.created_at > now() - interval '1 day' and n.link ->> 'target' = '/community/user/' || v_uid) then
      insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
      values ('account'::public.notif_topic, 'You have a new follower', private.game_name(v_uid) || ' follows your posts now.', 'user', p_user, 'scheduled', now(), 'community',
              jsonb_build_object('type', 'screen', 'target', '/community/user/' || v_uid));
    end if;
  end if;
  return jsonb_build_object('ok', true, 'following', v_on);
end $$;

create or replace function public.community_block(p_user uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_on boolean;
begin
  if v_uid is null or p_user = v_uid then return jsonb_build_object('ok', false); end if;
  delete from public.community_blocks where blocker = v_uid and blocked = p_user;
  if found then v_on := false;
  else
    insert into public.community_blocks (blocker, blocked) values (v_uid, p_user); v_on := true;
    delete from public.community_follows where (follower = v_uid and followee = p_user) or (follower = p_user and followee = v_uid);
  end if;
  return jsonb_build_object('ok', true, 'blocked', v_on);
end $$;

-- A report; enough reports hide the post or comment until staff look at it.
create or replace function public.community_report(p_kind text, p_ref text, p_reason text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_n integer; v_lim integer := coalesce((private.community_settings() ->> 'report_hide')::int, 3);
begin
  if v_uid is null or p_kind not in ('post', 'comment') then return jsonb_build_object('ok', false); end if;
  insert into public.community_reports (kind, ref, user_id, reason) values (p_kind, p_ref, v_uid, left(p_reason, 300)) on conflict do nothing;
  select count(*) into v_n from public.community_reports r where r.kind = p_kind and r.ref = p_ref;
  if v_n >= v_lim then
    if p_kind = 'post' then update public.community_posts set status = 'hidden', reason = 'Hidden after reports' where id::text = p_ref and status = 'shown';
    else
      update public.community_comments set status = 'hidden', reason = 'Hidden after reports' where id::text = p_ref and status = 'shown';
      update public.community_posts p set comments_count = (select count(*) from public.community_comments x where x.post_id = p.id and x.status = 'shown')
      where p.id = (select c.post_id from public.community_comments c where c.id::text = p_ref);
    end if;
  end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.community_profile(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  return (select jsonb_build_object('id', pr.id, 'name', coalesce(nullif(btrim(pr.full_name), ''), 'Student'), 'avatar_path', pr.avatar_path,
    'me', pr.id = v_uid,
    'posts', (select count(*) from public.community_posts p where p.user_id = pr.id and p.status = 'shown'),
    'followers', (select count(*) from public.community_follows f where f.followee = pr.id),
    'following_count', (select count(*) from public.community_follows f where f.follower = pr.id),
    'following', exists (select 1 from public.community_follows f where f.follower = v_uid and f.followee = pr.id),
    'blocked', exists (select 1 from public.community_blocks b where b.blocker = v_uid and b.blocked = pr.id),
    'list', case when private.community_blocked(v_uid, pr.id) and pr.id <> v_uid then '[]'::jsonb else coalesce((
      select jsonb_agg(private.community_post_json(p, v_uid) order by p.created_at desc)
      from (select * from public.community_posts x where x.user_id = pr.id and x.status = 'shown' order by x.created_at desc limit 20) p), '[]'::jsonb) end)
    from public.profiles pr where pr.id = p_user);
end $$;

-- For the Edge Function (service role): what to check, saving the AI's decision, and the @solutiontee quota.
create or replace function public.community_pending(p_limit integer default 20) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'posts', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'user_id', p.user_id, 'body', p.body, 'image_path', p.image_path))
      from (select * from public.community_posts x where x.status = 'pending' and x.image_path is null and x.created_at < now() - interval '1 minute'
            and x.created_at > now() - interval '1 day' order by x.created_at limit p_limit) p), '[]'::jsonb),
    'comments', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'user_id', c.user_id, 'body', c.body, 'post', (select left(p.body, 600) from public.community_posts p where p.id = c.post_id)))
      from (select * from public.community_comments x where x.status = 'pending' and x.created_at < now() - interval '1 minute'
            and x.created_at > now() - interval '1 day' order by x.created_at limit p_limit) c), '[]'::jsonb),
    'answers', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'user_id', p.user_id, 'body', p.body))
      from (select * from public.community_posts x where x.status = 'shown' and x.ask_ai and not x.ai_answered and x.created_at > now() - interval '1 day'
            order by x.created_at limit 5) p), '[]'::jsonb));
$$;

create or replace function public.community_decide(p_kind text, p_id text, p_ok boolean, p_reason text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_post public.community_posts; v_c public.community_comments;
begin
  if p_kind = 'post' then
    update public.community_posts set status = case when p_ok then 'shown' else 'rejected' end, reason = case when p_ok then null else left(p_reason, 300) end, checked_at = now()
    where id::text = p_id and status = 'pending' returning * into v_post;
    if v_post.id is not null and not p_ok then
      insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
      values ('account'::public.notif_topic, 'Your post was not shared', left(coalesce(nullif(p_reason, ''), 'It does not follow the community rules.'), 200), 'user', v_post.user_id,
              'scheduled', now(), 'community', jsonb_build_object('type', 'screen', 'target', '/community'));
    end if;
    return jsonb_build_object('ok', v_post.id is not null, 'ask_ai', coalesce(v_post.ask_ai, false) and p_ok);
  end if;
  update public.community_comments set status = case when p_ok then 'shown' else 'rejected' end, reason = case when p_ok then null else left(p_reason, 300) end, checked_at = now()
  where id::text = p_id and status = 'pending' returning * into v_c;
  if v_c.id is not null and p_ok then perform private.community_comment_shown(v_c.id); end if;
  return jsonb_build_object('ok', v_c.id is not null);
end $$;

-- Takes one AI answer from the author's daily allowance and adds it as a comment (once per post).
create or replace function public.community_ai_answer(p_post uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p public.community_posts; v_lim integer := coalesce((private.community_settings() ->> 'ai_answers_daily')::int, 5); v_id bigint;
begin
  select * into p from public.community_posts where id = p_post and status = 'shown' and ask_ai and not ai_answered for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_open'); end if;
  if (select count(*) from public.community_comments c join public.community_posts x on x.id = c.post_id
      where c.from_ai and x.user_id = p.user_id and c.created_at > now() - interval '1 day') >= v_lim then
    update public.community_posts set ai_answered = true where id = p.id;
    return jsonb_build_object('ok', false, 'error', 'quota');
  end if;
  update public.community_posts set ai_answered = true where id = p.id;
  if p_body is null or char_length(btrim(p_body)) < 2 then return jsonb_build_object('ok', false, 'error', 'empty'); end if;
  insert into public.community_comments (post_id, user_id, from_ai, body, status, checked_at) values (p.id, null, true, left(btrim(p_body), 3000), 'shown', now()) returning id into v_id;
  perform private.community_comment_shown(v_id);
  return jsonb_build_object('ok', true);
end $$;

-- Who may see a community picture (website signing route): the author, staff, or anyone when the post is shown.
create or replace function public.can_view_community_image(p_key text) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.is_staff() or exists (select 1 from public.community_posts p where p.image_path = p_key
    and (p.user_id = (select auth.uid()) or (p.status = 'shown' and not private.community_blocked((select auth.uid()), p.user_id))));
$$;

-- Admin queue numbers.
create or replace function public.admin_community_counts() returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when not private.is_staff() then null else jsonb_build_object(
    'pending', (select count(*) from public.community_posts where status = 'pending') + (select count(*) from public.community_comments where status = 'pending'),
    'hidden', (select count(*) from public.community_posts where status = 'hidden') + (select count(*) from public.community_comments where status = 'hidden'),
    'rejected_week', (select count(*) from public.community_posts where status = 'rejected' and created_at > now() - interval '7 days'),
    'posts_week', (select count(*) from public.community_posts where created_at > now() - interval '7 days')) end;
$$;

revoke all on function private.community_settings(), private.community_blocked(uuid, uuid), private.community_post_json(public.community_posts, uuid),
  private.community_comment_shown(bigint) from public, anon, authenticated;
revoke all on function public.community_pending(integer), public.community_decide(text, text, boolean, text), public.community_ai_answer(uuid, text)
  from public, anon, authenticated;
grant execute on function public.community_pending(integer), public.community_decide(text, text, boolean, text), public.community_ai_answer(uuid, text) to service_role;
revoke all on function public.community_feed(text, smallint, integer), public.community_post_get(uuid), public.community_post_create(text, text, smallint),
  public.community_post_delete(uuid), public.community_like(uuid), public.community_comment_add(uuid, text), public.community_comment_delete(bigint),
  public.community_follow(uuid), public.community_block(uuid), public.community_report(text, text, text), public.community_profile(uuid),
  public.can_view_community_image(text), public.admin_community_counts() from public, anon;
grant execute on function public.community_feed(text, smallint, integer), public.community_post_get(uuid), public.community_post_create(text, text, smallint),
  public.community_post_delete(uuid), public.community_like(uuid), public.community_comment_add(uuid, text), public.community_comment_delete(bigint),
  public.community_follow(uuid), public.community_block(uuid), public.community_report(text, text, text), public.community_profile(uuid),
  public.can_view_community_image(text), public.admin_community_counts() to authenticated;

