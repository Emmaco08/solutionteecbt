// Shared server code for the payment Edge Functions (milestone 4C, D-061).
// Paystack keys (D-133): typed by a super admin in admin → Payment settings and kept in Supabase Vault (Test and Live),
// read with paystack_config(). The old Edge Function secrets below still fill any key that is not in Vault.
// Secrets (Edge Function secrets, never in the app):
//   PAYSTACK_SECRET_KEY            sk_test_… / sk_live_…
//   PAYSTACK_CALLBACK_URL          optional page Paystack returns to after paying
//   PAYSTACK_PUBLIC_KEY            pk_test_… / pk_live_… (public; lets the app open Paystack's own sheet inside the app, D-089)
//   GOOGLE_PLAY_SERVICE_ACCOUNT    the service account JSON key (one line)
//   PLAY_PACKAGE_NAME              optional, default com.solutiontee.cbt
//   PLAY_RTDN_TOKEN                random secret in the Pub/Sub push URL
import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { googleAssertion } from "./paycrypto.ts";

export const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false, autoRefreshToken: false },
});

export const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
  "access-control-allow-methods": "POST, OPTIONS",
};
export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "content-type": "application/json" } });

export function bearer(req: Request): string {
  return (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
}

/** The signed-in user (checked by Supabase Auth), or null. */
export async function userFrom(req: Request): Promise<{ id: string; token: string } | null> {
  const token = bearer(req);
  if (!token) return null;
  const { data } = await admin.auth.getUser(token);
  return data.user ? { id: data.user.id, token } : null;
}

/** A client that acts as the caller (RLS and their 2-step status apply). */
export function asUser(token: string) {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { authorization: `Bearer ${token}` } },
  });
}

export async function rpc<T = Record<string, unknown>>(fn: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await admin.rpc(fn, args);
  if (error) throw new Error(`${fn}: ${error.message}`);
  return data as T;
}

// ---------------------------------------------------------------- Paystack
const PAYSTACK = "https://api.paystack.co";

export type PaystackMode = "live" | "test";
/** legacy: no key saved in admin → Payment settings yet; the old Edge Function secrets are used exactly as before. */
export type PaystackConfig = { mode: PaystackMode; legacy: boolean; sk: Record<PaystackMode, string>; pk: Record<PaystackMode, string> };
let cfgCache: { at: number; c: PaystackConfig } | null = null;

/** The current mode (admin's Test / Live switch) and the keys for both modes. Cached for 30 seconds. */
export async function paystackConfig(): Promise<PaystackConfig> {
  if (cfgCache && Date.now() - cfgCache.at < 30_000) return cfgCache.c;
  const { data, error } = await admin.rpc("paystack_config");
  const d = (error ? {} : (data ?? {})) as Record<string, string | null>;
  const envSk = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "", envPk = Deno.env.get("PAYSTACK_PUBLIC_KEY") ?? "";
  // The old secrets count for Live unless they are clearly test keys, and for Test only when they are test keys.
  const isTest = (k: string) => k.trim().startsWith("sk_test_") || k.trim().startsWith("pk_test_");
  const legacy = !d.sk_live && !d.sk_test;
  const c: PaystackConfig = {
    mode: legacy ? (isTest(envSk) ? "test" : "live") : d.mode === "test" ? "test" : "live",
    legacy,
    sk: { live: d.sk_live || (isTest(envSk) ? "" : envSk.trim()), test: d.sk_test || (isTest(envSk) ? envSk.trim() : "") },
    pk: { live: d.pk_live || (isTest(envPk) ? "" : envPk.trim()), test: d.pk_test || (isTest(envPk) ? envPk.trim() : "") },
  };
  if (!error) cfgCache = { at: Date.now(), c };
  return c;
}

/** The secret key for [mode] (default: the current mode). */
export async function paystackKey(mode?: PaystackMode): Promise<string> {
  const c = await paystackConfig();
  const k = c.sk[mode ?? c.mode];
  if (!k) throw new Error(`The Paystack ${mode ?? c.mode} secret key is not set (admin → Payment settings)`);
  return k;
}

/** A Paystack API call with the key of [mode] (default: the current mode). A payment is always checked in the mode it
 *  was made in (payments.live). */
export async function paystack(path: string, init: RequestInit = {}, mode?: PaystackMode): Promise<{ ok: boolean; status: number; body: Record<string, unknown> }> {
  const res = await fetch(PAYSTACK + path, {
    ...init,
    headers: { authorization: `Bearer ${await paystackKey(mode)}`, "content-type": "application/json", ...(init.headers ?? {}) },
    signal: AbortSignal.timeout(20_000),
  });
  const body = await res.json().catch(() => ({}));
  return { ok: res.ok && body?.status === true, status: res.status, body };
}

// ---------------------------------------------------------------- Google Play
let gToken: { at: number; token: string } | null = null;

export async function googleToken(): Promise<string> {
  if (gToken && Date.now() - gToken.at < 50 * 60_000) return gToken.token;
  const raw = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT") ?? "";
  if (!raw) throw new Error("GOOGLE_PLAY_SERVICE_ACCOUNT is not set");
  const sa = JSON.parse(raw);
  const assertion = await googleAssertion(sa, "https://www.googleapis.com/auth/androidpublisher");
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
    signal: AbortSignal.timeout(15_000),
  });
  const body = await res.json();
  if (!res.ok || !body.access_token) throw new Error("Google sign-in failed: " + (body.error_description ?? body.error ?? res.status));
  gToken = { at: Date.now(), token: body.access_token };
  return gToken.token;
}

export const playPackage = () => Deno.env.get("PLAY_PACKAGE_NAME") || "com.solutiontee.cbt";

export async function play(path: string, init: RequestInit = {}): Promise<{ ok: boolean; status: number; body: Record<string, unknown> }> {
  const res = await fetch(`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${playPackage()}${path}`, {
    ...init,
    headers: { authorization: `Bearer ${await googleToken()}`, "content-type": "application/json", ...(init.headers ?? {}) },
    signal: AbortSignal.timeout(20_000),
  });
  const text = await res.text();
  let body: Record<string, unknown> = {};
  try { body = text ? JSON.parse(text) : {}; } catch { body = { raw: text.slice(0, 300) }; }
  return { ok: res.ok, status: res.status, body };
}
