"use client";
import { useEffect, useRef, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { motion, useReducedMotion } from "motion/react";
import { BookOpenText, Check, Checks, Clock, FilePdf, GoogleLogo, Pause, Phone, Play, VideoCamera, WarningCircle, WhatsappLogo } from "@phosphor-icons/react";
import { cn } from "@/lib/utils";
import { fmtDur, fmtSize, linkParts, signed, timeOf, type Msg } from "./lib";

function useSigned(sb: SupabaseClient, key: string | null) {
  const [url, setUrl] = useState<string | null>(null);
  const [err, setErr] = useState(false);
  useEffect(() => {
    let live = true;
    if (key) signed(sb, key).then((u) => live && setUrl(u)).catch(() => live && setErr(true));
    return () => { live = false; };
  }, [sb, key]);
  return { url, err };
}

function Photo({ sb, k, onOpen }: { sb: SupabaseClient; k: string; onOpen: (url: string) => void }) {
  const { url, err } = useSigned(sb, k);
  if (err) return <div className="grid h-40 w-56 place-items-center rounded-xl bg-black/10 text-xs">Photo not available</div>;
  if (!url) return <div className="h-40 w-56 animate-pulse rounded-xl bg-black/10" />;
  return (
    <button type="button" onClick={() => onOpen(url)} className="block overflow-hidden rounded-xl focus-visible:outline-2" aria-label="Open photo">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={url} alt="Photo in the chat" className="max-h-72 w-auto max-w-[260px] object-cover transition-transform duration-300 hover:scale-[1.02]" loading="lazy" />
    </button>
  );
}

/** WhatsApp-like voice note: play / pause, a 28-bar wave that fills as it plays, time. */
function Voice({ sb, k, duration, mine }: { sb: SupabaseClient; k: string; duration?: number; mine: boolean }) {
  const { url, err } = useSigned(sb, k);
  const ref = useRef<HTMLAudioElement>(null);
  const [playing, setPlaying] = useState(false);
  const [pos, setPos] = useState(0);
  const [len, setLen] = useState(duration ?? 0);
  const [bars] = useState(() => Array.from({ length: 28 }, (_, i) => 0.35 + 0.65 * Math.abs(Math.sin(i * 1.7 + (k.charCodeAt(5) || 3)))));
  const frac = len ? Math.min(1, pos / len) : 0;
  return (
    <div className="flex w-60 items-center gap-3 py-1">
      <button type="button" disabled={!url} onClick={() => { const a = ref.current; if (!a) return; if (a.paused) void a.play(); else a.pause(); }}
        className={cn("grid size-10 shrink-0 place-items-center rounded-full transition-transform active:scale-90", mine ? "bg-white/20" : "bg-primary text-primary-foreground")}
        aria-label={playing ? "Pause voice note" : "Play voice note"}>
        {err ? <WarningCircle size={18} /> : playing ? <Pause size={18} weight="fill" /> : <Play size={18} weight="fill" />}
      </button>
      <div className="flex-1">
        <div className="flex h-7 items-center gap-[2px]" aria-hidden="true">
          {bars.map((h, i) => (
            <span key={i} className={cn("w-[3px] rounded-full transition-colors", i / bars.length <= frac ? (mine ? "bg-white" : "bg-primary") : mine ? "bg-white/35" : "bg-foreground/20")}
              style={{ height: `${h * 100}%` }} />
          ))}
        </div>
        <p className="text-[11px] tabular-nums opacity-75">{fmtDur(playing || pos ? pos : len)}</p>
      </div>
      {url ? <audio ref={ref} src={url} preload="metadata" onPlay={() => setPlaying(true)} onPause={() => setPlaying(false)}
        onEnded={() => { setPlaying(false); setPos(0); }} onTimeUpdate={(e) => setPos(e.currentTarget.currentTime)}
        onLoadedMetadata={(e) => Number.isFinite(e.currentTarget.duration) && setLen(e.currentTarget.duration)} /> : null}
    </div>
  );
}

function FileCard({ sb, m, mine }: { sb: SupabaseClient; m: Msg; mine: boolean }) {
  const [busy, setBusy] = useState(false);
  return (
    <button type="button" disabled={busy} onClick={async () => { setBusy(true); try { window.open(await signed(sb, m.attachment!), "_blank", "noopener,noreferrer"); } finally { setBusy(false); } }}
      className={cn("flex w-64 items-center gap-3 rounded-xl p-2 text-left", mine ? "bg-white/15" : "bg-muted")}>
      <span className="grid size-11 place-items-center rounded-lg bg-red-500/90 text-white"><FilePdf size={22} weight="fill" /></span>
      <span className="min-w-0 flex-1"><b className="block truncate text-sm">{m.meta?.name ?? "Document.pdf"}</b><span className="text-xs opacity-75">PDF · {fmtSize(m.meta?.size)}</span></span>
    </button>
  );
}

const CALL_ICON = { meet: GoogleLogo, whatsapp: WhatsappLogo, zoom: VideoCamera, video: VideoCamera } as const;
function CallCard({ m, mine }: { m: Msg; mine: boolean }) {
  const t = (m.meta?.type ?? "video") as keyof typeof CALL_ICON;
  const Icon = CALL_ICON[t] ?? Phone;
  return (
    <div className={cn("w-64 overflow-hidden rounded-xl", mine ? "bg-white/15" : "bg-muted")}>
      <div className="flex items-center gap-3 p-3">
        <span className={cn("grid size-11 place-items-center rounded-full text-white", t === "whatsapp" ? "bg-[#25D366]" : t === "meet" ? "bg-[#1a73e8]" : "bg-violet-600")}><Icon size={22} weight="fill" /></span>
        <span className="min-w-0"><b className="block text-sm">{m.body || "Join the call"}</b><span className="block truncate text-xs opacity-75">{m.meta?.url?.replace(/^https:\/\//, "")}</span></span>
      </div>
      <a href={m.meta?.url} target="_blank" rel="noopener noreferrer" className={cn("block border-t py-2 text-center text-sm font-bold", mine ? "border-white/20" : "border-border text-primary")}>Join now</a>
    </div>
  );
}

function RefCard({ m, mine }: { m: Msg; mine: boolean }) {
  return (
    <div className={cn("flex w-64 items-start gap-3 rounded-xl p-3", mine ? "bg-white/15" : "bg-muted")}>
      <span className="grid size-10 shrink-0 place-items-center rounded-lg bg-amber-400 text-[#0B1F44]"><BookOpenText size={20} weight="fill" /></span>
      <span className="min-w-0">
        <b className="block text-sm">{m.ref?.title ?? "Study link"}</b>
        {m.ref?.snippet ? <span className="line-clamp-2 block text-xs opacity-80">{m.ref.snippet}</span> : null}
        <span className="mt-1 block text-[11px] opacity-70">{m.ref?.type === "pq" ? "Past question" : "Lesson"} · opens in the SolutionTee app</span>
      </span>
    </div>
  );
}

/** One message. Mine on the right (navy), theirs on the left; system notes in the middle. */
export function Bubble({ sb, m, mine, who, onPhoto, first }: { sb: SupabaseClient; m: Msg; mine: boolean; who?: string; onPhoto: (url: string) => void; first: boolean }) {
  const rm = useReducedMotion();
  if (m.role === "system") {
    return <div className="my-2 flex justify-center"><span className="max-w-[85%] rounded-lg bg-amber-50 px-3 py-1.5 text-center text-xs text-amber-900 shadow-sm dark:bg-amber-950 dark:text-amber-100">{m.body}</span></div>;
  }
  const media = m.kind === "image";
  return (
    <motion.div initial={rm ? false : { opacity: 0, y: 8, scale: 0.97 }} animate={{ opacity: 1, y: 0, scale: 1 }} transition={{ duration: 0.22, ease: "easeOut" }}
      className={cn("flex", mine ? "justify-end" : "justify-start", first ? "mt-2" : "mt-0.5")}>
      <div className={cn("relative max-w-[78%] rounded-2xl shadow-sm", media ? "p-1" : "px-3 py-2",
        mine ? "bg-primary text-primary-foreground" : "bg-card text-card-foreground border",
        first && (mine ? "rounded-tr-md" : "rounded-tl-md"))}>
        {!mine && who && first ? <p className="mb-0.5 text-xs font-bold text-secondary">{who}</p> : null}
        {m.kind === "image" && m.attachment ? <Photo sb={sb} k={m.attachment} onOpen={onPhoto} /> : null}
        {m.kind === "voice" && m.attachment ? <Voice sb={sb} k={m.attachment} duration={m.meta?.duration} mine={mine} /> : null}
        {m.kind === "file" && m.attachment ? <FileCard sb={sb} m={m} mine={mine} /> : null}
        {m.kind === "link" ? <CallCard m={m} mine={mine} /> : null}
        {m.kind === "ref" ? <RefCard m={m} mine={mine} /> : null}
        {m.kind === "text" || (m.body && m.kind === "image") ? (
          <p className={cn("whitespace-pre-wrap break-words text-[15px] leading-snug", media && "px-2 pt-1")}>
            {linkParts(m.body).map((p, i) => p.href ? <a key={i} href={p.href} target="_blank" rel="noopener noreferrer" className="underline underline-offset-2">{p.t}</a> : <span key={i}>{p.t}</span>)}
          </p>
        ) : null}
        <span className={cn("mt-0.5 flex items-center justify-end gap-1 text-[11px] tabular-nums", media && "px-2 pb-1", mine ? "text-primary-foreground/70" : "text-muted-foreground")}>
          {timeOf(m.at)}
          {mine ? (m.failed ? <WarningCircle size={14} className="text-red-300" aria-label="Not sent" />
            : m.pending ? <Clock size={13} aria-label="Sending" />
            : m.read_at ? <Checks size={15} weight="bold" className="text-sky-300" aria-label="Seen" />
            : <Check size={14} weight="bold" aria-label="Sent" />) : null}
        </span>
      </div>
    </motion.div>
  );
}

/** Three bouncing dots while the other person types. */
export function Typing({ name }: { name: string }) {
  const rm = useReducedMotion();
  return (
    <div className="mt-2 flex items-center gap-2">
      <div className="flex gap-1 rounded-2xl border bg-card px-3 py-2.5 shadow-sm" aria-label={`${name} is typing`}>
        {[0, 1, 2].map((i) => (
          <motion.span key={i} className="size-2 rounded-full bg-muted-foreground/60"
            animate={rm ? undefined : { y: [0, -4, 0] }} transition={{ duration: 0.9, repeat: Infinity, delay: i * 0.15 }} />
        ))}
      </div>
    </div>
  );
}
