"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const editors = () => requireStaff(["super_admin", "admin", "editor"]);
const opt = (max: number) => z.string().trim().max(max).optional().transform((v) => (v ? v : null));
const link = z.string().trim().max(500).optional().transform((v) => (v ? v : null)).refine((v) => v === null || /^https:\/\//.test(v), "Links must start with https://");

const Class = z.object({
  id: z.string().uuid().optional(),
  title: z.string().trim().min(3, "Give the class a title").max(120),
  about: opt(2000),
  subject_id: z.coerce.number().int().positive().optional().or(z.literal("").transform(() => undefined)),
  exam: z.string().trim().toUpperCase().regex(/^[A-Z][A-Z0-9]{1,11}$/).optional().or(z.literal("").transform(() => undefined)),
  teacher: z.string().trim().min(2, "Write the teacher's name").max(80),
  starts_at: z.string().min(10, "Choose the date and time"),
  minutes: z.coerce.number().int().min(10).max(480),
  access: z.enum(["free", "premium", "paid"]),
  price_naira: z.coerce.number().min(0).max(1_000_000).optional(),
  seats: z.coerce.number().int().min(0).max(100000).optional(),
  status: z.enum(["draft", "published", "cancelled"]),
  web_only: z.boolean(),
  join_url: link,
  recording_url: link,
}).refine((c) => c.access !== "paid" || (c.price_naira ?? 0) >= 50, { message: "A paid class needs a price of at least ₦50", path: ["price_naira"] });

/** Adds or saves a class (D-147). The links go to the staff-only table; students only get them from class_join(). */
export async function saveClass(input: unknown): Promise<ActionResult<{ id: string }>> {
  await editors();
  const p = Class.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const { id, join_url, recording_url, price_naira, seats, starts_at, subject_id, exam, ...rest } = p.data;
  // The form time is Lagos time (WAT, UTC+1 all year).
  const start = new Date(/[zZ]|[+-]\d\d:\d\d$/.test(starts_at) ? starts_at : `${starts_at}:00+01:00`);
  if (Number.isNaN(start.getTime())) return { ok: false, error: "Choose the date and time" };
  const row = {
    ...rest, starts_at: start.toISOString(), subject_id: subject_id ?? null, exam: exam ?? null, seats: seats ? seats : null,
    price_kobo: rest.access === "paid" ? Math.round((price_naira ?? 0) * 100) : null,
  };
  const supabase = await createClient();
  const r = id ? await supabase.from("classes").update(row).eq("id", id).select("id").single() : await supabase.from("classes").insert(row).select("id").single();
  if (r.error) return { ok: false, error: friendlyError(r.error) };
  const l = await supabase.from("class_links").upsert({ class_id: r.data.id, join_url, recording_url, updated_at: new Date().toISOString() });
  if (l.error) return { ok: false, error: friendlyError(l.error) };
  revalidatePath("/admin/classes");
  return { ok: true, data: { id: r.data.id }, message: rest.status === "published" ? "Saved. Students see it in the app." : "Saved." };
}

export async function deleteClass(id: string): Promise<ActionResult> {
  await editors();
  const supabase = await createClient();
  const { count } = await supabase.from("class_registrations").select("class_id", { count: "exact", head: true }).eq("class_id", id).not("payment_id", "is", null);
  if (count) return { ok: false, error: "Students paid for this class. Cancel it instead and refund them in Payments." };
  const { error } = await supabase.from("classes").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/classes");
  return { ok: true, message: "Deleted." };
}

export async function classStudents(id: string): Promise<ActionResult<{ name: string; email: string | null; registered_at: string; joined_at: string | null; paid: boolean }[]>> {
  await editors();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_class_students", { p_class: id });
  if (error) return { ok: false, error: friendlyError(error) };
  return { ok: true, data: (data ?? []) as never };
}
