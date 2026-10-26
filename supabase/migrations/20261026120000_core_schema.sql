-- SolutionTee CBT · Phase 2 · core schema
-- Default deny: RLS is enabled on every table. Students never read `questions` directly;
-- they call public.fetch_questions(), which checks plan rules on the server (SECURITY.md §2).

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pgtap with schema extensions;

-- Helpers live in a schema that the Data API does not expose.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated, service_role;

-- ---------------------------------------------------------------- enums
create type public.staff_role as enum ('super_admin', 'admin', 'editor', 'teacher');
create type public.content_status as enum ('draft', 'review', 'published');
create type public.year_status as enum ('draft', 'published');
create type public.difficulty as enum ('easy', 'medium', 'hard');
create type public.entitlement_source as enum ('manual', 'paystack', 'play', 'code', 'referral', 'prize');

-- ---------------------------------------------------------------- people
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text check (char_length(full_name) <= 120),
  phone text check (phone ~ '^\+?[0-9 ]{7,20}$'),
  state text check (char_length(state) <= 40),
  school text check (char_length(school) <= 160),
  target_exams text[] not null default '{}',
  jamb_subjects text[] not null default '{}',
  target_score smallint check (target_score between 0 and 400),
  avatar_path text,
  banned_at timestamptz,
  ban_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.staff (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role public.staff_role not null,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- exams
create table public.exam_bodies (
  id smallint generated always as identity primary key,
  code text not null unique check (code ~ '^[A-Z0-9-]{2,20}$'),
  name text not null,
  logo_path text,
  sort smallint not null default 0,
  is_active boolean not null default true
);

create table public.subjects (
  id smallint generated always as identity primary key,
  code text not null unique check (code ~ '^[a-z]{2,6}$'),
  name text not null unique,
  sort smallint not null default 0
);

create table public.exam_subjects (
  exam_id smallint not null references public.exam_bodies (id) on delete cascade,
  subject_id smallint not null references public.subjects (id) on delete cascade,
  compulsory boolean not null default false,
  question_count smallint not null default 40 check (question_count between 1 and 200),
  minutes smallint check (minutes between 1 and 600),
  primary key (exam_id, subject_id)
);

create table public.exam_configs (
  exam_id smallint primary key references public.exam_bodies (id) on delete cascade,
  subjects_per_candidate smallint not null default 1 check (subjects_per_candidate between 1 and 9),
  total_minutes smallint check (total_minutes between 1 and 600),
  score_scale smallint not null default 100 check (score_scale between 1 and 1000),
  max_options smallint not null default 4 check (max_options in (4, 5)),
  rules jsonb not null default '{}'
);

create table public.exam_years (
  id bigint generated always as identity primary key,
  exam_id smallint not null references public.exam_bodies (id) on delete cascade,
  subject_id smallint not null references public.subjects (id) on delete cascade,
  year smallint not null check (year between 1978 and 2100),
  status public.year_status not null default 'draft',
  published_at timestamptz,
  unique (exam_id, subject_id, year)
);

-- ---------------------------------------------------------------- content
create table public.topics (
  id integer generated always as identity primary key,
  subject_id smallint not null references public.subjects (id) on delete cascade,
  parent_id integer references public.topics (id) on delete set null,
  name text not null check (char_length(name) between 1 and 120),
  sort smallint not null default 0,
  unique (subject_id, name)
);

create table public.passages (
  id uuid primary key default gen_random_uuid(),
  exam_id smallint not null references public.exam_bodies (id),
  subject_id smallint not null references public.subjects (id),
  year smallint check (year between 1978 and 2100),
  title text,
  body text not null check (char_length(body) between 1 and 40000),
  created_by uuid default auth.uid() references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.import_batches (
  id uuid primary key default gen_random_uuid(),
  file_name text not null,
  total_rows integer not null default 0,
  inserted_rows integer not null default 0,
  summary jsonb not null default '{}',
  created_by uuid default auth.uid() references auth.users (id),
  created_at timestamptz not null default now(),
  undone_at timestamptz,
  undone_by uuid references auth.users (id)
);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  exam_id smallint not null references public.exam_bodies (id),
  subject_id smallint not null references public.subjects (id),
  year smallint not null check (year between 1978 and 2100),
  number smallint check (number between 1 and 500),
  topic_id integer references public.topics (id) on delete set null,
  passage_id uuid references public.passages (id) on delete set null,
  body text not null check (char_length(body) between 1 and 20000),
  options jsonb not null check (jsonb_typeof(options) = 'object'),
  answer text not null check (answer in ('A', 'B', 'C', 'D', 'E')),
  explanation text check (char_length(explanation) <= 40000),
  difficulty public.difficulty,
  image_path text,
  status public.content_status not null default 'draft',
  content_hash text,
  import_batch_id uuid references public.import_batches (id) on delete set null,
  created_by uuid default auth.uid() references auth.users (id),
  updated_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint questions_answer_in_options check (options ? answer),
  constraint questions_options_keys check (options ?& array['A', 'B', 'C', 'D'])
);

create index questions_lookup on public.questions (exam_id, subject_id, year, status) where deleted_at is null;
create index questions_hash on public.questions (content_hash) where deleted_at is null;
create index questions_batch on public.questions (import_batch_id);
create index questions_topic on public.questions (topic_id);

-- ---------------------------------------------------------------- access & money
create table public.plans (
  id smallint generated always as identity primary key,
  code text not null unique check (code ~ '^[a-z0-9_]{2,30}$'),
  name text not null,
  description text,
  price_kobo integer not null check (price_kobo >= 0),
  duration_days integer check (duration_days between 1 and 1000),
  ends_on date,
  play_product_id text unique,
  is_active boolean not null default true,
  sort smallint not null default 0,
  check (duration_days is not null or ends_on is not null)
);

create table public.entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  plan_id smallint references public.plans (id),
  source public.entitlement_source not null,
  starts_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  revoked_by uuid references auth.users (id),
  granted_by uuid default auth.uid() references auth.users (id),
  reason text check (char_length(reason) <= 500),
  external_ref text unique,
  created_at timestamptz not null default now(),
  check (expires_at > starts_at),
  check (source <> 'manual' or (reason is not null and char_length(trim(reason)) >= 3))
);
create index entitlements_active on public.entitlements (user_id, expires_at) where revoked_at is null;

