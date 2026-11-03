-- SolutionTee CBT · Payments and redeem codes (milestone 4C). Always rolled back.
begin;
create schema tests;
grant usage on schema tests to anon, authenticated, service_role;
create table tests.results (n serial, ok boolean, name text, detail text);
grant all on tests.results to anon, authenticated, service_role;
grant usage, select on sequence tests.results_n_seq to anon, authenticated, service_role;
create function tests.check(cond boolean, name text, detail text default null) returns void
language sql as $$ insert into tests.results (ok, name, detail) values (coalesce(cond, false), name, detail); $$;
create function tests.throws(stmt text, state text, msg text, name text) returns void
language plpgsql as $$
begin
  execute stmt;
  perform tests.check(false, name, 'no error');
exception when others then
  perform tests.check(sqlstate = state and (msg is null or sqlerrm = msg), name, sqlstate || ' ' || sqlerrm);
end $$;
create function tests.as_user(uid uuid) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  select set_config('role', 'authenticated', true);
$$;
create function tests.as_service() returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  select set_config('role', 'service_role', true);
$$;
grant execute on all functions in schema tests to anon, authenticated, service_role;
create table tests.v (k text primary key, j jsonb);
grant all on tests.v to authenticated, service_role;

-- Known prices for the test, whatever the admin has set.
update public.plans set price_kobo = 150000, duration_days = 30, ends_on = null, is_active = true where code = 'monthly';
update public.plans set price_kobo = 350000, duration_days = 90, ends_on = null, is_active = true, play_product_id = 'tst_three_months' where code = 'three_months';
update public.plans set price_kobo = 600000, duration_days = null, ends_on = (private.lagos_today() + 200), is_active = true where code = 'exam_season';

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000d1', 'pay1@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000d2', 'pay2@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000d3', 'pay3@test.local', 'authenticated', 'authenticated');

insert into public.promo_codes (code, kind, value, plan_ids, max_uses, note) values
  ('tst20', 'pct', 20, '{}', null, 'test'),
  ('TST500', 'amt', 50000, (select array_agg(id) from public.plans where code = 'three_months'), null, 'test'),
  ('TSTFREE', 'pct', 100, '{}', null, 'test'),
  ('TSTWEEK', 'days', 7, '{}', 1, 'test'),
  ('TSTOLD', 'pct', 10, '{}', null, 'test');
update public.promo_codes set starts_at = now() - interval '10 days', ends_at = now() - interval '1 day' where code = 'TSTOLD';
insert into public.promo_codes (code, kind, value, paused, note) values ('TSTPAUSE', 'pct', 10, true, 'test');

-- ---------------------------------------------------------------- student 1: reading and quoting
select tests.as_user('00000000-0000-4000-8000-0000000000d1');
select tests.check((select count(*) from public.promo_codes) = 0, 'students cannot read codes');
select tests.throws($q$ insert into public.payments (user_id, provider, plan_id, reference, list_kobo, amount_kobo)
  values ('00000000-0000-4000-8000-0000000000d1', 'paystack', 1, 'x', 0, 0) $q$, '42501', null, 'students cannot insert payments');
select tests.throws($q$ insert into public.entitlements (user_id, source, expires_at) values ('00000000-0000-4000-8000-0000000000d1', 'paystack', now() + interval '1 year') $q$,
  '42501', null, 'students cannot give themselves Premium');
select tests.throws($q$ select public.pay_start('00000000-0000-4000-8000-0000000000d1', 'monthly', null) $q$, '42501', null, 'students cannot call pay_start');
select tests.throws($q$ select public.pay_paystack_result('x', 'success', 1, 'NGN', null, '{}', 'verify') $q$, '42501', null, 'students cannot confirm a payment');
select tests.throws($q$ select public.pay_play_confirm('00000000-0000-4000-8000-0000000000d1', 'tst_three_months', 't', 'o', '{}') $q$, '42501', null, 'students cannot confirm a Play purchase');
select tests.throws($q$ select public.pay_refunded('paystack', 'x', null, null, '{}', 'k') $q$, '42501', null, 'students cannot mark refunds');
select tests.throws($q$ select public.admin_payments() $q$, '42501', null, 'students cannot list payments');
select tests.throws($q$ select private.grant_plan('00000000-0000-4000-8000-0000000000d1', 1::smallint, 'paystack', 'x') $q$, '42501', null, 'students cannot call grant_plan');

