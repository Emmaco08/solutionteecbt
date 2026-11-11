"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const admins = () => requireStaff(["super_admin", "admin"]);

const Settings = z.object({
  on: z.boolean(),
  past_seasons: z.array(z.number().int().min(2020).max(2100)).max(10),
  min_mocks: z.number().int().min(1).max(20),
  names: z.enum(["first-initial", "first"]),
  min_questions: z.number().int().min(4).max(400),
  fast_minutes: z.number().int().min(0).max(120),
  include_staff: z.boolean(),
  exams: z.object({ JAMB: z.boolean(), WAEC: z.boolean(), NECO: z.boolean() }),
  subject_min_questions: z.number().int().min(4).max(200),
  subject_fast_minutes: z.number().int().min(0).max(120),
});

export async function saveLeaderboard(form: FormData): Promise<ActionResult> {
  await admins();
  const p = Settings.safeParse({
    on: form.get("on") === "on",
    past_seasons: form.getAll("past").map(Number),
    min_mocks: Number(form.get("min_mocks")),
    names: form.get("names"),
    min_questions: Number(form.get("min_questions")),
    fast_minutes: Number(form.get("fast_minutes")),
    include_staff: form.get("include_staff") === "on",
    exams: { JAMB: form.get("exam_JAMB") === "on", WAEC: form.get("exam_WAEC") === "on", NECO: form.get("exam_NECO") === "on" },
    subject_min_questions: Number(form.get("subject_min_questions")),
    subject_fast_minutes: Number(form.get("subject_fast_minutes")),
  });
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the settings" };
  const supabase = await createClient();
  // Keep the parts saved elsewhere (the weekly and monthly rewards, D-143).
  const { data: cur } = await supabase.from("app_settings").select("value").eq("key", "leaderboard").maybeSingle();
  const { error } = await supabase.from("app_settings").update({ value: { ...((cur?.value ?? {}) as Record<string, unknown>), ...p.data } }).eq("key", "leaderboard");
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/leaderboard");
  return { ok: true, message: p.data.on ? "Saved. Students can see the leaderboard." : "Saved. The leaderboard is off." };
}

/** Keep a held mock off the board, or let it count. */
export async function reviewMock(attemptId: string, decision: "ok" | "rejected"): Promise<ActionResult> {
  await admins();
  if (!/^[0-9a-f-]{36}$/.test(attemptId)) return { ok: false, error: "Unknown test" };
  const supabase = await createClient();
  const { error } = await supabase.from("leaderboard_reviews").upsert({ attempt_id: attemptId, decision }, { onConflict: "attempt_id" });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/leaderboard");
  return { ok: true, message: decision === "ok" ? "It counts now." : "Kept off the leaderboard." };
}

const Place = z.object({ xp: z.coerce.number().int().min(0).max(10000), days: z.coerce.number().int().min(0).max(90) });
const Rewards = z.object({
  on: z.boolean(),
  boards: z.object({ jamb: z.boolean(), challenges: z.boolean() }),
  week: z.array(Place).length(10),
  month: z.array(Place).length(10),
});

/** Top-10 rewards each week and month (D-143): paid by the server two days after the period closes. */
export async function saveLbRewards(input: unknown): Promise<ActionResult> {
  await admins();
  const p = Rewards.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the rewards" };
  const supabase = await createClient();
  const { data: cur } = await supabase.from("app_settings").select("value").eq("key", "leaderboard").maybeSingle();
  const { error } = await supabase.from("app_settings").update({ value: { ...((cur?.value ?? {}) as Record<string, unknown>), rewards: p.data } }).eq("key", "leaderboard");
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/leaderboard");
  return { ok: true, message: p.data.on ? "Saved. Rewards are paid two days after each week and month ends." : "Saved. Rewards are off." };
}
