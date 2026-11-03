"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const editors = () => requireStaff(["super_admin", "admin", "editor"]);
const lagos = (v: string) => new Date(`${v}:00+01:00`); // form times are Lagos time (WAT, UTC+1 all year)
const uuid = /^[0-9a-f-]{36}$/;

const Ch = z.object({
  id: z.string().optional(),
  title: z.string().trim().min(3, "Title is too short").max(80),
  subtitle: z.string().trim().max(160),
  kind: z.enum(["cash", "event", "practice"]),
  icon: z.enum(["trophy", "function", "atom", "book-open-text", "flask", "globe", "lightning", "star"]),
  exam_code: z.enum(["", "JAMB", "WAEC", "NECO"]),
  starts: z.string().min(10, "Choose when it starts"),
  ends: z.string().min(10, "Choose when it ends"),
  seconds: z.coerce.number().int().min(10).max(300),
  p1: z.coerce.number().int().min(0).max(10_000_000), p2: z.coerce.number().int().min(0).max(10_000_000), p3: z.coerce.number().int().min(0).max(10_000_000),
  reward_text: z.string().trim().max(160),
  premium_days: z.coerce.number().int().min(0).max(366),
  premium_top: z.coerce.number().int().min(0).max(100),
  allowed_exits: z.coerce.number().int().min(0).max(3),
  published: z.boolean(),
  same_questions: z.boolean(),
  mode: z.enum(["mixed", "subject", "fixed"]),
  subject_id: z.coerce.number().int().min(0),
  easy: z.coerce.number().int().min(0).max(50), medium: z.coerce.number().int().min(0).max(50),
  hard: z.coerce.number().int().min(0).max(50), very_hard: z.coerce.number().int().min(0).max(50),
});

/** Create or update a challenge. Returns its id. */
export async function saveChallenge(form: FormData): Promise<ActionResult<{ id: string }>> {
  await editors();
  const p = Ch.safeParse({ ...Object.fromEntries(form), published: form.get("published") === "on", same_questions: form.get("same_questions") === "on" });
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the challenge" };
  const c = p.data;
  const starts = lagos(c.starts), ends = lagos(c.ends);
  if (Number.isNaN(starts.getTime()) || Number.isNaN(ends.getTime())) return { ok: false, error: "Choose valid times" };
  if (ends <= starts) return { ok: false, error: "It must end after it starts" };
  const prizes = [c.p1, c.p2, c.p3].filter((x) => x > 0);
  if (c.mode === "subject" && !c.subject_id) return { ok: false, error: "Choose the subject for this challenge" };
  if (c.mode !== "fixed" && c.easy + c.medium + c.hard + c.very_hard === 0) return { ok: false, error: "Set how many questions of each level a student gets" };
  if (c.kind === "cash" && !prizes.length) return { ok: false, error: "A cash challenge needs at least a 1st prize" };
  const row = {
    title: c.title, subtitle: c.subtitle || null, kind: c.kind, icon: c.icon, exam_code: c.exam_code || null,
    starts_at: starts.toISOString(), ends_at: ends.toISOString(), seconds_per_question: c.seconds,
    prizes: c.kind === "practice" ? [] : prizes, reward_text: c.reward_text || null,
    premium_days: c.premium_days, premium_top: c.premium_top, allowed_exits: c.allowed_exits, published: c.published,
    mode: c.mode, subject_id: c.mode === "subject" ? c.subject_id : null,
    per_level: { easy: c.easy, medium: c.medium, hard: c.hard, very_hard: c.very_hard },
    same_questions: c.mode !== "fixed" && c.same_questions,
  };
  const supabase = await createClient();
  const r = c.id && uuid.test(c.id)
    ? await supabase.from("challenges").update(row).eq("id", c.id).is("closed_at", null).select("id").single()
    : await supabase.from("challenges").insert(row).select("id").single();
  if (r.error) return { ok: false, error: friendlyError(r.error) };
  revalidatePath("/admin/challenges");
  return { ok: true, data: { id: r.data.id }, message: "Saved." };
}

