"use server";
import { requireStaff } from "@/lib/auth";
import { sendEmail } from "@/lib/email";
import { testEmail } from "@/lib/email-templates";
import { allowSend } from "@/lib/auth-email";
import type { ActionResult } from "@/lib/result";

/** Sends a test email to the signed-in staff member's own address (never to anyone else). */
export async function sendTestToMe(): Promise<ActionResult> {
  const me = await requireStaff(["super_admin", "admin"]);
  if (!me.email) return { ok: false, error: "Your account has no email." };
  const gate = await allowSend("test", me.email, null);
  if (!gate.ok) return { ok: false, error: gate.error };
  const r = await sendEmail({ to: me.email, ...testEmail(me.name.split(" ")[0] ?? me.name), from: "info", tags: ["test"] });
  return r.ok ? { ok: true, message: `Test email sent to ${me.email}. Check your inbox (and spam).` } : { ok: false, error: r.error ?? "Could not send" };
}
