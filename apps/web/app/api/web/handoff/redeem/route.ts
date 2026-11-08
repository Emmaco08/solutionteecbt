import { z } from "zod";
import { createServiceClient } from "@/lib/supabase/server";
import { hasServiceKey } from "@/lib/env";
import { json } from "@/lib/auth-email";
import { HANDOFF_RULE, hashHandoff } from "@/lib/handoff";

const Body = z.object({ code: z.string().regex(HANDOFF_RULE) });

/**
 * POST /api/web/handoff/redeem  { code }     (payment website, D-115)
 * Swaps a one-time app code for a sign-in of the same account: the code is marked used in the same statement that
 * checks it (so it can never work twice), then a magic-link token hash is returned for the browser's verifyOtp.
 * No email is sent and no account is created. Same answer for every failure.
 */
export async function POST(req: Request) {
  if (!hasServiceKey()) return json({ error: "Not available right now." }, 503);
  const parsed = Body.safeParse(await req.json().catch(() => null));
  const fail = json({ error: "This link has expired. Log in with your email instead." }, 400);
  if (!parsed.success) return fail;
  const svc = await createServiceClient();
  const now = new Date().toISOString();
  const { data: row } = await svc.from("web_handoffs").update({ used_at: now })
    .eq("code_hash", hashHandoff(parsed.data.code)).is("used_at", null).gt("expires_at", now)
    .select("user_id, plan").maybeSingle();
  if (!row) return fail;
  const { data: u } = await svc.auth.admin.getUserById(row.user_id);
  const user = u?.user;
  if (!user?.email || !user.email_confirmed_at) return fail;
  if (user.banned_until && new Date(user.banned_until) > new Date()) return fail;
  const { data, error } = await svc.auth.admin.generateLink({ type: "magiclink", email: user.email });
  if (error || !data.properties?.hashed_token) return fail;
  return json({ token_hash: data.properties.hashed_token, plan: row.plan, email: user.email });
}
