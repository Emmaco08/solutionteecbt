import { z } from "zod";
import { createServiceClient } from "@/lib/supabase/server";
import { hasServiceKey } from "@/lib/env";
import { json } from "@/lib/auth-email";
import { hashHandoff, newHandoffCode } from "@/lib/handoff";

const Body = z.object({ plan: z.string().regex(/^[a-z0-9_]{2,40}$/).optional() });

/**
 * POST /api/web/handoff  { plan? }   Authorization: Bearer <app access token>     (D-115)
 * The signed-in app asks for a one-time code to open the payment website already logged in. The code works once, for
 * 2 minutes, and only on /pay. At most 10 codes an hour per account.
 */
export async function POST(req: Request) {
  if (!hasServiceKey()) return json({ error: "Not available right now." }, 503);
  const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const parsed = Body.safeParse(await req.json().catch(() => ({})));
  if (!token || !parsed.success) return json({ error: "Bad request" }, 400);
  const svc = await createServiceClient();
  const { data: who, error } = await svc.auth.getUser(token);
  const user = who?.user;
  if (error || !user?.email_confirmed_at) return json({ error: "Please log in again." }, 401);

  const since = new Date(Date.now() - 3600_000).toISOString();
  const { count } = await svc.from("web_handoffs").select("code_hash", { count: "exact", head: true }).eq("user_id", user.id).gt("created_at", since);
  if ((count ?? 0) >= 10) return json({ error: "Too many tries. Please wait a little." }, 429);

  const code = newHandoffCode();
  const { error: e2 } = await svc.from("web_handoffs").insert({ code_hash: hashHandoff(code), user_id: user.id, plan: parsed.data.plan ?? null });
  if (e2) return json({ error: "Could not start. Try again." }, 500);
  return json({ code, expires_in: 120 });
}
