-- Fix (D-147): the notification topic in finish_payment must be the notif_topic type.
do $$
declare d text := pg_get_functiondef('private.finish_payment(uuid,entitlement_source)'::regprocedure);
begin
  d := replace(d, $r$values (case when p.item_kind = 'class' then 'classes' else 'account' end,$r$,
                  $r$values ((case when p.item_kind = 'class' then 'classes' else 'account' end)::public.notif_topic,$r$);
  if position('::public.notif_topic' in d) = 0 then raise exception 'finish_payment not changed'; end if;
  execute d;
end $$;

