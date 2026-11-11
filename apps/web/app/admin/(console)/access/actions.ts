"use server";
import { revalidatePath } from "next/cache";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";
import { rulesFor, type RuleValue } from "./rules";

/** Saves both tiers. Values are rebuilt from the known rule list, so unknown keys can't be injected. */
export async function saveAccessRules(form: FormData): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data: exams } = await supabase.from("exam_bodies").select("code");
  const rules = rulesFor(exams ?? []);
  const build = (tier: "free" | "premium") => {
    const out: Record<string, RuleValue> = {};
    for (const r of rules) {
      const raw = String(form.get(`${tier}.${r.key}`) ?? "");
      if (r.kind === "bool") out[r.key] = raw === "on";
      else if (r.kind === "which") out[r.key] = raw === "newest" ? "newest" : "oldest";
      else if (raw === "all") out[r.key] = "all";
      else {
        const n = Math.max(0, Math.min(r.kind === "count" ? 1000 : 60, Math.floor(Number(raw) || 0)));
        out[r.key] = n;
      }
    }
    return out;
  };
  for (const tier of ["free", "premium"] as const) {
    const { error } = await supabase.from("access_rules").update({ rules: build(tier) }).eq("tier", tier);
    if (error) return { ok: false, error: friendlyError(error) };
  }
  revalidatePath("/admin", "layout");
  return { ok: true };
}
