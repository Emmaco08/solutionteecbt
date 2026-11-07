-- The questions of a server-built paper (cbt_paper), only from years open to the student's plan; same rate limit as fetch_questions.
create or replace function public.fetch_questions_by_ids(p_ids uuid[])
returns table(id uuid, number smallint, body text, options jsonb, answer text, explanation text, difficulty public.difficulty, image_path text,
              topic text, passage_id uuid, passage_title text, passage_body text, year smallint, section text)
language plpgsql security definer set search_path to '' as $$
#variable_conflict use_column
declare v_uid uuid := (select auth.uid()); v_used integer; v_got integer; v_open text[] := '{}'; r record;
begin
  if v_uid is null then raise exception 'not_signed_in' using errcode = '28000'; end if;
  if private.is_banned(v_uid) then raise exception 'banned' using errcode = '42501'; end if;
  if coalesce(cardinality(p_ids), 0) not between 1 and 200 then raise exception 'bad_page' using errcode = '22023'; end if;
  select coalesce(sum(f.cnt), 0) into v_used from private.fetch_log f where f.user_id = v_uid and f.at > now() - interval '1 hour';
  if v_used >= 3000 and not private.is_staff() then raise exception 'rate_limited' using errcode = '54000', hint = 'try_again_later'; end if;
  for r in select distinct x.exam_id, x.year from public.questions x where x.id = any (p_ids) loop
    if private.year_open(r.exam_id, r.year, 'cbt') then v_open := v_open || (r.exam_id || ':' || r.year); end if;
  end loop;
  return query
    select q.id, q.number, q.body, q.options, q.answer, q.explanation, q.difficulty, q.image_path,
           t.name, q.passage_id, p.title, p.body, q.year, q.section
    from public.questions q
    left join public.topics t on t.id = q.topic_id
    left join public.passages p on p.id = q.passage_id
    where q.id = any (p_ids) and (q.exam_id || ':' || q.year) = any (v_open)
      and q.status = 'published' and q.deleted_at is null;
  get diagnostics v_got = row_count;
  insert into private.fetch_log (user_id, cnt) values (v_uid, greatest(v_got, 1));
end;
$$;
revoke execute on function public.fetch_questions_by_ids(uuid[]) from public, anon;
grant execute on function public.fetch_questions_by_ids(uuid[]) to authenticated;
