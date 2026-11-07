-- U3c (docs/plans/u3c-jamb-papers.md, D-098): JAMB papers always complete; Use of English set the JAMB way.

alter table public.questions add column if not exists section text,
  add column if not exists section_source text check (section_source is null or section_source in ('rule', 'ai', 'admin', 'import'));
create index if not exists questions_section on public.questions (exam_id, subject_id, section) where deleted_at is null;

-- The shape of a paper per exam and subject (subject null = the exam's default). Admin-editable.
create table if not exists public.exam_blueprints (
  id bigint generated always as identity primary key,
  exam_id smallint not null references public.exam_bodies (id) on delete cascade,
  subject_id smallint references public.subjects (id) on delete cascade,
  total smallint not null check (total between 1 and 200),
  sections jsonb not null default '[]',   -- [{key, label, count, instruction, passage?:bool}]
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  unique nulls not distinct (exam_id, subject_id)
);
alter table public.exam_blueprints enable row level security;
create policy "read" on public.exam_blueprints for select to authenticated using (true);
create policy "admins edit (insert)" on public.exam_blueprints for insert to authenticated with check (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));
create policy "admins edit (update)" on public.exam_blueprints for update to authenticated using (private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]));
create policy "admins edit (delete)" on public.exam_blueprints for delete to authenticated using (private.can_edit(array['super_admin', 'admin']::public.staff_role[]));
create trigger exam_blueprints_audit after insert or update or delete on public.exam_blueprints for each row execute function private.audit_row();

insert into public.exam_blueprints (exam_id, subject_id, total, sections)
select e.id, null, 40, '[]'::jsonb from public.exam_bodies e where e.code = 'JAMB'
on conflict do nothing;
insert into public.exam_blueprints (exam_id, subject_id, total, sections)
select e.id, s.id, 60, '[
  {"key":"comprehension","label":"Comprehension passage","count":5,"passage":true,"instruction":"Read the passage carefully and answer the questions that follow."},
  {"key":"cloze","label":"Cloze passage","count":10,"passage":true,"instruction":"In the passage below, the numbered gaps indicate missing words. Choose the option that best fills each gap."},
  {"key":"novel","label":"JAMB novel","count":10,"instruction":"These questions are based on the JAMB recommended text (novel)."},
  {"key":"interpretation","label":"Sentence interpretation","count":5,"instruction":"Choose the option that best explains the information conveyed in each sentence."},
  {"key":"antonyms","label":"Antonyms","count":5,"instruction":"Choose the option opposite in meaning to the word or phrase in italics (or the underlined word)."},
  {"key":"synonyms","label":"Synonyms","count":5,"instruction":"Choose the option nearest in meaning to the word or phrase in italics (or the underlined word)."},
  {"key":"grammar","label":"Basic grammar","count":10,"instruction":"Choose the option that best completes each gap."},
  {"key":"oral","label":"Oral English","count":10,"instruction":"Oral forms: choose the option that answers each question on vowels, consonants, stress, intonation or rhymes."}
]'::jsonb
from public.exam_bodies e, public.subjects s where e.code = 'JAMB' and s.name = 'Use of English'
on conflict do nothing;

-- Sort English questions into JAMB sections by their wording (rules). Unclear ones stay null for the AI sorter.
create or replace function private.english_section(p_body text, p_topic text, p_has_passage boolean, p_passage text)
returns text language sql immutable set search_path to '' as $$
  select case
    when p_body ~* '(life changer|sweet sixteen|lekki headmaster|last days at forcados|in dependence|the (recommended )?(text|novel)\M|based on .{0,60}(novel|text))' then 'novel'
    when p_topic ilike 'cloze%' or (p_has_passage and coalesce(p_passage, '') ~ '(_{3,}|\.{4,}|\(\s*\d{1,2}\s*\)|\[\s*\d{1,2}\s*\])') then 'cloze'
    when p_has_passage or p_topic ilike 'comprehension%' or p_topic ilike 'summary%' then 'comprehension'
    when p_topic ilike 'oral%' or p_body ~* '(vowel|consonant|stress(ed)?\M|rhyme|same sound|pronounc|phonetic|syllable|intonation|emphatic)' then 'oral'
    when p_body ~* '(opposite in meaning|opposite of|antonym|contrary in meaning|most nearly opposite)' then 'antonyms'
    when p_body ~* '(nearest in meaning|closest in meaning|similar in meaning|same meaning|synonym|best replaces? the (underlined|italic))' then 'synonyms'
    when p_body ~* '(best interpret|interpretation|best explains|implies that|the sentence means|means that|which of the following is implied)' then 'interpretation'
    when p_body ~* '(\.{3,}|_{3,}|gap|best completes?|complete the sentence|fill)' then 'grammar'
    when p_topic ilike 'synonyms%' then null   -- a bare word: the AI decides (synonym or antonym, from the answer)
    else 'grammar' end;
