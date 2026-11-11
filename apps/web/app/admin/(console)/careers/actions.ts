"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const editors = () => requireStaff(["super_admin", "admin", "editor"]);
const opt = (max: number) => z.string().trim().max(max, `Keep it under ${max} letters`).optional().transform((v) => (v ? v : null));
/** One item per line; blank lines dropped. */
const lines = (maxItems: number) =>
  z.string().max(4000).optional().transform((v) => (v ?? "").split("\n").map((s) => s.trim()).filter(Boolean).slice(0, maxItems));

const Career = z.object({
  id: z.coerce.number().int().positive().optional(),
  name: z.string().trim().min(2, "Give the career a name").max(80),
  field: z.string().trim().min(2, "Choose a group").max(40),
  course: z.string().trim().min(2, "Write the university course").max(120),
  years: z.coerce.number().int().min(1).max(8),
  summary: z.string().trim().min(10, "Say in a line or two what the job is").max(600),
  skills: lines(8),
  universities: lines(10),
  earnings: opt(300),
  jamb_subjects: z.array(z.string().regex(/^[a-z]{2,5}$/)).max(3, "Pick at most 3 subjects (English is added by itself)")
    .refine((a) => new Set(a).size === a.length, "Each JAMB subject can be picked once"),
  jamb_note: opt(300),
  olevel: opt(300),
  after_school: opt(300),
  sort: z.coerce.number().int().min(0).max(100000).default(0),
  active: z.boolean(),
  checked: z.boolean(),
});

/** Adds a career, or saves changes to one (D-137). */
export async function saveCareer(input: unknown): Promise<ActionResult> {
  await editors();
  const p = Career.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const { id, ...row } = p.data;
  const supabase = await createClient();
  const r = id ? await supabase.from("careers").update(row).eq("id", id) : await supabase.from("careers").insert(row);
  if (r.error) return { ok: false, error: r.error.code === "23505" ? "A career with this name already exists." : friendlyError(r.error) };
  revalidatePath("/admin/careers");
  return { ok: true, message: id ? "Saved. Phones get it the next time they open Careers." : "Added." };
}

export async function setCareerFlag(id: number, flag: "active" | "checked", value: boolean): Promise<ActionResult> {
  await editors();
  const supabase = await createClient();
  const { error } = await supabase.from("careers").update(flag === "active" ? { active: value } : { checked: value }).eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/careers");
  return { ok: true, message: flag === "checked" ? (value ? "Marked as checked." : "Marked as not checked.") : value ? "Shown in the app." : "Hidden from the app." };
}

/** Students who picked it keep their account; their career is simply cleared (on delete set null). */
export async function deleteCareer(id: number): Promise<ActionResult> {
  await editors();
  const supabase = await createClient();
  const { error } = await supabase.from("careers").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/careers");
  return { ok: true, message: "Deleted." };
}
