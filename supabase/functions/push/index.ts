// Push notifications (milestone 4D, docs/plans/phase-4d.md, D-063).
// POST /functions/v1/push  {"run":"due"}
//   Called every 5 minutes by pg_cron (header x-cron-token, checked against Vault), or by an admin's "Send now"
//   (Authorization: Bearer <admin access token>, editors and up with 2-step).
// Takes due messages once (push_take_due), sends them with FCM HTTP v1, and records the result (push_done).
// Broadcasts go to FCM topics: every phone subscribes to t_<topic> for the topics it keeps on, and to tier_free or
// tier_premium. Personal and staff messages go to the saved tokens of those users.
// Without the FIREBASE_SERVICE_ACCOUNT secret, messages are still marked sent so they show in the app's inbox.
// Deployed with verify_jwt = false: the cron call has no user token; this function checks the caller itself.
import { admin, asUser, cors, json, rpc } from "../_shared/pay.ts";
import { googleAssertion } from "../_shared/paycrypto.ts";
import { fcmMessage, type PushRow } from "../_shared/fcm.ts";

let gToken: { at: number; token: string; project: string } | null = null;

async function firebase(): Promise<{ token: string; project: string } | null> {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";
  if (!raw) return null;
  if (gToken && Date.now() - gToken.at < 50 * 60_000) return gToken;
  const sa = JSON.parse(raw);
  const assertion = await googleAssertion(sa, "https://www.googleapis.com/auth/firebase.messaging");
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
    signal: AbortSignal.timeout(15_000),
  });
  const body = await res.json();
  if (!res.ok || !body.access_token) throw new Error("Firebase sign-in failed: " + (body.error_description ?? body.error ?? res.status));
  gToken = { at: Date.now(), token: body.access_token, project: sa.project_id };
  return gToken;
}

async function send(fb: { token: string; project: string }, message: Record<string, unknown>) {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${fb.project}/messages:send`, {
    method: "POST",
    headers: { authorization: `Bearer ${fb.token}`, "content-type": "application/json" },
    body: JSON.stringify({ message }),
    signal: AbortSignal.timeout(15_000),
  });
  if (res.ok) return { ok: true as const };
  const body = await res.json().catch(() => ({}));
  const code = String(body?.error?.details?.find?.((d: Record<string, unknown>) => d.errorCode)?.errorCode ?? body?.error?.status ?? res.status);
  return { ok: false as const, code, gone: res.status === 404 || code === "UNREGISTERED" || code === "INVALID_ARGUMENT" };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const cron = req.headers.get("x-cron-token");
  let allowed = false;
  if (cron) allowed = await rpc<boolean>("push_cron_ok", { p_token: cron }).catch(() => false);
  if (!allowed) {
    const token = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
    if (token) allowed = (await asUser(token).rpc("am_notifier")).data === true;
  }
  if (!allowed) return json({ error: "forbidden" }, 403);

  try {
    const rows = await rpc<PushRow[]>("push_take_due", { p_limit: 50 });
    if (!rows.length) return json({ sent: 0, messages: 0 });
    let fb: { token: string; project: string } | null = null;
    let fbError: string | null = null;
    try { fb = await firebase(); } catch (e) { fbError = String((e as Error).message).slice(0, 200); }

    let total = 0;
    for (const row of rows) {
      if (!fb) {
        await rpc("push_done", { p_id: row.id, p_sent: 0, p_error: fbError ?? "Push is off: FIREBASE_SERVICE_ACCOUNT is not set (inbox only)" });
        continue;
      }
      let sent = 0;
      const errors: string[] = [];
      const gone: string[] = [];
      const targets = row.audience === "user" || row.audience === "staff" ? (row.tokens ?? []).map((t) => ({ token: t })) : [{ token: null }];
      for (const t of targets.slice(0, 500)) {
        const r = await send(fb, fcmMessage(row, t.token));
        if (r.ok) sent++;
        else {
          errors.push(r.code);
          if (t.token && r.gone) gone.push(t.token);
        }
      }
      if (gone.length) await admin.from("push_tokens").delete().in("token", gone);
      total += sent;
      const err = errors.length ? `${errors.length} failed (${[...new Set(errors)].join(", ")})` : (targets.length ? null : "No phones to send to");
      await rpc("push_done", { p_id: row.id, p_sent: sent, p_error: err });
    }
    return json({ sent: total, messages: rows.length, push: fb ? "on" : "off" });
  } catch (e) {
    console.error(e);
    return json({ error: "server" }, 500);
  }
});
