-- D-095: the student left or cancelled a Paystack payment before paying. The payment becomes "abandoned" at once
-- (so the admin page no longer shows it waiting). A later "success" from Paystack still counts (pay_paystack_result).
create or replace function public.pay_cancel(p_reference text, p_uid uuid, p_note text default null)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p public.payments;
begin
  select * into p from public.payments where reference = p_reference and provider = 'paystack' for update;
  if p.id is null or p.user_id is distinct from p_uid then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if p.status <> 'pending' then return jsonb_build_object('ok', true, 'status', p.status); end if;
  update public.payments set status = 'abandoned' where id = p.id;
  insert into public.payment_events (payment_id, provider, kind, ok, note)
  values (p.id, 'server', 'cancelled', true, left(coalesce(p_note, 'The student left the payment before paying'), 300));
  return jsonb_build_object('ok', true, 'status', 'abandoned');
end;
$$;
revoke execute on function public.pay_cancel(text, uuid, text) from public, anon, authenticated;
grant execute on function public.pay_cancel(text, uuid, text) to service_role;
