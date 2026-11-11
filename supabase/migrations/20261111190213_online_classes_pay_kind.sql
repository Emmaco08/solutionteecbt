-- Classes (and tutor plans, C12) are paid through the existing start_item action with kind "item": the server
-- recognises the id and records the right kind, so the Paystack function did not need a change (D-147).
do $$
declare d text := pg_get_functiondef('public.content_pay_start(uuid,text,text,text)'::regprocedure);
begin
  d := replace(d, $r$  if p_uid is null then return jsonb_build_object('ok', false, 'error', 'auth'); end if;$r$,
$r$  if p_uid is null then return jsonb_build_object('ok', false, 'error', 'auth'); end if;
  if p_kind = 'item' and p_ref ~ '^[0-9a-f-]{36}$' then
    if exists (select 1 from public.classes c where c.id = p_ref::uuid) then p_kind := 'class';
    elsif to_regclass('public.tutor_plans') is not null and private.tutor_offer(p_ref::uuid) is not null then p_kind := 'tutor';
    end if;
  end if;$r$);
  if position($r$p_kind := 'class'$r$ in d) = 0 then raise exception 'content_pay_start not changed'; end if;
  execute d;
end $$;

