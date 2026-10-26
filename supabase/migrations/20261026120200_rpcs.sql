-- SolutionTee CBT · Phase 2 · server functions (RPCs) used by the app and the admin

-- ================================================================ students
/** Questions for one exam + subject + year. The only way a student reads questions.
    Checks: signed in, not banned, year published, year open for this plan and mode,
    and an hourly cap to slow down scraping (SECURITY.md §2). */
create or replace function public.fetch_questions(
  p_exam smallint, p_subject smallint, p_year smallint,
  p_mode text default 'cbt', p_limit integer default 60, p_offset integer default 0)
returns table (
  id uuid, number smallint, body text, options jsonb, answer text, explanation text,
  difficulty public.difficulty, image_path text, topic text, passage_id uuid, passage_title text, passage_body text)
language plpgsql volatile security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_used integer;
  v_got integer;
begin
  if v_uid is null then raise exception 'not_signed_in' using errcode = '28000'; end if;
  if private.is_banned(v_uid) then raise exception 'banned' using errcode = '42501'; end if;
  if p_mode not in ('cbt', 'pq') then raise exception 'bad_mode' using errcode = '22023'; end if;
  if p_limit not between 1 and 100 or p_offset < 0 then raise exception 'bad_page' using errcode = '22023'; end if;
  if not private.is_staff() and not exists (
      select 1 from public.exam_years y
      where y.exam_id = p_exam and y.subject_id = p_subject and y.year = p_year and y.status = 'published') then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if not private.year_open(p_exam, p_year, p_mode) then
    raise exception 'locked' using errcode = '42501', hint = 'premium_required';
  end if;

  select coalesce(sum(f.cnt), 0) into v_used from private.fetch_log f
  where f.user_id = v_uid and f.at > now() - interval '1 hour';
  if v_used >= 3000 and not private.is_staff() then
    raise exception 'rate_limited' using errcode = '54000', hint = 'try_again_later';
  end if;

  return query
    select q.id, q.number, q.body, q.options, q.answer, q.explanation, q.difficulty, q.image_path,
           t.name, q.passage_id, p.title, p.body
    from public.questions q
    left join public.topics t on t.id = q.topic_id
    left join public.passages p on p.id = q.passage_id
    where q.exam_id = p_exam and q.subject_id = p_subject and q.year = p_year
      and q.status = 'published' and q.deleted_at is null
    order by q.number nulls last, q.created_at
    limit p_limit offset p_offset;
  get diagnostics v_got = row_count;

  insert into private.fetch_log (user_id, cnt) values (v_uid, greatest(v_got, 1));
end;
$$;

/** Published years with whether each is open to this student (for lock icons in the app). */
create or replace function public.my_open_years(p_exam smallint default null)
returns table (exam_id smallint, subject_id smallint, year smallint, cbt_open boolean, pq_open boolean)
language sql stable security definer set search_path = '' as $$
  select y.exam_id, y.subject_id, y.year,
         private.year_open(y.exam_id, y.year, 'cbt'),
         private.year_open(y.exam_id, y.year, 'pq')
  from public.exam_years y
  where y.status = 'published' and (p_exam is null or y.exam_id = p_exam)
  order by y.exam_id, y.subject_id, y.year;
$$;

/** The signed-in student's plan in one call. */
create or replace function public.my_plan()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'tier', case when private.has_premium() then 'premium' else 'free' end,
    'expires_at', (select max(e.expires_at) from public.entitlements e
                   where e.user_id = (select auth.uid()) and e.revoked_at is null and e.expires_at > now()),
    'banned', private.is_banned());
$$;

-- ================================================================ admin: CSV import
/** Import questions in one transaction. p_rows is an array of objects with the CSV columns
    (validated first by packages/shared/csv). Unknown exam/subject codes abort the whole import.
    p_dry_run = true checks everything and rolls back, returning the same summary. */
create or replace function public.import_questions(p_file_name text, p_rows jsonb, p_dry_run boolean default false)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_batch uuid := gen_random_uuid();
  v_total integer := jsonb_array_length(p_rows);
  v_inserted integer := 0;
  v_dupes integer := 0;
  v_new_topics integer := 0;
  v_new_years integer := 0;
  v_bad record;
  v_summary jsonb;
