"use server";
import { revalidatePath } from "next/cache";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const admins = () => requireStaff(["super_admin", "admin"]);

/** Ban (optionally with every account on the same phone) or unban. */
export async function ban(userId: string, banned: boolean, reason: string, linked: boolean): Promise<ActionResult> {
  await admins();
  if (banned && reason.trim().length < 3) return { ok: false, error: "Write the reason (the student sees it)" };
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_ban", { p_user: userId, p_banned: banned, p_reason: reason.slice(0, 500) || undefined, p_linked: linked });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/fraud");
  const n = (data as { accounts?: number } | null)?.accounts ?? 1;
  return { ok: true, message: banned ? `${n} ${n === 1 ? "account" : "accounts"} banned.` : "Ban removed." };
}

/** Let a second account use a shared phone (for example brothers and sisters), or stop it again. */
export async function allowOnPhone(hash: string, userId: string, allowed: boolean): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_device_allow", { p_hash: hash, p_user: userId, p_allowed: allowed });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/fraud");
  return { ok: true, message: allowed ? "Allowed on this phone." : "No longer allowed on this phone." };
}

export async function decideBanAppeal(id: string, accept: boolean, note: string): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_ban_appeal", { p_appeal: id, p_accept: accept, p_note: note.slice(0, 500) || undefined });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/fraud");
  return { ok: true, message: accept ? "Accepted. The account is open again." : "Rejected. The ban stays." };
}
