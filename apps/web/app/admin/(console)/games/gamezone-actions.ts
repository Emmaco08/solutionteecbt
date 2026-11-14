"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

// Game Zone v2 admin (D-157): settings and XP per game, and the Word War / Memory Flash content.

const GAMES = ["duel", "reading", "rush", "survival", "blitz", "words", "memory", "relay"] as const;
const n = (min: number, max: number) => z.coerce.number().int().min(min).max(max);
/** Blank means "use the default". */
const opt = (min: number, max: number) => z.union([z.literal("").transform(() => undefined), z.null().transform(() => undefined), n(min, max)]).optional();

const Game = z.object({ on: z.boolean(), xp_play: opt(0, 500), xp_win: opt(0, 500), seconds: opt(5, 300), rounds: opt(3, 30) });
// Comprehension Clash takes 3 to 6 questions (the server clamps it too).

const Settings = z.object({
  queue_seconds: n(5, 60),
  daily_matches: n(5, 500),
  xp_play: n(0, 500),
  xp_win: n(0, 500),
  xp_ranked_win: n(0, 500),
  xp_streak: n(0, 500),
  games: z.record(z.enum(GAMES), Game),
});

/** Saves games.gz in app_settings; other games settings stay. */
export async function saveGzSettings(input: unknown): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  const p = Settings.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the numbers" };
  const supabase = await createClient();
  const { data: cur } = await supabase.from("app_settings").select("value").eq("key", "games").maybeSingle();
  const value = (cur?.value ?? {}) as Record<string, unknown>;
  // Keys this form does not edit (e.g. Comprehension Clash reading speed) stay.
  const old = (((value.gz ?? {}) as Record<string, unknown>).games ?? {}) as Record<string, Record<string, unknown>>;
  const FORM_KEYS = ["on", "xp_play", "xp_win", "seconds", "rounds"];
  const games = Object.fromEntries(
    Object.entries(p.data.games).map(([k, v]) => [
      k,
      {
        ...Object.fromEntries(Object.entries(old[k] ?? {}).filter(([x]) => !FORM_KEYS.includes(x))),
        ...Object.fromEntries(Object.entries(v).filter(([, x]) => x !== undefined)),
      },
    ]),
  );
  const gz = { ...((value.gz ?? {}) as Record<string, unknown>), ...p.data, games };
  const { error } = await supabase.from("app_settings").upsert({ key: "games", value: JSON.parse(JSON.stringify({ ...value, gz })) });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/games");
  return { ok: true, message: "Saved. The app uses the new settings from the next game." };
}

const Word = z.object({
  id: z.coerce.number().int().positive().optional(),
  kind: z.enum(["synonym", "antonym", "spelling"]),
  word: z.string().trim().max(40),
  answer: z.string().trim().min(1, "Add the right answer").max(40),
  wrong: z.array(z.string().trim().min(1).max(40)).min(3, "Add 3 wrong answers").max(3),
  active: z.boolean(),
});

export async function saveGzWord(input: unknown): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin", "editor"]);
  const p = Word.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the word" };
  const { id, ...row } = p.data;
  if (row.kind !== "spelling" && !row.word) return { ok: false, error: "Add the word" };
  if (new Set([row.answer.toLowerCase(), ...row.wrong.map((w) => w.toLowerCase())]).size < 4) return { ok: false, error: "The 4 options must all be different" };
  const supabase = await createClient();
  const r = id ? await supabase.from("gz_words").update(row).eq("id", id) : await supabase.from("gz_words").insert(row);
  if (r.error) return { ok: false, error: friendlyError(r.error) };
  revalidatePath("/admin/games");
  return { ok: true, message: row.active ? "Saved. It is live in Word War." : "Saved (waiting for review)." };
}

const Card = z.object({
  id: z.coerce.number().int().positive().optional(),
  subject_id: n(1, 32767),
  front: z.string().trim().min(1, "Add the front").max(30, "Keep cards short (30 letters)"),
  back: z.string().trim().min(1, "Add the back").max(30, "Keep cards short (30 letters)"),
  active: z.boolean(),
});

export async function saveGzCard(input: unknown): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin", "editor"]);
  const p = Card.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the card" };
  const { id, ...row } = p.data;
  if (row.front.toLowerCase() === row.back.toLowerCase()) return { ok: false, error: "The two faces must be different" };
  const supabase = await createClient();
  const r = id ? await supabase.from("gz_cards").update(row).eq("id", id) : await supabase.from("gz_cards").insert(row);
  if (r.error) return { ok: false, error: friendlyError(r.error) };
  revalidatePath("/admin/games");
  return { ok: true, message: row.active ? "Saved. It is live in Memory Flash." : "Saved (waiting for review)." };
}

/** Turn many words or cards on or off at once ("Approve all"). */
export async function setGzContent(kind: "words" | "cards", ids: number[] | "all", active: boolean): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const table = kind === "words" ? "gz_words" : "gz_cards";
  const q = supabase.from(table).update({ active });
  const r = ids === "all" ? await q.gte("id", 0) : await q.in("id", ids.slice(0, 1000));
  if (r.error) return { ok: false, error: friendlyError(r.error) };
  revalidatePath("/admin/games");
  return { ok: true, message: active ? "Approved. Students can play with them now." : "Hidden from students." };
}

export async function deleteGzContent(kind: "words" | "cards", id: number): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const r = await supabase.from(kind === "words" ? "gz_words" : "gz_cards").delete().eq("id", id);
  if (r.error) return { ok: false, error: friendlyError(r.error) };
  revalidatePath("/admin/games");
  return { ok: true, message: "Deleted." };
}
