"use server";
import { revalidatePath, updateTag } from "next/cache";
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
  updateTag("classes");
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
  updateTag("classes");
  return { ok: true, message: "Deleted." };
}

export async function classStudents(id: string): Promise<ActionResult<{ name: string; email: string | null; registered_at: string; joined_at: string | null; paid: boolean }[]>> {
  await editors();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_class_students", { p_class: id });
  if (error) return { ok: false, error: friendlyError(error) };
  return { ok: true, data: (data ?? []) as never };
}

const Page = z.object({
  on: z.boolean(),
  title: z.string().trim().min(3).max(120),
  intro: z.string().trim().max(800),
  price_note: z.string().trim().max(400),
  teachers: z.array(z.object({ name: z.string().trim().min(2).max(80), subject: z.string().trim().max(80).optional(), bio: z.string().trim().max(300).optional() })).max(12),
  faq: z.array(z.object({ q: z.string().trim().min(3).max(200), a: z.string().trim().min(3).max(800) })).max(12),
});

/** The text of cbt.solutiontee.com/classes (D-148). */
export async function saveClassesPage(input: unknown): Promise<ActionResult> {
  await editors();
  const p = Page.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the page text" };
  const supabase = await createClient();
  const { error } = await supabase.from("app_settings").upsert({ key: "jamb_classes", value: p.data, is_public: true }, { onConflict: "key" });
  if (error) return { ok: false, error: friendlyError(error) };
  updateTag("classes");
  revalidatePath("/admin/classes");
  return { ok: true, message: "Saved. The website page updates within a minute." };
}

export async function addMaterial(classId: string, title: string, url: string): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin", "editor", "teacher"]);
  const p = z.object({ classId: z.string().uuid(), title: z.string().trim().min(2).max(120), url: z.string().trim().regex(/^https:\/\//, "Links must start with https://").max(500) }).safeParse({ classId, title, url });
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the material" };
  const supabase = await createClient();
  const { error } = await supabase.from("class_materials").insert({ class_id: p.data.classId, title: p.data.title, url: p.data.url });
  if (error) return { ok: false, error: friendlyError(error) };
  return { ok: true, message: "Added. Students of this class see it in My classes." };
}

export async function removeMaterial(id: string): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin", "editor", "teacher"]);
  const supabase = await createClient();
  const { error } = await supabase.from("class_materials").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  return { ok: true, message: "Removed." };
}

export async function addAssignment(input: unknown): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin", "editor", "teacher"]);
  const p = z.object({
    class_id: z.string().uuid(), title: z.string().trim().min(2, "Give it a title").max(120), instructions: z.string().trim().max(4000).optional(),
    due_at: z.string().optional(), max_score: z.coerce.number().int().min(1).max(100),
  }).safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the assignment" };
  const due = p.data.due_at ? new Date(`${p.data.due_at}:00+01:00`) : null;
  const supabase = await createClient();
  const { error } = await supabase.from("class_assignments").insert({
    class_id: p.data.class_id, title: p.data.title, instructions: p.data.instructions || null, max_score: p.data.max_score,
    due_at: due && !Number.isNaN(due.getTime()) ? due.toISOString() : null,
  });
  if (error) return { ok: false, error: friendlyError(error) };
  return { ok: true, message: "Assignment added." };
}

export async function removeAssignment(id: string): Promise<ActionResult> {
  await requireStaff(["super_admin", "admin", "editor", "teacher"]);
  const supabase = await createClient();
  const { error } = await supabase.from("class_assignments").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  return { ok: true, message: "Removed." };
}

export async function classWork(classId: string): Promise<ActionResult<{
  materials: { id: string; title: string; url: string }[];
  assignments: { id: string; title: string; due_at: string | null; max_score: number }[];
  submissions: { assignment_id: string; assignment: string; max_score: number; user_id: string; name: string; answer: string; submitted_at: string; score: number | null; feedback: string | null }[];
}>> {
  await requireStaff(["super_admin", "admin", "editor", "teacher"]);
  const supabase = await createClient();
  const [m, a, s] = await Promise.all([
    supabase.from("class_materials").select("id, title, url").eq("class_id", classId).order("created_at"),
    supabase.from("class_assignments").select("id, title, due_at, max_score").eq("class_id", classId).order("created_at"),
    supabase.rpc("admin_class_submissions", { p_class: classId }),
  ]);
  if (m.error || a.error || s.error) return { ok: false, error: friendlyError((m.error ?? a.error ?? s.error)!) };
  return { ok: true, data: { materials: m.data ?? [], assignments: a.data ?? [], submissions: (s.data ?? []) as never } };
}

