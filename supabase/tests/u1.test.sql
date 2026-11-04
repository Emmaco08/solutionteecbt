-- U1 checks (docs/plans/big-update.md). Run with execute_sql; it always rolls back (raise at the end).
do $$ declare u uuid; n int; ok bool := false; m jsonb; b int; begin
select id into u from auth.users where id not in (select user_id from public.staff) limit 1;
perform set_config('request.jwt.claims', json_build_object('sub', u, 'role','authenticated')::text, true);
set local role authenticated;
-- 1. bookmarks keep text refs (notes "kind:id", questions "exam/subject/year/id")
insert into public.bookmarks (user_id, kind, ref, label) values (u, 'item', 'note:abc-123', 'Test note');
insert into public.bookmarks (user_id, kind, ref, label) values (u, 'question', '1/2/2019/55', 'Q');
select count(*) into b from public.bookmarks where user_id = u and ref in ('note:abc-123', '1/2/2019/55');
-- 2. students read the motivation list and today's line, but cannot change it
select count(*) into n from public.motivation_quotes;
m := public.today_motivation();
begin insert into public.motivation_quotes (body) values ('hacked line here'); exception when others then ok := true; end;
update public.motivation_quotes set body = 'changed by student' where id = 1;
raise exception 'RESULTS bookmarks=% (want 2) read=% today=% insert_refused=% unchanged=%', b, n, m ? 'body', ok,
  (select body from public.motivation_quotes where id = 1) <> 'changed by student';
end $$;
