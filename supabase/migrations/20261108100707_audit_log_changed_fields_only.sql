-- Backend plan step 0 (docs/plans/backend-neon.md): the audit log was 75% of the database because every edit saved
-- two full copies of the row. Edits now save only the fields that changed (before -> after), and edits that change
-- only the "updated" stamp are skipped. Inserts and deletes still keep the whole row (they are rare).
create or replace function private.audit_row() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  j jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  o jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  r jsonb := coalesce(j, o);
  b jsonb; a jsonb;
begin
  if coalesce(current_setting('app.bulk_audit', true), '') = 'on' then return null; end if;
  if tg_op = 'UPDATE' then
    select coalesce(jsonb_object_agg(k, o -> k), '{}'::jsonb), coalesce(jsonb_object_agg(k, j -> k), '{}'::jsonb)
      into b, a
    from jsonb_object_keys(j) k
    where (o -> k) is distinct from (j -> k) and k not in ('updated_at', 'updated_by');
    if a = '{}'::jsonb then return null; end if;
    o := b; j := a;
  end if;
  insert into public.audit_log (actor, action, table_name, row_id, before, after)
  values ((select auth.uid()), lower(tg_op), tg_table_name,
          coalesce(r ->> 'id', r ->> 'key', r ->> 'user_id', r ->> 'tier', r ->> 'exam_id'), o, j);
  return null;
end;
$$;
