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
});

export async function saveLeaderboard(form: FormData): Promise<ActionResult> {
  await admins();
  const p = Settings.safeParse({
    on: form.get("on") === "on",
    past_seasons: form.getAll("past").map(Number),
    min_mocks: Number(form.get("min_mocks")),
    names: form.get("names"),
  });
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the settings" };
  const supabase = await createClient();
  const { error } = await supabase.from("app_settings").update({ value: p.data }).eq("key", "leaderboard");
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
