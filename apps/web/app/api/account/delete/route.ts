import { createHash } from "node:crypto";
import { z } from "zod";
import { createServiceClient } from "@/lib/supabase/server";
import { hasServiceKey } from "@/lib/env";
import { json } from "@/lib/auth-email";
import { sendEmail } from "@/lib/email";
import { accountDeletedEmail } from "@/lib/email-templates";
import { cleanNote, cleanReason } from "./reasons";

const Body = z.object({
  confirm: z.literal("DELETE"),
  code: z.string().regex(/^\d{6}$/).optional(),
  reason: z.string().max(80).optional(),
  note: z.string().max(500).optional(),
  via: z.enum(["app", "web"]).optional(),
});

/** The access token's sign-in methods (already verified by getUser): used to accept a fresh website email code. */
function recentEmailCode(token: string, minutes = 15) {
  try {
    const payload = JSON.parse(Buffer.from(token.split(".")[1] ?? "", "base64url").toString("utf8")) as { amr?: { method?: string; timestamp?: number }[] };
    const since = Date.now() / 1000 - minutes * 60;
    return (payload.amr ?? []).some((a) => ["otp", "recovery", "magiclink"].includes(a.method ?? "") && (a.timestamp ?? 0) > since);
  } catch {
    return false;
  }
}

/**
 * POST /api/account/delete  { confirm: "DELETE", code?, reason?, note?, via? }   Authorization: Bearer <access token>
 * Deletes the signed-in student's account and everything linked to it (Google Play requirement), D-126:
 * - the app confirms with the 6-digit code from /api/account/delete/start (the reason was given there);
 * - the website confirms with the email code the student just signed in with (sign-in less than 15 minutes ago).
 * The reason is kept without any link to the person, then a goodbye email is sent. Staff accounts are refused.
 */
export async function POST(req: Request) {
  if (!hasServiceKey()) return json({ error: "Not available right now." }, 503);
  const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const parsed = Body.safeParse(await req.json().catch(() => null));
  if (!token || !parsed.success) return json({ error: "Type DELETE to confirm." }, 400);
  const b = parsed.data;

  const svc = await createServiceClient();
  const { data: who, error } = await svc.auth.getUser(token);
  if (error || !who.user) return json({ error: "Please log in again." }, 401);
  const uid = who.user.id;
  const { data: staff } = await svc.from("staff").select("role").eq("user_id", uid).maybeSingle();
  if (staff) return json({ error: "Staff accounts are removed by a super admin." }, 409);

  let reason = b.reason ? cleanReason(b.reason) : "", note = cleanNote(b.note);
  if (b.code) {
    const { data } = await svc.rpc("delete_code_check", { p_user: uid, p_hash: createHash("sha256").update(`${uid}:${b.code}`).digest("hex") });
    const r = (data ?? {}) as { result?: string; left?: number; reason?: string; note?: string };
    if (r.result === "wrong") return json({ error: `That code is not right. ${r.left ?? 0} ${r.left === 1 ? "try" : "tries"} left.` }, 400);
    if (r.result === "expired") return json({ error: "That code has expired. Ask for a new one." }, 400);
    if (r.result === "too_many") return json({ error: "Too many wrong codes. Ask for a new code." }, 429);
    if (r.result !== "ok") return json({ error: "Ask for a code first." }, 400);
    reason = reason || r.reason || "Other";
    note = note || r.note || "";
  } else if (!(b.via === "web" && recentEmailCode(token))) {
    // Older app versions did not send a code: they must update, or use the website.
    return json({ error: "Update the app to delete your account, or use cbt.solutiontee.com/delete-account." }, 400);
  }

  const email = who.user.email ?? "";
  const { data: profile } = await svc.from("profiles").select("full_name").eq("id", uid).maybeSingle();
  await svc.rpc("delete_reason_log", { p_user: uid, p_reason: reason || "Not given", p_note: note, p_via: b.via === "web" ? "web" : "app" });
  // A minimal, non-personal record that a deletion happened (for support and audits).
  await svc.from("audit_log").insert({ action: "delete_account", table_name: "auth.users", row_id: uid, after: { at: new Date().toISOString(), via: b.via ?? "app" } });
  const del = await svc.auth.admin.deleteUser(uid);
  if (del.error) return json({ error: "We could not delete your account. Contact support." }, 500);
  if (email) await sendEmail({ to: email, ...accountDeletedEmail(profile?.full_name ?? ""), from: "support", tags: ["account-deleted"] }).catch(() => null);
  return json({ ok: true, message: "Your account and data have been deleted." });
}