export async function markSubmission(assignmentId: string, userId: string, score: number, feedback: string): Promise<ActionResult> {
  const staff = await requireStaff(["super_admin", "admin", "editor", "teacher"]);
  const p = z.object({ a: z.string().uuid(), u: z.string().uuid(), score: z.number().int().min(0).max(100), feedback: z.string().trim().max(2000) }).safeParse({ a: assignmentId, u: userId, score, feedback });
  if (!p.success) return { ok: false, error: "Check the mark" };
  const supabase = await createClient();
  const { error } = await supabase.from("class_submissions").update({ score: p.data.score, feedback: p.data.feedback || null, marked_at: new Date().toISOString(), marked_by: staff.id })
    .eq("assignment_id", p.data.a).eq("user_id", p.data.u);
  if (error) return { ok: false, error: friendlyError(error) };
  return { ok: true, message: "Marked. The student sees it in My classes." };
}

// ---------------------------------------------------------------- programmes (classes v2, D-163)

const slugify = (s: string) => s.toLowerCase().normalize("NFKD").replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 70);
const dateOpt = z.string().trim().optional().transform((v) => (v ? v : null)).refine((v) => v === null || /^\d{4}-\d{2}-\d{2}$/.test(v), "Pick a date");
const imageKey = z.string().trim().optional().transform((v) => (v ? v : null)).refine((v) => v === null || /^public\/classes\/[A-Za-z0-9/_.-]+$/.test(v), "Upload the picture again");

const Program = z.object({
  id: z.string().uuid().optional(),
  title: z.string().trim().min(3, "Give the class a name").max(120),
  slug: z.string().trim().max(80).optional(),
  tagline: opt(200),
  about: opt(6000),
  highlights: z.string().max(3000).optional().transform((v) => (v ?? "").split("\n").map((l) => l.replace(/^[-•*]\s*/, "").trim()).filter(Boolean).slice(0, 12)),
  exam: opt(12),
  subjects: opt(200),
  teacher: opt(80),
  teacher_bio: opt(1200),
  teacher_photo: imageKey,
  flyer_path: imageKey,
  schedule_note: opt(200),
  access: z.enum(["free", "premium", "paid"]),
  price_naira: z.coerce.number().min(0).max(1_000_000).optional(),
  compare_naira: z.coerce.number().min(0).max(1_000_000).optional(),
  seats: z.coerce.number().int().min(0).max(100000).optional(),
  starts_on: dateOpt,
  ends_on: dateOpt,
  faq: z.array(z.object({ q: z.string().trim().min(3).max(200), a: z.string().trim().min(3).max(800) })).max(15),
  status: z.enum(["draft", "published", "closed"]),
  on_website: z.boolean(),
  sort: z.coerce.number().int().min(0).max(999).optional(),
}).refine((p) => p.access !== "paid" || (p.price_naira ?? 0) >= 50, { message: "A paid class needs a price of at least ₦50", path: ["price_naira"] })
  .refine((p) => !p.starts_on || !p.ends_on || p.ends_on >= p.starts_on, { message: "The end date is before the start date", path: ["ends_on"] });

