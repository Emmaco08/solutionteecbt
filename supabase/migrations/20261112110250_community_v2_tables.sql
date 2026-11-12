-- Community v2 (D-155), part 1: tables, columns, handles, helpers.

-- Community profiles: @handle, bio, photo choice (on by default, owner decision), header pattern.
create table if not exists public.community_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  handle text not null,
  handle_auto boolean not null default true,          -- made from the first name; the student has not picked one yet
  handle_changed_at timestamptz,                       -- last change the student made (once a month)
  pending_handle text,                                 -- waiting for the AI check
  bio text,
  pending_bio text,
  pending_at timestamptz,
  pending_reason text,                                 -- why the last change was not accepted (shown to the owner only)
  show_photo boolean not null default true,
  header smallint not null default 0 check (header between 0 and 5),
  created_at timestamptz not null default now(),
  constraint community_handle_format check (handle ~ '^[a-z0-9][a-z0-9_.]{1,18}[a-z0-9_]$'),
  constraint community_pending_handle_format check (pending_handle is null or pending_handle ~ '^[a-z0-9][a-z0-9_.]{1,18}[a-z0-9_]$'),
  constraint community_bio_len check (bio is null or char_length(bio) <= 160),
  constraint community_pending_bio_len check (pending_bio is null or char_length(pending_bio) <= 160)
);
create unique index if not exists community_profiles_handle on public.community_profiles (handle);
create unique index if not exists community_profiles_pending_handle on public.community_profiles (pending_handle) where pending_handle is not null;
create index if not exists community_profiles_pending on public.community_profiles (pending_at) where pending_at is not null;
alter table public.community_profiles enable row level security;
create policy "staff read" on public.community_profiles for select using (private.is_staff());
create policy "staff moderate" on public.community_profiles for update
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[])) with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));

-- Posts: up to 4 pictures, quotes, repost count, #topics.
alter table public.community_posts
  add column if not exists images text[] not null default '{}',
  add column if not exists quote_of uuid,
  add column if not exists reposts_count integer not null default 0,
  add column if not exists tags text[] not null default '{}';
alter table public.community_posts drop constraint if exists community_posts_images_max;
alter table public.community_posts add constraint community_posts_images_max check (cardinality(images) <= 4);
update public.community_posts set images = array[image_path] where image_path is not null and cardinality(images) = 0;
create index if not exists community_posts_quote on public.community_posts (quote_of) where quote_of is not null;
create index if not exists community_posts_tags on public.community_posts using gin (tags);
create index if not exists community_posts_user_time on public.community_posts (user_id, created_at desc);
create index if not exists community_posts_status_time on public.community_posts (status, created_at desc);

-- Threads: a reply belongs to a top-level comment (parent_id) and may answer a person in it (reply_to).
alter table public.community_comments
  add column if not exists parent_id bigint references public.community_comments (id) on delete cascade,
  add column if not exists reply_to uuid,
  add column if not exists likes_count integer not null default 0,
  add column if not exists replies_count integer not null default 0;
create index if not exists community_comments_parent on public.community_comments (parent_id) where parent_id is not null;
create index if not exists community_comments_post on public.community_comments (post_id, created_at);
create index if not exists community_comments_user on public.community_comments (user_id, created_at desc);