const Q = z.object({
  challenge_id: z.string().regex(uuid),
  body: z.string().trim().min(3, "Write the question").max(4000),
  A: z.string().trim().min(1, "Write option A").max(500), B: z.string().trim().min(1, "Write option B").max(500),
  C: z.string().trim().min(1, "Write option C").max(500), D: z.string().trim().min(1, "Write option D").max(500),
  answer: z.enum(["A", "B", "C", "D"], { message: "Choose the correct answer" }),
  explanation: z.string().trim().max(8000),
  subject_id: z.coerce.number().int().min(0),
  difficulty: z.enum(["easy", "medium", "hard", "very_hard"]),
});

/** A new question written for this challenge (D-029: cash challenges use new questions, not searchable past ones). */
export async function addQuestion(form: FormData): Promise<ActionResult> {
  await editors();
  const p = Q.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the question" };
  const q = p.data;
  const supabase = await createClient();
  const { count } = await supabase.from("challenge_questions").select("id", { count: "exact", head: true }).eq("challenge_id", q.challenge_id);
  const { error } = await supabase.from("challenge_questions").insert({
    challenge_id: q.challenge_id, position: (count ?? 0) + 1, body: q.body,
    options: { A: q.A, B: q.B, C: q.C, D: q.D }, answer: q.answer, explanation: q.explanation || null,
    subject_id: q.subject_id || null, difficulty: q.difficulty,
  });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath(`/admin/challenges/${q.challenge_id}`);
  return { ok: true, message: "Question added." };
}

/** Copies a Free-year past question into the challenge (only Free years, so nothing locked reaches Free students). */
export async function addFromBank(challengeId: string, questionId: string): Promise<ActionResult> {
  await editors();
  if (!uuid.test(challengeId) || !uuid.test(questionId)) return { ok: false, error: "Choose a question" };
  const supabase = await createClient();
  const { data: free } = await supabase.rpc("admin_question_is_free", { p_id: questionId });
  const { data: q, error } = await supabase.from("questions").select("id, body, options, answer, explanation, passage_id, subject_id, difficulty").eq("id", questionId).single();
  if (error || !q) return { ok: false, error: "Question not found" };
  if (!free) return { ok: false, error: "Use a question from a year Free students can open, or write a new one." };
  const { count } = await supabase.from("challenge_questions").select("id", { count: "exact", head: true }).eq("challenge_id", challengeId);
  const opts = q.options as Record<string, string>;
  const { error: e2 } = await supabase.from("challenge_questions").insert({
    challenge_id: challengeId, position: (count ?? 0) + 1, body: q.body, options: { A: opts.A, B: opts.B, C: opts.C, D: opts.D },
    answer: q.answer === "E" ? "A" : q.answer, explanation: q.explanation, source_question_id: q.id,
    subject_id: q.subject_id, difficulty: q.difficulty ?? "medium",
  });
  if (e2) return { ok: false, error: friendlyError(e2) };
  revalidatePath(`/admin/challenges/${challengeId}`);
  return { ok: true, message: "Question added." };
}

export async function removeQuestion(challengeId: string, id: string): Promise<ActionResult> {
  await editors();
  const supabase = await createClient();
  const { data: started } = await supabase.from("challenge_entries").select("id").eq("challenge_id", challengeId).limit(1);
  if (started?.length) return { ok: false, error: "Students have started this challenge, so its questions cannot change." };
  const { error } = await supabase.from("challenge_questions").delete().eq("id", id).eq("challenge_id", challengeId);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath(`/admin/challenges/${challengeId}`);
  return { ok: true, message: "Removed." };
}

export async function closeNow(id: string): Promise<ActionResult> {
  await editors();
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_challenge_close", { p_id: id });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath(`/admin/challenges/${id}`);
  return { ok: true, message: "Closed. Winners are saved and told." };
}

