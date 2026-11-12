"use client";
// Shared helpers for the tutor chat (D-152): types, formatting, signed file links and uploads.
import { useEffect, useState } from "react";
import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

export type Role = "student" | "tutor" | "admin" | "system";
export type Kind = "text" | "image" | "voice" | "file" | "link" | "ref";
export type Msg = {
  id: number; role: Role; kind: Kind; body: string; attachment: string | null; at: string; read_at: string | null;
  meta: { url?: string; type?: string; duration?: number; size?: number; name?: string; mime?: string } | null;
  ref: { type: "pq" | "lesson" | "quiz"; title?: string; count?: number; minutes?: number | null; due_at?: string | null; subtitle?: string; kind?: string; id?: string; exam_id?: number; subject_id?: number; year?: number; number?: number; snippet?: string } | null;
  /** v3 (D-153): reply, reactions (one per side), delete for everyone, my star. */
  reply_to?: number | null; reply?: Quote | null; reactions?: Partial<Record<Role, string>>; deleted?: boolean; starred?: boolean;
  pending?: boolean; failed?: boolean;
  /** A stable React key: a "sending" copy keeps its key when the server's copy replaces it, so nothing jumps (D-154). */
  ck?: string;
};
export type Quote = { id: number; role: Role; kind: Kind; body: string; deleted?: boolean; meta?: Msg["meta"] };
export type Chat = {
  id: string; user_id: string; name: string; avatar_path?: string | null; status: string; level: string; subject: string | null; tutor_id: string | null; tutor: string | null;
  paid_at: string | null; created_at: string; custom_note: string | null; custom_price_kobo: number | null; custom_days: number | null;
  goals: string; times: string | null; plan: string | null; last: Msg | null; unread: number; sort: string;
};
export type TutorOpt = { id: string; name: string; subjects: string | null; active: boolean; user_id: string | null; last_seen_at?: string | null };

/** A database row (tutor_messages) in the chat's shape. */
export function fromRow(r: Record<string, unknown>): Msg {
  const deleted = r.deleted === true || (r.deleted_at !== undefined && r.deleted_at !== null);
  const reactions = Object.fromEntries(Object.entries((r.reactions ?? {}) as Record<string, string>).filter(([, v]) => Boolean(v))) as Msg["reactions"];
  return {
    id: Number(r.id), role: (r.sender_role ?? r.role) as Role, kind: (deleted ? "text" : (r.kind ?? "text")) as Kind, body: deleted ? "" : String(r.body ?? ""),
    attachment: deleted ? null : ((r.attachment_path ?? r.attachment ?? null) as string | null), at: String(r.created_at ?? r.at), read_at: (r.read_at ?? null) as string | null,
    meta: deleted ? null : ((r.meta ?? null) as Msg["meta"]), ref: deleted ? null : ((r.ref ?? null) as Msg["ref"]),
    reply_to: (r.reply_to ?? null) as number | null, reply: (r.reply ?? undefined) as Quote | undefined, reactions, deleted,
    starred: r.starred === undefined ? undefined : r.starred === true,
  };
}

/** A newer copy of a known message (a raw Realtime row has no reply copy or star: keep ours). */
export function mergeMsg(old: Msg, n: Msg): Msg {
  return { ...old, ...n, ck: old.ck ?? n.ck, reply: n.reply ?? old.reply, starred: n.starred ?? old.starred, read_at: n.read_at ?? old.read_at, pending: false, failed: false };
}

/** Adds new messages and updates known ones (ticks, reactions, deletes), in id order. Our "sending" copies are replaced. */
export function mergeAll(ms: Msg[], fresh: Msg[], myRole: Role): Msg[] {
  const byId = new Map(ms.map((m) => [m.id, m]));
  const added: Msg[] = [];
  for (const n of fresh) {
    const o = byId.get(n.id);
    if (o) byId.set(n.id, mergeMsg(o, n));
    else added.push(n);
  }
  let out = [...byId.values()];
  if (added.length) {
    const keep: Msg[] = [];
    for (const x of out) {
      const twin = x.pending ? added.find((n) => n.role === myRole && n.kind === x.kind && n.body === x.body && !n.ck) : undefined;
      if (twin) twin.ck = x.ck ?? `t${x.id}`; // the server's copy takes over the "sending" bubble's place and key
      else keep.push(x);
    }
    out = [...keep, ...added];
  }
  const quote = (id: number): Quote | null => { const o = out.find((x) => x.id === id); return o ? { id: o.id, role: o.role, kind: o.kind, body: o.body, deleted: o.deleted, meta: o.meta } : null; };
  return out.map((m) => (m.reply_to && !m.reply ? { ...m, reply: quote(m.reply_to) } : m)).sort((a, b) => (a.pending ? 2 ** 52 : a.id) - (b.pending ? 2 ** 52 : b.id));
}

/** Short label for a quoted message. */
export function quoteText(q: Quote | null | undefined) {
  if (!q) return "Message";
  if (q.deleted) return "This message was deleted";
  switch (q.kind) {
    case "image": return "Photo";
    case "voice": return `Voice note${q.meta?.duration ? ` (${fmtDur(q.meta.duration)})` : ""}`;
    case "file": return q.meta?.name ?? "File";
    case "link": return q.body || "Call link";
    case "ref": return q.body || "Study link";
    default: return q.body;
  }
}

/** Which call service a link is: meet, whatsapp, zoom or video. */
export function callType(meta: Msg["meta"]): CallType {
  const t = meta?.type;
  if (t === "meet" || t === "whatsapp" || t === "zoom") return t;
  let host = "";
  try { host = new URL(meta?.url ?? "").host; } catch {}
  if (host.includes("meet.google")) return "meet";
  if (host.includes("zoom.us")) return "zoom";
  if (host.includes("wa.me") || host.includes("whatsapp")) return "whatsapp";
  return "video";
}

