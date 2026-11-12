-- Community v3 (D-156), part 1: check after posting, strikes and posting bans, AI in replies and on its own, staff and
-- moderator badges, SolutionTee pages, personal notification settings.

alter table public.community_comments
  add column if not exists ask_ai boolean not null default false,
  add column if not exists ai_answered boolean not null default false,
  add column if not exists ai_kind text check (ai_kind in ('answer', 'reply', 'auto'));
alter table public.community_posts
  add column if not exists ai_seen boolean not null default false,
  add column if not exists page_id uuid;
alter table public.community_profiles
  add column if not exists role text not null default 'student' check (role in ('student', 'moderator')),
  add column if not exists notify jsonb not null default '{}'::jsonb;
create index if not exists community_posts_unchecked on public.community_posts (created_at) where checked_at is null;
create index if not exists community_comments_unchecked on public.community_comments (created_at) where checked_at is null;

alter table public.community_notes drop constraint if exists community_notes_kind_check;
alter table public.community_notes add constraint community_notes_kind_check check (kind in (
  'like', 'reply', 'repost', 'quote', 'follow', 'mention', 'ai', 'shown', 'rejected', 'comment_like', 'profile',
  'removed', 'ban', 'post', 'milestone', 'digest', 'suggest', 'page'));

-- Strikes (each post or reply taken down) and posting bans.
create table if not exists public.community_strikes (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null,
  ref text not null,
  reason text,
  by_user uuid,
  created_at timestamptz not null default now()
);
create index if not exists community_strikes_user on public.community_strikes (user_id, created_at desc);
alter table public.community_strikes enable row level security;
create policy "staff read" on public.community_strikes for select using (private.is_staff());

create table if not exists public.community_bans (
  user_id uuid primary key references auth.users (id) on delete cascade,
  until timestamptz not null,
  reason text,
  created_at timestamptz not null default now()
);
alter table public.community_bans enable row level security;
create policy "staff read" on public.community_bans for select using (private.is_staff());
create policy "staff lift" on public.community_bans for delete using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));