select tests.check((select (public.quote_price('monthly') ->> 'amount_kobo')::int) = 150000, 'quote: list price');
select tests.check((select (public.quote_price('monthly', ' tst20 ') ->> 'amount_kobo')::int) = 120000, 'quote: 20% code, any case and spaces');
select tests.check((select public.quote_price('monthly', 'TST500') ->> 'error') = 'wrong_plan', 'quote: code for another plan refused');
select tests.check((select (public.quote_price('three_months', 'TST500') ->> 'amount_kobo')::int) = 300000, 'quote: ₦500 off');
select tests.check((select public.quote_price('monthly', 'TSTWEEK') ->> 'error') = 'days_code', 'quote: a free-days code is pointed to Redeem');
select tests.check((select public.quote_price('monthly', 'TSTOLD') ->> 'error') = 'expired', 'quote: expired code');
select tests.check((select public.quote_price('monthly', 'TSTPAUSE') ->> 'error') = 'paused', 'quote: paused code');
select tests.check((select public.quote_price('monthly', 'NOPE') ->> 'error') = 'not_found', 'quote: unknown code');
select tests.check((select public.quote_price('nosuchplan') ->> 'error') = 'plan', 'quote: unknown plan');
select tests.check((select public.redeem_code('TST20') ->> 'error') = 'discount_code', 'redeem: a discount code is pointed to checkout');

-- ---------------------------------------------------------------- server: Paystack flow for student 1
reset role;
select tests.as_service();
insert into tests.v values ('p1', public.pay_start('00000000-0000-4000-8000-0000000000d1', 'monthly', 'TST20'));
select tests.check((select (j ->> 'amount_kobo')::int = 120000 and j ->> 'email' = 'pay1@test.local' and not (j ->> 'free')::boolean from tests.v where k = 'p1'),
  'pay_start: server price with the code, email for Paystack');
select tests.check((select status = 'pending' and provider = 'paystack' from public.payments where reference = (select j ->> 'reference' from tests.v where k = 'p1')), 'pay_start: pending payment saved');
select tests.check(not private.has_premium('00000000-0000-4000-8000-0000000000d1'), 'pending payment gives nothing');

-- not paid yet
select tests.check((select public.pay_paystack_result((select j ->> 'reference' from tests.v where k = 'p1'), 'abandoned', null, null, null, '{}', 'verify') ->> 'status') = 'pending',
  'abandoned at Paystack: still waiting');
-- wrong amount: needs review, no Premium
insert into tests.v values ('p1b', public.pay_start('00000000-0000-4000-8000-0000000000d1', 'monthly', null));
select tests.check((select public.pay_paystack_result((select j ->> 'reference' from tests.v where k = 'p1b'), 'success', 100, 'NGN', 'card', '{}', 'webhook', 'tst-key-x') ->> 'status') = 'needs_review',
  'paid a different amount: needs review');
select tests.check(not private.has_premium('00000000-0000-4000-8000-0000000000d1'), 'needs review gives no Premium');
-- right amount via webhook
select tests.check((select public.pay_paystack_result((select j ->> 'reference' from tests.v where k = 'p1'), 'success', 120000, 'NGN', 'card', '{"tst":1}', 'webhook', 'tst-key-1') ->> 'status') = 'success',
  'webhook success: payment confirmed');
select tests.check(private.has_premium('00000000-0000-4000-8000-0000000000d1'), 'Premium given after the check');
-- the same webhook again, and the app's verify call
select tests.check((select (public.pay_paystack_result((select j ->> 'reference' from tests.v where k = 'p1'), 'success', 120000, 'NGN', 'card', '{}', 'webhook', 'tst-key-1') ->> 'duplicate')::boolean),
  'same webhook twice: duplicate, ignored');
select public.pay_paystack_result((select j ->> 'reference' from tests.v where k = 'p1'), 'success', 120000, 'NGN', 'card', '{}', 'verify');
select tests.check((select count(*) from public.entitlements where user_id = '00000000-0000-4000-8000-0000000000d1') = 1, 'webhook + verify + repeat: exactly one Premium');
select tests.check((select used_count from public.promo_codes where code = 'TST20') = 1, 'code use counted once');
select tests.check((select expires_at between now() + interval '29 days 23 hours' and now() + interval '30 days 1 hour'
                    from public.entitlements where user_id = '00000000-0000-4000-8000-0000000000d1'), 'Monthly gives 30 days');
-- second purchase stacks after the first
insert into tests.v values ('p1c', public.pay_start('00000000-0000-4000-8000-0000000000d1', 'monthly', null));
select public.pay_paystack_result((select j ->> 'reference' from tests.v where k = 'p1c'), 'success', 150000, 'NGN', 'bank', '{}', 'verify');
select tests.check((select max(expires_at) between now() + interval '59 days 23 hours' and now() + interval '60 days 1 hour'
                    from public.entitlements where user_id = '00000000-0000-4000-8000-0000000000d1' and revoked_at is null), 'buying again adds after the current Premium (60 days)');
select tests.check((select public.pay_start('00000000-0000-4000-8000-0000000000d1', 'monthly', 'TST20') ->> 'error') = 'already_used', 'a code works once per student');
-- unknown reference
select tests.check((select public.pay_paystack_result('st_nope', 'success', 1, 'NGN', null, '{}', 'webhook', 'tst-key-2') ->> 'error') = 'unknown_reference', 'unknown reference refused');

