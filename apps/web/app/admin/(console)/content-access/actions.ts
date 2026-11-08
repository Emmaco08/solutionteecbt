"use server";
import { revalidatePath } from "next/cache";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";
import { KINDS, MODES, type Defaults, type Mode, type CustomExam, type Rule, type Welcome } from "./shared";

const n = (v: unknown, min: number, max: number, def: number) => {
  const x = Math.round(Number(v));
  return Number.isFinite(x) ? Math.min(Math.max(x, min), max) : def;
};
const mode = (m: unknown): Mode => (MODES.some((x) => x.id === m) ? (m as Mode) : "default");
function clean(r: Rule): Rule | string {
  const m = mode(r.mode);
  const out: Rule = { mode: m, ads: n(r.ads, 1, 20, 1), hours: n(r.hours, 0, 720, 24), premium_pays: !!r.premium_pays };
  if (m === "pay") {
    const k = n(r.price_kobo, 0, 10_000_000, 0);
    if (k < 5000) return "Set a price of at least ₦50 for every “Pay per item” rule.";
    out.price_kobo = k;
  }
  return out;
}

export async function saveDefaults(d: Defaults): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const items: Record<string, Rule> = {};
  for (const k of KINDS) {
    const r = clean(d.items[k.id] ?? { mode: "default" });
    if (typeof r === "string") return { ok: false, error: `${k.label}: ${r}` };
    items[k.id] = r;
  }
  const years = clean(d.years ?? { mode: "default" });
  if (typeof years === "string") return { ok: false, error: `Past-question years: ${years}` };
  // Years that can be opened by watching, per exam: "all" or a list of years.
  const adsYears: Record<string, number[] | "all"> = {};
  for (const [exam, v] of Object.entries(d.years?.ads_years ?? {})) {
    if (!/^\d{1,3}$/.test(exam)) continue;
    adsYears[exam] = v === "all" ? "all" : (Array.isArray(v) ? v.map(Number).filter((y) => y >= 1950 && y <= 2100) : []);
  }
  const perKind: Record<string, number> = {};
  for (const k of KINDS) perKind[k.id] = n(d.limits?.item_per_day?.[k.id], 0, 50, 0);
  const limits = { year_per_day: n(d.limits?.year_per_day, 0, 50, 2), item_per_day: perKind };
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_content_access_save", { p_defaults: { items, years: { ...years, ads_years: adsYears }, limits } });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/content-access");
  return { ok: true, message: "Saved. Students get it at once (checked on the server)." };
}

export async function saveYear(exam: number, year: number, r: Rule): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const c = clean(r);
  if (typeof c === "string") return { ok: false, error: c };
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_year_access_save", {
    p_exam: exam, p_year: year, p_access: c.mode,
    p_ads: c.mode === "ads" ? c.ads! : null as unknown as number, p_hours: c.mode === "ads" ? c.hours! : null as unknown as number,
    p_price_kobo: c.mode === "pay" ? c.price_kobo! : null as unknown as number, p_premium_pays: c.mode === "pay" ? !!c.premium_pays : null as unknown as boolean,
  });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/content-access");
  return { ok: true, message: c.mode === "default" ? "Year rule removed." : "Year rule saved." };
}

export async function saveWelcome(w: Welcome): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_welcome_save", { p: w });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/content-access");
  return { ok: true, message: w.on ? "First-day welcome is on for new students." : "First-day welcome is off." };
}

export async function saveCustomExam(c: CustomExam): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const value = {
    on: !!c.on, who: c.who === "premium" ? "premium" : "everyone",
    max_questions: n(c.max_questions, 5, 100, 40), max_english: n(c.max_english, 5, 100, 60), max_minutes: n(c.max_minutes, 10, 300, 180),
  };
  const supabase = await createClient();
  const { error } = await supabase.from("app_settings").upsert({ key: "custom_exam", value, is_public: true });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/content-access");
  return { ok: true, message: "Custom exam saved. Students get it the next time the app loads settings." };
}
