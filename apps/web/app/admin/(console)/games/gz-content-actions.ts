"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

// Admin → Games tabs (owner, 13 Nov 2026): CSV uploads for Word War words, Memory Flash cards and Comprehension Clash
// passages, the passage list, and the reading speed. Rows are checked in the browser first and again here.

const EDITORS = ["super_admin", "admin", "editor"] as const;
const batchName = (file: string) => `${file.slice(0, 60)} · ${new Date().toISOString().slice(0, 16).replace("T", " ")}`;

const WordRow = z.object({
  kind: z.enum(["synonym", "antonym", "spelling"]),
  word: z.string().trim().max(40),
  answer: z.string().trim().min(1).max(40),
  wrong: z.array(z.string().trim().min(1).max(40)).length(3),
  difficulty: z.enum(["easy", "medium", "hard"]).default("medium"),
});

export async function importGzWords(rows: unknown[]): Promise<ActionResult<{ inserted: number }>> {
  await requireStaff([...EDITORS]);
  if (!Array.isArray(rows) || !rows.length) return { ok: false, error: "No words to add" };
  if (rows.length > 3000) return { ok: false, error: "At most 3,000 words per file. Split the file." };
  const clean: z.infer<typeof WordRow>[] = [];
  for (const [i, r] of rows.entries()) {
    const p = WordRow.safeParse(r);
    if (!p.success) return { ok: false, error: `Row ${i + 2}: ${p.error.issues[0]?.message ?? "check it"}` };
    if (p.data.kind !== "spelling" && !p.data.word) return { ok: false, error: `Row ${i + 2}: add the word` };
    clean.push(p.data);
  }
  const supabase = await createClient();
  for (let i = 0; i < clean.length; i += 500) {
    const { error } = await supabase.from("gz_words").insert(clean.slice(i, i + 500).map((r) => ({ ...r, active: true })));
    if (error) return { ok: false, error: `${friendlyError(error)} (${i} were added before this)` };
  }
  revalidatePath("/admin/games");
  return { ok: true, message: `${clean.length} words added. They are live in Word War now.`, data: { inserted: clean.length } };
}

const CardRow = z.object({
  subject_id: z.number().int().positive(),
  front: z.string().trim().min(1).max(30),
  back: z.string().trim().min(1).max(30),
  difficulty: z.enum(["easy", "medium", "hard"]).default("medium"),
});

export async function importGzCards(rows: unknown[]): Promise<ActionResult<{ inserted: number }>> {
  await requireStaff([...EDITORS]);
  if (!Array.isArray(rows) || !rows.length) return { ok: false, error: "No cards to add" };
  if (rows.length > 3000) return { ok: false, error: "At most 3,000 cards per file. Split the file." };
  const clean: z.infer<typeof CardRow>[] = [];
  for (const [i, r] of rows.entries()) {
    const p = CardRow.safeParse(r);
    if (!p.success) return { ok: false, error: `Row ${i + 2}: ${p.error.issues[0]?.message ?? "check it"}` };
    clean.push(p.data);
  }
  const supabase = await createClient();
  for (let i = 0; i < clean.length; i += 500) {
    const { error } = await supabase.from("gz_cards").insert(clean.slice(i, i + 500).map((r) => ({ ...r, active: true })));
    if (error) return { ok: false, error: `${friendlyError(error)} (${i} were added before this)` };
  }
  revalidatePath("/admin/games");
  return { ok: true, message: `${clean.length} card pairs added. They are live in Memory Flash now.`, data: { inserted: clean.length } };
}

const Q = z.object({
  kind: z.enum(["main", "intent", "vocab", "inference", "detail", "other"]),
  body: z.string().trim().min(3).max(1000),
  options: z.record(z.enum(["A", "B", "C", "D", "E"]), z.string().trim().min(1).max(400)),
  answer: z.enum(["A", "B", "C", "D", "E"]),
});
const Passage = z.object({
  title: z.string().trim().max(160),
  body: z.string().trim().min(200, "A passage needs at least 200 characters").max(6000, "A passage can have at most 6,000 characters"),
  difficulty: z.enum(["easy", "medium", "hard"]),
  questions: z.array(Q).min(3, "Each passage needs at least 3 questions").max(10),
});

