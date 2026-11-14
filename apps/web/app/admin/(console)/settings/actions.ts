"use server";
import { revalidatePath, updateTag } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

export async function setFlag(key: string, enabled: boolean): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  if (!/^[a-z0-9_]{2,60}$/.test(key)) return { ok: false, error: "Bad flag" };
  const supabase = await createClient();
  const { error } = await supabase.from("feature_flags").update({ enabled }).eq("key", key);
  if (error) return { ok: false, error: friendlyError(error) };
  if (key === "cash_prizes") updateTag("site"); // the website, Privacy Policy and Terms follow the cash switches (D-122)
  revalidatePath("/admin", "layout");
  return { ok: true };
}

const Settings = z.object({
  maintenance: z.enum(["on"]).optional(),
  maintenance_staff: z.enum(["on"]).optional(),
  maintenance_message: z.string().trim().min(5, "Write a short maintenance message").max(300),
  maintenance_until: z.union([z.literal(""), z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/, "Pick a date and time")]).default(""),
  play_prompt: z.enum(["on"]).optional(),
  play_force: z.enum(["on"]).optional(),
  play_notes: z.string().trim().max(500, "What's new: 500 letters at most").default(""),
  min_build: z.coerce.number().int("Build number is a whole number").min(0).max(99999999).default(0),
  whatsapp: z.string().trim().regex(/^\+?[0-9 ]{7,20}$/, "WhatsApp number looks wrong"),
  support_email: z.union([z.literal(""), z.string().trim().email("Support email looks wrong")]),
  company_name: z.string().trim().min(2).max(120),
  rc_number: z.string().trim().max(40),
  address: z.string().trim().max(300),
  website: z.string().trim().url("Website must start with https://"),
  web_app: z.string().trim().url("Web app address must start with https://"),
  disclaimer: z.string().trim().min(20).max(400),
});

export async function saveSettings(form: FormData): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const p = Settings.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const s = p.data;
  const digits = s.whatsapp.replace(/\D/g, "");
  const rows = [
    // "Back by" is typed in Lagos time (UTC+1, no daylight saving).
    { key: "maintenance", value: { enabled: s.maintenance === "on", message: s.maintenance_message, staff_bypass: s.maintenance_staff === "on",
      until: s.maintenance_until ? new Date(`${s.maintenance_until}:00+01:00`).toISOString() : null } },
    { key: "play_update", value: { prompt: s.play_prompt === "on", force: s.play_force === "on", notes: s.play_notes } },
    { key: "min_build", value: { build: s.min_build } },
    { key: "support", value: { whatsapp: `+${digits}`, whatsapp_link: `https://wa.me/${digits}`, email: s.support_email || null } },
    { key: "company", value: { name: s.company_name, rc_number: s.rc_number, address: s.address, website: s.website, web_app: s.web_app } },
    { key: "disclaimer", value: s.disclaimer },
  ];
  const supabase = await createClient();
  for (const r of rows) {
    const { error } = await supabase.from("app_settings").update({ value: r.value }).eq("key", r.key);
    if (error) return { ok: false, error: friendlyError(error) };
  }
  revalidatePath("/admin", "layout");
  return { ok: true };
}

const SWITCHES: Record<string, string[]> = {
  screen_protection: ["whole_app", "exams"],
  app_update: ["force"],
  google_auth: ["enabled"],
  cash_prizes: ["on", "teens"], // D-110, D-121
  exam_logos: ["on"], // D-111
};

/** One switch inside a JSON setting (D-080): screen protection and in-app updates. Logged by the settings trigger. */
export async function setAppSwitch(key: string, field: string, on: boolean): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  if (!SWITCHES[key]?.includes(field)) return { ok: false, error: "Unknown setting" };
  const supabase = await createClient();
  const { data, error: e1 } = await supabase.from("app_settings").select("value").eq("key", key).maybeSingle();
  if (e1 || !data) return { ok: false, error: e1 ? friendlyError(e1) : "Setting not found" };
  const value = { ...((data.value as Record<string, boolean | string | number | null>) ?? {}), [field]: on };
  const { error } = await supabase.from("app_settings").update({ value }).eq("key", key);
  if (error) return { ok: false, error: friendlyError(error) };
  // The website follows these at once: cash prizes (pages, Privacy, Terms; D-122) and the exam logos (D-131).
  if (key === "cash_prizes" || key === "exam_logos") updateTag("site");
  revalidatePath("/admin", "layout");
  return { ok: true };
}

/** Google's Web client ID for "Continue with Google" (D-087). Public, not a secret: it is inside every app. */
export async function setGoogleClientId(id: string): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const v = id.trim();
  if (v && !/^[0-9]{6,20}-[a-z0-9]{20,40}\.apps\.googleusercontent\.com$/.test(v))
    return { ok: false, error: "That does not look like a Google client ID (it ends with .apps.googleusercontent.com)." };
  const supabase = await createClient();
  const { data } = await supabase.from("app_settings").select("value").eq("key", "google_auth").maybeSingle();
  const value = { ...((data?.value as Record<string, unknown>) ?? { enabled: false }), web_client_id: v };
  const { error } = await supabase.from("app_settings").upsert({ key: "google_auth", value, is_public: true });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true, message: v ? "Saved." : "Removed." };
}
