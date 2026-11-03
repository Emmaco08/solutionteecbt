// Google Play Real-time developer notifications (milestone 4C, D-060): refunds and chargebacks.
// Pub/Sub push subscription endpoint:
//   https://<project>.supabase.co/functions/v1/play-rtdn?token=<PLAY_RTDN_TOKEN>
// The message body is not trusted: for a voided purchase we look the token up in Google's Voided Purchases API
// before removing Premium. Deployed with verify_jwt = false; the URL token is the check.
import { json, play, rpc } from "../_shared/pay.ts";
import { safeEqual } from "../_shared/paycrypto.ts";

async function isVoided(token: string): Promise<Record<string, unknown> | null> {
  const start = Date.now() - 30 * 24 * 3600_000;
  let page = "";
  for (let i = 0; i < 10; i++) {
    const q = new URLSearchParams({ startTime: String(start), type: "0", maxResults: "1000", ...(page ? { token: page } : {}) });
    const r = await play(`/purchases/voidedpurchases?${q}`);
    if (!r.ok) throw new Error(`voidedpurchases ${r.status}`);
    const list = (r.body.voidedPurchases ?? []) as Record<string, unknown>[];
    const hit = list.find((v) => v.purchaseToken === token);
    if (hit) return hit;
    page = ((r.body.tokenPagination as Record<string, string> | undefined)?.nextPageToken) ?? "";
    if (!page) return null;
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const want = Deno.env.get("PLAY_RTDN_TOKEN") ?? "";
  const got = new URL(req.url).searchParams.get("token") ?? "";
  if (!want || !safeEqual(want, got)) return json({ error: "forbidden" }, 403);

  let msg: { message?: { data?: string; messageId?: string } };
  try { msg = await req.json(); } catch { return json({ error: "bad json" }, 400); }
  let n: Record<string, unknown> = {};
  try { n = JSON.parse(atob(msg.message?.data ?? "")); } catch { return json({ ignored: "no data" }); }
  if (n.packageName && n.packageName !== (Deno.env.get("PLAY_PACKAGE_NAME") || "com.solutiontee.cbt")) return json({ ignored: "other app" });

  try {
    const v = n.voidedPurchaseNotification as { purchaseToken?: string; orderId?: string; refundType?: number } | undefined;
    if (v?.purchaseToken) {
      const hit = await isVoided(v.purchaseToken);
      if (!hit) {
        await rpc("pay_note", { p_reference: v.purchaseToken, p_provider: "play", p_kind: "rtdn_void", p_ok: false,
          p_note: "Google sent a refund notice, but the Voided Purchases API does not list it yet; will retry" });
        return json({ retry: true }, 503);  // Pub/Sub retries
      }
      const r = await rpc("pay_refunded", {
        p_provider: "play", p_reference: null, p_token: v.purchaseToken, p_refund_kobo: null,
        p_data: { orderId: hit.orderId ?? v.orderId ?? null, voidedReason: hit.voidedReason ?? null, voidedSource: hit.voidedSource ?? null },
        p_event_key: "rtdn:" + (msg.message?.messageId ?? v.purchaseToken),
      });
      return json(r);
    }
    // oneTimeProductNotification (bought / cancelled) and testNotification: the app reports purchases itself
    // (play-verify), so these are only acknowledged.
    return json({ ignored: Object.keys(n).find((k) => k.endsWith("Notification")) ?? "unknown" });
  } catch (e) {
    console.error(e);
    return json({ error: "server" }, 500);
  }
});
