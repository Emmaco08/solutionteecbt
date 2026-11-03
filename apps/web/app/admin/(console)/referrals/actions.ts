"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const money = () => requireStaff(["super_admin", "admin"]);

const Rules = z.object({
  enabled: z.boolean(),
  pct_per_friend: z.coerce.number().int().min(1, "At least 1% per friend").max(100),
  max_pct: z.coerce.number().int().min(0).max(100),
  count_on: z.enum(["test", "premium"]),
  cash_every: z.coerce.number().int().min(0).max(1000),
  cash_naira: z.coerce.number().int().min(0).max(1_000_000),
  monthly_cap: z.coerce.number().int().min(1).max(1000),
});
export type RulesInput = z.infer<typeof Rules>;

/** Referral rules (D-031, D-078). The server keeps every value inside safe limits too. */
export async function saveRules(form: FormData): Promise<ActionResult> {
  await money();
  const p = Rules.safeParse({ ...Object.fromEntries(form), enabled: form.get("enabled") === "on" });
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the rules" };
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_referral_settings", { p: p.data });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/referrals");
  return { ok: true, message: "Saved. New friends count with these rules." };
}

/** After paying by bank transfer: mark the reward paid (the student is told). */
export async function markPaid(id: string, note: string): Promise<ActionResult> {
  await money();
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_referral_paid", { p_reward: id, p_note: note.slice(0, 500) || undefined });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/referrals");
  return { ok: true, message: "Marked paid. The student was told." };
}