-- Same shape as the approved prototype (ST.ACCESS_DEFAULT): one row per tier.
create table public.access_rules (
  tier text primary key check (tier in ('free', 'premium')),
  rules jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid() references auth.users (id)
);

-- ---------------------------------------------------------------- app control
create table public.app_tabs (
  key text primary key check (key ~ '^[a-z0-9_]{2,30}$'),
  title text not null,
  icon text not null,
  type text not null check (type in ('home', 'study', 'test', 'ai_chat', 'profile', 'content_list', 'webview', 'link')),
  sort smallint not null default 0,
  enabled boolean not null default true,
  premium_only boolean not null default false,
  config jsonb not null default '{}',
  min_app_version text
);

create table public.onboarding_slides (
  id smallint generated always as identity primary key,
  title text not null,
  body text not null,
  animation text,
  sort smallint not null default 0,
  enabled boolean not null default true
);

create table public.news_posts (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 3 and 160),
  summary text check (char_length(summary) <= 400),
  body text,
  image_path text,
  category text not null default 'update',
  link_type text check (link_type in ('none', 'screen', 'url', 'doc')),
  link_target text,
  is_pinned boolean not null default false,
  status public.content_status not null default 'draft',
  publish_at timestamptz not null default now(),
  created_by uuid default auth.uid() references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.feature_flags (
  key text primary key check (key ~ '^[a-z0-9_]{2,60}$'),
  enabled boolean not null default false,
  description text,
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid() references auth.users (id)
);

create table public.app_settings (
  key text primary key check (key ~ '^[a-z0-9_]{2,60}$'),
  value jsonb not null,
  description text,
  is_public boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid() references auth.users (id)
);

-- ---------------------------------------------------------------- system
create table public.audit_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor uuid,
  action text not null,
  table_name text not null,
  row_id text,
  before jsonb,
  after jsonb
);
create index audit_log_at on public.audit_log (at desc);
create index audit_log_table on public.audit_log (table_name, at desc);

create table private.fetch_log (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  cnt integer not null,
  at timestamptz not null default now()
);
create index fetch_log_user_at on private.fetch_log (user_id, at desc);
alter table private.fetch_log enable row level security;
