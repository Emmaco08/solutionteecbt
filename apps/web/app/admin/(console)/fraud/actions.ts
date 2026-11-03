"use server";
import { revalidatePath } from "next/cache";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";
import { hasBrevo } from "@/lib/env";
import { sendEmail } from "@/lib/email";
import { phoneAppealEmail } from "@/lib/email-templates";

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

/** Ban a phone: all its ids and every account on it. No account can be made or used there; appeal only. */
export async function banPhone(hash: string, reason: string): Promise<ActionResult> {
  await admins();
  if (reason.trim().length < 3) return { ok: false, error: "Write the reason (the person sees it)" };
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_ban_device", { p_hash: hash, p_reason: reason.slice(0, 500) });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/fraud");
  const n = (data as { accounts?: number } | null)?.accounts ?? 0;
  return { ok: true, message: `Phone banned. ${n} ${n === 1 ? "account" : "accounts"} banned with it.` };
}

export async function unbanPhone(hash: string): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_unban_device", { p_hash: hash });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/fraud");
  const n = (data as { accounts?: number } | null)?.accounts ?? 0;
  return { ok: true, message: `Phone ban lifted.${n ? ` ${n} ${n === 1 ? "account" : "accounts"} opened again.` : ""}` };
}

/** Decide a banned phone's appeal and email the answer (Brevo). */
export async function decidePhoneAppeal(id: string, accept: boolean, note: string): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_device_appeal", { p_id: id, p_accept: accept, p_note: note.slice(0, 500) || undefined });
  if (error) return { ok: false, error: friendlyError(error) };
  const email = (data as { email?: string } | null)?.email;
  let mailed = false;
  if (email && hasBrevo()) {
    const sent = await sendEmail({ to: email, ...phoneAppealEmail(accept, note), from: "noreply", tags: ["phone-appeal"] });
    mailed = sent.ok;
  }
  revalidatePath("/admin/fraud");
  return { ok: true, message: `${accept ? "Accepted. The phone can be used again." : "Rejected. The ban stays."}${mailed ? ` We emailed ${email}.` : email ? ` Email ${email} yourself (email is not set up).` : ""}` };
}
