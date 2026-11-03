"use server";
import { revalidatePath } from "next/cache";
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
  const { error } = await supabase.from("qotd").upsert({ day, question_id: questionId, source: "admin" }, { onConflict: "day" });
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
