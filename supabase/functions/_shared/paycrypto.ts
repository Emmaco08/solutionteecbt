// Pure helpers for the payment Edge Functions (milestone 4C, D-061). No Deno or npm imports, so the same file
// is unit-tested with Node (supabase/functions/_shared/paycrypto.test.mjs) and deployed with the functions.

const enc = new TextEncoder();

export function toHex(buf: ArrayBuffer): string {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Compares two strings in constant time (for signatures and tokens). */
export function safeEqual(a: string, b: string): boolean {
  if (typeof a !== "string" || typeof b !== "string") return false;
  const x = enc.encode(a), y = enc.encode(b);
  let diff = x.length ^ y.length;
  const n = Math.max(x.length, y.length);
  for (let i = 0; i < n; i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

export async function sha256Hex(text: string): Promise<string> {
  return toHex(await crypto.subtle.digest("SHA-256", enc.encode(text)));
}

export async function hmacSha512Hex(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-512" }, false, ["sign"]);
  return toHex(await crypto.subtle.sign("HMAC", key, enc.encode(body)));
}

/** Paystack signs the raw request body with HMAC-SHA512 using the secret key (header x-paystack-signature). */
export async function paystackSignatureOk(secret: string, rawBody: string, header: string | null): Promise<boolean> {
  if (!secret || !header) return false;
  return safeEqual(await hmacSha512Hex(secret, rawBody), header.trim().toLowerCase());
}

/** The Play account id the app sends with a purchase: sha256 of the user id (no personal data goes to Google). */
export function playAccountId(userId: string): Promise<string> {
  return sha256Hex("solutiontee:" + userId);
}

/** Keeps only what the admin timeline needs from a Paystack transaction (no card numbers, no customer details). */
export function trimPaystack(d: Record<string, unknown> | null | undefined): Record<string, unknown> {
  if (!d) return {};
  const auth = (d.authorization ?? {}) as Record<string, unknown>;
  return {
    id: d.id ?? null,
    status: d.status ?? null,
    amount: d.amount ?? null,
    currency: d.currency ?? null,
    channel: d.channel ?? null,
    gateway_response: d.gateway_response ?? null,
    paid_at: d.paid_at ?? d.paidAt ?? null,
    fees: d.fees ?? null,
    bank: auth.bank ?? null,
    card_type: auth.card_type ?? null,
  };
}

function b64url(bytes: Uint8Array | string): string {
  const bin = typeof bytes === "string" ? bytes : String.fromCharCode(...bytes);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const bin = atob(body);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/** A signed JWT (RS256) for Google's OAuth token endpoint, from a service account JSON key. */
export async function googleAssertion(sa: { client_email: string; private_key: string }, scope: string, nowSec = Math.floor(Date.now() / 1000)): Promise<string> {
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope,
    aud: "https://oauth2.googleapis.com/token",
    iat: nowSec,
    exp: nowSec + 3600,
  }));
  const key = await crypto.subtle.importKey("pkcs8", pemToDer(sa.private_key), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, enc.encode(`${header}.${claims}`)));
  return `${header}.${claims}.${b64url(sig)}`;
}

/**
 * Decides what a Google Play products.get answer means for us.
 * purchaseState: 0 purchased, 1 cancelled, 2 pending. The account id must be this student's.
 */
export function playPurchaseVerdict(p: { purchaseState?: number; obfuscatedExternalAccountId?: string }, expectedAccount: string):
  "ok" | "pending" | "cancelled" | "wrong_account" {
  if (p.purchaseState === 2) return "pending";
  if (p.purchaseState !== 0) return "cancelled";
  if (!p.obfuscatedExternalAccountId || !safeEqual(p.obfuscatedExternalAccountId, expectedAccount)) return "wrong_account";
  return "ok";
}
