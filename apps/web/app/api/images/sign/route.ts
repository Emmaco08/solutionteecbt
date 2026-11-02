import { z } from "zod";
import { createClient } from "@supabase/supabase-js";
import { env, hasR2 } from "@/lib/env";
import { presignGet } from "@/lib/r2";
import { json } from "@/lib/auth-email";

const Body = z.object({ key: z.string().min(3).max(300).regex(/^(q|public\/news)\/[A-Za-z0-9/_.-]+$/) });

/**
 * POST /api/images/sign  { key: "q/jamb/2001/mth/7.webp" | "public/news/…" }   Authorization: Bearer <access token>
 * Returns a short-lived read link for a question image, only when the student may see that question
 * (public.can_view_question_image runs as the student, so the plan and year rules apply). D-045.
 * News pictures are signed when a news post the student can read (RLS: published, due) uses that key.
 */
export async function POST(req: Request) {
  if (!hasR2()) return json({ error: "Images are not available right now." }, 503);
  const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const parsed = Body.safeParse(await req.json().catch(() => null));
  if (!token) return json({ error: "Please log in again." }, 401);
  if (!parsed.success) return json({ error: "Unknown image." }, 400);

  const asUser = createClient(env.supabaseUrl, env.supabasePublishableKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const key = parsed.data.key;
  const { data: ok, error } = key.startsWith("public/news/")
    ? await asUser.from("news_posts").select("id").eq("image_path", key).limit(1).then((r) => ({ data: Boolean(r.data?.length), error: r.error }))
    : await asUser.rpc("can_view_question_image", { p_key: key });
  if (error) return json({ error: "Please log in again." }, 401);
  if (!ok) return json({ error: "This image is locked." }, 403);

  return json({ url: await presignGet(key), expiresIn: env.r2.signedUrlTtl });
}
