"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const admins = () => requireStaff(["super_admin", "admin"]);
const on = z.enum(["on"]).optional().transform((v) => v === "on");

// ---------------- Plans
const Plan = z.object({
  id: z.coerce.number().int().positive(),
  name: z.string().trim().min(2).max(60),
  description: z.string().trim().max(200),
  price_naira: z.coerce.number().min(0).max(1_000_000),
  duration_days: z.union([z.literal("").transform(() => null), z.coerce.number().int().min(1).max(1000)]),
  ends_on: z.union([z.literal("").transform(() => null), z.string().regex(/^\d{4}-\d{2}-\d{2}$/)]),
  play_product_id: z.string().trim().max(100).transform((v) => v || null),
  is_active: on,
}).refine((p) => p.duration_days !== null || p.ends_on !== null, { message: "Set a number of days or an end date" });

export async function savePlan(form: FormData): Promise<ActionResult> {
  await admins();
  const p = Plan.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the plan" };
  const { id, price_naira, ...rest } = p.data;
  const supabase = await createClient();
  const { error } = await supabase.from("plans").update({ ...rest, price_kobo: Math.round(price_naira * 100) }).eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true };
}

// ---------------- Tabs
const Tab = z.object({
  key: z.string().regex(/^[a-z0-9_]{2,30}$/),
  title: z.string().trim().min(1).max(20),
  icon: z.string().trim().min(2).max(40),
  sort: z.coerce.number().int().min(0).max(99),
  enabled: on,
  premium_only: on,
  min_app_version: z.string().trim().regex(/^(\d+\.\d+\.\d+)?$/, "Version looks like 1.0.0").transform((v) => v || null),
});

export async function saveTab(form: FormData): Promise<ActionResult> {
  await admins();
  const p = Tab.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the tab" };
  const { key, ...rest } = p.data;
  const supabase = await createClient();
  if (!rest.enabled) {
    const { count } = await supabase.from("app_tabs").select("key", { count: "exact", head: true }).eq("enabled", true).neq("key", key);
    if ((count ?? 0) < 2) return { ok: false, error: "Keep at least 2 tabs turned on." };
  }
  const { error } = await supabase.from("app_tabs").update(rest).eq("key", key);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true };
}

// ---------------- Onboarding slides
const Slide = z.object({
  id: z.coerce.number().int().positive().optional(),
  title: z.string().trim().min(3).max(80),
  body: z.string().trim().min(5).max(240),
  animation: z.string().trim().max(40).transform((v) => v || null),
  sort: z.coerce.number().int().min(0).max(99),
  enabled: on,
});

export async function saveSlide(form: FormData): Promise<ActionResult> {
  await admins();
  const p = Slide.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the slide" };
  const { id, ...rest } = p.data;
  const supabase = await createClient();
  const { error } = id ? await supabase.from("onboarding_slides").update(rest).eq("id", id) : await supabase.from("onboarding_slides").insert(rest);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true };
}

export async function deleteSlide(id: number): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { error } = await supabase.from("onboarding_slides").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true };
}