/** The real marks (public/third-party, D-153). */
export const LOGOS: Record<CallType, string | null> = { meet: "/third-party/google-meet.svg", whatsapp: "/third-party/whatsapp.svg", zoom: "/third-party/zoom.svg", video: null };
export const CALL_COLOR: Record<CallType, string> = { meet: "#1A73E8", whatsapp: "#1FAF5A", zoom: "#0B5CFF", video: "#2563B3" };

export const QUICK = ["👍", "❤️", "😂", "😮", "🙏", "🔥"];
export const EMOJI: [string, string[]][] = [
  ["Smileys", ["😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "🙂", "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😋", "😎", "🤓", "🧐", "🤔", "🤗", "🤭", "🤫", "😐", "😑", "😶", "🙄", "😏", "😮", "😯", "😲", "😴", "😌", "😛", "😜", "🥲", "😢", "😭", "😤", "😩", "😫", "🥺", "😬", "😰", "😓", "🤯", "😳", "🥳", "😷"]],
  ["Hands", ["👍", "👎", "👏", "🙌", "🙏", "🤝", "👋", "✋", "👌", "✌️", "🤞", "🤟", "🤙", "👈", "👉", "👆", "👇", "☝️", "💪", "✍️", "🫡", "🫶"]],
  ["Study", ["📚", "📖", "📝", "✏️", "🖊️", "📐", "📏", "🧮", "🔬", "🧪", "🧬", "⚗️", "🔭", "🌍", "💡", "🧠", "🎯", "🏆", "🥇", "📅", "⏰", "✅", "❌", "❓", "❗", "💯", "🎓", "🏫"]],
  ["Hearts", ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "💖", "💗", "💓", "💞", "💕", "✨", "⭐", "🌟", "🔥", "🎉", "🎊", "🙌"]],
];

/** "last seen today at 6:40 pm". */
export function lastSeen(iso?: string | null, now = new Date()) {
  if (!iso) return "";
  const l = dayLabel(iso, now);
  return l === "Today" || l === "Yesterday" ? `last seen ${l.toLowerCase()} at ${timeOf(iso)}` : `last seen ${l}`;
}

/** A profile photo (a/<user id>/…) as a short-lived link, or null. */
export function useAvatar(sb: SupabaseClient, path: string | null | undefined) {
  const [url, setUrl] = useState<string | null>(null);
  useEffect(() => {
    let live = true;
    if (path) signed(sb, path).then((u) => live && setUrl(u)).catch(() => live && setUrl(null));
    return () => { live = false; };
  }, [sb, path]);
  return path ? url : null;
}

/** Seconds to wait before joining a channel again: 1, 2, 4, 8, 16, 30… */
export const backoff = (fails: number) => Math.min(30, 2 ** Math.min(fails, 5));

/**
 * A Realtime channel that joins again by itself (D-153). The first join of a private channel can fail on the server
 * while Realtime wakes up, and supabase-js does not join a failed channel again: messages then showed only after a
 * reload. [setup] adds the listeners; [onUp] runs on every (re)join (fetch what was missed, track presence).
 */
export function liveChannel(sb: SupabaseClient, topic: string, opts: { private?: boolean; presenceKey?: string }, setup: (ch: RealtimeChannel) => void,
  onUp?: (ch: RealtimeChannel) => void, onDown?: () => void) {
  let closed = false, fails = 0, ch: RealtimeChannel | null = null, timer: ReturnType<typeof setTimeout> | null = null;
  const open = () => {
    if (closed) return;
    const c = sb.channel(topic, { config: { private: Boolean(opts.private), broadcast: { self: false }, ...(opts.presenceKey ? { presence: { key: opts.presenceKey } } : {}) } });
    setup(c);
    ch = c;
    c.subscribe((s) => {
      if (closed || ch !== c) return;
      if (s === "SUBSCRIBED") { fails = 0; onUp?.(c); return; }
      onDown?.();
      if (timer) return;
      timer = setTimeout(() => { timer = null; if (closed || ch !== c) return; ch = null; void sb.removeChannel(c); open(); }, backoff(fails++) * 1000);
    });
  };
  if (opts.private) void sb.realtime.setAuth().finally(open); else open();
  return {
    get channel() { return ch; },
    close() { closed = true; if (timer) clearTimeout(timer); if (ch) void sb.removeChannel(ch); ch = null; },
  };
}

/** A soft two-note ping for a new message (only when the tab is in the background or another chat is open). */
export function ping() {
  try {
    const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    const ctx = new Ctx();
    [880, 1320].forEach((f, i) => {
      const o = ctx.createOscillator(), g = ctx.createGain();
      o.frequency.value = f; o.type = "sine";
      g.gain.setValueAtTime(0.0001, ctx.currentTime + i * 0.12);
      g.gain.exponentialRampToValueAtTime(0.12, ctx.currentTime + i * 0.12 + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + i * 0.12 + 0.18);
      o.connect(g).connect(ctx.destination); o.start(ctx.currentTime + i * 0.12); o.stop(ctx.currentTime + i * 0.12 + 0.2);
    });
    setTimeout(() => void ctx.close(), 600);
  } catch {}
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
  if (m.deleted) return "This message was deleted";
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
  whatsapp: { label: "WhatsApp", prefix: "https://call.whatsapp.com/" },
  zoom: { label: "Zoom", prefix: "https://zoom.us/j/" },
  video: { label: "Video link", prefix: "https://" },
} as const;
export type CallType = keyof typeof CALLS;