$$;

update public.questions q set section = private.english_section(q.body, t.name, q.passage_id is not null, p.body), section_source = 'rule'
from public.topics t, public.passages p
where t.id = q.topic_id and (p.id = q.passage_id) and q.subject_id = (select id from public.subjects where name = 'Use of English') and q.section_source is distinct from 'admin';
update public.questions q set section = private.english_section(q.body, t.name, false, null), section_source = 'rule'
from public.topics t
where t.id = q.topic_id and q.passage_id is null and q.subject_id = (select id from public.subjects where name = 'Use of English') and q.section_source is distinct from 'admin';
update public.questions q set section_source = null where q.section is null and q.section_source = 'rule';

-- Picks whole "units" (a passage group or one question) until [p_need] questions are taken. The chosen year first,
-- then other open years at random. Never repeats a question or a duplicate (same content_hash).
create or replace function private.paper_take(p_exam smallint, p_subject smallint, p_years smallint[], p_year smallint, p_section text,
                                              p_need integer, p_exclude uuid[], p_hashes text[], p_split boolean)
returns uuid[] language plpgsql volatile security definer set search_path to '' as $$
declare v_out uuid[] := '{}'; v_hash text[] := coalesce(p_hashes, '{}'); v_left integer := p_need; u record; v_ids uuid[]; v_big uuid[];
begin
  if v_left <= 0 then return v_out; end if;
  for u in
    select z.unit, array_agg(z.id order by z.number nulls last, z.id) as ids, array_agg(z.content_hash) as hs, bool_or(z.year = p_year) as mine
    from (select x.id, x.year, x.number, x.content_hash, coalesce(x.passage_id::text, x.id::text) as unit
          from public.questions x
          where x.exam_id = p_exam and x.subject_id = p_subject and x.year = any (p_years)
            and x.status = 'published' and x.deleted_at is null
            and (p_section is null or x.section = p_section)
            and not (x.id = any (coalesce(p_exclude, '{}')))) z
    group by z.unit
    order by bool_or(z.year = p_year) desc nulls last, random()
  loop
    exit when v_left <= 0;
    -- drop duplicates of questions already chosen
    select coalesce(array_agg(t.i order by t.o), '{}') into v_ids
    from unnest(u.ids, u.hs) with ordinality t(i, h, o) where t.h is null or not (t.h = any (v_hash));
    continue when cardinality(v_ids) = 0;
    if cardinality(v_ids) <= v_left then
      v_out := v_out || v_ids; v_left := v_left - cardinality(v_ids);
      v_hash := v_hash || u.hs;
    elsif p_split then
      v_out := v_out || v_ids[1:v_left]; v_left := 0;
    elsif v_big is null then
      v_big := v_ids;   -- remember one big passage in case nothing smaller fits
    end if;
  end loop;
  if v_left > 0 and v_big is not null then v_out := v_out || v_big[1:v_left]; end if;
  return v_out;
end;
$$;
revoke all on function private.paper_take(smallint, smallint, smallint[], smallint, text, integer, uuid[], text[], boolean) from public, anon, authenticated;

-- A complete paper for the student (their plan's open years only). English follows its blueprint (sections in
-- order, scaled for shorter tests); other subjects: the year's questions, a random set if too many, quietly topped
-- up from other open years if too few. Returns {ok, ids, years, sections:[{key,label,instruction,start,count}], short}.
create or replace function public.cbt_paper(p_exam smallint, p_subject smallint, p_year smallint default null, p_count integer default null)
returns jsonb language plpgsql volatile security definer set search_path to '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_open smallint[] := '{}';
  y record; bp record;
  v_target integer; v_sum integer; v_left integer;
  v_ids uuid[] := '{}'; v_hashes text[] := '{}'; v_part uuid[]; v_sorted uuid[];
  v_secs jsonb := '[]'; v_counts integer[] := '{}'; v_fracs numeric[] := '{}';
  s jsonb; i integer; k integer;