begin
  if not private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if jsonb_typeof(p_rows) <> 'array' or v_total = 0 then raise exception 'no_rows' using errcode = '22023'; end if;
  if v_total > 5000 then raise exception 'too_many_rows' using errcode = '22023', hint = 'max 5000 per file'; end if;

  drop table if exists pg_temp._imp;
  create temporary table _imp on commit drop as
  select (r.ord - 1)::integer as row_no, r.x as raw,
         upper(trim(r.x ->> 'exam')) as exam_code,
         lower(trim(r.x ->> 'subject')) as subject_key,
         (r.x ->> 'year')::smallint as year,
         nullif(r.x ->> 'number', '')::smallint as number,
         nullif(trim(r.x ->> 'passage_id'), '')::uuid as passage_id,
         r.x ->> 'question' as body,
         jsonb_strip_nulls(jsonb_build_object(
           'A', nullif(r.x ->> 'option_a', ''), 'B', nullif(r.x ->> 'option_b', ''),
           'C', nullif(r.x ->> 'option_c', ''), 'D', nullif(r.x ->> 'option_d', ''),
           'E', nullif(r.x ->> 'option_e', ''))) as options,
         upper(trim(r.x ->> 'answer')) as answer,
         nullif(r.x ->> 'explanation', '') as explanation,
         nullif(trim(r.x ->> 'topic'), '') as topic,
         nullif(lower(trim(r.x ->> 'difficulty')), '')::public.difficulty as difficulty,
         nullif(trim(r.x ->> 'image_url'), '') as image_path,
         null::smallint as exam_id, null::smallint as subject_id
  from jsonb_array_elements(p_rows) with ordinality as r(x, ord);

  update _imp i set exam_id = e.id from public.exam_bodies e where e.code = i.exam_code;
  update _imp i set subject_id = s.id from public.subjects s
    where s.code = i.subject_key or lower(s.name) = i.subject_key;

  select row_no, exam_code, subject_key into v_bad from _imp where exam_id is null or subject_id is null limit 1;
  if found then
    raise exception 'unknown_exam_or_subject' using errcode = '22023',
      detail = format('row %s: exam "%s", subject "%s"', v_bad.row_no + 1, v_bad.exam_code, v_bad.subject_key);
  end if;

  select count(*) into v_dupes from _imp i
  where exists (select 1 from public.questions q
                where q.content_hash = private.question_hash(i.body) and q.deleted_at is null
                  and q.exam_id = i.exam_id and q.subject_id = i.subject_id);

  begin
    perform set_config('app.bulk_audit', 'on', true);

    insert into public.import_batches (id, file_name, total_rows)
    values (v_batch, left(p_file_name, 200), v_total);

    with ins as (
      insert into public.topics (subject_id, name)
      select distinct i.subject_id, i.topic from _imp i where i.topic is not null
      on conflict (subject_id, name) do nothing returning 1)
    select count(*) into v_new_topics from ins;

    with ins as (
      insert into public.exam_years (exam_id, subject_id, year)
      select distinct i.exam_id, i.subject_id, i.year from _imp i
      on conflict (exam_id, subject_id, year) do nothing returning 1)
    select count(*) into v_new_years from ins;

    insert into public.questions (exam_id, subject_id, year, number, topic_id, passage_id, body, options,
                                  answer, explanation, difficulty, image_path, status, import_batch_id)
    select i.exam_id, i.subject_id, i.year, i.number,
           (select t.id from public.topics t where t.subject_id = i.subject_id and t.name = i.topic),
           i.passage_id, i.body, i.options, i.answer, i.explanation, i.difficulty, i.image_path,
           'draft', v_batch
    from _imp i order by i.row_no;
    get diagnostics v_inserted = row_count;

    v_summary := jsonb_build_object('batch_id', v_batch, 'total', v_total, 'inserted', v_inserted,
      'possible_duplicates', v_dupes, 'new_topics', v_new_topics, 'new_years', v_new_years, 'dry_run', p_dry_run);
    update public.import_batches set inserted_rows = v_inserted, summary = v_summary where id = v_batch;

    perform set_config('app.bulk_audit', 'off', true);
    insert into public.audit_log (actor, action, table_name, row_id, after)
    values ((select auth.uid()), 'import', 'questions', v_batch::text, v_summary);

    if p_dry_run then raise exception 'dry_run_rollback'; end if;
  exception when raise_exception then
    if sqlerrm <> 'dry_run_rollback' then raise; end if;
  end;

  return v_summary;
end;
$$;

/** Undo an import: soft-deletes its questions (kept 30 days for recovery) and logs one audit row. */
create or replace function public.undo_import(p_batch uuid)
returns integer language plpgsql volatile security definer set search_path = '' as $$
declare v_n integer;
begin
  if not private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  perform set_config('app.bulk_audit', 'on', true);
  update public.questions set deleted_at = now()
  where import_batch_id = p_batch and deleted_at is null;
  get diagnostics v_n = row_count;
  update public.import_batches set undone_at = now(), undone_by = (select auth.uid())
  where id = p_batch and undone_at is null;
  if not found then raise exception 'not_found_or_already_undone' using errcode = 'P0002'; end if;
  perform set_config('app.bulk_audit', 'off', true);
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), 'undo_import', 'questions', p_batch::text, jsonb_build_object('removed', v_n));
  return v_n;
end;
$$;

