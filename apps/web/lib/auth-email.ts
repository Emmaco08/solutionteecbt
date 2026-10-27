import "server-only";
import { createHmac } from "node:crypto";
import { createServiceClient } from "@/lib/supabase/server";
import { env } from "@/lib/env";

/** HMAC so the rate-limit log never stores raw emails or IP addresses. */
const hash = (v: string) => createHmac("sha256", env.supabaseSecretKey).update(v.trim().toLowerCase()).digest("hex");

/** Client IP from the proxy headers (Vercel / Cloudflare), or null on localhost. */
export function clientIp(req: Request): string | null {
  const h = req.headers;
  return h.get("cf-connecting-ip") ?? h.get("x-real-ip") ?? h.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null;
}

export type Kind = "signup" | "recovery" | "notice" | "invite" | "test";

const REASONS: Record<string, string> = {
  wait_60s: "Please wait a minute before asking for another code.",
  too_many_for_email: "Too many codes for this email. Try again in an hour.",
  too_many_for_network: "Too many requests from this network. Try again later.",
  daily_limit: "We can't send more emails today. Please try again tomorrow.",
};

/** Asks the database (atomic, rate-limited) whether this email may be sent now. */
export async function allowSend(kind: Kind, email: string, ip: string | null): Promise<{ ok: true } | { ok: false; status: number; error: string }> {
  const svc = await createServiceClient();
  const { data, error } = await svc.rpc("email_send_allowed", { p_kind: kind, p_email_hash: hash(email), p_ip_hash: ip ? hash(ip) : null });
  if (error) return { ok: false, status: 500, error: "Could not send right now. Try again." };
  if (data === "ok") return { ok: true };
  return { ok: false, status: 429, error: REASONS[data] ?? "Please try again later." };
}

/** Uniform JSON responses for the app and web app. */
export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", "cache-control": "no-store" } });

export const PASSWORD_RULE = /^(?=.*[A-Za-z])(?=.*\d).{8,72}$/;
export const EMAIL_RULE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
