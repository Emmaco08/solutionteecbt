-- Community (owner, 13 Nov 2026): @mention suggestions while typing, a notification is read as soon as it is opened,
-- and pushes for likes, reposts and reply likes (at most one per post per hour; on by default, switchable in the app).

-- @ suggestions: pages first (SolutionTee), then people you follow, then everyone whose @handle or name starts with it.
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
          10 + (case when exists (select 1 from public.community_follows f where f.follower = v_uid and f.followee = c.user_id) then 0 else 10 end)
             + (case when c.handle = v_q then 0 else 1 end)
        from public.community_profiles c join public.profiles pr on pr.id = c.user_id
        where c.handle is not null and c.user_id <> v_uid and pr.banned_at is null
          and (c.handle like v_like or lower(pr.full_name) like v_like or lower(pr.full_name) like '% ' || v_like)
          and not private.community_blocked(v_uid, c.user_id)
        order by 2 limit 12) t
      order by t.rank limit 8) x), '[]'::jsonb);
end $$;
revoke all on function public.community_mention_suggest(text) from public, anon;
grant execute on function public.community_mention_suggest(text) to authenticated;

-- Opening one notification (or the post a push opened) marks it read at once.
create or replace function public.community_note_open(p_id bigint default null, p_post uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); n public.community_notes; v_left integer;
begin
  if v_uid is null then raise exception 'sign in first' using errcode = '42501'; end if;
  if p_id is not null then
    select * into n from public.community_notes where id = p_id and user_id = v_uid;
    if found then
      update public.community_notes x set read_at = now()
      where x.user_id = v_uid and x.read_at is null and x.kind = n.kind and x.post_id is not distinct from n.post_id
        and x.comment_id is not distinct from n.comment_id and (n.kind in ('like', 'repost', 'comment_like') or x.id = n.id);
    end if;
  end if;
  if p_post is not null then
    update public.community_notes set read_at = now() where user_id = v_uid and read_at is null and post_id = p_post;
  end if;
  select count(*) into v_left from public.community_notes where user_id = v_uid and read_at is null and created_at > now() - interval '60 days';
  return jsonb_build_object('ok', true, 'unread', v_left);
end $$;
revoke all on function public.community_note_open(bigint, uuid) from public, anon;
grant execute on function public.community_note_open(bigint, uuid) to authenticated;

-- Pushes: likes on by default now; reply likes count as likes.
create or replace function private.community_push(p_user uuid, p_title text, p_body text, p_target text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_kind text := nullif(current_setting('community.kind', true), ''); v_pref jsonb; v_key text;
begin
  if p_user is null then return; end if;
  v_key := case v_kind when 'reply' then 'replies' when 'mention' then 'mentions' when 'quote' then 'mentions' when 'follow' then 'follows'
    when 'ai' then 'ai' when 'post' then 'posts' when 'page' then 'posts' when 'milestone' then 'milestones' when 'digest' then 'digest'
    when 'like' then 'likes' when 'repost' then 'likes' when 'comment_like' then 'likes' else null end;
  if v_key is not null then
    select notify into v_pref from public.community_profiles where user_id = p_user;
    if coalesce((v_pref ->> v_key)::boolean, true) is false then return; end if;
  end if;
  insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
  values ('account'::public.notif_topic, left(p_title, 80), case when char_length(btrim(coalesce(p_body, ''))) < 2 then 'Open Community to see it.' else left(p_body, 200) end,
          'user', p_user, 'scheduled', now(), 'community', jsonb_build_object('type', 'screen', 'target', p_target));
end $$;

create or replace function private.community_note_push()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_body text; v_title text; v_others integer;
begin
  if new.kind not in ('like', 'repost', 'comment_like') or new.actor is null or new.post_id is null then return null; end if;
  -- One push per post (or reply) per hour; the notification list still shows everyone.
  if exists (select 1 from public.community_notes x where x.user_id = new.user_id and x.kind = new.kind and x.post_id = new.post_id
               and x.comment_id is not distinct from new.comment_id and x.id <> new.id and x.created_at > now() - interval '1 hour') then
    return null;
  end if;
  select count(distinct actor) - 1 into v_others from public.community_notes x
  where x.user_id = new.user_id and x.kind = new.kind and x.post_id = new.post_id and x.comment_id is not distinct from new.comment_id;
  v_title := private.game_name(new.actor) || case when v_others > 0 then ' and ' || v_others || case when v_others = 1 then ' other' else ' others' end else '' end
    || case new.kind when 'like' then ' liked your post' when 'repost' then ' reposted your post' else ' liked your reply' end;
  if new.kind = 'comment_like' then select body into v_body from public.community_comments where id = new.comment_id;
  else select body into v_body from public.community_posts where id = new.post_id; end if;
  perform set_config('community.kind', new.kind, true);
  perform private.community_push(new.user_id, v_title, v_body, '/community/post/' || new.post_id);
  return null;
exception when others then return null;
end $$;

drop trigger if exists community_notes_push on public.community_notes;
create trigger community_notes_push after insert on public.community_notes for each row execute function private.community_note_push();
