"use server";
import { revalidatePath } from "next/cache";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";
import type { AdsSettings } from "./ads-ui";

const UNIT = /^(ca-app-pub-\d{16}\/\d{10})?$/;

/** Save the ads level, formats, ad unit ids and rewards. The app reads them on the next open (no app update needed). */
export async function saveAds(v: AdsSettings): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  for (const [k, id] of Object.entries(v.units)) {
    if (!UNIT.test(id.trim())) return { ok: false, error: `The ${k} ad unit id should look like ca-app-pub-1234567890123456/1234567890` };
  }
  const value = {
    level: v.level,
    test_mode: v.test_mode,
    formats: v.formats,
    units: Object.fromEntries(Object.entries(v.units).map(([k, id]) => [k, id.trim()])),
    rewards: {
      ai_prompts: Math.min(Math.max(Math.round(v.rewards.ai_prompts), 1), 10),
      note_hours: Math.min(Math.max(Math.round(v.rewards.note_hours), 1), 168),
      streak_freeze: 1,
    },
  };
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_ads_save", { p_value: value });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/ads");
  return { ok: true, message: v.level === "off" ? "Ads are off." : "Saved. Students get it the next time they open the app." };
}
