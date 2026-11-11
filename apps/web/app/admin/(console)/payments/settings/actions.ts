"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const on = z.enum(["on"]).optional().transform((v) => v === "on");
const num = (min: number, max: number) => z.coerce.number().min(min).max(max);

const Settings = z.object({
  play_google: on,
  play_website: on,
  play_codes: on,
  website_url: z.string().trim().url().startsWith("https://", "The website must start with https://").max(200),
  paystack_mode: z.enum(["none", "ours", "paystack"]),
  paystack_pct: num(0, 20),
  paystack_flat: num(0, 10_000),
  paystack_flat_from: num(0, 1_000_000),
  paystack_cap: num(0, 100_000),
  google_on: on,
  google_pct: num(0, 50),
  play_url: z.string().trim().max(300).refine((v) => v === "" || v.startsWith("https://play.google.com/"), "The Google Play link must start with https://play.google.com/"),
});

/** Payment settings (D-113): how the Play app takes payments, and whether processing fees are added. Logged by the settings trigger. */
export async function savePaymentSettings(form: FormData): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const p = Settings.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the settings" };
  const s = p.data;
  if (!s.play_google && !s.play_website) return { ok: false, error: "Choose at least one way to pay in the Google Play app." };
  const value = {
    play: { google: s.play_google, website: s.play_website },
    website_url: s.website_url,
    fees: {
      // "on" is read by older apps: true only when we add the fee ourselves (D-132).
      paystack: { on: s.paystack_mode === "ours", mode: s.paystack_mode, pct: s.paystack_pct, flat: s.paystack_flat, flat_from: s.paystack_flat_from, cap: s.paystack_cap },
      google: { on: s.google_on, pct: s.google_pct },
    },
  };
  const supabase = await createClient();
  const { error } = await supabase.from("app_settings").upsert({ key: "payments", value, is_public: true }, { onConflict: "key" });
  if (error) return { ok: false, error: friendlyError(error) };
  // "Have a code?" in the Google Play app (D-117): free-days codes there, discount codes on the website.
  const { error: e3 } = await supabase.from("feature_flags").update({ enabled: s.play_codes }).eq("key", "codes_in_play_build");
  if (e3) return { ok: false, error: friendlyError(e3) };
  // The public website's Google Play button (cbt.solutiontee.com, D-114).
  const { error: e2 } = await supabase.from("app_settings").upsert({ key: "site", value: { play_url: s.play_url }, is_public: true }, { onConflict: "key" });
  if (e2) return { ok: false, error: friendlyError(e2) };
  revalidatePath("/admin", "layout");
  return { ok: true, message: "Payment settings saved. Phones get them the next time the app opens." };
}

const KEY_NAMES = ["paystack_sk_live", "paystack_pk_live", "paystack_sk_test", "paystack_pk_test"] as const;
export type PaystackKeyName = (typeof KEY_NAMES)[number];

/** Saves one Paystack key in Supabase Vault (D-133). Super admins with 2-step login; the database checks it again and
 *  checks the key's shape. The key is never sent back, logged or shown again (only a masked hint). */
export async function savePaystackKey(name: PaystackKeyName, value: string): Promise<ActionResult> {
  await requireStaff(["super_admin"]);
  if (!KEY_NAMES.includes(name)) return { ok: false, error: "Unknown key" };
  const v = String(value ?? "").trim();
  if (!v) return { ok: false, error: "Paste the key first." };
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_set_paystack_key", { p_name: name, p_value: v });
  if (error) return { ok: false, error: error.code === "42501" ? error.message : error.message || friendlyError(error) };
  revalidatePath("/admin/payments/settings");
  return { ok: true, message: `Saved (${String((data as { masked?: string } | null)?.masked ?? "")}). The payment server uses it within 30 seconds.` };
}

/** Test or Live for every Paystack payment (D-133). In Test mode only staff can pay. */
export async function setPaystackMode(mode: "test" | "live"): Promise<ActionResult> {
  await requireStaff(["super_admin"]);
  if (mode !== "test" && mode !== "live") return { ok: false, error: "Choose Test or Live" };
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_set_paystack_mode", { p_mode: mode });
  if (error) return { ok: false, error: error.message || friendlyError(error) };
  revalidatePath("/admin/payments/settings");
  return { ok: true, message: mode === "live" ? "Live: students pay with real money." : "Test: only staff can pay, with Paystack test cards." };
}
