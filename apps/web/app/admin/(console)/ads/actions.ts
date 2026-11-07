"use server";
import { revalidatePath } from "next/cache";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";
import { BANNER_SCREENS, BREAK_SPOTS, EARN_SPOTS, type AdsSettings } from "./ads-shared";

const UNIT = /^(ca-app-pub-\d{16}\/\d{10})?$/;
const n = (v: unknown, min: number, max: number, def: number) => {
  const x = Math.round(Number(v));
  return Number.isFinite(x) ? Math.min(Math.max(x, min), max) : def;
};

/** Save the ads level (or the admin's custom rules), formats, ad unit ids and rewards. The app reads them on the next
 *  open, so no app update is needed. */
export async function saveAds(v: AdsSettings): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  for (const [k, id] of Object.entries(v.units)) {
    if (!UNIT.test(id.trim())) return { ok: false, error: `The ${k.replace("_", " ")} ad unit id should look like ca-app-pub-1234567890123456/1234567890` };
  }
  const c = v.custom;
  const value = {
    level: v.level,
    test_mode: v.test_mode,
    formats: v.formats,
    units: Object.fromEntries(Object.entries(v.units).map(([k, id]) => [k, id.trim()])),
    rewards: {
      ai_prompts: n(v.rewards.ai_prompts, 1, 10, 2),
      note_hours: n(v.rewards.note_hours, 1, 168, 24),
      streak_freeze: 1,
      year_ads: n(v.rewards.year_ads, 1, 20, 1),
      year_minutes: n(v.rewards.year_minutes, 10, 1440, 60),
      xp_ads: n(v.rewards.xp_ads, 1, 20, 1),
      xp_amount: n(v.rewards.xp_amount, 1, 100, 5),
      xp_daily_cap: n(v.rewards.xp_daily_cap, 0, 100, 20),
    },
    custom: {
      banner_screens: c.banner_screens.filter((s) => BANNER_SCREENS.some((b) => b.id === s)),
      home_cards: n(c.home_cards, 0, 6, 1),
      native_every: n(c.native_every, 0, 30, 8),
      news_card: !!c.news_card,
      inter_every_tests: n(c.inter_every_tests, 0, 10, 2),
      inter_spots: c.inter_spots.filter((s) => BREAK_SPOTS.some((b) => b.id === s)),
      ai_every: n(c.ai_every, 0, 20, 0),
      interstitial_gap_s: n(c.interstitial_gap_s, 60, 3600, 300),
      interstitial_per_day: n(c.interstitial_per_day, 0, 40, 6),
      app_open_after_min: n(c.app_open_after_min, 0, 1440, 0),
      rint_spots: c.rint_spots.filter((s) => EARN_SPOTS.some((b) => b.id === s)),
      rewarded_per_day: n(c.rewarded_per_day, 0, 50, 8),
      after_video: c.inter_spots.includes("video_end"),
    },
  };
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_ads_save", { p_value: value });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/ads");
  return { ok: true, message: v.level === "off" ? "Ads are off." : "Saved. Students get it the next time they open the app." };
}
