"use server";
import { revalidatePath } from "next/cache";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

/** Lift the AI pause, block the AI tutor for good, or ban the whole account (big update 2, A8). */
export async function decide(userId: string, decision: "lift" | "block_ai" | "ban", note: string): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin"]);
  if (decision !== "lift" && note.trim().length < 3) return { ok: false, error: "Write the reason (the student sees it)" };
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_ai_safety_decide", { p_user: userId, p_decision: decision, p_note: note.slice(0, 500) || undefined });
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/ai-safety");
  return { ok: true, message: decision === "lift" ? "AI tutor opened again." : decision === "block_ai" ? "AI tutor blocked for this account." : "Account banned." };
}
