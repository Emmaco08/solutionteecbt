"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const editors = () => requireStaff(["super_admin", "admin", "editor"]);

const Section = z.object({
  key: z.string().trim().regex(/^[a-z0-9_]{2,30}$/, "A section key uses small letters, numbers and _"),
  label: z.string().trim().min(2, "Every section needs a name").max(60),
  count: z.coerce.number().int("Counts are whole numbers").min(0).max(200),
  instruction: z.string().trim().max(300, "Keep instructions under 300 letters"),
  passage: z.boolean().optional(),
});
const Blueprint = z.object({
  id: z.coerce.number().int().positive(),
  total: z.coerce.number().int("The total is a whole number").min(1, "The total must be at least 1").max(300),
  sections: z.array(Section).max(20).refine((a) => new Set(a.map((s) => s.key)).size === a.length, "Two sections share a key"),
});

/** Saves a blueprint's total and sections. The audit log is written by a database trigger. */
export async function saveBlueprint(input: unknown): Promise<ActionResult> {
  const staff = await editors();
  const p = Blueprint.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the blueprint" };
  const { id, total, sections } = p.data;
  const clean = sections.map((s) => ({ key: s.key, label: s.label, count: s.count, instruction: s.instruction, ...(s.passage ? { passage: true } : {}) }));
  const supabase = await createClient();
  const { error } = await supabase.from("exam_blueprints")
    .update({ total, sections: clean, updated_at: new Date().toISOString(), updated_by: staff.id }).eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/blueprints");
  return { ok: true, message: "Blueprint saved." };
}

/** Adds a blueprint for a subject that follows the exam default until now. */
export async function addSubjectBlueprint(examId: number, subjectId: number): Promise<ActionResult> {
  const staff = await editors();
  if (!Number.isInteger(examId) || !Number.isInteger(subjectId)) return { ok: false, error: "Choose a subject." };
  const supabase = await createClient();
  const { data: def } = await supabase.from("exam_blueprints").select("total").eq("exam_id", examId).is("subject_id", null).maybeSingle();
  const { error } = await supabase.from("exam_blueprints")
    .insert({ exam_id: examId, subject_id: subjectId, total: def?.total ?? 40, sections: [], updated_by: staff.id });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/blueprints");
  return { ok: true, message: "Blueprint added." };
}

/** Removes a subject blueprint (admins only, the exam default stays). */
export async function deleteBlueprint(id: number): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { error } = await supabase.from("exam_blueprints").delete().eq("id", id).not("subject_id", "is", null);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/blueprints");
  return { ok: true, message: "Blueprint removed. The subject uses the exam default again." };
}
