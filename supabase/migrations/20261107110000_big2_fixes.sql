-- Big update 2, step A (applied to the hosted project with apply_migration).
-- A13: new accounts see only notifications sent after they joined (plus personal ones).
do $$
declare d text;
begin
  select pg_get_functiondef('public.my_notifications'::regproc) into d;
  if position('n.sent_at > me.joined - interval ''7 days''' in d) > 0 then
    execute replace(d, 'and n.sent_at > me.joined - interval ''7 days''', 'and (n.audience = ''user'' or n.sent_at >= me.joined)');
  end if;
end $$;

-- A7: best JAMB score from the server (full JAMB tests + finished 4-subject JAMB mocks).
create or replace function public.my_best_jamb() returns jsonb language sql stable security definer set search_path to '' as $$
  with me as (select (select auth.uid()) as uid),
  tests as (select (a.server_score ->> 'total')::int as score, a.submitted_at as at, 'test' as source from public.attempts a, me
    where a.user_id = me.uid and a.status = 'submitted' and a.mode = 'full' and a.exam_id = (select e.id from public.exam_bodies e where e.code = 'JAMB') and a.server_score ? 'total'),
  mocks as (select e.score::int, e.finished_at, 'mock' from public.challenge_entries e join public.challenges c on c.id = e.challenge_id, me
    where e.user_id = me.uid and e.status = 'finished' and c.style = 'jamb_mock' and e.score is not null and cardinality(coalesce(e.subjects,'{}')) = 4),
  all_ as (select * from tests union all select * from mocks)
  select jsonb_build_object('best', (select max(score) from all_), 'latest', (select score from all_ order by at desc nulls last limit 1), 'count', (select count(*) from all_));
$$;
revoke all on function public.my_best_jamb() from public, anon;
grant execute on function public.my_best_jamb() to authenticated;
