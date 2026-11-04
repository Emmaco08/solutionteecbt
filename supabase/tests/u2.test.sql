-- U2 checks (D-090 payouts, D-091 challenge rules). Run with execute_sql; it always rolls back (raise at the end).
-- Last run 2026-11-04: all 11 true.
do $$
declare e record; c_id uuid; adm uuid; pc uuid; r jsonb; r2 jsonb; r3 jsonb; r4 jsonb; out text := ''; ok bool; n int; full_msg text := ''; u uuid;
begin
  select x.* into e from public.challenge_entries x where not exists (select 1 from public.prize_claims p where p.entry_id = x.id) limit 1;
  select user_id into adm from public.staff limit 1;
  insert into public.prize_claims (entry_id, user_id, amount, adult, bank_name, account_number, account_name, bank_code)
  values (e.id, e.user_id, 5000, true, 'GTBank', '0123456789', 'Test Winner', '058') returning id into pc;
  r := public.payout_begin(pc, adm);
  out := out || ' 1.send_before_check_refused=' || (not (r->>'ok')::bool);
  r := public.payout_checked(pc, adm, 'TEST WINNER');
  out := out || ' 2.checked=' || (r->>'ok');
  r := public.payout_begin(pc, adm);
  out := out || ' 3.begin=' || (r->>'ok') || ' ref_ok=' || ((r->>'ref') ~ '^po_[0-9a-f]{20}$');
  r2 := public.payout_begin(pc, adm);
  out := out || ' 4.double_send_refused=' || (not (r2->>'ok')::bool);
  r3 := public.payout_result(r->>'ref', 'success', 'TRF_x');
  select status = 'paid' and payout_status = 'sent' into ok from public.prize_claims where id = pc;
  out := out || ' 5.paid=' || ok;
  r4 := public.payout_result(r->>'ref', 'failed', null, 'late fail');
  select payout_status = 'sent' into ok from public.prize_claims where id = pc;
  out := out || ' 6.sent_stays_sent=' || ok;
  select count(*) into n from public.notifications where user_id = e.user_id and title like '₦5,000 sent%';
  out := out || ' 7.notified=' || (n = 1);
  select count(*) into n from public.audit_log where row_id = pc::text and action in ('payout_check', 'payout_send');
  out := out || ' 8.audited=' || (n = 2);
  update public.challenge_entries set score = 5, question_order = (select array_agg(gen_random_uuid()) from generate_series(1, 10)) where id = e.id;
  out := out || ' 9.below_min=' || (not private.challenge_reached_min(60::smallint, e.id));
  update public.challenge_entries set score = 6 where id = e.id;
  out := out || ' 10.at_min=' || private.challenge_reached_min(60::smallint, e.id) || ' no_min=' || private.challenge_reached_min(null, e.id);
  select id into c_id from public.challenges where published and closed_at is null and now() between starts_at and ends_at limit 1;
  if c_id is not null then
    update public.challenges set max_players = greatest((select count(*) from public.challenge_entries x where x.challenge_id = c_id), 1) where id = c_id;
    if (select count(*) from public.challenge_entries x where x.challenge_id = c_id) = 0 then
      insert into public.challenge_entries (challenge_id, user_id, status, question_order) values (c_id, adm, 'finished', '{}');
    end if;
    select id into u from auth.users where id not in (select user_id from public.challenge_entries where challenge_id = c_id) and id not in (select user_id from public.staff) limit 1;
    perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
    begin perform public.challenge_start(c_id, null, '{}'); exception when others then full_msg := sqlerrm; end;
    out := out || ' 11.full=' || (full_msg like 'This challenge is full%');
  else
    out := out || ' 11.no_live_challenge_to_test';
  end if;
  raise exception 'RESULTS%', out;
end $$;
-- Also: has_function_privilege('authenticated', 'public.payout_begin(uuid,uuid)', 'execute') = false (and the other payout_* functions).
