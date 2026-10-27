# Auth emails — how sign-up, codes and password reset work (contract for the app and web app)

SolutionTee sends every account email itself, through Brevo, with our own templates and senders. Supabase is not asked to send these emails. Supabase Auth still owns the accounts, codes and sessions.

Base URL: the website (`http://localhost:3000` in development, `https://solutiontee.com` later). All bodies are JSON.

## Sign up
1. `POST /api/auth/sign-up` with `{ email, password, fullName, consent: true, referralCode? }`
   - Password: 8–72 characters, with letters and numbers. `consent` must be `true` (Terms + Privacy).
   - `200 { ok, codeLength, message }`: a one-time code was emailed (from noreply@mail.solutiontee.com).
   - `409`: the email already has an account. For an account still waiting for its code, a resend only works with the same password.
   - `429`: too soon, or too many attempts (see Limits). `400`: the form is wrong (the `error` text is ready to show).
2. The app shows `codeLength` code boxes (the project currently uses 8; the dashboard can be set to 6).
3. `supabase.auth.verifyOtp({ email, token, type: "signup" })` confirms the email and signs the user in.
4. **Resend:** call `/api/auth/sign-up` again with the same details. The old code stops working.
5. `POST /api/auth/notify` with `{ event: "welcome" }` and header `Authorization: Bearer <access_token>` sends the welcome email (only once per account).

## Forgot password
1. `POST /api/auth/forgot-password` with `{ email }` always answers `200` with the same message, so nobody can test which emails have accounts. A code is sent only to confirmed, non-banned accounts.
2. `supabase.auth.verifyOtp({ email, token, type: "recovery" })` signs the user in.
3. `supabase.auth.updateUser({ password })` saves the new password.
4. `POST /api/auth/notify` with `{ event: "password_changed" }` and the Bearer token emails a security notice.

## Limits (database function `email_send_allowed`, HMAC-hashed email/IP only)
- 1 code per email per kind per 60 s
- 5 emails per email address per hour
- 20 per network (IP) per hour
- 280 per day in total (the Brevo free plan is 300 a day; the rest is kept for staff invites)

## Staff invites
Sent from the admin (Staff page) with a one-time link to `/admin/accept` (from info@mail.solutiontee.com).

## Testing without sending email
Run the dev server with `EMAIL_TRANSPORT=log` (development only; ignored in production). Emails are written to the server log instead of being sent. The subject line shows the code.
