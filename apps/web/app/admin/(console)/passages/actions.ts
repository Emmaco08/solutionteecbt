"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff, canEditContent } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const Passage = z.object({
  id: z.string().uuid().optional(),
  exam_id: z.coerce.number().int().positive("Choose an exam"),
  subject_id: z.coerce.number().int().positive("Choose a subject"),
  year: z.union([z.literal("").transform(() => null), z.coerce.number().int().min(1978).max(2100)]),
  title: z.string().trim().max(160),
  body: z.string().trim().min(20, "The passage is too short").max(40000),
});

export async function savePassage(form: FormData): Promise<ActionResult> {
  const staff = await requireStaff();
  if (!canEditContent(staff.role)) return { ok: false, error: "Only editors and admins can change passages." };
  const p = Passage.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const { id, ...row } = p.data;
  const supabase = await createClient();
  const { error } = id ? await supabase.from("passages").update({ ...row, title: row.title || null }).eq("id", id)
    : await supabase.from("passages").insert({ ...row, title: row.title || null });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true, message: id ? "Passage saved." : "Passage added. Attach questions to it from the question editor." };
}
