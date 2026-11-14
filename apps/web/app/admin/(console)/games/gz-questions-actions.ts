"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

// SolutionTee's own game questions (owner, 12 Nov 2026): CSV per subject, and where game questions come from.
// Students never see which source a question came from.

const Source = z.enum(["jamb", "own", "both"]);

/** games.gz.source (all subjects) and games.gz.sources.<subject_id> (one subject; "" = follow all subjects). */
export async function saveGzSource(input: unknown): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const p = z.object({ source: Source, sources: z.record(z.string().regex(/^\d+$/), z.union([Source, z.literal("")])) }).safeParse(input);
  if (!p.success) return { ok: false, error: "Check the choices" };
  const sources = Object.fromEntries(Object.entries(p.data.sources).filter(([, v]) => v));
  const supabase = await createClient();
  const { data: cur } = await supabase.from("app_settings").select("value").eq("key", "games").maybeSingle();
  const value = (cur?.value ?? {}) as Record<string, unknown>;
  const gz = { ...((value.gz ?? {}) as Record<string, unknown>), source: p.data.source, sources };
  const { error } = await supabase.from("app_settings").upsert({ key: "games", value: { ...value, gz } });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/games");
  return { ok: true, message: "Saved. New games use these questions." };
}

const Row = z.object({
  body: z.string().trim().min(3).max(2000),
  options: z.record(z.enum(["A", "B", "C", "D", "E"]), z.string().trim().min(1).max(400)),
  answer: z.enum(["A", "B", "C", "D", "E"]),
  difficulty: z.enum(["easy", "medium", "hard"]),
});

const QUIZ_GAMES = ["duel", "rush", "survival", "relay"] as const;

/** Adds checked rows from a CSV as live game questions for one subject (one batch, so it can be undone). [games]: the
 *  quiz games that may use them (empty or null = all four). */
export async function importGzQuestions(subjectId: number, file: string, rows: unknown[], games: string[] | null = null): Promise<ActionResult<{ inserted: number; batch: string }>> {
  const staff = await requireStaff(["super_admin", "admin", "editor"]);
  const only = (games ?? []).filter((g): g is (typeof QUIZ_GAMES)[number] => (QUIZ_GAMES as readonly string[]).includes(g));
  if (!Number.isInteger(subjectId) || subjectId < 1) return { ok: false, error: "Choose a subject" };
  if (!Array.isArray(rows) || !rows.length) return { ok: false, error: "No questions to add" };
  if (rows.length > 5000) return { ok: false, error: "At most 5,000 questions per file. Split the file." };
  const clean: z.infer<typeof Row>[] = [];
  for (const [i, r] of rows.entries()) {
    const p = Row.safeParse(r);
    if (!p.success) return { ok: false, error: `Row ${i + 2}: ${p.error.issues[0]?.message ?? "check it"}` };
    if (!p.data.options[p.data.answer]) return { ok: false, error: `Row ${i + 2}: the answer letter has no option` };
    clean.push(p.data);
  }
  const batch = `${file.slice(0, 60)} · ${new Date().toISOString().slice(0, 16).replace("T", " ")}`;
  const supabase = await createClient();
  let inserted = 0;
  for (let i = 0; i < clean.length; i += 500) {
    const chunk = clean.slice(i, i + 500).map((r) => ({ ...r, subject_id: subjectId, batch, created_by: staff.id, active: true, games: only.length && only.length < 4 ? only : null }));
    const { error } = await supabase.from("gz_questions").insert(chunk);
    if (error) return { ok: false, error: `${friendlyError(error)} (${inserted} were added before this)` };
    inserted += chunk.length;
  }
  revalidatePath("/admin/games");
  return { ok: true, message: `${inserted} questions added. They are live in games now.`, data: { inserted, batch } };
}

export type GzQuestionRow = { id: number; subject_id: number; body: string; options: Record<string, string>; answer: string; difficulty: string; active: boolean; batch: string | null; games: string[] | null };

export async function listGzQuestions(subjectId: number | null, search: string, page: number, game?: string): Promise<ActionResult<{ rows: GzQuestionRow[]; total: number; batches: { batch: string; n: number }[] }>> {
  await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  let q = supabase.from("gz_questions").select("id, subject_id, body, options, answer, difficulty, active, batch, games", { count: "exact" });
  if (subjectId) q = q.eq("subject_id", subjectId);
  // A game's tab lists the questions that game can use: its own plus the ones for all quiz games.
  if (game && (QUIZ_GAMES as readonly string[]).includes(game)) q = q.or(`games.is.null,games.cs.{${game}}`);
  const s = search.trim().replace(/[%,()]/g, " ");
  if (s) q = q.ilike("body", `%${s}%`);
  const { data, count, error } = await q.order("id", { ascending: false }).range(page * 50, page * 50 + 49);
  if (error) return { ok: false, error: friendlyError(error) };
  let b = supabase.from("gz_questions").select("batch").not("batch", "is", null).order("id", { ascending: false }).limit(2000);
  if (subjectId) b = b.eq("subject_id", subjectId);
  const { data: bs } = await b;
  const counts = new Map<string, number>();
  for (const r of bs ?? []) counts.set(r.batch as string, (counts.get(r.batch as string) ?? 0) + 1);
  return {
    ok: true,
    data: { rows: (data ?? []) as GzQuestionRow[], total: count ?? 0, batches: [...counts].slice(0, 8).map(([batch, n]) => ({ batch, n })) },
  };
}

export async function setGzQuestion(id: number, active: boolean): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const { error } = await supabase.from("gz_questions").update({ active }).eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/games");
  return { ok: true, message: active ? "Live in games." : "Hidden from games." };
}

export async function deleteGzQuestion(id: number): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const { error } = await supabase.from("gz_questions").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/games");
  return { ok: true, message: "Deleted." };
}

/** Removes every question from one CSV import. */
export async function undoGzBatch(batch: string): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const { error, count } = await supabase.from("gz_questions").delete({ count: "exact" }).eq("batch", batch);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/games");
  return { ok: true, message: `${count ?? 0} questions from that file removed.` };
}
