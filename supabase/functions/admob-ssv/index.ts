// AdMob rewarded-ad server-side verification (big update 2, step B, D-101).
// GET /functions/v1/admob-ssv?ad_network=…&ad_unit=…&custom_data=<nonce>&reward_amount=…&reward_item=…&timestamp=…
//     &transaction_id=…&user_id=<student id>&signature=…&key_id=…
// Google signs the query string (everything before "&signature=") with ECDSA P-256 / SHA-256. We check the signature
// with Google's public keys, then grant the reward once (ad_reward_grant is idempotent on the nonce).
// Set this URL as the "Server-side verification" callback on the rewarded ad unit in AdMob. verify_jwt is off.
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
const KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

let keyCache: { at: number; keys: Map<string, CryptoKey> } | null = null;
async function keys(): Promise<Map<string, CryptoKey>> {
  if (keyCache && Date.now() - keyCache.at < 6 * 3600_000) return keyCache.keys;
  const r = await fetch(KEYS_URL, { signal: AbortSignal.timeout(8000) });
  if (!r.ok) throw new Error(`keys HTTP ${r.status}`);
  const j = await r.json() as { keys: { keyId: number; base64: string }[] };
  const map = new Map<string, CryptoKey>();
  for (const k of j.keys ?? []) {
    const der = Uint8Array.from(atob(k.base64), (c) => c.charCodeAt(0));
    map.set(String(k.keyId), await crypto.subtle.importKey("spki", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]));
  }
  keyCache = { at: Date.now(), keys: map };
  return map;
}

const b64url = (s: string) => Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4)), (c) => c.charCodeAt(0));

/** DER ECDSA signature → raw r||s (64 bytes), which WebCrypto expects. */
function derToRaw(der: Uint8Array): Uint8Array<ArrayBuffer> {
  let i = 2;
  if (der[1] & 0x80) i = 2 + (der[1] & 0x7f);
  const read = () => {
    if (der[i] !== 0x02) throw new Error("bad sig");
    const len = der[i + 1];
    let v = der.slice(i + 2, i + 2 + len);
    i += 2 + len;
    while (v.length > 32 && v[0] === 0) v = v.slice(1);
    const out = new Uint8Array(32);
    out.set(v, 32 - v.length);
    return out;
  };
  const r = read(), s = read();
  const raw = new Uint8Array(new ArrayBuffer(64));
  raw.set(r, 0);
  raw.set(s, 32);
  return raw;
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const q = url.search.slice(1);
  const at = q.indexOf("&signature=");
  if (at < 0) return new Response("ok", { status: 200 }); // AdMob's "verify URL" ping has no signature
  const message = q.slice(0, at);
  const p = url.searchParams;
  const sig = p.get("signature") ?? "";
  const keyId = p.get("key_id") ?? "";
  try {
    const key = (await keys()).get(keyId) ?? (keyCache = null, (await keys()).get(keyId));
    if (!key) return new Response("unknown key", { status: 400 });
    const ok = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, derToRaw(b64url(sig)), new TextEncoder().encode(message));
    if (!ok) return new Response("bad signature", { status: 400 });
    const nonce = p.get("custom_data") ?? "";
    const user = p.get("user_id") ?? "";
    if (!UUID.test(nonce) || !UUID.test(user)) return new Response("ok", { status: 200 }); // verified but not ours (e.g. AdMob test)
    const { data, error } = await admin.rpc("ad_reward_grant", { p_nonce: nonce, p_user: user, p_tx: p.get("transaction_id") ?? "", p_unit: p.get("ad_unit") ?? "" });
    if (error) {
      console.error("admob-ssv grant", error.message);
      return new Response("error", { status: 500 }); // AdMob retries
    }
    console.log("admob-ssv", nonce, JSON.stringify(data));
    return new Response("ok", { status: 200 });
  } catch (e) {
    console.error("admob-ssv", e);
    return new Response("error", { status: 500 });
  }
});
