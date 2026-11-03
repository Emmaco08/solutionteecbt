"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff, canManage } from "@/lib/auth";
import { createClient, createServiceClient } from "@/lib/supabase/server";
import { hasServiceKey } from "@/lib/env";
import { friendlyError, type ActionResult } from "@/lib/result";

export type UserDetail = {
  id: string; email: string; created_at: string; last_sign_in_at: string | null; email_confirmed: boolean; is_premium: boolean;
  staff_role: string | null;
  profile: { full_name: string | null; phone: string | null; state: string | null; school: string | null; target_exams: string[]; jamb_subjects: string[]; target_score: number | null; banned_at: string | null; ban_reason: string | null } | null;
  entitlements: { id: string; source: string; plan: string | null; starts_at: string; expires_at: string; revoked_at: string | null; reason: string | null }[];
};

async function admin() {
  const staff = await requireStaff();
  if (!canManage(staff.role)) throw new Error("Only admins can manage students.");
  return staff;
}

export async function getUserDetail(id: string): Promise<ActionResult<UserDetail>> {
  try { await admin(); } catch (e) { return { ok: false, error: (e as Error).message }; }
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_user_detail", { p_user: id });
  if (error || !data) return { ok: false, error: friendlyError(error) };
  return { ok: true, data: data as unknown as UserDetail };
}

const Grant = z.object({
  user_id: z.string().uuid(),
  days: z.coerce.number().int().min(1).max(400),
  reason: z.string().trim().min(3, "Give a reason (at least 3 characters)").max(500),
});

export async function grantPremium(form: FormData): Promise<ActionResult> {
  let staff;
  try { staff = await admin(); } catch (e) { return { ok: false, error: (e as Error).message }; }
  const p = Grant.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const supabase = await createClient();
  // Extend from the current end date if the student already has Premium.
  const { data: current } = await supabase.from("entitlements").select("expires_at").eq("user_id", p.data.user_id).is("revoked_at", null)
    .gt("expires_at", new Date().toISOString()).order("expires_at", { ascending: false }).limit(1).maybeSingle();
  const start = current ? new Date(current.expires_at) : new Date();
  const expires = new Date(start.getTime() + p.data.days * 86400000);
  const { error } = await supabase.from("entitlements").insert({
    user_id: p.data.user_id, source: "manual", expires_at: expires.toISOString(), reason: p.data.reason, granted_by: staff.id,
    // A new grant starts at the database's "now" (avoids laptop/server clock skew); an extension starts when the current one ends.
    ...(current ? { starts_at: start.toISOString() } : {}),
  });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true, message: `Premium given until ${expires.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" })}.` };
}

export async function revokeEntitlement(id: string): Promise<ActionResult> {
  let staff;
  try { staff = await admin(); } catch (e) { return { ok: false, error: (e as Error).message }; }
  const supabase = await createClient();
  const { error } = await supabase.from("entitlements").update({ revoked_at: new Date().toISOString(), revoked_by: staff.id }).eq("id", id).is("revoked_at", null);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true };
}

export async function setBan(userId: string, banned: boolean, reason: string, linked = false): Promise<ActionResult> {
  try { await admin(); } catch (e) { return { ok: false, error: (e as Error).message }; }
  const supabase = await createClient();
  // D-078: the server bans (questions, study, AI, payments, challenges, referrals are refused; unpaid rewards and prizes
  // are cancelled; logged). Sign-in stays open so the student sees the ban screen and can send one appeal.
  const { error } = await supabase.rpc("admin_ban", { p_user: userId, p_banned: banned, p_reason: reason || undefined, p_linked: linked });
  if (error) return { ok: false, error: friendlyError(error) };
  // Older bans also blocked sign-in at the Auth level; unbanning clears that.
  if (!banned && hasServiceKey()) {
    await (await createServiceClient()).auth.admin.updateUserById(userId, { ban_duration: "none" });
  }
  revalidatePath("/admin", "layout");
  return { ok: true };
}
