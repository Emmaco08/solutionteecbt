"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const editors = () => requireStaff(["super_admin", "admin", "editor"]);

const Line = z.object({
  id: z.coerce.number().int().positive().optional(),
  body: z.string().trim().min(5, "Write at least 5 letters").max(280, "Keep it under 280 letters"),
  author: z.string().trim().max(80).optional().transform((v) => (v ? v : null)),
  kind: z.enum(["quote", "tip", "fact"]),
  sort: z.coerce.number().int().min(0).max(100000).default(0),
});

/** Adds a line, or saves changes to one. */
export async function saveLine(input: unknown): Promise<ActionResult> {
  await editors();
  const p = Line.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const { id, ...row } = p.data;
  const supabase = await createClient();
  const r = id ? await supabase.from("motivation_quotes").update(row).eq("id", id) : await supabase.from("motivation_quotes").insert(row);
  if (r.error) return { ok: false, error: friendlyError(r.error) };
  revalidatePath("/admin/motivation");
  return { ok: true, message: id ? "Saved." : "Added." };
}

export async function setActive(id: number, active: boolean): Promise<ActionResult> {
  await editors();
  const supabase = await createClient();
  const { error } = await supabase.from("motivation_quotes").update({ active }).eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/motivation");
  return { ok: true, message: active ? "Shown again." : "Paused." };
}

export async function deleteLine(id: number): Promise<ActionResult> {
  await editors();
  const supabase = await createClient();
  const { error } = await supabase.from("motivation_quotes").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/motivation");
  return { ok: true, message: "Deleted." };
}
