-- SolutionTee CBT · Phase 2 · server rules, triggers and Row Level Security

-- ================================================================ helper functions
create or replace function private.is_staff(roles public.staff_role[] default null)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.staff s
    where s.user_id = (select auth.uid())
      and (roles is null or s.role = any (roles))
  );
$$;

-- Admin writes need 2-step login (TOTP): Supabase puts aal2 in the JWT after MFA.
create or replace function private.is_aal2()
returns boolean language sql stable set search_path = '' as $$
  select coalesce((select auth.jwt()) ->> 'aal', '') = 'aal2';
$$;

create or replace function private.can_edit(roles public.staff_role[])
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_staff(roles) and private.is_aal2();
$$;

create or replace function private.has_premium(uid uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.entitlements e
    where e.user_id = uid and e.revoked_at is null
      and e.starts_at <= now() and e.expires_at > now()
  );
$$;

create or replace function private.is_banned(uid uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p where p.id = uid and p.banned_at is not null);
$$;

/** Is this year open to the signed-in user for this exam? kind 'cbt' = test, 'pq' = study mode.
    Same logic as the approved prototype (core.js ST.yearOpen): rule is 0/false, a number N
    (the N oldest or newest published years, by rules.which) or "all". */
create or replace function private.year_open(p_exam smallint, p_year smallint, p_kind text default 'cbt')
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  v_rules jsonb;
  v_code text;
  v_exam_rule jsonb;
  v_rule jsonb;
  v_which text;
  v_years smallint[];
begin
  if private.is_staff() then return true; end if;
  if (select auth.uid()) is null or private.is_banned() then return false; end if;

  select r.rules into v_rules from public.access_rules r
  where r.tier = case when private.has_premium() then 'premium' else 'free' end;
  if v_rules is null then return false; end if;

  select lower(e.code) into v_code from public.exam_bodies e where e.id = p_exam and e.is_active;
  if v_code is null then return false; end if;

  v_exam_rule := v_rules -> v_code;
  if v_exam_rule is null or v_exam_rule in ('0'::jsonb, 'false'::jsonb) then return false; end if;
  v_rule := case when p_kind = 'pq' then v_rules -> 'pq' else v_exam_rule end;
  if v_rule is null or v_rule in ('0'::jsonb, 'false'::jsonb) then return false; end if;
  if v_rule = '"all"'::jsonb or v_rule = 'true'::jsonb then return true; end if;
  if jsonb_typeof(v_rule) <> 'number' then return false; end if;

  v_which := coalesce(v_rules ->> 'which', 'oldest');
  select array_agg(t.year order by
           case when v_which = 'newest' then -t.year else t.year end)
    into v_years
  from (select distinct y.year from public.exam_years y
        where y.exam_id = p_exam and y.status = 'published') t;

  return p_year = any (v_years[1:(v_rule::text)::int]);
end;
$$;

grant execute on all functions in schema private to anon, authenticated, service_role;

-- ================================================================ triggers
create or replace function private.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_touch before update on public.profiles for each row execute function private.touch_updated_at();
create trigger passages_touch before update on public.passages for each row execute function private.touch_updated_at();
create trigger questions_touch before update on public.questions for each row execute function private.touch_updated_at();
create trigger news_touch before update on public.news_posts for each row execute function private.touch_updated_at();
create trigger flags_touch before update on public.feature_flags for each row execute function private.touch_updated_at();
create trigger settings_touch before update on public.app_settings for each row execute function private.touch_updated_at();
create trigger rules_touch before update on public.access_rules for each row execute function private.touch_updated_at();

-- Duplicate detection: hash of the question text, ignoring case and spacing.
create or replace function private.question_hash(p_body text)
returns text language sql immutable set search_path = '' as $$
  select md5(lower(regexp_replace(trim(p_body), '\s+', ' ', 'g')));
$$;

create or replace function private.questions_before_write()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.content_hash := private.question_hash(new.body);
  if tg_op = 'UPDATE' then new.updated_by := (select auth.uid()); end if;
  return new;
end;
$$;
create trigger questions_before_write before insert or update of body on public.questions
  for each row execute function private.questions_before_write();

create or replace function private.exam_years_publish()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.status = 'published' and (tg_op = 'INSERT' or old.status is distinct from 'published') then
    new.published_at := now();
  elsif new.status = 'draft' then
    new.published_at := null;
  end if;
  return new;
end;
$$;
create trigger exam_years_publish before insert or update of status on public.exam_years
  for each row execute function private.exam_years_publish();

-- New sign-up → profile row.
create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, nullif(left(new.raw_user_meta_data ->> 'full_name', 120), ''))
  on conflict (id) do nothing;
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

-- Audit: every write to admin-editable tables, whoever makes it (website, SQL editor, service role).
-- Bulk RPCs set app.bulk_audit = 'on' and write one summary row instead of thousands.
create or replace function private.audit_row()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  j jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  o jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  r jsonb := coalesce(j, o);
begin
  if coalesce(current_setting('app.bulk_audit', true), '') = 'on' then return null; end if;
  if tg_op = 'UPDATE' and j = o then return null; end if;
  insert into public.audit_log (actor, action, table_name, row_id, before, after)
  values ((select auth.uid()), lower(tg_op), tg_table_name,
          coalesce(r ->> 'id', r ->> 'key', r ->> 'user_id', r ->> 'tier', r ->> 'exam_id'), o, j);
  return null;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['staff', 'exam_bodies', 'subjects', 'exam_subjects', 'exam_configs', 'exam_years',
    'topics', 'passages', 'questions', 'import_batches', 'plans', 'entitlements', 'access_rules', 'app_tabs',
    'onboarding_slides', 'news_posts', 'feature_flags', 'app_settings']
  loop
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function private.audit_row()',
                   t || '_audit', t);
  end loop;
