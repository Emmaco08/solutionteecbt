import { createClient } from "@supabase/supabase-js";
import { z } from "zod";
import { env, hasR2 } from "@/lib/env";
import { presignPut } from "@/lib/r2";
import { json } from "@/lib/auth-email";

const Body = z.object({ contentType: z.enum(["image/jpeg", "image/webp"]), size: z.number().int().min(100).max(1024 * 1024) });

/**
 * POST /api/account/avatar  { contentType, size }   Authorization: Bearer <access token>   (milestone 4D, D-063)
 * Returns a 10-minute upload link for the student's profile photo at a/<user id>/<random>.<ext> in the private
 * R2 bucket. The app shrinks the photo first (512 px), uploads it, then saves the key in profiles.avatar_path.
 * Photos are shown through /api/images/sign, which only signs a student's own a/<id>/ keys.
 */
export async function POST(req: Request) {
  if (!hasR2()) return json({ error: "Photos are not available right now." }, 503);
  const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!token) return json({ error: "Please log in again." }, 401);
  const parsed = Body.safeParse(await req.json().catch(() => null));
  if (!parsed.success) return json({ error: "Use a JPEG photo under 1 MB." }, 400);
  const sb = createClient(env.supabaseUrl, env.supabasePublishableKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: who, error } = await sb.auth.getUser(token);
  if (error || !who.user) return json({ error: "Please log in again." }, 401);
  const ext = parsed.data.contentType === "image/webp" ? "webp" : "jpg";
  const key = `a/${who.user.id}/${crypto.randomUUID().slice(0, 8)}.${ext}`;
  return json({ key, url: await presignPut(key, parsed.data.contentType) });
}
