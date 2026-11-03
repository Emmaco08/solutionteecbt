# 4E3 — Referrals, one account per phone, bans (detail of `phase-4e.md` §4E3)

## Data
- `profiles.referral_code` (unique, `NAME-7K3P`, made on sign-up and for existing students).
- `device_accounts (device_hash, user_id, first_seen, last_seen, allowed)`: the app registers the hashed Android ID after
  sign-in. The first account on a phone owns it; later accounts see "This phone already has an account" unless the
  admin allows them (siblings) in Fraud & bans.
- `referrals (referrer, friend unique, status pending|counted|blocked, reason, counted_at, spent_payment)`; made from the
  sign-up `referral_code`. Counts when: friend's email is verified, the friend finishes one practice test (or buys
  Premium, if the admin chooses), the friend is the first account on their phone, the phone is not the referrer's, the
  referrer is under the monthly limit. Self-referral and shared phones → blocked with a reason.
- `referral_rewards (user, kind cash, amount, milestone, status due|claimed|paid|cancelled, bank details, receipt)`:
  every `cash_at` counted friends (default 30) = ₦`cash_naira` (default 5,000), paid by hand after review.
- `ban_appeals (user, reason, status, note)`: one per ban, within 14 days.
- Settings `app_settings.referrals`: on, % per friend (10), max % (100), counts on test|premium, cash every N (30),
  cash amount (5,000), monthly limit (20).

## Rules on the server
- Discount: when no promo code is used, `private.price` gives `min(unspent friends × %, max %)` off (Paystack /
  website / direct APK; Google Play prices are set by Play). Paying spends those friends (trigger on payments).
- Bans: `admin_ban` bans the student and, if chosen, every account on the same phone; unpaid referral cash and
  challenge prizes are cancelled; audit log. `my_status()` tells the app: banned (+ reason, appeal) / phone taken.

## App
Invite friends (code, WhatsApp / share, discount meter, cash progress, friends list), entry on Home and Me; banned
screen (one appeal); phone-taken screen; device registered after sign-in.

## Admin
Referrals: rules with live preview, cash rewards due (mark paid), top referrers, recent referrals.
Fraud & bans: phones with more than one account (allow / ban all), banned students, ban appeals.

## Tests
DB: code made; friend counts once, only on another phone, self-referral blocked, monthly limit, discount by the server
and spent on payment, cash milestone, ban cancels unpaid rewards, banned student blocked, appeal once.
App: invite screen, banned and phone-taken screens.

## Risks
Android ID changes after a factory reset (a new phone to us). No SMS check yet (assumption 3 in `phase-4e.md`).
