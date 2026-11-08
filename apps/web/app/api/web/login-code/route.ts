import { z } from "zod";
import { createServiceClient } from "@/lib/supabase/server";
import { hasBrevo, hasServiceKey } from "@/lib/env";
import { sendEmail } from "@/lib/email";
import { webLoginCodeEmail } from "@/lib/email-templates";
import { allowSend, clientIp, EMAIL_RULE, json } from "@/lib/auth-email";

const Body = z.object({ email: z.string().trim().toLowerCase().max(254) });

/**
 * POST /api/web/login-code  { email }   (payment website, D-114)
 * Emails a log-in code to an existing, confirmed account (never creates one: a "recovery" code, verified in the browser
 * with verifyOtp type "recovery", which signs the student in). Same answer whether or not the email has an account.
 */
export async function POST(req: Request) {
  if (!hasServiceKey() || !hasBrevo()) return json({ error: "Log-in is not available right now. Try again later." }, 503);
  const parsed = Body.safeParse(await req.json().catch(() => null));
  if (!parsed.success || !EMAIL_RULE.test(parsed.data.email)) return json({ error: "Enter a valid email, like tolu@gmail.com" }, 400);
  const { email } = parsed.data;
  const same = { ok: true, message: `If ${email} has a SolutionTee account, we sent a code to it.` };

  const gate = await allowSend("recovery", email, clientIp(req));
  if (!gate.ok) return json({ error: gate.error }, gate.status);

  const svc = await createServiceClient();
  const { data, error } = await svc.auth.admin.generateLink({ type: "recovery", email });
  if (error || !data.user?.email_confirmed_at) return json(same);
  if (data.user.banned_until && new Date(data.user.banned_until) > new Date()) return json(same);

  const sent = await sendEmail({ to: email, ...webLoginCodeEmail(data.properties.email_otp), from: "noreply", tags: ["web-login-code"] });
  if (!sent.ok) return json({ error: "We could not send your code. Try again in a minute." }, 502);
  return json({ ...same, codeLength: data.properties.email_otp.length });
}
