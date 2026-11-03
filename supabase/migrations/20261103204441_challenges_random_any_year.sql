-- SolutionTee CBT · owner (D-077): random past questions for challenges come from any year, Free and Premium.
-- Only published questions; no passage or picture questions; A–D answers; never twice in one challenge.
/** Admin: copy random published past questions (any year, Free and Premium; no passages or pictures) into the pool, with levels. */
create or replace function public.admin_challenge_add_random(p_id uuid, p_subjects smallint[], p_count integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.challenges; v_exam smallint; v_sid smallint; v_added integer; v_left integer; v_pos integer; v_out jsonb := '[]'::jsonb;
begin
  if not private.is_staff(array['super_admin', 'admin', 'editor']::public.staff_role[]) then raise exception 'Not allowed' using errcode = '42501'; end if;
  select * into c from public.challenges where id = p_id;
  if not found then raise exception 'Unknown challenge' using errcode = 'P0002'; end if;
  if c.closed_at is not null then raise exception 'This challenge has ended.' using errcode = 'P0001'; end if;
  if exists (select 1 from public.challenge_entries e where e.challenge_id = p_id) then
    raise exception 'Students have started this challenge, so its questions cannot change.' using errcode = 'P0001';
  end if;
  if p_count is null or p_count < 1 or p_count > 500 then raise exception 'Choose 1 to 500 questions per subject.' using errcode = '22023'; end if;
  if coalesce(cardinality(p_subjects), 0) = 0 then raise exception 'Choose at least one subject.' using errcode = '22023'; end if;
  v_exam := (select b.id from public.exam_bodies b where b.code = c.exam_code);
  foreach v_sid in array p_subjects loop
    select coalesce(max(position), 0) into v_pos from public.challenge_questions where challenge_id = p_id;
    with pick as (
      select q.id, q.body, q.options, q.answer, q.explanation, q.subject_id
      from public.questions q
      where q.subject_id = v_sid and q.status = 'published' and q.deleted_at is null and q.passage_id is null and q.image_path is null
        and (v_exam is null or q.exam_id = v_exam)
        and q.answer in ('A', 'B', 'C', 'D') and q.options ?& array['A', 'B', 'C', 'D']
        and not exists (select 1 from public.challenge_questions x where x.challenge_id = p_id and x.source_question_id = q.id)
      order by random() limit p_count),
    ins as (
      insert into public.challenge_questions (challenge_id, position, body, options, answer, explanation, source_question_id, subject_id, difficulty)
      select p_id, (v_pos + row_number() over ())::smallint, p.body,
             jsonb_build_object('A', p.options ->> 'A', 'B', p.options ->> 'B', 'C', p.options ->> 'C', 'D', p.options ->> 'D'),
             p.answer, p.explanation, p.id, p.subject_id, private.bank_level(p.id)
      from pick p returning 1)
    select count(*) into v_added from ins;
    select count(*) into v_left from public.questions q
      where q.subject_id = v_sid and q.status = 'published' and q.deleted_at is null and q.passage_id is null and q.image_path is null
        and (v_exam is null or q.exam_id = v_exam) and q.answer in ('A', 'B', 'C', 'D') and q.options ?& array['A', 'B', 'C', 'D']
        and not exists (select 1 from public.challenge_questions x where x.challenge_id = p_id and x.source_question_id = q.id);
    v_out := v_out || jsonb_build_object('subject', (select s.name from public.subjects s where s.id = v_sid), 'added', v_added, 'left', v_left);
  end loop;
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values ((select auth.uid()), 'challenge.add_random', 'challenges', p_id::text, jsonb_build_object('subjects', to_jsonb(p_subjects), 'count', p_count, 'result', v_out));
  return v_out;
end;
$$;
