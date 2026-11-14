"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

// Admin → App ratings (owner, 13 Nov 2026): when the app shows its rating card, Google's review box and suggestions.

const n = (min: number, max: number) => z.coerce.number().int().min(min).max(max);
const Settings = z.object({
  rating: z.object({ on: z.boolean(), after_days: n(0, 60), after_opens: n(1, 100), every_days: n(14, 365) }),
  review: z.object({ on: z.boolean(), after_days: n(0, 90), every_days: n(30, 365) }),
  nudges: z.object({ on: z.boolean(), after_days: n(0, 60), every_days: n(1, 60), community: z.boolean(), games: z.boolean(), tutor: z.boolean() }),
});
export type EngagementSettings = z.infer<typeof Settings>;

export async function saveEngagement(input: unknown): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const p = Settings.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the numbers" };
  const supabase = await createClient();
  const { error } = await supabase.from("app_settings").upsert({ key: "engagement", value: p.data });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/ratings");
  return { ok: true, message: "Saved. Phones pick it up the next time the app opens." };
}

export type RatingRow = { id: number; stars: number; comment: string | null; version: string | null; at: string; name: string; email: string | null };
export type RatingsData = { total: number; average: number | null; average_30: number | null; count_30: number; by_stars: Record<string, number>; rows: RatingRow[] };

export async function loadRatings(stars: number | null, offset: number): Promise<ActionResult<RatingsData>> {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_app_ratings", { p_stars: stars ?? undefined, p_offset: offset });
  if (error) return { ok: false, error: friendlyError(error) };
  return { ok: true, data: data as unknown as RatingsData };
}
