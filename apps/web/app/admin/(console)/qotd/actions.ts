"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

export type Candidate = { id: string; body: string; exam: string; subject: string; year: number; number: number | null; used: string | null };

const editors = () => requireStaff(["super_admin", "admin", "editor"]);
const isDay = (d: string) => /^\d{4}-\d{2}-\d{2}$/.test(d);

/** Questions that can be the question of the day: published, from a year Free students can open, no passage. */
export async function findQuestions(search: string, subject: number | null): Promise<ActionResult<Candidate[]>> {
  await editors();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_qotd_candidates", {
    p_search: search.trim() ? search.trim().slice(0, 80) : undefined, p_subject: subject ?? undefined, p_limit: 30,
  });
  if (error) return { ok: false, error: friendlyError(error) };
  return { ok: true, data: (data ?? []) as unknown as Candidate[] };
}

/** Schedules a question for a day (replaces the automatic pick or an earlier choice, unless students already answered). */
export async function scheduleQuestion(day: string, questionId: string): Promise<ActionResult> {
  await editors();
  if (!isDay(day) || !/^[0-9a-f-]{36}$/.test(questionId)) return { ok: false, error: "Choose a day and a question" };
  const supabase = await createClient();
  const { error } = await supabase.from("qotd").upsert(
    { day, question_id: questionId, source: "admin", custom_subject: null, custom_body: null, custom_options: null, custom_answer: null, custom_explanation: null },
    { onConflict: "day" },
  );
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/qotd");
  return { ok: true, message: "Scheduled." };
}

/** Removes a day's choice so the server picks one automatically. */
export async function clearDay(day: string): Promise<ActionResult> {
  await editors();
  if (!isDay(day)) return { ok: false, error: "Choose a day" };
  const supabase = await createClient();
  const { error } = await supabase.from("qotd").delete().eq("day", day);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/qotd");
  return { ok: true, message: "That day is back to automatic." };
}

const Own = z.object({
  day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Choose a day"),
  subject: z.string().trim().max(60),
  body: z.string().trim().min(3, "Write the question").max(4000),
  A: z.string().trim().min(1, "Write option A").max(500),
  B: z.string().trim().min(1, "Write option B").max(500),
  C: z.string().trim().min(1, "Write option C").max(500),
  D: z.string().trim().min(1, "Write option D").max(500),
  E: z.string().trim().max(500),
  answer: z.enum(["A", "B", "C", "D", "E"], { message: "Choose the correct answer" }),
  explanation: z.string().trim().max(8000),
}).refine((o) => o.answer !== "E" || o.E.length > 0, { message: "The correct answer is E, so write option E" });

/** The admin's own question for a day (any question, not only past questions). */
export async function saveOwnQuestion(form: FormData): Promise<ActionResult> {
  await editors();
  const p = Own.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the question" };
  const o = p.data;
  const options: Record<string, string> = { A: o.A, B: o.B, C: o.C, D: o.D };
  if (o.E) options.E = o.E;
  const supabase = await createClient();
  const { error } = await supabase.from("qotd").upsert(
    { day: o.day, question_id: null, source: "admin", custom_subject: o.subject || null, custom_body: o.body, custom_options: options, custom_answer: o.answer, custom_explanation: o.explanation || null },
    { onConflict: "day" },
  );
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/qotd");
  return { ok: true, message: "Saved." };
}