export async function reviewEntry(challengeId: string, entryId: string, decision: "ok" | "dq" | "reinstate"): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_challenge_review", { p_entry: entryId, p_decision: decision });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath(`/admin/challenges/${challengeId}`);
  return { ok: true, message: decision === "dq" ? "Disqualified. The ranking was updated." : decision === "reinstate" ? "Reinstated." : "Marked as fair." };
}

const LEVELS = ["easy", "medium", "hard", "very_hard"] as const;
const LEVEL_WORDS: Record<string, (typeof LEVELS)[number]> = {
  easy: "easy", medium: "medium", hard: "hard", "very hard": "very_hard", very_hard: "very_hard", "very difficult": "very_hard", "extremely difficult": "very_hard", difficult: "hard",
};
export type ImportRow = Record<string, string>;

/** CSV import of challenge questions: subject, difficulty, question, option_a..option_d, answer, explanation (optional). */
export async function importQuestions(challengeId: string, rows: ImportRow[]): Promise<ActionResult<{ added: number; errors: string[] }>> {
  await editors();
  if (!uuid.test(challengeId)) return { ok: false, error: "Unknown challenge" };
  if (!rows.length) return { ok: false, error: "The file has no questions" };
  if (rows.length > 2000) return { ok: false, error: "At most 2,000 questions per file" };
  const supabase = await createClient();
  const { data: started } = await supabase.from("challenge_entries").select("id").eq("challenge_id", challengeId).limit(1);
  if (started?.length) return { ok: false, error: "Students have started this challenge, so its questions cannot change." };
  const { data: subjects } = await supabase.from("subjects").select("id, code, name");
  const find = (v: string) => {
    const k = v.trim().toLowerCase();
    return (subjects ?? []).find((s) => s.code.toLowerCase() === k || s.name.toLowerCase() === k)?.id;
  };
  const { count } = await supabase.from("challenge_questions").select("id", { count: "exact", head: true }).eq("challenge_id", challengeId);
  const errors: string[] = [];
  type NewQ = { challenge_id: string; position: number; subject_id: number; difficulty: string; body: string; options: Record<string, string>; answer: string; explanation: string | null };
  const ok: NewQ[] = [];
  rows.forEach((r, i) => {
    const line = i + 2;
    const get = (k: string) => (r[k] ?? "").trim();
    const subject = find(get("subject"));
    const level = LEVEL_WORDS[get("difficulty").toLowerCase()];
    const answer = get("answer").toUpperCase();
    const opts = { A: get("option_a"), B: get("option_b"), C: get("option_c"), D: get("option_d") };
    if (!subject) return void errors.push(`Line ${line}: unknown subject "${get("subject")}"`);
    if (!level) return void errors.push(`Line ${line}: difficulty must be easy, medium, hard or very hard`);
    if (get("question").length < 3) return void errors.push(`Line ${line}: the question is empty`);
    if (!opts.A || !opts.B || !opts.C || !opts.D) return void errors.push(`Line ${line}: options A to D are needed`);
    if (!["A", "B", "C", "D"].includes(answer)) return void errors.push(`Line ${line}: answer must be A, B, C or D`);
    ok.push({ challenge_id: challengeId, position: (count ?? 0) + ok.length + 1, subject_id: subject, difficulty: level,
      body: get("question").slice(0, 4000), options: opts, answer, explanation: get("explanation").slice(0, 8000) || null });
  });
  if (errors.length) return { ok: true, data: { added: 0, errors: errors.slice(0, 30) }, message: "Nothing was added. Fix these lines and try again." };
  for (let i = 0; i < ok.length; i += 500) {
    const { error } = await supabase.from("challenge_questions").insert(ok.slice(i, i + 500));
    if (error) return { ok: false, error: friendlyError(error) };
  }
  revalidatePath(`/admin/challenges/${challengeId}`);
  return { ok: true, data: { added: ok.length, errors: [] }, message: `${ok.length} questions added.` };
}

