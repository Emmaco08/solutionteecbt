-- D-120 (lawyer's list): two clearly labelled kinds of questions, "Past Questions" (official papers, owned by the exam
-- bodies) and "SolutionTee Mock Questions" (our own, written from scratch), so that past questions can be switched off
-- if a licence is refused and the app keeps working with the mock questions.

alter table public.questions
  add column if not exists source text not null default 'past' check (source in ('past', 'mock')),
  add column if not exists paused_by_switch boolean not null default false;
create index if not exists questions_source on public.questions (source) where deleted_at is null;

-- Label for any question the app shows: bank questions by their source; challenge/mock-exam questions are
-- SolutionTee Mock when written by us, otherwise the source of the bank question they were copied from.
create or replace function public.question_sources(p_ids uuid[]) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(x.id, x.source), '{}'::jsonb) from (
    select q.id, q.source from public.questions q where q.id = any(p_ids[1:500])
    union all
    select c.id, coalesce((select q.source from public.questions q where q.id = c.source_question_id), 'mock')
    from public.challenge_questions c where c.id = any(p_ids[1:500])
  ) x;
$$;
revoke all on function public.question_sources(uuid[]) from public, anon;
grant execute on function public.question_sources(uuid[]) to authenticated, service_role;

-- Super admin switch: hide every past question (published -> review, remembered) or bring them back.
create or replace function public.admin_past_questions(p_on boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  if not private.can_edit(array['super_admin']::public.staff_role[]) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  perform set_config('app.bulk_audit', 'on', true);
  if p_on then
    update public.questions set status = 'published', paused_by_switch = false where paused_by_switch;
  else
    update public.questions set status = 'review', paused_by_switch = true
     where source = 'past' and status = 'published' and deleted_at is null;
  end if;
  get diagnostics n = row_count;
  perform set_config('app.bulk_audit', 'off', true);
  insert into public.app_settings (key, value) values ('past_questions', jsonb_build_object('on', p_on))
    on conflict (key) do update set value = excluded.value;
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), case when p_on then 'past_questions_on' else 'past_questions_off' end, 'questions', 'all',
          jsonb_build_object('rows', n));
  return jsonb_build_object('on', p_on, 'rows', n);
end $$;
revoke all on function public.admin_past_questions(boolean) from public, anon;
grant execute on function public.admin_past_questions(boolean) to authenticated;

-- Admin overview: how many of each kind (published / hidden by the switch).
create or replace function public.admin_question_sources() returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when private.is_staff() then jsonb_build_object(
    'past', (select count(*) from public.questions where source = 'past' and deleted_at is null and status = 'published'),
    'mock', (select count(*) from public.questions where source = 'mock' and deleted_at is null and status = 'published'),
    'paused', (select count(*) from public.questions where paused_by_switch),
    'own_challenge', (select count(*) from public.challenge_questions where source_question_id is null),
    'on', coalesce((select (value ->> 'on')::boolean from public.app_settings where key = 'past_questions'), true))
  end;
$$;
revoke all on function public.admin_question_sources() from public, anon;
grant execute on function public.admin_question_sources() to authenticated;

-- CSV import: optional `source` column ("past" or "mock"; blank = past).
create or replace function public.import_questions(p_file_name text, p_rows jsonb, p_dry_run boolean default false)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
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
         case when lower(trim(coalesce(r.x ->> 'source', ''))) in ('mock', 'solutiontee mock', 'own') then 'mock' else 'past' end as source,
         null::smallint as exam_id, null::smallint as subject_id
  from jsonb_array_elements(p_rows) with ordinality as r(x, ord);

  update _imp i set exam_id = e.id from public.exam_bodies e where e.code = i.exam_code;
  update _imp i set subject_id = s.id from public.subjects s
    where s.code = i.subject_key or lower(s.name) = i.subject_key;

  select row_no, exam_code, subject_key into v_bad from _imp where exam_id is null or subject_id is null limit 1;
  if found then
    raise exception 'unknown_exam_or_subject' using errcode = '22023',
      detail = format('row %s: exam "%s", subject "%s"', v_bad.row_no + 2, v_bad.exam_code, v_bad.subject_key);
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
                                  answer, explanation, difficulty, image_path, status, import_batch_id, source)
    select i.exam_id, i.subject_id, i.year, i.number,
           (select t.id from public.topics t where t.subject_id = i.subject_id and t.name = i.topic),
           i.passage_id, i.body, i.options, i.answer, i.explanation, i.difficulty, i.image_path,
           'draft', v_batch, i.source
    from _imp i order by i.row_no;
    get diagnostics v_inserted = row_count;

    -- An optional JAMB section column (U3c, D-098): only the known keys, marked as set by the import.
    update public.questions q set section = lower(trim(r ->> 'section')), section_source = 'import'
    from jsonb_array_elements(p_rows) r
    where q.import_batch_id = v_batch and q.body = r ->> 'body'
      and lower(trim(coalesce(r ->> 'section', ''))) in ('comprehension', 'cloze', 'novel', 'interpretation', 'antonyms', 'synonyms', 'grammar', 'oral');

    v_summary := jsonb_build_object('batch_id', v_batch, 'total', v_total, 'inserted', v_inserted,
      'possible_duplicates', v_dupes, 'new_topics', v_new_topics, 'new_years', v_new_years, 'dry_run', p_dry_run,
      'mock', (select count(*) from _imp where source = 'mock'));
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
$function$;