/** Publish or unpublish many questions at once (bulk bar in the Question bank). */
create or replace function public.set_questions_status(p_ids uuid[], p_status public.content_status)
returns integer language plpgsql volatile security definer set search_path = '' as $$
declare v_n integer;
begin
  if not private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if array_length(p_ids, 1) > 1000 then raise exception 'too_many' using errcode = '22023'; end if;
  perform set_config('app.bulk_audit', 'on', true);
  update public.questions set status = p_status, updated_by = (select auth.uid())
  where id = any (p_ids) and deleted_at is null;
  get diagnostics v_n = row_count;
  perform set_config('app.bulk_audit', 'off', true);
  insert into public.audit_log (actor, action, table_name, after)
  values ((select auth.uid()), 'bulk_status', 'questions', jsonb_build_object('status', p_status, 'count', v_n, 'ids', to_jsonb(p_ids)));
  return v_n;
end;
$$;

-- ================================================================ admin: users
create or replace function public.admin_list_users(p_search text default null, p_limit integer default 50, p_offset integer default 0)
returns table (id uuid, email text, full_name text, phone text, state text, created_at timestamptz,
               last_sign_in_at timestamptz, is_premium boolean, premium_until timestamptz, banned_at timestamptz,
               staff_role public.staff_role, total bigint)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if not private.is_staff(array['super_admin', 'admin']::public.staff_role[]) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  return query
    select u.id, u.email::text, p.full_name, p.phone, p.state, u.created_at, u.last_sign_in_at,
           private.has_premium(u.id),
           (select max(e.expires_at) from public.entitlements e
             where e.user_id = u.id and e.revoked_at is null and e.expires_at > now()),
           p.banned_at, s.role, count(*) over ()
    from auth.users u
    left join public.profiles p on p.id = u.id
    left join public.staff s on s.user_id = u.id
    where p_search is null or p_search = ''
       or u.email ilike '%' || p_search || '%' or p.full_name ilike '%' || p_search || '%' or p.phone ilike '%' || p_search || '%'
    order by u.created_at desc
    limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0);
end;
$$;

create or replace function public.admin_set_ban(p_user uuid, p_banned boolean, p_reason text default null)
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  if not private.can_edit(array['super_admin', 'admin']::public.staff_role[]) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if p_user = (select auth.uid()) then raise exception 'cannot_ban_self' using errcode = '22023'; end if;
  if exists (select 1 from public.staff s where s.user_id = p_user) then
    raise exception 'cannot_ban_staff' using errcode = '22023', hint = 'remove the staff role first';
  end if;
  if p_banned and (p_reason is null or char_length(trim(p_reason)) < 3) then
    raise exception 'reason_required' using errcode = '22023';
  end if;
  update public.profiles
  set banned_at = case when p_banned then now() end,
      ban_reason = case when p_banned then left(trim(p_reason), 500) end
  where id = p_user;
  if not found then raise exception 'not_found' using errcode = 'P0002'; end if;
end;
$$;

/** Real counts for the dashboard (no sample numbers). */
create or replace function public.admin_dashboard()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_staff() then raise exception 'not_allowed' using errcode = '42501'; end if;
  return jsonb_build_object(
    'students', (select count(*) from auth.users u where not exists (select 1 from public.staff s where s.user_id = u.id)),
    'new_students_7d', (select count(*) from auth.users u where u.created_at > now() - interval '7 days'
                         and not exists (select 1 from public.staff s where s.user_id = u.id)),
    'premium', (select count(distinct e.user_id) from public.entitlements e
                where e.revoked_at is null and e.starts_at <= now() and e.expires_at > now()),
    'questions', (select count(*) from public.questions q where q.deleted_at is null),
    'questions_published', (select count(*) from public.questions q where q.deleted_at is null and q.status = 'published'),
    'questions_review', (select count(*) from public.questions q where q.deleted_at is null and q.status = 'review'),
    'years_published', (select count(*) from public.exam_years y where y.status = 'published'),
    'imports_7d', (select count(*) from public.import_batches b where b.created_at > now() - interval '7 days' and b.undone_at is null),
    'banned', (select count(*) from public.profiles p where p.banned_at is not null),
    'by_subject', (select coalesce(jsonb_agg(x order by x.n desc), '[]') from (
        select s.name, count(*) as n from public.questions q join public.subjects s on s.id = q.subject_id
        where q.deleted_at is null group by s.name order by n desc limit 6) x)
  );
end;
$$;

-- RPC permissions: students get only the student functions; anon gets nothing.
revoke execute on function public.fetch_questions, public.my_open_years, public.my_plan,
  public.import_questions, public.undo_import, public.set_questions_status,
  public.admin_list_users, public.admin_set_ban, public.admin_dashboard from public, anon;
grant execute on function public.fetch_questions, public.my_open_years, public.my_plan,
  public.import_questions, public.undo_import, public.set_questions_status,
  public.admin_list_users, public.admin_set_ban, public.admin_dashboard to authenticated;