/** Adds or saves a class programme: what students buy once and then attend every session of. */
export async function saveProgram(input: unknown): Promise<ActionResult<{ id: string }>> {
  await editors();
  const p = Program.safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the form" };
  const { id, price_naira, compare_naira, seats, slug, sort, ...rest } = p.data;
  const row = {
    ...rest,
    // "me" and "img" are pages of their own on the website.
    slug: ((x) => (["me", "img"].includes(x) ? `${x}-class` : x))(slugify(slug || rest.title) || `class-${Date.now()}`),
    price_kobo: rest.access === "paid" ? Math.round((price_naira ?? 0) * 100) : null,
    compare_kobo: rest.access === "paid" && compare_naira && compare_naira > (price_naira ?? 0) ? Math.round(compare_naira * 100) : null,
    seats: seats ? seats : null,
    sort: sort ?? 0,
  };
  const supabase = await createClient();
  const r = id
    ? await supabase.from("class_programs").update(row).eq("id", id).select("id").single()
    : await supabase.from("class_programs").insert(row).select("id").single();
  if (r.error) return { ok: false, error: r.error.code === "23505" ? "Another class already uses this web address. Change the short link." : friendlyError(r.error) };
  // Sessions follow the programme's access (the price lives on the programme).
  await supabase.from("classes").update({ access: row.access, price_kobo: null }).eq("program_id", r.data.id);
  revalidatePath("/admin/classes");
  updateTag("classes");
  return { ok: true, data: { id: r.data.id }, message: row.status === "published" ? "Saved. Students see it in the app" + (row.access === "paid" && row.on_website ? " and on the website." : ".") : "Saved." };
}

export async function deleteProgram(id: string): Promise<ActionResult> {
  await editors();
  const supabase = await createClient();
  const { count } = await supabase.from("class_enrollments").select("user_id", { count: "exact", head: true }).eq("program_id", id).not("payment_id", "is", null);
  if (count) return { ok: false, error: "Students paid for this class. Close it instead (it stays for those who paid)." };
  const { error } = await supabase.from("class_programs").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin/classes");
  updateTag("classes");
  return { ok: true, message: "Deleted." };
}

/** Students enrolled in a programme (name, email, paid). */
export async function programStudents(id: string): Promise<ActionResult<{ name: string; email: string | null; enrolled_at: string; paid: boolean }[]>> {
  await editors();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_program_students", { p_program: id });
  if (error) return { ok: false, error: friendlyError(error) };
  return { ok: true, data: (data ?? []) as never };
}

/** Adds or saves one session of a programme (time, length, links). */
export async function saveSession(input: unknown): Promise<ActionResult<{ id: string }>> {
  await editors();
  const p = z.object({
    id: z.string().uuid().optional(),
    program_id: z.string().uuid(),
    title: z.string().trim().min(3, "Give the session a title").max(120),
    about: opt(2000),
    teacher: z.string().trim().min(2, "Write the teacher's name").max(80),
    starts_at: z.string().min(10, "Choose the date and time"),
    minutes: z.coerce.number().int().min(10, "At least 10 minutes").max(480),
    status: z.enum(["draft", "published", "cancelled"]),
    join_url: link,
    recording_url: link,
  }).safeParse(input);
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the session" };
  const { id, join_url, recording_url, starts_at, program_id, ...rest } = p.data;
  const start = new Date(/[zZ]|[+-]\d\d:\d\d$/.test(starts_at) ? starts_at : `${starts_at}:00+01:00`);
  if (Number.isNaN(start.getTime())) return { ok: false, error: "Choose the date and time" };
  const supabase = await createClient();
  const prog = await supabase.from("class_programs").select("access, exam").eq("id", program_id).single();
  if (prog.error) return { ok: false, error: friendlyError(prog.error) };
  const exam = prog.data.exam && /^[A-Z][A-Z0-9]{1,11}$/.test(prog.data.exam) ? prog.data.exam : null;
  const row = { ...rest, program_id, starts_at: start.toISOString(), access: prog.data.access, price_kobo: null, exam, web_only: false };
  const r = id ? await supabase.from("classes").update(row).eq("id", id).select("id").single() : await supabase.from("classes").insert(row).select("id").single();
  if (r.error) return { ok: false, error: friendlyError(r.error) };
  const l = await supabase.from("class_links").upsert({ class_id: r.data.id, join_url, recording_url, updated_at: new Date().toISOString() });
  if (l.error) return { ok: false, error: friendlyError(l.error) };
  revalidatePath("/admin/classes");
  updateTag("classes");
  return { ok: true, data: { id: r.data.id }, message: rest.status === "published" ? "Session saved. Enrolled students will be reminded before it starts." : "Session saved." };
}
