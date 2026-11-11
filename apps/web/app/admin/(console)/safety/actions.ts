"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const admins = () => requireStaff(["super_admin", "admin"]);
const KINDS = ["shared_phone", "many_accounts", "second_account", "phone_banned", "fair_play", "challenge_dq", "referral_abuse", "payment_abuse", "reports", "ai_strike"] as const;

const Settings = z.object({
  on: z.boolean(),
  alerts: z.boolean(),
  warn: z.coerce.number().int().min(1).max(500),
  ban: z.coerce.number().int().min(2).max(1000),
  points: z.object(Object.fromEntries(KINDS.map((k) => [k, z.coerce.number().int().min(0).max(100)])) as Record<(typeof KINDS)[number], z.ZodNumber>),
}).refine((s) => s.ban > s.warn, { message: "The ban level must be higher than the warning level" });

/** Automatic safety settings (D-145). Super admins and admins only. */
export async function saveSafety(input: unknown): Promise<ActionResult> {
  await admins();
  const p = Settings.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the settings" };
  const supabase = await createClient();
  const { error } = await supabase.from("app_settings").upsert({ key: "auto_safety", value: p.data, is_public: false }, { onConflict: "key" });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/safety");
  return { ok: true, message: p.data.on ? "Saved. Checks run every hour: a warning email first, then a ban." : "Saved. Automatic warnings and bans are off." };
}

export async function runSafetyNow(): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_safety_run");
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/safety");
  const d = (data ?? {}) as { on?: boolean; new_events?: number; warned?: number; banned?: number };
  return { ok: true, message: d.on ? `Done: ${d.new_events ?? 0} new flags, ${d.warned ?? 0} warned, ${d.banned ?? 0} banned.` : `Done: ${d.new_events ?? 0} new flags. Nobody is warned or banned while it is off.` };
}

export async function clearStudent(userId: string): Promise<ActionResult> {
  await admins();
  if (!z.string().uuid().safeParse(userId).success) return { ok: false, error: "Unknown student." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_safety_clear", { p_user: userId });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/safety");
  return { ok: true, message: "Points cleared. The student starts again from 0." };
}
