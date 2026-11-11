-- Careers and JAMB subject combinations (A2, D-137). Sample rows: the owner checks each one against this year's brochure
-- and ticks "checked" in Admin -> Careers. Public read (careers are not paid content); editors manage them.
create table public.careers (
  id bigint generated always as identity primary key,
  name text not null unique check (char_length(name) between 2 and 80),
  field text not null check (char_length(field) between 2 and 40),
  course text not null check (char_length(course) between 2 and 120),
  years smallint not null default 4 check (years between 1 and 8),
  summary text not null check (char_length(summary) between 10 and 600),
  skills text[] not null default '{}',
  universities text[] not null default '{}',
  earnings text check (char_length(earnings) <= 300),
  jamb_subjects text[] not null default '{}' check (cardinality(jamb_subjects) <= 3),
  jamb_note text check (char_length(jamb_note) <= 300),
  olevel text check (char_length(olevel) <= 300),
  after_school text check (char_length(after_school) <= 300),
  checked boolean not null default false,
  active boolean not null default true,
  sort integer not null default 0,
  updated_at timestamptz not null default now()
);
create index careers_sort_idx on public.careers (sort, id);
alter table public.careers enable row level security;
create policy "read active" on public.careers for select to anon, authenticated using (active or (select private.is_staff()));
create policy "content edit" on public.careers for all to authenticated
  using (private.can_edit(array['super_admin','admin','editor']::staff_role[]))
  with check (private.can_edit(array['super_admin','admin','editor']::staff_role[]));
grant select on public.careers to anon, authenticated;
grant insert, update, delete on public.careers to authenticated;

alter table public.profiles add column career_id bigint references public.careers(id) on delete set null;
create index profiles_career_idx on public.profiles (career_id) where career_id is not null;
grant insert (career_id), update (career_id) on public.profiles to authenticated;

