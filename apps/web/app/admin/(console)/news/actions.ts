"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { requireStaff, canEditContent } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const News = z.object({
  id: z.string().uuid().optional(),
  title: z.string().trim().min(3, "Title is too short").max(160),
  summary: z.string().trim().max(400),
  body: z.string().trim().max(20000),
  category: z.enum(["update", "exam", "app", "tips"]),
  link_type: z.enum(["none", "screen", "url", "doc"]),
  link_target: z.string().trim().max(500),
  image_path: z.string().trim().max(300),
  is_pinned: z.enum(["on"]).optional(),
  notify: z.enum(["on"]).optional(),
  status: z.enum(["draft", "published"]),
  publish_at: z.string().min(1),
}).refine((n) => n.link_type !== "url" || /^https:\/\//.test(n.link_target), { message: "A link must start with https://", path: ["link_target"] });

export type NewsState = { error?: string };

export async function saveNews(_p: NewsState, form: FormData): Promise<NewsState> {
  const staff = await requireStaff();
  if (!canEditContent(staff.role)) return { error: "Only editors and admins can post news." };
  const p = News.safeParse(Object.fromEntries(form));
  if (!p.success) return { error: p.error.issues[0]?.message ?? "Check the form" };
  const { id, is_pinned, notify, publish_at, ...n } = p.data;
  const row = {
    ...n, summary: n.summary || null, body: n.body || null, link_target: n.link_type === "none" ? null : n.link_target || null,
    image_path: n.image_path || null, is_pinned: is_pinned === "on", notify: notify === "on",
    // The form time is Lagos time (WAT, UTC+1 all year).
    publish_at: new Date(/[zZ]|[+-]\d\d:\d\d$/.test(publish_at) ? publish_at : `${publish_at}:00+01:00`).toISOString(),
  };
  const supabase = await createClient();
  const { error } = id ? await supabase.from("news_posts").update(row).eq("id", id) : await supabase.from("news_posts").insert(row);
  if (error) return { error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  redirect("/admin/news?saved=1");
}

export async function deleteNews(id: string): Promise<ActionResult> {
  const staff = await requireStaff();
  if (!canEditContent(staff.role)) return { ok: false, error: "Not allowed." };
  const supabase = await createClient();
  const { error } = await supabase.from("news_posts").delete().eq("id", id);
  if (error) return { ok: false, error: friendlyError(error) };
  revalidatePath("/admin", "layout");
  return { ok: true };
}