begin
  if v_uid is null or private.is_banned(v_uid) then return jsonb_build_object('ok', false, 'why', 'login'); end if;
  for y in select distinct ey.year from public.exam_years ey where ey.exam_id = p_exam and ey.subject_id = p_subject and ey.status = 'published' loop
    if private.year_open(p_exam, y.year, 'cbt') then v_open := v_open || y.year; end if;
  end loop;
  if cardinality(v_open) = 0 then return jsonb_build_object('ok', false, 'why', 'no_open_years'); end if;
  if p_year is not null and not (p_year = any (v_open)) then return jsonb_build_object('ok', false, 'why', 'locked'); end if;

  select * into bp from public.exam_blueprints b where b.exam_id = p_exam and b.subject_id = p_subject;
  if bp.id is null then select * into bp from public.exam_blueprints b where b.exam_id = p_exam and b.subject_id is null; end if;
  v_target := least(greatest(coalesce(p_count, bp.total, 40), 1), 200);

  if bp.id is not null and jsonb_array_length(bp.sections) > 0 then
    -- Scale the section counts to the test size (largest remainder), keeping the pattern.
    select sum((x ->> 'count')::int) into v_sum from jsonb_array_elements(bp.sections) x;
    for s in select * from jsonb_array_elements(bp.sections) loop
      v_counts := v_counts || floor((s ->> 'count')::numeric * v_target / v_sum)::int;
      v_fracs := v_fracs || ((s ->> 'count')::numeric * v_target / v_sum - floor((s ->> 'count')::numeric * v_target / v_sum));
    end loop;
    v_left := v_target - (select sum(c) from unnest(v_counts) c);
    while v_left > 0 loop
      select o into k from unnest(v_fracs) with ordinality t(f, o) order by f desc, o limit 1;
      v_counts[k] := v_counts[k] + 1; v_fracs[k] := -1; v_left := v_left - 1;
    end loop;
    i := 0;
    for s in select * from jsonb_array_elements(bp.sections) loop
      i := i + 1;
      continue when v_counts[i] = 0;
      v_part := private.paper_take(p_exam, p_subject, v_open, p_year, s ->> 'key', v_counts[i], v_ids, v_hashes, coalesce((s ->> 'passage')::boolean, false));
      select coalesce(array_agg(x.id order by (x.year = p_year) desc nulls last, x.year, coalesce(x.passage_id::text, ''), x.number nulls last), '{}'),
             v_hashes || coalesce(array_agg(x.content_hash) filter (where x.content_hash is not null), '{}')
        into v_sorted, v_hashes
      from public.questions x where x.id = any (v_part);
      if cardinality(v_sorted) > 0 then
        v_secs := v_secs || jsonb_build_object('key', s ->> 'key', 'label', s ->> 'label', 'instruction', s ->> 'instruction',
                                               'start', cardinality(v_ids), 'count', cardinality(v_sorted));
        v_ids := v_ids || v_sorted;
      end if;
    end loop;
    -- A section with too few questions anywhere: fill the rest from any English question (the pattern stays as close as possible).
    if cardinality(v_ids) < v_target then
      v_part := private.paper_take(p_exam, p_subject, v_open, p_year, null, v_target - cardinality(v_ids), v_ids, v_hashes, false);
      if cardinality(v_part) > 0 then
        v_secs := v_secs || jsonb_build_object('key', 'more', 'label', 'More questions', 'instruction', null, 'start', cardinality(v_ids), 'count', cardinality(v_part));
        v_ids := v_ids || v_part;
      end if;
    end if;
  else
    v_part := private.paper_take(p_exam, p_subject, v_open, p_year, null, v_target, '{}', '{}', false);
    select coalesce(array_agg(x.id order by (x.year = p_year) desc nulls last, x.year, x.number nulls last, x.id), '{}') into v_ids
    from public.questions x where x.id = any (v_part);
  end if;

  return jsonb_build_object('ok', cardinality(v_ids) > 0, 'ids', to_jsonb(v_ids), 'sections', v_secs, 'short', greatest(v_target - cardinality(v_ids), 0),
    'years', (select coalesce(jsonb_agg(distinct x.year), '[]') from public.questions x where x.id = any (v_ids)));
