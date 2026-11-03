// Paystack payments for the direct APK and the website (milestone 4C, docs/plans/phase-4c.md, D-060).
// POST /functions/v1/paystack   Authorization: Bearer <access token>
//   {action:"start", plan, code?, source?: "app"|"web"}
//      → {free:true, expires_at} when a 100% code covers it, else {reference, url, amount_kobo}
//   {action:"check", reference}
//      → {status: "pending"|"success"|"failed"|"needs_review"|"refunded", expires_at?}
//   {action:"refund", reference}   admins with 2-step only
//      → {requested:true}; Premium is removed when Paystack's refund.processed webhook arrives.
// The app never sends an amount: the price comes from pay_start() on the server.
import { admin, asUser, cors, json, paystack, rpc, userFrom } from "../_shared/pay.ts";
import { trimPaystack } from "../_shared/paycrypto.ts";

const ERR: Record<string, [number, string]> = {
  banned: [403, "This account cannot make payments. Contact support."],
  too_many: [429, "Too many payment attempts. Please wait a few minutes and try again."],
  too_many_tries: [429, "Too many wrong codes. Please wait an hour and try again."],
  plan: [400, "This plan is not on sale any more. Pick another plan."],
  covered: [409, "Your Premium already covers this plan's end date."],
};

async function premiumUntil(uid: string): Promise<string | null> {
  const { data } = await admin.from("entitlements").select("expires_at").eq("user_id", uid).is("revoked_at", null)
    .gt("expires_at", new Date().toISOString()).order("expires_at", { ascending: false }).limit(1);
  return data?.[0]?.expires_at ?? null;
}

/** Asks Paystack about a reference and applies the answer (idempotent). */
async function verifyAndApply(reference: string, kind: "verify" | "admin_check") {
  const v = await paystack(`/transaction/verify/${encodeURIComponent(reference)}`);
  if (!v.ok) {
    // 400 "Transaction reference not found": the student has not opened or finished checkout yet.
    await rpc("pay_note", { p_reference: reference, p_provider: "paystack", p_kind: kind, p_ok: false,
      p_note: `Verify answered ${v.status}: ${String(v.body?.message ?? "").slice(0, 200)}` });
    return { status: "pending" };
  }
  const d = (v.body.data ?? {}) as Record<string, unknown>;
  if (d.reference !== reference) return { status: "pending" };
  return await rpc<{ status: string }>("pay_paystack_result", {
    p_reference: reference, p_status: String(d.status ?? ""), p_amount_kobo: Number(d.amount ?? -1),
    p_currency: String(d.currency ?? ""), p_channel: (d.channel as string) ?? null, p_data: trimPaystack(d), p_kind: kind, p_event_key: null,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const user = await userFrom(req);
  if (!user) return json({ error: "Please log in again.", code: "auth" }, 401);
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "Bad request" }, 400); }
  const action = String(body.action ?? "");

  try {
    if (action === "start") {
      const plan = String(body.plan ?? "");
      const code = typeof body.code === "string" ? body.code.slice(0, 40) : null;
      const r = await rpc<Record<string, unknown>>("pay_start", { p_uid: user.id, p_plan: plan, p_code: code, p_source: body.source === "web" ? "web" : "app" });
      if (!r.ok) {
        const e = String(r.error ?? "");
        const [status, message] = ERR[e] ?? [400, "That code cannot be used."];
        return json({ error: message, code: e, plans: r.plans ?? null }, status);
      }
      if (r.free) return json({ free: true, reference: r.reference, expires_at: r.expires_at });
      const init = await paystack("/transaction/initialize", {
        method: "POST",
        body: JSON.stringify({
          email: r.email,
          amount: r.amount_kobo,
          currency: "NGN",
          reference: r.reference,
          channels: ["card", "bank", "ussd", "bank_transfer"],
          ...(Deno.env.get("PAYSTACK_CALLBACK_URL") ? { callback_url: Deno.env.get("PAYSTACK_CALLBACK_URL") } : {}),
          metadata: { payment_id: r.payment_id, plan, cancel_action: Deno.env.get("PAYSTACK_CALLBACK_URL") || undefined },
        }),
      });
      if (!init.ok) {
        await rpc("pay_note", { p_reference: r.reference, p_provider: "paystack", p_kind: "initialize", p_ok: false,
          p_note: `Paystack answered ${init.status}: ${String(init.body?.message ?? "").slice(0, 200)}` });
        await rpc("pay_paystack_result", { p_reference: r.reference, p_status: "failed", p_amount_kobo: null, p_currency: null,
          p_channel: null, p_data: {}, p_kind: "initialize", p_event_key: null });
        return json({ error: "Paystack is not answering right now. Please try again in a moment.", code: "paystack" }, 502);
      }
      const d = init.body.data as Record<string, unknown>;
      await rpc("pay_note", { p_reference: r.reference, p_provider: "paystack", p_kind: "initialize", p_ok: true, p_note: "Paystack checkout opened" });
      return json({ reference: r.reference, url: d.authorization_url, amount_kobo: r.amount_kobo });
    }

    if (action === "check" || action === "refund") {
      const reference = String(body.reference ?? "");
      if (!/^st_[0-9a-f]{20}$/.test(reference)) return json({ error: "Bad reference" }, 400);
      const { data: pay } = await admin.from("payments").select("user_id, status, provider").eq("reference", reference).maybeSingle();
      if (!pay || pay.provider !== "paystack") return json({ error: "Payment not found" }, 404);
      const isAdmin = (await asUser(user.token).rpc("am_money_admin")).data === true;
      if (pay.user_id !== user.id && !isAdmin) return json({ error: "Payment not found" }, 404);

      if (action === "check") {
        const r = pay.status === "pending" || pay.status === "failed" ? await verifyAndApply(reference, isAdmin && pay.user_id !== user.id ? "admin_check" : "verify")
          : { status: pay.status };
        return json({ status: r.status, expires_at: r.status === "success" && pay.user_id ? await premiumUntil(pay.user_id) : null });
      }

      if (!isAdmin) return json({ error: "Only admins with 2-step login can refund." }, 403);
      if (pay.status !== "success") return json({ error: "Only successful payments can be refunded." }, 409);
      const ref = await paystack("/refund", { method: "POST", body: JSON.stringify({ transaction: reference }) });
      await rpc("pay_note", { p_reference: reference, p_provider: "paystack", p_kind: "refund_requested", p_ok: ref.ok,
        p_note: ref.ok ? "Refund asked for by an admin; Premium is removed when Paystack finishes it" : `Paystack refused: ${String(ref.body?.message ?? ref.status).slice(0, 200)}` });
      if (!ref.ok) return json({ error: String(ref.body?.message ?? "Paystack refused the refund.") }, 502);
      return json({ requested: true });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    console.error(e);
    return json({ error: "Something went wrong. Please try again.", code: "server" }, 500);
  }
});
