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
  website_url: z.string().trim().url().startsWith("https://", "The website must start with https://").max(200),
  paystack_on: on,
  paystack_pct: num(0, 20),
  paystack_flat: num(0, 10_000),
  paystack_flat_from: num(0, 1_000_000),
  paystack_cap: num(0, 100_000),
  google_on: on,
  google_pct: num(0, 50),
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
      paystack: { on: s.paystack_on, pct: s.paystack_pct, flat: s.paystack_flat, flat_from: s.paystack_flat_from, cap: s.paystack_cap },
      google: { on: s.google_on, pct: s.google_pct },
    },
  };
  const supabase = await createClient();
  const { error } = await supabase.from("app_settings").upsert({ key: "payments", value, is_public: true }, { onConflict: "key" });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true, message: "Payment settings saved. Phones get them the next time the app opens." };
}
