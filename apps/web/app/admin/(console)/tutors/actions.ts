"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const admins = () => requireStaff(["super_admin", "admin"]);
const opt = (max: number) => z.string().trim().max(max).optional().transform((v) => (v ? v : null));
const phone = z.string().trim().optional().transform((v) => (v ? v.replace(/[\s-]/g, "") : null))
  .refine((v) => v === null || /^\+?[0-9]{10,15}$/.test(v), "Write the number with digits only, like +2348012345678");

/** Sends a reply in the student's tutor chat; the server also emails and notifies them (D-149). */
export async function replyTutor(requestId: string, body: string): Promise<ActionResult> {
  await admins();
  const text = body.trim();
  if (!text) return { ok: false, error: "Write a reply first" };
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("tutor_message_send", { p_request: requestId, p_body: text.slice(0, 2000) });
  if (error) return { ok: false, error: friendlyError(error) };
  const r = data as { ok: boolean; error?: string };
  if (!r.ok) return { ok: false, error: r.error === "length" ? "Replies can be up to 2,000 characters" : "This request was not found" };
  revalidatePath("/admin/tutors");
  return { ok: true, message: "Sent. The student gets a notification and an email." };
}

/** Status and assigned tutor. The tutor's WhatsApp / phone only show to the student while a plan is active. */
export async function updateRequest(id: string, patch: { status?: string; tutor_id?: string | null }): Promise<ActionResult> {
  await admins();
  const status = patch.status && ["new", "replied", "matched", "closed"].includes(patch.status) ? patch.status : undefined;
  const row: { status?: string; tutor_id?: string | null; updated_at: string } = { updated_at: new Date().toISOString() };
  if (status) row.status = status;
  if (patch.tutor_id !== undefined) { row.tutor_id = patch.tutor_id || null; if (patch.tutor_id && !status) row.status = "matched"; }
  const supabase = await createClient();
  const { error } = await supabase.from("tutor_requests").update(row).eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/tutors");
  return { ok: true, message: "Saved." };
}

const Tutor = z.object({
  id: z.string().uuid().optional(),
  name: z.string().trim().min(2, "Write the tutor's name").max(80),
  subjects: opt(200), bio: opt(600), whatsapp: phone, phone: phone, active: z.boolean(),
});
export async function saveTutor(input: unknown): Promise<ActionResult> {
  await admins();
  const p = Tutor.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const { id, ...row } = p.data;
  const supabase = await createClient();
  const { error } = id ? await supabase.from("tutors").update(row).eq("id", id) : await supabase.from("tutors").insert(row);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/tutors");
  return { ok: true, message: "Tutor saved." };
}

const Plan = z.object({
  id: z.string().uuid().optional(),
  name: z.string().trim().min(2, "Give the plan a name").max(80),
  description: opt(400),
  price_naira: z.coerce.number().min(50, "The price must be at least ₦50").max(1_000_000),
  days: z.coerce.number().int().min(1).max(366),
  sessions: z.coerce.number().int().min(0).max(200).optional(),
  active: z.boolean(),
  sort: z.coerce.number().int().min(0).max(999).optional(),
});
export async function savePlan(input: unknown): Promise<ActionResult> {
  await admins();
  const p = Plan.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const { id, price_naira, sessions, sort, ...rest } = p.data;
  const row = { ...rest, price_kobo: Math.round(price_naira * 100), sessions: sessions ? sessions : null, sort: sort ?? 0 };
  const supabase = await createClient();
  const { error } = id ? await supabase.from("tutor_plans").update(row).eq("id", id) : await supabase.from("tutor_plans").insert(row);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/tutors");
  return { ok: true, message: rest.active ? "Plan saved. Students see it in the app." : "Plan saved (hidden)." };
}

export async function deletePlan(id: string): Promise<ActionResult> {
  await admins();
  const supabase = await createClient();
  const { count } = await supabase.from("tutor_subscriptions").select("id", { count: "exact", head: true }).eq("plan_id", id);
  if (count) return { ok: false, error: "Students bought this plan. Hide it instead (untick Shown)." };
  const { error } = await supabase.from("tutor_plans").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/tutors");
  return { ok: true, message: "Plan deleted." };
}
