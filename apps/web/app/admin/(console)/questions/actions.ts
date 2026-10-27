"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { requireStaff, canEditContent } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";
import { latexProblem } from "@solutiontee/shared/csv";

const STATUSES = ["draft", "review", "published"] as const;

export async function setStatus(ids: string[], status: (typeof STATUSES)[number]): Promise<ActionResult<number>> {
  const staff = await requireStaff();
  if (!canEditContent(staff.role)) return { ok: false, error: "Only editors and admins can change questions." };
  if (!ids.length || ids.length > 1000 || !STATUSES.includes(status)) return { ok: false, error: "Nothing to change." };
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("set_questions_status", { p_ids: ids, p_status: status });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true, data: data ?? 0 };
}

const opt = z.string().trim().max(5000).optional().transform((v) => v || undefined);
const QuestionSchema = z
  .object({
    id: z.string().uuid().optional(),
    exam_id: z.coerce.number().int().positive("Choose an exam"),
    subject_id: z.coerce.number().int().positive("Choose a subject"),
    year: z.coerce.number().int().min(1978, "Year must be 1978 or later").max(new Date().getFullYear() + 1),
    number: z.coerce.number().int().min(1).max(500).optional().or(z.literal("").transform(() => undefined)),
    topic: z.string().trim().max(120).optional(),
    passage_id: z.string().uuid().optional().or(z.literal("").transform(() => undefined)),
    body: z.string().trim().min(1, "Write the question").max(20000),
    A: z.string().trim().min(1, "Option A is empty").max(5000),
    B: z.string().trim().min(1, "Option B is empty").max(5000),
    C: z.string().trim().min(1, "Option C is empty").max(5000),
    D: z.string().trim().min(1, "Option D is empty").max(5000),
    E: opt,
    answer: z.enum(["A", "B", "C", "D", "E"], { message: "Choose the correct answer" }),
    explanation: z.string().trim().max(40000).optional(),
    difficulty: z.enum(["easy", "medium", "hard"]).optional().or(z.literal("").transform(() => undefined)),
    image_path: z.string().trim().max(300).optional(),
    status: z.enum(STATUSES),
  })
  .refine((q) => q.answer !== "E" || Boolean(q.E), { message: "The answer is E but option E is empty", path: ["answer"] });

export type SaveState = { error?: string; fieldErrors?: Record<string, string> };

export async function saveQuestion(_prev: SaveState, form: FormData): Promise<SaveState> {
  const staff = await requireStaff();
  if (!canEditContent(staff.role)) return { error: "Only editors and admins can change questions." };
  const parsed = QuestionSchema.safeParse(Object.fromEntries(form));
  if (!parsed.success) {
    const fieldErrors: Record<string, string> = {};
    for (const i of parsed.error.issues) fieldErrors[String(i.path[0] ?? "form")] ??= i.message;
    return { error: "Fix the highlighted fields.", fieldErrors };
  }
  const q = parsed.data;
  for (const [k, v] of Object.entries({ body: q.body, A: q.A, B: q.B, C: q.C, D: q.D, E: q.E ?? "", explanation: q.explanation ?? "" })) {
    const p = latexProblem(v);
    if (p) return { error: "Fix the maths.", fieldErrors: { [k]: `This ${p}` } };
  }

  const supabase = await createClient();
  let topic_id: number | null = null;
  if (q.topic) {
    const { data: existing } = await supabase.from("topics").select("id").eq("subject_id", q.subject_id).eq("name", q.topic).maybeSingle();
    if (existing) topic_id = existing.id;
    else {
      const { data: made, error } = await supabase.from("topics").insert({ subject_id: q.subject_id, name: q.topic }).select("id").single();
      if (error) return { error: friendlyError(error) };
      topic_id = made.id;
    }
  }
  // Make sure the year exists for this exam + subject (as a draft until someone publishes it).
  await supabase.from("exam_years").upsert({ exam_id: q.exam_id, subject_id: q.subject_id, year: q.year }, { onConflict: "exam_id,subject_id,year", ignoreDuplicates: true });

  const options: Record<string, string> = { A: q.A, B: q.B, C: q.C, D: q.D };
  if (q.E) options.E = q.E;
  const row = {
    exam_id: q.exam_id, subject_id: q.subject_id, year: q.year, number: q.number ?? null, topic_id, passage_id: q.passage_id ?? null,
    body: q.body, options, answer: q.answer, explanation: q.explanation || null, difficulty: q.difficulty ?? null,
    image_path: q.image_path || null, status: q.status,
  };
  const res = q.id
    ? await supabase.from("questions").update(row).eq("id", q.id).select("id").single()
    : await supabase.from("questions").insert(row).select("id").single();
  if (res.error) return { error: friendlyError(res.error) };
  revalidatePath("/admin", "layout");
  redirect(`/admin/questions?saved=${res.data.id}`);
}

export async function deleteQuestion(id: string): Promise<ActionResult> {
  const staff = await requireStaff();
  if (!canEditContent(staff.role)) return { ok: false, error: "Only editors and admins can delete questions." };
  const supabase = await createClient();
  const { error } = await supabase.from("questions").update({ deleted_at: new Date().toISOString() }).eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true };
}
