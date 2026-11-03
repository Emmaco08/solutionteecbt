// Google Play purchases for the Play Store build (milestone 4C, D-060).
// POST /functions/v1/play-verify   Authorization: Bearer <access token>
//   {productId, purchaseToken}
//   → {status:"success", expires_at} · {status:"pending"} (cash/slow bank: try again later)
//   → 4xx {error, code: cancelled | wrong_account | token_used | unknown_product | google}
// Steps: ask Google (purchases.products.get) → it must be purchased and carry this student's account id →
// pay_play_confirm() grants Premium once per token → consume the purchase (this also acknowledges it,
// and lets the student buy the same plan again next time).
import { cors, json, play, rpc, userFrom } from "../_shared/pay.ts";
import { playAccountId, playPurchaseVerdict } from "../_shared/paycrypto.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const user = await userFrom(req);
  if (!user) return json({ error: "Please log in again.", code: "auth" }, 401);
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "Bad request" }, 400); }
  const productId = String(body.productId ?? "");
  const token = String(body.purchaseToken ?? "");
  if (!/^[a-z0-9._]{1,100}$/.test(productId) || token.length < 10 || token.length > 4000) return json({ error: "Bad request" }, 400);

  try {
    const g = await play(`/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}`);
    if (!g.ok) {
      console.error("play get", g.status, g.body);
      return json({ error: "Google could not confirm this purchase yet. Please try again.", code: "google" }, g.status === 404 || g.status === 400 ? 400 : 502);
    }
    const p = g.body as { purchaseState?: number; consumptionState?: number; obfuscatedExternalAccountId?: string; orderId?: string; purchaseTimeMillis?: string; regionCode?: string; purchaseType?: number };
    const verdict = playPurchaseVerdict(p, await playAccountId(user.id));
    if (verdict === "pending") return json({ status: "pending" });
    if (verdict === "cancelled") return json({ error: "This purchase was cancelled.", code: "cancelled" }, 400);
    if (verdict === "wrong_account") return json({ error: "This purchase belongs to another account.", code: "wrong_account" }, 403);

    const r = await rpc<Record<string, unknown>>("pay_play_confirm", {
      p_uid: user.id, p_product: productId, p_token: token, p_order_id: p.orderId ?? null,
      p_data: { orderId: p.orderId ?? null, purchaseTimeMillis: p.purchaseTimeMillis ?? null, regionCode: p.regionCode ?? null,
                test: p.purchaseType === 0 },
    });
    if (!r.ok) {
      const code = String(r.error ?? "");
      return json({ error: code === "token_used" ? "This purchase belongs to another account." : code === "unknown_product" ? "This plan is not set up yet." : "This account cannot make payments.", code },
        code === "unknown_product" ? 400 : 403);
    }
    if (p.consumptionState === 0) {
      const c = await play(`/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}:consume`, { method: "POST" });
      await rpc("pay_note", { p_reference: token, p_provider: "play", p_kind: "consume", p_ok: c.ok,
        p_note: c.ok ? "Purchase consumed (acknowledged) at Google" : `Consume failed (${c.status}); the app will send it again` });
    }
    return json({ status: r.status, expires_at: r.expires_at });
  } catch (e) {
    console.error(e);
    return json({ error: "Something went wrong. Please try again.", code: "server" }, 500);
  }
});
