import { createHash, randomInt } from "node:crypto";
import { createServiceClient } from "@/lib/supabase/server";
import { hasServiceKey } from "@/lib/env";
import { json } from "@/lib/auth-email";
import { sendEmail } from "@/lib/email";
import { deleteAppCodeEmail } from "@/lib/email-templates";
import { maskEmail } from "@/lib/guardian";
import { cleanNote, cleanReason } from "../reasons";

/**
 * POST /api/account/delete/start  { reason, note? }   Authorization: Bearer <access token>
 * Step 1 of deleting an account in the app (D-126): keeps the reason and emails a 6-digit code (10 minutes,
 * one a minute, five an hour). Only the code's hash is stored.
 */
export async function POST(req: Request) {
  if (!hasServiceKey()) return json({ error: "Not available right now." }, 503);
  const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  if (!token) return json({ error: "Please log in again." }, 401);
  const body = (await req.json().catch(() => ({}))) as { reason?: unknown; note?: unknown };
  const svc = await createServiceClient();
  const { data: who, error } = await svc.auth.getUser(token);
  if (error || !who.user?.email) return json({ error: "Please log in again." }, 401);
  const { data: staff } = await svc.from("staff").select("role").eq("user_id", who.user.id).maybeSingle();
  if (staff) return json({ error: "Staff accounts are removed by a super admin." }, 409);

  const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
  const hash = createHash("sha256").update(`${who.user.id}:${code}`).digest("hex");
  const { data: ok } = await svc.rpc("delete_code_start", { p_user: who.user.id, p_hash: hash, p_reason: cleanReason(body.reason), p_note: cleanNote(body.note) });
  if (ok === "wait") return json({ error: "We just sent you a code. Wait a minute before asking for another one." }, 429);
  if (ok === "too_many") return json({ error: "Too many codes. Try again in an hour, or contact support." }, 429);
  if (ok !== "ok") return json({ error: "Could not send the code. Try again." }, 500);

  const sent = await sendEmail({ to: who.user.email, ...deleteAppCodeEmail(code), from: "noreply", tags: ["delete-code"] });
  if (!sent.ok) return json({ error: "We could not send the email. Try again in a few minutes." }, 502);
  return json({ ok: true, codeLength: 6, email: maskEmail(who.user.email) });
}