end $$;
create trigger profiles_ban_audit after update of banned_at on public.profiles
  for each row when (old.banned_at is distinct from new.banned_at) execute function private.audit_row();

-- ================================================================ RLS
do $$
declare t text;
begin
  foreach t in array array['profiles', 'staff', 'exam_bodies', 'subjects', 'exam_subjects', 'exam_configs', 'exam_years',
    'topics', 'passages', 'import_batches', 'questions', 'plans', 'entitlements', 'access_rules', 'app_tabs',
    'onboarding_slides', 'news_posts', 'feature_flags', 'app_settings', 'audit_log']
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- Role groups
-- content: super_admin, admin, editor · settings/money/users: super_admin, admin · staff: super_admin

-- profiles: a student sees and edits only their own row (and never their ban fields).
create policy "own profile read" on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.is_staff(array['super_admin', 'admin']::public.staff_role[]));
create policy "own profile update" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
revoke update on public.profiles from authenticated, anon;
grant update (full_name, phone, state, school, target_exams, jamb_subjects, target_score, avatar_path)
  on public.profiles to authenticated;

-- staff
create policy "staff read" on public.staff for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff());
create policy "super admin manages staff" on public.staff for all to authenticated
  using (private.can_edit(array['super_admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin']::public.staff_role[]) and user_id <> (select auth.uid()));

-- Exam catalogue: everyone (even before login) may read active/published metadata; staff edit.
create policy "public read" on public.exam_bodies for select to anon, authenticated using (is_active or private.is_staff());
create policy "public read" on public.subjects for select to anon, authenticated using (true);
create policy "public read" on public.exam_subjects for select to anon, authenticated using (true);
create policy "public read" on public.exam_configs for select to anon, authenticated using (true);
create policy "read published years" on public.exam_years for select to authenticated
  using (status = 'published' or private.is_staff());
create policy "public read" on public.topics for select to authenticated using (true);

create policy "admins edit" on public.exam_bodies for all to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));
create policy "admins edit" on public.subjects for all to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));
create policy "admins edit" on public.exam_subjects for all to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));
create policy "admins edit" on public.exam_configs for all to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));
create policy "content edit" on public.exam_years for all to authenticated
  using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));
create policy "content edit" on public.topics for all to authenticated
  using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));

-- Questions, passages, imports: staff only. Students go through public.fetch_questions().
create policy "staff read" on public.questions for select to authenticated using (private.is_staff());
create policy "content edit" on public.questions for all to authenticated
  using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));
create policy "staff read" on public.passages for select to authenticated using (private.is_staff());
create policy "content edit" on public.passages for all to authenticated
  using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));
create policy "staff read" on public.import_batches for select to authenticated using (private.is_staff());
create policy "content edit" on public.import_batches for all to authenticated
  using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));

-- Plans and access rules are public (the app shows prices and what Free includes); admins edit.
create policy "public read" on public.plans for select to anon, authenticated using (is_active or private.is_staff());
create policy "admins edit" on public.plans for all to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));
create policy "public read" on public.access_rules for select to anon, authenticated using (true);
create policy "admins edit" on public.access_rules for all to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));

-- Entitlements: a student reads their own; only admins (2-step) or trusted server code create them.
create policy "own entitlements" on public.entitlements for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff(array['super_admin', 'admin']::public.staff_role[]));
create policy "admins grant" on public.entitlements for insert to authenticated
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]) and source = 'manual'
              and granted_by = (select auth.uid()));
create policy "admins revoke" on public.entitlements for update to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));

-- App control
create policy "public read" on public.app_tabs for select to anon, authenticated using (enabled or private.is_staff());
create policy "public read" on public.onboarding_slides for select to anon, authenticated using (enabled or private.is_staff());
create policy "public read" on public.news_posts for select to authenticated
  using ((status = 'published' and publish_at <= now()) or private.is_staff());
create policy "public read" on public.feature_flags for select to anon, authenticated using (true);
create policy "public read" on public.app_settings for select to anon, authenticated using (is_public or private.is_staff());

create policy "admins edit" on public.app_tabs for all to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));
create policy "admins edit" on public.onboarding_slides for all to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));
create policy "content edit" on public.news_posts for all to authenticated
  using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));
create policy "admins edit" on public.feature_flags for all to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));
create policy "admins edit" on public.app_settings for all to authenticated
  using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]))
  with check (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));

-- Audit log: read-only for admins; rows are only written by the trigger.
create policy "admins read" on public.audit_log for select to authenticated
  using (private.is_staff(array['super_admin', 'admin']::public.staff_role[]));
revoke insert, update, delete, truncate on public.audit_log from anon, authenticated;

-- Nothing for anonymous visitors beyond the explicit public-read policies above.
revoke all on public.questions, public.passages, public.import_batches, public.entitlements,
  public.profiles, public.staff, public.audit_log from anon;
