// Paystack webhook (milestone 4C, D-060). Set in Paystack → Settings → API Keys & Webhooks:
//   https://<project>.supabase.co/functions/v1/paystack-webhook
// 1. The x-paystack-signature header must be HMAC-SHA512(raw body, secret key); anything else gets 401.
// 2. charge.success is never trusted on its own: we call Paystack's verify endpoint, then apply the answer.
// 3. Each body is applied once (event key = sha256 of the body), so Paystack's retries are harmless.
// Deployed with verify_jwt = false (Paystack sends no Supabase token); the signature is the check.
import { json, paystack, paystackKey, rpc } from "../_shared/pay.ts";
import { paystackSignatureOk, sha256Hex, trimPaystack } from "../_shared/paycrypto.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const raw = await req.text();
  if (raw.length > 200_000) return json({ error: "too large" }, 413);
  if (!(await paystackSignatureOk(paystackKey(), raw, req.headers.get("x-paystack-signature")))) {
    return json({ error: "bad signature" }, 401);
  }
  let ev: { event?: string; data?: Record<string, unknown> };
  try { ev = JSON.parse(raw); } catch { return json({ error: "bad json" }, 400); }
  const key = "ps:" + (await sha256Hex(raw));
  const d = ev.data ?? {};

  try {
    if (ev.event === "charge.success") {
      const reference = String(d.reference ?? "");
      if (!reference.startsWith("st_")) return json({ ignored: "not ours" });
      const v = await paystack(`/transaction/verify/${encodeURIComponent(reference)}`);
      if (!v.ok) {
        // Ask Paystack to send it again later (it retries on non-200).
        await rpc("pay_note", { p_reference: reference, p_provider: "paystack", p_kind: "webhook", p_ok: false,
          p_note: `Webhook arrived but verify answered ${v.status}; Paystack will retry` });
        return json({ retry: true }, 503);
      }
      const t = (v.body.data ?? {}) as Record<string, unknown>;
      const r = await rpc("pay_paystack_result", {
        p_reference: reference, p_status: String(t.status ?? ""), p_amount_kobo: Number(t.amount ?? -1),
        p_currency: String(t.currency ?? ""), p_channel: (t.channel as string) ?? null, p_data: trimPaystack(t),
        p_kind: "webhook", p_event_key: key,
      });
      return json(r);
    }

    if (ev.event === "refund.processed") {
      const tx = (d.transaction ?? {}) as Record<string, unknown>;
      const reference = String(d.transaction_reference ?? tx.reference ?? "");
      if (!reference.startsWith("st_")) return json({ ignored: "not ours" });
      const amount = d.amount == null ? null : Number(d.amount);
      const r = await rpc("pay_refunded", {
        p_provider: "paystack", p_reference: reference, p_token: null, p_refund_kobo: amount,
        p_data: { id: d.id ?? null, status: d.status ?? null, amount, currency: d.currency ?? null }, p_event_key: key,
      });
      return json(r);
    }

    if (ev.event === "refund.failed" || ev.event === "refund.pending") {
      const tx = (d.transaction ?? {}) as Record<string, unknown>;
      const reference = String(d.transaction_reference ?? tx.reference ?? "");
      if (reference.startsWith("st_")) {
        await rpc("pay_note", { p_reference: reference, p_provider: "paystack", p_kind: ev.event, p_ok: ev.event !== "refund.failed",
          p_note: ev.event === "refund.failed" ? "Paystack could not finish the refund" : "Refund is being processed by Paystack" });
      }
      return json({ noted: true });
    }

    return json({ ignored: ev.event ?? "unknown" });
  } catch (e) {
    console.error(e);
    return json({ error: "server" }, 500);  // Paystack retries
  }
});