-- refunds
select tests.check((select public.pay_refunded('paystack', (select j ->> 'reference' from tests.v where k = 'p1c'), null, 50000, '{}', 'tst-ref-part') ->> 'partial')::boolean, 'part refund only noted');
select tests.check((select status from public.payments where reference = (select j ->> 'reference' from tests.v where k = 'p1c')) = 'success', 'part refund keeps Premium');
select tests.check((select public.pay_refunded('paystack', (select j ->> 'reference' from tests.v where k = 'p1c'), null, null, '{}', 'tst-ref-1') ->> 'status') = 'refunded', 'full refund');
select tests.check((select revoked_at is not null from public.entitlements e join public.payments p on p.entitlement_id = e.id
                    where p.reference = (select j ->> 'reference' from tests.v where k = 'p1c')), 'full refund removes that Premium');
select tests.check(private.has_premium('00000000-0000-4000-8000-0000000000d1'), 'the other paid Premium stays');
select tests.check((select (public.pay_refunded('paystack', (select j ->> 'reference' from tests.v where k = 'p1c'), null, null, '{}', 'tst-ref-1') ->> 'duplicate')::boolean), 'same refund twice ignored');

-- 100% code: free, no Paystack
insert into tests.v values ('p2', public.pay_start('00000000-0000-4000-8000-0000000000d2', 'monthly', 'TSTFREE'));
select tests.check((select (j ->> 'free')::boolean from tests.v where k = 'p2'), '100% code: Premium at once without Paystack');
select tests.check(private.has_premium('00000000-0000-4000-8000-0000000000d2'), '100% code: Premium given');

-- Exam Season ends on its fixed date (end of day, Lagos)
insert into tests.v values ('p3', public.pay_start('00000000-0000-4000-8000-0000000000d3', 'exam_season', null));
select public.pay_paystack_result((select j ->> 'reference' from tests.v where k = 'p3'), 'success', 600000, 'NGN', 'ussd', '{}', 'verify');
select tests.check((select expires_at = ((private.lagos_today() + 201)::timestamp at time zone 'Africa/Lagos')
                    from public.entitlements where user_id = '00000000-0000-4000-8000-0000000000d3'), 'Exam Season ends at the end of its date in Lagos');
select tests.check((select public.pay_start('00000000-0000-4000-8000-0000000000d3', 'exam_season', null) ->> 'error') = 'covered',
  'cannot buy Exam Season again while it already covers the date');

-- Google Play
select tests.check((select public.pay_play_confirm('00000000-0000-4000-8000-0000000000d2', 'tst_three_months', 'tok-1', 'GPA.1', '{}') ->> 'status') = 'success', 'Play: verified purchase gives Premium');
select tests.check((select (public.pay_play_confirm('00000000-0000-4000-8000-0000000000d2', 'tst_three_months', 'tok-1', 'GPA.1', '{}') ->> 'duplicate')::boolean), 'Play: same token again is a duplicate');
select tests.check((select public.pay_play_confirm('00000000-0000-4000-8000-0000000000d3', 'tst_three_months', 'tok-1', 'GPA.1', '{}') ->> 'error') = 'token_used', 'Play: another account cannot reuse a token');
select tests.check((select count(*) from public.payments where purchase_token = 'tok-1') = 1, 'Play: one payment per token');
select tests.check((select public.pay_play_confirm('00000000-0000-4000-8000-0000000000d2', 'nope', 'tok-2', 'GPA.2', '{}') ->> 'error') = 'unknown_product', 'Play: unknown product refused');
select tests.check((select public.pay_refunded('play', null, 'tok-1', null, '{}', 'tst-void-1') ->> 'status') = 'refunded', 'Play: voided purchase refunded');

-- ---------------------------------------------------------------- free-days codes
reset role;
select tests.as_user('00000000-0000-4000-8000-0000000000d3');
select tests.check((select (public.redeem_code('tstweek') ->> 'days')::int) = 7, 'redeem: 7 free days');
select tests.check((select count(*) from public.promo_redemptions where user_id = '00000000-0000-4000-8000-0000000000d3' and days = 7) = 1, 'redeem: own redemption recorded');
select tests.check((select count(*) from public.promo_codes) = 0, 'redeem: codes stay hidden from students');
select tests.as_user('00000000-0000-4000-8000-0000000000d2');
select tests.check((select public.redeem_code('TSTWEEK') ->> 'error') = 'used_up', 'redeem: a one-use code cannot be used by a second student');
select tests.check((select count(*) from public.payments) = (select count(*) from public.payments where user_id = '00000000-0000-4000-8000-0000000000d2'), 'students read only their own payments');
select tests.throws($q$ select provider_data from public.payments $q$, '42501', null, 'students cannot read raw provider data');
-- wrong-try limit
select public.redeem_code('WRONG' || g) from generate_series(1, 10) g;
select tests.check((select public.redeem_code('TSTWEEK') ->> 'error') = 'too_many_tries', 'redeem: 10 wrong tries in an hour locks codes for a while');
select tests.check((select public.quote_price('monthly', 'TST20') ->> 'error') = 'too_many_tries', 'quote: the same limit applies at checkout');

reset role;
select n, ok, name, detail from tests.results order by n;
rollback;
