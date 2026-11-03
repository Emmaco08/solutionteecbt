# Milestone 4C: Payments (detailed plan)

Part of Phase 4 (`docs/plans/phase-4.md`). Approval for the whole phase stays `PREMIUM APPROVED`. At the end of 4C I stop for the owner's review.

## Goal
A student pays for Premium and it turns on, on the phone and (later) on the website, only after **our server** has checked the payment with Paystack or Google. Nothing in the app can unlock Premium by itself.

## Scope
**In 4C**
1. **Paystack** (direct APK now; the website uses the same server code in Phase 5): card, bank transfer, USSD.
2. **Google Play Billing** (Play Store build): code complete, checked on the server with the Google Play Developer API. It can only be tried for real after the app is in a Play Console testing track.
3. **Two app builds (flavors):** `direct` (website APK, Paystack) and `play` (Play Store, Google Play). Flag `paystack_in_play_build` (already in the database, off) can switch Paystack on in the Play build later.
4. **Checkout as in the approved prototype:** plan, access period, total shown once, discount code (direct build only), "Opening Paystack" → "Checking payment" → success screen with confetti. Play build: Google's own sheet, then "Checking payment".
5. **Redeem codes** (D-024): discount codes (% or ₦ off, Paystack only) and free-Premium-days codes ("Redeem a code" on Me). Shared codes or batches of unique codes.
6. **Admin:** Payments page (list, filters, totals, detail with a timeline of every check, "Check again", Refund), Redeem codes page (create, pause, CSV export), Plans (Play product ID + reminder to set the same price in Play Console).
7. **Refunds:** a refund (from Paystack, from Google, or the admin's Refund button) removes the Premium it gave.

**Not in 4C:** receipts by email (later, Brevo), the student web portal (Phase 5), subscriptions with auto-renew (plans are "billed once, no auto-renew"), referral discounts (4E).

## How it works
**Paystack (direct build)**
1. App calls Edge Function `paystack` → `start` with the plan and an optional code. The **server** works out the price from `plans` and the code, saves a `pending` payment with a random reference, and asks Paystack to start a transaction for that amount. The app never sends an amount.
2. The app opens Paystack's checkout page in an in-app browser tab (Chrome Custom Tab).
3. Paystack calls our webhook `paystack-webhook`. We check the `x-paystack-signature` (HMAC-SHA512 of the raw body with the secret key), then call Paystack's **verify** endpoint ourselves, and only then grant Premium. The amount and currency must match what we saved; otherwise the payment is put on "needs review" and nothing is granted.
4. When the student comes back to the app, it calls `paystack` → `check` (same verify + grant). Whichever arrives first wins; the second finds the payment already done.
5. **Idempotent:** one entitlement per payment (`entitlements.external_ref` is unique, the payment row is locked while it is processed). Every webhook is stored once (hash of the body), so repeats do nothing.

**Google Play (play build)**
1. Each plan has a Play product ID (one-time, consumable product, because a student may buy Monthly again next month).
2. The app buys with `in_app_purchase` and passes a hash of the user id as the account id.
3. App sends the purchase token to Edge Function `play-verify`. The server signs in to Google with the service account, calls `purchases.products.get`, checks it is purchased, matches the product, the package and this user's account hash, grants Premium, then **consumes** the purchase (which also acknowledges it). A token can only ever be used once.
4. Pending purchases (cash at a shop, slow bank) show "Waiting for Google"; the app retries when they complete.
5. Refunds: Edge Function `play-rtdn` receives Google's Real-time developer notifications (Pub/Sub push, URL secret token) and checks Google's **Voided Purchases API** before removing Premium. It never trusts the message body alone.

**Entitlements:** `private.grant_plan()` adds Premium after any Premium already running (so buying early never wastes days). The "Exam Season" plan ends on its fixed date (end of day, Lagos time).

## Data model changes (one migration)
- `payments`: user, provider (`paystack`/`play`), plan, reference (unique), purchase token (unique), list price, discount, amount charged, currency, status (`pending`, `success`, `failed`, `abandoned`, `needs_review`, `refunded`), code used, entitlement, verified_at, channel, trimmed provider data. Students read only their own; only server code writes.
- `payment_events`: every webhook / verify / Google answer / refund with its result (the admin timeline). Unique event key for idempotency.
- `promo_codes`: code (case-insensitive), kind (`pct`, `amt`, `days`), value, plans it works on, uses allowed, used count, new-students-only, start and end, paused, note, batch. Admin (2-step) only.
- `promo_redemptions`: code, user, payment, discount or days. One use per student per code.
- Functions: `quote_price(plan, code)` (student; server price), `redeem_code(code)` (student; free days, with a limit on wrong tries), `my_payments()`, and server-only `private.*` functions used by the Edge Functions: start payment, confirm Paystack, confirm Play, refund. Admin: payments list, codes create/batch, payment detail.
- Audit: codes, plans and refunds are logged like other admin tables.

## Files
- `supabase/migrations/<v>_payments.sql`, `supabase/tests/payments.test.sql`
- `supabase/functions/paystack/` (start, check, admin refund), `paystack-webhook/`, `play-verify/`, `play-rtdn/`, `_shared/pay.ts` (signature check, Google sign-in)
- `apps/web/app/admin/(console)/payments/`, `codes/`, plans card update, nav entries
- `apps/mobile`: Gradle flavors, `lib/features/premium/` (payment provider interface, Paystack and Play providers, checkout, checking, success, redeem sheet), Me → "Redeem a code", `in_app_purchase` dependency
- Docs: `SETUP.md` §13 (Paystack keys and webhook, Play Console, service account), `DECISIONS.md`, `PROGRESS.md`, `HANDOFF.md`

## What the owner must do (never paste keys in chat)
1. **Paystack test secret key** → Supabase dashboard → Edge Functions → Secrets → `PAYSTACK_SECRET_KEY` (starts with `sk_test_`). The public key is not needed (the server starts every payment).
2. **Paystack webhook URL** → Paystack dashboard → Settings → API Keys & Webhooks → Test Webhook URL: `https://mxeemubacnmcmmmzteax.supabase.co/functions/v1/paystack-webhook`.
3. Later, for the Play build: Play Console account, the app uploaded to internal testing, one product per plan, a service account with "View financial data" and "Manage orders", its JSON key in Supabase secrets as `GOOGLE_PLAY_SERVICE_ACCOUNT`, and a Pub/Sub topic for refunds. Steps go in SETUP §13.

## Risks
- **Play Billing cannot be tested** until the app is in a Play Console test track with products. I will say so in the report.
- **Paystack in an in-app tab:** we cannot read the tab's address, so the app checks the payment when the student returns; the webhook makes it safe even if they never return.
- **Two builds:** `flutter run` and the APK script need the flavor (`--flavor direct`); `direct` is set as the default so old commands still work.
- **Play policy:** discount codes and the website must not be mentioned in the Play build. Free-days codes in the Play build are an open question for the owner.

## Test plan
- **SQL (run here on the dev database, rolled back):** server price and codes (%, ₦, days, plan limits, expiry, max uses, one per student, wrong-try limit), grant after current Premium, Exam Season end date, Paystack confirm is idempotent (twice → one entitlement), wrong amount → needs review, Play token used once, refund removes Premium, a student cannot read others' payments or any codes, cannot call server-only functions, cannot insert entitlements.
- **Unit (Deno/Node):** webhook signature check (good, bad, missing), Google JWT building.
- **App:** price/discount display, checkout widget test (direct and play), redeem sheet, `flutter analyze`.
- **Live (owner, after keys):** Paystack test card `4084 0840 8408 4081` → Premium on the phone; repeat webhook from Paystack dashboard → still one entitlement; refund in admin → Premium gone.

## Built (2026-11-03) and changes from this plan
- Built as planned; details in D-060.
- The Card / Bank transfer / USSD choice is shown as information on checkout, because Paystack's page asks again.
- Receipts by email stay out of 4C, so the success screen does not mention one.
- New flag `codes_in_play_build` (off) for "Redeem a code" in the Play build (owner/lawyer decision).
