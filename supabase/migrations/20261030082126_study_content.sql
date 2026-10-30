-- SolutionTee CBT · Phase 4A · Study content (video solutions, topic lessons, lesson notes, novels, syllabus/brochure)
-- Students never read study_items directly: they get a catalogue (titles + lock flag, no content) and open one item
-- at a time through study_item(), which checks the plan on the server. Files (videos, PDFs) live in the private R2
-- bucket under v/ and d/ and are signed by the website API only after can_view_study_file() says yes (D-045, D-053).

create table public.study_items (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('video_solution', 'lesson', 'note', 'novel', 'doc')),
  title text not null check (char_length(title) between 2 and 160),
  subtitle text check (char_length(subtitle) <= 200),
  exam_id smallint references public.exam_bodies (id),
  subject_id smallint references public.subjects (id),
  topic_id integer references public.topics (id),
  year smallint,
  question_id uuid references public.questions (id) on delete set null, -- video solution of this question
  body text,                                       -- notes: Markdown + LaTeX; novels: overview; videos: key working
  data jsonb not null default '{}'::jsonb,         -- video: duration_s; doc: pages, topics[]; novel: author, chapters[], themes[], characters[]
  files jsonb not null default '{}'::jsonb,        -- R2 keys: {"360": "v/..", "720": "v/..", "pdf": "d/..", "sizes": {...}}
  is_free boolean not null default false,
  status public.content_status not null default 'draft',
  sort smallint not null default 0,
  created_by uuid default auth.uid(),
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index study_items_list on public.study_items (kind, status, subject_id, sort) where deleted_at is null;
create index study_items_question on public.study_items (question_id) where question_id is not null;
create trigger study_items_touch before update on public.study_items for each row execute function private.touch_updated_at();
create trigger study_items_audit after insert or update or delete on public.study_items for each row execute function private.audit_row();

