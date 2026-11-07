do $do$
declare d text;
begin
  select pg_get_functiondef('public.cbt_paper(smallint,smallint,smallint,integer)'::regprocedure) into d;
  if position('v_nov' in d) > 0 then return; end if;
  d := replace(d, 's jsonb; i integer; k integer;', 's jsonb; i integer; k integer; v_match text; v_since smallint; v_label text; v_instr text; v_nov jsonb;');
  d := replace(d, $a$      v_part := private.paper_take(p_exam, p_subject, v_open, p_year, s ->> 'key', v_counts[i], v_ids, v_hashes, coalesce((s ->> 'passage')::boolean, false),
                                   nullif(s ->> 'match', ''), (s ->> 'since')::smallint);$a$,
  $b$      v_match := nullif(s ->> 'match', ''); v_since := (s ->> 'since')::smallint; v_label := s ->> 'label'; v_instr := s ->> 'instruction';
      if s ->> 'key' = 'novel' and p_year is not null then
        -- A year's paper: that year's novel (its own questions, topped up only with questions naming the same book).
        v_nov := private.year_novel(p_exam, p_subject, p_year, s -> 'novels');
        v_match := coalesce(v_nov ->> 'match', '(?!)'); v_since := null;
        v_label := 'JAMB novel' || coalesce(': ' || (v_nov ->> 'title'), '');
        v_instr := 'These questions are based on the JAMB recommended text' || coalesce(', ' || (v_nov ->> 'title'), '') || '.';
      end if;
      v_part := private.paper_take(p_exam, p_subject, v_open, p_year, s ->> 'key', v_counts[i], v_ids, v_hashes, coalesce((s ->> 'passage')::boolean, false),
                                   v_match, v_since);$b$);
  d := replace(d, $a$jsonb_build_object('key', s ->> 'key', 'label', s ->> 'label', 'instruction', s ->> 'instruction',$a$,
                  $b$jsonb_build_object('key', s ->> 'key', 'label', v_label, 'instruction', v_instr,$b$);
  if position('v_nov := private.year_novel' in d) = 0 or position('''label'', v_label' in d) = 0 then raise exception 'cbt_paper markers not found'; end if;
  execute d;
end
$do$;
