import { z } from "zod";
import { createServiceClient } from "@/lib/supabase/server";
import { hasBrevo, hasServiceKey } from "@/lib/env";
import { sendEmail } from "@/lib/email";
import { passwordChangedEmail, welcomeEmail } from "@/lib/email-templates";
import { allowSend, clientIp, json } from "@/lib/auth-email";

const Body = z.object({ event: z.enum(["welcome", "password_changed"]) });

/**
 * POST /api/auth/notify  { event: "welcome" | "password_changed" }   Authorization: Bearer <access token>
 * Sends a notice to the signed-in user's own email. "welcome" is sent once per account.
 * The token is checked with Supabase, so nobody can trigger emails to other people.
 */
export async function POST(req: Request) {
  if (!hasServiceKey() || !hasBrevo()) return json({ error: "Not available" }, 503);
  const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const parsed = Body.safeParse(await req.json().catch(() => null));
  if (!token || !parsed.success) return json({ error: "Bad request" }, 400);

  const svc = await createServiceClient();
  const { data: who, error } = await svc.auth.getUser(token);
  const user = who?.user;
  if (error || !user?.email || !user.email_confirmed_at) return json({ error: "Not signed in" }, 401);

  const gate = await allowSend("notice", user.email, clientIp(req));
  if (!gate.ok) return json({ ok: true, skipped: true }); // notices are best-effort; never block the app

  if (parsed.data.event === "welcome") {
    if (user.app_metadata?.welcome_sent) return json({ ok: true, skipped: true });
    const name = String(user.user_metadata?.full_name ?? "");
    const sent = await sendEmail({ to: user.email, ...welcomeEmail(name), from: "info", tags: ["welcome"] });
    if (sent.ok) await svc.auth.admin.updateUserById(user.id, { app_metadata: { ...user.app_metadata, welcome_sent: new Date().toISOString() } });
    return json({ ok: sent.ok });
  }
  const when = new Date().toLocaleString("en-GB", { timeZone: "Africa/Lagos", dateStyle: "medium", timeStyle: "short" }) + " (Lagos time)";
  const sent = await sendEmail({ to: user.email, ...passwordChangedEmail(when), from: "noreply", tags: ["password-changed"] });
  return json({ ok: sent.ok });
}
