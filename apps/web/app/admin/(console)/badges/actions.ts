"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";
import { ICONS, LEVELS, METRICS } from "./meta";

const admins = () => requireStaff(["super_admin", "admin"]);
const n = z.coerce.number().int().min(0).max(1_000_000);
const Badge = z.object({
  id: z.coerce.number().int().positive().optional(),
  key: z.string().trim().toLowerCase().regex(/^[a-z0-9_]{2,40}$/, "Short code: 2 to 40 letters, numbers or _"),
  name: z.string().trim().min(2, "Give the badge a name").max(40),
  description: z.string().trim().min(5, "Say how to win it").max(160),
  icon: z.string().refine((v) => ICONS.includes(v), "Pick an icon"),
  metric: z.string().refine((v) => v in METRICS, "Pick what it counts"),
  targets: z.object({ bronze: n, silver: n, gold: n, diamond: n }).refine((t) => t.bronze > 0 && t.silver > t.bronze && t.gold > t.silver && t.diamond > t.gold, "Each level must need more than the one before (bronze above 0)"),
  rewards: z.object(Object.fromEntries(LEVELS.map((l) => [l, z.object({ xp: z.coerce.number().int().min(0).max(5000), days: z.coerce.number().int().min(0).max(90) })])) as Record<(typeof LEVELS)[number], z.ZodObject<{ xp: z.ZodNumber; days: z.ZodNumber }>>),
  sort: z.coerce.number().int().min(0).max(100000),
  active: z.boolean(),
});

/** Adds a badge or saves changes (D-142). Students reach new levels the next time the app checks. */
export async function saveBadge(input: unknown): Promise<ActionResult> {
  await admins();
  const p = Badge.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const { id, ...row } = p.data;
  const supabase = await createClient();
  const r = id ? await supabase.from("badges").update(row).eq("id", id) : await supabase.from("badges").insert(row);
  if (r.error) return { ok: false, error: r.error.code === "23505" ? "A badge with this short code already exists." : friendlyError(r.error) };
  revalidatePath("/admin/badges");
  return { ok: true, message: id ? "Saved." : "Badge added." };
}

export async function setBadgeActive(id: number, active: boolean): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { error } = await supabase.from("badges").update({ active }).eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/badges");
  return { ok: true, message: active ? "Shown in the app." : "Paused. Students keep levels they already won." };
}

export async function deleteBadge(id: number): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { error } = await supabase.from("badges").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/badges");
  return { ok: true, message: "Deleted." };
}

/** The whole badges feature on or off (app_settings.badges.on); keeps the start time. */
export async function setBadgesOn(on: boolean): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { data } = await supabase.from("app_settings").select("value").eq("key", "badges").maybeSingle();
  const value = { ...((data?.value ?? {}) as Record<string, unknown>), on };
  const { error } = await supabase.from("app_settings").upsert({ key: "badges", value, is_public: true }, { onConflict: "key" });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/badges");
  return { ok: true, message: on ? "Badges are on." : "Badges are off. Nothing new is won while off." };
}
