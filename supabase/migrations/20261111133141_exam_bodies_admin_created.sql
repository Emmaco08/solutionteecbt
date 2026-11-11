-- More exams created by the admin (A3, D-138): a short line for each exam, safe codes, and every new exam gets its
-- rules row and its Free/Premium year rule (Premium: all years; free: locked until the admin opens some).
alter table public.exam_bodies add column subtitle text check (char_length(subtitle) <= 80);
update public.exam_bodies set subtitle = case code
  when 'JAMB' then 'English + 3 subjects · 180 questions · 2 hours'
  when 'WAEC' then 'Objective papers per subject'
  when 'NECO' then 'Objective papers per subject' end;
alter table public.exam_bodies add constraint exam_bodies_code_format check (code ~ '^[A-Z][A-Z0-9]{1,11}$');
alter table public.exam_bodies add constraint exam_bodies_name_len check (char_length(name) between 2 and 60);
alter table public.exam_bodies add constraint exam_bodies_logo_key check (logo_path is null or logo_path ~ '^(brand/exam-bodies/[a-z]+\.png|public/exams/[A-Za-z0-9/_.-]+)$');
create unique index if not exists exam_bodies_code_key on public.exam_bodies (code);

create or replace function private.exam_body_created() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.exam_configs (exam_id) values (new.id) on conflict do nothing;
  update public.access_rules
     set rules = rules || jsonb_build_object(lower(new.code), case when tier = 'premium' then '"all"'::jsonb else '0'::jsonb end)
   where not rules ? lower(new.code);
  return new;
end $$;
revoke all on function private.exam_body_created() from public, anon, authenticated;
create trigger exam_bodies_created after insert on public.exam_bodies for each row execute function private.exam_body_created();

