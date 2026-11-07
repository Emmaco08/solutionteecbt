"use server";
import { revalidatePath } from "next/cache";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";
import { KINDS, MODES, type Defaults, type Mode, type Rule } from "./shared";

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
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_content_access_save", { p_defaults: { items, years } });
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
