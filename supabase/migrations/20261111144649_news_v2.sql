-- News v2 (B7, D-141): likes, saved posts, comments with reports, per-post comments switch.
alter table public.news_posts add column comments_on boolean not null default true;

create table public.news_likes (
  post_id uuid not null references public.news_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create table public.news_saves (
  post_id uuid not null references public.news_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index news_saves_user_idx on public.news_saves (user_id, created_at desc);

create table public.news_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.news_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  body text not null check (char_length(btrim(body)) between 2 and 500),
  created_at timestamptz not null default now(),
  reports smallint not null default 0,
  hidden_at timestamptz,
  hidden_by uuid,
  hidden_reason text check (hidden_reason in ('reports', 'staff')),
  reviewed_at timestamptz
);
create index news_comments_post_idx on public.news_comments (post_id, created_at);
create index news_comments_user_idx on public.news_comments (user_id, created_at desc);
create index news_comments_reported_idx on public.news_comments (reports desc) where reports > 0 and reviewed_at is null;

create table public.news_comment_reports (
  comment_id uuid not null references public.news_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  reason text not null check (reason in ('rude', 'spam', 'wrong', 'other')),
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

alter table public.news_likes enable row level security;
alter table public.news_saves enable row level security;
alter table public.news_comments enable row level security;
alter table public.news_comment_reports enable row level security;

-- Likes and saves: each student only sees and changes their own rows; counts come from news_meta().
create policy "own likes" on public.news_likes for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()) and not private.is_banned());
create policy "own saves" on public.news_saves for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
-- Comments: students read them through news_comments_list() (names shortened); they write and delete their own.
create policy "own comments" on public.news_comments for select to authenticated using (user_id = (select auth.uid()) or private.is_staff());
create policy "write own comment" on public.news_comments for insert to authenticated
  with check (user_id = (select auth.uid()) and not private.is_banned()
    and exists (select 1 from public.news_posts p where p.id = post_id and p.comments_on and p.status = 'published' and p.publish_at <= now()));
create policy "delete own comment" on public.news_comments for delete to authenticated
  using (user_id = (select auth.uid()) or private.can_edit(array['super_admin','admin','editor']::staff_role[]));
create policy "staff moderate" on public.news_comments for update to authenticated
  using (private.can_edit(array['super_admin','admin','editor']::staff_role[]))
  with check (private.can_edit(array['super_admin','admin','editor']::staff_role[]));
create policy "report once" on public.news_comment_reports for insert to authenticated
  with check (user_id = (select auth.uid()) and not private.is_banned());
create policy "staff read reports" on public.news_comment_reports for select to authenticated using (private.is_staff());

grant select, insert, delete on public.news_likes, public.news_saves to authenticated;
grant select, insert (post_id, body), delete on public.news_comments to authenticated;
grant update (hidden_at, hidden_by, hidden_reason, reviewed_at, reports) on public.news_comments to authenticated;
grant select, insert (comment_id, reason) on public.news_comment_reports to authenticated;

-- Comment rules: 5 a minute and 30 a day; no links (spam); trimmed.
create or replace function private.news_comment_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.body := btrim(regexp_replace(new.body, '\s+\n', E'\n', 'g'));
  if new.body ~* '(https?://|www\.|\.com\b|\.ng\b|wa\.me|t\.me)' then
    raise exception 'no_links' using errcode = 'P0001';
  end if;
  if (select count(*) from public.news_comments c where c.user_id = new.user_id and c.created_at > now() - interval '1 minute') >= 5
     or (select count(*) from public.news_comments c where c.user_id = new.user_id and c.created_at > now() - interval '1 day') >= 30 then
    raise exception 'too_many' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger news_comments_guard before insert on public.news_comments for each row execute function private.news_comment_guard();

-- Three reports hide a comment until staff look at it.
create or replace function private.news_comment_reported() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.news_comments c
     set reports = c.reports + 1,
         hidden_at = case when c.hidden_at is null and c.reports + 1 >= 3 and c.reviewed_at is null then now() else c.hidden_at end,
         hidden_reason = case when c.hidden_at is null and c.reports + 1 >= 3 and c.reviewed_at is null then 'reports' else c.hidden_reason end
   where c.id = new.comment_id;
  return new;
end $$;
create trigger news_comment_reports_count after insert on public.news_comment_reports for each row execute function private.news_comment_reported();
revoke all on function private.news_comment_guard(), private.news_comment_reported() from public, anon, authenticated;

-- Likes, visible comments, and whether I liked / saved, for a list of posts.
create or replace function public.news_meta(p_ids uuid[])
returns table (post_id uuid, likes integer, comments integer, liked boolean, saved boolean)
language sql stable security definer set search_path = '' as $$
  select p.id,
         (select count(*)::int from public.news_likes l where l.post_id = p.id),
         (select count(*)::int from public.news_comments c where c.post_id = p.id and c.hidden_at is null),
         exists (select 1 from public.news_likes l where l.post_id = p.id and l.user_id = (select auth.uid())),
         exists (select 1 from public.news_saves s where s.post_id = p.id and s.user_id = (select auth.uid()))
  from public.news_posts p
  where p.id = any(p_ids[1:100]) and p.status = 'published' and p.publish_at <= now();
$$;

-- Comments of one post, oldest first: short names only (first name + initial), my own marked; hidden ones left out
-- (the writer still sees their own, marked hidden).
create or replace function public.news_comments_list(p_post uuid)
returns table (id uuid, name text, body text, created_at timestamptz, mine boolean, hidden boolean)
language sql stable security definer set search_path = '' as $$
  select c.id, private.lb_name(pr.full_name, 'first-initial'), c.body, c.created_at,
         c.user_id = (select auth.uid()), c.hidden_at is not null
  from public.news_comments c
  join public.news_posts p on p.id = c.post_id and p.status = 'published' and p.publish_at <= now()
  left join public.profiles pr on pr.id = c.user_id
  where c.post_id = p_post and (c.hidden_at is null or c.user_id = (select auth.uid()))
    and (select auth.uid()) is not null
  order by c.created_at
  limit 300;
$$;
revoke all on function public.news_meta(uuid[]), public.news_comments_list(uuid) from public, anon;
grant execute on function public.news_meta(uuid[]), public.news_comments_list(uuid) to authenticated;

-- Staff moderation queue: reported or hidden comments first, with the post title and the writer's name.
create or replace function public.admin_news_comments(p_filter text default 'reported')
returns table (id uuid, post_id uuid, post_title text, user_id uuid, name text, body text, created_at timestamptz,
               reports smallint, hidden_at timestamptz, hidden_reason text, reviewed_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select c.id, c.post_id, p.title, c.user_id, coalesce(pr.full_name, 'Student'), c.body, c.created_at,
         c.reports, c.hidden_at, c.hidden_reason, c.reviewed_at
  from public.news_comments c
  join public.news_posts p on p.id = c.post_id
  left join public.profiles pr on pr.id = c.user_id
  where private.is_staff()
    and case p_filter
          when 'reported' then (c.reports > 0 and c.reviewed_at is null) or c.hidden_reason = 'reports'
          when 'hidden' then c.hidden_at is not null
          else true end
  order by (c.reports > 0 and c.reviewed_at is null) desc, c.created_at desc
  limit 300;
$$;
revoke all on function public.admin_news_comments(text) from public, anon;
grant execute on function public.admin_news_comments(text) to authenticated;