end;
$$;
revoke execute on function public.cbt_paper(smallint, smallint, smallint, integer) from public, anon;
grant execute on function public.cbt_paper(smallint, smallint, smallint, integer) to authenticated;

-- (applied as migration u3c_sections_auto)
create or replace function private.questions_section() returns trigger
language plpgsql security definer set search_path to '' as $$
begin
  if new.subject_id = (select id from public.subjects where name = 'Use of English')
     and (new.section is null or new.section_source is distinct from 'admin' and new.section_source is distinct from 'import' and new.section_source is distinct from 'ai'
          and (tg_op = 'INSERT' or new.body is distinct from old.body or new.passage_id is distinct from old.passage_id or new.topic_id is distinct from old.topic_id)) then
    new.section := private.english_section(new.body, (select t.name from public.topics t where t.id = new.topic_id), new.passage_id is not null,
                                           (select p.body from public.passages p where p.id = new.passage_id));
    new.section_source := case when new.section is null then null else 'rule' end;
  end if;
  return new;
end;
$$;
create trigger questions_section before insert or update of body, passage_id, topic_id, section on public.questions
  for each row execute function private.questions_section();

create or replace function public.am_content_editor() returns boolean
language sql stable security definer set search_path to '' as $$
  select private.can_edit(array['super_admin', 'admin', 'editor']::public.staff_role[]);
$$;
revoke execute on function public.am_content_editor() from public, anon;
grant execute on function public.am_content_editor() to authenticated;

create or replace function private.sort_sections_kick(p_limit integer default 300) returns void
language sql security definer set search_path to '' as $$
  select null::void from (select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/sort-sections',
    headers := jsonb_build_object('content-type', 'application/json',
                                  'x-cron-token', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_token')),
    body := jsonb_build_object('limit', p_limit), timeout_milliseconds := 150000)) x;
$$;
revoke all on function private.sort_sections_kick(integer) from public, anon, authenticated;
select cron.schedule('sort-sections', '17 2 * * *', $cron$ select private.sort_sections_kick(300); $cron$);

-- (applied as migration u3c_fetch_by_ids) The questions of a server-built paper, only from years open to the student.
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

-- ---- Applied later the same day (migrations u3c_current_novel, u3c_cbt_paper_novel, u3c_import_section) ----
-- The JAMB set novel (owner, 2026-11-07): The Lekki Headmaster. The novel section only uses questions on that book
-- (the body mentions it, or a novel question from 2025 on). Admins change match/since on the Blueprints page.
update public.exam_blueprints b set sections = (
  select jsonb_agg(case when x ->> 'key' = 'novel'
    then x || '{"label":"JAMB novel: The Lekki Headmaster","match":"lekki","since":2025,"instruction":"These questions are based on the JAMB recommended text, The Lekki Headmaster by Kabir Alabi Garba."}'::jsonb
    else x end order by o)
  from jsonb_array_elements(b.sections) with ordinality t(x, o))
where b.subject_id = (select id from public.subjects where name = 'Use of English');
update public.questions set section = 'novel', section_source = 'rule'
where subject_id = (select id from public.subjects where name = 'Use of English') and body ~* 'lekki' and section_source is distinct from 'admin';
-- paper_take gained (p_match text default null, p_since smallint default null): see the live definition; cbt_paper
-- passes the section's match/since and calls it with all 11 arguments (null::text, null::smallint where unused).
-- import_questions: after the insert, rows with a valid `section` set questions.section and section_source = 'import'.

-- ---- Novel per year (owner, 2026-11-07; migrations u3c_novel_per_year, u3c_cbt_paper_year_novel) ----
-- A year's paper uses THAT year's novel: the year's own novel questions, topped up only with questions naming the same
-- book (the listed title the year's questions mention most, private.year_novel). Mixed and quick tests keep the current
-- set novel (match "lekki", since 2025). The novel list is in the blueprint (sections[novel].novels: [{title, match}]):
--   The Lekki Headmaster · The Life Changer · Sweet Sixteen · In Dependence · The Last Days at Forcados High School.
-- paper_take: with match/since, the chosen year's own questions of that section always count too.
-- cbt_paper: for the novel section with a year, label and instruction name that year's book.
-- (Full definitions: see the live functions; the edits were applied in place.)
