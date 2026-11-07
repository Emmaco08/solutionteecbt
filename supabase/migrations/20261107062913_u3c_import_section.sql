-- CSV import keeps an optional JAMB section per row (validated keys); empty → the rules trigger sorts it.
do $do$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p where p.proname = 'import_questions' and p.pronamespace = 'public'::regnamespace;
  if position('section_source = ''import''' in d) > 0 then return; end if;
  d := replace(d, $a$    get diagnostics v_inserted = row_count;
$a$, $b$    get diagnostics v_inserted = row_count;

    -- An optional JAMB section column (U3c, D-098): only the known keys, marked as set by the import.
    update public.questions q set section = lower(trim(r ->> 'section')), section_source = 'import'
    from jsonb_array_elements(p_rows) r
    where q.import_batch_id = v_batch and q.body = r ->> 'body'
      and lower(trim(coalesce(r ->> 'section', ''))) in ('comprehension', 'cloze', 'novel', 'interpretation', 'antonyms', 'synonyms', 'grammar', 'oral');
$b$);
  if position('section_source = ''import''' in d) = 0 then raise exception 'import_questions: insert marker not found'; end if;
  execute d;
end
$do$;
