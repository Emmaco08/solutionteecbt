-- D-084: XP pack payments (no plan) also show in Admin → Payments, named "550 XP pack".
do $fix$
declare f record; d text;
begin
  for f in select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname in ('admin_payments', 'admin_payment') loop
    d := pg_get_functiondef(f.oid);
    d := replace(d, 'join public.plans pl on pl.id = p.plan_id', 'left join public.plans pl on pl.id = p.plan_id');
    d := replace(d, 'left left join', 'left join');
    d := replace(d, 'pl.name', 'coalesce(pl.name, p.xp_pack || '' XP pack'')');
    execute d;
  end loop;
end
$fix$;
