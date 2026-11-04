"use server";
import { revalidatePath } from "next/cache";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";
import type { Json } from "@solutiontee/shared/database";

const admins = () => requireStaff(["super_admin", "admin"]);

/** Save every XP rule (D-081). The server keeps numbers inside safe limits. */
export async function saveXpRules(rules: Record<string, unknown>): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_xp_settings", { p: rules as Json });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/xp");
  return { ok: true, message: "Saved. Phones get the new rules the next time the app opens." };
}

export type XpUser = { user_id: string; name: string | null; email: string; earned: number; bought: number;
  history: { amount: number; kind: string; reason: string; note: string | null; at: string; by: string | null }[] };

export async function findStudent(query: string): Promise<ActionResult<XpUser | null>> {
  await admins();
  if (query.trim().length < 2) return { ok: false, error: "Type an email or a name" };
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_xp_user", { p_query: query.trim().slice(0, 120) });
  if (error) return { ok: false, error: friendlyError(error) };
  return { ok: true, data: (data as unknown as XpUser) ?? null };
}

/** Give (+) or take (−) XP with a reason the student sees. */
export async function adjustXp(userId: string, amount: number, reason: string): Promise<ActionResult> {
  await admins();
  if (!Number.isInteger(amount) || amount === 0) return { ok: false, error: "Choose an amount (use − to take XP away)" };
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_xp_adjust", { p_user: userId, p_amount: amount, p_reason: reason.slice(0, 300) });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/xp");
  return { ok: true, message: amount > 0 ? `${amount} XP given.` : `${-amount} XP taken.` };
}
