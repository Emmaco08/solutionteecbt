"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const n = (min: number, max: number) => z.coerce.number().int().min(min).max(max);

const Settings = z.object({
  on: z.boolean(),
  questions: n(5, 20), seconds: n(5, 60), daily_games: n(1, 500), daily_xp: n(0, 1000), arena_min_players: n(2, 500),
  xp: z.object({ play: n(0, 100), win: n(0, 200), beat_ai: n(0, 300), arena_play: n(0, 100), arena_top: z.array(n(0, 500)).length(3) }),
});

/** Games settings (D-150). Merged into the stored value so other keys stay. */
export async function saveGamesSettings(input: unknown): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const p = Settings.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the numbers" };
  const supabase = await createClient();
  const { data: cur } = await supabase.from("app_settings").select("value").eq("key", "games").maybeSingle();
  const { error } = await supabase.from("app_settings").upsert({ key: "games", value: { ...((cur?.value ?? {}) as Record<string, unknown>), ...p.data } });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/games");
  return { ok: true, message: p.data.on ? "Saved. Games are on in the app." : "Saved. Games are off in the app." };
}

const Arena = z.object({
  id: z.string().uuid().optional(),
  title: z.string().trim().min(3, "Give the arena a title").max(80),
  exam_id: n(1, 32767),
  subject_id: z.coerce.number().int().positive().optional().or(z.literal("").transform(() => undefined)),
  starts_at: z.string().min(10, "Choose the date and time"),
  q_count: n(5, 60), seconds: n(8, 60), gap: n(3, 15), max_players: n(2, 500),
  status: z.enum(["draft", "published", "cancelled"]),
});

/** Adds or saves a Live Exam Arena. The questions are picked when the first student joins (free-plan years). */
export async function saveArena(input: unknown): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin", "editor"]);
  const p = Arena.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const { id, starts_at, subject_id, ...rest } = p.data;
  const start = new Date(/[zZ]|[+-]\d\d:\d\d$/.test(starts_at) ? starts_at : `${starts_at}:00+01:00`);
  if (Number.isNaN(start.getTime())) return { ok: false, error: "Choose the date and time" };
  const supabase = await createClient();
  let fresh = false;
  if (id) {
    const { data: old } = await supabase.from("arenas").select("starts_at, question_ids, exam_id, subject_id, q_count").eq("id", id).maybeSingle();
    const started = old ? new Date(old.starts_at).getTime() < Date.now() : false;
    if (old?.question_ids && started && start.toISOString() !== new Date(old.starts_at).toISOString())
      return { ok: false, error: "This arena has started. Its time can no longer change." };
    // A new exam, subject or number of questions picks new questions when the next student joins (only before the start).
    fresh = !!old && !started && (old.exam_id !== rest.exam_id || old.subject_id !== (subject_id ?? null) || old.q_count !== rest.q_count);
  }
  const row = { ...rest, subject_id: subject_id ?? null, starts_at: start.toISOString(), ...(fresh ? { question_ids: null } : {}) };
  const r = id ? await supabase.from("arenas").update(row).eq("id", id) : await supabase.from("arenas").insert(row);
  if (r.error) return { ok: false, error: friendlyError(r.error) };
  revalidatePath("/admin/games");
  return { ok: true, message: rest.status === "published" ? "Saved. Students see it in Games." : "Saved." };
}

export async function deleteArena(id: string): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const { count } = await supabase.from("arena_players").select("user_id", { count: "exact", head: true }).eq("arena_id", id);
  if (count) return { ok: false, error: "Students joined this arena. Cancel it instead." };
  const { error } = await supabase.from("arenas").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/games");
  return { ok: true, message: "Arena deleted." };
}