alter table public.study_items enable row level security;
create policy "staff read" on public.study_items for select to authenticated using (private.is_staff());
create policy "content edit" on public.study_items for all to authenticated
  using (private.can_edit(array['super_admin', 'admin', 'editor', 'teacher']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin', 'editor', 'teacher']::public.staff_role[]));

-- Which Free/Premium rule (access_rules.rules key) controls each kind.
create or replace function private.study_feature(p_kind text)
returns text language sql immutable set search_path = '' as $$
  select case p_kind when 'video_solution' then 'videos' when 'lesson' then 'lessons' when 'note' then 'notes'
                     when 'novel' then 'novels' when 'doc' then 'syllabus' end;
$$;

/** May the signed-in student open this item? Staff and Premium: yes. Free: only items marked free, and only when
    the Free plan includes that kind of content (rule true, a number, or "all"). */
create or replace function private.study_open(p_kind text, p_is_free boolean)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare v_rule jsonb;
begin
  if private.is_staff() then return true; end if;
  if (select auth.uid()) is null or private.is_banned() then return false; end if;
  if private.has_premium() then return true; end if;
  if not p_is_free then return false; end if;
  select r.rules -> private.study_feature(p_kind) into v_rule from public.access_rules r where r.tier = 'free';
  return v_rule is not null and v_rule not in ('false'::jsonb, '0'::jsonb, 'null'::jsonb);
end;
$$;

/** Catalogue of published items of one kind: titles, metadata and a lock flag. Never returns content or file keys. */
create or replace function public.study_catalog(p_kind text, p_subject smallint default null)
returns table (id uuid, kind text, title text, subtitle text, exam_id smallint, subject_id smallint, topic_id integer,
               topic text, year smallint, question_id uuid, meta jsonb, is_free boolean, locked boolean, sort smallint)
language sql stable security definer set search_path = '' as $$
  select i.id, i.kind, i.title, i.subtitle, i.exam_id, i.subject_id, i.topic_id, t.name, i.year, i.question_id,
         jsonb_strip_nulls(jsonb_build_object(
           'duration_s', i.data -> 'duration_s', 'pages', i.data -> 'pages', 'author', i.data -> 'author',
           'chapters', jsonb_array_length(coalesce(i.data -> 'chapters', '[]'::jsonb)),
           'size_360', i.files -> 'sizes' -> '360', 'size_720', i.files -> 'sizes' -> '720', 'size_pdf', i.files -> 'sizes' -> 'pdf',
           'minutes', case when i.kind = 'note' then greatest(1, round(coalesce(char_length(i.body), 0) / 1100.0)) end)),
         i.is_free, not private.study_open(i.kind, i.is_free), i.sort
  from public.study_items i left join public.topics t on t.id = i.topic_id
  where i.kind = p_kind and i.status = 'published' and i.deleted_at is null
    and (p_subject is null or i.subject_id = p_subject)
    and (select auth.uid()) is not null
  order by i.sort, i.title;
$$;

/** One item with its content. Raises 'locked' when the plan does not include it, 'not_found' otherwise. */
create or replace function public.study_item(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare r public.study_items;
begin
  select * into r from public.study_items i where i.id = p_id and i.status = 'published' and i.deleted_at is null;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  if not private.study_open(r.kind, r.is_free) then raise exception 'locked' using errcode = 'P0001'; end if;
  return jsonb_build_object(
    'id', r.id, 'kind', r.kind, 'title', r.title, 'subtitle', r.subtitle, 'exam_id', r.exam_id,
    'subject_id', r.subject_id, 'topic_id', r.topic_id, 'year', r.year, 'question_id', r.question_id,
    'body', r.body, 'data', r.data, 'is_free', r.is_free, 'updated_at', r.updated_at,
    -- which files exist (keys stay on the server; the app asks the website API for a signed link)
    'files', (select coalesce(jsonb_object_agg(k, true), '{}'::jsonb) from jsonb_object_keys(r.files - 'sizes') k),
    'sizes', coalesce(r.files -> 'sizes', '{}'::jsonb));
end;
$$;

/** For the file signer: may the student open this R2 key (v/... or d/...)? Same rule as the item it belongs to. */
create or replace function public.can_view_study_file(p_key text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.study_items i, jsonb_each_text(i.files - 'sizes') f
    where f.value = p_key and i.status = 'published' and i.deleted_at is null
      and private.study_open(i.kind, i.is_free))
  or (private.is_staff() and exists (select 1 from public.study_items i, jsonb_each_text(i.files - 'sizes') f where f.value = p_key));
$$;

/** For the file signer: the R2 key of one file of an item, after the plan check (the app never sees keys). */
create or replace function public.study_file_key(p_id uuid, p_file text)
returns text language plpgsql stable security definer set search_path = '' as $$
declare r public.study_items;
begin
  select * into r from public.study_items i where i.id = p_id and i.deleted_at is null
    and (i.status = 'published' or private.is_staff());
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
  if not private.study_open(r.kind, r.is_free) then raise exception 'locked' using errcode = 'P0001'; end if;
  return r.files ->> p_file;
end;
$$;

-- ---------------------------------------------------------------- bookmarks and progress (own rows only)
create table public.bookmarks (
  user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
  kind text not null check (kind in ('question', 'item')),
  ref uuid not null,
  label text check (char_length(label) <= 200),     -- e.g. "JAMB 2001 Mathematics Q7"
  created_at timestamptz not null default now(),
  primary key (user_id, kind, ref)
);
alter table public.bookmarks enable row level security;
create policy "own bookmarks" on public.bookmarks for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create table public.study_progress (
  user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
  item_id uuid not null references public.study_items (id) on delete cascade,
  progress real not null default 0 check (progress between 0 and 1),
  position jsonb not null default '{}'::jsonb,       -- video seconds, page, chapter…
  updated_at timestamptz not null default now(),
  primary key (user_id, item_id)
);
create index study_progress_item on public.study_progress (item_id);
alter table public.study_progress enable row level security;
create policy "own progress" on public.study_progress for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create trigger study_progress_touch before update on public.study_progress for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------- grants
revoke execute on function public.study_catalog, public.study_item, public.can_view_study_file, public.study_file_key from public, anon;
grant execute on function public.study_catalog, public.study_item, public.can_view_study_file, public.study_file_key to authenticated;
revoke all on function private.study_open, private.study_feature from public, anon, authenticated;

-- Staff may upload study files too (video and PDF uploads use the same signed-PUT flow as images).
create or replace function public.can_upload_images()
returns boolean language sql stable security definer set search_path = '' as $$
  select private.can_edit(array['super_admin', 'admin', 'editor', 'teacher']::public.staff_role[]);
$$;

-- Study tab sections shown in the app (admin can rename, reorder, hide)
insert into public.app_settings (key, value, description, is_public, updated_by) values
  ('study_sections', '[
     {"key": "pq", "title": "Past questions", "subtitle": "Study mode with answers", "icon": "exam", "tone": "navy", "enabled": true},
     {"key": "video_solution", "title": "Video solutions", "subtitle": "Watch each answer", "icon": "playCircle", "tone": "blue", "enabled": true},
     {"key": "lesson", "title": "Topic lessons", "subtitle": "By syllabus topic", "icon": "chalkboardTeacher", "tone": "green", "enabled": true},
     {"key": "note", "title": "Lesson notes", "subtitle": "Read, with formulas", "icon": "note", "tone": "gold", "enabled": true},
     {"key": "novel", "title": "Novels", "subtitle": "JAMB literature texts", "icon": "books", "tone": "red", "enabled": true},
     {"key": "doc", "title": "Syllabus & brochure", "subtitle": "JAMB, WAEC, NECO", "icon": "filePdf", "tone": "navy", "enabled": true}
   ]'::jsonb, 'Study tab tiles: order, titles, on/off.', true, null)
on conflict (key) do nothing;