/** Accept (reinstate) or reject an appeal; the student gets a notification. */
export async function decideAppeal(id: string, accept: boolean, note: string): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_challenge_appeal", { p_appeal: id, p_accept: accept, p_note: note.slice(0, 500) || undefined });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/challenges");
  return { ok: true, message: accept ? "Accepted. The entry counts again." : "Rejected." };
}

/** Random past questions (Free years only, with levels) for the chosen subjects (D-074). */
export async function addRandom(challengeId: string, subjectIds: number[], count: number): Promise<ActionResult<{ subject: string; added: number; left: number }[]>> {
  await editors();
  if (!uuid.test(challengeId)) return { ok: false, error: "Unknown challenge" };
  const ids = subjectIds.filter((x) => Number.isInteger(x) && x > 0).slice(0, 30);
  if (!ids.length) return { ok: false, error: "Choose at least one subject" };
  if (!Number.isInteger(count) || count < 1 || count > 500) return { ok: false, error: "Choose 1 to 500 questions per subject" };
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_challenge_add_random", { p_id: challengeId, p_subjects: ids, p_count: count });
  if (error) return { ok: false, error: friendlyError(error) };
  const rows = (data ?? []) as { subject: string; added: number; left: number }[];
  const added = rows.reduce((n, r) => n + r.added, 0);
  revalidatePath(`/admin/challenges/${challengeId}`);
  return { ok: true, data: rows, message: added ? `${added} past questions added.` : "No more Free past questions left for these subjects." };
}

export async function setLevel(challengeId: string, questionId: string, level: string): Promise<ActionResult> {
  await editors();
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_challenge_set_level", { p_question: questionId, p_level: level });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath(`/admin/challenges/${challengeId}`);
  return { ok: true, message: "Level changed." };
}

/** Copy a challenge (settings and questions) to a new start time; hidden until published. */
export async function copyChallenge(id: string, starts: string): Promise<ActionResult<{ id: string }>> {
  await editors();
  const t = lagos(starts);
  if (!uuid.test(id) || Number.isNaN(t.getTime())) return { ok: false, error: "Choose when the copy starts" };
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_challenge_copy", { p_id: id, p_starts: t.toISOString() });
  if (error || !data) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/challenges");
  return { ok: true, data: { id: data as string }, message: "Copied. Check it, then tick “Show to students”." };
}

export type LiveData = {
  status: string;
  summary: { joined: number; playing: number; finished: number; disqualified: number; flagged: number; appeals_pending: number; avg_pct: number | null; avg_ms: number | null; best: number | null };
  board: { id: string; rank: number | null; name: string | null; state: string | null; status: string; review: string | null; score: number; answered: number; total: number; time_ms: number; exits: number; flags: string[]; dq_reason: string | null; prize: number | null; started_at: string; finished_at: string | null }[];
  by_subject: { subject: string; answers: number; right_pct: number }[];
  by_level: { level: string; answers: number; right_pct: number; avg_ms: number }[];
  spread: { from: number; students: number }[];
  questions: { id: string; body: string; subject: string | null; level: string; answer: string; answers: number; right_pct: number | null; avg_ms: number | null; no_answer: number; top_wrong: string | null }[];
  exits: { reason: string; students: number }[];
  students_per_subject: Record<string, number>;
  paper_size: number;
};

/** Live leaderboard and analysis (polled every 15 s by the admin page). */
export async function liveData(id: string): Promise<ActionResult<LiveData>> {
  await requireStaff();
  if (!uuid.test(id)) return { ok: false, error: "Unknown challenge" };
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_challenge_live", { p_id: id });
  if (error) return { ok: false, error: friendlyError(error) };
  return { ok: true, data: data as unknown as LiveData };
}

/** Let students review their answers after the end, or not (any time, also after it ends) — D-075. */
export async function setReview(id: string, on: boolean): Promise<ActionResult> {
  await editors();
  if (!uuid.test(id)) return { ok: false, error: "Unknown challenge" };
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_challenge_set_review", { p_id: id, p_on: on });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath(`/admin/challenges/${id}`);
  return { ok: true, message: on ? "Students can review their answers after it ends." : "Answer review is off." };
}
