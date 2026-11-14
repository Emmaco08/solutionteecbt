-- Scaling pass (owner, 14 Nov 2026: the server must cope when very many students are on).
-- 1. Every foreign key gets a covering index (87 were missing): joins and deletes on busy tables stay fast.
-- 2. Exact duplicate indexes are dropped (they slow every write and use memory for nothing).
-- 3. pg_cron's run history is trimmed to 3 days every night (6 jobs a minute added ~9,000 rows a day, forever).
do $$
declare r record; n int := 0; cols text; iname text;
begin
  for r in
    select c.conrelid::regclass as tbl, cl.relname, ns.nspname, c.conname, c.conkey
    from pg_constraint c
    join pg_class cl on cl.oid = c.conrelid
    join pg_namespace ns on ns.oid = cl.relnamespace
    where c.contype = 'f' and ns.nspname in ('public', 'private')
      and not exists (
        select 1 from pg_index i
        where i.indrelid = c.conrelid
          and (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] @> c.conkey
          and (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] <@ c.conkey)
  loop
    select string_agg(quote_ident(a.attname), ', ' order by k.ord) into cols
    from unnest(r.conkey) with ordinality k(attnum, ord)
    join pg_attribute a on a.attrelid = r.tbl and a.attnum = k.attnum;
    iname := left(r.relname || '_' || replace(replace(cols, '"', ''), ', ', '_') || '_fk', 60);
    execute format('create index if not exists %I on %s (%s)', iname, r.tbl, cols);
    n := n + 1;
  end loop;
  raise notice 'foreign-key indexes added: %', n;
end $$;

drop index if exists public.challenge_answers_one;        -- same as the primary key
drop index if exists public.community_comments_post_idx;   -- same as community_comments_post
drop index if exists public.community_posts_feed_idx;      -- same as community_posts_status_time
drop index if exists public.community_posts_user_time;     -- same as community_posts_user_idx

select cron.unschedule(jobid) from cron.job where jobname = 'cron-history-trim';
select cron.schedule('cron-history-trim', '43 3 * * *', $$delete from cron.job_run_details where end_time < now() - interval '3 days'$$);
delete from cron.job_run_details where end_time < now() - interval '3 days';
