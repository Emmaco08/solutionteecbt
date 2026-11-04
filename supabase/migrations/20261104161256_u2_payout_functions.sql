-- Prize payout steps, run only by the paystack Edge Function (service role) after it checked the admin (D-090).
/** The server's account check (Paystack "resolve account"): stores the name Paystack found. */
create or replace function public.payout_checked(p_claim uuid, p_admin uuid, p_name text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare pc public.prize_claims;
begin
  update public.prize_claims set verified_name = left(p_name, 120),
    payout_status = case when payout_status in ('none', 'failed', 'checked') then 'checked' else payout_status end
  where id = p_claim and status = 'submitted' returning * into pc;
  if pc.id is null then return jsonb_build_object('ok', false, 'error', 'This claim is not waiting for payment.'); end if;
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values (p_admin, 'payout_check', 'prize_claims', p_claim::text, jsonb_build_object('verified_name', pc.verified_name));
  return jsonb_build_object('ok', true, 'verified_name', pc.verified_name);
end;
$$;

/** Starts a payout: one reference per claim, only once, only for a checked account. */
create or replace function public.payout_begin(p_claim uuid, p_admin uuid)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare pc public.prize_claims;
begin
  select * into pc from public.prize_claims where id = p_claim for update;
  if pc.id is null or pc.status <> 'submitted' then return jsonb_build_object('ok', false, 'error', 'This claim is not waiting for payment.'); end if;
  if pc.payout_status not in ('checked', 'failed') then
    return jsonb_build_object('ok', false, 'error', case when pc.payout_status in ('sending', 'sent') then 'The money is already on its way.' else 'Check the account first.' end);
  end if;
  if pc.bank_code is null or pc.verified_name is null then return jsonb_build_object('ok', false, 'error', 'Check the account first.'); end if;
  if pc.payout_ref is null or pc.payout_status = 'failed' then
    pc.payout_ref := 'po_' || substr(md5(gen_random_uuid()::text), 1, 20);
  end if;
  update public.prize_claims set payout_status = 'sending', payout_ref = pc.payout_ref, payout_by = p_admin, payout_at = now(), payout_error = null
  where id = p_claim;
  insert into public.audit_log (actor, action, table_name, row_id, after)
  values (p_admin, 'payout_send', 'prize_claims', p_claim::text, jsonb_build_object('amount', pc.amount, 'ref', pc.payout_ref, 'bank_code', pc.bank_code));
  return jsonb_build_object('ok', true, 'ref', pc.payout_ref, 'amount', pc.amount, 'name', pc.verified_name, 'account_number', pc.account_number,
                            'bank_code', pc.bank_code, 'recipient_code', pc.recipient_code);
end;
$$;

/** Saves Paystack's recipient code for reuse. */
create or replace function public.payout_recipient(p_claim uuid, p_code text)
returns void language sql security definer set search_path to '' as $$
  update public.prize_claims set recipient_code = left(p_code, 60) where id = p_claim;
$$;

/** Paystack's answer for a payout (from the transfer call, verify or the webhook). Applied once: a sent payout stays sent. */
create or replace function public.payout_result(p_ref text, p_status text, p_transfer_code text default null, p_note text default null)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare pc public.prize_claims; v text;
begin
  select * into pc from public.prize_claims where payout_ref = p_ref for update;
  if pc.id is null then return jsonb_build_object('ok', false, 'error', 'unknown payout'); end if;
  v := case p_status when 'success' then 'sent' when 'failed' then 'failed' when 'reversed' then 'reversed' when 'abandoned' then 'failed' else 'sending' end;
  if pc.payout_status = 'sent' and v <> 'reversed' then return jsonb_build_object('ok', true, 'status', 'sent'); end if;
  if pc.payout_status = v and v <> 'sending' then return jsonb_build_object('ok', true, 'status', v); end if;
  update public.prize_claims set payout_status = v, transfer_code = coalesce(left(p_transfer_code, 60), transfer_code),
    payout_error = case when v in ('failed', 'reversed') then left(coalesce(p_note, 'Paystack could not send it'), 300) end,
    status = case when v = 'sent' then 'paid' else status end,
    paid_at = case when v = 'sent' then now() else paid_at end,
    paid_by = case when v = 'sent' then payout_by else paid_by end
  where id = pc.id;
  if v = 'sent' then
    insert into public.notifications (topic, title, body, audience, user_id, status, scheduled_at, source, link)
    values ('challenges', left('₦' || to_char(pc.amount, 'FM999,999,999') || ' sent to your bank', 80),
            'Your challenge prize is on its way to ' || pc.bank_name || ' ' || right(pc.account_number, 4) || '. Most banks show it within minutes.',
            'user', pc.user_id, 'scheduled', now(), 'challenge', jsonb_build_object('type', 'screen', 'target', '/me/winnings'));
  end if;
  return jsonb_build_object('ok', true, 'status', v);
end;
$$;

do $$ declare f text; begin
  foreach f in array array['payout_checked(uuid, uuid, text)', 'payout_begin(uuid, uuid)', 'payout_recipient(uuid, text)', 'payout_result(text, text, text, text)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to service_role', f);
  end loop;
end $$;
