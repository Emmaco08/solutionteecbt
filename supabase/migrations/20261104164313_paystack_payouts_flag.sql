-- Prize payouts by Paystack Transfer stay OFF until the business is registered with Paystack (owner, 2026-11-04).
-- Off: Admin → Winners & payouts works as before (pay by hand, then "I paid it myself"); the server refuses payout sends.
insert into public.feature_flags (key, enabled, description)
values ('paystack_payouts', false, 'Pay challenge prizes with Paystack Transfers from Winners & payouts. Turn on only after Paystack registers the business, transfer OTP is off and the balance is topped up (SETUP §18).')
on conflict (key) do nothing;
