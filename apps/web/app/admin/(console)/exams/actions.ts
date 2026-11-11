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

/** The three exams whose official logos ship with the app (/brand/exam-bodies). Their logo and code never change. */
const BUILT_IN = ["JAMB", "WAEC", "NECO"];

const NewExam = z.object({
  code: z.string().trim().toUpperCase().regex(/^[A-Z][A-Z0-9]{1,11}$/, "Short name: 2 to 12 letters or numbers, starting with a letter (for example BECE)"),
  name: z.string().trim().min(2, "Write the exam's full name").max(60),
  subtitle: z.string().trim().max(80).optional().transform((v) => (v ? v : null)),
});

/** Adds an exam (D-138). The database adds its rules row and keeps it locked for free students until years are opened. */
export async function createExam(input: unknown): Promise<ActionResult<{ id: number }>> {
  const staff = await requireStaff();
  if (!canManage(staff.role)) return { ok: false, error: "Only admins can add exams." };
  const p = NewExam.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const supabase = await createClient();
  const { data: last } = await supabase.from("exam_bodies").select("sort").order("sort", { ascending: false }).limit(1).maybeSingle();
  const { data, error } = await supabase.from("exam_bodies").insert({ ...p.data, sort: (last?.sort ?? 0) + 1, is_active: false }).select("id").single();
  if (error) return { ok: false, error: error.code === "23505" ? "An exam with this short name already exists." : friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true, data: { id: data.id }, message: "Exam added. It is hidden from students until you turn on Show in the app." };
}

const ExamDetails = z.object({
  id: z.coerce.number().int().positive(),
  name: z.string().trim().min(2, "Write the exam's full name").max(60),
  subtitle: z.string().trim().max(80).optional().transform((v) => (v ? v : null)),
  logo_path: z.string().trim().regex(/^public\/exams\/[A-Za-z0-9/_.-]+$/).or(z.literal("")).optional(),
  sort: z.coerce.number().int().min(0).max(1000),
  is_active: z.boolean(),
});

export async function saveExam(input: unknown): Promise<ActionResult> {
  const staff = await requireStaff();
  if (!canManage(staff.role)) return { ok: false, error: "Only admins can change exams." };
  const p = ExamDetails.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const supabase = await createClient();
  const { data: cur } = await supabase.from("exam_bodies").select("code").eq("id", p.data.id).maybeSingle();
  if (!cur) return { ok: false, error: "This exam no longer exists." };
  const builtIn = BUILT_IN.includes(cur.code);
  if (cur.code === "JAMB" && !p.data.is_active) return { ok: false, error: "JAMB is the app's main exam and cannot be hidden." };
  const { id, logo_path, ...row } = p.data;
  const update = builtIn ? row : { ...row, logo_path: logo_path ? logo_path : null };
  const { error } = await supabase.from("exam_bodies").update(update).eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true, message: "Saved. Phones get it the next time they open the Test tab." };
}
