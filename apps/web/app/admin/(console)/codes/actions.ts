"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const admins = () => requireStaff(["super_admin", "admin"]);
const date = z.union([z.literal("").transform(() => null), z.string().regex(/^\d{4}-\d{2}-\d{2}$/)]);
// Dates are typed in Lagos time: starts at 00:00, ends at the end of that day.
const lagos = (d: string | null, end = false) => (d ? new Date(`${d}T${end ? "23:59:59" : "00:00:00"}+01:00`).toISOString() : null);

const Code = z.object({
  kind: z.enum(["pct", "amt", "days"]),
  value: z.coerce.number().positive(),
  plan_ids: z.string().transform((s) => s.split(",").filter(Boolean).map(Number).filter((n) => Number.isInteger(n) && n > 0)),
  style: z.enum(["shared", "unique"]),
  code: z.string().trim().toUpperCase().max(24),
  prefix: z.string().trim().toUpperCase().max(8),
  count: z.union([z.literal("").transform(() => 1), z.coerce.number().int().min(1).max(1000)]),
  max_uses: z.union([z.literal("").transform(() => null), z.coerce.number().int().min(1).max(1_000_000)]),
  starts: date,
  ends: date,
  new_only: z.enum(["on"]).optional().transform((v) => v === "on"),
  note: z.string().trim().max(200),
}).superRefine((c, ctx) => {
  if (c.kind === "pct" && (c.value > 100 || !Number.isInteger(c.value))) ctx.addIssue({ code: "custom", message: "Percentage must be a whole number from 1 to 100" });
  if (c.kind === "days" && (c.value > 366 || !Number.isInteger(c.value))) ctx.addIssue({ code: "custom", message: "Free days must be 1 to 366" });
  if (c.style === "shared" && !/^[A-Z0-9-]{4,24}$/.test(c.code)) ctx.addIssue({ code: "custom", message: "Code: 4 to 24 letters, numbers or dashes" });
  if (c.style === "unique" && !/^[A-Z0-9]{2,8}$/.test(c.prefix)) ctx.addIssue({ code: "custom", message: "Prefix: 2 to 8 letters or numbers" });
  if (c.starts && c.ends && c.ends < c.starts) ctx.addIssue({ code: "custom", message: "The end date is before the start date" });
});

export async function createCodes(form: FormData): Promise<ActionResult<{ codes: string[] }>> {
  await admins();
  const p = Code.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const c = p.data;
  const value = c.kind === "amt" ? Math.round(c.value * 100) : c.value; // ₦ → kobo
  const plan_ids = c.kind === "days" ? [] : c.plan_ids;
  const supabase = await createClient();
  if (c.style === "shared") {
    const { error } = await supabase.from("promo_codes").insert({
      code: c.code, kind: c.kind, value, plan_ids, max_uses: c.max_uses, new_only: c.new_only,
      starts_at: lagos(c.starts) ?? new Date().toISOString(), ends_at: lagos(c.ends, true), note: c.note || null,
    });
    if (error) return { ok: false, error: error.code === "23505" ? "That code already exists. Pick another." : friendlyError(error) };
    revalidatePath("/admin/codes");
    return { ok: true, message: `Code ${c.code} created.`, data: { codes: [c.code] } };
  }
  const { data, error } = await supabase.rpc("admin_create_code_batch", {
    p_prefix: c.prefix, p_count: c.count, p_kind: c.kind, p_value: value, p_plan_ids: plan_ids,
    p_starts: lagos(c.starts) ?? new Date().toISOString(), p_ends: lagos(c.ends, true) as string, p_note: c.note || "", p_new_only: c.new_only,
  });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/codes");
  const codes = ((data as { codes?: string[] })?.codes ?? []);
  return { ok: true, message: `${codes.length} codes created.`, data: { codes } };
}

export async function pauseCodes(id: string, paused: boolean): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_pause_codes", { p_id: id, p_paused: paused });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/codes");
  return { ok: true, message: paused ? "Paused. Students can no longer use it." : "Turned back on." };
}

export async function batchCodes(batch: string): Promise<ActionResult<{ code: string; used: number }[]>> {
  await admins();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_batch_codes", { p_batch: batch });
  if (error) return { ok: false, error: friendlyError(error) };
  return { ok: true, data: data ?? [] };
}
