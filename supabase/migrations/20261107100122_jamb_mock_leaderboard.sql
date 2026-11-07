-- JAMB mock leaderboard (owner, 2026-11-07): the standard challenge leaderboard, with scores out of each student's
-- maximum (100 per subject) and the admin's "when scores show" setting respected (hidden / after the end).
do $do$
declare d text;
begin
  select pg_get_functiondef('public.challenge_result(uuid)'::regprocedure) into d;
  if position('board_hidden' in d) > 0 then return; end if;
  d := replace(d, $a$'prize', e.prize) order by coalesce(e.rank, r.rnk)), '[]'::jsonb)$a$,
                  $b$'prize', e.prize, 'max', case when c.style = 'jamb_mock' then 100 * greatest(cardinality(e.subjects), 1) end,
            'subjects', case when c.style = 'jamb_mock' then e.subject_scores end) order by coalesce(e.rank, r.rnk)), '[]'::jsonb)$b$);
  d := replace(d, $a$  return private.challenge_card(c, v_uid) || jsonb_build_object('top', v_top,$a$,
                  $b$  -- A mock whose scores are hidden (always, or until it ends) shows no leaderboard to students.
  if c.style = 'jamb_mock' and not private.is_staff()
     and (c.results = 'hidden' or (c.results = 'after_end' and private.challenge_status(c) <> 'ended')) then
    v_top := '[]'::jsonb;
    return private.challenge_card(c, v_uid) || jsonb_build_object('top', v_top, 'my_rank', null, 'board_hidden', true, 'results', c.results,
      'claim', v_claim, 'ranked', 0);
  end if;
  return private.challenge_card(c, v_uid) || jsonb_build_object('top', v_top, 'board_hidden', false,
    'my_max', (select case when c.style = 'jamb_mock' then 100 * greatest(cardinality(e.subjects), 1) end
               from public.challenge_entries e where e.challenge_id = p_id and e.user_id = v_uid),$b$);
  if position('board_hidden' in d) = 0 or position('''max'', case' in d) = 0 then raise exception 'challenge_result markers not found'; end if;
  execute d;
end
$do$;
