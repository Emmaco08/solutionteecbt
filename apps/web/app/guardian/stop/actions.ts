"use server";
import { createServiceClient } from "@/lib/supabase/server";
import { hasServiceKey } from "@/lib/env";
import { hashGuardianToken } from "@/lib/guardian";

/**
 * A parent or guardian turns off their child's account from the link in the notice email (D-109).
 * The token is the only proof needed (it went to their inbox). The account is paused at once (sign-in blocked)
 * and deleted after 30 days by the `guardian-withdrawn-delete` job unless support restores it.
 */
export async function stopChildAccount(token: string): Promise<{ ok: boolean; message: string }> {
  if (!hasServiceKey() || !/^[A-Za-z0-9_-]{30,80}$/.test(token)) return { ok: false, message: "This link is not valid." };
  const svc = await createServiceClient();
  const { data: row } = await svc.from("guardian_consents").select("user_id, withdrawn_at").eq("token_hash", hashGuardianToken(token)).maybeSingle();
  if (!row) return { ok: false, message: "This link is not valid or the account no longer exists." };
  if (row.withdrawn_at) return { ok: true, message: "This account is already turned off." };

  const now = new Date().toISOString();
  await svc.from("guardian_consents").update({ withdrawn_at: now, updated_at: now }).eq("user_id", row.user_id);
  await svc.from("profiles").update({ paused_at: now, paused_reason: "guardian" }).eq("id", row.user_id);
  // Blocks sign-in and ends the sessions at their next refresh.
  await svc.auth.admin.updateUserById(row.user_id, { ban_duration: "876000h" });
  await svc.from("audit_log").insert({ action: "guardian_withdrew", table_name: "guardian_consents", row_id: row.user_id, after: { at: now } });
  return { ok: true, message: "Done. The account is turned off and will be deleted in 30 days." };
}
