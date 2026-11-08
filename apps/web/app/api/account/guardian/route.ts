import { z } from "zod";
import { createServiceClient } from "@/lib/supabase/server";
import { env, hasBrevo, hasServiceKey } from "@/lib/env";
import { sendEmail } from "@/lib/email";
import { guardianNoticeEmail } from "@/lib/email-templates";
import { allowSend, clientIp, EMAIL_RULE, json } from "@/lib/auth-email";
import { ageFromYear, hashGuardianToken, newGuardianToken } from "@/lib/guardian";

const Body = z.object({ email: z.string().trim().toLowerCase().max(254) });

/**
 * POST /api/account/guardian  { email }   Authorization: Bearer <access token>
 * A student aged 13 to 17 gives a parent's or guardian's email (D-109). We save it and send the welcome notice
 * with a link that turns the account off. The parent does not need to approve; the notice is the consent record.
 * Can be sent again (e.g. a typo) up to 5 times; the rate limit for notices also applies.
 */
export async function POST(req: Request) {
  if (!hasServiceKey() || !hasBrevo()) return json({ error: "Not available right now. Try again later." }, 503);
  const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const parsed = Body.safeParse(await req.json().catch(() => null));
  if (!token || !parsed.success || !EMAIL_RULE.test(parsed.data.email)) return json({ error: "Enter a valid email, like mum@gmail.com" }, 400);
  const email = parsed.data.email;

  const svc = await createServiceClient();
  const { data: who, error } = await svc.auth.getUser(token);
  const user = who?.user;
  if (error || !user?.email) return json({ error: "Please log in again." }, 401);
  if (email === user.email.toLowerCase()) return json({ error: "Use your parent's or guardian's email, not your own." }, 400);

  const { data: p } = await svc.from("profiles").select("full_name, birth_year").eq("id", user.id).maybeSingle();
  const age = p?.birth_year ? ageFromYear(p.birth_year) : null;
  if (age === null || age < 13 || age >= 18) return json({ error: "This step is only for students aged 13 to 17." }, 409);

  const { data: old } = await svc.from("guardian_consents").select("send_count, withdrawn_at").eq("user_id", user.id).maybeSingle();
  if (old?.withdrawn_at) return json({ error: "This account was turned off by a parent or guardian." }, 403);
  if ((old?.send_count ?? 0) >= 5) return json({ error: "We have sent this email 5 times. Contact support to change it." }, 429);

  const gate = await allowSend("notice", email, clientIp(req));
  if (!gate.ok) return json({ error: gate.error }, gate.status);

  const { data: s } = await svc.from("app_settings").select("value").eq("key", "guardian").maybeSingle();
  const version = String((s?.value as { policy_version?: string } | null)?.policy_version ?? "2026-11-08");
  const link = newGuardianToken();
  const now = new Date().toISOString();
  const { error: e2 } = await svc.from("guardian_consents").upsert(
    { user_id: user.id, guardian_email: email, child_birth_year: p!.birth_year!, method: "email_notice", policy_version: version, token_hash: hashGuardianToken(link), updated_at: now },
    { onConflict: "user_id" },
  );
  if (e2) return json({ error: "Could not save. Try again." }, 500);

  const stop = `${env.siteUrl.replace(/\/+$/, "")}/guardian/stop?t=${link}`;
  const sent = await sendEmail({ to: email, ...guardianNoticeEmail(String(p?.full_name ?? ""), user.email, stop), from: "info", tags: ["guardian-notice"] });
  if (!sent.ok) return json({ error: "We could not send the email. Check the address and try again." }, 502);
  await svc.from("guardian_consents").update({ sent_at: now, send_count: (old?.send_count ?? 0) + 1 }).eq("user_id", user.id);
  return json({ ok: true, message: `We sent a welcome email to ${email}.` });
}
