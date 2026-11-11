import { createClient } from "@supabase/supabase-js";
import { z } from "zod";
import { env, hasR2 } from "@/lib/env";
import { presignPut } from "@/lib/r2";
import { json } from "@/lib/auth-email";

const TYPES = {
  "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp",
  "audio/webm": "webm", "audio/ogg": "ogg", "audio/mp4": "m4a", "audio/aac": "aac", "audio/mpeg": "mp3",
  "application/pdf": "pdf",
} as const;
const Body = z.object({
  request: z.string().uuid(),
  contentType: z.enum(Object.keys(TYPES) as [keyof typeof TYPES, ...(keyof typeof TYPES)[]]),
  size: z.number().int().min(100).max(10 * 1024 * 1024),
});

/**
 * POST /api/tutor/upload  { request, contentType, size }   Authorization: Bearer <access token>   (D-152)
 * A 10-minute upload link for a photo, voice note or PDF in a tutor chat, saved at t/<request id>/<random>.<ext> in the
 * private bucket. Only the student, their tutor or an admin of that chat gets one (tutor_file_ok runs as the caller);
 * files are read back through /api/images/sign, which checks can_view_tutor_file the same way.
 */
export async function POST(req: Request) {
  if (!hasR2()) return json({ error: "Files are not available right now." }, 503);
  const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!token) return json({ error: "Please log in again." }, 401);
  const parsed = Body.safeParse(await req.json().catch(() => null));
  if (!parsed.success) return json({ error: "Send a photo, voice note or PDF under 10 MB." }, 400);
  const sb = createClient(env.supabaseUrl, env.supabasePublishableKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: ok, error } = await sb.rpc("tutor_file_ok", { p_request: parsed.data.request });
  if (error) return json({ error: "Please log in again." }, 401);
  if (!ok) return json({ error: "You cannot send files in this chat." }, 403);
  const key = `t/${parsed.data.request}/${crypto.randomUUID().replace(/-/g, "").slice(0, 16)}.${TYPES[parsed.data.contentType]}`;
  return json({ key, url: await presignPut(key, parsed.data.contentType) });
}
