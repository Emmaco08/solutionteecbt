"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff, ROLE_LABEL } from "@/lib/auth";
import { createClient, createServiceClient } from "@/lib/supabase/server";
import { env, hasServiceKey } from "@/lib/env";
import { sendEmail, inviteEmail } from "@/lib/email";
import { friendlyError, type ActionResult } from "@/lib/result";

const Role = z.enum(["super_admin", "admin", "editor", "teacher"]);
const Invite = z.object({ email: z.string().trim().toLowerCase().email("Enter a valid email"), role: Role });

/** Super admin only. Creates (or reuses) the account, adds the staff role through RLS, and emails a one-time link. */
export async function inviteStaff(form: FormData): Promise<ActionResult<{ link?: string }>> {
  const me = await requireStaff(["super_admin"]);
  const p = Invite.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  if (!hasServiceKey()) return { ok: false, error: "The server is missing SUPABASE_SECRET_KEY." };
  const svc = await createServiceClient();
  const redirectTo = `${env.siteUrl}/admin/accept`;

  let gen = await svc.auth.admin.generateLink({ type: "invite", email: p.data.email, options: { redirectTo } });
  // Existing account (e.g. a student): send a password-reset style link instead.
  if (gen.error && /already|registered|exists/i.test(gen.error.message)) gen = await svc.auth.admin.generateLink({ type: "recovery", email: p.data.email, options: { redirectTo } });
  if (gen.error || !gen.data.user) return { ok: false, error: gen.error?.message ?? "Could not create the invite" };

  // Role insert uses the caller's own session, so RLS re-checks "super admin with 2-step".
  const supabase = await createClient();
  const { error } = await supabase.from("staff").upsert({ user_id: gen.data.user.id, role: p.data.role, created_by: me.id });
  if (error) return { ok: false, error: friendlyError(error) };

  const type = gen.data.properties.verification_type === "recovery" ? "recovery" : "invite";
  const link = `${env.siteUrl}/admin/accept?token_hash=${encodeURIComponent(gen.data.properties.hashed_token)}&type=${type}`;
  const sent = await sendEmail(p.data.email, "You're invited to the SolutionTee admin", inviteEmail(link, ROLE_LABEL[p.data.role], me.name));
  revalidatePath("/admin", "layout");
  return sent.ok
    ? { ok: true, message: `Invite sent to ${p.data.email}.` }
    : { ok: true, message: `Role saved, but the email could not be sent (${sent.error}). Copy the link and send it yourself.`, data: { link } };
}

export async function changeRole(userId: string, role: string): Promise<ActionResult> {
  const me = await requireStaff(["super_admin"]);
  const r = Role.safeParse(role);
  if (!r.success) return { ok: false, error: "Unknown role" };
  if (userId === me.id) return { ok: false, error: "You can't change your own role." };
  const supabase = await createClient();
  const { error } = await supabase.from("staff").update({ role: r.data }).eq("user_id", userId);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true };
}

export async function removeStaff(userId: string): Promise<ActionResult> {
  const me = await requireStaff(["super_admin"]);
  if (userId === me.id) return { ok: false, error: "You can't remove yourself." };
  const supabase = await createClient();
  const { error } = await supabase.from("staff").delete().eq("user_id", userId);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true };
}
