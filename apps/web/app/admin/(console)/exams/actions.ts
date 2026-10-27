"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff, canEditContent, canManage } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

export async function setYearStatus(yearId: number, status: "draft" | "published"): Promise<ActionResult> {
  const staff = await requireStaff();
  if (!canEditContent(staff.role)) return { ok: false, error: "Only editors and admins can publish years." };
  const supabase = await createClient();
  const { error } = await supabase.from("exam_years").update({ status }).eq("id", yearId);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true };
}

const Rules = z.object({
  exam_id: z.coerce.number().int().positive(),
  subjects_per_candidate: z.coerce.number().int().min(1).max(9),
  total_minutes: z.union([z.literal("").transform(() => null), z.coerce.number().int().min(1).max(600)]),
  score_scale: z.coerce.number().int().min(1).max(1000),
  max_options: z.coerce.number().int().refine((n) => n === 4 || n === 5, "4 or 5"),
});

export async function saveRules(form: FormData): Promise<ActionResult> {
  const staff = await requireStaff();
  if (!canManage(staff.role)) return { ok: false, error: "Only admins can change exam rules." };
  const p = Rules.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the values" };
  const supabase = await createClient();
  const { exam_id, ...rest } = p.data;
  const { error } = await supabase.from("exam_configs").update(rest).eq("exam_id", exam_id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true };
}

const SubjectRule = z.object({
  exam_id: z.coerce.number().int().positive(),
  subject_id: z.coerce.number().int().positive(),
  question_count: z.coerce.number().int().min(1).max(200),
  minutes: z.union([z.literal("").transform(() => null), z.coerce.number().int().min(1).max(600)]),
  compulsory: z.enum(["on"]).optional(),
});

export async function saveSubjectRule(form: FormData): Promise<ActionResult> {
  const staff = await requireStaff();
  if (!canManage(staff.role)) return { ok: false, error: "Only admins can change exam rules." };
  const p = SubjectRule.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the values" };
  const supabase = await createClient();
  const { exam_id, subject_id, compulsory, ...rest } = p.data;
  const { error } = await supabase.from("exam_subjects").upsert({ exam_id, subject_id, ...rest, compulsory: compulsory === "on" });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true };
}
