"use client";
// Shared helpers for the tutor chat (D-152): types, formatting, signed file links and uploads.
import type { SupabaseClient } from "@supabase/supabase-js";

export type Role = "student" | "tutor" | "admin" | "system";
export type Kind = "text" | "image" | "voice" | "file" | "link" | "ref";
export type Msg = {
  id: number; role: Role; kind: Kind; body: string; attachment: string | null; at: string; read_at: string | null;
  meta: { url?: string; type?: string; duration?: number; size?: number; name?: string; mime?: string } | null;
  ref: { type: "pq" | "lesson"; title?: string; subtitle?: string; kind?: string; id?: string; exam_id?: number; subject_id?: number; year?: number; number?: number; snippet?: string } | null;
  pending?: boolean; failed?: boolean;
};
export type Chat = {
  id: string; user_id: string; name: string; status: string; level: string; subject: string | null; tutor_id: string | null; tutor: string | null;
  paid_at: string | null; created_at: string; custom_note: string | null; custom_price_kobo: number | null; custom_days: number | null;
  goals: string; times: string | null; plan: string | null; last: Msg | null; unread: number; sort: string;
};
export type TutorOpt = { id: string; name: string; subjects: string | null; active: boolean; user_id: string | null };

/** A database row (tutor_messages) in the chat's shape. */
export function fromRow(r: Record<string, unknown>): Msg {
  return {
    id: Number(r.id), role: (r.sender_role ?? r.role) as Role, kind: (r.kind ?? "text") as Kind, body: String(r.body ?? ""),
    attachment: (r.attachment_path ?? r.attachment ?? null) as string | null, at: String(r.created_at ?? r.at), read_at: (r.read_at ?? null) as string | null,
    meta: (r.meta ?? null) as Msg["meta"], ref: (r.ref ?? null) as Msg["ref"],
  };
}

export const naira = (k: number) => `₦${Math.round(k / 100).toLocaleString("en-NG")}`;
export const initials = (n: string) => n.trim().split(/\s+/).filter(Boolean).map((p) => p[0]).slice(0, 2).join("").toUpperCase() || "?";
export const timeOf = (iso: string) => new Date(iso).toLocaleTimeString("en-NG", { hour: "numeric", minute: "2-digit" });

export function dayLabel(iso: string, now = new Date()) {
  const d = new Date(iso), a = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime(), b = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const diff = Math.round((b - a) / 86400000);
  if (diff === 0) return "Today";
  if (diff === 1) return "Yesterday";
  if (diff < 7) return d.toLocaleDateString("en-NG", { weekday: "long" });
  return d.toLocaleDateString("en-NG", { day: "numeric", month: "short", year: d.getFullYear() === now.getFullYear() ? undefined : "numeric" });
}

export function listTime(iso: string | undefined, now = new Date()) {
  if (!iso) return "";
  const l = dayLabel(iso, now);
  return l === "Today" ? timeOf(iso) : l;
}

export function preview(m: Msg | null) {
  if (!m) return "No messages yet";
  switch (m.kind) {
    case "image": return "📷 Photo";
    case "voice": return `🎤 Voice note${m.meta?.duration ? ` (${fmtDur(m.meta.duration)})` : ""}`;
    case "file": return `📎 ${m.meta?.name ?? "File"}`;
    case "link": return `📞 ${m.body || "Call link"}`;
    case "ref": return `📚 ${m.ref?.title ?? "Study link"}`;
    default: return m.body;
  }
}

export const fmtDur = (s: number) => `${Math.floor(s / 60)}:${String(Math.round(s % 60)).padStart(2, "0")}`;
export const fmtSize = (b?: number) => (!b ? "" : b > 1024 * 1024 ? `${(b / 1024 / 1024).toFixed(1)} MB` : `${Math.max(1, Math.round(b / 1024))} KB`);

/** Plan string from tutor_chats: "Monthly|2026-12-11 10:00:00+00" → name and days left. */
export function planInfo(plan: string | null) {
  if (!plan) return null;
  const [name, ends] = plan.split("|");
  const left = Math.max(0, Math.ceil((new Date(ends).getTime() - Date.now()) / 86400000));
  return { name, ends, left };
}

const linkCache = new Map<string, { url: string; until: number }>();
/** A short-lived link to a chat file (checked on the server for this chat's members). */
export async function signed(sb: SupabaseClient, key: string): Promise<string> {
  const hit = linkCache.get(key);
  if (hit && hit.until > Date.now()) return hit.url;
  const { data } = await sb.auth.getSession();
  const r = await fetch("/api/images/sign", {
    method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${data.session?.access_token ?? ""}` }, body: JSON.stringify({ key }),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.url) throw new Error(j.error ?? "Could not open the file");
  linkCache.set(key, { url: j.url, until: Date.now() + 8 * 60 * 1000 });
  return j.url as string;
}

/** Uploads a photo, voice note or PDF to this chat's private folder and returns its key. */
export async function upload(sb: SupabaseClient, request: string, blob: Blob, contentType: string): Promise<string> {
  const { data } = await sb.auth.getSession();
  const r = await fetch("/api/tutor/upload", {
    method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${data.session?.access_token ?? ""}` },
    body: JSON.stringify({ request, contentType, size: blob.size }),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(j.error ?? "Upload failed");
  const put = await fetch(j.url, { method: "PUT", headers: { "content-type": contentType }, body: blob });
  if (!put.ok) throw new Error("Upload failed. Check your internet and try again.");
  return j.key as string;
}

/** Turns plain links in a message into anchors (text only, never HTML from the message). */
export function linkParts(text: string): { t: string; href?: string }[] {
  const out: { t: string; href?: string }[] = [];
  const re = /https:\/\/[^\s<>"]+/g;
  let last = 0;
  for (const m of text.matchAll(re)) {
    if (m.index! > last) out.push({ t: text.slice(last, m.index) });
    out.push({ t: m[0], href: m[0] });
    last = m.index! + m[0].length;
  }
  if (last < text.length) out.push({ t: text.slice(last) });
  return out;
}

export const CALLS = {
  meet: { label: "Google Meet", prefix: "https://meet.google.com/" },
  whatsapp: { label: "WhatsApp call", prefix: "https://call.whatsapp.com/" },
  zoom: { label: "Zoom", prefix: "https://zoom.us/j/" },
  video: { label: "Video link", prefix: "https://" },
} as const;
export type CallType = keyof typeof CALLS;