create table if not exists public.community_comment_likes (
  comment_id bigint not null references public.community_comments (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);
alter table public.community_comment_likes enable row level security;

create table if not exists public.community_reposts (
  post_id uuid not null references public.community_posts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index if not exists community_reposts_user on public.community_reposts (user_id, created_at desc);
alter table public.community_reposts enable row level security;

create table if not exists public.community_bookmarks (
  post_id uuid not null references public.community_posts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
alter table public.community_bookmarks enable row level security;

create index if not exists community_likes_user on public.community_likes (user_id, created_at desc);

-- In-app Community notifications (grouped in the list; pushed only for the important kinds).
create table if not exists public.community_notes (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  actor uuid references auth.users (id) on delete cascade,      -- null: SolutionTee AI or the system
  kind text not null check (kind in ('like', 'reply', 'repost', 'quote', 'follow', 'mention', 'ai', 'shown', 'rejected', 'comment_like', 'profile')),
  post_id uuid references public.community_posts (id) on delete cascade,
  comment_id bigint references public.community_comments (id) on delete cascade,
  body text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists community_notes_user on public.community_notes (user_id, created_at desc);
create index if not exists community_notes_unread on public.community_notes (user_id) where read_at is null;
alter table public.community_notes enable row level security;

-- ---------- Handles ----------
create or replace function private.community_handle_reserved(p text)
returns boolean language sql immutable set search_path = '' as $$
  select p ~ '(solution|soln|admin|support|official|moderator|staff|tutor|jamb|waec|neco|helpdesk|security)'
      or p in ('help', 'team', 'root', 'system', 'everyone', 'here', 'ai', 'bot', 'null', 'undefined');
$$;

create or replace function private.community_handle_free(p text, p_uid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select not exists (select 1 from public.community_profiles c where (c.handle = p or c.pending_handle = p) and c.user_id <> p_uid);
$$;

-- A handle made from the first name: tolu, tolu_a, tolu.a, tolu27 …
create or replace function private.community_handle_make(p_uid uuid)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare v_name text; v_first text; v_last text; v_try text; i integer;
begin
  select coalesce(btrim(full_name), '') into v_name from public.profiles where id = p_uid;
  v_first := left(lower(regexp_replace(split_part(v_name, ' ', 1), '[^A-Za-z0-9]', '', 'g')), 14);
  v_last := lower(left(regexp_replace(split_part(v_name, ' ', 2), '[^A-Za-z]', '', 'g'), 1));
  if char_length(v_first) < 2 or v_first !~ '^[a-z]' or private.community_handle_reserved(v_first) then v_first := 'student'; end if;
  foreach v_try in array array[v_first, v_first || '_' || v_last, v_first || '.' || v_last, v_first || v_last] loop
    if char_length(v_try) >= 3 and v_try ~ '^[a-z0-9][a-z0-9_.]{1,18}[a-z0-9_]$' and private.community_handle_free(v_try, p_uid) then return v_try; end if;
  end loop;
  for i in 1..40 loop
    v_try := v_first || case when i <= 20 then (10 + floor(random() * 90))::int::text else (100 + floor(random() * 9900))::int::text end;
    if private.community_handle_free(v_try, p_uid) then return v_try; end if;
  end loop;
  return 'student' || substr(replace(p_uid::text, '-', ''), 1, 10);
end $$;

-- Makes the Community profile when it is missing; keeps a made-up handle in step with the student's name.
create or replace function private.community_profile_ensure(p_uid uuid)
returns public.community_profiles language plpgsql volatile security definer set search_path = '' as $$
declare c public.community_profiles;
begin
  select * into c from public.community_profiles where user_id = p_uid;
  if found then return c; end if;
  insert into public.community_profiles (user_id, handle) values (p_uid, private.community_handle_make(p_uid))
  on conflict (user_id) do nothing;
  select * into c from public.community_profiles where user_id = p_uid;
  return c;
end $$;

create or replace function private.community_profile_on_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    perform private.community_profile_ensure(new.id);
  elsif new.full_name is distinct from old.full_name then
    perform private.community_profile_ensure(new.id);
    update public.community_profiles set handle = private.community_handle_make(new.id) where user_id = new.id and handle_auto;
  end if;
  return null;
end $$;
drop trigger if exists community_profile_sync on public.profiles;
create trigger community_profile_sync after insert or update of full_name on public.profiles
  for each row execute function private.community_profile_on_profile();

-- Everyone gets a handle now.
do $$ declare r record; begin
  for r in select p.id from public.profiles p left join public.community_profiles c on c.user_id = p.id where c.user_id is null order by p.created_at loop
    perform private.community_profile_ensure(r.id);
  end loop;
end $$;

-- ---------- Notes (live on the student's own user:<id> channel) ----------
create or replace function private.community_note(p_user uuid, p_actor uuid, p_kind text, p_post uuid, p_comment bigint, p_body text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_user is null or p_user is not distinct from p_actor then return; end if;
  if p_actor is not null and private.community_blocked(p_user, p_actor) then return; end if;
  -- One like / repost note per person per post (toggling on and off does not spam).
  if p_kind in ('like', 'repost', 'comment_like', 'follow') and exists (
      select 1 from public.community_notes n where n.user_id = p_user and n.actor = p_actor and n.kind = p_kind
        and n.post_id is not distinct from p_post and n.comment_id is not distinct from p_comment
        and (p_kind <> 'follow' or n.created_at > now() - interval '1 day')) then
    return;
  end if;
  insert into public.community_notes (user_id, actor, kind, post_id, comment_id, body) values (p_user, p_actor, p_kind, p_post, p_comment, left(p_body, 200));
end $$;

create or replace function private.community_note_broadcast()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform realtime.send(jsonb_build_object('kind', new.kind, 'id', new.id, 'post_id', new.post_id,
    'from', case when new.actor is null then 'SolutionTee AI' else coalesce((select nullif(btrim(p.full_name), '') from public.profiles p where p.id = new.actor), 'A student') end),
    'community_note', 'user:' || new.user_id::text, true);
  return null;
exception when others then return null;
end $$;
drop trigger if exists community_notes_live on public.community_notes;
create trigger community_notes_live after insert on public.community_notes for each row execute function private.community_note_broadcast();

-- #topics in a text (kept as written, matched without case).
create or replace function private.community_tags(p text)
returns text[] language sql immutable set search_path = '' as $$
  select coalesce(array_agg(distinct t), '{}') from (select (regexp_matches(coalesce(p, ''), '#([A-Za-z][A-Za-z0-9_]{1,29})', 'g'))[1] as t limit 10) x;
$$;
update public.community_posts set tags = private.community_tags(body) where cardinality(tags) = 0 and body ~ '#[A-Za-z]';

-- Photos in Community: shown when the student keeps "Show my photo" on (on by default).
create or replace function public.can_view_avatar(p_key text)
returns boolean language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and not private.is_banned() and (
    p_key like 'a/' || (select auth.uid())::text || '/%'
    or (coalesce((select (s.value ->> 'on')::boolean from public.app_settings s where s.key = 'leaderboard'), false)
        and exists (select 1 from public.profiles p where p.avatar_path = p_key and p.show_photo_on_leaderboard
                    and not p.hide_on_leaderboard and p.banned_at is null))
    -- D-154: tutors' photos are shown to students; a tutor (and admins) see their students' photos.
    or exists (select 1 from public.tutors t where t.photo_path = p_key and t.active)
    or exists (select 1 from public.profiles p join public.tutor_requests r on r.user_id = p.id
               where p.avatar_path = p_key and (private.is_tutor_of(r.id) or private.tutor_staff()))
    -- D-155: Community photos.
    or exists (select 1 from public.profiles p join public.community_profiles c on c.user_id = p.id
               where p.avatar_path = p_key and c.show_photo and p.banned_at is null
                 and not private.community_blocked((select auth.uid()), p.id)));
$$;

-- Pictures of a post (any of up to 4).
create or replace function public.can_view_community_image(p_key text)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_staff() or exists (select 1 from public.community_posts p where (p.image_path = p_key or p_key = any (p.images))
    and (p.user_id = (select auth.uid()) or (p.status = 'shown' and not private.community_blocked((select auth.uid()), p.user_id))));
$$;
