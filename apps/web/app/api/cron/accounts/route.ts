import { createServiceClient } from "@/lib/supabase/server";
import { hasServiceKey, hasR2 } from "@/lib/env";
import { json } from "@/lib/auth-email";
import { sendEmail } from "@/lib/email";
import { guardianPrizeEmail, inactiveNoticeEmail, outboxEmail } from "@/lib/email-templates";
import { deletePrefix } from "@/lib/r2";

export const maxDuration = 60;

type Due = { notify: { id: string; email: string; name: string }[]; delete: string[] };

/**
 * POST /api/cron/accounts   header x-cron-token (Supabase cron `accounts-nightly`, 03:20 Lagos time)
 * Privacy Policy §10 (D-119):
 * 1. accounts with no activity for 23 months get an email: "log in before <date> or it is deleted";
 * 2. accounts told 30+ days ago that stayed inactive (24 months, no running Premium) are deleted;
 * 3. every deleted account (any route) loses its photos in R2 (`a/<user id>/`). Neon copies: archive-mover.
 * Also (every 10 minutes, body {"only":"minor_wins"}): emails the parent of a student aged 13 to 17 who won cash (D-121).
 * Staff accounts (the owner's included) are never selected by the database.
 */
export async function POST(req: Request) {
  if (!hasServiceKey()) return json({ error: "Not available" }, 503);
  const svc = await createServiceClient();
  const token = req.headers.get("x-cron-token") ?? "";
  const { data: ok } = token ? await svc.rpc("push_cron_ok", { p_token: token }) : { data: false };
  if (ok !== true) return json({ error: "forbidden" }, 403);

  const report = { parents_told: 0, parents_failed: 0, notified: 0, notice_failed: 0, deleted: 0, delete_failed: 0, files_removed: 0, files_failed: 0 };
  const started = Date.now();

  // 0. Parents of students aged 13 to 17 who won cash (D-121; every 10 minutes and nightly).
  const { data: wins } = await svc.rpc("minor_win_notices_due", { p_limit: 50 });
  for (const w of (wins ?? []) as { id: number; kind: "challenge" | "referral"; amount: number; title: string | null; child: string; guardian_email: string }[]) {
    if (Date.now() - started > 25_000) break;
    const mail = guardianPrizeEmail(w.child, w.amount, w.title ?? "", w.kind);
    const sent = await sendEmail({ to: w.guardian_email, ...mail, from: "support", tags: ["guardian-prize"] });
    await svc.rpc("minor_win_notice_mark", { p_id: w.id, p_ok: sent.ok, p_error: sent.error ?? undefined });
    if (sent.ok) report.parents_told++;
    else report.parents_failed++;
  }
  // 0b. Important moments queued by the database (D-127): bans, phone blocks, appeals, receipts, prizes, parent turn-off.
  const { data: outbox } = await svc.rpc("email_outbox_due", { p_limit: 60 });
  let outboxSent = 0, outboxFailed = 0;
  for (const o of (outbox ?? []) as { id: number; kind: string; data: Record<string, unknown>; email: string; name: string }[]) {
    if (Date.now() - started > 40_000) break;
    const mail = outboxEmail(o.kind, o.name, o.data ?? {});
    if (!mail) { await svc.rpc("email_outbox_mark", { p_id: o.id, p_ok: false, p_error: `Unknown email kind ${o.kind}` }); outboxFailed++; continue; }
    const sent = await sendEmail({ to: o.email, ...mail, from: o.kind === "payment_receipt" ? "info" : "support", tags: [`outbox-${o.kind}`] });
    await svc.rpc("email_outbox_mark", { p_id: o.id, p_ok: sent.ok, p_error: sent.error ?? undefined });
    if (sent.ok) outboxSent++; else outboxFailed++;
  }
  Object.assign(report, { emails_sent: outboxSent, emails_failed: outboxFailed });
  const body = (await req.json().catch(() => ({}))) as { only?: string };
  if (body.only === "minor_wins" || body.only === "emails") return json({ ok: true, ...report, ms: Date.now() - started });
  const { data, error } = await svc.rpc("inactive_due", { p_limit: 100 });
  if (error) return json({ error: error.message }, 500);
  const due = (data ?? { notify: [], delete: [] }) as unknown as Due;

  // 1. Notices (Brevo free plan: 300 emails a day shared with log-in codes, so at most 100 a night).
  const deleteOn = new Date(Date.now() + 31 * 86_400_000).toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: "Africa/Lagos" });
  const told: string[] = [];
  for (const u of due.notify) {
    if (Date.now() - started > 40_000) break;
    const mail = inactiveNoticeEmail(u.name, deleteOn, "https://cbt.solutiontee.com");
    const sent = await sendEmail({ to: u.email, ...mail, from: "support", tags: ["inactive-notice"] });
    if (sent.ok) told.push(u.id);
    else report.notice_failed++;
  }
  if (told.length) report.notified = Number((await svc.rpc("inactive_mark", { p_ids: told })).data ?? 0);

  // 2. Deletion of accounts that stayed inactive after the notice.
  for (const id of due.delete) {
    if (Date.now() - started > 45_000) break;
    await svc.from("audit_log").insert({ action: "delete_inactive_account", table_name: "auth.users", row_id: id, after: { at: new Date().toISOString() } });
    const del = await svc.auth.admin.deleteUser(id);
    if (del.error) report.delete_failed++;
    else report.deleted++;
  }

  // 3. Photos of deleted accounts (profile photo, appeal screenshots).
  if (hasR2()) {
    const { data: ids } = await svc.rpc("deleted_users_pending", { p_what: "r2", p_limit: 200 });
    const done: string[] = [];
    for (const id of (ids ?? []) as string[]) {
      if (Date.now() - started > 55_000) break;
      try {
        report.files_removed += await deletePrefix(`a/${id}/`);
        done.push(id);
      } catch {
        report.files_failed++;
      }
    }
    if (done.length) await svc.rpc("deleted_users_done", { p_what: "r2", p_ids: done });
  }
  return json({ ok: true, ...report, ms: Date.now() - started });
}