export async function importGzPassages(file: string, passages: unknown[]): Promise<ActionResult<{ inserted: number; batch: string }>> {
  const staff = await requireStaff([...EDITORS]);
  if (!Array.isArray(passages) || !passages.length) return { ok: false, error: "No passages to add" };
  if (passages.length > 300) return { ok: false, error: "At most 300 passages per file. Split the file." };
  const clean: z.infer<typeof Passage>[] = [];
  for (const [i, x] of passages.entries()) {
    const p = Passage.safeParse(x);
    if (!p.success) return { ok: false, error: `Passage ${i + 1}: ${p.error.issues[0]?.message ?? "check it"}` };
    if (p.data.questions.some((q) => !q.options[q.answer])) return { ok: false, error: `Passage ${i + 1}: an answer letter has no option` };
    clean.push(p.data);
  }
  const batch = batchName(file);
  const supabase = await createClient();
  let inserted = 0;
  for (const p of clean) {
    const { data, error } = await supabase
      .from("gz_passages")
      .insert({ title: p.title, body: p.body, difficulty: p.difficulty, batch, created_by: staff.id, active: true })
      .select("id")
      .single();
    if (error || !data) return { ok: false, error: `${friendlyError(error)} (${inserted} passages were added before this)` };
    const qs = p.questions.map((q, i) => ({ passage_id: data.id, kind: q.kind, body: q.body, options: q.options, answer: q.answer, sort: i }));
    const r = await supabase.from("gz_passage_questions").insert(qs);
    if (r.error) {
      await supabase.from("gz_passages").delete().eq("id", data.id);
      return { ok: false, error: `${friendlyError(r.error)} (${inserted} passages were added before this)` };
    }
    inserted++;
  }
  revalidatePath("/admin/games");
  return { ok: true, message: `${inserted} passages added. They are live in Comprehension Clash now.`, data: { inserted, batch } };
}

export type GzPassageRow = {
  id: number;
  title: string;
  body: string;
  difficulty: string;
  active: boolean;
  batch: string | null;
  questions: { kind: string; body: string; options: Record<string, string>; answer: string }[];
};

export async function listGzPassages(search: string, page: number): Promise<ActionResult<{ rows: GzPassageRow[]; total: number; batches: { batch: string; n: number }[] }>> {
  await requireStaff([...EDITORS]);
  const supabase = await createClient();
  let q = supabase.from("gz_passages").select("id, title, body, difficulty, active, batch, gz_passage_questions(kind, body, options, answer, sort)", { count: "exact" });
  const s = search.trim().replace(/[%,()]/g, " ");
  if (s) q = q.or(`title.ilike.%${s}%,body.ilike.%${s}%`);
  const { data, count, error } = await q.order("id", { ascending: false }).range(page * 20, page * 20 + 19);
  if (error) return { ok: false, error: friendlyError(error) };
  const { data: bs } = await supabase.from("gz_passages").select("batch").not("batch", "is", null).order("id", { ascending: false }).limit(1000);
  const counts = new Map<string, number>();
  for (const r of bs ?? []) counts.set(r.batch as string, (counts.get(r.batch as string) ?? 0) + 1);
  type Raw = Omit<GzPassageRow, "questions"> & { gz_passage_questions: (GzPassageRow["questions"][number] & { sort: number })[] | null };
  const rows = ((data ?? []) as unknown as Raw[]).map(({ gz_passage_questions, ...p }) => ({
    ...p,
    questions: [...(gz_passage_questions ?? [])].sort((a, b) => a.sort - b.sort),
  }));
  return { ok: true, data: { rows, total: count ?? 0, batches: [...counts].slice(0, 8).map(([batch, n]) => ({ batch, n })) } };
}

export async function setGzPassage(id: number, active: boolean): Promise<ActionResult> {
  await requireStaff([...EDITORS]);
  const supabase = await createClient();
  const { error } = await supabase.from("gz_passages").update({ active }).eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/games");
  return { ok: true, message: active ? "Live in Comprehension Clash." : "Hidden from the game." };
}

export async function deleteGzPassage(id: number): Promise<ActionResult> {
  await requireStaff([...EDITORS]);
  const supabase = await createClient();
  const { error } = await supabase.from("gz_passages").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/games");
  return { ok: true, message: "Passage deleted." };
}

export async function undoGzPassageBatch(batch: string): Promise<ActionResult> {
  await requireStaff([...EDITORS]);
  const supabase = await createClient();
  const { error, count } = await supabase.from("gz_passages").delete({ count: "exact" }).eq("batch", batch);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/games");
  return { ok: true, message: `${count ?? 0} passages from that file removed.` };
}

/** Comprehension Clash reading speed (words per minute): games.gz.games.reading.wpm. Questions per game are in the settings table. */
export async function saveGzReading(input: unknown): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const p = z.object({ wpm: z.coerce.number().int().min(120).max(600) }).safeParse(input);
  if (!p.success) return { ok: false, error: "Words per minute: 120 to 600." };
  const supabase = await createClient();
  const { data: cur } = await supabase.from("app_settings").select("value").eq("key", "games").maybeSingle();
  const value = (cur?.value ?? {}) as Record<string, unknown>;
  const gz = (value.gz ?? {}) as Record<string, unknown>;
  const games = (gz.games ?? {}) as Record<string, Record<string, unknown>>;
  const next = { ...value, gz: { ...gz, games: { ...games, reading: { ...(games.reading ?? {}), wpm: p.data.wpm } } } };
  const { error } = await supabase.from("app_settings").upsert({ key: "games", value: next });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/games");
  return { ok: true, message: "Saved. New games use this reading speed." };
}
