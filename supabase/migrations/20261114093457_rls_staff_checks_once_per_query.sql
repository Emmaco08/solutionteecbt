-- Admin pages timed out ("canceling statement due to statement timeout" on /admin/questions, owner 14 Nov 2026).
-- Cause: staff policies called private.is_staff() / private.can_edit() bare, so Postgres ran the check once per row
-- (33k questions → 11.6 s for 25 rows). Wrapped as (select …) the check runs once per query (an init plan).
-- Who can read or change what is exactly the same; only how often the check runs changes.
do $$
declare
  p record;
  q text;
  c text;
  re constant text := 'private\.(is_staff|can_edit)\(([^()]*)\)';
  n int := 0;
begin
  for p in
    select ns.nspname as sch, cl.relname as tbl, po.polname as pol,
           pg_get_expr(po.polqual, po.polrelid) as qual, pg_get_expr(po.polwithcheck, po.polrelid) as chk
    from pg_policy po join pg_class cl on cl.oid = po.polrelid join pg_namespace ns on ns.oid = cl.relnamespace
    where ns.nspname = 'public'
  loop
    q := p.qual;
    c := p.chk;
    if (q is not null and q ~ re and q !~* 'select private\.(is_staff|can_edit)')
       or (c is not null and c ~ re and c !~* 'select private\.(is_staff|can_edit)') then
      if q is not null then q := regexp_replace(q, re, '(select private.\1(\2))', 'g'); end if;
      if c is not null then c := regexp_replace(c, re, '(select private.\1(\2))', 'g'); end if;
      execute format('alter policy %I on %I.%I', p.pol, p.sch, p.tbl)
        || case when q is not null then format(' using (%s)', q) else '' end
        || case when c is not null then format(' with check (%s)', c) else '' end;
      n := n + 1;
    end if;
  end loop;
  raise notice 'policies updated: %', n;
end $$;

-- The question bank lists newest first.
create index if not exists questions_updated on public.questions (updated_at desc) where deleted_at is null;
