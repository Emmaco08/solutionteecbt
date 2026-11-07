"use server";
import { revalidatePath } from "next/cache";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";
import { PLACEMENTS, type Campaign, type CampaignReport } from "./shared";

const KEY = /^public\/ads\/[A-Za-z0-9/_.-]+$/;
const n = (v: unknown, min: number, max: number, def: number) => {
  const x = Math.round(Number(v));
  return Number.isFinite(x) ? Math.min(Math.max(x, min), max) : def;
};
const key = (k: string | null | undefined) => (k && KEY.test(k) ? k : null);

/** Save a brand campaign (house ad). The server refuses turning it on while a place it shows in has no file. */
export async function saveCampaign(c: Campaign): Promise<ActionResult & { id?: string }> {
  await requireStaff(["super_admin", "admin"]);
  if (!c.brand.trim() || !c.name.trim()) return { ok: false, error: "Enter the brand and a campaign name." };
  if (c.link && !/^https:\/\/\S+$/.test(c.link.trim())) return { ok: false, error: "The link must start with https://" };
  const p = {
    id: c.id ?? "",
    brand: c.brand.trim().slice(0, 80),
    name: c.name.trim().slice(0, 120),
    status: ["draft", "active", "paused", "ended"].includes(c.status) ? c.status : "draft",
    starts_on: c.starts_on ?? "",
    ends_on: c.ends_on ?? "",
    placements: c.placements.filter((x) => PLACEMENTS.some((p) => p.id === x)),
    share_pct: n(c.share_pct, 1, 100, 50),
    cap_per_day: n(c.cap_per_day, 1, 50, 3),
    weight: n(c.weight, 1, 10, 1),
    link: c.link?.trim() ?? "",
    cta: (c.cta ?? "").trim().slice(0, 24) || "Learn more",
    banner_key: key(c.banner_key), card_key: key(c.card_key),
    card_title: (c.card_title ?? "").trim().slice(0, 60), card_body: (c.card_body ?? "").trim().slice(0, 140),
    break_kind: c.break_kind === "video" ? "video" : "image", break_key: key(c.break_key),
    video_key: key(c.video_key), skip_after_s: n(c.skip_after_s, 0, 30, 5),
  };
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_ad_campaign_save", { p });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/ads/campaigns");
  return { ok: true, message: p.status === "active" ? "Saved. Students see it the next time ads load." : "Saved.", id: (data as { id?: string })?.id };
}

export async function deleteCampaign(id: string): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_ad_campaign_delete", { p_id: id });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/ads/campaigns");
  return { ok: true, message: "Campaign deleted." };
}

export async function campaignReport(id: string): Promise<CampaignReport | null> {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_ad_campaign_report", { p_id: id });
  if (error) return null;
  return data as unknown as CampaignReport;
}
