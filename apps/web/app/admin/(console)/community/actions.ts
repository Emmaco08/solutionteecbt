"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient, createServiceClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const admins = () => requireStaff(["super_admin", "admin"]);
type Kind = "post" | "comment";
const table = (k: Kind) => (k === "post" ? "community_posts" : "community_comments");

async function recount(postId: string) {
  const supabase = await createClient();
  const { count } = await supabase.from("community_comments").select("id", { count: "exact", head: true }).eq("post_id", postId).eq("status", "shown");
  await supabase.from("community_posts").update({ comments_count: count ?? 0 } as never).eq("id", postId);
}

/**
 * Staff decision (D-151). A waiting post or comment goes through community_decide (the same path as the AI, so the
 * author is told and counts stay right); shown / hidden items are switched directly and logged in the audit table.
 */
export async function moderate(kind: Kind, id: string, action: "show" | "reject" | "hide" | "delete", reason?: string): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { data: row, error: e1 } = await supabase.from(table(kind)).select("status" + (kind === "comment" ? ", post_id" : "")).eq("id", kind === "post" ? id : Number(id)).maybeSingle();
  if (e1) return { ok: false, error: friendlyError(e1) };
  if (!row) return { ok: false, error: "It was already deleted." };
  const r = row as unknown as { status: string; post_id?: string };
  if (action === "delete") {
    const { error } = await supabase.from(table(kind)).delete().eq("id", kind === "post" ? id : Number(id));
    if (error) return { ok: false, error: friendlyError(error) };
  } else if (r.status === "pending" && (action === "show" || action === "reject")) {
    const svc = await createServiceClient();
    const { error } = await svc.rpc("community_decide", { p_kind: kind, p_id: id, p_ok: action === "show", p_reason: reason?.trim() || "It does not follow the community rules." });
    if (error) return { ok: false, error: friendlyError(error) };
  } else {
    const status = action === "show" ? "shown" : action === "hide" ? "hidden" : "rejected";
    const { error } = await supabase.from(table(kind)).update({ status, reason: action === "show" ? null : (reason?.trim() || "Hidden by SolutionTee staff"), checked_at: new Date().toISOString() })
      .eq("id", kind === "post" ? id : Number(id));
    if (error) return { ok: false, error: friendlyError(error) };
  }
  if (kind === "comment" && r.post_id) await recount(r.post_id);
  revalidatePath("/admin/community");
  return { ok: true, message: action === "show" ? "Shown to students." : action === "delete" ? "Deleted." : action === "hide" ? "Hidden." : "Rejected. The student is told why." };
}

const n = (min: number, max: number) => z.coerce.number().int().min(min).max(max);
const Settings = z.object({ on: z.boolean(), ai_check: z.boolean(), daily_posts: n(1, 100), daily_comments: n(1, 500), ai_answers_daily: n(0, 50), report_hide: n(1, 50) });

export async function saveCommunitySettings(input: unknown): Promise<ActionResult> {
  await admins();
  const p = Settings.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the numbers" };
  const supabase = await createClient();
  const { data: cur } = await supabase.from("app_settings").select("value").eq("key", "community").maybeSingle();
  const { error } = await supabase.from("app_settings").upsert({ key: "community", value: { ...((cur?.value ?? {}) as Record<string, unknown>), ...p.data } });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/community");
  return { ok: true, message: p.data.on ? "Saved." : "Saved. Community is paused in the app." };
}

/** Staff decision on a waiting @handle and bio (D-155), through the same path as the AI so the student is told. */
export async function decideProfile(user: string, ok: boolean, reason?: string): Promise<ActionResult> {
  await admins();
  if (!z.string().uuid().safeParse(user).success) return { ok: false, error: "Unknown student" };
  const svc = await createServiceClient();
  const { data, error } = await svc.rpc("community_profile_decide", { p_user: user, p_ok: ok, p_reason: reason?.trim() || null });
  if (error) return { ok: false, error: friendlyError(error) };
  if (!(data as { ok?: boolean } | null)?.ok) return { ok: false, error: "It was already decided." };
  revalidatePath("/admin/community");
  return { ok: true, message: ok ? "Allowed. It shows now." : "Not allowed. The student is told why." };
}