-- "Not interested": the post goes away and that author shows less.
create table if not exists public.community_hidden (
  user_id uuid not null references auth.users (id) on delete cascade,
  post_id uuid not null references public.community_posts (id) on delete cascade,
  author uuid,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
alter table public.community_hidden enable row level security;

-- SolutionTee pages: the official @solutiontee page (super admins only) and pages any staff member makes.
create table if not exists public.community_pages (
  id uuid primary key default gen_random_uuid(),
  handle text not null unique check (handle ~ '^[a-z0-9][a-z0-9_.]{1,18}[a-z0-9_]$'),
  name text not null check (char_length(name) between 2 and 50),
  bio text check (bio is null or char_length(bio) <= 160),
  avatar_path text,
  header smallint not null default 0 check (header between 0 and 5),
  official boolean not null default false,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.community_pages enable row level security;
create policy "staff read" on public.community_pages for select using (private.is_staff());

create table if not exists public.community_page_members (
  page_id uuid not null references public.community_pages (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'editor' check (role in ('owner', 'editor')),
  primary key (page_id, user_id)
);
alter table public.community_page_members enable row level security;
create policy "staff read" on public.community_page_members for select using (private.is_staff());

create table if not exists public.community_page_follows (
  page_id uuid not null references public.community_pages (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (page_id, user_id)
);
alter table public.community_page_follows enable row level security;

alter table public.community_posts drop constraint if exists community_posts_page_fk;
alter table public.community_posts add constraint community_posts_page_fk foreign key (page_id) references public.community_pages (id) on delete cascade;
create index if not exists community_posts_page on public.community_posts (page_id, created_at desc) where page_id is not null;

insert into public.community_pages (handle, name, bio, official)
values ('solutiontee', 'SolutionTee', 'Official SolutionTee CBT page. Learn. Think. Solve. Tag @solutiontee in a post or reply and SolutionTee AI answers.', true)
on conflict (handle) do nothing;

-- Settings defaults (admin-editable): check after posting, strikes, ban length, AI comments, ads every N posts.
update public.app_settings set value = jsonb_build_object('moderation', 'after', 'strikes_limit', 3, 'strike_days', 30, 'ban_hours', 24,
  'ai_auto', true, 'ai_auto_daily', 15, 'ad_every', 5) || value where key = 'community';
insert into public.app_settings (key, value) select 'community', jsonb_build_object('moderation', 'after', 'strikes_limit', 3, 'strike_days', 30,
  'ban_hours', 24, 'ai_auto', true, 'ai_auto_daily', 15, 'ad_every', 5)
where not exists (select 1 from public.app_settings where key = 'community');

-- ---------- roles ----------
create or replace function private.community_badge(p_uid uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case
    when exists (select 1 from public.staff s where s.user_id = p_uid and s.role <> 'tutor') then 'staff'
    when exists (select 1 from public.community_profiles c where c.user_id = p_uid and c.role = 'moderator') then 'mod'
  end;
$$;

-- Can take down any post or reply: super admins, admins and Community moderators.
create or replace function private.community_is_mod(p_uid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.staff s where s.user_id = p_uid and s.role in ('super_admin', 'admin'))
      or exists (select 1 from public.community_profiles c where c.user_id = p_uid and c.role = 'moderator');
$$;

create or replace function private.community_can_page(p_uid uuid, p_page uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.community_pages pg where pg.id = p_page and (
    (pg.official and exists (select 1 from public.staff s where s.user_id = p_uid and s.role = 'super_admin'))
    or (not pg.official and (exists (select 1 from public.community_page_members m where m.page_id = pg.id and m.user_id = p_uid)
        or exists (select 1 from public.staff s where s.user_id = p_uid and s.role = 'super_admin')))));
$$;

-- Handles are shared by students and pages.
create or replace function private.community_handle_free(p text, p_uid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select not exists (select 1 from public.community_profiles c where (c.handle = p or c.pending_handle = p) and c.user_id <> p_uid)
     and not exists (select 1 from public.community_pages g where g.handle = p);
$$;

-- ---------- bans ----------
create or replace function private.community_banned_until(p_uid uuid)
returns timestamptz language sql stable security definer set search_path = '' as $$
  select until from public.community_bans where user_id = p_uid and until > now();
$$;

-- A take-down: a strike, a note and a push; at the admin's limit, a posting ban.
create or replace function private.community_strike(p_user uuid, p_kind text, p_ref text, p_reason text, p_by uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare s jsonb := private.community_settings(); v_n integer; v_lim integer := coalesce((s ->> 'strikes_limit')::int, 3);
  v_hours integer := coalesce((s ->> 'ban_hours')::int, 24); v_until timestamptz;
begin
  if p_user is null then return; end if;
  insert into public.community_strikes (user_id, kind, ref, reason, by_user) values (p_user, p_kind, p_ref, left(p_reason, 300), p_by);
  select count(*) into v_n from public.community_strikes x
    where x.user_id = p_user and x.created_at > now() - make_interval(days => coalesce((s ->> 'strike_days')::int, 30))
      and x.created_at > coalesce((select b.created_at from public.community_bans b where b.user_id = p_user), '-infinity');
  if v_lim > 0 and v_n >= v_lim then
    v_until := now() + make_interval(hours => greatest(v_hours, 1));
    insert into public.community_bans (user_id, until, reason, created_at) values (p_user, v_until, 'Community guidelines broken ' || v_n || ' times', now())
    on conflict (user_id) do update set until = excluded.until, reason = excluded.reason, created_at = now();
    perform private.community_note(p_user, null, 'ban', null, null,
      'You cannot post or reply until ' || to_char(v_until at time zone 'Africa/Lagos', 'FMDD Mon, FMHH12:MI am') || ' because posts were taken down ' || v_n || ' times.');
    perform private.community_push(p_user, 'Posting paused for ' || v_hours || ' hours',
      'Some of your posts broke the community guidelines. You can read and like posts, and post again after the break.', '/community/notifications');
  end if;
end $$;

-- Notes remember their kind for the push that follows, so each student's push settings apply.
create or replace function private.community_note(p_user uuid, p_actor uuid, p_kind text, p_post uuid, p_comment bigint, p_body text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform set_config('community.kind', p_kind, true);
  if p_user is null or p_user is not distinct from p_actor then return; end if;
  if p_actor is not null and private.community_blocked(p_user, p_actor) then return; end if;
  if p_kind in ('like', 'repost', 'comment_like', 'follow') and exists (
      select 1 from public.community_notes n where n.user_id = p_user and n.actor = p_actor and n.kind = p_kind
        and n.post_id is not distinct from p_post and n.comment_id is not distinct from p_comment
        and (p_kind <> 'follow' or n.created_at > now() - interval '1 day')) then
    return;
  end if;
  insert into public.community_notes (user_id, actor, kind, post_id, comment_id, body) values (p_user, p_actor, p_kind, p_post, p_comment, left(p_body, 200));
end $$;

-- Pushes follow each student's settings (Community → Edit profile → Notifications). Defaults: everything but likes.
create or replace function private.community_push(p_user uuid, p_title text, p_body text, p_target text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_kind text := nullif(current_setting('community.kind', true), ''); v_pref jsonb;
  v_key text;
begin
  if p_user is null then return; end if;
  v_key := case v_kind when 'reply' then 'replies' when 'mention' then 'mentions' when 'quote' then 'mentions' when 'follow' then 'follows'
    when 'ai' then 'ai' when 'post' then 'posts' when 'page' then 'posts' when 'milestone' then 'milestones' when 'digest' then 'digest'
    when 'like' then 'likes' when 'repost' then 'likes' else null end;
  if v_key is not null then
    select notify into v_pref from public.community_profiles where user_id = p_user;
    if coalesce((v_pref ->> v_key)::boolean, v_key <> 'likes') is false then return; end if;
  end if;
  insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
  values ('account'::public.notif_topic, left(p_title, 80), case when char_length(btrim(coalesce(p_body, ''))) < 2 then 'Open Community to see it.' else left(p_body, 200) end,
          'user', p_user, 'scheduled', now(), 'community', jsonb_build_object('type', 'screen', 'target', p_target));
end $$;
