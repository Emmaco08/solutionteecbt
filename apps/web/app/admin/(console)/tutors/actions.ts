"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const admins = () => requireStaff(["super_admin", "admin"]);
const opt = (max: number) => z.string().trim().max(max).optional().transform((v) => (v ? v : null));
const phone = z.string().trim().optional().transform((v) => (v ? v.replace(/[\s-]/g, "") : null))
  .refine((v) => v === null || /^\+?[0-9]{10,15}$/.test(v), "Write the number with digits only, like +2348012345678");

const Tutor = z.object({
  id: z.string().uuid().optional(),
  name: z.string().trim().min(2, "Write the tutor's name").max(80),
  subjects: opt(200), bio: opt(600), whatsapp: phone, phone: phone, active: z.boolean(),
});
export async function saveTutor(input: unknown): Promise<ActionResult> {
  await admins();
  const p = Tutor.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const { id, ...row } = p.data;
  const supabase = await createClient();
  const { error } = id ? await supabase.from("tutors").update(row).eq("id", id) : await supabase.from("tutors").insert(row);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/tutors");
  return { ok: true, message: "Tutor saved." };
}

const Plan = z.object({
  id: z.string().uuid().optional(),
  name: z.string().trim().min(2, "Give the plan a name").max(80),
  description: opt(400),
  price_naira: z.coerce.number().min(50, "The price must be at least ₦50").max(1_000_000),
  days: z.coerce.number().int().min(1).max(366),
  sessions: z.coerce.number().int().min(0).max(200).optional(),
  active: z.boolean(),
  sort: z.coerce.number().int().min(0).max(999).optional(),
  play_product_id: z.string().trim().toLowerCase().max(100).optional().transform((v) => (v ? v : null))
    .refine((v) => v === null || /^[a-z0-9._]{1,100}$/.test(v), "Google Play product ids use small letters, numbers, dots and underscores"),
});
export async function savePlan(input: unknown): Promise<ActionResult> {
  await admins();
  const p = Plan.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const { id, price_naira, sessions, sort, ...rest } = p.data;
  const row = { ...rest, price_kobo: Math.round(price_naira * 100), sessions: sessions ? sessions : null, sort: sort ?? 0 };
  const supabase = await createClient();
  const { error } = id ? await supabase.from("tutor_plans").update(row).eq("id", id) : await supabase.from("tutor_plans").insert(row);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/tutors");
  return { ok: true, message: rest.active ? "Plan saved. Students see it in the app." : "Plan saved (hidden)." };
}

export async function deletePlan(id: string): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { count } = await supabase.from("tutor_subscriptions").select("id", { count: "exact", head: true }).eq("plan_id", id);
  if (count) return { ok: false, error: "Students bought this plan. Hide it instead (untick Shown)." };
  const { error } = await supabase.from("tutor_plans").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/tutors");
  return { ok: true, message: "Plan deleted." };
}
