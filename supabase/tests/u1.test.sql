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

-- U1 fixes: challenge pictures (signed only when a published challenge uses the key; keys must be public/challenges/…)
do $$ declare u uuid; c_id uuid; a bool; b bool; bad bool := false; t jsonb; begin
select id into c_id from public.challenges where published limit 1;
update public.challenges set bg_light = 'public/challenges/2026/11/test-light.webp' where id = c_id;
begin update public.challenges set bg_dark = 'q/evil.webp' where id = c_id; exception when check_violation then bad := true; end;
select id into u from auth.users where id not in (select user_id from public.staff) limit 1;
perform set_config('request.jwt.claims', json_build_object('sub', u, 'role','authenticated')::text, true);
set local role authenticated;
a := public.can_view_challenge_image('public/challenges/2026/11/test-light.webp');
b := public.can_view_challenge_image('public/challenges/2026/11/not-used.webp');
t := public.my_practice_today(); -- today's answered questions from the server
raise exception 'RESULTS used=% (want t) unused=% (want f) bad_key_refused=% (want t) today_has_day=%', a, b, bad, t ? 'day';
end $$;
