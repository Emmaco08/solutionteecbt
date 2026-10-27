import { z } from "zod";
import { createServiceClient } from "@/lib/supabase/server";
import { hasBrevo, hasServiceKey } from "@/lib/env";
import { sendEmail } from "@/lib/email";
import { resetCodeEmail } from "@/lib/email-templates";
import { allowSend, clientIp, json, EMAIL_RULE } from "@/lib/auth-email";

const Body = z.object({ email: z.string().trim().toLowerCase().regex(EMAIL_RULE, "Enter a valid email address").max(254) });

/**
 * POST /api/auth/forgot-password  { email }
 * Always answers the same way (so nobody can check which emails have accounts). If the account exists and is
 * confirmed, emails a one-time code. The app then calls supabase.auth.verifyOtp({ email, token, type: "recovery" })
 * and supabase.auth.updateUser({ password }), then POST /api/auth/password-changed.
 */
export async function POST(req: Request) {
  if (!hasServiceKey() || !hasBrevo()) return json({ error: "Password reset is not available right now." }, 503);
  const parsed = Body.safeParse(await req.json().catch(() => null));
  if (!parsed.success) return json({ error: parsed.error.issues[0]?.message ?? "Enter a valid email address" }, 400);
  const { email } = parsed.data;
  const same = { ok: true, message: `If ${email} has a SolutionTee account, we sent a code to it.` };

  const gate = await allowSend("recovery", email, clientIp(req));
  if (!gate.ok) return json({ error: gate.error }, gate.status);

  const svc = await createServiceClient();
  const { data, error } = await svc.auth.admin.generateLink({ type: "recovery", email });
  // Unknown email or an unconfirmed sign-up: say the same thing, send nothing.
  if (error || !data.user?.email_confirmed_at) return json(same);
  if (data.user.banned_until && new Date(data.user.banned_until) > new Date()) return json(same);

  const sent = await sendEmail({ to: email, ...resetCodeEmail(data.properties.email_otp), from: "noreply", tags: ["reset-code"] });
  if (!sent.ok) return json({ error: "We could not send your code. Try again in a minute." }, 502);
  return json({ ...same, codeLength: data.properties.email_otp.length });
}
