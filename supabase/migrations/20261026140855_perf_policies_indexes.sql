-- SolutionTee CBT · Phase 2 · performance advisor fixes
-- 1) "for all" staff-edit policies also applied to SELECT, so every read ran two policies.
--    Split each into insert / update / delete (same conditions), leaving one SELECT policy per table.
do $$
declare r record;
begin
  for r in select tablename, policyname, array_to_string(roles, ', ') as roles, qual, with_check
           from pg_policies where schemaname = 'public' and cmd = 'ALL'
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
    execute format('create policy %I on public.%I for insert to %s with check (%s)',
                   r.policyname || ' (insert)', r.tablename, r.roles, coalesce(r.with_check, r.qual));
    execute format('create policy %I on public.%I for update to %s using (%s) with check (%s)',
                   r.policyname || ' (update)', r.tablename, r.roles, r.qual, coalesce(r.with_check, r.qual));
    execute format('create policy %I on public.%I for delete to %s using (%s)',
                   r.policyname || ' (delete)', r.tablename, r.roles, r.qual);
  end loop;
end $$;

-- 2) Indexes for foreign keys that queries filter or join on.
create index if not exists questions_subject on public.questions (subject_id);
create index if not exists questions_passage on public.questions (passage_id) where passage_id is not null;
create index if not exists passages_exam_subject on public.passages (exam_id, subject_id);
create index if not exists exam_years_subject on public.exam_years (subject_id);
create index if not exists exam_subjects_subject on public.exam_subjects (subject_id);
create index if not exists entitlements_plan on public.entitlements (plan_id);
create index if not exists topics_parent on public.topics (parent_id) where parent_id is not null;
