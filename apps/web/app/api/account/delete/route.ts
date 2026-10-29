import { z } from "zod";
import { createServiceClient } from "@/lib/supabase/server";
import { hasServiceKey } from "@/lib/env";
import { json } from "@/lib/auth-email";

const Body = z.object({ confirm: z.literal("DELETE") });

/**
 * POST /api/account/delete  { confirm: "DELETE" }   Authorization: Bearer <access token>
 * Deletes the signed-in student's account and everything linked to it (profile, attempts, answers,
 * Premium history cascade). Staff accounts must be removed from staff first. Required by Google Play.
 */
export async function POST(req: Request) {
  if (!hasServiceKey()) return json({ error: "Not available right now." }, 503);
  const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const parsed = Body.safeParse(await req.json().catch(() => null));
  if (!token || !parsed.success) return json({ error: "Type DELETE to confirm." }, 400);

  const svc = await createServiceClient();
  const { data: who, error } = await svc.auth.getUser(token);
  if (error || !who.user) return json({ error: "Please log in again." }, 401);
  const { data: staff } = await svc.from("staff").select("role").eq("user_id", who.user.id).maybeSingle();
  if (staff) return json({ error: "Staff accounts are removed by a super admin." }, 409);

  // Keep a minimal, non-personal record that a deletion happened (for support and audits).
  await svc.from("audit_log").insert({ action: "delete_account", table_name: "auth.users", row_id: who.user.id, after: { at: new Date().toISOString() } });
  const del = await svc.auth.admin.deleteUser(who.user.id);
  if (del.error) return json({ error: "We could not delete your account. Contact support." }, 500);
  return json({ ok: true, message: "Your account and data have been deleted." });
}
