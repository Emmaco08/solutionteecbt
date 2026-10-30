import { z } from "zod";
import { createClient } from "@supabase/supabase-js";
import { env, hasR2 } from "@/lib/env";
import { presignGet } from "@/lib/r2";
import { json } from "@/lib/auth-email";

const Body = z.object({
  id: z.string().uuid(),
  file: z.enum(["360", "720", "pdf", "cover"]),
});

/**
 * POST /api/study/file  { id: "<study item id>", file: "360" | "720" | "pdf" | "cover" }   Authorization: Bearer <access token>
 * Returns a short-lived read link for one file of a study item (video, PDF). public.study_file_key runs as the
 * student, so the Free/Premium rules decide; the R2 key itself never reaches the app (D-045, D-053).
 */
export async function POST(req: Request) {
  if (!hasR2()) return json({ error: "Files are not available right now." }, 503);
  const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const parsed = Body.safeParse(await req.json().catch(() => null));
  if (!token) return json({ error: "Please log in again." }, 401);
  if (!parsed.success) return json({ error: "Unknown file." }, 400);

  const asUser = createClient(env.supabaseUrl, env.supabasePublishableKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: key, error } = await asUser.rpc("study_file_key", { p_id: parsed.data.id, p_file: parsed.data.file });
  if (error) {
    if (/locked/.test(error.message)) return json({ error: "This is part of Premium.", code: "locked" }, 403);
    if (/not_found/.test(error.message)) return json({ error: "This is no longer available." }, 404);
    return json({ error: "Please log in again." }, 401);
  }
  if (!key) return json({ error: "This file has not been added yet." }, 404);

  // Videos are read in ranges while they play: give them 3 hours so a long lesson never stops half-way.
  const ttl = parsed.data.file === "360" || parsed.data.file === "720" ? 3 * 60 * 60 : env.r2.signedUrlTtl;
  return json({ url: await presignGet(key as string, ttl), expiresIn: ttl });
}
