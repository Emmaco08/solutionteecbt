import { z } from "zod";
import { createClient as createPlainClient } from "@supabase/supabase-js";
import { createServiceClient } from "@/lib/supabase/server";
import { env, hasBrevo, hasServiceKey } from "@/lib/env";
import { sendEmail } from "@/lib/email";
import { signupCodeEmail } from "@/lib/email-templates";
import { allowSend, clientIp, json, EMAIL_RULE, PASSWORD_RULE } from "@/lib/auth-email";

const Body = z.object({
  email: z.string().trim().toLowerCase().regex(EMAIL_RULE, "Enter a valid email address").max(254),
  password: z.string().regex(PASSWORD_RULE, "Use at least 8 characters with letters and numbers"),
  // The app asks for the name in profile setup (prototype order); the website may send it here.
  fullName: z.string().trim().max(120).optional().default(""),
  consent: z.literal(true, { message: "Please accept the Terms and Privacy Policy" }),
  referralCode: z.string().trim().max(32).optional(),
  // D-079: the phone's hashed ids; sign-up is refused on a banned phone.
  deviceIds: z.array(z.string().regex(/^[0-9a-f]{64}$/)).max(2).optional(),
});

/**
 * POST /api/auth/sign-up  { email, password, fullName?, consent: true, referralCode? }
 * Creates the account (unconfirmed) and emails a one-time code. Calling it again before the code is used
 * sends a fresh code (the old one stops working). The app then calls supabase.auth.verifyOtp({ email, token, type: "signup" }).
 */
export async function POST(req: Request) {
  if (!hasServiceKey() || !hasBrevo()) return json({ error: "Sign-up is not available right now." }, 503);
  const parsed = Body.safeParse(await req.json().catch(() => null));
  if (!parsed.success) return json({ error: parsed.error.issues[0]?.message ?? "Check the form" }, 400);
  const { email, password, fullName, referralCode } = parsed.data;

  const svc = await createServiceClient();
  if (parsed.data.deviceIds?.length) {
    const { data: phone } = await svc.rpc("device_status", { p_ids: parsed.data.deviceIds });
    if ((phone as { banned?: boolean } | null)?.banned) {
      await svc.from("device_events").insert({ device_hash: parsed.data.deviceIds[0], kind: "banned_phone_signup", detail: email });
      return json({ error: "This phone is banned from SolutionTee CBT, so no account can be created on it. You can send an appeal in the app." }, 403);
    }
  }
  const { data: status } = await svc.rpc("auth_user_status", { p_email: email });
  if (status === "confirmed") return json({ error: "This email already has an account. Log in, or reset your password." }, 409);
  if (status === "unconfirmed") {
    // A resend for an account waiting for its code: only for the same person. Supabase answers
    // "Email not confirmed" only when the password is right (a second sign-up never changes the password).
    const probe = await createPlainClient(env.supabaseUrl, env.supabasePublishableKey, { auth: { persistSession: false } })
      .auth.signInWithPassword({ email, password });
    if (!/not confirmed/i.test(probe.error?.message ?? ""))
      return json({ error: "This email is waiting to be confirmed. Use the same password as before." }, 409);
  }

  // Rate limit only real sends (after the 'already has an account' answer).
  const gate = await allowSend("signup", email, clientIp(req));
  if (!gate.ok) return json({ error: gate.error }, gate.status);

  const { data, error } = await svc.auth.admin.generateLink({
    type: "signup", email, password,
    options: { data: { full_name: fullName || null, referral_code: referralCode || null, terms_accepted_at: new Date().toISOString() } },
  });
  if (error) {
    if (/already been registered|already exists/i.test(error.message))
      return json({ error: "This email already has an account. Log in, or reset your password." }, 409);
    return json({ error: "We could not create your account. Try again." }, 400);
  }
  const code = data.properties.email_otp;
  const mail = signupCodeEmail(fullName, code);
  const sent = await sendEmail({ to: email, ...mail, from: "noreply", tags: ["signup-code"] });
  if (!sent.ok) return json({ error: "We could not send your code. Try again in a minute." }, 502);
  return json({ ok: true, codeLength: code.length, message: `We sent a ${code.length}-digit code to ${email}.` });
}
