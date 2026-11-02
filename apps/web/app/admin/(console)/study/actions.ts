"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { requireStaff, canEditStudy } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";
import type { Json } from "@solutiontee/shared/database";
import { KINDS, type StudyState } from "./kinds";

// Fields that a kind does not show are simply missing from the form, so every helper accepts "absent".
const num = z.string().trim().optional().transform((v) => (v ? Number(v) : null)).pipe(z.number().int().nullable());
const opt = z.string().trim().optional().transform((v) => v || null);

const Item = z.object({
  id: z.string().uuid().optional(),
  kind: z.enum(KINDS),
  title: z.string().trim().min(2, "Title is too short").max(160),
  subtitle: opt.pipe(z.string().max(200).nullable()),
  exam_id: num, subject_id: num, topic_id: num, year: num, sort: num,
  question_id: opt.pipe(z.string().uuid("The question id is not valid").nullable()),
  body: opt.pipe(z.string().max(60000).nullable()),
  is_free: z.enum(["on"]).optional(),
  status: z.enum(["draft", "review", "published"]),
  // files (keys come from our own upload endpoint)
  f360: opt, f360_size: num, f360_duration: num, f360_duration_old: num, f720: opt, f720_size: num,
  pdf: opt, pdf_size: num, pdf_pages: num, pages: num, cover: opt,
  // structured text
  author: opt, topics: opt, themes: opt, characters: opt, chapters: opt,
});


/** "Title | text" lines → [{title, text}] */
const pairs = (s: string | null, a: string, b: string) =>
  (s ?? "").split(/\r?\n/).map((l) => l.split("|").map((x) => x.trim())).filter((p) => p[0])
    .map(([x, ...rest]) => ({ [a]: x, [b]: rest.join(" | ") }));

export async function saveStudy(_p: StudyState, form: FormData): Promise<StudyState> {
  const staff = await requireStaff();
  if (!canEditStudy(staff.role)) return { error: "Only editors, teachers and admins can change study content." };
  const p = Item.safeParse(Object.fromEntries(form));
  if (!p.success) return { error: p.error.issues[0]?.message ?? "Check the form" };
  const v = p.data;
  const key = (k: string | null, prefix: string) => (k && new RegExp(`^${prefix}/[a-z0-9/_.-]+$`, "i").test(k) ? k : null);

  const files: Record<string, unknown> = {};
  const sizes: Record<string, number> = {};
  const data: Record<string, unknown> = {};
  if (v.kind === "video_solution" || v.kind === "lesson") {
    if (key(v.f360, "v")) { files["360"] = v.f360; if (v.f360_size) sizes["360"] = v.f360_size; }
    if (key(v.f720, "v")) { files["720"] = v.f720; if (v.f720_size) sizes["720"] = v.f720_size; }
    const duration = v.f360_duration ?? v.f360_duration_old;
    if (duration && files["360"]) data.duration_s = duration;
    if (v.status === "published" && !files["360"]) return { error: "Upload the 360p video before publishing (it is the one data saver uses)." };
  }
  if (v.kind === "doc") {
    if (key(v.pdf, "d")) { files.pdf = v.pdf; if (v.pdf_size) sizes.pdf = v.pdf_size; }
    data.pages = v.pages ?? v.pdf_pages ?? null;
    data.topics = pairs(v.topics, "title", "page").map((t) => ({ title: t.title, page: Number(t.page) || null }));
    if (v.status === "published" && !files.pdf) return { error: "Upload the PDF before publishing." };
  }
  if (v.kind === "novel") {
    // The original book as a PDF (optional): students read it in the app's PDF reader.
    if (key(v.pdf, "d")) { files.pdf = v.pdf; if (v.pdf_size) sizes.pdf = v.pdf_size; }
    if (v.pdf_pages ?? v.pages) data.pages = v.pages ?? v.pdf_pages;
    data.author = v.author;
    data.themes = pairs(v.themes, "title", "text");
    data.characters = pairs(v.characters, "name", "text");
    try {
      data.chapters = v.chapters ? JSON.parse(v.chapters) : [];
    } catch {
      return { error: "The chapters could not be read. Try again." };
    }
  }
  if (key(v.cover, "s")) files.cover = v.cover;
  if (Object.keys(sizes).length) files.sizes = sizes;

  const row = {
    kind: v.kind, title: v.title, subtitle: v.subtitle, exam_id: v.exam_id, subject_id: v.subject_id, topic_id: v.topic_id,
    year: v.year, question_id: v.kind === "video_solution" ? v.question_id : null, body: v.body,
    data: data as Json, files: files as Json, is_free: v.is_free === "on", status: v.status, sort: v.sort ?? 0, updated_by: staff.id,
  };
  const supabase = await createClient();
  const { error } = v.id ? await supabase.from("study_items").update(row).eq("id", v.id) : await supabase.from("study_items").insert(row);
  if (error) return { error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  redirect(`/admin/study?kind=${v.kind}&saved=1`);
}

/** Soft delete (kept for the audit log; students stop seeing it at once). */
export async function deleteStudy(id: string): Promise<ActionResult> {
  const staff = await requireStaff();
  if (!canEditStudy(staff.role)) return { ok: false, error: "Not allowed." };
  const supabase = await createClient();
  const { error } = await supabase.from("study_items").update({ deleted_at: new Date().toISOString(), status: "draft" }).eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true };
}
